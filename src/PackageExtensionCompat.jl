module PackageExtensionCompat

export @require_extensions

const HAS_NATIVE_EXTENSIONS = isdefined(Base, :get_extension)

@static if !HAS_NATIVE_EXTENSIONS
    using MacroTools, Requires, TOML

    @static if hasmethod(Base.include, Tuple{Function, Module, String})
        function _include(mapexpr::Function, m::Module, path::AbstractString)
            Base.include(mapexpr, m, path)
        end
    else
        function _include(mapexpr::Function, m::Module, path::AbstractString)
            str = read(path, String)
            pos = 1
            while true
                (expr, pos) = Meta.parse(str, pos; raise=false)
                expr !== nothing || break
                m.eval(mapexpr(expr))
            end
        end
    end

    rewrite(pkgs) = Base.Fix2(rewrite, pkgs)

    function rewrite(expr, pkgs)
        MacroTools.postwalk(Base.Fix2(rewrite_block, pkgs), expr)
    end

    function rewrite_block(block, pkgs)
        !Meta.isexpr(block, [:using, :import]) && return block
        imports = map(block.args) do use
            Meta.isexpr(use, [:(:), :as]) ?
                Expr(use.head, rewrite_use(use.args[1], pkgs), use.args[2:end]...) :
                rewrite_use(use, pkgs)
        end
        Expr(block.head, imports...)
    end

    function rewrite_use(use::Expr, pkgs)::Expr
        @assert Meta.isexpr(use, :.)
        string(use.args[1]) ∈ pkgs ? Expr(:., :., :., use.args...) : use
    end

    macro require_extensions()
        rootdir = dirname(dirname(pathof(__module__)))
        tomlpath = nothing
        for file in ["JuliaProject.toml", "Project.toml"]
            path = joinpath(rootdir, file)
            if isfile(path)
                tomlpath = path
            end
        end
        if tomlpath === nothing
            error("Expecting Project.toml or JuliaProject.toml in $rootdir. Not a package?")
        end
        toml = open(TOML.parse, tomlpath)
        extensions = get(toml, "extensions", [])
        isempty(extensions) && error("no extensions defined in $tomlpath")
        exprs = []
        for (name, pkgs) in extensions
            if pkgs isa String
                pkgs = [pkgs]
            end
            extpath = nothing
            for path in [joinpath(rootdir, "ext", "$name.jl"),
                         joinpath(rootdir, "ext", "$name", "$name.jl")]
                if isfile(path)
                    extpath = path
                end
            end
            extpath === nothing && error("Expecting ext/$name.jl or ext/$name/$name.jl in $rootdir for extension $name.")
            __module__.include_dependency(extpath)
            # include and rewrite the extension code
            expr = :($(_include)($(rewrite(pkgs)), $__module__, $extpath))
            for pkg in pkgs
                uuid = get(get(Dict, toml, "weakdeps"), pkg, nothing)
                uuid === nothing && error("Expecting a weakdep for $pkg in $tomlpath.")
                expr = :($Requires.@require $(Symbol(pkg))=$(uuid) $expr)
            end
            push!(exprs, expr)
        end
        push!(exprs, nothing)
        esc(Expr(:block, exprs...))
    end

else
    macro require_extensions()
        nothing
    end
end

end # module PackageExtensionCompat

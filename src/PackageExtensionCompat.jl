module PackageExtensionCompat

export @require_extensions

const HAS_NATIVE_EXTENSIONS = isdefined(Base, :get_extension)

@static if !HAS_NATIVE_EXTENSIONS
    using Requires, TOML

    _mapexpr(ms) = ex -> _mapexpr(ms, ex)

    function _mapexpr(ms, ex)
        # replace "using Foo" with "using ..Foo" for any Foo in ms
        @assert ex isa Expr
        @assert ex.head == :module
        for (i, arg) in pairs(ex.args[3].args)
            if arg isa Expr && arg.head in (:using, :import)
                for (j, mod) in pairs(arg.args)
                    if mod isa Expr && mod.head == :. && length(mod.args) == 1 && mod.args[1] isa Symbol && mod.args[1] in ms
                        arg.args[j] = Expr(:., :., :., mod.args[1])
                    end
                end
            end
        end
        ex
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
            mapexpr = _mapexpr(map(Symbol, pkgs))
            extpath = nothing
            for file in ["ext/$name.jl", "ext/$name/$name.jl"]
                path = joinpath(rootdir, file)
                if isfile(path)
                    extpath = path
                end
            end
            extpath === nothing && error("Expecting ext/$name.jl or ext/$name/$name.jl in $rootdir for extension $name.")
            expr = :(include($mapexpr, $extpath))
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

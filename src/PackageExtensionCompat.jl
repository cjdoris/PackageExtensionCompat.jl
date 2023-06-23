module PackageExtensionCompat

export @require_extensions

const HAS_NATIVE_EXTENSIONS = isdefined(Base, :get_extension)

@static if !HAS_NATIVE_EXTENSIONS
    using Requires, TOML

    _mapexpr(ms::Vector{Symbol}) = (ex::Expr) -> _mapexpr(ms, ex)

    function _mapexpr(ms::Vector{Symbol}, ex::Expr)
        # skip some top-level constructs
        if ex.head in (:struct, :function, :(=), :macro, :const, :call)
            return ex
        end
        # replace "using Foo" with "using ..Foo" for any Foo in ms
        is_import = ex.head in (:using, :import)
        for (j, ex2) in pairs(ex.args)
            if ex2 isa Expr
                ex.args[j] = is_import ? _mapexpr_import_arg(ms, ex2) : _mapexpr(ms, ex2)
            end
        end
        ex
    end

    function _mapexpr_import_arg(ms::Vector{Symbol}, ex::Expr)
        if ex.head == :.
            # import Foo
            # import Foo.Bar
            # NOT import .Foo
            # NOT import ..Foo
            if length(ex.args) ≥ 1
                m = ex.args[1]
                if m isa Symbol && m != :. && m in ms
                    # import Foo -> import ..Foo
                    pushfirst!(ex.args, :., :.)
                end
            end
        elseif ex.head == :as
            # import ... as Foo2
            if length(ex.args) == 2
                m = ex.args[1]
                if m isa Expr
                    ex.args[1] == _mapexpr_import_arg(ms, m)
                end
            end
        elseif ex.head == :(:)
            # import ...: foo, bar, baz
            if length(ex.args) ≥ 1
                m = ex.args[1]
                if m isa Expr
                    ex.args[1] = _mapexpr_import_arg(ms, m)
                end
            end
        end
        return ex
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

module PackageExtensionCompat

export @require_extensions

const HAS_NATIVE_EXTENSIONS = isdefined(Base, :get_extension)

@static if !HAS_NATIVE_EXTENSIONS
    using Requires, TOML

    function rewrite_import(str, pkgs)
        parts = split(strip(str))
        if length(parts) == 1 || (length(parts) ≥ 2 && parts[2] == "as")
            if parts[1] ∈ pkgs
                parts[1] = string("..", parts[1])
            end
        end
        join(parts, " ")
    end

    function rewrite_imports(str, pkgs)
        parts = split(str, ",")
        parts = map(part -> rewrite_import(part, pkgs), parts)
        join(parts, ", ")
    end

    function rewrite_line(line, pkgs)
        pat = r"^(\s*(using|import)\s+)([^;:#$]*[^;:#$\s])(.*)$"
        m = match(pat, line)
        if m === nothing
            line
        else
            string(m.captures[1], rewrite_imports(m.captures[3], pkgs), m.captures[4])
        end
    end

    function rewrite(srcfile, trgfile, pkgs)
        lines = readlines(srcfile)
        lines = map(line -> rewrite_line(line, pkgs), lines)
        code = join(lines, "\n")
        write(trgfile, code)
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
        rm(joinpath(rootdir, "ext_compat"), force=true, recursive=true)
        for (name, pkgs) in extensions
            if pkgs isa String
                pkgs = [pkgs]
            end
            extpath = nothing
            for path in [joinpath(rootdir, "ext", "$name.jl"), joinpath(rootdir, "ext", "$name", "$name.jl")]
                if isfile(path)
                    extpath = path
                end
            end
            extpath === nothing && error("Expecting ext/$name.jl or ext/$name/$name.jl in $rootdir for extension $name.")
            # rewrite the extension code
            # TODO: there may be other files to copy/rewrite
            __module__.include_dependency(extpath)
            extpath2 = joinpath(rootdir, "ext_compat", relpath(extpath, joinpath(rootdir, "ext")))
            mkpath(dirname(extpath2))
            rewrite(extpath, extpath2, pkgs)
            # include the extension code
            expr = :($(__module__.include)($extpath2))
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

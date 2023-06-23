module TestPackage

using PackageExtensionCompat

function __init__()
    @require_extensions
end

function hello_world end

end # module TestPackage

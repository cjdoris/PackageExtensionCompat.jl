module TestPackage

using PackageExtensionTools

function __init__()
    @require_extensions
end

function hello_world end

end # module TestPackage

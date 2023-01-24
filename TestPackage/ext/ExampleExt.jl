module ExampleExt

using TestPackage, Example

function __init__()
    @info "HELLO!!!"
end

TestPackage.hello_world() = Example.hello("World")

end

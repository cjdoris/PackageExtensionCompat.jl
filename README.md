# PackageExtensionCompat

[![Project Status: Unsupported – The project has reached a stable, usable state but the author(s) have ceased all work on it. A new maintainer may be desired.](https://www.repostatus.org/badges/latest/unsupported.svg)](https://www.repostatus.org/#unsupported)
[![Tests](https://github.com/cjdoris/PackageExtensionCompat.jl/actions/workflows/tests.yml/badge.svg)](https://github.com/cjdoris/PackageExtensionCompat.jl/actions/workflows/tests.yml)

**Note: This package is now unsupported because it is a no-op on Julia 1.9 and later, and older versions are no longer supported.**

Julia introduced
[package extensions](https://pkgdocs.julialang.org/v1.9/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions))
in v1.9. This package makes these extensions backwards-compatible to earlier Julia versions,
with zero overhead on new versions.

Internally, this uses
[Requires.jl](https://github.com/JuliaPackaging/Requires.jl)
on earlier versions, automating
[this strategy](https://pkgdocs.julialang.org/v1.9/creating-packages/#Requires.jl)
in the Pkg.jl docs.

Supports all versions of Julia from 1.0 upwards.

## Usage

Supposing you have a package called `Foo`:

1. Set up package extensions for `Foo` as usual. This means adding `[weakdeps]` and
   `[extensions]` to `Project.toml` and adding extension code to `ext/`.

2. Add `PackageExtensionCompat` as a dependency to `Foo`.

3. Add the following code to `src/Foo.jl`:
   ```julia
   using PackageExtensionCompat
   function __init__()
       @require_extensions
   end
   ```

That's it! Your package extensions will now be loaded as expected on any Julia version!

## Example

See
[the example folder](https://github.com/cjdoris/PackageExtensionCompat.jl/tree/main/example)
for an example package using this functionality.

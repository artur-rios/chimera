# NuGet Library Template Provenance

UC-54 bundles `dotnet-tools/templates` from commit
`7cd0a4867dbbd0301ddb5e6a207fbb0b29c56998`; the matching Python implementation is
`python-dotnet-tools` commit `c7255b386ca49a40cbafde7c6e4edd29b25fdebf`.
The original Artur Rios Attribution License and README credits are retained in
every generated repository. Runtime generation does not fetch templates.

The raw template constants are embedded in
`packages/chimera_utilities/lib/src/dotnet_repository_templates.dart`. They retain
the source configuration content, normalize CRLF to LF, and remove the UTF-8 BOM
from `.editorconfig`. Rendered bundles identify the source revision plus
`chimera-v1` and carry SHA-256 content checks for the shared writer.

The renderer deliberately corrects these source defects:

- Company uses the supplied Company value, independently of Author.
- The solution refers to the library directly inside `src` and includes the test
  project in `tests`, including both build configurations.
- Test package versions are pinned: coverlet.collector 6.0.4,
  Microsoft.NET.Test.Sdk 17.14.1, xunit 2.9.3, and
  xunit.runner.visualstudio 3.1.5. No floating restore selections are generated.
- The library's existing pack entries include root README and LICENSE. A real
  package build verifies they exist; no inconsistent copy of README is needed.
- A documented sample class and matching xUnit test make the generated solution
  immediately buildable and testable. `docs/.gitkeep` preserves the docs folder.
- Template substitution is a single pass, and metadata is XML-escaped. Literal
  text resembling another template key is preserved. MSBuild expressions and
  invalid XML code points are rejected before writing.

The fixture `packages/chimera_utilities/test/fixtures/dotnet_library/expected.json`
records independent expected content for all eleven generated files. The
acceptance command `dart run tool/verify_dotnet_library.dart` creates a temporary
repository, restores, builds, tests and packs it, then removes the temporary
output. Set `CHIMERA_DOTNET_RESTORE_SOURCE` to an existing local feed directory to
verify using cached packages without a remote source. The workflow
`.github/workflows/dotnet-library-scaffold.yml` runs these checks on Windows and
Linux with .NET 10. Those verification commands are never part of generation.

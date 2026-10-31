# UC-55 design and implementation plan

Scope: issue #104, FR-DW-09, BR-DW-09. The user authorized implementation and
verification without intermediate approval gates; a human must merge the PR.
This separate branch depends on shared scaffold/parser/renderer foundation
commit e993332 and its prerequisites, and targets develop after those changes.

Extend `DotnetRepositoryRenderer` with `renderMinimalLibrary(parameters, year)`
and reuse the five-field parser with `nuget:false`. The versioned bundle follows
pinned init-min templates: root config/license/README, src README, solution and
nested minimal project, plus docs/tests `.gitkeep` placeholders. Keep original
license attribution, omit all NuGet metadata and test projects, use shared
stable GUIDs, and correct the src README license link to `../LICENSE`.

`MinimalLibraryScaffoldService` validates and renders, then delegates directly
to `ScaffoldService` and `NativeScaffoldWriter`; introduce no second writer or
filesystem transaction. Existing destination, failed writes, and verification
failures retain the shared ownership/rollback safeguards.

CLI `dotnet init-min` supports the five flags or `--parameters <file>` and
structured `--json` output. Desktop `/dotnet/init-min` offers exclusive fields
or JSON file modes with localized EN/PT controls and outcomes. Web shows an
explicit unsupported result. JSON file loading is bounded and errors omit raw
input/exception text.

Sequence: failing renderer/core/adapter tests; independent source-derived
fixtures; minimal renderer/service; native CLI/desktop adapters; complete specs
and exact localization fixture; focused analysis, rollback tests, real temporary
.NET Debug/Release builds, and Windows/Linux acceptance CI. Full repository
checks are scheduled by the parent agent.

Independent review identified stale JSON selection after failed replacement.
Clear cached parameters before loading a replacement, disable interactions while
loading, and require a loaded JSON file before creation. A widget regression
was observed failing before this fix and passing after it. Shared parser review
fix 3bb67f5 is included as prerequisite-only cherry-pick 8948173, without UC-54
adapters. Full repository and Windows runtime checks remain for parent/CI.

Final focused verification: 60 Dart tests (including the complete localization
catalog and real generated .NET 10 Debug/Release builds), 4 widget tests, focused
fatal-info analysis, and dependency boundaries pass. Independent re-review found
no remaining Important findings after the stale-parameter fix.

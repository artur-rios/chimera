# UC-54 Scaffold NuGet Library Implementation Plan

> Execute inline under the approved M08 batch. No intermediate approval gates; human merge remains mandatory.

**Goal:** Render and transactionally create a complete offline NuGet library repository from flags/fields or one JSON parameter document.

**Architecture:** Utilities validate common repository parameters and render versioned embedded source templates into a `TemplateBundle`. `NugetLibraryScaffoldService` passes the rendered bundle to UC-47's `ScaffoldService` and `NativeScaffoldWriter`, preserving its exclusive destination reservation and safe rollback. Desktop and CLI use the same request/service, while web returns typed unsupported without a filesystem operation.

**Tech Stack:** Existing Dart/Flutter dependencies; .NET 10 SDK for build acceptance. No runtime downloads or subprocess generation.

**Spec:** Issue #103, dotnet-tools 7cd0a4867dbbd0301ddb5e6a207fbb0b29c56998 init-lib.ps1 and templates; python-dotnet-tools c7255b386ca49a40cbafde7c6e4edd29b25fdebf init_lib.py.

## Decisions and constraints

- Exactly one input mode: canonical source JSON fields or individual named values; no implicit default file and no mode mixing, including explicit empty flags.
- Required source fields: RootFolder, SolutionName, ProjectName, Author, Company, Description, Version, PackageId, RepositoryUrl. Validation identifies fields without echoing their values.
- Names are safe dotted .NET identifiers; destination leaf is a portable filename; NuGet package ID follows its portable ASCII character/length constraints; repository URL is absolute HTTPS without credentials; strict SemVer; metadata is nonempty single-line XML-safe text without MSBuild property/item/metadata expansion expressions.
- Preserve embedded editor configuration, gitignore, license/attribution, README/versioning, src solution, library and tests. Add docs placeholder.
- Correct source defects: Company must use Company, solution paths must match src layout, tests must be included in solution, README/license must be packable, test dependency versions must be pinned, and add compilable sample source/test.
- Validate before writing; template renderer failures produce typed scaffold errors with no output. Never overwrite existing destinations. No automatic Git init, dependency restore, build, or network requests during generation.

## Tasks

- [ ] Test common parameter modes and field failures first; implement parser and renderer with literal golden output fixtures.
- [ ] Test service validation/no-write/error mapping and native destination/rollback behavior; implement wrapper around shared writer.
- [ ] Test CLI flags/JSON/access/EN-PT behavior and desktop fields/parameter file/start/result; add route/home and localized messages.
- [ ] Verify a generated solution with real .NET 10 restore/build/test/pack using cached packages; add Windows/Linux CI acceptance coverage.
- [ ] Extend FR-DW-08, UC-54 and BR-DW-08, README and source attribution. Analyze, focused tests, record evidence, commit; root runs full suites before PR.

## Review focus

XML/MSBuild injection and literal placeholder-like metadata, explicit empty mixed-mode fields, Windows reserved names/paths, partial write rollback preserving unrelated content, generated solution test references and package license/readme contents.

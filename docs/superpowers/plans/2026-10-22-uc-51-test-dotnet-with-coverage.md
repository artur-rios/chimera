# UC-51 design and implementation plan

Scope: issue #100 and FR-DW-05; user authorized implementation/testing without
intermediate approval gates. This branch depends on UC-49 shared runner commits;
its separate pull request targets develop and requires a human merge.

Pure core contracts model input, resolved layout, preparation, artifact checks,
and output. Platform extends UC-49 discovery with recursive file discovery and
implements safe output preparation. Both roots are validated before deleting
anything; linked roots are rejected and child links are never followed.
SDK and ReportGenerator checks precede cleanup. No-project discovery is a
successful no-op preserving previous artifacts. Every test must emit all three
requested coverage formats before HTML generation is attempted.

CLI `dotnet test [base] [--json]` and desktop `/dotnet/test` share the workflow,
bounded/redacted native diagnostic stream, and process-tree cancellation. Web
shows an explicit unsupported explanation. EN and PT-BR messages cover outcomes.

Implementation sequence: failing core/workspace/adapter contract tests; shared
service and scoped discovery/cleanup; CLI and desktop adapters; real temporary
xUnit/coverlet/ReportGenerator integration; Windows/Linux CI and focused analyzer.

Verified locally: 19 focused Dart tests, including real xUnit/coverlet and
ReportGenerator execution with all requested formats and an intentional test
failure; 4 affected .NET widget tests; 43 complete catalog tests; focused
fatal-info analysis and dependency boundary checks. CI runs native contracts on
Windows and Linux. Full repository checks and Windows runtime execution remain
required before a human merge.

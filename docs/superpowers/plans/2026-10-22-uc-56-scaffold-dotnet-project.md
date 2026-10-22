# UC-56 Scaffold .NET Project Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver issue #105, minimal or blank-metadata NuGet project creation.
**Architecture:** A pure utilities renderer bundles the pinned net10.0 templates and creates a validated TemplateBundle. Core DotnetProjectService validates names and modes and delegates to the UC47 ScaffoldService/native writer. Desktop and CLI use the same service, web returns unsupported.
**Tech Stack:** Existing Dart, Flutter, args, crypto, SDK XML-independent literal template rendering.
**Spec:** Use Case Specification UC56, FR-DW-10, issue #105.

## Global Constraints
- Native Windows/Linux desktop and CLI, English and Brazilian Portuguese. Offline, new destinations only; partial-output rollback.
- Depends on UC47 shared writer commit 7cfc328. Human merges; stage gates approved for batch.
- Templates pinned at dotnet-tools 7cd0a4867dbbd0301ddb5e6a207fbb0b29c56998, UTF-8 LF output.

## Review Focus
- Device names, traversal, hidden names and XML metacharacters cannot become filenames.
- Both explicit modes must fail before output, default must be minimal.
- NuGet metadata includes empty fixed license/readme elements; placeholders never leak.
- Existing content, writer failures and unsupported targets preserve state.
- Unicode/space parent paths work; real SDK evaluation runs with isolated temp output.

### Task 1: Renderer and service
**Files:** utilities src/dotnet_project_template.dart; core src/dotnet_project_service.dart; CLI src/dotnet_project_command.dart; corresponding tests.
**Interfaces:** DotnetProjectRequest(name, parentDirectory='.', minimal=false, nuget=false); DotnetProjectService(ScaffoldWriter).execute(request) -> Future<ChimeraResult<DotnetProjectOutput>>. Output includes mode, projectPath and scaffold result.
- [ ] Write and run failing CLI tests for default/minimal/NuGet, invalid names/options, conflicts and both locales.
- [ ] Bundle normalized pinned template text; blank NuGet metadata while retaining XML elements; validate names and modes before invoking shared writer.
- [ ] Add isolated real dotnet msbuild project evaluation, golden fixtures and rollback tests; verify focused tests pass.

### Task 2: Desktop integration
**Files:** GUI dotnet_project_page.dart, dotnet_project_runtime*.dart, router.dart; l10n catalog and fixture; widget/integration/browser tests.
- [ ] Add failing EN/PT widget tests for form fields, modes and localized errors.
- [ ] Add accessible form and native/unsupported runtime, route and home action.
- [ ] Run formatting, fatal-info analysis, boundary checks and full test:all; review and prepare a separate develop PR with dependency evidence.

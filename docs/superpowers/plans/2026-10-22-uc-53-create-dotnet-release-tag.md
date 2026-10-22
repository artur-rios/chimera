# UC-53 Create .NET Release Tag Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement task-by-task.

**Goal:** Deliver issue #102, annotated local tags and explicit single-tag pushes.
**Architecture:** DotnetTagService reads project bytes through a native gateway reusing UC52 safe reads and XML-version parsing. It invokes the UC49 owned process runner for Git argument arrays. GUI and CLI are adapters, unsupported web returns a typed result. Recursive discovery matches the tag sources while UC52 bump discovery remains nonrecursive.
**Tech Stack:** Existing Dart/Flutter/args/path; SDK Git installed on native hosts.
**Spec:** UC53, FR-DW-07, GitHub issue #102.

## Global Constraints
- Native Windows/Linux, EN/PT-BR, no forced operations, no implicit remote operation.
- Dependencies UC49 process ownership (a28dd4c + ccf3085) and UC52 XML/read boundary foundation (cfd0040).
- Human merges. User approved batch design/testing gates; temporary Git repositories only in tests.

## Review Focus
- Existing or concurrently created tag refs must remain unchanged.
- Failed/cancelled push must never delete a local tag or claim confirmed remote success.
- Recursive discovery must not follow symlinks/junctions or accept ambiguous projects.
- Git and remote argument injection must be prevented without shell interpolation; credentials stay redacted.
- Cancellation before start and during subprocesses leaves no process tree or signal subscription.

### Task 1: Service and native gateway
**Files:** core src/dotnet_tag_service.dart; platform dotnet_tag.dart; CLI src/dotnet_tag.dart and runner.dart; native/core/CLI tests.
**Interfaces:** DotnetTagService(projects:DotnetTagProjectGateway,runner:NativeCommandRunner).execute(DotnetTagRequest(project?,push=false,remote='origin'),{OperationCancellation?}) -> ChimeraResult<DotnetTagOutput>.
- [ ] Write/run failing CLI tests for recursive discovery, annotations, conflicts, local-only default, failed push, selected local bare remote and only-one-tag publication.
- [ ] Implement semantic version validation, Git checks, annotation and explicit refspec push; reuse shared parsing and owned process runner.
- [ ] Add deterministic cancellation/dependency/validation tests and isolated real Git tests; verify both locales and typed failures.

### Task 2: Desktop and complete verification
**Files:** GUI dotnet_tag_page.dart/runtime*.dart/router.dart; l10n catalog+fixture; widget/native/browser checks; README.
- [ ] Add failing localized widgets, implement accessible fields, opt-in push, local/remote status and cancellation.
- [ ] Format, fatal-info analysis, boundaries, full test:all and independent review.
- [ ] Commit/push and prepare a develop PR that declares UC49/UC52 prerequisites and leaves merge to a human.

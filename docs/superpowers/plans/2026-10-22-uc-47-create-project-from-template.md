# UC-47 Create Project from Template Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver issue #96 with exact offline template output on native desktop and CLI.
**Architecture:** Utilities hold an immutable pinned template snapshot with SHA-256 integrity. A core ScaffoldService validates bundle/destination and delegates to a native writer. The writer reserves a new directory exclusively, tracks ownership and removes partial output safely; GUI and CLI call the same service. Web returns unsupported.
**Tech Stack:** Existing Dart, Flutter, args, crypto, path; native directory reservation via SDK dart:ffi.
**Spec:** docs/requirements/Use Case Specification Document.md, UC-47; GitHub issue #96.

## Global Constraints
- Shared behavior, English and Brazilian Portuguese, offline output, no history retention.
- One use case, branch, issue and PR. Human merges and closes issues. User approved intermediate stage gates for this batch.
- Current baseline is origin/develop 0da06c2.

## Review Focus
- Existing empty directories and symlink destinations must survive conflicts.
- A changed destination during writing must never be removed by rollback.
- Nested dotfiles and zero-byte files must match the snapshot exactly.
- Missing/corrupt template must fail before output is created.
- Spaces and Unicode in native paths must work without shell interpolation.

### Task 1: Shared service and native writer
**Files:** utilities lib/src/project_template.dart; core lib/src/scaffold_service.dart; platform lib/native_scaffolding.dart and lib/src/exclusive_directory.dart; corresponding package tests.
**Interfaces:** ScaffoldService(ScaffoldWriter writer, {TemplateBundle? template}).execute(ScaffoldRequest(destination: path)) returns Future<ChimeraResult<ScaffoldOutput>>. ScaffoldOutput carries destination, templateVersion, createdPaths.
- [ ] Add failing tests for exact snapshot output, invalid/missing bundle, existing paths, nested traversal, injected write failure and rollback ownership. Run focused Dart tests and observe missing feature failures.
- [ ] Implement immutable bundle integrity validation, typed errors and exclusive native creation; verify focused tests pass.

### Task 2: Desktop and CLI adapters
**Files:** CLI src/project_commands.dart and runner.dart; GUI project_template_page.dart, scaffold_runtime*.dart and router.dart; l10n message_catalog.dart; adapter tests.
- [ ] Add failing tests for project from-template arguments/help/JSON/failures in both locales and desktop destination/action/result/unsupported web.
- [ ] Implement `chimera project from-template <destination> [--json]`, native runtime and accessible GUI entry with field and create action.
- [ ] Run focused tests, formatter, fatal-info analysis, boundaries, then full melos test:all with real output retained.
- [ ] Review, commit, push issue branch and prepare a PR targeting develop with evidence and Closes #96.

## Progress
- Specifications imported from issue #96; source snapshot pinned to b4921f53c3fe1c304953ee5a6c4cbef3f0e57635.
- Baseline full suite running in original checkout.

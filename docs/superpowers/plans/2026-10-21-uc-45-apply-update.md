# UC-45 Apply Update Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Download, verify, and apply an explicitly accepted native installer while cleaning temporary data and preserving typed failure behavior.

**Architecture:** `chimera_core` orchestrates approval, staging, download, checksum, installation, and cleanup through ports. `chimera_platform` supplies bounded native adapters. CLI and GUI repeat UC-44 selection and pass the selected metadata only after explicit approval.

**Tech Stack:** Dart 3.13, Flutter, package:http, package:crypto, dart:io, package:test, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-21-uc-45-apply-update-design.md`

**Global Constraints:** No live networking or real process execution in tests. Never install before checksum success. Never download without explicit approval. Always attempt cleanup after staging. Web exposes no update behavior. Portable packages are not self-applied.

### Task 1: Shared apply orchestration

**Files:**
- Modify: `packages/chimera_core/lib/src/update_service.dart`
- Create: `packages/chimera_core/test/update_apply_service_test.dart`

1. Write failing tests for approval/portable gates, happy-path call order, download, checksum, installer and cleanup failures, thrown exceptions, and cleanup-on-every-staged-path.
2. Add typed staging/downloader/verifier/installer ports plus `UpdateApplyRequest`, `UpdateApplyResult`, and `UpdateApplyService`.
3. Map all failures to safe `FailureKind.update` values and run focused core tests.

### Task 2: Native apply adapters

**Files:**
- Modify: `packages/chimera_platform/lib/src/adapters.dart`
- Create: `packages/chimera_platform/lib/src/update_apply_adapters.dart`
- Modify: `packages/chimera_platform/lib/chimera_platform.dart`
- Modify: `packages/chimera_platform/test/adapters_test.dart`
- Create: `packages/chimera_platform/test/update_apply_adapters_test.dart`

1. Write failing tests for unique staging, bounded/abortable HTTPS GitHub download, streamed checksum comparison, fixed Windows/Linux process commands, elevation/nonzero failures, and safe diagnostics.
2. Implement native storage, downloader, verifier, process runner, and installer adapters behind injectable low-level factories.
3. Run platform tests and fatal-info analysis.

### Task 3: CLI apply command

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/update_apply_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

1. Write failing tests proving `--yes` is mandatory and has zero effects when absent, plus success, stable JSON, Portuguese, check failure, and apply failure.
2. Add `update apply` parsing, repeat compatible selection, construct the native apply service only after approval, and render localized output.
3. Run CLI and localization tests.

### Task 4: Native GUI confirmation and apply

**Files:**
- Modify: `apps/chimera_gui/lib/update_page.dart`
- Modify: `apps/chimera_gui/lib/update_runtime.dart`
- Modify: `apps/chimera_gui/lib/update_runtime_native.dart`
- Modify: `apps/chimera_gui/lib/update_runtime_unsupported.dart`
- Modify: `apps/chimera_gui/test/widgets/update_check_test.dart`
- Modify: `apps/chimera_gui/test/web_unsupported_test.dart`

1. Write failing widget tests for explicit confirmation, cancel/no side effects, apply success/failure, loading state, accessibility, both locales, and web absence.
2. Extend the injected page state machine and native runtime composition.
3. Run focused widget/web tests.

### Task 5: Documentation and verification

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/operations/release-artifacts.md`

1. Document explicit approval, checksum verification, platform installer behavior, cleanup, and typed failures.
2. Run formatting, focused core/platform/CLI/GUI/localization tests, fatal-info analysis, update contract tests, dependency boundaries, and the full relevant suite.
3. Review against issue #46 and open a PR targeting `develop` without merging or closing the issue.


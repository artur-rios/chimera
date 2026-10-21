# UC-44 Check for Update Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a safe, native-only update check that identifies the newest compatible GitHub release without downloading or installing it.

**Architecture:** `chimera_core` owns validated release metadata, SemVer precedence, compatibility selection, and the check service. `chimera_platform` supplies an injected GitHub Releases HTTP adapter. CLI and GUI compose those pieces and expose localized current, available, and failure states.

**Tech Stack:** Dart 3.13, Flutter, package:http, args, go_router, package_info_plus, package:test, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-21-uc-44-check-for-update-design.md`

**Global Constraints:** Tests must not use live networking, download artifacts, or invoke an installer. Runtime metadata remains the six-field IR-20 contract. Failures must be safe `FailureKind.update` values. Web must not expose or initialize native update behavior.

**Review Focus:** SemVer correctness, strict metadata validation, no artifact access during checks, stable CLI JSON, native-only GUI composition, localized parity, and safe diagnostics.

### Task 1: Shared release metadata and update check service

**Files:**
- Create: `packages/chimera_core/lib/src/update_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/update_service_test.dart`
- Modify: `tool/validate_release_metadata.dart`
- Modify: `tests/update/release_metadata_test.dart`
- Modify: `pubspec.yaml`

1. Write failing core tests for strict six-field parsing, HTTPS GitHub URLs, SHA-256, SemVer precedence, compatibility filtering, newest selection, current status, and source failure mapping.
2. Run `dart test packages/chimera_core/test/update_service_test.dart` and confirm the expected missing-API failure.
3. Implement `SemanticVersion`, `ReleaseMetadata`, `ReleaseMetadataValidator`, `ReleaseMetadataSource`, `UpdateTarget`, `UpdateCheckResult`, and `UpdateCheckService` in core.
4. Make the tool validator reuse core instead of defining a second contract.
5. Run the focused core and update-contract tests.

### Task 2: GitHub Releases metadata adapter

**Files:**
- Modify: `packages/chimera_platform/lib/src/adapters.dart`
- Create: `packages/chimera_platform/lib/src/github_release_metadata_source.dart`
- Modify: `packages/chimera_platform/lib/chimera_platform.dart`
- Create: `packages/chimera_platform/test/github_release_metadata_source_test.dart`
- Modify: `packages/chimera_platform/test/adapters_test.dart`

1. Write failing tests using an injected HTTP client for latest-release asset discovery, sidecar fetches, no artifact fetch, transport/status/malformed payload failures, and missing metadata assets.
2. Run the focused platform test and confirm the missing adapter failure.
3. Implement `GitHubReleaseMetadataSource` with safe response limits, GitHub media headers, strict JSON shape checks, and typed update failures.
4. Keep download/install ports separate for UC-45 and update the gateway contract test.
5. Run platform tests.

### Task 3: CLI `update check`

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/update_check_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

1. Write failing functional tests for current/available human output, stable JSON, Portuguese output, invalid options, update failure exit 69, and a recording source proving no artifact request.
2. Run the focused CLI test and confirm the command is absent.
3. Add injectable update-check composition to `runChimera`, parse `update check` flags, derive the GitHub endpoint, and render stable localized output.
4. Add English and Brazilian Portuguese catalog keys and retain catalog parity.
5. Run the CLI and localization focused tests.

### Task 4: Native GUI update page

**Files:**
- Create: `apps/chimera_gui/lib/update_page.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Create: `apps/chimera_gui/test/widgets/update_check_test.dart`
- Modify: `apps/chimera_gui/test/web_unsupported_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`

1. Write failing widget tests for native action visibility, current/available/failure states, stale-state clearing, accessibility semantics, both locales, and web absence.
2. Run the focused widget tests and confirm the route/page is absent.
3. Implement an injected `UpdatePage` state machine and native-only route/home action. Compose installed version with `package_info_plus` only on native platforms.
4. Add localized GUI copy and accessible live-region status.
5. Run focused widget/web tests.

### Task 5: Documentation and verification

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/operations/release-artifacts.md`

1. Document the check command, build configuration, metadata selection, and the no-download/no-install guarantee.
2. Run formatting and repository analysis.
3. Run focused update, platform, CLI, GUI, localization, and boundary tests.
4. Run `dart run melos run test:all` and preserve its fresh output for the PR.
5. Review the branch diff against issue #45 and open a PR targeting `develop` without merging or closing the issue.

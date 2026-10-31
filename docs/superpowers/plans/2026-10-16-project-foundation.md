# Chimera Project Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Establish the Flutter/Dart monorepo, shared contracts, application shells, test harnesses, CI/release delivery, and Yggdrasil registration required by issue #1 and IR-01 through IR-28.

**Architecture:** A Melos-managed workspace contains a Flutter GUI and Dart CLI over four shared packages. `chimera_core` owns requests/results/services and redacted diagnostics, `chimera_utilities` owns reusable algorithms, `chimera_platform` owns injectable operating-system boundaries, and `chimera_l10n` owns complete English and Brazilian Portuguese catalogs. Chimera owns build and runtime artifacts; Yggdrasil owns the external catalog and environment-specific Compose overlays.

**Tech Stack:** Flutter 3.47.7 stable, Dart 3.13.5, Melos, flutter_riverpod, go_router, args, intl, logging, shared_preferences, GitHub Actions, Docker/NGINX, Jenkins/Yggdrasil.

**Spec:** `docs/requirements/Operations & Infrastructure Document.md`, `docs/requirements/Technology Stack Document.md`, `docs/requirements/Testing Specification Document.md`, and Chimera issue #1.

## Global Constraints

- Use sound null safety and strict static analysis in every first-party package.
- Utility inputs and outputs, credentials, tokens, keys, certificates, generated identities, and authenticated URLs must never be logged.
- No application database, analytics, behavioral telemetry, cloud synchronization, or remote utility-processing service is permitted.
- Local preference storage is limited to `theme` (`light` or `dark`) and `language` (`en` or `pt-BR`).
- GUI and CLI depend on shared behavior rather than duplicating algorithms.
- All dependencies resolve to stable releases compatible with Flutter 3.47.7 and Dart 3.13.5.
- All user-facing keys exist in both English and Brazilian Portuguese.
- GitHub Actions references are pinned to released major versions and release assets include SHA-256 checksums.
- Yggdrasil remains authoritative for environment order, promotion, rollback, host assignment, secrets, and operational surfaces.

## Review Focus

- Sensitive diagnostic context: attempts to log blocked field names must be redacted and ordinary non-sensitive context retained.
- Localization drift: any missing or extra key in `pt-BR` must fail the catalog parity test.
- Dependency inversion: applications may depend on shared packages, but utilities and core may not depend on GUI, CLI, Flutter, or platform implementations.
- Container disclosure: `/healthz` must return exactly `{\"status\":\"ok\"}` without build, host, or dependency data.
- Release compatibility: metadata must reject unsupported platform, application, package type, insecure URL, malformed version, or missing checksum values.

---

### Task 1: Workspace Contract and Monorepo Skeleton

**Files:**
- Create: `pubspec.yaml`, `melos.yaml`, `analysis_options.yaml`, `.gitignore`
- Create: `test/foundation/workspace_layout_test.dart`
- Create: `apps/chimera_gui/pubspec.yaml`, `apps/chimera_cli/pubspec.yaml`
- Create: `packages/chimera_core/pubspec.yaml`, `packages/chimera_utilities/pubspec.yaml`, `packages/chimera_platform/pubspec.yaml`, `packages/chimera_l10n/pubspec.yaml`
- Create: `tests/fixtures/README.md`, `tests/web/README.md`, `tests/deployment/README.md`, `tests/update/README.md`

**Interfaces:**
- Produces: a Dart pub workspace and Melos scripts `analyze`, `test:unit`, `test:cli`, `test:gui`, `test:web`, `test:deployment`, and `test:all`.

- [x] Write `GivenFoundationSpecification_WhenWorkspaceInspected_ThenRequiredProjectsAndSuitesExist` before the directories and scripts exist.
- [x] Run `dart test test/foundation/workspace_layout_test.dart` and verify the missing paths/scripts fail.
- [x] Add the root workspace, strict analyzer configuration, package manifests, required directories, and Melos script declarations.
- [x] Run `dart pub get`, `dart run melos bootstrap`, and the layout test; verify they pass.
- [x] Commit with `build: scaffold chimera workspace`.

### Task 2: Shared Result, Service, Diagnostic, and Platform Contracts

**Files:**
- Create: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/lib/src/result.dart`
- Create: `packages/chimera_core/lib/src/operation_service.dart`
- Create: `packages/chimera_core/lib/src/diagnostics.dart`
- Create: `packages/chimera_core/test/result_test.dart`
- Create: `packages/chimera_core/test/diagnostics_test.dart`
- Create: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_platform/lib/chimera_platform.dart`
- Create: `packages/chimera_platform/lib/src/adapters.dart`
- Create: `packages/chimera_platform/test/adapters_test.dart`

**Interfaces:**
- Produces: sealed `ChimeraResult<T>`, `ChimeraSuccess<T>`, `ChimeraFailure<T>`, typed `FailureKind`, `OperationService<Request, Output>.execute(Request)`, `DiagnosticEvent`, `DiagnosticSink`, `FileGateway`, `ClipboardGateway`, `PreferenceGateway`, `UpdateGateway`, and `PreferenceKey.theme/language`.

- [x] Write failing Given–When–Then tests for success/failure mapping, diagnostic redaction, and fake implementations of every platform gateway.
- [x] Run the narrow package tests and verify missing types fail compilation.
- [x] Implement the minimal sealed result, service, allowlisted structured diagnostic context, and injectable adapter interfaces.
- [x] Run `dart test` in `chimera_core` and `chimera_platform`; verify all tests pass.
- [x] Commit with `feat: add shared foundation contracts`.

### Task 3: Complete Localization Catalog

**Files:**
- Create: `packages/chimera_l10n/lib/chimera_l10n.dart`
- Create: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Create: `packages/chimera_l10n/test/message_catalog_test.dart`

**Interfaces:**
- Produces: `MessageCatalog.lookup(String localeTag, String key)`, `supportedLocaleTags`, and initial keys `app.name`, `app.description`, `cli.noCommand`, `error.unexpected`.

- [x] Write tests for English lookup, Brazilian Portuguese lookup, invalid locale fallback to English, and exact key parity.
- [x] Run the tests and verify the absent catalog fails.
- [x] Implement immutable catalogs with English fallback and no persistence.
- [x] Run `dart test` for `chimera_l10n`; verify all tests pass.
- [x] Commit with `feat: add bilingual message catalogs`.

### Task 4: CLI and GUI Application Shells

**Files:**
- Create: `apps/chimera_cli/bin/chimera.dart`
- Create: `apps/chimera_cli/lib/chimera_cli.dart`
- Create: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/runner_test.dart`
- Create: generated Flutter platform files under `apps/chimera_gui/` for web, Windows, and Linux only
- Create: `apps/chimera_gui/lib/main.dart`, `apps/chimera_gui/lib/app.dart`, `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/app_test.dart`, `apps/chimera_gui/integration_test/app_test.dart`

**Interfaces:**
- Consumes: shared result, utilities, platform, and localization packages.
- Produces: `Future<int> runChimera(List<String> args, {String localeTag, StringSink out, StringSink err})` and `ChimeraApp` with a `ProviderScope` and `GoRouter` root route.

- [x] Write failing CLI functional tests for localized help/no-command output and zero sensitive stderr data.
- [x] Write failing widget tests for English/Portuguese application labels, keyboard reachability, and semantic heading exposure.
- [x] Implement the minimal CLI parser and Flutter shell using only shared catalogs/contracts.
- [x] Run CLI, widget, and integration narrow suites; verify all pass.
- [x] Commit with `feat: add gui and cli application shells`.

### Task 5: Architecture, Privacy, Release Metadata, and Performance Contracts

**Files:**
- Create: `tool/check_boundaries.dart`
- Create: `tool/validate_release_metadata.dart`
- Create: `test/foundation/dependency_boundaries_test.dart`
- Create: `tests/update/release_metadata_test.dart`
- Create: `tests/update/fixtures/release-metadata.json`
- Create: `tests/performance/acceptance_thresholds.json`
- Create: `tests/performance/foundation_benchmark_test.dart`
- Create: `docs/operations/availability.md`, `docs/operations/accessibility-review.md`

**Interfaces:**
- Produces: a dependency/privacy guard and validated release metadata fields `releaseVersion`, `platform`, `application`, `packageType`, `downloadUrl`, and `checksum`.

- [x] Write failing tests for forbidden dependency directions, database/analytics dependencies, every invalid release-metadata enum/URL/checksum, and committed performance thresholds.
- [x] Run the narrow tests and verify the missing validators fail.
- [x] Implement the guards, metadata validator, 99.5% monthly production availability objective, Yggdrasil status measurement contract, manual accessibility evidence template, and foundation performance limits.
- [x] Run the boundary, update, and performance tests; verify all pass.
- [x] Commit with `test: enforce foundation contracts`.

### Task 6: Web Container and Deployment Smoke Contract

**Files:**
- Create: `deploy/web/Dockerfile`, `deploy/web/nginx.conf`
- Create: `tests/deployment/container_contract_test.dart`
- Create: `tool/smoke_container.ps1`, `tool/smoke_container.sh`

**Interfaces:**
- Produces: port `8080`, public `/healthz` returning exactly `{\"status\":\"ok\"}`, immutable Flutter assets, non-root NGINX runtime, and no secret build arguments.

- [x] Write failing static contract tests for the health payload, non-root runtime, environment-specific labels, and absence of secret-bearing build arguments.
- [x] Run the narrow deployment test and verify missing files fail.
- [x] Implement the pinned Flutter build stage, unprivileged NGINX runtime, health route, SPA fallback, and cross-platform runtime smoke scripts.
- [x] Build and run the image locally; verify `/healthz` returns the exact contract and contains no extra fields.
- [x] Commit with `build: add web container runtime`.

### Task 7: CI, Branch Policy, Packaging, and Release Workflows

**Files:**
- Create: `.github/workflows/branch-policy.yml`
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release-artifacts.yml`
- Create: `tool/package_windows.ps1`, `tool/package_linux.sh`, `tool/write_checksums.dart`
- Create: `test/foundation/workflow_contract_test.dart`
- Create: `CHANGELOG.md`, `CONTRIBUTING.md`, `Jenkinsfile`

**Interfaces:**
- Produces required PR checks `Analyze and test`, `Cross-platform`, `Container`, and `Accessibility and performance`; Playwright engine coverage plus native Safari WebDriver coverage; portable and installer artifacts for GUI/CLI on Windows/Linux; SHA-256 files; release metadata; and `yggdrasilPipeline(stack: 'chimera')`.

- [x] Write failing workflow contract tests for triggers, stable check names, browser matrix (`chromium`, `firefox`, `webkit`, and native Safari), Windows/Linux native matrix, analyze-before-package ordering, checksums, evidence uploads, and branch-policy rules.
- [x] Run the workflow contract test and verify missing workflows fail.
- [x] Add the branch-policy workflow, CI matrix, package scripts, release workflow, contributing rules, changelog, and Jenkins entrypoint.
- [x] Run workflow contract tests plus PowerShell/Bash packaging dry runs against fixture directories; verify artifact names and checksums.
- [x] Commit with `ci: add build and release pipelines`.

### Task 8: Register Chimera in Yggdrasil

**Files (repository `artur-rios/yggdrasil`):**
- Modify: `catalog.yaml`
- Modify: `scripts/test_catalog.py`
- Create: `stacks/chimera.yml`, `stacks/chimera.proxy.yml`, `stacks/chimera.ports.yml`

**Interfaces:**
- Consumes: Chimera check names, Dockerfile, health path, and Jenkins application id.
- Produces: system/application id `chimera`, kind `web`, health `http://chimera:8080/healthz`, host `chimera`, service `web`, and local/development/homologation/production promotion coverage.

- [x] Add a failing catalog test asserting Chimera’s system, required checks, health contract, container service, and four resolved environments.
- [x] Run `python -m unittest scripts.test_catalog` and verify Chimera is absent.
- [x] Add the catalog entry and hardened Compose base/proxy/ports overlays; do not add secrets or environment values to the repository.
- [x] Run `python scripts/catalog.py validate`, `python scripts/catalog.py plan chimera`, and the full Yggdrasil test suite; verify all pass.
- [x] Commit, push, open a PR into Yggdrasil `develop`, wait for green CI, squash-merge it, and delete the branch.

### Task 9: Documentation, Full Verification, and Chimera Pull Request

**Files:**
- Modify: `README.md`
- Create: `docs/operations/release-artifacts.md`
- Update: `docs/superpowers/plans/2026-10-16-project-foundation.md` checkboxes

**Interfaces:**
- Consumes: all previous tasks.
- Produces: clean-clone bootstrap/test instructions and IR-01–IR-28 evidence mapping.

- [x] Update README status, installation, testing, architecture, container, and release instructions; mark issue #1 tracking complete on the branch.
- [x] Run formatting, `dart run melos bootstrap`, `dart run melos analyze`, and every named suite individually.
- [x] Run unfiltered `dart run melos run test:all` and read the complete output.
- [x] Run GUI web/Windows builds, CLI native compilation, Docker health smoke, and `git diff --check`.
- [ ] Push `feature/project-scaffold`, open a PR to `develop` with `Closes #1`, and wait for every required check.
- [ ] Squash-merge the green PR, delete the branch, move issue #1 to Done, close it, sync `develop`, and verify a clean tree.

## Self-Review Result

- IR-01–IR-09 map to Tasks 1–6.
- IR-10 and IR-16–IR-19 map to Tasks 6 and 8.
- IR-11–IR-15 and IR-20–IR-25 map to Tasks 5–7.
- IR-26–IR-28 map to Tasks 7–8.
- The foundation issue has no numbered alternative flows; every cited IR exists in the Operations document.
- Every implementation slice begins with a failing behavioral or contract test and ends with a narrow verification before the full suite.

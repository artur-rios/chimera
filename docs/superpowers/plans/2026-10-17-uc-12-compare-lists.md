# UC-12 Compare Lists Implementation Plan

> Execute this plan task by task with test-first changes and a reviewable commit
> after each green layer.

**Goal:** Deliver deterministic line-list comparison and normalization through
the shared utility, core service, CLI, GUI, native, and browser surfaces for
issue #13.

**Architecture:** `chimera_utilities` owns line parsing, normalization, and
stable multiset/set comparison; `chimera_core` owns result/failure mapping; CLI
and GUI remain thin local adapters. No input, result, or history persistence and
no processing network path are added.

**Tech Stack:** Dart 3.11, Flutter 3.41, args, Riverpod, go_router, file_picker,
package:test, flutter_test, integration_test, and Playwright.

---

### Task 1: Add the shared list comparator

**Files:**
- Create: `packages/chimera_utilities/lib/src/list_compare/list_comparator.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/list_compare/list_comparator_test.dart`

- [x] Add failing Given-When-Then tests for stable four-set output, line endings,
  empty/blank/Unicode values, every option combination, invalid options, and
  budgets.
- [x] Implement the smallest deterministic comparator and typed failures.
- [x] Run the focused utility test and strict package analysis.
- [x] Commit the green shared behavior.

### Task 2: Add the core operation service

**Files:**
- Create: `packages/chimera_core/lib/src/list_compare_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/list_compare_service_test.dart`

- [x] Add failing service tests for stable success JSON, redacted validation,
  and resource mapping.
- [x] Implement the operation request, output serialization, and service mapping.
- [x] Run focused core tests and strict package analysis.
- [x] Commit the green core layer.

### Task 3: Add the CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

- [x] Add failing command tests for literal/stdin/file sources, every option,
  human/JSON output, exact output files, conflicting sources, access failures,
  resource exit, localization, and redaction.
- [x] Add `chimera list compare` and its English/Portuguese messages.
- [x] Run CLI/localization suites and strict affected-package analysis.
- [x] Commit the green CLI adapter.

### Task 4: Add the GUI route and interactions

**Files:**
- Create: `apps/chimera_gui/lib/list_compare_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`

- [x] Add failing widget tests for navigation, comparison/options, file and
  clipboard adapters on both sides, copy/save, AF-01/AF-02 cleanup, stale
  clearing, busy-state races, localization, accessibility, and responsive layout.
- [x] Implement the route and injected local adapters.
- [x] Run widget tests and Flutter analysis.
- [x] Commit the green GUI layer.

### Task 5: Extend native and compiled-browser flows

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

- [x] Add a representative list-comparison flow to Windows/Linux integration.
- [x] Add a local-only comparison flow to Chromium, Firefox, and WebKit tests.
- [x] Add the bounded equivalent to native Safari smoke.
- [x] Run affected integration/browser suites and fix evidence-backed defects.
- [x] Commit the green cross-platform evidence.

### Task 6: Gate verification and delivery

**Files:**
- Review: all UC-12 changes and requirement traceability.

- [ ] Run formatting and strict static analysis.
- [ ] Run focused suites, affected native/browser suites, then unfiltered
  `melos run test:all`.
- [ ] Verify main flow, AF-01, AF-02, every cited FR/BR, both locales, offline
  behavior, and no persistence/network path.
- [ ] Obtain independent whole-branch review and resolve every blocker with
  affected-suite reruns.
- [ ] Commit, push, open the issue-closing PR to `develop`, require green CI,
  squash merge, delete the branch, verify Done/closed state, and sync `develop`.

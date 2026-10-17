# UC-10 Escape Text Implementation Plan

> Execute this plan task by task with test-first changes and a reviewable commit
> after each green layer.

**Goal:** Deliver deterministic text escaping in five modes through the shared
utility, core service, CLI, GUI, native, and browser surfaces for issue #11.

**Architecture:** `chimera_utilities` owns escaping and typed algorithm
failures; `chimera_core` owns application-result mapping; CLI and GUI remain
thin local adapters. No source or result persistence or network path is added.

**Tech Stack:** Dart 3.11, Flutter 3.41, args, Riverpod, go_router, file_picker,
package:test, flutter_test, integration_test, and Playwright.

---

### Task 1: Add the shared text escaper

**Files:**
- Create: `packages/chimera_utilities/lib/src/text_escape/text_escaper.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/text_escape/text_escaper_test.dart`

- [x] Add failing Given-When-Then tests for every canonical mode, empty and
  Unicode boundaries, unsupported modes, budgets, and no partial output.
- [x] Implement the smallest deterministic escaper and typed failures.
- [x] Run the focused utility test and strict package analysis.
- [x] Commit the green shared behavior.

### Task 2: Add the core operation service

**Files:**
- Create: `packages/chimera_core/lib/src/text_escape_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/text_escape_service_test.dart`

- [x] Add failing service tests for success, validation details, and resource
  mapping.
- [x] Implement the request, output serialization, and service mapping.
- [x] Run focused core tests and strict package analysis.
- [x] Commit the green core layer.

### Task 3: Add the CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

- [x] Add failing command tests for argument/stdin/file input, every mode,
  human/JSON output, exact output files, invalid options, access failures,
  resource exit, localization, and redaction.
- [x] Add `chimera text escape` and its English/Portuguese messages.
- [x] Run CLI and localization suites plus strict affected-package analysis.
- [x] Commit the green CLI adapter.

### Task 4: Add the GUI route and interactions

**Files:**
- Create: `apps/chimera_gui/lib/text_escape_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`

- [x] Add failing widget tests for navigation, main flow, all modes, file and
  clipboard input, copy/save, AF-01/AF-02, stale-result clearing, busy-state
  races, localization, accessibility, and responsive layout.
- [x] Implement the route and injected local adapters.
- [x] Run widget tests and Flutter analysis.
- [x] Commit the green GUI layer.

### Task 5: Extend native and compiled-browser flows

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

- [ ] Add the representative escape flow to Windows/Linux native integration.
- [ ] Add a local-only escape flow to Chromium, Firefox, and WebKit tests.
- [ ] Add the bounded equivalent to native Safari smoke.
- [ ] Run affected integration/browser suites and fix evidence-backed defects.
- [ ] Commit the green cross-platform evidence.

### Task 6: Gate verification and delivery

**Files:**
- Review: all UC-10 changes and requirement traceability.

- [ ] Run formatting and strict static analysis.
- [ ] Run focused suites, affected native/browser suites, then `melos run test:all` unfiltered.
- [ ] Verify the main flow, AF-01, AF-02, every cited FR/BR, both locales, offline behavior, and no persistence/network path.
- [ ] Obtain independent whole-branch review and resolve every blocker with affected-suite reruns.
- [ ] Commit, push, open the issue-closing PR to `develop`, require green CI, squash merge, delete the branch, verify Done/closed state, and sync `develop`.


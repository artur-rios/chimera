# UC-13 Analyze Text Implementation Plan

> Execute this plan task by task with test-first changes and a reviewable commit
> after each green layer.

**Goal:** Deliver deterministic Unicode-aware text statistics through the shared
utility, core service, CLI, GUI, native, and browser surfaces for issue #14.

**Architecture:** `chimera_utilities` owns grapheme, word, line, and UTF-8 byte
counting; `chimera_core` owns result/failure mapping; CLI and GUI remain thin
local adapters. No input, result, or history persistence and no processing
network path are added.

**Tech Stack:** Dart 3.11, Flutter 3.41, characters, args, Riverpod, go_router,
file_picker, package:test, flutter_test, integration_test, and Playwright.

---

### Task 1: Add the shared text analyzer

**Files:**
- Create: `packages/chimera_utilities/lib/src/text_analyze/text_analyzer.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Modify: `packages/chimera_utilities/pubspec.yaml`
- Create: `packages/chimera_utilities/test/text_analyze/text_analyzer_test.dart`

- [x] Add failing Given-When-Then tests for ASCII, empty/Unicode boundaries,
  grapheme clusters, multilingual words, punctuation/apostrophes, line endings,
  UTF-8 bytes, and budgets.
- [x] Implement the smallest deterministic analyzer and typed resource failure.
- [x] Run the focused utility test and strict package analysis.
- [x] Commit the green shared behavior.

### Task 2: Add the core operation service

**Files:**
- Create: `packages/chimera_core/lib/src/text_analyze_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/text_analyze_service_test.dart`

- [ ] Add failing service tests for stable success JSON and redacted resource
  mapping.
- [ ] Implement the operation request, output serialization, and service mapping.
- [ ] Run focused core tests and strict package analysis.
- [ ] Commit the green core layer.

### Task 3: Add the CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

- [ ] Add failing command tests for literal/stdin/file input, human/JSON output,
  exact output files, conflicting sources, access failures, resource exit,
  localization, and redaction.
- [ ] Add `chimera text analyze` and its English/Portuguese messages.
- [ ] Run CLI/localization suites and strict affected-package analysis.
- [ ] Commit the green CLI adapter.

### Task 4: Add the GUI route and interactions

**Files:**
- Create: `apps/chimera_gui/lib/text_analyze_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`

- [ ] Add failing widget tests for navigation, Unicode counts, file/clipboard
  input, copy/save, AF-01/AF-02 cleanup, stale clearing, busy-state races,
  localization, accessibility, and responsive layout.
- [ ] Implement the route and injected local adapters.
- [ ] Run widget tests and Flutter analysis.
- [ ] Commit the green GUI layer.

### Task 5: Extend native and compiled-browser flows

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

- [ ] Add a representative text-analysis flow to Windows/Linux integration.
- [ ] Add a local-only analysis flow to Chromium, Firefox, and WebKit tests.
- [ ] Add the bounded equivalent to native Safari smoke.
- [ ] Run affected integration/browser suites and fix evidence-backed defects.
- [ ] Commit the green cross-platform evidence.

### Task 6: Gate verification and delivery

**Files:**
- Review: all UC-13 changes and requirement traceability.

- [ ] Run formatting and strict static analysis.
- [ ] Run focused suites, affected native/browser suites, then unfiltered
  `melos run test:all`.
- [ ] Verify main flow, AF-01, AF-02, every cited FR/BR, both locales, offline
  behavior, and no persistence/network path.
- [ ] Obtain independent whole-branch review and resolve every blocker with
  affected-suite reruns.
- [ ] Commit, push, open the issue-closing PR to `develop`, require green CI,
  squash merge, delete the branch, verify Done/closed state, and sync `develop`.

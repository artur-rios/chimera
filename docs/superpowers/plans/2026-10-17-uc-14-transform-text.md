# UC-14 Transform Text Implementation Plan

> Execute this plan task by task with test-first changes and a reviewable commit
> after each green layer.

**Goal:** Deliver deterministic single-mode text transformation through the
shared utility, core service, CLI, GUI, native, and browser surfaces for issue
#15.

**Architecture:** `chimera_utilities` owns mode parsing and transformation;
`chimera_core` owns result/failure mapping; CLI and GUI remain thin local
adapters. No input, result, or history persistence and no processing network
path are added.

**Tech Stack:** Dart 3.13, Flutter 3.47.7, args, Riverpod, go_router,
file_picker, package:test, flutter_test, integration_test, and Playwright.

---

### Task 1: Add the shared text transformer

**Files:**
- Create: `packages/chimera_utilities/lib/src/text_transform/text_transformer.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/text_transform/text_transformer_test.dart`

- [ ] Add failing Given-When-Then tests for every mode, the Unicode 15.1
  White_Space set and exclusions, non-ASCII case expansion, UTF-16 sort order,
  mixed line boundaries, empty/blank/trailing lines, invalid modes, and exact
  input/output resource budgets.
- [ ] Implement the smallest deterministic transformer with typed validation
  and resource failures.
- [ ] Run focused utility tests and strict package analysis.
- [ ] Commit the green shared behavior.

### Task 2: Add the core operation service

**Files:**
- Create: `packages/chimera_core/lib/src/text_transform_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/text_transform_service_test.dart`

- [ ] Add failing service tests for stable success JSON and redacted
  validation/resource failures without partial output.
- [ ] Implement the request, output serialization, and failure mapping.
- [ ] Run focused core tests and strict package analysis.
- [ ] Commit the green core layer.

### Task 3: Add the CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

- [ ] Add failing command tests for literal/stdin/file input, modes,
  human/JSON output, exact output files, missing/invalid modes, conflicting
  explicit input sources, access/resource failures, localization, and redaction.
- [ ] Add `chimera text transform` and English/Portuguese messages.
- [ ] Run CLI/localization suites and strict affected-package analysis.
- [ ] Commit the green CLI adapter.

### Task 4: Add the GUI route and interactions

**Files:**
- Create: `apps/chimera_gui/lib/text_transform_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`

- [ ] Add failing widget tests for navigation, all modes, file/clipboard input,
  copy/save, validation/resource and AF-02 cleanup, stale clearing, busy races,
  localization, accessibility, and responsive layout.
- [ ] Implement the route and injected local adapters.
- [ ] Run widget tests and Flutter analysis.
- [ ] Commit the green GUI layer.

### Task 5: Extend native and compiled-browser flows

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

- [ ] Add a representative transform flow to Windows/Linux integration.
- [ ] Add a local-only transform flow to Chromium, Firefox, and WebKit tests.
- [ ] Add the bounded equivalent to native Safari smoke.
- [ ] Run affected integration/browser suites and fix evidence-backed defects.
- [ ] Commit the green cross-platform evidence.

### Task 6: Gate verification and delivery

**Files:**
- Review: all UC-14 changes and requirement traceability.

- [ ] Run formatting and strict static analysis.
- [ ] Run focused suites, affected native/browser suites, then unfiltered
  `melos run test:all`.
- [ ] Verify main flow, AF-01, AF-02, every cited FR/BR, both locales, offline
  behavior, and no persistence/network path.
- [ ] Obtain independent whole-branch review and resolve every blocker with
  affected-suite reruns.
- [ ] Under the user's explicit unattended self-merging batch authorization,
  commit, push, open the issue-closing PR to `develop`, require green CI, squash
  merge, delete the branch, move the issue to Done, verify closed state, and
  sync `develop`.

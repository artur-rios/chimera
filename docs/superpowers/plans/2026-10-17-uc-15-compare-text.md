# UC-15 Compare Text Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver deterministic line-, word-, and grapheme-level text comparison
through the shared utility, core service, CLI, GUI, native, and browser surfaces
for issue #16.

**Architecture:** `chimera_utilities` owns tokenization and diff construction;
`chimera_core` owns stable serialization and failure mapping; CLI and GUI remain
thin local adapters. No operation data persistence or processing network path is
added.

**Tech Stack:** Dart 3.13, Flutter 3.47.7, `diff_match_patch` 0.4.1,
`characters` 1.4.1, args, Riverpod, go_router, file_picker, package:test,
flutter_test, integration_test, and Playwright.

**Spec:** `docs/superpowers/plans/2026-10-17-uc-15-compare-text-design.md`

## Global Constraints

- Stable granularities are exactly `line`, `word`, and `character`.
- Diffs are deterministic across VM and web: timeout is disabled, token symbols
  use only non-surrogate UTF-16 code units, and adjacent equal kinds coalesce.
- Validation runs before input reads or resource work and diagnostics never
  contain source text or partial spans.
- All utility work stays local/offline and operation data is never persisted.
- English and Brazilian Portuguese are complete for every new user-facing key.
- Tests use Given-When-Then names and cover the main flow, AF-01, and AF-02.

## Review Focus

- Mixed CRLF, CR, and LF compare as the same logical line boundaries while a
  terminal boundary remains observable.
- Unicode whitespace grouping is identical on Dart VM and compiled web, with
  U+200B and U+FEFF retained as word content.
- Grapheme comparison never splits combining sequences, surrogate pairs, or emoji
  ZWJ sequences.
- Invalid options and source conflicts fail before file/stdin adapters read
  potentially sensitive input.
- Every resource failure exposes no spans, partial text, or sensitive diagnostic
  values at exact budget boundaries.

---

### Task 1: Add the shared text comparer

**Files:**
- Modify: `packages/chimera_utilities/pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `packages/chimera_utilities/lib/src/text_compare/text_comparer.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/text_compare/text_comparer_test.dart`

**Interfaces:**
- Produces: `TextCompareGranularity`, `TextDiffKind`, `TextDiffSpan`,
  `TextCompareSummary`, `TextCompareResult`, `TextCompareException`, and
  `TextComparer.compare({left, right, granularity})`.

- [x] Add failing Given-When-Then tests for all granularities, stable ordered
  spans/counts, mixed boundaries, Unicode whitespace exclusions, graphemes,
  empty/equal inputs, invalid granularity, and exact resource budgets.
- [x] Run the focused test and verify failure because the API is absent.
- [x] Add `diff_match_patch` 0.4.1 and implement the smallest deterministic
  token encoder, diff adapter, span coalescer, and typed failures.
- [x] Run focused utility tests and strict package analysis until green.
- [x] Commit the shared behavior.

### Task 2: Add the core operation service

**Files:**
- Create: `packages/chimera_core/lib/src/text_compare_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/text_compare_service_test.dart`

**Interfaces:**
- Consumes: Task 1's public comparer contract.
- Produces: `TextCompareOperationRequest`, `TextCompareOutput.toJson()`, and
  `TextCompareService.execute()`.

- [x] Add failing service tests for the exact stable JSON object and redacted
  validation/resource failure mapping without partial output.
- [x] Run the focused service test and verify the missing API failure.
- [x] Implement request/output types and utility-to-core result mapping.
- [x] Run focused core tests and strict package analysis until green.
- [x] Commit the core layer.

### Task 3: Add the CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

**Interfaces:**
- Consumes: Task 2's service and JSON contract.
- Produces: `chimera text compare` with paired literal/file/stdin sources,
  `--granularity`, `--json`, and `--output`.

- [x] Add failing CLI/catalog tests for every source type, all granularities,
  exact human/JSON/file payloads, both locales, validation-before-read, access
  failures, resource exit 75, source conflicts/shared stdin, and redaction.
- [x] Run focused CLI/catalog tests and verify missing-command/key failures.
- [x] Implement parser registration, source validation/read helpers, stable human
  formatting, localized messages, output writing, and exit mappings.
- [x] Run CLI/localization suites and strict affected-package analysis until
  green.
- [x] Commit the CLI adapter.

### Task 4: Add the GUI route and interactions

**Files:**
- Create: `apps/chimera_gui/lib/text_compare_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`

**Interfaces:**
- Consumes: Task 2's service/result contract and Task 3's catalog keys.
- Produces: `/text/compare`, dual local file/clipboard loaders, accessible span
  preview, and exact JSON copy/save actions.

- [x] Add failing widget tests for navigation, three granularities, both input
  adapters, exact JSON copy/save, validation/resource and access cleanup, stale
  clearing, busy races, EN/PT-BR, semantics, and narrow layout.
- [x] Run focused widget tests and verify missing route/page failures.
- [x] Implement the dual-input local-only page and register its home action and
  route dependencies.
- [x] Run widget tests and Flutter analysis until green.
- [x] Commit the GUI layer.

### Task 5: Extend native and compiled-browser flows

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

**Interfaces:**
- Consumes: Task 4's visible labels, semantics, and route.
- Produces: representative native and browser evidence for the same service path.

- [ ] Add a failing representative text-comparison flow to Windows/Linux
  integration tests.
- [ ] Add a failing local-only flow to Chromium, Firefox, and WebKit tests.
- [ ] Add the bounded equivalent to native Safari smoke.
- [ ] Run affected native/browser suites and fix only evidence-backed defects.
- [ ] Commit the cross-platform evidence.

### Task 6: Gate verification and delivery

**Files:**
- Review: all UC-15 changes and requirement traceability.

- [ ] Run repository formatting and strict static analysis.
- [ ] Run focused suites, affected native/browser suites, then unfiltered
  `dart run melos run test:all`.
- [ ] Verify main flow, AF-01, AF-02, every cited FR/BR, both locales, offline
  behavior, redaction, and no persistence/network path.
- [ ] Obtain independent whole-branch review and resolve every blocker with
  affected-suite reruns.
- [ ] Under the user's explicit unattended self-merging batch authorization,
  commit, push, open the issue-closing PR to `develop`, require green CI, squash
  merge, delete the branch, move the issue to Done, verify closed state, and
  sync `develop`.


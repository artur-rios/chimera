# UC-09 Convert Number Base Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver arbitrary-precision base conversion through Chimera's shared utility, CLI, and GUI.

**Architecture:** A pure-Dart converter validates and converts signed integers with `BigInt`; a core service maps its typed failures; CLI and Flutter adapters provide local I/O and presentation without duplicating conversion logic.

**Tech Stack:** Dart 3/Flutter, project-owned sealed results, `args`, `go_router`, Flutter widget/integration tests, Playwright/WebDriver browser smokes.

**Spec:** `docs/superpowers/plans/2026-10-17-uc-09-convert-number-base-design.md`

## Global Constraints

- Bases are integers from 2 through 36 inclusive.
- Conversion uses arbitrary-precision integers and performs no network I/O.
- Validation and resource failures are typed and never return partial output.
- Shared behavior lives in reusable Dart packages and is consumed by GUI and CLI.
- User-facing copy is complete in English and Brazilian Portuguese.
- Tests use Given-When-Then names and run through the unfiltered repository suite.

## Review Focus

- Sign-only and separated values must fail; leading/trailing whitespace is trimmed, embedded whitespace fails, and prefix-looking text is interpreted only as ordinary digits for the selected base; utility tests own these cases.
- Uppercase input digits must parse case-insensitively while output remains canonical lowercase; utility tests own this case.
- `-0`, `+000`, and leading zeroes must normalize predictably; utility tests own these cases.
- Values wider than 64 bits must round-trip without precision loss; utility and CLI tests own this case.
- Output expansion (for example base 36 to base 2) must trip the output budget without returning a result; utility and core tests own this case.

---

### Task 1: Shared conversion contract

**Files:**
- Create: `packages/chimera_utilities/lib/src/number_base/number_base_converter.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Test: `packages/chimera_utilities/test/number_base/number_base_converter_test.dart`

**Interfaces:**
- Produces: `NumberBaseRequest({required String value, required int sourceBase, required int targetBase})`; `NumberBaseResult({required String converted, required int sourceBase, required int targetBase})`; `NumberBaseException({required NumberBaseFailureKind kind, required String code, String? field, String? reason})`; and `NumberBaseConverter({int? maxInputCharacters, int? maxOutputCharacters}).convert(NumberBaseRequest) -> NumberBaseResult`.

- [x] Write failing known-answer, canonicalization, invalid-base/digit, review-focus, arbitrary-precision, and budget tests. Include bases 2/36; negative and same-base canonicalization; uppercase input/lowercase output; `0x10` rejection in base 16 and ordinary-digit acceptance in base 36; raw leading/trailing versus embedded whitespace; raw surrounding whitespace that exceeds the input budget; and each injected limit exactly at and one character beyond its boundary.
- [x] Run the focused utility test and confirm the expected missing-API failure.
- [x] Implement validation in the documented precedence, `BigInt` conversion, canonical result, nullable platform budgets, allocation-bounded output when configured, and `OutOfMemoryError` resource mapping.
- [x] Run the focused utility test until all cases pass.

### Task 2: Core service and typed failures

**Files:**
- Create: `packages/chimera_core/lib/src/number_base_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Test: `packages/chimera_core/test/number_base_service_test.dart`

**Interfaces:**
- Consumes: `NumberBaseConverter.convert(NumberBaseRequest)`.
- Produces: `NumberBaseOperationRequest({required String value, required int sourceBase, required int targetBase})`; `NumberBaseOutput(NumberBaseResult result)` with `toJson() -> {'converted', 'sourceBase', 'targetBase'}`; and `NumberBaseService({NumberBaseConverter converter = const NumberBaseConverter()}).execute(NumberBaseOperationRequest) -> Future<ChimeraResult<NumberBaseOutput>>`.

- [x] Write failing service tests for success, surrounding-whitespace normalization, AF-01 details, and AF-02 resource mapping.
- [x] Run the focused core test and confirm the expected missing-API failure.
- [x] Implement the service and shared-result mapping without exposing source input in failure details.
- [x] Run the focused core test until all cases pass.

### Task 3: CLI adapter

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Test: `apps/chimera_cli/test/functional/runner_test.dart`
- Test: `packages/chimera_l10n/test/message_catalog_test.dart`

**Interfaces:**
- Consumes: `NumberBaseService.execute(NumberBaseOperationRequest)`.
- Produces: `chimera number convert-base --from <2..36> --to <2..36>` with mutually exclusive `--input`/`--file` (stdin fallback), optional `--output`, `--json`, human/JSON output, and stable exit codes.

- [ ] Write failing CLI tests for direct and arbitrary-precision success, stdin/file input, JSON, localized human output, AF-01, AF-02, conflicting input, and access failures. Pin missing, non-integer, and out-of-range `--from`/`--to` diagnostics in source-before-target precedence.
- [ ] Add failing localization parity assertions for all new English and Brazilian Portuguese keys.
- [ ] Implement parser dispatch, runner behavior, output cleanup, and localized messages.
- [ ] Run CLI and localization tests until all cases pass.

### Task 4: Flutter route and page

**Files:**
- Create: `apps/chimera_gui/lib/number_base_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Test: `apps/chimera_gui/test/widgets/app_test.dart`

**Interfaces:**
- Consumes: `NumberBaseService`, local file/clipboard adapters, and message-catalog keys.
- Produces: `/number/convert-base` and an accessible localized input/result workflow.

- [ ] Write failing widget tests for routing, main flow, Portuguese copy, invalid input, resource failure, file/paste, copy/save failures, keyboard semantics, and stale-result clearing. Select and propagate boundary bases 2 and 36 in addition to the default 10-to-16 flow.
- [ ] Implement the page, adapters, dependency injection, route, and home action.
- [ ] Run the widget suite until all cases pass.

### Task 5: Full-flow and cross-platform evidence

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

**Interfaces:**
- Consumes: the public GUI route and accessible controls.

- [ ] Add failing native integration and Playwright flows using a nontrivial conversion and no-external-request assertion.
- [ ] Add a bounded Safari workflow smoke using values SafariDriver can enter reliably.
- [ ] Run the affected integration/browser suites and fix only product or harness defects supported by evidence.

### Task 6: Gate verification and delivery

**Files:**
- Review: all UC-09 changes and README tracking behavior.

- [ ] Run formatting and strict static analysis.
- [ ] Run focused suites, affected native/browser suites, then `melos run test:all` unfiltered.
- [ ] Verify the main flow, AF-01, AF-02, every cited FR/BR, both locales, offline behavior, and no persistence/network path.
- [ ] Obtain independent whole-branch review and resolve every blocker with affected-suite reruns.
- [ ] Commit, push, open the issue-closing PR to `develop`, require green CI, squash merge, delete the branch, verify Done/closed state, and sync `develop`.

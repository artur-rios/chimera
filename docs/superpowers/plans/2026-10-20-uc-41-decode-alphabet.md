# UC-41 Decode Alphabet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strictly decode Morse, ICAO/NATO radiotelephony words, or
uncontracted UEB Braille through shared CLI and GUI surfaces while exposing the
exact published mapping used.

**Architecture:** Add a pure decoder beside the existing alphabet encoder in
`chimera_utilities`; map adapter data through a redacted service in
`chimera_core`; then add localized CLI, Flutter, native, and browser adapters.
The decoder is the only implementation of grammar and mapping behavior.

**Tech Stack:** Dart 3.11+, Flutter 3.47+, Melos workspace, `package:test`,
Flutter widget/integration tests, Playwright, and Safari WebDriver.

**Spec:**
`docs/superpowers/specs/2026-10-20-uc-41-decode-alphabet-design.md`

## Global Constraints

- Implement UC-41, FR-CA-06 through FR-CA-08, FR-PL-01 through FR-PL-06,
  FR-PL-09 through FR-PL-11, BR-01 through BR-05, BR-15, BR-19, and issue #42.
- Use the exact canonical grammars, mappings, state transitions, metadata, and
  non-goals in the approved design.
- Process source and output locally and ephemerally; never log, retain as
  history, or transmit them.
- Complete every user-facing path in English and Brazilian Portuguese.
- Use typed redacted failures and documented CLI exit codes 64, 70, 74, and 75.
- Keep web, Windows, Linux, and CLI behavior aligned and run Flutter commands
  serially.

## Review Focus

- Reject non-canonical token spacing and report Unicode-scalar positions rather
  than UTF-16 offsets; covered in Tasks 1 and 2.
- Invert every UC-40 result, including every space/line break and UEB numeric,
  capital, and grade-1 transition; covered in Task 1.
- Reject orphaned or contradictory UEB indicators without leaking partial
  output; covered in Tasks 1 through 5.
- Keep mapping descriptors identical and immutable across encode/decode paths;
  covered in Tasks 1 through 3.
- Prevent late file/clipboard/copy/save completions from restoring discarded
  state; covered in Task 4.
- Include the decoded result in assistive semantics so native Safari and all
  other supported targets can observe exact output; covered in Tasks 4 and 5.

---

### Task 1: Add the shared strict decoder

**Files:**
- Modify: `docs/reference/alphabet-rules.md`
- Create: `packages/chimera_utilities/lib/src/alphabet/alphabet_decoder.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/alphabet/alphabet_decoder_test.dart`

**Interfaces:**
- Produces: `AlphabetDecodeRequest`, `AlphabetDecodeResult`, and
  `AlphabetDecoder.decode(...)` while reusing the existing alphabet contracts.

- [ ] **Step 1: Write failing unit tests.** Cover full inverse tables,
  round-trips, exact token grammar, NATO ASCII case folding, empty input,
  spaces, CR/LF, every valid UEB transition, malformed Unicode, unknown and
  ambiguous sequences, scalar positions, output limits, and allocation errors.
- [ ] **Step 2: Run the focused utility test.** Expected: FAIL because the
  decoder API does not exist.
- [ ] **Step 3: Implement the decoder, exports, and reference rules.** Keep
  token parsing scalar-aware and UEB state explicit.
- [ ] **Step 4: Run focused and full utility suites.** Expected: PASS.
- [ ] **Step 5: Commit `feat: add alphabet decoding`.**

### Task 2: Add the redacted core decoding service

**Files:**
- Create: `packages/chimera_core/lib/src/alphabet_decode_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/alphabet_decode_service_test.dart`

**Interfaces:**
- Consumes: `AlphabetDecoder.decode(AlphabetDecodeRequest)` from Task 1.
- Produces: `AlphabetDecodeOperationRequest`, `AlphabetDecodeOutput`, and
  `AlphabetDecodeService.execute(...)` returning `ChimeraResult`.

- [ ] **Step 1: Write failing service tests.** Cover text, immutable UTF-8
  bytes, stable JSON and mapping metadata, unknown alphabet, invalid UTF-8,
  ambiguous input positions, resource failures, unexpected errors, and
  redaction.
- [ ] **Step 2: Run the focused core test.** Expected: FAIL because the service
  API does not exist.
- [ ] **Step 3: Implement and export the service.** Parse only adapter values,
  invoke the shared decoder, and map safe failures without source data.
- [ ] **Step 4: Run focused core and utility suites.** Expected: PASS.
- [ ] **Step 5: Commit `feat: add alphabet decode service`.**

### Task 3: Add localized CLI decoding

**Files:**
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/alphabet_decode_test.dart`

**Interfaces:**
- Consumes: `AlphabetDecodeService` and its stable result/failure contract.
- Produces: `chimera alphabet decode` for argument, stdin, and UTF-8 file
  input, mapping-aware human/JSON output, and optional atomic output files.

- [ ] **Step 1: Write failing localization and CLI tests.** Cover both locales,
  help, all alphabets, every source, mapping output, AF-01, AF-02, JSON, exit
  codes 64/70/74/75, transactional output, and redaction.
- [ ] **Step 2: Run focused localization and CLI tests.** Expected: FAIL because
  the command and message keys do not exist.
- [ ] **Step 3: Implement the localized CLI command.** Reuse established source,
  output, JSON, and transactional file conventions.
- [ ] **Step 4: Run focused localization and CLI suites.** Expected: PASS.
- [ ] **Step 5: Commit `feat: add alphabet decode cli`.**

### Task 4: Add localized GUI decoding and native coverage

**Files:**
- Create: `apps/chimera_gui/lib/alphabet_decode_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/alphabet_decode_test.dart`
- Create: `apps/chimera_gui/integration_test/alphabet_decode_test.dart`

**Interfaces:**
- Consumes: `AlphabetDecodeService`, mapping metadata, localization, and the
  existing local file/clipboard/save adapter conventions.
- Produces: `/alphabet/decode`, home navigation, selection, exact result and
  mapping semantics, copy, and save.

- [ ] **Step 1: Write failing widget tests.** Cover both locales, all mappings,
  text/file/clipboard, AF-01, AF-02, exact copy/save, adapter failures,
  invalidation, stale completions, disposal, keyboard order, 200% text,
  accessibility, and 48-pixel targets.
- [ ] **Step 2: Run the focused widget test.** Expected: FAIL because the route
  and page do not exist.
- [ ] **Step 3: Implement the page, dependencies, route, and home action.** Clear
  source immediately after request construction and guard all async completions.
- [ ] **Step 4: Write and run native integration tests.** Cover both locales,
  known output plus mapping, discard, AF-01, AF-02, and zero network attempts.
- [ ] **Step 5: Run focused GUI suites serially.** Expected: PASS.
- [ ] **Step 6: Commit `feat: add alphabet decode interface`.**

### Task 5: Add browser coverage, verify, review, and deliver

**Files:**
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

**Interfaces:**
- Consumes: `/alphabet/decode` and stable result/mapping semantics.
- Produces: representative Chromium, Firefox, WebKit, Safari, native, and
  accessibility evidence for main and alternative flows.

- [ ] **Step 1: Add browser and Safari journeys.** Assert known output,
  mapping, ambiguity failure, output-access behavior where supported, semantic
  output, and no unexpected network requests.
- [ ] **Step 2: Run focused browser checks.** Expected: PASS.
- [ ] **Step 3: Update accessibility evidence and run formatting, fatal
  analysis, boundaries, focused/full suites, browser matrix, deployment,
  performance, and `dart run melos run test:all`.** Expected: all PASS.
- [ ] **Step 4: Obtain a fresh whole-branch review.** Resolve every Critical or
  Important finding with RED-to-GREEN regression evidence.
- [ ] **Step 5: Push, open an issue-closing PR to `develop`, require every CI
  check green, merge without bypassing protection, delete the branch, move #42
  to Done, verify closure, and sync `develop`.

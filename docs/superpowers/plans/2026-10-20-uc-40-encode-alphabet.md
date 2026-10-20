# UC-40 Encode with Alphabet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encode ephemeral text as Morse, ICAO/NATO radiotelephony words, or
uncontracted UEB Braille through shared CLI and GUI surfaces while exposing the
exact published mapping used.

**Architecture:** Add reusable alphabet contracts, immutable mapping metadata,
and a pure encoder in `chimera_utilities`; map adapter data through a redacted
service in `chimera_core`; and expose thin localized CLI and Flutter adapters.
The encoder is the only implementation of mapping behavior on every target.

**Tech Stack:** Dart 3.11+, Flutter 3.41+, Melos workspace, `package:test`,
Flutter widget/integration tests, Playwright, and Safari WebDriver.

**Spec:**
`docs/superpowers/specs/2026-10-20-uc-40-encode-alphabet-design.md`

## Global Constraints

- Implement UC-40, FR-CA-05, FR-CA-07 through FR-CA-08, FR-PL-01 through
  FR-PL-06, FR-PL-09 through FR-PL-11, BR-01 through BR-05, BR-15, BR-19,
  and issue #41.
- Use the exact standards, symbol sets, separators, case rules, numeric rules,
  mapping metadata, and non-goals in the approved design.
- Process source and output locally and ephemerally; never log, persist as
  history, or transmit them.
- Keep behavior consistent across web, Windows, Linux, and CLI surfaces.
- Complete every user-facing path in English and Brazilian Portuguese.
- Use typed redacted failures and documented CLI exit codes 64, 70, 74, and 75.
- Run Flutter commands serially.

## Review Focus

- Supplementary-plane failures must report Unicode-scalar rather than UTF-16
  positions; covered in Tasks 1 and 2.
- Mapping descriptors and their nested collections must be immutable and must
  exactly identify the standards used; covered in Tasks 1 through 3.
- Tokenized Morse/NATO output must preserve every space and CR/LF boundary
  without phantom separators; covered in Task 1.
- Braille numeric mode and following letters must be unambiguous for UC-41;
  covered with mixed letter/digit known answers in Task 1.
- Late file/clipboard/copy/save completions must not restore discarded source or
  results; covered in Task 4.
- Failures and diagnostics must not contain source text, rejected symbols, or
  partial output; covered in Tasks 2 through 5.

---

### Task 1: Add published mappings and the shared encoder

**Files:**
- Create: `docs/reference/alphabet-rules.md`
- Create: `packages/chimera_utilities/lib/src/alphabet/alphabet_codec.dart`
- Create: `packages/chimera_utilities/lib/src/alphabet/alphabet_encoder.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/alphabet/alphabet_encoder_test.dart`

**Interfaces:**
- Produces: `AlphabetKind`, `AlphabetFailureKind`, `AlphabetException`,
  `AlphabetMapping`, `AlphabetEncodeRequest`, `AlphabetEncodeResult`, and
  `AlphabetEncoder.encode(...)`.

- [ ] **Step 1: Write failing unit tests.** Cover full tables, mapping metadata
  and immutability, known answers for all three alphabets, empty input, spaces,
  CR/LF, case, every digit, Braille numeric transitions, malformed Unicode,
  unsupported scalar positions, bounded output, and allocation failures.
- [ ] **Step 2: Run the focused utility test.** Expected: FAIL because the
  alphabet encoder API does not exist.
- [ ] **Step 3: Implement the contracts, mappings, encoder, exports, and rules.**
  Keep token joining scalar-aware and Braille numeric/capital state explicit.
- [ ] **Step 4: Run the focused utility and all utility tests.** Expected: PASS.
- [ ] **Step 5: Commit `feat: add alphabet encoding`.**

### Task 2: Add the redacted core encoding service

**Files:**
- Create: `packages/chimera_core/lib/src/alphabet_encode_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/alphabet_encode_service_test.dart`

**Interfaces:**
- Consumes: `AlphabetEncoder.encode(AlphabetEncodeRequest)` from Task 1.
- Produces: `AlphabetEncodeOperationRequest`, `AlphabetEncodeOutput`, and
  `AlphabetEncodeService.execute(...)` returning `ChimeraResult`.

- [ ] **Step 1: Write failing service tests.** Cover text, immutable UTF-8 bytes,
  stable JSON with exact mapping metadata, unknown alphabet, malformed UTF-8,
  unsupported scalar location, resource failures, unexpected processing errors,
  and redaction.
- [ ] **Step 2: Run the focused core test.** Expected: FAIL because the service
  API does not exist.
- [ ] **Step 3: Implement the service and export.** Parse only adapter-level
  values, call the shared encoder, and map safe failures without source data.
- [ ] **Step 4: Run focused core and utility suites.** Expected: PASS.
- [ ] **Step 5: Commit `feat: add alphabet encode service`.**

### Task 3: Add localized CLI encoding

**Files:**
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/alphabet_encode_test.dart`

**Interfaces:**
- Consumes: `AlphabetEncodeService` and its stable output/failure contract.
- Produces: `chimera alphabet encode` for argument, stdin, and UTF-8 file input,
  with mapping-aware human/JSON output and optional atomic output files.

- [ ] **Step 1: Write failing localization and CLI tests.** Cover both locales,
  help, all alphabets, all sources, mapping output, AF-01, AF-02, JSON, exit
  codes 64/70/74/75, transactional output failures, and redaction.
- [ ] **Step 2: Run focused localization and CLI tests.** Expected: FAIL because
  the command and message keys do not exist.
- [ ] **Step 3: Implement the localized CLI command.** Reuse existing source,
  output, JSON, and transactional file adapter conventions.
- [ ] **Step 4: Run focused localization and CLI suites.** Expected: PASS.
- [ ] **Step 5: Commit `feat: add alphabet encode CLI`.**

### Task 4: Add localized GUI encoding and native coverage

**Files:**
- Create: `apps/chimera_gui/lib/alphabet_encode_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/alphabet_encode_test.dart`
- Create: `apps/chimera_gui/integration_test/alphabet_encode_test.dart`

**Interfaces:**
- Consumes: `AlphabetEncodeService`, mapping metadata, localized catalog keys,
  and existing local file/clipboard/save adapter conventions.
- Produces: `/alphabet/encode`, home navigation, alphabet selection, result and
  exact mapping regions, copy, and save.

- [ ] **Step 1: Write failing widget tests.** Cover both locales, selection,
  mapping display, text/file/clipboard, AF-01, AF-02, exact copy/save, adapter
  failures, invalidation, stale completions, disposal, keyboard order, 200% text,
  accessibility, and 48-pixel targets.
- [ ] **Step 2: Run the focused widget test.** Expected: FAIL because the route
  and page do not exist.
- [ ] **Step 3: Implement the page, app dependencies, router entry, and home
  action.** Clear source immediately after request construction and guard every
  async completion with an operation generation.
- [ ] **Step 4: Write and run native integration tests.** Cover both locales,
  known output plus mapping, discard, AF-01, AF-02, and zero network attempts.
- [ ] **Step 5: Run focused GUI suites serially.** Expected: PASS.
- [ ] **Step 6: Commit `feat: add alphabet encode interface`.**

### Task 5: Add browser coverage, verify, review, and deliver

**Files:**
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

**Interfaces:**
- Consumes: `/alphabet/encode` and stable result/mapping semantics from Task 4.
- Produces: representative Chromium, Firefox, WebKit, and Safari evidence for
  the main flow, both alternative flows, accessibility, and offline behavior.

- [ ] **Step 1: Add browser and Safari journeys.** Assert known Morse/NATO/UEB
  output and mapping metadata, unsupported-symbol failure, output-access
  behavior where supported, and no unexpected network requests.
- [ ] **Step 2: Run focused browser checks.** Expected: PASS after the route from
  Task 4 is complete.
- [ ] **Step 3: Update accessibility evidence and run format, fatal analysis,
  boundary checks, focused/full native suites, browser matrix, deployment,
  performance, and `dart run melos run test:all`.** Expected: all PASS.
- [ ] **Step 4: Obtain a fresh whole-branch review.** Resolve every Critical or
  Important finding with RED-to-GREEN regression evidence.
- [ ] **Step 5: Push, open an issue-closing PR to `develop`, require every CI
  check green, merge without bypassing protection, delete the branch, move #41
  to Done, verify closure, and sync `develop`.

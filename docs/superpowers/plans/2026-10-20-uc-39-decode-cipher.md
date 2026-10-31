# UC-39 Decode with Cipher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decode ephemeral text with every approved classical cipher through
the shared CLI and GUI surfaces.

**Architecture:** Add a pure typed decoder beside the existing encoder in
`chimera_utilities`, map adapter data through a redacted service in
`chimera_core`, and expose thin localized CLI and Flutter adapters. Reuse the
existing cipher algorithm, parameter, character-policy, and failure contracts
so every surface observes one decoding implementation.

**Tech Stack:** Dart 3.11+, Flutter 3.41+, Melos workspace, `package:test`,
Flutter widget/integration tests, Playwright, and Safari WebDriver.

**Spec:**
`docs/superpowers/specs/2026-10-20-uc-39-decode-cipher-design.md`

## Global Constraints

- Implement UC-39, FR-CA-02 through FR-CA-04, FR-CA-08, FR-PL-01 through
  FR-PL-06, FR-PL-09 through FR-PL-11, BR-01 through BR-05, BR-14, BR-15,
  BR-19, and issue #40.
- Process all input, output, and key material locally and ephemerally; never log,
  persist as history, or transmit it.
- Keep behavior consistent across web, Windows, Linux, and CLI surfaces.
- Complete every user-facing path in English and Brazilian Portuguese.
- Use the shared ASCII-letter cipher rules in `docs/reference/cipher-rules.md`.
- Use typed redacted failures and documented CLI exit codes 64, 70, 74, and 75.
- Run Flutter commands serially.

## Review Focus

- Bacon input with partial, mixed-case, or out-of-range groups must fail without
  partial plaintext; covered in Task 1 decoder tests.
- Rail Fence with a rail count at least as large as its letter count must be a
  no-op without rail-proportional allocation; covered in Task 1 decoder tests.
- Unsupported supplementary-plane symbols must report Unicode-scalar rather
  than UTF-16 positions; covered in Tasks 1 and 2.
- Late file/clipboard/copy/save completions must not restore discarded input,
  parameters, or results; covered in Task 4 widget tests.
- Keys and input must not appear in human output, JSON failures, diagnostics, or
  semantics; covered in Tasks 2 through 5.

---

### Task 1: Add inverse rules and the shared decoder

**Files:**
- Modify: `docs/reference/cipher-rules.md`
- Create: `packages/chimera_utilities/lib/src/cipher/cipher_decoder.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/cipher/cipher_decoder_test.dart`

**Interfaces:**
- Consumes: `CipherAlgorithm`, `CipherCharacterPolicy`, `CipherFailureKind`, and
  `CipherException` from the existing cipher contract.
- Produces: `CipherDecodeRequest`, `CipherDecodeResult`, and
  `CipherDecoder.decode(CipherDecodeRequest)`.

- [ ] **Step 1: Write failing decoder tests.** Add known inverse answers for all
  seven ciphers, encode/decode round trips, case, empty input, preserved Unicode,
  reject-policy scalar positions, invalid parameters, malformed Unicode, Bacon
  ambiguity, bounded output, and huge Rail Fence keys.
- [ ] **Step 2: Run `dart test packages/chimera_utilities/test/cipher/cipher_decoder_test.dart`.**
  Expected: FAIL because the decoder API does not exist.
- [ ] **Step 3: Implement the decoder and extend the published inverse rules.**
  Use backward rotation/subtraction, modular inverse for Affine, strict five-bit
  Bacon groups, and row-count reconstruction for Rail Fence.
- [ ] **Step 4: Run the decoder and encoder suites.** Expected: both PASS with no
  encoder regression.
- [ ] **Step 5: Commit `feat: add classical cipher decoding`.**

### Task 2: Add redacted core decoding service

**Files:**
- Create: `packages/chimera_core/lib/src/cipher_decode_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/cipher_decode_service_test.dart`

**Interfaces:**
- Consumes: `CipherDecoder.decode(CipherDecodeRequest)` from Task 1.
- Produces: `CipherDecodeOperationRequest`, `CipherDecodeOutput`, and
  `CipherDecodeService.execute(...)` returning `ChimeraResult`.

- [ ] **Step 1: Write failing service tests.** Cover text and immutable UTF-8
  bytes, stable JSON, unknown cipher/policy, malformed integers/UTF-8, AF-02
  scalar location, resource errors, unexpected processing errors, and redaction.
- [ ] **Step 2: Run `dart test packages/chimera_core/test/cipher_decode_service_test.dart`.**
  Expected: FAIL because the service API does not exist.
- [ ] **Step 3: Implement the service.** Parse raw adapter values, call only the
  shared decoder, and map validation/resource/processing failures without input,
  symbol, key, or implementation diagnostics.
- [ ] **Step 4: Run focused core and utility suites.** Expected: PASS.
- [ ] **Step 5: Commit `feat: add cipher decode service`.**

### Task 3: Add localized CLI decoding

**Files:**
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/cipher_decode_test.dart`

**Interfaces:**
- Consumes: `CipherDecodeService` and its stable output/failure contract.
- Produces: `chimera cipher decode` for argument, stdin, and UTF-8 file input,
  with human/JSON stdout and optional atomic output files.

- [ ] **Step 1: Write failing localization and CLI tests.** Cover both locales,
  help, every cipher, all three sources, preserve/reject, AF-01, AF-02, JSON,
  exit codes 64/70/74/75, output replacement/cleanup failures, and redaction.
- [ ] **Step 2: Run focused localization and CLI tests.** Expected: FAIL because
  the decode command and message keys do not exist.
- [ ] **Step 3: Implement the localized command.** Mirror the encode adapter's
  option validation and transactional output behavior while invoking only the
  decode service.
- [ ] **Step 4: Run focused localization and CLI suites.** Expected: PASS.
- [ ] **Step 5: Commit `feat: add cipher decode CLI`.**

### Task 4: Add localized GUI decoding and native coverage

**Files:**
- Create: `apps/chimera_gui/lib/cipher_decode_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/cipher_decode_test.dart`
- Create: `apps/chimera_gui/integration_test/cipher_decode_test.dart`

**Interfaces:**
- Consumes: `CipherDecodeService`, localized catalog keys, and existing local
  file/clipboard/save adapter conventions.
- Produces: `/cipher/decode`, the home action, conditional parameter controls,
  typed result/error semantics, copy, and save.

- [ ] **Step 1: Write failing widget tests.** Cover both locales, conditional
  controls, text/file/clipboard, AF-01, AF-02, exact copy/save, adapter failures,
  invalidation, stale completions, disposal, keyboard order, 200% text,
  accessibility, and 48-pixel targets.
- [ ] **Step 2: Run the focused widget test.** Expected: FAIL because the route
  and page do not exist.
- [ ] **Step 3: Implement the page, app dependencies, router entry, and home
  action.** Clear source and parameter controllers immediately after request
  construction and guard all async completions with an operation generation.
- [ ] **Step 4: Write and run native integration tests.** Cover both locales,
  exact local transfer, discard, AF-01, AF-02, and zero network attempts.
- [ ] **Step 5: Run focused GUI suites serially.** Expected: PASS.
- [ ] **Step 6: Commit `feat: add cipher decode interface`.**

### Task 5: Add browser coverage, verify, review, and deliver

**Files:**
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

**Interfaces:**
- Consumes: `/cipher/decode` and its stable keys/semantics from Task 4.
- Produces: representative Chromium, Firefox, WebKit, and Safari evidence for
  the main flow, AF-01, AF-02, accessibility, and offline behavior.

- [ ] **Step 1: Add failing browser and Safari journeys.** Use WebDriver-safe
  fixtures, assert known plaintext, invalid-key and unsupported-symbol failures,
  and reject unexpected network requests.
- [ ] **Step 2: Run focused browser checks.** Expected: PASS after the route from
  Task 4 is available and the new journeys are complete.
- [ ] **Step 3: Update accessibility evidence and run format, fatal analysis,
  boundary checks, and `dart run melos run test:all`.** Expected: all PASS.
- [ ] **Step 4: Obtain a fresh whole-branch review.** Resolve every Critical or
  Important finding with RED-to-GREEN regression evidence.
- [ ] **Step 5: Push, open an issue-closing PR to `develop`, require every CI
  check green, merge without bypassing protection, delete the branch, move #40
  to Done, verify closure, and sync `develop`.

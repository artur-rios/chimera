# UC-38 Encode with Cipher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encode ephemeral text with every approved classical cipher through
the shared CLI and GUI surfaces.

**Architecture:** Add pure typed encoding in `chimera_utilities`, redacted
request/result mapping in `chimera_core`, then thin localized CLI and Flutter
adapters. Shared cipher and character-policy enums are intentionally reusable
by UC-39, while this issue implements encoding only.

**Spec:**
`docs/superpowers/specs/2026-10-20-uc-38-encode-cipher-design.md`, UC-38,
FR-CA-01, FR-CA-03-FR-CA-04, FR-CA-08, FR-PL-01-FR-PL-06,
FR-PL-09-FR-PL-11, BR-01-BR-05, BR-14-BR-15, BR-19, issue #39

### Task 1: Add reference rules, shared encoder, and service

**Files:**
- Create: `docs/reference/cipher-rules.md`
- Create: `packages/chimera_utilities/lib/src/cipher/cipher_encoder.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/cipher/cipher_encoder_test.dart`
- Create: `packages/chimera_core/lib/src/cipher_encode_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/cipher_encode_service_test.dart`

- [ ] Write failing known-answer tests for Caesar, ROT13, Vigenere, Atbash,
  Affine, Bacon, and Rail Fence; case, empty input, preserve/reject policy,
  Unicode-scalar error positions, parameter boundaries, stray parameters,
  large rail keys, immutable results, and redacted service failures.
- [ ] Implement the smallest shared model, validator, encoder, and service that
  pass those tests.
- [ ] Run both focused suites and retain RED/GREEN evidence.

### Task 2: Add localized CLI behavior

**Files:**
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/cipher_encode_test.dart`

- [ ] Write failing tests for help, argument/stdin/file input, every cipher,
  both policies, human/JSON output, both interface locales, every typed failure
  and exit code, stray arguments, atomic output files, output failures, and
  redacted key/input diagnostics.
- [ ] Add `chimera cipher encode` through the shared service without echoing
  keys in output or errors.
- [ ] Run focused localization and CLI suites.

### Task 3: Add localized GUI route and lifecycle

**Files:**
- Create: `apps/chimera_gui/lib/cipher_encode_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/cipher_encode_test.dart`
- Create: `apps/chimera_gui/test/adapters/cipher_encode_save_test.dart`

- [ ] Write failing widget/adapter tests for all conditional controls, each
  source, validation and unsupported-symbol position, exact copy/save,
  cancellation and access failures, localization, accessibility, keyboard,
  responsive layout, re-entry prevention, invalidation, and disposal.
- [ ] Implement the page, home entry, result semantics, and ephemeral lifecycle.
- [ ] Run focused GUI suites serially.

### Task 4: Add native and browser full-flow coverage

**Files:**
- Create: `apps/chimera_gui/integration_test/cipher_encode_test.dart`
- Create: `tests/web/cipher_encode_browser.js`
- Create: `tests/web/cipher_encode.spec.mjs`
- Modify: `tests/web/playwright.config.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

- [ ] Cover representative known answers for every cipher, both policies,
  English and Brazilian Portuguese, AF-01, AF-02, exact transfer, state discard,
  responsive/keyboard semantics, and offline/no-network behavior.
- [ ] Run affected native, widget, browser, and Safari suites.

### Task 5: Verify, review, and deliver issue #39

- [ ] Run formatting, fatal analysis, boundary checks, and
  `dart run melos run test:all`.
- [ ] Obtain independent review and resolve every Critical or Important finding.
- [ ] Push, open an issue-closing PR to `develop`, require all CI green, squash
  merge, delete the branch, mark #39 Done, verify closure, and sync `develop`.

# UC-35 Generate Credit Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate ephemeral, clearly labeled synthetic Visa, Mastercard, American Express, or Discover card numbers from a locally bundled catalogue of published sandbox PANs, validating network structure and Luhn checksums before returning the requested positive count.

**Architecture:** Add a pure card generator in `chimera_utilities` whose production candidate source selects only exact PANs published for sandbox testing, with an injectable source for deterministic tests and bounded replacement of rejected candidates. Map raw adapter values and redacted typed failures in `chimera_core`; expose the same service through CLI and Flutter GUI adapters; verify native and compiled-web behavior offline.

**Tech Stack:** Dart 3.13.5, Flutter, package:test, flutter_test, args, go_router, Playwright, WebDriver

**Spec:** `docs/requirements/Use Case Specification Document.md` (UC-35), FR-GE-08, FR-GE-10, FR-GE-13, FR-PL-01-FR-PL-06, FR-PL-09-FR-PL-11, BR-01-BR-05, BR-10-BR-11, BR-19, GitHub issue #36

## Global Constraints

- Support only Visa, Mastercard, American Express, and Discover.
- Production output must come only from the exact, documented test PAN catalogue; never synthesize a PAN in a live issuer range.
- Validate every candidate against its requested network, documented length/prefix structure, and Luhn checksum before accepting it.
- Retry rejected candidates only within a fixed attempt bound and return one typed processing failure with no partial values if a valid replacement cannot be obtained.
- Validate a positive decimal count before consulting the candidate source; impose no product-specific ceiling beyond platform resource constraints.
- Label every result as synthetic test data in human, JSON, and GUI output.
- Keep requests/results out of diagnostics, persistence, history, and retained UI state after configuration changes or route disposal.
- Preserve stable transactional file output, English and Brazilian Portuguese localization, keyboard access, and offline behavior.
- Source catalogue values from the Visa Checkout sandbox guide and Stripe's published test-card documentation, recording URLs and access date in `docs/reference/card-test-data.md`.

## Review Focus

- No generated value may be mistaken for an unlabeled real account number or escape the published sandbox catalogue.
- Network/prefix/length and Luhn validation must be independent of candidate selection and must reject a mismatched or malformed injected candidate.
- Candidate-source, allocation, validation exhaustion, serialization, stdout, copy, and save failures must be redacted and atomic.
- GUI/CLI adapters must call the shared service rather than implement card selection, validation, or labeling themselves.

---

### Task 1: Add the shared card generator, catalogue documentation, and service

**Files:**
- Create: `docs/reference/card-test-data.md`
- Create: `packages/chimera_utilities/lib/src/card/card_generator.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/card/card_generator_test.dart`
- Create: `packages/chimera_core/lib/src/card_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/card_service_test.dart`

- [ ] Write failing tests for every network, exact catalogue membership, prefix/length/Luhn checks, exact count, validation before dependencies, bounded invalid-candidate replacement, exhaustion, source/allocation failures, immutability, and redacted typed service failures.
- [ ] Document the exact sandbox PAN catalogue and implement the smallest generator and service that pass those tests.
- [ ] Run the two focused suites and retain RED/GREEN evidence.

### Task 2: Add localized CLI behavior

**Files:**
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/card_generate_test.dart`

- [ ] Write failing tests for help, defaults, every network, count, human and JSON labels, localized validation/processing failures, stray arguments, transactional output, stdout/serialization failures, exit codes, and PAN-free diagnostics.
- [ ] Add `chimera card generate` using the shared service and established output boundaries.
- [ ] Run the focused localization and CLI suites.

### Task 3: Add the localized GUI route and state lifecycle

**Files:**
- Create: `apps/chimera_gui/lib/card_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/card_test.dart`
- Create: `apps/chimera_gui/test/adapters/card_save_test.dart`

- [ ] Write failing widget/adapter tests for both locales, every network, validation, processing, visible synthetic labeling, copy/save, cancellation, accessibility, keyboard submission, re-entry prevention, and stale completion/disposal.
- [ ] Implement the route, home entry, form, result semantics, copy/save actions, and ephemeral-state invalidation.
- [ ] Run the focused GUI suites.

### Task 4: Add native and browser full-flow coverage

**Files:**
- Create: `apps/chimera_gui/integration_test/card_generate_test.dart`
- Create: `tests/web/card_browser.js`
- Create: `tests/web/card.spec.mjs`
- Modify: `tests/web/playwright.config.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

- [ ] Cover every network, multi-value copy/save exactness, visible synthetic labeling, validation and processing boundaries, state discard, both locales where applicable, and zero unexpected network requests.
- [ ] Add the route to the browser matrix and Safari smoke workflow.
- [ ] Run affected native, widget, and web suites.

### Task 5: Verify, review, and deliver issue #36

- [ ] Run formatting, analysis, boundary checks, and `dart run melos run test:all`.
- [ ] Obtain independent code review and resolve every Critical or Important finding.
- [ ] Commit, push, open an issue-closing PR to `develop`, require all CI checks green, squash merge, delete the branch, move issue #36 to Done, verify closure, and sync `develop`.

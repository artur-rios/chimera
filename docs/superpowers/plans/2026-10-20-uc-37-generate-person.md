# UC-37 Generate Person Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate ephemeral, clearly labeled, internally consistent synthetic
US and Brazilian people through the shared CLI and GUI surfaces.

**Architecture:** Add pure aggregate generation and validation in
`chimera_utilities`, typed mapping in `chimera_core`, then thin localized CLI
and Flutter adapters. Candidate sources and the operation date are injectable,
validation is independent, document validation reuses UC-36, retry is bounded,
and each batch is atomic.

**Spec:**
`docs/superpowers/specs/2026-10-20-uc-37-generate-person-design.md`, UC-37,
FR-GE-09-FR-GE-13, FR-PL-01-FR-PL-06, FR-PL-09-FR-PL-11,
BR-01-BR-05, BR-10-BR-13, BR-19, issue #38

### Task 1: Add references, shared person generator, and service

**Files:**
- Create: `docs/reference/person-generation-rules.md`
- Create: `packages/chimera_utilities/lib/src/person/person_generator.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/person/person_generator_test.dart`
- Create: `packages/chimera_core/lib/src/person_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/person_service_test.dart`

- [ ] Write failing tests for both locales, exact age boundaries, leap dates,
  every field and cross-field invariant, matching identifiers, defaults,
  malformed/range/order/count validation, retry/exhaustion, source failures,
  allocation failures, immutability, labels, and redacted service mapping.
- [ ] Implement the smallest shared generator, validator, result model, and
  service that pass those tests while reusing UC-36 document validation.
- [ ] Run both focused suites and retain RED/GREEN evidence.

### Task 2: Add localized CLI behavior

**Files:**
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/person_generate_test.dart`

- [ ] Write failing tests for help/defaults, both person locales, age
  constraints, human/JSON labels, both interface locales, every typed failure
  and exit code, stray arguments, atomic output files, output failures, and
  redacted diagnostics.
- [ ] Add `chimera person generate` through the shared service.
- [ ] Run focused localization and CLI suites.

### Task 3: Add localized GUI route and lifecycle

**Files:**
- Create: `apps/chimera_gui/lib/person_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/person_test.dart`
- Create: `apps/chimera_gui/test/adapters/person_save_test.dart`

- [ ] Write failing widget/adapter tests for locale and age controls,
  validation, exhaustion, warning, exact copy/save, cancellation,
  accessibility, keyboard, responsive layout, re-entry prevention, and stale
  completion/disposal.
- [ ] Implement the page, home entry, result semantics, and ephemeral lifecycle.
- [ ] Run focused GUI suites serially.

### Task 4: Add native and browser full-flow coverage

**Files:**
- Create: `apps/chimera_gui/integration_test/person_generate_test.dart`
- Create: `tests/web/person_browser.js`
- Create: `tests/web/person.spec.mjs`
- Modify: `tests/web/playwright.config.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

- [ ] Cover representative US/BR people, age constraints, cross-field
  consistency, multi-person exact transfer, both locales, AF-01, AF-02, state
  discard, and offline/no-network behavior.
- [ ] Run affected native, widget, browser, and Safari suites.

### Task 5: Verify, review, and deliver issue #38

- [ ] Run formatting, fatal analysis, boundary checks, and
  `dart run melos run test:all`.
- [ ] Obtain independent review and resolve every Critical or Important finding.
- [ ] Push, open an issue-closing PR to `develop`, require all CI green, squash
  merge, delete the branch, mark #38 Done, verify closure, and sync `develop`.

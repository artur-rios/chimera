# UC-36 Generate Identity Document Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate ephemeral, clearly labeled, structurally valid synthetic US
and Brazilian identity-document values through the shared CLI and GUI surfaces.

**Architecture:** Add pure generation/validation in `chimera_utilities`, typed
mapping in `chimera_core`, then thin localized CLI and Flutter adapters. Candidate
sources are injectable, validation is independent, retry is bounded, and each
batch is atomic.

**Spec:** `docs/superpowers/specs/2026-10-20-uc-36-generate-identity-document-design.md`,
UC-36, FR-GE-09-FR-GE-10, FR-GE-13, FR-PL-01-FR-PL-06,
FR-PL-09-FR-PL-11, BR-01-BR-05, BR-10-BR-13, BR-19, issue #37

### Task 1: Add standards references, shared validators/generators, and service

**Files:**
- Create: `docs/reference/identity-document-rules.md`
- Create: `packages/chimera_utilities/lib/src/identity_document/identity_document_generator.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/identity_document/identity_document_generator_test.dart`
- Create: `packages/chimera_core/lib/src/identity_document_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/identity_document_service_test.dart`

- [ ] Write failing tests for all types, formats, official known answers,
  checksum mutations, locale/type mismatches, RG ambiguity, count validation,
  validation before dependencies, bounded replacement/exhaustion, allocation and
  candidate-source failures, immutability, labels, and redacted service mapping.
- [ ] Implement the smallest shared generator, validators, result model, and
  service that pass those tests.
- [ ] Run both focused suites and retain RED/GREEN evidence.

### Task 2: Add localized CLI behavior

**Files:**
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/identity_document_generate_test.dart`

- [ ] Write failing tests for help/defaults, all types/formats, human/JSON
  labels, both locales, every typed failure and exit code, stray arguments,
  atomic output files, stdout/serialization failures, and redacted diagnostics.
- [ ] Add `chimera document generate` through the shared service.
- [ ] Run focused localization and CLI suites.

### Task 3: Add localized GUI route and lifecycle

**Files:**
- Create: `apps/chimera_gui/lib/identity_document_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/identity_document_test.dart`
- Create: `apps/chimera_gui/test/adapters/identity_document_save_test.dart`

- [ ] Write failing widget/adapter tests for locales, all selectors, validation,
  exhaustion, warning, exact copy/save, cancellation, accessibility, keyboard,
  responsive layout, re-entry prevention, and stale completion/disposal.
- [ ] Implement the page, home entry, result semantics, and ephemeral lifecycle.
- [ ] Run focused GUI suites serially.

### Task 4: Add native and browser full-flow coverage

**Files:**
- Create: `apps/chimera_gui/integration_test/identity_document_generate_test.dart`
- Create: `tests/web/identity_document_browser.js`
- Create: `tests/web/identity_document.spec.mjs`
- Modify: `tests/web/playwright.config.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

- [ ] Cover representative US/BR types, both CNPJ formats, multi-value exact
  transfer, both locales, AF-01, AF-02, state discard, and offline/no-network.
- [ ] Run affected native, widget, browser, and Safari suites.

### Task 5: Verify, review, and deliver issue #37

- [ ] Run formatting, fatal analysis, boundary checks, and
  `dart run melos run test:all`.
- [ ] Obtain independent review and resolve every Critical or Important finding.
- [ ] Push, open an issue-closing PR to `develop`, require all CI green, squash
  merge, delete the branch, mark #37 Done, verify closure, and sync `develop`.

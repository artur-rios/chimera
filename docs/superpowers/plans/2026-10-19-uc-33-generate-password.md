# UC-33 Generate Password Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate an ephemeral password locally from a requested length and selected character classes, with guaranteed class coverage and no insecure fallback when secure entropy fails.

**Architecture:** Add a pure generator in `chimera_utilities` with an injectable bounded-random function and a production `Random.secure` source. Map raw adapter values and redacted typed failures in `chimera_core`; expose the same service through CLI and Flutter GUI adapters; verify native and compiled-web behavior offline.

**Tech Stack:** Dart 3.13.5, Flutter, package:test, flutter_test, args, go_router, Playwright, WebDriver

**Spec:** `docs/requirements/Use Case Specification Document.md` (UC-33), FR-GE-05, FR-PL-01–FR-PL-06, FR-PL-09–FR-PL-11, BR-01–BR-05, BR-19, GitHub issue #34

## Global Constraints

- Use only cryptographically secure randomness in production and never fall back to predictable entropy.
- Guarantee at least one character from every requested class.
- Reject no-class selections, non-decimal/non-positive lengths, and lengths smaller than the requested class count before requesting entropy.
- Keep generated passwords out of diagnostics, persistence, and retained UI state after configuration changes or route disposal.
- Preserve stable human/JSON CLI output, transactional file output, English and Brazilian Portuguese localization, keyboard access, and offline behavior.

## Review Focus

- Every candidate character must be sampled uniformly from the combined
  selected alphabet through the injected secure boundary. Reject candidates
  that omit a selected class so every valid constrained password remains
  equiprobable; bound rejection to a fixed processing failure.
- Entropy failures and invalid injected values must become redacted processing failures with no partial password.
- GUI/CLI adapters must call the shared service rather than implement generation themselves.
- Copy/save failures and pending async completions must clear or ignore sensitive state consistently.

---

### Task 1: Add the shared password generator and service

**Files:**
- Create: `packages/chimera_utilities/lib/src/password/password_generator.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/password/password_generator_test.dart`
- Create: `packages/chimera_core/lib/src/password_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/password_service_test.dart`

- [ ] Write failing tests for defaults, every class toggle, minimum feasible length, exact class coverage, deterministic uniform sampling, invalid/impossible constraints before entropy, entropy failure, invalid random output, and redacted typed service failures.
- [ ] Implement the smallest generator and service that pass those tests.
- [ ] Run the two focused suites and keep RED/GREEN evidence.

### Task 2: Add localized CLI behavior

**Files:**
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/password_generate_test.dart`

- [ ] Write failing tests for help, defaults, class flags, JSON, localized validation/processing failures, stray arguments, transactional output, stdout/serialization failures, exit codes, and secret-free diagnostics.
- [ ] Add `chimera password generate` using the shared service and established output boundaries.
- [ ] Run the focused localization and CLI suites.

### Task 3: Add the localized GUI route and state lifecycle

**Files:**
- Create: `apps/chimera_gui/lib/password_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/password_test.dart`
- Create: `apps/chimera_gui/test/adapters/password_save_test.dart`

- [ ] Write failing widget/adapter tests for both locales, validation, processing, copy/save, cancellation, accessibility, keyboard submission, re-entry prevention, and stale completion/disposal.
- [ ] Implement the route, home entry, form, result semantics, copy/save actions, and sensitive-state invalidation.
- [ ] Run the focused GUI suites.

### Task 4: Add native and browser full-flow coverage

**Files:**
- Create: `apps/chimera_gui/integration_test/password_generate_test.dart`
- Create: `tests/web/password_browser.js`
- Create: `tests/web/password.spec.mjs`
- Modify: `tests/web/playwright.config.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

- [ ] Cover default and constrained generation, copy/save exactness, validation and processing boundaries, state discard, both locales where applicable, and zero unexpected network requests.
- [ ] Add the route to the browser matrix and Safari smoke workflow.
- [ ] Run affected native, widget, and web suites.

### Task 5: Verify, review, and deliver issue #34

- [ ] Run formatting, analysis, boundary checks, and `dart run melos run test:all`.
- [ ] Obtain independent code review and resolve every Critical or Important finding.
- [ ] Commit, push, open an issue-closing PR to `develop`, require all CI checks green, squash merge, delete the branch, move issue #34 to Done, verify closure, and sync `develop`.

# UC-34 Generate UUID or GUID Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate ephemeral UUID version 4 or version 7 identifiers locally, in a requested UUID or GUID text representation and positive count, without partial output when entropy or time generation fails.

**Architecture:** Add a pure identifier generator in `chimera_utilities` around the approved `uuid` dependency, with injectable random bytes and clock. Map raw adapter values and redacted typed failures in `chimera_core`; expose the same service through CLI and Flutter GUI adapters; verify native and compiled-web behavior offline.

**Tech Stack:** Dart 3.13.5, Flutter, uuid 4.6.0, package:test, flutter_test, args, go_router, Playwright, WebDriver

**Spec:** `docs/requirements/Use Case Specification Document.md` (UC-34), FR-GE-06–FR-GE-07, FR-PL-01–FR-PL-06, FR-PL-09–FR-PL-11, BR-01–BR-05, BR-19, GitHub issue #35

## Global Constraints

- Support only UUID versions 4 and 7 and the documented UUID/GUID text representations.
- Use cryptographically secure randomness in production and never fall back to predictable entropy.
- Generate all requested identifiers atomically; discard the whole batch if randomness, time, allocation, formatting, or output transfer fails.
- Validate version, representation, and a positive decimal count before invoking randomness or the clock; impose no product-specific ceiling beyond platform resource constraints.
- Keep requests/results out of diagnostics, persistence, history, and retained UI state after configuration changes or route disposal.
- Preserve stable human/JSON CLI output, transactional file output, English and Brazilian Portuguese localization, keyboard access, and offline behavior.

## Review Focus

- Every identifier must have the requested RFC version nibble and RFC 9562 variant bits, with v7 timestamps encoded in the leading 48 bits.
- UUID representation is canonical lower-case hyphenated text; GUID representation uses the same value in upper-case braces without changing byte order.
- Random, clock, allocation, and invalid injected values must become redacted typed failures with no partial identifiers.
- GUI/CLI adapters must call the shared service rather than implement identifier generation or formatting themselves.

---

### Task 1: Add the shared UUID/GUID generator and service

**Files:**
- Modify: `packages/chimera_utilities/pubspec.yaml`
- Create: `packages/chimera_utilities/lib/src/uuid/uuid_generator.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/uuid/uuid_generator_test.dart`
- Create: `packages/chimera_core/lib/src/uuid_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/uuid_service_test.dart`

- [ ] Write failing tests for v4/v7 RFC bits, v7 timestamp, UUID/GUID formatting, exact count, uniqueness, validation before dependencies, random/time/allocation failures, invalid injected values, and redacted typed service failures.
- [ ] Implement the smallest generator and service that pass those tests.
- [ ] Run the two focused suites and retain RED/GREEN evidence.

### Task 2: Add localized CLI behavior

**Files:**
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Create: `apps/chimera_cli/test/functional/uuid_generate_test.dart`

- [ ] Write failing tests for help, defaults, versions, representations, count, JSON, localized validation/processing failures, stray arguments, transactional output, stdout/serialization failures, exit codes, and identifier-free diagnostics.
- [ ] Add `chimera uuid generate` using the shared service and established output boundaries.
- [ ] Run the focused localization and CLI suites.

### Task 3: Add the localized GUI route and state lifecycle

**Files:**
- Create: `apps/chimera_gui/lib/uuid_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Create: `apps/chimera_gui/test/widgets/uuid_test.dart`
- Create: `apps/chimera_gui/test/adapters/uuid_save_test.dart`

- [ ] Write failing widget/adapter tests for both locales, validation, processing, copy/save, cancellation, accessibility, keyboard submission, re-entry prevention, and stale completion/disposal.
- [ ] Implement the route, home entry, form, result semantics, copy/save actions, and ephemeral-state invalidation.
- [ ] Run the focused GUI suites.

### Task 4: Add native and browser full-flow coverage

**Files:**
- Create: `apps/chimera_gui/integration_test/uuid_generate_test.dart`
- Create: `tests/web/uuid_browser.js`
- Create: `tests/web/uuid.spec.mjs`
- Modify: `tests/web/playwright.config.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

- [ ] Cover v4/v7 and UUID/GUID generation, multi-value copy/save exactness, validation and processing boundaries, state discard, both locales where applicable, and zero unexpected network requests.
- [ ] Add the route to the browser matrix and Safari smoke workflow.
- [ ] Run affected native, widget, and web suites.

### Task 5: Verify, review, and deliver issue #35

- [ ] Run formatting, analysis, boundary checks, and `dart run melos run test:all`.
- [ ] Obtain independent code review and resolve every Critical or Important finding.
- [ ] Commit, push, open an issue-closing PR to `develop`, require all CI checks green, squash merge, delete the branch, move issue #35 to Done, verify closure, and sync `develop`.

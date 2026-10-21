# UC-42 Change Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply and locally persist an explicit light or dark theme across the
shared browser and desktop Flutter interface.

**Architecture:** Adapt the existing `PreferenceGateway` to
`shared_preferences`, centralize restore/select/error/stale-completion behavior
in one observable controller, and bind that controller to both
`MaterialApp.router` and an accessible localized selector on the home page.

**Tech Stack:** Dart 3.11+, Flutter 3.47+, `shared_preferences`, GoRouter,
Flutter widget/integration tests, Playwright, and Safari WebDriver.

**Spec:**
`docs/superpowers/specs/2026-10-20-uc-42-change-theme-design.md`

## Global Constraints

- Implement UC-42, FR-PL-07, BR-06, and issue #43.
- Persist only canonical `light` or `dark` under `PreferenceKey.theme`.
- Apply selection before persistence completes and retain it on write failure.
- Default safely to light on missing, invalid, or unreadable storage.
- Complete user-facing behavior in English and Brazilian Portuguese.
- Keep browser, Windows, and Linux behavior aligned and offline.
- Run Flutter commands serially.

### Task 1: Add preference adapter and theme controller

**Files:**
- Create: `apps/chimera_gui/lib/shared_preferences_gateway.dart`
- Create: `apps/chimera_gui/lib/theme_preferences.dart`
- Create: `apps/chimera_gui/test/theme_preferences_test.dart`

- [ ] Write failing tests for exact reads/writes, redacted adapter failures,
  restore defaults, valid and invalid stored values, immediate selection,
  write failure, stale completions, and disposal.
- [ ] Run the focused test and confirm RED.
- [ ] Implement the adapter and controller.
- [ ] Run the focused test and confirm GREEN.
- [ ] Commit `feat: add theme preference state`.

### Task 2: Bind theme state to the localized interface

**Files:**
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Create: `apps/chimera_gui/test/widgets/theme_preferences_test.dart`

- [ ] Write failing localization and widget tests for both themes and locales,
  restart restoration, invalid/read/write failures, immediate application,
  narrow 200-percent layout, keyboard order, semantics, and target size.
- [ ] Run focused tests and confirm RED.
- [ ] Add explicit light/dark theme data and the localized home selector.
- [ ] Run focused localization and widget suites and confirm GREEN.
- [ ] Commit `feat: add theme selection interface`.

### Task 3: Add platform evidence and deliver

**Files:**
- Create: `apps/chimera_gui/integration_test/theme_preferences_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify: `docs/operations/accessibility-review.md`

- [ ] Add native, Chromium, Firefox, WebKit, and Safari journeys for selection,
  persistence, restart restoration, accessibility, and zero network requests.
- [ ] Run focused and full formatting, analysis, boundary, unit, widget, native,
  browser, deployment, and performance verification serially.
- [ ] Obtain a fresh whole-branch review and resolve every Critical or Important
  finding with regression evidence.
- [ ] Push, open an issue-closing PR to `develop`, require all CI checks green,
  merge without bypassing protection, delete the branch, move #43 to Done,
  verify closure, and sync `develop`.

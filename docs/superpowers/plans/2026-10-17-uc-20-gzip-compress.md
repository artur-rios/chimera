# UC-20 GZIP Compress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compress text or local bytes into deterministic GZIP output across
CLI, GUI, desktop, and web.

**Architecture:** Add one platform-independent GZIP compressor to
`chimera_utilities`, map it through a typed `chimera_core` service, and keep CLI
and Flutter code as source/save adapters. Binary output remains one immutable
payload and is never rendered as text.

**Tech Stack:** Dart/Flutter workspace, `archive` 4.5.2, existing sealed result
model, staged CLI file writer, `file_picker`, Flutter widget/integration tests,
and Playwright/WebDriver browser harnesses.

**Spec:** `docs/superpowers/specs/2026-10-17-uc-20-gzip-compress-design.md`

## Global constraints

- Accept strict UTF-8 text or arbitrary validated bytes; empty input is valid.
- Support levels 0 through 9, default 6, and reject all others before encoding.
- Produce one metadata-free member with MTIME zero and identical bytes on every
  target by using the package's platform-independent Dart encoder.
- Retain one immutable result byte list; JSON views are transient.
- Add no network, persistence, history, telemetry, account, plugin, TAR/ZIP, or
  decompression behavior.
- Complete all user-facing behavior in English and Brazilian Portuguese.
- CLI saves are transactional; GUI saves provide one exact adapter handoff.
- Tests use Given-When-Then names and cover the main flow, AF-01, AF-02, every
  affected target/locale, no-network behavior, redaction, discard, and cleanup.

## Review focus

- Native and browser builds must emit byte-identical GZIP for the same input and
  level; a platform-conditional native codec is not acceptable.
- Header MTIME, optional metadata flags, CRC32, and ISIZE must be pinned.
- Empty input and level 0 are valid, not missing/invalid data.
- Invalid options must be rejected before any stdin/file collaborator runs.
- Raw binary must never reach a human text sink.
- Save failure must publish no success and preserve any existing CLI target.

---

### Task 1: Shared deterministic GZIP utility

**Files:**
- Modify: `packages/chimera_utilities/pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `packages/chimera_utilities/lib/src/gzip/gzip_compressor.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/gzip/gzip_compressor_test.dart`

**Produces:** `GzipCompressor`, `GzipCompressionResult`, typed failure kinds,
and the `archive` 4.5.2 dependency.

- [ ] Write failing known-answer and round-trip tests for empty, ASCII, Unicode,
  arbitrary bytes, compressible/incompressible input, levels 0/1/6/9, default
  level, deterministic repeated output, metadata-free header, trailer, counts,
  and immutable ownership.
- [ ] Run `dart test packages/chimera_utilities/test/gzip/gzip_compressor_test.dart`
  and verify RED because the public utility is missing.
- [ ] Add `archive: 4.5.2` using the workspace dependency tool and implement the
  smallest platform-independent encoder wrapper that satisfies the contract.
- [ ] Add failing invalid Unicode, byte-range, -1/10 level, exact input/output
  budget, injected allocation, redaction, and no-partial-output tests; make them
  pass without exposing dependency exceptions.
- [ ] Run `dart test packages/chimera_utilities/test` and commit
  `feat: add deterministic gzip compressor`.

---

### Task 2: Core service and stable binary JSON

**Files:**
- Create: `packages/chimera_core/lib/src/gzip_compress_service.dart`
- Create: `packages/chimera_core/test/gzip_compress_service_test.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`

**Produces:** text/byte operation requests, `GzipCompressOutput`, and
`GzipCompressService`.

- [ ] Write failing tests for request factories, default/explicit level,
  exact output ownership, counts, ordered JSON, and typed/redacted failure maps.
- [ ] Run the focused core test and verify RED because the service is absent.
- [ ] Implement one delegation to `GzipCompressor`; map validation/resource
  failures to `error.gzipCompress.validation` and `.resource` only.
- [ ] Run `dart test packages/chimera_core/test` and commit
  `feat: add gzip compression service`.

---

### Task 3: CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

**Produces:** `chimera gzip compress` with text/stdin/file, level, exact save,
human summary, stable JSON, and documented exits.

- [ ] Write failing parser and happy-path tests for all source kinds, empty text
  and empty file, default/0/9 levels, both locales, exact raw save, JSON bytes,
  and save-before-success ordering.
- [ ] Run the CLI test and verify RED on the missing command.
- [ ] Add localized usage, summary, validation, access, and resource keys with
  exact English/PT-BR parity; parse `--level`, `--output`, and `--json`.
- [ ] Require output or JSON and validate source cardinality/level before I/O.
- [ ] Reuse the staged transactional writer and add partial-stage, collision,
  replacement, cleanup/restore, allocation, redaction, exit 64/74/75, and
  no-success-on-failure regressions.
- [ ] Run l10n and CLI suites and commit `feat: expose gzip compression in cli`.

---

### Task 4: Interactive GZIP compression page

**Files:**
- Create: `apps/chimera_gui/lib/gzip_compress_page.dart`
- Create: `apps/chimera_gui/test/widgets/gzip_compress_test.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `docs/operations/accessibility-review.md`

**Produces:** localized `/gzip/compress` route, text/file/clipboard sources,
level selector, binary summary, and exact `.gz` save.

- [ ] Write failing widget tests for default level 6, levels 0/9, empty text,
  source exclusivity, exact result/save bytes, filename/MIME, route/home action,
  and both locales.
- [ ] Run the focused widget test and verify RED because the page is absent.
- [ ] Implement injectable file, clipboard, and save boundaries with generation
  guards, stale-result clearing, racing-action disablement, and one exact save
  handoff. Do not expose a binary copy action.
- [ ] Add AF-01/AF-02, cancellation, boundary exception, allocation, stale async
  completion, disposal, redaction, focus, keyboard, live-region, 48x48, narrow
  layout, 200-percent text, and contrast tests/evidence.
- [ ] Run l10n and widget suites and commit `feat: add gzip compression page`.

---

### Task 5: Native and browser evidence

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

**Produces:** representative exact compression evidence on Windows/Linux,
Chromium, Firefox, WebKit, and native Safari.

- [ ] Add failing native and compiled-browser flows for text or binary input,
  selected level, exact `.gz` save/download, independent decompression to the
  source, stable semantics, and zero unexpected network requests.
- [ ] Run locally available GUI integration and web suites; keep Linux and
  native Safari mandatory in unchanged CI.
- [ ] Commit `test: cover gzip compression targets`.

---

### Task 6: Gate verification, review, and delivery

**Produces:** reviewed PR closing issue #21 and a reconciled clean `develop`.

- [ ] Audit the main flow, AF-01, AF-02, FR-EN-06/17/18, FR-PL-01 through
  FR-PL-06 and FR-PL-09 through FR-PL-11, BR-01 through BR-05/19, every level
  boundary, source, locale, target, offline path, redaction rule, and ownership
  guarantee. Record deviations and explicit rulings.
- [ ] Run formatting, root/package analysis, dependency boundaries,
  `git diff --check`, and exact unfiltered `dart run melos run test:all`.
- [ ] Obtain independent whole-branch review; fix every Critical/Important
  finding test-first and rerun affected plus full gates.
- [ ] Push, open a PR to `develop` with `Closes #21`, attach it, and move the
  project item to Testing.
- [ ] Wait for branch-policy, every matrix job, native Safari, and aggregate
  Cross-platform to pass; squash merge without admin/force/self-approval and
  delete the branch.
- [ ] Verify issue closed, item Done, branches absent, clean synchronized
  `develop`, then continue to the next open issue in specification order.

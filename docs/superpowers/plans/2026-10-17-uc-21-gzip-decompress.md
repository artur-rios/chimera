# UC-21 GZIP Decompress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strictly decompress local GZIP bytes to explicit text or binary output
across CLI, GUI, desktop, and web.

**Architecture:** Add one pure-Dart strict GZIP member parser/decompressor to
`chimera_utilities`, map it through a typed `chimera_core` service, and keep CLI
and Flutter code as source/presentation/save adapters. Decode privately and
publish only after all members, checksums, mode conversion, and budgets pass.

**Tech Stack:** Dart/Flutter workspace, `archive` 4.5.2 `Inflate`/CRC/stream
primitives, existing sealed result model, staged CLI writer, `file_picker`,
Flutter widget/integration tests, and Playwright/WebDriver browser harnesses.

**Spec:** `docs/superpowers/specs/2026-10-17-uc-21-gzip-decompress-design.md`

## Global constraints

- Accept raw bytes containing exactly one or more valid RFC 1952 members.
- Verify framing, optional FHCRC, every CRC32/ISIZE, and reject all junk.
- Use one pure-Dart path on native and web; never publish partial output.
- Decode each member with `Inflate.lazy(...).inflateBlock()` and isolate its
  back-reference history from all earlier members.
- Require explicit text/binary mode; text is strict UTF-8 and binary is never
  sent to a human text sink.
- Check nullable input/output budgets before copying and during every write.
- Retain one immutable output; discard source and partials on all paths.
- Add no network, persistence, history, telemetry, accounts, plugins, or
  archive extraction behavior.
- Complete all user-facing behavior in English and Brazilian Portuguese.
- CLI writes are transactional; GUI saves are one exact adapter handoff.
- Tests use Given-When-Then names and cover main flow, AF-01, AF-02, every
  affected target/locale, offline behavior, redaction, discard, and cleanup.

## Review focus

- `GZipDecoder.decodeBytes` and native fallback behavior are forbidden.
- Concatenated members are valid; trailing bytes and malformed later members
  invalidate the entire operation.
- Reserved flags and optional header CRC must be enforced explicitly.
- The aggregate output limit must apply before mutation in every output method,
  including `writeBackReference`, without trusting ISIZE for allocation.
- Invalid UTF-8 is a text-mode failure but the same payload succeeds in binary.
- File metadata is never exposed or used as a destination path.
- Save failure must publish no success and preserve an existing CLI target.

---

### Task 1: Strict shared GZIP decompressor

**Files:**
- Create: `packages/chimera_utilities/lib/src/gzip/gzip_decompressor.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/gzip/gzip_decompressor_test.dart`
- Create: `tests/fixtures/encoded/gzip/README.md`
- Create: `tests/fixtures/encoded/gzip/manifest.json`
- Create: independent fixture source/member files as required by the manifest

**Produces:** strict framing/inflate/checksum behavior, text/binary modes,
immutable result, budgets, and typed failures.

- [ ] Write failing independent-fixture tests for empty, ASCII, Unicode,
  BOM-preserving text,
  arbitrary bytes, optional fields/FHCRC, concatenation, counts, mode output,
  immutable ownership, and repeated stateless calls.
- [ ] Run the focused utility test and verify RED because the API is missing.
- [ ] Implement the smallest strict member parser around
  `Inflate.lazy(...).inflateBlock()`, CRC32, and a member-scoped output facade.
  Reset DEFLATE history per member while enforcing the aggregate limit before
  `writeByte`, `writeBytes`, `writeStream`, and `writeBackReference` with
  overflow-safe comparisons. Never preallocate from ISIZE and publish only
  after full validation.
- [ ] Add failing mutations for magic/method/flags, optional fields, DEFLATE,
  truncation, CRC/ISIZE, trailing junk, later members, raw/zlib/ZIP, byte range,
  invalid Huffman and stored LEN/NLEN, a later member whose invalid initial
  back-reference could otherwise reach prior-member bytes, invalid UTF-8,
  `maxOutputBytes=0`, exact/+1 budgets, oversized back-references, combined
  concatenated-member limits, allocations, redaction, and no partial output.
  Pin the design's malformed/corrupt/unsupported classification table and make
  all tests pass without exposing dependency exceptions.
- [ ] Run `dart test packages/chimera_utilities/test` and commit
  `feat: add strict gzip decompressor`.

---

### Task 2: Core service and stable mode JSON

**Files:**
- Create: `packages/chimera_core/lib/src/gzip_decompress_service.dart`
- Create: `packages/chimera_core/test/gzip_decompress_service_test.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`

**Produces:** byte request, text/binary output, service delegation, and typed
validation/resource mappings.

- [ ] Write failing tests for both modes, empty payload, one delegation, exact
  byte ownership, BOM preservation, counts, ordered JSON, and every classified
  typed/redacted failure map.
- [ ] Run the focused core test and verify RED because the service is absent.
- [ ] Implement one delegation to `GzipDecompressor`; map archive/text failures
  to validation and budget/allocation failures to resource.
- [ ] Run `dart test packages/chimera_core/test` and commit
  `feat: add gzip decompression service`.

---

### Task 3: CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

**Produces:** `chimera gzip decompress` for stdin/file, explicit mode, exact
text/save/JSON, localized diagnostics, exits, and transactional output.

- [ ] Write failing parser/happy-path tests for both sources/modes, empty
  decompressed output, exact text without newline, exact raw save, ordered JSON,
  BOM code points/bytes, both locales, and save-before-success ordering.
- [ ] Run the focused CLI test and verify RED on the missing command.
- [ ] Add localized usage/summary/validation/access/resource keys; validate
  source cardinality, mode, and binary destination before any I/O.
- [ ] Reuse the staged writer and add corruption, invalid text, partial-stage,
  collision, replacement, cleanup/restore, allocation, redaction, exit
  64/74/75, and no-success-on-failure regressions.
- [ ] Run l10n and CLI suites and commit
  `feat: expose gzip decompression in cli`.

---

### Task 4: Interactive GZIP decompression page

**Files:**
- Create: `apps/chimera_gui/lib/gzip_decompress_page.dart`
- Create: `apps/chimera_gui/test/widgets/gzip_decompress_test.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `docs/operations/accessibility-review.md`

**Produces:** localized `/gzip/decompress`, arbitrary local file input, explicit mode, exact
text copy/save, binary save, source discard, and accessible lifecycle behavior.

- [ ] Write failing widget tests for route/home action, extension-independent
  file/mode flows, empty output, exact text/BOM copy/save and binary save,
  filename/MIME, discard, and both locales.
- [ ] Run the focused widget test and verify RED because the page is absent.
- [ ] Implement injectable file/copy/save boundaries with generation guards,
  stale-result clearing, racing-action disablement, immediate source discard,
  and one exact save handoff.
- [ ] Add malformed/input/output access, resource, cancellation, stale async,
  disposal, redaction, focus, keyboard, live-region, 48x48, narrow-layout,
  200-percent-text, and contrast tests/evidence.
- [ ] Run l10n and widget suites and commit
  `feat: add gzip decompression page`.

---

### Task 5: Native and browser evidence

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`
- Modify or create the narrowly scoped web save observer as required

**Produces:** strict decompression evidence on Windows/Linux,
Chromium, Firefox, WebKit, and native Safari.

- [ ] Record a target matrix covering Windows, Linux, Chromium, Firefox,
  WebKit, and native Safari. Across that matrix cover text and binary modes,
  English and Brazilian Portuguese, AF-01 corruption, exact
  copy/save/download including BOM, stable semantics, URL cleanup, and zero
  unexpected network requests; every target must cover at least one mode and
  one offline happy path, with all listed dimensions covered overall.
- [ ] Run locally available GUI integration and web suites; keep Linux and
  native Safari mandatory in unchanged CI.
- [ ] Commit `test: cover gzip decompression targets`.

---

### Task 6: Gate verification, review, and delivery

**Produces:** reviewed PR closing issue #22 and reconciled clean `develop`.

- [ ] Audit main flow, AF-01, AF-02, FR-EN-07/17/18, FR-PL-01 through
  FR-PL-06 and FR-PL-09 through FR-PL-11, BR-01 through BR-05/19, framing,
  every mode/source/locale/target, offline path, redaction, and ownership.
- [ ] Run formatting, root/package analysis, dependency boundaries,
  `git diff --check`, focused suites, and exact unfiltered
  `dart run melos run test:all`.
- [ ] Obtain independent whole-branch review; fix every Critical/Important
  finding test-first and rerun affected plus full gates.
- [ ] Push, open a PR to `develop` with `Closes #22`, attach it, and move the
  project item to Testing.
- [ ] Wait for branch policy, every matrix job, native Safari, and aggregate
  Cross-platform to pass; squash merge without admin/force/self-approval and
  delete the branch.
- [ ] Verify issue closed, item Done, branches absent, clean synchronized
  `develop`, then continue to the next open issue in specification order.

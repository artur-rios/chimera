# UC-23 HTML Decode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strictly decode recognized HTML character references into exact local
text across CLI, GUI, desktop, and web.

**Architecture:** Extract the existing Text Unescape HTML algorithm into one
dedicated `HtmlEntityDecoder` in `chimera_utilities`, preserve UC-11 by mapping
that decoder back through its current contract, and expose UC-23 through a
typed `chimera_core` service. CLI and Flutter remain source, presentation, and
output adapters and reuse the proven transactional writer and zero-byte web-save
boundary from UC-22.

**Tech Stack:** Dart/Flutter workspace, existing sealed result model and staged
CLI writer, `dart:convert` strict UTF-8, `file_picker`, `package:web`, Flutter
widget/integration tests, and Playwright/WebDriver browser harnesses.

**Spec:** `docs/superpowers/specs/2026-10-18-uc-23-html-decode-design.md`

## Global Constraints

- Recognize only `amp`, `lt`, `gt`, `quot`, `apos`, and strict decimal or
  hexadecimal numeric references; every reference requires `;`.
- Decode exactly once, left to right: `&amp;lt;` becomes `&lt;`, not `<`.
- Preserve non-reference text exactly and accept empty input/output.
- Reject unknown, unterminated, signed, nonnumeric, out-of-range, surrogate,
  isolated-surrogate, and malformed UTF-8 input with typed redacted failures.
- Entity/literal offsets use UTF-16 code units; malformed UTF-8 offsets use bytes;
  budget/allocation failures omit offsets.
- Keep UC-11 Text Unescape HTML behavior and public failures unchanged by
  delegating it to the same shared decoder.
- Use one utility/service across browser, desktop, and CLI; never return partial
  output and never add parsing, repair, sanitizing, persistence, or network.
- Production has no product-specific size ceiling; budgets and allocation seams
  exist only for deterministic tests.
- Complete every user-facing path in English and Brazilian Portuguese.
- CLI output writes are transactional; GUI saves perform one exact adapter
  handoff and revoke every web object URL.
- Tests use Given-When-Then names and cover the main flow, AF-01, AF-02, every
  source/locale/affected target, offline behavior, redaction, discard, races,
  and cleanup.

## Review Focus

- `&amp;lt;` must decode once to `&lt;`, never recursively to `<`.
- Literal `&`, missing semicolons, unknown names, signed numbers, non-scalars,
  and isolated surrogates must fail with exact safe reason/offset details.
- Text Unescape HTML must retain its existing `text-unescape.*` codes, reasons,
  offsets, budgets, and results after extraction.
- Empty decoded output must copy/save as zero bytes on web through the shared
  empty-file adapter.
- Source validation must happen before stdin/file access, and failed output
  writes must preserve existing destinations and publish no success.

---

### Task 1: Shared HTML entity decoder and UC-11 extraction

**Files:**
- Create: `packages/chimera_utilities/lib/src/html/html_entity_decoder.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Modify: `packages/chimera_utilities/lib/src/text_unescape/text_unescaper.dart`
- Create: `packages/chimera_utilities/test/html/html_entity_decoder_test.dart`
- Modify: `packages/chimera_utilities/test/text_unescape/text_unescaper_test.dart`

**Interfaces:**
- Produces: `HtmlEntityDecodeRequest({required String input})`,
  `HtmlEntityDecodeResult({required String decoded})`,
  `HtmlEntityDecodeException`, and
  `HtmlEntityDecoder.decodeText(HtmlEntityDecodeRequest)` /
  `decodeUtf8(List<int>)`.
- Preserves: `TextUnescaper.unescape(TextUnescapeRequest(mode: 'html'))` and
  all existing Text Unescape failure/result contracts.

- [ ] Write failing decoder tests with literal expected strings for all five
  names, decimal/hex/uppercase-X references, decode-once behavior, empty/ASCII/
  Unicode/supplementary/NUL/CRLF/BOM input, repeated calls, and exact result.
- [ ] Run `dart test packages/chimera_utilities/test/html/html_entity_decoder_test.dart`
  and verify RED because the API is missing.
- [ ] Implement the minimal strict scalar parser and UTF-8 entry point with
  `HtmlEntityDecoder({int? maxInputCharacters, int? maxOutputCharacters})` and
  a testing-only allocation seam; return no partial output.
- [ ] Add failing tests for unknown/unterminated entities, empty/signed/invalid
  numeric bodies, out-of-range and surrogate scalars, literal high/low
  surrogates, malformed UTF-8 with byte offsets, exact/exceeded budgets,
  `OutOfMemoryError`, and redacted errors; make them pass.
- [ ] Replace `TextUnescaper._unescapeHtml` with delegation to the decoder and
  map validation/resource failures to the exact existing `text-unescape.*`
  codes, fields, reasons, offsets, and limits.
- [ ] Run `dart test packages/chimera_utilities/test` and commit
  `feat: add html entity decoder`.

---

### Task 2: Core HTML decode service

**Files:**
- Create: `packages/chimera_core/lib/src/html_decode_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/html_decode_service_test.dart`

**Interfaces:**
- Consumes: Task 1's text/UTF-8 decoder entry points and typed failures.
- Produces: `HtmlDecodeOperationRequest.text(String)`,
  `HtmlDecodeOperationRequest.utf8Bytes(List<int>)`,
  `HtmlDecodeOutput.decoded`, ordered `toJson()`, and `HtmlDecodeService`.

- [ ] Write failing tests for text and UTF-8 sources, named/numeric/decode-once
  values, empty text, exact `{decoded: ...}` JSON order, one delegation, and no
  retained source.
- [ ] Run the focused core test and verify RED because the service is absent.
- [ ] Implement the request, output, and service; dispatch by source kind and
  map malformed/scalar/UTF-8 failures to validation and budgets/allocation to
  resource without leaking input or dependency messages.
- [ ] Add failing mapping tests for every utility failure kind, reason, and
  optional offset and make them pass.
- [ ] Run `dart test packages/chimera_core/test` and commit
  `feat: add html decode service`.

---

### Task 3: CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

**Interfaces:**
- Consumes: Task 2 service and the existing staged transactional writer.
- Produces: `chimera html decode`, exact human/JSON/save output, localized
  usage/result/errors, and exit 64/74/75 behavior.

- [ ] Write failing parser and happy-path tests for direct/stdin/file sources,
  named/numeric/decode-once and empty values, strict Unicode/UTF-8, exact stdout
  without newline, ordered JSON, exact UTF-8 save bytes, and both locales.
- [ ] Run focused CLI tests and verify RED on the missing `decode` subcommand.
- [ ] Add the command and localized keys. Validate unknown options and source
  cardinality before any input collaborator runs.
- [ ] Add failing AF-01/AF-02 tests for every malformed category, input/output
  denial, allocation/resource limits, stage/write/replace/restore failures,
  redaction, exits, and no success/partial result; make them pass through the
  existing transactional writer.
- [ ] Run l10n and complete CLI suites and commit
  `feat: expose html decoding in cli`.

---

### Task 4: Interactive HTML decode page

**Files:**
- Create: `apps/chimera_gui/lib/html_decode_page.dart`
- Create: `apps/chimera_gui/test/widgets/html_decode_test.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `docs/operations/accessibility-review.md`

**Interfaces:**
- Consumes: Task 2 service, the generic `trySaveEmptyFile`, and existing local
  file/clipboard/save patterns.
- Produces: localized `/html/decode`, typed/file/clipboard input, exact result,
  copy/save, strict failures, and accessible lifecycle.

- [ ] Write failing widget tests for route/home action, all three sources,
  named/numeric/decode-once/empty output, exact copy/save filename/MIME/UTF-8,
  both locales, and source/editor-history/result discard.
- [ ] Run the focused widget test and verify RED because the page is absent.
- [ ] Implement injectable source/copy/save/conversion boundaries, strict file
  decoding through the service, generation guards, stale-result clearing,
  racing-action disabling, and one exact save handoff. Use `trySaveEmptyFile`
  for empty web output and the normal picker path otherwise.
- [ ] Add failing tests for cancellation, malformed entities/UTF-8/Unicode,
  allocation, file/clipboard/copy/save denial, resource failure, stale async
  completion, disposal, redaction, focus/keyboard/live region, 48x48 targets,
  narrow layout, 200-percent text, contrast, and zero-byte save cleanup; make
  them pass.
- [ ] Run l10n and complete GUI suites and commit
  `feat: add html decode page`.

---

### Task 5: Native and compiled-browser evidence

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

**Produces:** Windows/Linux, Chromium/Firefox/WebKit, and native Safari evidence.

- [ ] Add a target matrix covering named/numeric/decode-once exact output,
  typed/file/clipboard sources, real keyboard activation, result focus, copy/
  save including empty output, URL cleanup, both locales overall, malformed
  input/no retained result, and zero external requests.
- [ ] Run locally available native integration and compiled-browser suites,
  retaining Linux and native Safari as mandatory unchanged CI gates.
- [ ] Commit `test: cover html decoding targets`.

---

### Task 6: Gate verification, review, and delivery

**Produces:** reviewed PR closing issue #24 and reconciled clean `develop`.

- [ ] Audit the main flow, AF-01, AF-02, FR-EN-09/17, FR-PL-01 through
  FR-PL-06 and FR-PL-09 through FR-PL-11, BR-01 through BR-05/19, every source,
  strict references/text, locales, targets, offline path, redaction, discard,
  UC-11 compatibility, and cleanup.
- [ ] Run formatting, root/package analysis, dependency boundaries,
  `git diff --check`, focused suites, and exact unfiltered
  `dart run melos run test:all`.
- [ ] Obtain an independent whole-branch review; fix every Critical/Important
  finding test-first and rerun affected plus full gates.
- [ ] Push, open a PR to `develop` with `Closes #24`, attach it, and move the
  project item to Testing.
- [ ] Wait for branch policy, every browser/native matrix job, native Safari,
  and aggregate Cross-platform to pass; squash merge without admin/force/
  self-approval and delete the branch.
- [ ] Verify issue closed, item Done, branches absent, clean synchronized
  `develop`, then start UC-24 fresh from its specification.

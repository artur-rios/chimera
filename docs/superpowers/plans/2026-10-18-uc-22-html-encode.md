# UC-22 HTML Encode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encode well-formed local text into deterministic HTML entities for a
selected insertion context across CLI, GUI, desktop, and web.

**Architecture:** Add one `dart:convert`-backed encoder to
`chimera_utilities`, map it through a typed `chimera_core` service, and keep CLI
and Flutter code as source/presentation/output adapters. Reuse repository
transactional writes and extract the existing empty-web-download boundary into
a generic adapter so valid empty output saves exactly once.

**Tech Stack:** Dart/Flutter workspace, `dart:convert` `HtmlEscape`, existing
sealed result model and staged CLI writer, `file_picker`, `package:web`, Flutter
widget/integration tests, and Playwright/WebDriver browser harnesses.

**Spec:** `docs/superpowers/specs/2026-10-18-uc-22-html-encode-design.md`

## Global Constraints

- Support only `all`, `element`, `double-quoted-attribute`, and
  `single-quoted-attribute`; default interfaces to `all`.
- Emit the exact Dart SDK entity spellings and preserve all other well-formed
  text without normalization, trimming, BOM stripping, or newline conversion.
- Reject isolated UTF-16 surrogates and malformed UTF-8 with typed redacted
  validation failures before output serialization.
- Empty text is valid and must copy/save as an exact empty result.
- Use one shared utility/service on browser, desktop, and CLI; never return
  partial output.
- Production has no product-specific size ceiling; injected budgets and
  allocation seams exist only for deterministic failure tests.
- Add no HTML parsing/sanitizing, JavaScript/CSS escaping, decode behavior,
  history, persistence, telemetry, accounts, plugins, collaboration, or network.
- Complete every user-facing path in English and Brazilian Portuguese.
- CLI output writes are transactional; GUI saves perform one exact adapter
  handoff and revoke every web object URL.
- Tests use Given-When-Then names and cover main flow, AF-01, AF-02, all
  contexts/sources/locales/affected targets, offline behavior, redaction,
  discard, races, and cleanup.

## Review Focus

- An existing entity such as `&amp;` must become `&amp;amp;`, never be trusted.
- `all` must encode slash while the three contextual modes follow their exact
  quote subsets; no UC-10 behavior may be silently substituted.
- Isolated surrogates and malformed UTF-8 must fail instead of being replaced.
- Empty output must download as zero bytes on web despite `file_picker_web`
  rejecting empty byte arrays.
- Context/source validation must happen before stdin/file access, and failed
  output writes must preserve existing destinations and publish no success.

---

### Task 1: Shared HTML entity encoder

**Files:**
- Create: `packages/chimera_utilities/lib/src/html/html_entity_encoder.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/html/html_entity_encoder_test.dart`

**Produces:** canonical context validation, strict scalar/UTF-8 input,
deterministic entities, budgets, and typed failures.

- [ ] Write failing tests with literal expected strings for all six entity
  characters across all four contexts, existing entities, empty/ASCII/Unicode,
  supplementary characters, NUL/CRLF/BOM, repeated calls, and exact result
  context. Name the production mutation each test catches.
- [ ] Run the focused test and verify RED because the API is missing.
- [ ] Implement `HtmlEntityEncoder.encodeText` and `encodeUtf8` using the four
  exact context names and `HtmlEscapeMode` mappings. Validate scalar text and
  byte ranges/strict UTF-8 before conversion; return no partial result.
- [ ] Add failing tests for empty/case/alias/unknown context, isolated high/low
  surrogates, malformed UTF-8, exact/exceeded input/output budgets,
  `OutOfMemoryError` through an injected conversion seam, and redacted errors;
  make them pass with minimal code.
- [ ] Run `dart test packages/chimera_utilities/test` and commit
  `feat: add html entity encoder`.

---

### Task 2: Core service and stable JSON

**Files:**
- Create: `packages/chimera_core/lib/src/html_encode_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/html_encode_service_test.dart`

**Consumes:** Task 1's text/UTF-8 encoder entry points and typed failures.

**Produces:** string/UTF-8 requests, output, one delegation, typed mappings,
and ordered JSON.

- [ ] Write failing tests for text and UTF-8 sources, all contexts, empty text,
  exact output/context JSON order, one delegation, and no retained source.
- [ ] Run the focused core test and verify RED because the service is absent.
- [ ] Implement `HtmlEncodeOperationRequest`, `HtmlEncodeOutput`, and
  `HtmlEncodeService`; dispatch by source kind and map invalid input/context to
  validation and budgets/allocation to resource.
- [ ] Add failing mapping/redaction tests for every utility failure and make
  them pass without exposing dependency messages or content.
- [ ] Run `dart test packages/chimera_core/test` and commit
  `feat: add html encode service`.

---

### Task 3: CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

**Consumes:** Task 2 service and the existing staged transactional writer.

**Produces:** `chimera html encode`, exact human/JSON/save output, localization,
and exit behavior.

- [ ] Write failing parser and happy-path tests for direct/stdin/file sources,
  default/all four contexts, empty values, strict Unicode/UTF-8, exact stdout
  without newline, ordered JSON, exact UTF-8 save bytes, and both locales.
- [ ] Run the focused CLI tests and verify RED on the missing command.
- [ ] Add the command and localized usage/result/error keys. Validate unknown
  options, source cardinality, and context before any input collaborator runs.
- [ ] Add failing AF-01/AF-02 tests for malformed text/UTF-8, unknown context,
  input/output denial, allocation/resource limits, stage/write/replace/restore
  failures, redaction, exit 64/74/75, and no success/partial result; make them
  pass through the existing transactional writer.
- [ ] Run l10n and complete CLI suites and commit
  `feat: expose html encoding in cli`.

---

### Task 4: Generic zero-byte web save adapter

**Files:**
- Rename: `apps/chimera_gui/lib/gzip_decompress_empty_file_save.dart` to
  `apps/chimera_gui/lib/empty_file_save.dart`
- Rename: `apps/chimera_gui/lib/gzip_decompress_empty_file_save_stub.dart` to
  `apps/chimera_gui/lib/empty_file_save_stub.dart`
- Rename: `apps/chimera_gui/lib/gzip_decompress_empty_file_save_web.dart` to
  `apps/chimera_gui/lib/empty_file_save_web.dart`
- Modify: `apps/chimera_gui/lib/gzip_decompress_page.dart`
- Modify: `apps/chimera_gui/test/widgets/gzip_decompress_test.dart`

**Consumes:** UC-21's proven conditional empty-download boundary.

**Produces:** a generic `trySaveEmptyFile` adapter with unchanged GZIP behavior
and a reusable exact zero-byte web boundary for Task 5.

- [ ] Add a failing generic-adapter regression proving native empty bytes fall
  through, non-empty web/native bytes fall through, and the compiled web path
  creates one exact empty Blob with filename/MIME and guaranteed URL revocation.
- [ ] Run the focused tests and verify RED on the missing generic API.
- [ ] Rename/generalize the three conditional files and update the GZIP page;
  keep implementation and behavior otherwise unchanged.
- [ ] Run focused GZIP widget and compiled-browser regressions plus analysis and
  commit `refactor: share empty web file saving`.

---

### Task 5: Interactive HTML encode page

**Files:**
- Create: `apps/chimera_gui/lib/html_encode_page.dart`
- Create: `apps/chimera_gui/test/widgets/html_encode_test.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `docs/operations/accessibility-review.md`

**Consumes:** Task 2 service, Task 4 empty-file adapter, and existing local
file/clipboard/save patterns.

**Produces:** localized `/html/encode`, all source/context/result actions,
strict input, exact save support, and accessible lifecycle.

- [ ] Write failing widget tests for route/home action, typed/file/clipboard
  sources, every context, empty output, exact copy/save filename/MIME/UTF-8,
  both locales, and source/result discard.
- [ ] Run the focused widget tests and verify RED because the page is absent.
- [ ] Implement injectable source/copy/save/conversion boundaries, strict file
  decoding, generation guards, stale-result clearing, racing-action disabling,
  and one exact save handoff. Use Task 4's generic conditional adapter for
  empty web output and retain the normal FilePicker path elsewhere.
- [ ] Add failing tests for cancellation, malformed UTF-8/Unicode, allocation,
  file/clipboard/copy/save denial, resource failure, stale async completion,
  disposal, redaction, focus/keyboard/live region, 48x48 targets, narrow layout,
  200-percent text, contrast, and zero-byte web save cleanup; make them pass.
- [ ] Run l10n, GZIP regression, and complete GUI suites and commit
  `feat: add html encode page`.

---

### Task 6: Native and compiled-browser evidence

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

**Produces:** Windows/Linux, Chromium/Firefox/WebKit, and native Safari evidence.

- [ ] Add a target matrix covering exact entity output, context selection,
  keyboard semantics, copy/save including empty output, URL cleanup, both
  locales overall, validation/no retained result, and zero external requests.
- [ ] Run the locally available native integration and compiled-browser suites,
  retaining Linux and native Safari as mandatory unchanged CI gates.
- [ ] Commit `test: cover html encoding targets`.

---

### Task 7: Gate verification, review, and delivery

**Produces:** reviewed PR closing issue #23 and reconciled clean `develop`.

- [ ] Audit main flow, AF-01, AF-02, FR-EN-08/17, FR-PL-01 through FR-PL-06
  and FR-PL-09 through FR-PL-11, BR-01 through BR-05/19, every context/source,
  strict text, locales, targets, offline path, redaction, discard, and cleanup.
- [ ] Run formatting, root/package analysis, dependency boundaries,
  `git diff --check`, focused suites, and exact unfiltered
  `dart run melos run test:all`.
- [ ] Obtain independent whole-branch review; fix every Critical/Important
  finding test-first and rerun affected plus full gates.
- [ ] Push, open a PR to `develop` with `Closes #23`, attach it, and move the
  project item to Testing.
- [ ] Wait for branch policy, every matrix job, native Safari, and aggregate
  Cross-platform to pass; squash merge without admin/force/self-approval and
  delete the branch.
- [ ] Verify issue closed, item Done, branches absent, clean synchronized
  `develop`, then start UC-23 fresh from its specification.

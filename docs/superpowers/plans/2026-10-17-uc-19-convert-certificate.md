# UC-19 Convert Certificate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert one supported certificate among PEM, DER, and Base64 while preserving its exact decoded DER content across CLI, GUI, desktop, and web.

**Architecture:** Refactor the existing certificate inspector's private decode/validation path to produce one private parsed document, then let a converter declared in the same library encode only its representation. A core service maps typed results; CLI and Flutter adapters add source/target selection, exact output, and safe save behavior without duplicating certificate logic.

**Tech Stack:** Dart 3.10 / Flutter 3.47, existing `asn1lib` 1.6.5 and `x509` 0.2.4+3 pins, `args`, `file_picker`, project-owned sealed results, Flutter widget/integration tests, Playwright/WebDriver harnesses.

**Spec:** `docs/superpowers/specs/2026-10-17-uc-19-convert-certificate-design.md`

## Global Constraints

- Preserve decoded DER byte-for-byte; never serialize through `x509` or `asn1lib`.
- Reuse the complete UC-18 decode, DER framing, ASN.1 schema, and metadata validation path.
- PEM output is LF-only, 64-character Base64 lines, exact certificate boundaries, and one terminal LF; Base64 is canonical unwrapped RFC 4648 with no terminal LF.
- One immutable result byte list is retained; text/JSON views are transient.
- No new dependency, network path, persistence, operation history, telemetry, trust verification, chain handling, or private-key behavior.
- User-facing text is complete in English and Brazilian Portuguese.
- CLI output saves use the existing staged transactional writer; GUI saves guarantee exact one-time adapter handoff and no retained app copy.
- Tests use Given-When-Then names and cover main flow, AF-01, AF-02, all affected targets/locales, no-network behavior, and cleanup.

## Review Focus

- A syntactically decodable DER blob that fails a UC-18 nested schema check must fail conversion before any output encoding.
- PEM with wrapper whitespace, CRLF, or non-64 source wrapping must decode to exact DER and emit the one canonical PEM form.
- Converting an explicit representation to itself must canonicalize its wrapper but preserve DER.
- Output-length exact-boundary and one-over cases must fail before allocation and emit no partial bytes.
- DER must never reach a human text sink; it requires save or JSON in CLI and exposes no GUI copy action.

---

### Task 1: Shared certificate conversion utility

**Files:**
- Modify: `packages/chimera_utilities/lib/src/certificate/certificate_inspector.dart`
- Test: `packages/chimera_utilities/test/certificate/certificate_converter_test.dart`
- Test: `packages/chimera_utilities/test/certificate/certificate_inspector_test.dart`

**Interfaces:**
- Consumes: `CertificateInputRepresentation`, UC-18 strict decode/framing/schema validators, and exact fixture DER.
- Produces: `CertificateOutputRepresentation`, `CertificateConversionResult`, `CertificateConversionException`, `CertificateConversionResourceException`, and `CertificateConverter.convertText/convertBytes`.

- [ ] **Step 1: Write failing source/target matrix tests**

  Add parameterized tests for PEM, DER, and Base64 byte sources plus PEM/Base64 text sources into every PEM/DER/Base64 target. Assert detected source, selected target, counts, canonical PEM/Base64 bytes, DER exact equality, `text == null` for DER, same-format canonicalization, and output immutability.

- [ ] **Step 2: Run the utility test and verify the public conversion types are missing**

  Run: `dart test packages/chimera_utilities/test/certificate/certificate_converter_test.dart`

  Expected: FAIL because `CertificateConverter` and its result types do not exist.

- [ ] **Step 3: Refactor inspection to one private parsed document**

  In `certificate_inspector.dart`, introduce `_ParsedCertificateDocument` with exact DER, detected representation, input count, and validated root structure. Refactor `inspectText`/`inspectBytes` through private `_parseText`/`_parseBytes` methods and map the existing metadata from that document. Keep every UC-18 public result, failure code, reason, budget, and validation behavior unchanged.

- [ ] **Step 4: Re-run UC-18 inspector tests**

  Run: `dart test packages/chimera_utilities/test/certificate/certificate_inspector_test.dart`

  Expected: all existing inspector tests PASS unchanged.

- [ ] **Step 5: Implement exact representation encoding**

  Add:

  ```dart
  enum CertificateOutputRepresentation { pem, der, base64 }

  final class CertificateConverter {
    const CertificateConverter({
      this.inspector = const CertificateInspector(),
      this.maxOutputBytes,
    });

    CertificateConversionResult convertText(
      String input, {
      CertificateInputRepresentation source = CertificateInputRepresentation.auto,
      required CertificateOutputRepresentation target,
    });

    CertificateConversionResult convertBytes(
      List<int> input, {
      CertificateInputRepresentation source = CertificateInputRepresentation.auto,
      required CertificateOutputRepresentation target,
    });
  }
  ```

  The converter calls the inspector's private parsed-document path in the same Dart library, translates inspection failures to conversion failures, predicts/checks output length, reuses DER for DER target, and writes canonical Base64/PEM bytes without certificate reserialization. `CertificateConversionResult.text` decodes the retained ASCII bytes only for text targets inside the typed output-resource boundary.

- [ ] **Step 6: Add failing validation/resource regressions, then make them pass**

  Cover malformed/nested-schema DER, explicit mismatch, multiple PEM blocks, byte range, all input/decoded/output budget exact boundaries, allocation translation, text DER rejection, target invariants, redaction, and no partial output. Assert input-side reasons map to field `input`; encoding/text-view reasons map to `output`.

- [ ] **Step 7: Run and commit Task 1**

  Run: `dart test packages/chimera_utilities/test`

  Expected: all utility tests PASS.

  Commit: `feat: add exact certificate conversion utility`

---

### Task 2: Core service and stable serialization

**Files:**
- Create: `packages/chimera_core/lib/src/certificate_convert_service.dart`
- Create: `packages/chimera_core/test/certificate_convert_service_test.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`

**Interfaces:**
- Consumes: `CertificateConverter`, source/target enums, and conversion failures from Task 1.
- Produces: `CertificateConvertOperationRequest.fromText/fromBytes`, `CertificateConvertOutput`, and `CertificateConvertService.execute`.

- [ ] **Step 1: Write failing core contract tests**

  Pin text/byte request factories, every target, exact output bytes/text/counts, immutable result ownership, and ordered JSON:

  ```json
  {"sourceRepresentation":"pem","targetRepresentation":"der","text":null,"bytes":[...],"inputByteCount":778,"derByteCount":534,"outputByteCount":534}
  ```

  PEM/Base64 JSON must set `bytes` to null and contain exact `text`. Add redacted validation/resource mapping tests.

- [ ] **Step 2: Run the core test and verify it fails**

  Run: `dart test packages/chimera_core/test/certificate_convert_service_test.dart`

  Expected: FAIL because the service is missing.

- [ ] **Step 3: Implement the service and export it**

  `CertificateConvertService` delegates once to the converter, wraps success in `CertificateConvertOutput`, and maps only typed utility exceptions to `FailureKind.validation` / `FailureKind.resource` with message keys `error.certificateConvert.validation` / `.resource`.

- [ ] **Step 4: Run and commit Task 2**

  Run: `dart test packages/chimera_core/test`

  Expected: all core tests PASS.

  Commit: `feat: add certificate conversion service`

---

### Task 3: CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

**Interfaces:**
- Consumes: Task 2 service; existing byte readers and staged transactional output writer.
- Produces: `chimera certificate convert --from --to` with text/stdin/file, human/JSON, and optional exact save.

- [ ] **Step 1: Write failing parser and happy-path functional tests**

  Test every source kind, source representation, target representation, both locales, exact text stdout, DER save, canonical PEM/Base64 save, JSON shape/newline, optional save-before-stdout, and one direct result byte-list handoff. Assert DER without `--output`/`--json` exits 64 before reads.

- [ ] **Step 2: Run the CLI test and verify the command is absent**

  Run: `dart test apps/chimera_cli/test/functional/runner_test.dart`

  Expected: FAIL on missing `certificate convert`.

- [ ] **Step 3: Add localized keys and CLI routing**

  Add English/PT-BR usage, saved-result, validation, input/file/output access, and resource keys with exact parity. Parse `--from=auto|pem|der|base64`, required `--to=pem|der|base64`, and existing source/output/json options. Emit the design's stable adapter codes and validate all structure before I/O.

- [ ] **Step 4: Reuse transactional output and add AF-02 regressions**

  Route output through `_writeFileTransactionally`. Test partial stage, name collision, replacement, backup cleanup/restore, allocation, existing destination preservation, no artifacts, no success stdout, exits 64/74/75, and redaction of input/path/collaborator messages.

- [ ] **Step 5: Run and commit Task 3**

  Run: `dart test packages/chimera_l10n/test && dart test apps/chimera_cli/test`

  Expected: localization and CLI suites PASS.

  Commit: `feat: expose certificate conversion in cli`

---

### Task 4: Interactive conversion page

**Files:**
- Create: `apps/chimera_gui/lib/certificate_convert_page.dart`
- Create: `apps/chimera_gui/test/widgets/certificate_convert_test.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`
- Modify: `docs/operations/accessibility-review.md`

**Interfaces:**
- Consumes: Task 2 service and injectable file-picker, file-saver, clipboard-reader, clipboard-writer boundaries.
- Produces: localized `/certificate/convert` page and home action.

- [ ] **Step 1: Write failing widget happy-path tests**

  Cover Auto-to-PEM default, text/file/clipboard exclusivity, every selector, exact text result/copy/save, DER count-only presentation/save, default filenames, exact byte identity, route/home registration, and both locales.

- [ ] **Step 2: Run the widget test and verify the page is absent**

  Run: `flutter test apps/chimera_gui/test/widgets/certificate_convert_test.dart`

  Expected: FAIL because the page and route do not exist.

- [ ] **Step 3: Implement the page and dependency wiring**

  Mirror the established UC-18 source lifecycle and UC-17 save boundary. Clear stale result/notices on source or selector changes, guard async generations, disable racing actions, expose copy only for text targets, and hand the exact output byte list once to save. Cancellation preserves completed output; thrown/allocation failures map to localized access/resource errors.

- [ ] **Step 4: Add AF-01/AF-02, lifecycle, and accessibility tests**

  Cover invalid source/target, malformed input, picker/clipboard/save exceptions, allocation, neutral cancellation, stale async completion, no retained file/result on failure/dispose, focus order, keyboard activation, live regions, semantic labels, 48x48 targets, narrow layout, and 200% text. Update the manual accessibility evidence.

- [ ] **Step 5: Run and commit Task 4**

  Run: `dart test packages/chimera_l10n/test && flutter test apps/chimera_gui/test/widgets`

  Expected: localization and widget suites PASS.

  Commit: `feat: add certificate conversion page`

---

### Task 5: Native, browser, and Safari evidence

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

**Interfaces:**
- Consumes: the routed page and fixture-backed service from Tasks 1–4.
- Produces: representative target evidence on Windows/Linux, Chromium, Firefox, WebKit, and native Safari.

- [ ] **Step 1: Add failing native and compiled-browser flows**

  Exercise PEM-to-DER save and DER-to-PEM display/save, assert exact fixture equality, localized success semantics, and no unexpected external requests.

- [ ] **Step 2: Run affected platform suites and implement harness wiring**

  Run the repository's documented GUI integration and web commands for locally available targets. Expected: new flows PASS; unavailable Linux/Safari targets remain required CI gates, never skipped from CI.

- [ ] **Step 3: Commit Task 5**

  Commit: `test: cover certificate conversion targets`

---

### Task 6: Gate verification, review, and delivery

**Files:**
- Verify: all files changed by Tasks 1–5
- No README edit: the roadmap is an issue index with no status/done marker, and prior merged rows use no completion notation.

**Interfaces:**
- Consumes: complete implementation and test evidence.
- Produces: review-ready PR that closes issue #20.

- [ ] **Step 1: Verify Gate 2 traceability**

  Confirm main flow, AF-01, AF-02, FR-EN-05, FR-EN-17/18, FR-PL-01–06 and 09–11, BR-01–05/19, NFR-01–03, all representations, both locales, all affected targets, no-network, redaction, discard, and exact output ownership. Record any plan deviation.

- [ ] **Step 2: Run formatting, analysis, boundaries, and the exact full suite**

  Run `dart format --output=none --set-exit-if-changed apps packages test tests tool`, root and package analysis, `dart run tool/check_boundaries.dart`, `git diff --check`, then exact unfiltered `dart run melos run test:all`. Read all output; no filter, skip, or retry-to-green.

- [ ] **Step 3: Obtain independent whole-branch review**

  Review against the design, plan, issue, and `develop`; fix every Critical/Important finding with regression tests and rerun affected plus full gates within the batch retry budget.

- [ ] **Step 4: Push, open, and attach the pull request**

  Target `develop`, include `Closes #20`, test evidence, requirement mapping, review result, and noted design calls. Move the project item to Testing.

- [ ] **Step 5: Wait for all required CI checks, then squash merge**

  Merge only when branch-policy, every matrix job, and the aggregate cross-platform check are green and the PR is mergeable without required human approval. Never use admin, force, or self-approval. Delete the branch.

- [ ] **Step 6: Reconcile and continue**

  Verify issue #20 closed, project item Done, local/remote branch absent, clean `develop == origin/develop`, and the Definition of Done. Then start the next open issue in specification order.

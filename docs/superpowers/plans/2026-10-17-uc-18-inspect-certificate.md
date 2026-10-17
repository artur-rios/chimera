# UC-18 Inspect Certificate Implementation Plan

> **For implementers:** execute this plan with test-driven development, record
> each task boundary in the SDD ledger, and do not publish until independent
> whole-branch review is approved.

**Goal:** Inspect exactly one X.509 certificate supplied as PEM, DER, or
unarmored Base64 and return safe structural metadata through shared CLI,
desktop, and web paths without retaining or transmitting certificate data.

**Architecture:** `chimera_utilities` owns strict representation detection,
decoding, X.509 parsing, canonical-DER enforcement, metadata extraction, and
resource limits. `chimera_core` maps typed results and failures into one stable
JSON contract. CLI and GUI adapters own ephemeral source access, localization,
copying, and presentation. Native and browser suites exercise the same service
path and prove offline behavior.

**Tech stack:** Dart 3.13, `x509: 0.2.4+3`, `asn1lib: 1.6.5`, existing strict
Base64 utilities, Flutter, `package:test`, `flutter_test`, native Flutter
integration tests, and Playwright.

**Spec:**
`docs/superpowers/plans/2026-10-17-uc-18-inspect-certificate-design.md`

## Global Constraints

- Accept exactly one certificate. Reject empty, corrupt, truncated,
  noncanonical, multiple-object, private-key, CSR, chain, representation
  mismatch, URL-safe Base64, and trailing-byte input without fallback.
- Text accepts PEM or Base64 only; explicit DER text is
  `unsupported-representation`. Byte values outside `0..255` are `byte-range`.
- Auto detection follows the design's exact marker/alphabet rules. Explicit
  representation never falls back after failure.
- Return metadata only: no source, DER, signature bytes, public-key material,
  raw extension values, parser messages, paths, or collaborator exceptions.
- OIDs are authoritative dotted-decimal strings; friendly names are nullable
  best-effort values and unknown noncritical extensions remain valid.
- Timestamps are UTC ISO-8601 with millisecond precision; serial hex is
  uppercase and even-width; subject, issuer, and extensions preserve order.
- Utility validation failures use code `certificate-inspect.invalid-input`,
  field `input`, and the stable design reason. Resource failures use
  `certificate-inspect.resource-limit`. CLI exits are 64, 74, and 75.
- CLI performs structural validation before any stdin or file read, emits no
  partial stdout, and JSON output is the stable object plus one newline.
- GUI source modes are exclusive. Source/format changes, failures, and stale
  completions clear prior results and enabled result actions.
- Production is unbounded; injected limits exist only for deterministic tests.
- Every adapter is local-only and offline, uses the shared service, discards
  transient data, supports English and Brazilian Portuguese, and introduces no
  persistence, account, plugin, collaboration, or trust-service path.
- Tests use Given/When/Then names, hand-derived expectations, real behavior,
  and a witnessed red-to-green cycle before production implementation.

## Review Focus

- Parser boundaries: exact-one-object enforcement, strict complete DER framing,
  arbitrary-precision serials, auto-detection ambiguity, unknown OIDs, and safe
  exception translation.
- Privacy: no sensitive source/key/signature/extension values in results,
  diagnostics, widget semantics, logs, paths, or retained adapter state.
- Cross-adapter consistency: identical metadata and JSON shape from all three
  representations, exact exit/error mapping, and no divergent parsing logic.
- Race/resource behavior: limit checks precede allocation, GUI stale work
  cannot restore results, and failed reads/copies cannot leave success state.
- Cross-platform evidence: compiled Chromium, Firefox, WebKit, native Safari,
  Windows, and Linux all traverse the shared service and make zero unexpected
  network requests during inspection.

---

### Task 1: Add certificate fixtures and the shared inspector

**Files:**
- Modify: `packages/chimera_utilities/pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `packages/chimera_utilities/lib/src/certificate/certificate_inspector.dart`
- Modify: `packages/chimera_utilities/lib/chimera_utilities.dart`
- Create: `packages/chimera_utilities/test/certificate/certificate_inspector_test.dart`
- Create: `tests/fixtures/certificates/certificate.pem`
- Create: `tests/fixtures/certificates/certificate.der`
- Create: `tests/fixtures/certificates/certificate.base64`
- Create: `tests/fixtures/certificates/manifest.json`
- Create: `tests/fixtures/certificates/README.md`

**Interfaces:**
- Add enum `CertificateInputRepresentation { auto, pem, der, base64 }`.
- Add immutable `CertificateAttribute`, `CertificateAlgorithm`,
  `CertificateExtensionMetadata`, and `CertificateInspectionResult` values.
- Add `CertificateInspectionException` and
  `CertificateInspectionResourceException`, each exposing only stable `code`,
  `field`, and `reason` values.
- Add `const CertificateInspector({int? maxInputBytes, int? maxDecodedBytes})`,
  `inspectText(String input, {CertificateInputRepresentation representation =
  CertificateInputRepresentation.auto})`, and `inspectBytes(List<int> input,
  {CertificateInputRepresentation representation =
  CertificateInputRepresentation.auto})`.
- Produces the only parsing/detection/metadata implementation consumed by
  Task 2.

- [ ] Commit a deterministic public certificate fixture in all three forms,
  with no private key and a provenance/license README; pin hand-checked bytes
  and expected metadata in `manifest.json`.
- [ ] Add failing tests for PEM/DER/Base64 and both auto entry points; exact
  version, serial, ordered DN attributes, UTC validity, algorithms, extensions,
  counts, and equal metadata across representations.
- [ ] Add failing tests for explicit mismatches; empty/corrupt/truncated input;
  noncanonical/trailing DER; private key, CSR, chain, repeated/mixed PEM blocks;
  URL-safe/padding/pad-bit/non-ASCII Base64; byte-range validation; unknown OID
  name fallback; unknown noncritical extension tolerance; and exact
  input/decoded/allocation resource reasons.
- [ ] Run the focused utility test and witness missing-API failures.
- [ ] Add `x509: 0.2.4+3` and `asn1lib: 1.6.5`, fetch the lockfile, and
  implement the smallest detector, strict decoder reuse, lossless complete DER
  framing/minimal-length check, raw serial-byte extraction, transient PEM
  wrapping, single-certificate parser, safe OID lookup, metadata copy, limit
  checks, and exception translation. Do not use `X509Certificate.toAsn1()`;
  version 0.2.4+3 drops extensions and unique IDs when re-encoding.
- [ ] Run focused tests, strict utility analysis, formatting, and diff checks.
- [ ] Commit the fixture and shared utility layer.

### Task 2: Add the core service and stable serialization

**Files:**
- Create: `packages/chimera_core/lib/src/certificate_inspect_service.dart`
- Modify: `packages/chimera_core/lib/chimera_core.dart`
- Create: `packages/chimera_core/test/certificate_inspect_service_test.dart`

**Interfaces:**
- Add `CertificateInspectOperationRequest.fromText(...)` and
  `.fromBytes(...)`, each carrying the utility representation.
- Add immutable `CertificateInspectOutput` and ordered `toJson()` matching the
  design exactly.
- Add `CertificateInspectService` with injectable `CertificateInspector` and
  `execute(CertificateInspectOperationRequest request)` returning the existing
  core result/failure convention.
- Consumes Task 1 and produces the sole adapter-facing operation for Tasks 3-5.

- [ ] Add failing tests for text/byte factories, every representation, exact
  ordered JSON and UTC strings, immutable snapshots, and redacted mapping of
  every validation/resource reason.
- [ ] Run the focused core test and witness missing-API failures.
- [ ] Implement request/output values, metadata-only mapping, stable JSON, and
  typed utility-to-core failure conversion without parsing logic.
- [ ] Run focused core tests, strict core analysis, formatting, and diff checks.
- [ ] Commit the core layer.

### Task 3: Add the CLI command and localization

**Files:**
- Modify: `apps/chimera_cli/lib/src/runner.dart`
- Modify: `apps/chimera_cli/test/functional/runner_test.dart`
- Modify: `packages/chimera_l10n/lib/src/message_catalog.dart`
- Modify: `packages/chimera_l10n/test/message_catalog_test.dart`

**Interfaces:**
- Add `chimera certificate inspect` with exactly one of `--text=<value>`,
  `--stdin`, or `--file=<path>`; optional
  `--format=auto|pem|der|base64`; and optional `--json`.
- Human output is a deterministic localized metadata report. JSON is Task 2's
  exact object plus one newline. Validation/access/resource exits are
  respectively 64/74/75.

- [ ] Add failing functional tests for text/stdin/file, PEM/DER/Base64,
  auto/explicit formats, empty explicit text, human and exact JSON output,
  both locales, source conflicts, unknown options/format, and all structural
  validation before any stdin/file read.
- [ ] Add failing tests for AF-01 malformed/unsupported input, AF-02 unreadable
  file, every resource class, exits 64/74/75, no partial stdout, and diagnostics
  that exclude certificate values, raw input, file paths, parser text, and
  collaborator exception details.
- [ ] Run focused CLI/catalog tests and witness missing command/key failures.
- [ ] Implement command registration, strict source loading, service dispatch,
  localized human rendering, stable JSON rendering, and safe failure mapping.
- [ ] Run CLI/localization suites, affected-package analysis, formatting, and
  diff checks.
- [ ] Commit the CLI adapter.

### Task 4: Add the GUI route and interactions

**Files:**
- Create: `apps/chimera_gui/lib/certificate_inspect_page.dart`
- Modify: `apps/chimera_gui/lib/app.dart`
- Modify: `apps/chimera_gui/lib/router.dart`
- Modify: `apps/chimera_gui/test/widgets/app_test.dart`
- Modify: `docs/operations/accessibility-review.md`

**Interfaces:**
- Add `/certificate/inspect` and a localized home action.
- Provide exclusive multiline text, injected local-file load, and injected
  clipboard paste; an Auto/PEM/DER/Base64 selector; inspect; bounded selectable
  metadata; and copy of Task 2's exact JSON object.
- Copy writes the JSON object without an added display-only transformation; no
  save/output-file flow is introduced.

- [ ] Add failing widget tests for navigation, each source and representation,
  equal metadata, exact JSON copy, localized human metadata, AF-01/AF-02,
  file/clipboard/copy access and allocation failures, no sensitive semantics or
  diagnostics, and clearing stale result/source/action state after failure.
- [ ] Add failing tests for exclusive sources, representation/source switching,
  stale completion suppression, busy action disablement, focus/keyboard order,
  bounded result semantics, EN/PT-BR labels, contrast/tap evidence, and narrow
  layout at 200% text.
- [ ] Run focused widget tests and witness missing route/page failures.
- [ ] Implement the local-only page, injected adapters, route dependencies,
  home action, exact JSON copy, lifecycle cleanup, and accessibility evidence.
- [ ] Run widget tests, Flutter analysis, formatting, and diff checks.
- [ ] Commit the GUI layer.

### Task 5: Extend native and compiled-browser flows

**Files:**
- Modify: `apps/chimera_gui/integration_test/app_test.dart`
- Modify: `tests/web/smoke.spec.mjs`
- Modify: `tests/web/safari_smoke.dart`

**Interfaces:**
- Consumes Task 4's route, labels, source adapters, and result semantics.
- Produces representative native/browser evidence through Task 2's shared
  service with interaction-scoped zero-request assertions.

- [ ] Add Windows/Linux integration flows that inspect representative text and
  file sources and verify displayed metadata plus exact copied JSON.
- [ ] Add compiled Chromium/Firefox/WebKit flows for representative
  PEM/DER/Base64 sources, visible metadata, exact clipboard JSON, and zero
  unexpected HTTP(S) requests during interaction.
- [ ] Add an equivalent bounded native Safari flow using browser-created
  input/clipboard data where SafariDriver cannot perform direct file upload.
- [ ] Run affected native/browser suites and fix only evidence-backed defects.
- [ ] Commit the cross-platform evidence.

### Task 6: Gate verification and delivery

**Files:**
- Review: all UC-18 changes and requirement traceability.

- [ ] Run repository formatting and strict static analysis.
- [ ] Run focused utility/core/CLI/l10n/widget suites, affected native/browser
  suites, then exact unfiltered `dart run melos run test:all`.
- [ ] Verify main flow, AF-01, AF-02, FR-EN-04, FR-EN-17, FR-PL-01 through
  FR-PL-06, FR-PL-09 through FR-PL-11, BR-01 through BR-05, BR-19, both
  locales, offline behavior, redaction, exact metadata, and no persistence.
- [ ] Obtain independent whole-branch review and resolve every blocker with
  affected-suite reruns.
- [ ] Under the user's explicit unattended self-merging authorization, commit,
  push, open the issue-closing PR to `develop`, require green CI, squash merge,
  delete the branch, mark the issue Done, verify closure, and sync `develop`.

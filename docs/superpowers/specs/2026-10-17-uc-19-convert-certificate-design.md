# UC-19 Convert Certificate Design

## Intent and scope

UC-19 lets a developer or local automation convert exactly one X.509
certificate among PEM, DER, and unarmored Base64 without changing its DER
certificate content. Processing remains local, offline, deterministic, and
stateless. It covers FR-EN-05, FR-EN-17 through FR-EN-18, FR-PL-01 through
FR-PL-06, FR-PL-09 through FR-PL-11, BR-01 through BR-05, and BR-19.

The feature validates the same supported-certificate contract introduced by
UC-18, then changes only the outer representation. It does not re-sign,
re-serialize, normalize, repair, verify trust, download intermediates, process a
certificate chain, or expose private-key operations.

## Representation contract

The public source representation remains `CertificateInputRepresentation` with
`auto`, `pem`, `der`, and `base64`. A new
`CertificateOutputRepresentation` contains only `pem`, `der`, and `base64`, so
an automatic target is unrepresentable.

Source handling is identical to certificate inspection:

- text accepts PEM or unarmored Base64; explicit DER text is rejected;
- byte input accepts PEM, DER, or Base64 and supports automatic detection;
- PEM must contain exactly one `CERTIFICATE` block;
- Base64 is decoded by the existing strict shared decoder after permitted PEM
  whitespace removal; and
- decoded DER must pass the complete UC-18 framing and X.509 structure checks.

The inspector is refactored internally so inspection and conversion share one
decode-and-validate path. That path returns an internal parsed document holding
the detected source representation, exact decoded DER bytes, input byte count,
and validated ASN.1 structure. Inspection maps metadata from it; conversion
maps representation bytes from the same DER object. The public UC-18 inspection
result continues to expose no DER or signature material.

Conversion never asks `x509` or `asn1lib` to serialize the certificate. DER
output is the exact decoded DER byte sequence. Base64 output is canonical RFC
4648 text with required padding and no whitespace or trailing newline. PEM
output uses exactly these boundaries, LF line endings, 64-character Base64
lines, and one terminal LF:

```text
-----BEGIN CERTIFICATE-----
<canonical Base64 in 64-character lines>
-----END CERTIFICATE-----
```

Consequently, source wrapper whitespace and line endings may become canonical,
but decoding any successful output produces byte-for-byte identical DER.
Converting to the same explicit representation is allowed and canonicalizes the
wrapper while preserving DER content.

## Utility result and failures

`CertificateConverter` lives beside the certificate inspector in
`chimera_utilities` and consumes its shared internal parsed-document path. It
offers text and byte entry points with explicit source and target
representations. `CertificateConversionResult` exposes:

- detected `sourceRepresentation`;
- selected `targetRepresentation`;
- one immutable output `Uint8List`;
- `text`, computed only for PEM/Base64 targets;
- `inputByteCount`, `derByteCount`, and `outputByteCount`.

DER conversion reuses the validated DER list as the result list. PEM/Base64
conversion retains only the encoded output bytes; a text view is transient.
Nullable input, decoded-DER, and output budgets make exact resource boundaries
testable. Output length is checked before allocation. Allocation exhaustion is
translated to a typed resource failure with no partial output.

Stable conversion failures use these values:

- validation: code `certificate-convert.invalid-input`, field `input`, with the
  existing safe certificate reasons (`malformed-certificate`,
  `unsupported-representation`, `multiple-certificates`, or `byte-range`);
- resource: code `certificate-convert.resource-limit`, field `input` or
  `output`, with `input-limit`, `decoded-limit`, `output-limit`, or
  `allocation-limit`.

`input-limit`, `decoded-limit`, and allocation while reading/decoding use field
`input`. `output-limit` and allocation while encoding or producing a transient
text view use field `output`. The typed output enum makes an invalid utility
target unrepresentable; CLI/GUI string parsing reports code
`certificate-convert.invalid-input`, field `target`, reason
`unsupported-representation` before invoking the utility.

No parser message, source value, output value, or path crosses the failure
boundary.

## Core service and serialization

`chimera_core` owns `CertificateConvertOperationRequest`,
`CertificateConvertOutput`, and `CertificateConvertService`. Request factories
represent text or byte sources plus source and target representations. The
service delegates all detection, validation, and conversion to the shared
utility and maps only typed failures.

`CertificateConvertOutput.toJson()` has this ordered shape:

```json
{
  "sourceRepresentation": "pem",
  "targetRepresentation": "der",
  "text": null,
  "bytes": [48, 130, 2, 18],
  "inputByteCount": 778,
  "derByteCount": 534,
  "outputByteCount": 534
}
```

PEM/Base64 targets set `text` to the exact converted text and `bytes` to `null`.
DER sets `text` to `null` and serializes bytes only for the caller-requested JSON
view. Saving always receives the result's one output byte list directly. JSON
maps/lists are transient immutable snapshots and neither service retains data
after returning.

## CLI adapter

The CLI adds `chimera certificate convert` with exactly one source:

- `--text=<value>` for PEM or Base64 text, including an explicitly empty value
  that reaches certificate validation;
- `--stdin` for raw bytes; or
- `--file=<path>` for raw local-file bytes.

`--from=auto|pem|der|base64` defaults to `auto`.
`--to=pem|der|base64` is required. `--output=<path>` optionally saves exact
output bytes transactionally using the existing staged writer. A DER target
requires `--output` or `--json`, preventing arbitrary binary bytes from reaching
a text sink. Without an output path, PEM/Base64 human output is the exact
converted text with no adapter-added newline. A non-JSON save prints one
localized success line only after the transaction commits. JSON writes the
stable object plus one LF, after any requested save succeeds.

Unknown options, source cardinality, source representation, target
representation, and the DER destination rule are validated before stdin/file
access. Adapter validation uses `certificate-convert.invalid-options`,
`.missing-source`, `.conflicting-sources`, `.invalid-from`, `.invalid-to`, or
`.output-required` as applicable. Input or output access failure exits 74,
validation exits 64, and resource failure exits 75. A failed staged write
removes temporary artifacts, preserves any existing destination, emits no
success output, and retains no copy. Diagnostics in English and Brazilian
Portuguese contain only typed safe details.

## Interactive adapter

The GUI adds `/certificate/convert` and a localized home action. It provides a
multiline PEM/Base64 field, local certificate-file loading, clipboard paste, an
`Auto`/`PEM`/`DER`/`Base64` source selector, and a `PEM`/`DER`/`Base64` target
selector. The default is Auto to PEM. Typed/pasted text and a selected file are
exclusive. Changing either source or representation clears stale output,
notices, and enabled result actions. Racing actions are disabled while work is
in flight.

PEM/Base64 success displays selectable exact converted text with copy and save
actions. DER success displays only source representation, target
representation, and byte counts, with save available and no text-copy action.
Default save names are `chimera-certificate.pem`,
`chimera-certificate.der`, and `chimera-certificate.base64`. File, clipboard,
and save boundaries are injectable. Ordinary boundary exceptions become safe
access failures; allocation exhaustion becomes resource failure. A failed load,
convert, copy, or save clears stale success as applicable and keeps no source,
result, or app-retained copy. File-picker cancellation is neutral and preserves
an already completed result; a thrown picker/save failure clears stale notices
and reports access failure. GUI save guarantees are defined at the adapter
boundary: exact result bytes are handed off once and Chimera retains no second
copy. Desktop/browser file-picker implementations own the platform transaction;
the GUI does not claim path-level staging or rollback that browser downloads
cannot provide.

Focus order is certificate input, file, paste, source selector, target selector,
convert, result, copy when applicable, and save. Success semantics announce the
source and target representations and byte counts, never the certificate value.
Errors and notices are live regions. Both locales, keyboard operation, narrow
layout, 200% text, contrast guidance, and tap targets are covered.

## Cross-platform evidence

The public UC-18 certificate fixtures remain the source of truth. Conversion
tests compare every source/target pair by decoding the output and asserting
byte-for-byte equality with `certificate.der`. They also pin canonical Base64
and PEM formatting, explicit and automatic source handling, same-format
canonicalization, one-certificate enforcement, malformed/corrupt DER,
source/format mismatches, invalid target values at adapters, byte-range input,
exact budget boundaries, allocation mapping, and immutable ownership.

Core tests pin stable JSON and typed failure mapping. CLI tests cover
text/stdin/file, all source and target representations, human/JSON output,
transactional save success and rollback, both locales, validation-before-read,
redaction, exits, and no partial stdout. Widget tests cover text/file/clipboard,
both selectors, exact copy/save, binary presentation, stale-state cleanup,
localized failures, focus, accessibility, and responsive layout. Windows/Linux
integration and compiled Chromium/Firefox/WebKit/native Safari exercise a
representative PEM-to-DER or DER-to-PEM conversion, exact save/download, and
zero unexpected network requests.

## Gate 1 requirement audit

- Main flow and FR-EN-05: every source/target matrix entry validates once and
  produces a representation whose decoded DER exactly equals the fixture DER.
- AF-01 and FR-EN-17: malformed, corrupt, unsupported, multiple-object,
  source/representation mismatch, invalid target, and byte-range cases return
  typed redacted validation failures without partial output.
- AF-02 and FR-EN-18: CLI transactional-save tests inject partial and
  replacement failures, assert cleanup, and preserve an existing destination.
  GUI tests assert exact bytes are handed to the save adapter once, cancellation
  is neutral, thrown save failure is safe, and no app-retained copy remains.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, desktop, and web adapters use
  one converter contract with stable human/JSON results and documented exits.
- FR-PL-09 through FR-PL-11, NFR-01 through NFR-03, and BR-03 through
  BR-05/BR-19: no history, preference, account, plugin, collaboration, trust, or
  network path is added; browser flows reject unexpected external requests.
- The plan must sequence failing utility tests before the shared conversion,
  then core, CLI, localization, widget, native/browser, and full-suite evidence.

No traced requirement is dangling, each alternative flow has a concrete failure
path, and the externally visible contracts above leave no unresolved behavioral
choice for implementation.

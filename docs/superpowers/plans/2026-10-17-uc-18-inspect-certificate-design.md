# UC-18 Inspect Certificate Design

## Intent, scope, and traceability

UC-18 lets a developer or local automation inspect one X.509 certificate from
PEM, DER, or unarmored Base64 without transmitting or retaining certificate
data. It covers FR-EN-04, FR-EN-17, FR-PL-01 through FR-PL-06, FR-PL-09
through FR-PL-11, BR-01 through BR-05, and BR-19. One shared inspector is
consumed by core, CLI, desktop, and web adapters.

Inspection reports structural certificate metadata. It does not validate a
trust chain, consult revocation services, fetch issuer data, verify host names,
or claim that a certificate should be trusted. Those operations would require
policy and network inputs that UC-18 does not define and would conflict with
the local/offline boundary.

The standards-backed metadata baseline is the original X.509 ASN.1 structure:
certificate version, serial number, subject and issuer
distinguished-name attributes, validity interval, signature algorithm,
subject-public-key algorithm, and extension identifiers/criticality. The result
also reports the detected input representation, input byte count, and canonical
DER byte count. This is enough to make all three supported representations
observable without exposing certificate contents or inventing a product-specific
certificate schema.

## Shared inspection contract

`chimera_utilities` adds `x509: 0.2.4+3`, the current stable package version at
implementation time and the X.509 library named by the Technology Stack.
It also adds `asn1lib: 1.6.5`, the exact public ASN.1 dependency resolved by
that package, for the authoritative structural acceptance and metadata path.
`x509` supplies best-effort friendly OID names and safe isolated attribute-value
conversion only; its eager certificate/public-key parser is not an acceptance
gate. It owns `CertificateInspector`,
`CertificateInputRepresentation`, immutable metadata value types, and typed
inspection failures.

The public inspector has text and byte entry points. Both accept an explicit
representation of `auto`, `pem`, `der`, or `base64`; `auto` is the default.
Text input supports PEM and Base64 only. DER is inherently binary and text plus
an explicit DER representation returns a validation failure rather than
guessing at a character-to-byte mapping.

Automatic detection is deterministic:

1. Text whose first non-ASCII-whitespace content is
   `-----BEGIN CERTIFICATE-----` is PEM; all other text is Base64.
2. Byte input with that PEM marker is PEM.
3. Otherwise byte input containing only the standard Base64 alphabet, `=`, and
   ASCII whitespace is Base64.
4. All other byte input is DER.

An explicit representation never falls back to another representation after a
parse error. Public byte input validates every element is in `0..255` before
allocation or parsing. PEM accepts RFC 7468-style ASCII line wrapping but must
contain exactly one `CERTIFICATE` block and no other PEM object. Unarmored
Base64 ignores ASCII whitespace, then uses the existing canonical
`Base64ByteDecoder`; URL-safe characters, malformed padding, non-zero padding
bits, and non-ASCII data are rejected. DER must be one strictly framed,
complete certificate; trailing bytes, indefinite or nonminimal lengths, empty
input, private keys, certificate requests, chains, and multiple certificates
are rejected.

Before certificate parsing, DER bytes pass a lossless framing check over the
original bytes: one top-level `SEQUENCE` must consume the complete input, every
TLV must use a definite minimally encoded length, constructed values must end
exactly at their declared boundary, and no trailing object or byte is allowed.
The original ASN.1 view enforces exact Certificate, TBSCertificate, Validity,
AlgorithmIdentifier, and SubjectPublicKeyInfo field types/cardinalities,
including BIT STRING signature/public-key fields and the ordered optional TBS
fields. It supplies unsigned serial value bytes, source-ordered DN attributes
(including repeated OIDs within one RDN), correctly decoded base-128 OIDs, and
ordered extension metadata. Long serials and OID arcs remain exact on web.
Validity is decoded from its original bytes under RFC 5280: UTCTime years
00–49 mean 2000–2049, 50–99 mean 1950–1999; GeneralizedTime keeps its four-digit
year. Both require seconds and Z, and impossible calendar values are rejected.

Public-key and signature BIT STRING values remain opaque structural fields.
Ed25519 and unknown public-key algorithms return their OID with a nullable
friendly name; no key instantiation, signature verification, or trust decision
is performed. `x509.parsePem` is deliberately not called because version
0.2.4+3 eagerly constructs only RSA/EC keys and would reject structurally valid
algorithms. `X509Certificate.toAsn1()` is also not called because that version
loses extensions and unique IDs. Parser objects and transient text/DER views
remain call-scoped and become unreachable before immutable metadata returns.

Optional injectable `maxInputBytes` and `maxDecodedBytes` budgets provide
deterministic resource-boundary tests while production remains unbounded, as
required by the project's validation constraints. Input size is checked before
text or decode allocation. Base64 decoded size is checked by the shared decoder
before allocation. Allocation exhaustion maps to a typed resource failure and
never returns partial metadata.

## Metadata model

The utility result contains:

- detected `representation` (`pem`, `der`, or `base64`; never `auto`);
- one-based X.509 `version` (`1`, `2`, or `3`);
- uppercase, even-width `serialNumberHex` with no `0x` prefix;
- ordered immutable `subject` and `issuer` attribute lists, each attribute
  containing dotted-decimal `oid`, nullable friendly `name`, and `value`;
- UTC `notBefore` and `notAfter` instants;
- `signatureAlgorithm` and `publicKeyAlgorithm`, each with dotted-decimal
  `oid` and nullable friendly `name`;
- ordered immutable `extensions`, each with dotted-decimal `oid`, nullable
  friendly `name`, and `critical`;
- `inputByteCount` and `derByteCount`.

OID friendly-name lookup is best effort. An unknown name produces `null` while
the required dotted-decimal OID remains present; an unknown noncritical
extension therefore does not make an otherwise supported certificate fail.
Distinguished-name values are copied to strings in source order. No signature
bytes, key coordinates/modulus, raw extension values, source text, or DER bytes
are retained or returned.

Stable utility failure reasons are:

- `malformed-certificate` for empty, corrupt, truncated, noncanonical, or
  otherwise unparseable certificate input;
- `unsupported-representation` for a source/representation mismatch or PEM
  content that is not exactly one certificate;
- `multiple-certificates` for chains or repeated certificate blocks;
- `byte-range` for a public byte-list member outside `0..255`;
- `input-limit`, `decoded-limit`, or `allocation-limit` for resource failure.

All validation failures use code `certificate-inspect.invalid-input`, field
`input`, and a safe reason only. Resource failures use code
`certificate-inspect.resource-limit`, field `input`, and a safe reason. Parser
messages and certificate values never cross the utility boundary.

## Core service and stable serialization

`chimera_core` owns `CertificateInspectOperationRequest`,
`CertificateInspectOutput`, and `CertificateInspectService`. Request factories
represent text or bytes plus the utility-owned representation. The service
delegates all detection, decoding, parsing, and metadata mapping to the shared
inspector and converts only typed failures.

`CertificateInspectOutput.toJson()` uses this ordered shape:

```json
{
  "representation": "pem",
  "version": 3,
  "serialNumberHex": "01AB",
  "subject": [{"oid": "2.5.4.3", "name": "commonName", "value": "example.test"}],
  "issuer": [{"oid": "2.5.4.3", "name": "commonName", "value": "Example CA"}],
  "notBefore": "2024-01-01T00:00:00.000Z",
  "notAfter": "2034-01-01T00:00:00.000Z",
  "signatureAlgorithm": {"oid": "1.2.840.113549.1.1.11", "name": "sha256WithRSAEncryption"},
  "publicKeyAlgorithm": {"oid": "1.2.840.113549.1.1.1", "name": "rsaEncryption"},
  "extensions": [{"oid": "2.5.29.19", "name": "basicConstraints", "critical": true}],
  "inputByteCount": 1099,
  "derByteCount": 771
}
```

Nested list/map objects are immutable snapshots of metadata only. ISO timestamps
are always UTC with millisecond precision. JSON construction is transient and no
service or diagnostic sink retains source or result data.

## CLI adapter

The CLI adds `chimera certificate inspect` with exactly one source:

- `--text=<value>` for PEM or unarmored Base64 text, including an explicitly
  selected empty value that then fails certificate validation;
- `--stdin` for raw bytes; or
- `--file=<path>` for raw local-file bytes.

`--format=auto|pem|der|base64` is optional and defaults to `auto`. `--json`
selects the stable JSON object followed by exactly one newline. Human output is
a deterministic localized metadata report with no certificate source or raw
cryptographic material. Structural validation—unknown options, exact source
cardinality, and format value—finishes before stdin or file access. File-read
failures use exit 74; validation uses 64; resource failure uses 75. No partial
stdout is emitted before a complete inspection and complete formatting pass.
Diagnostics are localized in English and Brazilian Portuguese and never echo
certificate input, file paths, parser text, or collaborator exception details.

## Interactive adapter

The GUI adds `/certificate/inspect` and a localized home action. It provides a
multiline PEM/Base64 field, local certificate-file loading, clipboard paste, and
an `Auto`/`PEM`/`DER`/`Base64` representation selector. Typed/pasted text and a
selected file are exclusive. Changing source or representation clears stale
metadata, notices, and enabled result actions; racing actions are disabled while
work is in flight.

Success renders a bounded, selectable metadata region with the representation,
version, serial, ordered subject/issuer attributes, UTC validity, algorithms,
and extensions. A copy action writes the exact stable JSON object to the local
clipboard. The GUI does not save or persist metadata because UC-18 defines no
output-file flow. File and clipboard adapters are injectable. Input/read or copy
allocation exhaustion maps to resource failure; other file/clipboard exceptions
map to access failure. A failed load, inspect, or copy clears stale success and
retains no source/result copy.

Focus order is certificate input, file, paste, representation, inspect, result,
and copy. Success semantics announce the representation and metadata counts,
not certificate values. Errors are live regions. Both locales, keyboard
operation, narrow layout, 200% text, contrast guidance, and tap targets are
covered.

## Cross-platform evidence

A committed public test certificate fixture under
`tests/fixtures/certificates/` supplies exact PEM, DER, and Base64 forms and a
documented metadata manifest. It contains no private key. Utility tests cover all
three representations, auto detection, explicit mismatches, one-certificate
enforcement, unknown noncritical extension tolerance, canonical DER, ordering,
OID fallback, byte validation, and resource boundaries. Core tests pin the
stable JSON and redacted failure mapping.

CLI tests cover text/stdin/file, each representation, auto/explicit formats,
human/JSON output, both locales, validation-before-read, AF-01 malformed or
unsupported input, AF-02 file access, resource failures, exits, redaction, and
no partial stdout. Widget tests cover text/file/clipboard, representation/source
switching, exact copy, localized failures, stale-state cleanup, focus,
accessibility, and responsive layout. Windows/Linux integration and compiled
Chromium/Firefox/WebKit/native Safari exercise representative certificate
inspection through the shared service and assert no unexpected network requests.

## Requirement audit

- FR-EN-04/main flow: fixture-backed utility, core, CLI, GUI, native, and browser
  tests prove PEM, DER, and Base64 inspection with one metadata contract.
- FR-EN-17/AF-01: malformed, unsupported, corrupt, noncanonical, multiple-object,
  and source/representation mismatch cases return typed redacted validation
  failures with no partial metadata.
- AF-02: CLI and GUI file adapters map read failures to safe file-access errors
  and clear stale results.
- FR-PL-01 through FR-PL-06 and BR-02: every adapter calls the same service;
  CLI sources, stable JSON, human output, and exits are documented and tested.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: no input/result
  history, preference, account, plugin, collaboration, trust-service, or network
  path is added; browser flows explicitly assert zero unexpected requests.

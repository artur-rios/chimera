# UC-25 JWT Inspect Design

## Intent and scope

UC-25 decodes compact signed JSON Web Tokens and optionally verifies their
signatures entirely on the local device. It covers FR-EN-11, FR-EN-12,
FR-EN-17, FR-PL-01 through FR-PL-06, and FR-PL-09 through FR-PL-11. The
implementation never accepts the unsecured `none` algorithm, never resolves
keys from the token or network, and never logs tokens, claims, keys, or decoded
output.

## Canonical inspection contract

The shared inspector accepts compact JWT text and an optional local key. It
requires exactly three non-empty, unpadded, canonical Base64url segments. The
protected header and payload must be UTF-8 JSON objects; arrays, scalars,
duplicate object members at any depth, malformed text, and invalid Unicode are
rejected. Numbers must be finite so every successful result remains valid JSON.
The signature must decode as non-empty bytes.

The protected `alg` member must be a string and one of `HS256`, `HS384`,
`HS512`, `RS256`, `RS384`, `RS512`, `ES256`, `ES256K`, `ES384`, or `ES512`.
`none`, missing or malformed algorithms, `b64: false`, unsupported critical
headers, and `jwk`, `jku`, `x5u`, `x5c`, `x5t`, or `x5t#S256` key-selection
headers are rejected. This prevents algorithm confusion, detached payloads,
and any implicit key discovery.

Without a key, the result contains the decoded header and claims with
verification status `not-requested`. With a key, the inspector verifies only
the algorithm named by the protected header. HMAC accepts a compatible `oct`
JWK or raw UTF-8 secret at least as long as the hash output. RSA and ECDSA
accept compatible public or private JWK/PEM material. For JWK input, a present
`alg` must equal the protected algorithm, a present `use` must be `sig`, and a
present `key_ops` must contain `verify`. A token `kid` is a key-selection hint:
it must equal a JWK `kid` when both exist, but it does not reject an explicitly
supplied single JWK, PEM, or raw secret that has no ID. Restricted,
wrong-family, wrong-curve, malformed, or conflicting-key-ID keys fail before
verification.

PEM support is deliberately the set parsed locally by `jose`:
SubjectPublicKeyInfo public keys, X.509 certificates, and unencrypted PKCS#1
RSA, PKCS#8 RSA/EC, or SEC1 EC private keys. PKCS#1 RSA public-key PEM and
encrypted private-key PEM are rejected as unsupported key material rather than
sent to another parser or service.

The inspector enforces the HMAC minimums and the approved ECDSA curve for each
algorithm. It does not invent an RSA modulus/exponent policy absent from the
requirements: RSA verification reports mathematical signature validity for a
locally supplied compatible key, including legacy keys. This is not a claim
that the signer used a currently recommended key strength.

A valid signature returns status `verified`. A cryptographically well-formed
but non-matching signature implements AF-02 by returning the parsed header and
claims with status `failed`; these values are explicitly untrusted. AF-02 is a
completed inspection result, so CLI execution succeeds and automation must
inspect the status field. Token/key parsing errors, unsupported forms, and
cryptographic dependency failures remain typed failures with no partial
result.

Mutable Base64, signing-input, signature, and raw-secret byte copies are
cleared in `finally` blocks. Dart strings and immutable maps cannot be reliably
overwritten, so interface adapters clear controllers, undo history, and
results at lifecycle boundaries and never persist or log them. Returned JSON
maps and lists are recursively immutable.

Stable failures use field `token` or `key`:

- `jwt-inspect.invalid-token` is a validation failure for malformed structure,
  encoding, JSON, headers, payloads, or signatures;
- `jwt-inspect.unsupported-algorithm` is a validation failure;
- `jwt-inspect.invalid-key` and `jwt-inspect.incompatible-key` are validation
  failures with safe reasons only;
- `jwt-inspect.verification-failed` is a processing failure for an unexpected
  cryptographic dependency failure, distinct from AF-02; and
- `jwt-inspect.resource-limit` is a resource failure.

No diagnostic contains input, output, dependency messages, or key metadata.
Production inspection limits each token or key source to 1 MiB, total decoded
JWT material to 768 KiB, and JSON nesting to 64 containers. CLI streams and
files and GUI files reject oversized sources before parsing; all adapters also
enforce the byte boundary after a collaborator returns. Injected budgets and a
verification seam provide deterministic resource and processing tests.

## Shared implementation

`chimera_utilities` owns `JwtInspectRequest`, `JwtInspectResult`,
`JwtVerificationStatus`, typed exceptions, and `JwtInspector`. JWT creation and
inspection share one internal strict JSON decoder so duplicate-member and
Unicode rules cannot drift. The `jose` package supplies key parsing and
cryptographic verification.

`chimera_core` owns `JwtInspectOperationRequest`, `JwtInspectOutput`, and
`JwtInspectService`, mapping utility failures to the existing result model.
Its stable ordered JSON representation is:

```json
{
  "header": {"alg": "HS256", "typ": "JWT"},
  "claims": {"sub": "123"},
  "verification": "verified"
}
```

## CLI adapter

The CLI exposes:

```text
chimera jwt inspect
  (--token=<jwt>|--token-file=<path>|stdin)
  [--key=<text>|--key-file=<path>]
  [--json]
```

Exactly one token source and at most one key source are accepted. Structural
options are validated before file or standard-input access. Files and stdin
use strict UTF-8. Human output prints compact header and claims JSON plus a
localized verification label; JSON output uses the stable core shape and one
terminal LF. Validation exits 64, unexpected processing exits 70, access exits
74, and resource failures exit 75. AF-02 exits zero with
`verification: failed`. All errors in both locales are redacted.

## Interactive adapter

The GUI exposes `/jwt/inspect` and a localized home action. It provides token
and optional verification-key editors with file and clipboard sources; the key
editor is obscured. Success displays formatted header and claims with a
localized `not requested`, `verified`, or prominently warned `failed` status.
The failed state describes the parsed data as untrusted. A copy action writes
the complete stable JSON result.

Source changes clear stale results. Operations disable competing actions and
use generation guards. Cancellation is neutral. File, clipboard, service, and
copy failures publish localized safe messages. Token and key editors and undo
histories are cleared after every attempt; decoded claims are cleared after a
copy failure, source change, or navigation. Focus order, live regions, keyboard
operation, 48-by-48 targets, narrow layout, 200-percent text, both locales, and
contrast follow existing application patterns.

## Verification

Known-answer HMAC tests and independently signed RSA/ECDSA fixtures cover every
supported family. Negative tests cover malformed/corrupt segments, duplicate
members, invalid Unicode, reserved headers, `none`, weak HMAC and
wrong/restricted keys,
non-finite numbers, excessive nesting, signature mismatch, allocation failure,
dependency failure, redaction,
repeated calls, and absence of partial results. Core, CLI, widget, native,
Chromium, Firefox, WebKit, and native Safari tests cover decode-only, verified,
explicitly failed/untrusted, source variants, discard, accessibility, and zero
external requests.

No main flow, alternative flow, or traced requirement is deferred.

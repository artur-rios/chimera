# UC-24 JWT Create Design

## Intent and scope

UC-24 creates and signs JSON Web Tokens entirely on the local device. It
covers FR-EN-10, FR-EN-12, FR-EN-17, FR-PL-01 through FR-PL-06, and FR-PL-09
through FR-PL-11. The implementation never accepts the unsecured `none`
algorithm, never sends data over the network, and never logs headers, claims,
keys, or tokens.

## Canonical signing contract

The shared signer accepts a header JSON object, a claims JSON object, an
algorithm, and key text. Supported algorithms are `HS256`, `HS384`, `HS512`,
`RS256`, `RS384`, `RS512`, `ES256`, `ES256K`, `ES384`, and `ES512`. Algorithm
names are case-sensitive. Header and claims must be UTF-8 JSON objects; arrays,
scalars, duplicate or non-finite values, and malformed text are rejected.

The selected algorithm owns the protected `alg` header. A supplied `alg` must
match it. `typ` defaults to `JWT` when absent. `b64: false`, unsupported
critical headers, and key-selection headers that conflict with the supplied
key are rejected rather than silently reinterpreted.

HMAC algorithms accept either an `oct` private JWK or a raw UTF-8 secret whose
length is at least the hash output size. RSA and ECDSA algorithms accept private
JWK or private PEM. Public-only, malformed, restricted, wrong-family, wrong-
curve, or otherwise incompatible keys fail before signing. The `jose` package
performs JWS construction and cryptographic signing; dependency exceptions and
messages never cross the utility boundary.

The compact JWT is returned only after complete signing. Mutable input byte
copies are cleared in `finally` blocks and all references are released after
the operation. Dart strings cannot be guaranteed to be overwritten, so
adapters clear controllers, undo history, and results at lifecycle boundaries
and never persist or log sensitive values.

Stable failures use field `header`, `claims`, `algorithm`, `key`, or `token`:

- `jwt-create.invalid-header`, `jwt-create.invalid-claims`, and
  `jwt-create.invalid-algorithm` are validation failures;
- `jwt-create.invalid-key` and `jwt-create.incompatible-key` are validation
  failures with safe reasons only;
- `jwt-create.signing-failed` is a processing failure; and
- `jwt-create.resource-limit` is a resource failure.

No diagnostic contains input, output, dependency messages, or key metadata.
Injected byte budgets and a signing seam provide deterministic resource and
processing tests without imposing a production size ceiling.

## Shared implementation

`chimera_utilities` owns `JwtCreateRequest`, `JwtCreateResult`, typed
exceptions, and `JwtCreator`. `chimera_core` owns `JwtCreateOperationRequest`,
`JwtCreateOutput`, and `JwtCreateService`, mapping utility failures to the
existing result model. Its ordered JSON representation is `{ "token": "..." }`.

## CLI adapter

The CLI exposes:

```text
chimera jwt create --algorithm=<name>
  [--header=<json>|--header-file=<path>]
  (--claims=<json>|--claims-file=<path>|stdin)
  (--key=<text>|--key-file=<path>)
  [--output=<path>] [--json]
```

The header defaults to `{}`. Exactly one claims source and one key source are
accepted. Structural options are validated before file or standard-input
access. Files and stdin use strict UTF-8. Human stdout is the exact compact JWT
without an added newline; JSON has one terminal LF. Output files use the
existing transactional writer. Validation exits 64, processing exits 70,
access exits 74, and resource failures exit 75. Errors in both locales are
redacted.

## Interactive adapter

The GUI exposes `/jwt/create` and a localized home action. It provides
algorithm selection plus header, claims, and key editors with file and
clipboard sources. The key editor is obscured. Success presents the compact
token with copy and save actions; save uses `chimera-jwt.txt` and
`application/jwt`.

Source changes clear stale results. Operations disable competing actions and
use generation guards. Cancellation is neutral. File, clipboard, service,
copy, and save failures publish localized safe messages. Header, claims, and
key editors and their undo histories are cleared after every signing attempt;
the token is cleared after copy/save failure, source changes, or navigation.
Focus order, live regions, keyboard operation, 48-by-48 targets, narrow layout,
200-percent text, both locales, and contrast follow existing application
patterns.

## Verification

Known-answer HMAC tests and independent verification of RSA/ECDSA tokens cover
every supported family. Negative tests cover malformed JSON, reserved headers,
weak/wrong/public-only keys, unsupported algorithms, corruption, allocation,
redaction, repeated calls, and no partial result. Core, CLI, widget, native,
Chromium, Firefox, WebKit, and native Safari tests cover source/output variants,
transactionality, discard, accessibility, and zero external requests.

No main flow, alternative flow, or traced requirement is deferred.

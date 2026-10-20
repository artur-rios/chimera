# UC-38 Encode with Cipher Design

## Scope and operation contract

Encode ephemeral text locally with the approved classical-cipher baseline:
Caesar, ROT13, Vigenere, Atbash, Affine, Bacon, and Rail Fence. One shared
implementation serves CLI, desktop, and browser adapters. Inputs, keys,
parameters, and results are never logged, persisted as history, or sent over a
network, and adapters discard operation state after replacement, failure, or
disposal.

The selected cipher alphabet is ASCII `A` through `Z`. ASCII case is retained.
Every request explicitly selects an unsupported-character policy:

- `preserve` leaves every non-ASCII-letter Unicode scalar unchanged; or
- `reject` returns a typed `unsupportedSymbol` failure containing only its
  zero-based Unicode-scalar position, never the symbol or surrounding input.

Empty text is valid. Unknown ciphers, policies, stray parameters, missing
parameters, malformed integers, and invalid parameter values are typed
validation failures with no partial output.

## Algorithms and parameters

- **Caesar:** requires an integer shift from 0 through 25 and rotates letters
  forward while retaining case.
- **ROT13:** is an explicit parameter-free Caesar variant with shift 13.
- **Vigenere:** requires a non-empty ASCII-letter key. Key case is ignored and
  the key advances only for supported input letters.
- **Atbash:** is parameter-free and maps `A` to `Z`, `B` to `Y`, and so on.
- **Affine:** requires integer `a` and `b` values from 0 through 25. `a` must be
  coprime with 26; encoding is `(a*x + b) mod 26`.
- **Bacon:** is the unambiguous 26-letter binary variant (`A = AAAAA` through
  `Z = BBAAB`). Uppercase plaintext emits uppercase `A/B`; lowercase plaintext
  emits lowercase `a/b`. No separators are inserted, so preserved whitespace
  and symbols remain exact and UC-39 can recover letter case deterministically.
- **Rail Fence:** requires at least two rails. It permutes the sequence of
  supported letters in the standard down/up zigzag, then writes those letters
  back into the original supported-letter positions. Preserved symbols
  therefore remain at their exact positions. A rail count greater than or equal
  to the supported-letter count is a valid no-op and does not allocate one
  buffer per unused rail.

These rules and known-answer fixtures are published in
`docs/reference/cipher-rules.md` so the later decode use case consumes the same
contract rather than inventing a second interpretation.

## Shared layers and failures

`CipherEncoder` in `chimera_utilities` owns typed algorithm selection,
parameter validation, Unicode-scalar traversal, and pure encoding.
`CipherEncodeService` in `chimera_core` maps raw adapter values into immutable
requests and redacted `ChimeraResult` outcomes. Unexpected processing errors
become processing failures and allocation errors become resource failures;
neither exposes input or key material.

CLI adds `chimera cipher encode` with argument, standard-input, and local-file
sources plus `--cipher`, `--character-policy`, algorithm-specific options,
`--output`, and `--json`. Stable JSON identifies the selected cipher and policy
but never echoes a key. GUI adds `/cipher/encode` with source text/file/
clipboard controls, algorithm and policy selectors, conditional parameter
fields, Encode, Copy, and Save actions. Configuration changes invalidate prior
results and notices, and stale asynchronous completions cannot republish them.

All user-facing labels and diagnostics are complete in English and Brazilian
Portuguese. Controls are keyboard reachable, responsive, and expose result and
error semantics suitable for assistive technology.

## Verification and traceability

Known-answer unit fixtures cover every cipher, uppercase/lowercase behavior,
empty and Unicode input, parameter boundaries, preserved symbols, exact scalar
positions for rejected symbols, and large Rail Fence keys. Service tests cover
redacted typed mappings and immutability. CLI and GUI tests cover each source,
both interface locales, human/JSON output, transactional save/copy, invalid and
stray options, access/resource failures, offline operation, discard, and stale
completion behavior.

Native and browser journeys exercise representative algorithms, both character
policies, AF-01 and AF-02, exact transfer, accessibility, and unexpected-network
detection on Windows, Linux, Chromium, Firefox, WebKit, and Safari. This traces
FR-CA-01, FR-CA-03 through FR-CA-04, FR-CA-08, FR-PL-01 through FR-PL-06,
FR-PL-09 through FR-PL-11, BR-01 through BR-05, BR-14, BR-15, and BR-19.

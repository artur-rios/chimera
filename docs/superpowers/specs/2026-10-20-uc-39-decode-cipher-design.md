# UC-39 Decode with Cipher Design

## Intent and scope

Decode ephemeral text locally with the same approved classical-cipher baseline
as UC-38: Caesar, ROT13, Vigenere, Atbash, Affine, Bacon, and Rail Fence. One
shared implementation serves CLI, desktop, and browser adapters. Input, keys,
parameters, and results are never logged, retained as history, or sent over a
network; adapters discard operation state after replacement, failure, or
disposal.

The selected alphabet remains ASCII `A` through `Z`, with ASCII case retained.
Every request explicitly selects one unsupported-character policy:

- `preserve` leaves non-cipher Unicode scalars unchanged; or
- `reject` returns a typed failure containing only the zero-based Unicode-scalar
  position, never the symbol or surrounding input.

Empty text is valid. Unknown ciphers or policies, stray or missing parameters,
malformed integers, invalid parameter values, malformed cipher text, and
ambiguous Bacon input return typed validation failures with no partial output.

## Algorithms and parameters

- **Caesar:** requires `shift` from 0 through 25 and rotates letters backward.
- **ROT13:** is its own inverse and accepts no parameters.
- **Vigenere:** requires a non-empty ASCII-letter key, subtracts repeated key
  offsets, ignores key case, and advances the key only for supported letters.
- **Atbash:** is its own inverse and accepts no parameters.
- **Affine:** requires `a` and `b` from 0 through 25 with `gcd(a, 26) = 1`, then
  applies `a^-1 * (y - b) mod 26`.
- **Bacon:** accepts only complete five-letter `A/B` or `a/b` groups. A group
  must have uniform case, represent a value from 0 through 25, and may be
  separated from another group by preserved symbols. A symbol inside a partial
  group, an incomplete group, a mixed-case group, or values 26 through 31 are
  typed ambiguous-input failures. The group's case determines decoded case.
- **Rail Fence:** requires at least two rails, derives the down/up zigzag row
  pattern from the supported-letter count, partitions the ciphertext by row,
  and reconstructs the original supported-letter sequence. Preserved symbols
  stay at their exact scalar positions. A rail count at least as large as the
  supported-letter count is a valid no-op without proportional allocation.

These decoding rules and inverse known-answer fixtures extend
`docs/reference/cipher-rules.md`, keeping encode and decode definitions together.

## Shared layers and failures

`CipherDecoder` in `chimera_utilities` owns typed algorithm selection,
parameter validation, Unicode-scalar traversal, and pure decoding. It reuses the
existing cipher algorithm, policy, and failure types. `CipherDecodeService` in
`chimera_core` maps raw adapter values into immutable requests and redacted
`ChimeraResult` outcomes. Unexpected processing errors become processing
failures and allocation errors become resource failures; neither exposes input
or key material.

CLI adds `chimera cipher decode` with argument, standard-input, and local-file
sources plus `--cipher`, `--character-policy`, algorithm-specific options,
`--output`, and `--json`. Stable JSON identifies the cipher and policy without
echoing keys. GUI adds `/cipher/decode` with text/file/clipboard input,
algorithm and policy selectors, conditional parameter fields, Decode, Copy, and
Save actions. Configuration changes invalidate results and notices; stale async
completions cannot restore discarded state.

All user-facing labels and diagnostics are complete in English and Brazilian
Portuguese. Controls remain keyboard reachable, responsive at 200% text scale,
at least 48 logical pixels where actionable, and expose result/error semantics
for assistive technology.

## Verification and traceability

Known-answer and round-trip unit fixtures cover every cipher, case behavior,
empty and Unicode input, parameter boundaries, preserved symbols, exact scalar
positions, malformed and ambiguous Bacon input, and very large Rail Fence keys.
Service tests cover UTF-8, redacted typed mappings, resource/processing failures,
and immutable inputs. CLI and GUI tests cover every source, both locales,
human/JSON output, transactional save/copy, invalid and stray options, access
failures, offline operation, discard, and stale completions.

Native and browser journeys cover a representative inverse, both character
policies, AF-01, AF-02, exact transfer, accessibility, and unexpected-network
detection on Windows, Linux, Chromium, Firefox, WebKit, and Safari. This traces
FR-CA-02 through FR-CA-04, FR-CA-08, FR-PL-01 through FR-PL-06, FR-PL-09
through FR-PL-11, BR-01 through BR-05, BR-14, BR-15, and BR-19.

## Explicit non-goals

This use case does not add new cipher families, custom alphabets, cryptographic
security claims, automatic cipher detection, key recovery, network services,
history, or persistent operation data.

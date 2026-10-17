# UC-11 Unescape Text Design

## Scope and traceability

UC-11 unescapes text in JSON, Unicode, C-style, HTML, or URL mode. It covers
FR-TX-03, FR-TX-11, FR-PL-01 through FR-PL-06, FR-PL-09 through FR-PL-11,
BR-01 through BR-05, and BR-19. The implementation remains local and
stateless. One shared utility contract is consumed by the core service, CLI,
desktop GUI, and compiled web application.

## Shared model and decoding contract

`chimera_utilities` owns a `TextUnescaper` with the canonical string modes
`json`, `unicode`, `c`, `html`, and `url`. Aliases and unsupported modes are
rejected. Empty input is valid. Successful results contain decoded text rather
than language-level wrapper quotes.

The decoder is strict wherever a mode-specific introducer appears, while
ordinary text is preserved:

- JSON recognizes `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`, and
  exactly four hexadecimal digits after `\u`. Raw C0 control characters and
  incomplete or unknown escapes are rejected. UTF-16 surrogate code units are
  decoded deterministically, including canonical pairs emitted by UC-10.
- Unicode recognizes `\uXXXX` and `\UXXXXXXXX` in otherwise literal text.
  The uppercase form must identify a Unicode scalar value; incomplete,
  non-hexadecimal, out-of-range, and surrogate scalar values are rejected.
- C-style recognizes reverse solidus, both quote kinds, question mark, bell,
  backspace, form feed, newline, carriage return, tab, and vertical-tab short
  escapes; one-to-three-digit octal escapes; exactly two-digit `\xHH`; exactly
  four-digit `\uXXXX`; and exactly eight-digit scalar `\UXXXXXXXX`. Unknown,
  incomplete, out-of-range, and malformed sequences are rejected.
- HTML recognizes `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&#39;`, and decimal
  or hexadecimal numeric character references. Every ampersand begins a
  reference and therefore unknown, unterminated, out-of-range, or surrogate
  references are rejected.
- URL decodes strict `%HH` octets as UTF-8 while preserving literal text.
  Incomplete percent escapes, non-hexadecimal octets, and malformed UTF-8 are
  rejected. A plus sign remains a plus because this is RFC 3986 component
  decoding, not form decoding.

Malformed input reports the zero-based UTF-16 offset of the failing sequence.
Nullable injected input/output character budgets exist only for deterministic
resource tests. Budget exhaustion or `OutOfMemoryError` becomes a typed
resource failure without exposing a partial result.

## Service and failure contract

`chimera_core` maps the utility request to `TextUnescapeOutput`, whose stable
JSON fields are `unescaped` and `mode`. Stable failures are:

- `text-unescape.invalid-mode`, field `mode`, reason `unsupported-mode`;
- `text-unescape.malformed-input`, field `input`, a mode-specific reason, and
  zero-based `offset`;
- `text-unescape.resource-limit`, field `input` or `unescaped`, reason
  `input-limit` or `output-limit`.

Core message keys are `error.textUnescape.validation` and
`error.textUnescape.resource`. Interface access failures use
`text-unescape.input-access`, `text-unescape.file-access`,
`text-unescape.output-access`, `text-unescape.clipboard-read`, and
`text-unescape.clipboard-write`. Diagnostics never contain source text.

## Interface behavior

The CLI command is `chimera text unescape --mode <mode>`. Exactly one input
source is accepted: `--input`, `--file`, or standard input. `--output` writes
the exact UTF-8 decoded text to a local file; `--json` returns a stable envelope
with `unescaped` and `mode`. Validation exits with 64, input/output access with
74, and resource failure with 75. Failed output writes emit no success result.

The GUI exposes `/text/unescape` with multiline input, local text-file load,
clipboard paste, mode selection, explicit decode action, selectable output,
copy, and save. It defaults to JSON with a small escaped example. Editing input
or mode clears stale output. Pending adapter or service work disables competing
actions. Failed copy or save clears the result as required by AF-02. English
and Brazilian Portuguese localize all controls, modes, notices, and failures.

## Requirement and test coverage

- FR-TX-03 and the main flow: utility known-answer and round-trip tests cover
  all five modes, empty input, boundaries, Unicode, supplementary characters,
  every accepted escape family, and representative literal text.
- FR-TX-11 and AF-01: utility, core, and CLI tests cover unsupported modes and
  malformed sequences with stable redacted details; GUI tests prove supported
  mode prevention and render localized malformed-input failures.
- AF-02: CLI and widget tests cover input-file, output-file, clipboard-read,
  clipboard-write, and save failures with no retained result.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, GUI, native, and compiled
  browser flows use the shared service and cover direct, stdin/file, human,
  JSON, localized, copy, and save behavior.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: tests assert no
  history or network path, and each operation remains local and ephemeral.

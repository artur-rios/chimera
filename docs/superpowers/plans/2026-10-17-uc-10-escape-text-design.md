# UC-10 Escape Text Design

## Scope and traceability

UC-10 escapes text in JSON, Unicode, C-style, HTML, or URL mode. It covers
FR-TX-02, FR-TX-11, FR-PL-01 through FR-PL-06, FR-PL-09 through FR-PL-11,
BR-01 through BR-05, and BR-19. The implementation is local and stateless, and
one shared utility contract is consumed by the core service, CLI, desktop GUI,
and compiled web application.

## Shared model and canonical output

`chimera_utilities` owns a `TextEscaper` with a string mode identifier so an
unsupported mode can produce a typed validation failure. Empty input is valid.
The five supported canonical mode names are `json`, `unicode`, `c`, `html`, and
`url`; aliases are deliberately rejected so every interface exposes the same
stable contract.

Escaped results contain string contents rather than language-level wrapper
quotes:

- JSON escapes quotation mark, reverse solidus, the standard short control
  sequences, and remaining U+0000 through U+001F code units as `\uXXXX`.
  Other Unicode text is preserved.
- Unicode emits every UTF-16 code unit as uppercase `\uXXXX`. Supplementary
  characters therefore use their canonical surrogate-pair spelling, making the
  output deterministic on every Dart target.
- C-style escapes reverse solidus, both quote kinds, bell, backspace, form feed,
  newline, carriage return, tab, vertical tab, and NUL using conventional short
  sequences. Remaining C0 controls and DEL use uppercase `\xHH`; other Unicode
  text is preserved.
- HTML escapes `&`, `<`, `>`, `"`, and `'` as `&amp;`, `&lt;`, `&gt;`,
  `&quot;`, and `&#39;`. Other text is preserved.
- URL percent-encodes the UTF-8 bytes of every character except RFC 3986
  unreserved characters (`A-Z`, `a-z`, `0-9`, `-`, `.`, `_`, `~`) using
  uppercase hexadecimal. It is therefore component-safe and encodes spaces as
  `%20`.

The utility supports nullable injected input/output character budgets solely
for deterministic resource-failure tests. Production uses no product-specific
limit. Budget exhaustion or `OutOfMemoryError` becomes a typed resource failure
without returning partial output.

## Service and failure contract

`chimera_core` maps the utility request to a `TextEscapeOutput` with `escaped`
and `mode` fields. Stable failure codes are:

- `text-escape.invalid-mode`, field `mode`, reason `unsupported-mode`;
- `text-escape.resource-limit`, field `input` or `escaped`, reason
  `input-limit` or `output-limit`.

Core message keys are `error.textEscape.validation` and
`error.textEscape.resource`. Interface access failures use
`text-escape.input-access`, `text-escape.output-access`,
`text-escape.clipboard-read`, and `text-escape.clipboard-write` without
including source text in diagnostics.

## Interface behavior

The CLI command is `chimera text escape --mode <mode>`. Exactly one input
source is accepted: `--input`, `--file`, or standard input. `--output` writes
the exact UTF-8 escaped text to a local file; `--json` returns a stable envelope
with `escaped` and `mode`. Validation exits with 64, input/output access with
74, and resource failure with 75. A failed output write emits no success result.

The GUI exposes `/text/escape` with multiline typed input, local text-file load,
clipboard paste, a mode selector, escape action, selectable result, copy, and
save. It defaults to JSON mode with a small example. Any input or mode change
clears stale output. Pending file/clipboard/service work disables competing
submission. A failed copy or save clears the result as required by AF-02.
English and Brazilian Portuguese localize every control, mode label, notice,
and failure.

## Requirement and test coverage

- FR-TX-02 and the main flow: utility known-answer tests cover all five modes,
  empty text, controls, quotes, Unicode, supplementary characters, HTML
  metacharacters, URL reserved characters, and UTF-8 percent encoding.
- FR-TX-11 and AF-01: utility, core, CLI, and widget tests cover unsupported
  mode validation with stable field/reason data and redacted diagnostics.
- AF-02: CLI and widget tests cover input-file, output-file, clipboard-read,
  clipboard-write, and save failures with no retained/result output.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, GUI, native, and compiled
  browser flows consume the shared service and cover direct, stdin/file, human,
  JSON, localized, copy, and save behavior.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: tests assert no
  history or network path, and each operation is local and ephemeral.


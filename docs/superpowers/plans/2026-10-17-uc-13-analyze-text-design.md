# UC-13 Analyze Text Design

## Scope and traceability

UC-13 reports character, word, line, and UTF-8 byte counts for one text value.
It covers FR-TX-06, FR-TX-11, FR-PL-01 through FR-PL-06, FR-PL-09 through
FR-PL-11, BR-01 through BR-05, and BR-19. Processing remains local, offline,
deterministic, and stateless. One shared utility contract is consumed by core,
CLI, desktop, and web adapters.

## Unicode and boundary contract

`chimera_utilities` owns `TextAnalyzer`. Counts use the following canonical
rules on every surface:

- characters are Unicode extended grapheme clusters as implemented by
  `package:characters`; combining sequences, emoji modifiers, flags, and joined
  emoji therefore count as one user-perceived character;
- words are maximal runs of Unicode letters, decimal numbers, and combining
  marks, with straight or curly apostrophes retained only when they join two
  such runs; punctuation-only and emoji-only spans are not words;
- line boundaries are LF, CRLF, or CR, with CRLF treated as one boundary; empty
  text has zero lines, non-empty text has one plus its boundary count, and a
  trailing boundary creates a final empty line;
- bytes are the exact length of the text's UTF-8 encoding without a byte-order
  mark.

All characters, whitespace, and line endings remain part of character and byte
counts. Analysis does not normalize, trim, replace, or persist the source text.
The result contains only four non-negative counts.

A nullable injected `maxInputCodeUnits` budget exists only for deterministic
AF-02 tests. It is checked before any successful result is exposed. Budget
exhaustion or `OutOfMemoryError` becomes a typed resource failure with no
partial counts.

## Service and failure contract

`chimera_core` maps the utility result to `TextAnalyzeOutput`. Stable JSON fields
are `characters`, `words`, `lines`, and `bytes` in that order.

The stable utility/service failure is `text-analyze.resource-limit`, field
`input`, reason `character-limit`. Core maps it to `FailureKind.resource` and
`error.textAnalyze.resource`. Diagnostics may include the field and reason but
never source text or partial counts.

UC-13 has no algorithm option. FR-TX-11 applies at the adapter boundary: missing
or contradictory source selections are typed validation failures using
`text-analyze.invalid-options` or `text-analyze.conflicting-inputs` and
`error.textAnalyze.validation`. File, stdin, clipboard, and destination failures
use stable access codes and localized messages without retaining a result.

## CLI behavior

The command is `chimera text analyze`. Input comes from exactly one effective
source: `--input`, `--file`, or standard input when neither option is supplied.
Supplying both explicit sources is a validation failure. Human output contains
four localized label/value lines. `--json` emits the stable service object.
`--output` writes the exact selected human or JSON payload as UTF-8 and emits
only a localized save confirmation. Validation exits with 64, input/output
access with 74, and resource failure with 75.

## GUI behavior

The GUI exposes `/text/analyze` with one multiline editor, local text-file and
clipboard loaders, and an explicit analyze action. Results appear as four
accessible localized statistics. Copy and save transfer the exact localized
four-line preview. Editing or replacing input clears stale output. Pending
adapter or service work disables competing actions, and a failed read, copy, or
save clears the result before displaying a localized failure.

The home action, route, controls, result labels, notices, and failures are fully
localized in English and Brazilian Portuguese. A compact default sample makes
the route immediately demonstrable without introducing persistence.

## Requirement and test coverage

- FR-TX-06 and the main flow: utility known-answer tests cover ASCII, empty
  input, composed/decomposed text, emoji clusters, multilingual words,
  punctuation, apostrophes, every line ending, trailing boundaries, and UTF-8.
- FR-TX-11 and AF-01: CLI tests cover contradictory sources and read/write
  failures; widget tests cover file and clipboard failures with cleared output.
- AF-02: injected budgets prove a typed resource failure without partial counts.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, GUI, native, and compiled
  browser flows consume the same service and verify identical counts.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: no history,
  preference, account, plugin, collaboration, or network path is added;
  compiled browser flows explicitly reject unexpected external requests.

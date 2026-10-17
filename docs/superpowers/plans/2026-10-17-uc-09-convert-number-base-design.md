# UC-09 Convert Number Base Design

## Goal

Convert signed arbitrary-precision integers between bases 2 and 36 through one
local implementation shared by the Flutter GUI and Dart CLI.

## Semantics

- Accept bases 2 through 36 inclusive.
- Accept an optional leading `+` or `-` followed by one or more ASCII digits.
  Digits `0`-`9` and letters `a`-`z`/`A`-`Z` are case-insensitive and must be
  valid for the source base. There is no special prefix syntax: `0x10` is invalid
  in base 16 because `x` is not a base-16 digit, but it is a valid ordinary digit
  sequence in base 36. Separators, fractions, and embedded whitespace are invalid.
- The converter checks any injected input budget against the raw text, then trims
  leading/trailing whitespace so stdin and text files ending with a newline behave
  like direct interactive input. The trimmed value must contain no whitespace.
- Emit canonical lowercase digits, remove leading zeroes and a leading `+`, and
  normalize every zero representation (including `-0`) to `0`.
- Use Dart `BigInt` so precision is limited by available resources rather than a
  fixed machine integer width. No new dependency is required.

## Architecture and interfaces

- `chimera_utilities` owns `NumberBaseConverter`, its request/result values, and
  typed validation/resource exceptions. Production defaults have no fixed source
  or output cap, honoring the rule that precision is limited only by platform
  resources. Optional nullable constructor budgets model a caller/platform limit
  for deterministic AF-02 tests. When an output budget is present, a bounded
  repeated-division encoder stops at the first excess digit before constructing
  an oversized string; the budget includes a minus sign. A caught
  `OutOfMemoryError` from `BigInt` parsing or unrestricted conversion is mapped to
  the same resource failure, without a partial result.
- `chimera_core` owns `NumberBaseService`, invokes the converter, and maps failures
  to the shared sealed result model. `NumberBaseService` injects the converter;
  `NumberBaseOutput` wraps the result and produces stable JSON.
- The CLI exposes `chimera number convert-base` with `--input`/stdin/`--file`,
  required integer `--from` and `--to` bases, optional `--output`, and `--json`. Human
  output is localized; JSON output contains `converted`, `sourceBase`, and
  `targetBase`. Validation, access, and resource failures use existing exit codes
  64, 74, and 75.
- The GUI exposes `/number/convert-base` with a text field, base selectors,
  file/paste input actions, a localized live result, and copy/save actions.
  The default sample is `255` from base 10 to base 16.
- All input and output remain in memory or explicitly selected local files and are
  never persisted as history or transmitted.

## Failure mapping

- AF-01: an out-of-range base, empty/sign-only value, or invalid digit produces a
  typed validation failure and no result. Reasons are `out-of-range-base`,
  `missing-value`, and `invalid-digit`; the base field is `sourceBase` or
  `targetBase`.
- AF-02: the raw source or canonical output (including a minus sign) exceeds an
  injected platform budget, or `BigInt` reports exhausted memory, and produces a
  typed resource failure and no partial output.
- Local stdin/file/clipboard/output failures are mapped to access failures by the
  adapters, as required by the shared platform requirements.
- A failed GUI operation clears any previous result before displaying the error.

## Stable failure contracts and precedence

- `NumberBaseFailureKind` has `validation` and `resource` members.
- Validation order is source base, target base, injected raw-input budget,
  missing/sign-only value, then the first invalid digit. A configured output
  budget is checked during conversion.
- Base failures use code `number-base.invalid-base`, field `sourceBase` or
  `targetBase`, and reason `missing-base`, `not-an-integer`, or
  `out-of-range-base` as applicable. Converter-level bases are already integers
  and therefore emit only `out-of-range-base`.
- Value failures use `number-base.invalid-value`, field `value`, and reason
  `missing-value` or `invalid-digit`. The source text is never included.
- Resource failures use `number-base.resource-limit`, field `value` for raw-input
  exhaustion or `converted` for output/memory exhaustion, and reason
  `input-limit` or `output-limit`.
- CLI adapter failures use `number-base.conflicting-inputs`,
  `number-base.input-access`, `number-base.file-access`, and
  `number-base.output-access`. GUI clipboard failures use localized
  `error.numberBase.clipboardRead`/`clipboardWrite` messages; failed output is
  cleared before the message is shown.
- Core message keys are `error.numberBase.validation` and
  `error.numberBase.resource`; adapters add the access keys above.

## Requirement and test coverage

- FR-TX-01 and BR-01: utility known-answer tests cover binary, decimal,
  hexadecimal, base 36, signs, zero normalization, and values beyond 64 bits.
- FR-TX-11 and AF-01: utility/core/CLI/widget tests cover invalid bases and digits.
- AF-02: injectable small budgets prove typed resource failure without output.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, GUI, native, and browser tests
  consume the same service contract and cover direct, stdin/file, human, JSON,
  localized, copy, and save behavior.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: tests assert no history
  or network behavior, and every path runs locally with ephemeral values.

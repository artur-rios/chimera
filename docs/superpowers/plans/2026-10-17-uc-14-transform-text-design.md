# UC-14 Transform Text Design

## Scope and traceability

UC-14 applies exactly one selected transformation to one text value. It covers
FR-TX-07, FR-TX-11, FR-PL-01 through FR-PL-06, FR-PL-09 through FR-PL-11,
BR-01 through BR-05, and BR-19. Processing is local, offline, deterministic,
and stateless. One shared utility contract is consumed by core, CLI, desktop,
and web adapters.

## Transformation contract

The stable modes are `lowercase`, `uppercase`, `normalize-whitespace`,
`sort-lines`, and `deduplicate-lines`. A request selects exactly one mode; modes
are not composed. This gives “one ordered transformation selection” a stable,
automation-friendly meaning and avoids hidden ordering between non-commutative
operations.

- `lowercase` and `uppercase` use Dart's locale-neutral Unicode mappings over
  the complete input, including mappings that expand one code point;
- `normalize-whitespace` uses the Unicode 15.1 White_Space property: U+0009
  through U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000 through U+200A,
  U+2028, U+2029, U+202F, U+205F, and U+3000. Every maximal run becomes one
  ASCII space and leading/trailing whitespace is removed. U+200B and U+FEFF are
  deliberately not whitespace;
- `sort-lines` uses Dart `String.compareTo`, therefore ascending UTF-16
  code-unit order, and preserves duplicate and blank content lines;
- `deduplicate-lines` retains the first occurrence of each exact logical line
  and its original order;
- line modes accept LF, CRLF, and CR, emit LF, and preserve whether a non-empty
  input ended with a line boundary. Empty input remains empty.

Input is never implicitly trimmed or normalized outside the selected mode. The
result contains only the transformed string and selected mode. Nullable
`maxInputCodeUnits` and `maxOutputCodeUnits` budgets bound work before input is
processed and before output is exposed. `OutOfMemoryError` is mapped to the same
resource contract. No source text, result, or history is retained.

## Public utility contract

`TextTransformMode` is the five-value enum above and exposes its stable slug.
`parseTextTransformMode(String)` accepts only an exact stable slug and otherwise
throws `TextTransformException`. `TextTransformer` has a const constructor with
nullable `maxInputCodeUnits` and `maxOutputCodeUnits`, and exposes
`transform({required String input, required String mode})` returning
`TextTransformResult(mode, output)`.

`TextTransformException` carries `TextTransformFailureKind.validation` or
`.resource`, a stable code, and optional `field`/`reason`. Invalid mode uses
`text-transform.invalid-mode`, field `mode`, reason `unsupported-mode`. Input
and output limits use `text-transform.resource-limit`, the corresponding field,
and reason `character-limit`; allocation failure uses reason `allocation-limit`.

## Service and failure contract

`chimera_core` exposes `TextTransformOperationRequest(input, mode)`,
`TextTransformOutput(result)` with stable JSON fields `mode` and `output`, and a
const `TextTransformService({transformer})`. It maps utility validation to
`FailureKind.validation`/`error.textTransform.validation` and resource failures
to `FailureKind.resource`/`error.textTransform.resource`. Failure details never
contain input or partial output.

## CLI behavior

The command is `chimera text transform --mode <mode>`. Input comes from exactly
one effective source: `--input`, `--file`, or standard input when neither is
provided. Supplying both explicit sources is `text-transform.conflicting-inputs`.
Missing or unknown `--mode` is `text-transform.invalid-mode`. Standard-input,
file-read, and output-write failures are respectively
`text-transform.input-access`, `text-transform.file-access`, and
`text-transform.output-access`.
Human output is the exact transformed text. `--json` emits the stable service
object. `--output` writes the exact selected payload as UTF-8 and emits only a
localized save confirmation. Validation exits with 64 and input/output access
with 74; resource failure exits with 75.

## GUI behavior

The GUI exposes `/text/transform` with one multiline editor, a localized mode
selector, local text-file and clipboard loaders, and an explicit transform
action. The output is an accessible preview. Copy and save transfer the exact
transformed text. Editing input or changing mode clears stale output. Pending
adapter or service work disables competing actions. Failed reads, copies, and
saves clear the result before showing a localized error.

GUI adapter failures use `text-transform.file-access`,
`text-transform.clipboard-read`, `text-transform.clipboard-write`, and
`text-transform.output-access`. The service remains the sole transformation
path; adapters never duplicate it.

The route, home action, modes, controls, notices, and failures are localized in
English and Brazilian Portuguese. A compact sample makes the route immediately
demonstrable without persistence.

## Requirement and test coverage

- FR-TX-07/main flow: utility known-answer tests cover both case modes, every
  Unicode whitespace class boundary, mixed line endings, sorting, duplicates,
  blank lines, trailing boundaries, Unicode, empty input, U+200B/U+FEFF
  exclusions, non-ASCII expanding case mappings, and a U+E000/U+10000 pair that
  distinguishes UTF-16 ordering from scalar ordering.
- FR-TX-11/AF-01: utility, service, CLI, and widget tests cover missing/unknown
  modes and conflicting explicit input sources with typed redacted failures.
- AF-02: CLI and widget tests prove output-access failures expose no result.
- Resource safety: exact-boundary and one-over input/output budgets map to exit
  75 or localized GUI failure with no partial output; allocation failures share
  the same production mapping.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, GUI, native, and compiled
  browser flows consume the same service and verify identical output.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: no history,
  preference, account, plugin, collaboration, or processing-network path is
  added; compiled browser flows reject unexpected external requests.

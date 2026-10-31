# UC-15 Compare Text Design

## Scope and traceability

UC-15 compares two text values at one selected granularity and returns ordered
unchanged, removed, and added spans. It covers FR-TX-08 through FR-TX-11,
FR-PL-01 through FR-PL-06, FR-PL-09 through FR-PL-11, BR-01 through BR-05,
and BR-19. Processing is deterministic, local, offline, and stateless. One
shared utility contract is consumed by core, CLI, desktop, and web adapters.

## Comparison contract

The stable granularities are `line`, `word`, and `character`. A request selects
exactly one granularity.

- `line` treats each logical line, including whether it has a following line
  boundary, as one token. LF, CRLF, and CR are accepted and normalized to LF so
  platform line endings compare consistently. A terminal boundary remains
  observable, and empty input has no tokens;
- `word` groups each maximal run of Unicode 15.1 White_Space as one token and
  each maximal run of all other grapheme clusters as one token. Whitespace is
  preserved exactly in returned spans. U+200B and U+FEFF are non-whitespace;
- `character` uses Unicode extended grapheme clusters from `package:characters`,
  so surrogate pairs, combining sequences, and emoji ZWJ sequences remain
  indivisible.

Tokens are discovered by scanning the left side first and the right side second.
The first occurrence receives the next symbol from U+0001 through U+D7FF, then
U+E000 through U+FFFF. U+0000 and the surrogate range are never assigned. This
provides exactly 63,487 one-code-unit symbols. `diff_match_patch` 0.4.1 runs on
the symbols with line checking and the time deadline disabled. No semantic or
efficiency cleanup runs: those routines classify their input as human text, so
running them on synthetic symbols could make token IDs affect span boundaries.
The raw deterministic diff is expanded back to tokens, and adjacent spans of the
same kind are coalesced. Replacements are represented as a removed span followed
by an added span.

The ordered result contains `TextDiffSpan(kind, text, tokenCount)` values and a
summary with added, removed, and unchanged token counts. `TextDiffKind` has the
stable slugs `unchanged`, `removed`, and `added`. Identical empty inputs return
no spans and zero counts. No input is trimmed, case-folded, or otherwise
normalized except for line-boundary normalization in `line` mode.

## Resource and failure contract

`TextComparer` accepts nullable testable budgets for combined input code units,
combined token count, distinct token symbols, comparison work, and result spans.
Production defaults are 1,000,000 combined input code units, 100,000 combined
tokens, 63,487 distinct token symbols, 25,000,000 comparison work units, and
10,000 final coalesced public spans. The comparison-work measure is the product
of the post-tokenization left and right token counts; it bounds adversarial work
before invoking the diff engine. Raw diff entries remain bounded by the token
budget, while the result-span budget is checked as final public spans coalesce.

Invalid granularity uses validation code `text-compare.invalid-granularity`,
field `granularity`, and reason `unsupported-granularity`. Budget failures use
resource code `text-compare.resource-limit` with fields `input`, `tokens`,
`symbols`, `work`, or `result`. Their reasons are respectively
`character-limit`, `token-limit`, `symbol-limit`, `work-limit`, and `span-limit`.
`OutOfMemoryError` maps to field `result`, reason `allocation-limit`. Failures
expose neither input nor partial spans.

## Public utility and service contracts

`TextCompareGranularity` is the three-value enum above and exposes its stable
slug. `parseTextCompareGranularity(String)` accepts only exact slugs.
`TextComparer.compare({required String left, required String right, required
String granularity})` returns `TextCompareResult`.

`chimera_core` exposes `TextCompareOperationRequest(left, right, granularity)`,
`TextCompareOutput(result)`, and `TextCompareService({comparer})`. Stable JSON is:

```json
{
  "granularity": "word",
  "spans": [
    {"kind": "unchanged", "text": "Hello ", "tokenCount": 2},
    {"kind": "removed", "text": "world", "tokenCount": 1},
    {"kind": "added", "text": "there", "tokenCount": 1}
  ],
  "summary": {"added": 1, "removed": 1, "unchanged": 2}
}
```

Utility validation and resource exceptions map to `FailureKind.validation` and
`.resource` with localized message keys `error.textCompare.validation` and
`error.textCompare.resource`.

## CLI behavior

The command is `chimera text compare --granularity <value>`. Each side selects
exactly one source from `--left`, `--left-file`, or `--left-stdin`, and the
matching right-side flags. Both sides cannot share stdin. Options and source
cardinality are validated before any input is read.

Human output writes one localized span line per ordered span. Span text is JSON
encoded so whitespace and line boundaries stay visible and unambiguous, followed
by localized added/removed/unchanged totals. `--json` emits the stable service
object. `--output` writes the exact selected payload as UTF-8 and emits only a
localized save confirmation. Validation exits with 64, source/output access with
74, and resource failure with 75. Diagnostics are redacted.

## GUI behavior

The GUI exposes `/text/compare` with two multiline editors. Each editor has
local text-file and clipboard loaders, followed by a localized granularity
selector and explicit compare action. The result is an accessible ordered span
list with localized kind labels and summary. Removed and added spans use theme
colors in addition to text labels; color is not the sole signal.

Copy and save transfer the exact stable JSON result, with save name
`chimera-text-diff.json`. Editing either input or changing granularity clears a
stale result. Pending adapter or service work disables competing actions. Failed
reads, copies, and saves clear the result before showing a localized error.

The route, home action, controls, span labels, summary, notices, and failures are
localized in English and Brazilian Portuguese. No history, preference, account,
plugin, collaboration, persistence, or processing-network path is added.

## Requirement and test coverage

- FR-TX-08 through FR-TX-10/main flow: known-answer utility tests cover each
  granularity, insertions, removals, replacements, equality, empty sides, mixed
  line endings, terminal boundaries, Unicode whitespace, combining sequences,
  surrogate pairs, and emoji ZWJ sequences.
- FR-TX-11/AF-01: utility, service, CLI, and widget tests cover missing/unknown
  granularity, invalid source cardinality, shared stdin, and validation-before-
  read ordering with typed redacted failures.
- AF-02: exact input/token/symbol/work/result boundaries and allocation mapping
  return resource failures without partial output; CLI exits 75 and GUI clears
  stale results.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, GUI, native, and compiled
  browser flows consume the same service and stable span semantics.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: inputs/results exist
  only for the active operation, and compiled browser flows reject unexpected
  external requests.


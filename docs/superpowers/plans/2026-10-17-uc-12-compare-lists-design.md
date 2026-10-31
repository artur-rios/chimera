# UC-12 Compare Lists Design

## Scope and traceability

UC-12 compares two line-based lists and returns left-only, right-only,
intersection, and equality results. It covers FR-TX-04, FR-TX-05, FR-TX-11,
FR-PL-01 through FR-PL-06, FR-PL-09 through FR-PL-11, BR-01 through BR-05,
and BR-19. Processing remains local, offline, deterministic, and stateless.
One shared utility contract is consumed by core, CLI, desktop, and web adapters.

## Options and line model

`chimera_utilities` owns `ListComparator`. Its request contains `left`, `right`,
`caseMode`, `whitespaceMode`, and `duplicateMode`. Canonical option values are:

- `caseMode`: `sensitive` or `insensitive`;
- `whitespaceMode`: `preserve` or `trim`;
- `duplicateMode`: `preserve` or `distinct`.

Aliases and unsupported values are rejected with a typed option failure. Defaults
are `sensitive`, `preserve`, and `preserve`, so comparison is lossless unless the
caller explicitly enables normalization.

Inputs split on LF, CRLF, or CR. An empty string represents an empty list;
otherwise blank entries, including a trailing blank entry, are real list items.
`trim` applies Dart's Unicode-aware `String.trim` to each item. `insensitive`
comparison uses the trimmed-or-original value's deterministic Unicode lowercase
form as its comparison key. Results retain the original source item rather than
returning a destructive normalized spelling.

## Comparison semantics

`preserve` implements a stable multiset comparison. Occurrences match one for
one. `intersection` contains the matched left occurrences in left order;
`leftOnly` contains unmatched left occurrences in left order; and `rightOnly`
contains unmatched right occurrences in right order. `distinct` first retains
only the first occurrence of each normalized key on each side, then applies the
same stable comparison. Equality is true exactly when both only-sets are empty.

This approach was selected over sorted-set output because stable source order
is more useful in interactive and CLI results, and over count maps because the
required contract names line sets rather than aggregate counters. The result
is deterministic across every surface while preserving user-provided spelling.

Nullable injected `maxInputCharacters`, `maxInputItems`, and `maxResultItems`
budgets exist only for deterministic AF-02 tests. Limits are checked before a
successful result is exposed. Budget exhaustion or `OutOfMemoryError` becomes a
typed resource failure with no partial result.

## Service and failure contract

`chimera_core` maps the utility result to `ListCompareOutput`. Stable JSON fields
are `leftOnly`, `rightOnly`, `intersection`, `equal`, and `options`; option fields
are `case`, `whitespace`, and `duplicates`.

Stable utility/service failures are:

- `list-compare.invalid-option`, field `caseMode`, `whitespaceMode`, or
  `duplicateMode`, reason `unsupported-option`;
- `list-compare.resource-limit`, field `input` or `result`, reason
  `character-limit`, `item-limit`, or `result-limit`.

Core message keys are `error.listCompare.validation` and
`error.listCompare.resource`. Interface source and destination failures use
`list-compare.input-access`, `list-compare.file-access`, and
`list-compare.output-access`. Diagnostics contain option names and safe counts,
never list contents.

## CLI behavior

The command is `chimera list compare`. Each side selects exactly one source:
`--left`, `--left-file`, or `--left-stdin`, and `--right`, `--right-file`, or
`--right-stdin`. Both sides cannot select stdin simultaneously. Missing,
multiple, or double-stdin selections are typed validation failures. This makes
argument, local-file, and standard-input behavior explicit and unambiguous.

Options are `--case`, `--whitespace`, and `--duplicates`. Human output contains
localized equality and three labeled result sections. `--json` emits the stable
service envelope. `--output` writes the exact selected human or JSON payload as
UTF-8 and emits only a localized save confirmation. Validation exits with 64,
input/output access with 74, and resource failure with 75. Failed writes expose
no success result.

## GUI behavior

The GUI exposes `/list/compare` with two multiline list editors, independent
local text-file and clipboard loaders, three option selectors, and an explicit
compare action. Results show localized equality plus accessible left-only,
right-only, and intersection sections in stable order. Copy and save transfer
the exact localized preview text. Editing either input or any option clears
stale results. Pending adapter or service work disables competing actions, and
failed copy/save clears the result.

The home action, route, controls, result labels, notices, and failures are fully
localized in English and Brazilian Portuguese. A compact default example makes
the route immediately demonstrable without introducing persistence.

## Requirement and test coverage

- FR-TX-04 and the main flow: utility tests cover all four outputs, stable order,
  equality, empty lists, blank items, CR/LF variants, and Unicode.
- FR-TX-05: parameterized tests cover both case modes, both whitespace modes,
  both duplicate modes, multiset counts, distinct first-occurrence behavior,
  and combined normalization.
- FR-TX-11 and AF-01: utility/core/CLI tests cover every unsupported option and
  contradictory CLI source selection with stable redacted details; GUI selectors
  prevent unsupported values.
- AF-02: injected budgets prove typed resource failure without partial sets.
  CLI and widget tests also cover file, stdin, clipboard, copy, and save access
  failures with no retained result.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, GUI, native, and compiled
  browser flows consume the same shared service and verify identical semantics.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: no history,
  preference, account, plugin, collaboration, or network path is added; compiled
  browser flows explicitly fail on unexpected external requests.

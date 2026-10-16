# UC-03 Convert JSON Array to Table Design

## Scope and traceability

UC-03 accepts a JSON array of objects plus display options and returns a table.
It covers FR-DA-01, FR-DA-02, FR-DA-08, FR-PL-01 through FR-PL-06,
FR-PL-09 through FR-PL-11, and BR-01 through BR-05 plus BR-19.

## Shared model and algorithm

`chimera_utilities` owns JSON validation, column derivation, cell rendering, and
resource accounting. Columns are the union of object keys in first-seen order.
Strings remain strings, numbers and booleans use their JSON spelling, null uses
`null`, missing keys use an empty cell, and nested arrays or objects remain
compact serialized JSON so structure is never flattened or lost.

The display option `includeRowNumbers` prepends a localized presentation column
without altering source columns. A configurable cell budget protects rendering;
the production default permits one million rendered data cells. Exceeding it is
a typed resource failure before any partial table is returned.

Malformed JSON reports its character offset. A top-level value that is not an
array reports `$`; a non-object array member reports `$[index]`. Failures contain
only the location and stable reason code, never the source. Empty arrays are
valid empty tables. Processing is local and stateless.

## Interface behavior

The CLI command is `chimera json array-to-table`. Input comes from `--input`,
standard input, or `--file`; `--row-numbers` controls the display option and
`--json` returns stable columns/rows metadata. Human output is a Markdown-style
table with escaped pipes and newlines. Validation exits with 64, resource
failure with 75, and input/file access with 74.

The GUI exposes `/json/array-to-table` with typed/pasted and local-file input, a
row-number checkbox, and a horizontally scrollable accessible table. English
and Brazilian Portuguese localize controls, failures, location labels, and the
row-number heading.

## Verification

- Utility tests cover heterogeneous keys, stable order, every scalar, nested
  preservation, missing values, empty arrays, malformed locations, non-array
  input, non-object members, Unicode, and resource exhaustion.
- Core tests cover stable serialization and typed validation/resource mapping.
- CLI tests cover argument/stdin/real-file input, human and JSON output,
  locations, exit codes, and redaction.
- Widget, native integration, compiled Chromium/Firefox/WebKit, and native
  Safari flows cover the main result, failures, accessibility, responsiveness,
  and no-network behavior.

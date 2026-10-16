# UC-04 Convert JSON Array to CSV Design

## Scope and traceability

UC-04 accepts a JSON array of objects plus delimiter and header options, then
returns CSV text or writes that text to a selected local file. It covers
FR-DA-02, FR-DA-03, FR-DA-08, FR-PL-01 through FR-PL-06, FR-PL-09 through
FR-PL-11, and BR-01 through BR-05 plus BR-19.

## Shared model and algorithm

`chimera_utilities` owns JSON validation, deterministic column derivation, cell
rendering, CSV option validation, and serialization. It reuses the JSON-table
contract: columns are the union of object keys in first-seen order; strings are
decoded strings; numbers, booleans, and null retain their JSON spelling;
missing properties become empty fields; and nested arrays or objects remain
compact serialized JSON.

The supported delimiter choices are comma, semicolon, tab, and pipe. Headers
are included by default and may be omitted. CSV uses double-quote escaping and
CRLF record separators, matching RFC 4180 conventions. The maintained `csv`
package performs quoting rather than duplicating a standards boundary in
application code.

Malformed JSON reports its character offset. A non-array reports `$`, a
non-object member reports `$[index]`, and an unsupported delimiter is a typed
option failure. Diagnostics contain stable reason codes and locations but never
source data. Processing is local and stateless.

## Interface behavior

The CLI command is `chimera json array-to-csv`. Input comes from `--input`,
standard input, or `--file`. `--delimiter` accepts `comma`, `semicolon`, `tab`,
or `pipe`; `--[no-]headers` controls the header row; `--output` writes exact
UTF-8 bytes to a local file; and `--json` returns a stable result envelope.
Validation exits with 64, resource failure with 75, and input/output access
failure with 74. A failed output write does not report or retain a successful
result.

The GUI exposes `/json/array-to-csv` with typed/pasted and local-file input,
delimiter and header controls, an accessible selectable CSV preview, and a
save action backed by the platform file picker. English and Brazilian
Portuguese localize all controls and failures. Save remains disabled until a
successful conversion and a failed save leaves the preview available only as
the already returned in-memory result.

## Verification

- Utility tests cover deterministic columns, all delimiters, headers on/off,
  quoting, CRLF, nested preservation, empty/missing values, malformed
  locations, shape failures, invalid options, Unicode, and resource limits.
- Core tests cover stable serialization and typed validation/resource mapping.
- CLI tests cover argument/stdin/real-file input, exact output-file bytes,
  human and JSON output, locations, exit codes, cleanup semantics, and
  redaction.
- Widget, native integration, compiled Chromium/Firefox/WebKit, and native
  Safari flows cover conversion, save behavior, localization, accessibility,
  responsiveness, and no-network behavior.


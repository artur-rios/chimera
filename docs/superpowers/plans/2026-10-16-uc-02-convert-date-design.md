# UC-02 Convert Date Design

## Scope and traceability

UC-02 converts a value among ISO 8601, Unix seconds, Unix milliseconds, and an
approved custom date pattern while resolving source and target IANA time zones.
It covers FR-SD-05, FR-PL-01 through FR-PL-06, FR-PL-09 through FR-PL-11, and
BR-01 through BR-05 plus BR-19.

## Shared model and algorithm

`chimera_utilities` owns one date conversion engine consumed by every
interface. A request declares source and target representations, source and
target IANA zones, and optional source/target patterns. Unix values are signed
base-10 integers. ISO values with an offset identify an instant directly; ISO
values without an offset and custom-pattern values are interpreted in the
source zone. ISO fractional seconds are supported through millisecond precision;
higher precision is rejected consistently across native and web targets.

Custom patterns deliberately support an unambiguous numeric subset of Unicode
date-field syntax: `yyyy`, `MM`, `dd`, `HH`, `mm`, `ss`, and `SSS`, with quoted
literals or the separators space, `-`, `/`, `.`, and `:`. Calendar fields are
parsed strictly. Unsupported, duplicate, incomplete, or ambiguous patterns are
validation failures.

Local wall-clock values are matched against the bundled IANA database. A
nonexistent daylight-saving time or a wall clock that resolves to more than one
instant is rejected instead of guessing. The common supported instant range is
0001-01-01T00:00:00.000Z through 9999-12-31T23:59:59.999Z. A target
zone must also keep the rendered local year inside 0001 through 9999 so every
formatted ISO result remains round-trippable. Values outside either boundary
produce a typed range failure without a partial result.

The result contains the source and target representations, normalized UTC
instant, source/target zones, target-zone offset, and converted value. Numeric
targets are UTC epochs. ISO targets include the selected target-zone offset.
Custom targets render the selected target zone with the approved pattern. No
input or output is persisted or transmitted.

## Interface behavior

The CLI command is `chimera date convert`. It accepts input through `--value`,
standard input, or `--file`, plus `--from`, `--to`, `--source-timezone`,
`--target-timezone`, `--source-pattern`, `--target-pattern`, and `--json`.
Human output is localized; JSON uses stable keys. Validation exits with 64,
range/processing failures with 70, and file/input access failures with 74.
Diagnostics never echo the supplied date.

The GUI exposes `/date/convert` with typed/pasted and local-file input,
representation selectors, source/target zones, conditional pattern fields, and
localized output/failures in English and Brazilian Portuguese. The form is
keyboard reachable, semantically labeled, and responsive.

## Verification

- Unit tests cover all representations and directions, negative epochs,
  fractional milliseconds, IANA offsets, DST gaps/overlaps, leap dates,
  malformed values/patterns/zones, and range boundaries.
- Core tests cover typed validation and range mapping with no partial output.
- CLI functional tests cover arguments, stdin, real local files, stable JSON,
  localized human output, exit codes, and sensitive-input redaction.
- Widget, integration, and compiled-browser tests cover routing, main flow,
  file loading, localization, failures, accessibility, responsive layout, and
  the no-network invariant.

# UC-01 Parse Cron Expression Design

## Scope and traceability

UC-01 accepts a five-field Unix cron expression or a six-field expression with
seconds, an IANA time-zone identifier, an occurrence count, and a reference
instant. It returns a structured explanation plus the requested previous and
next occurrences. The implementation covers FR-SD-01 through FR-SD-04,
FR-PL-01 through FR-PL-06, and FR-PL-09 through FR-PL-11.

## Shared model and algorithm

`chimera_utilities` owns the parser and occurrence calculator. Neither interface
duplicates cron semantics. A compiled schedule contains one normalized field per
cron position and supports wildcards, lists, inclusive ranges, and steps. Month
and weekday names are accepted case-insensitively. Sunday accepts both `0` and
`7`. Five-field expressions receive an implicit zero-second field.

The utility initializes the bundled IANA database from `package:timezone`, then
resolves the requested zone explicitly. It searches strictly before and after an
injected reference instant so tests remain deterministic. Calendar matching is
performed in the selected zone, including offset changes. Day-of-month and
day-of-week use Unix cron OR semantics when both are syntactically restricted.
Nonexistent wall-clock times are skipped, while both instants in a repeated
fall-back wall-clock period are returned in chronological order.

The request count is limited to 1 through 100. A bounded candidate-search budget
prevents pathological schedules from consuming unbounded CPU. Syntax, zone, and
count errors are typed validation failures; an exhausted search budget is a typed
resource failure. No request, result, or history is persisted or transmitted.

## Interface behavior

The CLI command is `chimera cron parse`. It accepts the expression as an option,
standard input, or `--file`, plus `--timezone`, `--count`, `--at`, and `--json`.
JSON output has stable keys and ISO-8601 occurrence values. Human output uses the
selected message catalog. Validation exits with 64, file access with 74,
processing with 70, and resource exhaustion with 75; diagnostics never echo
the supplied expression.

The GUI exposes `/cron/parse` and uses the same utility. Its form accepts a
typed or pasted expression and can load one from a local text file through an
injectable file-picker boundary. It also contains time zone, count, and
reference-instant inputs. Results and failures are localized in English and
Brazilian Portuguese, keyboard reachable, semantically labeled, and responsive
without overflow.

## Verification

- Unit tests cover five/six fields, aliases, ranges/lists/steps, previous/next
  ordering, IANA offsets, DST gaps and overlaps, malformed values, invalid
  zones/counts, syntactic Unix day matching, maximum count, and
  bounded-resource failure.
- CLI functional tests cover argument, stdin, and real local-file input; human
  and JSON output; exit codes; redaction; and identical utility semantics.
- Widget and integration tests cover routing, localized main flow, file loading,
  AF-01, accessibility, and narrow layouts. Browser tests exercise the cron flow
  and verify that it makes no external requests, including the native Safari
  smoke test.
- The complete repository suite and required GitHub checks remain green.

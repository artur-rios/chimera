# UC-06 Format JSON Design

## Scope

UC-06 validates any JSON-compatible root value and returns deterministic,
indented JSON through the shared library, CLI, browser, and desktop interfaces.
Inputs and results remain local and ephemeral.

## Decisions

- Use one bounded, standards-compliant parser/emitter so every supported
  surface shares the same formatting behavior without first materializing an
  unbounded object graph.
- Accept objects, arrays, strings, numbers, booleans, and null at the root.
- Offer 2- or 4-space indentation, preserve object insertion order, and copy
  valid numeric lexemes exactly so native and JavaScript builds agree even for
  integers beyond JavaScript's safe range and very small exponents.
- Reject malformed JSON with a typed code, parser offset, and parser reason.
- Reject indentation values outside the explicit 2/4-space contract.
- Enforce source, node, nesting-depth, and formatted-output limits while
  parsing and emitting. A failure never exposes a partial formatted result.
- Keep validation and formatting in `chimera_utilities`; map typed failures in
  `chimera_core`; leave CLI and GUI responsible for local file and clipboard
  access, localization, and presentation only.

## Interfaces

- CLI: `chimera json format`, with `--input`/stdin/`--file`, `--indent`,
  `--output`, and `--json`.
- GUI: `/json/format`, with pasted/typed, clipboard, or local-file JSON,
  indentation control, accessible preview, copy, and local save.
- Stable JSON output reports the formatted JSON and selected indentation.

## Failure contract

- Invalid JSON or options: validation failure (exit 64), including offset and
  a source-redacted reason for malformed JSON.
- Input, clipboard, or output access failure: access failure (exit 74), without
  echoing the source or formatted result.
- Source or output budget exceeded: resource failure (exit 75), without a
  partial result.

## Verification

Tests cover every JSON root kind, nested values, Unicode and escaped strings,
both indentation options, invalid JSON location/reason, resource budgets, CLI
input/output modes, clipboard and local-file flows, localization,
accessibility, responsive GUI behavior, native integration, compiled
Chromium/Firefox/WebKit, and native Safari smoke.

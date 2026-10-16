# UC-05 Convert JSON to YAML Design

## Scope

UC-05 accepts any JSON-compatible value and returns deterministic YAML through
the shared library, CLI, browser, and desktop interfaces. Inputs and results
remain local and ephemeral.

## Decisions

- Use `yaml_writer` 2.1.0, the serializer selected by the technology stack,
  for its safe primitive encodings. Wrap it with a bounded structural emitter
  because its collection/string path does not quote every YAML-sensitive key
  or scalar and constructs the complete output before a limit can be enforced.
- Accept objects, arrays, strings, numbers, booleans, and null at the root.
- Offer two explicit formatting options: 2- or 4-space indentation, and
  automatic or forced double-quoted strings.
- Preserve object insertion order from the JSON source.
- Parse JSON with a bounded recursive-descent parser so depth and node budgets
  are enforced before each value is allocated. Reject malformed JSON with its
  parser offset and reject numeric values that cannot be represented
  consistently across Dart VM and JavaScript targets. Bound individual numeric
  tokens before conversion, reject unsafe integers during digit scanning, and
  count only meaningful coefficient digits for decimal precision.
- Enforce configurable source-size, nesting-depth, node-count, and output-size
  budgets while parsing and emitting, not after building an unbounded graph or
  string. A failure never exposes partial YAML.
- Keep parsing and serialization in `chimera_utilities`; map its typed failures
  through `chimera_core`; leave CLI and GUI responsible for local I/O,
  localization, and presentation only.

## Interfaces

- CLI: `chimera json to-yaml`, with `--input`/stdin/`--file`, `--indent`,
  `--quote-strings`, `--output`, and `--json`.
- GUI: `/json/to-yaml`, with pasted/typed or local-file JSON, formatting
  controls, accessible YAML preview, and local save.
- Stable JSON output reports the YAML plus the selected formatting metadata.

## Failure contract

- Invalid JSON or options: validation failure (exit 64), with offset when the
  JSON decoder provides one.
- Input/output access failure: access failure (exit 74), without echoing source
  or YAML.
- Source, depth, node, or output budget exceeded: resource failure (exit 75),
  without partial YAML.

## Verification

Tests cover all JSON root kinds, nested structures, multiline and YAML-sensitive
strings, formatting options, invalid JSON and numbers, every resource budget,
CLI input/output modes, localization, accessibility, responsive GUI behavior,
native integration, compiled Chromium/Firefox/WebKit, and native Safari smoke.


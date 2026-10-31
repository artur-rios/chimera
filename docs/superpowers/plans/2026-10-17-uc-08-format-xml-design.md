# UC-08 Format XML Design

## Goal

Add local XML validation and formatting to the shared utility, core service,
CLI, and Flutter GUI while preserving XML meaning and returning safe,
location-aware errors.

## Decisions

- Use the pure-Dart `xml` package. It performs no external I/O and does not
  resolve external DTD resources.
- Accept only 2- or 4-space indentation, matching the existing structured-data
  formatters.
- Preserve declarations, simple doctypes, comments, CDATA, processing
  instructions, namespaces, attributes, and text. Reject doctypes with external
  identifiers or internal subsets because the cross-platform parser does not
  validate DTD grammar or resolve declared entities. Elements containing
  non-whitespace text or `xml:space="preserve"` are emitted without whitespace
  normalization so mixed content is not changed.
- Validate with the event parser before building a DOM. The event pass enforces
  source, node, and depth budgets and stops pathological inputs early. Output is
  checked against a separate size budget.
- Map parser details to a stable `malformed-xml` reason plus one-based line and
  column and zero-based offset. Never expose source text in failure details.
- Expose `xml format` in the CLI and `/xml/format` in the GUI. Both support
  direct input, file input, UTF-8 output, 2/4-space selection, and JSON-mode
  machine-readable CLI responses. The GUI also supports paste, copy, save,
  accessible live results, and localized English/Portuguese messages.

## Failure model

- Invalid indentation or XML: validation failure / exit 64.
- Source, node, depth, or output budget exceeded: resource failure / exit 75.
- File, stdin, clipboard, or output access failure: access failure / exit 74.
- A failed operation clears any prior result so stale content cannot be copied
  or saved.

## Verification

Unit tests cover valid structure, semantic preservation, mixed content,
location-aware failures, and each resource budget. Core, CLI, GUI widget,
native integration, and browser tests cover the public workflows in both
localized and machine-readable forms.

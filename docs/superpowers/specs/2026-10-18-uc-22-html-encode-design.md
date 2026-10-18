# UC-22 HTML Encode Design

## Intent and scope

UC-22 encodes local text into HTML entities for a selected insertion context.
Processing is deterministic, local, offline, and stateless. It covers FR-EN-08,
FR-EN-17, FR-PL-01 through FR-PL-06, FR-PL-09 through FR-PL-11, BR-01 through
BR-05, and BR-19.

This use case does not parse or sanitize HTML markup, encode JavaScript or CSS,
decode entities, promise safety for unquoted attributes or raw-text elements,
persist history, or add any network, account, plugin, or collaboration behavior.
It is separate from UC-10's generic five-mode text escaper: UC-22 exposes HTML
context selection and the dedicated `chimera html encode` interface required by
FR-EN-08 and FR-PL-03.

## Canonical context contract

The shared request carries the source text and one stable context identifier:

| Context | Intended insertion point | Entities emitted |
| --- | --- | --- |
| `all` | Unknown quoted-attribute or normal-element context | `&`, `<`, `>`, `"`, `'`, `/` |
| `element` | Normal element text content | `&`, `<`, `>` |
| `double-quoted-attribute` | Double-quoted attribute value | `&`, `<`, `>`, `"` |
| `single-quoted-attribute` | Single-quoted attribute value | `&`, `<`, `>`, `'` |

`all` is the default and maps to Dart's `HtmlEscapeMode.unknown`; the other
values map to `element`, `attribute`, and `sqAttribute`. The implementation uses
`dart:convert`'s `HtmlEscape`, which is the approved platform primitive in the
Technology Stack Document. Entity spellings therefore follow the Dart SDK:
`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`, and `&#47;`.

Every mode always encodes ampersands, so existing entity-looking text is encoded
as text rather than trusted or double-interpreted. Input must be well-formed
Unicode scalar text: paired supplementary characters are accepted, while
isolated UTF-16 surrogates are rejected before UTF-8 serialization can replace
them differently across adapters. Other text, including combining marks, NUL,
and line endings, is preserved without normalization. Empty input is valid and
produces empty output. Local files and standard input are decoded as strict UTF-8
without BOM stripping, newline conversion, or replacement characters.

Only the four exact lowercase context identifiers are accepted. Aliases, empty
context, casing variants, and custom boolean combinations are rejected so all
interfaces share one stable contract. This gives AF-01 a deterministic typed
validation path without exposing Dart SDK objects at an application boundary.

`HtmlEntityEncoder` supports nullable injected input and output character budgets
for deterministic resource tests; production applies no product-specific size
limit. Input is checked before conversion, output after complete private
conversion, and `OutOfMemoryError` becomes a resource failure. No partial output
is returned.

Stable utility failures are:

- `html-encode.invalid-context`, field `context`, reason
  `unsupported-context`; and
- `html-encode.invalid-input`, field `input`, reason `invalid-unicode` or
  `invalid-utf8`; and
- `html-encode.resource-limit`, field `input` or `encoded`, reason
  `input-limit`, `output-limit`, or `allocation-limit`.

Diagnostics never contain the source or encoded text.

## Shared result and service

`chimera_utilities` owns `HtmlEntityEncodeRequest`, `HtmlEntityEncodeResult`,
`HtmlEntityEncodeException`, and `HtmlEntityEncoder`. The result contains the
encoded string and canonical context.

`chimera_core` owns `HtmlEncodeOperationRequest`, `HtmlEncodeOutput`, and
`HtmlEncodeService`. The service delegates exactly once to the utility and maps
invalid context to `FailureKind.validation` and budgets/allocation to
`FailureKind.resource`. Its stable ordered JSON is:

```json
{
  "encoded": "&lt;strong&gt;",
  "context": "element"
}
```

## CLI adapter

The CLI adds:

```text
chimera html encode [--context=<context>]
  (--input=<text>|--file=<path>|stdin) [--output=<path>] [--json]
```

The default context is `all`. Exactly one source is accepted. Direct arguments
use strict scalar text; files and stdin are read as bytes and decoded through the
shared strict UTF-8 path. Structural options are validated before file or
standard-input access. Without `--output` or
`--json`, stdout receives the exact encoded text with no added newline.
`--output` uses the existing staged transactional writer to save exact UTF-8
bytes, then emits one localized success summary. JSON emits only the stable
envelope plus one terminal LF and only after a requested save succeeds.

Validation exits 64, input/output access exits 74, and resource failures exit
75. Failed writes preserve existing destinations, clean temporary artifacts,
emit no success result, and retain no result copy. English and Brazilian
Portuguese diagnostics are redacted.

## Interactive adapter

The GUI adds `/html/encode` and a localized home action. It accepts typed text,
a local UTF-8 text file, or clipboard text; offers the four localized contexts;
and defaults to `all`. Success presents selectable exact output plus copy and
save actions. Save uses `chimera-html-encoded.txt` and
`text/plain; charset=utf-8`.

Input or context changes clear stale results and notices. Cancellation is
neutral. File, clipboard, service, copy, and save operations disable competing
actions and use generation guards so stale async completions cannot publish.
File and clipboard strings use the same shared strict text validation. Adapter
allocation failures while loading a source or creating transient UTF-8 output
bytes map to resource failures through injectable conversion seams; genuine
platform denial remains access failure. After service completion, the request is
no longer retained. Copy or save
failure clears the result and publishes a localized access error, satisfying
AF-02 without a false success.

Focus order is input, file/paste, context, encode, result, copy, save. Results,
notices, and failures use accessible semantics and live regions. Both locales,
keyboard operation, 48-by-48 targets, narrow layout, 200-percent text, and
contrast are covered.

## Cross-platform and security evidence

Known-answer tests independently pin every entity spelling and context, including
ampersands, both quotes, slash, angle brackets, empty input, ASCII, Unicode,
supplementary characters, controls, CRLF, existing entity-looking text, isolated
surrogate rejection, and malformed UTF-8 rejection.
Mutation and boundary tests cover unsupported contexts, exact and exceeded
budgets, allocation failure mapping, repeated stateless calls, and redaction.

Core tests pin delegation, result shape, JSON order, and typed mappings. CLI
tests cover direct/stdin/file sources, default and every explicit context,
human/JSON/save output, both locales, exits, transactional rollback, redaction,
and validation before I/O. Widget tests cover source selection, every context,
stale-result clearing, copy/save, AF-02, races, localization, accessibility, and
layout. Native Windows/Linux and compiled Chromium/Firefox/WebKit/native Safari
exercise representative exact-output, copy/save, keyboard, and zero-network
flows.

## Requirement audit

- Main flow and FR-EN-08: one shared encoder validates a canonical context and
  returns deterministic HTML entities through every interface.
- AF-01 and FR-EN-17: unsupported context values produce typed, redacted
  validation failures with no result.
- AF-02: CLI transactional output and GUI copy/save adapters report access
  failures, retain no result, and publish no success.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, desktop, and browser consume
  the same utility/service with stable human, JSON, and exit-code contracts.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: requests/results are
  ephemeral and no persistence, history, telemetry, network, accounts, plugins,
  mobile, or collaboration surface is added.

No main flow, alternative flow, or traced requirement is deferred.

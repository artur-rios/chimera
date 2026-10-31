# UC-23 HTML Decode Design

## Intent and scope

UC-23 decodes recognized HTML character references into local text. Processing
is deterministic, local, offline, and stateless. It covers FR-EN-09,
FR-EN-17, FR-PL-01 through FR-PL-06, FR-PL-09 through FR-PL-11, BR-01
through BR-05, and BR-19.

This use case does not parse HTML markup, repair browser-style HTML, sanitize
content, decode references without a semicolon, persist history, or introduce
network, account, plugin, or collaboration behavior. It is distinct from
UC-11's generic five-mode Text Unescape interface: UC-23 exposes the dedicated
`chimera html decode` command and `/html/decode` interactive route required by
FR-EN-09 and FR-PL-03.

## Canonical decoding contract

The decoder recognizes the exact strict HTML reference set already established
by Text Unescape:

- named references `&amp;`, `&lt;`, `&gt;`, `&quot;`, and `&apos;`;
- decimal numeric references such as `&#39;` and `&#128512;`; and
- hexadecimal numeric references with lowercase or uppercase `x`, such as
  `&#xE9;` and `&#X1F600;`.

Every reference must end with a semicolon. Unknown named references, missing
semicolons, empty or signed numeric bodies, non-digits, values above U+10FFFF,
and UTF-16 surrogate values are malformed. A literal ampersand begins a
reference and is therefore malformed unless the complete recognized reference
follows. Other literal text is preserved exactly, including combining marks,
NUL, line endings, and supplementary Unicode scalars. Empty input is valid and
produces empty output. References are decoded once, from left to right, so
`&amp;lt;` becomes `&lt;`, not `<`.

Text input must contain only well-formed Unicode scalars. Local files and
standard input are decoded as strict UTF-8 without BOM stripping, newline
conversion, or replacement characters. This preserves the UC-22 round-trip
contract: every output produced by any HTML Encode context can be decoded back
to its original text.

`HtmlEntityDecoder` supports nullable injected input and output character
budgets for deterministic resource tests; production applies no
product-specific size limit. It validates the complete private conversion
before returning output, maps allocation exhaustion to a resource failure, and
never returns partial text.

Stable utility failures are:

- `html-decode.malformed-input`, field `input`, with reason
  `unknown-entity`, `unterminated-entity`, `invalid-number`, `out-of-range`,
  `surrogate-scalar`, or `invalid-utf8` and a safe offset where applicable;
  and
- `html-decode.resource-limit`, field `input` or `decoded`, with reason
  `input-limit`, `output-limit`, or `allocation-limit`.

Diagnostics never contain source or decoded text.

Offsets for entity syntax, numeric scalar, and literal-surrogate failures are
zero-based UTF-16 code-unit indexes into the decoded input string, matching the
existing Text Unescape contract. Malformed UTF-8 reports the zero-based byte
offset in the original byte source. Budget and allocation failures have no
meaningful source location and omit the offset. An isolated surrogate in direct
literal text uses `surrogate-scalar`, the same reason Text Unescape already
publishes; the new dedicated contract does not introduce a competing
`invalid-unicode` spelling.

## Shared implementation and compatibility

`chimera_utilities` owns `HtmlEntityDecodeRequest`,
`HtmlEntityDecodeResult`, `HtmlEntityDecodeException`, and
`HtmlEntityDecoder`. The result contains only the decoded text.

The existing Text Unescape HTML mode delegates to `HtmlEntityDecoder` and maps
its failures back to the existing `text-unescape.*` error contract. Its public
request, result, reason, offset, resource limits, and behavior remain unchanged.
This extraction ensures FR-PL-01 is satisfied by one HTML decoding algorithm
instead of maintaining a second UC-23 implementation.

`chimera_core` owns `HtmlDecodeOperationRequest`, `HtmlDecodeOutput`, and
`HtmlDecodeService`. The service accepts either direct scalar text or strict
UTF-8 bytes, delegates once to the utility, and maps malformed input to
`FailureKind.validation` and budgets/allocation to `FailureKind.resource`. Its
stable ordered JSON is:

```json
{
  "decoded": "<strong>"
}
```

## CLI adapter

The CLI adds:

```text
chimera html decode
  (--input=<text>|--file=<path>|stdin) [--output=<path>] [--json]
```

Exactly one source is accepted. Direct arguments use strict scalar text; files
and stdin are read as bytes and decoded through the shared strict UTF-8 path.
Structural options are validated before file or standard-input access. Without
`--output` or `--json`, stdout receives the exact decoded text with no added
newline. `--output` uses the existing staged transactional writer to replace
the destination with exact UTF-8 bytes before emitting one localized success
summary. JSON emits only the stable envelope plus one terminal LF and only
after a requested save succeeds.

Validation and malformed-entity failures exit 64, input/output access failures
exit 74, and resource failures exit 75. Failed writes preserve existing
destinations, remove temporary artifacts, emit no success result, and retain no
result copy. English and Brazilian Portuguese diagnostics are redacted.

## Interactive adapter

The GUI adds `/html/decode` and a localized home action. It accepts typed text,
a local UTF-8 text file, or clipboard text. Success presents selectable exact
output plus copy and save actions. Save uses `chimera-html-decoded.txt` and
`text/plain; charset=utf-8`.

Input changes clear stale results and notices. Cancellation is neutral. File,
clipboard, service, copy, and save operations disable competing actions and use
generation guards so stale asynchronous completions cannot publish. Adapter
allocation failures while loading a source or creating transient UTF-8 output
bytes map to resource failures through injectable conversion seams; genuine
platform denial remains an access failure. After service completion, the source
and editor undo history are discarded. Copy or save failure clears the result
and publishes a localized access error, satisfying AF-02 without a false
success.

Focus order is input, file, paste, decode, result, copy, save. Results, notices,
and failures use accessible semantics and live regions. Both locales, keyboard
operation, 48-by-48 targets, narrow layout, 200-percent text, and contrast are
covered.

## Cross-platform and security evidence

Known-answer tests independently pin every recognized named reference, decimal
and hexadecimal references, uppercase `X`, decode-once behavior, empty input,
ASCII, Unicode, supplementary characters, controls, CRLF, isolated surrogate
rejection, and malformed UTF-8 rejection. Mutation and boundary tests cover
unknown/unterminated/invalid/out-of-range references, exact and exceeded
budgets, allocation failure mapping, repeated stateless calls, and redaction.

Core tests pin direct-text and UTF-8 delegation, stable JSON order, and typed
mappings. CLI tests cover direct/stdin/file sources, human/JSON/save output,
both locales, exits, transactional rollback, redaction, and validation before
I/O. Widget tests cover every source, stale-result clearing, copy/save, AF-01,
AF-02, races, localization, accessibility, and layout. Native Windows/Linux and
compiled Chromium/Firefox/WebKit/native Safari exercise representative exact
decode, copy/save, keyboard, empty output, malformed input, cleanup, and
zero-network flows.

## Requirement and flow audit

- Main flow and FR-EN-09: one shared decoder validates and decodes the canonical
  reference set through every interface.
- AF-01 and FR-EN-17: malformed entity text, invalid Unicode, and malformed
  UTF-8 produce typed, redacted failures with no result.
- AF-02: CLI transactional output and GUI copy/save adapters report access
  failures, retain no result, and publish no success.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, desktop, and browser consume
  the same utility/service with stable human, JSON, and exit-code contracts.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: requests/results are
  ephemeral and no persistence, history, telemetry, network, accounts, plugins,
  mobile, or collaboration surface is added.

No main flow, alternative flow, or traced requirement is deferred.

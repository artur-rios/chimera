# UC-16 Base64 Encode Design

## Scope and traceability

UC-16 Base64-encodes UTF-8 text or exact local-file bytes and returns canonical
Base64 text. It covers FR-EN-01, FR-EN-17 through FR-EN-18, FR-PL-01 through
FR-PL-06, FR-PL-09 through FR-PL-11, BR-01 through BR-05, and BR-19.
Processing is deterministic, local, offline, and stateless. One shared utility
contract is consumed by core, CLI, desktop, and web adapters.

## Encoding contract

`chimera_utilities` owns `Base64ByteEncoder`. It emits standard RFC 4648 Base64
with the `A-Z`, `a-z`, `0-9`, `+`, and `/` alphabet, canonical `=` padding, and
no whitespace or line wrapping. Empty input is valid and produces an empty
string. Source selection is always based on the selected flag or input mode,
never on whether its content is empty.

The shared utility exposes `encodeBytes(List<int>)`, `encodeText(String)`, and
`encodeUtf8(List<int>)`. `encodeText` requires exact well-formed Unicode scalar
text: paired supplementary characters are accepted, while isolated UTF-16
surrogates are rejected before `utf8.encode` can replace them. `encodeUtf8`
strictly validates raw stdin bytes with `allowMalformed: false`. Neither path
trims, strips a BOM, converts CRLF, normalizes Unicode, nor changes trailing
whitespace/newlines. Local files use `encodeBytes` and pass through unchanged,
so arbitrary binary values including zero and `0xff` are supported. The utility
also validates that every public-list member is an integer byte in `0..255`.

Successful utility results contain:

- `encoded`: the canonical Base64 string;
- `inputByteCount`: the exact source byte count; and
- `outputCharacterCount`: the Base64 string length.

The encoder has nullable injectable `maxInputBytes` and
`maxOutputCharacters` budgets. Production defaults are unbounded to honor the
requirement that Chimera adds no product-specific size ceiling; tests inject
small limits to prove AF-02. The expected output length is checked before
encoding when a limit is configured. Allocation exhaustion during strict text
conversion or Base64 generation is mapped to the same typed resource failure,
with no partial result returned. CLI and GUI adapters separately map allocation
exhaustion during byte-source loading and transient output-buffer creation to a
resource failure rather than an access failure.

Stable failures use these fields:

- invalid byte: kind `validation`, code `base64-encode.invalid-byte`, field
  `input`, reason `byte-range`;
- malformed string text: kind `validation`, code
  `base64-encode.invalid-text`, field `input`, reason `invalid-unicode`;
- malformed UTF-8 stdin: kind `validation`, code
  `base64-encode.invalid-text`, field `input`, reason `invalid-utf8`;
- input budget: kind `resource`, code `base64-encode.resource-limit`, field
  `input`, reason `byte-limit`;
- output budget: kind `resource`, code `base64-encode.resource-limit`, field
  `output`, reason `character-limit`;
- allocation exhaustion: kind `resource`, code
  `base64-encode.resource-limit`, field `output`, reason `allocation-limit`.

## Core service and serialization

`chimera_core` owns `Base64EncodeOperationRequest`, `Base64EncodeOutput`, and
`Base64EncodeService`. Factory constructors represent exact binary bytes,
well-formed string text, or strict UTF-8 bytes; the service dispatches every
source through the matching shared utility entry point. This keeps Unicode and
UTF-8 conversion out of CLI/GUI adapters and maps utility exceptions to the
shared typed `OperationFailure` model without logging or echoing input.

`Base64EncodeOutput.toJson()` is stable and ordered as:

```json
{
  "encoded": "SGVsbG8=",
  "inputByteCount": 5,
  "outputCharacterCount": 8
}
```

No service stores the request or result after returning. The encoded string is
the sole domain result. Save adapters may create one transient UTF-8 write
buffer and discard it when the write completes; no history or second retained
copy is introduced. FR-EN-18's binary-result rule is not otherwise activated
because UC-16 returns text rather than decoded binary output.

## CLI adapter

The CLI adds `chimera base64 encode` with exactly one source:

- `--text=<value>` for a literal UTF-8 text value;
- `--stdin` for UTF-8 standard input; or
- `--file=<path>` for exact local-file bytes.

`--json` selects the stable service JSON. Without an output path, human stdout
is localized and uses Base64-safe single-line output:

```text
Base64: SGVsbG8=
Input bytes: 5
Output characters: 8
```

JSON stdout contains one trailing platform-independent newline, matching other
commands. `--output=<path>` without `--json` writes only the raw canonical
`encoded` value with no newline; `--json --output` writes the exact stable JSON
object with no newline. This makes a saved non-JSON artifact directly usable as
Base64 rather than wrapping it in localized labels. Source cardinality is
validated before stdin/file reads and is based on flag presence, so
`--text=""`, empty stdin, and an empty file are valid zero-byte sources.
The CLI reads stdin as raw bytes and delegates strict UTF-8 validation to core.
Stable CLI failures are:

- missing/conflicting source or unknown options: exit 64, validation;
- malformed text/UTF-8: exit 64, validation;
- genuine stdin/file/output access failure: exit 74, access;
- utility resource failure: exit 75, resource.

Diagnostics are localized in English and Brazilian Portuguese and never echo
source text, bytes, paths, or collaborator exception details.

## Interactive adapter

The GUI adds `/base64/encode` and a localized home action. The page provides:

- a multiline UTF-8 text field;
- local binary file loading;
- text paste from the local clipboard;
- an accessible Base64 result preview with byte/character counts;
- raw Base64 copy; and
- exact Base64 text save as `chimera-base64.txt`.

Text and file modes are exclusive. Loading a file clears text and retains only
the selected bytes for the pending operation; typing or pasting clears the file
selection. Empty text is a valid selected text source. A localized byte-count
summary makes binary-file selection visible without attempting to decode or
render it. Input changes, pending loads, and adapter failures clear stale
results. While an adapter or encoding call is in flight, all racing actions are
disabled.

File, clipboard, and save adapters remain injectable. Allocation exhaustion
raised by file/clipboard/save adapters maps to the localized resource failure;
other exceptions map to the appropriate access failure. File bytes, temporary
UTF-8 conversion bytes, and results exist only in widget state for the active
operation and are released when replaced or the page is disposed. Nothing is
persisted or transmitted.

The natural focus order is text, file, paste, encode, result, copy, and save.
Every control has a localized accessible label and keyboard activation. Result
semantics announce success plus byte/character counts but exclude the full
Base64 string, preventing an arbitrarily long screen-reader utterance; the
visible result remains selectable and the labeled copy action exposes its exact
content. Errors use a live region. Automated contrast and tap-target guidance,
narrow width, and 200% text scale are verified in both locales and recorded in
`docs/operations/accessibility-review.md`.

## Cross-platform evidence

- Utility known-answer tests cover RFC 4648 vectors, empty input, arbitrary
  binary bytes, UTF-8 text, exact count metadata, invalid byte values, and both
  resource boundaries.
- Core tests cover exact stable JSON plus redacted validation/resource mapping.
- CLI tests cover literal, stdin, binary file, human/JSON/raw-output-file modes,
  empty sources, strict Unicode/UTF-8 boundaries, source cardinality, unknown
  options, both locales, access failures, allocation failures, redaction, and
  exit 75 without partial output.
- Widget tests cover text/file/clipboard sources, empty text, exact copy/save
  payloads, source-mode switching, stale/busy cleanup, access/allocation/resource
  failures, logical focus and keyboard activation, localized labels, bounded
  semantics, contrast/tap targets, both locales, and narrow 200%-text layout.
- Windows/Linux integration exercises UTF-8 text plus injected `0x00/0xff`
  file bytes and an exact copy/save assertion.
- Compiled Chromium, Firefox, and WebKit tests use a real browser file chooser
  for `0x00/0xff`, assert exact Base64 plus copy/save behavior, and reject
  unexpected external requests. The native Safari source smoke receives the
  same bounded binary fixture flow.

## Requirement audit

- FR-EN-01/main flow: known-answer, CLI, widget, native, and browser tests prove
  UTF-8 text and exact local-file bytes encode to canonical Base64.
- FR-EN-17: public invalid bytes, isolated surrogates, malformed UTF-8 stdin,
  and malformed adapter options return typed, redacted validation failures.
- FR-EN-18: save paths write exact local output and retain no second persistent
  copy; decoded binary-result handling remains UC-17 scope.
- AF-01: CLI and widget tests inject file-read failures and prove no result.
- AF-02: injected byte/output budgets and source/output adapter allocation
  failures prove resource handling without partial output; CLI exits 75 and GUI
  clears stale output.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, GUI, native, and compiled
  browser adapters consume the same service and stable result semantics.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: no history,
  preference, account, plugin, collaboration, or network path is added;
  compiled-browser flows explicitly fail on unexpected external requests.


# UC-17 Base64 Decode Design

## Scope and traceability

UC-17 decodes canonical Base64 to strict UTF-8 text or exact binary bytes and
previews supported images. It covers FR-EN-02 through FR-EN-03, FR-EN-17
through FR-EN-18, FR-PL-01 through FR-PL-06, FR-PL-09 through FR-PL-11,
BR-01 through BR-05, and BR-19. Processing is deterministic, local, offline,
and stateless. One shared decoder is consumed by core, CLI, desktop, and web
adapters.

## Decoding contract

`chimera_utilities` owns `Base64ByteDecoder`. It accepts canonical RFC 4648
Base64 using the standard `A-Z`, `a-z`, `0-9`, `+`, and `/` alphabet, required
`=` padding, and no whitespace or line wrapping. Empty input is valid and
decodes to zero bytes. URL-safe alphabet characters, missing or excess padding,
embedded whitespace, non-ASCII input, invalid lengths, and non-zero padding
bits are rejected. A successful decode is round-tripped through the canonical
encoder to enforce the padding-bit rule.

The decoder exposes string and strict-UTF-8 byte entry points. Raw stdin and
Base64 files are decoded as UTF-8 with `allowMalformed: false`, then validated
by the same canonical parser. Public byte-list entry points validate that every
member is in `0..255`. No source is trimmed, normalized, or rewritten.

The caller selects `text` or `binary` output. Binary mode accepts every decoded
byte sequence. Text mode strictly decodes the result as UTF-8 and rejects
malformed sequences rather than inserting replacement characters. Successful
results contain one immutable decoded `Uint8List`, an optional decoded text
view for text mode, input character count, output byte count, and an optional
image-preview candidate media type. The decoder recognizes PNG, JPEG,
GIF87a/GIF89a, and WebP signatures only as preview candidates. The interactive
adapter must successfully decode a complete image before declaring the preview
available. A truncated or corrupt signature candidate remains exact binary
output and falls back to a nonfatal unavailable-preview notice.

Nullable injectable `maxInputCharacters` and `maxOutputBytes` budgets provide
deterministic resource-boundary tests while production remains unbounded. The
decoded length is predicted from canonical length and padding before allocation.
Allocation exhaustion is mapped to a typed resource failure, and no partial
result is returned.

Stable failures are:

- malformed Base64: kind `validation`, code `base64-decode.invalid-input`,
  field `input`, reason `malformed-base64`;
- out-of-range public input byte: kind `validation`, code
  `base64-decode.invalid-input`, field `input`, reason `byte-range`;
- malformed UTF-8 Base64 source: kind `validation`, code
  `base64-decode.invalid-input`, field `input`, reason `invalid-utf8`;
- decoded bytes are not UTF-8 in text mode: kind `validation`, code
  `base64-decode.invalid-text`, field `output`, reason `invalid-utf8`;
- input/output budgets: kind `resource`, code
  `base64-decode.resource-limit`, field `input` or `output`, reason
  `character-limit` or `byte-limit`;
- allocation exhaustion: kind `resource`, code
  `base64-decode.resource-limit`, field `output`, reason `allocation-limit`.

## Core service and serialization

`chimera_utilities` owns and exports `Base64DecodeMode` because mode selects the
utility's strict text conversion. `chimera_core` owns
`Base64DecodeOperationRequest`, `Base64DecodeOutput`, and
`Base64DecodeService`. Request factories represent a string source or
strict-UTF-8 source bytes and require an explicit utility-owned output mode. The
service delegates all parsing, text decoding, candidate signature detection,
and resource mapping to the shared utility.

`Base64DecodeOutput.toJson()` always has this ordered shape:

```json
{
  "mode": "text",
  "text": "Hello",
  "bytes": null,
  "inputCharacterCount": 8,
  "outputByteCount": 5,
  "imageCandidateMediaType": null
}
```

Binary mode sets `text` to `null` and `bytes` to the decoded integer list. Text
mode sets `bytes` to `null`. `imageCandidateMediaType` reports signature
detection only and never claims successful rendering. The service retains only
the utility result for the duration of the returned output. JSON serialization
is transient and saving passes the same decoded byte list directly to the
adapter.

## CLI adapter

The CLI adds `chimera base64 decode` with exactly one source:

- `--text=<value>` for literal Base64, including an explicitly empty value;
- `--stdin` for strict UTF-8 Base64 bytes; or
- `--file=<path>` for strict UTF-8 Base64 file bytes.

`--mode=text|binary` is required. Text-mode human stdout is the exact decoded
text with no label and no added newline. `--json` writes the stable JSON object
followed by exactly one `\n`. Binary mode requires either `--output=<path>` or
`--json`; plain human stdout without an output path is rejected so arbitrary
bytes never pass through a text sink. `--output` always writes the result's
exact decoded bytes in either mode. A non-JSON save prints one localized success
line only after the write succeeds. With `--json`, the stable JSON object and
one trailing `\n` are written to stdout only after an optional save succeeds.
No partial stdout is emitted before decoding and output writing finish.

Every structural check—unknown options, exact source cardinality, mode value,
and the binary destination/JSON requirement—runs before stdin or file access.
The production output writer stages bytes beside the destination, flushes them,
and replaces the destination only after a complete write. A failed write
removes its staged file and leaves no newly created or partially replaced
result; the adapter retains no byte copy. Tests inject a writer that simulates a
partial stage failure and assert cleanup plus an unchanged prior destination.
Stable exits are 64 for validation, 74 for input/output access, and 75 for
resource failure.
Diagnostics are localized in English and Brazilian Portuguese and never echo
Base64 input, decoded content, paths, or collaborator exception details.

## Interactive adapter

The GUI adds `/base64/decode` and a localized home action. It provides a
multiline Base64 field, local Base64-file loading, text paste, and an explicit
text/binary selector. Changing any source or mode clears stale output and
notices. File selection and typed/pasted text are exclusive, empty text is a
valid selected source, and all racing actions are disabled while work is in
flight.

Text mode displays selectable decoded text, supports exact text copy, and saves
the decoded UTF-8 bytes as `chimera-decoded.txt`. Binary mode displays the byte
count and asks an injectable preview decoder to validate recognized
PNG/JPEG/GIF/WebP candidates. Only a successfully decoded image is rendered and
announced as available. The preview decoder returns one owned, disposable
preview resource backed by a decoded `ui.Image`; the page renders it directly
with `RawImage` and never inserts source bytes or the decoded image into
Flutter's global `ImageCache`. The page disposes the preview on replacement,
source or mode change, decode/load failure, route disposal, and any stale async
completion. Browser implementations create no object URL; any future adapter
that does create one must revoke it at the same lifecycle boundaries. The same
result bytes are saved directly. Only a renderer-confirmed preview uses its
`.png`, `.jpg`, `.gif`, or `.webp` extension; an unsupported, rejected, corrupt,
or failed candidate uses `chimera-decoded.bin`. Binary output is not copied
through a text clipboard.

File, clipboard, save, and preview boundaries remain injectable. File,
clipboard, save, and decode allocation exhaustion maps to resource failure;
other file/clipboard/save exceptions map to access failure. Preview rejection,
ordinary preview exceptions, and preview allocation exhaustion are deliberately
nonfatal: exact binary output and save remain available, any stale image is
disposed and removed, and one localized live-region notice says preview is
unavailable. A failed decode/load/copy/save clears stale success as applicable,
and a failed transactional save retains no staged or adapter copy. Nothing is
persisted or transmitted.

The focus order is Base64 input, file, paste, output mode, decode, result,
text-copy when applicable, and save. Success semantics announce mode, input
characters, output bytes, and image availability without announcing arbitrary
decoded content. Errors and notices are live regions. Both locales, narrow
layout, 200% text, contrast guidance, keyboard operation, and tap targets are
covered.

## Cross-platform evidence

- Utility tests cover RFC 4648 vectors, empty input, binary bytes, strict UTF-8,
  canonical padding and pad bits, every malformed class, image signatures,
  counts, and both resource boundaries.
- Core tests cover both modes, exact stable JSON, one-byte-list ownership, and
  redacted validation/resource mapping.
- CLI tests cover literal/stdin/file sources, empty input, text/binary modes,
  JSON, exact raw save, required binary destination behavior, both locales,
  access/allocation failures, validation-before-read, exits, and redaction.
- Widget tests cover text/file/clipboard sources, mode switching, UTF-8 failure,
  exact copy/save, valid rendered PNG/JPEG/GIF/WebP fixtures, corrupt/truncated
  signature candidates, ordinary/allocation preview failures, stale-image
  cleanup, recording-fake disposal at every lifecycle boundary, absence of
  global image-cache/object-URL use, localized accessibility, focus, and
  responsive layout.
- Windows/Linux integration covers UTF-8 text and exact binary save. Compiled
  Chromium, Firefox, WebKit, and native Safari cover a small valid PNG Base64
  value, preview, exact download/save, and zero unexpected network requests.

## Requirement audit

- FR-EN-02/main flow: shared known-answer, CLI, GUI, native, and browser tests
  prove exact text and binary decoding.
- FR-EN-03: valid PNG/JPEG/GIF/WebP fixtures render in widget coverage and a PNG
  renders on native/compiled-browser targets; unsupported and corrupt candidate
  bytes remain exact binary without a false available-preview announcement.
- FR-EN-17/AF-01: malformed Base64 and invalid decoded UTF-8 return typed,
  redacted validation failures with no partial result.
- FR-EN-18/AF-02: output adapters receive the result's exact byte list;
  staged/partial write failures remove the stage, preserve a prior destination,
  return access failure before success stdout, and retain no adapter copy.
- FR-PL-01 through FR-PL-06 and BR-02: all adapters consume one service and
  stable result contract with documented sources, formats, and exit codes.
- FR-PL-09 through FR-PL-11 and BR-03 through BR-05/BR-19: no history,
  preference, account, plugin, collaboration, or production network path is
  added; browser interactions explicitly assert zero unexpected requests.

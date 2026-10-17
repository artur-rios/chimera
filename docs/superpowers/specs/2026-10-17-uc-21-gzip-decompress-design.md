# UC-21 GZIP Decompress Design

## Intent and scope

UC-21 decompresses local RFC 1952 GZIP bytes into explicit text or binary
output. Processing is local, offline, deterministic, and stateless. It covers
FR-EN-07, FR-EN-17 through FR-EN-18, FR-PL-01 through FR-PL-06, FR-PL-09
through FR-PL-11, BR-01 through BR-05, and BR-19.

This use case does not decode Base64, extract TAR/ZIP archives, infer output
type from metadata, use an embedded filename as a path, or add history,
accounts, plugins, collaboration, telemetry, or network behavior.

## Strict GZIP contract

The shared utility accepts raw byte lists. Every element must be in the
inclusive range 0 through 255. Empty source is invalid, while a valid GZIP
member whose uncompressed payload is empty succeeds.

Valid input is exactly one or more concatenated RFC 1952 members. Members are
decoded in order and their uncompressed bytes are concatenated. The parser:

- requires magic `1f 8b`, compression method DEFLATE (`CM=8`), and clear
  reserved flag bits;
- accepts FTEXT and safely parses FEXTRA, FNAME, FCOMMENT, and FHCRC;
- verifies FHCRC when present and always verifies each member's CRC32 and
  ISIZE modulo 2^32;
- accepts arbitrary MTIME, XFL, OS, filename, and comment metadata without
  exposing or acting on it; and
- rejects malformed optional fields, invalid DEFLATE, truncation, checksum or
  size mismatches, unsupported methods/flags, leading junk, and every trailing
  byte, including NUL padding.

Raw DEFLATE, zlib, ZIP, and other formats are not accepted. If any member in a
concatenated stream fails, no output is published.

`archive` 4.5.2 supplies the platform-independent Dart `Inflate` engine,
stream primitives, and CRC32 implementation. Chimera owns the strict member
framing parser and bounded output adapter. Each member is decoded through
`Inflate.lazy(...).inflateBlock()` until the final block returns `false`; the
eager `Inflate.stream` constructor is not used because it can stop on malformed
DEFLATE without reporting failure. It does not use `GZipDecoder`'s
platform facade: that API may return partial output for truncation, falls back
to zlib for missing GZIP headers, does not consistently enforce reserved flags
or FHCRC, and differs between native and web targets.

Each member writes through a member-scoped facade over one private aggregate
buffer. Its `length`, `subset`, and `writeBackReference` expose only bytes from
the current member, resetting DEFLATE history at every member boundary. The
facade checks the aggregate output budget before every `writeByte`,
`writeBytes`, `writeStream`, and `writeBackReference`, using subtraction-based
overflow-safe comparisons and never allocating from attacker-controlled ISIZE.

## Modes, result, and ownership

`GzipDecompressMode` is explicitly `text` or `binary`; FTEXT never selects it.
Binary mode accepts arbitrary decompressed bytes. Text mode decodes the complete
payload with strict UTF-8, without replacement or normalization. A leading
UTF-8 BOM remains U+FEFF, matching the established Base64 decode contract.

`GzipDecompressor.decompressBytes` returns `GzipDecompressionResult` with:

- `mode`;
- one immutable `Uint8List bytes`;
- optional `text`, present only in text mode;
- `inputByteCount`; and
- `outputByteCount`.

The result owns one copied immutable byte list. Save adapters receive that exact
list. JSON byte arrays are transient views. Chimera retains no compressed-source
reference after completion, and every application-owned source state or partial
buffer is cleared before returning or failing; callers may still own their
original input list.

Nullable `maxInputBytes` and `maxOutputBytes` make resource boundaries testable
without imposing a product-specific production limit. Input is checked before
copying. Output is checked on every write so a small input cannot expand past a
configured limit. Input copying, inflate output, CRC verification, result
ownership, and UTF-8 conversion allocation failures become typed resource
failures with no partial result.

Stable utility failures are:

- `gzip-decompress.invalid-input`, field `input`, reason `byte-range`;
- `gzip-decompress.invalid-archive`, field `input`, reason
  `malformed-gzip`, `corrupt-gzip`, or `unsupported-gzip`;
- `gzip-decompress.invalid-text`, field `output`, reason `invalid-utf8`; and
- `gzip-decompress.resource-limit`, field `input` or `output`, reason
  `byte-limit` or `allocation-limit`.

No dependency message, bytes, metadata, path, or decoded content crosses the
failure boundary.

Archive failure reasons are classified consistently:

| Reason | Conditions |
| --- | --- |
| `malformed-gzip` | Empty/short input, bad magic, truncated header/optional field/DEFLATE/trailer, unterminated name/comment, leading or trailing junk, or another structural framing failure. |
| `unsupported-gzip` | Compression method other than DEFLATE or any reserved flag bit. |
| `corrupt-gzip` | Invalid DEFLATE/Huffman/stored-block data, FHCRC mismatch, CRC32 mismatch, or ISIZE mismatch. |

For concatenated input, the reason is the first failing member's condition and
the entire operation fails without output.

## Core service and serialization

`chimera_core` owns `GzipDecompressOperationRequest`,
`GzipDecompressOutput`, and `GzipDecompressService`. The request carries raw
bytes and the explicit mode. The service delegates once and maps archive/text
failures to validation and budget/allocation failures to resource failures.

`GzipDecompressOutput.toJson()` has this stable ordered shape:

```json
{
  "mode": "text",
  "text": "hello",
  "bytes": null,
  "inputByteCount": 25,
  "outputByteCount": 5
}
```

Binary mode has `text: null` and the output byte array in `bytes`.

## CLI adapter

The CLI adds:

```text
chimera gzip decompress (--stdin|--file=<path>) --mode=text|binary
  [--output=<path>] [--json]
```

There is no text argument because GZIP input is raw bytes. Mode is required.
Without `--output` or `--json`, text mode writes the exact decoded text without
an added newline. Binary human output requires `--output`; `--json` is also a
valid destination. `--output` saves exact decoded bytes for either mode through
the existing staged transactional writer, then emits one localized success
summary instead of also printing decoded text. JSON emits JSON only, with one
terminal LF and only after any requested save succeeds.

Structural options are validated before stdin/file access. Validation exits
64, input/output access exits 74, and resource failures exit 75. Failed writes
preserve existing destinations, remove temporary artifacts, emit no success,
and retain no result copy. English and Brazilian Portuguese diagnostics are
typed and redacted.

## Interactive adapter

The GUI adds `/gzip/decompress` and a localized home action. It accepts one
arbitrary local file and validates GZIP by content, never by extension, plus an
explicit Text/Binary selector. Clipboard input is not
offered because supported clipboard adapters are text-only and Base64-wrapping
would create an unrelated encoding contract.

Text success presents selectable exact text, copy, and save as
`chimera-decompressed.txt` with `text/plain; charset=utf-8`. Binary success
shows counts only and saves as `chimera-decompressed.bin` with
`application/octet-stream`; raw binary is never rendered or copied as text.
There is no image preview because that belongs to the Base64 use case.

Cancellation is neutral. Changing the source or mode clears stale output and
notices. Success clears application-owned compressed source state and retains
no source reference while keeping one immutable result for copy/save; failure
does the same and publishes no partial output. Callers can still own their
original input lists.
Generation guards suppress stale async completions and racing actions are
disabled. File saving is one exact handoff to the platform adapter.

Focus order is file, mode, decompress, result, text-copy when applicable, then
save. Success and error summaries are live regions and the result is focusable.
Both locales, keyboard operation, 48-by-48 targets, narrow layout, 200-percent
text, and contrast guidance are covered.

## Cross-platform evidence

Independent fixtures cover empty, ASCII, Unicode, a BOM-prefixed UTF-8 payload,
arbitrary binary, optional
fields including FHCRC, concatenated members, and a highly compressible limit
sample. Their provenance and SHA-256 hashes are recorded. Mutation tests cover
every framing field, optional-field truncation, invalid DEFLATE, CRC/ISIZE,
later-member failure, trailing junk, invalid UTF-8, exact budgets, allocations,
immutability, per-member dictionary reset, redaction, and all-or-nothing output.

Core tests pin stable JSON and typed mapping. CLI tests cover stdin/file, both
modes, exact stdout/save/JSON, transactional rollback, both locales, exits, and
validation before I/O. Widget tests cover file/mode flows, source discard,
exact copy/save, async races, accessibility, localization, and layout. Native
Windows/Linux plus compiled Chromium/Firefox/WebKit/native Safari exercise
representative text and binary archives, corruption rejection, exact saved
bytes, and zero unexpected network requests.

## Requirement audit

- Main flow and FR-EN-07: raw local GZIP reaches one strict shared decoder and
  returns or saves exact text/binary output.
- AF-01 and FR-EN-17: malformed, corrupt, unsupported, and invalid-text inputs
  produce typed redacted failures without partial output.
- AF-02 and FR-EN-18: bounded writes and transactional adapters publish no
  partial result and preserve prior destinations.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, desktop, and browser use the
  same deterministic utility/service and stable human/JSON contracts.
- FR-PL-09 through FR-PL-11, BR-03 through BR-05, and BR-19: source/partials are
  discarded and no persistence, telemetry, account, plugin, collaboration, or
  network path is added.

No traced requirement is left without an implementation and test path.

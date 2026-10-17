# UC-20 GZIP Compress Design

## Intent and scope

UC-20 compresses text or local bytes into one standards-compliant GZIP member.
Processing is local, offline, deterministic, and stateless. It covers FR-EN-06,
FR-EN-17 through FR-EN-18, FR-PL-01 through FR-PL-06, FR-PL-09 through
FR-PL-11, BR-01 through BR-05, and BR-19.

This use case creates GZIP data only. It does not create TAR or ZIP archives,
preserve a source path, add an original filename or comment, encrypt output,
split output, or decompress data. UC-21 owns decompression.

## Compression contract

The shared utility accepts either a Dart `String` or a byte list. Text is
encoded as strict UTF-8 after rejecting unpaired UTF-16 surrogates. Byte input
is raw and each member must be in the inclusive range 0 through 255. Empty text
and empty byte input are valid and produce a valid empty GZIP member.

The public compression option is `level`, an integer from 0 through 9. Level 0
stores without deflate compression, levels 1 through 9 select increasing
compression effort, and the default is 6. Values outside this closed range are
validation failures before compression begins.

Output is one RFC 1952 GZIP member with:

- compression method DEFLATE;
- no original filename, comment, extra field, or source path;
- MTIME fixed to zero rather than wall-clock time;
- checksum and uncompressed-size trailer generated from the complete source;
  and
- no bytes before or after the member.

`archive` 4.5.2 is the approved dependency from the Technology Stack Document.
The utility uses the package's platform-independent Dart GZIP encoder on every
target rather than its native/web conditional facade. This keeps exact bytes
consistent across CLI, desktop, and browser surfaces. Known-answer tests pin the
header, trailer, decompressed content, level behavior, and cross-target bytes.

## Utility result and failures

`GzipCompressor` lives in `chimera_utilities`. It exposes `compressText` and
`compressBytes`, each with an optional level defaulting to 6.
`GzipCompressionResult` exposes:

- `level`;
- one immutable `Uint8List bytes`;
- `inputByteCount`; and
- `outputByteCount`.

The result owns one copied immutable byte list. Adapters pass that exact list to
their save boundary. Caller-requested JSON creates only a transient list view;
the service and adapters retain no source or result after returning.

Nullable `maxInputBytes` and `maxOutputBytes` limits make exact resource
boundaries testable without imposing a product-specific production limit.
Input length is checked before compression. Output length is checked before a
result is published. Encoder allocation exhaustion, input copying, UTF-8
encoding, and result ownership failures become typed resource failures; no
partial result escapes.

Stable utility failures are:

- `gzip-compress.invalid-input`, field `input`, reason `invalid-unicode` or
  `byte-range`;
- `gzip-compress.invalid-level`, field `level`, reason `outside-range`; and
- `gzip-compress.resource-limit`, field `input` or `output`, reason
  `byte-limit` or `allocation-limit`.

No exception message, source content, compressed content, or path crosses the
failure boundary.

## Core service and serialization

`chimera_core` owns `GzipCompressOperationRequest.text/bytes`,
`GzipCompressOutput`, and `GzipCompressService`. Request factories carry only
the selected source and level. The service delegates once to the shared utility
and maps typed validation/resource exceptions to the common result model.

`GzipCompressOutput.toJson()` has this stable ordered shape:

```json
{
  "level": 6,
  "bytes": [31, 139, 8, 0],
  "inputByteCount": 5,
  "outputByteCount": 25
}
```

The byte array is present because machine-readable output must carry the binary
operation result. It is produced only when a caller asks for JSON and is not
stored by the service.

## CLI adapter

The CLI adds `chimera gzip compress` with exactly one source:

- `--text=<value>` for strict UTF-8 text, including an explicitly empty value;
- `--stdin` for raw bytes; or
- `--file=<path>` for raw local-file bytes.

`--level=<0..9>` defaults to 6. Because the result is binary, the caller must
select `--output=<path>` or `--json`; this rule and all structural options are
validated before stdin or file access. `--output` saves the exact result through
the existing staged transactional writer. Human output after a committed save
is a localized summary containing the level and byte counts. JSON is written to
stdout with one terminal LF, after any requested save succeeds.

Adapter validation uses `gzip-compress.invalid-options`, `.missing-source`,
`.conflicting-sources`, `.invalid-level`, and `.output-required`. Input or file
access failures exit 74, validation exits 64, and resource failures exit 75. A
failed staged write preserves an existing destination, removes temporary
artifacts, emits no success output, and retains no result copy. English and
Brazilian Portuguese diagnostics contain only safe typed details.

## Interactive adapter

The GUI adds `/gzip/compress` and a localized home action. It provides a
multiline text field, local file loading, clipboard paste, and a compression
level selector for 0 through 9 with default 6. Text/paste and selected-file
sources are exclusive. Changing the source or level clears stale output,
notices, and enabled result actions. Operations are generation-guarded and
racing actions are disabled while work is in flight.

Success displays the level and input/output byte counts but never renders or
copies binary output. Save hands the exact result bytes once to the platform
adapter with default name `chimera-compressed.gz`, MIME type
`application/gzip`, and extension `gz`. A canceled picker or save is neutral;
thrown access/allocation failures are localized, clear stale success as
applicable, and retain no source/result copy. Desktop/browser file-picker
implementations own their platform transaction; the GUI promises exact one-time
handoff and no app-retained duplicate.

Focus order is text input, file, paste, level, compress, result, and save.
Success and failure summaries are live regions. Both locales, keyboard use,
48-by-48 targets, narrow layout, 200-percent text, and contrast guidance are
covered.

## Cross-platform evidence

Standards-derived fixtures cover empty input, ASCII, Unicode UTF-8, arbitrary
binary bytes, compressible and incompressible data, and levels 0, 1, 6, and 9.
Tests verify exact deterministic bytes where appropriate and always decode with
an independent GZIP decoder to the original bytes. They also pin invalid
Unicode, byte range, levels -1/10, exact input/output limits, allocation
translation, result immutability, and no partial output.

Core tests pin stable JSON and typed failure mapping. CLI tests cover
text/stdin/file, default and explicit levels, human/JSON output, transactional
save/rollback, both locales, validation-before-read, redaction, exits, and no
partial stdout. Widget tests cover text/file/clipboard, level changes, exact
save identity, stale-state cleanup, localized failures, focus, accessibility,
and responsive layout. Windows/Linux integration and compiled
Chromium/Firefox/WebKit/native Safari exercise a representative UTF-8 or binary
compression, exact saved/downloaded bytes, independent decompression, and zero
unexpected network requests.

## Requirement audit

- Main flow and FR-EN-06: every source reaches one shared compressor and yields
  a valid deterministic GZIP member containing exactly the source bytes.
- AF-01 and FR-EN-17: invalid Unicode, byte members, and levels return typed,
  redacted validation failures without output.
- AF-02 and FR-EN-18: resource limits and allocations publish no partial bytes;
  CLI transaction tests preserve destinations, while GUI tests assert one exact
  payload handoff and no retained duplicate.
- FR-PL-01 through FR-PL-06 and BR-02: core, CLI, desktop, and browser adapters
  use the same utility/service and stable human/JSON contracts.
- FR-PL-09 through FR-PL-11, BR-03 through BR-05, and BR-19: no history,
  preferences, accounts, plugins, collaboration, telemetry, or network path is
  added; compiled-browser flows reject unexpected external requests.

No traced requirement is left without a concrete implementation and test path.

# UC-27 QR Decode Design

## Scope and contracts

Decode one QR symbol from a local PNG, JPEG, or BMP image. Shared utility code
owns decoding; core maps typed outcomes; CLI, Linux/Windows desktop and browser
adapters consume the same service. Image data never leaves the device and is
released after the operation. The exact input formats are documented in help.

`QrDecoder.decode(List<int> bytes)` returns `QrDecodeResult` with `text`, `format`
(the image format: png/jpeg/bmp), `width`, `height`, and `inputByteCount`.
The constructor accepts `maxInputBytes` (default 16 MiB), `maxPixels` (default
16,777,216), and `maxOutputBytes` (default 8192). Empty/unsupported/corrupt images
and no QR symbol produce a typed decoding exception. Configured byte/pixel/output
limits and allocation failures produce typed resource exceptions. Dimensions
are checked from decoder metadata before raster allocation. QR detection uses
pinned pure-Dart zxing2 0.2.4, already used independently by encoder tests.
Raster samples are normalized to 8-bit ARGB before detection, including 16-bit
PNG input. BMP palette counts are bounded against bit depth and available bytes
before metadata parsing can allocate a palette. Byte-mode text supports strict
UTF-8, ISO-8859-1, and ASCII. The pinned dependency's placeholder codecs for
other ECI encodings are rejected as typed invalid-text failures, never used to
return corrupted text. Scoped codec normalization preserves segment order and
restores all dependency codec state on success and failure.

`QrDecodeOperationRequest({required List<int> bytes})`, `QrDecodeOutput(result)`
and `QrDecodeService({decoder = const QrDecoder()})` follow existing core
conventions. `QrDecodeOperationService` aliases
`OperationService<QrDecodeOperationRequest, QrDecodeOutput>`. Output getters
mirror the utility result and `toJson()` includes only the five named fields.
Failures use `qr-decode.validation`, `qr-decode.decoding`, `qr-decode.resource`
and message keys `error.qrDecode.validation`, `error.qrDecode.decoding`,
`error.qrDecode.resource`; diagnostics contain safe field/reason metadata only.

## Adapters

CLI: `chimera qr decode (--file=<path>|--stdin) [--output=<path>] [--json]`.
File and stdin supply binary image bytes with bounded streaming reads. Invalid
sources/options exit 64; unreadable source or failed transactional UTF-8 output
save exits 74; limits exit 75. Human output is exact decoded text plus newline;
JSON includes the output fields. Never echo image bytes in diagnostics.

GUI: `/qr/decode` provides a bounded image picker, Decode button, result text,
metadata, Copy and Save UTF-8. Dependencies are injectable like the QR encoder.
Picker/decode/copy/save failure clears stale content and presents a localized
safe live error. File cancellation preserves the current state. Clear image
bytes on completion and disposal, clear result on navigation/disposal or new
input. No image preview/cache is needed. Keyboard order, focus movement and
semantic labels follow current pages. All text has English and pt-BR entries.

## Traceability and verification

Main flow: image picker/binary CLI -> shared decode -> localized presentation ->
discard image. AF-01: unsupported, corrupt and no-code images map to typed
safe decoding failures. AF-02: read failures map to file-access failure.
All cited FR-EN-14, FR-EN-17, FR-PL-01–06 and FR-PL-09–11 exist. Tests are written
first for shared outcomes, service mappings, CLI and GUI success/failure paths,
resource boundaries, Unicode and non-retention. Native integration and compiled
Chromium/Firefox/WebKit and Safari harnesses cover success and failure.
Run formatting, analysis, boundary check and the complete `test:all`, followed by
independent review and required PR CI before merging into develop.

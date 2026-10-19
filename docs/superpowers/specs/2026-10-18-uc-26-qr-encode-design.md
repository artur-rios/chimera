# UC-26 QR Encode Design

## Scope

UC-26 generates a QR code from local text and returns deterministic PNG bytes.
The same shared implementation serves the CLI, Flutter desktop, and Flutter web
interfaces. No input or output is transmitted or retained after the operation.

## Input and options

The encoder accepts Unicode text and converts it to UTF-8. QR versions 1 through
40 are selected automatically. Callers choose one of the standard error
correction levels (`low`, `medium`, `quartile`, or `high`), an exact square image
size from 64 through 4096 pixels, a quiet-zone width from 0 through 32 modules,
and foreground/background colors in `#RRGGBB` form. Defaults are medium error
correction, 512 pixels, a four-module quiet zone, black foreground, and white
background.

Empty text, malformed Unicode, unsupported option values, input beyond version
40 capacity, and a requested image too small to allocate at least one pixel to
every symbol or quiet-zone module are typed validation failures. Allocation
failures and output budgets are typed resource failures. The utility bounds
input before allocating its UTF-8 copy and bounds the raster dimensions before
allocating pixel storage.

## Shared rendering

`chimera_utilities` owns QR validation, encoding, rasterization, and PNG
serialization. It uses the pure-Dart `qr` package for the QR matrix and `image`
for deterministic PNG bytes on every supported target. This deliberately uses
the platform-neutral encoder beneath `qr_flutter`: a Flutter-only renderer
cannot satisfy the requirement that CLI, desktop, and browser invoke one shared
implementation. The Technology Stack document is updated to describe the
resolved packages.

The rasterizer includes the quiet zone in the requested image size and maps
module boundaries with integer arithmetic. Every output pixel belongs to
exactly one module interval, so arbitrary valid dimensions remain crisp without
anti-aliasing. The result contains only immutable metadata and the PNG byte
list. Adapters display or save those exact bytes rather than encoding again.

## Core contract

`QrEncodeOperationRequest` carries text and typed options. `QrEncodeService`
maps utility exceptions to stable `ChimeraFailure` values and returns
`QrEncodeOutput` with PNG bytes, dimensions, QR version, module count, error
correction, quiet zone, colors, and input/output byte counts. JSON output uses a
base64 PNG field plus the same metadata so it remains transport-safe.

## CLI

`chimera qr encode` accepts exactly one of `--text`, `--stdin`, or `--file`.
Options are `--error-correction`, `--size`, `--margin`, `--foreground`,
`--background`, `--output`, and `--json`. Human mode requires `--output`, writes
the PNG transactionally, and prints a localized summary. JSON mode may omit
`--output`; it emits the base64 PNG and metadata, and also writes the exact PNG
when an output path is supplied. Invalid options exit 64, file-access failures
74, and resource failures 75.

## GUI

The `/qr/encode` page provides text input, file and clipboard ingestion,
correction controls, numeric size and margin fields, color fields, generation,
an exact PNG preview, metadata, and Save PNG. All user-visible text is localized
in English and Brazilian Portuguese. The page is keyboard ordered, exposes
live-region success and error feedback, and gives the preview a useful semantic
label. Failed picker, clipboard, preview, or save operations clear stale state
and surface the appropriate localized adapter failure.

## Verification

Tests cover utility vectors and PNG structure, every correction level, Unicode,
capacity and option boundaries, deterministic output, service mappings, CLI
argument/stdin/file/JSON/transactional-save behavior, localized GUI behavior,
keyboard and semantic contracts, native integration, Chromium/Firefox/WebKit,
and the Safari smoke harness. The full repository gate remains the release
criterion.

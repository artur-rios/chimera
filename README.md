# Chimera

Chimera is a multilingual, cross-platform developer toolbox that combines
common conversion, encoding, formatting, comparison, analysis, and synthetic
test-data utilities in one local-first application. It targets the browser,
Windows and Linux desktops, and the command line.

> **Status:** Foundation, cron-expression parsing, date conversion, JSON array
> table rendering, JSON-to-CSV, and JSON-to-YAML conversion are implemented; remaining
> utility use cases are delivered through the public backlog below.

Delivery is tracked in the public [Chimera GitHub Project](https://github.com/users/artur-rios/projects/17).

## What it does

- Converts, formats, compares, encodes, decodes, and analyzes developer data.
- Generates checksummed synthetic people, payment cards, and identity documents.
- Exposes shared behavior through browser, desktop, and CLI interfaces.
- Processes utility data locally and keeps the utilities available offline.
- Publishes portable and installed desktop and CLI releases with guided updates.

## What it doesn't do

- Cloud synchronization, remote utility processing, or remote storage.
- User accounts, authentication, plugins, collaboration, or mobile applications.

## Specifications

Start with the informal documents for context, then use the requirements as the
normative implementation source.

| Document | What's in it |
| --- | --- |
| [Brainstorm](docs/initial/Brainstorm.md) | Original free-form project notes. |
| [Project Overview](docs/initial/Project%20Overview.md) | Audience, scope, non-goals, and success measures. |
| [Technology Stack](docs/initial/Technology%20Stack.md) | Informal technology and deployment decisions. |
| [Workflow](docs/initial/Workflow.md) | Step-by-step delivery of one use case. |
| [Business Rules](docs/initial/Business%20Rules.md) | Domain entities and `BR-xx` rules. |
| [Vision Document](docs/requirements/Vision%20Document.md) | Stakeholders, positioning, and `F-xx` features. |
| [System Requirements](docs/requirements/System%20Requirements%20Document.md) | Functional and non-functional requirements and traceability. |
| [Use Case Specification](docs/requirements/Use%20Case%20Specification%20Document.md) | `UC-01` through `UC-45` and their flows. |
| [Development Workflow](docs/requirements/Development%20Workflow%20Document.md) | Branches, issue lifecycle, review gates, and Definition of Done. |
| [Testing Specification](docs/requirements/Testing%20Specification%20Document.md) | Unit, functional, integration, browser, and deployment testing. |
| [Technology Stack Document](docs/requirements/Technology%20Stack%20Document.md) | Normative technology choices and version policy. |
| [Operations & Infrastructure](docs/requirements/Operations%20%26%20Infrastructure%20Document.md) | Repository layout, Yggdrasil deployment, and `UC-46`. |

## Installation

Install Flutter 3.47.7 (which includes Dart 3.13.5), Node.js 24, and Docker.
Windows desktop builds additionally need Visual Studio's Desktop development
with C++ workload; Linux desktop builds need the Flutter Linux prerequisites.

From a clean clone, resolve the workspace with:

```bash
flutter pub get
dart run melos bootstrap
```

Run the GUI with `flutter run` from `apps/chimera_gui`. Run the CLI with
`dart run apps/chimera_cli/bin/chimera.dart`. Both entry points consume shared
packages rather than owning utility implementations.

### Generate Lorem Ipsum

Open **Generate Lorem Ipsum** in the GUI, or run:

```bash
dart run apps/chimera_cli/bin/chimera.dart lorem generate --unit=words --count=3
dart run apps/chimera_cli/bin/chimera.dart lorem generate --unit=sentences --count=2 --json
dart run apps/chimera_cli/bin/chimera.dart lorem generate --unit=paragraphs --count=2 --output=lorem.txt
```

The defaults are `--unit=paragraphs --count=1`. Unit names are case-sensitive:
`words`, `sentences`, and `paragraphs`. Count must contain only decimal digits
and represent a positive integer exactly representable by the target runtime
(native/Wasm int64 or a finite JavaScript number). Leading zeroes are accepted;
values that would be rounded are rejected. There is no product count ceiling.
Requests exceeding available resources return a typed resource failure with no
partial result. The generator needs no input source and rejects input, file, and
stdin flags.

Generation is deterministic and local, using these public-domain Latin fragments:
`Lorem ipsum dolor sit amet.` and `Consectetur adipiscing elit.` Words cycle through
`Lorem ipsum dolor sit amet consectetur adipiscing elit`, separated by one space
without punctuation. Sentences alternate the two capitalized, punctuated fragments,
separated by one space. Each paragraph contains both sentences, separated by one
space; paragraphs are separated by exactly one blank line (`\n\n`). The requested
unit count is exact, with no leading or trailing whitespace or terminal newline.

Human CLI stdout contains exactly the generated text. `--json` emits one JSON
object followed by a newline, with stable keys `unit`, `count`, and `text`, for
example `{"unit":"words","count":3,"text":"Lorem ipsum dolor"}`. When `--output`
is supplied, the file contains the exact generated UTF-8 text without a BOM or
added newline; human stdout confirms the save, and JSON stdout retains the same
result object. Native file replacement is transactional. Stdout completion is
awaited; access failures return exit 74, validation failures 64, and resource
failures 75, with localized diagnostics on stderr.

GUI copy and save use the same exact text and UTF-8 bytes (`chimera-lorem.txt`).
Changing the unit or count invalidates the previous result. Failed generation,
copy, or save clears the result; canceling a save preserves it. English and
Brazilian Portuguese labels and errors are provided. Generation, copying, and
saving use no network or operation history.

### Generate a checksum

Open **Generate checksum** in the GUI, or use the CLI:

```bash
dart run apps/chimera_cli/bin/chimera.dart checksum generate --input=123456789
dart run apps/chimera_cli/bin/chimera.dart checksum generate --file=input.bin --algorithm=adler32 --json
dart run apps/chimera_cli/bin/chimera.dart checksum generate --stdin --output=checksum.txt
```

Algorithms are `crc32` (default, CRC-32/ISO-HDLC) and `adler32` (RFC 1950).
Provide exactly one source: `--input` preserves text as UTF-8, including whitespace,
newlines and BOM; `--file` and `--stdin` preserve every byte. Empty text or files
are valid. Checksums are eight lowercase hexadecimal characters with leading
zeroes. For `--input=123456789`, exact human stdout is `cbf43926` followed by one
LF; JSON stdout is `{"algorithm":"crc32","checksum":"cbf43926"}` followed by one
LF. This two-field JSON schema is locale independent.

`--output` saves the checksum followed by one LF as UTF-8, using a transactional
local file replacement. Human stdout then reports `Checksum saved.` (localized);
JSON stdout retains the same result schema. Exit codes are 0 for success, 64 for
invalid options/input, 74 for input/output access failures, and 75 for resource
failure. Diagnostics go to stderr without source data or exception details.
GUI copy writes the checksum alone; GUI save writes the same checksum-plus-LF
file. Processing works offline, keeps no history and imposes no arbitrary size
limit. Input and editor undo history are discarded after processing, failure,
replacement, or navigation away. See the [independent known-answer fixtures](tests/fixtures/checksums/README.md).

### Check for a native update

Installed Windows and Linux builds can compare their version with compatible
metadata from the latest stable GitHub release:

```bash
dart run apps/chimera_cli/bin/chimera.dart update check \
  --current-version 0.1.0 --platform windows --package-type installer
```

Use `--repository=owner/name` to select the release source and `--json` for
stable automation output. The check strictly validates the six-field release
metadata and SemVer compatibility. It does not download or install an artifact;
an available result requires a separate explicit approval. The update page is
available only in native desktop builds.

Apply an available installer only with explicit approval:

```bash
dart run apps/chimera_cli/bin/chimera.dart update apply --yes \
  --current-version 0.1.0 --platform windows --package-type installer
```

The apply workflow stages a bounded download and verifies its published SHA-256
before invoking the platform installer. Cleanup is attempted after every direct
attempt, and a cleanup failure is surfaced. Windows hands the per-user Inno
Setup installer and its staging cleanup to a detached helper that waits for the
current process to exit, avoiding an executable-replacement deadlock. Windows
reports this state as `scheduled`, disables duplicate apply actions, and lets
Inno Setup surface any post-exit installation failure. Linux
preflights the Debian transaction before asking for elevation through `pkexec`;
permission denial is reported with retry guidance. Apply targets must match the
host platform. Guided self-update rejects portable packages because replacing a
running portable app cannot safely preserve the working version.

### Parse a cron expression

`chimera cron parse` accepts five-field Unix syntax or six fields with seconds.
It supports wildcards, lists, ranges, steps, English month/weekday names, IANA
time zones, and 1–100 previous and next occurrences. Input can come from
`--expression`, standard input, or a local `--file`.

```bash
dart run apps/chimera_cli/bin/chimera.dart cron parse \
  --expression "0 9 * * MON-FRI" \
  --timezone America/Sao_Paulo \
  --count 3 \
  --at 2026-01-05T12:00:00Z
```

Add `--json` for stable machine-readable output. CLI failures use exit code 64
for validation, 70 for processing, 74 for file access, 75 for resource limits,
and 69 for update failures. The GUI exposes the same shared behavior at
`/cron/parse`; neither interface persists or transmits the request or result.

### Convert a date

`chimera date convert` converts ISO 8601, Unix seconds, Unix milliseconds, and
strict numeric custom patterns across IANA time zones. Input can come from
`--value`, standard input, or a local `--file`.

```bash
dart run apps/chimera_cli/bin/chimera.dart date convert \
  --value 2026-01-15T12:30:45Z \
  --from iso8601 \
  --to custom \
  --target-timezone America/Sao_Paulo \
  --target-pattern "dd/MM/yyyy HH:mm:ss"
```

Supported custom fields are `yyyy`, `MM`, `dd`, `HH`, `mm`, `ss`, and `SSS`.
Ambiguous or nonexistent local daylight-saving times are rejected rather than
guessed. The GUI exposes the same shared behavior at `/date/convert`.

### Convert a JSON array to a table

`chimera json array-to-table` validates an array of JSON objects, derives
columns in first-seen key order, and preserves nested arrays and objects as
compact JSON cell values. Input can come from `--input`, standard input, or a
local `--file`; add `--row-numbers` for presentation row numbers and `--json`
for stable machine-readable output.

```bash
dart run apps/chimera_cli/bin/chimera.dart json array-to-table \
  --input '[{"name":"Ada","skills":["Dart","C"]}]' \
  --row-numbers
```

The GUI exposes the same local-only behavior at `/json/array-to-table` with a
horizontally scrollable table. Validation failures identify the JSON offset or
array path without echoing input data, and resource failures return no partial
table.

### Convert a JSON array to CSV

`chimera json array-to-csv` validates an array of JSON objects and serializes
the derived columns as RFC 4180-style CSV. Comma, semicolon, tab, and pipe
delimiters are supported; headers are included by default and can be disabled.
Input can come from `--input`, standard input, or a local `--file`; `--output`
writes exact UTF-8 bytes to a local file and `--json` returns stable metadata.

```bash
dart run apps/chimera_cli/bin/chimera.dart json array-to-csv \
  --input '[{"name":"Ada","skills":["Dart","C"]}]' \
  --delimiter comma \
  --output developers.csv
```

The GUI exposes the same local-only conversion and save flow at
`/json/array-to-csv`. Nested values remain compact JSON and failed file writes
return a typed access failure without reporting a successful result.

### Convert JSON to YAML

`chimera json to-yaml` validates any JSON-compatible root value and serializes
it with deterministic key order. Use `--indent 2` or `--indent 4`, add
`--quote-strings` to double-quote string values, and select input with
`--input`, standard input, or a local `--file`. `--output` writes exact UTF-8
bytes locally and `--json` returns stable output metadata.

```bash
dart run apps/chimera_cli/bin/chimera.dart json to-yaml \
  --input '{"name":"Ada","skills":["Dart","C"]}' \
  --indent 2 \
  --output developer.yaml
```

The GUI exposes the same local-only preview/save flow at `/json/to-yaml`.
Malformed input reports its offset without echoing the source, and source,
nesting, node, or output limits fail without returning partial YAML.

### Format JSON

`chimera json format` validates any JSON-compatible root value and returns
deterministically formatted JSON. Use `--indent 2` or `--indent 4`, select input
with `--input`, standard input, or a local `--file`, write exact UTF-8 bytes
with `--output`, and request stable metadata with `--json`.

```bash
dart run apps/chimera_cli/bin/chimera.dart json format \
  --input '{"name":"Ada","skills":["Dart","C"]}' \
  --indent 2 \
  --output developer.json
```

The GUI exposes the same local-only flow at `/json/format` with typed, local
file, or clipboard input plus accessible preview, copy, and save actions.
Malformed input reports a redacted reason and offset; access or resource
failures return no partial result.

### Format SQL

`chimera sql format` formats PostgreSQL, MySQL, SQL Server, or SQLite locally.
Select a dialect with `--dialect`, use `--indent 2` or `--indent 4`, and choose
`--keyword-case upper`, `lower`, or `preserve` for recognized structural and
common DDL keywords; identifiers and literals retain their original spelling.
Input may come from `--input`,
standard input, or a local `--file`; `--output` writes exact UTF-8 bytes and
`--json` returns stable metadata.

```bash
dart run apps/chimera_cli/bin/chimera.dart sql format \
  --input 'select id,name from users where active=true' \
  --dialect postgresql \
  --keyword-case upper \
  --output query.sql
```

The GUI exposes the same offline-only flow at `/sql/format` with typed, local
file, or clipboard input plus accessible preview, copy, and save actions.
Invalid dialect syntax or SQL structure reports a redacted reason and offset;
resource and access failures return no partial result.

## Architecture

| Project | Responsibility |
| --- | --- |
| `apps/chimera_gui` | Flutter browser, Windows, and Linux presentation shell. |
| `apps/chimera_cli` | Dart command-line presentation shell. |
| `packages/chimera_core` | Typed results, operation services, and redacted diagnostics. |
| `packages/chimera_utilities` | Platform-independent utility implementations. |
| `packages/chimera_platform` | Injectable file, clipboard, preference, and update boundaries. |
| `packages/chimera_l10n` | Complete English and Brazilian Portuguese message catalogs. |

The applications may depend inward on shared packages. Core and utilities may
not depend on Flutter, an application, or a platform implementation. The
repository's boundary test enforces that direction and rejects database or
analytics dependencies.

## Testing

The complete suite defined in the
[Testing Specification](docs/requirements/Testing%20Specification%20Document.md)
runs with:

```bash
dart run melos run test:all
```

Individual suites are `analyze`, `test:unit`, `test:cli`, `test:gui`,
`test:web`, `test:deployment`, and `test:performance`. The web suite builds the
application and runs the pinned Playwright harness natively on Linux or in its
official Linux container on Windows, where Docker must be available. CI covers
unit, widget, CLI, native GUI, Chromium, Firefox, WebKit, native Safari,
deployment, update, accessibility, and performance behavior. CI publishes LCOV,
test logs, accessibility results, and performance results as build evidence.

## Web container

Build and verify the unprivileged NGINX image on Windows with:

```powershell
./tool/smoke_container.ps1
```

On Linux use `sh tool/smoke_container.sh`. The container listens on port 8080;
`/healthz` returns exactly `{"status":"ok"}`. Yggdrasil owns environment
promotion, Traefik routing, rollback, secrets, logs, and platform metrics. No
utility input or output is sent to those operational surfaces.

## Releases

Release preparation happens on `develop`; an unchanged `release/X.Y.Z` snapshot
targets `main`. After Yggdrasil completes its environment gates and creates
the `vX.Y.Z` tag and private draft release, GitHub Actions publishes that draft
only after verifying the complete Windows and Linux GUI/CLI portable and
installer bundle locally and on GitHub. Every native artifact has a SHA-256
sidecar and six-field release-metadata sidecar. See
[Release artifacts](docs/operations/release-artifacts.md) for formats and the
infrastructure-requirement evidence map, and use the
[publish-release runbook](docs/operations/publish-release.md) for readiness,
approval, health, rollback, and post-publication verification.

### Decode a QR code

`chimera qr decode` reads a local PNG, JPEG, or BMP image and returns its QR
text. Supply exactly one binary source, `--file` or `--stdin`. Use `--json`
for text plus image-format, dimension, and byte-count metadata; `--output`
saves the exact decoded text as UTF-8 through the transactional file writer.

```bash
dart run apps/chimera_cli/bin/chimera.dart qr decode --file code.png --json
```

The GUI exposes the same local decoder at `/qr/decode`, with image selection,
copy, and Save UTF-8 text. Encoded input is limited to 16 MiB, raster images to
16,777,216 pixels, and decoded text to 8192 UTF-8 bytes. Unsupported, corrupt,
and QR-free images return typed decoding failures without retaining image data.
Byte-mode text supports UTF-8, ISO-8859-1, and ASCII; other ECI encodings and
malformed encoded text return a typed decoding failure.

### Generate a hash

`chimera hash generate` accepts exactly one source: UTF-8 text with `--input`,
arbitrary bytes from `--stdin`, or a local `--file`. File/stdin bytes preserve
BOMs and invalid UTF-8. Choose `sha256` (default), `sha384`, `sha512`, `md5`,
or `sha1` with `--algorithm`.

```bash
dart run apps/chimera_cli/bin/chimera.dart hash generate --input=abc --json
dart run apps/chimera_cli/bin/chimera.dart hash generate --file=archive.bin --algorithm=sha512 --output=digest.txt
```

JSON has stable `algorithm`, lowercase hexadecimal `digest`, `legacy`, and
localized `warning` fields. Human output includes the digest and any warning;
`--output` transactionally saves the digest followed by a newline. MD5 and SHA-1
are explicitly labeled legacy and unsuitable for security decisions.

The GUI route `/hash/generate` supports text, clipboard and arbitrary local
files, an algorithm selector, copy, and save. Processing is offline and
stateless, with no application size cap or retained source/history. Resource and
access failures discard the source and expose no successful partial result.

## Roadmap

| Milestone | Delivers | Depends on | Issues | Status |
| --- | --- | --- | ---: | --- |
| [M-01 - Foundation](https://github.com/artur-rios/chimera/milestone/1) | Repository scaffold and initial infrastructure | - | 1 | 1 / 1 closed |
| [M-02 - Scheduling and structured data](https://github.com/artur-rios/chimera/milestone/2) | Cron, date, JSON, CSV, YAML, SQL, and XML tools | M-01 | 8 | 8 / 8 closed |
| [M-03 — Number and text tools](https://github.com/artur-rios/chimera/milestone/3) | Base conversion, escaping, comparison, analysis, and transformation | M-01 | 7 | 7 / 7 closed |
| [M-04 — Encoders and decoders](https://github.com/artur-rios/chimera/milestone/4) | Base64, certificates, GZIP, HTML, JWT, QR, and URL tools | M-01 | 14 | 14 / 14 closed |
| [M-05 — Test-data generators](https://github.com/artur-rios/chimera/milestone/5) | Hashes, checksums, text, credentials, identifiers, cards, documents, and people | M-01 | 8 | 8 / 8 closed |
| [M-06 — Ciphers and alphabets](https://github.com/artur-rios/chimera/milestone/6) | Approved cipher and alphabet encoding and decoding | M-01 | 4 | 4 / 4 closed |
| [M-07 — Experience and distribution](https://github.com/artur-rios/chimera/milestone/7) | Preferences, updates, packaging, and Yggdrasil release delivery | M-01–M-06 | 5 | 5 / 5 closed |
| [M-08 — Developer workflow automation](https://github.com/artur-rios/chimera/milestone/8) | Project templates, terminal automation, and .NET repository workflows | M-01 | 10 | 0 / 10 closed |

## Backlog

### M-01 — Foundation

| Issue | Work | Specification |
| --- | --- | --- |
| [#1](https://github.com/artur-rios/chimera/issues/1) | Project scaffold and initial infrastructure | [Operations & Infrastructure](docs/requirements/Operations%20%26%20Infrastructure%20Document.md) |

### M-02 — Scheduling and structured data

| Issue | Work | Specification |
| --- | --- | --- |
| [#2](https://github.com/artur-rios/chimera/issues/2) | UC-01 — Parse Cron Expression | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-01-parse-cron-expression) |
| [#3](https://github.com/artur-rios/chimera/issues/3) | UC-02 — Convert Date | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-02-convert-date) |
| [#4](https://github.com/artur-rios/chimera/issues/4) | UC-03 — Convert JSON Array to Table | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-03-convert-json-array-to-table) |
| [#5](https://github.com/artur-rios/chimera/issues/5) | UC-04 — Convert JSON Array to CSV | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-04-convert-json-array-to-csv) |
| [#6](https://github.com/artur-rios/chimera/issues/6) | UC-05 — Convert JSON to YAML | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-05-convert-json-to-yaml) |
| [#7](https://github.com/artur-rios/chimera/issues/7) | UC-06 — Format JSON | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-06-format-json) |
| [#8](https://github.com/artur-rios/chimera/issues/8) | UC-07 — Format SQL | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-07-format-sql) |
| [#9](https://github.com/artur-rios/chimera/issues/9) | UC-08 — Format XML | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-08-format-xml) |

### M-03 — Number and text tools

| Issue | Work | Specification |
| --- | --- | --- |
| [#10](https://github.com/artur-rios/chimera/issues/10) | UC-09 — Convert Number Base | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-09-convert-number-base) |
| [#11](https://github.com/artur-rios/chimera/issues/11) | UC-10 — Escape Text | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-10-escape-text) |
| [#12](https://github.com/artur-rios/chimera/issues/12) | UC-11 — Unescape Text | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-11-unescape-text) |
| [#13](https://github.com/artur-rios/chimera/issues/13) | UC-12 — Compare Lists | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-12-compare-lists) |
| [#14](https://github.com/artur-rios/chimera/issues/14) | UC-13 — Analyze Text | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-13-analyze-text) |
| [#15](https://github.com/artur-rios/chimera/issues/15) | UC-14 — Transform Text | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-14-transform-text) |
| [#16](https://github.com/artur-rios/chimera/issues/16) | UC-15 — Compare Text | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-15-compare-text) |

### M-04 — Encoders and decoders

| Issue | Work | Specification |
| --- | --- | --- |
| [#17](https://github.com/artur-rios/chimera/issues/17) | UC-16 — Base64 Encode | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-16-base64-encode) |
| [#18](https://github.com/artur-rios/chimera/issues/18) | UC-17 — Base64 Decode | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-17-base64-decode) |
| [#19](https://github.com/artur-rios/chimera/issues/19) | UC-18 — Inspect Certificate | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-18-inspect-certificate) |
| [#20](https://github.com/artur-rios/chimera/issues/20) | UC-19 — Convert Certificate | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-19-convert-certificate) |
| [#21](https://github.com/artur-rios/chimera/issues/21) | UC-20 — GZIP Compress | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-20-gzip-compress) |
| [#22](https://github.com/artur-rios/chimera/issues/22) | UC-21 — GZIP Decompress | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-21-gzip-decompress) |
| [#23](https://github.com/artur-rios/chimera/issues/23) | UC-22 — HTML Encode | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-22-html-encode) |
| [#24](https://github.com/artur-rios/chimera/issues/24) | UC-23 — HTML Decode | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-23-html-decode) |
| [#25](https://github.com/artur-rios/chimera/issues/25) | UC-24 — Create and Sign JWT | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-24-create-and-sign-jwt) |
| [#26](https://github.com/artur-rios/chimera/issues/26) | UC-25 — Inspect and Verify JWT | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-25-inspect-and-verify-jwt) |
| [#27](https://github.com/artur-rios/chimera/issues/27) | UC-26 — Encode QR Code | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-26-encode-qr-code) |
| [#28](https://github.com/artur-rios/chimera/issues/28) | UC-27 — Decode QR Code (done) | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-27-decode-qr-code) |
| [#29](https://github.com/artur-rios/chimera/issues/29) | UC-28 — URL Encode | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-28-url-encode) |
| [#30](https://github.com/artur-rios/chimera/issues/30) | UC-29 — URL Decode | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-29-url-decode) |

### M-05 — Test-data generators

| Issue | Work | Specification |
| --- | --- | --- |
| [#31](https://github.com/artur-rios/chimera/issues/31) | UC-30 — Generate Hash | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-30-generate-hash) |
| [#32](https://github.com/artur-rios/chimera/issues/32) | UC-31 — Generate Checksum | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-31-generate-checksum) |
| [#33](https://github.com/artur-rios/chimera/issues/33) | UC-32 — Generate Lorem Ipsum | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-32-generate-lorem-ipsum) |
| [#34](https://github.com/artur-rios/chimera/issues/34) | UC-33 — Generate Password | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-33-generate-password) |
| [#35](https://github.com/artur-rios/chimera/issues/35) | UC-34 — Generate UUID or GUID | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-34-generate-uuid-or-guid) |
| [#36](https://github.com/artur-rios/chimera/issues/36) | UC-35 — Generate Credit Card | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-35-generate-credit-card) |
| [#37](https://github.com/artur-rios/chimera/issues/37) | UC-36 — Generate Identity Document | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-36-generate-identity-document) |
| [#38](https://github.com/artur-rios/chimera/issues/38) | UC-37 — Generate Person | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-37-generate-person) |

### M-06 — Ciphers and alphabets

| Issue | Work | Specification |
| --- | --- | --- |
| [#39](https://github.com/artur-rios/chimera/issues/39) | UC-38 — Encode with Cipher | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-38-encode-with-cipher) |
| [#40](https://github.com/artur-rios/chimera/issues/40) | UC-39 — Decode with Cipher | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-39-decode-with-cipher) |
| [#41](https://github.com/artur-rios/chimera/issues/41) | UC-40 — Encode with Alphabet | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-40-encode-with-alphabet) |
| [#42](https://github.com/artur-rios/chimera/issues/42) | UC-41 — Decode Alphabet | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-41-decode-alphabet) |

### M-07 — Experience and distribution

| Issue | Work | Specification |
| --- | --- | --- |
| [#43](https://github.com/artur-rios/chimera/issues/43) | UC-42 — Change Theme | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-42-change-theme) |
| [#44](https://github.com/artur-rios/chimera/issues/44) | UC-43 — Change Language | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-43-change-language) |
| [#45](https://github.com/artur-rios/chimera/issues/45) | UC-44 — Check for Update | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-44-check-for-update) |
| [#46](https://github.com/artur-rios/chimera/issues/46) | UC-45 — Apply Update | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-45-apply-update) |
| [#47](https://github.com/artur-rios/chimera/issues/47) | UC-46 — Publish Release | [Operations](docs/requirements/Operations%20%26%20Infrastructure%20Document.md#73-operational-use-case--uc-46-publish-release) |

### M-08 — Developer workflow automation

| Issue | Work | Source repositories |
| --- | --- | --- |
| [#96](https://github.com/artur-rios/chimera/issues/96) | UC-47 — Create Project from Template | [`cli-utils`](https://github.com/artur-rios/cli-utils) |
| [#97](https://github.com/artur-rios/chimera/issues/97) | UC-48 — Type Periodic Commands | [`cli-utils`](https://github.com/artur-rios/cli-utils) |
| [#98](https://github.com/artur-rios/chimera/issues/98) | UC-49 — Build .NET Solution | [`dotnet-tools`](https://github.com/artur-rios/dotnet-tools), [`python-dotnet-tools`](https://github.com/artur-rios/python-dotnet-tools) |
| [#99](https://github.com/artur-rios/chimera/issues/99) | UC-50 — Clean .NET Build Artifacts | [`dotnet-tools`](https://github.com/artur-rios/dotnet-tools), [`python-dotnet-tools`](https://github.com/artur-rios/python-dotnet-tools) |
| [#100](https://github.com/artur-rios/chimera/issues/100) | UC-51 — Test .NET Projects with Coverage | [`dotnet-tools`](https://github.com/artur-rios/dotnet-tools), [`python-dotnet-tools`](https://github.com/artur-rios/python-dotnet-tools) |
| [#101](https://github.com/artur-rios/chimera/issues/101) | UC-52 — Bump .NET Project Version (implemented; awaiting human review) | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-52-bump-net-project-version) |
| [#102](https://github.com/artur-rios/chimera/issues/102) | UC-53 — Create .NET Release Tag | [`dotnet-tools`](https://github.com/artur-rios/dotnet-tools), [`python-dotnet-tools`](https://github.com/artur-rios/python-dotnet-tools) |
| [#103](https://github.com/artur-rios/chimera/issues/103) | UC-54 — Scaffold NuGet Library Repository | [`dotnet-tools`](https://github.com/artur-rios/dotnet-tools), [`python-dotnet-tools`](https://github.com/artur-rios/python-dotnet-tools) |
| [#104](https://github.com/artur-rios/chimera/issues/104) | UC-55 — Scaffold Minimal .NET Library Repository | [`dotnet-tools`](https://github.com/artur-rios/dotnet-tools), [`python-dotnet-tools`](https://github.com/artur-rios/python-dotnet-tools) |
| [#105](https://github.com/artur-rios/chimera/issues/105) | UC-56 — Scaffold .NET Project | [`dotnet-tools`](https://github.com/artur-rios/dotnet-tools), [`python-dotnet-tools`](https://github.com/artur-rios/python-dotnet-tools) |

## Contributing

One use case equals one issue, branch, and pull request. Feature and fix branches
target `develop`; release branches target `main`. See the
[Development Workflow](docs/requirements/Development%20Workflow%20Document.md)
for the review gates, testing requirements, and Definition of Done.

## License and attribution

Chimera is distributed under the [Artur Rios Attribution License](LICENSE).
Copyright © 2026 [Artur Rios](https://artur-rios.tech).

### Bump a .NET project version (native Windows/Linux)

Use `chimera dotnet bump --version=2.0.0 --project=./src/App.csproj`, or select one
increment with `--major`, `--minor` or `--patch`. Without `--project`, Chimera finds
one immediate `.csproj` child of `./src`; a directory selection uses the same
nonrecursive rule. Add `--json` for structured old/new versions, project path and
recovery details. XML source and UTF-8/UTF-16 encoding are preserved. Failed
transactions retain and report an original backup, including when automatic
restoration succeeds. Exit codes: 0 verified success, 1 transaction/access failure,
2 validation. The desktop form shares this behavior; web explains native-only
support. Conditional projects with multiple Version nodes and other encodings
are rejected before mutation.

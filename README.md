# Chimera

Chimera is a multilingual, cross-platform developer toolbox that combines
common conversion, encoding, formatting, comparison, analysis, and synthetic
test-data utilities in one local-first application. It targets the browser,
Windows and Linux desktops, and the command line.

> **Status:** Specification complete; implementation not started.

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

The repository currently contains specifications. The foundation milestone will
add the Flutter and Dart monorepo. Its intended bootstrap command is:

```bash
melos bootstrap
```

Use the latest stable Flutter and Melos releases at implementation time; Dart is
the version bundled with Flutter.

## Testing

The complete suite defined in the
[Testing Specification](docs/requirements/Testing%20Specification%20Document.md)
will run with:

```bash
melos run test:all
```

The suite covers unit, widget, CLI functional, GUI integration, cross-browser,
deployment, update, accessibility, and performance behavior.

## Roadmap

| Milestone | Delivers | Depends on | Issues | Status |
| --- | --- | --- | ---: | --- |
| [M-01 — Foundation](https://github.com/artur-rios/chimera/milestone/1) | Repository scaffold and initial infrastructure | — | 1 | 0 / 1 closed |
| [M-02 — Scheduling and structured data](https://github.com/artur-rios/chimera/milestone/2) | Cron, date, JSON, CSV, YAML, SQL, and XML tools | M-01 | 8 | 0 / 8 closed |
| [M-03 — Number and text tools](https://github.com/artur-rios/chimera/milestone/3) | Base conversion, escaping, comparison, analysis, and transformation | M-01 | 7 | 0 / 7 closed |
| [M-04 — Encoders and decoders](https://github.com/artur-rios/chimera/milestone/4) | Base64, certificates, GZIP, HTML, JWT, QR, and URL tools | M-01 | 14 | 0 / 14 closed |
| [M-05 — Test-data generators](https://github.com/artur-rios/chimera/milestone/5) | Hashes, checksums, text, credentials, identifiers, cards, documents, and people | M-01 | 8 | 0 / 8 closed |
| [M-06 — Ciphers and alphabets](https://github.com/artur-rios/chimera/milestone/6) | Approved cipher and alphabet encoding and decoding | M-01 | 4 | 0 / 4 closed |
| [M-07 — Experience and distribution](https://github.com/artur-rios/chimera/milestone/7) | Preferences, updates, packaging, and Yggdrasil release delivery | M-01–M-06 | 5 | 0 / 5 closed |

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
| [#28](https://github.com/artur-rios/chimera/issues/28) | UC-27 — Decode QR Code | [Use Case](docs/requirements/Use%20Case%20Specification%20Document.md#uc-27-decode-qr-code) |
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

## Contributing

One use case equals one issue, branch, and pull request. Feature and fix branches
target `develop`; release branches target `main`. See the
[Development Workflow](docs/requirements/Development%20Workflow%20Document.md)
for the review gates, testing requirements, and Definition of Done.

## License and attribution

Chimera is distributed under the [Artur Rios Attribution License](LICENSE).
Copyright © 2026 [Artur Rios](https://artur-rios.tech).

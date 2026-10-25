# Technology Stack Document — Chimera

## 1. Purpose

This document is the single source of truth for the technologies used to build
Chimera: its runtime platform, language, libraries, delivery tooling, and test
tools. Every dependency follows the approved policy of using its latest stable
release at implementation time.

Other requirements documents link here instead of repeating technical versions.
When a technology choice changes, this document changes first.

---

## 2. Platform & Language

| Concern | Choice | Version policy | Notes |
| --- | --- | --- | --- |
| Application framework | **Flutter** | Latest stable at implementation time | Builds the shared web and Windows/Linux desktop interfaces. |
| Language and CLI runtime | **Dart** | Version bundled with the selected Flutter release | Implements shared packages and the Windows/Linux CLI. |
| Language mode | Sound null safety with strict static analysis | Platform-provided | Applies to every first-party package and application. |

---

## 3. Repository & Application Architecture

| Concern | Choice | Version | Role |
| --- | --- | --- | --- |
| Monorepo management | **Melos** | Latest stable at implementation time | Coordinates applications, packages, analysis, and test commands. |
| GUI state management | **flutter_riverpod** | Latest stable at implementation time | Keeps presentation state separate from stateless utility logic. |
| GUI navigation | **go_router** | Latest stable at implementation time | Provides category and utility routes for browser and desktop. |
| CLI parsing | **args** | Latest stable at implementation time | Defines subcommands, options, help, and validation. |
| Result model | Project-owned sealed Dart types | Dart platform | Represents successful output and typed failures without exceptions crossing interface boundaries. |

All utility behavior lives in reusable Dart packages. The Flutter GUI and Dart
CLI are adapters over the same application services; neither contains a second
implementation of an algorithm.

---

## 4. Libraries

### 4.1 Flutter and Dart ecosystem

| Package | Version | Used by | Role |
| --- | --- | --- | --- |
| **flutter_localizations** | Flutter SDK | GUI | Supplies Flutter localization integration. |
| **intl** | Latest stable at implementation time | GUI and core | Resolves localized messages, dates, and locale data. |
| **shared_preferences** | Latest stable at implementation time | GUI | Stores only theme and language preferences. |
| **file_picker** | Latest stable at implementation time | GUI | Selects local input files and browser output downloads. |
| **file_selector** | Latest stable at implementation time (1.1.0 verified 2026-10-19) | GUI native output | Obtains a path-only save location before the project-owned transactional file writer touches the destination. |
| **cross_file** | Latest stable at implementation time | GUI and core | Normalizes selected files without introducing remote storage. |
| **path** | Latest stable at implementation time | CLI and desktop | Handles platform-safe local paths. |
| **http** | Latest stable at implementation time | Update service | Reads GitHub release metadata and downloads accepted updates. |
| **package_info_plus** | Latest stable at implementation time | Desktop | Reads the installed application version for update comparison. |
| **logging** | Latest stable at implementation time | All applications | Emits structured diagnostic events with redaction rules. |

### 4.2 Utility implementation

| Package | Version | Capability | Role |
| --- | --- | --- | --- |
| **archive** | Latest stable at implementation time | GZIP | Compresses and decompresses local byte streams. |
| **crypto** | Latest stable at implementation time | Hashes and updates | Calculates cryptographic hashes and verifies artifact checksums. |
| **csv** | Latest stable at implementation time | Structured data | Serializes JSON-array rows as CSV. |
| **yaml_writer** | Latest stable at implementation time | Structured data | Serializes JSON-compatible values as YAML. |
| **xml** | Latest stable at implementation time | Structured data | Parses and formats XML locally. |
| **timezone** | Latest stable at implementation time | Date conversion | Resolves IANA time zones and daylight-saving transitions. |
| **jose** | Latest stable at implementation time | JWT | Creates, signs, decodes, and verifies tokens locally. |
| **x509** | Latest stable at implementation time | Certificates | Parses and inspects supported certificate structures. |
| **qr** | Latest stable at implementation time | QR encoding | Builds platform-neutral QR matrices from local text. |
| **image** | Latest stable at implementation time | QR images | Renders shared QR matrices as portable PNG bytes. |
| **zxing2** | Latest stable at implementation time | QR decoding | Decodes QR images locally. |
| **diff_match_patch** | Latest stable at implementation time | Text comparison | Produces word- and character-level differences. |
| **uuid** | Latest stable at implementation time | Identifiers | Generates supported UUID and GUID values. |

Cron interpretation, number-base conversion, classical ciphers, alphabets,
checksums not supplied by the listed libraries, document-number validation,
synthetic-person generation, and dialect-aware SQL formatting are implemented as
project-owned Dart modules with specification-based fixtures. JSON, Base64, HTML,
and URL primitives use Dart platform libraries where they meet the requirements.

---

## 5. Local State

Chimera has no database, ORM, migrations, server-side state, or operation history.
The `shared_preferences` adapter stores exactly two values on the user's device:

| Key | Type | Allowed values | Default |
| --- | --- | --- | --- |
| `theme` | String enum | `light`, `dark` | `light` |
| `language` | BCP 47 language tag | `en`, `pt-BR` | `en` |

The core and CLI packages do not depend on this adapter. Operation requests and
results exist in memory only and are discarded when returned to the caller.

---

## 6. Cross-Cutting Technologies

| Concern | Technology | Version | How it is used |
| --- | --- | --- | --- |
| Input validation | Project-owned typed validators | Dart platform | Validates operation-specific inputs before invoking an algorithm. |
| Localization | flutter_localizations + intl | See §4.1 | Resolves all user-facing text through English and Brazilian Portuguese catalogs. |
| Logging | logging | See §4.1 | Writes structured diagnostics while excluding utility inputs, outputs, keys, tokens, and generated personal data. |
| Error model | Project-owned sealed result types | Dart platform | Maps typed errors consistently to GUI messages, CLI stderr, and CLI exit codes. |
| Configuration | `--dart-define`, environment variables, and CLI flags | Platform-provided | Supplies non-secret build, deployment, and command settings. |
| Update transport | http + GitHub Releases API | See §4.1 | Checks release metadata and downloads an artifact only after approval. |
| Update integrity | crypto | See §4.2 | Verifies the published checksum before installation. |

Authentication and authorization technologies are intentionally absent because
Chimera has no accounts or protected operations.

---

## 7. Build, Packaging & Deployment Technologies

| Concern | Technology | Version | Role |
| --- | --- | --- | --- |
| Continuous integration | **Self-hosted Jenkins managed by Yggdrasil**, plus **GitHub Actions** on the GitHub mirror | Images pinned by version and digest in `yggdrasil.yml`; action references pinned in workflow files | Jenkins runs the Linux analysis, tests, builds, and release packaging (`ci/*.sh`); GitHub Actions runs the Windows and macOS jobs and the Windows release packaging. |
| Release and deployment manager | **[Yggdrasil](https://github.com/artur-rios/yggdrasil)** | Owner-managed compatible release | Enforces the repository release flow and resolves deployment behavior from its catalog. |
| Deployment orchestration | **Self-hosted Jenkins managed by Yggdrasil** | Yggdrasil-managed installation | Receives the git server's webhooks, invokes the shared Yggdrasil pipeline, gates environments, and completes releases. |
| Environment deployment | **Docker Compose through Yggdrasil** | Docker-compatible Compose implementation | Builds, labels, deploys, health-checks, and rolls back the environment workload on its host. |
| Web container | **NGINX** | Latest stable container image at implementation time | Serves compiled Flutter web assets and the liveness response. |
| Container runtime | **Docker Engine** | Latest stable supported by the VPS | Builds and runs the web image. |
| Edge routing | **Traefik** | Existing VPS installation | Terminates ingress and routes traffic to the web container. |
| Web host | **Ubuntu VPS** | Existing supported installation | Runs Docker and the web workload. |
| Native artifact hosting | **Git server releases, copied to GitHub Releases** | Yggdrasil-managed Forgejo; managed GitHub service | Publishes portable packages, installers, checksums, and release metadata. |

Build and test checks run in Yggdrasil's Jenkins pipeline, from Chimera's
`yggdrasil.yml` and `ci/` scripts; the Windows and macOS jobs stay GitHub Actions
workflows on the GitHub mirror. The Yggdrasil catalog defines its environments,
required checks, health probe, host name, deployment triggers, and approval
policy. Yggdrasil's Jenkins agent runs deployment on the target host,
rolls back an unhealthy replacement, and completes the release promotion after
all configured gates pass.

---

## 8. Testing Technologies

Testing behavior, structure, and commands are defined in the
[Testing Specification Document](Testing%20Specification%20Document.md).

| Concern | Technology | Version | How it is used |
| --- | --- | --- | --- |
| Dart unit tests | **test** | Latest stable at implementation time | Tests shared packages and CLI behavior. |
| Flutter unit and widget tests | **flutter_test** | Flutter SDK | Tests presentation behavior and shared Flutter adapters. |
| Full-application tests | **integration_test** | Flutter SDK | Exercises browser and desktop workflows through the built application. |
| Cross-browser automation | **Playwright + webdriver** | Latest stable compatible releases, pinned in test configuration | Playwright drives Chromium, Firefox, and WebKit in its official Linux image; webdriver drives native Safari on macOS against the same compiled web application. |
| Coverage | Flutter/Dart coverage tooling and **LCOV** | Latest stable compatible release | Produces and reports coverage while traceability governs completeness. |
| Test doubles | Hand-written fakes and in-memory adapters | Project-owned | Replaces update transport, file access, clipboard access, and local preferences. |
| Test data | Version-controlled fixtures and builders | Project-owned | Covers valid, invalid, boundary, localized, and standard-derived examples. |

No test uses a live network service. Deployment smoke tests operate against the
locally built container or the explicitly selected deployment environment.

---

## 9. Version Summary

| Category | Package / Tool | Version |
| --- | --- | --- |
| Platform | Flutter | Latest stable at implementation time |
| Language | Dart | Bundled with the selected Flutter release |
| Repository | Melos | Latest stable at implementation time |
| Architecture | flutter_riverpod | Latest stable at implementation time |
| Architecture | go_router | Latest stable at implementation time |
| CLI | args | Latest stable at implementation time |
| Localization | flutter_localizations | Flutter SDK |
| Localization | intl | Latest stable at implementation time |
| Local state | shared_preferences | Latest stable at implementation time |
| Files | file_picker | Latest stable at implementation time |
| Native save location | file_selector | Latest stable at implementation time |
| Files | cross_file | Latest stable at implementation time |
| Files | path | Latest stable at implementation time |
| Networking | http | Latest stable at implementation time |
| Application metadata | package_info_plus | Latest stable at implementation time |
| Logging | logging | Latest stable at implementation time |
| Compression | archive | Latest stable at implementation time |
| Cryptography | crypto | Latest stable at implementation time |
| Structured data | csv | Latest stable at implementation time |
| Structured data | yaml_writer | Latest stable at implementation time |
| Structured data | xml | Latest stable at implementation time |
| Date and time | timezone | Latest stable at implementation time |
| Tokens | jose | Latest stable at implementation time |
| Certificates | x509 | Latest stable at implementation time |
| QR | qr and image | Latest stable at implementation time |
| QR | zxing2 | Latest stable at implementation time |
| Text comparison | diff_match_patch | Latest stable at implementation time |
| Identifiers | uuid | Latest stable at implementation time |
| CI/CD | Yggdrasil's Jenkins; GitHub Actions for Windows and macOS | Images pinned in `yggdrasil.yml`; actions pinned in workflows |
| Deployment | Yggdrasil | Owner-managed compatible release |
| Deployment | Self-hosted Jenkins | Managed by the Yggdrasil installation |
| Deployment | Docker Compose | Compatible with the deployed Docker Engine |
| Web serving | NGINX | Latest stable container image at implementation time |
| Containers | Docker Engine | Latest stable supported by the VPS |
| Edge routing | Traefik | Existing VPS installation |
| Web hosting | Ubuntu VPS | Existing supported installation |
| Artifact hosting | GitHub Releases | Managed current service |
| Testing | test | Latest stable at implementation time |
| Testing | flutter_test | Flutter SDK |
| Testing | integration_test | Flutter SDK |
| Testing | Playwright + webdriver | Latest stable compatible releases pinned by the repository |
| Coverage | LCOV | Latest stable compatible release |

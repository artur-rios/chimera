# Changelog

All notable changes to Chimera are documented here. Releases follow Semantic
Versioning and use tags in the form `vX.Y.Z`.

## [Unreleased]

## [0.1.3] - 2026-11-24

### Fixed

- On Linux with an NVIDIA graphics card, the GUI window shows the whole
  application again, under Wayland and X11 alike. Since 0.1.2 it showed
  only the top-right quarter, drawn into the window's bottom-left quarter:
  a Flutter 3.50.0 bug, fixed in 3.50.1.
- On Linux under Wayland, the GUI window's contents are drawn at the right
  size after the window's display scale changes, as when it moves between
  monitors of different scales. Since 0.1.2 they came out twice their size,
  showing only their top-left quarter, or shrunk into that quarter: a
  Flutter 3.50 bug that the Linux runner now works around.
- CLI executable and full-stdout tests no longer time out on a loaded build
  agent: the CLI is compiled once per test run, outside their deadlines,
  instead of once per suite or from source in each test.

### Changed

- Built with Flutter 3.50.1.
- The `analyze-and-test` check runs the package and CLI suites once, with
  coverage, instead of a second time without it, and `browser-tests` runs the
  three browsers in one Playwright run.

## [0.1.2] - 2026-11-15

### Changed

- Built with Flutter 3.50.0 (Dart 3.14.0); Material widgets now come from the
  `material_ui` package.
- Dependencies updated to their latest stable releases, including go_router
  18.1.4, flutter_riverpod 3.5.0, file_picker 13.3.3, archive 4.7.1 and
  crypto 3.0.8; the web image builds on a refreshed `debian:12.15-slim`.
- Save dialogs no longer pass the `type` and `allowedExtensions` arguments that
  file_picker deprecated and that never had any effect.

## [0.1.1] - 2026-10-30

### Fixed

- CLI process tests no longer time out on a loaded build agent: they run a CLI
  compiled once instead of compiling it from source in each test.

## [0.1.0] - 2026-10-29

### Added

- Native GitHub release checks with strict shared metadata validation, SemVer
  compatibility selection, localized CLI/desktop status, and no artifact
  download before explicit approval.
- Explicitly approved native installer updates with bounded staging, streamed
  SHA-256 verification, platform installation, typed failures, and temporary
  data cleanup across CLI and desktop flows.
- Monorepo foundation for the Flutter GUI, Dart CLI, and shared packages.
- English and Brazilian Portuguese application catalogs.
- Privacy, dependency-boundary, release-metadata, accessibility, performance,
  and deployment contracts.
- Reproducible unprivileged web container and native release pipelines.
- Fail-closed release readiness, live Yggdrasil catalog, and complete native
  artifact-bundle gates with an operator promotion and rollback runbook.
- Shared five- and six-field cron parsing with IANA-zone previous/next
  occurrences, localized GUI flow, and human or JSON CLI output.
- Strict ISO 8601, Unix epoch, custom-pattern, and IANA-zone date conversion
  with localized GUI flow and human or JSON CLI output.
- Deterministic JSON-object array table rendering with nested JSON cells,
  optional row numbers, localized GUI flow, and human or JSON CLI output.
- Standards-compliant JSON-object array CSV serialization with selectable
  delimiters and headers, localized preview/save flow, and exact CLI file output.
- Deterministic JSON-to-YAML serialization with indentation and quoting options,
  typed resource limits, localized preview/save flow, and exact CLI file output.
- Deterministic JSON validation and formatting with selectable indentation,
  localized file/clipboard preview, copy/save flows, and exact CLI file output.
- Dialect-aware PostgreSQL, MySQL, SQL Server, and SQLite formatting with
  selectable indentation and keyword case across the shared library, CLI, and
  localized file/clipboard GUI flows.
- Strict concatenated-member GZIP decompression with text and binary modes,
  typed validation and resource limits, and localized CLI and GUI flows.

### Changed

- The repository moved to <https://git.techcraftsmen.net/artur-rios/chimera>,
  with GitHub as a read-only mirror. Yggdrasil's Jenkins pipeline runs the Linux
  checks, the branch policy, and the release builds from `yggdrasil.yml` and
  `ci/`, and publishes releases on the git server and on GitHub; the Windows and
  macOS jobs stay GitHub Actions workflows on the mirror. Renovate proposes
  dependency updates.

### Fixed

- Installed ReportGenerator in the .NET workflow without `--allow-roll-forward`,
  which writes an invalid runtime config on .NET SDK 10.0.402 and broke the
  tool and the coverage integration test.

# Changelog

All notable changes to Chimera are documented here. Releases follow Semantic
Versioning and use tags in the form `vX.Y.Z`.

## [Unreleased]

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

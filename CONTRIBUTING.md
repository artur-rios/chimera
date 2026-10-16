# Contributing

Install Flutter 3.47.7, Dart 3.13.5, Docker, and the native toolchain for the
platform you plan to change. Resolve the workspace with `flutter pub get`.

## Branches and pull requests

`develop` is the integration branch. Create lowercase `feature/<name>` or
`fix/<name>` branches from current `develop` and open their pull requests back
to `develop`. Production releases are unchanged `release/X.Y.Z` snapshots of
`develop` opened against `main`. Never add release-only commits to a release
branch.

Each use case uses one issue, one branch, and one pull request. Conventional
Commit subjects are required. Update `CHANGELOG.md` when a user or operator
would notice the change.

## Verification

Run these checks before opening a pull request:

```text
dart format --output=none --set-exit-if-changed apps packages test tests tool
dart analyze --fatal-infos
dart run melos run test:all
dart run tool/check_boundaries.dart
```

Container changes additionally require `tool/smoke_container.ps1` on Windows
or `sh tool/smoke_container.sh` on Linux. Packaging changes require both scripts'
dry runs and the release-sidecar tests. Pull requests must pass `branch-policy`,
`Analyze and test`, `Cross-platform`, `Container`, and
`Accessibility and performance`.

## Releases

Finalize the version and changelog on `develop`, cut `release/X.Y.Z`, and open
it against `main`. Yggdrasil owns promotion and creates the `vX.Y.Z` release;
GitHub Actions then builds and attaches the native portable packages,
installers, SHA-256 sidecars, and release metadata.

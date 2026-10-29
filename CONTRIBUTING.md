# Contributing

The repository lives at <https://git.techcraftsmen.net/artur-rios/chimera>:
clone it from there and open pull requests there.
[GitHub](https://github.com/artur-rios/chimera) is a read-only mirror, where only
the Windows and macOS jobs run.

```bash
git clone https://git.techcraftsmen.net/artur-rios/chimera.git
```

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
dry runs and the release-sidecar tests.

Pull requests must pass `branch-policy` and the Jenkins checks of
[`yggdrasil.yml`](yggdrasil.yml): `analyze-and-test`, `browser-tests`,
`native-linux`, `container`, `accessibility-performance`, `cleanup-contract`,
`generated-library`, `evaluate-projects`, `version-contract`, `build-contract`,
and `minimal-library`. Each runs `ci/<name>.sh` in a pinned image, which you can
run yourself from the repository's root. They must also pass the GitHub Actions
jobs that run on the mirror, which Jenkins copies onto the pull request: `Safari`,
`Native (windows)`, `Artifact cleanup (windows-latest)`,
`Generated NuGet library (windows-latest)`, `.NET project evaluation (windows-latest)`,
`Project version editing (windows-latest)`,
`.NET build, coverage and process lifecycle (windows-latest)`,
`Minimal library contracts (windows-latest)`, and
`Windows owned terminal lifecycle`. Renovate (`renovate.json`) proposes
dependency updates.

## Releases

Finalize the version and changelog on `develop`, cut `release/X.Y.Z`, and open
it against `main`. Yggdrasil owns promotion and, only after production approval,
merges and tags `vX.Y.Z`. Jenkins then builds the Linux packages
(`ci/release-build.sh`), has the mirror's `release-windows.yml` build the Windows
ones, validates the native portable packages, installers, SHA-256 sidecars, and
release metadata together (`ci/release-validate.sh`), and publishes the release
on the git server and on GitHub. Follow the complete
[publish-release runbook](docs/operations/publish-release.md); release branches
must pass `dart tool/validate_release_readiness.dart --version X.Y.Z`.

# Release artifacts and infrastructure evidence

Chimera publishes native artifacts only after the tagged source passes the full
verification. Yggdrasil owns web deployment, the release's tag and its
publication: its release agent verifies the source and builds the Linux
packages (`ci/release-build.sh`), the GitHub mirror's `release-windows.yml`
workflow builds the Windows packages, and the whole bundle is validated
(`ci/release-validate.sh`) before any release exists; all 24 files are then
uploaded and checked by name and size on the git server and on GitHub.

## Artifact set

Each supported platform produces GUI and CLI packages in portable and installer
forms:

| Platform | Portable | Installer |
| --- | --- | --- |
| Windows x64 | `.zip` | Inno Setup `.exe` |
| Linux x64 | `.tar.gz` | Debian `.deb` |

Names follow
`chimera-{gui|cli}-{windows|linux}-x64-X.Y.Z-{portable|installer}.{extension}`.
Every package has two sidecars:

- `<artifact>.sha256` contains the lowercase SHA-256 digest and filename.
- `<artifact>.release.json` contains `releaseVersion`, `platform`,
  `application`, `packageType`, `downloadUrl`, and `checksum`.

Generate or verify sidecars locally with:

```text
dart run tool/write_checksums.dart <artifact-directory> \
  --version X.Y.Z --repository artur-rios/chimera
dart run tool/validate_release_metadata.dart <artifact>.release.json
```

Validate a combined release directory only when it contains the exact eight
native artifacts and all sixteen sidecars:

```text
dart run tool/validate_release_bundle.dart <artifact-directory> \
  --version X.Y.Z --repository artur-rios/chimera
```

Installed native builds can inspect these sidecars without downloading an
artifact:

```text
chimera update check --repository=artur-rios/chimera \
  --current-version=X.Y.Z --platform=windows --package-type=installer
```

The command reads the latest stable GitHub release, validates every discovered
`.release.json` sidecar against the same six-field validator used by packaging,
and selects the highest exact platform/application/package match using SemVer
precedence. `--json` provides stable automation output. A check never requests
the `downloadUrl` and never invokes an installer; an available result only says
that explicit approval is required by the separate apply workflow.

Apply the selected installer with an explicit same-invocation approval:

```text
chimera update apply --yes --repository=artur-rios/chimera \
  --current-version=X.Y.Z --platform=windows --package-type=installer
```

Without `--yes`, the CLI returns `update-approval-required` before release
discovery, staging, download, or installer activity. The native desktop presents
the same approval as a confirmation dialog containing the version, package type,
and checksum.
Approval is never persisted.

Accepted downloads are restricted to HTTPS `github.com`, use abortable bounded
streaming with a 512 MiB limit, and are written to an isolated temporary root.
The staged file's SHA-256 must exactly match the validated release metadata before
an installer can run. Windows installers use per-user destinations. A detached
helper waits for the current process to exit, runs the verified `.exe` with Inno
Setup unattended/no-restart flags, and owns cleanup of that handed-off staging
root. This avoids asking a running executable to wait for its own replacement.
The immediate result is `scheduled`, not `applied`; the native update screen
disables further checks, and Inno Setup retains its silent progress/error UI so
post-exit failures remain visible. An application-scoped named mutex rejects
duplicate helpers without blocking the other Chimera application.
Linux first validates the `.deb` transaction with
`dpkg --no-act --install`, then invokes `pkexec dpkg --no-triggers --install`.
Chimera's Debian artifacts have no maintainer scripts, so a failed unpack stays
within dpkg's native file backup and rollback behavior. A dismissed or unavailable
permission prompt produces a separate actionable failure. Direct staging cleanup
is attempted after every attempt and any failure is reported; Windows handoff
cleanup is performed by the detached helper. Portable packages are deliberately
rejected by guided self-update because safe in-place replacement of a running
portable application cannot satisfy the working-version preservation
requirement.

The release build rejects malformed tags and runs formatting, analysis, and
tests before either platform is packaged (the Windows workflow is dispatched
after it). The validation recomputes every digest and verifies bundle
completeness and exact metadata; it is pass or fail, and the files uploaded are
the ones taken before it ran. Releases of a repository are serialized by
Yggdrasil's release lock, and the release is public on GitHub only once it is
complete on the git server. Package builds never receive deployment credentials.
Native artifacts contain application binaries only; Yggdrasil keeps host
variables and secrets outside the repository and container layers. The complete
human-operated flow and failure procedures are in the
[publish-release runbook](publish-release.md).

## Infrastructure requirements evidence

| Requirement | Evidence |
| --- | --- |
| IR-01 | Root pub workspace, six member projects, and workspace-layout test. |
| IR-02 | GUI and CLI depend on `chimera_core` and `chimera_utilities`; boundary test rejects reverse dependencies. |
| IR-03 | File, clipboard, preference, update staging, download, checksum, and installer boundaries are injectable contracts. |
| IR-04 | Dependency guard rejects database packages; no remote processing service exists. |
| IR-05 | `PreferenceKey` exposes only `theme` and `language`. |
| IR-06 | Catalog-parity tests require exact English and Brazilian Portuguese key sets. |
| IR-07 | `DiagnosticEvent` retains allowlisted context and redacts sensitive fields. |
| IR-08 | Dependency guard rejects analytics packages and no telemetry pipeline exists. |
| IR-09 | Container contract and live smoke require the exact public `/healthz` payload. |
| IR-10 | Yggdrasil resolves Chimera through local, development, homologation, and production in promotion order. |
| IR-11 | `ci/release-build.sh` verifies the source before packaging, and publication requires complete bundle validation (`ci/release-validate.sh`). |
| IR-12 | The normative Playwright/WebDriver harness runs Chromium, Firefox, and WebKit on Linux plus the compiled shell in native Safari on macOS. |
| IR-13 | CI integration-tests and builds Windows and Linux native targets. |
| IR-14 | Windows/Linux scripts produce GUI/CLI portable and installer artifacts. |
| IR-15 | `write_checksums.dart` emits a SHA-256 sidecar for every recognized native artifact; `validate_release_bundle.dart` recomputes all eight. |
| IR-16 | Yggdrasil builds the Chimera Dockerfile with an environment label and immutable environment tag. |
| IR-17 | Yggdrasil's shared pipeline reads the root `yggdrasil.yml` (checks, branch policy, release files). |
| IR-18 | Compose contains only public build arguments; secrets remain in Yggdrasil's variable store. |
| IR-19 | Yggdrasil's tested deployment pipeline retains or restores the prior healthy image. |
| IR-20 | Typed metadata and complete-bundle validators enforce all six fields and exact release identity for every artifact. |
| IR-21 | Flutter accessibility guidelines and responsive widget checks run in CI; their logs, LCOV, and the completed foundation review are uploaded as evidence. |
| IR-22 | Catalog lookup, CLI startup, GUI startup, and one-megabyte hashing workloads enforce committed thresholds and publish CI output. |
| IR-23 | `availability.md` defines a 99.5% monthly objective measured by Yggdrasil probes. |
| IR-24 | Flutter, Dart, Melos, application packages, Playwright, NGINX, and action majors are pinned to stable releases. |
| IR-25 | `branch-policy` (Yggdrasil's rules, then `ci/branch-policy.sh`) enforces feature/fix-to-develop and release-to-main ancestry, unused-tag, manifest-version, and changelog rules. |
| IR-26 | Release branch policy validates the deploying Yggdrasil installation's catalog and Chimera contract for checks, GitHub Actions checks, health URL, public host, service, and environments. |
| IR-27 | Yggdrasil's release pipeline owns merge, `vX.Y.Z` release creation, and release-branch deletion after gates. |
| IR-28 | Yggdrasil exposes container state, health, logs, and host metrics without receiving utility data. |

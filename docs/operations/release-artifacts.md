# Release artifacts and infrastructure evidence

Chimera publishes native artifacts only after the tagged source passes the full
verification job. Yggdrasil owns web deployment; GitHub Actions owns native
packaging and attaches the results to the existing `vX.Y.Z` GitHub release.

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

The release workflow rejects malformed tags and runs formatting, analysis, and
tests before either platform package job. Package jobs never receive deployment
credentials. Native artifacts contain application binaries only; Yggdrasil
keeps host variables and secrets outside the repository and container layers.

## Infrastructure requirements evidence

| Requirement | Evidence |
| --- | --- |
| IR-01 | Root pub workspace, six member projects, and workspace-layout test. |
| IR-02 | GUI and CLI depend on `chimera_core` and `chimera_utilities`; boundary test rejects reverse dependencies. |
| IR-03 | `FileGateway`, `ClipboardGateway`, `PreferenceGateway`, and `UpdateGateway` are injectable platform contracts. |
| IR-04 | Dependency guard rejects database packages; no remote processing service exists. |
| IR-05 | `PreferenceKey` exposes only `theme` and `language`. |
| IR-06 | Catalog-parity tests require exact English and Brazilian Portuguese key sets. |
| IR-07 | `DiagnosticEvent` retains allowlisted context and redacts sensitive fields. |
| IR-08 | Dependency guard rejects analytics packages and no telemetry pipeline exists. |
| IR-09 | Container contract and live smoke require the exact public `/healthz` payload. |
| IR-10 | Yggdrasil resolves Chimera through local, development, homologation, and production in promotion order. |
| IR-11 | Release package jobs require the `Verify before packaging` job. |
| IR-12 | The normative Playwright/WebDriver harness runs Chromium, Firefox, and WebKit on Linux plus the compiled shell in native Safari on macOS. |
| IR-13 | CI integration-tests and builds Windows and Linux native targets. |
| IR-14 | Windows/Linux scripts produce GUI/CLI portable and installer artifacts. |
| IR-15 | `write_checksums.dart` emits a SHA-256 sidecar for every recognized native artifact. |
| IR-16 | Yggdrasil builds the Chimera Dockerfile with an environment label and immutable environment tag. |
| IR-17 | The root `Jenkinsfile` calls `yggdrasilPipeline(stack: 'chimera')`. |
| IR-18 | Compose contains only public build arguments; secrets remain in Yggdrasil's variable store. |
| IR-19 | Yggdrasil's tested deployment pipeline retains or restores the prior healthy image. |
| IR-20 | Typed validator and per-artifact JSON sidecars enforce all six metadata fields. |
| IR-21 | Flutter accessibility guidelines and responsive widget checks run in CI; their logs, LCOV, and the completed foundation review are uploaded as evidence. |
| IR-22 | Catalog lookup, CLI startup, GUI startup, and one-megabyte hashing workloads enforce committed thresholds and publish CI output. |
| IR-23 | `availability.md` defines a 99.5% monthly objective measured by Yggdrasil probes. |
| IR-24 | Flutter, Dart, Melos, application packages, Playwright, NGINX, and action majors are pinned to stable releases. |
| IR-25 | Branch Policy enforces feature/fix-to-develop and release-to-main ancestry rules. |
| IR-26 | Yggdrasil's catalog records Chimera's checks, health URL, public host, service, and environments. |
| IR-27 | Yggdrasil's release pipeline owns merge, `vX.Y.Z` release creation, and release-branch deletion after gates. |
| IR-28 | Yggdrasil exposes container state, health, logs, and host metrics without receiving utility data. |

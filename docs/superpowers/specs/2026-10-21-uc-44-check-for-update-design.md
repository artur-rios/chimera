# UC-44 Check for Update Design

## Intent

Implement GitHub issue #45 so installed Windows and Linux desktop/CLI builds can
check GitHub Releases for a newer compatible Chimera release without downloading
an application artifact. The result must say either that the installation is
current or describe the compatible update and require an explicit follow-on
approval before UC-45 can download it.

## Scope

- Add shared typed release metadata, semantic-version comparison, compatibility
  selection, and a check-only application service.
- Add a native GitHub Releases metadata adapter behind an injectable boundary.
- Add `chimera update check` with stable human and JSON output and localized
  English/Brazilian Portuguese failures.
- Add a native-only GUI update page and home action with current, available, and
  failure states. The web application exposes no update action and performs no
  update network request.
- Reuse the same release metadata validator from packaging/update contract tests
  and runtime behavior.
- Do not download artifacts, install anything, persist update state, or contact a
  live network service from tests.

## Architecture

`chimera_core` owns the six-field `ReleaseMetadata` value described by IR-20,
strict parsing/validation, semantic versions, compatibility selection, and
`UpdateCheckService`. The service consumes an injected metadata source and accepts
the installed version plus target platform, application, and package type. It
returns typed `current` or `available` output and maps every source, parsing, and
selection failure to `FailureKind.update` without exposing response bodies.

`chimera_platform` implements the native GitHub boundary. Given the configured
repository, it reads the latest stable GitHub release, discovers JSON metadata
sidecars, fetches those sidecars, and returns their JSON values to the core
service. HTTP status failures, malformed GitHub responses, missing sidecars, and
transport failures become safe update failures. The adapter never downloads the
artifact URL during a check. The HTTP client is injected for deterministic tests.

The CLI and GUI compose the service with native platform/application information.
The CLI uses build-defined repository and installed-version values, with explicit
flags available for deterministic automation. The desktop GUI reads the installed
version through `package_info_plus`. Both surfaces receive injectable services in
tests. No update preference or operation history is stored.

## Metadata and compatibility

Runtime metadata uses exactly `releaseVersion`, `platform`, `application`,
`packageType`, `downloadUrl`, and `checksum`, matching IR-20 and the existing
release sidecars. A candidate is compatible only when platform, application, and
package type exactly match the installed target. Initial release packaging is
x64-only; architecture compatibility is enforced by the published artifact name
contract and the packaging/release validator rather than inventing a seventh
metadata field.

Versions use strict SemVer precedence. Build metadata does not affect precedence;
prerelease versions sort below their matching stable version. A candidate prompts
only when its version is strictly newer. When multiple compatible candidates are
present, the highest version wins deterministically. Invalid metadata makes the
whole check fail rather than silently accepting a partial catalog.

## Interface behavior

`chimera update check` reports the installed version and either `current` or the
available version, artifact kind, and checksum. JSON uses stable keys. It never
downloads the artifact. Unsupported native platforms, invalid target options,
missing configuration, transport failures, and malformed metadata exit with the
documented update failure code.

The desktop page exposes one Check action. Available output describes the version
and package and makes clear that approval is required before downloading. Current
output does not show an approval action. Failures leave the installed app usable
and clear stale availability. All user-visible copy is present in both supported
locales and status changes are announced accessibly.

## Failure mapping

- AF-01: transport, HTTP, GitHub payload, sidecar, metadata, or compatibility
  catalog failure returns a typed update failure; the installed version remains
  unchanged and no artifact request occurs.
- AF-02: no strictly newer compatible release returns a successful `current`
  result with no prompt or approval affordance.
- Unsupported platform/configuration is a typed update failure before networking.
- Resource failures while decoding metadata return a typed resource-safe update
  failure with no response contents in diagnostics.

## Testing and verification

Tests are written first and use literal GitHub/metadata fixtures plus recording
fakes. Core tests cover strict SemVer, malformed metadata, compatible selection,
newest selection, current status, prerelease/build precedence, and the invariant
that a check never calls artifact download/install boundaries. Platform tests
cover GitHub response discovery and every transport/status/payload failure without
live networking. CLI and widget tests cover both locales, human/JSON output,
native-only visibility, current/available/failure behavior, and absence of an
artifact request. Repository formatting, analysis, full tests, and dependency
boundaries remain required before the pull request.

## Builder calls

- The GitHub endpoint is the latest stable release API for the configured
  repository; tests may inject a different endpoint/source.
- Package type defaults to `installer` because guided self-update is an installed
  distribution capability. Portable builds may request `portable` explicitly.
- UC-44 exposes approval intent but performs no approval persistence; UC-45 takes
  the selected metadata and an explicit acceptance in the same invocation.

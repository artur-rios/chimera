# UC-46 Publish Release Design

## Intent

Implement the repository-owned part of GitHub issue #47 without performing an
actual production release. Chimera must reject an unprepared release snapshot,
reject an incomplete or corrupt native artifact set, and verify that the live
Yggdrasil catalog still contains the deployment contract on which the root
`Jenkinsfile` depends. Yggdrasil remains responsible for approvals, ordered
deployment, health verification, rollback, merge, tag/release creation, and
release-branch deletion.

## Boundaries

- `tool/validate_release_readiness.dart` validates a strict `X.Y.Z` release
  version against the workspace, CLI, and GUI manifests and a dated changelog
  section. It performs no GitHub or deployment mutation.
- `tool/validate_release_bundle.dart` validates the exact eight native packages
  and their checksum and metadata sidecars after the Windows and Linux jobs are
  combined. It recalculates every digest and validates every metadata field and
  GitHub download URL before the publisher receives write permission.
- The release-to-`main` branch-policy path checks out Yggdrasil `main`, installs
  its declared Python test dependencies, validates its catalog, and runs the
  catalog contract test for Chimera. A missing repository, dependency, catalog
  entry, or required field fails the policy check and leaves the pull request
  open.
- The catalog contract requires an explicit production approval. The existing
  root `Jenkinsfile` remains the single deployment handoff. Chimera's catalog
  entry must opt into the verified handoff with `releaseArtifacts: true`, and
  Yggdrasil serializes the complete release flow per application.
  Yggdrasil's shared pipeline owns check waiting, environment ordering,
  approvals, health checks, rollback, failure statuses, final merge, tag and
  release creation, and branch deletion.
- After successful deployment, Yggdrasil creates the immutable tag and a private
  draft release, dispatches Chimera's artifact workflow with the exact release
  ID, and waits. The workflow serializes work per tag, validates and uploads the
  complete bundle, verifies GitHub's remote size and SHA-256 for every asset,
  and only then atomically changes the draft to a public release. An interrupted
  run leaves partial assets private and safely replaceable on retry.
- `docs/operations/publish-release.md` gives operators an auditable preflight,
  promotion, observation, failure, and recovery procedure. It never instructs
  an agent to approve or publish production autonomously. Its preflight also
  proves the controller's mounted catalog matches the reviewed Yggdrasil
  `main`, preventing a stale runtime from bypassing the approval contract.

## Release Readiness Contract

A release version is valid only when it is canonical `X.Y.Z`, the root and CLI
manifest versions match it exactly, the GUI manifest has the same version with
an optional positive build suffix, and the changelog has exactly one dated
`## [X.Y.Z] - YYYY-MM-DD` heading. This catches a release branch whose name,
application identity, or operator notes disagree before deployment begins.

The policy continues to require `release/X.Y.Z` to be an unchanged ancestor of
current `develop` and rejects an existing `vX.Y.Z` tag. Release readiness is an
additional gate, not a replacement for ancestry or tag checks.

## Native Bundle Contract

The complete bundle contains desktop and CLI artifacts for Windows and Linux,
each in portable and installer form. Every artifact has one `.sha256` and one
`.release.json` sidecar. Validation rejects:

- missing or unexpected files;
- digest or checksum-filename mismatches;
- malformed metadata;
- mismatched version, platform, application, package type, URL, or checksum;
- duplicate logical packages hidden behind alternate filenames.

Only the validated bundle reaches `gh release upload`, and only while the target
release is still a draft. Package jobs and the validator have read-only
repository permission; only the final publisher has `contents: write`. The
publisher revalidates the local bundle, uploads under a per-tag concurrency
lock, compares GitHub's complete remote asset list, sizes, states, and digests,
then publishes the draft in one release update.

## Failure Semantics

- A readiness, branch-policy, required-check, or catalog preflight failure keeps
  the release pull request open and prevents later release environments.
- A deployment or health failure is handled by Yggdrasil, which marks the
  environment failure, retains or restores the prior healthy workload, and does
  not promote to the next environment.
- Missing agents, approvals, variables, or credentials stop in Yggdrasil before
  the next environment changes.
- A package, bundle, upload, or remote validation failure leaves the GitHub
  release private and reports the exact rejected path/field. A retry replaces
  draft assets; users never observe a partial stable bundle.

## Traceability

- FR-UP-01, IR-14, IR-15, IR-20, BR-09, BR-16: exact artifact set, checksum,
  and metadata validation before publication.
- IR-10, IR-16-IR-19, IR-26-IR-28: live Yggdrasil catalog preflight plus the
  existing shared-pipeline handoff and operator evidence.
- IR-11-IR-13, IR-21, IR-24: existing catalog-required CI checks remain stable
  and precede release promotion and packaging.
- IR-25: branch ancestry, naming, unused-tag, and new version/changelog gates.

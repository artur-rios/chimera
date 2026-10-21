# UC-46 Publish Release Implementation Plan

**Goal:** Make Chimera's release preparation and native publication fail closed
while preserving Yggdrasil as the deployment and release authority.

**Architecture:** Add two deterministic Dart validators: one for source-release
readiness and one for the merged native artifact bundle. Wire source validation
and a live Yggdrasil catalog check into release branch policy, wire bundle
validation between packaging and publication, and document the human-operated
promotion and recovery procedure. Add a companion Yggdrasil change that requires
production approval and hands a private draft release to the serialized Chimera
artifact workflow.

## Task 1: Specify readiness and bundle failures

**Files:**
- Add: `test/foundation/release_readiness_test.dart`
- Add: `test/foundation/release_bundle_test.dart`
- Modify: `test/foundation/workflow_contract_test.dart`

- Cover canonical versions, manifest drift, missing/duplicate changelog entries,
  exact eight-artifact completeness, corrupt bytes, invalid metadata, and
  unexpected files.
- Assert release branch policy performs readiness and live Yggdrasil catalog
  preflight, and publication depends on successful local and remote bundle
  validation while the release remains a draft.
- Run the focused tests and witness failures before implementation.

## Task 2: Implement source release readiness

**Files:**
- Add: `tool/validate_release_readiness.dart`
- Modify: `.github/workflows/branch-policy.yml`

- Implement structured validation errors and a nonzero command exit.
- Validate root, CLI, GUI, and changelog versions.
- In the release-to-main policy path, run the validator, then validate the live
  Yggdrasil catalog and its Chimera contract.

## Task 3: Implement complete bundle validation

**Files:**
- Add: `tool/validate_release_bundle.dart`
- Modify: `.github/workflows/release-artifacts.yml`

- Define the exact Windows/Linux desktop/CLI portable/installer matrix once.
- Recompute SHA-256 values and compare exact sidecar content and metadata.
- Download both packaging artifacts into a read-only validation job.
- Require that job before the write-scoped publisher uploads any file.
- Revalidate the downloaded bundle in the publisher, verify every remote asset's
  state, size, and SHA-256, then publish the draft release.

## Task 4: Complete the Yggdrasil handoff

**Files (companion Yggdrasil pull request):**
- Modify: `catalog.yaml`
- Modify: `scripts/github.sh`
- Modify: `jenkins/library/vars/yggdrasilPipeline.groovy`
- Modify: affected Yggdrasil tests and documentation

- Require explicit approval for production.
- Create the exact tag and an unpublished draft release after deployment.
- Dispatch `release-artifacts.yml` with the tag and release ID, wait until the
  workflow publishes the verified draft, and only then delete the release branch.
- Require the explicit `releaseArtifacts` catalog capability and serialize the
  complete release flow per application across multibranch jobs.

## Task 5: Add the operator runbook and traceability

**Files:**
- Add: `docs/operations/publish-release.md`
- Modify: `docs/operations/release-artifacts.md`
- Modify: `CONTRIBUTING.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- Document preparation, exact branch point, PR targets, checks, Yggdrasil
  surfaces, approvals, native publication, rollback evidence, and stop rules.
- State explicitly that implementation does not publish a release and that only
  an approved human-operated UC-46 run may do so.

## Task 6: Verify and review

- Format changed Dart files.
- Run readiness, bundle, workflow, packaging, metadata, deployment, and branch
  policy tests.
- Run static analysis, dependency boundaries, and `git diff --check`.
- Request an independent release-blocking correctness/security review.
- Commit, push, and open the UC-46 pull request into `develop`; do not merge,
  tag, deploy, delete a branch, or close the issue.

# Publish a Chimera release

This runbook executes UC-46 after its implementation pull request and all
intended product changes have been reviewed and merged into `develop`. It is an
operator procedure: automation may prepare evidence, but a human product owner
approves production promotion. Never move an existing release tag, bypass a
required check, or copy deployment credentials into this repository.

## 1. Confirm the release is ready

Choose a canonical `X.Y.Z` version. On `develop`, update the root and CLI
`pubspec.yaml` versions to exactly `X.Y.Z`, update the GUI version to `X.Y.Z` or
`X.Y.Z+N` with a positive build number, and move the intended changelog entries
under exactly one dated heading:

```text
## [X.Y.Z] - YYYY-MM-DD
```

From a clean checkout of the intended `develop` commit, run:

```text
flutter pub get
dart tool/validate_release_readiness.dart --version X.Y.Z
dart format --output=none --set-exit-if-changed apps packages test tests tool
dart analyze --fatal-infos
dart run melos run test:all
dart run tool/check_boundaries.dart
```

Confirm the companion Yggdrasil release contract has been reviewed and rolled
out on the Yggdrasil installation that deploys Chimera: Jenkins reads its own
yggdrasil checkout, and the release pull request's `branch-policy` validates
that very catalog (`ci/branch-policy.sh` runs `tool/validate_yggdrasil_contract.py`
and Yggdrasil's `ChimeraCatalogTests` on it). Confirm the installation's
protected stores contain the required agent, environment variables, public
routing configuration, the production approval owner and, for the Windows
files, the GitHub App that dispatches workflows on the mirror (**Actions: Read
and write**). Do not print or copy their values. Stop if any check fails.

Record the approved `develop` commit:

```text
git fetch origin develop main
git switch develop
git pull --ff-only origin develop
git rev-parse HEAD
```

## 2. Open the immutable release snapshot

Create `release/X.Y.Z` at that exact recorded commit. Do not add release-only
commits to the branch.

```text
git switch -c release/X.Y.Z <approved-develop-commit>
git push -u origin release/X.Y.Z
```

Open the pull request from `release/X.Y.Z` into `main` on
<https://git.techcraftsmen.net/artur-rios/chimera>, titled `release: vX.Y.Z`.

The pull request must remain open unless all of these are successful:

- `branch-policy`: Yggdrasil's ancestry and unused-tag rules, then Chimera's
  source readiness and catalog contract (`ci/branch-policy.sh`);
- every Jenkins check of `yggdrasil.yml` (`analyze-and-test`, `browser-tests`,
  `native-linux`, `container`, `accessibility-performance`, `cleanup-contract`,
  `generated-library`, `evaluate-projects`, `version-contract`,
  `build-contract`, `minimal-library`) and every GitHub Actions job the catalog
  lists in `actionsChecks`, which Jenkins copies from the mirror;
- every Yggdrasil deployment status and the required production approval.

The `release/*` push may deploy the on-demand homologation environment. Verify
the selected commit, image label, route, and exact public health response
`{"status":"ok"}` there before approving production.

## 3. Observe Yggdrasil promotion

Jenkins runs Yggdrasil's shared pipeline on the repository (its
`Jenkinsfile.default`; Chimera has no `Jenkinsfile` of its own), which reads
`yggdrasil.yml`. For a valid release pull request it:

1. runs the branch policy and every check `main` requires, and waits for the
   GitHub Actions checks;
2. marks each configured release environment pending;
3. waits for the required production approval;
4. deploys on the catalog-selected agent and verifies health;
5. promotes only after the preceding environment succeeds;
6. after the last environment succeeds, merges the exact pull-request head and
   tags `vX.Y.Z`;
7. builds, validates and publishes the release files (below), then deletes the
   release branch where the git server allows it.

Observe the pull request checks, Jenkins stage view, Yggdrasil status API, public
health route, container state, logs, and platform metrics. These surfaces may
contain operational signals only—never utility input, output, or secrets.

## 4. Verify native publication

From the tag, on the release agent, `ci/release-build.sh` repeats the source
verification and builds, packages and smoke-tests the Linux GUI and CLI
packages with their sidecars. Jenkins dispatches the mirror's
`Release Windows` workflow (`release-windows.yml`) on the tag, which builds the
Windows packages and sidecars, and downloads them. `ci/release-validate.sh` then
combines both sets and runs:

```text
dart run tool/validate_release_bundle.dart <bundle> \
  --version X.Y.Z --repository artur-rios/chimera
```

Only a valid bundle is published: Jenkins creates draft releases on the git
server and on GitHub, uploads the files it took before validation, checks each
by name and size, and publishes the git server's release, then GitHub's last.
Confirm the release has eight native artifacts and, for each artifact, one
`.sha256` and one `.release.json` sidecar (24 files total). Download to an
isolated directory and rerun the validator before announcing the release.

## 5. Stop and recover safely

- **Required check or branch-policy failure:** leave the pull request open and
  do not approve later environments. Fix the cause on `develop`, obtain review,
  and replace the release branch with a new exact approved snapshot.
- **Deployment or health failure:** do not merge or tag. Confirm Yggdrasil marks
  the deployment failed and that the previous image is healthy or restored.
  Preserve Jenkins, health, and rollback evidence before retrying.
- **Missing catalog, agent, variable, approval, or credential:** stop before the
  next environment. Restore the external prerequisite in Yggdrasil or its
  protected store; never add it to Chimera source or artifacts.
- **Native build, upload, or validation failure:** after the merge the release
  cannot run again; nothing is published while the bundle is incomplete or
  invalid (a Windows run that failed, or GitHub Actions checks skipped, leaves
  the bundle incomplete). Finish it with Yggdrasil's `release-resume` job
  (`REPOSITORY=chimera`, `TAG=vX.Y.Z`), which rebuilds and revalidates the files
  from the unchanged tag. If source or workflow code must change, keep the
  existing tag immutable and prepare a new reviewed patch release.

After success, record the pull request, merge commit, tag, releases (git server
and GitHub), Windows workflow run, Jenkins run, deployment statuses, health evidence, and bundle
validation result. Closing the UC-46 issue still requires explicit human
approval after its implementation pull request is reviewed and merged.

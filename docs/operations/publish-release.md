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

Confirm the companion Yggdrasil release contract has been reviewed, merged to
Yggdrasil `main`, and rolled out on the controller host. A green remote catalog
is not enough: Jenkins reads the controller's mounted checkout. On that host,
update and restart the platform as described by Yggdrasil, then prove both the
host and controller see the approved contract:

```text
cd /opt/yggdrasil
git fetch origin main
git pull --ff-only origin main
scripts/platform.sh up
docker restart yggdrasil-status-1 yggdrasil-jenkins-1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
test "$(python3 scripts/catalog.py get chimera production approval)" = true
python3 scripts/catalog.py show chimera | jq -e '.releaseArtifacts == true'
docker exec yggdrasil-jenkins-1 cat /etc/jenkins/catalog.yaml |
  cmp --silent catalog.yaml -
```

The Jenkins GitHub App installation must also show **Actions: Read and write**.
Confirm its protected stores contain that credential, the required agent,
environment variables, public routing configuration, and the production
approval owner. Do not print or copy their values. Stop if any command or
permission check fails. The release branch-policy independently loads
Yggdrasil `main`, validates it, and runs the Chimera catalog contract test; this
guards repository drift, while the checks above guard controller drift.

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
gh pr create --base main --head release/X.Y.Z --title "release: vX.Y.Z"
```

The pull request must remain open unless all of these are successful:

- `branch-policy`, including ancestry, unused tag, source readiness, and live
  Yggdrasil catalog checks;
- `Analyze and test`, `Cross-platform`, `Container`, and
  `Accessibility and performance`;
- every Yggdrasil deployment status and the required production approval.

The `release/*` push may deploy the on-demand homologation environment. Verify
the selected commit, image label, route, and exact public health response
`{"status":"ok"}` there before approving production.

## 3. Observe Yggdrasil promotion

The root `Jenkinsfile` invokes `yggdrasilPipeline(stack: 'chimera')`. For a valid
release pull request the shared pipeline:

1. waits for the catalog-required GitHub checks;
2. marks each configured release environment pending;
3. waits for the required production approval;
4. deploys on the catalog-selected agent and verifies health;
5. promotes only after the preceding environment succeeds; and
6. after the last environment succeeds, merges the exact pull-request head,
   creates tag `vX.Y.Z` and a private draft release, and dispatches the native
   artifact workflow with that release's immutable ID;
7. waits for the artifact workflow to publish the verified draft, then deletes
   the release branch.

Observe the pull request checks, Jenkins stage view, Yggdrasil status API, public
health route, container state, logs, and platform metrics. These surfaces may
contain operational signals only—never utility input, output, or secrets.

## 4. Verify native publication

Yggdrasil dispatches `Release Artifacts` while the GitHub release is private.
Its read-only jobs repeat source verification and build the Windows and Linux
desktop/CLI portable and installer packages. A separate read-only job combines
the packages and runs:

```text
dart run tool/validate_release_bundle.dart dist \
  --version X.Y.Z --repository artur-rios/chimera
```

Only then may the write-scoped job revalidate and upload the bundle. Work for a
tag is serialized. The job reads GitHub's remote asset list and verifies all 24
asset names, uploaded states, sizes, and SHA-256 digests against its local files.
Only that successful check changes the draft into a public release. Confirm the
release has eight native artifacts and, for each artifact, one `.sha256` and one
`.release.json` sidecar (24 files total). Download to an isolated directory and
rerun the validator before announcing the release.

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
- **Native build, upload, or validation failure:** the release remains a private
  draft, even if it contains partial assets. A serialized retry may replace
  those draft assets against the unchanged tag. If source or workflow code must
  change, keep the existing tag immutable and prepare a new reviewed patch
  release; delete or retain the failed draft according to operator policy, but
  never publish it.

After success, record the pull request, merge commit, tag, GitHub release,
workflow run, Jenkins run, deployment statuses, health evidence, and bundle
validation result. Closing the UC-46 issue still requires explicit human
approval after its implementation pull request is reviewed and merged.

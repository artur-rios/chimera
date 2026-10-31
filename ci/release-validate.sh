#!/usr/bin/env bash
# The release's validation (`release.validate` in yggdrasil.yml; the old release-artifacts.yml's
# validate-artifacts, "Validate complete native bundle"): the Linux and Windows packages together, each with its
# checksum and release metadata sidecar, and nothing else. It is pass or fail: the pipeline uploads the set it took
# before this ran, so nothing here can change what is published.
#
# The pipeline puts the release's files under RELEASE_FILES (a copy): release.build's at their paths in the
# checkout (build/dist/linux/), the Windows workflow's artifact under windows/chimera-windows-packages/. They are
# gathered into one directory here, as the workflow's download-artifact merge-multiple did. A release whose Windows
# files are missing (the GitHub Actions checks skipped, or the Windows run failed) fails here, as a release without
# them never passed this validation on GitHub: finish it with yggdrasil's release-resume job.
#
# RELEASE_FILES, RELEASE_TAG and RELEASE_VERSION are set by the pipeline.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

files=${RELEASE_FILES:?ci/release-validate.sh: RELEASE_FILES is not set}
version=${RELEASE_VERSION:?ci/release-validate.sh: RELEASE_VERSION is not set}
repository=artur-rios/chimera

bundle="$files/bundle"
rm -rf "$bundle"
mkdir -p "$bundle"
for directory in "$files/build/dist/linux" "$files/windows/chimera-windows-packages"; do
  if [ -d "$directory" ]; then
    find "$directory" -maxdepth 1 -type f -exec cp {} "$bundle/" \;
  else
    echo "ci/release-validate.sh: ${directory#"$files"/} is missing" >&2
  fi
done

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
dart run tool/validate_release_bundle.dart "$bundle" --version "$version" --repository "$repository"

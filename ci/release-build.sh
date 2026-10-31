#!/usr/bin/env bash
# The release's Linux files (`release.build` in yggdrasil.yml), run on the release agent from the checkout of
# the release's tag. It ports the Linux jobs of the old release-artifacts.yml:
#
#   verify          the release source: readiness for the version, formatting, analysis and every test suite;
#   package-linux   the Linux GUI and CLI built for the version, packaged (tool/package_linux.sh) with their
#                   checksum and release metadata sidecars, and both .deb packages installed and smoke-tested.
#
# Everything lands in dist/linux/ (the release's `files`). The Windows packages are the release-windows.yml
# workflow's; release.validate checks the whole set; yggdrasil's pipeline uploads and publishes it, on the git
# server and on the GitHub mirror (the old workflow's draft check and its publish job).
#
# RELEASE_TAG and RELEASE_VERSION are set by the pipeline (vX.Y.Z and X.Y.Z). By hand, set RELEASE_TAG.
#
# It runs as root, as release builds do on the release agent: the Linux desktop prerequisites are installed with
# apt, and the packages with dpkg, into the build's own container.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

tag=${RELEASE_TAG:?ci/release-build.sh: RELEASE_TAG (vX.Y.Z) is not set}
if ! [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ci/release-build.sh: '$tag' is not a vX.Y.Z tag" >&2
  exit 1
fi
version=${tag#v}
# The GitHub repository the applications look at for updates (the releases are copied there by the mirror), and
# the one the release metadata's download addresses name. The workflow had it from GITHUB_REPOSITORY.
repository=artur-rios/chimera

if [ "$(id -u)" -ne 0 ]; then
  echo "ci/release-build.sh: run it as root: the packages are installed with dpkg and smoke-tested" >&2
  exit 1
fi

# The image is the .NET SDK's: the verification runs the whole test suite, whose scaffold tests use the .NET 10 SDK
# the GitHub runner had (see ci/analyze-and-test.sh). The packages the workflow's apt step installed are installed
# here, with two the runner already had: pkexec (the GUI package Depends on pkexec | policykit-1) and unzip (Flutter
# unpacks the Linux engine artifacts with it).
# shellcheck source=ci/apt-packages.sh
source ci/apt-packages.sh
ensure_packages clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev dpkg-dev xvfb pkexec unzip
# shellcheck source=ci/python.sh
source ci/python.sh
ensure_python3
# shellcheck source=ci/pyyaml.sh
source ci/pyyaml.sh
ensure_pyyaml
# shellcheck source=ci/node.sh
source ci/node.sh
ensure_node
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

# ---- Verify before packaging ----
flutter pub get
dart tool/validate_release_readiness.dart --version "$version"
dart format --output=none --set-exit-if-changed apps packages test tests tool
dart analyze --fatal-infos
dart run melos run test:unit
dart test test tests/deployment tests/update tests/performance

# ---- Package Linux ----
(
  cd apps/chimera_gui
  flutter build linux --release \
    --build-name="$version" \
    --dart-define="CHIMERA_RELEASE_REPOSITORY=$repository"
)
mkdir -p build/cli/linux
dart compile exe apps/chimera_cli/bin/chimera.dart \
  --define="CHIMERA_VERSION=$version" \
  --define="CHIMERA_RELEASE_REPOSITORY=$repository" \
  -o build/cli/linux/chimera

rm -rf dist/linux
sh tool/package_linux.sh \
  --version "$version" \
  --gui-dir apps/chimera_gui/build/linux/x64/release/bundle \
  --cli build/cli/linux/chimera \
  --output dist/linux
dart run tool/write_checksums.dart dist/linux --version "$version" --repository "$repository"

# ---- Smoke-test the installed Linux packages ----
dpkg --install dist/linux/chimera-cli-linux-*-installer.deb
dpkg --install dist/linux/chimera-gui-linux-*-installer.deb
chimera --help
set +e
xvfb-run -a timeout 5s chimera-gui
status=$?
set -e
if [ "$status" -ne 124 ]; then
  echo "ci/release-build.sh: chimera-gui exited $status before the 5 s smoke timeout (124 expected)" >&2
  exit 1
fi

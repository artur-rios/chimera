#!/usr/bin/env bash
# The native-linux check (GitHub: ci.yml's "Native (linux)", the Linux leg of native-tests; the Windows
# leg stays a GitHub Actions job, "Native (windows)"): the native GUI integration tests under a virtual
# display, then the release builds of the Linux GUI and the CLI.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/apt-packages.sh
source ci/apt-packages.sh
ensure_packages clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev xvfb
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
xvfb-run -a dart run tool/run_native_gui_tests.dart linux

(cd apps/chimera_gui && flutter build linux --release)
# The AOT compiler does not create parent directories.
mkdir -p build/cli/linux
dart compile exe apps/chimera_cli/bin/chimera.dart -o build/cli/linux/chimera

#!/usr/bin/env bash
# The minimal-library check (GitHub: minimal-dotnet-library.yml's "Minimal library contracts
# (ubuntu-latest)"; the windows-latest leg stays a GitHub Actions job): the pinned goldens, safety,
# rollback, and real Debug and Release builds with the .NET SDK, the image's (the workflow's setup-dotnet
# 10.0.x).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/python.sh
source ci/python.sh
ensure_python3
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
dart test \
  packages/chimera_utilities/test/dotnet_minimal_repository_test.dart \
  packages/chimera_core/test/minimal_library_scaffold_service_test.dart \
  packages/chimera_platform/test/minimal_library_scaffold_test.dart \
  apps/chimera_cli/test/functional/dotnet_init_min_test.dart

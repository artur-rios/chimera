#!/usr/bin/env bash
# The version-contract check (GitHub: dotnet-version.yml's "Project version editing (ubuntu-latest)"; the
# windows-latest leg stays a GitHub Actions job): the .NET project version editing contracts.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
dart test \
  packages/chimera_utilities/test/dotnet_version/dotnet_version_editor_test.dart \
  packages/chimera_core/test/dotnet_bump_service_test.dart \
  packages/chimera_platform/test/dotnet_bump_test.dart \
  apps/chimera_cli/test/functional/dotnet_bump_cli_test.dart \
  packages/chimera_platform/test/windows_short_path_test.dart

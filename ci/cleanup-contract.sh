#!/usr/bin/env bash
# The cleanup-contract check (GitHub: dotnet-clean.yml's "Artifact cleanup (ubuntu-latest)"; the
# windows-latest leg stays a GitHub Actions job): the native build artifact cleanup contracts.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
dart test \
  packages/chimera_core/test/dotnet_clean_service_test.dart \
  packages/chimera_platform/test/dotnet_clean_test.dart \
  apps/chimera_cli/test/functional/dotnet_clean_cli_test.dart

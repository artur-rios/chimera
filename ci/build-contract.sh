#!/usr/bin/env bash
# The build-contract check (GitHub: dotnet-workflows.yml's ".NET build, coverage and process lifecycle
# (ubuntu-latest)"; the windows-latest leg stays a GitHub Actions job): shared builds, discovery,
# diagnostics and cancellation, then annotated tags, the selected remote and cancellation, with the .NET
# SDK, the image's (the workflow's setup-dotnet 10.0.x), and ReportGenerator installed into
# .dotnet-test-tools/ and put on PATH, as the workflow did.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/python.sh
source ci/python.sh
ensure_python3
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

# renovate: datasource=nuget depName=dotnet-reportgenerator-globaltool
REPORTGENERATOR_VERSION=5.5.11
if [ ! -x .dotnet-test-tools/reportgenerator ]; then
  dotnet tool install dotnet-reportgenerator-globaltool --version "$REPORTGENERATOR_VERSION" \
    --tool-path .dotnet-test-tools
fi
export PATH="$PWD/.dotnet-test-tools:$PATH"

flutter pub get
dart test \
  packages/chimera_core/test/dotnet_build_test.dart \
  packages/chimera_platform/test/native_commands_test.dart \
  packages/chimera_platform/test/dotnet_build_integration_test.dart \
  apps/chimera_cli/test/functional/dotnet_build_test.dart \
  packages/chimera_core/test/dotnet_test_test.dart \
  packages/chimera_platform/test/dotnet_test_workspace_test.dart \
  packages/chimera_platform/test/dotnet_test_integration_test.dart \
  apps/chimera_cli/test/functional/dotnet_test_test.dart \
  packages/chimera_platform/test/native_project_discovery_alias_test.dart \
  packages/chimera_platform/test/windows_short_path_test.dart
dart test \
  packages/chimera_core/test/dotnet_tag_service_test.dart \
  packages/chimera_platform/test/dotnet_tag_project_test.dart \
  apps/chimera_cli/test/functional/dotnet_tag_test.dart \
  apps/chimera_cli/test/functional/dotnet_tag_signal_test.dart

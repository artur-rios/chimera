#!/usr/bin/env bash
# The evaluate-projects check (GitHub: dotnet-project.yml's ".NET project evaluation (ubuntu-latest)"; the
# windows-latest leg stays a GitHub Actions job): the .NET project scaffold, evaluated with the real .NET
# SDK, the image's (the workflow's setup-dotnet 10.0.x).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/python.sh
source ci/python.sh
ensure_python3
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
dart test packages/chimera_platform/test/dotnet_project_scaffold_test.dart

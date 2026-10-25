#!/usr/bin/env bash
# The generated-library check (GitHub: dotnet-library-scaffold.yml's "Generated NuGet library
# (ubuntu-latest)"; the windows-latest leg stays a GitHub Actions job): the scaffold's parameter, template
# and transaction contracts, then a generated repository restored, built, tested and packed with the real
# .NET SDK, the image's (the workflow's setup-dotnet 10.0.x).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/python.sh
source ci/python.sh
ensure_python3
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
dart test \
  packages/chimera_utilities/test/dotnet_repository_test.dart \
  packages/chimera_core/test/dotnet_library_scaffold_service_test.dart \
  packages/chimera_platform/test/dotnet_library_scaffold_test.dart
dart run tool/verify_dotnet_library.dart

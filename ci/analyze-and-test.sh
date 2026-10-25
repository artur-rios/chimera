#!/usr/bin/env bash
# The analyze-and-test check (GitHub: ci.yml's "Analyze and test"): formatting, analysis, the dependency
# boundaries, the Dart and contract tests, and the Dart coverage report. The test logs and the coverage
# are the check's archive (yggdrasil.yml), as they were the workflow's test-and-coverage-evidence.
#
# The suites use what the GitHub runner had installed: the .NET 10 SDK (the scaffold tests evaluate and build
# real projects), Node (a compiled-JavaScript boundary test) and Python with PyYAML (the Yggdrasil contract test).
# The image is the .NET SDK's; the others are fetched, checksum-pinned, by the scripts sourced below.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

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

flutter pub get
dart format --output=none --set-exit-if-changed apps packages test tests tool
dart analyze --fatal-infos
dart run tool/check_boundaries.dart

mkdir -p evidence
dart run melos run test:unit 2>&1 | tee evidence/unit-tests.txt
dart run melos run test:deployment 2>&1 | tee evidence/deployment-tests.txt

dart test --coverage=coverage/dart \
  packages/chimera_core/test \
  packages/chimera_l10n/test \
  packages/chimera_platform/test \
  apps/chimera_cli/test
dart run coverage:format_coverage \
  --packages=.dart_tool/package_config.json \
  --report-on=packages \
  --in=coverage/dart \
  --lcov \
  --out=coverage/dart/lcov.info

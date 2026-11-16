#!/usr/bin/env bash
# The accessibility-performance check (GitHub: ci.yml's "Accessibility and performance"): the semantic
# widget checks with coverage, then the committed performance contracts. Their logs, the coverage, the
# accessibility review and the thresholds are the check's archive (yggdrasil.yml), as they were the
# workflow's accessibility-and-performance-evidence.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
mkdir -p evidence
# The widget checks, then the GUI's other suites (the adapters and the pages' own), which no other check runs;
# test/performance is the performance contracts' below.
(
  cd apps/chimera_gui
  flutter test --coverage test/widgets test/adapters test/*_test.dart 2>&1 | tee ../../evidence/accessibility-tests.txt
)
dart run melos run test:performance 2>&1 | tee evidence/performance-tests.txt

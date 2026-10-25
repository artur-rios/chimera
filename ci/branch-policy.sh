#!/usr/bin/env bash
# chimera's own branch policy (`branchPolicy` in yggdrasil.yml), run after yggdrasil's scripts/branch-policy.sh
# passed, and reported with it as the `branch-policy` status. yggdrasil's policy already checks what the old
# branch-policy.yml checked about branches: feature/ or fix/ (or renovate/) cut from develop into develop,
# release/x.y.z into main as a snapshot of develop whose version has no tag. What is left is chimera's, for a
# release pull request into main only:
#
#   - the source is ready for that version (tool/validate_release_readiness.dart);
#   - the catalog of the yggdrasil installation that deploys chimera is valid, keeps chimera's release and
#     deployment contract (tool/validate_yggdrasil_contract.py) and passes yggdrasil's own ChimeraCatalogTests.
#
# The pipeline sets HEAD_REF, BASE_REF and YGGDRASIL_DIR, its yggdrasil checkout. The workflow checked out
# yggdrasil's main from GitHub; the catalog read here is the one this pipeline runs with.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

base=${BASE_REF:?ci/branch-policy.sh: BASE_REF is not set}
head=${HEAD_REF:?ci/branch-policy.sh: HEAD_REF is not set}
if [ "$base" != main ]; then
  echo "ci/branch-policy.sh: nothing more to check for '$head' -> '$base'."
  exit 0
fi
yggdrasil=${YGGDRASIL_DIR:?ci/branch-policy.sh: YGGDRASIL_DIR is not set}
version=${head#release/}

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh
# shellcheck source=ci/pyyaml.sh
source ci/pyyaml.sh
ensure_pyyaml

dart tool/validate_release_readiness.dart --version "$version"

export PYTHONDONTWRITEBYTECODE=1
python3 "$yggdrasil/scripts/catalog.py" validate
python3 tool/validate_yggdrasil_contract.py "$yggdrasil/catalog.yaml"
# Keep ensure_pyyaml's PYTHONPATH (a fetched PyYAML) after yggdrasil's scripts.
PYTHONPATH="$yggdrasil/scripts${PYTHONPATH:+:$PYTHONPATH}" python3 -m unittest test_catalog.ChimeraCatalogTests -v

echo "'$head' -> '$base' is ready to release $version."

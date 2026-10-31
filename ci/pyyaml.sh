# shellcheck shell=bash
# Sourced by the scripts under ci/ that run Python with PyYAML (not run on its own): ensure_pyyaml makes
# `import yaml` work.
#
# tool/validate_yggdrasil_contract.py reads yggdrasil's catalog with PyYAML, and so do yggdrasil's own
# scripts the branch policy runs; test/foundation/yggdrasil_contract_test.dart runs the validator. The GitHub
# runner had PyYAML, and the branch policy pip-installed pyyaml==6.0.3; the Flutter image has python3 but
# neither PyYAML nor pip. So the same release's source archive is fetched, checked against its PyPI sha256,
# and its pure-Python package put on PYTHONPATH (PyYAML runs without its C extension). A PyYAML that is
# already importable is used.
#
# Renovate follows the version (the comment above it), not the checksum: when it moves the version, copy the
# sdist's sha256 from https://pypi.org/project/PyYAML/#files by hand.
# renovate: datasource=pypi depName=PyYAML
PYYAML_VERSION=6.0.3
PYYAML_SHA256=d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f

ensure_pyyaml() {
  if python3 -c 'import yaml' >/dev/null 2>&1; then
    return 0
  fi

  local directory archive home
  directory=$(mktemp -d)
  archive="$directory/pyyaml.tar.gz"
  echo "ci/pyyaml.sh: no PyYAML; fetching PyYAML $PYYAML_VERSION"
  curl --fail --silent --show-error --location --retry 3 -o "$archive" \
    "https://files.pythonhosted.org/packages/source/p/pyyaml/pyyaml-${PYYAML_VERSION}.tar.gz" \
    || { rm -rf "$directory"; return 1; }
  if ! echo "$PYYAML_SHA256  $archive" | sha256sum --check --strict --status; then
    echo "ci/pyyaml.sh: the PyYAML archive does not match its pinned checksum" >&2
    rm -rf "$directory"
    return 1
  fi
  home=$(mktemp -d)
  tar -xzf "$archive" -C "$directory" --no-same-owner
  mv "$directory/pyyaml-${PYYAML_VERSION}/lib/yaml" "$home/yaml"
  rm -rf "$directory"
  export PYTHONPATH="$home${PYTHONPATH:+:$PYTHONPATH}"
  python3 -c 'import yaml; print("PyYAML", yaml.__version__)'
}

# shellcheck shell=bash
# Sourced by the scripts under ci/ that run the whole Dart test suite (not run on its own): ensure_node makes
# sure `node` is on the PATH.
#
# packages/chimera_core/test/lorem_web_boundary_test.dart runs compiled JavaScript with node. The GitHub runner
# had Node already; the .NET SDK image has none, and a check may run as a user that cannot install packages, so
# Node is fetched from nodejs.org, pinned by version and by checksum (its SHASUMS256.txt), and unpacked into a
# directory of its own. It is Node 24, the major the workflows used (setup-node 24) and the Playwright image has.
# A node that is already there is used.
#
# Renovate follows the version (the comment above it), not the checksums: when it moves the version, copy the two
# linux-*.tar.gz lines of https://nodejs.org/dist/v<version>/SHASUMS256.txt into this file by hand.
# renovate: datasource=node-version depName=node
NODE_VERSION=24.22.1

ensure_node() {
  if command -v node >/dev/null 2>&1; then
    return 0
  fi

  local arch sha256 directory archive home
  case $(uname -m) in
    x86_64)
      arch=x64
      sha256=eb6728e77c576a35162c122c45ccadf224d89ff00abc8dae46cc2897c6002d7c ;;
    aarch64)
      arch=arm64
      sha256=33c37be234ba8bee041961047b19160f4d7d0f164e8e246f78bdd10feff148b3 ;;
    *)
      echo "ci/node.sh: no node on the PATH, and no pinned build for $(uname -m)" >&2
      return 1 ;;
  esac

  directory=$(mktemp -d)
  archive="$directory/node.tar.gz"
  echo "ci/node.sh: no node on the PATH; fetching Node $NODE_VERSION"
  curl --fail --silent --show-error --location --retry 3 -o "$archive" \
    "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${arch}.tar.gz" \
    || { rm -rf "$directory"; return 1; }
  if ! echo "$sha256  $archive" | sha256sum --check --strict --status; then
    echo "ci/node.sh: the Node archive does not match its pinned checksum" >&2
    rm -rf "$directory"
    return 1
  fi
  home=$(mktemp -d)
  tar -xzf "$archive" -C "$home" --strip-components=1 --no-same-owner
  rm -rf "$directory"
  export PATH="$home/bin:$PATH"
  node --version
}

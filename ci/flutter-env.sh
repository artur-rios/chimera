# shellcheck shell=bash
# Puts the pinned Flutter SDK on PATH. Sourced by the other scripts under ci/, not run.
#
# The workflows pinned Flutter 3.47.7 (subosito/flutter-action). No published Flutter image has that
# version (ghcr.io/cirruslabs/flutter stops at 3.44.0, whose Dart 3.12 is older than pubspec.yaml's
# `sdk: ^3.13.0`), so the images in yggdrasil.yml only supply the tools around it, and the SDK itself is
# fetched here from Flutter's release archive and checked against its checksum, as deploy/web/Dockerfile
# does. FLUTTER_SHA256 comes from
# https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json; change it together with
# FLUTTER_VERSION (Renovate bumps the version, not the checksum), and the same two lines in the Dockerfile.
#
# FLUTTER_SDK_DIR reuses an unpacked SDK between runs (default: a directory under $TMPDIR).

# renovate: datasource=github-tags depName=flutter/flutter versioning=regex:^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$
FLUTTER_VERSION=3.47.7
FLUTTER_SHA256=af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230

FLUTTER_SDK_DIR=${FLUTTER_SDK_DIR:-${TMPDIR:-/tmp}/flutter-$FLUTTER_VERSION}

if [ ! -x "$FLUTTER_SDK_DIR/bin/flutter" ]; then
  _flutter_work=$(mktemp -d)
  echo "ci/flutter-env.sh: fetching Flutter $FLUTTER_VERSION"
  curl --fail --silent --show-error --location --retry 3 -o "$_flutter_work/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  echo "$FLUTTER_SHA256  $_flutter_work/flutter.tar.xz" | sha256sum --check --strict -
  # Without ownership: as root, tar would keep the archive's owner, and git then refuses the SDK's own
  # checkout as "dubious ownership". The Playwright and .NET SDK images have no xz, so there Python's
  # tarfile unpacks it (its "data" filter drops the owner too); the .NET checks source ci/python.sh first.
  if command -v xz >/dev/null 2>&1; then
    tar -xJf "$_flutter_work/flutter.tar.xz" --no-same-owner -C "$_flutter_work"
  else
    python3 -c 'import sys, tarfile; tarfile.open(sys.argv[1], "r:xz").extractall(sys.argv[2], filter="data")' \
      "$_flutter_work/flutter.tar.xz" "$_flutter_work"
  fi
  mkdir -p "$(dirname "$FLUTTER_SDK_DIR")"
  rm -rf "$FLUTTER_SDK_DIR"
  mv "$_flutter_work/flutter" "$FLUTTER_SDK_DIR"
  rm -rf "$_flutter_work"
  unset _flutter_work
fi

export FLUTTER_ROOT=$FLUTTER_SDK_DIR
export PATH="$FLUTTER_SDK_DIR/bin:$FLUTTER_SDK_DIR/bin/cache/dart-sdk/bin:$PATH"
# What GitHub Actions set: the Playwright config reads it (retries, forbidOnly), and Flutter's tools stay quiet.
export CI=true

flutter config --no-analytics --no-cli-animations >/dev/null
dart --disable-analytics >/dev/null
flutter --version

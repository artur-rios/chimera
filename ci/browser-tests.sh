#!/usr/bin/env bash
# The browser-tests check (GitHub: ci.yml's "Browser (chromium|firefox|webkit)", one job per browser): the
# release web build, served by the Playwright config's own web server, in Chromium, Firefox and WebKit.
#
# The image is Playwright's own, at the version tests/web/package-lock.json pins (@playwright/test), so the
# three browsers and their system libraries are already there: the workflow installed them with
# `npx playwright install --with-deps`, which needs root. The install below only fetches a browser when the
# image's do not match the harness (renovate.json moves the two together). Node is the image's (the
# workflow used Node 24).
#
# Every browser runs even when one fails, as the workflow's fail-fast: false matrix did; the check fails if
# any of them did. One Playwright run holds the three projects: its workers take tests of every browser, so
# one browser's last slow tests no longer leave the others' workers idle, and the web server starts once.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
(cd apps/chimera_gui && flutter build web --release --no-web-resources-cdn)

cd tests/web
npm ci
browsers=(chromium firefox webkit)
npx playwright install "${browsers[@]}"
npx playwright test "${browsers[@]/#/--project=}"

#!/bin/sh
# The container check (GitHub: ci.yml's "Container"): the web image builds and answers its exact health
# contract, through tool/smoke_container.sh.
#
# yggdrasil.yml runs it in the pinned docker CLI image (Alpine: no bash, hence sh) with the CI engine's
# socket (`docker: true`). The container is asked from inside itself (the `-` port, see
# tool/smoke_container.sh), and the image and the container are named after this check's container
# (its hostname), so two builds on one engine do not meet. The image is removed afterwards.
set -eu
cd "$(dirname "$0")/.."

name="chimera-ci-$(hostname)"
trap 'docker image rm --force "chimera-ci:$(hostname)" >/dev/null 2>&1 || true' EXIT
sh tool/smoke_container.sh "chimera-ci:$(hostname)" "$name" -

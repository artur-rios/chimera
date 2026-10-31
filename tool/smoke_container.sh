#!/usr/bin/env sh
# Builds the web image and checks that it answers its health contract.
#
#     sh tool/smoke_container.sh [image] [container-name] [host-port]
#
# With a host port (default 18080) the container is published on 127.0.0.1 and asked from here. With `-`
# it is not published and is asked from inside itself (docker exec): that is how CI runs it
# (ci/container.sh), from a container that talks to the engine through its socket, where the engine's
# 127.0.0.1 is not this container's and a fixed port could collide with another build.
set -eu

image="${1:-chimera-smoke:local}"
container_name="${2:-chimera-smoke}"
host_port="${3:-18080}"
health_uri="http://127.0.0.1:${host_port}/healthz"
if [ "${host_port}" = - ]; then
  health_uri="http://127.0.0.1:8080/healthz"
fi

# shellcheck disable=SC2329 # run by the trap below
cleanup() {
  docker rm --force "${container_name}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker build \
  --file deploy/web/Dockerfile \
  --tag "${image}" \
  --build-arg YGG_ENVIRONMENT=local \
  .
if [ "${host_port}" = - ]; then
  docker run --detach --rm --name "${container_name}" "${image}" >/dev/null
else
  docker run \
    --detach \
    --rm \
    --name "${container_name}" \
    --publish "127.0.0.1:${host_port}:8080" \
    "${image}" >/dev/null
fi

health() {
  if [ "${host_port}" = - ]; then
    # The runtime image's own HEALTHCHECK asks the same way.
    docker exec "${container_name}" wget -qO- "${health_uri}" 2>/dev/null
  else
    curl --fail --silent --show-error "${health_uri}" 2>/dev/null
  fi
}

attempt=0
while [ "${attempt}" -lt 60 ]; do
  response="$(health || true)"
  if [ "${response}" = '{"status":"ok"}' ]; then
    printf '%s\n' 'Container smoke: OK'
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 1
done

printf '%s\n' "Container did not return the exact health contract at ${health_uri}." >&2
exit 1

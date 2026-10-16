#!/usr/bin/env sh
set -eu

image="${1:-chimera-smoke:local}"
container_name="${2:-chimera-smoke}"
host_port="${3:-18080}"
health_uri="http://127.0.0.1:${host_port}/healthz"

cleanup() {
  docker rm --force "${container_name}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker build \
  --file deploy/web/Dockerfile \
  --tag "${image}" \
  --build-arg YGG_ENVIRONMENT=local \
  .
docker run \
  --detach \
  --rm \
  --name "${container_name}" \
  --publish "127.0.0.1:${host_port}:8080" \
  "${image}" >/dev/null

attempt=0
while [ "${attempt}" -lt 60 ]; do
  response="$(curl --fail --silent --show-error "${health_uri}" 2>/dev/null || true)"
  if [ "${response}" = '{"status":"ok"}' ]; then
    printf '%s\n' 'Container smoke: OK'
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 1
done

printf '%s\n' "Container did not return the exact health contract at ${health_uri}." >&2
exit 1

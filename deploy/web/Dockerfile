FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.47.7
ARG FLUTTER_SHA256=af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl git xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN curl --fail --location --silent --show-error \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      --output /tmp/flutter.tar.xz \
    && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum --check --strict \
    && tar --extract --xz --file /tmp/flutter.tar.xz --directory /opt \
    && rm /tmp/flutter.tar.xz

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /workspace
COPY . .
RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics \
    && flutter pub get

ARG CHIMERA_BASE_PATH=/
ARG CHIMERA_RELEASE_REPOSITORY=artur-rios/chimera
ARG CHIMERA_UPDATE_CHANNEL=stable

WORKDIR /workspace/apps/chimera_gui
RUN flutter build web \
      --release \
      --no-web-resources-cdn \
      --base-href="${CHIMERA_BASE_PATH}" \
      --dart-define="CHIMERA_RELEASE_REPOSITORY=${CHIMERA_RELEASE_REPOSITORY}" \
      --dart-define="CHIMERA_UPDATE_CHANNEL=${CHIMERA_UPDATE_CHANNEL}"

FROM nginxinc/nginx-unprivileged:1.30.6-alpine AS runtime

ARG YGG_ENVIRONMENT=local
LABEL io.chimera.environment=$YGG_ENVIRONMENT

COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/apps/chimera_gui/build/web /usr/share/nginx/html

USER 101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD test "$(wget -qO- http://127.0.0.1:8080/healthz)" = '{"status":"ok"}' || exit 1

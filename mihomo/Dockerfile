ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.22
FROM ${BUILD_FROM}

ARG BUILD_ARCH=amd64
ARG YQ_VERSION=v4.54.3

# The HA base image already ships bash, jq, curl and tar.
# yq (mikefarah) applies the add-on overrides to the mihomo config.
RUN case "${BUILD_ARCH}" in \
        aarch64) YQ_ARCH=arm64 ;; \
        amd64)   YQ_ARCH=amd64 ;; \
        armhf|armv7) YQ_ARCH=arm ;; \
        i386)    YQ_ARCH=386 ;; \
        *) echo "Unsupported arch ${BUILD_ARCH}"; exit 1 ;; \
    esac \
    && curl -fsSL -o /usr/local/bin/yq \
       "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}" \
    && chmod +x /usr/local/bin/yq \
    && yq --version

# Web UI: metacubexd, version pinned in metacubexd.version (bumped by GitHub Actions)
COPY metacubexd.version /app/metacubexd.version
RUN mkdir -p /app/ui \
    && curl -fsSL "https://github.com/MetaCubeX/metacubexd/releases/download/$(tr -d '[:space:]' < /app/metacubexd.version)/compressed-dist.tgz" \
       | tar xz -C /app/ui \
    && test -f /app/ui/index.html

# Architecture-specific mihomo binary (static, built by GitHub Actions)
COPY mihomo-${BUILD_ARCH} /app/mihomo
COPY start-mihomo.sh /app/start-mihomo.sh
COPY mihomo-default.yaml /app/mihomo-default.yaml

RUN chmod +x /app/mihomo /app/start-mihomo.sh

CMD ["/app/start-mihomo.sh"]

ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.22
FROM ${BUILD_FROM}

ARG BUILD_ARCH=amd64
ARG YQ_VERSION=v4.54.3
# Optional override of the Yacd-meta archive URL (default: GitHub, pinned in yacd.version)
ARG YACD_URL=""

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

# Web UI: Yacd-meta (talks to both mihomo and sing-box Clash API).
# Pinned to a commit of its built gh-pages branch (bumped by GitHub Actions).
COPY yacd.version /app/yacd.version
RUN YACD_SHA="$(tr -d '[:space:]' < /app/yacd.version)" \
    && mkdir -p /app/ui \
    && curl -fsSL "${YACD_URL:-https://github.com/MetaCubeX/Yacd-meta/archive/${YACD_SHA}.tar.gz}" \
       | tar xz -C /app/ui --strip-components=1 \
    && test -f /app/ui/index.html

# sing-box: official static musl release (pinned in sing-box.version, bumped by GitHub Actions).
# No musl build exists for armv6 (armhf): there only mihomo is available.
COPY sing-box.version /app/sing-box.version
RUN SB_VERSION="$(tr -d '[:space:]' < /app/sing-box.version)" \
    && case "${BUILD_ARCH}" in \
        aarch64) SB_ARCH=arm64 ;; \
        amd64)   SB_ARCH=amd64 ;; \
        armv7)   SB_ARCH=armv7 ;; \
        i386)    SB_ARCH=386 ;; \
        *)       SB_ARCH="" ;; \
    esac \
    && if [ -n "${SB_ARCH}" ]; then \
        mkdir -p /tmp/sb \
        && curl -fsSL "https://github.com/SagerNet/sing-box/releases/download/${SB_VERSION}/sing-box-${SB_VERSION#v}-linux-${SB_ARCH}-musl.tar.gz" \
           | tar xz -C /tmp/sb --strip-components=1 \
        && install -m 755 /tmp/sb/sing-box /app/sing-box \
        && rm -rf /tmp/sb \
        && /app/sing-box version; \
    else echo "sing-box: no build for ${BUILD_ARCH}, skipping"; fi

# Architecture-specific mihomo binary (static, built by GitHub Actions)
COPY mihomo-${BUILD_ARCH} /app/mihomo
COPY run.sh /app/run.sh
COPY mihomo-default.yaml sing-box-default.json /app/

RUN chmod +x /app/mihomo /app/run.sh

CMD ["/app/run.sh"]

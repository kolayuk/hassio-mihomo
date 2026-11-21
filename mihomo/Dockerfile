FROM alpine:3.22

# Required packages (yq is used to apply add-on overrides to the mihomo config)
RUN apk add --no-cache ca-certificates bash jq curl tar libc6-compat gcompat \
    && (apk add --no-cache yq-go || apk add --no-cache yq) \
    && yq --version

# Web UI: metacubexd, version pinned in metacubexd.version (bumped by GitHub Actions)
COPY metacubexd.version /app/metacubexd.version
RUN mkdir -p /app/ui \
    && curl -fsSL "https://github.com/MetaCubeX/metacubexd/releases/download/$(cat /app/metacubexd.version | tr -d '[:space:]')/compressed-dist.tgz" \
       | tar xz -C /app/ui

# Architecture-specific mihomo binary (built by GitHub Actions)
ARG BUILD_ARCH
COPY mihomo-${BUILD_ARCH} /app/mihomo
COPY start-mihomo.sh /app/start-mihomo.sh
COPY mihomo-default.yaml /app/mihomo-default.yaml

RUN chmod +x /app/mihomo /app/start-mihomo.sh

CMD ["/app/start-mihomo.sh"]

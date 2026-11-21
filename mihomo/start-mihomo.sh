#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"
HOME_DIR="/data/mihomo"
RUNTIME_CONFIG="${HOME_DIR}/runtime-config.yaml"
DEFAULT_CONFIG="/app/mihomo-default.yaml"
API_PORT=9090

opt() {
    # opt <jq-path> <default>
    local v
    v=$(jq -r "${1} // empty" "${OPTIONS_FILE}" 2>/dev/null || true)
    if [ -z "${v}" ]; then echo "${2}"; else echo "${v}"; fi
}

CONFIG_FILE=$(opt '.config_file' '/homeassistant/mihomo.yaml')
TUN_ENABLED=$(opt '.tun' 'true')
TUN_STACK=$(opt '.tun_stack' 'mixed')
API_SECRET=$(opt '.api_secret' '')
EXCLUDES_JSON=$(jq -c '.tun_route_exclude_address // []' "${OPTIONS_FILE}" 2>/dev/null || echo '[]')

mkdir -p "${HOME_DIR}"

# ---------------------------------------------------------------------------
# Config file: create it from the bundled template on first start
# ---------------------------------------------------------------------------
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "[mihomo] Config ${CONFIG_FILE} not found, creating it from the default template"
    mkdir -p "$(dirname "${CONFIG_FILE}")"
    cp "${DEFAULT_CONFIG}" "${CONFIG_FILE}"
fi
echo "[mihomo] Using config: ${CONFIG_FILE}"

# ---------------------------------------------------------------------------
# Web UI (metacubexd): refresh the copy inside the mihomo home dir on every
# start, so image updates are picked up. Point it at the same origin it is
# served from (mihomo's external-controller).
# ---------------------------------------------------------------------------
rm -rf "${HOME_DIR}/ui"
cp -r /app/ui "${HOME_DIR}/ui"
cat > "${HOME_DIR}/ui/config.js" <<'EOF'
window.__METACUBEXD_CONFIG__ = {
  defaultBackendURL: window.location.origin,
  githubToken: '',
}
EOF

# ---------------------------------------------------------------------------
# Build runtime config = user config + add-on overrides
# ---------------------------------------------------------------------------
cp "${CONFIG_FILE}" "${RUNTIME_CONFIG}"

# Always expose the controller + bundled UI so the "Open Web UI" button works
yq -i "
  .\"external-controller\" = \"0.0.0.0:${API_PORT}\" |
  .\"external-ui\" = \"ui\"
" "${RUNTIME_CONFIG}"

if [ -n "${API_SECRET}" ]; then
    SECRET="${API_SECRET}" yq -i '.secret = strenv(SECRET)' "${RUNTIME_CONFIG}"
fi

if [ "${TUN_ENABLED}" = "true" ]; then
    echo "[mihomo] TUN mode enabled (stack: ${TUN_STACK}) - routing all host traffic"
    STACK="${TUN_STACK}" yq -i '
      .tun.enable = true |
      .tun.stack = strenv(STACK) |
      .tun."auto-route" = true |
      with(.tun | select(."auto-redirect" == null); ."auto-redirect" = true) |
      .tun."auto-detect-interface" = true |
      .tun."strict-route" = (.tun."strict-route" // false) |
      .tun."dns-hijack" = (.tun."dns-hijack" // ["any:53", "tcp://any:53"])
    ' "${RUNTIME_CONFIG}"

    if [ "$(echo "${EXCLUDES_JSON}" | jq 'length')" -gt 0 ]; then
        echo "[mihomo] Excluding from TUN: $(echo "${EXCLUDES_JSON}" | jq -r 'join(", ")')"
        EXCL="${EXCLUDES_JSON}" yq -i '.tun."route-exclude-address" = env(EXCL)' "${RUNTIME_CONFIG}"
    else
        echo "[mihomo] tun_route_exclude_address is empty - using route-exclude-address from ${CONFIG_FILE}"
    fi

    # TUN needs mihomo's DNS to answer hijacked queries
    if [ "$(yq '.dns.enable // false' "${RUNTIME_CONFIG}")" != "true" ]; then
        echo "[mihomo] WARNING: dns.enable is not true in your config; hijacked DNS queries will fail"
    fi
else
    echo "[mihomo] TUN mode disabled by add-on option; using tun section from config as-is"
fi

if [ ! -c /dev/net/tun ] && [ "${TUN_ENABLED}" = "true" ]; then
    echo "[mihomo] WARNING: /dev/net/tun is not available"
fi

echo "[mihomo] Web UI: http://<host>:${API_PORT}/ui/"
echo "[mihomo] Testing configuration..."
/app/mihomo -d "${HOME_DIR}" -f "${RUNTIME_CONFIG}" -t

exec /app/mihomo -d "${HOME_DIR}" -f "${RUNTIME_CONFIG}"

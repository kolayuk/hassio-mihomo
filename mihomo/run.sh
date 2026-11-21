#!/usr/bin/env bash
# Add-on entrypoint: runs mihomo or sing-box (option "engine") with the add-on
# overrides applied (TUN, LAN exclusions, API/Web UI on :9090 with Yacd).
set -euo pipefail

OPTIONS_FILE="/data/options.json"
API_PORT=9090

opt() {
    # opt <jq-path> <default>  ("false" is a value, only null/missing -> default)
    local v
    v=$(jq -r "${1} | if . == null then empty else tostring end" "${OPTIONS_FILE}" 2>/dev/null || true)
    if [ -z "${v}" ]; then echo "${2}"; else echo "${v}"; fi
}

ENGINE=$(opt '.engine' 'mihomo')
TUN_ENABLED=$(opt '.tun' 'true')
TUN_STACK=$(opt '.tun_stack' 'mixed')
API_SECRET=$(opt '.api_secret' '')
EXCLUDES_JSON=$(jq -c '.tun_route_exclude_address // []' "${OPTIONS_FILE}" 2>/dev/null || echo '[]')
EXCLUDES_COUNT=$(echo "${EXCLUDES_JSON}" | jq 'length')

log() { echo "[${ENGINE}] $*"; }

case "${ENGINE}" in
    mihomo)
        CONFIG_FILE=$(opt '.config_file' '/homeassistant/mihomo.yaml')
        DEFAULT_CONFIG="/app/mihomo-default.yaml"
        HOME_DIR="/data/mihomo"
        RUNTIME_CONFIG="${HOME_DIR}/runtime-config.yaml"
        BIN="/app/mihomo"
        VERSION_CMD=(-v)
        ;;
    sing-box)
        CONFIG_FILE=$(opt '.singbox_config_file' '/homeassistant/sing-box.json')
        DEFAULT_CONFIG="/app/sing-box-default.json"
        HOME_DIR="/data/sing-box"
        RUNTIME_CONFIG="${HOME_DIR}/runtime-config.json"
        BIN="/app/sing-box"
        VERSION_CMD=(version)
        ;;
    *)
        echo "Unknown engine '${ENGINE}'"; exit 1 ;;
esac

if [ ! -x "${BIN}" ]; then
    log "ERROR: ${ENGINE} is not available for this architecture"
    exit 1
fi

mkdir -p "${HOME_DIR}"
log "Engine: $("${BIN}" "${VERSION_CMD[@]}" | head -1)"

# ---------------------------------------------------------------------------
# Config file: create it from the bundled template on first start
# ---------------------------------------------------------------------------
if [ ! -f "${CONFIG_FILE}" ]; then
    log "Config ${CONFIG_FILE} not found, creating it from the default template"
    mkdir -p "$(dirname "${CONFIG_FILE}")"
    cp "${DEFAULT_CONFIG}" "${CONFIG_FILE}"
fi
log "Using config: ${CONFIG_FILE}"

# ---------------------------------------------------------------------------
# Web UI (Yacd-meta, works with both engines' Clash API). Refresh the copy on
# every start so image updates are picked up, and point it at the origin it is
# served from instead of the built-in http://127.0.0.1:9090.
# ---------------------------------------------------------------------------
rm -rf "${HOME_DIR}/ui"
cp -r /app/ui "${HOME_DIR}/ui"
sed -i 's#<div id="app" data-base-url="[^"]*"></div>#<div id="app" data-base-url="http://127.0.0.1:9090"></div><script>document.getElementById("app").setAttribute("data-base-url", window.location.origin)</script>#' \
    "${HOME_DIR}/ui/index.html"

if [ "${TUN_ENABLED}" = "true" ] && [ ! -c /dev/net/tun ]; then
    log "WARNING: /dev/net/tun is not available"
fi

# ---------------------------------------------------------------------------
# mihomo: runtime config = user YAML + overrides (yq)
# ---------------------------------------------------------------------------
run_mihomo() {
    cp "${CONFIG_FILE}" "${RUNTIME_CONFIG}"

    yq -i "
      .\"external-controller\" = \"0.0.0.0:${API_PORT}\" |
      .\"external-ui\" = \"ui\"
    " "${RUNTIME_CONFIG}"

    if [ -n "${API_SECRET}" ]; then
        SECRET="${API_SECRET}" yq -i '.secret = strenv(SECRET)' "${RUNTIME_CONFIG}"
    fi

    if [ "${TUN_ENABLED}" = "true" ]; then
        log "TUN mode enabled (stack: ${TUN_STACK}) - routing all host traffic"
        STACK="${TUN_STACK}" yq -i '
          .tun.enable = true |
          .tun.stack = strenv(STACK) |
          .tun."auto-route" = true |
          with(.tun | select(."auto-redirect" == null); ."auto-redirect" = true) |
          .tun."auto-detect-interface" = true |
          .tun."strict-route" = (.tun."strict-route" // false) |
          .tun."dns-hijack" = (.tun."dns-hijack" // ["any:53", "tcp://any:53"])
        ' "${RUNTIME_CONFIG}"

        if [ "${EXCLUDES_COUNT}" -gt 0 ]; then
            log "Excluding from TUN: $(echo "${EXCLUDES_JSON}" | jq -r 'join(", ")')"
            EXCL="${EXCLUDES_JSON}" yq -i '.tun."route-exclude-address" = env(EXCL)' "${RUNTIME_CONFIG}"
        else
            log "tun_route_exclude_address is empty - using route-exclude-address from ${CONFIG_FILE}"
        fi

        if [ "$(yq '.dns.enable // false' "${RUNTIME_CONFIG}")" != "true" ]; then
            log "WARNING: dns.enable is not true in your config; hijacked DNS queries will fail"
        fi
    else
        log "TUN mode disabled by add-on option; using tun section from config as-is"
    fi

    log "Web UI: http://<host>:${API_PORT}/ui/"
    log "Testing configuration..."
    "${BIN}" -d "${HOME_DIR}" -f "${RUNTIME_CONFIG}" -t
    exec "${BIN}" -d "${HOME_DIR}" -f "${RUNTIME_CONFIG}"
}

# ---------------------------------------------------------------------------
# sing-box: runtime config = user JSON + overrides (jq)
# ---------------------------------------------------------------------------
run_singbox() {
    jq --arg ctl "0.0.0.0:${API_PORT}" --arg secret "${API_SECRET}" '
        (if .log.level == null then .log.level = "info" else . end)
      | .experimental.clash_api.external_controller = $ctl
      | .experimental.clash_api.external_ui = "ui"
      | (if $secret != "" then .experimental.clash_api.secret = $secret else . end)
    ' "${CONFIG_FILE}" > "${RUNTIME_CONFIG}"

    if [ "${TUN_ENABLED}" = "true" ]; then
        log "TUN mode enabled (stack: ${TUN_STACK}) - routing all host traffic"
        # auto_redirect is left to the config (off unless set): sing-box exits silently
        # on kernels where its nftables redirect is unsupported; auto_route alone
        # already sends all host traffic through the tunnel.
        if [ "$(jq '[.inbounds[]? | select(.type == "tun")] | length' "${RUNTIME_CONFIG}")" = "0" ]; then
            log "No tun inbound in config, adding one (tag tun-in)"
        fi
        if [ "${EXCLUDES_COUNT}" -gt 0 ]; then
            log "Excluding from TUN: $(echo "${EXCLUDES_JSON}" | jq -r 'join(", ")')"
        else
            log "tun_route_exclude_address is empty - using route_exclude_address from ${CONFIG_FILE}"
        fi
        jq --arg stack "${TUN_STACK}" --argjson excl "${EXCLUDES_JSON}" '
            .inbounds = ((.inbounds // [])
              | if any(.[]; .type == "tun") then .
                else . + [{"type": "tun", "tag": "tun-in", "address": ["172.19.0.1/30"]}] end
              | map(if .type == "tun" then
                      .stack = $stack
                    | .auto_route = true
                    | (if .strict_route == null then .strict_route = false else . end)
                    | (if ($excl | length) > 0 then .route_exclude_address = $excl else . end)
                  else . end))
          | .route.auto_detect_interface = true
          | .route.rules = (.route.rules // [])
          | (if any(.route.rules[]; .action == "hijack-dns") then .
             else .route.rules = [{"protocol": "dns", "action": "hijack-dns"}] + .route.rules end)
          | (if any(.route.rules[]; .action == "sniff") then .
             else .route.rules = [{"action": "sniff"}] + .route.rules end)
        ' "${RUNTIME_CONFIG}" > "${RUNTIME_CONFIG}.tmp" && mv "${RUNTIME_CONFIG}.tmp" "${RUNTIME_CONFIG}"
    else
        log "TUN mode disabled by add-on option; using inbounds from config as-is"
    fi

    log "Web UI: http://<host>:${API_PORT}/ui/"
    log "Testing configuration..."
    "${BIN}" check -D "${HOME_DIR}" -c "${RUNTIME_CONFIG}"
    log "configuration test is successful"
    exec "${BIN}" run -D "${HOME_DIR}" -c "${RUNTIME_CONFIG}"
}

if [ "${ENGINE}" = "mihomo" ]; then run_mihomo; else run_singbox; fi

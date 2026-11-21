# Home Assistant Add-on: Mihomo

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports armhf Architecture][armhf-shield]
![Supports i386 Architecture][i386-shield]

Mihomo (Clash.Meta) with TUN mode: a rule-based proxy that acts as a VPN for the
whole Home Assistant host, with the [metacubexd][metacubexd] web dashboard built in.

## Features

- **Whole-host VPN (TUN)**: the add-on runs with `NET_ADMIN`/`NET_RAW` and `/dev/net/tun`,
  so mihomo creates a TUN interface with `auto-route` + `auto-redirect`, and all host traffic goes through it
- **Local network excluded**: LAN ranges skip the tunnel. You can change the list in the add-on options
  or in your mihomo config
- **Web UI button**: "Open Web UI" in Home Assistant opens metacubexd, which mihomo itself serves on port 9090
- **Auto-updating**: GitHub Actions rebuilds mihomo (from the `Meta` branch) and pins the latest metacubexd
  release every day, then bumps the add-on version so Home Assistant offers the update

## Configuration

The mihomo config file is `/homeassistant/mihomo.yaml`, the `mihomo.yaml` file next to
`configuration.yaml`. If the file does not exist, it is created from the bundled template the
first time the add-on starts. Edit it (or replace it with your own config) and restart the add-on.

### Add-on options

| Option | Default | Description |
| ------ | ------- | ----------- |
| `config_file` | `/homeassistant/mihomo.yaml` | Path to the mihomo config |
| `tun` | `true` | Force TUN mode on (`tun.enable`, `auto-route`, `auto-detect-interface`, default `dns-hijack`). Set to `false` to use the `tun` section of your config unchanged |
| `tun_stack` | `mixed` | TUN stack: `mixed`, `system` or `gvisor` |
| `tun_route_exclude_address` | private/LAN ranges | CIDRs that bypass the tunnel (written to `tun.route-exclude-address`). **Leave the list empty to use `route-exclude-address` from your mihomo config instead** |
| `api_secret` | empty | If set, it replaces `secret` for the API/Web UI |

The add-on always sets `external-controller: 0.0.0.0:9090` and `external-ui` to the bundled
metacubexd, so the Web UI button always works. Your file is not modified. The merged
config is written to `/data/mihomo/runtime-config.yaml` inside the add-on.

### Minimal config example

```yaml
mixed-port: 7893
allow-lan: true
mode: rule
log-level: info

dns:
  enable: true            # required for TUN dns-hijack
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - https://1.1.1.1/dns-query

tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-redirect: true
  auto-detect-interface: true
  route-exclude-address:   # used when add-on option tun_route_exclude_address is empty
    - 192.168.0.0/16
    - 10.0.0.0/8
    - 172.16.0.0/12

proxies:
  - name: my-vless
    type: vless
    server: example.com
    port: 443
    uuid: 00000000-0000-0000-0000-000000000000
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: www.microsoft.com
    reality-opts:
      public-key: xxxxxxxx
      short-id: xxxx
    client-fingerprint: chrome

proxy-groups:
  - name: Proxy
    type: select
    proxies: [my-vless, DIRECT]

rules:
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - MATCH,Proxy
```

## Ports (host network)

| Port | Description |
| ---- | ----------- |
| 7890 / 7891 / 7893 | HTTP / SOCKS5 / mixed proxy (if enabled in config) |
| 9898 | TProxy (if enabled in config) |
| 9090 | REST API and Web UI (`/ui/`) |
| 1053 | DNS server in the default template |

## Web UI

Use **Open Web UI** on the add-on page, or go to `http://<home-assistant-ip>:9090/ui/`.
metacubexd connects to the same address automatically. If you set a secret, enter it once in the UI.

## Security

The add-on needs host networking, `NET_ADMIN`/`NET_RAW` and `/dev/net/tun` to act as a
host-wide VPN. Set `api_secret` if your LAN is not trusted.

[metacubexd]: https://github.com/MetaCubeX/metacubexd
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg

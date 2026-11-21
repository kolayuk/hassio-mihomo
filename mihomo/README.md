# Home Assistant Add-on: Mihomo / sing-box

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports armhf Architecture][armhf-shield]
![Supports i386 Architecture][i386-shield]

[Mihomo][mihomo] (Clash.Meta) **or** [sing-box][sing-box] with TUN mode: a rule-based proxy
that acts as a VPN for the whole Home Assistant host, with the [Yacd-meta][yacd] web dashboard
built in (it works with both engines).

## Features

- **Two engines**: pick `mihomo` (default) or `sing-box` with the `engine` option. Each has its
  own config file, so you can switch back and forth
- **Whole-host VPN (TUN)**: the add-on runs with `NET_ADMIN`/`NET_RAW` and `/dev/net/tun`,
  so the engine creates a TUN interface with auto-route + auto-redirect, and all host traffic goes through it
- **Local network excluded**: LAN ranges skip the tunnel. You can change the list in the add-on options
  or in your engine config
- **Web UI button**: "Open Web UI" in Home Assistant opens Yacd-meta, served by the engine itself on port 9090
- **Auto-updating**: GitHub Actions rebuilds mihomo (from the `Meta` branch) and pins the latest sing-box
  release and Yacd-meta build every day, then bumps the add-on version so Home Assistant offers the update

sing-box is not available on `armhf` (no static build exists for armv6); there only mihomo runs.

## Configuration

Config files live next to `configuration.yaml`:

| Engine | Config file | Format |
| ------ | ----------- | ------ |
| `mihomo` | `/homeassistant/mihomo.yaml` | [mihomo YAML](https://wiki.metacubex.one/en/config/) |
| `sing-box` | `/homeassistant/sing-box.json` | [sing-box JSON](https://sing-box.sagernet.org/configuration/) |

If the selected engine's file does not exist, it is created from the bundled template the
first time the add-on starts. Edit it (or replace it with your own config) and restart the add-on.

### Add-on options

| Option | Default | Description |
| ------ | ------- | ----------- |
| `engine` | `mihomo` | `mihomo` or `sing-box` |
| `config_file` | `/homeassistant/mihomo.yaml` | Path to the mihomo config |
| `singbox_config_file` | `/homeassistant/sing-box.json` | Path to the sing-box config |
| `tun` | `true` | Force TUN on. mihomo: `tun.enable`, `auto-route`, `auto-detect-interface`, default `dns-hijack`. sing-box: adds a `tun` inbound if there is none, sets `auto_route` (`auto_redirect` only if you set it in your config), `route.auto_detect_interface` and adds `sniff` + `hijack-dns` route rules if missing. Set to `false` to use your config unchanged (the generated templates have TUN off, so this turns TUN off unless you enable it there) |
| `tun_stack` | `mixed` | TUN stack: `mixed`, `system` or `gvisor` |
| `tun_route_exclude_address` | private/LAN ranges | CIDRs that bypass the tunnel (mihomo `tun.route-exclude-address`, sing-box tun inbound `route_exclude_address`). **Leave the list empty to use the list from your engine config instead** |
| `api_secret` | empty | If set, it replaces `secret` for the API/Web UI |

The add-on always serves the API and the bundled Yacd on `0.0.0.0:9090` (mihomo
`external-controller`/`external-ui`, sing-box `experimental.clash_api`), so the Web UI button
always works. Your file is not modified. The merged config is written to
`/data/<engine>/runtime-config.*` inside the add-on.

### Migrating from sing-box as a SOCKS5 proxy

Copy your existing sing-box config to `/homeassistant/sing-box.json`, set `engine: sing-box` and
start the add-on. Your `socks`/`mixed` inbounds keep working; with `tun: true` the add-on adds the
TUN inbound and DNS hijacking, so the whole host goes through your `route.final` outbound and LAN
ranges stay direct. Add a `dns` section with a server that uses your proxy as `detour` so
DNS is not resolved in the clear.

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

### DNS in TUN mode

With TUN on, **all DNS queries of the host are hijacked by mihomo** (`dns-hijack: any:53`), so
Home Assistant resolves names only through the `dns.nameserver` list of your config. If none of
those servers are reachable (e.g. DoH to `1.1.1.1` blocked or throttled), the whole host loses DNS.
Make sure your config has at least one reachable resolver, and ideally send DNS for blocked domains
through the proxy (`nameserver-policy` / `proxy-server-nameserver`, see the mihomo docs).

## Ports (host network)

| Port | Description |
| ---- | ----------- |
| 7890 / 7891 / 7893 | HTTP / SOCKS5 / mixed proxy (if enabled in config) |
| 9898 | TProxy (if enabled in config) |
| 9090 | REST API and Web UI (`/ui/`) |
| 1053 | DNS server in the default template |

## Web UI

Use **Open Web UI** on the add-on page, or go to `http://<home-assistant-ip>:9090/ui/`.
Yacd connects to the same address automatically. If you set a secret, enter it once in the UI.

## Security

The add-on needs host networking, `NET_ADMIN`/`NET_RAW` and `/dev/net/tun` to act as a
host-wide VPN. Set `api_secret` if your LAN is not trusted.

[mihomo]: https://github.com/MetaCubeX/mihomo
[sing-box]: https://github.com/SagerNet/sing-box
[yacd]: https://github.com/MetaCubeX/Yacd-meta
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg

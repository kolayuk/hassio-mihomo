# Home Assistant Add-on: Mihomo

[![GitHub Release][releases-shield]][releases]
[![License][license-shield]](LICENSE.md)
[![Build Status][build-shield]][build]
![Supports aarch64 Architecture][aarch64-shield]

[![Add to Home Assistant][addon-badge]][addon]

A Home Assistant add-on repository for running [Mihomo][mihomo] (formerly Clash.Meta) as a transparent proxy with advanced routing capabilities.

## Add-ons

This repository contains the following add-ons

### [Mihomo Proxy](./mihomo/)

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports armhf Architecture][armhf-shield]
![Supports i386 Architecture][i386-shield]

_Mihomo (Clash.Meta) - A rule-based transparent proxy with advanced routing capabilities._

## About

This add-on enables you to run Mihomo (formerly Clash.Meta) on your Home Assistant instance. Mihomo is a rule-based network proxy that supports transparent proxy, multiple protocols, and advanced routing features.

The add-on provides a complete proxy solution with automatic daily updates, ensuring you always have the latest features and security patches from the [Mihomo project][mihomo].

## Features

- 🚀 **Transparent Proxy (TProxy)** - Seamless traffic routing on port 9898
- 🔄 **Auto-updating** - Daily builds with the latest Mihomo binary via GitHub Actions
- ⚙️ **Flexible Configuration** - Support for custom configurations
- 🛡️ **Whole-host VPN (TUN)** - TUN mode on by default, local network excluded (configurable)
- 🔀 **Two engines** - mihomo (default) or sing-box, selectable in the add-on options
- 🖥️ **Yacd Web UI** - "Open Web UI" button in Home Assistant (port 9090, `/ui/`), works with both engines
- 🌐 **Multi-protocol Support** - SS, VMess, Trojan, VLESS, and more
- 🏠 **Home Assistant Integration** - Native add-on with full access to Home Assistant network
- 🦾 **ARM64 Support** - Optimized for Raspberry Pi 4 and similar devices

## Installation

### One-Click Install

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fkolayuk%2Fhassio-mihomo)

### Manual Installation

1. Navigate to your Home Assistant Supervisor panel
2. Click on "Add-on Store"
3. Click the three dots menu and select "Repositories"
4. Add this repository URL: `https://github.com/kolayuk/hassio-mihomo`
5. Find "Mihomo Proxy" in the add-on store and click Install

## Configuration

### Basic Setup

The add-on works out of the box with a default configuration. For custom setups:

1. Edit `/homeassistant/mihomo.yaml` (the `mihomo.yaml` next to `configuration.yaml`; created from the template on first start)
2. Add your proxy configuration (see [Configuration Template](#configuration-template))
3. Restart the add-on

### Configuration Template

```yaml
# Example configuration
mixed-port: 7893
allow-lan: true
mode: rule
log-level: info

dns:
  enable: true
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1

proxies:
  # Add your proxy servers here

proxy-groups:
  # Add your proxy groups here

rules:
  # Add your routing rules here
  - MATCH,DIRECT
```

For a complete configuration reference, see the [mihomo-default.yaml](mihomo/mihomo-default.yaml) template in this repository.

## Default Ports

| Service      | Port | Description                      |
| ------------ | ---- | -------------------------------- |
| HTTP Proxy   | 7890 | HTTP(S) proxy server             |
| SOCKS5 Proxy | 7891 | SOCKS5 proxy server              |
| Mixed Proxy  | 7893 | Combined HTTP(S) and SOCKS proxy |
| TProxy       | 9898 | Transparent proxy (Linux)        |
| DNS          | 53   | DNS server                       |
| API          | 9090 | RESTful API endpoint             |

## Web UI

Access the Mihomo dashboard by navigating to:

```txt
http://homeassistant.local:9090/ui/
```

Or click **Open Web UI** on the add-on page. The bundled [Yacd-meta](https://github.com/MetaCubeX/Yacd-meta) is served by the engine (mihomo or sing-box) and connects automatically.

## Advanced Features

### TUN Mode

TUN mode is enabled by default, so the add-on works as a VPN for the whole host. Add-on options:

- `tun` (default `true`) forces TUN on. Set it to `false` to use your config's `tun` section unchanged
  (the generated template has `tun.enable: false`, so this turns TUN off unless you enable it there)
- `tun_stack` can be `mixed` (default), `system` or `gvisor`
- `tun_route_exclude_address` lists the CIDRs that bypass the tunnel (LAN ranges by default).
  Leave it **empty** to use `tun.route-exclude-address` from your mihomo config

See [mihomo/README.md](mihomo/README.md) for details.

### Sniffer

Enable protocol sniffing for better traffic identification:

```yaml
sniffer:
  enable: true
  sniff:
    TLS:
      ports: [443, 8443]
    HTTP:
      ports: [80, 8080-8880]
```

## Troubleshooting

### Check Logs

```bash
# View add-on logs in Home Assistant
ha addons logs mihomo
```

### Common Issues

1. **Port conflicts**: Ensure no other services are using the configured ports
2. **DNS issues**: Try disabling the DNS server or changing the port
3. **Connection refused**: Check if `allow-lan` is set to `true`

## Links

- 📦 [Mihomo (Clash.Meta) Repository](https://github.com/MetaCubeX/mihomo/tree/Meta)
- 📚 [Mihomo Documentation](https://wiki.metacubex.one/)
- 🏠 [Home Assistant](https://www.home-assistant.io/)
- 🐛 [Report Issues](https://github.com/kolayuk/hassio-mihomo/issues)

## Changelog & Releases

This repository keeps a change log using [GitHub's releases][releases]
functionality.

Releases are based on [Semantic Versioning][semver], and use the format
of `MAJOR.MINOR.PATCH`. In a nutshell, the version will be incremented
based on the following:

- `MAJOR`: Incompatible or major changes
- `MINOR`: Backwards-compatible new features and enhancements
- `PATCH`: Backwards-compatible bugfixes and package updates

## Support

Got questions?

You have several options to get them answered:

- The [Home Assistant Discord server][discord-ha] for general Home Assistant discussions
- The Home Assistant [Community Forum][forum]
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]
- Check out certains FAQs on the [wiki][wiki]

You could also [open an issue here][issue] on GitHub.

## Contributing

This is an active open-source project. We are always open to people who want to
use the code or contribute to it.

We have set up a separate document containing our
[contribution guidelines][contributing].

Thank you for being involved! :heart_eyes:

## Authors & contributors

The original setup of this repository is by [Ka Pui Cheung][kapuic].

For a full list of all authors and contributors,
check [the contributor's page][contributors].

## License

MIT License

Copyright © 2025 Ka Pui Cheung

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[addon-badge]: https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg
[addon]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fkolayuk%2Fhassio-mihomo
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[build-shield]: https://github.com/kolayuk/hassio-mihomo/actions/workflows/ci.yml/badge.svg
[build]: https://github.com/kolayuk/hassio-mihomo/actions/workflows/ci.yml
[contributing]: https://github.com/kolayuk/hassio-mihomo/blob/main/.github/CONTRIBUTING.md
[contributors]: https://github.com/kolayuk/hassio-mihomo/graphs/contributors
[discord-ha]: https://discord.gg/c5DvZ4e
[forum]: https://community.home-assistant.io/
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
[issue]: https://github.com/kolayuk/hassio-mihomo/issues
[kapuic]: https://github.com/kapuic
[license-shield]: https://img.shields.io/github/license/kolayuk/hassio-mihomo.svg
[mihomo]: https://github.com/MetaCubeX/mihomo/tree/Meta
[reddit]: https://reddit.com/r/homeassistant
[releases-shield]: https://img.shields.io/github/v/release/kolayuk/hassio-mihomo.svg
[releases]: https://github.com/kolayuk/hassio-mihomo/releases
[semver]: http://semver.org/spec/v2.0.0.html
[wiki]: https://github.com/kolayuk/hassio-mihomo/wiki

# MOS WiFi Drivers

A **MOS plugin** that installs WLAN drivers and kernel modules for the [MOS](https://mos-official.net) NAS operating system (Devuan-based).

---

## Overview

WiFi support on MOS requires three layers to be in place:

| Layer | What it is | Provided by |
|---|---|---|
| Kernel symbols | Built-in support for `cfg80211`, `mac80211` | MOS kernel (ich777 / Mainfrezzer) |
| Kernel modules | Compiled `.ko` driver files per chip | `mos-wifi-modules` package |
| Firmware | Vendor binary blobs | `wireless-regdb`, `firmware-*` via apt |

This plugin handles layers 2 and 3 automatically. Layer 1 must be provided by a compatible MOS kernel (≥ 6.18.x).

---

## How It Works

When the plugin installs or MOS starts, `mos-wifi-driver-install.sh` runs automatically and:

1. Installs base packages via `apt` (`wireless-regdb`, `iw`, `wpasupplicant`)
2. Checks if a WiFi module package is already present
3. If not, downloads the kernel-specific `mos-wifi-modules` `.deb` from GitHub Releases ([Mainfrezzer/mos-kernel](https://github.com/Mainfrezzer/mos-kernel), with fallback to [ich777/mos-kernel](https://github.com/ich777/mos-kernel))
4. Installs the package via `dpkg` and runs `depmod`
5. Loads available modules via `modprobe`

A local `.deb` path can also be provided manually via the plugin UI.

---

## Supported Drivers

| Chipset family | Modules |
|---|---|
| Intel (AX200, AX210, …) | `iwlwifi` |
| Realtek (RTL8821CU, RTL8822BU, …) | `rtl8xxxu`, `rtw88_core`, `rtw88_usb`, `rtw88_8822bu`, `rtw88_8821cu` |
| Atheros / Qualcomm | `ath9k` |
| Base wireless stack | `cfg80211`, `mac80211` |

---

## Requirements

- MOS kernel **6.18.x or newer** (must have `cfg80211`/`mac80211` built in)
- The `mos-wifi-modules` package must be available in a [Mainfrezzer/mos-kernel](https://github.com/Mainfrezzer/mos-kernel) or [ich777/mos-kernel](https://github.com/ich777/mos-kernel) GitHub Release for your exact kernel version
- Internet access on the MOS system (for automatic download), or a locally provided `.deb`

---

## Installation

Install via **MOS Hub** (recommended) or manually:

```bash
# Manually trigger driver install
/usr/bin/plugins/mos-wifi-driver-install

# With a local .deb file
/usr/bin/plugins/mos-wifi-driver-install /path/to/mos-wifi-modules.deb
```

---

## Automatic Reinstallation

Controlled via `settings.json`:

```json
{
  "installOnStart": true,
  "installOnOsUpdate": true
}
```

The `functions` file hooks into these MOS lifecycle events:

| Hook | Trigger |
|---|---|
| `install` | Plugin installation |
| `plugin_update` | Plugin update |
| `mos_start` | Every MOS system start |
| `mos_osupdate` | After OS updates |

---

## Repository Structure

```
mos_wifi/
├── mos-wifi-driver-install.sh   # Main installer script
├── functions                    # MOS lifecycle hooks
├── settings.json                # Plugin settings
├── page/                        # Vue/Vuetify plugin UI
│   ├── index.vue
│   └── locales/
│       ├── de.json
│       └── en.json
└── .github/workflows/           # Build & release automation
```

---

## Related Repositories

- [ich777/mos-kernel](https://github.com/ich777/mos-kernel) – Official MOS kernel builds
- [Mainfrezzer/mos-kernel](https://github.com/Mainfrezzer/mos-kernel) – MOS kernel fork with WiFi module packages
- [mos-official.net](https://mos-official.net) – MOS project website

---

## License

GPL-3.0 — see [LICENSE](LICENSE) for details.

Third-party components (kernel modules, firmware) remain under their respective upstream licenses — see [THIRD_PARTY.md](THIRD_PARTY.md).
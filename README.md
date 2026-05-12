# MOS WiFi Drivers

MOS WiFi Drivers provides a **MOS plugin** to install common WiFi
firmware and driver packages inside the MOS environment.

---

## Overview

This repository contains the **MOS plugin implementation**, optional helper
functions, configuration files (such as `settings.json`)

## WiFi Driver Installation

Das Plugin paketiert ein zusaetzliches Skript zur WLAN-Treiberinstallation.
Bei der Installation des Plugin-Pakets wird dieses Skript automatisch ausgefuehrt
und kann zusaetzlich im Plugin-UI manuell gestartet werden.

Zusaetzlich ist eine `functions`-Datei enthalten, die die MOS-Lifecycle-Hooks
`install`, `plugin_update`, `mos_start` und `mos_osupdate` bereitstellt,
damit die WLAN-Treiberinstallation auch bei Start/Update erneut ausgefuehrt werden kann.

---

## Build & Automation

This repository includes a **GitHub Actions workflow** used to build and package
the plugin and its associated binaries for MOS.

The build process is fully automated and produces artifacts that can be
installed through the MOS Hub.

---

## Licensing

The contents of this repository (plugin code, build scripts, configuration,
and automation) are licensed under **GPL-3.0**.

---

## Third-Party Software

This repository builds and packages third-party open-source software.
Packaged components remain licensed under their original upstream licenses.

Refer to `THIRD_PARTY.md` for details.


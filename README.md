# MOS Nethogs Network Monitor

MOS Nethogs provides a **MOS plugin** to install Nethogs and other network
monitoring tools inside the MOS environment.

---

## Overview

This repository contains the **MOS plugin implementation**, configuration files
(such as `settings.json`), and installer scripts for network monitoring tools.

## Nethogs Installation

Das Plugin paketiert ein Installationsskript zur Installation von Nethogs und weiteren
Netzwerk-Überwachungstools. Bei der Installation des Plugin-Pakets wird dieses Skript
automatisch ausgefuehrt und kann zusaetzlich im Plugin-UI manuell gestartet werden.

Zusaetzlich ist eine `functions`-Datei enthalten, die die MOS-Lifecycle-Hooks
`install`, `plugin_update`, `mos_start` und `mos_osupdate` bereitstellt,
damit die Installation auch bei Start/Update erneut ausgefuehrt werden kann.

### Installed Tools

- **Nethogs**: Real-time network traffic monitor per process
- **iftop**: Interactive network bandwidth monitor
- **vnstat**: Network traffic statistics
- **bmon**: Visual bandwidth monitor

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

# mos-nethogs

#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

PACKAGES=(
  firmware-iwlwifi
  firmware-realtek
  firmware-atheros
  firmware-brcm80211
  wireless-regdb
  iw
  wpasupplicant
)

MODULES=(
  cfg80211
  mac80211
  iwlwifi
  brcmfmac
  ath9k
  rtw88_core
)

log() {
  echo "[mos-wifi] $*"
}

if [[ "${EUID}" -ne 0 ]]; then
  log "Dieses Skript muss als root ausgefuehrt werden."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  log "apt-get ist nicht verfuegbar. Treiberinstallation uebersprungen."
  exit 1
fi

log "Aktualisiere Paketlisten..."
apt-get update

AVAILABLE_PACKAGES=()
for pkg in "${PACKAGES[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    AVAILABLE_PACKAGES+=("$pkg")
  else
    log "Paket nicht verfuegbar, ueberspringe: $pkg"
  fi
done

if [[ "${#AVAILABLE_PACKAGES[@]}" -eq 0 ]]; then
  log "Keine installierbaren WLAN-Pakete gefunden."
  exit 1
fi

log "Installiere WLAN-Treiber/Firmware-Pakete..."
apt-get install -y --no-install-recommends "${AVAILABLE_PACKAGES[@]}"

if command -v modprobe >/dev/null 2>&1; then
  KERNEL_MODULE_DIR="/lib/modules/$(uname -r)"
  if [[ -d "$KERNEL_MODULE_DIR" ]]; then
    log "Lade haeufige WLAN-Kernelmodule, falls vorhanden..."
    for module in "${MODULES[@]}"; do
      if modinfo "$module" >/dev/null 2>&1; then
        modprobe "$module" || true
      else
        log "Kernelmodul nicht verfuegbar, ueberspringe: $module"
      fi
    done
  else
    log "Kein Kernel-Modulverzeichnis gefunden ($KERNEL_MODULE_DIR), ueberspringe modprobe."
  fi
fi

log "WLAN-Treiberinstallation abgeschlossen."
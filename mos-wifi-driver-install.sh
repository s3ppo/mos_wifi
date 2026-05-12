#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SCRIPT_VERSION="2026-05-12a"

PACKAGES=(
  wireless-regdb
  iw
  wpasupplicant
)

MODULES=(
  cfg80211
  mac80211
  rtl8xxxu
  rtw88_core
  rtw88_usb
  rtw88_8822bu
  rtw88_8821cu
  ath9k
  iwlwifi
)

log() {
  echo "[mos-wifi] $*"
}

report_wifi_interfaces() {
  local wlan_ifaces
  wlan_ifaces="$(ip -o link show 2>/dev/null | awk -F': ' '/^[0-9]+: wl/{print $2}')"

  if [[ -n "${wlan_ifaces}" ]]; then
    log "WLAN-Interface(s) erkannt: ${wlan_ifaces//$'\n'/, }"
    return
  fi

  log "Kein WLAN-Interface (wl*) erkannt."
  log "Hinweis: Der Adapter ist evtl. sichtbar, aber ohne passenden Kernel-Treiber gebunden."
}

detect_usb_wifi_adapter_status() {
  if ! command -v usb-devices >/dev/null 2>&1; then
    return
  fi

  local unbound_count
  unbound_count="$({
    usb-devices | awk '
      BEGIN { RS=""; FS="\n"; count=0 }
      {
        product=""
        unbound=0
        for (i=1; i<=NF; i++) {
          if ($i ~ /^S:[[:space:]]+Product=/) {
            product = substr($i, index($i, "=") + 1)
          }
          if ($i ~ /^I:[[:space:]]/ && $i ~ /Driver=\(none\)/) {
            unbound=1
          }
        }
        if (unbound && product ~ /(WLAN|Wireless|802\.11|Wi-?Fi)/) {
          count++
        }
      }
      END { print count }
    '
  } 2>/dev/null)"

  if [[ "${unbound_count:-0}" -gt 0 ]]; then
    log "USB-WLAN-Adapter erkannt, aber ohne gebundenen Kernel-Treiber."
    log "Hinweis: Je nach Chipsatz ist ggf. ein zusaetzlicher Treiber noetig."
  fi
}

if [[ "${EUID}" -ne 0 ]]; then
  log "Dieses Skript muss als root ausgefuehrt werden."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  log "apt-get ist nicht verfuegbar. Treiberinstallation uebersprungen."
  exit 1
fi

log "Installer-Version: ${SCRIPT_VERSION}"

log "Aktualisiere Paketlisten..."
echo y | apt-get update || {
  log "Fehler beim apt-get update (dpkg gesperrt?). Versuche spaeter erneut."
  exit 0
}

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
  exit 0
fi

log "Installiere WLAN-Treiber/Firmware-Pakete..."
echo y | apt-get install -y --no-install-recommends "${AVAILABLE_PACKAGES[@]}" || {
  log "Fehler bei der Installation (dpkg gesperrt?). Versuche spaeter erneut."
  exit 0
}

detect_usb_wifi_adapter_status

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

report_wifi_interfaces

log "WLAN-Treiberinstallation abgeschlossen."
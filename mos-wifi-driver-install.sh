#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
SCRIPT_VERSION="2026-06-12a"

# Base packages
PACKAGES=(
  wireless-regdb
  iw
  wpasupplicant
)

# Expected kernel modules (loaded after driver package install)
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

# Plugin/Driver configuration
PLG_NAME="mos-wifi-driver"
DRV_PLG_DIR="/boot/optional/drivers/$PLG_NAME"
DRIVER_PKG="mos-wifi-modules"

log() {
  echo "[mos-wifi] $*"
}

report_kernel_build_env() {
  local kernel_dir
  local build_link
  local build_target

  kernel_dir="/lib/modules/$(uname -r)"
  build_link="${kernel_dir}/build"

  if [[ ! -e "${build_link}" ]]; then
    log "Kernel-Build-Verzeichnis fehlt (${build_link})."
    log "Hinweis: Ohne Header/Build-Tree koennen keine DKMS-WLAN-Treiber gebaut werden."
    return
  fi

  if [[ -L "${build_link}" ]]; then
    build_target="$(readlink "${build_link}")"
    if [[ ! -d "${build_link}" ]]; then
      log "Kernel-Build-Link ist defekt: ${build_link} -> ${build_target}"
      log "Hinweis: Ohne gueltigen Build-Tree ist ein externer WLAN-Treiber nicht kompilierbar."
      return
    fi
  fi

  if [[ ! -f "${build_link}/Makefile" ]]; then
    log "Kernel-Build-Tree erkannt, aber Makefile fehlt (${build_link}/Makefile)."
    log "Hinweis: Build-Umgebung unvollstaendig, DKMS-Build wird voraussichtlich fehlschlagen."
    return
  fi

  log "Kernel-Build-Umgebung erkannt: ${build_link}"
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

report_kernel_wireless_support() {
  local kernel_dir
  local module_count
  local cfg_count
  local search_dirs
  local dir

  kernel_dir="/lib/modules/$(uname -r)"

  if [[ ! -d "${kernel_dir}" ]]; then
    log "Kernel-Modulverzeichnis fehlt: ${kernel_dir}"
    return
  fi

  search_dirs=()
  for dir in \
    "${kernel_dir}/kernel/net/wireless" \
    "${kernel_dir}/kernel/net/mac80211" \
    "${kernel_dir}/kernel/drivers/net/wireless"; do
    if [[ -d "${dir}" ]]; then
      search_dirs+=("${dir}")
    fi
  done

  if [[ "${#search_dirs[@]}" -eq 0 ]]; then
    log "Keine WLAN-Kernelmodulpfade gefunden (net/wireless, net/mac80211, drivers/net/wireless)."
    log "Hinweis: Dieser MOS-Kernel enthaelt vermutlich keine passenden WLAN-USB-Treiber."
    return
  fi

  module_count="$(find "${search_dirs[@]}" -type f \( -name '*.ko' -o -name '*.ko.xz' -o -name '*.ko.zst' \) 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${module_count:-0}" -eq 0 ]]; then
    log "Keine ladbaren WLAN-Kernelmodule in net/wireless, net/mac80211 oder drivers/net/wireless gefunden."
    log "Hinweis: Dieser MOS-Kernel enthaelt vermutlich keine passenden WLAN-USB-Treiber."
    return
  fi

  cfg_count="0"
  if [[ -d "${kernel_dir}/kernel/net/wireless" ]]; then
    cfg_count="$(find "${kernel_dir}/kernel/net/wireless" -type f -name 'cfg80211*.ko*' 2>/dev/null | wc -l | tr -d ' ')"
  fi
  log "Kernel-WLAN-Module gefunden: ${module_count}"
  if [[ "${cfg_count:-0}" -eq 0 ]]; then
    log "Hinweis: cfg80211-Moduldatei nicht gefunden (kann auch einkompiliert sein)."
  fi
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

check_modules_already_installed() {
  # Check if wifi modules are already available (built into kernel or previously installed)
  for module in cfg80211 mac80211; do
    if modinfo "$module" >/dev/null 2>&1; then
      log "WLAN-Kernelmodule bereits vorhanden (einkompiliert oder installiert)."
      return 0
    fi
  done
  return 1
}

download_driver_deb() {
  local UNAME="$1"
  local DRV_DIR="$DRV_PLG_DIR/$UNAME"
  
  # TODO: Implement GitHub API download similar to ZFS plugin
  # For now, this is a placeholder - requires GitHub release setup
  log "Download von GitHub Releases (noch nicht implementiert)."
  return 1
}

check_and_install_driver_package() {
  local UNAME
  local DRV_DIR
  local DRIVER_DEB
  local CUSTOM_PATH="$1"
  
  UNAME="$(uname -r)"
  DRV_DIR="$DRV_PLG_DIR/$UNAME"
  
  # First: Check if modules are already available
  if check_modules_already_installed; then
    return 0
  fi
  
  # Second: If custom path provided, try to use it
  if [[ -n "$CUSTOM_PATH" ]]; then
    if [[ -f "$CUSTOM_PATH" ]]; then
      log "Installiere WiFi-Treiber-Paket von: $CUSTOM_PATH"
      dpkg -i "$CUSTOM_PATH" >/dev/null 2>&1 || {
        log "FEHLER: Treiber-Paket-Installation fehlgeschlagen."
        return 1
      }
      
      # Rebuild kernel module dependencies
      depmod --all >/dev/null 2>&1 || true
      udevadm trigger >/dev/null 2>&1 || true
      udevadm settle --timeout=15 >/dev/null 2>&1 || true
      
      log "Treiber-Paket erfolgreich installiert."
      return 0
    else
      log "FEHLER: Datei nicht gefunden: $CUSTOM_PATH"
      return 1
    fi
  fi
  
  # Third: Check if driver package exists locally in default location
  if DRIVER_DEB=$(ls -1 "$DRV_DIR"/*.deb 2>/dev/null | sort -V | tail -1); then
    log "Installiere WiFi-Treiber-Paket: $(basename "$DRIVER_DEB")"
    dpkg -i "$DRIVER_DEB" >/dev/null 2>&1 || {
      log "FEHLER: Treiber-Paket-Installation fehlgeschlagen."
      return 1
    }
    
    # Rebuild kernel module dependencies
    depmod --all >/dev/null 2>&1 || true
    udevadm trigger >/dev/null 2>&1 || true
    udevadm settle --timeout=15 >/dev/null 2>&1 || true
    
    log "Treiber-Paket erfolgreich installiert."
    return 0
  fi
  
  # Fourth: Try to download from GitHub (requires release setup)
  log "Versuche, WiFi-Treiber-Paket von GitHub herunterzuladen..."
  if download_driver_deb "$UNAME"; then
    return 0
  fi
  
  # No driver package found
  log "FEHLER: Kein WiFi-Treiber-Paket verfuegbar."
  return 1
}

load_kernel_modules() {
  if ! command -v modprobe >/dev/null 2>&1; then
    return
  fi
  
  local KERNEL_MODULE_DIR
  KERNEL_MODULE_DIR="/lib/modules/$(uname -r)"
  
  if [[ ! -d "$KERNEL_MODULE_DIR" ]]; then
    log "Kernel-Modulverzeichnis nicht gefunden ($KERNEL_MODULE_DIR)"
    return
  fi
  
  log "Lade WLAN-Kernelmodule..."
  for module in "${MODULES[@]}"; do
    if modinfo "$module" >/dev/null 2>&1; then
      modprobe "$module" || log "Warnung: Modul $module konnte nicht geladen werden"
    fi
  done
}

if [[ "${EUID}" -ne 0 ]]; then
  log "Dieses Skript muss als root ausgefuehrt werden."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  log "apt-get ist nicht verfuegbar."
  exit 1
fi

log "Installer-Version: ${SCRIPT_VERSION}"
report_kernel_wireless_support

log "Aktualisiere Paketlisten..."
apt-get update >/dev/null 2>&1 || {
  log "Warnung: apt-get update fehlgeschlagen (dpkg gesperrt?)"
}

# Install base packages
log "Installiere WiFi-Basis-Pakete (firmware, tools)..."
apt-get install -y --no-install-recommends "${PACKAGES[@]}" >/dev/null 2>&1 || {
  log "Warnung: Einige Basis-Pakete konnten nicht installiert werden."
}

# Check and install kernel-specific driver package
if ! check_and_install_driver_package "$1"; then
  log "FEHLER: WLAN-Treiber nicht verfuegbar."
  log ""
  log "Moegliche Loesungen:"
  log "1. Pfad eingeben: Geben Sie den Pfad zur .deb-Datei ueber die Plugin-Oberflaeche ein"
  log "2. Lokal: .deb-Paket unter $DRV_PLG_DIR/\$(uname -r)/ bereitstellen"
  log "3. Download: GitHub-Release als Quelle konfigurieren (siehe Dokumentation)"
  log "4. Kernel: Treiber-Module koennen auch im Kernel einkompiliert sein"
  log ""
  log "Kontaktiere den Administrator fuer Unterstuetzung."
  exit 1
fi

detect_usb_wifi_adapter_status
load_kernel_modules
report_wifi_interfaces

log "WLAN-Treiberinstallation abgeschlossen."
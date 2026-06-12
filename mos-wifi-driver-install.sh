#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

SCRIPT_VERSION="2026-06-12b"

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

# GitHub source for WiFi module packages
# Primary:  Mainfrezzer/mos-kernel (custom MOS kernel fork with WiFi support)
# Fallback: ich777/mos-kernel (upstream, once WiFi modules are added there)
GITHUB_REPO_PRIMARY="Mainfrezzer/mos-kernel"
GITHUB_REPO_FALLBACK="ich777/mos-kernel"

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

report_kernel_wireless_support() {
    local kernel_dir module_count cfg_count search_dirs=() dir
    kernel_dir="/lib/modules/$(uname -r)"

    if [[ ! -d "${kernel_dir}" ]]; then
        log "Kernel-Modulverzeichnis fehlt: ${kernel_dir}"
        return
    fi

    for dir in \
        "${kernel_dir}/kernel/net/wireless" \
        "${kernel_dir}/kernel/net/mac80211" \
        "${kernel_dir}/kernel/drivers/net/wireless"; do
        [[ -d "${dir}" ]] && search_dirs+=("${dir}")
    done

    if [[ "${#search_dirs[@]}" -eq 0 ]]; then
        log "Keine WLAN-Kernelmodulpfade gefunden (net/wireless, net/mac80211, drivers/net/wireless)."
        log "Hinweis: Dieser MOS-Kernel enthaelt vermutlich keine passenden WLAN-USB-Treiber."
        return
    fi

    module_count="$(find "${search_dirs[@]}" -type f \( -name '*.ko' -o -name '*.ko.xz' -o -name '*.ko.zst' \) 2>/dev/null | wc -l | tr -d ' ')"

    if [[ "${module_count:-0}" -eq 0 ]]; then
        log "Keine ladbaren WLAN-Kernelmodule in den Kernel-Pfaden gefunden."
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
    for module in cfg80211 mac80211; do
        if modinfo "$module" >/dev/null 2>&1; then
            log "WLAN-Kernelmodule bereits vorhanden (einkompiliert oder installiert)."
            return 0
        fi
    done
    return 1
}

# Sucht in einem GitHub-Release nach einem .deb das zur aktuellen Kernel-Version passt.
# Strategie:
#   1. Exakter Match: Dateiname enthaelt genau "$(uname -r)"
#   2. Versionsmatch: Dateiname enthaelt die Kernel-Basisversion (z.B. "6.18.35")
#      Das deckt Faelle ab wo der Dateiname "mos-wifi-modules_6.18.35-mos_amd64.deb" heisst
#      aber uname -r "6.18.35-mos-custom" liefert.
_find_deb_url_in_release() {
    local release_json="$1"
    local uname="$2"

    # Kernel-Basisversion extrahieren (z.B. "6.18.35" aus "6.18.35-mos")
    local base_ver
    base_ver="$(echo "$uname" | grep -oP '^\d+\.\d+\.\d+')"

    # Alle .deb Asset-URLs aus dem JSON extrahieren
    local all_debs
    all_debs="$(echo "$release_json" | \
        grep -o '"browser_download_url": *"[^"]*\.deb"' | \
        grep -o 'https://[^"]*')"

    if [[ -z "$all_debs" ]]; then
        return 1
    fi

    # Prioritaet 1: Exakter uname -r Match im Dateinamen
    local exact_match
    exact_match="$(echo "$all_debs" | grep -F "${uname}" | grep -i 'wifi\|wireless\|wlan\|modules' | head -1)"
    if [[ -n "$exact_match" ]]; then
        echo "$exact_match"
        return 0
    fi

    # Prioritaet 2: Kernel-Basisversion Match + wifi/modules im Namen
    if [[ -n "$base_ver" ]]; then
        local ver_match
        ver_match="$(echo "$all_debs" | grep -F "${base_ver}" | grep -i 'wifi\|wireless\|wlan\|modules' | head -1)"
        if [[ -n "$ver_match" ]]; then
            echo "$ver_match"
            return 0
        fi
    fi

    # Prioritaet 3: Irgendein .deb mit wifi/wireless/wlan/modules im Namen
    # (als letzter Ausweg, falls Namensschema unbekannt)
    local generic_match
    generic_match="$(echo "$all_debs" | grep -i 'wifi\|wireless\|wlan\|modules' | head -1)"
    if [[ -n "$generic_match" ]]; then
        log "Warnung: Kein versionsspezifischer Treiber gefunden, verwende generisches Paket."
        echo "$generic_match"
        return 0
    fi

    return 1
}

# Versucht, das WiFi-Modul-.deb von einem GitHub-Repo herunterzuladen und zu installieren.
_download_and_install_from_repo() {
    local repo="$1"
    local uname="$2"
    local drv_dir="$3"

    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    log "Pruefe GitHub Releases: ${repo}..."

    local release_json
    release_json="$(curl -fsSL --connect-timeout 10 --max-time 30 "$api_url" 2>/dev/null)" || {
        log "GitHub API nicht erreichbar: ${repo}"
        return 1
    }

    # Sicherstellen dass es ein gueltiges JSON-Release ist
    if ! echo "$release_json" | grep -q '"tag_name"'; then
        log "Kein gueltiges Release gefunden in: ${repo}"
        return 1
    fi

    local release_tag
    release_tag="$(echo "$release_json" | grep -o '"tag_name": *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')"
    log "Gefundenes Release: ${release_tag}"

    local deb_url
    if ! deb_url="$(_find_deb_url_in_release "$release_json" "$uname")"; then
        log "Kein passendes WiFi-Modul-.deb fuer Kernel ${uname} in Release ${release_tag}."
        return 1
    fi

    local deb_filename
    deb_filename="$(basename "$deb_url")"
    local deb_path="${drv_dir}/${deb_filename}"

    mkdir -p "$drv_dir"
    log "Lade herunter: ${deb_filename}"
    if ! curl -fsSL --connect-timeout 10 --max-time 120 -o "$deb_path" "$deb_url"; then
        log "Download fehlgeschlagen: ${deb_url}"
        rm -f "$deb_path"
        return 1
    fi

    log "Installiere: ${deb_filename}"
    if ! dpkg -i "$deb_path" >/dev/null 2>&1; then
        log "FEHLER: dpkg -i fehlgeschlagen fuer ${deb_filename}"
        rm -f "$deb_path"
        return 1
    fi

    depmod --all >/dev/null 2>&1 || true
    udevadm trigger >/dev/null 2>&1 || true
    udevadm settle --timeout=15 >/dev/null 2>&1 || true

    log "WiFi-Treiber-Paket erfolgreich installiert: ${deb_filename}"
    return 0
}

download_driver_deb() {
    local uname="$1"
    local drv_dir="$DRV_PLG_DIR/$uname"

    # Primaerquelle: Mainfrezzer/mos-kernel (MOS-Kernel-Fork mit WLAN-Support)
    if _download_and_install_from_repo "$GITHUB_REPO_PRIMARY" "$uname" "$drv_dir"; then
        return 0
    fi

    # Fallback: ich777/mos-kernel (Upstream, sobald Module dort verfuegbar sind)
    log "Primaerquelle nicht verfuegbar, versuche Fallback: ${GITHUB_REPO_FALLBACK}..."
    if _download_and_install_from_repo "$GITHUB_REPO_FALLBACK" "$uname" "$drv_dir"; then
        return 0
    fi

    return 1
}

check_and_install_driver_package() {
    local CUSTOM_PATH="${1:-}"
    local UNAME DRV_DIR DRIVER_DEB

    UNAME="$(uname -r)"
    DRV_DIR="$DRV_PLG_DIR/$UNAME"

    # 1. Module bereits vorhanden?
    if check_modules_already_installed; then
        return 0
    fi

    # 2. Expliziter Pfad uebergeben?
    if [[ -n "$CUSTOM_PATH" ]]; then
        if [[ -f "$CUSTOM_PATH" ]]; then
            log "Installiere WiFi-Treiber-Paket von: $CUSTOM_PATH"
            dpkg -i "$CUSTOM_PATH" >/dev/null 2>&1 || {
                log "FEHLER: Treiber-Paket-Installation fehlgeschlagen."
                return 1
            }
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

    # 3. Lokales .deb bereits gecacht (z.B. von frueherer Installation)?
    if DRIVER_DEB=$(ls -1 "$DRV_DIR"/*.deb 2>/dev/null | sort -V | tail -1); then
        log "Installiere gecachtes WiFi-Treiber-Paket: $(basename "$DRIVER_DEB")"
        dpkg -i "$DRIVER_DEB" >/dev/null 2>&1 || {
            log "FEHLER: Treiber-Paket-Installation fehlgeschlagen."
            return 1
        }
        depmod --all >/dev/null 2>&1 || true
        udevadm trigger >/dev/null 2>&1 || true
        udevadm settle --timeout=15 >/dev/null 2>&1 || true
        log "Treiber-Paket erfolgreich installiert."
        return 0
    fi

    # 4. Von GitHub herunterladen
    log "Versuche, WiFi-Treiber-Paket von GitHub herunterzuladen..."
    if download_driver_deb "$UNAME"; then
        return 0
    fi

    log "FEHLER: Kein WiFi-Treiber-Paket verfuegbar."
    return 1
}

load_kernel_modules() {
    if ! command -v modprobe >/dev/null 2>&1; then
        return
    fi

    local KERNEL_MODULE_DIR="/lib/modules/$(uname -r)"
    if [[ ! -d "$KERNEL_MODULE_DIR" ]]; then
        log "Kernel-Modulverzeichnis nicht gefunden ($KERNEL_MODULE_DIR)"
        return
    fi

    log "Lade WLAN-Kernelmodule..."
    for module in "${MODULES[@]}"; do
        if modinfo "$module" >/dev/null 2>&1; then
            modprobe "$module" 2>/dev/null || log "Warnung: Modul $module konnte nicht geladen werden"
        fi
    done
}

# ── Hauptprogramm ─────────────────────────────────────────────────────────────

if [[ "${EUID}" -ne 0 ]]; then
    log "Dieses Skript muss als root ausgefuehrt werden."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    log "apt-get ist nicht verfuegbar."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    log "curl ist nicht verfuegbar – wird benoetigt fuer GitHub-Download."
    exit 1
fi

log "Installer-Version: ${SCRIPT_VERSION}"
log "Kernel: $(uname -r)"
report_kernel_wireless_support

log "Aktualisiere Paketlisten..."
apt-get update >/dev/null 2>&1 || {
    log "Warnung: apt-get update fehlgeschlagen (dpkg gesperrt?)"
}

log "Installiere WiFi-Basis-Pakete (firmware, tools)..."
apt-get install -y --no-install-recommends "${PACKAGES[@]}" >/dev/null 2>&1 || {
    log "Warnung: Einige Basis-Pakete konnten nicht installiert werden."
}

if ! check_and_install_driver_package "${1:-}"; then
    log "FEHLER: WLAN-Treiber nicht verfuegbar."
    log ""
    log "Moegliche Loesungen:"
    log "1. Manueller Pfad: .deb-Datei ueber die Plugin-Oberflaeche angeben"
    log "2. Lokal bereitstellen: .deb unter $DRV_PLG_DIR/\$(uname -r)/ ablegen"
    log "3. GitHub-Quellen: ${GITHUB_REPO_PRIMARY} oder ${GITHUB_REPO_FALLBACK}"
    log "   -> Kernel-spezifisches WiFi-Modul-.deb muss im 'latest' Release vorhanden sein"
    log "4. Einkompiliert: Treiber-Module koennen auch direkt im Kernel enthalten sein"
    log ""
    log "Kontaktiere den Administrator fuer Unterstuetzung."
    exit 1
fi

detect_usb_wifi_adapter_status
load_kernel_modules
report_wifi_interfaces

log "WLAN-Treiberinstallation abgeschlossen."
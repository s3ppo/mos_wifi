#!/usr/bin/env bash

set -euo pipefail

SCRIPT_VERSION="2026-06-12g"

GITHUB_REPO="ich777/mos-addon-drivers"

MODULES=(
    cfg80211
    mac80211
    rtl8xxxu
    rtw88_core
    rtw88_usb
    rtw88_8822bu
    rtw88_8821cu
    ath9k_htc
    mt7601u
    mt76x0u
    mt76x2u
    mt7921u
    iwlwifi
)

PLG_NAME="mos-wifi-driver"
DRV_PLG_DIR="/boot/optional/drivers/$PLG_NAME"

log() {
    echo "[mos-wifi] $*"
}

report_kernel_wireless_support() {
    for mod in cfg80211 mac80211; do
        if modinfo "$mod" >/dev/null 2>&1; then
            log "Built-in OK: ${mod}"
        else
            log "Warnung: ${mod} nicht gefunden – falscher Kernel?"
        fi
    done
}

# URL direkt aus Kernel-Version konstruieren – kein API-Call nötig.
# Namensschema: wifi_<base>-1+mos_amd64.deb
# Release-Tag:  <uname -r>  (z.B. 6.18.36-mos)
# Beispiel:     wifi_6.18.36-1+mos_amd64.deb
build_deb_url() {
    local uname="$1"
    local base_ver
    base_ver="$(echo "$uname" | grep -oP '^\d+\.\d+\.\d+')"
    local tag="${uname}"
    local filename="wifi_${base_ver}-1+mos_amd64.deb"
    # + muss als %2B URL-encoded werden
    local filename_encoded="wifi_${base_ver}-1%2Bmos_amd64.deb"
    echo "https://github.com/${GITHUB_REPO}/releases/download/${tag}/${filename_encoded}"
}

check_wifi_package_installed() {
    # Paketname ist "wifi-driver"
    if dpkg -l "wifi-driver" 2>/dev/null | grep -q "^ii"; then
        log "WiFi-Paket bereits installiert (wifi-driver)."
        return 0
    fi
    return 1
}

download_and_install_wifi_package() {
    local uname="$1"
    local drv_dir="$DRV_PLG_DIR/$uname"
    local base_ver
    base_ver="$(echo "$uname" | grep -oP '^\d+\.\d+\.\d+')"
    local deb_filename="wifi_${base_ver}-1+mos_amd64.deb"
    local deb_url
    deb_url="$(build_deb_url "$uname")"
    local deb_path="${drv_dir}/${deb_filename}"

    log "WiFi-Paket: ${deb_filename}"
    log "Quelle: https://github.com/${GITHUB_REPO}/releases/tag/${uname}"

    mkdir -p "$drv_dir"

    if [[ -f "$deb_path" ]]; then
        log "Gecachtes Paket gefunden: ${deb_filename}"
    else
        log "Lade herunter..."
        if ! curl -fsSL --connect-timeout 10 --max-time 180 \
                -o "$deb_path" "$deb_url"; then
            log "FEHLER: Download fehlgeschlagen."
            log "URL: ${deb_url}"
            rm -f "$deb_path"
            return 1
        fi

        # MD5 prüfen falls verfügbar
        local md5_url="${deb_url}.md5"
        local expected_md5
        expected_md5="$(curl -fsSL --connect-timeout 10 --max-time 10 \
            "$md5_url" 2>/dev/null | awk '{print $1}')"
        if [[ -n "$expected_md5" ]]; then
            local actual_md5
            actual_md5="$(md5sum "$deb_path" | awk '{print $1}')"
            if [[ "$expected_md5" != "$actual_md5" ]]; then
                log "FEHLER: MD5-Prüfung fehlgeschlagen – Datei beschädigt."
                rm -f "$deb_path"
                return 1
            fi
            log "MD5 OK: ${actual_md5}"
        fi
    fi

    log "Installiere: ${deb_filename}"
    if ! dpkg -i "$deb_path" >/dev/null 2>&1; then
        log "FEHLER: dpkg -i fehlgeschlagen."
        rm -f "$deb_path"
        return 1
    fi

    depmod --all >/dev/null 2>&1 || true
    udevadm trigger >/dev/null 2>&1 || true
    udevadm settle --timeout=15 >/dev/null 2>&1 || true

    log "WiFi-Paket erfolgreich installiert: ${deb_filename}"
    return 0
}

load_kernel_modules() {
    if ! command -v modprobe >/dev/null 2>&1; then
        log "modprobe nicht verfuegbar."
        return
    fi

    log "Lade WLAN-Kernelmodule..."
    local loaded=0
    for module in "${MODULES[@]}"; do
        if modinfo "$module" >/dev/null 2>&1; then
            if modprobe "$module" 2>/dev/null; then
                log "Geladen: ${module}"
                (( loaded++ )) || true
            else
                log "Warnung: ${module} konnte nicht geladen werden."
            fi
        fi
    done

    if [[ "$loaded" -eq 0 ]]; then
        log "Keine Module geladen – Treiber-Paket nicht installiert?"
    else
        log "${loaded} Modul(e) geladen."
    fi
}

report_wifi_interfaces() {
    local wlan_ifaces
    wlan_ifaces="$(ip -o link show 2>/dev/null | awk -F': ' '/^[0-9]+: wl/{print $2}')"
    if [[ -n "${wlan_ifaces}" ]]; then
        log "WLAN-Interface(s) erkannt: ${wlan_ifaces//$'\n'/, }"
    else
        log "Kein WLAN-Interface (wl*) erkannt."
    fi
}

# ── Hauptprogramm ─────────────────────────────────────────────────────────────

if [[ "${EUID}" -ne 0 ]]; then
    log "Dieses Skript muss als root ausgefuehrt werden."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    log "FEHLER: curl nicht verfuegbar."
    exit 1
fi

UNAME="$(uname -r)"
log "Installer-Version: ${SCRIPT_VERSION}"
log "Kernel: ${UNAME}"

report_kernel_wireless_support

if ! check_wifi_package_installed; then
    if ! download_and_install_wifi_package "$UNAME"; then
        log "WiFi-Treiber konnten nicht installiert werden."
        exit 1
    fi
fi

load_kernel_modules
report_wifi_interfaces

log "WLAN-Treiberinstallation abgeschlossen."
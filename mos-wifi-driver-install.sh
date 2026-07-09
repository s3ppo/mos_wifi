#!/usr/bin/env bash

set -euo pipefail

SCRIPT_VERSION="2026-07-09a"

# GitHub-Quelle für WiFi-Firmware-Pakete
# Paket enthält NUR Firmware-Blobs – Kernel-Module sind direkt im MOS-Kernel
GITHUB_REPO="mos-nas/mos-addon-drivers"

# Kernel-Module die geladen werden sollen.
# Hinweis: iwlmvm/iwldvm fehlen noch im MOS-Kernel (CONFIG_IWLMVM/IWLDVM nicht gesetzt).
#          Intel-WLAN wird erst funktionieren wenn ich777 diese nachliefert.
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
    iwlmvm
    iwldvm
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

# URL direkt aus Kernel-Version konstruieren – kein GitHub API-Call nötig.
# Namensschema: wifi_<base>-1+mos_amd64.deb
# Release-Tag:  <uname -r>  (z.B. 6.18.38-mos)
build_deb_url() {
    local uname="$1"
    local base_ver
    base_ver="$(echo "$uname" | grep -oP '^\d+\.\d+\.\d+')"
    echo "https://github.com/${GITHUB_REPO}/releases/download/${uname}/wifi_${base_ver}-1%2Bmos_amd64.deb"
}

build_deb_filename() {
    local uname="$1"
    local base_ver
    base_ver="$(echo "$uname" | grep -oP '^\d+\.\d+\.\d+')"
    echo "wifi_${base_ver}-1+mos_amd64.deb"
}

# Prüft ob das Firmware-Paket bereits heruntergeladen wurde.
# dpkg-Installation wird nicht verwendet (Root-Overlay zu klein für 96 MB Firmware).
# Stattdessen: dpkg -x nach /boot/optional/drivers/ – Firmware liegt bereits
# via MOS-Overlay auf /boot (vfat) und ist damit direkt verfügbar.
check_firmware_extracted() {
    local uname="$1"
    local extract_dir="$DRV_PLG_DIR/$uname/extracted"
    # Als "installiert" gilt: Extraktionsverzeichnis vorhanden mit Firmware-Inhalt
    if [[ -d "${extract_dir}/lib/firmware" ]]; then
        log "Firmware-Paket bereits extrahiert."
        return 0
    fi
    return 1
}

download_and_extract_firmware() {
    local uname="$1"
    local drv_dir="$DRV_PLG_DIR/$uname"
    local deb_filename
    deb_filename="$(build_deb_filename "$uname")"
    local deb_url
    deb_url="$(build_deb_url "$uname")"
    local deb_path="${drv_dir}/${deb_filename}"
    local extract_dir="${drv_dir}/extracted"

    log "WiFi-Firmware-Paket: ${deb_filename}"
    log "Quelle: https://github.com/${GITHUB_REPO}/releases/tag/${uname}"

    mkdir -p "$drv_dir"

    # Download (mit -L für GitHub Release-Asset Redirects)
    if [[ -f "$deb_path" ]]; then
        log "Gecachtes Paket gefunden: ${deb_filename}"
    else
        log "Lade herunter..."
        if ! curl -fsSL -L --connect-timeout 10 --max-time 180 \
                -o "$deb_path" "$deb_url"; then
            log "FEHLER: Download fehlgeschlagen."
            log "URL: ${deb_url}"
            rm -f "$deb_path"
            return 1
        fi
        log "Download abgeschlossen: $(du -h "$deb_path" | cut -f1)"

        # MD5 prüfen
        local md5_url="${deb_url}.md5"
        local expected_md5
        expected_md5="$(curl -fsSL -L --connect-timeout 10 --max-time 10 \
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

    # Extrahieren nach /boot statt dpkg -i (Root-Overlay hat keinen Platz)
    # MOS mounted /boot (vfat) bereits als /usr/lib/firmware via Overlay –
    # die Firmware ist nach dpkg -x damit direkt verfügbar.
    log "Extrahiere Firmware-Paket nach ${extract_dir}..."
    mkdir -p "$extract_dir"
    if ! dpkg -x "$deb_path" "$extract_dir" 2>/dev/null; then
        log "FEHLER: Extraktion fehlgeschlagen."
        rm -rf "$extract_dir"
        return 1
    fi

    # Firmware-Files nach /boot/firmware/ kopieren damit MOS-Overlay sie findet
    if [[ -d "${extract_dir}/lib/firmware" ]]; then
        log "Kopiere Firmware nach /boot/firmware/..."
        mkdir -p /boot/firmware
        cp -rn "${extract_dir}/lib/firmware/." /boot/firmware/ 2>/dev/null || true
        log "Firmware installiert."
    fi

    log "Firmware-Paket erfolgreich verarbeitet: ${deb_filename}"
    return 0
}

load_kernel_modules() {
    if ! command -v modprobe >/dev/null 2>&1; then
        log "modprobe nicht verfuegbar."
        return
    fi

    depmod --all >/dev/null 2>&1 || true

    log "Lade WLAN-Kernelmodule..."
    local loaded=0
    local missing=0
    for module in "${MODULES[@]}"; do
        if modinfo "$module" >/dev/null 2>&1; then
            if modprobe "$module" 2>/dev/null; then
                log "Geladen: ${module}"
                (( loaded++ )) || true
            else
                log "Warnung: ${module} konnte nicht geladen werden."
            fi
        else
            (( missing++ )) || true
        fi
    done

    log "${loaded} Modul(e) geladen, ${missing} nicht verfuegbar (noch nicht im Kernel)."

    # Spezifische Hinweise auf bekannte fehlende Module
    if ! modinfo iwlmvm >/dev/null 2>&1; then
        log "Hinweis: iwlmvm fehlt – Intel CNVi/PCIe WLAN noch nicht unterstuetzt."
        log "         Warte auf Kernel-Update von ich777 (CONFIG_IWLMVM=m)."
    fi
}

report_wifi_interfaces() {
    local wlan_ifaces
    wlan_ifaces="$(ip -o link show 2>/dev/null | awk -F': ' '/^[0-9]+: wl/{print $2}')"
    if [[ -n "${wlan_ifaces}" ]]; then
        log "WLAN-Interface(s) erkannt: ${wlan_ifaces//$'\n'/, }"
    else
        log "Kein WLAN-Interface (wl*) erkannt."
        log "Hinweis: WLAN-Adapter anstecken oder pruefen ob Treiber fuer den Chip verfuegbar ist."
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

if ! check_firmware_extracted "$UNAME"; then
    if ! download_and_extract_firmware "$UNAME"; then
        log "FEHLER: Firmware-Paket konnte nicht installiert werden."
        log "Paket-Quelle: https://github.com/${GITHUB_REPO}/releases"
        exit 1
    fi
fi

udevadm trigger >/dev/null 2>&1 || true
udevadm settle --timeout=15 >/dev/null 2>&1 || true

load_kernel_modules
report_wifi_interfaces

log "WLAN-Installation abgeschlossen."
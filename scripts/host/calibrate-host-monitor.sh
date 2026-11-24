#!/usr/bin/env bash
# Calibra o monitor físico do Host (6500K neutro, contraste nativo, brilho equilibrado, sRGB) via DDC/CI + KScreen.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$ROOT_DIR/.env" ] && source "$ROOT_DIR/.env"

PRIMARY_OUTPUT="${PRIMARY_OUTPUT:-HDMI-A-1}"
HOST_BRIGHTNESS="${HOST_BRIGHTNESS:-90}"
HOST_CONTRAST="${HOST_CONTRAST:-80}"
HOST_COLOR_PRESET_VCP="${HOST_COLOR_PRESET_VCP:-05}"

if command -v ddcutil >/dev/null 2>&1; then
    sudo ddcutil setvcp 14 "$HOST_COLOR_PRESET_VCP" 2>/dev/null || true
    sleep 0.2
    sudo ddcutil setvcp 12 "$HOST_CONTRAST" 2>/dev/null || true
    sleep 0.2
    sudo ddcutil setvcp 10 "$HOST_BRIGHTNESS" 2>/dev/null || true
    sleep 0.2
    sudo ddcutil getvcp 10 12 14 2>/dev/null || true
else
    echo "Aviso: ddcutil não instalado — pulando ajuste de hardware DDC/CI."
fi

if command -v kscreen-doctor >/dev/null 2>&1; then
    kscreen-doctor \
        "output.${PRIMARY_OUTPUT}.colorProfileSource.sRGB" \
        "output.${PRIMARY_OUTPUT}.brightness.${HOST_BRIGHTNESS}" 2>/dev/null || true
    kscreen-doctor -o | grep -A 15 "$PRIMARY_OUTPUT" | grep -E "Output:|Color profile|Brightness"
fi

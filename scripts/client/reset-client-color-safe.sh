#!/usr/bin/env bash
# Restaura brilho e gama limpos (100%, 6500K neutro) no cliente Linux X11 com segurança.
set -euo pipefail

export DISPLAY="${DISPLAY:-:0}"

pkill -x redshift-gtk 2>/dev/null || true
pkill -x redshift 2>/dev/null || true
command -v redshift >/dev/null 2>&1 && redshift -x 2>/dev/null || true

PANEL=$(xrandr --query 2>/dev/null | awk '/ connected/{print $1; exit}')
if [ -n "${PANEL:-}" ]; then
    xrandr --output "$PANEL" --brightness 1.0 --gamma 1.0:1.0:1.0
fi

if [ -x /usr/sbin/xfpm-power-backlight-helper ]; then
    MAX=$(/usr/sbin/xfpm-power-backlight-helper --get-max-brightness 2>/dev/null || true)
    [ -n "${MAX:-}" ] && pkexec --disable-internal-agent /usr/sbin/xfpm-power-backlight-helper --set-brightness "$MAX" 2>/dev/null || true
fi
command -v brightnessctl >/dev/null 2>&1 && brightnessctl set 100% 2>/dev/null || true
for bl in /sys/class/backlight/*; do
    if [ -f "$bl/max_brightness" ] && [ -w "$bl/brightness" ]; then
        cat "$bl/max_brightness" > "$bl/brightness" 2>/dev/null || true
    fi
done

echo "Brilho e gama restaurados com segurança em ${PANEL:-painel padrão}."
xrandr --verbose 2>/dev/null | grep -E "^${PANEL}|Brightness:|Gamma:" | head -n 6 || true

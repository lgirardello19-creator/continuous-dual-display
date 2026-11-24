#!/usr/bin/env bash
# Posiciona o monitor virtual à esquerda ou direita do monitor principal no KDE Plasma 6 Wayland.
set -euo pipefail

VIRTUAL_OUTPUT_NAME="${VIRTUAL_OUTPUT_NAME:-Virtual-SecondScreen}"
PRIMARY_OUTPUT="${PRIMARY_OUTPUT:-HDMI-A-1}"
PRIMARY_WIDTH="${PRIMARY_WIDTH:-1920}"
VIRTUAL_WIDTH="${VIRTUAL_WIDTH:-1920}"
VIRTUAL_SCALE="${VIRTUAL_SCALE:-1}"
VIRTUAL_SIDE="${VIRTUAL_SIDE:-left}"
HOST_BRIGHTNESS="${HOST_BRIGHTNESS:-}"

for _ in $(seq 1 40); do
    if kscreen-doctor -o 2>/dev/null | grep -q "$VIRTUAL_OUTPUT_NAME"; then
        break
    fi
    sleep 0.5
done

if ! kscreen-doctor -o 2>/dev/null | grep -q "$VIRTUAL_OUTPUT_NAME"; then
    echo "ERRO: saída $VIRTUAL_OUTPUT_NAME não apareceu no kscreen-doctor" >&2
    exit 1
fi

sleep 0.5

if [ "$VIRTUAL_SIDE" = "right" ]; then
    PRIMARY_POS="0,0"
    VIRTUAL_POS="${PRIMARY_WIDTH},0"
else
    VIRTUAL_POS="0,0"
    PRIMARY_POS="${VIRTUAL_WIDTH},0"
fi

ARGS=(
    "output.${VIRTUAL_OUTPUT_NAME}.position.${VIRTUAL_POS}"
    "output.${VIRTUAL_OUTPUT_NAME}.scale.${VIRTUAL_SCALE}"
    "output.${VIRTUAL_OUTPUT_NAME}.priority.2"
    "output.${PRIMARY_OUTPUT}.position.${PRIMARY_POS}"
    "output.${PRIMARY_OUTPUT}.scale.1"
    "output.${PRIMARY_OUTPUT}.priority.1"
    "output.${PRIMARY_OUTPUT}.colorProfileSource.sRGB"
)

if [ -n "$HOST_BRIGHTNESS" ]; then
    ARGS+=("output.${PRIMARY_OUTPUT}.brightness.${HOST_BRIGHTNESS}")
fi

kscreen-doctor "${ARGS[@]}"

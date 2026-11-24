#!/usr/bin/env bash
# Instala e configura o cliente Moonlight Qt (AppImage extraído, sem sudo/Flatpak) em Linux X11/Wayland.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$ROOT_DIR/.env" ] && source "$ROOT_DIR/.env"

HOST_IP="${HOST_IP:-10.42.0.228}"
HOST_FALLBACK_IP="${HOST_FALLBACK_IP:-}"
HOST_SSH_USER="${HOST_SSH_USER:-pc}"
APP_NAME="${APP_NAME:-Monitor Estendido}"
VIRTUAL_WIDTH="${VIRTUAL_WIDTH:-1920}"
VIRTUAL_HEIGHT="${VIRTUAL_HEIGHT:-1080}"
STREAM_FPS="${STREAM_FPS:-60}"
STREAM_BITRATE_KBPS="${STREAM_BITRATE_KBPS:-80000}"
MOONLIGHT_VERSION="${MOONLIGHT_VERSION:-6.2.0}"

APPIMAGE_URL="https://github.com/moonlight-stream/moonlight-qt/releases/download/v${MOONLIGHT_VERSION}/Moonlight-${MOONLIGHT_VERSION}-x86_64.AppImage"
INSTALL_DIR="$HOME/.local/opt/moonlight"
BIN_LINK="$HOME/.local/bin/moonlight-monitor"
LAUNCHER="$HOME/.local/bin/second-screen-connect.sh"
CONF_DIR="$HOME/.config/Moonlight Game Streaming Project"
CONF_FILE="$CONF_DIR/Moonlight.conf"

mkdir -p "$HOME/.local/bin" "$HOME/.local/opt" "$CONF_DIR" \
         "$HOME/.config/autostart" "$HOME/.local/share/applications"

echo "[1/5] Baixando e extraindo Moonlight v${MOONLIGHT_VERSION} (~51 MB)..."
TMP_IMG="/tmp/Moonlight-${MOONLIGHT_VERSION}-x86_64.AppImage"
curl -fL --progress-bar "$APPIMAGE_URL" -o "$TMP_IMG"
chmod +x "$TMP_IMG"

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
(cd "$INSTALL_DIR" && "$TMP_IMG" --appimage-extract >/dev/null)
rm -f "$TMP_IMG"
ln -sf "$INSTALL_DIR/squashfs-root/AppRun" "$BIN_LINK"

echo "[2/5] Gravando Moonlight.conf (${VIRTUAL_WIDTH}x${VIRTUAL_HEIGHT}@${STREAM_FPS}, ${STREAM_BITRATE_KBPS} kbps, HEVC, YUV 4:4:4)..."
[ -f "$CONF_FILE" ] && cp "$CONF_FILE" "${CONF_FILE}.bak-$(date +%Y%m%d-%H%M%S)"

python3 - "$CONF_FILE" "$VIRTUAL_WIDTH" "$VIRTUAL_HEIGHT" "$STREAM_FPS" "$STREAM_BITRATE_KBPS" <<'PYEOF'
import sys, configparser, os

path, w, h, fps, br = sys.argv[1:6]
cp = configparser.RawConfigParser()
cp.optionxform = str
if os.path.exists(path):
    cp.read(path)
if not cp.has_section("General"):
    cp.add_section("General")

prefs = {
    "width": w,
    "height": h,
    "fps": fps,
    "bitrate": br,
    "unlockbitrate": "true",
    "autoadjustbitrate": "false",
    "videocfg": "2",          # VCC_FORCE_HEVC
    "videodec": "0",          # VDS_AUTO (VA-API hardware com fallback seguro)
    "yuv444": "true",         # Texto nítido 1:1 e fidelidade de cores
    "hdr": "false",           # SDR sRGB alinhado ao monitor principal
    "windowmode": "0",        # WM_FULLSCREEN
    "vsync": "true",
    "framepacing": "true",
    "hostaudio": "true",      # Áudio continua no PC principal
    "muteonfocusloss": "true",
    "capturesyskeys": "0",    # CSK_OFF
    "mouseacceleration": "true",
    "keepawake": "true",
    "connwarnings": "false",
    "confwarnings": "false",
    "quitAppAfter": "false",
    "mdns": "true",
}
for k, v in prefs.items():
    cp.set("General", k, v)

with open(path, "w") as f:
    cp.write(f, space_around_delimiters=False)
PYEOF

echo "[3/5] Criando lançador com brilho/gama limpos..."
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export DISPLAY="\${DISPLAY:-:0}"

if command -v xrandr >/dev/null 2>&1; then
    PANEL=\$(xrandr --query 2>/dev/null | awk '/ connected/{print \$1; exit}')
    [ -n "\${PANEL:-}" ] && xrandr --output "\$PANEL" --brightness 1.0 --gamma 1.0:1.0:1.0 2>/dev/null || true
fi

TARGET=""
for _ in \$(seq 1 10); do
    if ping -c 1 -W 1 "$HOST_IP" >/dev/null 2>&1; then
        TARGET="$HOST_IP"
        break
    fi
    if [ -n "$HOST_FALLBACK_IP" ] && ping -c 1 -W 1 "$HOST_FALLBACK_IP" >/dev/null 2>&1; then
        TARGET="$HOST_FALLBACK_IP"
        break
    fi
    sleep 1
done

[ -n "\$TARGET" ] || { echo "Host não encontrado ($HOST_IP)" >&2; exit 1; }
[ "\${1:-}" = "--ui" ] && exec "$BIN_LINK"
exec "$BIN_LINK" stream "\$TARGET" "$APP_NAME"
EOF
chmod +x "$LAUNCHER"

echo "[4/5] Salvando autostart e atalho na Área de trabalho..."
DESKTOP_CONTENT="[Desktop Entry]
Type=Application
Name=Monitor Estendido
Comment=Conecta esta tela como monitor estendido contínuo do PC principal
Exec=\"$LAUNCHER\"
Icon=video-display
Terminal=false
Categories=System;Utility;
"
printf '%s' "$DESKTOP_CONTENT" > "$HOME/.config/autostart/second-screen.desktop"
printf '%s' "$DESKTOP_CONTENT" > "$HOME/.local/share/applications/second-screen.desktop"

for d in "$HOME/Área de trabalho" "$HOME/Desktop"; do
    if [ -d "$d" ]; then
        printf '%s' "$DESKTOP_CONTENT" > "$d/Monitor-Estendido.desktop"
        chmod +x "$d/Monitor-Estendido.desktop"
        if command -v gio >/dev/null 2>&1; then
            gio set -t string "$d/Monitor-Estendido.desktop" metadata::xfce-exe-checksum \
                "$(sha256sum "$d/Monitor-Estendido.desktop" | awk '{print $1}')" 2>/dev/null || true
        fi
        break
    fi
done

echo "[5/5] Pareando com o Host ($HOST_IP)..."
PIN=$(python3 -c 'import secrets; print(f"{secrets.randbelow(9000)+1000}")')
export DISPLAY="${DISPLAY:-:0}"
"$BIN_LINK" pair --pin "$PIN" "$HOST_IP" >/tmp/moonlight-pair.log 2>&1 &
PAIR_PID=$!
sleep 2

if ssh -o BatchMode=yes -o ConnectTimeout=3 "${HOST_SSH_USER}@${HOST_IP}" \
    "/home/${HOST_SSH_USER}/.local/bin/pair-sunshine-pin.sh $PIN $(hostname)" 2>/dev/null; then
    wait "$PAIR_PID" || true
    echo "Pareamento automático concluído!"
else
    echo "SSH sem senha indisponível; no Host execute:"
    echo "  ~/.local/bin/pair-sunshine-pin.sh $PIN $(hostname)"
    wait "$PAIR_PID" || true
fi

echo "Pronto! Abra o atalho 'Monitor Estendido' ou execute: $LAUNCHER"

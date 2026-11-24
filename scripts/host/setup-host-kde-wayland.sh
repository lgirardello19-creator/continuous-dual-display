#!/usr/bin/env bash
# Configura o Host Linux (KDE Plasma 6 Wayland): monitor virtual persistente + Sunshine otimizado + UFW local.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$ROOT_DIR/.env" ] && source "$ROOT_DIR/.env"

SUNSHINE_NAME="${SUNSHINE_NAME:-PC-Principal}"
PRIMARY_OUTPUT="${PRIMARY_OUTPUT:-HDMI-A-1}"
PRIMARY_WIDTH="${PRIMARY_WIDTH:-1920}"
VIRTUAL_NAME="${VIRTUAL_NAME:-SecondScreen}"
VIRTUAL_OUTPUT_NAME="${VIRTUAL_OUTPUT_NAME:-Virtual-${VIRTUAL_NAME}}"
VIRTUAL_WIDTH="${VIRTUAL_WIDTH:-1920}"
VIRTUAL_HEIGHT="${VIRTUAL_HEIGHT:-1080}"
VIRTUAL_SCALE="${VIRTUAL_SCALE:-1}"
VIRTUAL_SIDE="${VIRTUAL_SIDE:-left}"
APP_NAME="${APP_NAME:-Monitor Estendido}"
CLIENT_SUBNET="${CLIENT_SUBNET:-10.42.0.0/24}"
WIFI_SUBNET="${WIFI_SUBNET:-}"
HOST_BRIGHTNESS="${HOST_BRIGHTNESS:-}"

for bin in sunshine krfb-virtualmonitor kscreen-doctor; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "ERRO: '$bin' não está instalado. Instale 'sunshine' e 'krfb' primeiro." >&2
        exit 1
    fi
done

mkdir -p "$HOME/.local/bin" "$HOME/.config/sunshine" \
         "$HOME/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d"

# 1. Instala scripts auxiliares no usuário
cp "$SCRIPT_DIR/position-virtual-display.sh" "$HOME/.local/bin/position-virtual-display.sh"
cp "$SCRIPT_DIR/pair-pin.sh" "$HOME/.local/bin/pair-sunshine-pin.sh"
chmod +x "$HOME/.local/bin/position-virtual-display.sh" "$HOME/.local/bin/pair-sunshine-pin.sh"

# 2. Serviço systemd de usuário para o monitor virtual persistente
# Porta 5999 fica bloqueada no firewall; krfb-virtualmonitor serve apenas para instanciar o output no KWin.
VMON_PASS=$(python3 -c 'import secrets; print(secrets.token_hex(12))')
cat > "$HOME/.config/systemd/user/virtual-second-screen.service" <<EOF
[Unit]
Description=Monitor virtual estendido (${VIRTUAL_NAME} ${VIRTUAL_WIDTH}x${VIRTUAL_HEIGHT}@60)
After=graphical-session.target plasma-kwin_wayland.service
PartOf=graphical-session.target

[Service]
Type=simple
Environment=VIRTUAL_OUTPUT_NAME=${VIRTUAL_OUTPUT_NAME}
Environment=PRIMARY_OUTPUT=${PRIMARY_OUTPUT}
Environment=PRIMARY_WIDTH=${PRIMARY_WIDTH}
Environment=VIRTUAL_WIDTH=${VIRTUAL_WIDTH}
Environment=VIRTUAL_SCALE=${VIRTUAL_SCALE}
Environment=VIRTUAL_SIDE=${VIRTUAL_SIDE}
Environment=HOST_BRIGHTNESS=${HOST_BRIGHTNESS}
ExecStart=/usr/bin/krfb-virtualmonitor --name ${VIRTUAL_NAME} --resolution ${VIRTUAL_WIDTH}x${VIRTUAL_HEIGHT} --scale ${VIRTUAL_SCALE} --port 5999 --password ${VMON_PASS}
ExecStartPost=$HOME/.local/bin/position-virtual-display.sh
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=graphical-session.target
EOF
unset VMON_PASS
chmod 600 "$HOME/.config/systemd/user/virtual-second-screen.service"

# 3. Drop-in para o Sunshine iniciar após o monitor virtual existir
cat > "$HOME/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/10-virtual-second-screen.conf" <<EOF
[Unit]
After=virtual-second-screen.service
Wants=virtual-second-screen.service

[Service]
ExecStartPre=
ExecStartPre=/bin/sleep 2
EOF

# 4. Configuração otimizada do Sunshine
cat > "$HOME/.config/sunshine/sunshine.conf" <<EOF
sunshine_name = ${SUNSHINE_NAME}
address_family = both
capture = kwin
output_name = ${VIRTUAL_OUTPUT_NAME}
hevc_mode = 2
av1_mode = 0
nvenc_preset = 1
nvenc_twopass = disabled
nvenc_latency_over_power = enabled
nvenc_spatial_aq = disabled
sw_preset = superfast
sw_tune = zerolatency
min_threads = 4
fec_percentage = 5
lan_encryption_mode = 0
stream_audio = disabled
origin_web_ui_allowed = pc
system_tray = enabled
EOF

cat > "$HOME/.config/sunshine/apps.json" <<EOF
{
    "env": {
        "PATH": "\$(PATH):\$(HOME)/.local/bin"
    },
    "apps": [
        {
            "name": "${APP_NAME}",
            "image-path": "desktop.png",
            "auto-detach": "true",
            "wait-all": "true"
        }
    ]
}
EOF

# 5. Credenciais locais do Sunshine (sem navegador, sem imprimir senha)
if [ ! -f "$HOME/.config/sunshine/.local-auth" ]; then
    PASS=$(python3 -c 'import secrets; print(secrets.token_urlsafe(18))')
    umask 077
    printf 'pc:%s\n' "$PASS" > "$HOME/.config/sunshine/.local-auth"
    chmod 600 "$HOME/.config/sunshine/.local-auth"
    systemctl --user stop app-dev.lizardbyte.app.Sunshine.service 2>/dev/null || true
    sunshine "$HOME/.config/sunshine/sunshine.conf" --creds pc "$PASS" >/dev/null 2>&1
    unset PASS
fi

# 6. Firewall UFW (se ativo): libera portas do Sunshine apenas para redes locais
if command -v ufw >/dev/null 2>&1 && sudo -n ufw status 2>/dev/null | grep -q "Status: active"; then
    for net in $CLIENT_SUBNET $WIFI_SUBNET; do
        [ -n "$net" ] || continue
        sudo ufw allow from "$net" to any port 47984,47989,48010 proto tcp comment "Sunshine LAN" >/dev/null
        sudo ufw allow from "$net" to any port 47998:48000 proto udp comment "Sunshine LAN" >/dev/null
        sudo ufw allow from "$net" to any port 48002,48010 proto udp comment "Sunshine LAN" >/dev/null
    done
fi

# 7. Ativa e inicia serviços
systemctl --user daemon-reload
systemctl --user enable --now virtual-second-screen.service
systemctl --user enable --now app-dev.lizardbyte.app.Sunshine.service
sleep 4

echo "=== Verificação ==="
systemctl --user is-active virtual-second-screen.service app-dev.lizardbyte.app.Sunshine.service
kscreen-doctor -o | grep -E "Output:|Geometry:|priority|Color profile|Brightness"

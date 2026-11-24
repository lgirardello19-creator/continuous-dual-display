#!/usr/bin/env bash
# Cria conexão Ethernet Gigabit direta com IP estático sem alterar a rota padrão de internet.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
[ -f "$ROOT_DIR/.env" ] && source "$ROOT_DIR/.env"

ETH_IFACE="${ETH_IFACE:-enp4s0}"
ETH_CONN_NAME="${ETH_CONN_NAME:-Cabo-Segundo-Monitor}"
HOST_IP="${HOST_IP:-10.42.0.228}"

if ! command -v nmcli >/dev/null 2>&1; then
    echo "ERRO: nmcli (NetworkManager) não encontrado." >&2
    exit 1
fi

nmcli connection delete "$ETH_CONN_NAME" 2>/dev/null || true
nmcli connection add type ethernet ifname "$ETH_IFACE" con-name "$ETH_CONN_NAME" \
    ipv4.method manual \
    ipv4.addresses "${HOST_IP}/24" \
    ipv4.never-default yes \
    ipv4.ignore-auto-dns yes \
    ipv6.method link-local \
    ipv6.never-default yes \
    connection.autoconnect yes \
    connection.autoconnect-retries 0

nmcli connection up "$ETH_CONN_NAME"

echo "=== Interface e rotas ==="
ip -brief addr show "$ETH_IFACE"
ip route | head -n 4

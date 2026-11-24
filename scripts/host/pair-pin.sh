#!/usr/bin/env bash
# Aceita automaticamente um PIN de 4 dígitos pendente no Sunshine via API local (sem navegador).
set -euo pipefail

PIN="${1:-}"
CLIENT_NAME="${2:-SecondScreen}"
AUTH_FILE="${SUNSHINE_AUTH_FILE:-$HOME/.config/sunshine/.local-auth}"

if ! [[ "$PIN" =~ ^[0-9]{4}$ ]]; then
    echo "Uso: $0 <PIN_4_DIGITOS> [nome_cliente]" >&2
    exit 1
fi

if [ ! -f "$AUTH_FILE" ]; then
    echo "ERRO: arquivo de autenticação local não encontrado: $AUTH_FILE" >&2
    exit 1
fi

CREDS=$(cat "$AUTH_FILE")

PAIRING_ID=""
for _ in $(seq 1 30); do
    RESP=$(curl -sk -u "$CREDS" "https://127.0.0.1:47990/api/pin" 2>/dev/null || true)
    PAIRING_ID=$(printf '%s' "$RESP" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    ps = d.get("pairings") or []
    if ps:
        print(ps[-1].get("id", ""))
except Exception:
    pass
')
    if [ -n "$PAIRING_ID" ]; then
        break
    fi
    sleep 0.5
done

if [ -z "$PAIRING_ID" ]; then
    echo "ERRO: nenhuma solicitação de pareamento pendente no Sunshine" >&2
    exit 1
fi

PAYLOAD=$(python3 -c 'import json,sys; print(json.dumps({"pairing_id":sys.argv[1],"pin":sys.argv[2],"name":sys.argv[3]}))' "$PAIRING_ID" "$PIN" "$CLIENT_NAME")
OUT=$(curl -sk -u "$CREDS" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "https://127.0.0.1:47990/api/pin")

if printf '%s' "$OUT" | grep -q '"status":true'; then
    echo "PAREADO_OK"
else
    echo "FALHA_PAREAMENTO: $OUT" >&2
    exit 1
fi

---
name: continuous-dual-display
description: Configure a second computer/laptop as a low-latency, color-matched continuous extended monitor (left or right) for a primary PC using Virtual Display + Sunshine + Moonlight over direct Gigabit Ethernet or 5GHz Wi-Fi.
version: 1.0.0
---

# Skill: Continuous Dual Display (Host ↔ Second Device)

Use esta skill quando o usuário quiser conectar um notebook ou segundo PC como **monitor estendido contínuo** (esquerda/direita) com alta fluidez (60 fps, <5 ms), cores alinhadas e persistência por padrão.

## Arquitetura Padrão (Melhor Custo-Benefício Técnico)
- **Transporte:** Cabo Gigabit Ethernet direto com IP estático (`ipv4.never-default=yes`, sem gateway/DNS → internet continua no Wi-Fi) ou Wi-Fi 5/6 GHz.
- **Monitor Virtual (KDE Plasma 6 Wayland):** `krfb-virtualmonitor` (porta VNC bloqueada no firewall) + `kscreen-doctor` em serviço `systemd --user`.
- **Host Streaming:** **Sunshine** (`capture = kwin`, `address_family = both`, `hevc_mode = 2`, `nvenc_preset = 1`, `stream_audio = disabled`, DMA-BUF zero-copy).
- **Cliente:** **Moonlight Qt** (`1080p@60`, `80 Mbps` cabo / `30 Mbps` Wi-Fi, `HEVC`, `YUV 4:4:4`, `Fullscreen`, `V-Sync + Frame Pacing`).
- **Pareamento headless:** `sunshine --creds` (salvo `chmod 600`) + `moonlight pair --pin` + `POST /api/pin`.

## Fluxo Obrigatório
1. Leia [`AGENT_PLAYBOOK.md`](AGENT_PLAYBOOK.md) completo antes de executar.
2. Copie `config.env.example` → `.env` e preencha os valores reais detectados na Fase 0.
3. No Host: rode `scripts/host/setup-direct-ethernet.sh` (se houver cabo), `scripts/host/setup-host-kde-wayland.sh` e opcionalmente `scripts/host/calibrate-host-monitor.sh`.
4. No Cliente Linux: rode `scripts/client/setup-client-linux-moonlight.sh`.
5. Verifique todos os itens da Fase 6 do `AGENT_PLAYBOOK.md` com evidências reais.

## Regras Críticas
- **Sempre** usar `address_family = both` no Sunshine (evita `localhost` falhar por IPv6).
- **Nunca** rodar `redshift -P -O` sem `-c /dev/null -b 1.0` (pode escurecer a tela do cliente).
- **Nunca** commitar `.env`, `.local-auth`, `sunshine_state.json` ou chaves privadas.

# Continuous Dual Display (Tela Estendida Contínua Entre Dispositivos)

Guia técnico e scripts **prontos para agentes de IA** transformarem um notebook ou segundo computador em um **monitor estendido contínuo** (à esquerda ou à direita do PC principal), com **60 fps travados, latência sub-5 ms, cores alinhadas (YUV 4:4:4 Full Range) e inicialização automática padrão**.

> **Para usar com uma IA (Claude, Antigravity, Codex, Cursor, Hermes):**
> Envie este repositório para o seu agente de IA com o prompt:
> *"Leia `AGENT_PLAYBOOK.md` (ou `SKILL.md`) neste repositório e configure meu segundo dispositivo como monitor estendido contínuo à [esquerda/direita] do meu PC principal, mantendo salvo por padrão."*

---

## Por que Sunshine + Moonlight + Monitor Virtual?

Comparativo medido frente às alternativas comuns para usar um notebook como segunda tela estendida de um PC Linux/Windows:

| Solução | Monitor virtual no KDE Wayland | Latência / Fluidez | Fidelidade de Cor / Texto | Peso na CPU do Cliente |
|---|---|---|---|---|
| **Sunshine + Moonlight + Monitor Virtual** | **Nativo (`krfb-virtualmonitor` + KWin)** | **<5 ms, 60+ fps** (NVENC/VA-API) | **YUV 4:4:4 + Full Range (0–255), 80 Mbps** | Muito baixo (~3–5% com decode HW) |
| TwinDesk | Não cria sozinho no KDE Wayland | Média (WebRTC/Electron) | 4:2:0 | Alto (Electron) |
| Deskreen / Weylus | Não cria monitor virtual | Média/baixa (browser) | 4:2:0 | Alto (browser em tela cheia) |
| VNC puro (`krfb`) | Sim | Baixa em rolagem/vídeo | RGB | Médio/alto |
| KRDP | Espelha desktop, não estende isolado | Boa | 4:2:0 | Baixo |

---

## Arquitetura Recomendada

```text
┌───────────────────────────┐    Cabo Gigabit Ethernet direto (0.1–0.2 ms)    ┌───────────────────────────┐
│   CLIENTE (Notebook)      │ ◄═════════════ 10.42.0.x / 1000 Mbps ══════════ │   HOST (PC Principal)     │
│                           │     HEVC 4:4:4 Full Range @ 60fps / 80 Mbps     │                           │
│  • Moonlight Qt (VA-API)  │                                                 │  • Virtual Display (0,0)  │
│  • Tela cheia (esquerda)  │     (Internet continua normal pelo Wi-Fi,       │  • Monitor Físico (1920,0)│
│  • sRGB 6500K / 100% BL   │      cabo configurado com never-default=yes)    │  • Sunshine KWin + NVENC  │
└───────────────────────────┘                                                 └───────────────────────────┘
```

- **Zero impacto na internet:** o cabo Ethernet direto usa IP estático (`ipv4.never-default=yes`, sem gateway/DNS), mantendo a internet no Wi-Fi.
- **Zero popup de permissão:** no KDE Plasma 6 Wayland, o Sunshine usa `capture = kwin` com **DMA-BUF zero-copy** direto da GPU.
- **Zero navegador / zero PIN manual:** credenciais locais geradas via CLI (`sunshine --creds`) e pareamento automático via `moonlight pair --pin` + `POST /api/pin`.
- **Salvo por padrão:** serviços `systemd --user` no Host e autostart + atalho no Cliente.

---

## Estrutura do Repositório

- [`AGENT_PLAYBOOK.md`](AGENT_PLAYBOOK.md) — Playbook passo a passo determinístico para agentes de IA (descoberta, instalação por OS/compositor, rede, pareamento headless, calibração de cores/brilho, armadilhas reais e verificação).
- [`SKILL.md`](SKILL.md) — Versão compacta no formato padrão de Skill para agentes.
- [`config.env.example`](config.env.example) — Variáveis parametrizadas do ambiente.
- [`scripts/host/`](scripts/host/) — Scripts para o PC principal (Host):
  - `setup-direct-ethernet.sh` — Link Gigabit direto estático sem roubar rota de internet.
  - `setup-host-kde-wayland.sh` — Monitor virtual persistente + Sunshine NVENC/KWin + UFW local + credenciais CLI.
  - `position-virtual-display.sh` — Posiciona o monitor virtual à esquerda ou direita do principal.
  - `pair-pin.sh` — Aceita PIN de pareamento via API local do Sunshine sem abrir navegador.
  - `calibrate-host-monitor.sh` — Calibra o monitor principal (6500K, contraste neutro, brilho alvo, sRGB) via DDC/CI + KScreen.
- [`scripts/client/`](scripts/client/) — Scripts para o notebook/segundo dispositivo (Cliente Linux):
  - `setup-client-linux-moonlight.sh` — Instala Moonlight AppImage (sem `sudo`/Flatpak), configura HEVC 4:4:4 Fullscreen 80 Mbps, cria autostart/atalho e pareia automaticamente.
  - `reset-client-color-safe.sh` — Limpa curvas de gama/redshift e restaura brilho/gama 100% no X11 com segurança.

---

## Licença

MIT

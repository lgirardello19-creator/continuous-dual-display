# Agent Playbook: Duas Telas Contínuas Entre Dispositivos Diferentes

Este documento foi escrito para ser executado diretamente por um **agente de IA** (Claude Code, Codex, Antigravity, Hermes, Cursor, etc.). Ele consolida toda a arquitetura, comandos de diagnóstico, adaptação por SO/compositor, calibração de cores/brilho e **armadilhas reais validadas em campo**.

---

## Regra Geral de Execução para a IA

1. **Nunca assuma o hardware/SO** — rode primeiro a Fase 0 (Descoberta) antes de instalar ou configurar qualquer coisa.
2. **Nunca imprima senhas, tokens ou chaves** em logs ou respostas.
3. **Nunca altere a rota padrão de internet do usuário** ao configurar cabo Ethernet direto (`ipv4.never-default=yes` e `ipv4.ignore-auto-dns=yes` obrigatórios).
4. **Valide cada etapa com evidência real** (saída de comando) antes de declarar pronto.

---

## Fase 0 — Descoberta do Ambiente (Host e Cliente)

Execute no **Host** (PC principal):

```bash
echo "OS:"; cat /etc/os-release | head -n 4
echo "SESSION: $XDG_SESSION_TYPE / $XDG_CURRENT_DESKTOP"
echo "GPU:"; lspci | grep -iE 'vga|3d|display'
echo "OUTPUTS:"; kscreen-doctor -o 2>/dev/null || wlr-randr 2>/dev/null || xrandr --query 2>/dev/null | grep " connected"
echo "NET:"; ip -brief addr
echo "CARRIER:"; for n in /sys/class/net/e*; do [ -e "$n" ] && echo "$(basename "$n"): carrier=$(cat "$n/carrier" 2>/dev/null) speed=$(cat "$n/speed" 2>/dev/null)"; done
```

Decisões derivadas da descoberta:
- **Transporte:** se houver cabo Ethernet direto com `carrier=1` e `speed=1000`, use-o (`STREAM_BITRATE_KBPS=80000`, `lan_encryption_mode=0`, `fec_percentage=5`). Sem cabo, use Wi-Fi 5/6 GHz (`STREAM_BITRATE_KBPS=30000`, `fec_percentage=20`).
- **Criação de Monitor Virtual no Host:**
  - **KDE Plasma 6 Wayland (testado ponta-a-ponta):** `krfb-virtualmonitor` + `kscreen-doctor` + Sunshine `capture = kwin`.
  - **GNOME Wayland:** Mutter virtual monitor (`xdg-desktop-portal` ScreenCast) + Sunshine `capture = portal`.
  - **wlroots (Hyprland/Sway):** `hyprctl output create headless` / `swaymsg create_output` + Sunshine `capture = kms` ou `wlr`.
  - **Linux X11 (AMD/Intel):** saída livre / dummy plug + `xrandr`. Em NVIDIA X11, prefira dummy plug HDMI/DP ou migração para Wayland.
  - **Windows Host:** [Virtual Display Driver (IddSampleDriver / MTT)](https://github.com/VirtualDrivers/Virtual-Display-Driver) + Sunshine `capture = ddx`.
- **Encoder no Host:**
  - **NVIDIA RTX/GTX:** deixe `encoder =` (autodetect -> prioriza `nvenc` com `hevc_nvenc` + `h264_nvenc` + CUDA DMA-BUF zero-copy).
  - **AMD/Intel:** `vaapi` (Linux) ou `amf`/`quicksync` (Windows).
  - **Fallback automático:** `sw_preset = superfast`, `sw_tune = zerolatency`.

---

## Fase 1 — Rede Dedicada de Baixa Latência (Cabo Gigabit Direto)

Se o Host e o Cliente estiverem ligados por um cabo Ethernet direto:
1. No Cliente (ou no Host), a interface pode já usar compartilhamento do NetworkManager (`10.42.0.1`).
2. No Host, configure uma conexão Ethernet dedicada com **IP estático** (`10.42.0.228/24`, **sem gateway e sem DNS**), para nunca depender de DHCP nem derrubar a internet Wi-Fi:
   ```bash
   cp config.env.example .env
   # Edite .env com ETH_IFACE, HOST_IP, PRIMARY_OUTPUT, VIRTUAL_SIDE etc.
   bash scripts/host/setup-direct-ethernet.sh
   ```
3. **Verificação obrigatória:**
   - `ip route` deve manter `default via ... dev wlan0` (ou interface de internet original).
   - `ping -c 3 <IP_DO_CLIENTE>` deve retornar `< 1 ms` e `0% packet loss`.

---

## Fase 2 — Configurar o Host (KDE Plasma 6 Wayland + Sunshine)

1. Instale `sunshine` e `krfb` (Arch/CachyOS: `sudo pacman -S --needed sunshine krfb`; Fedora: `dnf install krfb` + Sunshine; Ubuntu/Debian: `apt install krfb` + Sunshine `.deb`).
2. Rode:
   ```bash
   bash scripts/host/setup-host-kde-wayland.sh
   ```
   O script:
   - Instala `~/.local/bin/position-virtual-display.sh` e o serviço persistente `systemd --user` `virtual-second-screen.service` (roda `krfb-virtualmonitor` na porta `5999` bloqueada no firewall).
   - Posiciona o monitor virtual exatamente à esquerda (`0,0`, `priority 2`) ou direita (`PRIMARY_WIDTH,0`, `priority 2`) do monitor principal (`priority 1`).
   - Grava `~/.config/sunshine/sunshine.conf` com:
     - `address_family = both` (**crítico:** evita falha de acesso a `https://localhost:47990` em sistemas onde `localhost` resolve para `::1` primeiro).
     - `capture = kwin` + `output_name = Virtual-<VIRTUAL_NAME>` (DMA-BUF zero-copy, zero popup de permissão).
     - `hevc_mode = 2` (habilita HEVC SDR 8/10-bit e YUV 4:4:4).
     - `nvenc_preset = 1`, `nvenc_twopass = disabled`, `nvenc_latency_over_power = enabled`.
     - `stream_audio = disabled` (mantém áudio apenas no PC principal, evitando eco no notebook).
     - `origin_web_ui_allowed = pc` (painel Web UI restrito a localhost).
   - Gera credenciais locais do Sunshine via CLI (`sunshine --creds`, salvas com `chmod 600` em `~/.config/sunshine/.local-auth`) — **elimina a necessidade de abrir navegador**.
   - Instala `~/.local/bin/pair-sunshine-pin.sh` para pareamento headless via `POST https://127.0.0.1:47990/api/pin`.
   - Libera no UFW apenas as portas do Sunshine (`47984,47989,48010/tcp`, `47998:48000,48002,48010/udp`) restritas às sub-redes locais (`CLIENT_SUBNET` / `WIFI_SUBNET`), mantendo a porta `5999` do `krfb` **fechada**.
   - Cria drop-in systemd no Sunshine (`After=virtual-second-screen.service`, `Wants=virtual-second-screen.service`) e ativa ambos no boot.

3. **Verificação obrigatória no Host:**
   - `systemctl --user is-active virtual-second-screen.service app-dev.lizardbyte.app.Sunshine.service` → ambos `active`.
   - `kscreen-doctor -o` → monitor virtual na posição correta (`0,0` à esquerda; principal em `1920,0`, `priority 1`).
   - `tail -n 50 ~/.config/sunshine/sunshine.log` → `Found HEVC encoder: hevc_nvenc [nvenc]` (ou VAAPI/software) e `[pipewire] using DMA-BUF buffers`.
   - `GET https://127.0.0.1:47990/api/pin` autenticado → `HTTP 200`.

---

## Fase 3 — Configurar o Cliente (Moonlight) e Pareamento Automático

### Cliente Linux (Mint, Ubuntu, Arch, Fedora)
Execute no Cliente (ou puxe do Host via SSH se já houver chave configurada):
```bash
bash scripts/client/setup-client-linux-moonlight.sh
```
O script:
- Baixa e extrai o `Moonlight-x86_64.AppImage` oficial (~51 MB) para `~/.local/opt/moonlight` (evita dependência de `libfuse2` e economiza espaço de runtimes Flatpak).
- Grava `~/.config/Moonlight Game Streaming Project/Moonlight.conf` com chaves exatas do `moonlight-qt v6.2.0`:
  - `width=1920`, `height=1080`, `fps=60`, `bitrate=80000`, `unlockbitrate=true`, `autoadjustbitrate=false`
  - `videocfg=2` (`HEVC`), `videodec=0` (`Auto` → usa VA-API/QuickSync hardware com fallback seguro), `yuv444=true`, `hdr=false`
  - `windowmode=0` (`Fullscreen`), `vsync=true`, `framepacing=true`
  - `hostaudio=true`, `muteonfocusloss=true`, `capturesyskeys=0`, `mouseacceleration=true`, `keepawake=true`
- Cria lançador `~/.local/bin/second-screen-connect.sh`, **autostart padrão** (`~/.config/autostart/second-screen.desktop`) e **atalho na Área de Trabalho**.
- **Pareamento automático sem navegador:** gera um PIN de 4 dígitos, executa `moonlight pair --pin <PIN> <HOST_IP>` e aciona `~/.local/bin/pair-sunshine-pin.sh <PIN>` no Host (via SSH quando disponível; caso contrário imprime o PIN para aceitar no Host via `pair-sunshine-pin.sh <PIN>`).

### Cliente Windows / macOS
1. Instale o [Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt/releases).
2. Configure: `1080p` (ou nativa), `60 fps`, `80 Mbps` (cabo) / `30 Mbps` (Wi-Fi), `HEVC`, `YUV 4:4:4`, `Fullscreen`, `V-Sync`, `Frame Pacing`, `Play audio on host PC`, `Optimize mouse for remote desktop`.
3. Pareie com `<HOST_IP>` e aceite o PIN no Host executando `~/.local/bin/pair-sunshine-pin.sh <PIN>`.
4. Abra o app **Monitor Estendido**.

---

## Fase 4 — Calibração Segura de Cores e Brilho ("Tela Infinita")

O objetivo é fazer dois painéis físicos diferentes parecerem uma única tela contínua:

1. **Mesmo espaço de cor e faixa dinâmica:**
   - **Host:** `Color profile source = sRGB` no monitor principal; Sunshine já transmite em `Color range: JPEG` (Full Range 0–255) + `YUV 4:4:4`.
   - **Monitor físico do Host (via `ddcutil`):** ajuste para o ponto branco neutro **`6500 K`** (`VCP 0x14 = 0x05`), **contraste neutro** (`VCP 0x12 = 80`) e **brilho equilibrado** em nits com o painel do notebook (ex.: monitor 250 nits em `90%` casa com notebook ~220 nits em `100%`). Use `scripts/host/calibrate-host-monitor.sh`.
   - **Cliente:** `xrandr --output <PANEL> --brightness 1.0 --gamma 1.0:1.0:1.0`, backlight em `100%` (ou ajustado para igualar visualmente ao monitor físico).
2. **Alinhamento de Luz Noturna (Night Light ↔ Redshift):**
   - No KDE Plasma 6 Wayland, o KWin ScreenCast captura o framebuffer **antes** do Night Light.
   - **Se o Night Light do PC estiver DESLIGADO/PAUSADO (`6500 K`):** desligue o `redshift` no cliente (`redshift -x`), caso contrário uma tela fica branca (`6500 K`) e a outra laranja (`2200 K`).
   - **Se o Night Light do PC estiver LIGADO (ex.: `2200 K`):** mantenha o `redshift` do cliente na **mesma temperatura** e **sempre com `-c /dev/null -b 1.0`** (nunca deixe `redshift` ler arquivos antigos com brilho reduzido!).

---

## Fase 5 — Armadilhas Reais Descobertas em Campo (NÃO REPETIR!)

1. **`https://localhost:47990` inacessível no navegador:**
   - *Causa:* por padrão o Sunshine escuta só em IPv4 (`0.0.0.0:47990`), mas `/etc/hosts` resolve `localhost` para IPv6 (`::1`) primeiro.
   - *Solução:* sempre definir `address_family = both` em `sunshine.conf`.
2. **Notebook ficou sem brilho após rodar `redshift -P -O`:**
   - *Causa:* chamar `redshift -P -O <TEMP> -g <GAMMA>` **sem `-c /dev/null` e sem `-b 1.0`** carrega `~/.config/redshift.conf` existente (que pode derrubar brilho/LUT do X11) e valores de gama `< 1.0` escurecem muito o painel.
   - *Solução:* nunca aplique gama agressiva sem testar com o usuário olhando; para recuperar imediatamente rode `scripts/client/reset-client-color-safe.sh` (`redshift -x` + `xrandr --brightness 1.0 --gamma 1.0:1.0:1.0` + backlight 100%).
3. **Cabo Ethernet direto perde o IP ou rouba a internet:**
   - *Causa:* conexão DHCP (`ipv4.method=auto`) perde o lease ou assume rota padrão quando conectada.
   - *Solução:* usar conexão dedicada no NetworkManager com `ipv4.method manual`, IP fixo, `ipv4.never-default yes`, `ipv4.ignore-auto-dns yes`, `connection.autoconnect-retries 0`.
4. **NVENC falha com `CUDA_ERROR_ALREADY_ACQUIRED` / `NV_ERR_STATE_IN_USE`:**
   - *Causa:* sessão de boot anterior com OOM-kill em carga pesada de CUDA/jogo deixou o GSP firmware da NVIDIA sem canais livres.
   - *Solução:* deixar `encoder =` vazio (autodetect) no `sunshine.conf` com `sw_preset = superfast` e `sw_tune = zerolatency` como fallback; após reiniciar o Host, o NVENC volta automaticamente em hardware.
5. **Stream não abre no final de um script rodado via `ssh ... | bash`:**
   - *Causa:* `nohup ... &` lançado dentro de subshell/pipe pode ser encerrado ao fechar o terminal do agente.
   - *Solução:* o atalho de Área de Trabalho + autostart `.desktop` garantem abertura limpa na sessão gráfica; para testar via terminal, use `systemd-run --user` ou clique no atalho.
6. **Pareamento Moonlight ≠ acesso remoto ao SO do cliente:**
   - O pareamento Sunshine/Moonlight envia vídeo do Host → Cliente; ele não abre shell no Cliente. Se a IA no Host precisar administrar o Cliente depois, o Cliente precisa ter `openssh-server` habilitado.

---

## Fase 6 — Checklist Final de Verificação (Evidências)

Antes de encerrar, confirme com saída real:
- [ ] `kscreen-doctor -o`: monitor virtual na posição pedida (`left`/`right`) e monitor físico como primário (`priority 1`).
- [ ] `systemctl --user is-active`: serviço do monitor virtual + Sunshine `active` e `enabled`.
- [ ] `GET /api/clients/list` no Sunshine: cliente listado com `"enabled": true`.
- [ ] `nvidia-smi --query-gpu=encoder.stats.sessionCount,encoder.stats.averageFps`: `sessionCount >= 1` quando conectado (ou log `hevc_nvenc` / `VAAPI` ativo).
- [ ] `ip route`: rota padrão de internet intacta (Wi-Fi/WAN), cabo direto apenas na sub-rede local com `< 1 ms`.
- [ ] `ufw status`: portas Sunshine liberadas apenas para LAN/cabo; porta `5999` do `krfb` fechada.
- [ ] Ambas as telas na mesma temperatura de cor (`6500 K` ou Night Light alinhado) e brilho equilibrado.

---

## Atalhos Úteis no Cliente (Moonlight)

- `Ctrl + Alt + Shift + Q` — sair da tela cheia / encerrar sessão de vídeo.
- `Ctrl + Alt + Shift + M` — alternar captura do mouse se clicar dentro da janela no notebook.
- `Ctrl + Alt + Shift + S` — exibir/ocultar overlay de estatísticas (FPS, bitrate, latência de rede e decode).

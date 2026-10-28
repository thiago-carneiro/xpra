# Relatório de candidatos a otimização — xpra 6.5.5 (análise estática)

Data: 2026-10-20 · Base: worktree `/tgdesenv/src/proj0/u4w7/src/external/xpra-655` (v6.5.5 @ a2b94688)
Método: 4 assentos read-only por área (pipeline de desenho, rede/protocolo, UI thread/timers, servidor encode/batch).
**Rótulo geral: TODOS os itens são hipóteses estáticas — nenhum ganho foi medido. A verificação é a próxima fase.**

## P0 — Verificar primeiro (comandos baratos, podem explicar tudo sozinhos)

- **V1. Fast-path nativo ausente → fallback YAML silencioso** [não verificado no install do usuário]: `xpra/net/packet_encoding.py:42-49` tenta `rencodeplus` (Cython) e cai em yaml.dump/load por packet se o `.pyd` faltar; idem lz4 pyx em `xpra/net/compression.py:43-56`. Degradação de ordem de grandeza em TODA a sessão, invisível (log debug). Verificação (1 comando no Windows): `xpra.exe info | grep -iE "encoder|compressor"` ou procurar `rencodeplus*.pyd`/`lz4*.pyd` na instalação. Se ausente → reinstalar o wheel oficial resolve sem código.
- **V2. Qual backend o cliente usa?** GTK3+OpenGL (padrão) vs cliente nativo win32 (PoC 2025). Define se os itens A2/A6 (nativo) ou A1/A3/A5 (GTK) dominam. Verificação: qual .exe o usuário lança (Xpra.exe vs Xpra_cmd/GTK) + `xpra info`.
- **V3. Fallback de vídeo para PIL por frame** (lado servidor): pipeline falho → `video_fallback()` avisa só uma vez por wid e re-tenta `check_pipeline` A CADA FRAME (`xpra/server/window/video_compress.py:2492-2546`, `2403-2430`). Verificação: log `video fallback:` debug; `client_options["encoder"]="fallback:..."`.

## Candidatos cliente (GTK3/OpenGL — caminho primário do usuário)

| # | Local | Mecanismo | Impacto (hipótese) | Verificação | Risco/Esf. |
|---|---|---|---|---|---|
| A1 | `client/gtk3/opengl/glarea_backing.py:104-106` + `opengl/backing.py:959,885-887` | Loop de apresentação GL se reagenda sozinho (`queue_render()`) a cada frame-clock tick, mesmo idle; double-buffer pinta a janela toda por tick | ALTO — CPU/GPU constante em idle ("pesado") | py-spy no cliente idle; logar `gl_show` com tela parada; comentar `queue_render` e medir ΔCPU | baixo/médio |
| A3 | `cairo/image.pyx:142-148` + `cairo/backing.py:41-56` (via `gui/window/backing.py:639-642` idle_add) | Zero-copy `create_for_data` inatingível p/ dados de rede (bytes readonly) → aloca+converte superfície por frame na UI thread | MÉDIO-ALTO (só backend cairo) | py-spy UI thread; comparar `--opengl=yes/no` | médio/médio |
| A5+B4 | `client/subsystem/window/draw.py:42-49,97-107` | UMA draw-thread para todas as janelas: decode grande de uma janela atrasa paints/acks das demais → servidor reduz taxa globalmente | MÉDIO-ALTO (multijanela) | `-d draw`: `decode_time` vs defasagem de fila; instrumentar backlog da `_draw_queue` | alto/médio (GIL limita) |
| A4 | `opengl/backing.py:499-510,1836-1840,1146-1152,982-985` | VBO novo criado e deletado a cada frame de shader (vídeo/upscale) | MÉDIO (churn, driver-dependente) | renderdoc/frame trace contando glGenBuffers/s | baixo/baixo |
| B1 | `net/packet_encoding.py:167-174` | `memoryview.tobytes()` copia o payload inteiro antes do decode | MÉDIO (0.3–1ms por draw grande) | py-spy parse-thread; contar tipos em `decode()` | baixo/baixo |
| B2 | `net/protocol/socket_handler.py:1110-1128` | 2 fatias-cópia por packet quando o read de 64KB contém >1 packet | MÉDIO-BAIXO | contadores `input_raw_packetcount`; strace memcpys | médio/médio |
| B6 | `socket_handler.py:133,79-89` | Write-queue `Queue(1)`: 1 packet em voo, wakeups por packet, sem coalescência de packets pequenos (o servidor tem batching; o cliente não) | BAIXO-MÉDIO (churn sob rajada de input) | `perf sched`/ETW; testar `XPRA_PACKET_JOIN_SIZE` | médio/médio |

## Candidatos cliente nativo win32 (só se V2 = nativo)

| # | Local | Mecanismo | Impacto (hipótese) |
|---|---|---|---|
| A2 | `client/win32/window.py:496-506` + `gdi_backing.py:95-97` | `InvalidateRect(hwnd, None, True)` + BitBlt da JANELA INTEIRA por WM_PAINT, independente do dano | ALTO p/ janelas grandes |
| A6 | `client/win32/gdi_backing.py:133-139` | Caminho por-linha em Python (2 ctypes por linha) em todo paint não alinhado | MÉDIO |

## Candidatos servidor (afetam a percepção de lentidão do cliente)

| # | Local | Mecanismo | Impacto (hipótese) | Verificação |
|---|---|---|---|---|
| D1 | `batch_config.py:48-52` + `window_source.py: compress 1693-1703` | Batching reativo: congestão/resize adicionam até +250ms por 1s; `min_delay` cresce com fila | ALTO p/ "lento" durante uso | `xpra info` → `batch.delay`; log damage; A/B `XPRA_BATCH_MAX_DELAY=100` |
| D2 | `batch_delay_calculator.py:262-302` | Sem cap de banda/congestão, target=1 → delay≈16ms → encode full-frame contínuo (CPU do servidor saturada) | ALTO p/ "pesado" | CPU por wid; A/B com cap |
| D4 | `video_compress.py:1085-1090,1119-1137` + `1750` | Fila av-sync segura até 30 imagens full-window RGB ≈ 250MB/janela + latência | MÉDIO-ALTO (memória) | `xpra info` → `av_sync`; `XPRA_AV_SYNC_DEFAULT` |
| D5 | `video_compress.py:1780-1823,1280` | Heurística liga downscale cedo; cada mudança de escala destrói/recria o pipeline | MÉDIO | `xpra info` → `scaling=`; A/B `XPRA_SCALING=0` |
| D6 | `video_subregion.py:339-391` | Identificação de região O(N·rects) a cada ≥10 damage events + refresh/setup ao mudar | BAIXO-MÉDIO | log subregion; A/B `XPRA_VIDEO_SUBREGION=0` |

## Startup / idle (parcial — área C teve grep indisponível; retry pendente)

- C1: `platform/win32/gui.py:63-71,89` — ctypes `libgdk-3-0.dll` + COM (propsys) importados no import do módulo → custo de startup [hipótese].
- C2: `POLL_LAYOUT` ~10s polling de layout de teclado — idle menor.
- Negativos confirmados: cursor é server-push (sem polling cliente); ping default off; tray trivial.
- **Pendências de varredura** (retry recomendado): `spinner.py`, `window_hooks.py` (WM_TIMER/alocações por evento), fila de eventos serializada, e o sintoma **órfãos** — lado servidor encode NÃO spawn subprocessos (`Popen` só em evdi load e probe nvidia); a fonte dos órfãos está no lado cliente win32 ou em outro caminho — investigação própria.

## Temas transversais

1. **Degradação silenciosa é o tema dominante** (V1, V3, e o fallback cairo A3): falhas de ambiente viram lentidão permanente sem alerta. Antes de otimizar código, eliminar fallbacks com verificação de ambiente.
2. **Config antes de código**: D1/D2/D4/D5/D6 têm knobs de env — um "plano de tuning" sem tocar no código pode resolver boa parte do sintoma.
3. **Padrão de contribuição upstream** (do painel de docs): micro-PR com teste; candidatos de código (A1, A4, B1, B2) são do tamanho certo.

## Plano de verificação (fase seguinte, quando autorizado)

1. No Windows do usuário (5 min): V1, V2, `xpra info` (batch.delay, av_sync, scaling, encoder/compressor), CPU idle com OpenGL on/off.
2. Em par local controlável (Linux, este host): servidor + cliente GTK3 → py-spy/perf nos candidatos A1, A3, A5, B1/B2; A/B de envs D1/D2.
3. Só depois de números: priorizar mudanças de código e/ou knobs de config, com baseline/medida por item (performance-pipeline: medir antes de otimizar).

---

## Medições realizadas (28/10/2026) — host Linux, xpra 6.5.2 do sistema

Transferabilidade provada: `xpra/net/packet_encoding.py`, `xpra/net/compression.py` e `xpra/server/window/batch_delay_calculator.py` são **byte-idênticos** (md5) entre o install 6.5.2 e o worktree v6.5.5. Interpreter `/usr/bin/python3.12`; `rencodeplus` (Cython 1.0.10) presente; `yaml` ausente.

### Encoder real (rencodeplus) — corrige a medição inválida da 1ª rodada

| payload | encoded B | ratio | encode med µs | decode med µs |
|---|---|---|---|---|
| controle | 59 | — | 1.8 | 0.7 |
| 64KB | 65.606 | 1.001 | 4.4 | 2.9 |
| 1MB | 1.048.648 | 1.000 | 59.2 | 33.0 |
| 4MB | 4.194.376 | 1.000 | 264.1 | 278.8 |

Round-trip verificado (campo `draw` byte-equal em 64KB; comprimento em 1/4MB). Contraste: encoder `none` = 45B para qualquer payload (não serializa). Artefatos: `/tgdesenv/src/proj0/u4w7/home2/tmp/xpra-bench/bench_rencodeplus.{json,md,py}`.

### Achado estrutural: o payload de draw é OUT-OF-BAND

- **Send** (`xpra/net/protocol/socket_handler.py`): item `Compressed` com `can_inline=False` ou > `INLINE_SIZE=32768` (linha 703) é fatiado — `packets.append((0, i, il, item.data))` (710) e placeholder `packet[i]=b''` (711); só o stub passa pelo rencodeplus (`do_encode`, 737); cada chunk ganha header próprio (527-568). Docstring 650-665.
- **Receive**: chunks com index>0 ficam **crus** em `raw_packets` (1167-1180, nunca decodificados); o stub index-0 é decodificado (1183); chunks remontados por índice (1206-1211); descompressão de rede só se `level>0` (1141-1143).
- **Seleção**: `TRY_ENCODERS=(rencodeplus,yaml,none)` (`packet_encoding.py:25`); `enable_encoder_from_caps` (596-609) escolhe o primeiro em `PERFORMANCE_ORDER` anunciado → rencodeplus quando presente.

### Consequências para o ranking (correções)

- **B1 (cópia memoryview→bytes antes do decode): REBAIXADO** — draws não passam pelo decoder (out-of-band). O custo medido da cópia (4MB = 243µs; 1MB = 34µs) não incide no caminho de draw; vale para packets in-band (clipboard, file transfer, stubs).
- **B3 (fallback YAML): REFUTADO como risco prático** — yaml não está instalado neste build; o fallback real seria `none` (sem serialização). A checagem no install do usuário segue válida como diagnóstico, mas deixa de ser prioridade.
- **B2 (padrão de cópia do read path): PROMOVIDO** — o wire path fatia um frame de 4MB em ~128 chunks de 32KB (`INLINE_SIZE`), cada um com header próprio; o read path processa centenas de mini-packets por frame — exatamente o cenário denso onde o padrão de slicing copia ~90-162× o tamanho do stream e a alternativa com offsets é **24× mais rápida** (473,7µs → 19,8µs por leitura de 128KB).
- **Novo candidato N2 — overhead por chunk**: header por chunk (527-568), tupla+append por chunk e splice por índice na recepção (1206-1211). Medir: nº de chunks por frame e custo do splice; A/B com `INLINE_SIZE` maior.
- `memoryview_to_bytes`: 1MB 34.1µs; 4MB 243.5µs (só relevante in-band).

---

## Verificação (28/10/2026, tarde) — harpia-dev1 + cliente Windows 6.5.5

Detalhes, tabelas e scripts em `verification-2026-10-28.md` / `verification-2026-10-28/`. Estado dos candidatos
após a medição:

| item | veredito | evidência |
|---|---|---|
| V1 fast-path nativo | **presente** | `.pyd` de rencodeplus/lz4 no 6.5.5; servidor vê `encoder=rencodeplus`, `compressor=lz4` |
| V2 backend | **GTK3 + OpenGL** (win32 só como backend de contexto GL) | log do cliente; `Xpra_cmd.exe opengl` safe/zerocopy |
| V3 fallback de vídeo | n/a neste build | cliente Windows não tem decoders de vídeo (`encodings.core` = webp/png/avif/rgb/jpeg); nenhuma chave `fallback` |
| A1 loop GL em idle | **REFUTADO** | 30 s idle: +0 `do_gl_show`/`on_render`; CPU 0,23 % (Linux), 0,8–0,9 % (Windows) |
| A3 superfície cairo por frame | **CONFIRMADO, maior que o estimado** | buffer readonly → ramo lento: 274 µs (RGB24) / 1,42 ms (ARGB32) por frame 1080p, 6,3 ms em 4K; 1 µs se writable; memcpy = 183 µs |
| N2 overhead por chunk | **CAI** | item > INLINE_SIZE sai como 1 pacote raw + stub de 44 B (2 pacotes para 64 KB, 1 MB e 4 MB); `encode()` = 5,6 µs |
| B2 cópias no read path | válido em 6.5.x, **já corrigido no master** | `read_exact`/`recv_into` (commit `1d4b31b139`, 2026-05-25, #4873), ausente na branch 6.5.x |
| D1 batching reativo | **sem efeito em LAN** | `XPRA_BATCH_MAX_DELAY=100` não muda o delay (nunca chegou perto de 500) |
| D2 servidor saturado | **não observado** | 13 % de um core sob xterm rolando |
| A5/B4 draw thread única | ver seção do par Linux em `verification-2026-10-28.md` | |

A correção mais importante é na premissa de B2/N2: o payload de draw **não** é fatiado em 32 KB; `INLINE_SIZE` só
decide inline vs. out-of-band, e o out-of-band é um único pacote raw.

# Verificação dos candidatos pendentes — 28/10/2026

Fase de verificação do `perf-report.md` (itens que a sessão anterior não pôde medir por falta de
PyGObject/X server) mais o plano de 5 minutos no Windows do usuário (V1, V2, `xpra info`, CPU idle
com OpenGL on/off).

**Rótulo geral: medições reais, mas em cenário sintético (xterm rolando `yes`, xclock) e em LAN.
Os números servem para confirmar/refutar mecanismos, não para prever ganho no uso diário.**

## Ambiente

| lado | detalhe |
|---|---|
| Servidor | harpia-dev1 = gr15sdes01, RHEL 8.10, xpra 6.5.2-10.r0 (python3.12), Xorg 1.20 + `xorg-x11-drv-dummy` (pacote xpra1), AMD EPYC 9334 ×128 |
| Cliente Linux | mesmo host, display dummy `:178` (xpra start), GL via llvmpipe (greylisted; `--opengl=force`), PyGObject 3.28, pycairo 1.23, PyOpenGL 3.1.10 |
| Cliente Windows | Xpra 6.5.5-r0 (`Xpra_cmd.exe attach ssh://…/179`), Windows 11, Intel Iris Xe, OpenGL 4.6 backend win32, cpython 3.14 |
| Sessões | `:177` (par Linux), `:178` (host do cliente Linux), `:179` (cliente Windows), todas com `xterm` inicial |
| Medição de CPU | `cpu_sample.sh` (utime+stime de `/proc/PID/stat` em janela fixa) no Linux; `TotalProcessorTime` em janela fixa no Windows. % = fração de **um** core |

Transferabilidade: os módulos exercitados foram comparados por md5 entre o 6.5.2 instalado, a tag `v6.5.5`
e o `master` do clone (ver seção B2 para a diferença relevante).

## Windows (plano de 5 minutos)

- **V1 — fast-path nativo: PRESENTE.** `lib/xpra/net/rencodeplus/rencodeplus.cp314-mingw_x86_64_msvcrt_gnu.pyd` e
  `lib/xpra/net/lz4/lz4.cp314-….pyd` existem; o servidor confirma `client.0.connection.encoder=rencodeplus`,
  `compressor=lz4`. (`yaml` também está empacotado, mas não é selecionado.)
- **V2 — backend: GTK3 + OpenGL.** O log diz `xpra GTK3 client version 6.5.5-r0`; `OpenGL 4.6 enabled on
  'Intel(R) Iris(R) Xe Graphics'`, `using native win32 backend` (isto é o backend de *contexto GL*, não o cliente
  nativo win32 — `lib/xpra/client/win32/` existe mas não é o caminho usado). `Xpra_cmd.exe opengl`: `safe=True`,
  `zerocopy=True`, `renderer=Intel(R) Iris(R) Xe Graphics`. Conclusão: valem os candidatos A1/A3/A5, não A2/A6.
- **`xpra info` (servidor :179 com o cliente Windows):** `batch.min-delay=33`, `batch.max-delay=500`,
  `av-sync.enabled=False`, `scaling=(1, 1)`, nenhuma chave `fallback`. `encodings.core` do cliente Windows =
  webp, png, png/P, png/L, avif, rgb24, rgb32, jpeg, jpega — **sem h264/vp8/vp9**: este build não decodifica vídeo,
  então tudo chega como webp/jpeg/rgb (relevante para A5 e para o custo de decode por frame).
- **CPU do cliente Windows** (janelas de 20–30 s; "carga" = `xterm -geometry 200x60 -e yes` na sessão, ~1000
  pacotes draw em ~36 s):

| cenário | opengl=no (cairo) | opengl=yes (GL) |
|---|---|---|
| idle, 1 xterm parado (1ª rodada) | 0,47 % | 0,94 % |
| idle (2ª rodada) | 0,39 % | 0,78 % |
| carga (1ª rodada) | 11,6 % (batch.delay≈86 ms) | 27,6 % (batch.delay≈16 ms) |
| carga (2ª rodada) | 28,9 % (1115 draws, batch.delay avg 29) | 22,7 % (1005 draws, batch.delay avg 23) |

  Leitura: **em idle não há loop ativo em nenhum dos backends** (A1 refutado também no Windows). Sob carga, a
  variação entre rodadas (11,6 % vs 28,9 % para cairo) vem do servidor ter escolhido taxas diferentes
  (batch.delay 86 vs 29 ms); por frame entregue, cairo custa mais que GL (2ª rodada: 28,9 %/1115 vs 22,7 %/1005
  ≈ +15 % por draw), coerente com o microbenchmark A3 abaixo.

- **D1 A/B (`XPRA_BATCH_MAX_DELAY=100` no servidor :179, cliente cairo, mesma carga):** `batch.max-delay=100`
  confirmado no `xpra info`; batch.delay da janela pesada avg 65 / cur 58 / max 177 ms, 803 draws, cliente 16,6 %,
  **servidor 13,0 %** de um core. Com o default (500) as rodadas anteriores deram avg 23–29 ms. Ou seja, o cap não
  reduz o delay (ele nunca chegou perto de 500 em LAN); o delay observado é governado pela latência de decode/ack
  do cliente, não pelo teto. **D1 sem efeito neste cenário; D2 (servidor saturado) não observado: 13 % de um core
  para uma janela de texto rolando.**

## Linux — microbenchmarks (headless, python3.12 do sistema, xpra 6.5.2)

### A3 — `make_image_surface()` com buffer readonly (CONFIRMADO, e maior que o estimado)

`bench_cairo_surface.py`: `xpra.cairo.image.make_image_surface(fmt, "BGRX", buf, w, h, w*4)` com três tipos de
buffer; "make+paint" inclui `Context(backing).set_source_surface(s).paint()` como no `cairo_paint_surface`.
Mediana de 15 repetições, µs:

| tamanho | buffer | RGB24 make | RGB24 make+paint | ARGB32 make | ARGB32 make+paint |
|---|---|---|---|---|---|
| 499×316 | bytes (readonly) | 19,5 | 36,2 | 106,5 | 143,9 |
| 499×316 | bytearray (writable) | **1,1** | 16,2 | 1,0 | 23,9 |
| 1920×1080 | bytes (readonly) | 273,6 | 456,0 | **1419,6** | 1867,0 |
| 1920×1080 | memoryview (readonly) | 269,0 | 456,3 | 1416,7 | 1867,8 |
| 1920×1080 | bytearray (writable) | **1,0** | 179,9 | 1,0 | 277,5 |
| 3840×2160 | bytes (readonly) | 1872,4 | 3923,4 | **6317,3** | 8689,7 |
| 3840×2160 | bytearray (writable) | 1,0 | 2114,4 | 1,0 | 1145,6 |

Baselines: `ImageSurface(RGB24, 1920×1080)` = 85 µs; memcpy de 8,3 MB = 183 µs; 4K: 781 µs / 1186 µs.

Leitura: o ramo zero-copy (`create_for_data`) só é tomado quando `not bc.is_readonly()` — e os pixels que chegam
da rede são `bytes`/`memoryview` readonly, então o cliente cai sempre no ramo lento. O custo do ramo lento é
**1,5–7× o custo de um memcpy puro** (RGB24 1080p: 274 µs vs 183 µs; ARGB32 1080p: 1420 µs — a conversão por
pixel, não a alocação de 85 µs, domina). Em 4K ARGB32 são 6,3 ms por frame na UI thread, só para criar a
superfície. Uma cópia para `bytearray` antes do `create_for_data` custaria ~183 µs (1080p) e habilitaria o ramo
rápido: candidato de código pequeno e mensurável. Só afeta `--opengl=no`.

### N2/B2 — chunking do payload (CORREÇÃO da sessão anterior)

`bench_chunking.py` instancia `SocketProtocol` com uma conexão fake, encoder rencodeplus, e chama `encode()` num
pacote `draw` com um `Compressed` de 64 KB / 1 MB / 4 MB:

| INLINE_SIZE | payload | pacotes no fio | formato | encode() mediana |
|---|---|---|---|---|
| 32768 (default) | 64 KB | **2** | raw 65 536 B + stub 44 B | 5,8 µs |
| 32768 | 1 MB | **2** | raw 1 048 576 B + stub 44 B | 5,6 µs |
| 32768 | 4 MB | **2** | raw 4 194 304 B + stub 44 B | 5,6 µs |
| 16 MB (tudo inline) | 1 MB | 1 | 1 048 626 B | 676 µs |
| 16 MB (tudo inline) | 4 MB | 1 | 4 194 354 B | 1605 µs |

- **A afirmação "um frame de 4 MB vira ~128 chunks de 32 KB" estava errada.** `INLINE_SIZE` é o limiar acima do
  qual um item sai *inteiro* como **um** pacote raw com header próprio; o receptor aceita no máximo 4 pacotes raw
  por pacote lógico (`process_payload`: "too many raw packets"). Não há fatiamento em 32 KB.
- Consequências: **N2 (overhead por chunk) cai** — o custo é um header + um append por item, 5,6 µs por draw
  independentemente do tamanho. O caminho out-of-band é ~120–290× mais barato que inlinar (676/1605 µs), ou seja,
  o design atual já está certo e `XPRA_INLINE_SIZE` não é um knob útil.
- **B2 (cópias por fatiamento no read path) continua válido para 6.5.x, mas já foi corrigido upstream:** o
  `socket_handler.py` do 6.5.2 instalado e o da tag `v6.5.5` têm o padrão `b"".join(read_buffers)` /
  `buf[:payload_size]` (v6.5.5 linhas 1017/1117/1121); o `master` lê o header com `read_exact(8)` e o payload com
  `recv_into` num `bytearray(size)` pré-alocado (`read_exact`), sem fatias — commit **`1d4b31b139` (2026-05-25,
  "#4873 use socket.recv_into")**, que não está na branch de release 6.5.x (`v6.5.5` não é ancestral de master).
  Portanto: nada a propor em código; o ganho chega com a próxima série. A motivação quantitativa da sessão
  anterior ("centenas de mini-packets por frame") não procede, mas o padrão de cópia em si existia.

## Linux — par cliente/servidor (A1, A3 ao vivo, A5/B4)

### A1 — loop de apresentação GL em idle (REFUTADO)

Cliente GTK3 em `:178` → `:177` com `--opengl=force -d opengl`, 1 xterm parado. Janela de 30 s sem interação:

| contador | antes | depois |
|---|---|---|
| `do_gl_show` no log | 5 | 5 (+0) |
| `on_render(` no log | 0 | 0 (+0) |
| linhas de log | 512 | 512 (+0) |
| CPU do cliente | — | **0,23 %** de um core |

`queue_render()` só é chamado a partir de `do_gl_show`, que só roda após um paint; não há tick de frame-clock
enquanto nada muda. O cliente Windows com GL mostra o mesmo (0,8–0,9 % idle). A1 sai da lista.

### Par Linux sob carga (`run_damage2.sh`, `--mmap=no`)

Cliente GTK3 em `:178` → `:177` (socket unix, `--mmap=no` para forçar o caminho de encode/decode real — a
primeira rodada usava `mmap`, que não exercita decoder nenhum). Fases: idle 20 s → `xclock -update 1`
(janela leve, 1 damage/s) 25 s → xclock + `xterm -geometry 200x60 -e yes` (janela pesada, ~1200×900,
pipeline escolhido pelo servidor: **openh264** com csc libyuv; o cliente Linux tem decoders de vídeo) 30 s.
CPU em % de um core:

| fase | cliente cairo (`--opengl=no`) | cliente GL (llvmpipe, `--opengl=force`) | servidor :177 | Xorg dummy :177 |
|---|---|---|---|---|
| idle | 0,25 | 0,25 | — | — |
| xclock só | 0,44–0,52 | 1,40 | — | — |
| xclock + xterm `yes` | **4,5** | **41,2** | 8,7–11,5 | **84** |

- O GL por software (llvmpipe) não é comparável ao GL de verdade: os 41 % são rasterização na CPU. O número
  útil aqui é o cairo: 4,5 % para decodificar h264 e pintar ~25 fps de 1200×900.
- O gargalo deste cenário é o **Xorg dummy** renderizando o texto do xterm (84 % de um core), não o xpra.
  Em uso real o X server é o do servidor da aplicação, então isso não é um candidato.

### A5/B4 — draw thread única, bloqueio head-of-line (NÃO REPRODUZIDO neste cenário)

Métrica: `client-latency` (tempo entre envio e ack de decode do cliente, ms, média suavizada) da **janela
leve** (xclock) com e sem a janela pesada, lido do `xpra info` do servidor (`info_*_light.txt` /
`info_*_heavy.txt`):

| cliente | xclock só | xclock + xterm `yes` |
|---|---|---|
| cairo | avg 2 / recent 1 ms | avg 1 / recent 1 ms |
| GL (llvmpipe) | avg 18 / recent 6 ms | avg 2 / recent 1 ms |

A janela leve não ficou mais lenta com a pesada ao lado — com decode h264 de ~1 MP a ~25 fps a fila da draw
thread não enfileira o bastante para aparecer. O mecanismo (uma `_draw_queue` servida por uma única thread,
`draw.py`) continua verdadeiro por leitura, mas **só deve pesar quando o decode por frame é caro**: o caso
candidato é justamente o cliente Windows, que não tem decoders de vídeo e recebe webp/jpeg (decode de
1080p webp ≈ 5–15 ms por frame). Para medir isso faltam duas coisas que não fiz: (1) uma carga de janela
grande a 1080p+ no cliente Windows com `-d paint` **sem** remote logging (`--remote-logging=no`; com
remote logging ligado o `-d paint` inundou o servidor com 290 k pacotes de log e travou o `xpra info`) e
(2) o snapshot do servidor tirado **antes** de fechar a janela pesada (neste script o xterm é fechado antes
do snapshot, por isso só a janela leve aparece nas tabelas acima).

## Resumo dos vereditos

| item | antes (estático) | depois (medido) |
|---|---|---|
| V1 fast-path nativo | não verificado | presente (rencodeplus + lz4) |
| V2 backend | desconhecido | GTK3 + OpenGL (win32 só como contexto GL) |
| V3 fallback de vídeo | hipótese | n/a: o build Windows não tem decoders de vídeo |
| A1 loop GL em idle | ALTO | **refutado** (0 renders em 30 s idle) |
| A3 superfície cairo | MÉDIO-ALTO | **confirmado**: 0,27–1,4 ms/frame 1080p, 1,9–6,3 ms em 4K, só `--opengl=no`; fix pequeno (copiar p/ bytearray) |
| A5/B4 draw thread | MÉDIO-ALTO | não reproduzido com h264; pendente no Windows (webp/jpeg) |
| B1 cópia antes do decode | rebaixado | mantido rebaixado (draw é out-of-band) |
| B2 fatiamento no read path | promovido | válido em 6.5.x, **já corrigido no master** (#4873) — nada a propor |
| N2 overhead por chunk | novo | **cai**: 1 pacote raw por item, 5,6 µs |
| D1 batching reativo | ALTO | sem efeito em LAN (cap nunca atingido) |
| D2 servidor saturado | ALTO | não observado (9–13 % de um core) |

Ordem sugerida para a próxima fase: A3 (único candidato de código confirmado, com medida antes/depois
direta no Windows `--opengl=no`), depois A5 no Windows com a metodologia corrigida acima.

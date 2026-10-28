# Clientes alternativos do Xpra — estado em 2026-10-28

Data: 2026-10-28 · Repos lidos em harpia-dev1 (RHEL 8.10), clones em
`/tgdesenv/src/proj0/u4w7/src/external/{rust-xpra,go-xpra,xpra-html5,vispra}` (`--depth=200`;
só o `xpra-html5` ficou de fato truncado — os outros três têm menos de 200 commits e o clone
contém o histórico inteiro, confirmado por `git rev-parse --is-shallow-repository`).
Referência oficial: `docs/Usage/Clients.md` do master upstream (tabela datada **2026-08-02**).
Metadados do GitHub via `https://api.github.com/repos/...` sem autenticação, no mesmo dia.

Fontes marcadas em cada afirmação: **[README]** (README/CHANGELOG/docs do repo), **[log]** (`git log`,
`git ls-files`, `wc -l`), **[API]** (GitHub API), **[src]** (código lido), **[docs]** (`docs/Usage/Clients.md`).

**Nenhum binário foi construído**: não há `cargo`/`rustc`/`go` em harpia-dev1 nem em harpia-dev3
(`which`, `ls /opt/rh`, `rpm -qa` — só `rust-srpm-macros`, que é macro de empacotamento, e os
`gcc-toolset-10..15`), nem na máquina Windows (`cargo`/`go`/`gcc`/`cl` ausentes; só `node`).
A tentativa de `npm ci && npm run build` do vispra em harpia-dev1 (node 24.18.1 em `~/.local/bin`)
foi bloqueada pela política de execução de código externo desta sessão e não foi repetida; o
`setup.py` do html5 (que só copia/minifica arquivos) tampouco foi executado pelo mesmo motivo.

---

## Resumo

| Repo | Linguagem | Último commit | Commits | LOC próprio | Stars | Issues abertas | Windows? | Status (uma linha) |
|---|---|---|---|---|---|---|---|---|
| rust-xpra | Rust (`winit`+`softbuffer`) | 2026-10-18 | 213 (histórico completo) | 12,9 k em 37 `.rs` | 5 | 13 (0 PRs) | Sim: x86_64 e arm64, `.exe` com UPX | PoC ativo; v0.3.1 (2026-08-01) é a última release; HEAD exige servidor 7.0+ |
| go-xpra | Go puro, sem cgo, sem toolkit | 2026-10-18 | 100 (completo) | 21,0 k em 121 `.go` | 1 | 0 (0 PRs, 0 fechadas) | Sim: amd64 `.exe` | Mínimo por desenho; v0.2.3 (2026-10-18); exige 7.0+; ganhou macOS, clipboard e mmap |
| xpra-html5 | JavaScript sem framework | 2026-10-20 | 245 na janela (desde 2024-11; shallow) | ~13,0 k JS + 4,0 k HTML + 1,8 k CSS (+67,7 k vendorizado) | 342 | 24 (0 PRs; 267 fechadas) | Navegador | Produção; 22.0 (2026-10-17) exige 7.0+; última release GitHub v20 (2026-03-18), tag v21 sem release |
| vispra | TypeScript / SolidJS / Vite | 2026-03-18 | 26 (completo) | 23,1 k em 108 `.ts`/`.tsx` (+22,5 k vendorizado) | 0 | 0 | Navegador | Parado: um único push em 2026-04-15, nada desde; dialeto de pacotes pré-6.5 |

Contexto que muda a leitura de toda a tabela: o master do xpra está em **8.0** (`xpra/__init__.py`),
e nas últimas duas semanas o mantenedor moveu **os três clientes da Xpra-org para "mínimo 7.0"**
(html5 em 2026-10-17, rust e go em 2026-10-18) **[log]**. O servidor 6.5.2 de harpia-dev1 e o cliente
Windows 6.5.5 do estudo ficam, portanto, fora do alcance do HEAD desses repos; só releases antigas
(rust-xpra ≤ 0.3.1, go-xpra ≤ 0.2.2, html5 ≤ v21) ou o vispra falam com um servidor 6.x.

---

## rust-xpra

- **Identidade** **[API]**: `Xpra-org/rust-xpra`, criado 2025-04-07, branch `main`, GPLv3, 5 stars,
  2 forks, `pushed_at` 2026-10-18. Descrição: "Xpra client implementation in rust".
- **Atividade** **[log]**: 213 commits, 191 de Antoine Martin e 21 de um segundo contribuidor
  (`sganis`, todos no início). Dois surtos: 51 commits em 2025-04 (o PoC), depois silêncio de 14 meses,
  e 162 commits desde 2026-07 (76/25/40/21 por mês). Último commit 2026-10-18: "announce version 8
  and a 7.0 minimum protocol version".
- **Releases** **[API][log]**: tags `v0.1 … v0.3.1`; última release GitHub **v0.3.1 em 2026-08-01**.
  O `CHANGELOG.md` já tem uma seção `[0.4.0] 2026-09-24` e o `Cargo.toml` diz `0.4.0`, mas **não há
  tag v0.4.0** — tudo que está abaixo sobre mmap, macOS, 7.0+ etc. é HEAD, não release.
- **Issues** **[API]**: 13 abertas, 12 fechadas, 0 PRs. As 13 abertas são o roadmap do próprio autor,
  todas criadas em 2025-04-07/23: `opengl accelerated rendering` (#3), `video decoding` (#13),
  `audio support` (#5), `keyboard` (#15), `high dpi` (#2), `file transfers`, `printing`, `quic`,
  `webcam`, `system tray window forwarding`, `window transparency`, `window geometry`,
  `disable features we don't need`. Várias já foram parcialmente entregues (áudio e h264 no Windows,
  HiDPI) sem fechar a issue.
- **README — propósito e status** **[README]**: "Xpra client implemented in rust, for MS Windows,
  Linux and macOS"; "builds on MS Windows, Linux (X11 and Wayland) and macOS". O `CLAUDE.md` do repo
  ainda diz "Proof-of-concept … Not usable yet" e "no server/audio/clipboard support" — está
  desatualizado em relação ao próprio README (clipboard de texto e áudio no Windows existem).
- **Requisito de servidor** **[README][log]**: HEAD exige **xpra 7.0 ou posterior**, "tested against
  7.0 and 8.0", hello com `protocol-version: [7, 0]`; aceita pacotes com nomes legados e atuais, e
  "nothing sent depends on `XPRA_BACKWARDS_COMPATIBLE`". A release 0.3.1 falava com 6.6+ em modo
  compatível (é isso que a tabela oficial ainda descreve).
- **Protocolo/transportes** **[README][Cargo.toml]**: `tcp`/`ssl`/`ws`/`wss`, `ssh` via subprocesso,
  socket Unix; TLS verificado contra o trust store do sistema (`--ssl-insecure` para desligar), sem CA
  privada, sem AES de aplicação; autenticação só `hmac+sha256` (diálogo, `XPRA_PASSWORD`, `pinentry`
  ou diálogo próprio). Serialização via `serde_json` + `yaml-rust2` (não há rencodeplus — a tabela
  oficial marca `rencodeplus 🔴 / yaml 🟢`, consistente); `lz4_flex` só para descompressão.
- **Imagem/vídeo/áudio** **[README][src]**: `jpeg` (libjpeg-turbo via `turbojpeg`), `png` (`spng`),
  `webp` (`libwebp-sys`, C vendorizado e linkado estático); **sem rgb cru** fora do mmap; **`h264` só
  no Windows, via Media Foundation** (`src/client/mediafoundation.rs`, 396 linhas), nenhum codec
  embutido; **áudio: só Opus cru, só Windows** (MF decoder + WASAPI, jitter buffer adaptativo,
  `windows_audio.rs` 926 linhas), sem microfone. **mmap servidor→cliente ligado por padrão em Linux
  e macOS** (arquivo de 128 MB), explicitamente "not … Windows".
- **Desktop** **[README]**: clipboard texto bidirecional (CLIPBOARD; X11/XWayland via `copypasta`,
  Windows nativo); tray + balões de notificação só no Windows (`Shell_NotifyIconW`); bell = tom no
  Windows, `^G` no Linux; HiDPI em pixels lógicos com escala nearest-neighbour (`XPRA_DESKTOP_SCALING`);
  manifesto DPI per-monitor-V2 embutido no `.exe`. Limitações Wayland/macOS documentadas (sem
  override-redirect real, posição ignorada, NumLock).
- **Tamanho** **[log]**: 70 arquivos rastreados; 37 `.rs` = **12.907 linhas** (`client.rs` sozinho
  3.820); 2 `.toml` 96 linhas; 1 `.spec` RPM; `packaging/` com RPM e DEB. Doc: 6 `.md` com 1.532 linhas.
- **Build** **[Cargo.toml][README][CI]**: `cargo build`, edition 2024, perfil release com `lto`,
  `opt-level="z"`, `strip`, `panic=abort`; precisa de um compilador C (libwebp e libjpeg-turbo são
  compilados pelos crates `-sys`; "no cmake, no nasm, no bindgen" para o webp). CI `rust.yml`:
  `windows-latest` + `ubuntu-latest`; `release.yml`: Windows x86_64 (UPX), Windows arm64, Linux
  x86_64 e arm64 (UPX), macOS arm64, com SBOM CycloneDX por binário. Pacotes RPM/DEB no repositório
  **beta** da xpra.org, instalados como `/usr/bin/rust-xpra`. Grafo de dependências: 124 crates no
  Linux (98 linkados), 77 no Windows (53 linkados), "winit alone accounts for 76 of the Linux total".
- **Arquitetura relevante para desempenho** **[src]**: threads `reader`, `ping` e **uma única
  thread `decode`** (`start_draw_decode_loop`, `client.rs:1409`) que decodifica jpeg/png/webp e mantém
  os `H264Decoder` por janela; os pixels decodificados voltam ao event loop do `winit` via
  `EventLoopProxy` e são blitados para um framebuffer `softbuffer` em CPU, apresentado com
  `present_with_damage` (`window.rs:243`; CHANGELOG 0.4.0: "vectorise the draw blit", "present only
  the regions that changed"). **Não há OpenGL nem qualquer caminho GPU** (issue #3 aberta desde
  2025-04); no Windows a única aceleração é o decodificador h264 do SO.

## go-xpra

- **Identidade** **[API]**: `Xpra-org/go-xpra`, criado 2026-07-28, `main`, GPLv3, 1 star, 1 fork,
  `pushed_at` 2026-10-18.
- **Atividade** **[log]**: 100 commits, **um único autor** (Antoine Martin, três e-mails); 54 em
  2026-07, 28 em 08, 6 em 09, 12 em 10. Último commit 2026-10-18.
- **Releases** **[API][log]**: tags `v0.1.0 … v0.2.3`; **v0.2.3 em 2026-10-18** é release GitHub e
  coincide com o HEAD. CHANGELOG 0.2.3: macOS nativo, SBOM, "support v8 xpra servers", mmap,
  clipboard texto bidirecional (X11/Wayland/Windows), tray no Windows, socket Unix, estados de janela,
  minimização, coordenadas relativas por monitor.
- **Issues** **[API]**: 0 abertas, 0 fechadas, 0 PRs — nunca houve uso do rastreador.
- **README — propósito** **[README]**: "A minimal Xpra client in Go … The scope is deliberately small —
  connect, show windows, forward input — and the implementation is pure Go with no cgo." Plataformas:
  X11 e Wayland no Linux, Win32, **AppKit no macOS via `purego`** (sem cgo; `darwin/doc.go` admite que
  repinta o buffer inteiro a cada retângulo de dano).
- **Requisito de servidor** **[src]**: `protocol/options.go:42` `MinProtocolVersion = {7, 0}`,
  `clientVersion = "8.0"` (`client/hello.go:24`); recebe nomes legados por padrão,
  `XPRA_BACKWARDS_COMPATIBLE=0` para só os modernos.
- **Protocolo** **[README][go.mod]**: tcp/tls/ws/wss/ssh (subprocesso `ssh`, `sshpass` opcional)/socket
  Unix; rencodeplus próprio (`rencodeplus/`, 930 linhas); `lz4` só de entrada (`pierrec/lz4`); chunks
  out-of-band remontados por índice; `hmac+sha256`; TLS com CA privada opcional; sem AES.
- **Imagem** **[README][src]**: rgb cru (pede `BGRX`/`BGRA` no hello para copiar linha a linha sem
  shuffle), jpeg, png (paleta e cinza), webp — todos via `image/*` da stdlib e `golang.org/x/image`
  (decodificadores Go puros). **Sem vídeo, sem áudio** ("What it does not do: h264 and the other
  encodings, rich clipboard formats, audio, native notification popups, forwarded system tray icons,
  and keymap upload"). mmap receive-only de 128 MiB em sockets Unix no Linux.
- **Tamanho** **[log]**: 153 arquivos; 121 `.go` = **21.017 linhas** (`client` 4.602, `cmd/go-xpra`
  3.408, `wayland` 2.828, `win32` 2.783, `darwin` 2.051, `protocol` 1.715, `x11` 1.376, `ui` 1.017,
  `rencodeplus` 930, `internal/mockserver` 199).
- **Build** **[README][go.mod][CI]**: `go build ./cmd/go-xpra`, Go ≥ 1.25.0 (piso vem de
  `golang.org/x/image`; "still compiles under 1.24"); 6 dependências diretas; CI em matriz de SOs;
  release cross-compilada de `ubuntu-latest` para linux (2 arquiteturas) e windows, com SBOM;
  pacotes RPM/DEB no repositório da xpra.org (`packaging/`, `.spec` de 148 linhas).
- **Arquitetura relevante** **[README][src]**: quatro goroutines (leitura, escrita, desktop, e a
  principal "owns all client state and is the only writer"); **a decodificação jpeg/png/webp roda
  inline na goroutine principal** (`client/client.go:920-922` → `decodeImage`), ou seja, um decode
  grande bloqueia o tratamento dos demais pacotes. No Windows o buffer é memória Go comum; o `Paint`
  faz `InvalidateRect(hwnd, &damaged, 0)` com o retângulo de dano e `erase=0` (`win32/window.go:378-384`)
  e o `WM_PAINT` blita só a região pedida com `SetDIBitsToDevice` (`win32/window.go:435`). No X11 o
  backing store é um pixmap no servidor X; no Wayland, `wl_shm`.

## xpra-html5

- **Identidade** **[API]**: `Xpra-org/xpra-html5`, criado 2021-01-20 (separado do repo principal),
  `master`, MPL-2.0, **342 stars**, 82 forks, `pushed_at` 2026-10-20.
- **Atividade** **[log][API]**: 245 commits na janela (2024-11-28 → 2026-10-20; o histórico real é
  maior — 1.771 contribuições só do mantenedor segundo `/contributors`); 11 autores na janela, 212
  commits de Antoine Martin, 15 de Corbin Wunderlich, 7 de Tobias Messner, o resto com 1–4. Ritmo
  2026: 2–10 commits/mês até setembro e **19 em outubro**, quase todos de 2026-10-17 (migração para o
  dialeto 7.0 em uma leva de ~12 commits).
- **Releases** **[API][README]**: releases GitHub v18.1 (2025-11-06), v19 (2025-12-07), **v20
  (2026-03-18)**; tag **v21** existe (CHANGELOG `[21.0] 2026-05-11`) sem release GitHub; `setup.py`
  diz `VERSION = "22"` e o CHANGELOG abre com `[22.0] 2026-10-17`, **sem tag**. As tags v19–v21 não
  estão no `master` dentro da janela clonada (release branches). Nota: o CHANGELOG data `[20.0]` em
  "2026-12-19", data impossível — erro de digitação (a release GitHub é de 2026-03-18).
- **Issues** **[API]**: 24 abertas, 267 fechadas, 0 PRs. Duas de 2026 (`#423` erro de carregamento de
  estilo, `#415` teclado sem entrada); o resto são pedidos de longa data: `#238 render using webgl`
  (2023), `#64 Web Audio API` (2021), `#142 use keyboard layout map`, `#305 múltiplos targets de
  clipboard`, `#277 SBOM`, `#27 webcam/microfone` (2016).
- **README — propósito e requisito** **[README]**: "Simply point your browser to the contents of the
  `html5` folder"; instalado pelo servidor como `xpra-html5` e servido pelo web server embutido.
  **"This client requires Xpra 7.0 or later and uses the modern protocol dialect"**, com
  `docs/Protocol-v7.md` registrando validação manual em 2026-10-17 contra 7.0 e 8.0 com
  `BACKWARDS_COMPATIBLE` ligado e desligado (conexão, renderização, upload de 300 KB); o próprio
  `todo-v7.txt` admite que áudio sustentado, impressão, notificações, clipboard de imagem e
  TLS/WebTransport "remain to be verified. No automated test suite was added."
- **Funcionalidades** **[README/CHANGELOG][src]**: ws/wss, WebTransport experimental
  (`WebTransport.js`), AES de aplicação, hmac-sha256; rgb (lz4), jpeg, png, webp, avif, `scroll`;
  vídeo h264/vp8 via `WebCodecs` (`VideoDecoder.js`); 21.0 removeu `mpeg1`/`jsmpeg` e os
  encodings muxados (`h264+mp4`, `vp8+webm`, `mpeg4+mp4`) "they have had no decoder since v10";
  áudio via `MediaSource` com fallback `aurora`; decode em workers (`DecodeWorker.js`,
  `OffscreenDecodeWorker.js`); clipboard texto/HTML (+ PNG em 22.0); notificações, downloads,
  impressão via diálogo do navegador; teclado por layout com `simple-keyboard`.
- **Tamanho** **[log]**: 98 arquivos rastreados; JS total 80.734 linhas, dos quais **67,7 k são
  `html5/js/lib/`** (jquery 10,7 k, jquery-ui 19,1 k, simple-keyboard 8,9 k, aurora 17,2 k,
  web-streams-ponyfill 4,2 k, brotli 1,7 k, lz4 0,75 k, rencode 0,59 k); **código próprio ≈ 13,0 k JS
  em 19 arquivos** (`Client.js` 5.179, `Keycodes.js` 1.901, `Window.js` 1.457, `Utilities.js` 967,
  `Protocol.js` 745) + 3.957 HTML + 1.768 CSS + `setup.py` 627.
- **Build** **[README][setup.py]**: `./setup.py install` (copia para `/usr/share/xpra/www`,
  minifica com `uglifyjs` se houver, gera `.gz`/`.br` se `brotli` estiver no PATH), `./setup.py rpm`
  / `deb`; CI `ci.yml` + `build.yml` em `ubuntu-latest`; `shell.nix` e `sonar-project.properties`
  presentes. Em harpia-dev1 só exigiria `python3.12` (não executado nesta sessão).

## vispra

- **Identidade** **[API][log]**: `MajidNajafi/vispra`, MIT, **criado e empurrado no mesmo dia,
  2026-04-15** (`created_at` = `pushed_at` com 6 minutos de diferença); 0 stars, 0 forks,
  0 issues; `language: null` no GitHub (os `.js` vendorizados dominam). Não existe `Xpra-org/vispra`
  (API: "Not Found"). Os 26 commits são de "ali parnan" (LICENSE: "Copyright (c) 2026 Ali Parnan"),
  entre **2026-03-08 e 2026-03-18**; o dono do repo GitHub não assinou nenhum commit. Nada desde.
- **README — propósito** **[README]**: "modern HTML5 client for Xpra built with SolidJS and TypeScript.
  It connects to an Xpra server over WebSocket". Requisitos declarados: Node 20+, npm, Docker (para o
  servidor de teste); `npm run dev|build|test|test:integration|typecheck`; o modo de desenvolvimento
  auto-conecta em `ws://localhost:10000` hardcoded em `src/main.tsx`; "no packages".
- **Protocolo** **[src]**: porta em TypeScript do `Protocol.js`/`WebTransport.js` do html5
  (comentários dizem "Port of the legacy Protocol.js"); envia **nomes de pacote antigos**
  (`pointer-position`, `button-action`, `key-action`, `map-window`, `configure-window`,
  `damage-sequence`, `close-window`), e um commit se chama "Fix clipboard paste for Xpra v6.4.3" —
  é um cliente do **dialeto pré-6.5**, logo funciona com o 6.5.2 de harpia-dev1 e com 7.x/8.0 só em
  modo compatível. Ainda carrega `jsmpeg` (mpeg1) e `aurora` em `src/vendor/` — o que o html5 removeu
  em 21.0.
- **Funcionalidades** **[src][log]**: ws/wss e WebTransport (`webtransport.ts`), `brotli-wasm`,
  `lz4js`, `rencode.js` vendorizado; `WebCodecs` para h264/vp8 (`VideoDecoder`), `MediaSource` para
  áudio, `OffscreenCanvas` e três workers (`protocol-worker`, `decode-worker`,
  `offscreen-decode-worker`); clipboard (a palavra mais frequente no código, 544 ocorrências), modo
  desktop e seamless, painel de "performance presets" (incl. "RDP performance preset"), canvas
  `desynchronized` "for lower latency rendering", teclado virtual `simple-keyboard`, ícones de janela
  (commit 2026-03-16 — a tabela oficial diz que são descartados; ver drift).
- **Tamanho** **[log]**: 156 arquivos; **95 `.ts` + 13 `.tsx` = 23.052 linhas** (testes incluídos:
  `__tests__` ≈ 3,6 k), 13 `.css` 2.266, `package-lock.json` dentro dos 3.140 de JSON; vendorizado:
  `src/vendor/` 22,5 k (`aurora` 17,2 k, `jsmpeg` 4,2 k, `rencode.js` 0,56 k — duplicado em `public/`).
- **Build** **[package.json]**: Vite 6 + `vite-plugin-solid`, TypeScript 5.7, vitest 3; 6 dependências
  de runtime (`solid-js`, `brotli-wasm`, `lz4js`, `simple-keyboard`, `file-saver`, `streamsaver`).
  Viável em harpia-dev1 com o node 24 de `~/.local/bin` se o registro npm estiver acessível (não
  verificado; a execução foi bloqueada nesta sessão).

---

## Drift vs `docs/Usage/Clients.md` (tabela datada 2026-08-02)

O documento ficou para trás em menos de três meses, principalmente por causa dos commits de
2026-10-17/18. O que diverge do que os repos dizem hoje:

| Item | O que o doc diz | O que o repo diz hoje | Fonte |
|---|---|---|---|
| Requisito de servidor (rust) | "requires an xpra 6.6 or later server, left in its default backwards-compatible mode"; "Sends 6.5+ names, receives legacy: needs a 6.6+ server" | 7.0+, `protocol-version: [7, 0]`, aceita ambos os nomes, independente do modo do servidor | README, commit 2026-10-18 |
| Requisito de servidor (go) | "receives legacy unless `XPRA_BACKWARDS_COMPATIBLE=0`" (sem mínimo declarado) | `MinProtocolVersion = {7, 0}`; "support v8 xpra servers" | `protocol/options.go`, CHANGELOG 0.2.3 |
| Packet types (html5) | "Legacy names, both directions" 🟠 | dialeto moderno nas duas direções, 7.0+ obrigatório | README, `docs/Protocol-v7.md`, CHANGELOG 22.0 |
| Plataformas (rust) | "Runs on MS Windows and on Linux, X11 or Wayland" | + macOS (arm64 publicado), com tabela de limitações própria | README "Known macOS limitations", release.yml |
| Plataformas (go) | "three window systems: Linux X11, Linux Wayland and MS Windows" | + macOS via AppKit/purego, Dock icon, menu-bar | README, `darwin/`, CHANGELOG 0.2.3 |
| Clipboard (go) | 🔴 | texto UTF-8 bidirecional em X11, Wayland, Windows e macOS | README "What it does", CHANGELOG 0.2.3 |
| Shared memory (go) | 🔴 | mmap receive-only 128 MiB em socket Unix no Linux | README, CHANGELOG 0.2.3 |
| Transports (go e rust) | `tcp/ssl/ssh/ws/quic` — sem menção a socket Unix | ambos aceitam `socket:///…`; o rust também `/caminho` | READMEs (o doc só lista socket Unix para o cliente nativo) |
| DPI (rust) | "no server DPI / monitor synchronization" | 0.4.0: "send the local display size and per-monitor layout in the hello", coordenadas por monitor, HiDPI lógico | CHANGELOG 0.4.0, README "HiDPI displays" |
| Client tray / menu (go) | 🔴 | ícone de área de notificação no Windows e menu-bar no macOS, com Exit | README, CHANGELOG 0.2.3 |
| Window icons (vispra) | "Decoded and dropped: every window shows the same branding icon" | commit 2026-03-16 "display window icons from xpra server" — anterior à data do doc, portanto possivelmente um erro de leitura e não drift | `git log` |
| Tamanho: rust-xpra | 32 arquivos, 9 kloc | 37 `.rs`, 12,9 kloc (+43 %) | `git ls-files`/`wc -l` |
| Tamanho: go-xpra | 83 arquivos, 14 kloc | 121 `.go`, 21,0 kloc (+50 %) | idem |
| Tamanho: xpra-html5 | 32 arquivos, 18 kloc | ≈34 arquivos próprios (js+html+css+py), 19,4 kloc; vendorizado 67,7 k ("some 70 kloc" confere) | idem |
| Tamanho: vispra | 117 arquivos, 24 kloc; "gets the equivalent from npm and never commits it" | 108 `.ts`/`.tsx` + 13 `.css` = 121 arquivos, 25,3 kloc (mesma árvore de março, só método de contagem); **mas commita 22,5 kloc em `src/vendor/`** (aurora, jsmpeg, rencode) | idem |
| Lista de clientes | vispra como "third party", licença MIT, link `MajidNajafi/vispra` | correto; vale acrescentar que está inativo desde 2026-03 e que os commits são de outra pessoa | API, `git log` |
| kotlin-xpra | listado com 34 arquivos / 4,5 kloc | repo criado em **2026-10-18** (1 star, `pushed_at` 2026-10-19) — a linha é mais nova que a data "2026-08-02" da seção, i.e. a tabela de tamanho foi atualizada sem mover a data | API |

O que **confere**: licenças, mantenedores, `rencodeplus 🔴 / yaml 🟢` para o rust (serde_json +
yaml-rust2, nenhum rencode), `lz4` só de entrada em todos os alternativos, h264 só Windows/MF e Opus só
Windows no rust, go sem vídeo e sem áudio, html5/vispra com `aurora` como fallback de áudio, `ssh` via
subprocesso nos dois nativos, notificações só logadas no go e no rust fora do Windows.

Há um skill no repo, `.claude/skills/update-client-feature-table/`, para refazer exatamente essas
tabelas a partir dos repos; os clones em harpia-dev1 servem de entrada para ele, se um PR de
atualização for desejado (o mantenedor aceita PRs de docs — ver `session-report.md`, seção 2).

---

## O que isso muda para o estudo de performance

1. **Nenhum dos alternativos é um substituto para o cliente Windows do usuário.** O rust-xpra é o
   único que roda no Windows com algum caminho acelerado (h264 por Media Foundation), mas não tem
   OpenGL (issue #3 aberta há 18 meses), não tem mmap no Windows, não tem rgb cru fora do mmap, não
   tem teclado completo nem clipboard além de texto, e o HEAD exige servidor 7.0+ — o servidor 6.5.2
   de harpia-dev1 só falaria com a release 0.3.1. O go-xpra não decodifica vídeo nem áudio.
2. **Ponto de comparação útil para A3 (Cairo per-frame surface).** Os dois nativos fazem o que o
   candidato A3 propõe: mantêm **um framebuffer persistente por janela em memória própria** e blitam só
   o retângulo de dano (`softbuffer::present_with_damage` no rust; `InvalidateRect(&damaged, erase=0)`
   + `SetDIBitsToDevice` no go). O rust 0.4.0 ainda vetorizou o blit ("vectorise the draw blit"). É
   evidência de desenho, não medição — mas mostra o mantenedor adotando, nos clientes novos, a
   estrutura que o `cairo/image.pyx` do cliente Python não consegue alcançar com buffers somente-leitura.
3. **Ponto de comparação para A5/B4 (uma única thread de decode).** O rust-xpra repete o modelo do
   cliente Python: **uma thread `decode`** para todas as janelas (`client.rs:1409`), com os
   `H264Decoder` indexados por janela dentro dela; o go-xpra é ainda mais simples e **decodifica na
   goroutine principal**. Ou seja, o mantenedor não considerou o decode paralelo por janela uma
   prioridade nem partindo do zero; qualquer proposta de paralelizar `_draw_queue` no cliente GTK
   deve vir com medição multijanela, não com o argumento arquitetural sozinho.
4. **Contraponto ao A2 (win32 nativo em Python, `InvalidateRect(hwnd, None, True)`).** O go-xpra
   mostra a versão correta do mesmo mecanismo em ~2,8 k linhas de Go (`win32/`): invalidar só o dano,
   sem apagar fundo, blitar só o pedido. Se o cliente nativo win32 do Python (PoC 2025) voltar a ser
   relevante, o `go-xpra/win32/window.go` é a referência mais curta para o padrão.
5. **Compatibilidade de versões virou variável do estudo.** Com master em 8.0 e os três clientes
   Xpra-org em "mínimo 7.0", medir qualquer alternativo contra o par 6.5.2/6.5.5 exige releases
   antigas (rust 0.3.1, go 0.2.2, html5 ≤ v21) ou um servidor 7.x/8.0 em harpia-dev1 — e um servidor
   8.0 em modo não compatível rejeitaria o cliente 6.5.5 do usuário. Decidir isso antes de qualquer
   benchmark cruzado.
6. **Se um benchmark cruzado for feito, o único que dá para construir aqui hoje é o vispra** (node
   24 presente; `npm ci && npm run build`, com permissão explícita) ou o html5 (`python3.12 setup.py`),
   ambos servidos pelo web server do próprio xpra; rust/go exigem instalar `cargo`/`go` (não há em
   dev1, dev3 nem no Windows) — ou usar os binários prontos das releases (`.exe` x86_64 e arm64 do
   rust-xpra, `.exe` amd64 do go-xpra), que para o Windows do usuário é o caminho realista.
7. **O html5 é a referência mais madura fora do cliente nativo** (342 stars, 267 issues fechadas,
   11 autores recentes), mas as issues abertas que importariam para desempenho — `#238 render using
   webgl` (2023) e `#64 Web Audio API` (2021) — estão paradas; o decode já é em worker com
   `OffscreenCanvas`, ou seja, o browser faz o que A3/A5 pedem para o GTK.

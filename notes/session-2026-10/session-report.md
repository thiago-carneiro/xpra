# Session analysis notes — October 2026

Personal research notes kept on a branch of a fork of Xpra (https://github.com/Xpra-org/xpra).
They record three workstreams carried out on a Linux workstation against the
Windows client 6.5.2 → 6.5.5, plus the artifacts produced along the way.

Internal workstation paths (anything starting with `/tgdesenv/...`) are not part
of this repository; the artifacts they refer to are mirrored under
`notes/session-2026-10/`.

Base tree: Xpra master at commit `92be3fe67c` (2026-10-20), with a worktree pinned
to tag `v6.5.5` (`a2b94688`) for version-accurate line numbers.

---

## 1. Maximized windows / taskbar (Windows client)

**Symptom (client 6.5.2):** maximized windows often covered the Windows taskbar;
windows snapped to a screen corner lost their alignment.

**Static analysis pointed at three mechanisms:**
- the win32 `WM_GETMINMAXINFO` hook that clamps undecorated windows to the monitor
  workarea (issue #771, fix r8530), which is sensitive to DPI and multi-monitor layouts;
- per-monitor DPI reporting on Windows ("scaling is a pain because the OS tries very
  hard to lie to us" — issue #4205; #3943 per-monitor dpiAwareness);
- the GTK client's `calculate_window_offset()` path (`xpra/client/gui/client_window_base.py`),
  which nudges windows onto a local monitor and is not a full coordinate translation.

**Outcome:** upgrading the client to **6.5.5 resolved the symptom**. The 6.5.3–6.5.5
release notes list exactly this family of fixes ("desktop scaling misplaces relative
windows", "apply the new DPI before resizing the display", "XSETTINGS / DPI fix"),
so no further action was needed from this side.

## 2. Documentation contribution (upstream issue #5080)

A review panel (heterogeneous models) assessed whether "helping with the fragmented
documentation" was a safe contribution. Findings:

- The fragmentation critique that motivated the idea (a competitor's blog post,
  2025-06-30) describes a **superseded state**: the Trac instance is gone, `xpra.org`
  redirects to GitHub, the wiki is down to download pages, and `docs/` in master *is*
  the Jekyll site published at xpra-org.github.io. The maintainer has been migrating
  content into `docs/` since 2021 and still is.
- The appetites for documentation PRs are high: 11 of 12 external doc PRs merged; the
  single refusal (#4020) was a scope/style issue, and the maintainer rewrote it himself.
- The real, falsifiable defect is **drift between the code and its derived
  representations**: the defaults `auto` for `--file-transfer` / `--open-files` /
  `--open-url` (`xpra/scripts/config.py:1220-1222`) are missing from the man page
  (`fs/share/man/man1/xpra.1:697,703,709`) and the docs page says "enabled (which is
  the default)" (`docs/Features/File-Transfers.md:15`). The `--help` metavar has the
  same gap (`xpra/scripts/parsing.py:1332-1340`).

Pre-PR probes (all local, read-only) established:

- `auto` resolves to "enabled, with confirmation prompts where a UI exists"
  (`xpra/net/file_transfer.py:229-234`, `xpra/server/subsystem/file.py:38-39`,
  `xpra/client/base/file.py:43`);
- the man page is **manual** (no generator; `setup.py:3054-3057` only installs it;
  `parsing.py:930-933` says "remember to update the man page as well!");
- no CLA/DCO (GPLv2+, 0/12 recent commits with `Signed-off-by`);
- the LTS `v5.1.x` branch is affected and more severely (its man page documents
  `on|off` only, with no `--open-url` entry).

**Issue opened: https://github.com/Xpra-org/xpra/issues/5080** — issue-first, as the
project's accepted pattern. A follow-up PR is pending on the maintainer's response
(or silence), per the plan recorded with the issue.

## 3. Performance study (static, then measured)

22 candidate optimizations were identified by reading only (four parallel read-only
review passes: draw/paint pipeline, networking, UI thread/timers, server
encode/batching). The study then measured the headless-feasible subset.

**Measurement setup:** system Xpra 6.5.2 on a Linux host, `/usr/bin/python3.12`,
`rencodeplus` Cython 1.0.10 present, `yaml` absent. Transferability to 6.5.5 was
established by comparing the exercised modules: `xpra/net/packet_encoding.py`,
`xpra/net/compression.py` and `xpra/server/window/batch_delay_calculator.py` are
byte-identical (md5) between the installed 6.5.2 and the `v6.5.5` worktree.

**Measured — rencodeplus encode/decode (median of 5, µs):**

| payload | encoded bytes | ratio | encode | decode |
|---|---|---|---|---|
| control | 59 | — | 1.8 | 0.7 |
| 64 KB | 65,606 | 1.001 | 4.4 | 2.9 |
| 1 MB | 1,048,648 | 1.000 | 59.2 | 33.0 |
| 4 MB | 4,194,376 | 1.000 | 264.1 | 278.8 |

Round-trip verified. `memoryview_to_bytes` is a plain memcpy: 34.1 µs / 1 MB,
243.5 µs / 4 MB.

**Structural finding — draw payloads are out-of-band.** A `Compressed` item that cannot
be inlined (or exceeds `INLINE_SIZE = 32768`, `xpra/net/protocol/socket_handler.py:703`)
is split into chunks (`:710`), the packet keeps an empty placeholder (`:711`), and only
the stub is encoded (`do_encode`, `:737`). Chunks receive their own headers (`:527-568`).
On receive, chunks with index > 0 are stored raw and never decoded (`:1167-1180`); the
index-0 stub is decoded (`:1183`) and the chunks are spliced back by index
(`:1206-1211`). Network-layer decompression happens only when `level > 0`
(`:1141-1143`). Encoder selection: `TRY_ENCODERS = ("rencodeplus", "yaml", "none")`
(`packet_encoding.py:25`), first match in `PERFORMANCE_ORDER` advertised by the peer
(`socket_handler.py:596-609`).

**Consequences (the corrections the measurements forced):**

- *Payload copy before decode* (`memoryview.tobytes()`) — **downgraded**: draws never
  pass through the decoder, so the measured copy cost does not apply to them; it only
  affects in-band payloads (clipboard, file transfer, large stubs).
- *YAML fallback* — **refuted as a practical risk**: `yaml` is not even installed in
  this build; the real fallback would be `none` (no serialization). The one-command
  check on a given install remains useful as a diagnostic, but it is not a priority.
- *Read-path slicing copies* — **promoted**: a 4 MB frame becomes ~128 chunks of 32 KB,
  i.e. hundreds of small packets per frame. Under that density the current slicing
  pattern (`socket_handler.py:1110-1128`) copies 90–162× the stream size; an offset-based
  (memoryview) reader is **24× faster** in the synthetic benchmark (473.7 → 19.8 µs per
  128 KB read).
- *New candidate — per-chunk overhead*: one header per chunk, one tuple+append per
  chunk, and index splicing on receive; measurable with an `INLINE_SIZE` A/B.

**Not measurable on this host:** the display/GL-dependent candidates (GL presentation
loop that re-schedules itself while idle, `client/gtk3/opengl/glarea_backing.py:104-106`;
Cairo per-frame surface allocation on the UI thread, `cairo/image.pyx:142-148`; the
single draw thread serializing decode for all windows,
`client/subsystem/window/draw.py:97-107`). They need a machine with PyGObject and an
X server; the host used has neither and installing them requires root.

## Artifacts

| File | Content |
|---|---|
| `notes/session-2026-10/docs-issue-5080.md` | Final issue text (opened upstream as #5080) |
| `notes/session-2026-10/probe-results.md` | Pre-PR probe results (auto semantics, man page, license/CLA, LTS) |
| `notes/session-2026-10/perf-report.md` | Full 22-candidate report plus the measured corrections |
| `notes/session-2026-10/bench_rencodeplus.py` | Benchmark script used for the encoder measurements |
| `notes/session-2026-10/bench_rencodeplus.json` / `.md` | Raw benchmark results |

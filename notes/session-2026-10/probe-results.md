# Sondagem pré-PR — resultados (2026-10-20)

Executor: dev-navigator-1 (harpia/glm-5.3-flash) · Base: `/tgdesenv/src/proj0/u4w7/src/external/xpra` (master @ 92be3fe67c)
Método: leitura read-only do clone + raw.githubusercontent para a LTS (o assento não tinha shell; S4 verificada por fonte remota da branch — rotular como fato com fonte externa ao clone).

## S1 — Semântica do `auto` em runtime (RESOLVIDA)

`auto` ⇒ habilitado (≡ `yes`) no servidor; "ask" onde há UI.

- Default: `xpra/scripts/config.py:1220-1222` (`file-transfer`/`open-files`/`open-url` = `"auto"`).
- Leitura servidor: `xpra/server/subsystem/file.py:38-39` → `FileTransferAttributes.init_opts(opts, can_ask=False)`; cliente: `xpra/client/base/file.py:43` (can_ask=True default).
- Ramificação: `xpra/net/file_transfer.py:229-234` — `pask(v)=v.lower() in ("ask","auto")`; `file_transfer = pask or str_to_bool(v)` ⇒ `auto`→True; `*_ask = pask and can_ask` → False no servidor (idem open_files :240-242, open_url :244-246).
- Efeito: `subsystem/file.py:50-54` publica features já resolvidas em bool; caps cruzam o fio resolvidos (`net/file_transfer.py:430` boolget). Servidor Linux típico: transferências habilitadas, sem diálogo no servidor; cliente com UI pede confirmação.
- **Achado adicional**: o próprio `--help` (`xpra/scripts/parsing.py:1332-1340`) usa metavar `yes|no|ask` e imprime "Default: yes" via `enabled_str("auto")` — omite `auto` consistentemente. A omissão não é só da man page.

## S2 — Man page é manual (RESOLVIDA: manual)

- `setup.py:3054-3057` apenas instala o troff; nenhum gerador no repo (groff só renderiza p/ HTML: `packaging/MacOS/make-app.sh:456`, `packaging/MSWindows/BUILD.py:858-864`).
- `xpra/scripts/parsing.py:930-933` comenta "remember to update the man page (xpra.1) as well!".
- Histórico (API GitHub): config.py e xpra.1 mudam no MESMO commit com frequência (ex.: `09b2c437b` 2026-10-19, `abfe8e489` 2026-10-06) — a omissão do `auto` é gap de manutenção manual antigo.
- **Alvo do patch: a man page manual** (+ possivelmente o texto de `--help` em parsing.py).

## S3 — LICENSE/CLA/DCO (RESOLVIDA: sem barreira)

- GPLv2+ (`COPYING` = texto GPL v2; `README.md:16` "GPLv2+"; headers "GPL v2 or later" em `xpra/server/features.py:3-4`); copyright Antoine Martin (+Nathaniel Smith).
- Sem CLA/DCO: `.github/` só tem ISSUE_TEMPLATE, workflows build/containers/release/test, dependabot, FUNDING; `CONTRIBUTING.md` não exige sign-off; 0/12 commits recentes de master com `Signed-off-by`.

## S4 — LTS v5.1.x afetada (RESOLVIDA: sim, e pior que master)

- Branch: `origin/v5.1.x` (a831c895; série até tag v5.1.6).
- `config.py:1049-1051` (v5.1.x) mantém os mesmos defaults `auto`.
- Man page v5.1.x documenta `--file-transfer=on|off` (xpra.1:583) e `--open-files=on|off` (:586) — nem `ask` nem `auto`; entrada própria de `--open-url` não encontrada.
- **A issue pode afirmar que a LTS também é afetada: sim** (fonte: raw.githubusercontent na branch v5.1.x).

## Consequência para o plano

- As 4 condições bloqueantes do consolidado estão satisfeitas; nada impede a issue.
- Escopo de PR recomendado: man page (`fs/share/man/man1/xpra.1`) + frase em `docs/Features/File-Transfers.md:15`. O texto de `--help` (parsing.py:1332-1340) entra na issue como superfície adicional — o mantenedor decide se inclui no PR (mudança de metavar é doc-string, mas visível em runtime).
- Frase correta para os docs, derivada de S1: default é `auto` = transferências habilitadas, com confirmação do usuário onde houver UI; no servidor, habilitado sem diálogo.

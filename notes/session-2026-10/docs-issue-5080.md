# Draft da issue (pronta para abrir — requer permissão expressa do usuário)

**Destino:** https://github.com/Xpra-org/xpra/issues (nova issue — não Discussion, protocolo do painel)
**Idioma:** inglês (projeto upstream)
**Título sugerido:**
```
Documentation: man page omits the `auto` value and default for --file-transfer / --open-files / --open-url
```

**Corpo sugerido:**

```markdown
While reviewing the CLI docs I noticed the man page lists an incomplete set of
accepted values for three file/URL options, and omits their actual default:

- `man xpra` documents `--file-transfer=on|off|ask` (xpra.1, line 697) and
  `--open-files=on|off|ask` (line 703), but the defaults in
  `xpra/scripts/config.py` (lines 1220-1222, master @ 92be3fe) are all `"auto"`.
- `--open-url` is documented as `yes|no|ask` (line 709) with no default shown;
  its default is also `"auto"` (config.py line 1221).
- `docs/Features/File-Transfers.md` line 15 says transfers are "enabled (which
  is the default)" — the actual default is `auto`, not `enabled`.
- The `--help` output has the same gap: the metavar for these options is
  `yes|no|ask` and the default is printed as "yes"
  (`xpra/scripts/parsing.py`, lines 1332-1340, via `enabled_str("auto")`).

Proposed fix (happy to send a PR): add `auto` to the accepted-values lists in
the man page for those three options, state the real default, and reword the
sentence in `docs/Features/File-Transfers.md` to something like:

    enabled by default (`auto`: transfers are enabled, and users are prompted
    for confirmation wherever a user interface is available)

I left the `--help` metavar in `parsing.py` out of this — happy to include it
if you prefer the two surfaces to move together.
```

**Notas de redação (do painel/sondagem):**
- Não usar o vocabulário "fragmentação/consolidação" (custo reputacional — avaliação Achado 9).
- Caminhos com linhas exatas, no formato que o mantenedor usa (planejamento §2.1).
- Oferecer o PR como add-on barato (protocolo issue-first; PR só após resposta ou 14 dias de silêncio).
- NÃO mencionar licença (não está em disputa).
- Se o mantenedor responder "eu mesmo faço": agradecer e redirecionar o PR para apenas `docs/Features/File-Transfers.md` (mitigação R1 do planejamento).

# ssh:// vs tcp:// — latência de ack (2026-10-29)

Fechamento do pendência #2 do [session-report](./session-report.md): a observação lateral de que
`client-latency` sobre ssh variava (39–253 ms entre rodadas iguais) precisava ser isolada do transporte.

## Método

Servidor de teste **`:177`** no harpia-dev1, criado só para o benchmark (o `:77` real do usuário ficou
intocado, e o servidor de teste foi derrubado ao final):

```
xpra start :177 --bind-tcp=0.0.0.0:14501 --tcp-auth=none --start-child='xterm -geometry 80x24'
```

- **mesmo servidor, mesmo X display, mesmo load** para os dois transportes — a única variável é o túnel:
  - `ssh://u4w7@gr15sdes01/177` → notebook usa o socket unix `@xpra/177` via ssh.
  - `tcp://gr15sdes01:14501` → conexão TCP direta (auth=none), mesmo servidor.
- Carga = janela pesada `xterm -geometry 230x70 -e yes` (webp, ~1 MP), como nas rodadas A3/A5.
- Cliente Windows 6.5.5 (`Xpra_cmd.exe`, `--opengl=no`, subsystems desligados).
- Métrica = `client-latency` (servidor → cliente → ack) lido do `xpra info :177` para a janela pesada
  (id `6291490`, `damage.packets_sent` altos). Duas rodadas: ordem (ssh→tcp) e invertida (tcp→ssh).

Scripts e snapshots brutos em [`ssh-vs-tcp/`](./ssh-vs-tcp/).

## Resultados (janela pesada `window.6291490`)

`client-latency.avg` (ms) e `batch.delay.avg` (batching do servidor), por rodada:

| rodada / ordem | transporte | client-latency.avg | client-latency.recent | batch.delay.avg | target-latency | fps |
|---|---|---|---|---|---|---|
| 1 (ssh→tcp) | **ssh** | **161** | 161 | 28 | 125 | ~95–100 |
| 1 (ssh→tcp) | **tcp** | **17** | 17 | 27 | 17 | ~80–90 |
| 2 (tcp→ssh) | **ssh** | **48** | 38 | 26 | — | ~30–350 |
| 2 (tcp→ssh) | **tcp** | **28** | 23 | 27 | — | ~30 |

## Leitura

- **Direção consistente nas duas rodadas: `ssh` ≥ `tcp` em `client-latency`, nunca o contrário.**
  Magnitude variável (rodada 1: ssh 9,5× pior; rodada 2: ssh 1,7× pior), mas o efeito não cruza o sinal.
- **`batch.delay.avg` é praticamente igual** (~26–28 ms) nos dois transportes → o batching do servidor não
  explica a diferença; ela está no canal de transporte (ssh: criptografia, multiplexação do canal reverso do
  ack) e na retroalimentação que xpra aplica via `target-latency`.
- **`target-latency` é o sinal mais limpo**: o servidor mede o RTT do cliente e o usa como alvo de batching.
  Rodada 1: ssh → `target-latency=125` ms vs tcp → `target-latency=17` ms. É a medição direta do RTT de
  transporte observado pelo servidor.  **O túnel ssh infla o RTT percebido em ~7× neste link LAN.**
- Fps oscila (a taxa a que o cliente drena o pipe É a variável sob teste), então `client-latency.avg`
  herda um pouco dessa variância; por isso leio o `target-latency`/RTT como o marcador robusto.

## Caveats

- `fps` diferiu entre rodadas (~95 ssh vs ~80 tcp na 1ª; ~30 nas duas na 2ª) → não é um benchmark controlado
  de fps, mas a comparação relativa de RTT vale porque ambos os transportes correram o mesmo load no mesmo
  servidor na mesma hora.
- auth=none em TCP só é aceitável num servidor de teste efêmero; o `:177` foi derrubado logo em seguida.

## Conclusão / veredito

Para a investigação de performance, confirma-se o pendência #2: **o gateway ssh é um fator real de latência
de ack neste link.** Quando o cliente pode usar um listener TCP direto (mesma rede), o ack cai de **~7× a
~9,5×** em condições de carga alta, e o RTT percebido pelo servidor (target-latency) cai de ~125 ms para
~17 ms. Isso **não muda a conclusão A5** (o head-of-line na draw thread permanece pequeno no build atual),
apenas isola a variável transporte que contaminava as leituras anteriores de `client-latency`.

Sem ação de código upstream: é configuração de rede (expor TCP ou usar ssh para o RTT ser aceitável). Anota
aqui para o perfil não confundir `client-latency` sobre ssh com custo do cliente.
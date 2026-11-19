# Diário de experimentos

Cada teste fica registrado aqui, inclusive os que falharam ou foram invalidados. Nada é apagado: uma correção vira um teste novo. Horários são locais (UTC−3).

## 2026-11-19

### Teste 1 — Sonda Fase 3b: computação ou cópia? (18:08–18:09)

- **O que foi feito:** o mesmo shader da Fase 3, com e sem a cópia do resultado para a RAM, com 8 e 1.024 iterações. 156 execuções em ordem aleatória.
- **Resultado:** sem a cópia, as duas placas foram **44% mais lentas** que a GTX 970 sozinha; com a cópia, 23% mais rápidas. A GTX 750 Ti é **3,06×** mais lenta em computação.
- **Conclusão:** o ganho da Fase 3 vinha das cópias em paralelo pelos dois links PCIe. Link agora em Gen3 x8.
- **Detalhes:** [phase3b-probe-report.md](phase3b-probe-report.md)

### Teste 2 — NEXO GPU CONTROL travando (18:12–18:30)

- **Problema:** a janela "corrompia": cliques demoravam até 12 s ou mais de 30 s e ela não fechava.
- **Causa:** consulta do estado PnP (7–9 s por placa) rodando dentro da interface a cada 3 s.
- **Correção (v1.1):** telemetria em segundo plano. Clique → 31–175 ms; fechar → 87 ms.
- **Funcionou?** Sim, confirmado pelo Bruno na máquina.
- **Detalhes:** [gpu-control.md](gpu-control.md)

### Teste 3 — Forza Horizon 4 só com a GTX 970 (18:44)

- **Resultado:** 85 FPS (predefinição Média, 1440×900). A GTX 750 Ti ficou parada (2 W).
- **Detalhes:** [fh4-test-2026-11-19.md](fh4-test-2026-11-19.md)

### Teste 4 — Forza Horizon 4 com as duas placas habilitadas (19:01)

- **Resultado:** 86 FPS. A GTX 750 Ti continuou parada (1 W).
- **Conclusão:** o jogo usa uma placa só; o gargalo é o processador (menos de 1% do tempo limitado pela GPU). Habilitar a segunda placa não muda o FPS.

### Teste 5 — NEXO GPU ENGINE v0.1, primeira execução (19:10) — INVÁLIDO

- **O que foi feito:** primeiro job real do Engine: calibra a velocidade de cada placa, divide o trabalho e compara com a GTX 970 sozinha.
- **Por que é inválido:** o Forza Horizon 4 ainda estava aberto, usando a GTX 970. Resultado distorcido (−386% em 256 iterações).
- **Mantido em** `data/gpu-engine/2026-11-19/engine-runs.csv` com `validity=INVALID`.

### Teste 6 — Engine com o jogo fechado (19:13)

- **Resultado:** 1.024 iterações: duas placas 54,1 ms contra 72,3 ms da 970 sozinha (**25,2% mais rápido**). 256 iterações: 55,1% mais rápido.
- **Problema:** o valor de 256 iterações era bom demais. A 970 sozinha levou 46,8 ms, quando deveria levar ~25 ms.

### Teste 7 — Diagnóstico da instabilidade (19:15)

- **O que foi feito:** repetição de 256 iterações com log do clock a cada 100 ms.
- **Resultado:** agora o dual ficou **17% mais lento**. A GTX 970 passou a maior parte do tempo a 670 MHz, e não no boost de 1.113 MHz.
- **Causa:** entre as rodadas, a validação no CPU (1–2 s) deixava as placas caírem de clock. A primeira rodada depois da pausa pegava a placa lenta.

### Teste 8 — Engine com pre-roll e ordem ABBA (19:16–19:18)

- **Correção:** antes de cada rodada medida, o Engine roda o mesmo trabalho uma vez sem cronometrar, para subir o clock. A ordem alterna (A B B A…).
- **Resultado (4 sessões, todos os elementos validados):**

| Iterações | Duas placas | GTX 970 sozinha | Ganho |
|---:|---:|---:|---:|
| 256 | 20,9 ms | 25,7 ms | 18,7% |
| 256 | 20,7 ms | 23,1 ms | 10,3% |
| 1.024 | 50,5 ms | 66,2 ms | 23,7% |
| 1.024 | 53,1 ms | 66,0 ms | 19,5% |

- **Conclusão:** **as duas placas aceleram computação de verdade, de 10% a 24%**, com divisão calibrada de ~72/28. O teto teórico, pelas velocidades medidas no Teste 1, era ~25%.

### Teste 9 — GPU Control v2 com botão do Engine (19:22–19:24)

- **O que foi feito:** painel novo de dois canais com todas as métricas das placas e um botão que executa o Engine e mantém as duas ocupadas por 10 s.
- **Resultado:** com um clique, as duas curvas de uso subiram juntas para ~95% por 10 s. Resultado na tela: GTX 970 71% + GTX 750 Ti 29%, 20,32 ms contra 26,82 ms, **24,2% mais rápido**, validação PASS.
- **Captura:** [assets/gpu-control-v2-engine-run.png](assets/gpu-control-v2-engine-run.png)

## Lições do dia

1. Medir de novo é o que separa o que parece do que é. O "ganho de 50%" era cópia; o ganho real de computação é de 10% a 25%.
2. Uma placa ~3× mais lenta só ajuda com a divisão certa (~72/28). Dividir 50/50 deixa tudo mais lento.
3. Jogos não usam duas GPUs sozinhos. O Engine acelera trabalho do próprio NEXO, não jogos.
4. Clock de GPU varia muito. Sem aquecer a placa antes de medir, o resultado muda de sinal.

## Próximos testes

- Engine com mais sessões (ao menos 3, em horários diferentes) e intervalo de confiança.
- Mais tamanhos de job e iterações, para mapear quando compensa usar as duas placas.
- OBS gravando pelo NVENC da GTX 750 Ti enquanto a GTX 970 roda um jogo.

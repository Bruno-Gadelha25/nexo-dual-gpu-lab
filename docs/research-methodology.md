# Metodologia de pesquisa

## Pergunta

Num PC de 2012 com duas GPUs NVIDIA diferentes, controladas explicitamente por D3D12, dividir uma carga entre elas reduz o tempo total? Quanto custa juntar os resultados?

## Hipóteses (como deveriam ter sido escritas)

- **H0:** o tempo mediano do modo paralelo é igual ao da GTX 970 sozinha.
- **H1a (computação):** o paralelo é mais rápido porque as duas GPUs calculam ao mesmo tempo.
- **H1b (link):** o paralelo é mais rápido porque cada GPU copia sua parte pelo seu próprio link PCIe.

Os dados da Fase 3 rejeitam H0 para o workload medido, mas **não distinguem H1a de H1b**. Os indícios favorecem H1b (ver [auditoria, C1](audit/claude-audit-2026-11-19.md)).

## O que cada métrica mede

| Coluna | O que está dentro do intervalo | O que fica fora |
|---|---|---|
| `total_ms` (solo) | gravação da lista no CPU, envio, shader, cópia VRAM → `READBACK` (RAM) pelo PCIe, fence, acordar o CPU | validação no CPU |
| `total_ms` (paralelo) | o mesmo para as duas GPUs, até a última terminar | validação |
| `gpu970_ms` / `gpu750_ms` | do início da gravação daquela GPU até seu evento | — |
| `sync_wait_ms` | do fim do envio até o último evento | — |
| `transfer_ms` | cópia 750 Ti → heap compartilhado, fence, cópia heap → `READBACK` da 970 | geração do shader, validação |
| `queue_wait_enqueue_ms` | só a chamada de CPU que enfileira o `Wait` | o tempo de espera na GPU |

Todos os tempos usam `QueryPerformanceCounter` do host. Não há timestamps de GPU.

## Desenho da Fase 3

- Cargas: 1M, 2M, 4M, 8M elementos; 8 iterações do shader por elemento.
- Modos: GTX 970 solo, GTX 750 Ti solo, dual sequencial e dual paralelo em 50/50, 55/45, 60/40, 65/35, 70/30.
- 5 aquecimentos + 20 medições por configuração; uma única sessão.
- Ordem: para cada carga, 20× GTX 970 solo, 20× GTX 750 Ti solo, depois cada divisão em bloco. **Não aleatória.**
- Validação: todos os elementos comparados com a referência do CPU; uma divergência aborta a suíte.

## Estatística

- Publicado: média, mediana, desvio-padrão amostral (n−1), p95 nearest-rank (com n=20, é o 19º valor ordenado).
- Acrescentado pela auditoria: IC de 95% da redução da mediana por bootstrap percentil (10.000 reamostragens, semente 20261119) e correlação de Spearman entre a repetição e o tempo. Script: [analysis/reanalyze_phase3.py](../analysis/reanalyze_phase3.py).
- O IC cobre só a variação dentro da sessão. Não cobre deriva entre blocos nem entre dias.

## Ameaças à validade

| Ameaça | Situação | Mitigação proposta |
|---|---|---|
| Tempo inclui cópia pelo PCIe | presente | timestamps de GPU; variante sem readback; kernel com mais iterações |
| Baseline instável (até 21% entre blocos) | presente | ordem aleatória, aquecimento até estabilizar, várias sessões |
| Escolha da divisão nos mesmos dados | presente, efeito pequeno | sessão confirmatória com divisão pré-registrada |
| Link PCIe diferente entre campanhas | presente | registrar link por execução, mesmo campo |
| GPU com monitor e composição do Windows (GTX 970 primária) | provável | registrar processos gráficos ativos; repetir com a 970 sem saída |
| Rótulo da GPU pela ordem de enumeração | risco | selecionar por DeviceId/LUID e gravar no CSV |
| Telemetria esparsa (0,9–2,4 s) | presente | telemetria por execução, NVML no próprio processo |

## Correlação e causa

Nenhum documento deve dizer que o PCIe "causa" o resultado sem um experimento que varie o link ou isole a cópia. A hipótese H1b é a explicação mais provável, não um fato demonstrado.

## Campanha recomendada (Fase 3b)

1. Pré-registrar hipóteses, divisões, tamanhos, critério de aquecimento e análise.
2. Timestamps de GPU em cada fila: início do kernel, fim do kernel, fim da cópia.
3. Três variantes: só kernel, kernel + readback, kernel pesado (256 e 4.096 iterações).
4. Ordem aleatória com semente gravada; pelo menos 3 sessões em momentos diferentes.
5. Gravar em cada linha: DeviceId, LUID, link atual (mesmo campo nas duas GPUs), clocks, temperatura.
6. Consolidação medida como pipeline único, com validação fora do tempo.
7. Preservar a Fase 3 original sem alterações.

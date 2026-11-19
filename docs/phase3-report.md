# NEXO DUAL GPU — Fase 3: otimização e benchmark

**Data:** 2026-11-19  
**Máquina:** Windows 11 x64, Intel Core i7-3770K, 32 GB RAM, NVIDIA GTX 970 4 GB + GTX 750 Ti 4 GB.  
**Resultado da suíte:** `SUITE_RESULT=PASS`.

## Resumo executivo

A computação D3D12 paralela em duas GPUs foi mais rápida que a GTX 970 sozinha nas quatro cargas. A melhor divisão medida dependeu do tamanho: 65/35 para 1 milhão, 60/40 para 2 milhões e 50/50 para 4 e 8 milhões de elementos. O ganho de mediana ficou entre 28,6% e 50,4% nas cargas medidas.

Isso comprova ganho para esta carga computacional sintética com dados locais independentes em cada GPU. Não comprova ganho em jogos ou FPS. A consolidação do resultado da GTX 750 Ti para a GTX 970 por Cross-Adapter custou mais que o ganho de computação nas quatro cargas: dual + cópia final foi 38,3% a 76,1% mais lento que GTX 970 sozinha. Quando a aplicação puder manter e consumir os resultados particionados em cada GPU, evita esse custo; quando exigir um único buffer consolidado, este caminho medido não vence a GTX 970 sozinha.

## Método e integridade

- Suíte D3D12 criada em C++, com shader HLSL Shader Model 5.1 já compilado; ambiente existente foi usado, sem instalação.
- Cada configuração teve 5 aquecimentos e 20 repetições medidas. Foram testados os modos GTX 970 sozinha, GTX 750 Ti sozinha, duas GPUs sequenciais e paralelas nas divisões 50/50, 55/45, 60/40, 65/35 e 70/30.
- Cargas: 1M, 2M, 4M e 8M elementos; oito iterações por elemento. Verificação determinística dos resultados na CPU em todas as execuções.
- Computação: 1.200 linhas no CSV (240 aquecimentos + 960 medições = 48 configurações, cada uma com 5 + 20); todas as 960 medições e 240 aquecimentos têm `validation=PASS`.
- Transferência final: 500 linhas (100 aquecimentos + 400 medições = 20 configurações, cada uma com 5 + 20); todas têm `validation=PASS`.
- Estatísticas no CSV: média, mediana, desvio-padrão amostral e p95 pelo método nearest-rank. Todos os tempos são de parede medidos pelo processo; os tempos de GPU individuais e de espera/sincronização também estão nos CSVs.
- As GPUs calcularam partições independentes. A etapa de transferência mediu o resultado da partição secundária (GTX 750 Ti) para a GTX 970 e sua sincronização com fila/fence compartilhada; não foi incluída na tabela de tempo do kernel dual.
- Limite de parada configurado: 75 °C ou 3.700 MiB por GPU. Não foi acionado. Nenhum clock foi alterado; não houve overclock, teste de estresse, instalação, modificação de driver ou configuração do Windows.

## Melhor divisão paralela por carga

| Elementos | Divisão GTX 970 / GTX 750 Ti | Dual média (ms) | Mediana (ms) | Desvio-padrão (ms) | p95 (ms) | GTX 970 sozinha: média / mediana / p95 (ms) | Redução da mediana vs. GTX 970 |
|---:|:---:|---:|---:|---:|---:|:---:|---:|
| 1.000.000 | 65/35 | 2,5262 | 2,4077 | 0,2941 | 2,8955 | 3,4146 / 3,3732 / 3,5921 | 28,6% |
| 2.000.000 | 60/40 | 4,3827 | 4,2890 | 0,2939 | 4,6048 | 7,0823 / 7,0864 / 7,5461 | 39,5% |
| 4.000.000 | 50/50 | 6,7674 | 6,5856 | 0,3151 | 7,4327 | 13,4075 / 13,2718 / 14,6655 | 50,4% |
| 8.000.000 | 50/50 | 11,1134 | 11,1242 | 0,0513 | 11,1766 | 22,4866 / 21,0072 / 25,5561 | 47,0% |

A GTX 750 Ti sozinha teve medianas de 5,1788 / 9,8419 / 11,2396 / 21,8057 ms para 1M / 2M / 4M / 8M. Em 4M houve dispersão elevada na execução solo (desvio-padrão 3,7989 ms, p95 18,9126 ms); a mediana foi usada para selecionar a divisão e a dispersão está preservada nos dados brutos.

A execução dual sequencial não apresentou ganho consistente: melhor mediana medida por carga foi 4,4782 / 8,1343 / 12,4654 / 21,2527 ms. A vantagem veio da submissão paralela às duas filas, não de somar trabalho em sequência.

## Transferência Cross-Adapter de resultado final

Uma textura compartilhada Cross-Adapter com fence foi usada para transferir a partição produzida pela GTX 750 Ti à GTX 970. Cada combinação de tamanho/divisão teve 5 aquecimentos e 20 medições válidas. A fence sincronizou as filas; a integridade passou em todas as direções testadas nesta fase (direção específica: GTX 750 Ti → GTX 970). A Fase 2 já havia validado comunicação nos dois sentidos.

| Elementos | Divisão escolhida | Payload da partição secundária | Mediana de transferência | p95 | Dual + transferência vs. GTX 970 sozinha |
|---:|:---:|---:|---:|---:|---:|
| 1M | 65/35 | 1,4 MB | 2,5894 ms | 2,7422 ms | 4,9971 ms; 48,1% mais lento |
| 2M | 60/40 | 3,2 MB | 5,5136 ms | 5,7122 ms | 9,8026 ms; 38,3% mais lento |
| 4M | 50/50 | 8,0 MB | 13,1274 ms | 13,2299 ms | 19,7130 ms; 48,5% mais lento |
| 8M | 50/50 | 16,0 MB | 25,8745 ms | 25,9800 ms | 76,1% mais lento |

O custo não é principalmente a chamada de enfileiramento da espera: a mediana de `queue_wait_enqueue_ms` ficou aproximadamente entre 0,02 e 0,03 ms. A cópia/retorno e sua conclusão dominam o custo observado. Para aplicação real, a primeira opção a explorar é manter dados e resultados locais às GPUs e trocar apenas dados estritamente necessários, ou reduzir/comprimir/agregar o resultado antes de cruzar o adaptador.

## Telemetria e limites observados

- Telemetria amostrada a cada ~2,4 s durante a suíte: GTX 970 43–45 °C, clocks gráficos amostrados 135–1.113 MHz, memória 828–903 MiB usados; GTX 750 Ti 32–35 °C, clocks 135–1.163 MHz, memória 307–349 MiB usados.
- Uso de GPU amostrado: 0–66% na GTX 970 e 0–36% na GTX 750 Ti. A amostragem é esparsa em relação a kernels de poucos milissegundos; não representa pico de utilização nem clock sustentado. Clocks baixos correspondem a amostras em repouso/entre cargas.
- CPU total amostrada: 0–72%; RAM do sistema: 10.169–10.343 MiB; working set do processo: até ~189 MiB. Temperaturas foram bem inferiores ao limite de parada.
- NVIDIA-SMI reportou PCIe Gen1 x8 nas amostras antes e depois. Isso é a velocidade atual observada, não prova o máximo do link; nenhuma mudança de BIOS ou link foi feita. A transferência Cross-Adapter pode ser limitada pelo caminho PCIe/driver e pelo custo de sincronização.
- As cargas e os tamanhos do benchmark são deliberadamente pequenos/moderados e não simulam renderização de jogo, dependências de frames, latência de apresentação ou escalabilidade de um motor gráfico.

## Otimização recomendada

1. Usar partições independentes e dados locais por GPU; evitar compartilhar recursos no caminho crítico.
2. Selecionar a proporção por medição: neste workload, a divisão observada variou com o tamanho e não foi sempre 61/39. Uma implementação futura pode estimar a taxa de cada GPU usando janelas curtas e ajustar a próxima partição, com limites e histerese para evitar oscilações.
3. Quando o consumidor puder aceitar duas saídas, mantê-las separadas. Se precisar unificar, medir o custo total no desenho do algoritmo, pois a transferência final observada anulou o ganho de computação.
4. A prova de conceito ainda não demonstra ganho para gráficos de jogos. Um protótipo de renderização precisará lidar com dependências, sincronização, composição/transferência e apresentação no adaptador de saída.

## Arquivos

- `benchmark.csv` — todas as medições de computação e aquecimentos.
- `transfer-benchmark.csv` — todas as medições de transferência final e aquecimentos.
- `summary-statistics.csv`, `transfer-summary-statistics.csv`, `optimization-decision.csv` — agregações e comparação por carga.
- `nexo_dual_gpu.cpp`, `compute.hlsl`, `compute.cso`, `build.ps1`, `run-suite.ps1`, `summarize.ps1` — fonte e scripts do benchmark.
- `logs/` — compilação, saída/erro do programa, execução, telemetria, dados crus do NVIDIA-SMI e verificação de integridade da Fase 2.
- Todos os oito arquivos originais da Fase 2 conferem por SHA256 e tamanho com o inventário anterior. Ver `logs/fase2-integrity-check.csv`; nenhum foi alterado.

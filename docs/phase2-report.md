# NEXO Dual GPU — Fase 2: prova de conceito executável

Data: 19/11/2026. Resultado global: **PASS** para computação D3D12 simultânea, verificação de resultados e comunicação Cross-Adapter bidirecional com fences.

## 1. Ambiente

A auditoria está em [`logs/environment-audit.txt`](logs/environment-audit.txt). Visual Studio Build Tools/MSVC, Windows SDK 10.0.26100.0, DXGI/D3D12 headers/libs, FXC, D3DCompiler e NVIDIA-SMI já existiam. O shader foi compilado como **Shader Model 5.1** com FXC. Nenhum componente foi instalado ou baixado.

## 2. Implementação e método

O executável [`nexo_dual_gpu.exe`](nexo_dual_gpu.exe) enumera adaptadores DXGI e seleciona cada NVIDIA por LUID, criando um `ID3D12Device` e uma fila COMPUTE independente em cada uma. LUIDs vistos: GTX 970 `00000000:0000E8C1`; GTX 750 Ti `00000000:0000FA29`.

O shader [`compute.hlsl`](compute.hlsl) grava uma função inteira determinística por elemento (8 iterações de mistura de bits) em um UAV. Cada execução gera até 1.000.000 valores na GTX 970; no split, cada GPU gera 500.000 valores com o mesmo padrão global. Os resultados são copiados para readback, verificados integralmente no CPU e comparados com a referência. O aquecimento foi de apenas 8.192 elementos por placa.

Para a execução paralela, o programa grava as duas listas de comandos, submete ambas às filas e só então espera pelos dois fences/eventos. Cada GPU conclui e valida seu intervalo. Não há dependência do launcher Kyty, jogos, CUDA Toolkit ou alteração de driver.

Tempos são medidos pelo relógio de alta resolução do host, desde submissão/registro até conclusão do fence conforme a coluna. Não são timestamps do clock da GPU. O intervalo dual foi medido até ambas as conclusões; os valores individuais são latências host do trabalho submetido em cada fila. Comandos curtos, custos de submissão e fences fazem parte da medição. Duas repetições por cenário são poucas e não formam benchmark estatístico.

## 3. Cálculo simultâneo

Todos os 6 registros passaram na validação integral (`PASS`), em [`benchmark.csv`](benchmark.csv).

| Cenário | Repetição 1 | Repetição 2 | Média |
|---|---:|---:|---:|
| GTX 970 sozinha, 1.000.000 | 2,915 ms | 2,923 ms | **2,919 ms** |
| Split 500k/500k sequencial | 4,813 ms | 4,884 ms | **4,849 ms** |
| Split 500k/500k paralelo | 2,956 ms | 2,902 ms | **2,929 ms** |

Latências por fila no split paralelo: GTX 970 **1,800 / 1,822 ms**; GTX 750 Ti **2,842 / 2,798 ms**. As janelas de submissão até fence das duas GPUs se sobrepuseram; a soma das duas latências individuais foi maior que o tempo total observado, consistente com trabalho em voo simultâneo. A API GPU não fornece aqui um clock/timestamp comum às duas placas, então o instante exato de sobreposição dos núcleos não foi instrumentado com timestamps de hardware.

**Interpretação de desempenho:** o split paralelo foi em média ~39,6% mais rápido que executar o mesmo split sequencialmente. Porém, foi essencialmente empatado com a GTX 970 sozinha: o split foi aproximadamente **0,34% mais lento**, menor que a variação observada. Portanto, este workload minúsculo **não demonstrou ganho confiável sobre usar somente a GTX 970**. A GTX 750 Ti levou em média ~2,82 ms para metade do trabalho contra ~1,81 ms da GTX 970, logo o split 50/50 não é equilibrado. Não se mediu FPS nem se testou jogo.

## 4. Transferência Cross-Adapter real

As transferências estão registradas em [`logs/run.stdout.txt`](logs/run.stdout.txt). Em cada direção:

1. A GPU produtora executa o shader e cria um padrão verificável local.
2. Copia 1 MiB para uma textura 2D `R32_UINT`, row-major, 512×512, em heap `DEFAULT` com `D3D12_HEAP_FLAG_SHARED | D3D12_HEAP_FLAG_SHARED_CROSS_ADAPTER` e recurso com `D3D12_RESOURCE_FLAG_ALLOW_CROSS_ADAPTER`.
3. Cria-se handle compartilhado, aberto pela outra adapter; recurso é colocado no heap importado.
4. Uma fence com `D3D12_FENCE_FLAG_SHARED | D3D12_FENCE_FLAG_SHARED_CROSS_ADAPTER` também é aberta pelo peer. A fila receptora enfileira `Wait` para um valor ainda não sinalizado; a fila produtora copia e sinaliza depois. A fila receptora copia a textura para readback após o wait.
5. CPU valida todos os 262.144 valores no peer.

| Direção | Bytes | Integridade | Produtor até conclusão do peer | Chamada CPU de enfileirar Wait |
|---|---:|---|---:|---:|
| GTX 970 → GTX 750 Ti | 1.048.576 | PASS | 2,628 ms | 0,032 ms |
| GTX 750 Ti → GTX 970 | 1.048.576 | PASS | 2,516 ms | 0,017 ms |

O tempo end-to-end inclui submissão/cópia do produtor, espera da fence no peer, cópia do peer para readback e fence local; **não** inclui a geração do shader no produtor e não representa largura de banda pura do PCIe. A duração interna exata da espera da fence não foi isolada, mas o wait foi enfileirado antes do sinal e a cópia no peer só concluiu com os dados corretos. Isso comprova a sincronização GPU-GPU utilizada.

Uma tentativa de colocar um buffer Cross-Adapter retornou `E_INVALIDARG`; a variação com heap `ALLOW_ONLY_BUFFERS` também foi rejeitada pelo driver. O teste final usou a textura row-major compatível, que passou. Não se conclui que buffers Cross-Adapter sejam universalmente impossíveis; apenas que a configuração testada não foi aceita aqui.

## 5. Telemetria e PCIe

Coleta NVIDIA-SMI durante a execução em [`logs/telemetry.csv`](logs/telemetry.csv), resumo em [`logs/execution-summary.txt`](logs/execution-summary.txt).

- Pré-execução: GTX 970 40 °C e GTX 750 Ti 32 °C; pós-execução 41 °C e 32 °C. Máximo amostrado: **42 °C / 33 °C**. A amostragem (~0,9 s) não captura o pico instantâneo de tarefas de poucos milissegundos.
- Temperatura da CPU: **NÃO FOI POSSÍVEL MEDIR** com os contadores padrão consultados/NVIDIA-SMI; nenhuma ferramenta adicional foi instalada.
- Utilização total de CPU amostrada: pico 69% (inclui atividade geral do sistema e é apenas amostragem). RAM física utilizada no período: aproximadamente 9.169–9.392 MiB de 32.728 MiB visíveis. Working set amostrado do processo chegou a ~82,8 MiB; leitura Win32 do próprio processo ao final ~88 MiB (métricas instantâneas diferem).
- Em todas as amostras PCIe durante trabalho: **Gen1 x8** tanto na GTX 970 quanto na GTX 750 Ti. Não houve subida automática para Gen3 sob esta carga. Isso confirma link atual, não limite máximo da placa-mãe/CPU nem causa do Gen1.
- `nvidia-smi` no diagnóstico anterior reportava hostmax/gen.max 1, ao passo que PnP informa máximo Gen3 no endpoint e CPU/placa especificam PCIe 3.0. O máximo real da plataforma e o slot físico associado a cada caminho continuam NÃO CONFIRMADOS. Nenhuma configuração PCIe foi alterada.

## 6. Conclusões obrigatórias

1. **As duas GPUs executaram trabalho D3D12 real? CONFIRMADO.** Cada adapter recebeu e completou dispatch compute com dados diferentes; todos os resultados foram validados no CPU. As duas submissões do cenário paralelo precederam qualquer espera e as janelas de fence se sobrepuseram.
2. **Cross-Adapter nos dois sentidos? CONFIRMADO.** 1 MiB em cada direção, sem divergências.
3. **Fences Cross-Adapter sincronizaram? CONFIRMADO.** Wait do peer foi enfileirado antes do sinal do produtor; cópia/readback após fence passou.
4. **Execução dupla foi mais rápida?** Contra split sequencial, sim (~39,6%). Contra GTX 970 sozinha, empate técnico no pequeno workload; nenhuma melhoria confiável foi demonstrada.
5. **Gargalos observados:** GTX 750 Ti significativamente mais lenta no mesmo shader; link PCIe atual Gen1 x8; handoff/fence/readback de 1 MiB custa ~2,5–2,6 ms, muito próximo do próprio cálculo de 1M itens (~2,9 ms). O tráfego cross-adapter pode apagar qualquer ganho em tarefas pequenas. Shader Model 5.1 e gestão explicitamente independente das GPUs limitam o denominador comum.

### Classificação

- **CONFIRMADO:** compilação sem dependências novas; dois devices e queues; computação D3D12 nas duas; outputs determinísticos verificados; submissões paralelas em voo; recursos e fences Cross-Adapter e dados íntegros em ambos sentidos; link atual Gen1 x8 durante amostras.
- **PARCIALMENTE CONFIRMADO:** sobreposição efetiva das unidades de execução (as janelas host de fence se sobrepõem e o makespan é menor que a soma, mas não foram usados timestamps de hardware comuns); ganho de desempenho para workloads maiores.
- **NÃO SUPORTADO:** não se pode somar VRAM automaticamente; nada neste protótipo configura SLI/NVLink.
- **NÃO FOI POSSÍVEL TESTAR:** estabilidade prolongada, ganho estatístico, temperatura do CPU, largura de banda pura e tempos de fence isolados, slot físico/max PCIe, jogos/FPS ou escalabilidade para workloads gráficos reais.

## 7. Arquivos entregues

- `nexo_dual_gpu.cpp`, `compute.hlsl`, `compute.cso`, `nexo_dual_gpu.exe`
- `build.ps1`, `run-with-telemetry.ps1`
- `benchmark.csv`
- `logs/`: auditoria do ambiente, saída final, stderr, telemetria, resumo, compilação e logs de tentativas/correções do harness.

A primeira tentativa longa foi cancelada após identificar validação CPU repetitiva excessiva; uma seguinte encontrou e corrigiu uma espera repetida de evento manual-reset. As amostras de benchmark apresentadas acima são somente da execução final PASS. O monitor PowerShell não expôs o campo OS `ExitCode`; o programa imprimiu `RESULT=PASS` no caminho que retorna 0. Nenhum código de saída do sistema é alegado como coletado.

## Referências técnicas oficiais

- [Microsoft — Direct3D 12 shared heaps](https://learn.microsoft.com/en-us/windows/win32/direct3d12/shared-heaps): limites, memória de sistema, heaps Cross-Adapter e layouts de textura.
- [Microsoft — flags de fence D3D12](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/ne-d3d12-d3d12_fence_flags): criação de fence compartilhada entre adapters.
- [Microsoft — espera GPU em command queue](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/nf-d3d12-id3d12commandqueue-wait): wait enfileirado pela GPU.
- [Microsoft — sistemas multi-adapter](https://learn.microsoft.com/en-us/windows/win32/direct3d12/multi-engine): adapters independentes e controle explícito multi-GPU.

Esta fase está encerrada. Nenhuma integração com jogos foi iniciada.



# Glossário

| Termo | Significado neste projeto |
|---|---|
| **Adapter / adaptador** | Uma GPU vista pelo DXGI. Cada GPU física é um adaptador independente. |
| **Aquecimento (warmup)** | Execuções descartadas antes das medições, para estabilizar caches, clocks e driver. |
| **Bootstrap** | Reamostragem com reposição para estimar a incerteza de uma estatística (aqui, a mediana). |
| **Cross-Adapter** | Recurso ou fence D3D12 criado numa GPU e aberto em outra por um handle compartilhado. Não une as memórias. |
| **D3D12 / Direct3D 12** | API gráfica e de computação da Microsoft, de baixo nível, com controle explícito de filas e sincronização. |
| **Dispatch** | Comando que executa um compute shader em grupos de threads. |
| **DXGI** | Camada do Windows que enumera adaptadores e saídas de vídeo. |
| **Fence** | Contador de sincronização: uma fila sinaliza um valor; outra fila ou o CPU espera por ele. |
| **Feature level** | Conjunto de recursos D3D suportado. GTX 970: 12_1. GTX 750 Ti: 11_0. |
| **Fila COMPUTE** | Fila de comandos D3D12 só para computação e cópia, sem gráficos. |
| **Heap compartilhado** | Bloco de memória criado com `D3D12_HEAP_FLAG_SHARED_CROSS_ADAPTER`; neste hardware fica na memória do sistema. |
| **HLSL** | Linguagem de shaders do Direct3D. |
| **IC 95%** | Intervalo de confiança: faixa que, pelo método usado, cobre o valor verdadeiro em 95% das repetições do procedimento. |
| **LUID** | Identificador local de um adaptador, válido até a próxima reinicialização. |
| **Mediana** | Valor do meio dos dados ordenados; menos sensível a picos que a média. |
| **NVENC** | Codificador de vídeo em hardware das GPUs NVIDIA. |
| **NVML** | Biblioteca da NVIDIA para consultar o estado das GPUs (usada pelo `nvidia-smi`). |
| **p95 (nearest-rank)** | Menor valor tal que pelo menos 95% das amostras são menores ou iguais. Com 20 amostras, é o 19º valor. |
| **PCIe Gen1/Gen3, x8** | Geração e número de lanes do link. Teórico por direção: Gen1 x8 ≈ 2,0 GB/s; Gen3 x8 ≈ 7,9 GB/s. |
| **Readback** | Heap D3D12 na memória do sistema, que o CPU consegue ler. Copiar para ele atravessa o PCIe. |
| **SLI / NVLink** | Tecnologias NVIDIA de ligação entre GPUs iguais. **Não** são usadas aqui. |
| **Split / divisão 65/35** | 65% dos elementos na GTX 970 e 35% na GTX 750 Ti. |
| **UAV** | Unordered Access View: buffer que o shader pode escrever. |
| **Workload sintético** | Carga artificial criada para medição, sem relação direta com uma aplicação real. |

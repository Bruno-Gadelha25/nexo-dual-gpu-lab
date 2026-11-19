# Visão técnica

## Componentes atuais

- **Fase 1 — diagnóstico:** identificação de CPU, memória, placas, PCIe, DXGI/D3D12 e CUDA Driver API.
- **Fase 2 — prova de conceito:** dispositivo/fila D3D12 independente por GPU, cálculo determinístico, verificação CPU e transferência Cross-Adapter com recursos compartilhados e fences.
- **Fase 3 — otimização:** partições locais independentes em GTX 970/GTX 750 Ti; mede execução solo, sequencial e paralela e a transferência final de resultados.
- **Fase 4 — observabilidade:** amostragem passiva a cada 30 segundos, com estatísticas no encerramento da campanha.
- **Fase 4B — PCIe:** identificação das GPUs por bus ID e leitura de counters NVML TX/RX; counters ainda não validados, nenhum benchmark. Ver [phase4b-pcie-report.md](phase4b-pcie-report.md).
- **GPU Control:** interface que grava uma política local; não existe Engine que a consuma. Ver [gpu-control.md](gpu-control.md).
- **OBS:** planejamento; NVENC por GPU não confirmado. Ver [obs-integration.md](obs-integration.md).

## O que o tempo da Fase 3 mede

O intervalo cronometrado inclui gravar a lista de comandos, executar o shader e copiar o resultado para a memória do sistema pelo PCIe. Com o shader leve usado, a cópia tende a dominar. Ver [research-methodology.md](research-methodology.md) e a [auditoria](audit/claude-audit-2026-11-19.md).

## Limites do protótipo

Os resultados das Fases 2–3 são cargas sintéticas. Não demonstram aceleração de jogos, composição de frames, apresentação ou escalabilidade de um motor gráfico. Resultados Cross-Adapter são dados compartilhados entre adaptadores, não VRAM unificada.

Diagramas: [architecture.md](architecture.md). Índice: [index.md](index.md).

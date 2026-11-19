# Visão técnica

## Componentes atuais

- **Fase 1 — diagnóstico:** identificação de CPU, memória, placas, PCIe, DXGI/D3D12 e CUDA Driver API.
- **Fase 2 — prova de conceito:** dispositivo/fila D3D12 independente por GPU, cálculo determinístico, verificação CPU e transferência Cross-Adapter com recursos compartilhados e fences.
- **Fase 3 — otimização:** partições locais independentes em GTX 970/GTX 750 Ti; mede execução solo, sequencial e paralela e a transferência final de resultados.
- **Fase 4 — observabilidade:** amostragem passiva a cada 30 segundos, com estatísticas no encerramento da campanha.

## Limites do protótipo

Os resultados das Fases 2–3 são cargas sintéticas de computação. Não demonstram aceleração de jogos, composição de frames, apresentação ou escalabilidade de um motor gráfico. Resultados Cross-Adapter são dados compartilhados entre adaptadores, não VRAM unificada.

Consulte os relatórios copiados em `docs/` e as fontes sob `phases/`.

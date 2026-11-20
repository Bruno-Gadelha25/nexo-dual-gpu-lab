# Estado das fases (2026-11-19)

| Módulo | Demonstrado | Planejado | Não testado |
|---|---|---|---|
| **Fase 1 — Diagnóstico** | Duas GPUs enumeradas por DXGI e CUDA; devices e filas D3D12 nas duas; heap Cross-Adapter aberto nos dois sentidos | — | estabilidade sob carga, slot físico, link máximo real |
| **Fase 2 — Prova de conceito** | Compute D3D12 nas duas GPUs ao mesmo tempo, validação total; Cross-Adapter com fence nos dois sentidos (1 MiB) | — | ganho estatístico (n=2), timestamps de GPU |
| **Fase 3 — Otimização** | Redução de 28,6% a 50,4% no tempo de geração + readback; consolidação mais cara que o ganho | escalonador adaptativo | se o ganho é de computação ou de link (C1); estabilidade entre sessões (H1); comportamento em Gen3 (H2) |
| **Fase 4 — Monitoramento** | Coletor passivo ativo (PID 14664 em 2026-11-19, iniciado 08:06) | relatório ao encerrar (prazo máximo 2026-11-24 07:54) | nenhum dado importado; anonimização pendente (M7) |
| **Fase 4B — PCIe** | Identificação por bus ID; 2 snapshots completos | validação dos counters; workloads pareados | throughput validado; correlação; contenção. Coletor atual com defeito (H4) |
| **GPU Control** | Interface abre, mostra telemetria somente leitura, grava política; self-test de 5 botões | schema versionado, scheduler em DRY RUN, workers | qualquer execução real nas GPUs; não há Engine |
| **OBS** | OBS 33.0.1 instalado; composição D3D11 vista na GTX 970 num log | perfis A–D | qual GPU faz o NVENC; gravação; desempenho |
| **NEXO AI COUNCIL** | — | projeto separado, outro repositório | tudo; não faz parte deste laboratório |

## Distinção entre resultados históricos e campanhas abertas

- **Históricos e fechados:** Fases 1, 2 e 3. Seus CSVs e relatórios não são editados. Correções ficam na [auditoria](audit/claude-audit-2026-11-19.md).
- **Abertos:** Fase 4 (coletando), Fase 4B (preparação), GPU Control e OBS (em desenvolvimento). Nada deles é resultado experimental ainda.

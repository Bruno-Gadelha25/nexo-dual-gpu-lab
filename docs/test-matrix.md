# Matriz de testes

Tipos: **E** = estático (sem GPU), **C** = compilação, **U** = unitário, **B** = benchmark sintético, **F** = teste físico com GPU, **X** = validação externa.

| Item | Tipo | Estado | Evidência | Observação |
|---|---|---|---|---|
| Inventário DXGI/D3D12 das duas GPUs | F | PASS (2026-11-19) | `phases/phase1-diagnostic/evidence/gpus-dxgi-d3d12.txt` | criação de device e filas DIRECT/COMPUTE/COPY |
| Abertura de heap Cross-Adapter nos dois sentidos | F | PASS | idem | sem cópia nem fence |
| CUDA Driver API enumera 2 GPUs | F | PASS | `cuda-driver-enum.txt` | nenhum kernel CUDA |
| Compute simultâneo com validação total | F + B | PASS | `benchmarks/phase2/benchmark.csv` | n=2 por cenário |
| Transferência e fence Cross-Adapter 970↔750 Ti | F | PASS (relatado) | `docs/phase2-report.md` | stdout não versionado |
| Grade da Fase 3 (1.200 linhas) | B | Concluída sem divergência | `benchmarks/phase3/benchmark.csv` | `PASS` por construção (auditoria M2) |
| Transferência final 750 Ti → 970 (500 linhas) | B | Concluída sem divergência | `benchmarks/phase3/transfer-benchmark.csv` | só um sentido |
| Recontagem e recálculo dos CSVs | E | PASS (2026-11-19) | `scripts/static-checks.ps1`, `analysis/reanalyze_phase3.py` | 0 divergências |
| Links Markdown | E | PASS (fora dos históricos) | `scripts/static-checks.ps1` | 7 links quebrados no relatório histórico da Fase 2 |
| Credenciais e caminhos no histórico | E | PASS | auditoria I1 | 5 commits |
| Sintaxe PowerShell | E | PASS | `scripts/static-checks.ps1` | sintaxe ≠ execução |
| Compilação C++/HLSL isolada | C | PASS (2026-11-19) | MSVC 19.51.36260, `/W4`, pasta temporária | Fases 2 e 3, sem erros |
| Sonda Fase 3b: com/sem cópia, 8 e 1.024 iterações | F + B | Concluída, 60/60 validações PASS | `data/phase3b-probe/2026-11-19/` | exploratória, n=10, uma sessão |
| Testes unitários | U | **NÃO EXISTEM** | — | candidato: função `expected()` e parsing de CSV |
| Coletor Fase 4B | F | **FALHA** no código atual (local) | auditoria H4 | quebra na 2ª GPU; não grava |
| Counters NVML PCIe | F | **NÃO VALIDADO** | 3 de 8 implausíveis | — |
| Self-test GPU Control v1.1 (5 botões + backups) | F (UI) | PASS 6/6 (2026-11-19) | `docs/gpu-control.md` | não testa execução nas GPUs |
| Responsividade da janela GPU Control | F (UI) | v1.0 FALHA (>30 s); v1.1 PASS (≤175 ms) | `docs/gpu-control.md` | cliques por `BM_CLICK` |
| Forza Horizon 4: 970 vs. duas placas | F (jogo) | 85 vs. 86 FPS; 750 Ti em repouso | `docs/fh4-test-2026-11-19.md` | n=1 por configuração; limitado pela CPU |
| NEXO GPU ENGINE: job distribuído vs. GTX 970 | F + B | 10,3–23,7% mais rápido, validação PASS (Teste 8) | `docs/gpu-engine.md` | poucas sessões, mesmo dia |
| GPU Control v2: botão do Engine | F (UI) | PASS; duas curvas a ~95% por 10 s (Teste 9) | `docs/experiment-log.md` | — |
| NVENC por GPU no OBS | F | **NÃO EXECUTADO** | `docs/obs-integration.md` | — |
| Monitoramento Fase 4 | F (passivo) | Em andamento | dados locais | não importado |
| Kernel isolado com timestamps de GPU | F + B | **INCONCLUSIVO** | `docs/phase3b-probe-report.md` | timestamps não esperaram a cópia neste driver; usado o tempo do host |
| Repetição em várias sessões | B | **NÃO EXECUTADO** | — | necessário para o achado H1 |
| Revisão por pessoa externa | X | **NÃO EXECUTADO** | — | — |
| CI GitHub Actions | E | configurado neste PR | `.github/workflows/static-checks.yml` | sem GPU |

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
| Compilação C++/HLSL isolada | C | **NÃO EXECUTADO** nesta auditoria | `scripts/validate-version.ps1 -Compile` | relatórios das Fases 2–3 dizem que compilou |
| Testes unitários | U | **NÃO EXISTEM** | — | candidato: função `expected()` e parsing de CSV |
| Coletor Fase 4B | F | **FALHA** no código atual (local) | auditoria H4 | quebra na 2ª GPU; não grava |
| Counters NVML PCIe | F | **NÃO VALIDADO** | 3 de 8 implausíveis | — |
| Self-test GPU Control (5 botões) | F (UI) | PASS (relatado) | relatório local do self-test | não testa execução nas GPUs |
| NVENC por GPU no OBS | F | **NÃO EXECUTADO** | `docs/obs-integration.md` | — |
| Monitoramento Fase 4 | F (passivo) | Em andamento | dados locais | não importado |
| Kernel isolado com timestamps de GPU | F + B | **NÃO EXECUTADO** | — | necessário para o achado C1 |
| Repetição em várias sessões | B | **NÃO EXECUTADO** | — | necessário para o achado H1 |
| Revisão por pessoa externa | X | **NÃO EXECUTADO** | — | — |
| CI GitHub Actions | E | configurado neste PR | `.github/workflows/static-checks.yml` | sem GPU |

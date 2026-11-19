# Índice da documentação

Comece pelo [README](../README.md). Para avaliar o rigor, leia a [auditoria independente](audit/claude-audit-2026-11-19.md).

## Visão geral

- [Visão técnica](technical-overview.md) — componentes e limites em uma página
- [Arquitetura](architecture.md) — diagramas do fluxo D3D12 e Cross-Adapter
- [Hardware e ambiente](hardware-and-environment.md)
- [Estado das fases](phase-status.md) — o que foi demonstrado, planejado e não testado
- [Glossário](glossary.md) · [FAQ](faq.md)

## Método e reprodução

- [Metodologia de pesquisa](research-methodology.md) — o que o tempo medido inclui e as ameaças à validade
- [Reprodutibilidade](reproducibility.md) — compilar, executar e registrar
- [Matriz de testes](test-matrix.md) — estático, compilação, físico, externo

## Relatórios por fase (históricos)

Os relatórios abaixo são preservados como foram escritos. Correções e ressalvas ficam na auditoria, não dentro deles.

| Relatório | Observação da auditoria |
|---|---|
| [Fase 1 — diagnóstico](phase1-hardware-report.md) | Cita `dxdiag.txt`, que não é versionado (ignorado por privacidade). |
| [Fase 2 — prova de conceito](phase2-report.md) | 7 links apontam para logs e binários locais não versionados. "Seleciona por LUID" não confere com o código (achado M1). |
| [Fase 3 — otimização](phase3-report.md) | Números conferem; interpretação revisada (achados C1, H1, H3). Linha 8M da tabela de transferência sem o valor absoluto (36,9987 ms). |
| [Fase 3b — sonda computação vs. cópia](phase3b-probe-report.md) | Campanha nova (2026-11-19). Sustenta C1 e confirma H2. |
| [Teste de jogo — Forza Horizon 4](fh4-test-2026-11-19.md) | 85 vs. 86 FPS; jogo usa uma placa; gargalo na CPU. |
| [Fase 4B — PCIe](phase4b-pcie-report.md) | Relatório de estado consolidado na auditoria. |
| [Progresso Fase 4B](progress/phase4b-pcie-progress-2026-11-19.md) | Resumo do operador. |
| [Progresso GPU Control](progress/nexo-gpu-control-progress-2026-11-19.md) | Resumo do operador. |

## Diário

- [Diário de experimentos](experiment-log.md) — Teste 1, Teste 2…, inclusive os inválidos

## Módulos em preparação

- [GPU Engine](gpu-engine.md)

- [GPU Control](gpu-control.md)
- [Integração OBS](obs-integration.md) · [Gravação do vídeo no OBS](obs-recording.md)
- Fase 4: [nota de logs ativos](../phases/phase4-monitoring/ACTIVE-LOGS.md)

## Dados

- Fase 2: [benchmark.csv](../benchmarks/phase2/benchmark.csv), [telemetry.csv](../benchmarks/phase2/telemetry.csv)
- Fase 3: [benchmark.csv](../benchmarks/phase3/benchmark.csv), [summary-statistics.csv](../benchmarks/phase3/summary-statistics.csv), [transfer-benchmark.csv](../benchmarks/phase3/transfer-benchmark.csv), [transfer-summary-statistics.csv](../benchmarks/phase3/transfer-summary-statistics.csv), [optimization-decision.csv](../benchmarks/phase3/optimization-decision.csv)
- Reanálise: [analysis/](../analysis/README.md)

## Governança

- [Privacidade](privacy-review.md) · [Dependências e licenças](dependencies-and-licenses.md) · [Versionamento](VERSIONING.md)
- [Roadmap](../planning/roadmap.md) · [Revisão de publicação](../planning/publication-review.md) · [Contribuição](../CONTRIBUTING.md)

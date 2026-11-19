# NEXO DUAL GPU LAB

Projeto privado de pesquisa sobre computação heterogênea com Direct3D 12, recursos Cross-Adapter e escalonamento de carga entre duas GPUs.

- **Versão:** consulte [`VERSION`](VERSION); changelog em [`CHANGELOG.md`](CHANGELOG.md).
- **Estado:** experimental alpha, não é um renderizador multi-GPU para jogos e não há ganho de FPS comprovado.
- **Repositório remoto:** `Bruno-Gadelha25/nexo-dual-gpu-lab`, visibilidade **PRIVATE** (confirmada em 2026-11-19). Nenhuma release pública está autorizada.

## Estrutura

- `phases/phase1-diagnostic/` — fontes e evidências da auditoria de hardware.
- `phases/phase2-prototype/` — fonte D3D12, prova de conceito e scripts.
- `phases/phase3-optimization/` — fonte, scripts, dados e resultados de benchmarks sintéticos.
- `phases/phase4-monitoring/` — scripts e nota da campanha passiva. Os logs ativos permanecem no diretório de origem e não devem ser copiados enquanto estiverem sendo escritos.
- `benchmarks/` — CSVs selecionados e auditados das Fases 2–3.
- `docs/` — arquitetura, resultados, dependências, privacidade e política de versões.
- `planning/` — próximos passos e revisões pendentes.

## Limites

As provas de conceito medem computação sintética, criação/uso de recursos compartilhados e sincronização. Elas não demonstram composição de frames, apresentação ou escalabilidade de um motor gráfico. A cópia Cross-Adapter não constitui memória VRAM unificada. Consulte os relatórios de cada fase e preserve seus CSVs originais.

## Desenvolvimento

- Política: [`docs/VERSIONING.md`](docs/VERSIONING.md)
- Histórico: [`VERSION_HISTORY.md`](VERSION_HISTORY.md)
- Dependências/licenças: [`docs/dependencies-and-licenses.md`](docs/dependencies-and-licenses.md)
- Privacidade: [`docs/privacy-review.md`](docs/privacy-review.md)
- Validação local: `powershell -NoProfile -File scripts/validate-version.ps1`

Builds e testes de hardware devem ser relatados separadamente. CI sem GTX 970 e GTX 750 Ti físicas não valida comportamento Multi-GPU real. A licença do projeto ainda não foi definida; não redistribuir.

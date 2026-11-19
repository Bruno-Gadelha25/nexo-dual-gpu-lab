# NEXO DUAL GPU LAB — área de trabalho privada

Este diretório contém cópias locais organizadas do projeto. O trabalho fica somente neste computador: não há remoto Git configurado, publicação ou compartilhamento.

## Estrutura

- `phases/phase1-diagnostic/` — fontes, executáveis de referência e evidências da auditoria de hardware.
- `phases/phase2-prototype/` — fonte D3D12, artefatos e logs históricos da prova de conceito.
- `phases/phase3-optimization/` — fonte, scripts, resultados e logs do benchmark de otimização.
- `phases/phase4-monitoring/` — scripts e snapshots documentais da campanha ativa.
- `benchmarks/phase2/` e `benchmarks/phase3/` — CSVs selecionados para análise e versionamento local.
- `docs/` — relatórios, arquitetura, privacidade e dependências/licenças.
- `planning/` — planejamento ainda não executado.

Os executáveis e logs brutos permanecem disponíveis na cópia local, mas são excluídos do Git por `.gitignore`. CSVs de benchmark selecionados estão versionados. As evidências brutas de diagnóstico podem conter identificadores do computador.

`copy-manifest.csv` registra os hashes SHA256 de 87 arquivos copiados e confirma que as cópias correspondem às fontes no momento da organização.

## Fase 4 ativa

Não copie, mova ou renomeie os arquivos em escrita em `E:\NEXO-DUAL-GPU\phase4-monitoring\logs\AAAA-MM-DD\`. A campanha ativa permanece na pasta original. Esta área inclui os scripts e uma nota de referência; os CSVs da coleta serão incorporados depois que a campanha encerrar.

## Histórico

Repositório Git local, branch `main`, sem remotes. O primeiro commit usa identidade local técnica `NEXO Dual GPU Lab (local) <nexo-dual-gpu-lab@local.invalid>`; essa identidade não está configurada globalmente e deve ser substituída pela identidade do proprietário antes de qualquer colaboração externa.

Consulte `docs/privacy-review.md`, `docs/dependencies-and-licenses.md` e `planning/publication-review.md` antes de qualquer futura publicação ou sincronização.

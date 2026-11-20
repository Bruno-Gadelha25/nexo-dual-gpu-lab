# Como contribuir

Repositório público. Issues e sugestões são bem-vindas; contribuições de código só com convite do proprietário.

## Regras do laboratório

1. **Não editar dados históricos.** CSVs em `benchmarks/` e relatórios de fase em `docs/phase*-report.md` são evidência. Correções vão para um documento novo (errata ou auditoria) e para o `CHANGELOG.md`.
2. **Não inventar resultados.** Todo número precisa de um CSV ou log que o sustente.
3. **Separar tipos de teste:** estático, compilação, unitário, benchmark sintético, teste físico com GPU e validação externa. Nunca apresentar CI como teste Multi-GPU.
4. **Hardware:** não alterar BIOS, drivers, registro ou dispositivos; não desabilitar GPU com monitor ativo; não fazer overclock nem teste térmico; não encerrar o monitor da Fase 4.
5. **Privacidade:** nada de credenciais, hostname, PIDs, logs ativos ou IDs de instância PnP. Rodar `scripts/static-checks.ps1` antes de cada PR.

## Fluxo Git

- Nunca commitar direto na `main`. Usar `feature/<nome>` ou `experiment/<nome>`.
- Pull Request com: resumo, arquivos alterados, motivo, testes executados (e não executados), limitações e riscos.
- Merge só com aprovação do proprietário. Sem force-push; tags não são movidas.
- Arquivos de texto em UTF-8.

## Antes de abrir o PR

```powershell
powershell -NoProfile -File scripts/static-checks.ps1
python -I analysis/reanalyze_phase3.py
```

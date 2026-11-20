# Reanálise independente

`reanalyze_phase3.py` lê os CSVs históricos de `benchmarks/phase3/` **somente para leitura** e grava resultados derivados em `output/`. Usa só a biblioteca padrão do Python 3.8+.

```powershell
python -I analysis/reanalyze_phase3.py
```

| Arquivo em `output/` | Conteúdo |
|---|---|
| `phase3-reduction-bootstrap.csv` | redução da mediana (melhor divisão paralela vs. GTX 970 sozinha) com IC 95% bootstrap (10.000 reamostragens, semente 20261119) |
| `phase3-implied-throughput.csv` | bytes do resultado ÷ mediana do tempo, para cada modo solo e cada transferência |
| `phase3-gtx970-baseline-consistency.csv` | GTX 970 com N elementos sozinha vs. a mesma GTX 970 com N elementos dentro do dual |
| `phase3-rep-trend-spearman.csv` | correlação de Spearman entre o número da repetição e o tempo, por grupo |

O script também reconta linhas e recalcula as estatísticas publicadas. Sai com código 1 se algo divergir.

**Limites:** o IC mede apenas a variação dentro da única sessão gravada. A "taxa implícita" é uma conta (bytes ÷ tempo total), não uma medição de largura de banda. A interpretação está em [../docs/audit/claude-audit-2026-11-19.md](../docs/audit/claude-audit-2026-11-19.md).

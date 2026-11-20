# Fase 4B — instrumentação PCIe: relatório de estado

**Estado:** validação inicial. **Nenhum benchmark foi executado.** Nenhuma correlação foi demonstrada.
**Base:** leitura, em 2026-11-19, dos arquivos locais `phase4b-report.md`, `pcie-analysis.md`, `pcie-telemetry.csv`, `gpu-throughput.csv`, `workload-timings.csv` e `collect-pcie.ps1` na pasta da Fase 4B da máquina do laboratório. Esses arquivos **não** foram importados para o repositório neste PR (contêm IDs de instância PnP e o coletor tem defeito; ver abaixo). Resumo anterior do operador: [progress/phase4b-pcie-progress-2026-11-19.md](progress/phase4b-pcie-progress-2026-11-19.md).

## Objetivo

Medir o tráfego PCIe TX/RX de cada GPU e, depois, relacioná-lo com execuções de compute e transferências Cross-Adapter. Separada da Fase 4 (monitoramento passivo); as duas não devem ser misturadas.

## Fonte dos counters

- `nvidia-smi` instalado não oferece `pcie.tx_throughput`/`pcie.rx_throughput` (campo rejeitado).
- Alternativa: `nvmlDeviceGetPcieThroughput` da `nvml.dll` do driver, com a GPU escolhida pelo bus ID. A NVIDIA documenta o valor em KB/s numa janela de cerca de 20 ms ([NVML Device Queries](https://docs.nvidia.com/deploy/nvml-api/latest/api/group__nvmlDeviceQueries.html)).
- TX = saindo da GPU; RX = entrando na GPU. Não dizem a origem/destino lógico nem provam tráfego peer-to-peer.
- Limite teórico usado para plausibilidade: 984,6 MB/s por lane em Gen3 (8 GT/s, codificação 128b/130b) × 8 lanes ≈ 7.877 MB/s por direção. Amostra acima de 110% desse valor é marcada `implausible_above_link_estimate`. O cálculo está correto.

## Dados existentes

| Arquivo | Linhas de dados | Conteúdo |
|---|---:|---|
| `pcie-telemetry.csv` | 5 | 2 snapshots completos (2 GPUs cada) + 1 linha isolada de tentativa incompleta |
| `gpu-throughput.csv` | 8 | 4 counters por snapshot completo |
| `workload-timings.csv` | 0 | só cabeçalho |

Counters:

| Snapshot | GPU | TX (KB/s) | RX (KB/s) |
|---|---|---:|---:|
| 13:40:58 | GTX 970 | 48 | 878 |
| 13:40:58 | GTX 750 Ti | **209.685.756** (implausível) | 48 |
| 13:55:08 | GTX 970 | 292 | **209.700.600** (implausível) |
| 13:55:08 | GTX 750 Ti | 195 | **209.665.102** (implausível) |

- Os três valores implausíveis estão todos entre 209,66 e 209,70 milhões de KB/s, cerca de 26 vezes o teórico. Um patamar tão estreito sugere valor-sentinela ou leitura inválida, não ruído. Causa não determinada.
- 37,5% de leituras inválidas: o instrumento **não está validado**.
- O snapshot de 13:55 mostrou 18% de uso na GTX 970: não é baseline ocioso, apesar do nome `diagnostic_idle`.
- Link nas leituras: Gen3 x8 nas duas GPUs, `hostmax=3`. As Fases 1–3 registraram Gen1 x8 com `hostmax=1`. Ver [hardware-and-environment.md](hardware-and-environment.md).

## Defeito no coletor atual (achado H4 da auditoria)

`collect-pcie.ps1` acumula linhas com `$telemetryBatch += $tele` e `$throughputBatch += $through` sem inicializar os arrays. No PowerShell, o segundo `+=` sobre um objeto único falha (`op_Addition`); reproduzi o padrão com objetos simulados, sem hardware. O script também não tem nenhuma instrução que grave CSV. Portanto, a frase "o coletor grava um lote somente após obter as duas linhas de GPU e os quatro counters" **não corresponde ao código atual**. Os CSVs existentes vieram de uma versão anterior, não preservada.

Correção proposta (não aplicada; o arquivo é local):

```powershell
$telemetryBatch = @(); $throughputBatch = @()   # no início de cada lote
# ... coleta ...
if ($telemetryBatch.Count -eq 2 -and $throughputBatch.Count -eq 4) {
    $telemetryBatch  | Export-Csv -Append -NoTypeInformation -Encoding UTF8 (Join-Path $root 'pcie-telemetry.csv')
    $throughputBatch | Export-Csv -Append -NoTypeInformation -Encoding UTF8 (Join-Path $root 'gpu-throughput.csv')
} else { Write-Warning 'Lote incompleto descartado' }
```

## Próximos passos (antes de qualquer carga)

1. Corrigir e testar o coletor com dados simulados.
2. Fazer dezenas de leituras sem carga e medir a taxa de valores implausíveis; consultar a NVIDIA/driver se persistir.
3. Validar escala e unidade com uma transferência de tamanho conhecido (ex.: o readback de 32 MB da Fase 3).
4. Só então parear tempos de execução com `RunId` e timestamps.
5. Separar correlação de causa; preservar valores crus.

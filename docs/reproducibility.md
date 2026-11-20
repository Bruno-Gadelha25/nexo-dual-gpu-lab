# Reprodutibilidade

## Níveis de reprodução

| Nível | Precisa de GPU? | Como |
|---|---|---|
| 1. Conferir os dados publicados | Não | `powershell -NoProfile -File scripts/static-checks.ps1` e `python -I analysis/reanalyze_phase3.py` |
| 2. Compilar os fontes | Não (só toolchain) | `build.ps1` de cada fase, ou `scripts/validate-version.ps1 -Compile` |
| 3. Diagnóstico de capacidade | Sim, leitura | `scripts/validate-version.ps1 -RunHardwareCompatibility -ConfirmHardwareCompatibility` (recusa se o monitor da Fase 4 estiver ativo) |
| 4. Repetir benchmarks | Sim, carga real | `run-with-telemetry.ps1` (Fase 2), `run-suite.ps1` (Fase 3) — **só com autorização do proprietário** |

Os níveis 1 e 2 podem ser feitos por qualquer avaliador. Os níveis 3 e 4 exigem a máquina com GTX 970 + GTX 750 Ti ou equivalente.

## Requisitos

- Windows 10/11 x64; duas GPUs NVIDIA com D3D12 (o código exige `VendorId 0x10DE` em pelo menos dois adaptadores).
- Visual Studio Build Tools com MSVC x64 e Windows SDK 10.0.26100 (`fxc.exe`).
- `build.ps1` tem caminhos fixos para `VS\18\BuildTools` e para o SDK 10.0.26100. Ajuste se a sua instalação for diferente.
- Python 3.8+ (só biblioteca padrão) para a reanálise.

## Compilar

```powershell
cd phases/phase3-optimization/source
powershell -NoProfile -File build.ps1
```

O script compila `compute.hlsl` com `fxc /T cs_5_1 /O3` e `nexo_dual_gpu.cpp` com `cl /std:c++17 /O2 /W4`. Saídas `.exe` e `.cso` são ignoradas pelo Git. O build grava em `logs/build.log`; crie a pasta `logs` antes se ela não existir.

## Executar a Fase 3 (com autorização)

```powershell
powershell -NoProfile -File run-suite.ps1 -Mode preflight   # uma execução curta
powershell -NoProfile -File run-suite.ps1 -Mode full
powershell -NoProfile -File summarize.ps1
```

- O monitor da Fase 4 não deve ser interrompido. Não execute benchmarks enquanto ele estiver ativo sem decidir como separar os dados.
- Trava térmica: o script cria `logs/thermal-stop.flag` a 75 °C ou 3.700 MiB por GPU; o programa para entre medições.
- Os CSVs novos são gravados na pasta do fonte. **Não sobrescreva** `benchmarks/phase3/`; crie uma pasta nova datada.

## O que registrar em cada execução

1. Commit do código e hash SHA-256 do `.exe` e do `.cso`.
2. Versões: Windows (build), driver NVIDIA, SDK, MSVC.
3. Estado do link PCIe das duas GPUs **durante a carga**, com o mesmo campo `nvidia-smi`.
4. Processos gráficos ativos (OBS, navegador, jogos) e qual GPU tem monitor.
5. Ordem das medições e semente, se aleatória.
6. Temperaturas e clocks no início e no fim.

## Limites conhecidos

- Logs brutos (stdout, telemetria crua) das Fases 2–3 ficaram na máquina e não estão no repositório.
- Os resultados da Fase 3 foram obtidos com link Gen1 x8. Leituras posteriores mostram Gen3 x8; os números devem mudar.
- CI não tem GPU. Um CI verde nunca vale como teste Multi-GPU.

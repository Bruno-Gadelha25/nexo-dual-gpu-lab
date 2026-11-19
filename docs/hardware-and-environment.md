# Hardware e ambiente

Fonte principal: [relatório da Fase 1](phase1-hardware-report.md) e `phases/phase1-diagnostic/evidence/`. Coleta de 2026-11-19, somente leitura.

## Máquina

| Componente | Valor | Evidência |
|---|---|---|
| CPU | Intel Core i7-3770K, Ivy Bridge, 4c/8t, 3,5 GHz (máx. 3,9) | `cpu-e-memoria.txt`, `cpu-cpuid.txt` |
| Instruções | SSE4.2, AVX, F16C presentes; AVX2, BMI1/2, AVX-512 ausentes | `cpu-cpuid.txt` |
| RAM | 4 × 8 GiB Corsair DDR3-1600, ~32 GiB | `cpu-e-memoria.txt` |
| Placa-mãe | Gigabyte Z77X-UP5 TH (SMBIOS `Z77X-UP5 TH-CF`), BIOS AMI F12 de 2014-05-14 | `cpu-e-memoria.txt` |
| Sistema | Windows 11 Pro 64 bits, build 26200 | `diagnostico-completo.txt` |
| Driver | NVIDIA 582.78, WDDM 3.2 | `nvidia-e-cuda.txt` |

## GPUs

| | GTX 970 | GTX 750 Ti |
|---|---|---|
| Chip | GM204 (Maxwell 2ª geração) | GM107 (Maxwell 1ª geração) |
| Núcleos CUDA (especificação NVIDIA) | 1.664 | 640 |
| VRAM | 4 GiB (pool próprio) | 4 GiB (pool próprio) |
| Feature level D3D12 máximo | 12_1 | 11_0 |
| Compute capability | 5.2 | 5.0 |
| NVENC | H.264 e HEVC | H.264 (sem HEVC) |
| Endereço PCI | bus 1 | bus 2 |
| Ordem DXGI observada | adapter 0 | adapter 1 |

As duas VRAMs são independentes. Um recurso Cross-Adapter fica num heap compartilhado; isso não soma memória.

## Link PCIe — estado observado

| Momento | GTX 970 | GTX 750 Ti | `hostmax` | Fonte |
|---|---|---|---|---|
| Fase 1 (madrugada) | Gen1 x8 | Gen1 x8 | 1 | `pcie-e-placa-mae.txt` |
| Fase 2 (01:42) | Gen1 x8 | Gen1 x8 | — | `benchmarks/phase2/telemetry.csv` |
| Fase 3 | Gen1 x8 (antes/depois) | Gen1 x8 | — | relatório da Fase 3 |
| Fase 4B (13:40–13:55) | Gen3 x8 | Gen3 x8 | 3 | CSV local da Fase 4B |
| Self-test GPU Control (13:53) | Gen3 x8 | Gen3 x8 | — | relatório local do self-test |

- A CPU e a placa suportam PCIe 3.0 em x16, x8/x8 ou x8/x4/x4. As duas GPUs em x8 é coerente com dois slots ocupados.
- A mudança de `hostmax` 1 → 3 não tem causa registrada (BIOS, reinicialização ou plano de energia são hipóteses, não fatos).
- A Fase 4B lê `pcie.link.gen.gpucurrent`; as Fases 2–3 leram `pcie.link.gen.current`. Use o mesmo campo nas próximas campanhas.
- Um relato verbal diz que a GTX 750 Ti estaria num slot Gen1 x4. As evidências versionadas mostram x8 nas duas. O slot físico de cada placa continua **não confirmado**.

## Ferramentas usadas

Visual Studio Build Tools 18 (MSVC), Windows SDK 10.0.26100, `fxc` (Shader Model 5.1), `nvidia-smi`, `nvcuda.dll` e `nvml.dll` do driver, PowerShell 5.1, CIM/WMI. Nenhuma foi instalada pelo projeto. CUDA Toolkit não está instalado.

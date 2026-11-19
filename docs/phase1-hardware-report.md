# NEXO Dual GPU — Fase 1: diagnóstico de hardware

Data da coleta: 19/11/2026. Windows 11 Pro 64 bits (CIM build 26200; DxDiag DirectX 12, WDDM 3.2). Procedimentos somente de leitura, mais dois programas diagnósticos locais compilados com Visual Studio Build Tools e Windows SDK já existentes. Não foram instalados componentes, alterados drivers/BIOS/registro/PATH, desativadas GPUs ou executados benchmarks, estresse, kernels CUDA ou renderização.

## Resumo executivo e classificação

| Pergunta | Resultado |
|---|---|
| 1. As duas GPUs estão funcionando corretamente? | **PARCIALMENTE CONFIRMADO** — ambas estão presentes/OK no inventário Windows/NVIDIA e permitem D3D12, filas e chamadas CUDA de enumeração. Isso não valida estabilidade sob carga, portas de vídeo nem funcionamento em jogos. |
| 2. Podem ser acessadas simultaneamente? | **CONFIRMADO** — DXGI enumera duas adapters NVIDIA distintas com LUIDs diferentes; CUDA Driver API enumera 2 devices numa inicialização. |
| 3. Ambas criam dispositivos D3D12? | **CONFIRMADO** — `D3D12CreateDevice` deu S_OK em cada uma; filas DIRECT, COMPUTE e COPY também. Feature level máximo relatado: GTX970 12_1; GTX750 Ti 11_0. |
| 4. Existe possibilidade técnica de Cross-Adapter Resources? | **CONFIRMADO para criação/abertura básica** — no probe D3D12 as duas direções criaram heap compartilhado, criaram textura row-major elegível, abriram o heap na outra adapter e criaram recurso colocado no heap aberto. Não executamos comandos de cópia, fence, leitura ou escrita entre placas. |
| 5. É possível distribuir renderização entre elas? | **PARCIALMENTE CONFIRMADO** — APIs permitem dois dispositivos e filas separadas e recurso compartilhado básico; logo um protótipo explícito pode atribuir tarefas a cada GPU. Não provado que um motor/jogo existente use ambas nem que desempenho total aumente. |
| 6. Gargalos de PCIe, CPU e RAM | **PARCIALMENTE CONFIRMADO** — CPU Ivy Bridge 4c/8t e link observado Gen1 x8 em cada placa; manual/CPU suportam modos superiores. Limite efetivo de host e motivo do Gen1 estão em conflito entre ferramentas. 32 GiB DDR3-1600 instalados. |
| 7. API mais adequada para protótipo | **Direct3D 12** para o protótipo de gráficos: no PC já está disponível e passou o teste de dois dispositivos e Cross-Adapter. CUDA é opção para tarefas de compute customizadas, mas falta Toolkit/`nvcc`; não mistura memória automaticamente. |
| 8. Recursos a desenvolver do zero | **CONFIRMADO como trabalho de software necessário** — seleção de adapter, divisão de tarefas, sincronização por fences, gestão de recursos, transferência/compartilhamento, composição final numa GPU/saída, tratamento de GPU secundária mais lenta/FL inferior, fallback e recuperação de erros. O teste atual não implementa esses mecanismos de execução. |
| 9. O que não foi comprovado | Renderização real multi-GPU; cópia/sincronização efetiva por comandos; escalabilidade/desempenho; compatibilidade de jogos; latência; estabilidade prolongada; slot físico de cada placa; máximo PCIe negociável em carga; compilação/executabilidade de kernels CUDA; funcionamento da iGPU Intel. |

**Conclusão:** há base técnica para um protótipo experimental próprio em D3D12. As duas GPUs aparecem como adapters independentes e a troca de handles Cross-Adapter foi aceita nos dois sentidos. Isso não é SLI, não agrega as duas VRAM de 4 GiB e não ativa aceleração conjunta automaticamente. O gargalo mais claro medido é o PCIe atual Gen1 x8; a divergência sobre máximo da plataforma deve ser investigada separadamente antes de qualquer otimização. GTX750 Ti limita os recursos comuns ao feature level 11_0, embora cada GPU possa executar tarefas diferentes com seu próprio dispositivo.

## Inventário verificado

### GTX 970

- Nome: NVIDIA GeForce GTX 970; PCI VEN_10DE / DEV_13C2; subsystem 85081043; revision A1. PCI BDF `00000000:01:00.0`.
- Driver NVIDIA 582.78 (WMI 32.0.15.8278), WDDM 3.2.
- VRAM: NVSMI 4096 MiB total (2889 MiB livre na amostra); DxDiag 4030 MB dedicados disponíveis. DXGI `DedicatedVideoMemory=4,226,416,640` bytes. DXGI/DxDiag memória compartilhada reportada ~16 GiB (DxDiag 16364 MB); não é memória de vídeo dedicada.
- Arquitetura Maxwell, compute capability 5.2 (NVSMI).
- DirectX runtime no sistema: 12; DDI 12. Níveis suportados: 12_1, 12_0, 11_1, 11_0, 10_1, 10_0, 9_3, 9_2, 9_1, 1_0_CORE. Shader Model: query D3D12 devolveu enum 0x68 (6.8).
- D3D12 device e filas direct/compute/copy: S_OK. ResourceBindingTier 3, ResourceHeapTier 1, CrossNodeSharingTier reportado 0; NodeCount 1.

### GTX 750 Ti

- Nome: NVIDIA GeForce GTX 750 Ti; PCI VEN_10DE / DEV_1380; subsystem 105F10DE; revision A2. PCI BDF `00000000:02:00.0`.
- Mesmo driver NVIDIA 582.78 / WDDM 3.2.
- VRAM: NVSMI 4096 MiB total (3615 MiB livre na amostra); DxDiag 4044 MB dedicados disponíveis. DXGI `DedicatedVideoMemory=4,241,424,384` bytes. Memória compartilhada reportada ~16 GiB (não dedicada).
- Arquitetura Maxwell, compute capability 5.0 (NVSMI).
- DirectX runtime 12, DDI 12. Níveis suportados: 11_0, 10_1, 10_0, 9_3, 9_2, 9_1, 1_0_CORE. Shader Model query devolveu enum 0x68 (6.8).
- D3D12 device e filas direct/compute/copy: S_OK. ResourceBindingTier 3, ResourceHeapTier 1, CrossNodeSharingTier reportado 0; NodeCount 1.

A query D3D12 de Shader Model consultou uma lista decrescente e informou 6.8 nas duas adapters. A evidência é o valor da API/driver, não uma validação de compilação de shaders nem de todas as funcionalidades específicas do shader model em ambas as GPUs.

### Placa, CPU e memória

SMBIOS informa placa Gigabyte `Z77X-UP5 TH-CF`, BIOS AMI F12 datada de 2014-05-14. O campo de revisão SMBIOS `x.x` e modelo genérico não comprovam revisão física; o nome coincide com a GA-Z77X-UP5 TH Rev. 1.0 comercial. A documentação oficial dessa placa descreve chipset Intel Z77. Não foi aberta a máquina para ler silk-screen.

CPU: Intel Core i7-3770K, 4 núcleos/8 threads, CPUID BFEBFBFF000306A9. CPUID local: SSE3/SSSE3/SSE4.1/SSE4.2, AVX, FMA, F16C presentes; AVX2, BMI1, BMI2 e AVX-512F ausentes. CPU Intel ARK lista AVX (não AVX2) e PCIe 3.0 até x16, x8/x8 ou x8+x4+x4.

Memória: 4×8 GiB Corsair `CMP32GX3M4X1600C10`, DDR3-1600 configurada, rótulos WMI correspondem a dois DIMMs por canal. Total CIM 34,318,626,816 bytes (~32 GiB). A placa especifica máximo 32 GB; instalado equivale ao limite oficial.

## DXGI, D3D12 e Multi-Adapter

O programa local `gpus-dxgi-d3d12.exe` enumerou GTX 970, GTX 750 Ti e Microsoft Basic Render Driver (software). Os LUIDs das NVIDIA são diferentes. Para cada NVIDIA: criar D3D12 device no mínimo FL 11_0, consultar nível máximo e recursos, criar filas direct/compute/copy; todos os retornos foram `HRESULT=0x00000000`.

Cross-Adapter probe feito apenas com heap/recursos pequenos, sem submissão de trabalho GPU:
- GTX 970 → GTX 750 Ti: CreateHeap S_OK; textura 2D row-major com recurso cross-adapter S_OK; CreateSharedHandle S_OK; OpenSharedHandle no peer S_OK; CreatePlacedResource no heap peer S_OK.
- GTX 750 Ti → GTX 970: mesmos resultados S_OK.
- Um primeiro ensaio de buffer committed/flags inadequadas retornou E_INVALIDARG; foi corrigido para a forma documentada de heap compartilhado e textura row-major. A conclusão usa apenas o ensaio final bem-sucedido.

O teste confirma criação/abertura interoperável do objeto, não coerência de dados, sincronização, cópia ou leitura/escrita entre GPUs. Isso exige comandos e fences cross-adapter e validação específica. O campo `CrossNodeSharingTier=0` consultado é um recurso multi-node no mesmo dispositivo lógico e não contradiz a abertura cross-adapter observada em adapters independentes.

## PCIe: leitura cuidadosa

PNP e NVSMI observaram Gen1 x8 nos dois links durante a amostra. PnP endpoint informa máximo Gen3 x16; NVSMI mostra gpumax=3, hostmax=1 e gen.max=1. A placa-mãe/CPU documentam PCIe Gen3 e modos lane split, criando divergência com hostmax=1. Assim, reportamos link atual Gen1 x8 e não alegamos capacidade negociada máxima real; a velocidade em repouso pode variar e não foi feita carga/benchmark. PnP caminhos PEG0/PEG1 identificam raízes, não os nomes serigrafados dos slots, então slot físico de cada placa fica NÃO CONFIRMADO.

## CUDA

O teste usando `nvcuda.dll` (API de driver presente com driver NVIDIA) chamou `cuInit(0)` e enumerou 2 devices: GTX970 CC 5.2 e GTX750Ti CC 5.0. Não executou kernel. Não foi encontrado `nvcc`, CUDA Toolkit, nem CUDA_PATH. A indicação “CUDA Version 13.0” do NVSMI é compatibilidade máxima do driver, não instalação do Toolkit. Torch está instalado CPU-only. A documentação CUDA Maxwell descreve suporte nativo sm_50 desde Toolkit 6.0 e sm_52 desde 6.5; notas CUDA atuais precisam ser conferidas para a versão do toolkit escolhida, que não existe neste host.

## Método, limitações e arquivos

Consultas: CIM/WMI, dxdiag, NVSMI, PnPUtil, CPUID e APIs DXGI/D3D12/CUDA Driver. Compilador VS Build Tools 18.10.2 e SDK Windows 10.0.26100 já existiam; nenhum componente foi instalado. Os dois pequenos diagnósticos e fontes estão nesta pasta. `dxdiag.txt` preserva a saída bruta do DxDiag.

### Fontes oficiais

- Intel ARK i7-3770K: https://www.intel.com/content/www/us/en/products/sku/65523/intel-core-i73770k-processor-8m-cache-up-to-3-90-ghz/specifications.html
- GIGABYTE GA-Z77X-UP5 TH Rev. 1.0: https://www.gigabyte.com/Motherboard/GA-Z77X-UP5-TH-rev-10
- Manual GIGABYTE (slots e compartilhamento): https://download1.gigabyte.com/Files/Manual/mb_manual_ga-z77x-up5_th_e.pdf
- Microsoft Direct3D 12 multi-adapter: https://learn.microsoft.com/en-us/windows/win32/direct3d12/multi-engine
- Microsoft shared heaps / Cross-Adapter: https://learn.microsoft.com/en-us/windows/win32/direct3d12/shared-heaps
- NVIDIA Maxwell CUDA compatibility: https://docs.nvidia.com/cuda/maxwell-compatibility-guide/
- NVIDIA CUDA 13.0 Update 1 release notes: https://docs.nvidia.com/cuda/archive/13.0.1/cuda-toolkit-release-notes/index.html

### Classificação global

- **CONFIRMADO:** duas GPUs NVIDIA independentes enumeradas em DXGI; D3D12 device e filas em ambas; CUDA Driver API enumera ambas; abertura de heap/recurso Cross-Adapter em ambos os sentidos; CPU e RAM identificadas.
- **PARCIALMENTE CONFIRMADO:** funcionamento geral das GPUs; capacidade de construir sistema que atribua tarefas a ambas; limites teóricos de plataforma e PCIe.
- **NÃO SUPORTADO:** AVX2/BMI1/BMI2 pelo i7-3770K conforme CPUID. “Somar VRAM” como um único espaço automático não é mecanismo fornecido por estes testes.
- **NÃO FOI POSSÍVEL TESTAR:** benchmark/estabilidade, renderização multi-GPU, cópia e sincronização real via comandos, jogos, kernels CUDA compilados, slot físico de cada placa, link Gen3 x8/x8 em uso/carga, revisão física exata da placa e iGPU Intel.

Este relatório encerra a fase diagnóstica; nenhum sistema Multi-GPU foi iniciado ou implementado.

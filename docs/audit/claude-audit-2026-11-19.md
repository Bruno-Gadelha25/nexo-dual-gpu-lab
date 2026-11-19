# Auditoria técnica e científica independente — 2026-11-19

**Escopo:** `main` em `c64e9c1` (versão `0.1.0-alpha.1`, tag `v0.1.0-alpha.1`), mais leitura somente dos arquivos locais em `E:\NEXO-DUAL-GPU\` (Fase 4, Fase 4B, GPU Control, OBS) e da worktree não commitada do Codex (`feature/repository-readiness-2026-11-19`).
**Auditor:** Claude (Anthropic), a pedido do proprietário.
**Modo:** somente leitura para dados e hardware. Nenhum benchmark, teste de GPU, alteração de driver/BIOS/dispositivo ou interrupção de processo foi feito. O monitor da Fase 4 (PID 14664) foi apenas consultado e continua ativo.

> Regra usada: um número só foi aprovado depois de recalculado a partir do CSV bruto. Uma afirmação só foi aprovada se o código ou os dados a sustentam. Texto bem escrito não conta como evidência.

## 1. Resumo para quem tem cinco minutos

1. **Os números da Fase 3 estão corretos.** Recontei 1.200 + 500 linhas e recalculei as 68 linhas de estatística: zero divergências. As reduções de 28,6% a 50,4% e o custo da consolidação (38,3% a 76,1% mais lento) se reproduzem exatamente.
2. **A interpretação do ganho não está sustentada.** O tempo chamado de "computação" inclui a cópia do resultado da GPU para a memória do sistema pelo PCIe. O kernel é trivial (8 iterações de inteiros). A taxa implícita é de 1,1 a 1,5 GB/s, perto do limite prático de um link PCIe Gen1 x8, e a GTX 750 Ti empata com a GTX 970 nas cargas grandes, apesar de ter cerca de 2,6 vezes menos núcleos. A explicação mais provável para o ganho é **dois links PCIe copiando em paralelo**, não duas GPUs computando. Isso precisa ser confirmado com timestamps de GPU.
3. **O baseline da GTX 970 é instável.** A mesma GTX 970 fez 4 milhões de elementos 21% mais rápido dentro de uma execução dual do que sozinha. A ordem das medições não foi aleatorizada. O 50,4% de pico depende desse baseline.
4. **O estado do PCIe mudou entre campanhas** (Gen1 x8 com `hostmax=1` nas Fases 1–3; Gen3 x8 com `hostmax=3` na Fase 4B), sem causa documentada. Os resultados da Fase 3 valem para o estado Gen1.
5. **O coletor atual da Fase 4B não funciona** como a documentação diz: quebra na segunda GPU e não tem nenhuma instrução que grave CSV.
6. **Privacidade:** nenhuma credencial, hostname ou PID encontrado em nenhum dos 5 commits alcançáveis.
7. **Veredicto:** pronto para revisão interna como **relatório de laboratório exploratório**. Não está pronto para ser apresentado como evidência de ganho de computação multi-GPU.

## 2. Tabela de severidade

| ID | Sev. | Título curto | Onde |
|---|---|---|---|
| C1 | CRITICAL | "Ganho de computação" mede sobretudo cópia GPU→host pelo PCIe | `phases/phase3-optimization/source/nexo_dual_gpu.cpp` (`encode`, `soloRun`); `docs/phase3-report.md` §Resumo |
| H1 | HIGH | Baseline da GTX 970 instável e ordem de medição não aleatória | `benchmarks/phase3/benchmark.csv`; `nexo_dual_gpu.cpp` (laço medido) |
| H2 | HIGH | Estado do link PCIe mudou entre campanhas sem explicação | Fase 1 evidência vs. `docs/progress/phase4b-pcie-progress-2026-11-19.md` |
| H3 | HIGH | Custo da consolidação é soma de medianas de experimentos separados e inclui um salto extra | `docs/phase3-report.md` §Transferência; `optimization-decision.csv` |
| H4 | HIGH | Coletor da Fase 4B quebra e não grava dados (local) | `E:\NEXO-DUAL-GPU\phase4b-pcie\collect-pcie.ps1` |
| H5 | HIGH | Trabalho não commitado do Codex corrompe acentos e reescreve evidência histórica (local) | worktree `feature/repository-readiness-2026-11-19` |
| M1 | MEDIUM | GPU escolhida pela ordem de enumeração, não por LUID como o relatório diz | `phases/phase2-prototype/source/nexo_dual_gpu.cpp`, `phases/phase3-optimization/source/nexo_dual_gpu.cpp`; `docs/phase2-report.md` §2 |
| M2 | MEDIUM | `validation=PASS` é garantido por construção; `Integrity` fixo no script | `nexo_dual_gpu.cpp` (`recordCompute`), `summarize.ps1` |
| M3 | MEDIUM | Melhor divisão escolhida e reportada nos mesmos dados; sem IC; uma única sessão | `docs/phase3-report.md` §Melhor divisão |
| M4 | MEDIUM | Telemetria esparsa e pareamento frágil das GPUs | `run-suite.ps1`, `run-with-telemetry.ps1` |
| M5 | MEDIUM | Evidências citadas não estão no repositório | `docs/phase2-report.md`, `docs/phase3-report.md`, `docs/phase1-hardware-report.md` |
| M6 | MEDIUM | Counters NVML: 3 de 8 implausíveis, todos no mesmo patamar (~209,7 milhões KB/s) | `E:\NEXO-DUAL-GPU\phase4b-pcie\gpu-throughput.csv` |
| M7 | MEDIUM | Monitor da Fase 4 grava hostname e lista de processos | `phases/phase4-monitoring/source/monitor.ps1` |
| M8 | MEDIUM | Reprodutibilidade: caminhos fixos de toolchain, versões não registradas por execução | `phases/*/source/build.ps1` |
| M9 | MEDIUM | GPU Switcher tem caminho de desabilitar dispositivo | `E:\NEXO-DUAL-GPU\gpu-switcher\gpu-switcher.ps1` |
| L1 | LOW | Linha de 8M da tabela de transferência sem o valor absoluto | `docs/phase3-report.md` §Transferência |
| L2 | LOW | `$args` (variável automática) sobrescrita | `run-suite.ps1` linha 9 |
| L3 | LOW | Esperas `INFINITE` e liberação de recursos sem drenar filas em caso de erro | `nexo_dual_gpu.cpp` (`wait`, `dualParallel`, `catch`) |
| L4 | LOW | `copy-manifest.csv` com caminhos absolutos `E:\` | `copy-manifest.csv` |
| L5 | LOW | README sem resultados, hardware, reprodução ou navegação; mistura de idiomas | `README.md`, `CHANGELOG.md`, `docs/VERSIONING.md` |
| I1 | INFO | Histórico sem credenciais, hostname ou PIDs | todos os commits |
| I2 | INFO | "750 Ti em slot Gen1 x4" (relato verbal) não aparece nas evidências | Fase 1 evidência |
| I3 | INFO | Licença indefinida (decisão do proprietário) | — |

## 3. Achados em detalhe

### C1 — "Ganho de computação" mede sobretudo cópia GPU→host — CRITICAL

- **Onde:** `phases/phase3-optimization/source/nexo_dual_gpu.cpp`, função `Gpu::encode` (o `CopyBufferRegion` para o buffer `READBACK` está na mesma lista do `Dispatch`) e `soloRun`/`dualParallel` (o intervalo medido vai de antes do `encode` até o fim do fence). Afirmação em `docs/phase3-report.md`, §Resumo executivo: "A computação D3D12 paralela em duas GPUs foi mais rápida".
- **Evidência:**
  1. O tempo inclui: gravação da lista no CPU + `Dispatch` + cópia de `4×N` bytes da VRAM para um heap `READBACK` (memória do sistema, atravessa o PCIe) + sinalização do fence.
  2. O shader faz 8 iterações de cerca de 8 operações inteiras por elemento. Para 8M elementos são cerca de 0,5 bilhão de operações; numa GTX 970 (ordem de TOPS) isso é uma fração de milissegundo. É uma estimativa de ordem de grandeza, não uma medição.
  3. Taxa implícita (bytes do resultado ÷ mediana do tempo), em `analysis/output/phase3-implied-throughput.csv`: GTX 970 1,19 / 1,13 / 1,21 / 1,52 GB/s e GTX 750 Ti 0,77 / 0,81 / 1,42 / 1,47 GB/s (1M/2M/4M/8M). O teórico de PCIe Gen1 x8 é 2,0 GB/s por direção; Gen3 x8 é cerca de 7,9 GB/s.
  4. A GTX 750 Ti (640 núcleos CUDA) empata ou vence a GTX 970 (1.664 núcleos) em 4M e 8M. Num gargalo de computação isso não aconteceria; num gargalo de link idêntico (ambas Gen1 x8), acontece.
  5. O split 50/50 em 8M leva 11,12 ms, quase exatamente metade dos 21,0 ms solo: cada GPU copia metade dos bytes pelo seu próprio link.
- **Consequência:** a frase "ganho de 28,6% a 50,4% na computação" atribui o efeito ao mecanismo errado. O mais provável é que o experimento meça **a soma das larguras de banda de dois links PCIe** durante o readback. Isso continua sendo um resultado real e interessante, mas é outro resultado.
- **Correção:** (a) reescrever a conclusão como "tempo de geração + readback ao host"; (b) nova campanha (Fase 3b) com `ID3D12QueryHeap` de timestamps (`GetTimestampFrequency`) separando kernel e cópia por GPU; (c) variante sem readback no intervalo medido; (d) kernel com carga computacional ajustável (ex.: 8, 256, 4096 iterações) para achar o ponto em que deixa de ser limitado por cópia.
- **Como verificar:** com timestamps, o tempo de kernel da GTX 750 Ti deve ser cerca de 2 a 3 vezes o da GTX 970; o tempo de cópia deve escalar com bytes e com o estado do link. Se o ganho dual persistir com kernel pesado e sem readback, C1 fica resolvido.

### H1 — Baseline da GTX 970 instável e ordem não aleatória — HIGH

- **Onde:** laço medido em `nexo_dual_gpu.cpp` (para cada N: 20× GTX 970 solo, depois 20× GTX 750 Ti solo, depois cada divisão em blocos); `benchmarks/phase3/benchmark.csv`.
- **Evidência (`analysis/output/phase3-gtx970-baseline-consistency.csv`):** mediana da GTX 970 com 4M elementos sozinha = 13,27 ms; a mesma GTX 970 processando 4M elementos dentro do dual 8M 50/50 = 10,49 ms (−21,0%). Com 2M: 7,09 ms sozinha e 6,59 ms dentro do dual (−7,1%). No grupo GTX 970 solo 8M há tendência forte de queda ao longo das repetições (Spearman −0,83). A GTX 750 Ti solo 4M tem DP 3,80 ms e p95 18,91 ms.
- **Consequência:** o denominador das reduções não está em regime estável. Usando 10,49 ms como baseline de 4M, a redução seria cerca de 37%, não 50,4%. O IC bootstrap (agora calculado: 4M = 48,4% a 51,2%) só mede o ruído **dentro** de uma sessão; não captura deriva entre blocos.
- **Correção:** intercalar modos em ordem aleatória com semente registrada; aquecer até estabilizar (critério explícito); repetir em pelo menos 3 sessões; registrar clock/P-state por amostra; reportar variação entre sessões.
- **Como verificar:** em nova campanha, a mediana da GTX 970 para N elementos deve ser a mesma (±5%) sozinha e dentro do dual.

### H2 — Estado do link PCIe mudou entre campanhas — HIGH

- **Evidência:** Fase 1 (`phases/phase1-diagnostic/evidence/pcie-e-placa-mae.txt`): Gen1 x8 nas duas GPUs, `gen.max=1`, `hostmax=1`. Fases 2 e 3: Gen1 x8 em todas as amostras. Fase 4B e self-test do GPU Control (mesmo dia, ~13:40–13:55): Gen3 x8 e `LinkGenHostMax=3`. A Fase 4B usa o campo `pcie.link.gen.gpucurrent`; as Fases 2–3 usaram `pcie.link.gen.current`. Nenhum documento explica a mudança de `hostmax` de 1 para 3.
- **Consequência:** a Fase 3 é limitada por cópia (C1) e foi medida em Gen1; num link Gen3 os números devem mudar muito. Os resultados não devem ser apresentados como propriedade "da plataforma PCIe 3.0".
- **Correção:** registrar, por execução e sob carga, os mesmos campos de link nas duas GPUs; anotar BIOS, plano de energia e reinicializações; tratar uma repetição da Fase 3 em Gen3 como **campanha nova**, sem sobrescrever a antiga.
- **Como verificar:** campanha nova com o link anotado em cada linha do CSV.

### H3 — Custo da consolidação: soma de medianas e salto extra — HIGH

- **Onde:** `docs/phase3-report.md` §Transferência; coluna `ParallelPlusFinalTransferMs` em `optimization-decision.csv` (`summarize.ps1` soma a mediana paralela com a mediana de transferência).
- **Evidência:** (a) as duas medianas vêm de experimentos separados, executados em momentos diferentes; mediana de soma ≠ soma de medianas. (b) O tempo paralelo já inclui o readback da parte da GTX 750 Ti para o host. (c) A transferência medida (`transferFinal`) faz VRAM 750 Ti → textura compartilhada (memória do sistema) → GTX 970 → `READBACK` da GTX 970 (para validar): o resultado atravessa o PCIe mais vezes do que uma consolidação real precisaria. Taxa implícita ~0,56 a 0,62 GB/s.
- **Consequência:** a conclusão "a consolidação anulou o ganho" é plausível em Gen1, mas não foi medida como pipeline. O número exato (38,3% a 76,1%) não representa uma aplicação real.
- **Correção:** medir um pipeline ponta a ponta único: GTX 750 Ti escreve direto no recurso cross-adapter, GTX 970 consome na VRAM, validação fora do intervalo cronometrado, timestamps de GPU.
- **Como verificar:** nova coluna `end_to_end_ms` medida numa única execução, comparada ao solo da GTX 970.

### H4 — Coletor da Fase 4B quebra e não grava dados — HIGH (arquivo local)

- **Onde:** `E:\NEXO-DUAL-GPU\phase4b-pcie\collect-pcie.ps1`, linhas 59 e 76 (`$telemetryBatch += $tele`, `$throughputBatch += $through`).
- **Evidência:** as variáveis nunca são inicializadas como array. Testei o padrão isoladamente, sem hardware: o primeiro `+=` vira um objeto e o segundo falha com `op_Addition`. Além disso, o script não tem nenhum `Export-Csv`, `Add-Content` ou `Set-Content`: nada é gravado. A documentação diz "o coletor grava um lote somente após obter as duas linhas de GPU e os quatro counters" e "sintaxe validada". Sintaxe válida não é execução correta. Os CSVs existentes vieram de uma versão anterior que não foi preservada.
- **Correção:** `$telemetryBatch=@(); $throughputBatch=@()` no início de cada lote; verificar `2` linhas de GPU e `4` counters; só então `Export-Csv -Append`; teste com objetos simulados.
- **Como verificar:** `-Snapshot` sem carga produz exatamente 2 linhas de telemetria e 4 de counters; um lote forçado incompleto não grava nada.

### H5 — Trabalho não commitado do Codex corrompe e reescreve evidência — HIGH (local)

- **Onde:** `E:\NEXO-DUAL-GPU\readiness-worktree-2026-11-19` (branch `feature/repository-readiness-2026-11-19`, 27 arquivos modificados e 20+ novos, nada commitado).
- **Evidência:** a versão reescrita de `docs/phase2-report.md` contém acentos corrompidos (o caractere de substituição U+FFFD aparece no lugar das letras acentuadas, ex.: "execut?vel", "C?lculo simult?neo", com `?` representando U+FFFD aqui) e mantém a afirmação incorreta de seleção "por LUID" (ver M1). Arquivos de evidência histórica foram editados: `gpus-dxgi-d3d12.txt` (7.354 → 3.590 bytes), `diagnostico-completo.txt`, `nvidia-e-cuda.txt`, `relatorio-hardware.md`, e também `phases/phase2-prototype/source/nexo_dual_gpu.cpp` e `copy-manifest.csv`. Há erro de texto introduzido na Fase 1 ("enumera duas adapters NVIDIA distintas com identificadas como adapters distintos").
- **Consequência:** se for commitado como está, contraria a própria política do projeto ("datasets e relatórios preservados byte a byte") e quebra a rastreabilidade das evidências.
- **Correção:** não commitar como está. Anonimizar só em **cópias novas** (ex.: `evidence/redacted/`), mantendo os originais intactos ou removendo-os do índice com justificativa e hash registrado. Corrigir a codificação (salvar em UTF-8).
- **Como verificar:** `git diff --stat` não deve tocar arquivos históricos; busca por `\uFFFD` no repositório deve dar zero.
- **Observação:** este PR **não** toca nessa worktree e não incorpora esse trabalho. Os dois conjuntos precisam ser reconciliados pelo proprietário.

### M1 — Seleção das GPUs pela ordem de enumeração — MEDIUM

- **Evidência:** as duas versões do `nexo_dual_gpu.cpp` fazem `if (VendorId == 0x10DE) push_back` e usam `nv[0]` como "GTX 970" e `nv[1]` como "GTX 750 Ti". As colunas `gpu970_*`/`gpu750_*` são fixas no código. `docs/phase2-report.md` §2 afirma "seleciona cada NVIDIA por LUID". O LUID só é impresso.
- **Consequência:** se a ordem DXGI mudar (troca de monitor, driver, slot), os rótulos trocam sem aviso. Não há indício de que isso ocorreu (a ordem nas evidências da Fase 1 é 970, 750 Ti), mas não há verificação.
- **Correção:** selecionar por `DeviceId` (`13C2`/`1380`) e falhar se não encontrar; gravar descrição e LUID em cada linha do CSV.

### M2 — `PASS` garantido por construção — MEDIUM

- **Evidência:** `verify` lança exceção em caso de divergência; a suíte aborta e nenhuma linha `FAIL` é escrita. `recordCompute` só escreve `PASS`. `summarize.ps1` fixa `Integrity='PASS'` e `TransferMs=0`.
- **Consequência:** "todas as 1.200 linhas têm PASS" é verdadeiro, mas não é uma taxa de sucesso: significa "a suíte terminou". A validação é real e forte (comparação de todos os elementos), mas a forma de relatar exagera.
- **Correção:** documentar como "execução completa sem divergência"; numa nova versão, registrar falhas como linhas e calcular `Integrity` a partir dos dados.

### M3 — Seleção e estatística — MEDIUM

- **Evidência:** a melhor das 5 divisões foi escolhida pela mediana e a redução foi relatada sobre os mesmos 20 pontos (viés de seleção). Sem intervalo de confiança. Uma única sessão. p95 nearest-rank com n=20 é o 19º valor ordenado, muito instável. Fase 2 tem n=2 (o relatório reconhece).
- **Correção aplicada neste PR:** IC bootstrap de 95% em `analysis/output/phase3-reduction-bootstrap.csv`: 1M 28,6% [24,9; 29,9]; 2M 39,5% [36,7; 41,3]; 4M 50,4% [48,4; 51,2]; 8M 47,0% [46,3; 54,9]. **Limite:** só ruído intra-sessão.
- **Correção pendente:** sessão confirmatória com a divisão pré-registrada.

### M4 — Telemetria — MEDIUM

- Amostras a cada 0,9 s (Fase 2) e ~2,4 s (Fase 3) para cargas de poucos ms; não há ligação amostra↔execução. `run-suite.ps1` assume que as duas últimas linhas do `nvidia-smi --loop` são GPU0 e GPU1, nessa ordem; se o arquivo terminar no meio de um ciclo, o par fica trocado (o nome da GPU está na linha, então é detectável). A afirmação "Gen1 x8 durante trabalho" não é segura com essa amostragem: GPUs NVIDIA reduzem o link em repouso.

### M5 — Evidências citadas que não estão no repositório — MEDIUM

- `docs/phase2-report.md` aponta para 7 arquivos ausentes (`logs/*.txt`, `nexo_dual_gpu.exe`, caminhos relativos antigos). `docs/phase3-report.md` cita `logs/` e `logs/fase2-integrity-check.csv`. A Fase 1 cita `dxdiag.txt` (ignorado pelo `.gitignore`). Afirmações sobre LUIDs, stdout e transferências da Fase 2 não podem ser conferidas por terceiros.
- **Correção:** importar cópias anonimizadas dos logs ou anotar cada link como "evidência local não versionada". Os relatórios históricos não foram editados neste PR; os links são anotados em `docs/index.md`.

### M6 — Counters NVML implausíveis — MEDIUM

- 3 de 8 counters ficaram em 209.665.102 a 209.700.600 KB/s, cerca de 26 vezes o teórico de Gen3 x8 por direção. O agrupamento apertado sugere valor-sentinela ou leitura inválida, não ruído. Com 37,5% de leituras inválidas, o instrumento não está validado. A classificação e a preservação dos valores crus pelo operador estão corretas.

### M7 — Monitor da Fase 4 grava dados identificáveis — MEDIUM

- `monitor.ps1` usa `$env:COMPUTERNAME`; o relatório local contém o hostname. `gpu-processes.csv` (~2,9 MB) lista processos. Ao importar a campanha, anonimizar hostname, nomes de processo de terceiros e PIDs.

### M8 — Reprodutibilidade do build — MEDIUM

- `build.ps1` fixa `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\...` e SDK `10.0.26100.0`. Versão de driver, SDK e compilador não são gravadas com os resultados. Usar `vswhere`, aceitar parâmetros e gravar versões no cabeçalho da execução.

### M9 — GPU Switcher pode desabilitar dispositivos — MEDIUM (local)

- `gpu-switcher.ps1` tem modo single que desabilita uma GPU. Há travas (token digitado, elevação, console local, checagem de saída de vídeo). Recomendo não versionar esse script junto do laboratório até haver revisão de segurança, ou versioná-lo com aviso explícito. Este PR não o importa.

### LOW e INFO

- **L1:** `docs/phase3-report.md`, tabela de transferência, linha 8M: falta "36,9987 ms" (o percentual 76,1% está certo).
- **L2:** `run-suite.ps1` linha 9 atribui `$args`, variável automática do PowerShell.
- **L3:** `wait()` usa `INFINITE` (só a transferência tem timeout de 30 s). No `catch`, os objetos D3D12 são liberados sem esperar a GPU terminar.
- **L4:** `copy-manifest.csv` tem 87 caminhos `E:\NEXO-DUAL-GPU\...`. Sem nome de usuário; risco baixo. O validador `validate-version.ps1` depende do formato. Recomendo manter e, numa versão futura, acrescentar colunas relativas.
- **L5:** o README não apresentava resultados, hardware, reprodução ou navegação. `CHANGELOG.md`, `RELEASE_NOTES.md` e `docs/VERSIONING.md` estão em inglês; o resto em português. (README reescrito neste PR.)
- **I1:** busca em todos os 5 commits alcançáveis (incluindo `ed447b4` da branch `experiment/...`) por tokens GitHub/AWS/OpenAI/Slack/Google, chaves privadas, `password`, `senha`, `token`, e-mail pessoal, hostname e os PIDs informados: nenhum achado real. Autoria usa e-mail `noreply`.
- **I2:** o relato "750 Ti no slot Gen1 x4" não aparece nas evidências: PnP e `nvidia-smi` mostram x8 nas duas.
- **I3:** licença indefinida. Não foi criada.

## 4. O que foi aprovado (conferido nos dados ou no código)

- Contagens da Fase 3: 1.200 linhas de compute (240 aquecimentos + 960 medições, 48 grupos × (5+20)); 500 de transferência (100 + 400, 20 grupos × (5+20)); todas `PASS` (ver M2).
- Média, mediana, DP amostral e p95 nearest-rank das 48 + 20 linhas de resumo: idênticos ao recálculo.
- Reduções de 28,6% / 39,5% / 50,4% / 47,0% e custos de 48,1% / 38,3% / 48,5% / 76,1%: reproduzidos. Valem para o workload sintético, **não** para FPS (o relatório diz isso).
- Fase 2: médias 2,919 / 4,849 / 2,929 ms, "0,34% mais lento", "~39,6% mais rápido que sequencial", telemetria (42/33 °C, CPU 69%, Gen1 x8): conferem com os CSVs.
- Fase 2: duas GPUs executaram trabalho real, com validação completa no CPU; recursos e fences cross-adapter funcionaram nos dois sentidos (código lido; logs não versionados).
- Fase 1: relatório coerente com as evidências versionadas.
- Fase 4B e GPU Control: os documentos de progresso são cautelosos e não afirmam benchmark nem Engine.
- Repositório privado, tag anotada, histórico sem segredos.

## 5. O que foi reprovado

- Atribuição do ganho da Fase 3 a computação (C1).
- Estabilidade do baseline e desenho da ordem de medição (H1).
- Generalização para "plataforma PCIe 3.0" (H2).
- Custo de consolidação como número representativo (H3).
- Afirmação "coletor grava apenas lotes completos" (H4).
- Afirmação "seleciona por LUID" (M1).

## 6. Pendências

1. Campanha Fase 3b com timestamps, ordem aleatória e várias sessões (requer autorização de hardware).
2. Explicar a mudança Gen1 → Gen3.
3. Corrigir e testar o coletor da Fase 4B; validar counters NVML.
4. Reconciliar este PR com a worktree do Codex.
5. Importar logs anonimizados das Fases 2–3 e, ao fim, da Fase 4.
6. Decisão de licença.

## 7. Testes

**Executados (sem GPU):** recontagem e recálculo dos CSVs (`analysis/reanalyze_phase3.py`, `scripts/static-checks.ps1`): PASS. Verificação de links relativos: PASS fora dos relatórios históricos; 7 links quebrados no relatório histórico da Fase 2 (aviso). Busca de credenciais e caminhos absolutos no histórico: sem achados reais. Parser do PowerShell em todos os `.ps1` versionados: PASS. `git fsck`: PASS. Reprodução isolada do erro `+=` do coletor 4B com objetos simulados.

**Não executados:** compilação C++/HLSL (o validador do projeto tem `-Compile`, não rodei); qualquer execução em GPU; benchmarks; coletor 4B real; self-test do GPU Control; OBS. CI no GitHub Actions roda só verificações estáticas e não valida Multi-GPU.

## 8. Veredicto de prontidão acadêmica

**Pronto com ressalvas para avaliação como relatório exploratório de laboratório.** Engenharia cuidadosa, dados íntegros, limites bem declarados em quase tudo. **Não pronto** para sustentar a tese "duas GPUs heterogêneas aceleram computação" enquanto C1, H1 e H2 não forem resolvidos com nova campanha. A forma honesta de apresentar hoje é: *"num PC de 2012 com links PCIe Gen1 x8, dividir a geração e o readback de um buffer entre duas GPUs reduziu o tempo total em 28,6% a 50,4%; a hipótese principal é o paralelismo dos dois links, e consolidar o resultado numa única GPU eliminou o ganho."*

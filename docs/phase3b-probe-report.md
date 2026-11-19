# Fase 3b — sonda exploratória: computação vs. cópia

**Data:** 2026-11-19, de 18:08:56 a 18:09:06 (horário local). **Tipo:** teste físico curto, exploratório, autorizado pelo proprietário.
**Fonte:** [`phases/phase3b-probe/source/probe_timestamps.cpp`](../phases/phase3b-probe/source/probe_timestamps.cpp). **Dados:** [`data/phase3b-probe/2026-11-19/`](../data/phase3b-probe/2026-11-19/probe.csv).
**Não substitui a Fase 3.** É uma campanha nova e separada, feita para testar o achado C1 da [auditoria](audit/claude-audit-2026-11-19.md).

> Aviso para a Fase 4: esta sonda rodou enquanto o monitor passivo estava ativo. Exclua o intervalo 18:08:56–18:09:06 das estatísticas da Fase 4.

## Pergunta

O ganho da Fase 3 vem de as duas GPUs **calcularem** ao mesmo tempo ou de **copiarem** o resultado pelo PCIe ao mesmo tempo?

## Desenho

- Mesmo shader da Fase 3 (`compute.cso`), 8M elementos.
- GPUs escolhidas por DeviceId (`13C2` = GTX 970, `1380` = GTX 750 Ti), não pela ordem de enumeração.
- 12 configurações: {8, 1024 iterações} × {com cópia para READBACK, sem cópia} × {GTX 970 sozinha, GTX 750 Ti sozinha, dual paralelo 50/50}.
- 3 aquecimentos por configuração, depois 10 medições por configuração em **ordem aleatória** (semente 20261119, `std::mt19937`). 156 execuções.
- Tempo do host (`QueryPerformanceCounter`, do início da gravação até o fim do fence) e timestamps de GPU.
- Validação de todos os elementos contra a referência no CPU nas execuções com cópia (60 de 60 PASS). Sem cópia não há o que ler; marcado `NOT_CHECKED`.
- `nvidia-smi` a cada 200 ms durante a execução (305 amostras).
- Executável: SHA-256 `8280c566…3e31`; `compute.cso`: `68cdbc84…6c46656`. MSVC 19.51.36260, `/O2 /W4`.

## Resultados (mediana de 10 execuções, tempo do host)

| Iterações | Cópia | GTX 970 sozinha | GTX 750 Ti sozinha | Dual 50/50 | Dual vs. 970 |
|---:|:---:|---:|---:|---:|---:|
| 8 | sim | 6,051 ms | 7,595 ms | 4,635 ms | **23,4% mais rápido** |
| 8 | não | 1,023 ms | 2,478 ms | 1,478 ms | **44,4% mais lento** |
| 1024 | sim | 65,041 ms | 189,524 ms | 94,594 ms | 45,4% mais lento |
| 1024 | não | 60,038 ms | 183,426 ms | 92,127 ms | 53,4% mais lento |

Link PCIe em todas as 305 amostras: **Gen3 x8** nas duas GPUs. Temperatura máxima amostrada: 58 °C.

## Leitura

1. **Sem a cópia, o dual não acelera o kernel leve.** Com 8 iterações, o trabalho de GPU é tão pequeno que o custo de gerenciar duas filas supera o ganho. O ganho só aparece quando a cópia para a RAM entra no tempo. Isso **sustenta o achado C1**: o ganho da Fase 3 vem do paralelismo das cópias pelos dois links.
2. **A GTX 750 Ti é cerca de 3 vezes mais lenta em computação.** Com 1.024 iterações: 183,4 ms contra 60,0 ms (razão 3,06). Na Fase 3 as duas pareciam iguais em 4M e 8M porque o tempo era dominado pela cópia.
3. **Em computação pesada, 50/50 é a divisão errada.** O dual fica preso na metade da 750 Ti. Pelas taxas medidas, a divisão ideal seria cerca de 75/25 (970/750 Ti), com tempo teórico de cerca de 45 ms, ou 25% abaixo da 970 sozinha. **Essa divisão não foi testada.**
4. **O link mudou e a Fase 3 não se reproduz no estado atual.** A GTX 970 sozinha com 8M + cópia levou 6,05 ms hoje, contra 21,0 ms na Fase 3 (em Gen1 x8). A cópia de 32 MB custa cerca de 5 ms (diferença com e sem cópia), compatível com Gen3 x8. Isso **confirma o achado H2**.

## Limitações

- Exploratória: uma sessão, n=10 por configuração, 8M elementos apenas.
- OBS, navegadores e o monitor da Fase 4 estavam ativos; a GTX 970 tem o monitor principal.
- **Timestamps de GPU não isolaram a cópia.** As consultas `D3D12_QUERY_TYPE_TIMESTAMP` gravadas depois das barreiras não esperaram o fim do trabalho anterior neste driver: o intervalo "kernel" ficou em zero e o intervalo da cópia indicou taxas impossíveis (cerca de 50 GB/s). As colunas `k*_ms` e `c*_ms` do CSV estão preservadas, mas **não devem ser lidas como tempos de kernel e de cópia**. As conclusões acima usam só o tempo do host e a diferença entre as variantes com e sem cópia.
- O tempo de cópia de ~5 ms é uma diferença entre medianas, não uma medição direta.

## Próximo passo

Fase 3b completa, pré-registrada: divisões guiadas pela taxa medida (incluindo ~75/25), várias sessões, timestamps em listas separadas ou na fila de cópia para isolar a transferência, e o mesmo desenho repetido se o link voltar a Gen1.

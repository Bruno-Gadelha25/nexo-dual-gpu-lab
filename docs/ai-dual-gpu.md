# IA local nas duas placas (2026-11-20)

Campanha que mede **modelos de linguagem e embeddings rodando localmente** (Ollama 0.40.11, CUDA) na GTX 970, na GTX 750 Ti e nas duas juntas. Os modelos são os usados pelos assistentes do autor: **Julinha** (qwen3:1.7b e qwen3:4b-instruct com a personalidade e ~1.500 tokens de notas) e **Nexo** (`nexo:latest`, um qwen3 8B com instrução de sistema própria). Os assistentes são projetos separados; aqui entram só os modelos, os pedidos de teste e os números.

- Script: [`phases/ai-dual-gpu/bench-ai-dual-gpu.mjs`](../phases/ai-dual-gpu/bench-ai-dual-gpu.mjs) (Node 24, sem dependências)
- Demonstração gravada: [`phases/ai-dual-gpu/demo-ia.mjs`](../phases/ai-dual-gpu/demo-ia.mjs)
- Dados brutos: [`data/ai-dual-gpu/2026-11-20/`](../data/ai-dual-gpu/2026-11-20/)

## Como foi montado

Um Ollama por arranjo, cada um preso por `CUDA_VISIBLE_DEVICES` (UUID da placa) e conferido no log (`using device ...`, `model buffer size`):

| Porta | Placas visíveis | Papel |
|---|---|---|
| 11437 | só GTX 970 | "só a 970" |
| 11436 | só GTX 750 Ti | "só a 750 Ti" |
| 11438 | as duas | modelo espalhado nas duas |
| 11439 | só GTX 970, `OLLAMA_NUM_PARALLEL=2` | dois pedidos juntos na mesma placa |

Comum a todos: `OLLAMA_FLASH_ATTENTION=1`, contexto 4096, `temperature 0.6`, `seed 7`, `think: false`, até 160 tokens por resposta (200 no teste de pedidos simultâneos). Cada medição tem 1 pedido frio e 4 aquecidos, com perguntas diferentes; a tabela mostra a mediana dos aquecidos. Telemetria do `nvidia-smi` a cada 500 ms durante tudo. Nada de OBS, jogo ou outro serviço de IA aberto durante a medição. Link PCIe: Gen3 x8 nas duas placas.

## Resultados

### 1. Uma conversa, em cada arranjo

Velocidade de geração em tokens por segundo (maior é melhor) e tempo até a primeira palavra com o prompt já em cache.

| Modelo | Só GTX 970 | Só GTX 750 Ti | As duas | Melhor |
|---|---:|---:|---:|---|
| Julinha, qwen3:1.7b (1,7 GB) | **48 tok/s** · 0,20 s | 20 tok/s · 0,42 s | 19,5 tok/s (o Ollama escolheu a 750 Ti) | **só a 970** |
| Julinha, qwen3:4b-instruct (3,2 GB) | **20,6 tok/s** · 0,45 s (`num_gpu 99`) | 10,1 tok/s · 1,0 s (`num_gpu 99`) | 14,4 tok/s · 0,70 s (dividido ~1,1 + 1,3 GB) | **só a 970** |
| Nexo, qwen3 8B (5,0–6,0 GB) | 5,15 tok/s · 3,4 s (`num_gpu 20`, resto na RAM) | 4,0 tok/s · 3,6 s (resto na RAM) | **7,35 tok/s · 3,3 s** (1,9 + 2,0 GB nas placas, 1,0 GB na RAM) | **as duas: +43%** |

Leitura:

- **Modelo que cabe numa placa:** a 970 sozinha ganha sempre. Dividir um modelo que cabe só acrescenta a conversa entre as placas pelo PCIe, e a 750 Ti (2,0 a 2,4× mais lenta aqui) vira o passo mais lento.
- **Modelo que não cabe numa placa (Nexo, 8B):** espalhar nas duas ganha da melhor configuração possível da 970 sozinha, porque a alternativa não é "mais placa", é a RAM do sistema e o processador. Aqui as duas placas juntas funcionam como uma placa de ~8 GB.
- **Armadilha encontrada:** com as duas placas visíveis, o Ollama põe o modelo pequeno na placa com mais memória livre. Como a 970 desenha o monitor principal, essa placa era a 750 Ti, e a Julinha ficou 2,4× mais lenta (19,5 contra 48 tok/s). O Ollama principal da máquina estava com as duas visíveis; as medições dele foram separadas como inválidas para "só a 970" (`single-ollama-principal-INVALIDO-ambas-visiveis.jsonl`).
- Sem `num_gpu 99`, o Ollama estimou que o 4B não cabia inteiro na 970 e deixou parte na CPU (8,8 tok/s). Forçando as camadas na placa: 20,6 tok/s. Os dois resultados estão nos dados.

### 2. Duas conversas ao mesmo tempo (qwen3:1.7b)

Oito pedidos (quatro pares), 200 tokens cada, ordem ABBA.

| Arranjo | Tempo total | Tokens/s somados |
|---|---:|---:|
| Só a 970, pedidos em fila | 11,1 s | 41,4 |
| Só a 970, os dois juntos (`num_parallel 2`) | 7,6 s* | 60,3* |
| Um pedido em cada placa, ao mesmo tempo | 13,2 s | 35,0 |

\* A primeira rodada com `num_parallel 2` levou 11,6 s (42,5 tok/s) porque incluiu a carga do modelo; a segunda é a medida limpa. Uma repetição só: tratar como indicativo.

Leitura: para modelo pequeno, **a 970 sozinha atende duas pessoas melhor** do que dividir uma para cada placa, porque cada par termina quando a resposta mais lenta (a da 750 Ti) termina.

### 3. Memória da Julinha: embeddings divididos pela velocidade de cada placa

1.536 textos, `embeddinggemma:300m`, lotes de 64, três repetições. Divisão calculada a cada repetição pela velocidade medida (deu 67% na 970 e 33% na 750 Ti). Todo lote é conferido (um vetor por texto).

| Rep. | Só 970 | Só 750 Ti | As duas, divisão calibrada | As duas, meio a meio | Ganho calibrado vs. 970 |
|---:|---:|---:|---:|---:|---:|
| 1 | 51,9 s | 105,2 s | **36,0 s** | 51,4 s | **30,7%** |
| 2 | 52,0 s | 109,4 s | **38,5 s** | 52,1 s | **26,0%** |
| 3 | 54,0 s | 109,5 s | **35,4 s** | 51,3 s | **34,4%** |

Leitura: **mesma lição do NEXO GPU ENGINE.** Com a divisão pela velocidade, as duas placas juntas indexam a memória **26% a 34% mais rápido** que a 970 sozinha. Meio a meio, o ganho some (a 750 Ti termina por último). O teto teórico somando as velocidades é ~33%; os resultados ficam nele.

## Resposta curta

| Tarefa de IA | Duas placas ajudam? |
|---|---|
| Conversa com modelo que cabe numa placa (Julinha 1.7b/4b) | **Não.** Use só a 970 e prenda o Ollama nela. |
| Conversa com modelo maior que 4 GB (Nexo 8B) | **Sim, +43%** contra a 970 + RAM. |
| Muitos textos para a memória (embeddings em lote) | **Sim, +26% a +34%**, com a divisão pela velocidade. |
| Duas conversas ao mesmo tempo com modelo pequeno | **Não.** A 970 com `num_parallel 2` é melhor. |
| Funções separadas (conversa na 970; voz e memória na 750 Ti) | É o arranjo em uso no assistente do autor; não disputa VRAM. Medição com voz fica para a próxima campanha. |

## Limitações

- Uma sessão, numa manhã. Os números de geração variaram menos de 5% entre repetições, mas não há intervalo de confiança.
- O teste de pedidos simultâneos tem poucas rodadas.
- O Nexo nas duas placas usou a divisão automática do Ollama; outras divisões (`tensor_split`) não foram testadas nesta campanha.
- O vídeo foi gravado depois, com o OBS ligado; os números dele são demonstração, não medição.

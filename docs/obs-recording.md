# Gravação do vídeo no OBS

Configuração para gravar, num único vídeo, o painel NEXO GPU CONTROL e a tela do jogo ao mesmo tempo, mostrando a GTX 970 sozinha, a GTX 750 Ti sozinha e as duas juntas.

## Configuração aplicada na máquina (2026-11-19)

- **Perfil `NEXO Gravacao`:** 1920×1080, 30 fps (reduzido de 60 no Teste 11), gravação MP4 híbrido, qualidade alta, NVENC (GPU 0 do OBS = GTX 970). Arquivos em `Vídeos`, com nome `NEXO aaaa-mm-dd hh-mm-ss`.
- **Coleção de cenas `NEXO Dual GPU`**, com 5 cenas iguais na montagem e diferentes só na legenda (a 5ª, `5 · Forza na GTX 750 Ti`, foi acrescentada depois):
  - `1 · Só GTX 970`
  - `2 · Só GTX 750 Ti`
  - `3 · Duas placas`
  - `4 · Forza Horizon 4`
- **Montagem:** monitor do painel (LG, na GTX 750 Ti) à esquerda e monitor do jogo (SyncMaster, na GTX 970) à direita, cada um em 960×600; título em cima, legenda do teste embaixo. A captura do monitor da GTX 750 Ti usa o método WGC, que funciona entre placas diferentes.
- **Áudio:** áudio do PC no dispositivo padrão; microfone mudo.
- **"Esconder janelas do OBS da captura" ligado:** o OBS não aparece no vídeo.
- Perfil e coleção anteriores (`Sem nome`) continuam intactos e selecionáveis no menu do OBS; há backup do `user.ini`.
- O NEXO GPU CONTROL v2.1 abre sozinho no monitor secundário (o da GTX 750 Ti).
- Gerador usado: [`tools/obs/make_obs_nexo.py`](../tools/obs/make_obs_nexo.py). Os caminhos dos monitores foram trocados por marcadores na versão versionada.

## Grave com o OBS minimizado

Com a janela do OBS aberta no monitor da GTX 750 Ti, a prévia ao vivo disputa a placa com o Engine, e o job das duas placas chegou a ficar 183% mais lento (Teste 11 do [diário](experiment-log.md)). Minimizado, o resultado volta ao normal.

- Abra pelo atalho da área de trabalho **NEXO Gravar (OBS)**: ele já inicia minimizado na bandeja, com o perfil e as cenas certas.
- Controle pelo teclado:

| Atalho | Ação |
|---|---|
| Ctrl+Alt+R | começar a gravar |
| Ctrl+Alt+S | parar a gravação |
| Ctrl+Alt+1 … Ctrl+Alt+5 | cena 1 … 5 |

## Roteiro

Antes de gravar:

1. Feche WhatsApp, navegador e qualquer coisa pessoal **nos dois monitores**: os dois são gravados.
2. Feche o Forza Horizon 4. Um jogo aberto invalida a medição do Engine (Teste 5 do diário).
3. Abra o NEXO GPU CONTROL pelo atalho; ele aparece no monitor da esquerda.

Gravação (um único arquivo):

| Passo | Cena no OBS | No GPU Control | O que deve aparecer |
|---|---|---|---|
| 1 | `1 · Só GTX 970` | **Só GTX 970** → **Executar job do Engine** | curva âmbar sobe; a ciano fica parada; job ≈ 24 ms |
| 2 | `2 · Só GTX 750 Ti` | **Só GTX 750 Ti** → **Executar job do Engine** | curva ciano sobe; job ≈ 53 ms (placa ~2,2× mais lenta neste job) |
| 3 | `3 · Duas placas` | **Duas placas** → **Executar job do Engine** | as duas sobem juntas; job ≈ 20 ms; ~24% mais rápido que a 970 sozinha |
| 4 | `4 · Forza Horizon 4` | (nenhum clique) | abra o jogo e rode o benchmark: âmbar sobe, ciano fica parada |
| 5 | `5 · Forza na GTX 750 Ti` | (nenhum clique) | antes, em Configurações → Sistema → Tela → Gráficos, defina a GPU específica do Forza como GTX 750 Ti e ponha o jogo no monitor da esquerda: a curva ciano sobe. Depois volte a opção para o padrão. |

Cada execução do Engine leva cerca de 15 s (medição + 10 s de trabalho contínuo). Espere a curva descer antes de trocar de cena.

## O que dizer no vídeo para ficar honesto

- O Engine acelera **trabalho do próprio NEXO**. Jogos não usam duas GPUs sozinhos (Forza: 85 vs. 86 FPS).
- O OBS grava pelo NVENC da GTX 970. Isso aparece no painel como "Codificador de vídeo" e um pouco de uso na 970, inclusive nos passos 2 e 4.
- O ganho de ~24% vale para este job sintético, com a divisão calibrada (~71/29).

## Resultados de referência (Teste 10 do diário)

| Política | Tempo do job (8M elementos, 256 iterações) |
|---|---:|
| Só GTX 970 | 24,1 ms |
| Só GTX 750 Ti | 53,1 ms |
| Duas placas (~71/29) | 20,3 ms |

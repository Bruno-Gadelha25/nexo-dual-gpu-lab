# Integração com OBS

> Atualização 2026-11-19: configuração de gravação do vídeo (dois monitores, 4 cenas) em [obs-recording.md](obs-recording.md). O NVENC por GPU continua não confirmado.

**Estado:** planejamento. **Nenhum perfil foi aplicado, nenhuma gravação foi feita, o NVENC por GPU não foi confirmado.**

Base: leitura do guia local `OBS-GPU-GUIDE.md`, de `obs-gpu-profiles.json` e de `obs-results.csv` (só cabeçalho) na pasta `gpu-switcher/obs-integration`. Nada foi importado neste PR.

## Fatos observados

- OBS Studio 33.0.1 instalado; não estava rodando no inventário.
- Um log do OBS registrou composição D3D11 na GTX 970 (índice 0 naquele log) e encoders `obs_nvenc_h264_tex` e `obs_nvenc_hevc_tex`.
- A lista de encoders **não** diz qual GPU física faz cada NVENC. Índice DXGI e ordinal NVENC são coisas diferentes.
- As duas GPUs têm monitor conectado (GTX 970 primária).

## Capacidade de codificação (especificação NVIDIA)

| GPU | H.264 NVENC | HEVC NVENC | AV1 |
|---|---|---|---|
| GTX 970 (GM204) | sim | sim | não |
| GTX 750 Ti (GM107) | sim | não | não |

Fonte: [NVIDIA Video Encode and Decode Support Matrix](https://developer.nvidia.com/video-encode-decode-support-matrix).

## Por que não é simples

O OBS compõe a cena numa GPU e o encoder pode estar em outra. Nesse caso a imagem precisa atravessar o PCIe a cada quadro. Com o link em Gen1 x8 (estado das Fases 1–3), um quadro 1080p RGBA tem cerca de 8,3 MB; a 60 FPS seriam cerca de 0,5 GB/s só nessa cópia, uma fração relevante da taxa de ~1,5 GB/s medida indiretamente na Fase 3. É uma estimativa, não uma medição.

## Perfis planejados (não testados)

| Perfil | Jogo | Composição OBS | NVENC |
|---|---|---|---|
| A | GTX 970 | GTX 970 | GTX 750 Ti |
| B | GTX 750 Ti | a definir | GTX 970 |
| C | NEXO nas duas | — | H.264 |
| D | mesma GPU para tudo | mesma | mesma |

## Antes de testar

1. Confirmar o NVENC por GPU com o seletor do OBS e o log, cruzando com o bus PCI.
2. Uma gravação curta por vez, mesma cena, preset, resolução e duração.
3. Registrar FPS, frametimes, quadros perdidos/pulados (janela Stats), uso e temperatura das GPUs.
4. Só depois integrar com o NEXO.

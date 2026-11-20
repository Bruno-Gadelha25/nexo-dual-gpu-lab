# Perguntas frequentes

**As duas placas somam 8 GB de VRAM?**
Não. Cada uma tem seus 4 GiB. Um recurso Cross-Adapter é um bloco compartilhado (neste hardware, na memória do sistema), não uma memória unificada.

**Isso aumenta o FPS dos jogos?**
Não há nenhuma evidência disso. Nenhum jogo foi testado. Jogos não usam duas GPUs diferentes sozinhos; a aplicação teria de ser escrita para isso.

**Então o que foi provado?**
Que as duas GPUs executam trabalho D3D12 ao mesmo tempo com resultado correto, que trocam dados por recursos e fences Cross-Adapter, e que, num workload sintético, dividir a geração e a cópia de um buffer reduziu o tempo em 28,6% a 50,4%.

**O ganho é de computação?**
Provavelmente não. O tempo medido inclui copiar o resultado pelo PCIe, e o shader é muito leve. A explicação mais provável é que cada GPU usa seu próprio link PCIe e as duas cópias acontecem em paralelo. Falta um teste com timestamps de GPU para confirmar. Ver [auditoria, C1](audit/claude-audit-2026-11-19.md).

**Por que a GTX 750 Ti foi mais rápida que a GTX 970 em 4 milhões de elementos?**
Porque o tempo é dominado pela cópia, e as duas tinham o mesmo link (Gen1 x8). Além disso, a medição da GTX 970 sozinha variou entre blocos. Ver achados C1 e H1.

**Por que juntar os resultados elimina o ganho?**
Para juntar, a parte da GTX 750 Ti precisa atravessar o PCIe de novo (VRAM → memória compartilhada → GTX 970). Num link lento, isso custa mais do que a divisão economizou. O número exato publicado soma dois experimentos separados e inclui um salto extra; ver achado H3.

**O link é PCIe 3.0 ou 1.0?**
A placa e a CPU suportam 3.0. Durante as Fases 1–3 o link estava em Gen1 x8; nas leituras da Fase 4B, em Gen3 x8. A causa da mudança não foi registrada.

**O botão "DUAL GPU ON" do GPU Control liga as duas GPUs juntas?**
Não. Ele grava um arquivo JSON. Ainda não existe programa que leia esse arquivo.

**Posso rodar os benchmarks?**
Pode conferir os dados e compilar sem GPU. Rodar benchmarks usa as GPUs físicas e precisa de autorização do proprietário. Ver [reproducibility.md](reproducibility.md).

**Por que os CSVs dizem 100% PASS?**
Porque qualquer divergência aborta a suíte antes de gravar a linha. "PASS" significa "a execução terminou sem nenhum elemento errado". A validação compara todos os elementos.

**Qual é a licença?**
Ainda não foi escolhida. Não redistribua.

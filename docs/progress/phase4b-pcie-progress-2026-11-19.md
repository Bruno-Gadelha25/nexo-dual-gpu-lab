# Fase 4B — PCIe: estado da instrumentação

**Estado:** validação de telemetria; nenhum benchmark foi iniciado.  
**Data do registro:** 2026-11-19.  
**Origem:** resumo operacional fornecido pelo operador. Este documento não substitui os relatórios, CSVs ou logs originais do computador de laboratório.

## Escopo e separação das fases

A Fase 4 continua sendo o monitoramento passivo (temperatura, clocks, utilização e memória). A Fase 4B é uma campanha separada para validar a instrumentação PCIe e, somente depois, relacionar tráfego observado com workloads de compute e transferências Cross-Adapter.

Os resultados das duas fases não devem ser combinados como se fossem uma única campanha.

## Estado observado

- As duas GPUs foram identificadas por PCI Bus ID.
- Os dispositivos PnP correspondentes estavam em estado OK.
- As amostras completas reportaram **PCIe Gen3 x8** para a GTX 970 e **PCIe Gen3 x8** para a GTX 750 Ti.
- O valor máximo x16 reportado pelo endpoint não demonstra a largura elétrica/física do slot da placa-mãe. Não se conclui, a partir desse campo, que o slot opere fisicamente em x16.
- O `nvidia-smi` instalado não expôs os campos de throughput PCIe consultados.
- A alternativa NVML local retornou counters TX/RX, mas **3 de 8 valores registrados foram considerados fisicamente implausíveis** em relação ao link observado. Os valores brutos foram preservados na coleta local e devem ser excluídos de estatísticas derivadas até validação.
- Foram registradas cinco linhas de telemetria, sendo uma tentativa incompleta, e oito counters.
- Um snapshot completo mostrou **18% de utilização da GTX 970**. Portanto, esse snapshot não deve ser classificado como baseline ocioso.
- O coletor foi ajustado para descartar lotes incompletos sem gravar linhas parciais. A sintaxe do coletor foi validada.

## O que ainda não foi demonstrado

Nenhum benchmark de compute ou transferência foi iniciado. Não existem, até este registro, tempos de execução pareados com as amostras TX/RX.

Consequentemente, os dados atuais **não permitem concluir**:

- correlação entre tráfego PCIe e tempo de compute;
- contenção entre os links ou entre as GPUs;
- custo efetivo de comunicação Cross-Adapter;
- vantagem ou desvantagem de execução paralela;
- throughput efetivo validado para cada direção de transferência.

Os counters suspeitos não devem ser usados para médias, percentis, correlações ou alegações de desempenho. A presença de counters NVML, por si só, não valida suas unidades, escala ou integridade.

## Próximas etapas recomendadas

1. Confirmar a semântica, unidade, escala e janela de amostragem do counter NVML utilizado.
2. Validar os counters com tráfego controlado e uma operação de transferência conhecida, verificando coerência em ambas as GPUs.
3. Estabelecer baseline somente quando as duas GPUs estiverem comprovadamente sem carga relevante.
4. Executar workloads sustentados com eventos de início/fim sincronizados à telemetria.
5. Preservar os valores brutos, marcar amostras inválidas e produzir estatísticas apenas sobre lotes validados.
6. Separar correlação observacional de afirmações causais.

## Integridade e segurança

A campanha passiva da Fase 4 permanece ativa conforme informado pelo operador. Não interromper nem alterar esse monitor para executar a Fase 4B.

Nenhum benchmark foi iniciado e não foram reportadas alterações em BIOS, drivers, dispositivos ou configurações globais.

Os CSVs, logs e relatórios originais da máquina não foram incluídos neste registro de documentação. Eles precisam ser copiados e revisados separadamente antes de serem adicionados ao repositório privado.

## Referências técnicas

- [NVIDIA NVML Device Query API](https://docs.nvidia.com/deploy/nvml-api/latest/api/group__nvmlDeviceQueries.html)
- [NVIDIA NVML Device Structures](https://docs.nvidia.com/deploy/nvml-api/latest/api/group__nvmlDeviceStructs.html)

## Nota de revisão

Este é um registro de progresso, não um relatório final da Fase 4B nem evidência de benchmark. A campanha só poderá produzir conclusões depois da validação dos counters e da coleta de workloads pareados.

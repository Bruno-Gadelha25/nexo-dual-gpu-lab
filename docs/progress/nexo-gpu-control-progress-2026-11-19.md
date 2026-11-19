# NEXO GPU CONTROL — estado da interface

**Estado:** interface independente com self-test concluído; integração com o scheduler ainda não implementada.  
**Data do registro:** 2026-11-19.  
**Origem:** resumo operacional fornecido pelo operador. Este documento não substitui os fontes, scripts ou logs originais da aplicação local.

## Escopo

A interface NEXO GPU CONTROL foi preparada como uma camada de apresentação e configuração para um futuro NEXO GPU ENGINE.

A janela foi deixada aberta após os testes. O identificador de processo foi omitido deste documento versionado por ser um dado operacional temporário.

## O que foi verificado

- O self-test passou nos cinco cenários de botão informados pelo operador.
- A interface apresentou telemetria em modo somente leitura.
- Os testes confirmaram que nenhum dispositivo físico foi alterado.
- A interface grava uma política local destinada a um futuro scheduler.
- Nenhuma política de produção foi criada.

## Limitação funcional central

**O NEXO GPU ENGINE ainda não existe para consumir a política gravada pela interface.**

Assim, os modos e botões estão preparados e foram testados como interface, mas a distribuição real de tarefas entre GPUs ainda não está operacional.

Não interpretar um estado visual de Dual/ON como prova de execução computacional simultânea. A interface não demonstrou, por si só, distribuição de workloads, escalonamento adaptativo ou ganho de desempenho.

## Próximas etapas

1. Definir e documentar um schema versionado para a política local.
2. Implementar um scheduler determinístico que leia e valide essa política.
3. Iniciar com um modo **DRY RUN**, sem submeter workloads às GPUs.
4. Criar workers independentes para cada dispositivo e conectar o scheduler ao protótipo D3D12 existente.
5. Validar integridade dos resultados, sincronização, falhas e telemetria antes de habilitar execução real.
6. Medir separadamente o custo de transferência Cross-Adapter.
7. Integrar OBS somente após verificar e documentar a seleção real do adaptador de codificação; esta interface não comprova configuração NVENC.

## Segurança e preservação

- Não foram reportadas alterações em BIOS, drivers, dispositivos PnP ou configurações globais.
- O Switcher existente não foi alterado.
- OBS e o monitor passivo da Fase 4 não foram encerrados.
- Não executar operações que desabilitem uma GPU enquanto ela sustentar uma saída de vídeo ativa.
- Não habilitar políticas de produção até existir um scheduler funcional e testes de segurança.

## Escopo deste registro Git

Este commit adiciona somente documentação de estado. Os fontes, scripts, arquivos de configuração e resultados de self-test da aplicação local não foram fornecidos neste envio e, portanto, não estão incluídos no repositório por este commit.

A licença do projeto continua indefinida. Não redistribuir componentes de terceiros sem revisão de suas licenças.

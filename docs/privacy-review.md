# Revisão de privacidade e estado de compartilhamento

## Estado atual

- Área local: `E:\NEXO-DUAL-GPU\private-workspace`.
- Git foi inicializado localmente. Nenhum remoto está configurado.
- Nenhuma consulta remota ao GitHub, push, release, pacote ou publicação foi feita.
- O workspace não é público porque não existe repositório remoto; seu conteúdo está apenas no armazenamento local disponível.
- A cópia não modificou nem moveu os diretórios das Fases 1–4.

## Dados a tratar como privados

- `dxdiag.txt`, relatórios de hardware e saídas WMI podem revelar nome do computador, IDs PnP, configuração e software instalado.
- Logs de execuções podem conter PID, nomes/caminhos de processos, relógio, uso de memória e informações do ambiente.
- Logs de monitoramento da Fase 4 são gravados no diretório original e não foram copiados porque estão ativos.
- Os CSVs de benchmark e telemetria descrevem o hardware e o comportamento da máquina.

A varredura local de arquivos textuais não encontrou padrões de credenciais comuns (chaves, tokens, senhas ou chaves privadas). Isso não substitui revisão manual dos dados identificadores antes de qualquer compartilhamento.

## Proteções do repositório

`.gitignore` exclui executáveis, objetos compilados, logs brutos de fases, `dxdiag.txt`, estado do monitor e arquivos de credenciais. Os CSVs selecionados de benchmark permanecem locais e versionados neste repositório local privado.

A proteção de acesso e criptografia do volume E: não foi auditada. Nenhum conteúdo foi enviado a serviços externos nesta organização.

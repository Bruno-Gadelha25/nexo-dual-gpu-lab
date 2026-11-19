# Revisão de privacidade e estado de compartilhamento

## Estado verificado em 2026-11-19

- Workspace: `E:\NEXO-DUAL-GPU\private-workspace`.
- Repositório remoto: `https://github.com/Bruno-Gadelha25/nexo-dual-gpu-lab`, proprietário `Bruno-Gadelha25`, visibilidade `PRIVATE`, branch padrão `main`.
- A cópia local está sincronizada com `origin/main` antes das alterações de versionamento; qualquer envio destas alterações limita-se a arquivos administrativos revisados.
- Nenhuma release pública, pacote ou alteração de visibilidade foi feita. O projeto permanece privado.
- A revisão anterior registrou 2 commits e não encontrou padrões comuns de credenciais; esta informação não substitui nova auditoria antes de incluir dados novos.

## Dados privados

- Relatórios de hardware, evidências WMI/DXGI/CUDA e benchmarks descrevem a configuração e o comportamento deste computador.
- Logs podem incluir processos, caminhos, PIDs, uso de memória e sensores. Os logs brutos da campanha da Fase 4 não estão versionados.
- A Fase 4 continua ativa no diretório original. Não copiar, mover ou editar seus arquivos de coleta enquanto o monitor estiver escrevendo.
- O hostname foi substituído por texto de privacidade no documento versionado. O histórico alcançável foi auditado após essa correção; o backup antigo do histórico não pertence ao repositório e nunca deve ser enviado.

## Proteções e limites

`.gitignore` exclui executáveis e saídas brutas selecionadas. CSVs de benchmarks escolhidos permanecem no repositório privado por decisão do proprietário. Privado não significa livre de revisão: auditar todo novo arquivo e commit antes de sincronizar.

A licença do projeto ainda não foi escolhida. Windows SDK, MSVC, FXC, drivers e ferramentas NVIDIA têm termos próprios; não redistribuí-los sem revisão. A proteção física/criptografia do volume E: não foi auditada.

## Auditoria independente de 2026-11-19

Detalhes em [audit/claude-audit-2026-11-19.md](audit/claude-audit-2026-11-19.md) (achados I1, L4, M7, M9).

- **Histórico:** os 5 commits alcançáveis (`main` e `experiment/phase4b-gpu-control-status`) foram varridos em todas as versões de todos os arquivos. Nenhum token, chave privada, senha, e-mail pessoal, hostname ou PID operacional encontrado. A autoria usa e-mail `noreply` do GitHub.
- **Caminhos absolutos conhecidos e aceitos:** `copy-manifest.csv` (87 caminhos `E:\NEXO-DUAL-GPU\...`, sem nome de usuário, necessários para `validate-version.ps1`), scripts de build (caminhos do Visual Studio e do SDK), scripts e nota da Fase 4. `scripts/static-checks.ps1` avisa se surgir caminho absoluto novo fora dessa lista.
- **Identificadores de hardware versionados:** VEN/DEV/SUBSYS/REV, bus PCI e LUIDs das GPUs nas evidências da Fase 1 e no relatório da Fase 2. Descrevem modelos comerciais e um estado temporário (LUID muda a cada reinicialização); risco baixo. Os IDs de **instância** PnP (`4&...`) aparecem só nos arquivos locais da Fase 4B e do GPU Control, que **não** foram importados.
- **Antes de importar a Fase 4:** o monitor grava o hostname (`$env:COMPUTERNAME`) no relatório e uma lista de processos em `gpu-processes.csv`. Anonimizar hostname, nomes de processos de terceiros e PIDs numa cópia; manter o original fora do Git.
- **Não versionar sem revisão de segurança:** `gpu-switcher.ps1`, que pode desabilitar uma GPU.

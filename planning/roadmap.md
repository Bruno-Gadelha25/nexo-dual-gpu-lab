# Plano de continuidade

Atualizado em 2026-11-19 após a [auditoria independente](../docs/audit/claude-audit-2026-11-19.md).

## Ciência (prioridade)

1. **Fase 3b** — repetir a Fase 3 como campanha nova, sem tocar na original: timestamps de GPU separando kernel e cópia, variante sem readback, kernel com carga ajustável, ordem aleatória, pelo menos 3 sessões, link PCIe registrado em cada linha. Responde aos achados C1, H1 e H2.
2. Explicar a mudança do link de Gen1 x8 (`hostmax=1`) para Gen3 x8 (`hostmax=3`).
3. Medir a consolidação como pipeline único ponta a ponta (achado H3).

## Instrumentação

4. Corrigir e testar o coletor da Fase 4B; validar os counters NVML antes de qualquer carga.
5. Concluir a Fase 4 sem interromper a coleta; importar uma cópia datada e anonimizada (hostname, processos, PIDs) depois de encerrada.

## Engenharia

6. Selecionar GPUs por DeviceId/LUID e gravar a identidade em cada linha de CSV.
7. GPU Control → schema versionado → scheduler determinístico em DRY RUN → workers por GPU → execução real só com autorização.
8. OBS: confirmar o NVENC por GPU antes de qualquer perfil.
9. Testes unitários para a função de referência e para o parsing dos CSVs.

## Governança

10. Reconciliar este trabalho com a worktree não commitada do Codex (`feature/repository-readiness-2026-11-19`).
11. Manter o repositório privado; decidir a licença antes de qualquer redistribuição.

## Fora do escopo deste repositório

- **NEXO AI COUNCIL** (ChatGPT, Gemini e Claude com orquestrador determinístico): projeto independente, em planejamento, com repositório, dados e credenciais próprios. Nenhuma integração existe ou é afirmada aqui.

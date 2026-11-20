# Contrato de integração do NEXO GPU ENGINE

A UI publica `scheduler-policy.json` como estado desejado, em JSON UTF-8, substituído via arquivo temporário; se já existir, guarda backup antes de atualizar.

Campos mínimos:

- `schemaVersion`: versão do contrato.
- `updatedAt`: timestamp ISO-8601.
- `mode`: `DUAL_ON`, `DUAL_OFF`, `GTX970_ONLY` ou `GTX750TI_ONLY`.
- `distributionEnabled`: somente `true` para DUAL_ON.
- `primaryGpu`: chave/identidade lógica.
- `allowedAdapters`: cada adapter contém nome, PCI Device ID, Device Instance ID e bus ID NVIDIA.
- `hardwareDeviceChangesAllowed`: sempre `false`.
- `engineAcknowledgement`: `PENDING_ENGINE_INTEGRATION` até o Engine reconhecer o arquivo.

O Engine futuro deve escolher DXGI LUIDs/adaptadores por identidade, respeitar `allowedAdapters`, reconhecer mudanças sem reinício quando seguro e expor ACK/erro separado. É proibido interpretar DUAL_OFF/ONLY como instrução PnP ou desligamento físico. Não existe consumidor implementado neste módulo inicial; botões atualizam a política local, sem despacho real.

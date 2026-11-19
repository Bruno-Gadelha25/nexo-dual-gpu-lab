# Arquitetura

Descreve o que o código das Fases 2 e 3 faz de fato (fontes em `phases/phase2-prototype/source/` e `phases/phase3-optimization/source/`).

## 1. Componentes

```mermaid
flowchart TB
  subgraph Host["Processo nexo_dual_gpu.exe (CPU)"]
    E["Enumeração DXGI<br/>VendorId 0x10DE"] --> G0["Gpu g0 = 1ª NVIDIA<br/>(tratada como GTX 970)"]
    E --> G1["Gpu g1 = 2ª NVIDIA<br/>(tratada como GTX 750 Ti)"]
    REF["Referência no CPU<br/>expected(index, seed, iters)"]
  end
  subgraph D0["GTX 970"]
    Q0["ID3D12Device + fila COMPUTE"] --> U0["UAV DEFAULT (VRAM)"] --> RB0["READBACK (RAM do sistema)"]
  end
  subgraph D1["GTX 750 Ti"]
    Q1["ID3D12Device + fila COMPUTE"] --> U1["UAV DEFAULT (VRAM)"] --> RB1["READBACK (RAM do sistema)"]
  end
  G0 --> Q0
  G1 --> Q1
  RB0 --> REF
  RB1 --> REF
```

Observações:

- A atribuição "g0 = GTX 970" depende da **ordem de enumeração** DXGI. O código não confere nome nem LUID (achado M1 da auditoria).
- Cada GPU tem seu próprio dispositivo, fila, fence local e evento Win32. Não há nó compartilhado (não é Linked Node / SLI).

## 2. Uma medição de "compute" (Fase 3)

```mermaid
sequenceDiagram
  participant CPU
  participant Q as Fila COMPUTE
  participant GPU
  participant RAM as RAM (READBACK)
  Note over CPU: t0 = qpc()
  CPU->>CPU: encode(): Dispatch + barreira + CopyBufferRegion
  CPU->>Q: ExecuteCommandLists + Signal(fence)
  Q->>GPU: shader (8 iterações por elemento)
  GPU->>RAM: cópia de 4×N bytes pelo PCIe
  GPU-->>CPU: fence concluído → evento
  Note over CPU: t1 = qpc(); total_ms = t1 − t0
  CPU->>CPU: verify(): compara todos os elementos (fora do tempo)
```

**Consequência:** `total_ms` inclui a cópia pelo PCIe. Com um shader leve, essa cópia tende a dominar (achado C1).

No modo paralelo, as duas listas são gravadas, as duas filas recebem o trabalho e só então o CPU espera os dois eventos (`WaitForMultipleObjects`). `total_ms` vai do início até o último evento.

## 3. Transferência Cross-Adapter (consolidação)

```mermaid
sequenceDiagram
  participant P as GTX 750 Ti (produtora)
  participant H as Heap compartilhado<br/>(SHARED_CROSS_ADAPTER)
  participant C as GTX 970 (receptora)
  participant R as READBACK da 970
  C->>C: Wait(fence compartilhada, v) enfileirado antes
  P->>H: CopyTextureRegion (VRAM → textura row-major R32_UINT)
  P->>P: Signal(fence compartilhada, v)
  C->>R: após o wait: copia textura → READBACK
  C-->>C: fence local → evento no CPU
  Note over C,R: CPU valida todos os valores
```

- O heap é criado na produtora com `D3D12_HEAP_FLAG_SHARED | D3D12_HEAP_FLAG_SHARED_CROSS_ADAPTER`, exportado por `CreateSharedHandle` e aberto na receptora com `OpenSharedHandle`.
- Buffers Cross-Adapter foram rejeitados pelo driver (`E_INVALIDARG`); por isso a textura row-major de largura 2048.
- O intervalo cronometrado inclui o salto extra até o `READBACK` da receptora (achado H3).

## 4. Módulos fora do caminho de execução

```mermaid
flowchart LR
  UI["NEXO GPU CONTROL<br/>(interface WinForms)"] -->|grava| POL["scheduler-policy.json"]
  POL -. "não existe consumidor" .-> ENG["NEXO GPU ENGINE<br/>(não implementado)"]
  ENG -.-> W["Workers por GPU<br/>(não implementados)"]
  MON["Monitor Fase 4<br/>(passivo, 30 s)"] --> LOGS["CSVs locais<br/>(não versionados)"]
```

Linhas tracejadas são planejamento. Detalhes: [gpu-control.md](gpu-control.md).

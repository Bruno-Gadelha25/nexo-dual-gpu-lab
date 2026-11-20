# Arquitetura

Descreve o que o código das Fases 2 e 3 faz de fato (fontes em `phases/phase2-prototype/source/` e `phases/phase3-optimization/source/`).

## 1. Componentes

```mermaid
%%{init: {"theme":"base","themeVariables":{"primaryColor":"#1f1b26","primaryTextColor":"#f4f2ee","primaryBorderColor":"#ee1c25","lineColor":"#ee1c25","secondaryColor":"#2a2533","tertiaryColor":"#1a1720","clusterBkg":"#18151d","clusterBorder":"#77708a","edgeLabelBackground":"#14121a","fontFamily":"Segoe UI, Arial, sans-serif","actorBkg":"#1f1b26","actorBorder":"#ee1c25","actorTextColor":"#f4f2ee","actorLineColor":"#9a94a8","signalColor":"#ee1c25","signalTextColor":"#14121a","noteBkgColor":"#3a1418","noteTextColor":"#f4f2ee","noteBorderColor":"#ee1c25","labelBoxBkgColor":"#1f1b26","labelBoxBorderColor":"#ee1c25","labelTextColor":"#f4f2ee","loopTextColor":"#f4f2ee","activationBkgColor":"#3a1418"}}}%%
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
  classDef g970 fill:#3a2508,stroke:#ffa028,color:#ffd9a0,stroke-width:2px
  classDef g750 fill:#0b2f33,stroke:#3cd2dc,color:#c8f6fa,stroke-width:2px
  classDef eng fill:#3a1418,stroke:#ee1c25,color:#ffffff,stroke-width:2px
  classDef data fill:#1f1b26,stroke:#9a94a8,color:#f4f2ee,stroke-width:1px
  class E,REF data
  class G0,Q0,U0,RB0 g970
  class G1,Q1,U1,RB1 g750
  style Host fill:#18151d,stroke:#77708a,color:#f4f2ee
  style D0 fill:#24170a,stroke:#ffa028,color:#ffd9a0
  style D1 fill:#0a1f22,stroke:#3cd2dc,color:#c8f6fa
```

Observações:

- A atribuição "g0 = GTX 970" depende da **ordem de enumeração** DXGI. O código não confere nome nem LUID (achado M1 da auditoria).
- Cada GPU tem seu próprio dispositivo, fila, fence local e evento Win32. Não há nó compartilhado (não é Linked Node / SLI).

## 2. Uma medição de "compute" (Fase 3)

```mermaid
%%{init: {"theme":"base","themeVariables":{"primaryColor":"#1f1b26","primaryTextColor":"#f4f2ee","primaryBorderColor":"#ee1c25","lineColor":"#ee1c25","secondaryColor":"#2a2533","tertiaryColor":"#1a1720","clusterBkg":"#18151d","clusterBorder":"#77708a","edgeLabelBackground":"#14121a","fontFamily":"Segoe UI, Arial, sans-serif","actorBkg":"#1f1b26","actorBorder":"#ee1c25","actorTextColor":"#f4f2ee","actorLineColor":"#9a94a8","signalColor":"#ee1c25","signalTextColor":"#14121a","noteBkgColor":"#3a1418","noteTextColor":"#f4f2ee","noteBorderColor":"#ee1c25","labelBoxBkgColor":"#1f1b26","labelBoxBorderColor":"#ee1c25","labelTextColor":"#f4f2ee","loopTextColor":"#f4f2ee","activationBkgColor":"#3a1418"}}}%%
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
%%{init: {"theme":"base","themeVariables":{"primaryColor":"#1f1b26","primaryTextColor":"#f4f2ee","primaryBorderColor":"#ee1c25","lineColor":"#ee1c25","secondaryColor":"#2a2533","tertiaryColor":"#1a1720","clusterBkg":"#18151d","clusterBorder":"#77708a","edgeLabelBackground":"#14121a","fontFamily":"Segoe UI, Arial, sans-serif","actorBkg":"#1f1b26","actorBorder":"#ee1c25","actorTextColor":"#f4f2ee","actorLineColor":"#9a94a8","signalColor":"#ee1c25","signalTextColor":"#14121a","noteBkgColor":"#3a1418","noteTextColor":"#f4f2ee","noteBorderColor":"#ee1c25","labelBoxBkgColor":"#1f1b26","labelBoxBorderColor":"#ee1c25","labelTextColor":"#f4f2ee","loopTextColor":"#f4f2ee","activationBkgColor":"#3a1418"}}}%%
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
%%{init: {"theme":"base","themeVariables":{"primaryColor":"#1f1b26","primaryTextColor":"#f4f2ee","primaryBorderColor":"#ee1c25","lineColor":"#ee1c25","secondaryColor":"#2a2533","tertiaryColor":"#1a1720","clusterBkg":"#18151d","clusterBorder":"#77708a","edgeLabelBackground":"#14121a","fontFamily":"Segoe UI, Arial, sans-serif","actorBkg":"#1f1b26","actorBorder":"#ee1c25","actorTextColor":"#f4f2ee","actorLineColor":"#9a94a8","signalColor":"#ee1c25","signalTextColor":"#14121a","noteBkgColor":"#3a1418","noteTextColor":"#f4f2ee","noteBorderColor":"#ee1c25","labelBoxBkgColor":"#1f1b26","labelBoxBorderColor":"#ee1c25","labelTextColor":"#f4f2ee","loopTextColor":"#f4f2ee","activationBkgColor":"#3a1418"}}}%%
flowchart LR
  UI["NEXO GPU CONTROL<br/>(interface WinForms)"] -->|grava| POL["scheduler-policy.json"]
  POL -. "não existe consumidor" .-> ENG["NEXO GPU ENGINE<br/>(não implementado)"]
  ENG -.-> W["Workers por GPU<br/>(não implementados)"]
  MON["Monitor Fase 4<br/>(passivo, 30 s)"] --> LOGS["CSVs locais<br/>(não versionados)"]
  classDef g970 fill:#3a2508,stroke:#ffa028,color:#ffd9a0,stroke-width:2px
  classDef g750 fill:#0b2f33,stroke:#3cd2dc,color:#c8f6fa,stroke-width:2px
  classDef eng fill:#3a1418,stroke:#ee1c25,color:#ffffff,stroke-width:2px
  classDef data fill:#1f1b26,stroke:#9a94a8,color:#f4f2ee,stroke-width:1px
  class UI,POL,MON,LOGS data
  class ENG,W eng
```

Linhas tracejadas são planejamento. Detalhes: [gpu-control.md](gpu-control.md).

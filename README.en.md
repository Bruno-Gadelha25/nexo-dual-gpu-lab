# NEXO DUAL GPU LAB — English summary

Private research lab on heterogeneous compute with **two different NVIDIA GPUs in one PC** (GTX 970 + GTX 750 Ti, Intel i7-3770K, Gigabyte Z77X-UP5 TH, Windows 11), using Direct3D 12, independent COMPUTE queues, Cross-Adapter resources and fences. The Portuguese [README.md](README.md) is the reference version; if the two disagree, the Portuguese one wins.

- **Version:** `0.1.0-alpha.1` (experimental alpha). **License:** not chosen yet; do not redistribute.
- **Not** SLI, NVLink, unified VRAM or multi-GPU game rendering. **No** FPS gain has been shown.

## What was demonstrated

- Both GPUs ran D3D12 compute work at the same time, each with its own device and queue; every output element was checked on the CPU.
- Data moved between the cards through Cross-Adapter shared heaps and shared fences, in both directions, with no mismatches.
- On a synthetic workload (generate N integers and read them back to system memory), splitting the work across both GPUs cut median time by **28.6% to 50.4%** (1M–8M elements, 20 measured runs per configuration after 5 warm-ups).
- Consolidating the result onto one GPU cost more than that gain in every measured case.

## What the independent audit found

See [docs/audit/claude-audit-2026-11-19.md](docs/audit/claude-audit-2026-11-19.md) (Portuguese).

- All counts and summary statistics recompute exactly from the raw CSVs.
- The timed interval includes the GPU→host readback over PCIe, and the shader is very light. The implied rate (1.1–1.5 GB/s) matches a PCIe Gen1 x8 link, and the GTX 750 Ti ties the GTX 970 at large sizes. The most likely explanation is **two PCIe links copying in parallel**, not two GPUs computing. GPU timestamps are needed to confirm.
- The GTX 970 baseline drifted between measurement blocks (up to 21%), and run order was not randomized.
- The PCIe link state changed between campaigns (Gen1 x8 in Phases 1–3, Gen3 x8 in Phase 4B) with no documented cause.

## Status

| Phase | Status |
|---|---|
| 1 Diagnostics | Done |
| 2 Proof of concept | Done |
| 3 Optimization benchmarks | Done (interpretation under review) |
| 4 Passive monitoring | Running; data not imported |
| 4B PCIe instrumentation | Early validation; NVML counters not yet trustworthy; no benchmark |
| GPU Control UI | UI self-tested; no engine consumes its policy |
| OBS | Planning only; NVENC GPU not confirmed |

Static CI checks data and documentation only. It does not validate physical multi-GPU behavior.

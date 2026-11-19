# Changelog

All notable project changes are recorded here. Experimental measurements are append-only evidence; they are never rewritten to make a later version look better.

## [Unreleased]

Branch `feature/claude-repository-audit-2026-11-19`. No benchmark CSV or historical phase report was modified.

- **Added:** independent technical and scientific audit (`docs/audit/claude-audit-2026-11-19.md`), with severity table and verification steps.
- **Added:** read-only re-analysis of Phase 3 CSVs (`analysis/reanalyze_phase3.py`) and its derived outputs: bootstrap 95% CIs, implied throughput, GTX 970 baseline consistency, repetition trend.
- **Added:** `scripts/static-checks.ps1` (SemVer, CSV counts and statistics, Markdown links, credentials, absolute paths, PowerShell syntax, git fsck) and a static-only GitHub Actions workflow.
- **Added:** documentation set: index, architecture (Mermaid), hardware and environment, research methodology, reproducibility, test matrix, phase status, Phase 4B status report, GPU Control, OBS, glossary, FAQ, English summary, contribution guide.
- **Changed:** README rewritten as the lab's entry point, with results recomputed from the CSVs; technical overview, roadmap and privacy review updated.
- **Added:** exploratory Phase 3b probe (`phases/phase3b-probe/`, `data/phase3b-probe/2026-11-19/`, `docs/phase3b-probe-report.md`): without the readback the dual path is 44% slower; the GTX 750 Ti is ~3.06x slower in compute; link now Gen3 x8.
- **Corrected (interpretation, not data):** Phase 3 timings include the GPU-to-host readback over PCIe; the reported gain is not established as a compute gain. See audit finding C1.

## [0.1.0-alpha.1] - 2026-11-19

First private alpha snapshot of the NEXO DUAL GPU LAB research prototype.

- **Added:** hardware/DXGI/D3D12/CUDA inventory reports and reproducible diagnostic sources (Phase 1).
- **Added:** independent D3D12 compute queues, deterministic result validation, and bidirectional Cross-Adapter shared-resource/fence prototype (Phase 2).
- **Added:** workload partitioning and repeatable synthetic compute/transfer benchmark datasets with statistical summaries (Phase 3).
- **Added:** passive Phase 4 monitoring source and operator notes. Its live data is still being collected and is not included.
- **Documented:** measured results, dependencies, known limitations, privacy boundaries, and this versioning policy.

### Known limitations

- This is a synthetic-compute research prototype; it does not implement multi-GPU game rendering or demonstrate FPS gains.
- The measured Cross-Adapter transfer overhead can erase compute gains when results must be consolidated.
- Phase 4 monitoring is active; its raw logs and final analysis are excluded from this snapshot.
- The OBS/GPU Switcher preparation exists outside this repository and has not been integrated or benchmarked here.
- The project license is not yet selected. This private alpha is not an authorization to redistribute or publish it.
- No GPU-backed CI has been configured. Real multi-GPU compatibility must be validated on the target hardware.

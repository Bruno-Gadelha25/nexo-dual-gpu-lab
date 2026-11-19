# Changelog

All notable project changes are recorded here. Experimental measurements are append-only evidence; they are never rewritten to make a later version look better.

## [Unreleased]

- No changes recorded.

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

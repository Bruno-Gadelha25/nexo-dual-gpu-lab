# Release notes

## v0.1.0-alpha.1 — private experimental snapshot — 2026-11-19

This is the first versioned NEXO DUAL GPU LAB snapshot. It is an experimental research baseline, not a stable application and not a public release.

### Included

- Hardware and API inventory sources and reports.
- D3D12 compute prototype with independent devices/queues, deterministic CPU verification, and bidirectional Cross-Adapter resource/fence evidence.
- Synthetic workload optimization sources, benchmark CSVs, and statistical summaries.
- Phase 4 passive monitor source and documentation; live collection files are deliberately excluded.
- Dependency, privacy, architecture, and versioning documentation.

### Validation evidence

The checked-in Phase 2 and Phase 3 reports describe successful builds and hardware runs on the target GTX 970 + GTX 750 Ti system. The reports also state their limits: synthetic workloads do not model game rendering; transfer costs can remove the measured compute advantage; no FPS gain is claimed. Local repository object integrity and the copy manifest are checked by `scripts/validate-version.ps1`.

### Not included / not claimed

- No game integration, frame scheduling, or demonstrated gaming performance.
- No completed Phase 4 campaign or active raw logs.
- No tested OBS secondary-GPU encoder configuration; the external preparation module is not part of this repository snapshot.
- No redistributable license decision, installer, or public release.
- No assertion that cloud CI validates physical Multi-GPU behavior.

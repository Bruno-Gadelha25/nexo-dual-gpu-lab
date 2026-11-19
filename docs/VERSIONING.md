# Versioning and release policy

## Current baseline

`VERSION` stores the SemVer value without a leading `v`. The initial proposal is `0.1.0-alpha.1`: the project has reproducible source and measured research results, but remains an early prototype with no game-rendering integration, no stable API, no chosen redistribution license, and an active monitoring campaign. The `alpha.1` suffix expressly signals that scope.

## Semantic Versioning

Use `MAJOR.MINOR.PATCH` and SemVer prerelease identifiers, with `v` only on Git tags:

- While the project is experimental, keep `MAJOR=0`; increment MINOR for a new compatible capability/research milestone and PATCH for fixes or documentation/data corrections that do not change the milestone.
- Use `-alpha.N` for internal, incomplete snapshots; `-beta.N` only after the planned feature set is complete and reviewed; remove the prerelease suffix only after stability and compatibility criteria are met.
- A benchmark correction never replaces the old result. Append corrected data with provenance and explain the correction in `CHANGELOG.md`.

## Git layout

- `main` contains reviewed, versioned history. Keep the current single-maintainer flow on `main`; do not create `develop` until parallel integration work makes it useful.
- Use `feature/<short-name>` for bounded implementation work and `experiment/<short-name>` for temporary research whose code/data should remain reviewable. Merge by normal commits/PRs without rewriting published history.
- Keep one focused commit per meaningful phase/correction. Never force-push, remove historical benchmark files, or amend a tagged release.

## Tags and releases

Create annotated tags named `v< VERSION >`, e.g. `v0.1.0-alpha.1`, only after:

1. `VERSION`, changelog, history, release notes, and code scope agree.
2. Static validation and local Git object/file-integrity checks pass.
3. The available source builds successfully, or the exact build limitation is recorded.
4. Hardware-specific checks are either run on the real device and reported, or clearly marked NOT RUN. CI without physical GPUs must never be represented as Multi-GPU validation.
5. Private-repository visibility, reviewed file list, license/dependency state, and privacy audit are checked before any remote sync.

A Git tag is not a GitHub Release. This policy creates no public release. The repository remains private; any future visibility change requires the owner's explicit authorization.

## Validation automation

Run `powershell -NoProfile -File scripts/validate-version.ps1` in Windows PowerShell 5.1 for static checks. `-Compile` compiles source into a unique temporary directory without overwriting project artifacts. `-RunHardwareCompatibility` is opt-in, performs only the existing DXGI/D3D12 capability probe, and refuses while the Phase 4 monitor is active. It does not run the Phase 2/3 benchmarks. Those remain separately authorized measurements on the physical GPUs.

The validator checks SemVer metadata, annotated tag naming, Git object integrity, tracked copy-manifest hashes, and repository file-size limits. The script does not authenticate to GitHub or change remote visibility. A human privacy/license review remains necessary.

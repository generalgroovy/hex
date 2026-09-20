# Cleanup and pixel-art checkpoint

Status: verified local source checkpoint, 2026-09-08; not a new installer.

Source is the existing dirty `main` checkout at
`a1aa02807626823d0fbc1e25e75441ca3b7f4d36`. Pre-existing gameplay, roster,
packaging and other work was preserved. This slice changes documentation,
obsolete production paths, asset admission and presentation, not game rules.

## Removed and recoverable

| Cleanup | Result |
| --- | --- |
| Retired paths | 43 exact files: obsolete asset/README writers, triggers, unused production classes and exclusive tests, orphan sidecars, contradictory plans/prompts |
| Primary documents | One current specification, compact README, current visual/sprite contracts, one queue; old execution plan replaced with a short supporting guide |
| Projectile startup | Removed mandatory loads of nine older burst sheets and unused fallback drawing; current validated pixel library is the live route |
| Campus startup | One validated illustrated route; 558 lines of shadowed rendering removed; normal/reduced map pixels unchanged |
| Guard | 43 absent-path checks, live dependency scan, 13 data-derived primary-document claims; 103 self-test assertions |

The 43 retired files total 241,027 original bytes. Recovery copies and SHA-256
manifests are outside the repository at
`C:\Users\sende\Projects\flux-cleanup-archive-20260908`.
The `docs-contract`, `retired-designs`, `retired-prompts`, `runtime-cleanup`
and `runtime-cleanup/campus-startup` subfolders preserve exact pre-edit files.
Nothing was removed from Git history or another repository. No raw accepted
art sheet was deleted as part of dead-code cleanup.

This is dependency-proven cleanup, not a claim that every older-named file is
unused. Illustrated facade/roof/doorway/bell assets, contact/shadow sources,
source provenance, gallery validation, replay and save/wire migrations remain
real dependencies. Historical evidence is not an alternative current plan.

## Visible and reusable work

| Area | Actual state |
| --- | --- |
| Basic material | Stronger distinct eight-element pixel silhouettes and motion; essential identity/occupied boundary survive reduced effects and exhausted decorative budgets |
| Steam | Reviewed rounded rising lobes and upward decay instead of triangular mounds; six phase/quality sequences only, unchanged authority and concealment rules |
| Character assembly | Catalog-driven, hash-locked importer for all 27 identities and exactly three size guides; explicit alpha/background policy, fixed scale, no automatic runtime promotion |
| S. Wayne pilot | 12/80 review cells: all eight standing headings plus south/east walk A/B; exact originals and approved background-removal rules retained |
| Live character art | Existing five individual sets remain; 22 profiles still explicitly use same-size aliases; the new partial pilot is not a playable replacement |
| Runtime atlas admission | Current roster derives 24 extension slots beyond three base pages; strict identity/path/hash/pixel checks and failed-config cleanup |

The sprite pipeline reuses registration and anatomy guides, not palette-only
identity clones. One complete 80-cell identity must pass motion and native-scale
review before replacing a working sheet. Additional page residency needs a
coordinated presenter/gallery lifetime policy; a presenter-only cache would
leave gallery-held textures resident. That expansion is not implemented here.

## Evidence and limits

| Gate | Result |
| --- | --- |
| Initial cleanup Full | 87 suites, 398,015 assertions, zero failures/stderr; import and 120 Hz boot passed |
| Atlas admission | 4 focused suites, 33,159 assertions, zero failures/stderr |
| Campus cleanup | 7 focused suites, 8,704 assertions; actual normal/reduced decoded-RGBA captures identical before/after; clean 120 Hz/protocol 47 boot |
| Character importer | 997 technical assertions, zero failures/warnings/stderr; real pilot hashes/masks rechecked |
| Active pixel/material gate | 5 suites, 107,879 assertions, zero failures; 20,484 native pack checks |
| Export integration | Initial Full caught four stale export-pin failures; corrected the single atlas pin and retained seven-file fail-closed allowlist; 54,009 focused assertions then passed |
| Actual Windows PCK | 22 isolated checks: 474 sequences/3 textures, raw/imported pixel equality, six new Steam sequences, seven raw files and authoring exclusions; expected 27/57/36 runtime identity |
| Final aggregate Full | **87 suites, 398,314 assertions, zero failures/stderr; strict import and actual 120 Hz/protocol 47 boot passed in 99.502 s** |

Evidence is retained under `.godot/cleanup-20260908`, the material diagnostics
and each art batch's review/provenance files. Final aggregate evidence is copied
to `docs/evidence/cleanup-art-v1`, including the earlier failed gate. Automated proof does not certify
human charm, sustained 120 FPS, a physical friend session or Windows signing.

The accepted magic manifest is
`c9a76d6ae89aa9dc8f9898c9cae8ffbaaf6ae7495d54022859bf50968e97e1a4`.
Only atlas page 01 changed; all 468 other definitions and 1,936 non-Steam frames
remain byte-identical. Its reviewed raw export set is seven pages/119,207 bytes.
The prior source-audit hash was refreshed to the already-reviewed chemistry
kernel; no simulation source changed in this visual slice. Canonical LF output
preserves hashes across Git normalization. Original pack recovery is in the
external archive's `magic-steam` folder.

The diagnostic Windows PCK hash is
`1d42f075be2655b64805bbe875aabc0fe108bf7f8809d4be5b4fb5a5e141ebde`.
This is export proof, not a refreshed one-file installer or published release.

## Continue or test

Run `flux.cmd play` from the repository to test current source. The previous
`exports/windows-cast-gallery-p47-20260908/release/FLUX.exe` stays unchanged;
it does not contain this cleanup/art slice.

Next: finish S. Wayne's remaining motion cells, validate Small motion, then
Middle/Oh Tipi and Large/The Red Baron before expanding unique cast pages.
Further material work starts from actual normal/reduced gameplay captures.
Use the single queue in `.agent/OVERHAUL-IMPLEMENTATION.md`; do not resume old
production prompts. No commit, push, branch unification or publication occurred.

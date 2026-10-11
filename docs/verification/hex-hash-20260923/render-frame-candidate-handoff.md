# Render frame preparation candidate handoff

Date: 2026-09-23  
Scope: D6 test-only source; no production, registration, engine, import, capture, profile, export, package, identity, or queue action by this agent.

## Narrow hypothesis

D5 attributed the largest synchronous native draw bucket to `hex_ground`: normal distributed p50 24.861 ms of 36.057 ms total draw and normal dense p50 28.837 ms of 42.267 ms. D6 measures only the source-backed preparation portion that currently builds every `HexChemistryWorld.view()` and then calls `HexCourtPresenter._collect_render_regions()`.

`tests/support/hex_render_frame_candidate.gd` exposes:

- `current_bundle(court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float) -> Dictionary`, the actual current loop over `presenter._cells` followed by the actual current `_collect_render_regions()`;
- `candidate_bundle(court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float) -> Dictionary`, returning the same `{"views": Dictionary, "regions": Dictionary}` shape from one function-local pass.

The candidate applies only when `court.get_script()` is exactly `HexChemistryWorld` and the presenter's 44-material order exactly equals `HexChemistryWorld.material_layers()`. It declines subclasses. Any future production use must keep the current generic/subclass path. Renderable non-Dictionary cell or material records also fall back to `current_bundle()` instead of silently narrowing current behavior.

For an exact base court, the candidate seeds the same ordered material-region dictionaries. It creates a scalar-only zero-view template only when the presenter has cells, duplicates it per existing cell, reads each known layer once, skips empty dictionaries, and calls the original `render_regions()` only for nonempty layers. The raw rows produce the current quantities, presence flags, last raw Fire phase, and maximum Steam heat. The same rows immediately pass through the original `_prepare_region()` with the presenter's expected whole-cell polygon, then sort by `footprint_id` exactly as the current collector does. There is no cross-call/frame cache, geometry/selection/style change, raw-region alias, or mutable authority alias.

## Diagnostic contract

`tests/performance/profile_hex_render_frame_candidate.gd` is a headless preparation-only ABBA/BAAB diagnostic. It uses a fresh `res://.godot/hex-render-frame-candidate-*.json` receipt path.

The 21-case deterministic equivalence matrix covers:

- occupied-only empty court with zero presenter cells, plus full-topology empty court;
- exact Fire and product formation/active/decay/expiry boundaries at integral and fractional ticks;
- last-raw Fire phase, maximum Steam heat, zero-quantity presence, multiple overlapping footprint IDs, owners, source IDs, and expiries;
- missing and extra cell layers;
- direct mutation visibility and restoration;
- independent output views, regions, and nested source IDs with no authority alias;
- stale prepared membership after a cell is removed, preserving the current missing-cell two-field view;
- current fallback for renderable non-Dictionary material and cell records;
- original `_prepare_region()` rejection with complete views and fail-closed empty regions;
- structural refusal of a `HexChemistryWorld` subclass.

The two timed fixtures are the existing legal `sustained-distributed` and `dense-crucible` worlds after 120 neutral plus 40 paid ticks. Presenter configuration and `_prepare_court(..., false)` occur once and symmetrically outside both timed implementations, matching normal Wellspring's occupied-only membership. The receipt separately retains the 2,766-cell authority topology and asserts that timed presenter cells equal `court.occupied_cells().size()`; it does not confuse that stored membership with active-cell occupancy. The full-topology empty court remains equivalence-only. Each timed fixture uses four alternating cycles, four blocks per cycle, five unbatched samples per block: 16 blocks and 40 samples per implementation. Every sample's structure and Variant bytes are checked outside its timer. Completion guards require 21 equivalence cases, both legal cases, all 32 total blocks, and all 160 timed samples before success.

The receipt includes every raw block/sample, exact bundle byte size, view-cell and prepared-region counts, frozen authority hashes, legal metrics/occupancy, source hashes, and p50/p95/p99 comparisons. It cannot establish a complete `hex_ground`, draw, rendered frame, GPU, network, capacity, export, package, or release gain. Root owns any later native original/candidate pixel comparison and all production decisions.

## Static state

- `git diff --check` on both new GDScript files: PASS.
- Material-order assumption is asserted at runtime before equivalence or timing.
- Manual completion arithmetic: `21` equivalence cases; `40 = 4 cycles * 2 blocks per implementation * 5 samples`; `160 = 2 cases * 2 implementations * 40 samples`.
- Engine/import/test/profile execution by this agent: `NOT_RUN` by assignment; root-owned v1 evidence follows.

Ready-to-run source SHA-256 values (refresh if either source changes):

- `tests/support/hex_render_frame_candidate.gd`: `4c2dfc0f78e7980a4b5707a07d7b0e242369d2a884591736dc68b9d6890db949`
- `tests/performance/profile_hex_render_frame_candidate.gd`: `d2cbea1eb6acb1c8e6c1d69ea92509504e6b4c2d82f3e91dfca0d1e34e74156a`

## Root-owned headless v1 result

The root-owned isolated run passed with `PASS: hex-render-frame-candidate; 976 assertions; 0 failures`, 21/21 equivalence cases, 2/2 legal profile cases, all 32 blocks, 160 timed samples, and zero stderr. Each implementation has 40 samples per legal case. The receipt binds the frozen source hashes above and the exact current presenter/world sources.

| Legal tick-160 case | Timed views | Prepared regions | Bundle bytes | Current p50 / p95 / p99 | Candidate p50 / p95 / p99 | Median delta |
|---|---:|---:|---:|---:|---:|---:|
| Sustained distributed | 57 | 64 | 214,532 | 14,904 / 17,428 / 17,914 us | 5,314 / 6,311 / 7,128 us | 9,590 us |
| Dense crucible | 49 | 81 | 198,392 | 14,092 / 16,525 / 16,973 us | 5,623 / 7,079 / 8,076 us | 8,469 us |

The timed memberships are the actual occupied-only presenter cells for normal Wellspring. Both authorities separately retain the full 2,766-cell topology. The distributed authority hash is `0da034fd61796a2e1768ec9365b0eceedd719d42126c9c3f49f01515cab89305`; the dense authority hash is `f77fec6a943ef75ca80596dd92b5ab50c4c455063a031e7fddbf45396c572c76`.

Evidence:

- receipt: `.godot/hex-render-frame-candidate-hash-v1.json`, SHA-256 `32a7c2b7ee763f3da41760aea47938fbbde917a16ccc1a7c9b8e65451ce9860b`;
- stdout: `.godot/hex-probe-hash-render-frame-v1/probe.log`, 198 bytes, SHA-256 `852f9f59f19b20249f8fd8d69fc9abadf727ebe9d1d15ef7f7ca8157b3e72e7b`;
- stderr: `.godot/hex-probe-hash-render-frame-v1/probe.log.err`, 0 bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

This establishes a material reduction only for headless function-local view and prepared-region construction. It does not establish a complete `hex_ground` or frame reduction, pixel equivalence, rendered behavior, GPU behavior, capacity, or release acceptance. Production integration remains undecided pending the separately root-owned native original/candidate pixel and timing comparison.

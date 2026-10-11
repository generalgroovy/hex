# D8 viewport submission candidate handoff

Status: **TEST-ONLY DRAFT, NOT RUN, relinquished to root on 2026-09-23.** The production runtime remains sealed at `p55-1b26a51136d1`; no production, registration, identity, import, test, capture, profile, or export action was performed by this task.

## Current frozen draft

| File | SHA-256 | State |
| --- | --- | --- |
| `tests/support/hex_viewport_candidate.gd` | `d7bd92c559c3b983b3b981558f982ecf5cf942cffbc421d9faaa85300a332bd1` | Relinquished test-only candidate |
| `tests/support/hex_viewport_harness.gd` | `0288de2e09227f855aa58c1ff145861e82cf262362175dd885febead6da38180` | Relinquished test-only native bridge |
| `tests/performance/profile_hex_viewport_candidate.gd` | `1f36d713dcb36fcf7d848a9b6862604848185d3f53163d799192b2994eefa79e` | Relinquished pre-run profiler draft |

The candidate keeps `draw_ground` unchanged by inheritance and exposes an explicit test-only visible call. It performs the full D6 frame preparation, cover extraction, and semantic edge counting before conservatively rejecting wholly offscreen regions in only the five material loops. Cover repaint, apron, stone, and rim remain unculled. The visible rectangle is derived function-locally from the snapped camera transform and expanded by `8 + 1 / zoom`. Invalid, nonfinite, empty, degenerate, and zero-area geometry fails open. No cross-frame cache or authority mutation is introduced.

The profiler draft targets 103 analytic visibility checks, three fallback checks, 55 native RGBA controls, and four legal paid-scene timing cases. Timing uses four ABBA/BAAB cycles with five samples per block, producing 40 samples per arm per case. Candidate-only diagnostics, image readback, hashing, fixture setup, and source/identity checks are outside the intended timed sample. Synthetic material and boundary controls are pixel oracles and are not gameplay workloads.

The last completed source change added a test-harness factory for the nested ground canvas, guarded the occupied-cell lookup, and made timing sample/flattened-series type checks explicit. `git diff --check` passed for all three source files after that change. No Godot parser or runtime validation has run.

## Required corrections before the first engine run

1. `_public_fallback_cases` calls the derived-world district-base path on a detached `Node2D`. That path issues apron/stone/rim drawing outside `_draw` and will be rejected by Godot. Route this control through the existing `GroundCanvas`/`_present_direct` draw notification, or make this inactive return-only fallback use `draw_district_base=false`; the separate practice native pixel case already covers `true`.
2. The diagonal `cross` boundary placement moves the region AABB only one pixel across each viewport edge. A pointy hex can then have no rasterized polygon pixel inside the corner, making the positive material control fail for a geometrically valid reason. Keep AABB contact checks distinct and move the visible-corner positive oracle far enough across both edges to guarantee actual polygon raster coverage.
3. `_finish({})` records counters, hashes, and identity but discards completed `pixel_cases`, `timing_cases`, and their case-level diagnostics because those arrays are local to `_run`. Retain the accumulated arrays in run-owned fields or pass a partial payload at each failure exit so a failed run preserves the completed evidence requested by root.

These are pre-run blockers. The current hashes identify the relinquished draft and must not be described as an executable or accepted candidate. Root owns all subsequent changes and engine execution.

## Evidence limits

- `NOT_RUN`: parser/import, analytic assertions, native RGBA comparison, timing, source/identity runtime guards, and receipt production.
- The draft does not establish a frame-rate, GPU, sustained-cadence, network, capacity, package, or release result.
- The test-only Bootstrap bridge recomputes the production camera transform for measurement; production does not yet pass a visible rectangle to the presenter.
- The candidate copies the five bounded production submission loops, so source drift must be checked again before any integration decision.
- Even a successful first diagnostic would measure material submission only. It would not authorize production integration or prove end-to-end gameplay capacity.

# Render frame preparation integration handoff

Date: 2026-09-23  
Scope: bounded production integration in `HexCourtPresenter` plus one focused unit suite. Root owns registration, engine execution, identity, native validation, packaging, and release decisions.

## Production change

`src/presentation/hex_court_presenter.gd` now constructs the two read-only per-draw products through `_prepare_frame_bundle(court, tick)`. In `draw_ground()`, only the old per-cell `view` loop and `_collect_render_regions()` call were replaced. Cover-surface selection, district base, every material draw helper, rim drawing, ordering, styles, and return behavior remain in their original order.

The integrated exact-base path is the measured D6 candidate:

- it runs only when `court.get_script()` is exactly the preloaded `HexChemistryWorld` script and the current 44-material order equals `HexChemistryWorld.material_layers()`;
- it allocates one function-local scalar zero-view template only when `_cells` is nonempty and duplicates that template per existing cell;
- it reads each known cell layer once, skips missing/empty dictionaries, and calls the original `HexChemistryWorld.render_regions()` only for nonempty dictionaries;
- it derives quantity, presence, last-raw Fire phase, and maximum Steam heat from those raw regions;
- it immediately invokes the original `_prepare_region()` with the presenter's expected whole-cell polygon and retains the original footprint sort;
- it creates no persistent or cross-frame cache and returns fresh views, prepared regions, polygons, and nested source IDs with the same Variant order/bytes as the frozen old oracle.

`_current_frame_bundle()` preserves the prior call-based view loop and original collector. `_prepare_frame_bundle()` uses it for every generic court, subclass, material-order mismatch, non-Dictionary cell record, or non-Dictionary known layer. Missing authority cells retain the old two-field `fire_phase`/`steam_heat` view. Original `_prepare_region()` rejection still returns complete views and fail-closed empty regions.

The pre-edit presenter is preserved at `docs/verification/hex-render-frame-20260923/baseline-source/src/presentation/hex_court_presenter.gd`, SHA-256 `c31e3637085fac57ec1091cf89944c6fd964dacafb1f86afa569290d9eb44393`.

## Unit suite

`tests/unit/test_hex_render_frame.gd` is a standalone `FluxTestSuite` with stable suite ID `hex-render-frame`. Root should register:

```gdscript
preload("res://tests/unit/test_hex_render_frame.gd"),
```

The suite contains 16 guarded equivalence cases and a statically expected 84 assertions. It compares the actual production `_prepare_frame_bundle()` with only `HexRenderFrameCandidate.current_bundle()`, the frozen pre-integration loop/collector oracle. It covers:

- ordered 8+36 material identity and Fire/product phase boundaries at fractional and integral ticks;
- zero-quantity presence, overlapping owners/source IDs/expiries, missing and extra layers;
- direct mutation visibility/restoration;
- independent views, regions, and nested source IDs with no authority alias;
- renderable Array cell/layer fallback;
- original `_prepare_region()` rejection with complete views and empty regions;
- a subclass override that adds a distinctive `subclass_marker`, proving the generic fallback preserves overridden behavior and exact old bytes;
- an independent duck-typed generic court oracle;
- an empty occupied-only presenter with zero cells.

Focused contract after root registration:

```powershell
pwsh -NoProfile -File scripts/test.ps1 -Tier Focused -Suite hex-render-frame
```

Root's broader gate should retain the existing shared/court/handoff/Water/whole-coverage/authored-shape suites it selected, then Full and native/package gates if Focused passes.

## Static verification

- Baseline-to-production no-index diff contains one preload, the narrow `draw_ground()` construction replacement, `_prepare_frame_bundle()`, and `_current_frame_bundle()` only.
- `git diff --check` for the presenter and new unit suite: PASS.
- Frozen D6 prototype and profiler remain unchanged.
- Godot/import/Focused/Full/native/package execution by this agent: `NOT_RUN` by assignment.

Root's fresh production Focused v2 run passed the registered `hex-render-frame` suite with its exact 84 assertions and guarded 16-case completion. The selected seven-suite adjacency set passed 2,074 assertions total with zero failures and zero stderr bytes. Receipt: `docs/verification/hex-render-frame-20260923/focused-v2.json`, SHA-256 `e3e9d5da5a524d733c6afef8b5f9ad5a79136d6defc3a0fbfb1add23faf860b3`. Captured output: `docs/verification/hex-render-frame-20260923/focused-v2.out`, SHA-256 `bc1f42733596c50e21ad06b9d366d0768eb002ab9f78c036a241b09e396a7ce7`.

Final SHA-256 values (refresh if source changes):

- `src/presentation/hex_court_presenter.gd`: `57926b68365d872a71224a52d6560ae9a0c0119f8533cb5a99ee60291da5621a`
- `tests/unit/test_hex_render_frame.gd`: `ff096a9ddc474d855585a253418c05eb09899fbaea8f016f5e82d95c4a8a3457`

## Evidence boundary and unresolved runtime gates

The sealed pre-integration D6 headless result measured only views plus prepared regions: distributed p50 14.904 to 5.314 ms and dense p50 14.092 to 5.623 ms, with exact Variant bytes. The sealed native D6 evidence was collected before this source integration. After integration, the native test-only presenter's `super.draw_ground()` resolves to the new runtime implementation, so rerunning that old harness cannot be described as another independent old/new comparison. Any post-integration native claim must use the preserved baseline/oracle or an explicitly reviewed control design.

Runtime parsing, the 84-assertion suite, and the selected adjacent Focused suites are freshly passed by root as recorded above. Full, native pixels/timing, runtime identity, PCK/EXE, and artifact integrity remain root-owned unresolved gates. The integration does not by itself establish rendered frame, GPU, network, capacity, export, package, or release acceptance.

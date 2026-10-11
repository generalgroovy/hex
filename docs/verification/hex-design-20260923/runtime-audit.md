# H.E.X. runtime and geometry audit

Status: bounded static audit and read-only probe handoff, 2026-09-23. Godot execution, imports, tests, profiling, captures, networking and exports are `NOT_RUN` by this worker and remain root-owned. The dirty `main` checkout at `1559a566e33255c59337c5963f1c3c685d757f1f`, the frozen `p55-a0952919d4d5` Loom candidate, personal profiles, prior exports and staged packs were not changed.

## Authority boundary

The live contract remains 48 px face-to-face whole cells, unchanged Wellspring bounds/obstacles, 18 px clearance, unchanged character bodies and world-space spell radii, positive-area cell eligibility, and full effect across every selected cell. Paid material is divided across the complete selection. There is no valid nearest-N or per-pixel clipping substitute (`SPECIFICATION.md`; `src/sim/hex/hex_grid.gd:7-17`; `src/sim/hex/hex_footprint.gd:420-444`; `src/sim/hex/hex_chemistry_world.gd:238-252,677-684`).

The campus definition enumerates complete hex polygons inside the same playable rectangle and excludes polygons overlapping collision obstacles expanded by the fixed 18,000-unit clearance. It rejects any topology above `HexChemistryWorld.MAX_CELLS` (`src/sim/hex/hex_world_definition.gd:17-60`). The cap is exactly 4,096 in simulation, chemistry snapshot validation and snapshot wire packing (`src/sim/hex/hex_chemistry_world.gd:9,55-73`; `src/net/hex_chemistry_snapshot.gd:15,810-831`; `src/net/hex_snapshot_wire_packing.gd:8,27-28`). It is a topology cap, not permission to omit eligible cells or cap an effect.

The current 48 px definition has 2,766 eligible cells. The smaller-lattice question cannot be answered by changing `HexGrid` constants in-place: `HexWorldDefinition`, footprint selection, collision, contact, render polygons, topology hashes and protocol identity all consume that global geometry. The standalone `tests/diagnostics/hex_geometry_comparison_20260923.gd` instead replays only the definition's enumeration policy against the same map/collision/clearance at 48, 32 and 24 px. Its 48 px result must equal the production cell array in exact order and reproduce `definition_hash`; otherwise all candidate results fail. It never configures 32/24 authority, raises a cap, changes the map, selects an effect or truncates a result.

Candidate integer geometry is explicit: 48 uses `(half_width, half_height)=(24000,27712)`, 32 uses `(16000,18476)`, and 24 uses `(12000,13856)`, with even heights and `row_pitch=3*half_height/2`. The exact 32/24 eligible counts and cap margins are `ROOT_PENDING`; they must come from the receipt rather than area-ratio estimates. If either count exceeds 4,096, the current definition, authority, snapshot and packing contracts reject it. Raising that cap would be a separate simulation/network/schema/capacity design change, outside this audit.

## Snapshot and storage hotspots

The retained fresh receipt `docs/verification/hex-acceptance-20260921/snapshot-stages.json` is five-sample diagnostic evidence for one unchanged 48 px workload: eight champions, 120 neutral warmup ticks, 40 paid dense-crucible ticks, 29 active cells, 2,400 source plus 2,400 product quantity, 332 correctness assertions and no failures. Its inclusive stages overlap and cannot be summed:

| Stage | p50 | p95/max | Concrete work |
| --- | ---: | ---: | --- |
| world capture | 471.974 ms | 556.525 ms | chemistry encode, world lanes, compression and complete detached `prepare` roundtrip (`src/net/hex_world_snapshot.gd:73-147`) |
| world prepare | 294.957 ms | 304.929 ms | decode, trusted topology reconstruction, relation validation, collision clone/surfaces and final hash (`src/net/hex_world_snapshot.gd:178-258`) |
| chemistry restore | 282.545 ms | 333.664 ms | fresh dense topology, typed-lane decode, relations/conservation and exact authority hash (`src/net/hex_chemistry_snapshot.gd:223-275`) |
| chemistry producer | 146.712 ms | 150.843 ms | topology validation/indexing, sparse allocation lanes, topology hash and full chemistry state hash (`src/net/hex_chemistry_snapshot.gd:67-173`) |
| blank chemistry world | 139.104 ms | 145.009 ms | 2,766 cells, each deep-owning 44 material dictionaries (`src/sim/hex/hex_chemistry_world.gd:55-73,111-122`) |
| world state hash | 77.172 ms | 77.951 ms | canonical world plus chemistry projection; chemistry still visits every topology record (`src/sim/hex/hex_chemistry_world.gd:1087-1114`) |
| prediction bind | 73.277 ms | 74.586 ms | deep duplicate of all mutable chemistry dictionaries plus collision clone/surfaces (`src/net/client_prediction.gd:274-296`) |
| topology hash | 8.431 ms | 9.328 ms | ordered coordinates and three metadata integers per cell (`src/net/hex_chemistry_snapshot.gd:832-843`) |

Wire size was only 3,216 encoded chemistry bytes and 7,908 world bytes. The dominant observed cost is local validation/allocation/hash work over a dense trusted topology, not transmitted topology: snapshots deliberately address trusted cells by stable lexicographic index and do not accept remote map geometry (`src/net/hex_chemistry_snapshot.gd:48-50`).

The sharpest repeated interpreted loop is `_trusted_cells`: every call validates each cell key, record, three exact integer metadata fields and all 44 material dictionaries (`src/net/hex_chemistry_snapshot.gd:810-831`). At 2,766 cells this is 121,704 layer checks per call, before sorting. Chemistry production calls it; incoming `_prepare` calls it again and then configures a fresh topology. The world producer avoids an extra chemistry-only roundtrip, but intentionally retains the complete outer `prepare` before publishing bytes (`src/net/hex_world_snapshot.gd:73-87,142-147`). This is expensive by design and currently correct.

Dense storage has a clear scaling consequence. Every trusted cell owns 44 independently mutable material dictionaries, even though the measured workload occupied 29 of 2,766 cells. A 32/24 lattice increases topology work approximately with cell count in definition enumeration, blank construction, `_trusted_cells`, topology hash, state-hash projection, prediction deep copy and collision topology. That qualitative dependency is source-established; exact timing at unaccepted scales is `NOT_RUN` and must not be extrapolated from five samples.

## Smallest safe optimization

The smallest bounded candidate remains a stateless empty-cell shortcut inside `HexChemistrySnapshot._trusted_cells`, with no cache and no schema change:

1. Create one function-local `World._new_empty_cell()` template.
2. Retain the size/origin checks, `Vector2i` key check, dictionary record check, and exact `TYPE_INT` checks for `terrain`, `elevation` and `structure` before any shortcut.
3. Set the template's three metadata fields to the validated record values. If native structural equality proves `record == template`, append the cell without 44 interpreted material checks. Otherwise run the current 44 `has`/dictionary checks unchanged.
4. Sort and return exactly as today.

This targets the observed empty majority and changes neither accepted input shape nor output order. It must preserve acceptance of extra fields and nonempty material dictionaries, reject every existing malformed shape, and observe mutations on the next call. It establishes shape only; it does not establish ownership. Independent mutable ownership must still come from the current deep construction/copy paths.

A topology fingerprint/revision cache is not the next safe slice. The contract permits reuse only within one synchronous operation after validation, and there is no current immutable-topology owner token that can justify reuse across mutable authority calls. Sparse/lazy live-cell storage could remove more cost, but it changes internal ownership, hashing, prediction, collision and malformed-state behavior and is therefore a later design slice.

## Equivalence and malformed-input gates

Any snapshot optimization must prove all of the following against the old implementation, not merely pass a happy-path capture:

- exact ordered `Array[Vector2i]`, topology hash, chemistry snapshot dictionary/typed lanes, canonical bytes, snapshot hash, world snapshot, state hash, paid metrics and next-tick authority;
- source authority unchanged by accepted and rejected calls; destination cell/layer dictionaries independently mutable across cells, reconstructed worlds and prediction replicas;
- exact rejection of non-`Vector2i` keys, non-dictionary records, missing metadata, float/string/dictionary/null metadata, missing material names, and scalar/array/null material values;
- unchanged acceptance of integer metadata, empty/nonempty material dictionaries and extra fields where the current validator accepts them;
- empty, oversized (>4,096), reversed-insertion, negative-coordinate and exact-4,096 boundary topologies; invalid origin and direct mutation between consecutive calls, with no stale result;
- complete relation/conservation checks, 1,048,576-byte chemistry bound, 32,768-byte world/envelope bound, malformed compressed chemistry rejection, canonical sorting and presentation `value_revision` invalidation (`src/net/hex_chemistry_snapshot.gd:205-275,773-843,934-977`; `src/net/hex_world_snapshot.gd:13-22,152-258`; `src/net/world_snapshot_envelope.gd:13-15,68-101`).

Smaller geometry also needs independent mechanic equivalence rather than a topology-only green result. World-space radii remain unchanged, so finer cells increase selected-cell counts. Per-part/product coverage is bounded at 127 cells in cast validation and snapshot decode/packing (`src/sim/hex/hex_cast_parts.gd:11,278-315`; `src/net/hex_chemistry_snapshot.gd:16,596,699`). Before any scale can become live, enumerate every maximum disk/sector/capsule/annulus/intersection used by all spells and recipes at boundary, obstacle and negative-coordinate cases. Reject the scale if any valid full selection cannot fit existing exact bounds; nearest-N truncation or omitted zero allocations is invalid. Then prove selection, conservation, continuous traversal/contact, collision/occlusion, pressure balance and snapshot roundtrips on the complete cells.

## Contact and visibility findings

Persistent whole-cell contact is canonical-owner based: point containment maps to exactly one cell, segment traversal scans stored active cells through bounded AABBs, analytic-shape contact returns a canonical selected owner, and persistent field contact requires shared selected membership (`src/sim/hex/hex_footprint.gd:447-615`). Whole-cell selection uses positive area and strict tangency rules (`src/sim/hex/hex_footprint.gd:680-750`). Geometry scaling cannot replace these paths with cell-center, nearest-cell or nearest-N tests.

Current presentation visibility uses the same interpolated observer/actor ground anchors, 360 degrees, 720 ground units, authored building rectangles, exact active solid-cover hex segment checks, and chemistry blockers (`src/app/bootstrap.gd:3170-3183,3607-3636`). Combat cues and relevant audio reuse that predicate (`src/app/bootstrap.gd:1452-1459,1541-1565,3648-3659`). Strict LOS is therefore a separate invariant from the fog artwork and should remain unchanged.

For root's 3,072 × 2,304 static-terrain SubViewport design:

- Use map/world UV for static terrain and exact building rectangles/hex polygons. Do not apply the 55-degree metric projection to map geometry; projection is used for sight distance/radial presentation while world collision positions remain screen-cardinal (`src/presentation/sight_occlusion.gd:44-58`).
- A tangent shadow quad includes the near silhouette chord and therefore covers part of its own occluder. Subtract the exact owning convex polygon from that shadow before the single mask union. For solid hex cover use `hex_occluders()` polygons, not their `Rect2`; the existing helper explicitly preserves traversable bounding-box corners (`src/presentation/sight_occlusion.gd:94-126`; `src/sim/hex/hex_collision_world.gd:202-206`).
- Do not repaint all occluders globally after composing shadows. That can reveal a far occluder through a nearer occluder's shadow. Own-polygon subtraction belongs to each shadow before union; other occluders' shadows must still shade that surface. Compose one final bounded overlay so overlapping shadows do not accumulate darkness.
- Dynamic cover for sight includes recipe IDs 301, 305, 306, 307 and 329, while movement-solid coverage is only 301 (`src/sim/hex/hex_collision_world.gd:82-100`). Keep fog surface shading separate from movement collision and obtain dynamic occluders from the collision replica used by `_pov_point_visible`.
- A cache key based only on `HexChemistryWorld.value_revision` is insufficient: cover activates/expires as `tick` crosses product phase boundaries, and the collision cover set is rebuilt at the beginning of each simulation step before moving products (`src/sim/core/sim_world.gd:68-84`). Use the actual post-`set_hex_surfaces` occluder polygon set, or add an exact cover revision owned by `HexCollisionWorld`. A broad value revision will also invalidate for unrelated chemistry.
- The static full-map RGBA8 texture is about 27 MiB before framebuffer/driver overhead. Record allocation/rebuild count and GPU frame timings. Build it once per map/layout/resource identity, not per frame; update fog geometry for interpolated viewpoint, camera origin/zoom/viewport and actual cover-set changes. Preserve nearest/linear filtering intentionally at fractional zoom and check world-edge/reserved-UI sampling.
- Feathering is cosmetic only. The hard LOS predicate must continue to gate actor bodies, labels, health, speech, contact cues and audio. Test exact face/vertex tangencies, observer inside/on an occluder (fail-closed shadow helper), overlapping building/hex shadows, far-surface occlusion, spectator viewpoint changes, zoom/resolution changes and normal/reduced effects.

## Root run and acceptance plan

Run the geometry oracle exactly once through the repository's guarded engine wrapper, using a fresh receipt suffix:

```powershell
Set-Location C:\Users\sende\Projects\hex
. .\scripts\flux2-common.ps1
$hexRoot = (Get-Location).Path
$hexLog = Join-Path $hexRoot '.godot\hex-geometry-comparison-20260923-v1.log'
Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless','--path',$hexRoot,'--script','res://tests/diagnostics/hex_geometry_comparison_20260923.gd','--','--output=res://.godot/hex-geometry-comparison-20260923-v1.json') $hexLog -RejectWarnings -TimeoutSeconds 180
Get-Content -Raw -LiteralPath (Join-Path $hexRoot '.godot\hex-geometry-comparison-20260923-v1.json')
```

Expected limits: 48 px must report 2,766 cells, exact production order/hash equivalence, positive cap margin and coordinate safety. The 32/24 counts are deliberately not baked in; use their exact receipt values. Any `within_live_cap=false` is a hard current-contract rejection, not an invitation to raise 4,096 or omit cells. This topology probe does not establish snapshot capacity, gameplay/contact/visibility equivalence or protocol compatibility.

For the optimization gate, first rerun the unchanged `tests/performance/profile_hex_snapshot_stages.gd` to create a new five-sample 48 px baseline. Implement only the stateless `_trusted_cells` branch plus a frozen independent old-function oracle. Measure old/candidate exclusive validation in three ABBA cycles over the identical real topology, with output equality and source preservation outside timers. Run focused chemistry/world/prediction malformed-input and ownership suites, rerun the unchanged stage profiler, then the unchanged representative dense workload. Accept only with exact equivalence and a repeatable local reduction; do not describe it as 120 Hz capacity unless an end-to-end p95 workload meets 8.333 ms under the unchanged eight-player contract.

## Files and current result

- Added `docs/verification/hex-design-20260923/runtime-audit.md`.
- Added `tests/diagnostics/hex_geometry_comparison_20260923.gd` as a read-only root-run oracle.
- Runtime, shared schemas/catalogs, queues, maps, caps and selected checkpoints: unchanged by this audit.
- Static inspection and `git diff --check`: passed.
- Godot import/script/test/profile/export/network execution: `NOT_RUN`.
- 32/24 exact eligibility/cap outcome: `ROOT_PENDING`.
- Smallest optimization implementation and timing improvement: `NOT_IMPLEMENTED` / `NOT_ESTABLISHED`.

## 2026-09-23 opaque-terrain review and native oracle handoff

Root subsequently reported a fresh geometry-oracle pass with 25 assertions: 48 px = 2,766 eligible cells, 32 px = 6,495 and 24 px = 11,633. The 32 px and 24 px candidates therefore exceed the unchanged 4,096 topology cap by 2,399 and 7,537 cells respectively. This is a current-contract rejection for both smaller scales. It does not authorize topology omission, nearest-N selection, a cap change or a protocol/schema change. Root also reported a fresh 332-assertion snapshot-stage pass with world-capture p95 504.123 ms and prepare p95 296.851 ms. Those root-run values supersede `ROOT_PENDING` for the exact counts and refresh the five-sample performance observation; they still do not establish 120 Hz capacity or a safe smaller-grid migration. This audit worker did not run or independently inspect those engine receipts.

The finalized opaque-terrain design avoids overlapping-alpha leakage by sampling one static 3,072 x 2,304 campus texture and replacing hidden pixels with terrain rather than repeatedly darkening live pixels. The important geometry constraints remain:

- screen polygons, canary positions and texture UV inversion must use the same `PixelPresentation.snapped_canvas_origin(camera_origin, zoom_percent)` translation as `_set_world_transform`; deriving them from unsnapped `-camera_origin * zoom` introduces a one-pixel disagreement at fractional camera positions;
- each tangent shadow must exclude only its own exact rectangle/hex surface before terrain replacement, while a different blocker may still shade that surface;
- `HexCollisionWorld.hex_occluders()` is the canonical presentation/sight polygon source for active recipe IDs 301, 305, 306, 307 and 329; movement solidity remains the narrower Rampart-only rule;
- invalid/dead/missing viewpoint authority must replace the full viewport with opaque terrain. The missing-local branch returns before the ordinary mask call, so its test canary must be submitted from an earlier production draw hook and proven visible while a living actor is present;
- the full-map RGBA8 texture remains roughly 27 MiB before render-target and driver overhead. A one-time map/layout build avoids per-frame rebuild cost, but allocation, upload, native frame time and resize/device-reset behavior still need measured evidence.

`tests/visual/capture_terrain_visibility.gd` is the bounded native oracle for root to run. It subclasses production Bootstrap and injects a 15 x 15 magenta canary immediately before `_draw_pov_mask`; consecutive baseline/canary crops must be byte-identical behind a real wall, inside the wall surface, outside 720 projected ground units, inside an exact active cover hex, and with dead/missing observer authority. Clear in-range and post-cover-removal controls must change at least 64 crop pixels. Eight bearings use one dynamically selected authored `los_cutaway` wall. Both normal/reduced modes and 50/75/100 zoom are covered, at least one camera origin must be noninteger, and every pair preserves the exact world state hash and runtime object identities. One presentation-only Rampart dictionary is injected and then removed through `HexCollisionWorld.set_hex_surfaces`; the restored authority hash must match exactly. It is explicitly not a paid-formation oracle. A real spectator path is `NOT_RUN` because it requires a connected-client/session fixture; the helper does not fake `_is_spectating`.

Root can run the helper once under the guarded native engine lease and an isolated profile. Both the profile directory and capture directory must be fresh; resolve the pinned engine before replacing `LOCALAPPDATA`:

```powershell
Set-Location C:\Users\sende\Projects\hex
. .\scripts\flux2-common.ps1
$hexRoot = (Get-Location).Path
$godot = Get-FluxGodot
$capture = Join-Path $hexRoot '.godot\terrain-visibility-20260923-v2'
$log = Join-Path $hexRoot '.godot\terrain-visibility-20260923-v2.log'
$profile = Join-Path $hexRoot '.godot\terrain-visibility-profile-20260923-v2'
if ((Test-Path -LiteralPath $capture) -or (Test-Path -LiteralPath $profile)) { throw 'Capture and isolated profile paths must be fresh.' }
New-Item -ItemType Directory -Path (Join-Path $profile 'Roaming'),(Join-Path $profile 'Local') | Out-Null
$priorAppData = $env:APPDATA
$priorLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $profile 'Roaming'
    $env:LOCALAPPDATA = Join-Path $profile 'Local'
    Invoke-FluxGodotChecked $godot @('--path',$hexRoot,'--script','res://tests/visual/capture_terrain_visibility.gd','--',"--output=$capture") $log -RejectWarnings -TimeoutSeconds 300
} finally {
    $env:APPDATA = $priorAppData
    $env:LOCALAPPDATA = $priorLocalAppData
}
Get-Content -Raw -LiteralPath (Join-Path $capture 'capture-receipt.json')
```

Expected result: `status=native_opaque_terrain_visibility_capture_complete`, 31 cases, zero failures, eight `wall-approach-*` records, six `wall-zoom-*` records, nonzero `fractional_camera_cases`, `changed_pixels=0` for every hidden oracle, at least 64 changed pixels for every visible control, and restored cover/missing-actor authority hashes. A parse/runtime failure, any leaked hidden pixel, a missing visible canary, identity/hash drift, absent exact hex occluder, or zero fractional-camera cases is a hard failure. A passing receipt is local native-render evidence only; it does not establish paid cover creation, spectator/network filtering, exports, performance or human visual acceptance.

Root executed this exact helper (`sha256=07d32931300f7b0a2183d460bdefa56adf4d886f178bb7527f09102201cdcfb4`) against frozen source identity `p55-ede24ea44158`. The fresh receipt is `.godot/hex-terrain-v1/capture-receipt.json` (`sha256=5d99f689db3f9005037ab57afd72c1794f191791c686ef7a9c8d53d59ef282a3`): Windows native display, Godot 4.7.1 stable official, 31 cases, 159 assertions, zero failures and root-reported zero stderr. All 25 hidden cases changed exactly zero sampled pixels. All six visible controls changed 209-225 pixels, well above the 64-pixel floor. Twenty-eight cases used fractional camera origins. The receipt records the expected 2,766-cell topology and map hash `9d481a582a0e84c1ecb74ee7637ba6cd7f9119deb0eeacdc509904f5d4810417`. This closes the bounded local canary oracle only. Native spectator, paid cover formation, multiplayer filtering, performance, exports and human visual acceptance remain `NOT_RUN` by this helper.

Root's subsequent image inspection correctly narrowed that receipt: its first synthetic cover record populated collision/products but omitted the Fortify material-layer membership and complete render metadata, so the active-cover canary proved opaque terrain replacement inside a collision hex but did not prove that `draw_cover_surfaces` restored a visible structural layer. Preserve the receipt as preliminary canary evidence; do not cite it as a cover-surface rendering pass. The corrected helper (`sha256=d9c75485c0bc33179ed2bc848d80e5facb337a38f537de28bb749fe79f17f561`) now installs a complete Fortify presentation record, adds the product to `cells[cell].fortify`, advances and restores `value_revision` while retaining the topology-only `render_revision`, requires one active canonical render region, chooses a center within screen bounds x=240-1040/y=180-500, and compares active-versus-removed plain frames before any cover canary. The 49 x 49 surface crop must change by at least 16 pixels; the two canary pairs then retain hidden-active and visible-removed behavior. The original cell record, revision values, product absence, collision occluder set and exact world state hash must be restored twice. This corrected helper is `ROOT_PENDING` / `NOT_RUN` as of this audit update; expected success is 31 canary cases plus the surface oracle, 165 assertions and zero failures.

## Final integration-owner results (supersede pending entries above)

Root executed the corrected helper on frozen source and exact exported PCK
`p55-ede24ea44158`: `hex-terrain-v2` and `hex-terrain-pack-v1` each pass 31 canary
cases plus the cover-surface oracle, 165 assertions, zero failures/stderr. Active
versus removed Fortify changes 1,538 pixels in the 49x49 surface crop; source and
PCK crop hashes match. Active hidden crops change zero pixels; removed controls
change 225. Root and independent image review confirmed actual raised cover versus
bare paving. The preliminary v1 result remains narrowed as described above.

The final four-case native stress diagnostic completed 7,991 correctness assertions
with zero failures, 360 frames and 720 authority ticks per case. All 1,440 measured
frames miss 16.667 ms. Distributed normal/reduced frame p95 is 307.768/280.316 ms;
dense normal/reduced is 184.772/182.184 ms. Dense two-tick simulation p95 is
153.920/155.262 ms. This verifies workload consistency, not capacity or a speedup.
No matched old-source rendered baseline was measured. The stateless snapshot
validation optimization remains proposed and unimplemented. Detailed timings,
limitations, package/Loom/lifecycle evidence and retained log paths are in HANDOFF.md
and evidence-map.json; those are the integration-owner ledger, not this worker's
independent execution claims.

# Expanded Wellspring layout evidence

Status: **implemented and locally qualified in p60-6d80c3bce71e, October 9, 2026.**
The [final integration record](../element-expansion-evidence-20261009/integration.md)
links the passed Full/native/package gates. Native map images inspect arrivals,
menus, map pages, garden phases and paid-ground overlaps; they do not establish human wayfinding or full district art acceptance.

Date: 2026-10-09. Scope: map JSON, content validator, exact preservation and route tests, native Bootstrap journey. No simulation movement tuning, resource recovery, networking or paid-spell limits changed in this slice.

## Established examples and transfer limits

- [Respawn / EA, Arsenal season game updates](https://www.ea.com/technology/news/arsenal-season-game-updates) describes a redesigned Apex Firing Range organized around a core, agility course, duel pit and combat town. The relevant shipped technique is purpose-specific spaces with deliberate flow between them. Wellspring keeps its services and target court, then adds distinguishable movement and cover districts. This is developer design intent and a shipped reference, not a controlled study proving the H.E.X. dimensions or learning outcome.
- [Respawn controls interview, Getting Titanfall’s controls just right](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right) discusses iteration on wall running, initiating and teaching it, and chaining speed through movement. Wellspring exposes actual runnable lower wall faces, real corners and optional narrow contact routes beside ordinary walking loops. No Titanfall timing, velocity or geometry ratio is asserted to transfer directly to this top-down game.
- [ArenaNet, Explore the World of Guild Wars 2](https://www.guildwars2.com/en/news/explore-the-world-of-guild-wars-2/) presents map points of interest, waypoints and optional vista approaches as ways to navigate and explore. H.E.X. uses a named, bounded thirteen-stop directory plus a map. Guild Wars 2 requires discovery and charges for waypoints; H.E.X.’s free, initially available offline sandbox destinations are an explicit project choice, not behavior attributed to that reference.

The reference-supported decisions are separation by purpose, readable named landmarks, optional movement challenges with ordinary routes, and explicit map destinations. Exact scale, spacing, corridor widths and labels are authored H.E.X. hypotheses. Passing geometry or native tests does not establish balance, enjoyable traversal, human wayfinding or stable frame time.

## Concrete authored contract

The canvas grows from 3072×2688 to 6144×5376, exactly four times the area. Expansion is east and south. The former campus remains an exact content prefix: all three district boundaries, twenty routes, ten bridges, twenty-five buildings, thirteen activities, six landmarks, twelve station IDs and positions, four target actors, spawn, resets and duel definitions remain unchanged. Two extra core arrival forecourts are metadata only.

| District | Environment | Bounds in pixels | Practice role |
| --- | --- | --- | --- |
| Tideglass Quays | coast | 3136,128 · 2944×2464 | Long shore approaches and optional wall contacts |
| Verdant Reaches | grove | 64,2720 · 1984×2560 | Long sprint/slide loops and a broad return |
| Basalt Foundry | foundry | 2112,2720 · 1984×2560 | Perpendicular real cover, sightline breaks and exits |
| Starward Terraces | observatory | 4160,2720 · 1920×2560 | Broad approaches, short wall contacts and clear retreat |

Each district adds six solid runnable practice walls, two 192px ordinary routes and one 64px optional advanced route. Seven 192px bridges form additional inter-district connections. The four landmark anchors are flat decorative references on clear ground; they add no hidden collision or healing. Existing environments’ names do not imply new resource or damage rules.

`SanctumCampusLayout.travel_destinations()` returns deep copies of thirteen `{id,label,detail,position:[pixel_x,pixel_y],area_id}` rows. `travel_destination(id)` returns one deep copy or an empty object. Validation requires a unique bounded directory, an existing containing activity and 40px collision clearance. Four `movement_courses` identify actual wall IDs, contact coordinates, lower-face normals and tangents. Validation rejects invented or misplaced contact geometry. The root navigation controller revalidates live collision and occupants at travel time; published metadata alone is not travel authority.

Current ownership is explicit in the [authored campus](../../content/maps/sanctum_campus_g2_v1.json), [layout loader](../../src/content/sanctum_campus_layout.gd), [preservation and route suite](../../tests/unit/test_sanctum_campus_layout.gd), and [native journey](../../tests/visual/capture_wellspring_expansion.gd). The [navigation controller](../../src/app/local_navigation_controller.gd) opens Menu through Esc, controller Back or its single pointer button; M opens World map. F4 opens Compendium, whose M/L3 Map action remains available. Gameplay Start remains emote. The thirteen arrivals are offline free-exploration conveniences, preserving resources, spell cooldowns and the weave; they are not checkpoint resets.

## Independent measurements and acceptance

The exact pre-expansion JSON is pinned at `tests/fixtures/campus_before_expeditions_20261009.json`, SHA-256 `ec13a6ad81a57625584f217a3fe3c8e070b25ba5705ffcbbcf77f1229bea33ec`. The layout suite projects only the explicitly added records away and compares the entire original object canonically. Historical earlier expansion hashes remain checked too.

An independent Python integer-polygon/SAT enumeration recorded 13,598 eligible cells before expansion and 59,466 afterward; new axial bounds are q −128…252, r 7…257. Root’s native topology result agrees with 59,466. The preserved script is `.godot/campus-expansion-baseline/movement/count_topology.py`. Root raised the finite cell and coordinate limits to accommodate this geometry while retaining active cast/product caps; this document makes no runtime performance claim from that change.

The layout tests traverse all new route/bridge envelopes at 4px spacing, require their full promised half-width clearance including endpoints, and pass every small segment through the actual collision mover. They independently pin all thirteen arrivals, check copy isolation and unsafe input refusal, and use actual MovementSystem admission to acquire each new real wall face, charge the existing 18,000 Stamina entry, grant no protection and expire without fresh input.

`.godot/wellspring-expansion-focus-v4/engine.log` records `sanctum-campus-layout` at 40,241 assertions/zero failures, `local-navigation` at 183/zero and `wellspring-map` at 895/zero; all seven selected suites passed and stderr is empty. This remains focused evidence. The earlier v3 run retained three stale assertion failures and 468 bytes of malformed-JSON stderr. The loader's quiet parser now refuses the invalid file without emitting engine errors; failure/reload checks remain in place. Earlier failed logs are preserved in their original directories; [map evidence](map-overview.md#coverage-and-remaining-gates) lists the complete seven-suite result.

`tests/visual/capture_wellspring_expansion.gd` uses the real Bootstrap Menu to World map flow. The final v7 journey visits all thirteen destinations at 1280x720 and 960x540 with keyboard, controller and pointer confirmation, checks unchanged resources/weave/cooldowns, actual clearance, camera reset, ordinary walking and saved bytes, and records 42 images including 16 garden frames and 2 paid-ground overlap views. These scripted checks do not establish human wayfinding, physical-device acceptance or full district traversal.
Those images sample arrivals, menus and maps; they do not inspect every landmark or fully traverse each district. Final-source v3 passed and its pixels exactly match the individually reviewed v2 set, as recorded below.


## Cross-review findings

The combat reviewer verified original prefix preservation, real wall geometry, route width checks and publication only after complete validation. They found that a previously admitted loader could retain its directory after a missing or malformed reload. The repaired loader clears its content hash and both published travel caches before file admission; regressions cover both failure modes after first publishing the real twelve entries.

The map-menu reviewer found no concrete static blocker in the native journey’s final production input path and twenty-two-image plan. Its map spacing assertion concerns waypoint numbers; the dedicated map suite separately checks the larger full-pin envelope. Root’s executed navigation and map suites passed before the final loader hardening; this document does not promote static review to native visual acceptance.

The reciprocal renderer review found the previous 512px single-wall compositor bound rejected the new 640–832px spans. The renderer now admits edges up to 1024px while retaining the 3 MiB total practice-wall cache cap; subsequent cache/footprint checks and sampled native review passed. The terrain region and backdrop review otherwise found no concrete blocker in global UV/cell continuity, bounded cache residency or stale-origin revision gating.

## Final follow-up boundaries

Map v2 subsequently completed 5,531 checkpoints, 1,656 ordinary simulation steps and 22 individually reviewed images. Its first attempt failed in the harness's untyped `Array` call to `SimWorld.step(Array[SimCommand])`; the repair typed those commands and changed no map authority. The images cover menus, map pages and sampled arrivals, not every landmark or full district traversals.

The final source adds a compact measured introduction, a 520px Range height cap, and a region-local terrain candidate filter without changing authored collision, travel positions or layout data. `.godot/wellspring-final-ux-focus-v1/engine.log` passed UI checks at 34,833 assertions and terrain checks at 260,234, with zero stderr. Its aggregate failed three assertions from a mistaken architecture fixture candidate. That candidate was withdrawn; the exact original architecture suite passed 133 assertions with zero stderr in `.godot/wellspring-architecture-original-v1/`. This preserved correction history is not a Full pass. [Environment evidence](environment.md#compact-ui-and-cold-region-follow-up) describes the independent sampler equivalence checks.

Teaching v5's reviewed 24 images precede the smaller cards. Teaching v6 passed 125 checkpoints/1,516 steps, with nine changed images individually inspected and fifteen matching reviewed v5 pixels. Map v3 passed 5,531 checkpoints/1,656 steps and all 22 images match individually reviewed v2 pixels. Camera v3 passed 44 checks and its six images match previously reviewed pixels. The [final native receipt](../element-expansion-evidence-20261009/native/pre-garden-review.json) verifies 76 images and 141 source hashes for `p60-6bf50929aa6c`, including retained wallrun/delivery images. These results establish neither human wayfinding, complete district exploration nor sustained frame performance.

The [terrain comparison](terrain-optimization-comparison.json) measures eight first-arrival normal views per journey: mean settling interval fell from 2,449.625ms before to 737.75ms after, 69.9% lower; eight subsequent cached views averaged 94.625ms after. Each sample includes four frames plus forced draw/readback. These sequential local observations do not measure FPS or isolate a Reduced Effects benefit. The unchanged 22 native images and independent sampler tests support preservation of the sampled appearance; they do not prove every landmark or walking route. Full and portable qualification passed; the final integration record links their separate receipts.


## Element Garden follow-up and current gates

[garden focused v2](garden-focused-v2.json) passed four suites / **112,746 assertions**, with zero failures and zero stderr (66,360 exhibition, 993 map, 2,643 illustrated kit and 42,750 layout).

[Element Garden](element-garden.md) adds 63 physical plots in Tideglass, ordered
by ingredient count and stable mask. Six plots alternate raw deposits with their
two-source self reaction; the other 57 show mixed reactions. Across those cycles
the garden presents six raw materials and all 63 recipe identities. Its bounded
61-cell courts use actual material and lifecycle rendering without exposing live
actors to exhibit damage. All visible plots are admitted; at most 63 courts
contain 3,843 cells. Real paid ground is drawn above harmless exhibit pads.

The thirteenth destination, `element-garden`, arrives at (4880,720). Its location
label uses the 288×288 forecourt at (4736,576); the full plot directory still
covers Tideglass. The 288px plot lattice preserves 160px clearance from existing
walls and at least 72px between pad outlines. All previous geometry and travel
records remain exact; the new forecourt contributes the twenty-fourth activity
and the thirty-fourth floor label. No resources, cooldowns or weave are reset.

The [Full v3 interrupted receipt](../element-expansion-evidence-20261009/full-v3-interrupted.json)
records 79 completed suites and zero stderr but no completed Full receipt.
The final native inventory passed: **96 images**, including 42 map/region/garden images (16 garden frames, including 2 real paid-ground overlap views), 24 teaching, six camera, eight wallrun and sixteen delivery images. Full v6 passed all **237 registered suites**; native review and exact portable verification passed separately.

The historical 69.9% reduction in cold arrival capture intervals belongs to
the **pre-garden 22-image** comparison. It neither benchmarks exhibition updates
nor certifies final garden frame time; each sample included four frames and
forced draw/readback. Keep it separate from the forthcoming garden capture.

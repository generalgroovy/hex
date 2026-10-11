# Bootstrap draw component instrumentation handoff

## Conclusion and scope

The current native profile proves that CPU time spent synchronously inside inherited `Bootstrap._draw()` is large, but it does not attribute that time. Its four `bootstrap_draw_submission_us` p95 values are 175,535, 169,419, 109,859, and 108,949 microseconds (`rendered-v1.out:4-7`). The timer is the interval around `super._draw()` in `RenderHarness._draw()` (`tests/performance/profile_unified_wellspring_rendered.gd:21-29`); it measures CanvasItem command preparation/submission on the main thread, not later GPU execution (`:98`).

A bounded follow-up can instrument the unchanged inherited draw through typed test-only subclasses and narrow Bootstrap helper overrides. The concrete `tests/support/hex_draw_component_harness.gd` now implements eight pairwise-disjoint buckets without copying `Bootstrap._draw()`. Seven can contain work in the whole-Hex fixture; `legacy_chemistry` is expected to be an almost-empty control because `_draw_element_chemistry()` returns immediately when `world.hex_court != null` (`src/app/bootstrap.gd:3713-3717`). The frozen tick-160 diagnostic should complement the 720-tick stress profile. It cannot replace the stress distribution or establish an optimization.

## Current call boundaries

`Bootstrap._draw()` submits work in a fixed synchronous order (`src/app/bootstrap.gd:1148-1314`). The following selected buckets do not contain one another in the current source:

| Bucket | Exact intercepted call | What it includes | What it deliberately excludes |
|---|---|---|---|
| `campus` | `SanctumCampusRenderer.draw(CanvasItem, SanctumCampusLayout, int, Vector2, bool, bool) -> void` (`sanctum_campus_renderer.gd:62-69`), called at `bootstrap.gd:1160-1161` | Ground texture plus campus activity areas, arena, buildings, landmarks, stations, and district labels (`:70-84`) | Static backdrop's separate `TerrainCanvas._draw`; actor contacts/shadows; all Hex material drawing |
| `hex_ground` | `HexCourtPresenter.draw_ground(CanvasItem, RefCounted, float, bool, bool) -> bool` (`hex_court_presenter.gd:109-147`), called at `bootstrap.gd:1162-1163` | The expensive court `view` pass over `_cells`, render-region collection, cover-region preparation, district base, all ingredient/product material submission, and rim | Later cover repaint in POV; projectiles; cue drawing |
| `actor_bodies` | `CartoonChampionPresenter.draw(CanvasItem, PlayerState, String, Vector2, float, SimConfig, bool, Vector2, float) -> bool` (`cartoon_champion_presenter.gd:681-712`) | Sprite frame selection, movement accents/afterimages, aura, body texture, evasion contour for every visible local or remote champion call | Jump/landing sampling, natural contact, receiving shadow, fallback circles, labels/health bars, startup spell, observer repaint; these remain residual |
| `hud` | `CompactCombatHud.draw(CanvasItem, Vector2, PlayerState, AbilityCatalog, String, String, String, String, int, int, bool, Vector2i, String, Vector2, String) -> void` (`compact_combat_hud.gd:77-93`), called at `bootstrap.gd:1261-1281` | Entire compact HUD, including its `champion_art.portrait_frame()` lookup | Station notice, practice coach, debug/editor/playground/specimen/compendium/gallery UI |
| `pov_mask` | Bootstrap helper `_draw_pov_mask(Vector2, Vector2, Vector2) -> void` (`bootstrap.gd:3118-3163`), called at `:1241-1244` | Occluder polygon construction, solid replacement, range feather, shadow regions, `_draw_pov_terrain`, and `draw_cover_surfaces` | Observer-body repaint immediately after it |
| `projectiles` | Bootstrap helper `_draw_projectile(ProjectileState, Vector2, Color, float) -> void` (`bootstrap.gd:3778-3791`), called once per `world.projectiles` entry at `:1177-1180` | The selected Hex, burst, foundation, or fallback projectile path for each projectile | The interpolation/color setup just before the helper and field loop just before projectiles |
| `combat_cues` | Bootstrap helper `_draw_combat_cues(Vector2) -> void` (`bootstrap.gd:1634-1690`), called at `:1182` | Interception feedback, visibility callback work, Hex/foundation cue presentation, labels, and fallback beam/spray/ring primitives | Cue update/ingest performed outside drawing |
| `legacy_chemistry` | Bootstrap helper `_draw_element_chemistry(float, Vector2) -> void` (`bootstrap.gd:3713-3727`), called at `:1176` | Legacy deposit/reaction preparation and submission only when there is no Hex court | Whole-Hex ground/material work; for the proposed fixtures it records only entry/guards |

These buckets may be summed for one draw because no selected wrapper runs inside another selected wrapper. In particular:

- `pov_mask` contains `HexCourtPresenter.draw_cover_surfaces()`, but `TimedGround` overrides only `draw_ground()`. There is no `hex_ground` overlap.
- `combat_cues` contains `HexCourtPresenter.draw_cue()` and foundation presenter calls, but none has another selected timer.
- `projectiles` wraps the Bootstrap helper; it calls `HexCourtPresenter.draw_projectile()`, not `draw_ground()`.
- `actor_bodies` sees `CartoonChampionPresenter.draw()` calls only. The HUD calls `portrait_frame()` (`compact_combat_hud.gd:314-320`), and the POV observer path calls `movement_frame()` before repainting (`bootstrap.gd:3228-3245`), so neither is counted as an actor body.

Do not add `_draw_remote_travellers()` to the additive set while `actor_bodies` is selected: the remote helper contains the remote champion `draw()` calls (`bootstrap.gd:1693-1752`) and would double count them. Likewise, do not add `draw_cover_surfaces`, `draw_cue`, or presenter-level projectile timers to the sum unless their enclosing bucket is removed. Nested timers may be useful separately, but must be labelled non-additive.

## Concrete harness review

The current test-only harness preserves all production method signatures and return values, calls `super` exactly once, and changes only timing-accounting state:

- `TimedCampus.draw`, `TimedGround.draw_ground`, `TimedActors.draw`, and `TimedHud.draw` match the typed production signatures (`tests/support/hex_draw_component_harness.gd:22-50`). Boolean results from ground and actor drawing are returned unchanged.
- `_draw_pov_mask`, `_draw_projectile`, `_draw_combat_cues`, and `_draw_element_chemistry` match the Bootstrap helper signatures and call the inherited implementations once (`:94-112`).
- The inherited complete draw is retained. The harness clears counters, activates them immediately before `super._draw()`, disables them immediately afterward, and records the same outer interval as the existing profile (`:84-92`).
- Presenter samples require both `counters.active` and the owning Bootstrap canvas instance ID (`:6-20`). This excludes calls made on another canvas. The static `PovTerrainBackdrop` is `UPDATE_ONCE` and owns a separate `TerrainCanvas` (`pov_terrain_backdrop.gd:6-25`); the concrete harness also intentionally leaves that backdrop bound to the original campus renderer (`hex_draw_component_harness.gd:57-65`). Its callback therefore cannot enter the `campus` bucket.

One setup requirement is material: `configure_fixture(true)` prepares champion pages on its original `CartoonChampionPresenter` (`chemistry_coach_harness.gd:78-94`), then `install_timers()` replaces that object with a fresh `TimedActors` (`hex_draw_component_harness.gd:71-81`). The concrete runner correctly rebuilds the eight identities from the frozen world's actors and calls `prepare_override_pages()` on the replacement before capture (`profile_hex_draw_components.gd:101-110`). It does not rely on the replaced presenter's readiness or Bootstrap's prior preparation key.

Call `install_timers()` exactly once per fresh harness. It reconfigures fresh presenter instances, so repeated installation would reset presentation caches and would no longer be the same draw history. The old campus renderer remains owned by the static backdrop by design; the new campus renderer is configured from the same `visual_language` and `campus_layout`. Exact reference pixels below are the acceptance test for this split.

## Additive accounting and residual

For each draw, define:

```text
selected_us = campus + hex_ground + actor_bodies + hud
            + pov_mask + projectiles + combat_cues + legacy_chemistry
residual_us = total_draw_us - selected_us
```

The residual is not a new component and must not be interpreted as one. It contains all unwrapped work in `Bootstrap._draw()`: frame setup and transforms, `PixelMagicLibrary.begin_frame`, movement trace, debug obstacles, fields, projectile interpolation/color setup, practice targets, local/remote actor work outside the champion presenter, social/station UI, POV observer repaint, aim reticle, station notice, coach/editor/overlay panels, branch checks, and direct CanvasItem submissions. It also contains measurement overhead because each wrapper's `start` and `finish` calls and dictionary writes occur inside the outer timer but outside the component duration computed at `Counters.finish()` (`hex_draw_component_harness.gd:12-20`). A small negative residual is therefore a harness defect or timer-resolution/accounting failure; a positive residual is expected.

`HexCourtPresenter.draw_ground()` is intentionally one component. Its source interleaves trusted court `view` calls, region/material preparation, cache updates, and CanvasItem submission (`hex_court_presenter.gd:109-147`). This wrapper can attribute cost to whole-Hex ground/material handling, but cannot separate preparation from submission. Any later split needs a separate test-only seam with an equivalence oracle; timings alone cannot justify an optimization.

Callbacks are part of the component that synchronously invokes them. `draw_ground()` uses `court.call("view", ...)` per cell (`hex_court_presenter.gd:116-120`), and combat feedback receives `_pov_point_visible` as a callable (`bootstrap.gd:1634-1637`). Their elapsed work is correctly included in `hex_ground` and `combat_cues`. Work performed later by RenderingServer, the display driver, or the static SubViewport is outside these synchronous buckets and outside `total_draw_us`; the existing `_present()` interval through `RenderingServer.frame_post_draw` remains the broader render-completion observation (`profile_unified_wellspring_rendered.gd:336-341`).

## Minimal frozen-frame diagnostic

The concrete `tests/performance/profile_hex_draw_components.gd` uses the two legal eight-actor fixtures frozen at tick 160, once in normal and once in reduced mode. It retains the 120 neutral plus 40 paid command ticks used to construct each state, then advances no simulation during drawing (`:42-54`). For each fixture/mode it executes three visual-control arms:

1. Original `BootstrapHarness` control with no timed subclasses.
2. Component harness after `install_timers()`, with `timing_enabled = false`.
3. The same component harness after enabling its counters.

The original-versus-disabled comparison detects subclass reconfiguration or wrapper drift. Disabled-versus-enabled detects pixel drift from timing. The current runner does not collect an original or disabled outer-time distribution, so these controls do not quantify timing perturbation; the receipt states only that instrumentation may perturb timing (`profile_hex_draw_components.gd:61-68`). It performs four reference warmups per arm and 32 enabled frozen samples per fixture/mode (`:7-9,125-183`). `draw_ground()` maintains court revision/cell/cover caches (`hex_court_presenter.gd:86-93,109-130`) and projectile drawing maintains a size cache (`:92,202-223`), so this is a warmed repeated-draw result. It is not a sample of the evolving 720-tick workload and must not be described as its p95 decomposition.

The runner fixes an expected world hash before drawing, checks it after every reference control arm and after every one of the 32 measured draws, and performs those checks outside all timers (`profile_hex_draw_components.gd:128-150,155-183`). It also records fixture identity, tick, actor count, Hex cell/occupancy summary, visual mode, 1280x720 viewport, paid metrics, and source hashes. This proves authority immutability for the explicitly hashed world at every checked boundary; it does not claim presenter caches are immutable.

After `RenderingServer.frame_post_draw`, the runner captures the same full native viewport and requires `Image.FORMAT_RGBA8`, identical dimensions/format/data for original versus disabled and disabled versus enabled, then records SHA-256 of the raw RGBA8 bytes (`profile_hex_draw_components.gd:125-150,184,191-202`). Pixel checks run outside all component and outer timers. It also requires exactly one requested draw per observation and these structural counter checks for enabled draws:

- exactly one `campus`, `hex_ground`, `hud`, `pov_mask`, `combat_cues`, and `legacy_chemistry` call;
- `legacy_chemistry` remains the guard-only path for a non-null Hex court;
- `projectiles` equals the frozen `world.projectiles.size()` (`profile_hex_draw_components.gd:172`);
- `actor_bodies` equals the number of visible champion presenter calls, recorded along with the fixture's actor/visibility facts rather than assumed to equal eight.

The testable hypothesis is narrow: one or more selected buckets accounts for a stable, material fraction of `total_draw_us` across repeated pixel-equivalent draws, with `hex_ground` the source-backed candidate because it scans every prepared court cell and builds all material views/regions every draw. Accept the diagnostic only if the component sum is arithmetically consistent and all reference pixels, call counts, and authority hashes are exact. A dominant bucket identifies where a later optimization investigation should start; it does not prove why the cost occurs. Because only enabled timing is sampled, this v1 result cannot claim that bucket magnitudes or ranking are unchanged by instrumentation.

## Static review of the concrete runner and first failed attempt

The two test-only files are internally consistent with the source audit as currently written. The initial review was static and explicitly did not prove script/runtime acceptance. Root subsequently ran the first engine attempt; it failed before any component samples when Godot rejected a ternary expression of untyped `Array` as an assignment to `Array[String]` at the then-current runner line 51. The exact stderr is preserved in `docs/verification/hex-hash-20260923/draw-components-v1.out`, the attempted sources are in `failed-draw-v1/`, and the owned PID record is `draw-components-v1-termination.json`. That attempt produced no valid receipt and is not draw-performance evidence.

The only ensuing runner repair replaces the rejected ternary with the typed literal `var modes: Array[String] = ["normal", "reduced"]` and reverses it for `dense-crucible` (`profile_hex_draw_components.gd:51-55`). This preserves the intended balanced order: sustained runs normal then reduced, dense runs reduced then normal. Static reinspection found no new component-boundary or workload change. A repaired v2 engine result remained `NOT_RUN` at the time of this handoff; root alone owns that execution.

- All eight wrapper/helper signatures match the current typed production methods, all non-void results are preserved, and no production `_draw` body is copied.
- The runner fails before work if the output receipt is not fresh/scoped, the backend is headless, the viewport is not 1280x720, production content/topology fails validation, or the capture directory already exists/cannot be created (`profile_hex_draw_components.gd:17-40`). Existing captures therefore are not overwritten.
- A failed original or timed harness configuration is checked and cleaned up before show/capture/timing (`:112-123`). The new timed champion presenter is prepared after installation (`:101-110`).
- All saved reference images must be RGBA8, all two pairwise full-frame byte comparisons must pass, and authority is checked after each arm and measured draw (`:125-150,173`).
- Every enabled row asserts a non-negative residual; one call for each fixed top-level bucket; at least one champion body; and exactly one projectile helper call per frozen projectile (`:155-178`). Each component and total series must contain exactly 32 samples (`:179-182`).
- The receipt explicitly distinguishes synchronous CPU submission, non-additive render completion, residual overhead, frozen diagnostic scope, and lack of GPU/optimization claims (`:61-68`). Source hashes include the runner, both harnesses, Bootstrap, the four wrapped presenters, the backdrop, and illustrated campus kit (`:58-60`).

No remaining static blocker was found in the repaired two test files. The first execution is `FAILED` before measurement; native frame capture, exact pixels, and measured component timings remain `NOT_RUN` until root executes the repaired diagnostic.

## Remaining gaps

- The frozen diagnostic does not reproduce the stress profile's 360 evolving measured frames, event density distribution, cache history, or p95. Retain `rendered-v1.out` as the stress observation and label the new result as component attribution at tick 160.
- Synchronous CanvasItem timing cannot attribute GPU/driver execution. Keep outer `queue_redraw` through `frame_post_draw` elapsed time and render counters separate from component CPU submission.
- Microsecond timestamps, dictionary updates, wrapper dispatch, and fresh presenter configuration can perturb short components. The visual controls catch pixel drift but do not bound timing perturbation because the runner samples only the enabled arm.
- The selected actor bucket is sprite-body work only. A large residual may still be actor-related because contacts, shadows, landing, labels, health bars, startup spells, and fallback primitives are inline in Bootstrap.
- An exact pixel match on this machine/backend establishes equivalence for the tested frames only. It does not establish human visual acceptance, capacity, or other hardware behavior.

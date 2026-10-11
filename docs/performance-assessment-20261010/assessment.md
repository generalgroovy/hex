# H.E.X. performance assessment — October 10, 2026

Status: historical pre-optimization diagnosis. Implementation and current qualification are tracked in [the performance implementation report](../performance-implementation-20261010.md). The measurements below describe the preserved original source/portable, not the optimized candidate. Three agents independently audited simulation, rendering and reference-game engineering; the simulation and rendering agents cross-checked one another. The root agent ran all engine diagnostics serially on the user's PC with isolated saves.

**The reported lag is reproducible. The strongest measured problem near the Element Garden is preparing and drawing its material effects. Ordinary scenes are also too slow, and paid casting adds work even with no Garden plots visible.** The graphics looking simpler than League does not make H.E.X.'s implementation cheaper. The remedy is to change the amount and representation of repeated work, then qualify the actual portable against a frame-time budget.

## Current identity and hardware

- Production identity: `p60-6d80c3bce71e`, protocol 60, source digest `6d80c3bce71e9d7eb0fe9246f5f440d304da77f779edfc4054a965732b806e61`, 3,240 canonical runtime records. Rechecked during this assessment.
- Portable: `exports/hex-element-expansion-20261009/windows/hex.exe` and its adjacent original `hex.pck`. Package files were not changed.
- ASUS Vivobook Go 15 E1504FAF, Ryzen 3 7320U, four physical cores/eight logical processors, Windows 11 Home, 7.28 GiB usable RAM. Windows reports AMD Radeon Graphics, driver `32.0.21045.5002`, desktop 1920×1080 at 60 Hz.
- Free physical memory fluctuated from about 0.76 GiB to 1.2 GiB during initial checks; paging counters were nonzero at sampled instants. This can amplify stalls but does not establish memory pressure as their cause. No apps were closed and no driver, power-plan or system settings were changed.
- The game uses Godot 4.7.1 Compatibility through ANGLE/D3D11 on this PC. It already uses sprite atlases, cached meshes, sparse authoritative chemistry and spatial projectile queries. An engine rewrite is not the first justified action.

See [hardware observation](hardware.json) and [portable hashes](portable-hashes.json). The user's League performance is their observation; this assessment did not launch or independently benchmark League.

## Measurements and their limits

Two native diagnostics used the current production source at 1280×720, 75% camera zoom, fullbody/pixel-cast art, ordinary fixed-step main loop, isolated preferences and no LAN discovery. The first was unfocused; the second requested focus and reported focus true at every case endpoint. Both ran with the debug engine, so their absolute times are diagnostic, not release certification. The original portable was then run separately with its own engine FPS reporting.

The focused run's monotonic process-start intervals and main-thread draw/submission timers were:

| Scenario | Frame-interval samples | Mean interval | Mean total draw/submission | Mean Garden draw/submission | Actual simulation ticks per real second |
|---|---:|---:|---:|---:|---:|
| Starting area, idle | 132 | 60.4 ms | 18.1 ms | <0.01 ms | 116.1 |
| Garden entry, 28 resident plots | 9 | 866.1 ms | 500.4 ms | 476.7 ms | 9.3 |
| Garden middle, 29 resident plots | 9 | 800.9 ms | 509.0 ms | 485.3 ms | 9.5 |
| Garden middle, reduced effects | 14 | 551.6 ms | 381.5 ms | 357.7 ms | 14.3 |
| Diagnostic only: omit Garden ground drawing, retain its simulation | 115 | 69.0 ms | 21.6 ms | omitted | 113.5 |
| Diagnostic only: omit Garden drawing and maintenance | 121 | 65.8 ms | 22.5 ms | omitted | 114.2 |
| Paid Fire Bolt attempts every 120 ticks, zero Garden plots | 126 | 94.7 ms | 29.6 ms | <0.01 ms | 81.9 |
| Follow-up paid all-six Mantle attempts, zero Garden plots | 103 | 115.5 ms | 46.1 ms | <0.01 ms | 67.7 |

These are short sequential samples, not randomized paired trials. The Garden phases evolve between cases; the reduced-effects case was worse in the first run and better in the second. Neither establishes its precise improvement. Both show that the existing setting does not solve the bottleneck. The omission cases are attribution experiments, not proposed gameplay that hides the exhibits.

The focused Fire case paid 5,400 matter across nine attempts, reached three simultaneous projectiles and 29 occupied paid cells. The following Mantle case paid another 2,400, reached 62 occupied cells, and retained up to two prior projectiles. It therefore represents a real sequence of paid casts with finite resources and possible residual Fire, not an isolated cost measurement of the six-element recipe. The first run's casting scene still had four Garden plots; use the corrected focused run for the zero-Garden comparison.

The Garden-entry draw components averaged **7.54 ms for geometry preparation, 119.63 ms for frame/material preparation, and 178.11 ms inside material-surface drawing**. These sit within the 476.7 ms Garden total. The remaining approximately 171.4 ms covers other drawing, marks, outlines, descriptors, labels and call overhead. Geometry cache thrashing is real, but fixing only those 7.54 ms cannot cure the whole scene. Garden maintenance averaged 0.519 ms per simulation step in that case. In the drawing-omitted case, periodic lifecycle restarts still produced maintenance spikes up to 51.5 ms; secondary work also needs bounding.

Important measurement rules:

- The JSON fields ending in `cpu_ms` are elapsed time around main-thread functions, not operating-system CPU-cycle measurements or GPU timing. They can include scheduling and driver waits. Nested categories must not be added together.
- Process-start intervals are not physical presentation timestamps or input-to-photon latency. Instrumentation itself adds work, including occupied-cell observation and sample storage.
- Nine Garden intervals cannot support stable p99 or p99.9 claims. Raw percentiles are preserved for reproducibility, not used for acceptance.
- The nominal 120 Hz setting is not achieved when frames stall. At 9.3 ticks per real second, authority advances only about 7.8% of real time. Godot can clamp delivered `_process(delta)` before H.E.X.'s own accumulator, so the game's existing dropped-time counter does not account for the full wall-time shortfall. Record ticks versus wall time as well as accumulator drops. [Godot process-delta contract](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-process)
- GPU execution, physical input latency, thermal behavior and long-session frame pacing remain unmeasured. The large-window terrain fallback is source-proven, not a fresh fullscreen benchmark.

### Unchanged portable check

The original executable does not expose external script/path overrides in its help. Instead it was launched from its own package directory with its original PCK, `--print-fps`, 1280×720, normal art flags and isolated saves. The Garden run uses the game's existing validated spawn fixture at `(4880,720)`. These engine FPS reports are one-second summaries, not individual frame-time traces. Startup is included and background applications remained running.

| Original portable scenario | Engine FPS range after the first three reports | Median reported FPS | Reports included | Total process wall time including startup |
|---|---:|---:|---:|---:|
| Starting area, idle | **14–16 FPS** | **15 FPS** | 19 | 45.68 s |
| Garden entry at `(4880,720)` | **1–2 FPS** | **2 FPS** | 15 | 40.90 s |

This confirms that the slowdown is present in the unchanged portable, not merely an artifact of the instrumented source harness. The three omitted initial reports are an explicit descriptive warm-up convention; every original FPS report remains in the receipt. Window focus was not controlled in this portable-only run. The separate focused diagnostic reproduces the same qualitative problem. These short runs do not establish a sustained frame-rate distribution.

See [portable results](portable-results.json), [starting-area log](portable-hearth.log), [Garden log](portable-garden.log) and [post-run identity check](portable-identity-after.json). Both original package hashes remained unchanged and matched their published checksums.

Raw evidence: [initial diagnostic](diagnostic-initial.json), [focused diagnostic](diagnostic-focused.json), [initial probe](diagnostic-initial.gd), [focused probe](diagnostic-focused.gd), and [original-portable runner](run-original-portable.ps1). The probes contain machine-local output paths; adapt those for another machine. They do not belong in the shipped runtime. An unused intermediate portable-script candidate was never run because the original executable's CLI does not support it.

## Why League can feel smooth while H.E.X. does not

League's client and H.E.X. offline do different work. Riot documents dedicated server authority, including much of the work for solo Swarm, while H.E.X. offline runs the complete combat authority locally alongside presentation. That does not mean League's client has no simulation. It means the user's PC is not running every part of the League match. [Riot, The Tech Behind Swarm, July 2025](https://www.riotgames.com/en/news/the-tech-behind-swarm)

League also deliberately separates visual richness from repeated CPU work. Its published graphics pipeline uses baked terrain/shadow information and prepared character assets; a detailed scene can therefore be cheap to submit repeatedly. H.E.X. redraws a large custom CanvasItem every frame and reconstructs many material records and commands. Godot's custom draw commands are retained until a redraw is requested; H.E.X. repeatedly requests one. [Riot graphics pipeline](https://www.riotgames.com/en/news/trip-down-lol-graphics-pipeline), [Godot custom drawing](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)

Riot itself has shipped deceptively small expensive effects: a speed-dependent Rakan trail cost excessive CPU time, while Swain's oversized outline bounds caused a large-screen blur. Fixing those representations retained the intended look. This directly supports preserving H.E.X.'s movement and chemistry while replacing redundant preparation and tightly bounding cosmetic geometry. [Riot real-world profiling](https://www.riotgames.com/en/news/profiling-real-world-performance-league)

Factorio provides an especially close ground-rendering precedent: cache terrain draw orders by chunk and animate from time parameters without rebuilding static geometry. Apex's developer explanation separates input, client rendering and server update responsibilities; it does not justify lowering local movement to its historical server frequency. Dead Cells demonstrates that convincing volume and animation can come from art prepared in 3D and displayed in 2D. The [comparative research appendix](comparative-research.md) connects these and other verified examples to concrete proposals, and distinguishes historical accounts from current requirements.

## Source findings and proposed changes, in order

### 1. Make dynamic material presentation compact and reusable

The current [frame preparation](../../src/presentation/hex_court_presenter.gd#L378) initializes 69 material maps and copies a 140-field default view for each occupied cell. It then builds, validates and converts region data. [Material-surface selection](../../src/presentation/hex_material_surface.gd#L162) and [material descriptors](../../src/presentation/hex_court_presenter.gd#L765) obtain fresh recipe definitions in repeated draw paths, despite an immutable `runtime_definition` facility already existing for simulation readers. Both readers only inspect these definitions. Reusing the compiled immutable contract in these two places is a narrow first candidate; measure its gain before expanding the refactor.

Propose an owned sparse render representation containing only present material, phase, quantity, danger and required display attributes. Share immutable recipe descriptors and cell geometry. Retain compatible public authoring/diagnostic accessors without reconstructing their full detached shapes for every draw. Batch surface instances by compatible texture/material and use cached meshes or buffers with time-based animation. Confirm the actual driver batching and GPU cost before choosing the batch layout; script draw calls are not the same as GPU draw calls.

Keep active threat borders, aim/contact readability, protection indicators, status identity, cover and expiry exact. Cache invalidation must cover quantity, remaining damage pool, intensity, provenance, phase boundaries and expiry. `render_revision` alone is a geometry revision and cannot guarantee correct danger state. This is the largest measured presentation target, supported by Riot's representation/batching examples and Factorio's retained terrain work.

### 2. Make the Garden inexpensive without removing its 63 combinations

The [Garden presenter](../../src/presentation/element_garden_presenter.gd) shares one ground presenter across courts, while its [geometry cache](../../src/presentation/hex_court_presenter.gd#L314) remembers only the last court. Retain small per-resident-court geometry caches inside the shared presenter; do not instantiate 63 complete art banks. Cache plaque text until its displayed content changes.

After the general renderer fixes, offer a stronger display-only representation: generate versioned lifecycle samples from the real chemistry model, or retain validated field geometry with clock-driven phase/animation data. All plots remain visible, named and accurate. The inspected plot can execute the full live demonstration; the Spell Range continues using the real authority for all combinations. Replayed exhibits must be identified honestly and invalidated when the rule version changes. Player spells in the Garden must remain real, paid and visibly above the harmless exhibit layer.

Schedule exhibit expiry/restart work across frames or a bounded preparation queue. Reducing maintenance frequency alone will not repair the measured drawing cost. No combat statuses, projectiles or enemy hazards should disappear to meet a cosmetic budget.

### 3. Remove synchronous world construction from interactive frames

[Terrain chunk misses](../../src/presentation/wellspring_illustrated_kit.gd#L482) compose images and upload textures during drawing. When a view spans more than 24 chunks, the fallback can synchronously compose all 132 world regions into a quarter-scale overview. The [POV backdrop](../../src/presentation/pov_terrain_backdrop.gd#L27) expands the visible area, so it can cross that threshold even when the main view does not. At a valid test origin and 75% zoom, a 1920×1080 main view spans 15 chunks but its backdrop spans 28.

Prebake exact static chunks and the map overview during asset preparation. Stream the next neighborhood before it is needed, with bounded main-thread texture upload. Keep ordinary ground rendering separate from whole-map overview generation. Fast travel should prepare the destination while a clear brief transition is shown, then resume control when essentials are ready. Preserve the large world and varied districts. Factorio's chunk-cache account and Riot's baked pipeline are direct precedents; neither predicts a numerical H.E.X. speedup.

### 4. Fix the ordinary-scene budget as well as dense effects

The starting area's measured 18.1 ms draw/submission average already exceeds an entire 60 FPS frame budget of 16.67 ms before all other work is considered. Split unchanged ground and interface layers from dynamic characters, fields and protection cues, allowing retained draw commands to survive. Reuse actor depth ordering once per frame; cache text layout until its inputs change. Audit the visibility/cutaway pass and its 96-segment range ring using actual CPU/GPU traces.

The main paid court currently prepares all occupied coverage, including offscreen cells. Cull only presentation preparation against the camera and full effect envelope. Keep offscreen authority and sight/cover semantics intact. This is not permission to cull unseen gameplay or expose occluded threats.

### 5. Introduce a genuine performance preset

A proposed Low preset should independently control render scale, decorative particles, material embellishment, glow area, ambient animation and trail density, with a measured global budget. Keep every damaging projectile, danger footprint, cast warning and invulnerability/intangibility cue readable. Bound trail segment count independently of speed, as in Riot's Rakan fix. A six-element spell needs one readable combined visual identity with selective motifs; it need not multiply every decorative layer by six.

Keep reduced-motion accessibility separate from performance quality. Lower resolution can help GPU work, but cannot remove repeated CPU dictionary construction, recipe creation or draw-list preparation. No existing preset is presently qualified as smooth.

### 6. Preserve movement timing first; optimize measured simulation second

Keep the current 120 Hz movement/collision contract during the first renderer changes. Interpolation already exists. If simulation remains too expensive, share sorted product/candidate work across actors, retain packed state and spatial queries, and eliminate demonstrated unused work such as `_owner_material_slots()` on the Hex branch. Avoid repeating per-target status objects when equivalent batches preserve exact source, damage and expiry semantics; Riot's Swarm is a relevant precedent.

Only then evaluate a properly redesigned 60 Hz authority option or selective lower-frequency cosmetic subsystems. Existing integer tick timings, cooldowns, movement chains, collision sweeps and network protocol need equivalent semantics. Raising the catch-up limit is not a cure; it can lengthen input stalls. Move remaining measured hot loops to a native extension only if representation and algorithm changes are insufficient.

Network publication is a separate hosting concern. Ordinary offline play does not capture/broadcast 60 Hz snapshots. Historical host measurements already show publication pressure, but optimizing it would not repair the Garden's offline renderer. Qualify offline, host and client workloads separately.

## Proposed acceptance contract

These are engineering targets for this PC, not achieved results or limits borrowed from another game.

| Gate | Requirement |
|---|---|
| Baseline | Actual release portable, this PC, 1280×720 Low, normal documented background load and power state; test 1920×1080 separately. |
| Warm frame budget | Target 60 FPS. CPU frame work and GPU execution independently below 13.3 ms at p99, leaving approximately 20% headroom. They overlap and should not be summed as a simple serial budget. |
| Frame pacing | Measure actual presentation intervals: 99.9% at or below 20 ms, with no reproducible game-caused frame above 33.3 ms in warm play. Report maximum and counts over 20/33.3/50/100 ms. |
| Simulation | Keep authority at its intended rate relative to wall time, without increasing latency through growing backlog or silently losing game time. |
| Required scenes | Idle Hearth, all Garden approaches and lifecycle restarts, sustained paid casting and legal high-load mixed effects, Range, movement chains across district boundaries, menus, cold launch and fast travel. |
| Correctness | Same damage, resource use, status windows, collision, projectile visibility, cover, teaching phases and paid-over-exhibit layering. Compare deterministic state and visual boundary cases. |
| Input | Measure engine event-to-authority and event-to-render response separately. Do not claim physical input-to-photon latency without appropriate measurement. |
| Endurance | Repeat fixed routes, then a 20–30 minute traversal/combat soak. Record memory growth, paging, clocks/power conditions, backlog and frame tails. |
| Release | Functional tests, screenshot gates, source identity and hashes remain necessary, but sustained frame-time evidence is an additional release gate. |

Create repeatable captures before each optimization, change one subsystem at a time, and stop expansion when the measured budget regresses. The immediate objective is a reproducible stable 60 FPS baseline on this PC with no repeatable gameplay hitches. No software change can guarantee that every frame remains perfect under every possible Windows/background workload.

## Evidence boundary and accountability

The previous millions of assertions, image checks, map validation and package identity established functional behavior. They did not establish sustained frame pacing. The Garden and larger world increased presentation workload without a matching performance acceptance gate. That gap should be fixed as part of development, not attributed to the user's hardware without measurement.

Production source and the portable were preserved. This assessment adds documentation, diagnostic scripts and receipts only. The next implementation should start with compact material presentation, Garden retained rendering and the ordinary-scene draw budget, then terrain preparation and measured simulation work. Keep the six ingredients, all 63 combinations, all spell forms, movement chains, distinct characters and the larger map unless a separately measured design tradeoff becomes necessary.

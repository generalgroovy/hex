# Presentation improvement checkpoint — October 11, 2026

**Paused at the user's request:** “pause and push at next best state.” This is a
source checkpoint on `codex/hex-screen-smoothness-20261011`, based on
`95ca630e20d11eb140405d45aed7c93636dfbdcb`. The runtime identity is
**p60-33606f016138**, with 3,392 canonical production records, protocol 60 and
snapshot schema 24. No new portable or binary release is qualified by this push.

The task was to improve flickering, screen coverage, low-spec smoothness,
projectile depth, audio and map detail using specialist implementation and
independent cross-review. Work stopped after completing the active edits and
checkpoint checks. The broader design and performance task is not declared done.

## Implemented and cross-reviewed

| Concern | Implemented change | Checks and independent review |
|---|---|---|
| Terrain flicker | Two bounded viewport buffers retain the completed texture and matching world rectangle until the next capture finishes. Proactive padding, cancellation of obsolete captures and explicit callback ownership cover direction changes and teardown. | Visibility owner; world/audio review found a stale-capture cancellation race, then corrected. Native moving-boundary fixture checks exact pixels. |
| Screen coverage | Sight derives from all inverse-projected viewport corners, including camera lead, wide windows and snapped canvas translation. Removed the redundant radial terrain-mask ring. Walls, solid hexes and chemical concealment retain their roles. | Root plus visibility owner; actual viewport, resize, wide-window, occlusion and zero-radial-mask regressions. |
| Camera and movement presentation | Camera advances after fixed-step catch-up using the same interpolated feet as drawing. Spectator focus uses interpolated motion too. | Visibility cross-review; catch-up and early world-transition regressions. No movement or payment retuning. |
| Projectiles and element identity | Fixed directional facet lighting, stable indexed topology, raised inner faces and contained ground shadows. Six reusable mixture-sector templates cover all 63 combinations. | Effects owner; root inspected native identity and phase sheets, owner independently inspected strength and reduced-effect sheets. New geometry remains inside existing visual contact bounds. |
| Sprite and hand presentation | Reused existing sprites; hand and Mantle glyphs use lightweight mixture layout, avoiding allocation of unused projectile meshes. | Visibility review caught the unnecessary geometry preparation. No new sprite atlas or animation overhaul is claimed. |
| Paid ground geometry | A 512-entry FIFO retains exact detached six-vertex polygons. Origin and render revision invalidate geometry; each live record still supplies its own owner, phase, quantity and expiry. Integer-owner edge-prefix lookup avoids repeated serialization. | Effects owner; visibility independently reviewed final FIFO and prefix changes. Frozen pre-change geometry/prefix oracles, eviction, revisit, mutation and authority-hash tests. |
| Map assets and readability | Retained, spatially culled meshes add brass astrolabes, shell/tide reliefs, copper vents, fern/flower clusters and Academy book crests. Route shoulders and destinations have distinct motifs. | World owner; effects review found cross-route intrusion and required all-route exclusions. Root rejected faint first-pass details and inspected the stronger pass. Clear route centers, building margins and arrival pockets remain bounded. |
| Sound | 48 cached cast/contact clips use distinct transients, bodies and tails, three variants per identity and quieter startup. Four fixed voices include a reserved contact voice; occupied voices are not stolen. No synthesis during gameplay. | World owner; bounded bank, voice ownership, clip diversity, amplitude, headroom and clean endpoint tests. Listening remains separate acceptance. |
| Integration and identity | Updated player-facing sight description, contracts, registered regressions and exact source identity. Profiling checks the actual rendered viewport and focuses only its own test window. | Root owned shared files and all serialized Godot jobs. Separate worktree preserves dirty user files and prior builds. |

The new floor layer is static: at most 132 patches, 60,000 vertices and 512 marks;
no clocks, particles, extra physics or per-frame triangulation. Reduced Effects
uses the same floor meshes. Floor placement avoids ordinary route centers by
24 world units, arrival centers by 88 and building bounds by 12. This adds visual
character without adding simulation entities.

## Validation

The exact executed checkpoint results are recorded in `checkpoint.json` and the
adjacent logs/receipts. Headless checks use isolated user data with Godot
`4.7.1.stable.official.a13da4feb`. Native checks use Compatibility/OpenGL on this
Ryzen 3 7320U / Radeon 610M Linux PC. A native image is evidence for its sampled
rendering, not physical input latency or an entire play session without flicker.

- Import and exact runtime-identity checks passed.
- The initial focused run passed **15 suites / 467,829 assertions** with no
  failures or engine errors.
- The complete runner executed **247 suites / 7,051,949 assertions** on frozen
  production. Its only failures were two obsolete assertions expecting the old
  720-unit cutoff in `solo-duel-world-tell`. That failed run is preserved.
- After that run, only the fixture changed: it now checks a witness beyond the
  old ground-metric radius, the visible rival's warning, and a point beyond the
  new finite radius. Existing wall, chemical reveal, interpolation and phase
  controls remain. Independent visibility review checked the correction.
- The corrected focused run passed **16 suites / 468,311 assertions**, including
  all 482 world-warning checks, with no failures or engine errors. Production
  remained **p60-33606f016138**. Together the runs cover all 247 suites and
  **7,051,951 final assertions** with zero remaining failures; this is a union
  of results, **not a second clean Full invocation**.

See [the failed complete run](logs/checkpoint-full.log) and
[the corrected focused run](logs/checkpoint-corrected-focused.log).

Native evidence includes 12 projectile sheets
covering identity, strength and phases at 100%/75% scale, normal/reduced modes;
and 1,274 backdrop checks across 64 motion frames, four handoffs and six terrain
draws. The procedural backdrop fixture deliberately isolates texture/rectangle
handoffs from the rest of the game. Its receipt does not qualify full-game art.

The final map/audio capture checks five locations in normal and Reduced Effects,
including images with the new floor layer disabled as a comparison. The full
capture sets and their source hashes are retained in
[`world-audio/`](world-audio/), [`projectiles/`](projectiles/) and
[`backdrop/`](backdrop/). These compare the added layer; they do not recreate the
entire old executable.

The final map/audio run passed **107 checks with zero failures and 15 frames**.
Its compiled floor layer contains **383 marks, 111 patches and 42,669 vertices**.
Root inspected all five final location captures. The final 12 projectile PNGs
match the previously independently reviewed images byte for byte. Startup also
passed the isolated headless 120 Hz boot; this does not qualify a packaged build.

[Starward floor detail](world-audio/starward-orrery-after-details.png) ·
[Tideglass reliefs](world-audio/tideglass-beacon-after-details.png) ·
[Projectile identities](projectiles/identities-reduced-0-zoom-100.png) ·
[Default-volume sound reel](world-audio/element-audio-30-percent.wav)

The sound bank uses 467,202 bytes. The capture harness exports six-element reels
at default 30% and 100%, with clean clip endpoints and a conservative four-voice
peak budget of 0.88 (0.264 at default gain). These checks do not replace listening
on the user's speakers or testing long sessions.

The identity helper used for this Linux session is retained alongside the
evidence. It ports the canonical record/hash procedure from
`scripts/runtime-build-identity.ps1`; its result exactly reproduced the baseline
**p60-be3efd332e1a / 3,390 records** before generating this checkpoint. PowerShell
is not installed on this PC. The canonical PowerShell checker remains available
for cross-platform reproduction.

## Performance evidence and limits

No overall FPS improvement is claimed for this checkpoint. The final candidate
gameplay comparison was deferred when the user requested the pause. A bounded
geometry microbenchmark before the final FIFO refinement measured roughly
2.69–2.81 microseconds per uncached call versus 0.79–0.87 cached, with equal
checksums. That isolated result is neither a final-source measurement nor a
gameplay speedup estimate.

The matched, focused baseline is retained as
[`baseline/measurements.json.gz`](baseline/measurements.json.gz) (lossless gzip;
uncompressed SHA-256 `6ac5535d563d61d5f4c5898c0dc8c35e79cdb22690087ad75d6d404822e3336e`): five Low-profile cases at an
actual 1280×720 viewport, ten seconds each, zero unfocused warm frames and unchanged
source. Warm mean / p95 frame intervals in milliseconds:

| Baseline case | Mean | p95 |
|---|---:|---:|
| Hearth idle | 16.664 | 17.149 |
| Garden middle | 17.003 | 20.646 |
| All-six paid Mantle | 23.748 | 30.492 |
| Movement across terrain boundaries | 16.767 | 17.432 |
| Close paid Fire bolts | 22.797 | 38.730 |

These are engine callback intervals, not GPU timings or physical presentation.
Finite cast cases include expiry/idle and prior-case warming. They show why
dense paid-field work still needs measurement; settings such as “60 FPS” are
targets. League of Legends was not benchmarked here, and no relative speed claim
is made. Reusing immutable geometry and eliminating redundant draws follows the
same general principle of doing less repeated CPU/render submission work.

Useful failures are retained locally rather than silently counted as passes:
the first focused run exposed duplicate backdrop callbacks; a first native
backdrop script had a naming/type error; the first VFX capture had an output-path
guard failure. These were corrected before the passing reruns. The first baseline
timed out because native window size differed from the rendered viewport; a later
unfocused run is not the matched baseline. The focused baseline's complete engine
receipt is valid, but its wrapper exited after a shell-file edit while running;
the wrapper was subsequently kept immutable during each invocation. The earlier
faint-map capture remains separate from the final art revision. Original transient
receipts, failure runs and baseline screenshots are also retained outside `/tmp`
in `.godot/presentation-checkpoint-20261011/retained-runs/` in this checkout.

## Resume only when requested

1. Read `checkpoint.json` and this branch's source identity, then inspect working
   state. Preserve `/home/otp/Projects/hex` user changes and prior portables.
2. Run the final-source native profile with the same baseline harness, viewport,
   focus, settings, workloads and cast admission counts. Record mean, p95, slow
   tails and stage costs; repeat the final FIFO microbenchmark if reporting it.
3. Review the richer map in movement and combat, listen to the recorded reel and
   play keyboard/controller transitions. Human feel, sound and readability are
   still separate from geometric and headless assertions.
4. Build a fresh portable only after qualification, then verify its actual
   startup, imported assets, safe exit and performance. Existing Windows packages
   retain their own identities and evidence. Multiplayer acceptance is separate.

No automatic optimization, export, release or main-branch merge continues while
this request is paused.

## Research used

- [Godot CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html): measure the expensive work and reuse stable results.
- [Godot jitter and stutter](https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html): differing update clocks and interpolation inform the camera timing correction.
- [Godot CanvasItem drawing](https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html#class-canvasitem-method-draw-colored-polygon): repeated polygon triangulation motivates retained indexed geometry.
- [Godot SubViewport update modes](https://docs.godotengine.org/en/4.6/classes/class_subviewport.html) and [viewport rendering](https://docs.godotengine.org/en/4.4/tutorials/rendering/viewports.html): one-shot rendering and completed-frame ownership inform buffer handoff.
- [Riot's LoL graphics pipeline](https://www.riotgames.com/en/news/trip-down-lol-graphics-pipeline) and [real-world profiling](https://www.riotgames.com/en/news/profiling-real-world-performance-league): workload-specific profiling and draw organization are useful precedents, not evidence that Hex or this machine matches LoL's performance.
- [Godot AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html): retained streams and explicit playing-state ownership inform the bounded voice design.

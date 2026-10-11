# Performance comparison: established techniques and H.E.X. proposals

Research checked October 10, 2026. Documentation only: this appendix does not
implement or qualify a performance fix. Historical engineering accounts describe
the implementation at publication, not necessarily the game's current internals.
Current requirements are identified separately. The proposals need measurements
on the actual H.E.X. target PC; no borrowed speedup is predicted.

**A game can look simpler and still do more expensive work per displayed frame.**
Its cost depends on which data it processes, how often it repeats work, how much
it allocates or uploads, and whether that work finishes before the next frame.
The comparison with League is useful evidence that a playable target is worth
pursuing; it does not identify H.E.X.'s bottleneck by itself.

## What the League comparison establishes

Riot's Windows requirements page, updated September 22, 2026 and checked for this
assessment, lists Core i3-530 / AMD A6-3650 CPUs and Intel HD 4600 among its
minimum hardware choices, with low graphics at 1024×768. It now requires DirectX
11 feature level 11_0. The page explicitly allows performance problems on minimum
hardware; it does not promise 60 FPS. These are published requirements, not a
benchmark of this PC. [Current Riot system requirements](https://support.riotgames.com/en-us/league-of-legends/performance/minimum-and-recommended-system-requirements-league-of-legends)

The checkbox specifically named **Low Spec Mode** disables pregame-client
animations and effects. Riot distinguishes that client guidance from in-game
low-FPS troubleshooting. A fair comparison should record the actual in-match
resolution, graphics settings, frame cap and workload, while accepting the
user's observation that League is playable on the same machine.
[Riot client-performance guidance](https://support.riotgames.com/en-us/league-of-legends/performance/troubleshooting-lag-or-low-fps-in-the-updated-client)

Riot's January 16, 2025 server-allocation article documents cloud-hosted game
processes, substantial differences between average and peak CPU use, and tests
of allocation strategies across multiple scenarios. It supports comparing peak
load rather than just averages and confirms that remote machines perform game
work. Its server-fleet cost results do not establish a desktop FPS improvement.
[Riot server-allocation engineering](https://www.riotgames.com/en/news/tech-blog-cpu-usage)

The July 25, 2025 Swarm article explicitly identifies League as a dedicated,
server-authoritative game; even solo Swarm kept most game logic on the server.
It describes lightweight enemy representations, shared flowfield pathfinding,
simplified client movement, data-authored native-code waves, grouped status
processing and particle profiling. Its important lesson is to match data and
algorithms to the actual workload while retaining the intended play.
[Riot's Swarm engineering account](https://www.riotgames.com/en/news/the-tech-behind-swarm)

In H.E.X.'s current offline path, the same PC runs authoritative simulation and
presentation. Snapshot publication in `Bootstrap` is guarded by
`session_transport.is_host()`; ordinary offline play does not continuously
broadcast multiplayer snapshots. This local workload distinction can contribute
to different performance, but does not quantify the difference or prove that
simulation is the current bottleneck. The catalogue's 504 authored spells also
does not imply that all 504 execute every tick. See the current
[runtime loop](../../src/app/bootstrap.gd) and
[playable contract](../../README.md).

## Documented techniques and transferable changes

Each evidence cell summarizes its linked source in fewer than 150 words. The
H.E.X. column contains proposals, not claims that the other game uses our exact
implementation or that the proposed change has already improved H.E.X.

| Example | Documented evidence and boundary | Proposed application to H.E.X. |
|---|---|---|
| League: prepare static appearance in advance | Riot's January 2017 pipeline baked static-object and grass shadows into terrain textures. Animated character assets were exported and loaded at match start; animated water textures and extra geometry added motion to the scene. This is a historical pipeline account. [Source](https://www.riotgames.com/en/news/trip-down-lol-graphics-pipeline) | Prebuild immutable campus terrain and decorative geometry. Keep a bounded cache around the camera and anticipated movement. Prepare destination assets before releasing travel input. Apply time-based animation over retained geometry. |
| League: distinguish logical and visual resolution | In 2016, Riot kept a 128×128 fog-of-war representation and improved its displayed appearance through upscaling and filtering. Increasing logical resolution would have increased CPU work; presentation could be improved independently. [Source](https://www.riotgames.com/en/news/story-fog-and-war) | Preserve exact authoritative chemistry while caching compact visual summaries of changed cells and regions. A rich-looking field need not reconstruct gameplay dictionaries or perform chemistry during every draw. Never approximate collision, damage boundaries or elemental identity solely to save rendering work. |
| League: constrain effect generation and pixel coverage | Riot's 2018 investigation found a Rakan trail whose geometry generation grew with movement speed, and a Swain outline whose incorrect bounds caused a very large blur. Bounded trail generation and corrected outline bounds resolved the respective problems. These were different CPU and GPU failures. [Source](https://www.riotgames.com/en/news/profiling-real-world-performance-league) | Bound decorative trail segments independently of speed and cap cosmetic layers per effect. Measure CPU preparation and GPU overdraw separately. Tight bounds and fewer decorative passes should preserve attack cores, warning contours and protection cues. A `draw_*` call count alone is not a measured GPU draw-call count. |
| League: data access and the frequent case | Riot's 2015 particle optimization examined animated values, avoiding unnecessarily large lookup tables in common simple cases and improving data access. The account emphasizes measuring the real usage pattern before changing a plausible general-purpose implementation. [Source](https://www.riotgames.com/en/news/random-acts-optimization) | Cache immutable recipe data and precompiled spell descriptors. Replace repeated large view dictionaries with small retained render records where profiling confirms the cost. Optimize common visible/active states before rare editor or diagnostic paths. |
| League: performance monitoring | Riot's 2018 missing-milliseconds account shows how aggregated FPS changed with hardware mix and how a tiny polling-condition error imposed a recurring delay. It argues for hardware-controlled comparisons and frame times. [Source](https://www.riotgames.com/en/news/profiling-case-missing-milliseconds) | Preserve reproducible replay routes and compare the same release configuration on the same PC. Record distributions and individual hitches, not just mean FPS or test counts. Attribute a change to an isolated experiment before promoting it. |
| Factorio: cache preparation as well as pixels | The 2019 animated-water account describes a costly render-preparation regression. Factorio cached draw orders per chunk and prepared newly visible chunks; time-driven water reused unchanged vertex data, while static chunks reused finished pixels. The article also describes freezing cosmetic water for weaker hardware and opportunities for advance preparation. [Source](https://www.factorio.com/blog/post/fff-323) | Give each Garden plot persistent geometry or a stable cache entry. Do not alternately invalidate one geometry cache for many independent courts. Cache terrain preparation per chunk, prefetch likely next chunks and spread work over spare frame budget. |
| Factorio: share and schedule repeated work | The 2024 optimization account replaced overlapping radar polling with shared chunk registrations and bucketed updates; unregistered chunks ceased updating. This is a concrete example of reducing redundant processing rather than merely running the same processing faster. [Source](https://www.factorio.com/blog/post/fff-421) | Maintain active/dirty chemistry regions and due timers. Schedule harmless exhibit lifecycles separately from combat. Preserve offscreen gameplay causality: invisibility alone must not stop a damaging projectile, reaction or status timer. |
| Apex: separate rates and responsibilities | Respawn's 2021 netcode explanation distinguishes server states, rendered frames and client inputs, and describes prediction for immediate local feedback. It cautions that work per tick differs between games. Its historical 20 Hz server rate says nothing about a suitable local-physics rate for H.E.X. [Source](https://www.ea.com/games/apex-legends/apex-legends/news/servers-netcode-developer-deep-dive) | Protect input, movement and collision responsiveness while separating cosmetic animation, UI and harmless exhibits from authority frequency. Test any eventual simulation-rate change with collision sweeps, timing/replay checks and interpolation; changing a number alone is not a fix. |
| Titanfall: predictable control and economical cues | In the March 2017 interview, Respawn developers describe repeated wallrun testing, anticipatory view tilt, training through level design, and slides derived from normal movement with targeted changes. They discuss aim steadiness and avoiding unintended view motion. This is first-hand design testimony, not an engine performance benchmark. [Source](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right) | Retain readable wall contact, movement momentum and deliberate poses with small state-driven cues. A stable camera and prompt input feedback matter more than adding more animated layers. Keep the collision query focused on nearby relevant geometry without removing movement options. |
| Godot: central bullet management | The official bullet-shower example manages bullet logic centrally and uses physics-server handles instead of separate scene nodes for each bullet. It illustrates a lower-overhead representation for large populations; its demo population is not a guaranteed capacity on this PC. [Source](https://github.com/godotengine/godot-demo-projects/blob/master/2d/bullet_shower/bullets.gd) | H.E.X. already has custom projectile simulation. Improve measured data traversal, broad-phase collision queries and retained drawing buffers there; do not invent a per-bullet-node problem. Keep gameplay projectiles deterministic and visible while batching purely decorative work. |
| Dead Cells: authored depth in 2D art | Motion Twin confirms that much of Dead Cells' art originated in 3D and was transformed into 2D. This supports an art-production technique, not a numerical performance claim. [Source](https://motiontwin.com/faq) | Preserve volume through authored directional poses, contact shadows and height cues. Precompute reusable shapes and animation assets. A more alive appearance does not require full 3D simulation or expensive procedural reconstruction. |
| Noita: scale systemic interactions deliberately | The primary GDC 2019 session page identifies co-creator Petri Purho's discussion of scaling falling-sand simulation into continuous worlds and integrating destructible rigid bodies. The primary transcript was not inspectable in this research, so exact chunk sizes, thread schedules and dirty-rectangle details are not asserted here. [Source](https://www.gdcvault.com/play/1025695/Exploring-the-Tech-and-Design) | Retain emergent chemistry as a core design goal while demanding bounded active work and reproducible worst-case tests. Use the directly documented Factorio examples above to justify specific chunk/cache changes. |

## What to preserve while making it faster

The distinct six-element combinations, eight spell deliveries, character passives,
movement chains and larger world are authored content. Their existence does not
require all possible instances or demonstrations to be fully recomputed every
frame. A six-element projectile can retain one identity and one finite gameplay
budget while displaying a clear core and a bounded set of ingredient motifs.
The same principle applies to menu cards: cache what is unchanged and update
only visible content when its inputs change.

The Garden can remain a complete teaching area while doing substantially less
repeated work. Candidate designs include retained per-plot geometry, staggered
harmless updates, or versioned visual lifecycle samples produced by the real
chemistry implementation. If samples replace live exhibit simulation, describe
them honestly and verify them against the current chemistry version. Keep actual
player spells live, authoritative and visually distinguishable from exhibits.
These are proposed local design choices, not reported Noita or League features.

A performance preset should reduce ambient particles, decorative trail density,
nonessential animation and pixel resolution before sacrificing gameplay clarity.
It must keep hostile projectiles, collision-relevant boundaries, detonation
warnings and protection states legible. Treat Reduced Motion as an accessibility
setting, not an implicit substitute for a measured performance preset.

Prefer removing redundant work and repairing cache ownership before an engine
rewrite, blanket multithreading or lowering global simulation frequency. If hot
loops remain, profile a targeted native implementation. Any such migration needs
the same deterministic outcomes, saved-data compatibility and finite budgets.

## How the proposals become evidence

For each candidate, keep the same release build configuration, hardware,
resolution, power state and repeatable route. Separate cold loading, warm travel,
Garden display, sustained casting and worst legally reachable combat. Compare
frame-time percentiles and hitch counts together with simulation backlog, input
timing, CPU preparation, GPU time and memory growth. Verify gameplay and visual
clarity after the measured change.

The target is a measurable stable gameplay baseline on this PC, with explicit
headroom and no reproducible game-caused hitch in the supported scenarios.
Neither a game's reputation, a borrowed technique, an average FPS value nor a
large correctness suite can guarantee completely smooth play under every OS,
thermal, background-process or network condition.

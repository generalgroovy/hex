# H.E.X. performance implementation — October 10, 2026

Status: completed local performance implementation and qualification for p60-be3efd332e1a. The October 11 source publication preserves this runtime and its measured limits.

Current source **p60-be3efd332e1a** has passed the final **Full v5 gate: 244 suites, 6,880,581 assertions, zero failures and zero stderr**, plus 614 independent native pixel comparisons and the final native measurement wrapper/source checks. Hearth and Garden average about 17–18 ms between process starts on the measured laptop. Heavy casting still exceeds the 16.67 ms budget: final close-Fire and all-six Mantle means are about 25–28 ms, with the detailed limits below. This is a verified improvement with remaining workload limits, not a claim of completely smooth 60 FPS. [Full v5 receipt](performance-qualification-20261010/full-v5.json).

The final Windows portable in **`exports/hex-smooth-fields-20261010`** has passed its native export smoke, standalone payload/archive verification and packaged-terrain decoding. Its completed visible measurements averaged **57.64 reported FPS at Hearth, 59.00 in the Garden, 49.13 for the finite nearby Fire sequence and 38.71 for all-six Mantle**. Fire still reached 21 reported FPS under load; the means include the finite sequence and any subsequent idle, so heavy-field smoothness remains unfinished. First-pass package **p60-d649c4d1d99c** and intermediate source **p60-6980b3dcafec** retain separate historical evidence. The first-pass portable is `exports/hex-smooth-20261010/windows`; the older portable remains preserved at `exports/hex-element-expansion-20261009/windows`. This document supersedes the proposed-work sections of [the assessment](performance-assessment-20261010/assessment.md); its original measurements and research remain historical evidence.

The objective is responsive movement and casting throughout Wellspring, including the Element Garden, on the measured Ryzen 3 7320U/Radeon laptop. The six elements, all 63 combinations, paid spell rules, 120 Hz simulation, collision, statuses, visibility, and movement timing remain the gameplay contract. A functional test pass is not a smoothness certificate.

## Final shared-rendering source

The completed shared-rendering pass is frozen as **p60-be3efd332e1a**, with 3,390 canonical records and runtime SHA-256 `be3efd332e1a9cc584a4cdc4e983c2ce9e5de84ed5a179a0d1152f5ef8237e33` (protocol 60 / snapshot 24). It extends the intermediate caches with these bounded representation changes:

| Retained work | Limit and correctness boundary |
|---|---|
| Fixed-to-pixel region conversion | At most 512 entries keyed by both exact fixed polygon and expected cell polygon. Inputs and returned geometry are detached; phase, ownership, stock, expiry and direction are still read for each region. |
| Shared fill and mark placement | Reuses the exact retained six-vertex fill mesh and centroid/clearance data, each with a 512-entry bound. Current color, opacity, texture and painter order remain live; capacity overflow follows the original path. |
| Repeated boundaries within one cell | At most 64 exact prefix/polygon identities skip repeated edge preparation per cell. The old per-edge deduplication handles overflow; neighboring cells and different ownership, danger or phase still contribute their own boundaries. |
| Surface glow | At most 256 polygons / 512 meshes retain the original two convex insets. No live mesh is evicted; colors and opacity are supplied at draw time, with the original static helper for invalid or excess inputs. |

The final **Full v5 gate passed 244 suites and 6,880,581 assertions with zero failures and zero stderr**, including import, canonical identity after import, the complete suite registry and the subsequent boot. This gate covers the frozen **p60-be3efd332e1a** source. [Full v5 receipt](performance-qualification-20261010/full-v5.json).

Four focused suites also passed **154,856 assertions with zero failures**, including **5,506** in the expanded paid-field suite. The independent native comparison passed **614 exact RGBA comparisons with zero mismatches**, including the 176 actual paid-field boundary comparisons and eight retained/overflow glow comparisons at both zooms with changing color/opacity. These establish the sampled representation equivalence and cache bounds, not performance or complete gameplay acceptance. [Focused log](performance-qualification-20261010/shared-paid-focused.log), [native receipt](performance-qualification-20261010/shared-paid-equivalence.json).

## Final native source measurements — p60-be3efd332e1a

The final source matrix completed **25 records: 18 warm rows and seven startup/travel rows**, at 1280×720 with Compatibility/ANGLE/D3D11, VSync enabled and a 60 FPS limit. It ran eight ordinary cases for about ten seconds each at Low and Standard, plus a sixty-second Garden loop per profile. The wrapper and canonical source checks passed; all warm rows recorded zero unfocused frames, zero dropped/clamped accumulator time and approximately 119.88–120.42 simulation ticks per wall second. These are measured process-start intervals, not physical presentation or input-latency timestamps. [Final native v3 receipt](performance-qualification-20261010/native-final-v3.json).

An independent audit recomputed **all 15,055 raw frame intervals**, 250 raw metric distributions and the main draw-stage distributions without discrepancies. It checked 15,087 actual draw callbacks, all 298 recorded/current source hashes, exact case order, completion and focus records, and 18 screenshot files with stable hashes and the expected 1280×720 dimensions. Screenshot file checks do not add a visual or human-playability verdict. [Independent native audit](performance-qualification-20261010/native-final-v3-audit.json).

| Final source warm workload | Low mean | Low p95 | Standard mean | Standard p95 |
|---|---:|---:|---:|---:|
| Hearth idle | 17.345 ms | 19.768 ms | 17.234 ms | 19.095 ms |
| Garden entry | 17.442 ms | 22.510 ms | 17.755 ms | 22.946 ms |
| Garden middle | 17.913 ms | 23.418 ms | 17.165 ms | 20.639 ms |
| Paid Fire Bolt, distant target | 22.856 ms | 33.242 ms | 20.918 ms | 23.251 ms |
| Paid all-six Mantle | **28.173 ms** | **36.246 ms** | **27.581 ms** | **33.354 ms** |
| Movement across terrain boundaries | 18.209 ms | 23.011 ms | 18.186 ms | 23.321 ms |
| Range floor plus paid firing | 17.234 ms | 18.912 ms | 19.008 ms | 28.597 ms |
| Twelve paid Fire Bolts, nearby target | **25.751 ms** | **39.507 ms** | **24.857 ms** | **39.206 ms** |
| Garden, sixty-second loop | 17.494 ms | 22.796 ms | 17.232 ms | 20.290 ms |

Both Garden loops, both Mantle rows and both close-Fire rows had **no intervals above 50 ms**. The Low distant-Fire row still had **seven above 50 ms out of 438 intervals**, with a 55.314 ms maximum; it remains an observed hitch limit. The final Mantle and close-Fire means also exceed the 16.67 ms budget for 60 FPS. These results support improved workload-specific smoothness, not a flat 60 FPS claim.

The close-Fire rows each admitted twelve casts and paid 7,200 matter, reaching six products and up to 150 visible region records. Their whole-run values include empty time: Low had 186 empty draws out of 390 (26 before the first field, 160 after the last); Standard had 203 out of 404 (26 before, 177 after). At the peak of **150 visible records**, the 27 samples per profile still averaged **38.286 / 37.876 ms** to the next process start, with Court drawing alone averaging **13.047 / 12.858 ms**. This peak remains above the smoothness target despite the absence of 50 ms spikes in those final close-Fire samples.

Earlier matrix cases had already warmed presentation caches, and Standard followed Low. The isolated ten-second close-Fire baselines started with empty outline/native-surface caches. Therefore the final rows are neither sustained-battle measurements nor isolated causal comparisons with those baselines. The Range rows paid real matter but again reached **zero occupied paid-ground cells**, limiting their active-field coverage. These sample partitions and normalized inclusive rendering costs are retained in the [independent audit](performance-qualification-20261010/native-final-v3-audit.json).

Cold costs remain separate. Synchronous startup took **5.54 seconds**; Garden travel rows reached **140–177 ms** frame intervals, and Range fixture preparation took **1.31–1.32 seconds** outside the warm rows. The two Garden loops retained 114,660,131 texture bytes at both endpoints, while static memory increased approximately 16.0/16.2 MB with the full observer retaining samples. Available physical memory changed from about 1,422 to 978 MiB over the matrix. These are endpoint observations under ordinary background load, not a continuous memory trace, leak-free-process proof or randomized profile comparison.

**Qualification scope:** the frozen source's final Full gate and native source matrix have passed. The export has passed its smoke, exact standalone package checks and packaged-terrain decoding, and the actual portable measurements are recorded below. These completed checks establish their stated functional, representation and measurement results; the heavy-field performance target is still unmet. First-pass package and intermediate timing evidence remain historical.

## Final Windows portable — p60-be3efd332e1a

The final portable is [HEX-p60-be3efd332e1a-Windows-x64.zip](../exports/hex-smooth-fields-20261010/HEX-p60-be3efd332e1a-Windows-x64.zip), **160,935,115 bytes / 153.5 MiB**, with the extracted executable at `exports/hex-smooth-fields-20261010/windows/hex.exe`. Native export launch, exact source identity and safe close passed. The separate standalone verifier passed **18 of 18 checks**, validating the exact ten payload entries, unique archive membership, runtime identity, hashes and launcher/instruction requirements. Both the first-pass fallback PCK and ZIP remained unchanged. [Export receipt](performance-qualification-20261010/package-final.json), [standalone verification receipt](performance-qualification-20261010/zip-verification-final.json).

| Artifact | SHA-256 |
|---|---|
| Final PCK | `4d75c71cc68845da6053733653f1de405ce69bd897d01402f80709a7a44ea812` |
| Final ZIP | `79c7511324725e6b6661810e7eccac6696388a758be704e287e44ed5057afbd4` |

The final PCK also passed **2,062 terrain checks**, decoding all **132 chunks plus the overview** and validating their dimensions, RGBA hashes, provenance and release identity. All 136 target resource paths were absent from the minimal isolated project before the explicit pack mount; no loose project assets supplied a fallback. Original and staged PCK hashes matched before and after. This verifies the actual packaged terrain contents, without claiming frame-pacing or gameplay acceptance. [Final terrain receipt](performance-qualification-20261010/terrain-pack-final.json), [copy and mount provenance](performance-qualification-20261010/terrain-pack-provenance-final.json).

The package receipt records no installer execution or historical checkpoint promotion.

## Final visible portable measurements — p60-be3efd332e1a

The actual final EXE/PCK was measured in four separate visible launches at 1280×720, Low detail, with isolated preferences and no LAN. Each launch requested 900 engine iterations; those are neither seconds nor a verified count of displayed frames. The table includes **every recorded engine one-second FPS observation**, including startup where reported, the finite casting sequence and any idle after it or after field expiry. Both spell cases admitted twelve casts and refused zero through ordinary cooldown and Flux rules, without refill. All four completed with empty stderr and no validation errors, and the EXE/PCK/build-state hashes stayed unchanged. The independent audit passed **457 checks with zero errors**, recomputing the saved FPS observations, cast admissions and window-state evidence without another game run. [Final visible portable receipt](performance-qualification-20261010/portable-visible-final.json), [independent portable audit](performance-qualification-20261010/final-portable-audit.json).

| Final portable workload | Mean reported FPS | Reported range | One-second observations |
|---|---:|---:|---:|
| Hearth | 57.643 | 46–60 | 14 |
| Garden entry | 59.000 | 56–61 | 14 |
| Twelve paid Fire Bolts, nearby target | **49.125** | **21–60** | 16 |
| Twelve paid all-six Mantles | **38.714** | **36–50** | 21 |

The Fire sample contains four early observations at **31, 22, 21 and 22 FPS**, followed later by ten at 60 FPS. Its 49.125 FPS mean therefore hides a substantial casting slowdown. Mantle stayed below 60 in every recorded one-second observation. The final renderer reduces the earlier workload costs but does not deliver completely smooth heavy casting on this laptop. Engine FPS observations cannot establish a frame-present distribution, input latency or sustained-casting performance.

Across the four launches, **243 of 245 window samples had an available main window**; all 243 reported foreground ownership, visible and non-minimized state. The two unavailable samples were at Garden startup and Fire exit, with no sampler errors. Sampling roughly every 500 ms does not prove uninterrupted focus or unobscured physical presentation. Available physical memory was approximately 809 MiB before the matrix and 916 MiB after it. The final and historical visible runs differ in duration, sample counts, cache history, background load and memory availability; their values are observations, not controlled speedup ratios.

Remaining performance work is concentrated in visible overlapping fields and the unexplained part of frame time outside measured callbacks. The audited 150-region native samples still average about 38 ms between process starts, and the actual Fire portable observations also show the slowdown. The Low distant-Fire hitches and separately recorded cold travel costs also remain measured limits. Reducing those costs requires further profiling and representation changes while preserving the same field boundaries, ownership, phase cues and 120 Hz gameplay contract.

## Foundation changes retained in the final source

| Work | Result and bounds | Relevant established technique |
|---|---|---|
| Garden rendering | Retains exact live field geometry and submits shared animated material textures through one merged UV mesh per plot. Pad geometry and plaque layout are reused. Warning and cover cues still use production rules. | Factorio's retained chunk draw data; Riot's profiling of representation and effect costs. |
| Garden lifecycle | Real isolated chemistry remains active. FIFO scheduling allows at most one harmless exhibit restart per rendered frame, avoiding repeated catch-up restarts. Expiry and damage authority are unchanged. | Bounded cosmetic work; separation of simulation from visual representation. |
| Paid material rendering | Sparse internal bundles, immutable recipe reads, conservative viewport culling, and bounded per-court geometry caches remove repeated empty records and offscreen draw preparation. Exact outline triangles share resident meshes; overflow uses the original draw path. Ownership seams, Backdraft deadlines, phase, intensity and danger remain fresh. | Riot's graphics pipeline and measured effect optimization. |
| Spell Range | Internal material preparation uses occupied cells while retaining all 469 floor cells. Static stone fills and marks share an ordered mesh with an exact float palette. At most eight layouts and 4,096 source cells are retained; excess layouts use the original drawing path. | Retained static geometry and compatible draw batching, selected after measuring the actual Range bottleneck. |
| Terrain | 132 exact terrain chunks, each up to 512×512 pixels, and a separate overview are baked before play. The twelve southern edge chunks are 512×256. A versioned manifest validates source provenance and pixels. Runtime drawing does not compose images or trigger whole-world construction. | Riot's baked terrain; Factorio's chunk caching. |
| Streaming and travel | Bounded background requests and main-thread uploads prepare the visible area plus a guard and a prefetched neighborhood. Offline control resumes after destination essentials are ready; network authority continues during local loading. | Explicit asset residency and preparation outside drawing. |
| Terrain lifetime | Leaving Wellspring stops queued work and collects only completed background loads. Returning to the same view resumes demand. Final teardown consumes the at-most-two outstanding handles; rejected reconfiguration preserves the existing map and texture owner. | Explicit resource ownership across asynchronous work; [Godot's threaded loading contract](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html). |
| Visibility rendering | Opaque terrain occlusion polygons share a triangle submission with terrain UVs. The batch is flushed before physical cover is repainted. Building bounds are read once during each synchronous draw, then discarded; sight and aim results are never cached across frames. | Compatible draw batching, preserving painter order and disclosure rules. |
| Character memory | Tiny portraits and validated metadata remain available for all characters. Large body/action pages serve the current actors and Gallery selection, with a bounded recent-identity cache. Successful Fullbody startup skips an unused wireframe bank containing 116.44 MiB of validated uncompressed pixels; that asset total is not a measured process-RAM saving. | Working-set budgets and asset residency rather than loading the entire cast permanently. |
| HUD | At most twelve spell-card text/layout records are retained. Ability metadata, binding, rectangle, or font changes invalidate the relevant record. Up to 64 panel meshes are retained with an exact polygon fallback. Resources, cooldowns, warnings, colors and casting progress remain live. | Retaining unchanged interface work. |
| Simulation | Empty product/flight work and zero-distance collision searches return early. Movement's 31 timer decrements use direct typed fields. Empty pressed/held spell masks bypass ordered slot searches, including the combat repeat selector. Zero cooldown arrays take a direct exit; active cooldown aliases reuse exact first-match indices. The unused legacy material-slot preparation is skipped on the Hex branch. | Profile-guided removal of repeated work, checked against preserved reference behavior. |
| Player settings | Menu → Performance offers Low/Standard visual detail and 60/120/unlimited frame limits. Low is the new default and reduces optional decoration; reduced-motion accessibility remains independent. | Budgeting presentation separately from authoritative gameplay. |
| Measurement | `scripts/profile-gameplay.gd` records frame-start intervals, draw/process stages, simulation ticks versus wall time, terrain residency, memory, paid casts, and threshold counts. Cold preparation is recorded separately from warm cases. | Reproducible profiling before further changes. |

The comparisons are engineering precedents, not a claim that H.E.X. uses those games' engines or will achieve their performance. Source explanations are linked in the [comparative research](performance-assessment-20261010/comparative-research.md), including [Riot's pipeline](https://www.riotgames.com/en/news/trip-down-lol-graphics-pipeline), [Riot's real-world profiling](https://www.riotgames.com/en/news/profiling-real-world-performance-league), and [Factorio FFF-323](https://factorio.com/blog/post/fff-323).

## Validation method and historical first-pass receipts

Root owns and serializes engine runs. Rendering, simulation, and memory agents review each other's boundaries. The preserved pre-change source is under `.godot/smooth-20261010-baseline`; additional exact references are under `.godot/performance-optimization-baseline`.

Focused validation covers every Garden recipe and raw element, native clipped UV geometry, lifecycle restart fairness, direct membership and phase invalidation, character page hashes/eviction/fallback, preference migration, input quarantine, opaque visibility UVs, and static HUD cache invalidation. Simulation comparisons include exact ordered events, complete world hashes, all actor script fields, signed and boundary timer values, and every low-16-bit spell mask.

The first-pass **Full v4 gate passed 243 suites and 6,875,075 assertions with zero failures and zero stderr**, including import, post-import canonical identity, the complete suite registry and a subsequent boot. Its source is **p60-d649c4d1d99c**, 3,388 canonical records, protocol 60 / snapshot 24. This gate predates the second-pass Court/Retro caches. [Full receipt](performance-qualification-20261010/full-v4.json).

The first-pass native rendering comparison passed **440 exact RGBA comparisons**, covering all 69 material identities across three phases and normal/reduced effects, mixed ownership and overlapping lifetimes, HUD sizes/alpha, fractional placement and cache overflow. Both sides had to load native material textures and submit real draws; a checker-only control rejected empty output. This proves the arranged outline and panel cases, not every natural battle or input latency. [First-pass receipt](performance-qualification-20261010/render-equivalence-final.json); [earlier preserved run](performance-qualification-20261010/render-equivalence.json).

The separate Range comparison passed **101 exact RGBA comparisons** against frozen pre-optimization floor methods. Overlapping crops cover the entire 469-cell floor and perimeter, with 11,256 vertex/margin witnesses. Empty, paid Fire and all-six fields, two effects modes, two zooms, fractional transforms, terrain/elevation edits, same-count membership changes, origin shifts and restoration were exercised. Positive controls require eight real retained mesh layouts, reuse and zero fallback; the reference used no candidate floor mesh. [Receipt](performance-qualification-20261010/range-render-equivalence.json)

Together these are **541 first-pass pixel comparisons**, not second-pass acceptance. Native cases include Hearth, Garden approaches and lifecycle repeats, real paid Fire Bolt and all-six Mantle, Range casting, and continuous movement across terrain boundaries. Screenshot inspection complements these checks.

The first-pass packaged-terrain audit passed **2,062 checks**, decoding all **132 chunks plus the overview** from the actual exported PCK. It compared dimensions, RGBA hashes, manifest provenance and release identity, with all 136 target resource paths absent before an explicit mount into an isolated minimal project. Original and staged PCK hashes were identical before and after. This establishes packaged resource integrity; it does not measure release rendering or performance. The older media inventory alone does not enumerate these `.res` resources. [Terrain receipt](performance-qualification-20261010/terrain-pack.json), [isolated-pack provenance](performance-qualification-20261010/terrain-pack-provenance.json).

The compact Performance menu was opened and closed through normal navigation with gameplay input blocked, at 1280×720 and 960×540. Both captured layouts were inspected without clipped controls or overlapping panel text. This checks the sampled layout and modal ownership, not complete physical-controller usability. [Receipt](performance-qualification-20261010/performance-ui.json), [1280×720 capture](performance-qualification-20261010/native/performance-1280x720.png), [960×540 capture](performance-qualification-20261010/native/performance-960x540.png).

## Historical first-pass native measurements

The frozen implementation was measured at 1280×720, Compatibility/ANGLE/D3D11, VSync enabled and a 60 FPS limit. Each ordinary warm case lasted about ten seconds; Garden had an additional sixty-second loop per detail setting. All sixteen warm records stayed focused, advanced simulation at approximately 120 ticks per wall second and recorded zero dropped or clamped time. These are process-start intervals, not physical presentation timestamps.

Selected historical rows are retained here; the linked receipt contains the complete first-pass distributions.

| First-pass warm workload | Low mean | Low p95 | Standard mean | Standard p95 |
|---|---:|---:|---:|---:|
| Hearth idle | 17.05 ms | 18.40 ms | 17.41 ms | 19.02 ms |
| Garden entry | 17.41 ms | 23.08 ms | 17.65 ms | 23.39 ms |
| Paid all-six Mantle | **31.93 ms** | **41.38 ms** | **36.58 ms** | **50.78 ms** |
| Garden, sixty-second loop | 17.23 ms | 20.76 ms | 17.16 ms | 20.18 ms |

The Garden loops had p99 of 24.79/24.27 ms and no intervals above 50 ms. The first-pass all-six case was a real limit: Low had three intervals above 50 ms; Standard had nineteen. Its Low mean process callback was 5.85 ms and draw submission 13.32 ms, including 6.08 ms for paid ground; these nested elapsed categories cannot be summed as independent CPU/GPU costs. It reached 33 paid cells. The Range case spent real matter and fired projectiles but had **zero occupied paid-ground cells**, so it does not qualify sustained active-field rendering.

The native Fire fixture fires once per second toward a distant point. Its paid ground was outside the drawn viewport: the recorded ground-bundle and surface stages were zero. The actual portable fixture aims 200 pixels away and retries each time normal cooldown permits, producing twelve admitted casts. These differ in cadence and visible ground load; the native Fire row must not be used to predict rapid clustered casting in the portable.

Loading remains separate: synchronous native startup took 5.75 seconds; Garden travel records contained intervals of 141–179 ms, and Range fixture preparation took approximately 1.3 seconds outside warm measurement. One Standard pre-soak arrival recorded one dropped 120 Hz tick (8.33 ms). These costs are not hidden in a warm-play claim. Both Garden loops retained exactly 114,658,319 texture bytes; total static memory rose about 16.2 MB per loop while the full observer retained samples, so this is not a leak-free-process claim.

The native run completed all 23 ordered records with stable source and empty stderr, but the new PowerShell wrapper then failed to count its single completion-log line. The failed summary is preserved. A one-assignment array fix was independently reviewed and passed a separate native three-second lifecycle check. Source-only revalidation checked the original data, screenshots, logs and source identity without remeasuring frames. A second agent independently recomputed all 14,216 frame intervals and their statistics, with no discrepancies. [Original summary and failure](performance-qualification-20261010/native-final-original-summary.json), [explicit post-run revalidation and complete distributions](performance-qualification-20261010/native-final-revalidation.json), [repaired wrapper native check](performance-qualification-20261010/profiler-wrapper-smoke.json).

Available physical memory was approximately 914 MiB before this run and 912 MiB after it. The Low/Standard sequence was not randomized, and normal background applications remained open. Small differences between profiles should not be treated as isolated speedups.

## Historical first-pass visible portable measurements

The actual first-pass EXE/PCK was measured at 1280×720 with isolated preferences, Low detail, a requested visible window, and no LAN. The following values include **every engine one-second FPS observation**, including cold startup where reported, finite casting and idle after the sequence. They are not frame-present timestamps or sustained-casting averages. Each paid case admitted twelve casts through ordinary cooldown and Flux rules without refill. EXE/PCK hashes stayed unchanged and stderr was empty. [Visible first-pass receipt](performance-qualification-20261010/portable-visible-v1.json).

| Portable workload | First-pass reported FPS mean | Reported range | Observations | Older visible portable mean / range |
|---|---:|---:|---:|---:|
| Hearth | 59.77 | 58–60 | 13 | 24.57 / 19–28 (7 observations) |
| Garden entry | 57.57 | 51–60 | 14 | 2.75 / 1–5 (63 observations) |
| Twelve paid Fire Bolts, nearby target | 44.67 | 11–61 | 18 | Not measured in this comparison |
| Twelve paid all-six Mantles | 29.92 | 12–60 | 26 | Not measured in this comparison |

The older visible comparison used **p60-6d80c3bce71e**. Valid window samples reported foreground ownership, visible/non-minimized windows for both versions; some exit-time samples had no remaining process. Sampling roughly every 500 ms cannot prove uninterrupted or unobscured presentation. The runs differed in duration, available memory and background load, so these observations do not establish a controlled speedup ratio. [Older visible receipt](performance-qualification-20261010/old-portable-visible.json).

An earlier first-pass run launched the game with a **hidden-window setting** and did not sample window state. Its Hearth/Garden means were 33.12/32.92 reported FPS, versus 59.77/57.57 in the subsequent visible run. That launch condition is a material confound; the hidden run remains preserved but cannot qualify normal visible play or isolate the cause of the difference. Neither the hidden nor the visible observations justify a blanket 60 FPS claim. [Hidden-window receipt](performance-qualification-20261010/portable-hidden-window.json).

## Historical close-Fire bottleneck and intermediate candidate

The original native Fire row above aimed far away and generated **no visible paid-ground work**. A matched source workload now aims 200 pixels away and makes twelve finite attempts at the first ordinarily permitted tick, without refill. On first-pass source **p60-d649c4d1d99c**, all twelve were admitted, spending 7,200 matter and reaching six simultaneous products and up to 150 prepared visible region records. The ten-second Low-detail run recorded **32.798 ms mean / 70.701 ms p95 frame intervals** (305 intervals; 54 above 50 ms), with zero unfocused frames. It advanced about 111.97 simulation ticks per wall second despite recording no dropped/clamped accumulator time. [Matched close-Fire baseline](performance-qualification-20261010/close-fire-baseline.json).

Measured mean callbacks were 4.83 ms for process and 12.71 ms for draw submission, including 5.81 ms for Court drawing. Conflagration drawing consumed 1.254 seconds of 1.777 seconds of accumulated Court time across 306 draws; fire marks accounted for 0.462 seconds **inside** that Conflagration work. These nested diagnostic timers include instrumentation overhead and must not be added together or described as GPU time. This identifies a substantial visible-field submission bottleneck that the distant Fire fixture did not exercise.

Intermediate candidate **p60-6980b3dcafec** retains exact absolute-UV Court/Retro meshes, center/clearance results, texture-color keys and boundary preparation with bounded caches and original-path overflow. Ownership, direct-mutation invalidation, phase and live color/texture inputs remain part of the review contract. No authoritative gameplay rule or simulation rate is being changed.

Its focused suite passed **3,249 assertions**, and the independent frozen-reference native comparison passed **606 exact RGBA comparisons with zero mismatches**: 430 arranged material/mark/overflow cases plus 176 comparisons at actual paid-field phase boundaries. The real sequence admitted twelve casts, paid 7,200 matter without refill, reached six products and 150 region records, and completed finite expiry. Every paid comparison checked unchanged authority and complete field-boundary coverage inside the crop. This qualifies the sampled drawing equivalence; it does not establish the speed improvement or replace a fresh Full gate. [Focused log](performance-qualification-20261010/paid-field-focused.log), [native receipt](performance-qualification-20261010/paid-field-equivalence.json).

The intermediate candidate's matched close-Fire run measured **27.273 ms mean / 48.506 ms p95**, with **16 of 367 intervals above 50 ms**, versus 32.798 / 70.701 ms and 54 of 305 intervals in the first-pass baseline. It again admitted twelve casts and paid 7,200 matter. The improvement applies to this finite workload: 182 of its 368 draw samples had no visible paid regions—15 before the first field and 167 after the last field. The remaining 186 samples contained visible fields. Consequently, the whole-run mean is not a sustained-battle result or evidence of a stable 60 FPS rate. [Retained-mesh close-Fire receipt](performance-qualification-20261010/close-fire-retained-mesh.json).

The intermediate all-six Mantle results still exceed the 16.67 ms budget for 60 FPS:

| Intermediate Mantle workload | Mean frame interval | p95 | Intervals above 50 ms | Paid matter / attempts |
|---|---:|---:|---:|---:|
| Low | 31.253 ms | 38.340 ms | 0 of 320 | 3,600 / 11 |
| Standard | 41.651 ms | 63.063 ms | 43 of 241 | 3,000 / 10 |

These rows used ordinary paid admission and recorded no unfocused frames, but differ in actual admitted matter and attempt count. They do not establish an isolated Low-versus-Standard speedup or a consistent improvement over the first-pass Mantle measurements. These measurements justified the subsequent shared-geometry and boundary work in the final source. [Retained-mesh Mantle receipt](performance-qualification-20261010/mantle-retained-mesh.json).

## Interpretation and remaining performance limits

Reparsing the earlier original-portable logs gives **15.00 FPS mean at Hearth** (22 observations, 14–16 range) and **1.94 FPS mean at Garden entry** (18 observations, 1–3 range). The earlier assessment discarded the first three observations; this reparse includes all observations. These are historical runs with different dates, duration, load and insufficient matched window-state evidence. Use the explicitly visible comparison above for the newer scoped comparison; do not mix these histories into a speedup ratio. [Historical raw-log reparse](performance-qualification-20261010/old-portable-all-samples.json).

The first intermediate implementation substantially reduced Garden submission cost, but still missed the frame budget. It predates even the first-pass merged Garden mesh, timer fast paths, HUD cache, and bounded character pages, so it is not a result for either qualified first-pass source or the second-pass candidate.

Failed qualification is retained rather than replaced: Full v1 stopped at a stale art-binding audit; v2 completed suite enumeration but correctly failed on three script errors in an incomplete synthetic character fixture; v3 stopped before engine work because the concise queue omitted its required current-roster declaration. The art audit now passes 328 checks, the repaired fixture passes 99,097 assertions, and the current-scope check passes. The fixture repair preserves every original motion/contact matrix and explicitly checks rejection of nonresident identities. [Fixture receipt](performance-qualification-20261010/actor-motion-fixture.json), [v1](performance-qualification-20261010/full-v1.json), [v2](performance-qualification-20261010/full-v2.json), [v3](performance-qualification-20261010/full-v3.json).

Frame-start intervals and elapsed callback timers are diagnostic measurements, not GPU duration or physical presentation/input latency. Godot's render-setup CPU monitor is also not a GPU timer. The benchmark's last-step simulation stages sample one completed fixed step per rendered frame; they do not sum every catch-up step.

The final benchmark clears stage records before every actual draw, including loading exits, and records callback serials and entry phases. Earlier cold-stage breakdowns could repeat a preceding frame and are invalid for attribution; their separately recorded frame/process/draw intervals remain historical diagnostics. Full observation retains detailed samples in memory, so its static-memory growth includes the observer itself. Light observation omits those stage dictionaries and marks unavailable metrics explicitly. Neither mode measures physical presentation.

The machine has approximately 7.28 GiB of usable RAM shared with its integrated Radeon graphics. The retained OS snapshots around the first broad native run reported approximately 824 and 1,099 MiB physically available; these are endpoint observations, not a continuous memory trace. No background applications, drivers, power settings, or user saves were changed. Hardware/load observations accompany comparisons; the result remains workload-specific. [Start snapshot](performance-qualification-20261010/native-os-start.json), [end snapshot](performance-qualification-20261010/native-os-after-v1.json).

The final source has passed Full v5, the independent pixel comparisons and the native measurement checks recorded above. Its portable export has passed smoke, standalone byte/inventory verification and packaged-terrain decoding, and has completed the visible four-case measurement. The preserved first-pass package remains distinct. These completed checks do not establish sustained 60 FPS or human playability acceptance; the heavy-field shortfalls are recorded above.

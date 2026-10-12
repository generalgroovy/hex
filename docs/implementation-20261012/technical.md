# Technical implementation and evidence — 12 October 2026

This ledger records implementation and local Windows qualification. The preserved release baseline is `p60-d8e6ea1cd808`; current edited source is a separate candidate. Passing a source test, pixel comparison, package check or instrumentation gate does not establish smooth gameplay or a frame-rate improvement.

The current [generated candidate](../../content/runtime/runtime_build_identity_v1.json) is **p60-845f85b5253e**, with 3,436 production records. Its [clean final Full](full-final.json) passed **260 suites / 7,331,212 assertions / zero failures**, with empty stderr; current-runtime identity checks, import and the 120 Hz configuration boot check also passed. The receipt's source identity, asset inventory and three log hashes were independently matched to the preserved `.godot/windows-tests/18b42abf09814ca6ac5307595d7d50c1` files. Fresh Windows package, standalone delivery, terrain-pack integrity and five-case normal-close/reopen lifecycle checks also **passed**. Source, tests and tooling are frozen. Focused and native component receipts below retain their own source scope; these local qualification checks do not establish performance acceptance. Interactive profiling retries have stopped; performance acceptance remains **OPEN**.

The preceding `p60-85b1eede354d` [diagnostic Full](full-second-failed.json) completed 260 suites and 7,217,428 checks with 636 failures across nine suites. Its original failed receipt and raw `.godot/windows-tests/e437172c91bd4bd6b97c80f172e7f0e0` evidence are preserved. Peer-reviewed source/test repairs were applied, including restoring corrupted display glyphs without weakening unbound-control expectations. The [13-suite repair run](final-repair-focused.json) then passed 1,967,421 checks with zero failures; that focused result does not erase the earlier failure or qualify the complete candidate.

The [package receipt](package.json) and [standalone file verification](delivery-files.json) describe `exports/hex-comprehensive-20261012`. Independent review matched all ten payload files and all ten unique ZIP members against the recorded lengths and SHA256s, checked both exported identity documents against the candidate, and verified the native smoke log's exact build identity and safe-close completion. Export and smoke stderr are empty. The ZIP is 161,146,185 bytes, SHA256 `e25f8e3e5abbf0c3a678b66b2ef1aa51b3f16a5f7de8996dfc8679f287e30539`; the copied documentation receipts match the original receipt bytes. The preceding `exports/hex-audit-overhaul-20261011` fallback remains available: its `p60-d8e6ea1cd808` PCK and ZIP still match their original package receipt. This is local portable delivery evidence; the installer was not run and no checkpoint was promoted.

The [exported terrain check](terrain-pack.json) passed **2,062 checks covering 132 chunks plus one overview**, or 133 decoded images and 140,378,112 RGBA bytes. The [copy/mount provenance](terrain-pack-provenance.json) binds the same final PCK and release identity to a byte-identical isolated copy, explicitly mounted after confirming the target resources were absent and no loose `assets`, `src` or `content` fallback existed. Independent review matched the receipt copies, nine recorded file hashes, ordered chunk extents and byte totals; the verifier's stderr is empty. This establishes exported resource integrity, not gameplay loading speed or memory savings.

The [actual release lifecycle](portable-lifecycle.json) passed all five sequential cases: Hearth, Garden, paid Fire, paid all-six Mantle and reopen. Both paid cases completed **12 admitted casts / zero refusals**. Every case records the exact candidate identity, normal window-close completion and empty stderr. Independent review matched all five raw log hashes, recounted the cast outcomes, checked the valid shared isolated preferences against every case's unchanged hash, and confirmed that the EXE, PCK and both identity files retain their pre-run hashes. Caller `APPDATA` was restored. Visible launch was requested; this receipt does not qualify foreground focus, frame pacing, physical input, earned progression, damaged-save recovery or replay export.

Two earlier lifecycle harness failures remain preserved. The [hidden-window attempt](portable-lifecycle-hidden-failed.json) stopped when the owned process refused the normal close request, with no completed cases. The [first visible attempt](portable-lifecycle-parser-failed.json) completed Hearth and Garden before its log reader incorrectly required a spell wire on a non-cast event; its original Fire log contains clean normal close, empty stderr and 12 admitted casts. The bounded helper corrections changed window visibility and restricted spell-wire lookup to cast outcomes; malformed cast outcomes still fail. Their original helper hashes match the failed receipts. Neither failed harness receipt was rewritten as a pass or attributed to a game defect.

| Plan area | Implemented candidate | Evidence available | Remaining gate |
| --- | --- | --- | --- |
| 1. Measurement reliability | Exact owned HWND and physical client dimensions; sampled foreground/visibility checks; separate opt-in single foreground request; optional Start button and manual arming before game instantiation; run/case/workload/phase metadata; bounded light/full recording; raw failed-run retention | 147 source-only assertions pass: 35 window/foreground, 54 manual-arm boundaries, 8 portable log/phase, 50 profile admission; root independently repeated the same checks. Native observation-budget check: 7 assertions, zero failures, empty stderr. Independent source review approved the arming boundary repairs and explicit Start event; reviewer separately ran all 54 arming checks. Native Start event observed, but the resulting run failed viewport/focus admission | Actual comparable runs with admitted size/focus/workload. Present timestamps remain unavailable; performance acceptance OPEN |
| 2. Retained campus drawing | Opt-in six bounded CanvasItems in existing painter order; ordinary launches use the immediate renderer; live landmark animation and proximity invalidation; detached rebuild/timing counters | 19 focused assertions pass. Native Godot 4.7.1: 40 first-frame comparisons, zero RGBA mismatches, empty stderr. Independent key/ownership, Bootstrap integration and default/CLI precedence source reviews completed | Opt-in retained Bootstrap frame/lifecycle exercise; matched foreground-qualified performance comparison. Final portable lifecycle used the ordinary immediate path. No demonstrated speedup; performance acceptance OPEN |
| 3. Loading and memory diagnosis | Optional fixed-key terrain stage timers for ready retrieval, pixel validation, texture creation, retention trimming and request submission; bounded request-to-observed-ready latency; sampled process private/working-set bytes | Clean focused rerun: 349 terrain assertions, zero failures and empty stderr. Full 132-chunk bake completed in 6.848 seconds; chunk and overview bytes unchanged, manifest provenance updated by the actual bake. Final exported pack passed 2,062 integrity checks for all 133 images | Cold/travel/warm measured results; no loading-speed or memory-saving claim |

## Measurement boundaries

[The shared window policy](../../scripts/measurement-observation.ps1) accepts only owned physical client dimensions, visible and non-minimized windows, and matching foreground HWND/PID at every available observation. Contiguous unavailable-handle observations at startup or shutdown are retained and counted separately. Missing interior windows, unknown/incorrect foreground, wrong client dimensions, malformed ordering, or an interior observation gap greater than two seconds reject qualification. At least three available samples spanning one second are required. Approximately 500 ms samples are **not continuous focus or unobscured-presentation proof**.

The [native helper](../../scripts/flux2-common.ps1) temporarily sets only the observer thread's DPI context while reading the client rectangle, then restores it. It records client pixels independently of outer decoration. This follows the Windows contracts for [GetClientRect](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getclientrect) and [SetThreadDpiAwarenessContext](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setthreaddpiawarenesscontext). Neither the game's DPI configuration nor system settings are changed.

`-RequestForegroundOnce` is explicit and defaults off in the wrappers. With that option, the checked runner requests activation only once, after confirming the process owns its nonzero main-window handle. The request, native result and elapsed time are recorded separately from the read-only observations. No retry or input synthesis is used; actual sampled focus still gates the result. The source profiler uses one engine-side request when neither the external option nor manual arming is selected. Normal close, warning/stderr rejection, exact payload identity and finite paid-workload checks remain active.

The source wrapper's opt-in `-WaitForForeground` shows a **Start performance test** button before it constructs the game. A real button event (mouse click or keyboard activation) must occur before the existing one-second sampled-focus interval can start; engine focus alone cannot trigger it. The button disables after confirmation. The entire setup still has a 60-second monotonic deadline and resets stability after ineligible focus, dimensions/visibility or a poll gap above 250 ms. At most 601 engine setup observations are retained, at least 100 ms apart. The receipt records UTC and monotonic setup, manual-confirmation, arm and game-instantiation boundaries; every case also records its own start. Missing confirmation, a confirmation inside the claimed stable interval, timeout or a missing arm fails and retains its partial report. No input is synthesized.

Every original Windows row stays in the receipt. An explicit phase index labels rows before the UTC arm boundary **setup**, with their own diagnostic assessment, and rows at/after that boundary **measurement**. Setup cannot inflate the required three post-arm samples or one-second span. Both the first post-arm delay and the original gap across the arm boundary must fit the existing two-second sampling limit; contradictory raw setup records, a missing endpoint, clock divergence or late arming reject admission. Engine focus polls and focus-exit events cover post-arm preparation and inter-case warmups as well as measured cases. These checks corroborate sampled focus; they do not prove unobserved intervals. The cold game-start row excludes process launch, empty-window setup, user waiting and provenance hashing. The frozen d8 portable has no pre-instantiation arm; its existing whole-run focus policy remains unchanged.

[The actual-portable wrapper](../../scripts/measure-portable.ps1) still measures one-second engine FPS output, not present timestamps or input latency. It records the requested 12 attempts and admitted/refused events separately. Its phase annotations describe stdout order around the first/last attempt only: FPS windows may straddle those anchors, and paid effects can remain after the final attempt. It does not relabel that time as idle or infer an active-only FPS average. At most 8,192 recognized stdout records enter observation arrays; overflow retains a failed prefix and the complete raw log. Input script hashes and EXE/PCK/BUILD-STATE hashes are bound before and after the run.

[The native-source profiler](../../scripts/profile-gameplay.gd) enforces 12,000 callback record groups per stream per case and 120,000 across a run. Both light and full modes reject overflow, retain partial evidence and stop; neither silently drops or subsamples records. One group may contain aligned scalar/context arrays. Copies and JSON serialization consume additional transient memory beyond the group counts. Light mode leaves detailed stages unavailable, while keeping focus, dimensions, payment, tick progression and workload checks. Full instrumentation remains an observer with cost of its own.

PATH and named install directories were checked read-only. No PresentMon/CapFrameX executable was found in those checked locations; Windows Performance Recorder was present. This is not a complete installation inventory, and no capture, download or service installation occurred. A verified [PresentMon](https://github.com/GameTechDev/PresentMon) trace is still a separate future gate. The controlled, workload-specific approach follows Riot's [real-world League performance profiling](https://www.riotgames.com/en/news/profiling-real-world-performance-league); it does not imply H.E.X. has League's renderer, workload or performance.

## Preserved failed baseline

The [newly gated frozen d8 Mantle run](baseline-d8-window-gated/measurement.json) used the actual exported EXE/PCK, normal window close after 45 seconds, and the full finite 12-cast workload. All 87 available window observations had the correct owner, visible non-minimized state and exact 1280×720 client dimensions. **Zero of 87 were foreground.** All 12 casts were admitted and none refused; this does not override the focus failure.

The engine's mean reported FPS was 44.23. That number is retained diagnostic evidence and is **not an admitted baseline for a candidate speedup claim**. The original raw logs and failed status remain unchanged. It predates the optional external foreground request and cannot qualify that later wrapper revision.

The first later source reference run also failed the independent Windows gate: all 73 post-arm available observations showed another foreground process, despite 1,301 engine focus samples reporting focus and no focus-exit event. Its earlier focus-only arming started automatically after about one second. That failed run remains diagnostic evidence; it motivated the explicit Start button. The independent Windows gate remains mandatory and unchanged.

| Preserved source attempt | Observed outcome | Qualification |
| --- | --- | --- |
| [Initial reference](profile-reference-first/summary.json) | Earlier focus-only arming; zero of 73 available post-arm Windows samples foreground | Failed foreground admission |
| [Manual Start reference](profile-reference-manual/summary.json) | Actual Start event and arm received. The client changed from 1280×720 to 1920×1057 during `garden_middle`; 8 of 44 available post-arm samples had incorrect size, and 7 were unfocused. The intentional viewport failure retained a partial report and stderr | Failed viewport/focus admission; no matched comparison |
| [Fixed reference attempt](profile-reference-fixed/summary.json) | No Start confirmation or arm; bounded setup stopped at 60.012 seconds, preserving the partial report and all setup observations | Failed manual-start admission; no measured gameplay |

Interactive retries stopped. These files retain their original failed status; no row from them establishes a speed gain, a stable frame rate or completed performance acceptance.

## Retained campus contract

[RetainedCampusCanvas](../../src/presentation/retained_campus_canvas.gd) holds exactly six ordered child CanvasItems: ground/floor craft, activity/arena, buildings, landmarks, stations and district labels. It sits behind the existing gameplay drawing. [SanctumCampusRenderer](../../src/presentation/sanctum_campus_renderer.gd) exposes those same ordered phases for the immediate path. Paid material, actors, visibility masks and UI remain outside this cache.

Ordinary game launches use the established immediate renderer. The experiment requires `--retained-campus`; `--reference-campus` takes precedence if both flags are present. The profile wrapper passes `--retained-campus` explicitly for its candidate mode and `--reference-campus` for `-ReferenceCampus`, then checks the observed mode in every result. Component pixel correctness has passed, but the experiment stays opt-in because its frame-pacing benefit is unproven.

Content/renderer generation, style, font changes and exact culling view invalidate retained commands. Focus additionally invalidates practice instructions, landmark opacity and station presentation; context invalidates arena labels; animation tick invalidates landmarks. Reduced ambient motion has no tick invalidation. Ground residency/upload changes invalidate the ground layer. Map/renderer reconfiguration advances a generation; an explicit `invalidate()` supports admitted in-place presentation changes. Direct unannounced mutation of authored dictionaries is outside the retained ownership contract.

This uses Godot's documented [cached custom drawing commands](https://docs.godotengine.org/en/4.6/tutorials/2d/custom_drawing_in_2d.html#updating), not a render-to-texture replacement. The exact original culling rectangle is retained, so moving the camera can rebuild static layers. No overscan or coarser visibility is assumed. Expected stationary reuse is an implementation hypothesis until measured on the supported Godot version and this PC.

[The native comparison](../../scripts/verify-retained-campus.gd) checks two 512×384 views after the first submitted frame of changed states: 75%/100% transforms, animation, proximity, detail/title/context changes, reduced effects, fractional camera changes, and hide/reactivation. A live foreground drawing witness tests painter order. It compares current immediate and retained source paths, not an independent historical renderer. Empty or lagged rendering must not be treated as a speedup. Retained child draw timers sit **outside Bootstrap's own `_draw` timer**; their reduction cannot be inferred solely from a smaller Bootstrap draw duration.

The source wrapper accepts `-ReferenceCampus`, which selects `--reference-campus` and checks the actual renderer mode in every report row. Full mode records before/after counters for each of the six layers: redraw requests, actual callbacks and elapsed draw-command generation microseconds. It also records aggregate preparation calls/time inside `_process`. Light mode retains only those fixed counters, disables child timers, and marks preparation time unavailable. These are overlapping diagnostics, not a sum of total CPU or GPU work. Source tests reject mismatched modes, missing/extra layers, regressing or nonfinite counters, child work in reference mode and active child timers in light mode.

Local engine evidence: `.godot/wave-a-integration/network-retained-balance-repair.log` contains the 19-assertion retained suite; `.godot/retained-campus-native-20261012/receipt.json` records the 40 exact pixel comparisons. The native receipt checks its scoped source hashes before/after. These component checks do not cover every Bootstrap state transition or establish a speed gain.

## Loading contract

[Terrain instrumentation](../../src/presentation/wellspring_terrain_stream.gd) is optional and aggregate-only, with five fixed stage keys and at most two pending request timestamps. It keeps exact pixel validation, ordinary upload/time/byte budgets, culling and final request-token cleanup. A reset changes only diagnostic state. Request-to-observed-ready latency includes decode, polling and scheduling; it is not worker CPU decode time. Texture creation includes driver work and is not GPU execution time.

The terrain-stream source is an existing bake-provenance input. The normal full bake ran after this edit and emitted all 132 chunks plus the overview. Root compared the binary results with the preceding assets: only the manifest provenance changed. The local bake log is `.godot/wave-a-integration/terrain-bake.log`, with empty stderr. The clean 349-assertion terrain result is in `.godot/wave-a-integration/joined-journey-repair3.log`, with empty stderr; that invocation also passed avoidance and signature progression suites. The earlier `range-audio-ui.log` invocation remains failed evidence with its separate Range compilation error and teardown warnings. No manually invented provenance update qualifies.

## Rejected snapshot size-witness experiment

[The bounded producer probe](../../scripts/profile-producer-size-witness.gd) uses the current full map, two/eight actual actors and ordinary paid commands. It alternates seven measured consume pairs after one warmup, compares exact snapshot/packet bytes and source/state hashes, and separately times the concrete production capture/pack factory. Construction, input copies and validation remain outside the consume timer. The factory and consume timings overlap and must not be added. These headless microbenchmarks exclude ENet, rendering and physical presentation.

Reusing the encoder's private encoded-size result passed exact-byte/authority checks but showed **no reliable timing benefit**, so the production change and its dependent tests were removed. The original repeated size validation remains. The diagnostic script and both original receipts remain for review.

| Fixture | Encoded chemistry bytes | Factory median before → experiment (ms) | Same-run reference → experiment consume median (ms) |
| --- | ---: | ---: | ---: |
| 2 actors, idle | 211 | 30.572 → 31.847 | 13.577 → 14.139 |
| 2 actors, 180 paid ticks | 2,646 | 44.793 → 46.654 | 19.301 → 19.689 |
| 8 actors, 180 paid ticks | 8,261 | 73.460 → 77.974 | 32.029 → 32.630 |

Both strict runs completed with zero failures and empty stderr. The receipts are local `.godot/producer-size-before-20261012.json` (SHA256 `bd7bfa09309250747a246ed9421d4dd8ce917b008d6dd173f5a30502ef47b504`) and `.godot/producer-size-after-20261012.json` (`219aa3ce000b396a9b89c612ab425ebbba5a14c4dd1f2a71fb82b9dc84870c62`), 6,991 bytes each. They bind their own source snapshots; the after receipt describes the now-reverted experiment. The seven-sample results do not establish a regression rate or gameplay performance. They do reject treating one avoided serialization of these small payloads as a demonstrated optimization. Profiling reconstruction, validation and hashing stages is a later diagnostic step, before another production rewrite.

## Reproducible gates

From the repository root, the source-only measurement check is:

```powershell
& ./scripts/test-gameplay-profile.ps1
```

Root owns every engine invocation. The new recorder test uses the existing checked runner:

```powershell
. ./scripts/flux2-common.ps1
$hexRepo = Get-FluxRepoRoot
$hexEngine = Get-FluxGodot
Invoke-FluxGodotChecked $hexEngine @('--headless', '--path', $hexRepo, '--script', 'res://scripts/test-gameplay-observation-budget.gd') '<fresh-log-path>' -RejectWarnings -TimeoutSeconds 90
```

After preserving terrain binary hashes, the actual bake command through that runner is:

```powershell
Invoke-FluxGodotChecked $hexEngine @('--headless', '--path', $hexRepo, '--script', 'res://scripts/bake_wellspring_terrain.gd') '<fresh-bake-log-path>' -RejectWarnings -TimeoutSeconds 600
```

Then run the registered `retained-campus-canvas` and `wellspring-terrain-stream` suites. The native comparison requires an isolated `APPDATA`, the resulting exact Godot user-data path and a fresh absolute output directory:

```powershell
Invoke-FluxGodotChecked $hexEngine @('--path', $hexRepo, '--script', 'res://scripts/verify-retained-campus.gd', '--', '--no-lan-discovery', '--verify-user-data=<exact-isolated-Godot-user-data>', '--output=<fresh-absolute-output-directory>') '<fresh-native-log-path>' -RejectWarnings -VisibleWindow -TimeoutSeconds 180
```

For a future performance comparison, use separate fresh output directories for matched `profile-gameplay.ps1` runs with and without `-ReferenceCampus`; keep quality, case order, duration, dimensions, arming policy and light/full observer mode identical, then repeat the order in reverse. This is a reproducible method, not a request to restart interactive retries during the current final Full/package qualification. `-WaitForForeground` gives the user up to 60 seconds to activate **Start performance test** and keep the visible window in front before the game starts. `-RequestForegroundOnce` is a separate optional request, not proof of successful focus. The comparison below remains unqualified:

```powershell
& ./scripts/profile-gameplay.ps1 -OutputDirectory '<fresh-reference-output>' -Profiles low -Cases garden_middle,paid_all_six_mantle_sustained -SecondsPerCase 12 -FrameLimit 60 -Width 1280 -Height 720 -WaitForForeground -ReferenceCampus -TimeoutSeconds 240
# Repeat to another fresh output without -ReferenceCampus, then reverse order.
```

Default runs require every available sampled observation to remain foreground; armed runs require every post-arm available observation. Failed focus runs remain evidence without becoming accepted comparisons.

The shared engine watchdog now permits an explicit maximum of 3,600 seconds. Its default remains 180 seconds; the Full/Release test wrapper requests 2,700 seconds to accommodate the complete suite, including the full-map network and paid-balance additions. The clean final Full receipt records 1,595.989 seconds overall. Focused, boot, profile and portable budgets remain independently bounded. This changes supervision time, not simulation or performance acceptance limits.

Acceptance requires unchanged tested RGBA pixels, live labels/animation, no warnings or leaked resources, bounded resources, and a matched measurement with unchanged workload, dimensions, focus admission and observer mode. If pixels, lifecycle or workload gates fail, keep the immediate reference path active. If timings show no reliable benefit, report that result and leave the retained implementation opt-in; structural reuse alone does not justify a performance claim.

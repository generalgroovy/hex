# Independent D5 frozen draw-component review

Status: **REVIEWED; valid bounded diagnostic, no production change or performance acceptance.** Reviewed the two test-only harness/profiler files, `.godot/hex-draw-components-hash-v2.json`, logs, and all twelve control PNGs. Reviewer owns only this document and ran no engine operations or source edits. The frozen runtime remains `p55-a9837cac9e8c`.

## Evidence verification

V2 reports **PASS: 2,095 assertions, zero failures and zero-byte stderr**, with four populated case/mode views and **32 measured draws each (128 rows)**. Independent checks matched all **23 source SHA-256 values** to disk, including the unchanged frozen chemistry world and production Bootstrap/presenters.

For all 128 rows, this reviewer verified sequential indices, component call counts, nonnegative residuals, and the exact identity `sum(eight component durations) + residual = total_draw`. Each row has one campus, ground, HUD, POV-mask, combat-cue and legacy-chemistry call. Distributed views have one actor-body and six projectile calls; dense views have eight actor-body and four projectile calls. The passing profiler also checks projectile call count against the actual frozen world's projectile list. All **44 raw series** match their row values, and every series' nearest-rank p50/p95/p99/max recomputes correctly. With 32 samples, p99 is the observed maximum.

The original, timer-subclass-disabled and timer-subclass-enabled controls are **identical complete 1280x720 RGBA pixel bytes for every view**. Independent PNG decoding reproduced all twelve recorded RGBA SHA-256 values. Each view's three PNG files are also byte-for-byte identical, not merely visually similar. Thus the timing instrumentation preserved the tested rendered output; this does not quantify its timing overhead.

V1 remains **FAILED before measurement**: its stderr records a runtime assignment of untyped Array to Array[String] in the mode ternary at profiler line 51. The failed source copies and process-identity termination record are retained under `failed-draw-v1/` and `draw-components-v1-termination.json`. V1 supplies no valid component timing evidence. Current source constructs a typed mode array and reverses it for the dense case.

## Workload and ownership limits

All views freeze at **tick 160**, after the existing 120 neutral plus 40 paid ticks, on the genuine **2,766-cell campus with eight actors**. Distributed state has seven admissions / 4,200 paid matter / 57 active cells; dense state has eight admissions / 4,800 paid matter / 29 active cells. Conservation is checked before drawing. Normal and reduced views of each workload retain the same world hash, and the profiler verifies the frozen authority hash after controls and every measured draw. No simulation advances during the observations.

The inherited production Bootstrap draw body is not copied. Typed subclasses wrap the unchanged production calls; component call sites are pairwise disjoint within that body. An active owner-canvas guard excludes other canvases and one-time backdrop work. Counters reset per draw, and each observation requires exactly one requested draw. The four control warmups per arm are outside the measured sample arrays.

These are **synchronous CPU draw-submission measurements of frozen states**, not GPU time, the simulation, actual player input, the entire presentation frame, or a decomposition of the earlier 720-tick rendered stress workload. Timers, virtual dispatch, counters and unmeasured production work contribute to the residual; instrumentation perturbation is unquantified. `present_elapsed` additionally includes scheduling/render completion and cannot be added to draw time. Component percentiles cannot be summed.

## Measured component medians

Values are microseconds. Column order follows the actual case/mode run order.

| Component | Distributed normal | Distributed reduced | Dense reduced | Dense normal |
| --- | ---: | ---: | ---: | ---: |
| Campus | 1,913 | 2,146 | 1,913 | 1,901 |
| Hex ground | 24,861 | 25,698 | 28,773 | 28,837 |
| Actor bodies | 233 | 216 | 940 | 1,139 |
| HUD | 1,107 | 1,259 | 1,236 | 1,277 |
| POV mask | 5,908 | 5,986 | 5,514 | 5,483 |
| Projectiles | 660 | 637 | 445 | 407 |
| Combat cues | 11 | 10 | 10 | 10 |
| Legacy chemistry | 6 | 5 | 6 | 6 |
| Residual | 1,155 | 1,192 | 2,261 | 2,217 |
| Total draw | 36,057 | 37,203 | 41,280 | 42,267 |
| Present elapsed, separately observed | 70,457 | 80,385 | 85,708 | 82,478 |

Hex-ground work is the largest measured synchronous call bucket in these views. Its normal-mode median is **24.861 ms distributed and 28.837 ms dense**, while total draw medians are **36.057 ms and 42.267 ms**. This identifies a concrete follow-up target; it is not an optimization result or sustained-performance acceptance.

## Visual inspection and recommendation

The reviewer displayed all four enabled normal/reduced frames with the image tool; exact pixel/file equality binds them to the original and disabled controls. The distributed fixture places most geometry/actors outside the visible local view, with some active Earth coverage at the lower-left edge; dense frames show multiple actors and whole-hex Earth/Fire/Water/Air coverage. HUD, campus and POV masking are present. No instrumentation-induced visual difference or missing control image was found. These stills are evidence of the arranged frozen views, not navigation quality, motion comfort, animation acceptance or a human-approved art style.

Recommendation: retain this diagnostic as evidence supporting one bounded test-only investigation of Hex-ground work. Any render-bundle candidate needs fresh exact-output/authority/ownership checks and a measured comparison before production integration. The earlier rendered deadline failure, exact-EXE lifecycle gap, physical-device tests, networking/capacity and human approval remain open. No remaining blocker was found in the validity of this D5 receipt within its stated scope.

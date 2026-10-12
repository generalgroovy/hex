# Native performance evidence — 12 October 2026

**This implementation does not establish smoother overall frame pacing or 60 FPS.** The final source is `p60-d8e6ea1cd808`. Its native run completed with the requested viewport, unchanged source and empty stderr, but substantial focus loss makes it a diagnostic record. Keep implementation correctness, exact pixels, native timing and portable acceptance as separate gates.

The [comparison JSON](native-performance-comparison.json) preserves source identities, exact raw-file SHA256s and byte lengths, per-case counts, visible-field partitions, stage costs, cold arrivals and the earlier soak. Full per-frame arrays remain local under `.godot/audit-overhaul-20261011/{baseline,candidate,final-candidate}/metrics.json`. The corresponding `summary.json` is the wrapper receipt; there is no separate `receipt.json`.

## Observed frame pacing

All rows used Godot 4.7.1, Windows, the Low profile, the Compatibility renderer through ANGLE on AMD Radeon graphics, a 60 Hz display, a 60-frame cap and an actual 1290 × 730 window. Each warm case lasted approximately 10 seconds. Values are **mean / p95 process-start interval in milliseconds**; they measure callback cadence, not physical presentation or input latency.

| Case | Baseline `33606f` | Intermediate `3a7e6f` | Final `d8e6ea` | Final unfocused / process frames |
| --- | ---: | ---: | ---: | ---: |
| Hearth idle | 19.99 / 27.07 | 20.73 / 24.31 | 22.68 / 28.20 | 0 / 443 |
| Element Garden | 18.61 / 25.36 | 20.89 / 27.97 | 21.28 / 27.07 | 438 / 471 |
| All-six Mantle | 29.22 / 35.75 | 34.88 / 45.23 | 34.72 / 42.58 | 290 / 290 |
| Movement route | 21.53 / 31.12 | 23.06 / 30.43 | 22.63 / 32.74 | 444 / 444 |
| Close Fire (12 attempts) | 27.79 / 53.24 | 30.41 / 46.07 | 30.52 / 48.99 | 329 / 329 |
| Sustained Fire | — | 31.55 / 40.48 | 33.90 / 50.15 | 238 / 296 |
| Sustained Mantle | — | 34.84 / 42.48 | 34.69 / 42.70 | 0 / 290 |

Final average callback cadence ranged from **28.80 to 47.00 Hz** across these cases. Warm simulation advancement remained approximately 120 ticks per second, with zero reported clamped or dropped time. A healthy simulation clock does not establish smooth rendered motion.

The comparison has material limits:

- The baseline wrapper failed because it requested 1280 × 720 and received 1290 × 730. Matching later runs to its actual viewport preserves a useful diagnostic comparison; it does not turn that failed receipt into a pass.
- Both candidate runs used the same profiler script SHA256, `631ab1ff0ebbcc7165b6223c783644c4c9b16400ec9eae4d235a7594448f4ed7`. The baseline observer differed. New preparation and per-draw region counters add observation cost; the small reported head/tail observer timer excludes nested Court/Bootstrap/SimWorld instrumentation.
- The final wrapper's `measured` status checks completion, source, viewport and logs, **not continuous focus**. Its 1,739 unfocused process frames are retained above. The baseline and intermediate warm cases had no recorded focus loss.
- Available OS RAM before the runs was 1,295.06 MiB, 1,585.01 MiB and 632.62 MiB respectively. Paging, thermal state and other desktop load were not controlled or attributed.
- Final paid Hearth cases required 12 terrain chunks, versus 15 in the intermediate run. Focus-sensitive camera state can change visible work. Small timing changes cannot be assigned to one cache change.
- These are single sequential observations, not repeated randomized trials. Short-run tail values are especially variable.

## Paid-field cost and preserved coverage

The final all-six Mantle Court averaged **5.17 ms per draw**: geometry 0.11 ms, live bundle preparation 1.85 ms and drawing/other work 3.21 ms. Court remained the largest individual measured draw layer; campus/setup was 2.41 ms and the combat HUD 1.89 ms. This Mantle row was unfocused, so these identify where work remains rather than prove a regression's cause.

Close Fire averaged **8.08 ms while paid ground was visible**, with a 13.51 ms p95. Its all-draw mean was only 4.13 ms because roughly half the draws had no visible paid ground. The corresponding visible-field means/p95s were 8.32/16.61 ms at baseline and 8.38/13.82 ms in the intermediate run. The final decrease is small and confounded by focus/camera changes. Whole-case averages must not be presented as active-casting performance.

Close Fire admitted all 12 ordinary attempts and spent 7,200 Matter in every run, with a maximum of 30 paid cells. Mantle recorded 11 attempts, 3,600 Matter and 33 cells in all three runs; baseline admission/refusal fields are absent and remain null in the JSON. Sustained scenarios use ordinary finite resources, report refusals, and never refill during measurement.

The final refinement retains exposed-edge masks for the same immutable boundary-count result. Every reuse still checks the current owner/phase/danger/lifetime prefix and exact ordered polygon; external count maps and changed inputs use the original calculation. Storage is capped at eight topologies and 512 masks per topology. The final close-Fire case alone added **13,648 mask hits and 2,028 mask builds**; the cumulative endpoints are preserved in the JSON. Compound cache lookups also avoid repeated `has()` followed by indexing. These counters show repeated work was removed; they do not establish a particular frame-time improvement.

The [focused test log](final-focused.log) records 6,490 paid-field assertions and 11,254 polygon-cache assertions with zero failures. The unchanged [native exact-RGBA gate](paid-pixels-final.json) passed **614 comparisons, including 176 paid-sequence comparisons**, with zero failed comparisons and unchanged source during capture. No draw commands, painter order, widths, colors, hazard coverage or authority were changed by the mask refinement.

## Streaming, startup and sustained observation

Synchronous startup was 8.28 seconds at baseline, 7.29 seconds intermediate and 8.40 seconds final. Initial ready-arrival phases then took 0.59, 0.58 and 0.64 seconds. First Garden travel arrival took 0.59, 0.85 and 0.90 seconds. These are process-cache conditions, not flushed OS-cache measurements; they do not demonstrate a load-time improvement.

Streaming limits queued work to a 2 MiB byte budget and a 2 ms target between operations. An indivisible validation/upload can exceed 2 ms; subsequent admissions then stop. Destination prefetch is bounded and does not authorize travel or skip verification. The final arrival still contains long frame intervals, so the budget must not be described as a hard hitch-free guarantee.

The earlier **60-second Garden soak belongs only to `p60-3a7e6f5fee64`**. It measured 19.70/25.10 ms mean/p95 and 50.76 Hz average callback cadence with no focus loss. Terrain requests/uploads, residency and texture bytes stayed unchanged. Static memory rose 16,424,066 bytes while the profiler accumulated raw sample arrays; this neither establishes a production leak nor proves stable production RAM. It is not a final-source endurance receipt.

## Actual release executable and shutdown qualification

The exported **p60-d8e6ea1cd808** subsequently passed four runs of its actual
EXE/PCK with normal window closing requested after 45 seconds. The
[complete measurement](portable-measurement.json) retains payload hashes,
per-case arguments, memory observations, every emitted FPS line, window samples,
cast events and safe-close evidence. The game and package bytes were unchanged.

| Release case | FPS samples | Mean / lowest reported FPS | Paid casts admitted / refused | Foreground / window observations |
|---|---:|---:|---:|---:|
| Hearth | 28 | 59.82 / 59 | 0 / 0 | 87 / 88 |
| Garden entry | 31 | 60.00 / 60 | 0 / 0 | 89 / 90 |
| Finite Fire | 31 | 55.65 / 31 | 12 / 0 | 89 / 90 |
| Finite all-six Mantle | 31 | 46.74 / 38 | 12 / 0 | 89 / 89 |

All 354 available-window observations were foreground, visible and nonminimized.
The other three observations had no available main window at startup or shutdown;
they do not record an observed foreground loss. Sampling about every 500 ms does not prove continuous
focus or physical presentation. Available RAM before this run was 850.54 MiB.
The requested resolution was 1280×720; this helper does not verify actual client
dimensions. Its one-second engine FPS samples are different from the instrumented
process-start intervals above. Process wall time includes startup/teardown that
need not emit an FPS line, and the samples contain idle after finite casts.
They establish neither a controlled before/after gain nor sustained 60 FPS.

The earlier [iteration-limit run](portable-forced-exit-failed.json) retained zero
foreground samples and failed its strict warning gate: after twelve paid casts,
Fire/Mantle reported seven/six audio objects alive at exit. A verbose Fire repeat
identified AudioStreamWAV and AudioStreamPlaybackWAV instances. The subsequent
[normal-close probe](portable-window-close-probe.json) recorded twelve paid casts,
exit 0, safe-close markers and zero stderr on the same executable. Normal close
then passed for all four cases. Neither the game nor the warning filter was
changed. The measurement wrapper's opt-in normal-close mode uses the existing
owned-process watchdog, rejects premature exit or rejected close requests,
requires the safe-close marker, and now requires all twelve admitted/refused
events for a paid case. The old failed evidence remains available.

Godot's [audio-exit issue #95484](https://github.com/godotengine/godot/issues/95484)
documents related reports in other versions. It provides context only; it does
not establish the cause of H.E.X.'s observed shutdown-path difference.

## Bounded next step

First compare focused, identical-camera full/light observer runs with repeated ordering and stable machine conditions. This separates observation cost and visible workload from source changes before assigning causes.

Godot documents that CanvasItem `_draw()` commands are retained until `queue_redraw()` requests another draw, which supplies the engine mechanism for this experiment. [Godot 4.6 custom drawing documentation](https://docs.godotengine.org/en/4.6/tutorials/2d/custom_drawing_in_2d.html#updating).

For the next implementation experiment, isolate one unchanged campus or HUD layer in a retained CanvasItem so its drawing commands can survive between frames while paid Court, health, readiness and danger remain live. Campus/setup and HUD still consume recurring draw time despite descriptor/layout reuse. Keep a strict residency bound and exact invalidation inputs, require the same pixel gate, and retain the experiment only if repeated same-scene CPU and frame costs improve. This remains a proposed experiment, with its benefit on this game's Godot 4.7.1 build unmeasured. The present evidence does not justify removing paid regions, reducing the 120 Hz authority clock, or claiming a GPU bottleneck.

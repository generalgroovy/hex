# Ignored terrain worker experiment

This archive qualifies the isolated worker prototype's exact bytes; it does not establish whole-game frame pacing. Subsequent actual Bootstrap routes passed and root accepted a staged production promotion, still subject to checks on the promoted source. The original runtime base remains unchanged and canonical promotion has not yet been applied at this documentation checkpoint.

[review.json](review.json) independently recomputes the two native receipts. [archive-manifest.json](archive-manifest.json) records 32 byte-exact evidence/source payloads, totaling 14,992,922 bytes. The analysis source is included. The archived proposal README predates execution; this file and the review record describe the later gates.

The real-worker functional run passed **162 checks / 10 cases / zero stderr**. It uses genuine semaphore-gated tasks and exact ImageTexture readbacks with synthetic loader tokens and a synthetic pump clock. Full and cropped pixels, mutable source-image isolation, first/middle/last corrupt bytes, sticky cancellation and same-ID reentry, suspension/reconfiguration, metadata drift, retrieval overrun and an injected non-disposing join error are covered. All 26 actual task joins and every loader collection are accounted for. A successful reconfiguration resets its public per-generation counters, while the fixture's actual join accounting survives that boundary.

The native comparison passed **76,844 checks forward** and **77,109 reverse**, each with 64 fresh-stream cases, eight early camera-demand traces and two cancellation controls, all with empty stderr. Each view has 12 measured sequential arm pairs across the two processes; two warmup cycles per process remain in the raw files. The exact predecessor and worker receive the same views and all retained endpoint texture pixels match the manifest.

| Required view | Whole arrival/halo pump p95, old → worker | First-ready pump count mean | First-ready wall mean | All-phase main-pump elapsed mean |
| --- | ---: | ---: | ---: | ---: |
| Garden, six tiles | 5.339 → 2.073 ms | 9 → 7.5 | 396.761 → 316.152 ms | 155.967 → 42.919 ms |
| Large, 28 tiles | 5.149 → 2.053 ms | 42.333 → 30.75 | 1,815.618 → 1,281.289 ms | 322.226 → 89.271 ms |
| Cropped edge, one tile | 5.969 → 1.931 ms | 2 → 3 | 87.733 → 124.456 ms | 31.192 → 9.195 ms |
| Full, one tile | 4.703 → 2.163 ms | 2.083 → 3 | 85.616 → 126.647 ms | 72.284 → 20.765 ms |

The first-ready counts above add one to the raw zero-based completion index. P95 pools pump calls through the full halo drain; it is not a gameplay-frame percentile. Main elapsed includes the complete fixed arrival/warm/walking/drain sequence and may include scheduler or driver waits; these are not thread CPU counters. Worker elapsed is recorded separately and may overlap the main thread or include descheduling; neither adding nor subtracting it yields a frame or total-CPU measurement. Native constructors/configuration and endpoint pixel readback are outside pump clocks. OS/driver/resource cache history is uncontrolled.

Both invocation-order strata retain the direction of the larger-view improvement and the one-tile latency penalty. The cropped predecessor's 25.542 ms wall-time outlier remains in the data. Fully drained walking traces have zero missing-ready samples in either arm. Early camera-demand traces generally have fewer missing-ready samples with the worker, but Garden's first worker trace has a longest unready run of four versus three in its reference. These are fixed camera rectangles, not actual player movement.

Stored validation payloads reach 2 MiB and the conservative copy/reconstruction overlap reaches 3 MiB. These are logical byte counts, excluding hash contexts, worker-pool storage, allocator/COW behavior, resident textures and GPU-driver memory. They are not process RSS or a hard physical-memory ceiling. Two combined loader/worker owners and exact final joins remain enforced.

**Subsequent route gate:** the [independent actual Bootstrap review](../terrain-worker-bootstrap-walk/review.json) records Garden arrival at 27 paused callbacks in both arms and Verdant at 17 → 18, with equal 480-command routes, authority/packet/image endpoints, no later walking pauses and complete normal-close ownership. Worker tasks close 36/36 and 35/35. The earlier pending-route status inside `review.json` describes its immutable archival checkpoint, not the latest decision.

**Current decision:** stage the named async subclass and task helper for promoted-source qualification. Do not hide the single-tile polling penalty, claim a hard 2 ms limit, or infer foreground, physical-input, GPU or FPS acceptance. The stage also corrects a newly found diagnostic capture-reset edge; the task's old interval is excluded after a new profile epoch. That change requires its own blocked-worker regression and is not presented as already exercised by this historical prototype comparison.

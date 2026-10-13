# Garden arrival validation experiment

Status: primitive comparisons passed; bounded production prototype in progress.
Owner: technical implementation, root tests. Technical reviews clocks/lifetime, experience reviews arrival and
walking behavior, gameplay reviews absence of authority changes. Execute only
after the T7 gate and a coherent source freeze; keep the existing portable.

## Observed problem

The qualified `foreground-1e084/metrics.json` in the previous iteration records
21 Garden-arrival pixel validations taking 92,655 microseconds in aggregate,
versus 15,213 microseconds for 21 texture creations. Ready retrieval takes 729
microseconds across 23 calls; request submission takes 21,875 across 22 calls.
These are instrumented CPU elapsed totals, including possible scheduling waits.
They do not explain the exact 156.523 ms maximum frame-start interval.

`WellspringTerrainStream.pump` checks a 2,000 microsecond target between whole
operations. Each decoded tile then undergoes an indivisible one-MiB SHA-256
validation in `valid_image` before upload. One operation can exceed that target;
the current contract correctly stops the next operation after an overrun.
The pixel hash and dimensional/format checks must remain exact.

## Prompt and subtasks

1. Root prepares an ignored primitive comparison. Load actual lossless native
   tile images before timing. Measure `get_data`, one complete hash, and the
   exact same SHA-256 computed through 32/64/128 KiB updates. Include slice
   allocation, context start and finish. Use two warmups, alternating pair order
   and a reversed-order second process. Preserve raw observations and outliers.
   Technical reviews the helper before root executes it.
2. Separate peak indivisible work from total work. Chunking is worth a production
   experiment only if peak cost falls substantially without excessive total
   allocation/work. Also measure the first buffer-copy boundary; a reduced hash
   slice cannot hide an unchanged expensive first copy. No FPS claim is possible
   from this primitive experiment.
3. If justified, design a bounded validation state machine with independent
   review before editing the stream. Pending decode plus validation jobs must
   share the existing two-job ceiling. Retain at most the admitted tile image,
   one pixel buffer and one hash context per job; account transient memory
   separately from resident textures. No partially verified image is published.
4. Integration must preserve current-demand priority, obsolete-destination
   draining, byte/upload limits, readiness, suspend/resume and final token
   collection. Reconfiguration must refuse owned in-flight work. A corrupt byte,
   failed hash operation or changed image format stays fail-closed. Existing
   immediate tooling validation and exported-pack checks remain available.
5. Gameplay and experience independently review normal walking, explicit travel,
   resize/rekey, rapid return and shutdown. Root runs real native decoded-image
   admission, exact final pixels and repeated moving arrival comparisons.
   Compare peak pump, arrival wall time, total CPU and peak temporary memory.
   Retain only a useful improvement; preserve the rejected helper/results.

Both primitive comparisons passed for three real tiles, with 792 raw observations
and 36 corruption refusals each. Whole-tile hash means were 3.70–4.09 ms; 32 KiB
updates raised total validation by approximately 8–11%, while the largest measured
individual operation across those observations was 356 microseconds. Raw proof is
in [terrain-hash](terrain-hash/). This supports testing smaller scheduled operations;
it does not establish a hard pump limit, faster arrival or better game frame time.
The prototype retains the original two-owner ceiling and full digest checks.

## Established mechanisms and limits

The native stream comparison now rejects the fixed 2 ms policy as a default.
For the Garden view, pooled arrival-pump p95 fell from 7.300 to 2.390 ms, while
required-ready pump count rose from 9.083 to 21.667 and instrumented readiness
wall time rose from 276.393 to 736.491 ms. The large and edge views also became
ready later; early moving views encountered more missing-terrain frames. Total
all-phase pump CPU increased in all three means. Exact receipt and source copies
are preserved in [terrain-stream-slices](terrain-stream-slices/review.json).
These are native stream diagnostics, with their observation and scheduling costs;
they are not foreground FPS measurements. Actual Bootstrap traversal remains a
separate diagnostic, followed by restoration of the preserved original policy.

A worker-hash design is a separate unaccepted hypothesis. It would move only
SHA-256 over detached bytes off the main thread while retaining image retrieval,
metadata checks and texture publication on the main thread. Its measurement must
include scheduling, single-tile latency, total readiness, walking and task cleanup.
Reducing one processing spike cannot justify introducing longer gameplay waits.

[Factorio's terrain rendering account](https://www.factorio.com/blog/post/fff-323)
reports removing repeated preparation through reusable per-chunk draw orders.
That successful separation of preparation and rendering is relevant here.
Its suggestion of spreading future preparation over ticks is explicitly a
future opportunity, not evidence that incremental hashing shipped in Factorio.

[Godot's HashingContext API](https://docs.godotengine.org/en/stable/classes/class_hashingcontext.html)
supports computing one digest through multiple updates. That supplies the exact
mechanism to test; it supplies no H.E.X. timing result. [Background loading
guidance](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html)
also supports the existing rule to retrieve only completed requests.

[Riot's Swarm engineering account](https://www.riotgames.com/en/news/the-tech-behind-swarm)
shows why reducing simulation work alone can leave a client rendering bottleneck
unchanged: its successful VFX work targeted the early render-pass critical path.
This supports measuring the actual blocking stage. H.E.X. uses a different
renderer and workload; no Swarm particle, pathfinding or throughput result is
assumed to transfer.

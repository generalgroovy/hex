# Contiguous movement/cast attribution, 13 October 2026

All six native runs passed independent raw-receipt review. The evidence identifies MovementSystem as the largest of the seven instrumented children in each of these prepared workloads. It does **not** establish a gameplay optimization, a stable numerical observer overhead, or a fraction of the complete foreground frame.

[review.json](review.json) retains process, invocation order, zero/one/eight-step, warmup, verification-tail, paid-state and outlier strata. Its independent 30,033 checks cover exact receipt identities, source and qualification linkage, group schedules, every retained event/execution/branch row, disjoint child/parent/outer containment, strict boundary packet/state hashes, finite payment endpoints, two-world cleanup and empty parse/run stderr. The six engine receipts contain **73,880 checks**, **790 paired groups**, **744 measured groups**, **36 warmup groups**, **10 verification tails** and **2,400 paired completed steps**. Of those steps, 2,232 are in measured groups. Each arm executes the same trajectory; these are not 4,800 different simulation states.

The original thirteen functional partitions remain unchanged in [their archive](../movement-cast-functional-b/review.json). The additional five-actor Mantle prerequisite independently passed 14,490 checks and every one of its 480 ticks; its exact receipt, logs and independent review are preserved under `qualifications/bootstrap_roster_mantle/`. The Garden and close-Fire prerequisite receipts are also copied here so the exact command/event history is available without ignored working files.

## Measured intervals

Values below are mean microseconds per completed step in the **observed** arm, pooled across the two processes. These timings include the inserted clocks and associated observer work. They are main-thread elapsed intervals, not hardware thread CPU counters.

| Instrumented child | One-player Garden | One-player close Fire | Prepared five-actor Mantle |
| --- | ---: | ---: | ---: |
| Setup, resources and status | 46.620 | 69.504 | 149.526 |
| Reaction/contact ratios | 11.097 | 15.929 | 36.586 |
| Hex pre-movement effects | 17.623 | 27.081 | 109.042 |
| MovementSystem | 146.542 | 216.748 | 402.289 |
| Admission offer | 4.069 | 7.416 | 13.680 |
| Combat player step | 22.141 | 47.712 | 75.569 |
| Release storage | 3.285 | 9.283 | 10.451 |
| Containing movement/cast parent | 263.280 | 404.559 | 821.900 |

All child sums remain inside the containing parent; the residual is retained. Other simulation stages, observer copying and event/tick/error storage remain in the whole-group interval. The seven children must not be added again to their parent or to whole-group time.

Process variation is material. Forward/reverse MovementSystem means are **144.204/148.880 us** for Garden, **128.658/304.838 us** for Fire and **422.351/382.227 us** for roster Mantle. Their parent means are **258.486/268.074**, **232.153/576.964** and **865.042/778.758 us**, respectively. Root independently obtained the same rounded process figures. The shared rank is more useful than treating these isolated values as an exact explanation of the earlier foreground process totals.

## Observer comparison and limits

The table shows observed minus plain **whole-group elapsed time**, pooling equal opposite-order runs. Each Garden row has 48 measured pairs; each paid row has 100. Zero-step groups are preserved separately as actual empty-loop measurements and contain no simulated work.

| Workload | Steps/group | Mean difference (us) | Median difference (us) | Paired p95 (us) |
| --- | ---: | ---: | ---: | ---: |
| Garden | 1 | +31.458 | +23.0 | +334 |
| Garden | 8 | -41.250 | -136.5 | +1,783 |
| Close Fire | 1 | -17.150 | +65.5 | +538 |
| Close Fire | 8 | -286.750 | +31.5 | +5,389 |
| Roster Mantle | 1 | +61.270 | +67.5 | +884 |
| Roster Mantle | 8 | +111.670 | +252.5 | +3,702 |

Negative differences do not establish negative or zero observer cost. Invocation order changes the result: Garden's one-step mean difference is -128.125 us when plain runs first and +191.042 us when observed runs first. Fire and Mantle retain the same order sensitivity. Both arms use the existing nine-stage and cumulative observers; the observed arm additionally runs seven child clocks and copies their fixed lanes and branches inside the outer interval.

The largest Fire tail is preserved without trimming. In reverse order, the group from tick 379 to 387 has an actual `hex_clash`: plain whole-group time is **117.316 ms**, observed is **11.930 ms**, while their movement/cast parents sum to only **4.951/2.716 ms**. The same forward group is **5.920/29.859 ms**. This identifies neither a timer bug nor the cause of the remaining interval. It prevents a credible small overhead or speedup claim from the pooled mean. Raw maxima, positive and negative outliers, all warmups and verification tails remain available.

Each process preserves finite paid behavior: close Fire has four admissions, four releases, zero refusals and 2,400 matter paid; roster Mantle has two admissions, two releases, two real cooldown refusals and 1,200 matter paid. Initial admission/release fall in the declared warmup; later opportunities, actual flight/ground/products and refusal groups remain in the measured trajectory. The JSON phase strata overlap and include their group/step counts; they are not mutually exclusive cost buckets.

The timing harness runs contiguous SimWorld groups, with full state/packet/payment proof **between groups**. It retains each interior event array and fixed branch/execution lanes and checks them afterward against the separately qualified functional trace. It does not capture an interior state packet at each measured tick. Boundary proof still changes cache and thermal history between groups. Command preparation, source checks, buffer allocation and verification are outside the loop clocks; buffer allocation is reported separately. These samples are correlated phases of persistent trajectories, not independent frames.

Garden/Fire contain one ordinary player. The separate Mantle setup uses the actual never-entered Bootstrap factory, default spawn, explicit prepared initial Mantle slot, starter weave, four authored neutral training targets and default charter, followed by a fresh strictly equivalent observed world. It does not run full Bootstrap scheduling, rendering, separate exhibition courts, saves, GPU work or physical input. No FPS or smooth-60 claim follows.

## Frozen source and resume

[source-pin-review.json](source-pin-review.json) independently verified all **335** frozen manifest/input hashes before the seven UI files were applied. Each timing receipt adds exactly its qualification receipt for **336** pins. Exact ignored drivers, transformations, pin manifests and seven UI predecessors are archived; unchanged tracked inputs are identified by their hashes and root's committed `b57451465a46a33da19e279184b69f3d7579e8bb` checkpoint. This compact review did not run Git. The `inputs/.godot/` archive payloads require an explicit Git force-add because the repository normally ignores `.godot` directories.

The reviewed analyzer is included and refuses to overwrite `review.json`. Its first local invocation stopped on an analyzer-only naming assumption (`tail` versus the actual `verification_tail` field); no engine receipt or timing data changed. The corrected exact schedule was then checked in full. This is not a failed engine gate.

Gameplay independently approved the final authority/scope wording, without claiming a second numeric recount. Root independently reconciled the process means. Retain these results as a bounded attribution result. Any next internal movement investigation is deferred until the user resumes; no optimization was applied from this rank. The separate occupied-membership proposal is [archived unexecuted](../deferred-occupied-membership/README.md).

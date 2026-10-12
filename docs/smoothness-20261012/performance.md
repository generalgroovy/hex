# October 12 foreground performance assessment

The measured intermediate candidate improved the observed frame intervals, but **smooth 60 FPS remains unqualified**. The paid-ground cache was withdrawn after its isolated native comparison failed to demonstrate a speed benefit. Consequently the `46fca` profiles below describe that intermediate source, not the final source after withdrawal. The final source requires its own foreground qualification.

The final frozen source for this delivery is **`p60-be680e20d70e`**, full SHA-256 `be680e20d70e1a284eb4175916a7d97da4446b20bfada79a89f98e741446aa8e`, with 3,436 records. Its [final immediate attempt](final-immediate/summary.json) is `incomplete_or_failed`: no Start event was received before the 60,006 ms setup timeout. The [partial report](final-immediate/metrics.json.partial.json) has zero gameplay cases, no arm or game-instantiation timestamp, and zero measurement samples. Its [stderr](final-immediate/engine.log.err) preserves the intentional timeout error; a complete metrics file does not exist. Before/after source identity matches, but that does not qualify timing. The 157.218-second wrapper duration includes setup and surrounding work and is not gameplay duration. Its Full and portable gates subsequently passed as recorded in the [delivery record](README.md). The retained-campus comparison remains deferred and opt-in; final-source performance stays open. The [next iteration](../iteration-20261012/README.md) has separate source and measurement records.

## Inputs and validity

| Profile | Source | Receipt and raw intervals |
| --- | --- | --- |
| Baseline, full observer | `p60-845f85b5253e` | [summary](baseline-immediate/summary.json), [metrics](baseline-immediate/metrics.json) |
| Intermediate, full observer | `p60-46fca721f60d` | [summary](candidate-immediate/summary.json), [metrics](candidate-immediate/metrics.json) |
| Intermediate, light observer | `p60-46fca721f60d` | [summary](candidate-light/summary.json), [metrics](candidate-light/metrics.json) |

For the three completed profiles in this table, the gameplay reviewer independently checked receipts, metrics-file SHA-256 values, stable before/after source identities and input hashes, empty stderr, and completed/no-validation-error state. The intermediate candidate's full manifest SHA is `46fca721f60d2526be71bea06bdb3a43ae921998d2e0216b13507f9ef2deb4f6`, with 3,436 records. Both intermediate profiles have the same source. All three use Godot 4.7.1 official `a13da4feb`, debug build, GL compatibility through ANGLE/D3D11, the same profiling-script hash, 1280x720, low quality, a 60 frame cap, VSync enabled, immediate campus drawing and 120 Hz authority.

Each of these three completed runs received the explicit Start event before its stable foreground interval. Post-arm Windows records were baseline 105 total/104 available foreground/one unavailable shutdown boundary; candidate full 105/105 foreground; candidate light 103/103 foreground. There were no interior gaps or sampled focus mismatches. All post-arm Godot samples were focused. The light run's 37 unfocused setup observations precede accepted Start and are retained. These approximately half-second Windows observations support sampled foreground eligibility, not continuous focus, unobscured presentation or input latency. The [baseline light attempt](baseline-light/summary.json) never received Start or produced gameplay cases and is excluded, as is the final-source attempt described above.

The reviewer recomputed every case's mean and nearest-rank p50/p95/p99 from raw intervals and checked consecutive frame-start timestamps; all matched the stored metrics. Values below are milliseconds, means rounded to six decimals. These are engine frame-start intervals, not captured display presents or GPU duration. No frame-presentation trace was recorded.

## Warm frame intervals

Each warm case runs for approximately 12 wall-clock seconds.

| Profile | Case | Samples | Mean | p50 | p95 | p99 | Maximum |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline/full | Garden | 548 | 21.957210 | 18.663 | 39.306 | 53.651 | 61.813 |
| Baseline/full | Fire Bolt | 355 | 33.868254 | 31.618 | 54.934 | 74.395 | 95.313 |
| Baseline/full | All-six Mantle | 321 | 37.555433 | 31.929 | 73.790 | 83.079 | 91.357 |
| Intermediate/full | Garden | 600 | 20.002890 | 17.843 | 33.774 | 40.237 | 45.216 |
| Intermediate/full | Fire Bolt | 421 | 28.552259 | 26.893 | 39.859 | 46.442 | 56.789 |
| Intermediate/full | All-six Mantle | 382 | 31.453243 | 29.280 | 48.763 | 64.778 | 67.641 |
| Intermediate/light | Garden | 663 | 18.123199 | 16.935 | 24.547 | 28.657 | 30.989 |
| Intermediate/light | Fire Bolt | 466 | 25.784702 | 24.836 | 32.768 | 36.663 | 38.686 |
| Intermediate/light | All-six Mantle | 441 | 27.243465 | 27.041 | 33.250 | 38.203 | 42.146 |

Every intermediate casting interval, even under the light observer, exceeds the 16.667 ms budget for 60 FPS. In the light run, 429/663 Garden intervals also exceed it. Removing individual long stalls has not met the sustained frame-time goal.

## Paid work, simulation time and comparison limits

The commands use ordinary finite payment and natural recovery, with no resource refills. They request a cast every 120 simulation ticks; successful admission is not forced. The extra completed ticks can cross an additional request boundary.

| Profile/case | Attempts / admitted / refused | Paid matter | Simulation ticks | Wall seconds | Ticks/second | Dropped backlog seconds |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Baseline/Garden | 0 / 0 / 0 | 0 | 1,451 | 12.072518 | 120.190336 | 0 |
| Intermediate full/Garden | 0 / 0 / 0 | 0 | 1,441 | 12.016715 | 119.916300 | 0 |
| Intermediate light/Garden | 0 / 0 / 0 | 0 | 1,445 | 12.032266 | 120.093755 | 0 |
| Baseline/Fire | 12 / 12 / 0 | 7,200 | 1,434 | 12.047213 | 119.031680 | 0 |
| Intermediate full/Fire | 13 / 13 / 0 | 7,800 | 1,445 | 12.044436 | 119.972409 | 0 |
| Intermediate light/Fire | 13 / 13 / 0 | 7,800 | 1,444 | 12.039275 | 119.940777 | 0 |
| Baseline/Mantle | 12 / 6 / 6 | 3,600 | 1,410 | 12.119034 | 116.345907 | 0.05 |
| Intermediate full/Mantle | 13 / 7 / 6 | 4,200 | 1,446 | 12.050717 | 119.992860 | 0 |
| Intermediate light/Mantle | 13 / 7 / 6 | 4,200 | 1,444 | 12.043869 | 119.895027 | 0 |

No case recorded clamped wall time. Refusals remain ordinary reported outcomes; these summary counts alone do not establish each refusal's cause. The timing ratio near 120 is also a finite-window quantity, not evidence of a different authority rate.

These are comparable scenarios, not identical work. Faster Fire Bolts shorten projectile occupancy: full-observer frames containing a cast/projectile fell from 162/355 to 79/421, while paid-ground frames increased from 193/355 to 342/421. Candidate runs admitted additional paid casts. Maximum recorded Garden residency was 25 plots in both full runs and 22 in the light run; terrain residency also differs in some cases. These differences must not be attributed to omitted rendering without further evidence.

There is one predecessor/intermediate full-observer pair, no successful predecessor light run, no reverse-order repeat, and no isolated causal estimate for any optimization. Available memory also varied: approximately 950 to 310 MB around baseline, 459 to 588 MB around candidate full, and 524 to 1,193 MB around candidate light. That documents uncontrolled conditions, not proof of paging as the bottleneck.

The light observer reports lower intervals on the same source, but this is not a clean measurement of observer overhead: scheduling, residency and run conditions changed. Reported outer observer cost, approximately 0.04–0.06 ms per frame, excludes nested instrumentation and monitor collection. Subtracting it cannot reconstruct uninstrumented performance. Light-mode unavailable stage counters are null, not zero.

## Arrival and remaining costs

Keep arrival separate from warm play. Garden arrival p99/max was 294.244 ms baseline, 248.226 ms intermediate/full and 263.804 ms intermediate/light, from only 33/35/33 intervals. Startup arrival p99/max was 116.208/155.396/120.193 ms from 19 intervals each. These tiny-window maxima do not estimate stable tails or full application launch. Separately recorded synchronous startup took 7,478.447/7,807.901/6,944.432 ms; there was no controlled cold OS-cache experiment.

Intermediate full-observer CPU stage timers identify investigation targets:

- Paid-ground drawing averaged 4.731 ms for Fire and 4.900 ms for Mantle, with p95 7.660/8.096 ms. Nested court-bundle preparation averaged 1.860/1.857 ms, essentially unchanged from baseline's 1.799/1.879 ms. The isolated batch-cache proposal has no supported live speed claim.
- Immediate campus setup averaged 2.266/2.265 ms in the casting cases. Combat HUD drawing averaged 1.698/1.576/1.685 ms across Garden/Fire/Mantle. Garden's binding/card/text-measure preparation counts were already stable, so simply proposing another text-measurement cache misses the observed cost.
- Garden's inclusive drawing averaged 1.535 ms, with surface preparation 0.425 ms, merged mesh submission 0.325 ms and plaques 0.215 ms. Its fixed-step work and rendering are distinct from first-arrival preparation.

These timers nest and are not additive GPU or frame-budget accounting. Last-completed-fixed-step samples do not measure every fixed step in a frame with catch-up work. Warm terrain-loading frames were zero; that does not qualify cold travel.

## Rejected paid-ground optimization

The separate [native ground receipt](../../.godot/ground-submission-20261012-d/receipt.json) retains **317 exact RGBA comparisons, zero mismatches**, unchanged authority and source, and actual alternating callback order. Both paid sequences made 12 attempts/12 admissions/zero refusals, paid 7,200 matter, and naturally expired without refills. Mantle expired at tick 2,717, within the independently reviewed 2,912-tick ceiling derived from startup, cooldown/recovery, flight and finite product/trail phases. Its request policy waits for readiness and differs from the foreground profile's fixed 120-tick cadence.

Six sets of 16 measured pairs after two warmup pairs do not support a CPU speed win. Candidate/reference mean differences were Fire +2.35%/+4.86%, Mantle +1.48%/+2.15% and one active Garden-63 plot -11.50/-1.25 microseconds for normal/reduced effects. A pronounced first-draw penalty remains. Descriptive adjacent AB-block 95% t intervals cross zero for five cases; reduced Fire's interval is +182 to +761 microseconds. These are eight blocks from one process, not independent-run confidence or proof of universal regression. The decision is to withdraw unproven complexity, preserve the exact correctness oracle and failed/finished receipts, and qualify the resulting source separately. The holistic `46fca` profile cannot assign its improvement to this cache.

## Next bounded priorities

1. Qualify the final source after withdrawal with the same declared observer mode and ordinary finite casts. For causal promotion, add order-balanced repeats and a fixed admitted-work diagnostic with actual phase/cell counts, alongside the wall-time gameplay case. Preserve failures and source identity.
2. Reduce paid-ground preparation/submission where current timings are largest. Separate metadata work from command count under identical live states; retain exact coverage, ingredient identity, danger boundaries, phase transitions and paid-source lifetime. Require an actual repeated CPU win before retaining another cache.
3. When foreground testing resumes, run a bounded paired trial of existing opt-in retained-campus mode against a qualified final immediate reference. This trial is presently deferred. All six scoped files still match the earlier 40-comparison native pixel receipt; 19 structural assertions also passed. It excludes paid fields, actors, visibility and UI. This is sufficient for a trial, not default promotion: count child draw/preparation work outside Bootstrap's main draw timer, inspect actual Bootstrap rendering/lifecycle, and remember that camera movement invalidates exact-view keys. Potential savings are only part of the 2.26 ms campus stage. Inspect HUD submission separately, reusing its existing layout caches and retaining every option and meaning.
4. Bound first-arrival initialization independently of warm drawing. Test cold and revisited Garden travel, with complete phase/coverage checks and no invisible missing fields.
5. Use an actual presentation/driver trace if engine intervals remain above budget after CPU improvements. Preserve 120 Hz authority, payment and catch-up accounting; reducing simulation work by dropping paid content, refilling resources or silently discarding time would not meet the smooth-play goal.

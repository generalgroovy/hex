# Technical evidence — October 12 smoothness pass

The Garden spatial lookup memo remains in the candidate. The proposed Court
metadata batch and Water/Fire/Steam style memo were withdrawn after the native
paid-field comparison failed to establish a CPU benefit. The measured
`p60-46fca721f60d` source therefore remains an **intermediate**, not the final
post-withdrawal source. [Performance evidence and limits](performance.md) and the
[active queue](../../.agent/OVERHAUL-IMPLEMENTATION.md) own the broader status.
The frozen post-withdrawal candidate is `p60-be680e20d70e`, 3,436 records,
runtime SHA-256
`be680e20d70e1a284eb4175916a7d97da4446b20bfada79a89f98e741446aa8e`;
its clean Full qualification and local package, standalone delivery, exported
terrain and release lifecycle gates passed. Final-source performance remains open.

**Retained Garden work.** Root's
[exhibition change](../../src/app/element_garden_exhibition.gd) reuses the exact
visible-plot selection and nearest-plot lookup while the view/observer is
unchanged, with configure/clear invalidation. Demonstration lifecycles, current
inspection text and drawing remain live; combat authority is unchanged. The focused Garden suite passed
76,949 assertions with zero failures in
`.godot/smoothness-20261012/garden-projectile-focused-4.log`.

The [local Garden benchmark](../../.godot/smoothness-20261012/garden-spatial-bench.json)
alternated old/new execution order in one process, using two real simulation
steps per frame. Each case retained 589 frames after eleven warm-up frames.
It checked plot information each frame and resident court hashes every sixty
frames; those checks passed. These are CPU exhibition-step measurements, not
foreground frame pacing or complete-game acceptance.

| Garden workload | Predecessor mean | Candidate mean | Predecessor / candidate p95 |
| --- | ---: | ---: | ---: |
| Stationary camera and observer | 529.49 µs | 470.19 µs | 2,249 / 1,976 µs |
| Moving observer | 463.12 µs | 430.98 µs | 1,564 / 1,467 µs |
| Moving camera and observer | 489.96 µs | 469.32 µs | 1,513 / 1,421 µs |

Garden benchmark SHA-256:
`83f757aed55f8ebf204d094684b5d9926e32da1d6362e7f9d3ba2e1c033952fa`.

**Withdrawn Court experiment.** The
[native-d receipt](../../.godot/ground-submission-20261012-d/receipt.json) passed
317 exact RGBA comparisons with zero mismatches and unchanged watched sources.
Its six timing cases used two warm-up and sixteen measured pairs, with actual
draw-callback order verified. Both Fire and Mantle admitted twelve ordinary paid
casts without refills. Mantle naturally expired at tick count 2,717, within its
authored 2,912-tick ceiling; no expiry was forced. This finite readiness-driven
workload differs from the source profiler's 120-tick casting cadence.

All four paid-ground mean submission times regressed: Fire 9.950→10.183 ms,
reduced Fire 9.709→10.181 ms, Mantle 6.012→6.101 ms, and reduced Mantle
6.147→6.279 ms. Reduced Fire was slower in fourteen of sixteen pairs, with a
407.5 µs paired median increase. Garden's warm paired medians changed by only
−1.5/−4 µs and had a pronounced execution-order effect. These observations did
not justify keeping the additional dictionaries, copies and cache keys.
Their individual contributions were not isolated.

The [withdrawal manifest](../../.godot/smoothness-20261012/withdrawn-ground-batch/withdrawal.json)
records all four before/after file hashes. Only this pass's two production slices
and dependent tests were removed; previous dirty work, the Garden memo and other
agents' changes remain. Both production files are byte-identical to their
preserved pre-pass copies, independently verified by the experience reviewer:

| Restored production file | SHA-256 |
| --- | --- |
| `src/presentation/hex_court_presenter.gd` | `7211f0aba37becc097355ef7b3eae60caa2a133d6156af3e00421cef2b5c5d05` |
| `src/sim/hex/hex_chemistry_world.gd` | `5618b81316329bba8524022365db2f30a5f613603fe1e08b3abd98d18637a567` |

Native receipt SHA-256:
`424e54ec2b654fbea892d4481de78cd975ec76f68f8907752cb6a10722e9a854`.
Withdrawal manifest SHA-256:
`7e8d7e11112ebd5fd044333bd2f5776961ff7c7c506c2446d09ac7c4116efb02`.
The raw receipts, withdrawn source, failed fixture attempts and frozen comparison
oracle remain local evidence; their `.godot` paths are ignored by Git. Earlier
failed attempts are not substituted for the completed native-d comparison.

**Post-withdrawal checks.** The first
[focused wrapper receipt](ground-withdrawal-focused.json) failed the expected
source-identity precheck because it was invoked before identity regeneration.
It launched no engine, imported nothing and executed zero suites/assertions.
The fresh post-withdrawal engine run then passed all four selected suites:
`paid-field-rendering` 6,490 assertions, `hex-render-frame` 284,
`hex-shared-presenter` 44,630 and `hex-court-presenter` 125,228 — **176,632
assertions, zero failures**, exit 0 and independently checked zero-byte stderr.
The [raw focused log](../../.godot/smoothness-20261012/ground-withdrawal-focused-2.log)
belongs to the frozen `p60-be680e20d70e` source. After the test-only fixture repairs,
the [clean final Full](full-final.json) passed **261 suites, 7,401,986 assertions,
zero failures and zero-byte stderr**, including import, source identity checks
and 120 Hz boot, in 1,252,982 ms. Independent raw-log/hash verification and the
preserved earlier failed Full are recorded in [validation evidence](validation.md).
The subsequent [package](package.json) and [standalone delivery](delivery-files.json)
passed with independently matched ZIP/PCK and all ten payload-member bytes. The
[terrain gate](terrain-pack.json) passed 2,062 checks for 132 chunks plus overview;
the [actual-release lifecycle](portable-lifecycle.json) passed all five normal-close
cases, including twelve accepted and zero refused Fire and all-six Mantle casts
per paid case, with empty stderr throughout. The prior 845f fallback remains
byte-matched. [Validation evidence](validation.md) records the exact artifact
hashes, independent checks and limits. No installer, physical-input, multiplayer
or final-source frame-pacing acceptance is inferred from these local gates.

**Final-source performance remains open.** The
[final immediate attempt](final-immediate/summary.json) did not receive a Start
event before its 60.006-second setup timeout. Its
[partial report](final-immediate/metrics.json.partial.json) records no arm boundary,
no game instantiation and zero measured cases. Before/after runtime identity and
profiler input hashes match `p60-be680e20d70e`. This is a failed setup attempt,
not gameplay timing or evidence of a game failure; the preserved stderr records
the explicit arming timeout. The retained-campus comparison is deferred, and
immediate campus remains the default with retained campus opt-in.

A future comparison requires the human Start event within the bounded setup
window, the stable-focus period, and all existing owned-window, foreground,
1280×720 and unchanged-source gates. No final-source timing gain is established.
Godot documents that drawing commands remain cached until
`queue_redraw()`, which motivates the experiment but does not establish a gain
for this game or device. [Official custom drawing documentation](https://docs.godotengine.org/en/4.6/tutorials/2d/custom_drawing_in_2d.html#updating).
Retain a changed default only with equivalent live cues and a useful controlled
measurement; otherwise keep retained campus opt-in. Smooth sustained 60 FPS
remains unqualified.

# FLUX consolidation checkpoint — 2026-09-12

Status: local portable verified; human acceptance and W4 remain open.

The current pointer selects `consolidation-p47-20260912` after fresh Full,
rendering, exact export/PCK/boot and same-export localhost checks passed.
This bounded maintenance milestone preserves its gameplay, all original assets,
user edits and the Frostway/M2a fallback. Main HEAD remains a1aa02807626823d0fbc1e25e75441ca3b7f4d36;
the protected baseline had 860 collapsed dirty/untracked status entries.

Playable: [flux2.exe](../exports/windows-consolidation-p47-20260912/windows/flux2.exe)
with adjacent `flux2.pck`; or extract the complete
[97.7MB portable ZIP](../exports/windows-consolidation-p47-20260912/release/FLUX2-Windows-x86_64.zip).
No game was visibly launched during this run. The PCK SHA-256 is
`0f4e9c6e560e127d6ececbf0bb3661b5ac6bc3f9f232aaf0e77b4b7ee434592e`;
ZIP SHA-256 is `0e55d75fde437fda60f91efa07a3b7efcf13afb60cd784f2c0ce8a70f1f77f7c`.

Final Full: **98 suites / 690,489 assertions**, zero failures/stderr. All3,097
frozen inputs remained unchanged across export. Newly rendered221 gameplay PNGs
are byte-identical to M2b;12 additional station PNGs passed static image review.
[Exact artifact receipt](evidence/windows-consolidation-p47-20260912/checkpoint.json)
and [same-export localhost receipt](evidence/consolidation-20260912/same-export-receipt.json)
retain referenced logs and payload hashes. The later39-assertion Focused run
left both Full receipts' logs/reports unchanged, and the builder copied exactly
the final Full's durable reports despite shared report replacement.

The preserved [M2b pointer](evidence/consolidation-20260912/previous-checkpoint.json)
retains its original payload identities. All32 changed frozen inputs have exact
baseline recovery copies; four source files were added and none removed. Recovery
inventory: [source-delta.json](evidence/consolidation-20260912/source-delta.json).

## Changes and evidence

| Change | Acceptance and recovery |
|---|---|
| Whole-checkout engine guard and durable logs/reports | 13 fresh ownership/contention/cancellation/stale-child checks passed. Full receipts now retain independent logs and validated source reports; 104 portable-validator assertions passed. Exact owned pre-edit files retained. |
| Valid world-boundary snapshots | Real-map tick345 exposed legitimate wall IDs -1/-2 rejected by the old event validator. Both sentinels now accepted, -3 rejected; unchanged encoded fixture now validates. Validation policy changes same-build fingerprint, so older rejecting peers cannot join. No schema fields or gameplay collision changed. |
| Current station bindings and readable instructions | Exact keyboard/mouse/controller labels, truthful UNBOUND guidance; clipped Gallery sentence shortened. 12 actual 720p normal/reduced images passed Astra review, each draw preserved world state. |
| Proven dead bootstrap fallback | 98 unreachable production lines and obsolete test hooks removed. Active size presenter and both procedural failure bodies remain. Independent sprite class/scenes/assets/generators remain. [Consumer trace and recovery](evidence/consolidation-20260912/bootstrap-legacy-removal.md). |
| Chemistry boolean sampling | Same bounds and bounded integer samples as the unchanged dictionary oracle; temporary result dictionaries removed in the boolean projectile path. 110,720 differential assertions, 31,355 batch assertions and every-tick baseline state/event trace agree. No broad speedup claim. |
| Diagnostic and delivery truth | Stale stage/drill mirrors, roster expectation and observer-counter initialization corrected. Current portable and historical installer reported separately. No installer/security action taken. |

The [bounded audit](evidence/consolidation-20260912/README.md) records confirmed
defects separately from usability concerns and proposals. The
[single queue](../.agent/OVERHAUL-IMPLEMENTATION.md) remains the only work order.
No movement cost, spell cost, caps, clock, RNG, footprint, identity or balance was
retuned. Rapid remains trail-free; Capacitor, Frostway and Rampart keep M2b rules.

## W4 remains failed

All timings below are milliseconds, two repeats of 720 measured ticks after
120 warmup ticks; same Godot4.7.1, Ryzen3 7320U, seed608120, eight paid actors.
Snapshot capture/packing and instrumented stages are separate measurements.

| Measurement | Matched before | Final v2 | Interpretation |
|---|---|---|---|
| Synthetic simulation p50 | 8.155 / 9.433 | 8.143 / 7.973 | Background load was variable. |
| Synthetic simulation p95 | 14.106 / 17.104 | 13.165 / 13.175 | Both exceed8.333ms. No causal percentage speedup claim. |
| Synthetic simulation p99 | 17.189 / 32.353 | 15.437 / 14.319 | Tail variability remains. |
| Synthetic worst tick | 44.416 / 139.457 | 52.589 / 20.536 | Shared-host measurements. |
| Synthetic missed ticks /720 | 337 /451 | 347 /328 | Target remains120Hz. |
| Snapshot capture/packing p95 | 7.877 /11.103 | 8.350 /7.772 | Separately timed; do not add p95 values. |
| Direct sim+snapshot interval p95 | 21.430 /28.059 | 20.420 /20.412 | 360 snapshot-bearing intervals/repeat. |
| Real-map simulation p95 | 27.720 /31.560 | 27.807 /27.397 | Both stage-instrumented; old run rejected2 snapshots/repeat and was invalid acceptance evidence. |
| Real-map rejected snapshots | 2 /2 | 0 /0 | Corrected run passed17,129 assertions. |

[Full timing distributions, identities, counts, memory limitations and raw logs](evidence/consolidation-20260912/performance-results.md).
The final synthetic state hash is3a001c52354913e7ab7793551ef0776af6cee216581e0cd6dc5b745d73430b02;
baseline/final drill trace is0ecb3477e695b77e041be87eef5b92e0e52017ba2b6f91bf41f287be08657e44.
The first candidate regressed the mixed-query microbenchmark and was replaced.
The second's microbenchmark remains noisy. Static control-flow counts support
74,664 avoided result dictionaries in the drill; this is not allocator profiling.

The valid instrumented real-map run attributes chemistry p95 to22.464/22.077ms
versus projectile6.200/6.296ms. Next bounded technical work is chemistry subphase
attribution with exact per-tick state/events/IDs, before choosing an optimization.
Do not expand effects or lower workload/caps to pass W4.

## Acceptance boundaries and short playtest

Human gait/feel/readability, sustained rendered120FPS, physical two-PC internet
play and current installer/updater remain open. Captures establish static rendered
appearance; localhost fixtures establish only their exercised local network paths.

At720p, visit Gallery and Host/Join with a custom keyboard, mouse or controller
Interact binding; confirm complete instructions and sensible device switching.
Compare all three shared body sizes while moving in one direction and aiming in
another. Use two Charge Rapid impacts at one nearby endpoint to form Capacitor;
compare walking/sprinting, paid slide/jump, final warning and enemy displacement
in normal/reduced effects. Repeat Ice Frostway and Earth Rampart counters. Check
that Rapid has no flight trail. Use the exact same new portable on both machines
for the later physical network test; M2b is retained for offline comparison.

Nothing was committed, pushed, published or installed. No user settings, original
assets or known-working exports were deleted. Recovery files and useful failed
runs remain together under evidence/consolidation-20260912.

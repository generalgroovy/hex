# H.E.X. eight-priority performance implementation

Status: locally validated playtest checkpoint `p56-089aaf734a1c`, 2026-09-28.

Open [PLAY-HEX.cmd](../exports/hex-performance-eight-20260928/windows/PLAY-HEX.cmd),
or extract [the Windows portable ZIP](../exports/hex-performance-eight-20260928/HEX-p56-089aaf734a1c-Windows-x64.zip)
and keep EXE/PCK together. Separate export, native art admission, expected source
identity and safe shutdown passed. Two exports remain: this one and
`hex-combat-clarity-20260928` (`p56-0f3f12334cff`). No installer, release pointer,
commit, push or publication was performed.

The user authorized priorities 1-8. Keep 120 Hz, exact geometry, all combat rules,
paid matter, event ordering, hurtboxes and visual threat information. No commit,
push or installer promotion. One lead runs engine workflows.

Superseding cleanup instruction: retain only two functional exports. Removed 26
older generated directories (7,369,159,608 bytes) after retained-package checks;
small receipts survive in `docs/build-retention/`. No original assets removed.
The final replacement package was produced only after correctness/native gates.
Both retained payload manifests and ZIP hashes were independently checked by
the pruning tool; original art, source, personal preferences and dirty work remain.

Fresh instrumented baseline: normal/reversed p95 19.128/19.082 ms; worst ticks
265.423/250.872 ms. At tick 381, Spray contacts alone took 262.103/247.495 ms.
The first focused attempt stopped at the stale identity guard (no engine test);
the next compile exposed Rect2i's one-argument intersects API. Closed-boundary
rejection now uses explicit integer interval comparisons. Failed receipts remain.

| Priority | Bounded implementation | Acceptance |
|---|---|---|
| 1 | Optional disjoint per-tick stage timings and retained raw samples | Fresh paired baseline; diagnostics excluded from authority |
| 2 | Conservative spatial candidate rejection | Exact collisions retained; replay state/events match |
| 3 | Reuse/prune exact Spray and hex geometry | Edge/vertex/tangent and stored-owner tests, matching replay |
| 4 | Efficient deterministic contact queue | Same ordering, stale generations and reflection behavior |
| 5 | Avoid repeated stationary chemistry work | Safe lifetime/invalidation, exact transitions and crossing behavior |
| 6 | Reduce hot-loop allocations and redundant conversions | Bounded scratch data, no mutable alias leakage |
| 7 | Separate/optimize snapshot production | Strict incoming validation and malformed producer tests retained |
| 8 | Reduce presentation work without reducing threat information | Native visual comparison and separate timing evidence |

## Implemented scope under validation

| Area | Implementation and guard |
|---|---|
| Measurement | Opt-in disjoint `SimWorld` stage clocks plus p50/p95/p99/max and every raw tick sample; absent from authority/hash/wire state |
| Flight candidates | Per-tick 128 px spatial buckets around swept, radius-inflated closed bounds; exact TOI still decides contacts; reinsert reflected/split paths |
| Contact ordering | Binary min-heap retains fraction, policy priority and entity/source keys; exact-key duplicates use insertion order instead of relying on unstable sorting |
| Spray geometry | Read-only bounded hex-polygon cache, four-cell continuous ownership, exact origin-contact fast path, guarded radius/cone broad rejection before exhaustive edge witnesses |
| Stationary fields | Cache occupied-cell union against actual coverage values, including direct mutations/restores; return an independent dictionary |
| Allocation work | Reuse immutable geometry; eliminate repeated full-queue sorts and topology buffer resizing; never cache mutable authority aliases |
| Snapshots | Native canonical cell ordering and single preallocated topology byte buffer; strict incoming validation and full producer roundtrip remain mandatory |
| Presentation | Compute identical owner/phase/material edge-key prefix once per region, not once per edge; no missing cues, reduced draw fidelity or cross-frame stale cache |

The new geometry corpus compares 240 complete field-contact witness records with
the old exhaustive enumeration, plus 600 continuous ownership cases including
fractional vertex ties. Queue/spatial tests include negative coordinates, closed
bucket endpoints, reflected path replacement, equal keys and changed TOIs.
Focused v3 passed 7 suites / 18,032 assertions. Focused v5 passed 5 suites /
17,425 assertions after a test-only inferred-type parse error was corrected;
v4 is a retained failure, not acceptance. Final Full passed **172 suites /
1,533,766 assertions**, zero failures/stderr, import and 120 Hz boot.
The post-import v2 rerun passes the same full count and the new explicit identity
check. Godot's generated 20-byte UID is the only added source record between
diagnostics (`p56-4526dd9846cf`) and final packaging (`p56-089aaf734a1c`): removing
that one record reproduces the complete earlier canonical source digest. The
bridge receipt records this proof; no gameplay byte was changed after profiling.
For future new scripts, import generated sidecars before the identity/Full freeze.
Full now fails immediately if import still changes canonical production inputs.

## Final simulation measurements

Same production first-four/four-delivery workload: eight paid casters, 120 warmup
plus 720 measured ticks per order. No refills, cap overrides or density reductions.
Peak 19 flights, 23 products, 20 cast records and 11 events/tick. Instrumentation
is identical on both sides. These are simulation-only timings, not total frames.

| Metric | Before normal / reversed | After normal / reversed |
|---|---|---|
| Median | 6.110 / 6.048 ms | 5.307 / 5.385 ms |
| p95 | 19.128 / 19.082 ms | 12.820 / 12.766 ms |
| p99 | 28.015 / 27.811 ms | 17.344 / 17.113 ms |
| Maximum | 265.423 / 250.872 ms | 64.723 / 64.148 ms |
| Ticks over 8.333 ms | 197 / 186 of 720 | 132 / 126 of 720 |

About 33% lower p95 and 74-76% shorter maximum hitches. **120 Hz dense timing
still FAILS.** The final tick-381 Spray stage takes 61.288 ms; tick 378 takes
54.748 ms. Tick-784 projectile contacts take 20.689 ms. These measured stages,
not guessed workloads, are the next simulation targets.

All 1,440 measured tick states and ordered event streams retain baseline trace
`8c9b2463acaddc48d4a168e981ddd6983c437e7f5ae10a7ed34da93e2269e452`;
final canonical hash is unchanged in both orders. This is equivalence evidence
for the exercised workload, not a mathematical proof for all possible matches.

## Snapshot dependency

The refreshed decomposition probe passed 604 assertions, exact chemistry/world/
envelope/packet roundtrips, with no stderr. Median full world capture is
657.676 / 639.048 ms (distributed / dense), envelope capture 662.462 / 649.233 ms,
and packet packing 3.609 / 3.118 ms. Only three calls/component: these are diagnostic
medians, not a capacity certificate. Inclusive nested timers must not be added.
Strict validation is retained; the small serialization optimization does **not**
resolve the large topology/hash/prepare dependency. Hosting is not release-ready.

The first probe failed a fixture-clearance assertion: fine-grid center eligibility
does not imply an 18px actor fits. The test harness now relocates only invalid
distributed samples to the nearest legal center; targets use their own clearance.
Dense geometry and the baseline comparison remain unchanged. The failed v1
receipt survives separately; do not use it as passed evidence.

## Native presentation validation

42 fresh native frames from 14 ordinary paid Bolts cover seven revised pairs,
formation/active/decay and normal/reduced effects. Every PNG SHA256 exactly matches
the preceding validated `docs/combat-phase-evidence-20260928/native/` image. Two
Radiance formation/active examples were freshly reviewed; all 42 have automated
identity evidence, not 42 fresh human reviews. Reuse the existing image evidence
instead of copying identical PNGs into another documentation folder.

Refreshed native component harness: **2,096 assertions, zero failures/stderr**;
all four original/timers-disabled/timers-enabled complete-frame controls match.
32 frozen draws per distributed/dense x normal/reduced case, no advancing world.
The first attempt exposed its stale campus draw signature; the harness now forwards
the current visible-world rectangle. Failed v1 is retained, not acceptance.

| Frozen draw diagnostic | Total CPU submission p95 | Hex ground p95 |
|---|---:|---:|
| Distributed, normal | 62.791 ms | 47.501 ms |
| Distributed, reduced | 61.601 ms | 47.381 ms |
| Dense, reduced | 23.985 ms | 6.465 ms |
| Dense, normal | 23.549 ms | 6.387 ms |

Component quantiles are not additive. This excludes moving-pose preparation,
simulation, networking, GPU duration and real input. No before/after renderer
speedup is claimed. It exposes remaining presentation work; it does not pass
the frame budget. Shared material edge-prefix reuse is a bounded first change,
not a completed batching/renderer overhaul.

## Next measured slices

| Order | Next bounded work | Gate |
|---|---|---|
| 1 | Attribute snapshot topology hashing, trusted reconstruction and prepare; design immutable topology reuse without weakening incoming validation | Byte-identical producer/restore, malformed data rejected, separate capture/packing timing |
| 2 | Reduce visible hex-ground preparation and command submission; profile pose updates separately | Exact danger/ownership/phase boundaries and native pixel controls; moving rendered workload |
| 3 | Decompose remaining Spray ticks 378/381 and projectile-contact tick 784 | Same frozen workload and full authority/event trace; exact contact witnesses |
| 4 | Re-run complete host+snapshot+render cadence and same-export lifecycle | Only then consider physical two-PC test and installer/update promotion |

Priorities 1-8 have a correctness-tested bounded implementation. The overall
dense 120 Hz, rendering and multiplayer acceptance goals remain unfinished.

No snapshot delta protocol, worker-thread simulation, GDExtension rewrite,
gameplay cap changes, time-sliced hazards or renderer rewrite is claimed. These
would need separate design/acceptance; bounded optimizations do not establish
extreme player/projectile capacity or end-to-end 120 Hz.

Record each as implemented/tested/deferred honestly. Do not claim 120 Hz from
configuration, an isolated speedup or a passing functional suite. Dense simulation,
exported rendering, snapshots and physical networking require separate receipts.

## Local playtest

Use Academy / Spell Loom to equip Bolt, Heavy, Rapid and Spray; compare repeated
Spray casts into overlapping Water/Fire/Earth/Air fields, close cover contacts,
reflection and moving through reactions. Move/aim independently and chain the
existing jumps, slides and air evasions. Look for reduced cast hitches, unchanged
contact outcomes and unchanged warning/active/decay cues. Saved bindings still
override defaults. This is a solo checkpoint; remote play remains experimental.

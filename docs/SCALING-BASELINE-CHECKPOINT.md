# FLUX scaling baseline checkpoint

Status: baseline instrumentation and static limit inventory complete, 2026-09-14;
full-system capacity acceptance NOT ESTABLISHED. Playable production remains B1.

The September 14 larger-area/high-load amendment is incorporated into the
[single queue](../.agent/OVERHAUL-IMPLEMENTATION.md). This bounded slice adds a
legal four-delivery profiling fixture and preserves an eight-player baseline
before contact, optimization, area, persistence or capacity changes.

## Playable source and fallback

Launch the current source from the checkout:

```powershell
cd C:\Users\sende\Projects\flux
.\scripts\run.cmd
```

Expected identity: **p49-5e49b41aac92**, protocol 49, snapshot 19, preferences 11.
Production SHA256: `5e49b41aac92b68d76f7baf8409b76bddebc081ae2792350881fac80eb4a60ef`.
The [B1 handoff](FOUR-DELIVERY-B1-CHECKPOINT.md) describes current gameplay:
Rapid 1, Spray 3, Bolt 5, Heavy 15 across eight elements; paid strength provenance,
equal-strength deposit chemistry, and trail-free Rapid. Ordered direct attack
clashes and Spray interception/ingredient reservation remain pending B2.

The selected portable remains **Overnight P48, p48-111d911c27fa** in
`exports/windows-overnight-p48-20260913/windows/flux2.exe`, alongside its PCK.
Its rules and protocol differ from current B1 source. The selected pointer,
three payloads and five referenced evidence members were freshly hash-verified.
No package, installer, pointer promotion or publication was performed here.

## Changes and acceptance

Added `tests/scenarios/four_delivery_load_probe.gd` and
`scripts/profile-four-delivery.ps1`, plus the generated script UID. The fixture
uses all 32 current catalogue cells, eight real champion resource profiles,
ordinary paid casting, unchanged production limits, and natural cleanup.
No attacks are seeded and no health, Flux or cooldown is refilled or bypassed.
All 32 wire identities must actually pay and release in every case/repeat.

The four cases are authored-campus normal play, synthetic open pressure,
corridor pressure, and clustered pressure. Each has two reversed-input repeats,
fixed seed 608120, 120 warmup ticks and 720 measured ticks. A separate open
pressure soak uses 7,200 measured ticks per repeat: 60 seconds of simulated time.
State/event traces, per-wire payment/releases, refusals, queue counts and natural
cleanup agree between repeats. The harness records requested input separately
from paid starts, post-step active inventory, emitted/queued/evicted events,
snapshot bytes/packets, timing distributions and static process memory.

Root serialized every engine operation; investigation workers owned separate
read-only audit reports and were idle during benchmarks. Candidate inputs were
frozen before final validation. The final 3,135-input inventory is unchanged
after validation; comparison with B1's 3,132 inputs shows exactly the three new
harness inputs and no changed/removed pre-existing production or asset input.
Personal profile bytes also match the before-run hash. See
[preservation receipt](evidence/scaling-baseline-20260914/preservation.json).

Fresh final checks on that freeze:

| Check | Result |
| --- | --- |
| Full v2: import, deterministic suites and isolated 120 Hz boot | PASS: 105 suites, 696,784 assertions, zero failures and zero stderr |
| Four-case load matrix | PASS correctness: 28,178 assertions, zero failures |
| Two-repeat 60-second simulated soak | PASS correctness: 52,788 assertions, zero failures |
| Source/profile/pointer/payload preservation | PASS; 73 referenced files copied and hash-verified |
| Rendered performance, input-to-visible latency, socket networking and physical two-PC | NOT RUN in this slice |
| Packaging, installer/updater and human acceptance | NOT RUN in this slice |

Full v1 predates the final one-count-per-failed-snapshot metric correction and
is diagnostic history. Diagnostic v1 failed two campus release-coverage checks:
its aim encountered structures. The assertion was retained and strengthened;
aim now targets the court center with shorter lateral excursions. Diagnostic v2
passed all 6,952 checks. Both diagnostics and their logs are preserved. Earlier
B1 native frames and P48 delivery/network receipts remain historical evidence;
they are not new rendered, network or packaging measurements for this slice.

## Measured constraints

Target: Windows x64, AMD Ryzen 3 7320U, four cores/eight logical processors,
Godot 4.7.1. The following ranges span two repeats; they are not averaged quantiles.
The host metric includes production step, event retention and capture/packing
every other tick. It excludes rendering, sockets, physical input and observer work.

| Case | Simulation p95 ms | Host metric p95 ms | Host ticks over 8.333 ms |
| --- | ---: | ---: | ---: |
| Campus normal, 720 ticks | 4.727–4.768 | 8.445–8.463 | 47 / 47 |
| Open pressure, 720 ticks | 6.741–6.833 | 11.107–11.183 | 185 / 191 |
| Corridor pressure, 720 ticks | 6.718–6.789 | 11.086–11.100 | 194 / 200 |
| Cluster pressure, 720 ticks | 6.766–6.901 | 10.488–10.623 | 155 / 159 |
| Open soak, 7,200 ticks | 6.182–6.252 | 10.047–10.157 | 2,578 / 2,463 |

All per-repeat p50/p95/p99/max, misses and workload counters are retained in
[measurements](evidence/scaling-baseline-20260914/measurements.md) and the copied
original JSON. The soak simulation maximum was 26.438 / 15.996 ms, with 14 / 6
simulation deadline misses. The host timing already exceeds the budget before
rendering and sockets. This does not close the historical W4 gate, whose older
workload differs and cannot be used as a matched performance comparison.

Each soak repeat produced 1,353 paid releases. It requested 720 discrete
Bolt/Heavy/Spray actions plus 23,040 held Rapid input-ticks; held ticks are not
individual paid casts. There were 565 explicit discrete refusals (78.5%), leaving
155 admitted discrete actions and 1,198 Rapid shots. These measurements show
admission-limited overload, not support for the entire requested workload.

Post-step peaks were 64 projectiles, 127 deposits and 10 reactions; these are
separate peaks, not simultaneous counts. Production still enforces the shared
128 projectile-plus-deposit envelope. All eight actors survived the open soak;
natural cleanup completed after another 1,036 ordinary ticks in both repeats.

Each soak repeat had 450 event-queue evictions and 183 emitted events that could
not be encoded as session feedback. No snapshot publication was rejected.
Maximum raw snapshot size was 14,968 bytes; maximum encoded datagram was 1,296
bytes, below the 1,392-byte MTU, with up to five packets per peer per publication.
Total encoded output was 16,456,816 bytes / 14,312 packets per peer over 60
simulated seconds. These are local serialization counts, excluding transport
framing. Local encoding ages event redundancy; it does not model remote
acknowledgement, loss, socket backpressure or recovery.

Static memory rose about 286.5 KB from start to the end of measured work in each
soak repeat and remained about 94.1 KB above start after cleanup. The process
static peak stayed at 72,541,251 bytes. This includes retained harness buckets
and reports; it is neither an allocation-rate measurement nor proof about leaks
or OS working set.

No supported full-system load envelope is newly accepted. No optimization was
retained or performance candidate rejected in this instrumentation slice.
The audit preserves earlier rejected P2 spatial-index and P7 eligibility work;
cluster regression and negligible end-to-end gain remain reasons to avoid
reintroducing those proposals without new matched evidence.

## Areas and lifetimes before / after

Every production dimension and lifetime is unchanged. The complete 36-recipe
[source-derived parameter table](evidence/scaling-baseline-20260914/area-lifecycle-baseline.json)
is the baseline for the later coordinated shape/serialization/rendering slice.
These are shape parameters, not interchangeable circles or occupied-area bounds.

| Shape / ingredient | Before = after this slice |
| --- | --- |
| Steam, expanding veil | Radius parameter 112.5 px; formation / active / decay 240 / 2,625 / 500 ms |
| Magma, front | Radius / length parameters 30 / 100 px; phases 350 / 2,750 / 500 ms |
| Firestorm, corridor | Radius / length parameters 22.5 / 162.5 px; phases 350 / 2,250 / 350 ms |
| Mistcurrent, corridor | Radius / length parameters 31.25 / 200 px; phases 220 / 2,750 / 400 ms |
| Terminal ingredients | Radius 30–40 px; element lifetime 3,000–5,000 ms |
| Trails | Radius 20 px; lifetime 800–1,500 ms; Rapid has no flight trails |
| Body hurt radii / common wall clearance | Small 15 / Middle 18 / Large 21 px; common clearance 18 px |

No generic scale was applied to Heavy, Spray, directional lanes, Rampart solid
geometry or trails. Larger footprints and at least doubled intended persistence
remain required, separately measured work. Current reaction validators stop at
125 px radius, 325 px length and 600 lifecycle ticks; terminal ingredient role
bounds stop at 40 px. Blind scaling would be rejected or clamped. Those limits,
snapshot compatibility, authoritative geometry, materials and guides must change
together when the shape-specific candidate is implemented.

## Limit inventory and next slice

The independent source audits cover
[runtime/contact](evidence/scaling-baseline-20260914/runtime-limits.md),
[network/event/actor](evidence/scaling-baseline-20260914/network-limits.md), and
[presentation/audio](evidence/scaling-baseline-20260914/presentation-limits.md).
The [review record](evidence/scaling-baseline-20260914/harness-review.md) distinguishes
independent observations from root's final corrections.

Immediate constraints include the 12-event queue, shared projectile/deposit
budget, 16-actor chemistry tracking limit and four-bit actor packing. More than
16 actors currently stops new reaction formation. Several session/prediction/
spawn/presentation limits remain eight. Raising only the lobby constant would
therefore produce an invalid future-player fixture. Live capacity stays eight.

Next in the single queue is B2: shared ordered contact and Spray's finite
ingredient/interception transaction, with immutable wall/range horizons,
event-time revalidation of mutable cover/actors, deterministic ties, refusal
without spend, and no post-negation outcomes. Evidence-only geometry drafts are
not integrated. The proposed coarse Spray contact lattice misses some thin and
tangent overlaps and is not accepted as exact geometry.

Then profile and optimize the measured costliest paths one at a time, retaining
correctness-equivalent reference oracles and dense-scene fallback. Only afterward
introduce shape-specific larger footprints and doubled persistence, validate
dense Steam/Magma/first-four balance, and consider proved capacity increases.
Matrix C (new enlarged/interception behavior), E (4×/16× contact demand), F (future
32 actors), exact contact/index counters, rendered distributions, physical latency,
allocation rate and socket recovery remain pending. The current fixture is the
legal B1 baseline; it cannot exercise unimplemented Spray ingredient/interception.

## Reproduce the stress checks

Close the playable game so the engine guard can grant exclusive ownership. Use
a fresh RunId for each invocation; the wrapper refuses to overwrite earlier runs.

```powershell
.\scripts\profile-four-delivery.ps1 -RunId my-matrix-001 -Case all -Ticks 720
.\scripts\profile-four-delivery.ps1 -RunId my-soak-001 -Case open-pressure -Ticks 7200
```

Run these sequentially, with other benchmarks and worker investigations idle.
The wrapper isolates Godot user data and checks the personal profile afterwards.
Outputs are `.godot/four-delivery-load-<RunId>.json` and matching `-logs` folders.
Final receipts/logs for this checkpoint are copied under
`docs/evidence/scaling-baseline-20260914/referenced/` with their hashes in
`preservation.json`. The report summarizer reads those retained copies.

Rollback of this slice is limited to the three added harness inputs and these
owned documentation changes, after checking for intervening edits. Existing
production, user data, working builds and historical evidence stay preserved.

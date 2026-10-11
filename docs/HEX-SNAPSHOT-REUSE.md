# H.E.X. snapshot reuse and engineering audit

Status: snapshot-only source validated on 2026-09-29; included in the subsequent
visual-hierarchy candidate, whose export gate is recorded separately.

Snapshot source: `p56-c47a989265ef`, protocol 56 / schema 22, 2,942 records.

## Audit conclusions and priority

| Priority | Finding | Improvement and acceptance |
|---|---|---|
| 1 — snapshot path | A fresh local baseline captures the whole world in 667.694 / 682.443 ms (distributed / dense); ordinary public hashes take 150.456 / 131.920 ms | Reduce redundant canonical projection and geometry reconstruction without changing bytes or removing producer/incoming checks; this checkpoint |
| 2 — authority representation | A mostly static 11,337-cell campus is still walked repeatedly for every state hash, validation and snapshot | Follow with explicit immutable topology plus sparse dynamic lanes; measure cold/warm/mutating worlds and schema compatibility before migration, never rely on a stale revision |
| 3 — drawing | Previous native frozen CPU submission p95 was 24–63 ms; hex ground alone 6–48 ms | Cache/batch visible static material geometry by actual state/phase, separately profile moving poses; preserve harm, ownership, occlusion and Reduced Effects cues |
| 4 — combat spikes | Previous simulation p95 ~12.8 ms, worst Spray tick ~65 ms; exact geometric work remains dominant | Attribute the remaining Spray/contact spikes; optimize broad worksets and witness reuse, not collision fidelity or paid costs |
| 5 — end-to-end hosting | Application requests snapshots at 60 Hz; current per-capture cost cannot sustain that cadence | Budget complete host + render + snapshot + restore + transport together; repeat same-export lifecycle before any friends-ready claim |
| 6 — player acceptance | Automated correctness does not establish satisfying movement, readable crowded combat or character animation quality | Human compare the seven revised reactions; inspect moving Rapid/weakened shots and eight-direction actions at native scale before further balance/art expansion |

This order prioritizes a stable responsive base over adding mechanics while
major time-budget failures remain. No balance, movement, damage, lifetime, range,
hitbox, camera, art or threat-indicator changes are included in this checkpoint.

## Implemented changes

| Change | Safety boundary |
|---|---|
| Canonical blank-cell JSON rows | Only exact three-key int32 metadata records use cached text; cache key includes coordinate and all three values, maximum 16,384 entries; no authority reference or whole-state hash cached |
| Sparse material JSON | Only shallow integer maps use separate serialization; wide, malformed, opaque or nested cell data falls back to the complete original serializer |
| Dense-data fallback | Preflight selects the general serializer above 12.5% nonblank records (minimum eight); avoids the earlier experiment's all-nonempty regression |
| Original recursion depth | All non-cell lanes remain in the original whole-document JSON context; a cells-only placeholder is substituted without changing later values or escaping |
| Detached geometry template | One template keyed by exact typed topology bytes, not a revision or probabilistic hash; every restored world gets a deep copy with no shared material dictionaries |
| Strict validation preserved | Every call checks actual metadata and material types; changed geometry/origin misses the cache; all conservation, provenance, cross-lane and producer roundtrip checks remain |
| Native geometry ordering | Native Vector2i sort replaces the identical x/y script comparator; canonical hash ordering remains the published string-key order |
| Lower allocation validation | Three direct metadata type checks replace a temporary comparison dictionary per cell; missing fields still reject |

The archived [D10 experiment](verification/hex-cell-json-20260923/HANDOFF.md)
was a negative result, not an accepted optimization. This is a new, measured
implementation for the current sparse 24 px campus. Its bounded blank-row cache
and dense fallback specifically address that experiment's poor results. Old
evidence is not counted as fresh acceptance.

## Verification contract

Fresh before/after probe: same campus, eight real paid actors, 120 warmup ticks
and 40 workload ticks, three direct calls per component. Timings are diagnostic
medians, not capacity percentiles. Inclusive nested measurements are not added.
The probe also alternates candidate/general hash measurements on changing state
and synthetic all-nonempty data, requiring exact canonical bytes every time.
Synthetic orphan material is a hash stress case, not a legal gameplay workload.

Focused tests cover direct metadata/material changes, integer boundaries,
fallback recovery, insertion/key replacement, opaque values, cache eviction,
cross-world ownership, changed topology/origin, malformed cached input and strict
snapshot roundtrips. Existing malformed snapshot tests remain mandatory.

## Fresh results

| Diagnostic, milliseconds | Baseline distributed / dense | Final distributed / dense |
|---|---:|---:|
| Whole-world hash median | 150.456 / 131.920 | 68.532 / 69.923 |
| Warm full-world capture median | 667.694 / 682.443 | 374.877 / 351.404 |
| Warm envelope capture median | 667.022 / 648.032 | 376.425 / 374.212 |
| Cold full-world capture median | Not separately measured | 516.463 / 575.788 |

Warm capture improves about 44% / 49%; it is **still much too slow** for the
requested 60 Hz snapshot cadence. These are three-call component diagnostics,
not end-to-end multiplayer or rendered-capacity results.

Twelve alternating candidate/general hash calls per arm preserve exact bytes:
changing-metadata medians 68.151 / 57.851 ms versus 140.588 / 129.750 ms;
synthetic all-nonempty medians 356.925 / 350.936 ms versus 355.075 / 347.858 ms.
The dense fallback adds about 0.5% / 0.9% median overhead in this synthetic case,
not the earlier candidate's large regression. This is not legal dense gameplay.

| Gate | Fresh result |
|---|---|
| Full | 172 suites / 1,534,214 assertions; zero failures/stderr; import, post-import identity, 120 Hz boot pass |
| Final snapshot probe | 820 assertions; cold/warm restores, wire roundtrips and exact pressure-case bytes |
| Simulation equivalence | All 1,440 measured tick states/events match the earlier checkpoint; p95 12.845 / 12.845 ms, max 64.191 / 66.199 ms: still above 8.333 ms |
| Native presentation preservation | 42 paid-combat PNGs match prior reviewed images by SHA256; visual refinement comes only afterward |
| Export | Snapshot-only state not separately packaged; subsequent visual checkpoint owns its combined export evidence |

The first final probe printed PASS but its error stream contained a typed-array
assignment error; the wrapper rejected it. Both failed receipt/error and corrected
final receipt are retained. Automated output is not accepted solely on a PASS line.
See [the evidence index](snapshot-reuse-evidence-20260929/README.md).
No installer, checkpoint pointer, commit, push or publication was performed.

## Next bounded checkpoint

Make static topology an explicit, validated immutable object and define sparse
dynamic canonical lanes. Preserve strict input validation at admission/restore
boundaries, and prove direct mutation is either impossible or detected. A protocol
or canonical-hash migration needs versioned compatibility tests, not an unnoticed
wire change. Do not start renderer and networking rewrites simultaneously.

Retain only the newest two independently verified exports. Archive small
receipts before pruning older generated payloads; preserve source art, user work,
personal settings and useful failed diagnostics. One lead owns engine execution.

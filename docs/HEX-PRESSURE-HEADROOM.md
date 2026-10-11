# Combat headroom checkpoint

Status: local checkpoint complete, 2026-09-30. Full/native/package correctness
passed for `p56-606574fca67f`; dense 120 Hz timing remains FAILED.
[Play](../exports/hex-headroom-20260930/windows/PLAY-HEX.cmd) ·
[Evidence](headroom-evidence-20260930/README.md) · [Playtest](HEX-PLAYTEST.md).
Previous `p56-c47fb65e2bd7` remains the verified fallback.

## Bounded implementation contract

Improve the ability to play fluidly amid interacting spells without reducing
the number of choices, hiding effects, dropping simulation work, or raising caps.
Preserve exact command-order independence, impact points, finite paid matter,
height rules, formation/active/decay timing, resources, all 32 spells and 36 pairs.

| Slice | Approach | Acceptance |
|---|---|---|
| Local physics | Conservative integer bounds before exact hex sweeps, overlap and wall attachment | Frozen collision oracle; face/vertex ties, distant pillars, large/negative coordinates |
| Definition reuse | Immutable compiled views for read-only hot consumers; mutable copies remain available | Every wire unchanged, nested immutability and recompile isolation |
| Spray contact | Bound nearest-witness work without changing contact ordering or quantization | Frozen analytic oracle, sparse/dense/degenerate fixtures and paid full-tick replay |
| Short flights | Prove both endpoints strictly inside one convex hex, then use exact whole-cell membership | General traversal remains for boundaries/crossings; complete entry/exit/witness records match |
| Integration | Full suite, paid pressure repeats, native UI/boot and source-bound Windows package | Record failures and timing tails honestly; keep exactly two verified builds |

No gameplay retune, new art, trails, network schema change or installer promotion.
Final evidence distinguishes real paid workload from synthetic geometry
stress and CPU simulation from rendered FPS, human fun and physical networking.

## What changed, and why it is safe

- Physics rejects closed integer bounds separated from a query, with a one-fixed-unit
  conservative guard. Survivors keep exact collision, surface IDs, lexicographic
  ties and embedded-structure escape. No broad-phase result grants a hit.
- Spray keeps the original nearest `(distance squared, x, y)` witness order.
  Only an actually accepted point establishes a pruning bound; invalid near
  candidates cannot exclude a farther valid contact. Same scalar/quantization
  predicates, whole-cell coverage and wall cutoff remain authoritative.
- Short projectile paths use a convex-interior proof, not a sample heuristic.
  Face/vertex contacts, crossings and ambiguous endpoints retain full traversal.
- Read-only combat callers borrow recursively frozen compiled definitions.
  Mutable APIs still return detached deep copies for per-cast range/damage edits;
  recompilation cannot mutate earlier borrowed data. No parallel rule table.

## Final fresh measurements

| Synthetic query, alternating 32 samples per arm | Old median | New median |
|---|---:|---:|
| Spray into dense 217-cell region |146.073 ms|4.549 ms|
| Spray into sparse region |32.425 ms|1.581 ms|
| 24 short-flight intervals |3.554 ms|1.790 ms|
| 24 wall-attachment queries /157 pillars |171.179 ms|34.166 ms|
| 24 circle sweeps /157 pillars |22.618 ms|6.840 ms|
| 320 definition reads |2.326 ms|0.548 ms|

These are synthetic CPU query batches, not per-frame gameplay or FPS claims.
Correctness: 392 comparisons, identical results, zero stderr. Each arm retains
the frozen preceding query or an equivalent detached definition read; these
batch timings are not the live scene timings below.

| Paid eight-caster simulation / two input orders | Preceding checkpoint | Final checkpoint |
|---|---:|---:|
| Median step |9.897 / 9.825 ms|8.251 / 8.237 ms|
| p95 step |18.387 / 17.971 ms|14.234 / 13.534 ms|
| Worst step |98.565 / 99.011 ms|53.479 / 52.212 ms|
| Steps above 8.333 ms / 720 |559 / 555|346 / 342|

All 1,440 tick states/events match the preceding paid workload exactly:
138 admissions, 35 deposits, 52 reactions; peak 29 flights, 32 cast records and
29 products. Trace SHA256:
`34dfdcd227e1ad57e440d37ee59fabb55855c4905a6bc8f52bacaf0e97bf6e7c`.
The final diagnostic passed 1,889 correctness checks. Approximately 23–25% lower
p95 and 46–47% lower worst steps are measured on this machine in sequential runs,
not a universal hardware guarantee. The 8.333 ms timing gate still FAILED.
This is neither extreme-projectile nor 32-player capacity acceptance.

| Final-source gate | Result |
|---|---|
| Focused geometry/field regressions |4 suites / 33,201 assertions, zero stderr|
| Full |173 suites / 1,791,867 assertions, zero failures/stderr; import/source identity and configured 120 Hz boot passed|
| Native ordinary UI |49 checks / 11 captures; paid held Bolt, release-stop, swap/no-op, bindings, attunement and disabled services passed|
| Windows package |30-skin native launch, source identity and safe close passed; payload and ZIP hashes checked|
| Retention |New headroom + preceding simplification builds retained; older boundary export removed, 299,635,049 bytes; small receipts preserved|

The native Loom, rebound HUD and 1600×900 layout were visually inspected.
The 11 PNG file hashes do not match the preceding run; no pixel-parity claim is
made. Exact simulation replay is separate evidence, not proof of equal rendered
frames. Human feel, moving/GPU pacing, physical controllers and remote play are
NOT_RUN in this slice. Historical snapshot capture cost remains a separate issue.

No commit, push, publication, installer or historical checkpoint-pointer promotion.
Remaining work: human tempo/counterplay comparison, then profile the remaining
admission/application tails and snapshot work without weakening exact rules.

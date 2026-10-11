# Combat headroom evidence

Status: final local checkpoint `p56-606574fca67f` verified, 2026-09-30.
Correctness/package passed; dense 120 Hz timing FAILED.
Design scope: [HEX-PRESSURE-HEADROOM](../HEX-PRESSURE-HEADROOM.md).

| Evidence | Classification |
|---|---|
| failed-focused-v1 | Rejected new fixture used nonexistent MoveResult.surface_id; stderr made the apparent suite pass invalid |
| focused-v2 | Corrected collision/geometry/definition tests: 5 suites, 20,323 assertions, zero stderr |
| focused-v3 | Final strict-interior shortcut and actor/field regressions:4 suites /33,201 assertions, zero stderr |
| queries-v1 | Rejected diagnostic script referenced script resource_path through a class constant; no timing accepted |
| queries-v2 | Synthetic alternating ABBA/BAAB CPU work; identical results, not live FPS or capacity evidence |
| pressure-v1 | 1,440 paid tick/event states match p56-c47 baseline. Worst step roughly55ms vs99ms; p95 mixed and still over budget |
| full | Final source p56-606574fca67f:173 suites /1,791,867 assertions, zero failures/stderr; import/identity/configured120Hz boot passed |
| headroom-queries-final |392 exact comparisons; 32 alternating samples per arm, all six synthetic batches improved; CPU diagnostic, not FPS|
| fine-grid-steps-headroom-final |1,889 checks; all 1,440 paid tick/event states exact; p95 14.234/13.534 ms, worst 53.479/52.212 ms; 8.333 ms timing gate FAILED|
| native |49 checks /11 frames, zero stderr; Loom/attunement/rebinding/held paid Bolt/release and disabled services|
| native-ui-comparison.json |0/11 PNG byte hashes equal to preceding run; not pixel-parity acceptance. Current Loom/HUD/large layout visually inspected|
| package |Windows portable p56-606574fca67f:30-skin native boot, identity, safe close, payload/ZIP verification passed; no installer|
| [friends-readiness](friends-readiness/README.md) |Fresh same-export lifecycle FAILED at120s; snapshot bottleneck isolated; insufficient typed-cache experiment removed and source restored to verified606 identity. Internet relay is not implemented|
| ../build-retention/hex-boundary-reuse-20260930 |Older generated build removed after guarded hash checks; 299,635,049 bytes; latest two functional packages retained|

No authority work, effect, cap, cost, timing or reaction was dropped to improve
measurements. Exact collision/field witnesses are compared with frozen preceding
control flow. Final source identity, full gate, repeated pressure correctness and
Windows package passed. Intermediate and failed records remain above; do not
mix their timings with the final source. Physical networking, moving rendered
performance and human feel remain separate and unverified here.

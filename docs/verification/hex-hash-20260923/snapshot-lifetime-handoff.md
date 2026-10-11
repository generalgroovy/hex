# Snapshot lifetime diagnostic handoff — 2026-09-23

Status: **root-run v2 PASS for the bounded single-process diagnostic: 671 assertions, 32 complete iterations, zero failures and zero stderr**. Root installed the reviewed draft as `tests/performance/profile_hex_snapshot_lifetime.gd`; the installed source is authoritative. This worker did not run Godot or create the imported UID.

## Bounded diagnostic

The script extends the existing production Wellspring profile fixture. It creates the genuine campus with 2,766 cells and eight production actors, runs the unchanged 120 neutral warmup ticks plus the first 40 paid dense-crucible ticks, and requires the established legal state: eight admissions, 4,800 paid matter, 29 active cells, 49 cells with stored material, and valid conservation. That authority then remains frozen for all measurement iterations.

Thirty-two iterations each call the actual production boundaries once:

1. `HexWorldSnapshot.capture(template)` with one inclusive timer;
2. `HexWorldSnapshot.prepare(snapshot, template)` with a separate inclusive timer;
3. `ClientPrediction.bind_hex_world(prepared)` with a separate inclusive timer.

Equality, Variant-byte comparison, world/Hex hashing, instance/ownership checks, memory observations, weak-reference checks, fixture work, and the one reversible independence mutation occur outside the three production-call timers. Each capture must equal the baseline snapshot and `var_to_bytes` buffer exactly. Every prepared replica and prediction authority must preserve the frozen world/Hex hashes while owning distinct objects. The first replica is mutated and restored outside timers to prove it cannot change the frozen source or detached prediction copy.

## Replacement order and tracked lifetime

One local holder Dictionary is the only strong owner of the current replica. Each iteration records weak references and instance IDs for the prior replica, its Hex authority, and the prior prediction authority. After prepare succeeds, the helper assigns the candidate into the holder and requires the superseded replica and authority to be released **before** prediction bind. It then binds prediction and requires the superseded prediction authority to be released. This matches Bootstrap's `world = candidate` then `client_prediction.bind_hex_world(world)` order without an observer-owned strong reference extending the old replica lifetime.

Rows record IDs and cell counts only for the known template/source, current replica, and current prediction authority. All three must contain 2,766 cells, but that three-field cardinality is explicitly not presented as a count of every live or unreachable world. The internal validation candidate created by `capture()` is not exposed and cannot be weak-tracked here. Final holder clearing and prediction reset must release the last explicitly tracked replica, replica authority, and prediction authority.

Immediate WeakRef expiry applies only to these isolated, explicitly tracked RefCounted instances; it does not prove that production Bootstrap has no additional holder. Instance IDs identify each tracked observation, but they are not treated as globally unique creation counts if the engine reuses an ID after release.

This is deliberately a mixed-role, single-process probe: the frozen source also acts as the trusted template, so host capture is sampled while client-style replica/prediction copies are resident. Its memory levels are not a real role-separated host or guest heap. The diagnostic does not run sockets, application scheduling, actual 60 Hz snapshot cadence, rendering, the 300-second lifecycle, or multiplayer capacity.

## Memory and interpretation

Every memory observation calls both `OS.get_static_memory_usage()` and `OS.get_static_memory_peak_usage()` outside timers. Nonpositive API results are recorded as `null` with the corresponding availability flag `false`; zero is not presented as measured usage. Rows sample before capture, after capture, after prepare, after replica replacement/before bind, after bind, and after the helper scope. The after-helper sample can show release of call-local snapshot, encoded-byte, and weak-reference structures, but allocator retention may keep static memory high after object release.

The baseline snapshot and its Variant-byte buffer remain resident for equality checks, and the diagnostic accumulates 32 receipt rows. That observer overhead contributes to reported static memory. The diagnostic does not subtract or attribute it.

Weak-reference expiry proves lifetime only for the explicitly tracked objects. A rising or monotonic memory series does not prove a leak, unreachable retention, allocator causality, or the cause of the historical lifecycle failure. The receipt states these limits and cannot establish lifecycle or release acceptance.

## Fail-closed receipt contract

The run cannot publish a passing populated receipt unless all 32 iterations complete and contain:

- exact capture Variant bytes and frozen authority hashes;
- 32 samples for each of capture, prepare, and prediction bind;
- complete available/unavailable memory observations at every named boundary;
- the three known 2,766-cell field records and actual instance IDs;
- successful prior-replica release before bind and prior-prediction release after bind;
- successful final release after holder clearing/reset;
- unchanged frozen source authority.

The receipt source-hash list names `tests/performance/profile_hex_snapshot_lifetime.gd`. The guarded output path is `res://.godot/hex-snapshot-lifetime-*.json` and must be fresh.

Root v2 command contract:

```powershell
Set-Location C:\Users\sende\Projects\hex
pwsh -NoProfile -File .\scripts\probe-hex.ps1 `
  -RunId hash-lifetime-v2 `
  -Script res://tests/performance/profile_hex_snapshot_lifetime.gd `
  -Output res://.godot/hex-snapshot-lifetime-hash-v2.json
```

Acceptance requires wrapper exit zero, zero stderr/warnings/failures, all completeness/release checks, and receipt source hashes matching the executed files. Preserve any failed run before revision.

## Root execution result

The first installed run is preserved as **FAILED / NOT A DIAGNOSTIC RESULT**. `docs/verification/hex-hash-20260923/snapshot-lifetime-v1.out` records four parse errors where GDScript could not infer instance-ID variables read through the Dictionary holder (`final_replica_id`, `final_replica_hex_id`, `previous_replica_id`, and `previous_replica_hex_id`). Root changed only those four declarations to explicit `int` types. No ownership order, timer, workload, assertion, or production behavior changed.

The fresh v2 run passed with Godot 4.7.1 headless:

- 671 assertions, zero failures, 32/32 completed iterations, and zero stderr;
- genuine 2,766-cell campus, tick 160, eight actors, eight admissions, 4,800 paid matter, 29 active cells, and 49 stored-material cells;
- exact 7,908-byte snapshot Variant/wire representation on every iteration;
- all 31 actual superseded replica and replica-authority transitions released before prediction bind (iteration 0 has no predecessor);
- all 31 actual superseded prediction-authority transitions released after bind;
- final current replica, replica authority, and prediction authority all released after holder clear/reset;
- installed source hash in the receipt matches disk: `62a1af0111f6a64af824f940bf4036eeec315f2d4b83686302a79c28d7c927d1`.

Inclusive stage timings in microseconds:

| Actual production call | p50 | p95 | p99 / max |
| --- | ---: | ---: | ---: |
| `HexWorldSnapshot.capture` | 383,143 | 426,223 | 435,382 |
| `HexWorldSnapshot.prepare` | 252,200 | 299,967 | 309,548 |
| `ClientPrediction.bind_hex_world` | 94,926 | 107,451 | 142,156 |

The 32-sample p99 is the observed maximum and is sample-limited. These calls were isolated and sequential; the values are not a scheduler, cadence, frame, network, or capacity measurement.

Both OS memory APIs were available. Static memory was 67,347,610 bytes before the repeated diagnostic and 67,666,026 bytes after it, a 318,416-byte difference that includes the retained baseline snapshot/byte buffer, accumulated receipt rows, allocator behavior, and all other observer/runtime effects. The process static-memory peak moved from 117,003,218 to 156,444,897 bytes; the final tracked-release observation was 67,658,870 bytes. These observations do not prove a leak or attribute the difference/peak to retained worlds. WeakRef evidence separately establishes only that the explicitly tracked instances expired at the asserted boundaries.

Evidence hashes:

- installed profiler: `62a1af0111f6a64af824f940bf4036eeec315f2d4b83686302a79c28d7c927d1`;
- preserved v1 failure output: `22e423ccfccaac7ed755f873ca9c0278d101ac7581175a1a1203a66aab63f7ba`;
- v2 stdout: `0259afc9fd97dd01df09a9e5c895996b6f958e0812e8de5a112b4889dd038ca4`;
- v2 receipt `.godot/hex-snapshot-lifetime-hash-v2.json`: `c42aaba828202e29877d4633f828ff2dcae5f4002de5a3ca3c20aa54c88f98c1`.

## Static evidence

- Installed profiler SHA-256: `62a1af0111f6a64af824f940bf4036eeec315f2d4b83686302a79c28d7c927d1`.
- Installed profiler length: 414 lines.
- `git diff --no-index --check` reports no whitespace errors; no conflict markers are present.
- No production, frozen oracle, existing profiler, queue, identity, export, or package file was changed.
- No Godot, import, test, profile, capture, export, PCK, EXE, network, or package command was run by this worker.

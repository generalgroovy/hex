# Snapshot-lifetime diagnostic review

Status: **STATIC AND V2 RECEIPT REVIEW COMPLETE; engine executed only by the root.** This is separate from the completed D2 runtime slice. No production changes, Godot runs, imports, tests, profiles or exports were performed by the reviewer.

Reviewed `.godot/hash-lifetime-draft.gd` and `retention-audit.md` against the bounded ownership paths in `Bootstrap._apply_world_envelope`, `HexWorldSnapshot.prepare`, and `ClientPrediction.configure/reset/bind_hex_world`.

## Finding and correction

The first draft retained the superseded replica in the helper parameter and caller locals until after prediction bind. Production assigns `world = candidate` before binding prediction, so the initial draft could hold one additional full authority during bind and attribute that synthetic lifetime to production. This was reported to the owner and corrected before execution.

The corrected draft uses a single strong `current.replica` holder. It obtains only IDs and WeakRefs to the superseded replica/court, prepares the new replica, assigns the holder, checks both old replica references expired, then binds prediction and checks the former prediction court expired. The helper has no surviving strong local or parameter referencing the old replica. Final cleanup clears the holder and calls prediction.reset; the helper's local prepared reference has already left scope. Returned rows contain values/IDs, not strong world references. This now reflects the relevant production replacement order.

## Scope, checks and limits

- It calls actual production capture, prepare and prediction bind on one frozen legal eight-actor, 2,766-cell, 29-active/49-material-record workload. Prediction owns a deep copy; a reversible terrain mutation checks that source and prediction authority do not change with the replica.
- Capture output is compared both structurally and as `var_to_bytes` to the unchanged baseline snapshot. World/Hex hashes are checked for the source, restored replica and prediction. The Variant-byte equality is a deterministic local snapshot check, not a new wire-format or network claim.
- Thirty-two completed iterations, populated timing sample arrays, per-row release flags and memory observation shape, and final weak-reference release are required. Actual execution must still reject stderr/script errors and verify the receipt; static review is not a compilation guarantee. The source-hash list expects installation as `tests/performance/profile_hex_snapshot_lifetime.gd`, so a draft-path run alone would not attribute the actual script correctly.
- WeakRef expiry is evidence only for the explicitly tracked prepared/replaced replica and prediction objects. Capture's internal validation candidate is not exposed or tracked. Known-field cardinalities do not count all live/unreachable worlds, and cannot establish global leak absence.
- Each timer wraps one named production call. Equality/hash/ownership assertions, memory reads, mutation and weak-release checks occur outside timers. There is no observer-inclusive aggregate replacement timer. Thirty-two samples provide a sample-limited tail; no cadence or sustained-load acceptance follows.
- The revised scope explicitly combines host capture and client-style replacement in one process, with the frozen source doubling as the trusted template. It is not the role-separated host/client heap, the application scheduler, 60 Hz snapshot cadence, sockets or the failed 300-second lifecycle.
- OS static/peak observations use explicit availability flags and null for unavailable/nonpositive values. They are engine static-memory monitor values, not independently measured PID private bytes or working set. Baseline snapshot/bytes and the accumulating 32-row receipt are observer-owned memory; they also contribute to static levels. A slope or plateau cannot distinguish a leak, allocator retention, serialization churn or unrelated allocations.

Recommendation: the corrected draft is suitable for the one bounded diagnostic run with strict stderr/completeness validation and source hashes. No remaining static blocker identified. Retain these attribution limits and do not present a passing diagnostic as network, capacity, rendered-performance or global memory acceptance. No production optimization is justified solely by this draft.
Reviewed draft SHA-256: `014dfca73e8a2d2a52ee59c162e1cf410eae92daf43cdba9bde7c3f29f346c4e`.


## Execution follow-up

The first installed run is **FAILED / no valid diagnostic result**. Logs under `.godot/hex-probe-hash-lifetime-v1/` and `snapshot-lifetime-v1.out` contain four parse errors: the Dictionary-derived final/previous replica and replica-Hex IDs could not have their types inferred (lines 142, 143, 181 and 182). The wrapper rejected the run. Static review did not establish compilation, and this failed attempt supplies no lifetime or timing evidence.

The installed script now declares those four variables explicitly as `int`; inspection found no algorithm change relative to the corrected draft. The worker subsequently expanded the draft's `retention_limit` prose, so the latest scratch draft is not byte-identical to the originally reviewed draft or installed file. The extra limits apply regardless: immediate expiry in this isolated RefCounted context does not prove production Bootstrap has no additional holders, and instance IDs are observation identifiers rather than globally unique creation counts if IDs can be reused.

Installed source reviewed for v2: `tests/performance/profile_hex_snapshot_lifetime.gd`, SHA-256 `62a1af0111f6a64af824f940bf4036eeec315f2d4b83686302a79c28d7c927d1`. V2 receipt review is complete below. Production runtime/package and sealed D2 review are unchanged by this diagnostic follow-up.

## Verified v2 result

`.godot/hex-snapshot-lifetime-hash-v2.json` and `.godot/hex-probe-hash-lifetime-v2/probe.log` agree on **PASS: 671 assertions, zero failures, all 32 iterations completed**. Stderr is zero bytes. All **11 recorded source SHA-256 values** match the installed files, including the reviewed installed diagnostic; the frozen production world source remains unchanged.

Independent receipt checks verified sequential iteration numbers, all 32 raw samples per stage matching their row-level samples, nearest-rank p50/p95/p99 and max values, each known topology field reporting 2,766 cells, unchanged expected world/Hex hashes in every row, six populated available-memory observations per row, and the superseded-instance ID chain. Iterations 1-31 report each prior replica/replica-Hex released before bind and each prior prediction authority released after bind. Iteration 0 correctly reports no previous objects. Final IDs match the last tracked objects and all three final WeakRefs report released after clearing/reset.

| Inclusive production call | Samples | p50, us | p95, us | p99 / max, us |
| --- | --- | --- | --- | --- |
| Capture | 32 | 383,143 | 426,223 | 435,382 |
| Prepare | 32 | 252,200 | 299,967 | 309,548 |
| Prediction bind | 32 | 94,926 | 107,451 | 142,156 |

The Godot static-memory monitor reads **67,347,610 bytes before the diagnostic and 67,666,026 bytes after it**, a **318,416-byte difference**. Its reported peak is **156,444,897 bytes**. The final tracked-object release observation reads 67,658,870 bytes before outer result/receipt bookkeeping. Baseline snapshot buffers and accumulated rows remain resident, so the difference cannot be assigned to a leak or to production ownership. These are not PID private-byte or working-set measurements.

Conclusion: the explicitly tracked replacement objects released at the checked boundaries in this isolated 32-iteration workload, while source/replica/prediction hash and ownership checks passed. The run also confirms that the named complete calls remain expensive on this host. It does **not** establish global leak absence, production Bootstrap's full holder population, the cause or resolution of the prior resource failure, real 60 Hz snapshot scheduling, networking lifecycle success, rendered performance or multiplayer capacity. The failed v1 stays preserved. Sealed D2 integration/package acceptance is unchanged by this diagnostic review.

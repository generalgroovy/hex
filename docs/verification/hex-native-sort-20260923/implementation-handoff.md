# Native hash-key sort candidate handoff

Status: **TEST-ONLY CANDIDATE READY; ENGINE NOT RUN**

Runtime source identity supplied by root: `p55-aeefbd4a5e7b`.

## Files

- `tests/support/hex_native_sort_candidate.gd`
  - SHA-256: `cfe9a711c0698934c01c652ea52d38a60e32b2cc696365336afca74bb7c0d7af`
  - Test-only `HexChemistryWorld` subclass.
  - Overrides only `_stable_hash_cells()`.
  - Formats each admitted `Vector2i` key once, sorts the resulting typed `Array[String]` with the native sorter, and performs inverse lookup to the original key.
  - Unsupported key types or an unexpected formatted-key collision return through `super._stable_hash_cells()`.
  - Record iteration, empty-cell specialization, compact fallback, and generic `_stable` conversion retain production types and order.
  - `from_world()` deep-copies every authority field consumed by `_state_hash_bytes()`; it keeps no cross-call cache or source alias.

- `tests/performance/profile_hex_native_sort_candidate.gd`
  - SHA-256: `ab4e6618d38380066ec93e04c213bcdbd0319662da44c81f86ce8aae52d2c885`
  - Extends the preserved hash candidate profiler only for its genuine Wellspring fixtures, workload helpers, statistics, and 38-case equivalence matrix.
  - Does not time or claim the older stateless prototype.
  - Times public `HexChemistryWorld.state_hash()` on the current production world against public `state_hash()` on the independently copied native-sort subclass.
  - Uses the preserved `hex_stable_cells_candidate.gd` only as an outside-timer frozen byte/hash oracle.

## Acceptance matrix

- Expected equivalence calls: 42 total: 38 inherited current-contract cases plus one cell, lexicographic-looking mixed-sign positions, reversed insertion order, and the 4,096-cell boundary.
- The inherited cases retain empty cells, negative/reordered coordinates, all float/bool/null/string metadata shapes, missing/malformed layers, mixed extras and equal-format nested ties, direct metadata mutation/restoration, layer transitions, and nested between-call mutation.
- A separate ownership case checks two independent candidate copies, nested/material/metrics isolation, and repeated add/remove/reorder mutations on the same candidate instance to reject hidden order caching.
- Profile cases: `production-empty`, `legal-paid-29-active`, and `synthetic-all-nonempty`.
- The first two use the genuine 2,766-cell campus; the synthetic case is explicitly invalid chemistry fallback pressure.
- Each arm receives 56 unbatched samples per case through four cycles of seven-sample ABBA/BAAB blocks.
- Fixture construction, deep copying, warmup, frozen-oracle comparisons, byte/hash checks, source checks, and identity checks remain outside timers.
- Completeness validation checks exact case order, cycle/block/arm order, seven samples per block, flattened raw-row identity, 56 samples per implementation, and statistics sample counts.
- Any failure exits nonzero. Partial receipts preserve completed raw blocks/cases rather than printing a false complete result.
- Receipt writes remain disabled unless the output path passed the fresh, scoped-path guard, so a failed preflight cannot overwrite prior evidence.

Expected output path: `res://.godot/hex-native-sort-candidate-*.json` and it must be fresh.

## Static checks

- Both new GDScript files pass `git diff --check` with no trailing whitespace.
- No `class_name`, production edit, registration edit, cache, copied outer hash pipeline, or old-prototype timing call was added.
- The candidate timing helper is named `_measure_native_block`; it does not incompatibly override the inherited four-argument `_measure_block`.
- Local integer-division warnings are explicitly suppressed, matching the inherited profiler convention.
- Source SHA-256 and runtime identity are checked before and after equivalence/timing and written to the receipt.

## Assumptions and limits

- The candidate assumes native `Array[String].sort()` uses the same strict String ordering as the current cached `String(a) < String(b)` comparator. Exact bytes across the full matrix must prove this at runtime.
- `str(Vector2i)` is expected to be injective for the production key domain. The candidate still falls back if duplicate formatted text is observed.
- The 4,096-cell case is an equivalence boundary, not a timed legal gameplay workload.
- No performance, frame, cadence, capacity, networking, package, or export result is claimed until root runs and audits the isolated receipt.

Godot/import/tests/capture/profile/export: **NOT RUN by implementation agent**.

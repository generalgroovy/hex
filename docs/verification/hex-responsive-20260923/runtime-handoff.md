# Runtime handoff — stateless trusted-cell validation

Date: 2026-09-23  
Working fallback: `p55-ede24ea44158`  
Imported development identity after this source slice: `p55-88927e8914d5`  
Scope: one stateless `_trusted_cells` fast path, an independent frozen oracle, equivalence tests, and matched microprofile evidence. No schema, protocol, topology representation, simulation cadence, balance, cache, source ownership, or capacity change.

## Change and invariants

`src/net/hex_chemistry_snapshot.gd::_trusted_cells` now creates one local canonical empty-cell record per invocation. After the existing topology bound, origin, key, record, and integer metadata checks, it copies the current record's three metadata integers into that local record and uses native structural equality to recognize the dominant exact blank shape. Exact blanks skip the 44 interpreted material-layer checks. Records with extras, missing or malformed layers, or any nonempty layer fall through to the original full validator. The result still uses `HexGrid._cell_less` canonical ordering.

The shortcut is stateless. It stores no authority reference or result, mutates no source record, and observes direct mutations on the next call. The original validator was copied independently into `tests/support/hex_trusted_cells_legacy_oracle.gd`; it deliberately has no `class_name`, so it does not add an unexpected global script class.

`tests/unit/test_hex_snapshot_optimization.gd` adds old-oracle comparisons for negative and reordered coordinates, accepted scalar/dictionary extras, nonempty material records, missing and malformed metadata/layers, non-`Vector2i` keys, non-dictionary records, invalid origins, the exact 4,096-cell bound and 4,097 rejection, between-call mutation visibility, source identity/deep equality, and production snapshot/prepare round trips. Existing ownership, revision, and state-hash tests remain.

## Evidence

The unchanged pre-edit stage baseline is `.godot/hex-snapshot-stages-responsive-baseline-v1.json`: Godot 4.7.1 headless on Windows, AMD Ryzen 3 7320U, genuine 2,766-cell Wellspring topology, eight actors, 120 warmup ticks plus 40 paid workload ticks, 29 active cells, 332 assertions, zero failures. Its validator source SHA-256 is `5624b2f71e6b6e13e799c13e09f17a7abbff641da830d8bb77709fa9f7f1504c`.

The first ABBA attempt is **FAILED harness evidence**, despite its premature `PASS` line. `docs/verification/hex-responsive-20260923/abba-v1.out` records three runtime errors at the former profiler line 107 because a ternary-created untyped `Array` was assigned to `Array[String]`. Its JSON has no valid timing blocks and must not be used. The wrapper correctly rejected stderr. The profiler now assigns the typed order explicitly and requires seven samples in every block, all 16 blocks per case, eight blocks per implementation, and exactly 56 samples per implementation before success.

Fresh root-run ABBA v2 is `.godot/hex-trusted-cells-responsive-v2.json` and `docs/verification/hex-responsive-20260923/abba-v2.out`: **PASS, 584 assertions, zero failures/stderr**. Four cycles alternate ABBA/BAAB, seven samples per block, producing 56 samples per implementation per case. Fixture construction, warmup, equality, source identity/hash, topology hash, and deep source checks are outside the timers. All returned cell arrays and source invariants matched the frozen legacy oracle.

| Same 2,766-cell topology | Legacy p50 / p95 / p99 / min / max (µs) | Candidate p50 / p95 / p99 / min / max (µs) | p50 / p95 change |
| --- | ---: | ---: | ---: |
| Exact empty records | 59,993 / 61,892 / 62,719 / 54,441 / 62,719 | 26,584 / 31,128 / 37,769 / 25,268 / 37,769 | -55.7% / -49.7% |
| Representative 29 nonempty records | 59,083 / 61,951 / 62,410 / 50,698 / 62,410 | 27,010 / 30,649 / 33,576 / 25,733 / 33,576 | -54.3% / -50.5% |
| Synthetic all-2,766 nonempty fallback | 58,911 / 61,804 / 64,231 / 50,599 / 64,231 | 60,943 / 62,764 / 67,340 / 54,433 / 67,340 | +3.4% / +1.6% |

Every one of the 56 samples in every implementation/case exceeded both 8.333 ms and 16.667 ms. p99 is only the nearest-rank maximum of 56 samples, not a tail-capacity estimate. The 29-record and all-nonempty fixtures add one synthetic material entry per selected record; they are validator pressure and do not claim a legal paid simulation workload. Godot exposes no allocation count here.

The source profile is tied to validator SHA-256 `722cdc67a124645f1656b14fc602158fd50e72459f349f4780ef85625e7ed4f1`, oracle `19c22a811f91c576181d163a4ec457d328ac5a71fc41effceb624d897dd02ac0`, profiler `8bda9e932adbf10647b8244cf88831cd0458d617eda36a8400fdf385eb754627`, map hash `9d481a582a0e84c1ecb74ee7637ba6cd7f9119deb0eeacdc509904f5d4810417`, definition hash `6122177196f65528fd9291827319778a82faf4ee5dbc2cf7a629a59390f1e23e`, and topology hash `2c41dd235abc0576b587aeeb8a614f0a9aa8507104df7fdc556428abb721b9de`.

The root-run post-change stage receipt is `.godot/hex-snapshot-stages-responsive-stages-v1.json`: **PASS, 332 assertions, zero failures**, with the same authority hash `6920447054711abf68fce43a66b56814a0b0a9b085e5e6a9b2119a9bf56291ce`, chemistry hash `f77fec6a943ef75ca80596dd92b5ab50c4c455063a031e7fddbf45396c572c76`, topology, workload, and candidate source hash. It is a separate five-sample run, not an alternating before/after experiment:

| Inclusive stage | Baseline p50 / p95 (µs) | Candidate p50 / p95 (µs) | p50 change |
| --- | ---: | ---: | ---: |
| Chemistry capture | 144,756 / 162,131 | 112,486 / 124,656 | -22.3% |
| World capture | 488,128 / 571,758 | 406,548 / 496,395 | -16.7% |
| World prepare | 344,384 / 463,708 | 266,051 / 269,142 | -22.7% |
| Chemistry restore | 277,381 / 624,855 | 336,074 / 413,697 | +21.2% |

The restore p50 regression is noisy and unresolved: each run has only five samples, baseline p95 was 624,855 µs, and the run order was not alternated. Unchanged-stage variation is also visible (`blank_world` p50 100,472→82,615 µs and `world_hash` 75,628→76,678 µs). Only the isolated ABBA validator comparison establishes causal local improvement. The stage results show the expected broader direction while preserving hashes; they do not prove frame, 120 Hz, networking, export, or release capacity.

The root-run Fast import/boot gate passed with zero stderr but executes zero unit suites. The focused `hex-snapshot-optimization` suite remains a required explicit run unless a later Full receipt includes it. This worker ran no Godot process.

## Next source-backed gate

World capture remains the dominant measured stage at p50 406,548 µs. It inclusively performs chemistry capture, packing/compression, actor/projectile encoding, and a complete `HexWorldSnapshot.prepare` producer round trip. World prepare alone is p50 266,051 µs. Its source path decompresses and unpacks chemistry, calls `HexChemistrySnapshot._prepare`, reconstructs dynamic collision, creates a new `SimWorld`, validates cross-authority relations, and verifies the outer state hash. These inclusive numbers do not isolate which of those operations now dominates.

The current `HexChemistryWorld.state_hash` already has a native exact-empty-cell structural branch: blank records do **not** execute 44 interpreted layer iterations. It still builds `compact_cells` for all 2,766 cells, canonicalizes/sorts that full dictionary through `_stable`, JSON-serializes the complete canonical value, and hashes it on every call. The unchanged `world_hash` measurement (p50 76,678 µs after) includes outer player/projectile fields as well, so current evidence does not attribute that time to layer scanning or even exclusively to chemistry hashing.

The next smallest safe step is measurement, not a topology rewrite: add matched, outside-acceptance instrumentation that separates chemistry compact projection, `_stable` canonicalization, JSON encoding, SHA-256, chemistry reconstruction/configure-geometry, collision-surface reconstruction, and the outer verified hash on the same unchanged 29-active-cell authority. Use empty, legal 29-active, and synthetic dense pressure, alternating current/oracle order with source/hash checks outside timers.

If that decomposition shows canonicalization/JSON dominates, the bounded candidate is a stateless specialized serializer/projection that produces **byte-for-byte the existing canonical value and SHA-256**, rather than changing the state-hash formula to topology-hash-plus-sparse-state. Required equivalence includes reordered insertion, negative `Vector2i` cells, all metadata, empty/nonempty material layers, extras and malformed public mutations, mixed dictionary key types, nested arrays/dictionaries, booleans/null/numbers, and between-call mutation visibility. No cached trust is safe while `cells` and nested records remain publicly mutable. A changed hash formula would be a protocol/replay migration and is outside this slice.

If reconstruction dominates instead, profile `HexChemistrySnapshot._prepare`'s `configure_geometry`/metadata copy separately from decode, relation validation, and final hash. Any immutable-topology or sparse-active-state design must retain a fresh independently mutable returned authority, exact malformed-input rejection, full material dictionaries expected by live simulation/presentation, local trusted ownership, collision equivalence, canonical hashes, and current 4,096-cell limits. Do not omit the complete producer round trip merely to lower capture timing.

## Integration commands

Root only; use fresh receipt/run IDs:

```powershell
Set-Location C:\Users\sende\Projects\hex
pwsh -NoProfile -File .\scripts\test.ps1 -Tier Focused -Suite hex-snapshot-optimization -ReceiptPath docs/verification/hex-responsive-20260923/snapshot-focused-v1.json

pwsh -NoProfile -File .\scripts\probe-hex.ps1 `
  -RunId trusted-cells-responsive-v3 `
  -Script res://tests/performance/profile_hex_trusted_cells.gd `
  -Output res://.godot/hex-trusted-cells-responsive-v3.json

pwsh -NoProfile -File .\scripts\probe-hex.ps1 `
  -RunId snapshot-stages-responsive-after-v2 `
  -Script res://tests/performance/profile_hex_snapshot_stages.gd `
  -Output res://.godot/hex-snapshot-stages-responsive-after-v2.json
```

The focused suite must pass with zero stderr. A valid validator receipt must contain three cases, 16 blocks and 56 samples per implementation in each case, zero failures, identical returned cells, and unchanged authority/topology hashes. The stage rerun must retain the exact workload and authority hashes. Promotion still requires the unchanged representative dense workload, Full suite, exact export/PCK evidence, and the separate stress/network/human gates owned by integration.

## Files

- `src/net/hex_chemistry_snapshot.gd`
- `tests/unit/test_hex_snapshot_optimization.gd`
- `tests/support/hex_trusted_cells_legacy_oracle.gd` and `.uid`
- `tests/performance/profile_hex_trusted_cells.gd` and `.uid`
- this handoff

Static checks: owned source/test files have no conflict markers; `git diff --check` is clean. Engine/import/test/profile evidence above was produced by the integration lead, not this worker.

Final focused gate: `docs/verification/hex-responsive-20260923/focused-v1.json` and `.out` are root-run **PASS** evidence for nine selected suites, 7,153 assertions, zero failures, and zero stderr. This includes `hex-snapshot-optimization` (235 assertions), `hex-chemistry-snapshot`, `hex-world-snapshot`, `unified-prediction`, Water presentation, and visibility/presentation suites. The earlier focused-suite pending note is therefore closed; Full, export/PCK, stress, network, and human gates remain separate.

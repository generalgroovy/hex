# Strict packed wire decode candidate handoff

Date: 2026-09-23  
Scope: D4 test-only prototype; no production, registration, import, engine, capture, profile, export, identity, queue, or package action by this agent.

## Candidate

`tests/support/hex_wire_decode_candidate.gd` contains two test-only entry points:

- `composed_current()` is the frozen behavioral oracle: current `HexSnapshotWirePacking.validate_structure(packed, cell_count)` followed by current `HexSnapshotWirePacking.unpack(packed, cell_count)`.
- `strict_decode()` fuses those two calls. It preserves the current shape, schema, header, count, flattened-row, positive/ordered-ID, sparse-plane, variable-row, and cell-count checks. It calls the current private leaf helpers and constructs the same detached dictionary in the same insertion order with the same typed conversions and fresh nested output. It has no cache, unchecked route, compression change, or topology change.

The candidate deliberately preserves structurally accepted values that are not semantically constrained by the current composed pipeline: arbitrary string contents for both hashes, zero-length variable payload rows, arbitrary lengths and values in `pending`, `sources`, `exposure`, and `flow_carry`, and any `PackedInt64Array` metrics length. A caller cell count of `-1` remains rejected because validation's default accepts it but the following public `unpack()` rejects it.

## Diagnostic

`tests/performance/profile_hex_wire_decode_candidate.gd` is a fail-closed isolated decode microbenchmark. It must write only to a fresh `res://.godot/hex-wire-decode-candidate-*.json` path.

The 87 exact equivalence cases derive as follows:

- 2 valid structural cases, including the accepted loose-semantic lanes;
- 4 cell-count boundaries: `0`, `-1`, `4096`, and `4097`;
- 2 missing/extra-key shapes;
- 18 wrong top-level lane types;
- 9 schema/header size/value cases;
- 2 cast/product count-cap cases;
- 14 cast/product ID, order, row-ID, and flattened-length cases;
- 16 cast/product sparse truncation, trailing-byte, row/cell-bound, zero-amount, duplicate/decreasing-order, and maximum-row cases;
- 15 variable-row wrong-ID, negative-count, truncated-header/payload, and trailing-value cases across all three variable lanes;
- 3 direct mutate/reject/restore calls;
- 1 nested output/source ownership case;
- 1 maximum bounded packed-lane success case.

The timed cases run in this order:

1. the genuine 2,766-cell, eight-actor dense-crucible authority after 120 neutral warmup ticks and the existing first 40 paid ticks, with exact 8 admissions, 4,800 paid matter, 29 active cells, 49 stored material cells, and conservation checks;
2. the genuine empty 2,766-cell campus authority;
3. one explicitly non-gameplay 4,096-cell synthetic pressure value with 64 cast rows, 32 product rows, 38,400 cast-allocation rows, and 4,064 product-allocation rows. Variable rows have zero payload because the current grammar defines no payload-count maximum.

Each case uses four alternating cycles: ABBA on even cycles and BAAB on odd cycles, seven unbatched decode samples per block, 16 blocks total, and 56 raw samples per implementation. `production_composed` times the actual current validation-then-unpack pair. `candidate` times one strict fused decode. Fixture construction, byte/equality checks, source hashes, malformed cases, and ownership checks stay outside timers. Completion guards require exactly 87 equivalence cases, 3 profile cases, 16 blocks per case, and 56 samples per implementation before a receipt can report success.

The receipt records original packed Variant/lane byte sizes, decoded byte size, raw blocks and samples, paid metrics/occupancy, topology count, batch size 1, and source SHA-256 values. Any measured benefit is limited to isolated decode. It cannot establish a whole-prepare, capture, frame, rendered, networking, allocation, export, capacity, or release gain.

## Static verification

- `git diff --check` on both new GDScript files: PASS.
- Manual contract trace against `src/net/hex_snapshot_wire_packing.gd`: PASS; exact composed acceptance and output order retained, with immediate rejection after each shared leaf parser.
- Manual completion arithmetic: PASS (`87 = 2+4+2+18+9+2+14+16+15+3+1+1`; `56 = 4 cycles * 2 blocks per implementation * 7 samples`).
- Engine/import/test/profile execution by this agent: `NOT_RUN` by assignment. The root-owned isolated run is recorded below.

Source hashes below are SHA-256 over the ready-to-run files and must be refreshed if either source changes:

- `tests/support/hex_wire_decode_candidate.gd`: `dc3b9dd0f656a99bdaf36ea939a36178107abc0ade7859a3385cd5304af5fd05`
- `tests/performance/profile_hex_wire_decode_candidate.gd`: `2330d3606162aba95111a2748cee9f62cedb16100c6fa816d0f3e5dcca31d1cf`

## Root-owned v1 result

The root-owned Windows headless run passed with `PASS: hex-wire-decode-candidate; 1105 assertions; 0 failures`, 87/87 equivalence cases, 3/3 populated profile cases, 48/48 blocks, 336 raw timed samples (56 per implementation in each of three cases), and zero stderr. It ran Godot `4.7.1-stable (official)` on the recorded AMD Ryzen 3 7320U host. The legal fixture reproduced the expected 8 actors, tick 160, 8 admissions, 4,800 paid matter, 29 active cells, 49 stored material cells, and exact paid metrics in the receipt.

| Case | Packed bytes | Current composed p50 / p95 / p99 | Candidate p50 / p95 / p99 | Median delta |
|---|---:|---:|---:|---:|
| Legal paid dense-crucible | 3,788 | 162 / 237 / 296 us | 88 / 132 / 138 us | 74 us |
| Empty campus | 740 | 31 / 33 / 34 us | 19 / 20 / 21 us | 12 us |
| Synthetic maximum bounded lanes | 268,916 | 48,786 / 60,512 / 96,631 us | 24,698 / 53,898 / 88,948 us | 24,088 us |

The synthetic row is non-gameplay pressure and showed substantial tail variance; it is not a capacity or runtime workload result. All raw rows remain in the receipt.

Evidence:

- receipt: `.godot/hex-wire-decode-candidate-hash-v1.json`, SHA-256 `7dfe7bcd47d743e0b97623e2c7be0aafb786bf81ccd18853fd8fbc2e3825642e`;
- stdout: `.godot/hex-probe-hash-wire-decode-v1/probe.log`, 197 bytes, SHA-256 `1845011e0d25a435acd1517fed2e3e053378ffd6101dda02d7dfbb8664dba4e4`;
- stderr: `.godot/hex-probe-hash-wire-decode-v1/probe.log.err`, 0 bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The receipt binds the frozen candidate sources above and the exact compared production codec:

- `src/net/hex_snapshot_wire_packing.gd`: `d3d5cfb801811244eca8113174e931820266835f2733329368454a32849ed07b`;
- `src/net/hex_chemistry_snapshot.gd`: `722cdc67a124645f1656b14fc602158fd50e72459f349f4780ef85625e7ed4f1`;
- `src/sim/hex/hex_chemistry_world.gd`: `7582964d1c889f1ceaf5114ff6600eb3ead842318e4cf6db95aed1d82985cb7b`;
- `tests/performance/profile_unified_wellspring.gd`: `7f524c49f7104f7a549c964f759248c0b1d8abff8da1d12e19a0c7ae728ee6b9`.

## Disposition

Production integration is deferred. The legal workload saved 74 microseconds at the median inside isolated decode, while the current measured whole prepare is roughly 252 milliseconds. This run did not measure an end-to-end prepare improvement, so the result does not justify production churn on its own. The candidate and profiler remain test-only evidence for a future broader prepare optimization, with no production, compression, topology, cadence, workload, or capacity change.

# Independent review: test-only H.E.X. state-hash candidate

Status: REVIEWED. No valid-domain semantic blocker identified. The valid v2 receipt supports integrating the exact measured specialization as a bounded optimization, followed by fresh focused/full regression and export checks. This is not responsiveness or release acceptance.

Scope: `tests/support/hex_stable_cells_candidate.gd` and `tests/performance/profile_hex_hash_candidate.gd`, compared with current `HexChemistryWorld.state_hash`, `_stable`, `_new_empty_cell`, and `canonical_bytes.gd` in `C:\Users\sende\Projects\hex`. This reviewer made no runtime edits and ran no Godot, imports, tests, profiles, or exports. The parent owns engine execution. The runtime identity file currently records `p55-1ce2d09597b3`; that file alone is not an independent rebuild or release verification.

## Static findings

- The candidate preserves the 14 outer fields in production order, Vector2i `[x,y]` conversion, formatted-string ordering of valid Vector2i cell keys, and the metadata order `elevation`, `structure`, `terrain`. It then uses the same JSON serialization, signed 64-bit little-endian UTF-8 byte-length prefix, UTF-8 data, and SHA-256 routine.
- Specialization requires all three metadata values to have exact `TYPE_INT` and the complete record to equal a fresh empty-cell template after refreshing its metadata. Therefore extra fields, missing fields/layers, malformed metadata, and nonempty materials cannot silently take the fast path. The fallback discards only empty Dictionaries and delegates recursion to production `_stable`.
- The independent frozen oracle has its own projection loop and recursive `_stable` copy matching the current source. Nested integer/string keys with equal formatted text retain production comparator behavior; the candidate makes no new tie-order guarantee. Both insertion orders are represented by explicit fixtures.
- There is no retained world reference, persistent cache, or between-call data reuse. All templates, compact records, key arrays, and stable arrays are call-local; the candidate reads live authority every call. Fixtures cover metadata mutation/restoration, nested mutation/restoration, and empty-to-nonempty material transitions.
- Equivalence is scoped to valid top-level Vector2i keys and Dictionary records, with production's String-typed record-key iteration. The prototype preserves those typed operations. Sorting happens before typed cell iteration, so this review does not claim identical error timing for unsupported key or record types. It does not accept arbitrary cyclic Variant graphs.
- Benchmark A is the actual current `court.state_hash()`, not the frozen oracle. B is the complete `Candidate.candidate_hash()`, including stable projection, serialization, byte prefixing, and SHA-256. The oracle and byte comparisons are outside timers. Alternating ABBA/BAAB blocks reduce simple order bias; 4 cycles x 2 blocks x 7 samples yields 56 samples per implementation per case. The nearest-rank p99 is consequently the observed maximum, not a robust tail estimate.

## Execution evidence

The first run is **FAILED / INVALID** despite `probe.log` reporting `PASS: 505 assertions; 0 failures`. `.godot/hex-probe-responsive-hash-candidate-v1/probe.log.err` records a warning-as-error parse failure at support line 50, dependency compilation failure, and cascading calls to nonexistent oracle functions. `.godot/hex-hash-candidate-responsive-v1.json` contains three empty case objects and no timing blocks. Its PASS text and zero assertion failures establish neither equivalence nor performance. Preserve this artifact as failed evidence.

The fresh v2 run is **VALID for its stated local hash-call scope**: `.godot/hex-hash-candidate-responsive-v2.json`, stdout/stderr under `.godot/hex-probe-responsive-hash-candidate-v2/`. It records **1,134 assertions, 0 failures, 38 completed equivalence cases, and 3 completed profile cases**, with zero-byte stderr. The support script now explicitly types the oracle stable value as Variant. The profile adds completion counters, expected case identities, block/sample structure guards, and failure exits before publishing a populated receipt. The original false-PASS failure mode is addressed; external stderr checking remains necessary.

Independent read-only verification matched all **10 source SHA-256 values** against disk at review time, including the actual production implementation and both prototype files. It also checked all **48 block entries**, cycle/block numbering, alternating ABBA/BAAB order, 7 samples per block, 8 blocks/56 samples per implementation per case, and equality between flattened block samples and the aggregate sample arrays. All six p50/p95/p99 rows recomputed correctly from raw samples. Every sample in both implementations exceeds 8,333 and 16,667 microseconds.

| Case | Material-nonempty / active cells | Production p50/p95/p99, us | Candidate p50/p95/p99, us | Median reduction |
| --- | --- | --- | --- | --- |
| Production empty | 0 / 0 | 77,529 / 97,630 / 117,839 | 58,752 / 69,995 / 71,850 | 24.2% |
| Legal paid workload | 49 / 29 | 80,370 / 86,738 / 93,743 | 62,854 / 71,555 / 75,091 | 21.8% |
| Synthetic all-nonempty | 2,766 / synthetic active metric 0 | 141,873 / 150,596 / 164,704 | 136,908 / 141,828 / 142,850 | 3.5% |

All three fixtures have 2,766 topology cells. Distinguish 29 active cells from 49 material-nonempty records in the legal fixture. Empty/legal improvements are large enough to justify the exact bounded integration and renewed regression checks. The small synthetic fallback improvement is only a local observation and should not be generalized as a reliable speedup. There is no measured fallback regression in this run.

Recommendation: integrate the exact measured path with its integral metadata guard, call-local ownership, identical cell ordering and generic fallback; preserve the independent frozen oracle and transition/tie fixtures; then obtain fresh focused/full and exported-artifact regression evidence. Preserve pre-integration v2 sources or hashes so this receipt remains explicitly tied to the former production baseline. Changing production later makes its receipt hash historical, not invalid evidence of this completed comparison.

## Limits

These are headless isolated hash-call measurements. They do not establish whole-frame or 120 Hz performance, rendered responsiveness, allocation behavior, actual multiplayer capacity, exports, physical networking, or human visual acceptance. The all-nonempty case deliberately inserts invalid chemistry authority and only measures fallback pressure. The parent reported very low available physical memory earlier in the session. The saved mid-run OS observation records 859,576 KiB free physical out of 7,634,556 KiB at 2026-09-23T15:08:51.5795734Z, with 11,033,192 KiB free virtual. That is one observation, not a peak, allocation count, or attribution of the timing. Treat these results as resource-constrained local observations; ABBA reduces simple order bias but does not isolate paging, thermal effects, or unrelated host activity.


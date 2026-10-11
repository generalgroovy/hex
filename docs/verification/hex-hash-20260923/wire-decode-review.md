# Independent D4 strict wire-decode candidate review

Status: **STATIC AND RECEIPT REVIEW COMPLETE. Test-only candidate retained; production integration deferred.** Scope is test-only `hex_wire_decode_candidate.gd` and `profile_hex_wire_decode_candidate.gd`, compared with current `HexSnapshotWirePacking.validate_structure(packed, cell_count)` followed by `unpack(packed, cell_count)`. Public `unpack` alone is explicitly not the oracle. Reviewer owns only this document and performs no engine operations or code edits.

## Contract and ownership

The candidate preserves the composed pipeline's shape/schema/header/ID gates, cast/product maxima, flattened-row sizes, sparse ordering and bounds, variable-row exact-ID/count/trailing-data rules, dictionary insertion order, typed detached rows and metrics duplication. It reuses the same production leaf parsers, avoiding duplicated traversals without introducing a second grammar. It rejects cell_count=-1 because composed unpack rejects it even though validation alone supports the default. It retains structurally accepted arbitrary string hashes, direct packed scalar lanes and arbitrary metrics lengths; semantic chemistry validation remains elsewhere.

No result or authority reference is cached between calls. Detached rows and converted/copied packed lanes are constructed per call. Tests cover direct header invalidation/restoration between calls, output mutation independence and input-byte preservation. The executed equivalence and ownership cases support this intended stateless and independent-output contract.

## Corrections raised during review

1. The initial ownership test indexed metrics[0] while the small base fixture's metrics array was empty. The owner changed the base metrics to PackedInt64Array([0]), allowing the intended nested-output mutation to execute.
2. The initial fused candidate parsed all five leaf lanes before checking for rejection, while the actual composed validator short-circuits on the first malformed lane. This could add work and allocations for an invalid early plane with large later lanes. Reviewer requested an immediate null return after each parse to preserve the production rejection sequence. Resolved and verified: immediate null returns now follow cast sparse, product sparse, product sources, cast parts and product states in the same rejection sequence.

## Experiment

The profiler declares 87 deterministic equivalence cases, covering supported acceptance plus malformed shape, every lane type, schema/header sizes and values, cast/product counts, ID ordering, sparse and variable lane errors, mutation/restoration and output independence. Three timed cases run in order: genuine legal paid campus, genuine empty campus, and synthetic bounded packed-lane pressure. Legal workload checks require eight actors/admissions, 4,800 paid matter, 29 active and 49 stored cells, and conservation on 2,766-cell campus geometry.

Synthetic pressure explicitly uses 4,096 topology cells, 64 cast rows, 32 product rows, maximum bounded sparse row counts and zero-length variable payloads. It is structurally decodable data with fabricated rows/hashes, not legal chemistry, actual world capacity, or maximal variable-lane pressure (that grammar has no payload-count maximum).

Each implementation receives three untimed warmups then four alternating ABBA/BAAB cycles, two seven-sample blocks per implementation per cycle: 56 samples per implementation/case. Each timer surrounds one complete decode call, including its baseline wrapper; fixture construction, source/byte equality and mutation checks are outside timers. No loop batching is used. Nearest-rank p99 is the sample maximum. Completion counters and populated case/block/sample guards reject skipped or empty results; external stderr checking remains required.

Acceptance here can establish a bounded decode-only comparison. It cannot establish complete prepare/capture, network scheduling, compression, allocation, frame, export, release or capacity gains. Production implementation and the frozen D2 package are not changed by this prototype. Receipt/source hashes, raw blocks and timing evidence were independently verified below.


## Verified experiment and decision

`.godot/hex-wire-decode-candidate-hash-v1.json` and its log agree on **PASS: 1,105 assertions, zero failures, 87 completed equivalence cases and three completed timing cases**, with zero-byte stderr. All **nine recorded source SHA-256 values** match disk. The production wire codec, chemistry snapshot codec and chemistry world hashes also match the preceding lifetime receipt; this candidate has not changed those production files.

Independent checks confirmed all **48 blocks**, cycle/block indices, alternating ABBA/BAAB order, seven samples per block, 56 samples per implementation/case, and equality between concatenated block samples and aggregate arrays. All six minimum/maximum/p50/p95/p99 rows recompute correctly. Fixture metadata confirms the legal eight-actor, tick-160, eight-admission, 4,800-paid-matter, 29-active/49-stored workload, and the synthetic case's explicit non_gameplay flag.

| Case | Packed bytes / cells | Composed current p50/p95/p99, us | Candidate p50/p95/p99, us | Median reduction, us |
| --- | --- | --- | --- | --- |
| Legal paid campus | 3,788 / 2,766 | 162 / 237 / 296 | 88 / 132 / 138 | 74 |
| Empty campus | 740 / 2,766 | 31 / 33 / 34 | 19 / 20 / 21 | 12 |
| Synthetic bounded lanes | 268,916 / 4,096 | 48,786 / 60,512 / 96,631 | 24,698 / 53,898 / 88,948 | 24,088 |

**Recommendation: defer production integration.** The legal fixture's measured saving is only 74 microseconds per isolated decode. The separate lifetime diagnostic measured a 252,200-microsecond median for complete prepare, but these are separate experiments and do not establish a measured whole-prepare improvement or an additive decomposition. The large synthetic gain does not justify promotion: its fabricated chemistry and maximum sparse lanes are pressure data, not gameplay or supported capacity evidence. Keep the candidate and receipt as bounded evidence; no new runtime identity, package or capacity claim follows.

No remaining static equivalence blocker was identified. The two pre-run findings were corrected before this successful receipt. Final reviewed support SHA-256: `dc3b9dd0f656a99bdaf36ea939a36178107abc0ade7859a3385cd5304af5fd05`; profiler SHA-256: `2330d3606162aba95111a2748cee9f62cedb16100c6fa816d0f3e5dcca31d1cf`.

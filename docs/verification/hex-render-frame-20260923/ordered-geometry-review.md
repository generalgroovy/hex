# Independent D7 ordered geometry candidate review

Status: **STATIC AND RECEIPT REVIEW PASSED; production integration DEFERRED.** Reviewer changes only this document, with no engine or source operations. This test-only diagnostic is separate from integrated D6 acceptance.

## Constructor semantics

Compared the candidate with actual production `HexChemistryWorld.configure_geometry` (world SHA256 `7582964d1c889f1ceaf5114ff6600eb3ead842318e4cf6db95aed1d82985cb7b`). The candidate specializes only the exact base script with strictly increasing `HexGrid._cell_less` input. That lexicographic strict-order check proves uniqueness; derived worlds and unsorted/duplicate inputs dispatch through the actual public method. Typed `Array[Vector2i]` bounds the input element domain.

For the specialized path, the origin/query bounds, nonempty topology, 4,096-cell maximum, casts/products/pending/sources guards, paid-matter guard, per-coordinate bound and translated-center bound match production. Both allocate a local prepared dictionary, build the same empty-cell template, deep-duplicate all 44 material lanes per cell and commit origin/cells only after successful validation. Render-polygon cache invalidation matches; no cross-call cache or retained input exists. Geometry output order equals the baseline sorted order. No constructor semantic mismatch was found statically.

## Profile and requested corrections

The baseline includes actual `World.new()` and public `configure_geometry`; candidate includes the same fresh-world construction plus checked specialization. Timers include all construction/check/allocation work. Definition loading, detached-input sorting, warmups, bytes/hashes and receipt work are outside timers. Samples release their world references explicitly; receipt rows retain numbers, not worlds. The expected oracle world and serialized comparison buffer are retained symmetrically for validation. Thus this is fresh geometry construction, not full snapshot preparation, deallocation timing, runtime/frame or network performance.

The initial 21-case matrix covers normal/reversed/duplicate/empty inputs, maximum size, coordinate/query bounds, paid-state rejection, replacement/cache invalidation, direct mutations, derived override dispatch and nested ownership. Three untimed warmups per arm and four ABBA/BAAB cycles with five samples/block are intended to produce 16 blocks and 40 samples/arm.

Before execution, requested these bounded corrections:

1. Replace the typed `Array[String]` block-order ternary of untyped literals with explicit typed-array assignments, avoiding the prior known runtime conversion failure pattern.
2. Make profile completeness validate exact cycle/block/implementation order and flattened sample correspondence, in addition to counts.
3. Record runtime identity and guard source/identity stability before and after the experiment, either in the script or an explicitly documented root wrapper. Current source hashing occurs only after timing.
4. Add an already-configured world with strictly ordered valid-then-invalid cells to exercise fast-path atomic rejection after local allocation. Existing seeded duplicate rejection exercises the original fallback instead.

These requests were sent to the author and root. No timing result or integration recommendation exists before the corrected source and supervised receipt are reviewed. D6 production and its sealed evidence remain outside this candidate's edit scope.


## Corrected source re-review

All four requested corrections are present and statically satisfactory. `_implementation_order` constructs an explicitly typed array and uses branch-local `assign`. Completeness now checks each of 16 blocks against expected cycle, block and arm, requires five positive integer samples, reconstructs both 40-element arm arrays and requires their exact equality with the receipt series. Before/after checks compare all seven source digests, parsed runtime-identity fields and exact manifest SHA256. This establishes experiment-time stability; it is not an independent recomputation of the production runtime identity, which remains the root wrapper's current-state responsibility.

The new seeded strictly sorted `[Vector2i.ZERO, Vector2i(257, 0)]` fixture exercises rejection after the fast path has allocated the first local cell. Exact before/after world serialization includes existing geometry, authority counters and polygon-cache metadata. The completion count is now **22 equivalence cases**. No remaining static blocker or evident parse/typing issue was found.

Reviewed final source SHA256 values:

- Support: `6811f3c4ac5ef7adc602ff0cdd75449670d4ac401031291437a40d70a25a503c`.
- Profiler: `1b3f6b5094a520ed44329a86ff9bfb35d82ea3e639362ad1df29eb384a305be3`.

Ready for the root's bounded supervised probe after the active D6 engine pipeline. **Engine/import/profile remain NOT_RUN; no performance or production-integration recommendation is made.**


## Verified supervised receipt and decision

Root executed `.godot/hex-ordered-geometry-candidate-render-frame-v1.json`: **PASS, 270 assertions, 22 equivalence cases, one legal timed case, zero failures and zero-byte stderr**. Independently verified all seven source hashes, the runtime manifest bytes/hash and parsed identity, all 16 ABBA/BAAB blocks, five positive samples/block, exact flattened arrays and all min/p50/p95/p99/max statistics. Script guards compare source/identity state before and after the complete experiment. The recorded runtime is unchanged **p55-1b26a51136d1**.

The input is the genuine sorted **2,766-cell** topology, with **44 material lanes per cell**. Exact comparison output is 3,485,972 Variant bytes; authority hash is `85e3a4ac02c3193472b85ff32d4de67df582b6d25cb2c527a583e5ab6e89c050`. Each arm has 40 fresh-world construction observations, batch size one.

| Full geometry construction | Minimum, us | p50, us | p95, us | p99/max, us |
| --- | --- | --- | --- | --- |
| Actual public production path | 47,675 | 52,125 | 56,279 | 85,624 |
| Checked ordered candidate | 41,636 | 44,866 | 48,299 | 48,991 |

The measured construction median saving is **7,259 us (13.9%)**. This is a valid bounded result, with exact output and ownership checks; it does not establish whole-snapshot-prepare, session replacement, tick, draw, frame or network gain. Tail statistics retain all samples; with 40 observations, p99 is the observed maximum.

**Recommendation: defer production integration at this checkpoint.** Preserve the candidate as a measured option. If pursued, the next useful gate is a bounded test-only comparison through the actual snapshot-prepare caller, with identical trusted-input construction and exact resulting authority bytes/ownership. This can determine whether the isolated 7.259-ms saving produces enough complete-operation benefit to justify another runtime/package integration. The current experiment alone does not resolve that question, and it does not alter D6's exported playable package or red capacity result.

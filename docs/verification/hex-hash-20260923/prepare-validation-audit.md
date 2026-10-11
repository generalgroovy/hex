# H.E.X. prepare/validation repetition audit

Scope: read-only review of the current `HexWorldSnapshot.capture -> prepare` path and public `HexChemistrySnapshot.capture/restore` paths after D2. No Godot process, test, import, export, package, or profiler was run. Current measured context is world capture about 375 ms p50, world prepare about 259 ms p50, and prediction bind about 78 ms p50 (`docs/verification/hex-hash-20260923/snapshot-stages-v1.out:6-10`); those timings do not attribute the costs below.

## Already implemented; do not propose again

Two material shortcuts are already present:

- Outer world capture calls `_capture_for_outer_roundtrip()` instead of public `HexChemistrySnapshot.capture()`, deliberately avoiding a nested chemistry-only reconstruction. It still requires the complete outer `prepare()` before publication (`src/net/hex_world_snapshot.gd:73-85`, `142-147`; `src/net/hex_chemistry_snapshot.gd:61-67`).
- Outer world prepare takes the fresh `HexChemistryWorld` returned by `HexChemistrySnapshot._prepare()` directly. It no longer allocates a second blank chemistry world and restores the first into it (`src/net/hex_world_snapshot.gd:211-226`).

The outer hash path also already reuses the chemistry hash that `_prepare()` independently verified, avoiding another complete chemistry hash during outer canonical assembly (`src/net/hex_world_snapshot.gd:252-257`; `src/sim/core/sim_world.gd:451-469`).

## Exact synchronous repetition

### `HexWorldSnapshot.capture(world)`

For one unchanged 2,766-cell authority, the synchronous producer path performs these whole-topology passes:

1. `_capture_for_outer_roundtrip()` calls `_trusted_cells()`, which validates every cell shape/material lane and sorts all keys by `HexGrid._cell_less` (`src/net/hex_chemistry_snapshot.gd:67-75`, `810-841`).
2. It computes the topology fingerprint over that order (`src/net/hex_chemistry_snapshot.gd:153-156`, `842-853`).
3. It computes the live chemistry authority hash. D2's `_stable_hash_cells()` independently obtains and sorts all cell keys by the published string comparator before projecting cell records (`src/sim/hex/hex_chemistry_world.gd:1087-1134`). This order is not interchangeable with `HexGrid._cell_less` without an exact-byte proof.
4. It JSON-encodes the detached chemistry snapshot for the one-MiB local guard (`src/net/hex_chemistry_snapshot.gd:171-173`, `217-220`).
5. Packing converts and checks every dynamic lane; `_compress_hex()` then calls `WirePacking.validate_structure()` over the locally produced packed value before serializing it (`src/net/hex_snapshot_wire_packing.gd:24-68`; `src/net/hex_world_snapshot.gd:85-87`, `290-299`).
6. The mandatory outer `prepare(snapshot, world)` decompresses the just-produced packed value, validates its complete packed structure, and then `WirePacking.unpack()` repeats packed shape/length/ID/sparse-plane/variable-row traversal while producing the detached dictionary (`src/net/hex_world_snapshot.gd:211-220`, `302-315`; `src/net/hex_snapshot_wire_packing.gd:71-106`, `115-136`).
7. `HexChemistrySnapshot._prepare()` JSON-encodes the unpacked detached snapshot again, recomputes `_trusted_cells()` and the topology hash against the live trusted authority, constructs a fresh chemistry world, and verifies the reconstructed authority hash (`src/net/hex_chemistry_snapshot.gd:223-275`). The second trusted-topology validation is later than player/projectile capture, packing, compression, and outer hash assembly; it catches a topology change occurring during producer capture.
8. `World.configure_geometry()` duplicates and sorts the already canonically sorted `ordered_cells` again before allocating 44 independently owned material dictionaries per cell (`src/sim/hex/hex_chemistry_world.gd:53-73`). The sort is repeated; the point/bounds/duplicate checks and independent nested dictionaries are not redundant.
9. The prepared chemistry hash performs another published canonical cell ordering. Outer prepare then clones the trusted collision world, constructs one fresh `SimWorld`, validates cross-world relations, and assembles the outer hash (`src/net/hex_world_snapshot.gd:228-258`, `318-327`). Those constructions occur once, not twice.

Thus outer capture performs two `_trusted_cells()` topology validations/sorts, two topology hashes, one live and one reconstructed chemistry canonical hash, and one additional `configure_geometry()` sort. These repetitions straddle the producer/verification boundary; they are not all safely collapsible.

### Public `HexWorldSnapshot.prepare(snapshot, trusted_world)`

One public consumer call repeats packed validation and decoding locally: `_decompress_hex(..., cell_count)` calls `WirePacking.validate_structure()`, then `WirePacking.unpack()` rechecks the same unchanged packed dictionary and decodes the same sparse/variable lanes (`src/net/hex_world_snapshot.gd:211-220`, `302-315`; `src/net/hex_snapshot_wire_packing.gd:71-106`, `115-136`). It also performs one `_trusted_cells()` sort followed by the second `configure_geometry()` sort and the required reconstructed state hash.

`validate_wire_structure()` has an even narrower exact duplicate: `_decompress_hex()` already returns only a structure-valid packed dictionary, and the next expression immediately calls `WirePacking.validate_structure()` on it again (`src/net/hex_world_snapshot.gd:150-173`, `302-315`). This is within one public call with no intervening callback or mutation point.

Validation performed earlier by `WorldSnapshotEnvelope.validate()` or transport cannot be carried into this public call as an assumed fact. The snapshot dictionary remains mutable between calls, and public `prepare()` must continue to reject independently.

### Public `HexChemistrySnapshot.capture(world)`

Public chemistry capture intentionally pays more than the outer producer helper:

- `_capture_for_outer_roundtrip()` validates/sorts trusted cells, computes topology and live authority hashes, and JSON-encodes the snapshot.
- `_prepare(snapshot, world)` repeats JSON size encoding, trusted-cell validation/order, topology hash, fresh-world construction, and reconstructed authority hash (`src/net/hex_chemistry_snapshot.gd:51-58`, `67-75`, `153-173`, `223-275`).
- After `_prepare()` has already compared the prepared hash to `snapshot.authority_hash`, line 56 hashes the prepared world again and hashes the live world a second time. The second live hash detects a source mutation since the snapshot hash was captured; the second prepared hash has no intervening mutation/callback in current base-class code (`src/net/hex_chemistry_snapshot.gd:55-57`, `273-275`).

Within `_prepare()`, snapshot shape is checked at line 224 and checked again through public `encoded_size()` at lines 226 and 217-220. That adjacent shallow validation can be shared within the call; the JSON byte-size check itself cannot be removed.

### Public `HexChemistrySnapshot.restore(snapshot, target)`

Restore calls `_prepare()` once, so it has one trusted-cell order/topology hash, one fresh chemistry construction, one `configure_geometry()` re-sort, and one reconstructed hash. Only after all checks pass does it swap the prepared dictionaries/scalars into `target` (`src/net/hex_chemistry_snapshot.gd:176-202`, `223-275`). The fresh world is required for atomic rejection. Decoding directly into `target`, sharing its topology dictionaries, or dropping that construction would weaken the published no-mutation-on-rejection contract.

## Safe public-call-local reuse candidates

These candidates require no persistent cache and do not trust prior network validation:

1. **Fuse strict packed validation and unpack inside `HexWorldSnapshot.prepare()`.** One internal decoder should perform every current `validate_structure()` check while producing the detached lanes once. `_decompress_hex()` must retain framing, compressed-size, decompression, and safe Variant-type checks; the strict decoder must retain schema/header bounds, row sizes, sorted unique IDs, sparse allocation bounds/order, and variable-row completeness. Do not pass a boolean “already validated” from transport or expose an unchecked public path. The exact duplicate at `validate_wire_structure():172-173` can likewise be reduced to the one strict result already produced in that same call.
2. **Pass canonical trusted order into an internal ordered geometry constructor.** `_trusted_cells()` already returns `HexGrid._cell_less` order. An internal base-world constructor may skip the second `sort_custom` only if it still checks nonempty/maximum size, origin and every cell/query bound, strict monotonic order, uniqueness, and empty paid state, and still deep-duplicates the complete per-cell material shape. This removes only the sort; it does not alias topology or skip any validity/ownership check.
3. **Reuse adjacent shape facts only inside `_prepare()`.** After `_snapshot_shape_valid(snapshot)` succeeds, an internal encoded-size helper may serialize the known-shaped snapshot without invoking the public shape validator again. Public `encoded_size()` remains strict for all callers.
4. **For standalone chemistry capture only, avoid the second prepared hash.** `_prepare()` has already verified `prepared.state_hash() == snapshot.authority_hash`. The final mutation guard can compare `world.state_hash()` to `snapshot.authority_hash`, preserving the second live-source observation while avoiding a second hash of the base-class prepared candidate. This does not improve outer world capture because it already bypasses public chemistry capture.

The lowest-risk, measurable hypothesis is candidates 1 and 2 as separate A/B changes: **one strict packed decode plus one checked linear canonical-order assertion should reduce `world_prepare` below the current ~259 ms p50 and therefore reduce producer `world_capture`, while producing byte-identical captures and exactly the same accept/reject and ownership results.** Measure each separately; do not combine a null result into a larger redesign.

## Reuse that is not safe under the stated contract

- Do not pass producer `_trusted_cells()` or its topology hash through the entire outer capture and suppress the later trusted-topology check. Calls between those points read player/projectile state, ledgers, hashes, packing, and compression. Current typed parameters admit script subclasses, and GDScript method dispatch such as `state_hash()`, `canonical_values()`, or ledger access can re-enter or mutate caller-owned state. The later topology check is the source mutation boundary.
- Do not treat `value_revision` or `render_revision` as a topology-version token. Direct dictionary mutations are supported by current tests and need not bump either revision (`tests/unit/test_hex_snapshot_optimization.gd:91-119`, `154-189`).
- Do not reuse a validation result across public `validate_wire_structure()` and `prepare()` calls. The dictionary can change between calls; client validation must remain complete.
- Do not reuse `HexGrid._cell_less` topology order as the authority-hash order. D2 preserves the published `str(key)` comparator and exact sparse projection (`src/sim/hex/hex_chemistry_world.gd:1099-1134`).
- Do not eliminate the fresh chemistry world, fresh `SimWorld`, collision clone, or independently owned cell dictionaries. They provide atomic rejection and prevent remote replica/prediction/topology aliasing.
- Do not retain ordered cells, hashes, decoded lanes, or prepared worlds beyond one call. Concurrent mutation is not synchronized by these codecs; a persistent result would make later direct changes invisible.

An internal ordered-geometry helper should be called only on the exact fresh base `HexChemistryWorld` created by `_prepare()`. If generalized to subclass instances, overridden construction/method behavior could change acceptance or introduce callbacks. Similarly, any removal of the final public-capture prepared hash relies on `_prepare()` returning the exact base `World.new()` with no external reference or callback before return.

## Required old-oracle coverage before accepting either hypothesis

Preserve the old implementation independently and compare old/new results, not only expected happy-path values.

1. **Exact successful bytes and continuation:** ordinary and saturated paid worlds; the production 2,766-cell campus; public chemistry capture versus `_capture_for_outer_roundtrip()` exact Dictionary and `var_to_bytes` identity (`tests/unit/test_hex_world_snapshot.gd:323-331`); capture/restore/recapture hash identity and identical next simulation transition (`tests/unit/test_hex_chemistry_snapshot.gd:26-47`); full world prepare/restore exact hash, fresh ownership, and identical next command (`tests/unit/test_hex_world_snapshot.gd:55-85`).
2. **Trusted topology acceptance and ordering:** ordinary mixed/negative coordinates, reversed insertion order, accepted extra scalar/dictionary keys, nonempty authored layers, exact 4,096 boundary, and 4,097 rejection. Compare with the frozen pre-D2 trusted-cell oracle (`tests/support/hex_trusted_cells_legacy_oracle.gd:1-37`; `tests/unit/test_hex_snapshot_optimization.gd:21-42`, `91-104`).
3. **Malformed and direct-mutation visibility:** missing/wrong-type terrain/elevation/structure; missing/wrong-type material layers; non-`Vector2i` keys; non-Dictionary records; invalid origin; direct material-shape and metadata mutations on consecutive calls (`tests/unit/test_hex_snapshot_optimization.gd:45-119`). Preserve the frozen sparse authority hash for empty-Dictionary metadata, missing authored layers, orphan material, and unexpected authority keys (`tests/unit/test_hex_snapshot_optimization.gd:178-189`, `249-288`).
4. **Packed-wire rejection:** wrong schema/header type or width; duplicate/unsorted cast and product IDs; mismatched flattened-row lengths; truncated, extra, duplicate, out-of-order, and one-past-topology sparse rows; truncated/extra variable rows; wrong compressed size; valid compression with a missing lane; outer 32,768-byte and chemistry one-MiB limits. The current concrete compressed-size and malformed-packed cases are at `tests/unit/test_hex_world_snapshot.gd:146-158` and `tests/performance/profile_hex_snapshot_stages.gd:209-232`; sparse boundary cases are at `tests/unit/test_hex_chemistry_snapshot.gd:168-190`.
5. **Authority and relation rejection:** forged topology/chemistry/outer hashes; stale but structurally valid player, projectile, and outer-header lanes; duplicate/orphan allocations and mappings; conservation failure; projectile/source/owner bijection failures (`tests/unit/test_hex_chemistry_snapshot.gd:74-149`; `tests/unit/test_hex_world_snapshot.gd:88-158`; `tests/unit/test_hex_snapshot_optimization.gd:214-233`). Every restore rejection must leave target hashes and owned dictionaries unchanged (`tests/unit/test_hex_chemistry_snapshot.gd:352-356`; `tests/unit/test_hex_world_snapshot.gd:346-351`).
6. **Ownership:** every cell retains the exact metadata plus all material-layer keys; nested dictionaries do not alias siblings or another world; prepared collision, chemistry, players, and dynamic movement remain independent (`tests/unit/test_hex_snapshot_optimization.gd:139-175`; `tests/unit/test_hex_world_snapshot.gd:69-80`).
7. **Mutation/re-entry oracle before any cross-phase reuse:** use a test-only subclass whose first `state_hash()` call mutates one trusted metadata value or material lane, and a `SimWorld`/state double that mutates Hex topology during an intervening outer-capture method. Freeze the old implementation's return/empty result and source mutation, then require exact equality. If this oracle cannot be made deterministic, do not reuse topology order/hash across the producer and verification phases; the call-local strict-decode and ordered-construction candidates do not require that reuse.

Acceptance remains functional and evidentiary: unchanged public results, exact bytes, exact old-oracle rejection set, atomic targets, independent ownership, zero new stderr, and separately measured stage movement. No cadence, caps, topology, paid workload, or client validation may change to obtain a timing reduction.

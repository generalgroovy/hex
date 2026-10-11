# Call-local chemistry-digest reuse brief

## Finding

There is **no repeated `HexChemistryWorld.state_hash()` on the same instance inside either public `HexWorldSnapshot.capture()` or `HexWorldSnapshot.prepare()`**. Those paths already reuse a call-local verified digest for outer canonical assembly. The only source-supported duplicate is in standalone public `HexChemistrySnapshot.capture()`: its fresh prepared base world is hashed once by `_prepare()` and then hashed again immediately after `_prepare()` returns. That second prepared-world hash can be removed without caching or trusting caller input.

This candidate does **not** reduce the measured whole-world capture or prepare operations. Outer capture deliberately calls `_capture_for_outer_roundtrip()`, not public chemistry `capture()` (`src/net/hex_world_snapshot.gd:76-85`). A repository search found standalone public chemistry capture in diagnostics/tests, but no production caller under `src/` other than its declaration. Treat this as a bounded API-cost candidate only; do not infer network or lifecycle benefit.

## Exact current call graph

### `HexWorldSnapshot.capture(world)`

1. `_capture_for_outer_roundtrip(world.hex_court)` computes the live chemistry hash once as `snapshot.authority_hash` (`src/net/hex_world_snapshot.gd:73-84`; `src/net/hex_chemistry_snapshot.gd:67-73,153-170`).
2. The outer producer uses that exact local digest in `world._state_hash_with_verified_hex_hash(...)`; it does not call `world.hex_court.state_hash()` again (`src/net/hex_world_snapshot.gd:119-138`; `src/sim/core/sim_world.gd:451-485`).
3. The mandatory outer `prepare(snapshot, world)` reconstructs a distinct fresh chemistry world, and `HexChemistrySnapshot._prepare()` hashes that reconstruction once to prove it matches `snapshot.authority_hash` (`src/net/hex_world_snapshot.gd:142-147,211-220`; `src/net/hex_chemistry_snapshot.gd:223-275`).
4. Outer prepare then reuses the already verified detached digest when assembling the fresh `SimWorld` hash (`src/net/hex_world_snapshot.gd:252-257`).

The live-world hash and reconstructed-world hash are on different objects. Sharing the live digest in place of the reconstruction hash would stop proving that decode/reconstruction preserved authority, so it is not a candidate.

### `HexWorldSnapshot.prepare(snapshot, trusted_world)`

`HexChemistrySnapshot._prepare()` performs the only chemistry hash, on its fresh reconstructed base world, at `src/net/hex_chemistry_snapshot.gd:273`. The outer comparison uses `_state_hash_with_verified_hex_hash(String(detached.authority_hash))` at `src/net/hex_world_snapshot.gd:254-257`. Public `SimWorld.state_hash()` would hash chemistry at `src/sim/core/sim_world.gd:446-448`, but this prepare path does not call it. There is no same-object duplicate to remove.

### `HexChemistrySnapshot.capture(world)`

1. `_capture_for_outer_roundtrip()` hashes the live source once into its new local snapshot (`src/net/hex_chemistry_snapshot.gd:51-55,67-73,153-170`).
2. `_prepare(snapshot, world)` creates exact base `World.new()`, reconstructs it, and verifies `prepared.state_hash() == snapshot.authority_hash` (`src/net/hex_chemistry_snapshot.gd:223-275`).
3. On successful return, line 56 hashes that same prepared instance a second time, with no intervening callback, mutation, or exposed reference, before hashing the live source a second time (`src/net/hex_chemistry_snapshot.gd:55-57`).

The final live-source hash is required. It detects source mutation or nondeterminism across capture/reconstruction and preserves the two calls seen by a typed subclass override. The second prepared hash is redundant: `_prepare()` has just verified the exact base object against the function-local digest, and the base hash has no mutating side effect.

Public `restore()` and `validate()` each call `_prepare()` once and therefore hash only one fresh prepared world (`src/net/hex_chemistry_snapshot.gd:176-206`). `snapshot_hash()` hashes canonical snapshot bytes, not a `HexChemistryWorld` (`src/net/hex_chemistry_snapshot.gd:209-214`).

## One bounded candidate

Own one production edit in `src/net/hex_chemistry_snapshot.gd`, confined to current lines 55-57. Preserve `_prepare()` unchanged and preserve short-circuit behavior:

```gdscript
var prepared := _prepare(snapshot, world)
if prepared == null:
    return {}
var verified_authority_hash: String = String(snapshot.authority_hash)
if world.state_hash() != verified_authority_hash:
    return {}
return snapshot
```

`snapshot` is created inside this public capture call. A successful `_prepare()` means its `authority_hash` has already been checked against the fresh prepared base at line 273. No digest is accepted from a public parameter, no public prepare/restore validation changes, and no value survives the call. Do not add an optional digest parameter, mutable static holder, revision cache, or caller-visible unchecked helper.

This preserves current failure ordering: an empty producer result returns before `_prepare()`; an `_prepare()` rejection returns before the second live-source hash; success still invokes the live source hash twice overall. It removes only the second pure hash of the unexposed exact-base prepared object.

Risks to freeze in tests:

- `_prepare()` currently returns the exact `World.new()` created at line 235. If a future change permits a subclass, external reference, callback, or mutation after its line-273 verification, this reuse must be reconsidered.
- A source subclass can override `state_hash()` or mutate itself during a call. Keep the final live call and prove the same source call count, ordering, resulting mutation, returned snapshot/empty result, and stderr as the old wrapper.
- The candidate advances the final live hash by roughly one removed prepared-hash duration. A wall-clock-dependent override could observe that timing, although such behavior is outside deterministic authority hashing; include a stateful call-count/mutation subclass oracle, and record this residual timing hazard rather than claiming universal subclass equivalence.
- Never reuse the first live digest instead of the reconstructed hash inside `_prepare()`. That would weaken malformed decode and reconstruction rejection.

## Minimal old-oracle whole-operation A/B

Proposed ownership for a later implementation slice:

- `src/net/hex_chemistry_snapshot.gd`: the single candidate comparison above.
- `tests/support/hex_chemistry_capture_legacy_oracle.gd`: a frozen eight-line copy of only the old public wrapper. It must call the current `_capture_for_outer_roundtrip()` and `_prepare()` and retain `prepared.state_hash() != world.state_hash()`; it must not copy either codec body.
- `tests/performance/profile_hex_chemistry_capture_digest_reuse.gd`: functional old/new oracle, matched timing, receipt, and source/identity guards. Reuse the existing legal 2,766-cell eight-actor paid fixture helpers without editing them.

For both arms, start from the same unchanged legal authority and require exact Dictionary equality, `var_to_bytes()` equality, snapshot hash/encoded size, unchanged source hash and bytes, successful independent restore, no mutable aliasing, and identical next legal continuation. Before timing, compare empty and paid legal worlds; malformed topology/material/ledger worlds; direct same-instance mutations between calls; and a test-only `HexChemistryWorld` subclass whose first or second `state_hash()` mutates one tracked authority field. Rejection must match the frozen old wrapper exactly and leave caller-owned state changed only by the explicit subclass mutation.

Time the complete public operation, not isolated hashes. Use two untimed warmups per arm, then four balanced cycles with ABBA on even cycles and BAAB on odd cycles, three unbatched samples per block: 24 samples per arm, 48 total. Keep equality, restore, continuation, source checks, and object release outside timers. Record every positive raw sample and block identity. Use a 90-second script elapsed bound checked between blocks and a 120-second root wrapper timeout; timeout produces no valid receipt. Root alone schedules the engine work.

## Evidence boundary

The frozen D9 integrated legal whole-hash median is 49.300 ms. The current five-sample inclusive stage receipt reports world capture 355.528 ms and world prepare 253.908 ms (`docs/verification/hex-native-sort-20260923/stages-v1.out`). Its 92.016-ms `chemistry_capture` stage measures `_capture_for_outer_roundtrip()`, not public `HexChemistrySnapshot.capture()` (`tests/performance/profile_hex_snapshot_stages.gd:129-139`). None of those figures measures this candidate, and separate-stage values cannot be subtracted to claim a gain.

Source inspection supports one fewer prepared-world hash per successful standalone chemistry capture. Only a matched whole-operation old/new receipt can establish the absolute benefit. Even a positive result would establish local headless standalone API cost only, not world snapshot, prediction, replay, socket, frame, allocation, capacity, package, or lifecycle acceptance.

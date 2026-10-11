# P2 bounded snapshot review

Status: PROPOSAL / STATIC_VERIFIED inspection. No runtime change or engine execution by this worker. Authoritative checkout is `C:\Users\sende\Projects\hex`; old FLUX was not accessed or changed for this subtask.

Reviewed the current `tests/performance/profile_hex_snapshot_stages.gd`, `src/net/hex_chemistry_snapshot.gd`, `src/net/hex_world_snapshot.gd`, `src/sim/hex/hex_chemistry_world.gd`, `src/sim/core/canonical_bytes.gd` and existing chemistry snapshot tests. Earlier `docs/verification/hex-integration-20260920/snapshot-stage-comparison.json` is historical attribution only, not current 48 px timing evidence.

## Existing implementation and measurement boundary

The live checkout already has per-call empty-cell skeleton duplication, verified chemistry-hash reuse, direct chemistry `_prepare` without constructing a second blank, decorated canonical sorting, native signed little-endian encoding, and sparse empty-cell state-hash projection. Reapplying earlier FLUX changes would be redundant or conflict with newer code.

The stage profiler uses the actual 2,766-cell / 48 px campus, eight champions, 120 neutral warmup ticks and the unchanged first 40 paid dense-workload ticks. Five repetitions measure world hash, topology hash, chemistry producer, world capture, blank creation, chemistry restore, world prepare and prediction binding. Exact snapshots/hashes, unchanged source authority and malformed-input rejection are checked outside timers. The stages overlap; their inclusive times must not be summed. It does not measure a complete dense timeline, sockets or rendering. Root is scheduling a fresh baseline; no current speedup is established.

## One candidate: stateless empty-cell validation fast path

Target only `HexChemistrySnapshot._trusted_cells`. Today every call checks all 44 material layer dictionaries in all 2,766 cells through interpreted iteration, including the many empty cells. That is 121,704 material checks per invocation, before sorting. This function is inside both producer and incoming `_prepare` paths. Historical stage timing identified capture/prepare as material costs; the proposed validator's exclusive cost has not yet been measured separately.

Create one local `World._new_empty_cell()` template per call. Keep the current topology size/origin guards, Vector2i key checks, record dictionary check and exact TYPE_INT checks for terrain/elevation/structure. Set the local template's three metadata values to the validated record values. If `record == empty_cell`, native structural equality proves the full expected material shape with empty dictionary values; skip only the 44 interpreted layer checks for that cell. Otherwise execute the existing material `has` and dictionary-type checks unchanged. Append/sort the same cells exactly as today. Equality is a shape proof, not a mutable-ownership proof; existing detached construction and ownership tests remain required.

This is a shape-validation fast path, not a cached topology or simulation representation. It neither skips incoming validation nor removes state. No cached fingerprint, revision counter, alias to mutable authority, new field, schema change or trusted-input exception is required. Nonempty, extra-field and malformed records take the original validator. Root should only choose this slice if the fresh measurement and independent paired oracle show useful improvement.

## Exact invariants and oracle

- Return exactly the same ordered `Array[Vector2i]` or empty rejection array as the original function for every tested input. Preserve origin/bounds checks, exact metadata types and lexicographic grid ordering.
- Preserve baseline acceptance of extra fields and nonempty material dictionaries; `_trusted_cells` checks shape, while relation validation later rejects invalid allocations. The fast path must not accidentally strengthen or weaken those semantics.
- Do not mutate any source record, material dictionary, metadata, cache or revision. Only the function-local expected template may change.
- Keep every `_prepare` relation/conservation/hash check and outgoing self-roundtrip unchanged. Snapshot typed lanes, bytes, hashes, paid metrics and next-tick authority must match exactly.
- Freeze the pre-change `_trusted_cells` body as an independent test oracle. Compare both functions over real 2,766-cell topology, 4,096-cell boundary topology, reversed insertion order, negative coordinates and varied integer metadata. Test empty/oversized topologies and invalid origin separately.
- For each of the 44 layer names, exercise missing key, non-dictionary scalar/array/null, empty dictionary and nonempty dictionary. Include non-dictionary records, non-Vector2i keys, missing metadata, and float/string/dictionary/null metadata. Float metadata equal in numeric value to an integer must still reject before the native equality shortcut.
- Include extra metadata/material keys and mutate terrain or a layer directly between consecutive calls, ensuring there is no stale fast-path result. Confirm unchanged source hash/records after accepted and rejected calls.

Existing `hex-chemistry-snapshot` covers full registry, atomic corruption rejection, topology fingerprint mismatch, sparse 4,096-cell indexing, dispersed/zero allocations, rich product state and subsequent real-input continuation. Retain those checks; add the focused validator-oracle cases rather than replacing existing tests. Then run `hex-world-snapshot` and `unified-prediction` for detached ownership and replay compatibility.

## Minimal measurement and integration request

First root runs the unchanged stage script with a fresh `--output=res://.godot/hex-snapshot-stages-acceptance-before-v1.json`. If capture/prepare remain material, measure old versus candidate `_trusted_cells` on one unchanged actual workload state with three ABBA cycles, source hashes and raw samples. Check output equality/source preservation outside timers and include local-template creation inside the candidate timer. No cached input or smaller topology is allowed. This needs an explicitly assigned test/probe owner before implementation.

Accept only if paired exclusive validation timing improves and focused oracles pass. Re-run the unchanged stage profile, then a representative unchanged dense workload; compare demand, paid accounting, snapshot/hash equality and malformed rejection. Do not call stored accounting success a 120 Hz pass or attribute unrelated simulation timing changes to this validator. Networking acceptance still requires the unchanged same-export lifecycle.

Baseline source SHA-256:

- `src/net/hex_chemistry_snapshot.gd`: `5624b2f71e6b6e13e799c13e09f17a7abbff641da830d8bb77709fa9f7f1504c`
- `src/net/hex_world_snapshot.gd`: `5d1f1e68e9998b170b41cba6873de0b3870bd9abc5931a2147c7db7f53217fa3`
- `src/sim/core/canonical_bytes.gd`: `11de76f54bd1f420fe925d2683dcdaeca1ef59d253810cbbfc42f5ff12250d2a`

Rollback for a future accepted slice is only the isolated `_trusted_cells` fast path and its owned tests/probe. At this handoff only this review document was added; runtime files remain unchanged by this subtask.

# Native cell-key sort integration handoff

## Status

- Production integration and bounded unit coverage are ready for root-owned validation.
- Godot/import/test/profile/package work: **NOT RUN by this agent**.
- Integration baseline supplied by root: `p55-aeefbd4a5e7b`.
- The earlier test-only D9 candidate passed `1261` assertions with `42` equivalence cases and complete `56`-sample arms across three profiles. Those measurements justify this integration but are not measurements of the integrated production source.

## Exact change

- `src/sim/hex/hex_chemistry_world.gd`
  - `_stable_hash_cells()` now recognizes the exact supported `Vector2i` cell-key domain, formats each key once, sorts a typed `Array[String]` with the native sorter, and reconstructs the original key array through a function-local inverse dictionary.
  - A formatted-key collision or any unsupported key type returns to the existing formatted `sort_custom` comparator path.
  - The current record projection and canonical byte construction body remains single and unchanged. No cache, schema, cadence, public API, or generic `_stable()` behavior changed.
- `tests/unit/test_hex_hash_specialization.gd`
  - Preserves the existing frozen-oracle production checks and raises the strict completion count from `38` to `45`.
  - Adds actual production byte/hash equivalence for one cell, mixed-sign lexicographic-looking positions, reversed insertion, same-instance add/remove/reorder mutation, and the `4096`-cell boundary.
  - The mixed-position case also carries integral metadata, a nonempty material lane, and mixed nested keys so the new ordering is exercised without narrowing the existing record projection.

## Static verification

- `git diff --check -- src/sim/hex/hex_chemistry_world.gd tests/unit/test_hex_hash_specialization.gd`: clean.
- Manual source inspection confirmed there is one current record-projection loop and that its body was not duplicated for the optimized order.
- Completion arithmetic: existing `38` production equivalence cases plus `7` new cases equals the fail-closed expected count `45`.

## Source hashes

- `src/sim/hex/hex_chemistry_world.gd`: `6a62134d2498ef6205ab798944fe9f00ee34ea342d7d4a07bd5d9f5c48140130`
- `tests/unit/test_hex_hash_specialization.gd`: `9ce7785feba8764a37a0d915cbfdd4c44508b947c2d5e8bf63121957e44e962d`

## Assumptions and limits

- Native `Array[String].sort()` must retain the same ascending `String` order as the published comparator. The frozen oracle cases, including negative and lexicographic-looking coordinates, are the executable guard for that assumption.
- Unsupported or collision-shaped key domains retain the old comparator rather than gaining new acceptance behavior.
- The integrated runtime reconstructs an `Array` of original keys after native sorting. Its performance must be freshly measured; the earlier prototype timing must not be relabeled as integrated timing.
- The prior legal and dense D9 measurements remained above their absolute budgets. This slice establishes a bounded hash-cost reduction, not an overall frame or capacity result.

# State-hash specialization implementation handoff — 2026-09-23

Status: **bounded production integration and standalone regression suite ready; engine verification NOT_RUN by this worker**. Runtime identity remains root-owned. No schema, protocol, topology, simulation, gameplay, cadence, cache, global class, dependency, export, or package change is included.

## Production change

`src/sim/hex/hex_chemistry_world.gd` now exposes the private `_state_hash_bytes()` used by `state_hash()`. It preserves the existing 14 outer values in their exact order and preserves the existing JSON framing, canonical length prefix, UTF-8 bytes, and SHA-256 implementation.

The cells slot uses the exact reviewed and measured stateless specialization:

- copy and sort the current cell keys with the published cached `str(Vector2i)` comparator;
- iterate the sorted keys as `Vector2i` and records as `Dictionary`;
- directly emit the canonical `[x,y]` plus `elevation, structure, terrain` stable array only when all three metadata values are exact integers and the complete record equals a fresh call-local empty-cell template;
- otherwise project the record through the existing typed `String` loop, omit only empty Dictionaries, and pass both cell and compact record through the existing generic `_stable` implementation.

No authority reference or result survives a call. Extras, missing fields/layers, malformed values, nonempty materials, mixed nested keys, and direct between-call mutations remain on the published fallback path. A no-index comparison with the preserved baseline source shows the state-hash area is the only runtime difference.

## Regression suite

`tests/unit/test_hex_hash_specialization.gd` is a standalone `FluxTestSuite` with suite ID `hex-hash-specialization`. It reuses only the frozen old-byte path from `tests/support/hex_stable_cells_candidate.gd`; it does not use the measured candidate path as its production oracle.

All 38 prototype equivalence cases are represented: six core/reorder/extras/nested mutation cases; twelve field-by-field float/boolean/null/string metadata cases; three missing metadata fields; one missing material layer; four malformed layer values; both nested integer `4` / string `"4"` insertion orders without asserting equality between tied permutations; six direct empty-fast-path metadata mutation/restoration cases; three empty/nonempty/empty material transition states; and one empty cells dictionary. Every case compares actual production `_state_hash_bytes()` with frozen old bytes, checks the production hash, checks source instance/cell ownership, and verifies the complete hashed authority remains unchanged.

Paid snapshot continuation is intentionally not duplicated. `tests/unit/test_hex_chemistry_snapshot.gd::_test_real_input_continuation` already restores actual paid authority repeatedly and compares the subsequent stepped hashes through product formation/expiry. `tests/unit/test_hex_canonical_sort.gd::_test_real_paid_authority` independently covers products, trails, live cell material, and direct nested mutations with the old projection/comparator oracle. Root includes both in the focused gate.

## Exact files and static result

- Preserved pre-integration runtime: `docs/verification/hex-hash-20260923/baseline-source/src/sim/hex/hex_chemistry_world.gd` — SHA-256 `b87e2cafa243646395db58a0ad7071806be129eca1eb12de647e16aed7fd27cd`.
- Integrated runtime: `src/sim/hex/hex_chemistry_world.gd` — SHA-256 `7582964d1c889f1ceaf5114ff6600eb3ead842318e4cf6db95aed1d82985cb7b`.
- New unit suite: `tests/unit/test_hex_hash_specialization.gd` — SHA-256 `4f0722274830d45739c83fdaa2db780759ed7ac08aef97833b2401250c72b187`.
- Frozen oracle/support remains unchanged from v2: SHA-256 `4dde73bf6ceb9354d740669a46253983c2e6166624cb4f27005c943d593f7ffa`.

Static whitespace and conflict-marker checks pass. The runtime diff is confined to the state-hash area, the outer field list contains all 14 published values, and the production cell specialization retains the typed `Vector2i` / `Dictionary` / `String` domain. No UID was authored. This worker ran no Godot, import, unit, focused, full, profile, PCK, EXE, export, or package command. Root owns registration, identity, all engine gates, the integrated profile, and artifact validation.

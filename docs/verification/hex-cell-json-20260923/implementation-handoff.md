# Canonical cell JSON candidate handoff

## Status

- Bounded test-only candidate and profiler are ready for root-owned execution.
- Godot, imports, tests, profiling, capture, packaging, and export: **NOT RUN by this agent**.
- Production source, completed D9 sources, registrations, identity, assets, profiles, and packages were not edited.
- Root's frozen v1 attempt reached `239` assertions and then failed with two fixture failures plus a script error: `configure_geometry()` rejected the escaped-string fixture because `Grid.center(Vector2i(-144, 233)) + origin` exceeded the world-coordinate bound. No D10 timing result exists from v1. The preserved run and logs remain under root-owned `runs/v1` evidence.
- Pass 2 uses `Vector2i(-2, 3)`, whose world center with the retained origin is `(-1,011,000, 1,721,704)`, and guards every new `configure_geometry()` result before indexing its cells. Candidate serialization behavior is unchanged.

## Candidate

- `tests/support/hex_cell_json_candidate.gd` is a detached `HexChemistryWorld` subclass that overrides only `_state_hash_bytes()`.
- It preserves the current native `Vector2i` string-key order, builds canonical cell JSON in a function-local `PackedStringArray`, and uses fixed punctuation only for an exact empty record with signed 32-bit metadata. Godot `JSON.stringify` formats every emitted scalar.
- Exact ordinary records with bounded integer metadata and material dictionaries use the current generic stable projection and engine JSON encoding per cell. If a cell has any extra/missing/malformed/deep value, non-integer material entry, out-of-range integer, unsupported key, or formatted-key collision, the entire call delegates to production `super._state_hash_bytes()`.
- Prefix and suffix lanes are each encoded as a root JSON array, preserving the original depth of their arbitrary values. No authority reference, serialized fragment, ordered-key array, or result is cached across calls.

## Equivalence and ownership coverage

- `tests/performance/profile_hex_cell_json_candidate.gd` inherits fixture/statistics helpers while replacing candidate construction, byte/hash checks, timing blocks, completeness validation, source hashes, receipt scope, and labels.
- The inherited 42-case D9 matrix runs through this candidate's actual public `_state_hash_bytes()` and `state_hash()` paths.
- Five added cases cover synthetic direct-hash signed 32-bit coordinate/metadata extrema, positive and negative signed 64-bit metadata fallback, ASCII/Unicode/control/quote/backslash plus mixed nested-key fallback, escaped and Unicode values in outer metrics while cells remain on the direct path, and a deep cell value that delegates the whole call. Strict expected equivalence count: `47`.
- The ownership case uses two detached candidates, mutates nested data and metrics, performs same-instance cell add/remove checks against the frozen oracle, and verifies ordinary direct-path to deep whole-call fallback to exact restoration on one candidate.

## Profile contract

- Timed arms are live `production_current.state_hash()` and detached `candidate_cell_json.state_hash()` only.
- Three workloads: production empty campus, genuine legal paid workload with 29 active cells, and clearly labeled synthetic all-nonempty pressure.
- Each arm receives 56 unbatched samples per workload in four-cycle ABBA/BAAB order. Fixture construction, warmup, cloning, frozen-oracle comparisons, source checks, and ownership checks stay outside timers.
- Fail-closed checks validate all 47 equivalence cases, one ownership case, three profile rows, exact block order, flattened sample identity, positive samples, source hashes, and runtime identity. A valid fresh scoped path retains partial results after later failure; an invalid or existing path is never written.

## Static verification and assumptions

- `git diff --check` is clean for all three owned files.
- Candidate SHA-256: `tests/support/hex_cell_json_candidate.gd` = `6bcc7f7b042b904e4951b03128b0cb8f5ca7f994c574734cac08a164d0d48930`.
- Profiler SHA-256: `tests/performance/profile_hex_cell_json_candidate.gd` = `b7784a2e9acb851a695c8b5da170228b4bd7d3db848c1236906a8f88ff572bad`.
- Scalar output still depends on Godot's JSON implementation; int32 extrema are explicit executable byte-oracle cases rather than assumed decimal formatting.
- Per-cell JSON is intentionally limited to a shallow ordinary schema because serializing arbitrary nested values at a different recursion depth could change behavior. The whole-call production fallback is part of the candidate contract and may limit benefit when unusual authority is present.
- The candidate uses additional function-local strings and joins. Allocation behavior is not measured, and no performance improvement is claimed before the root-owned alternating run.
- D9's approximately 49.3 ms legal public-hash result is context only. This experiment does not establish frame, capacity, networking, export, or integrated-runtime gain.

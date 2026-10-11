# Ordered geometry construction candidate handoff

Date: 2026-09-23  
Scope: test-only D7 equivalence and microbenchmark candidate. No production source, test registry, engine process, import, test, capture, profile, export, or package command was changed or run by this agent.

## Candidate

`tests/support/hex_ordered_geometry_candidate.gd` contains one checked specialization for the exact base `HexChemistryWorld`. `construct(origin, eligible_cells)` creates a fresh base world, while `configure_geometry(world, origin, eligible_cells)` chooses between two paths:

- an exact-base, strictly `HexGrid._cell_less` ordered path that retains the public constructor's origin, empty-topology, 4,096-cell, paid-state, coordinate, and translated-query bounds checks, then allocates the same complete fresh cell shape and invalidates the same render-polygon fields;
- the actual public `world.configure_geometry()` path for every noncanonical input and every derived world.

The checked path skips only `eligible_cells.duplicate()` plus `sort_custom()`. It performs no caching, exposes no caller-controlled unchecked flag, retains no world or ordered input, and calls `HexChemistryWorld._new_empty_cell()` before deep-duplicating that 47-field shape for each cell. The 44 material dictionaries remain independently owned for every cell and world. Strict monotonic order proves uniqueness; duplicates and reversed input use the original path, so arbitrary `Array[Vector2i]` ordering retains the public acceptance and output behavior.

## Equivalence matrix

`tests/performance/profile_hex_ordered_geometry_candidate.gd` fails closed unless all 22 bounded equivalence cases complete before timing:

- ordinary sorted mixed/negative cells and valid negative origin;
- reversed input, duplicate cells, empty topology, exact 4,096 acceptance, and 4,097 rejection;
- invalid origin, positive/negative cell coordinate bounds, and translated cell-center query bounds;
- nonempty casts, products, pending state, source mappings, and paid-matter rejection;
- accepted reconfiguration with metadata replacement and render-polygon invalidation;
- rejected reconfiguration with exact prior-object byte preservation;
- sorted input whose late invalid coordinate rejects only after local prepared-cell allocation, proving the caller's seeded prior object remains byte-identical on that specialized-path failure;
- direct input and authority mutation between consecutive calls;
- a derived override that must be invoked exactly once through the original fallback;
- complete 3-metadata plus 44-material shape, per-layer/per-cell ownership, and between-world ownership.

Every general case invokes actual `HexChemistryWorld.configure_geometry()` as the old oracle, compares acceptance, exact structural `var_to_bytes` output, and accepted authority hashes. Rejection cases compare exact before/after bytes for both objects. Typed public signatures define the input element domain as `Vector2i`; malformed coordinates and state are covered without inventing an untyped API.

## Proposed isolated profile

The one timed case uses the genuine `sanctum_campus_g2_v1.json` definition, asserts its 2,766 cells, and sorts a detached input once outside timing into the same canonical order produced by `_trusted_cells()`. Each timed sample includes:

1. `HexChemistryWorld.new()`;
2. either actual public `configure_geometry()` (`production_current`) or the checked candidate;
3. all validation and allocation of 2,766 cell records and 44 independently owned material dictionaries per cell.

Four cycles alternate ABBA on even cycles and BAAB on odd cycles. Each block has five samples, producing 40 raw scalar timings per implementation with `batch_size=1`. Completed worlds are checked for exact Variant bytes and authority hash outside the timer and immediately released; timing rows retain only numbers. Three untimed warmups per arm precede the measured blocks. The receipt must contain the exact cycle/block/arm order, 16 blocks, five positive rows per block, flattened per-arm rows identical to the 40 recorded implementation samples, one completed profile case, and 22 completed equivalence cases before it can report PASS.

The profiler fingerprints every measured source and parses the runtime identity before equivalence/timing, repeats both after the final sample, and refuses a receipt if either changed. The stable source hashes, full runtime identity, identity path, and identity SHA-256 are included in the receipt.

Expected output path contract: `res://.godot/hex-ordered-geometry-candidate-*.json`, fresh file only.

This is a geometry-construction diagnostic on fresh empty worlds. It does not time hash computation, snapshot prepare, simulation, paid admissions, renderer work, networking, exports, or complete frame/runtime behavior. A result cannot establish a full-prepare or gameplay gain without separate integration evidence.

## Static state

- `git diff --check` on the two candidate files and this handoff: PASS.
- `class_name` declarations in the two candidate files: none.
- Engine/import/tests/profile: `NOT_RUN` by assignment.
- Candidate support SHA-256: `6811f3c4ac5ef7adc602ff0cdd75449670d4ac401031291437a40d70a25a503c`.
- Candidate profiler SHA-256: `1b3f6b5094a520ed44329a86ff9bfb35d82ea3e639362ad1df29eb384a305be3`.
- Actual production oracle `src/sim/hex/hex_chemistry_world.gd` SHA-256 at authoring: `7582964d1c889f1ceaf5114ff6600eb3ead842318e4cf6db95aed1d82985cb7b`.
- `src/sim/hex/hex_grid.gd` SHA-256 at authoring: `2e99c993e5ab72cd084b445804f1f69230631a760f6de681fb4b03ab321d5505`.

Root owns any engine run, registration, production decision, source freeze, identity update, broader snapshot comparison, and package evidence. No performance result is claimed before root's supervised probe.

## Root-executed v1 result and disposition

Root subsequently ran the frozen scripts under probe ID `render-frame-geometry-v1`. The run passed 270 assertions, all 22 guarded equivalence cases, the one profile case, all 16 exact alternating blocks, both 40-sample flattened implementation rows, all seven before/after source hashes, and the before/after runtime identity guard with zero failures and zero stderr bytes.

Receipt: `.godot/hex-ordered-geometry-candidate-render-frame-v1.json`  
Receipt SHA-256: `68a59b0176e07a639c2714312c8ffb58d499858c15f7098255b3ded4e6f5834f`  
Probe stdout: `.godot/hex-probe-render-frame-geometry-v1/probe.log`, SHA-256 `7956ff8ae2b25d6b16f8e870b490ec3576567dc75f67343bba8b521acec39119`  
Probe stderr: `.godot/hex-probe-render-frame-geometry-v1/probe.log.err`, zero bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

The receipt records runtime build `p55-1b26a51136d1`, engine `4.7.1.stable.official.a13da4feb`, 2,766 topology cells, 3,485,972 exact structural Variant bytes, and authority hash `85e3a4ac02c3193472b85ff32d4de67df582b6d25cb2c527a583e5ab6e89c050`. Inclusive fresh-constructor timings in microseconds were:

| implementation | samples | min | p50 | p95 | p99/max |
| --- | ---: | ---: | ---: | ---: | ---: |
| `production_current` | 40 | 47,675 | 52,125 | 56,279 | 85,624 |
| `candidate` | 40 | 41,636 | 44,866 | 48,299 | 48,991 |

Astra independently verified the seven source hashes, runtime identity, 16-block order, raw row counts, and recomputed statistics. These results establish a bounded constructor-only reduction for this isolated sorted topology on this machine. Production integration is **DEFERRED** until a whole-snapshot-prepare A/B measures whether the constructor difference produces a material complete-operation change. The receipt does not measure or establish snapshot-prepare, capture, gameplay, network, rendered-frame, capacity, export, package, or release improvement.

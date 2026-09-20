# Projectile delivery foundations

Status: focused visual/simulation contract for element-independent spell delivery shapes.

## Architecture

FLUX projectile presentation is layered:

`delivery simulation -> neutral visual foundation -> elemental visual layer -> impact/residue -> world/material reaction`

Delivery shape controls travel/spawn geometry. Element controls authored payload and presentation. Elemental art never silently changes collision, fan geometry, projectile count, deterministic IDs, damage, or material reaction behavior.

Simulation aim remains continuous. Eight-direction art exists only for compact top-down readability and may be chosen by nearest-direction presentation or replaced by safe runtime rotation where appropriate.

## Shared top-down contract

- top-down / three-quarter 2.5D presentation;
- transparent sprites, nearest-neighbour runtime sampling;
- no caster baked into projectile sheets;
- no UI, labels or decorative boards in runtime sheets;
- projectile visual pivot = simulation center;
- visual dimensions do not define collision radius;
- elevation/arcing is a separate authored capability, not faked by shifting sprites inside cells;
- directional row order for new projectile references: `N, NE, E, SE, S, SW, W, NW`;
- paired directions must be exact mirrors when the delivery shape is symmetric.

## Delivery families

1. Burst — simultaneous symmetric multi-projectile fan.
2. Bolt — single discrete aimed projectile.
3. Beam — continuous/held or charged line delivery.
4. Spray — sustained cone/stream volume.
5. Rapid Fire — repeated small discrete projectiles with cadence authority.
6. Whip — flexible line/tether/sweep delivery.
7. Orb — slower larger payload, optionally lobbed only when height authority exists.
8. Wave — broad travelling front.

Every promoted element must eventually be represented on every accepted delivery foundation, but simulation semantics remain authored rather than inferred from the sprite.

## Burst v3 visual contract

The validated runtime grid is 16 columns x 8 directional rows per element.

- columns 0-1: spawn;
- columns 2-7: travel;
- columns 8-11: impact;
- columns 12-14: residue;
- column 15: reserved.

Runtime cells are 32x32. The project-bound 3×3 style board is cropped and
normalized by `tools/assets/prepare_burst_runtime_v3.py`; its generated manifest
locks hashes, pixel budgets, pivots, directions and phase columns while keeping
release approval explicitly false until integrated acceptance.

Exact symmetry is derived from a right-facing source frame:

- South = vertical mirror of North;
- South-West = horizontal mirror of South-East;
- West = horizontal mirror of East;
- North-West = horizontal mirror of North-East.

The burst fan is never baked into a single sprite. The runtime spawns independent projectile entities around the true aim vector.

Recommended first deterministic fixture:

`count=5`, relative angles `[-24, -12, 0, +12, +24]` degrees.

Projectile entity IDs are allocated in negative-angle to positive-angle order.

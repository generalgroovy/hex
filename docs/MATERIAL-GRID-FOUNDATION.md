# Material registry and grid foundation

Status: **canonical current material-state foundation**. Registry/grid/reset are
live; first-eight reaction mutation remains gated by C6–C9.

## Implemented scope

Checkpoint F1 implements reactive-material gates C0 and C1 without pretending
that reactions already exist:

- a versioned canonical catalog with eleven occupancy materials and independent
  amount, temperature, wetness, Charge, and elevation fields;
- stable positive material wire IDs and SHA-256 content hashes;
- a validated Wellspring Material Yard definition authored as compact,
  non-overlapping rectangles and expanded into exactly 128 x 128 cells;
- packed integer columns rather than one Godot node or dictionary per cell;
- a complete worldbone perimeter and internal reset plinth with a separately
  verifiable immutable hash;
- a deterministic deduplicated awake queue processed in ascending cell order
  under a real-time work budget compiled for the authoritative 120 Hz;
- guarded runtime writes, exact seed reset, canonical full-state hashing, and a
  read-only one-texture debug preview in the playable Wellspring.

Content sources:

- [`foundation_materials_v1.json`](../content/materials/foundation_materials_v1.json)
- [`sanctum_material_yard_v1.json`](../content/maps/sanctum_material_yard_v1.json)

Reaction design sources, not yet executable runtime behavior:

- [`ELEMENT-REACTIONS-FIRST-EIGHT.md`](ELEMENT-REACTIONS-FIRST-EIGHT.md)
- [`ELEMENT-REACTIONS-IMPLEMENTATION-PLAN.md`](ELEMENT-REACTIONS-IMPLEMENTATION-PLAN.md)
- [`first_eight_element_reactions_v1.json`](../content/reactions/first_eight_element_reactions_v1.json)

The first reaction phase is locked to Earth, Fire, Water, Wind, Ice, Charge,
Light and Dark. Spirit, Chaos, Gravity and Time remain reserved/gated until the
complete first-eight fundamental acceptance gate passes.

## Cell storage

Each of the 16,384 cells owns parallel packed integer values:

| Column | Meaning |
| --- | --- |
| Material wire ID | Current occupancy material; `empty` is an explicit stable ID |
| Amount | Scale-1000 occupancy quantity |
| Temperature | Signed authored milli-temperature used by later thermal gates |
| Wetness | Scale-1000 independent coating/exposure field |
| Charge | Scale-1000 independent energy field, allowing charged water/metal later |
| Elevation | Signed authored height/head input for later collision and flow |
| Worldbone mask | Immutable topology membership |
| Awake mask/queue | Deduplicated deterministic pending work |

Charge is deliberately not an occupancy material: water, metal, a device, or a
fighter exposure may carry Charge without losing its material identity. The
grid stores no float and does not depend on camera visibility or rendering.

## Safety and determinism

The definition fails closed on unknown or duplicate IDs/wires, missing cell
fields, wrong dimensions, invalid chunks or work budgets, overlapping/out-of-
bounds seed rectangles, missing required sample materials, invalid quantities,
or any incomplete worldbone edge.

Runtime writes cannot change a worldbone cell or create new worldbone. Mutable
writes validate ID, amount, temperature, wetness, and Charge, then enter the
deduplicated awake queue. Queue insertion history is discarded by canonical
ascending processing. The authored 30,720-cells/second ceiling compiles to 256
cells/tick at the authoritative 120 Hz; unused whole-tick capacity is
not banked into an unbounded burst.

Reset copies the immutable seed columns, clears pending work/remainders/errors,
and reproduces the exact original state and worldbone hashes. Presentation
reads these arrays into one 128 x 128 texture and cannot mutate them.

## First-eight reaction direction

The design-locked first phase contains exactly 36 unordered element pairs. These
pairs are map interactions rather than a hidden damage wheel: they create or
alter materials, routes, friction, structures, visibility, conductor networks,
projectile/vector geometry, concealment and readable actor statuses.

The flagship lifecycle is:

```text
Earth + Fire
-> Magma
-> elevation-driven flow
-> cooling crust
-> Basalt
-> fracture
-> Rubble
```

Water may create Steam while rapidly cooling Magma, enabling an intentionally
created basalt crossing that can later be fractured into rubble. This lifecycle
must be implemented through typed material/structural state and bounded dirty
collision; it may never mutate worldbone.

The detailed implementation order is F2A reaction schema/orchestrator, F2B
structure plus Magma/Basalt, F2C thermal/hydrology, F2D Charge networks, F2E
vector/optical/visibility interactions, and F2F Dark/residue/matrix completion.
Only after all 36 first-eight pairs meet deterministic, reset, safety, network,
performance, readability and gameplay gates may the remaining four element
families receive executable interaction design.

## Deliberate limitations and next gate

F1 imports static examples of empty, worldbone, stone, brick, wood, water, oil,
fire, steam, ice, rubble, Charge, and elevation. It does not yet flow liquids,
transfer heat, burn, freeze, fracture, collapse, conduct, derive collision, or
replicate deltas. The new first-eight registry is explicitly
`design_locked_unimplemented`; its presence does not mean reactions currently
step in simulation.

F2A must first introduce a validated reaction catalog and the single material
phase orchestrator. F2B then adds typed structural damage/damaged stages/rubble
and the Magma -> Basalt lifecycle. Later F2 slices promote the remaining
first-eight interactions with conservation, fixed work, reset, replay,
worldbone, movement, collision, semantic network/presentation and 120 Hz tests.

# First-eight element reaction implementation plan

Status: **C5/F2A catalog compiler complete; C6 exposure/contact is active next**.
Runtime world mutation remains disabled until the bounded contact authority and
its reset/replay fixtures pass.

This plan implements the first-eight reaction network inside the **shared authored
Wellspring sandbox**, not inside isolated test rooms only. The canonical design
sources are:

- [`ELEMENT-REACTIONS-FIRST-EIGHT.md`](ELEMENT-REACTIONS-FIRST-EIGHT.md)
- [`ELEMENT-ENVIRONMENT-RESPONSES.md`](ELEMENT-ENVIRONMENT-RESPONSES.md)
- [`CORE-GAME-DESIGN.md`](CORE-GAME-DESIGN.md)
- `content/reactions/first_eight_element_reactions_v1.json`

## Scope lock

Promoted families:

`Earth, Fire, Water, Wind, Ice, Charge, Light, Dark`

Deferred until the fundamental acceptance gate:

`Spirit, Chaos, Gravity, Time`

No slice may silently introduce production behavior for a deferred family.

## Global design law

Reactions are **world-state transformations**, not an elemental weakness wheel.
They should primarily change:

- movement and traction;
- routes and traversal geometry;
- visibility/information;
- projectile trajectories;
- structure/cover;
- fields/networks;
- timing and resource pressure.

Damage and status are valid outputs but are not the organizing principle.

The same world inputs must produce the same physical reaction regardless of which
champion created them. Affinity may affect authored spell access/efficiency, but
never multiplies reaction physics implicitly.

## F2R — selective environment response foundation

This is now a prerequisite for promoting live chemistry beyond contained test
fixtures.

Goal: make maps explicitly declare what can react and what is inert.

Deliverables:

1. typed response classes: inert, cosmetic, state, movement, visibility,
   trajectory, structural, network, hazard, conversion;
2. material/prop response registry with stable IDs;
3. explicit element-operation whitelist per archetype;
4. thresholds/capacity/lifetime/reset metadata for strong operations;
5. editor/debug visualization of material tags, worldbone, reset groups and
   supported responses;
6. validator that rejects undeclared strong mutation callbacks;
7. fixtures proving visually similar objects may have different semantic
   response data without presentation becoming authority.

Initial interaction-dense archetypes:

- Water basin + sluice/pump;
- furnace/fuel/heat source;
- mutable soil/stone/brick + support;
- relay/capacitor/grounding node;
- prism/mirror;
- vegetation/growth;
- rubble/movable cover;
- wind/pressure device.

Exit gate: players/tools can determine from semantic data which interactions are
valid; unsupported combinations remain deliberately inert.

## Global runtime contract

Before a reaction becomes playable, the kernel must own:

- stable reaction IDs and deterministic unordered-pair lookup;
- explicit formation thresholds/prerequisites;
- fixed authoritative phase order per simulation tick;
- bounded dirty/awake work independent of camera/render visibility;
- typed actor effects such as slow, DoT, interrupt, reveal, mark, displacement,
  traction and projectile redirect;
- typed map effects such as flow, phase change, structure damage, temporary
  geometry, gas/visibility fields and conductor networks;
- source/owner/team/assist metadata separated from physical outcome;
- formation/active/residue lifecycle with hard area/lifetime/propagation caps;
- exact reset and canonical hashing;
- semantic presentation/network events rather than pixel-derived authority;
- authoritative 120 Hz deterministic tests and replay fixtures;
- worldbone preservation and route-safety validation;
- shared-world zone policy so safe/social regions can reject hostile mutation;
- eight-player stress bounds for events, reaction work and presentation.

## F2A — reaction schema and definition compiler

Goal: compile the complete first-eight design into executable data without yet
allowing unreviewed major map mutation.

| Deliverable | State |
|---|---|
| `ReactionCatalog` validator; exact eight enabled IDs and 36 unordered pairs | **Complete** |
| Unknown/gated element, duplicate/missing pair, invalid/fractional bounds, missing counter/telegraph and premature enablement fail closed | **Complete** |
| Stable wires `301–336`, symmetric lookup and content/compatibility hashes | **Complete** |
| Seven integer channels compiled onto nine shared primitive profiles | **Complete** |
| Fixed-capacity exposure/contact queue and ordered phase orchestrator | **C6 next** |
| Typed formation event with tick/cell/source/owner/team and deterministic same-tick conflict order | **C6 next** |
| Snapshot, replay, reset and 120 Hz scheduling proof | **C6–C8** |

Exit gate: all 36 pair definitions compile/validate; world mutation remains
explicitly gated by implemented operation handlers.

## F2B — structure + flagship Magma lifecycle

Goal: prove that chemistry can reshape a route while remaining resettable,
multiplayer-safe and worldbone-safe.

Foundation:

- typed mutable structural health/damage classes;
- warned damaged stages;
- deterministic support checks;
- ordered collapse;
- rubble material/state;
- bounded dirty collision/navigation updates;
- explicit basalt material/structural state;
- reset-group and shared-zone ownership rules.

Flagship lifecycle:

```text
Earth + Fire
-> heated compatible Earth
-> Magma
-> bounded elevation-driven flow
-> cooling crust
-> Basalt
-> fracture
-> Rubble
```

Requirements:

- formation requires compatible authored material + heat threshold;
- Magma follows deterministic elevation/neighbor order;
- contact applies capped short DoT/ground denial;
- selected growth/wood can ignite;
- selected mutable stone can soften;
- Water creates Steam + rapid cooling;
- Ice accelerates solidification;
- basalt may create temporary route/cover but never worldbone;
- fracture produces rubble and recomputes only bounded dirty regions;
- several players may contribute Earth/Fire/Water/Ice while credit remains
  deterministic;
- safe/social zones reject the hostile lifecycle entirely.

Exit gate: a shared Proving/Foundry fixture demonstrates melt -> flow -> cool ->
basalt -> fracture -> rubble identically at 120 Hz, including two-plus player
contributions and exact local reset.

## F2C — thermal + hydrology + movement

Promote in order:

1. **Freeze** — Water + Ice.
2. **Steam** — Fire + Water.
3. **Mud** — Earth + Water.
4. **Thermal Shock** — Fire + Ice.
5. **Flood** — Water + Water.
6. **Permafrost** — Earth + Ice.
7. **Conflagration** — Fire + Fire.
8. **Frostway** — Ice + Ice; M2a finite slow lane supersedes historical Glacier cover.

Integration requirements:

- traction feeds canonical movement;
- water depth/flow modifies movement through explicit bounded rules;
- gases feed semantic visibility without leaking hidden actors;
- flow uses fixed neighbor order and integer conservation;
- thermal thresholds use hysteresis to avoid tick-edge flicker;
- world activity boundaries prevent a training experiment from unexpectedly
  flooding unrelated safe/social space;
- existing slide/jump/wavedash routes are tested on dry, mud, ice and flood
  surfaces.

Exit gate: players can deliberately flood, freeze, melt, steam, muddy and
fracture routes; the same commands reproduce the same player/world hashes.

## F2D — Charge networks

Promote:

1. Conductive Flood — Water + Charge.
2. Grounding Network — Earth + Charge.
3. Overload — Charge + Charge.
4. Superconduct — Ice + Charge.
5. Arcflash — Charge + Light.
6. Plasma Arc — Fire + Charge.
7. Ion Storm — Wind + Charge.
8. Static Shroud — Dark + Charge.

Required systems:

- Charge remains an independent field;
- explicit conductor tags/graphs, never visual-metal inference;
- deterministic conductor discovery with hard visit limits;
- visible warning before propagated damage/interrupt;
- no same-tick repeat farming;
- grounding/network break are semantic facts;
- devices use shared typed interfaces, not bespoke map scripts;
- eight-player overlapping network tests remain under packet/work budgets;
- ownership/assist credit handles one player wetting, another charging and a
  third triggering an overload.

Exit gate: Water/relay/device fixtures produce bounded propagation, grounding,
overload and interruption with exact reset/replay.

## F2E — vectors, optics and visibility

Promote:

- Vortex — Wind + Wind;
- Dustfront — Earth + Wind;
- Firestorm — Fire + Wind;
- Mistcurrent — Water + Wind;
- Hailstream — Ice + Wind;
- Lightbend — Wind + Light;
- Crystal Prism — Earth + Light;
- Crystal Lens — Ice + Light;
- Mirrorwater — Water + Light;
- Solar Flare — Fire + Light;
- Radiance — Light + Light;
- Penumbra — Light + Dark.

Required systems:

- vector fields use explicit integer direction/strength/bounds;
- projectile redirection is deterministic and visibly previewed;
- actor air influence respects mass, collision and global speed ceiling;
- optical behavior uses semantic normals/surfaces, not sprite pixels;
- visibility effects modify only authoritative permitted information;
- several players' overlapping projectile trajectories remain readable;
- reduced-effects mode preserves vector/optical boundaries.

Exit gate: players intentionally curve spells, use Vortex for movement, create or
remove occlusion and manipulate Light/Dark boundaries without information leaks.

## F2F — Dark, residues and pair completion

Promote remaining reactions including:

- Blightsoil — Earth + Dark;
- Cinderveil — Fire + Dark;
- Blackwater — Water + Dark;
- Shadowdraft — Wind + Dark;
- Black Ice — Ice + Dark;
- Umbral Field — Dark + Dark;
- Fortify — Earth + Earth;
- any first-eight pair not already promoted.

Standardize:

- residue cleanup;
- overlapping-field ownership;
- replacement/priority;
- repeated exposure guards;
- accessibility cues;
- cross-zone propagation rejection;
- host/local reset interaction.

Dark concealment must always retain disturbance/edge cues and cannot become an
information-security bypass.

Exit gate: all 36 pair IDs have one executable baseline with explicit counterplay,
bounded lifecycle and shared-world behavior.

# Fundamental acceptance gate

Spirit, Chaos, Gravity and Time remain gated until all of the following pass:

| Gate | Evidence |
| --- | --- |
| Pair completeness | Exactly 36 first-eight unordered pairs execute; no implicit fallback. |
| Environment selectivity | Strong behavior occurs only on explicitly compatible material/prop definitions; inertness is supported. |
| Determinism | Authoritative 120 Hz suites pass; same-rate replay hashes remain stable. |
| Shared multiplayer | Eight-player stress covers simultaneous inputs, ownership/assists and reaction event budgets. |
| Worldbone safety | Maximum reaction/destruction pressure cannot mutate worldbone or remove critical connectivity. |
| Zone safety | Safe/social regions reject hostile mutation; local reset groups cannot corrupt unrelated world regions. |
| Reset | Materials, structures, fields, residues, networks and derived collision return exactly to seed where resettable. |
| Bounded work | Hard per-tick/material/network/event ceilings exist and are measured. |
| Map interaction | Reactions demonstrably change routes, movement, visibility, trajectories, cover or structure. |
| Counterplay | Strong outcomes have visible preparation and practical positional/material answers. |
| Readability | Normal/grayscale/color-vision/reduced-effects tests communicate formation, active state and residue. |
| Performance | Shared-world dense fixtures pass modest-hardware simulation/render/network budgets. |
| Gameplay | Multi-player sessions show deliberate setups, counters, cooperative combinations and recoverable mistakes. |

Only then may a new design review propose executable Spirit, Chaos, Gravity or
Time reactions.

# Development cadence

Each reaction slice follows:

```text
response/content definition
-> validator + failing deterministic fixture
-> minimal authoritative operation
-> reset/replay/hash checks
-> movement/spell/world integration
-> multiplayer ownership/zone test
-> semantic presentation/network event
-> counterplay/readability fixture
-> dense-work/performance fixture
-> warning-clean Windows 120 Hz gate
-> focused reversible checkpoint
```

Bounded schema/fixture preproduction may overlap final verification, but only one
unstable authoritative behavior slice is promoted at a time.

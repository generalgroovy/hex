# Element/environment response contract

Status: **canonical authoring contract for the first-eight sandbox phase**.

This document defines how authored world materials, structures, props and regions
respond to the first eight promoted elements. It deliberately rejects the idea
that every element must affect every environment object just because a physical
or fantasy simulation could imagine an interaction.

The goal is **clear systemic gameplay**, not exhaustive realism.

## 1. Core rule: explicit response or explicit inertness

Every gameplay-relevant material/prop archetype declares which elemental
operations it supports. Unsupported operations are inert by design.

Do not infer simulation behavior from sprite color, material name or player
expectation alone.

```text
visual appearance != simulation material
simulation material + authored response table -> allowed outcomes
```

Examples:

- a decorative metal railing may be non-conductive for gameplay simplicity;
- a dedicated relay plate may be conductive and networked;
- ornamental glass may ignore thermal shock;
- structural glass may crack from a validated temperature delta;
- painted water scenery may be presentation-only;
- authored water cells may flow, freeze and conduct Charge.

This keeps performance, counterplay and player knowledge bounded.

## 2. Response classes

An element/environment pair chooses zero or more explicit response classes:

| Class | Meaning | Examples |
| --- | --- | --- |
| `inert` | No gameplay mutation. | Wind vs massive worldbone; Water vs sealed decorative stone. |
| `cosmetic` | Presentation response only; no authority. | Dust puff, harmless steam decoration. |
| `state` | Changes a stored material/property state. | Wetness, temperature, charge, brittle, soot. |
| `movement` | Changes traction, acceleration, jump/slide route or flow. | Mud, ice, current, wind lane. |
| `visibility` | Changes LOS/readability information. | Steam, dust, darkness, radiance. |
| `trajectory` | Redirects/reflects/curves spell geometry. | Prism, wind field, mirrorwater. |
| `structural` | Changes support, health, geometry or collision. | Fracture, magma softening, glacier, fortify. |
| `network` | Participates in connected field/device propagation. | Charge water/relay/grounding graph. |
| `hazard` | Applies bounded damage/control. | Fire, magma, charged flood, blackwater exposure. |
| `conversion` | Becomes another material/state. | Water -> ice, Earth -> magma -> basalt. |

One pair should use the smallest set needed to produce a useful tactical result.

## 3. First-eight element environmental identity

### Earth

Primary environmental verbs:

- build/fortify;
- compact;
- fracture;
- create or manipulate rubble;
- interact with soil/mineral structure;
- provide grounded/conductive sinks where authored;
- create temporary traversal geometry.

Earth should **not** mean every rock can be freely reshaped. Worldbone and many
architectural surfaces remain inert.

### Fire

Primary verbs:

- heat;
- ignite authored fuel;
- burn growth/wood/oil where permitted;
- create smoke/steam through other states;
- soften/melt selected mutable Earth;
- produce thermal shock when real thresholds are met.

Fire does not automatically damage stone, metal or every prop.

### Water

Primary verbs:

- wet;
- flow through authored cells;
- cool;
- displace loose matter;
- create Mud with soil;
- freeze under Ice/cold;
- conduct Charge when configured;
- interact with pumps/sluices/basins.

Water does not simulate infiltration into every wall or object.

### Wind

Primary verbs:

- apply bounded directional force;
- move gases;
- move loose matter;
- redirect compatible projectiles;
- support airborne movement in explicit lanes/fields;
- atomize Water into mist;
- feed/spread Fire only through bounded authored rules.

Wind never becomes a universal physics solver for every movable prop.

### Ice

Primary verbs:

- reduce temperature;
- freeze authored Water/wet surfaces;
- create low-friction traversal;
- create brittle/temporary rigid geometry;
- focus Charge through superconductive authored states;
- create optical lenses where appropriate.

Ice does not automatically freeze all liquids or lock every moving object.

### Charge

Primary verbs:

- store;
- propagate through explicit conductor graphs;
- interrupt actors/devices;
- overload capacitors/relays;
- interact with Water/wetness;
- ground through authored nodes;
- combine with selected fields such as Fire/Wind/Light/Dark.

Charge never uses visual metallic color as a conductor test.

### Light

Primary verbs:

- reveal;
- illuminate;
- refract/reflect through semantic optical surfaces;
- create readable boundaries with Dark;
- cleanse selected concealment/residue;
- support authored protection/healing mechanics when an ability explicitly owns
  them.

Light does not bounce off every shiny surface or automatically heal.

### Dark

Primary verbs:

- conceal;
- decay transient/growth states;
- create attritional residues;
- contaminate Water/Ice/soil where authored;
- suppress or contest Light information;
- provide pursuit/trace mechanics without true unreadable invisibility.

Dark never hides simulation-critical danger without shape/motion/residue cues.

## 4. Environmental archetype matrix

The table is a design default, not executable data yet. Individual maps may opt
an archetype out explicitly.

| Environment archetype | Earth | Fire | Water | Wind | Ice | Charge | Light | Dark |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Worldbone | Inert | Inert | Inert | Inert | Inert | Optional ground sink only | Optional optical marking | Inert |
| Mutable stone/brick | Fortify/fracture | Heat/selected melt | Usually inert | Dust only if loose | Brittle/permafrost | Ground only if tagged | Prism only if mineral-tagged | Blight/decay only if tagged |
| Soil | Compact/raise | Dry/heat | Mud | Dustfront | Permafrost | Grounding | Crystal/mineral exceptions | Blightsoil |
| Wood | Structure/rubble | Ignite/burn | Wet/extinguish | Move smoke/embers, not timber | Frost/brittle optional | Usually inert | Reveal only | Decay optional |
| Vegetation | Growth/roots | Burn | Wet/growth support | Sway/spread seeds only if useful | Frost | Usually inert | Reveal/growth support if authored | Blight/decay |
| Water basin | Bank/redirect | Steam | Flood | Mist/current | Freeze | Conductive Flood | Mirrorwater | Blackwater |
| Oil/fuel | Usually inert | Ignite | Displace/dilute only if authored | Move flame/smoke | Usually inert | Usually inert | Usually inert | Cinder/soot interaction optional |
| Loose rubble | Compact/fortify | Heat only | Displace/mud if soil-rich | Move/dust | Freeze together optional | Usually inert | Usually inert | Decay usually inert |
| Metal relay/device | Structural anchor only | Heat/disable if authored | Wet/cool | Usually inert | Cool/superconduct | Conduct/store/overload | Optical device interaction | Static shroud/disable optional |
| Prism/mirror | Mount/fracture | Heat damage optional | Wet/distort optional | Usually inert | Lens formation optional | Usually inert | Reflect/refract | Dull/occlude |
| Steam/smoke/gas | Usually inert | Sustain/heat | Condense/dilute | Move/part | Condense/freeze | Ionize optional | Illuminate/reveal | Conceal/deepen |
| Ice | Fracture/embed | Melt/thermal shock | Thicken/melt state | Hail/move particles | Glacier | Superconduct | Crystal Lens | Black Ice |
| Magma/basalt | Earth substrate | Heat sustain | Steam/cool basalt | Move gases only | Rapid cool | Usually inert | Glare/visibility only | Soot/decay optional |

## 5. Map-authoring rule

Each gameplay material or prop definition should eventually expose something
like:

```json
{
  "id": "water_basin",
  "responses": {
    "fire": ["heat", "steam"],
    "ice": ["freeze"],
    "charge": ["conduct"],
    "wind": ["mistcurrent"],
    "light": ["mirrorwater"],
    "dark": ["blackwater"]
  },
  "inert": ["earth"]
}
```

This is illustrative. Runtime schemas must use stable wire IDs, bounded numeric
thresholds and validated operations.

## 6. Interaction-density rule

A new environmental object should preferably participate in several existing
systems without becoming hard to read.

Good example — **sluice gate**:

- interact to open/close;
- changes Water flow;
- modifies a movement route;
- can power a wheel/relay;
- can create/destroy Conductive Flood connectivity;
- may become a team objective;
- can be reset by host/trial rules.

Weak example:

- decorative lever with one scripted animation and no relation to world state.

Interaction count alone is not a target. Add a connection only if players can
observe, learn and use it.

## 7. Strong reaction prerequisites

High-impact environment changes require preparation.

Examples:

- Magma requires sufficient heat in compatible Earth, not any Fire pixel touching
  any rock;
- Thermal Shock requires a real temperature delta and compatible structure;
- Conductive Flood requires connected wet/conductive state and a warning pulse;
- collapse requires authored structural damage/support loss;
- Light reflection requires a semantic prism/mirror normal;
- Dark concealment never suppresses mandatory danger silhouettes.

## 8. Shared-world reset and ownership

Because several players can manipulate the same sandbox:

- response operations record source/owner/team where relevant;
- the physical state is world-owned after creation;
- assists/environment kills can reference contributing sources;
- safe regions reject hostile operations;
- mutable zones declare capacity, reset group and cleanup policy;
- conflicting simultaneous operations resolve by deterministic phase order;
- clients receive semantic events, not authority to apply transformations.

## 9. Readability requirement

Every significant environment change has a visible progression where practical:

```text
formation/priming -> active state -> residue/recovery
```

Examples:

- wet surface darkens/animates before Charge warning;
- hot Earth visibly heats before Magma;
- structure cracks before collapse;
- water rims frost before complete freeze;
- conductor nodes pulse before overload;
- Penumbra has a visible boundary;
- Dark fields show edge disturbance when occupied.

## 10. Acceptance test

Before adding a new environment response, prove:

1. it creates a useful decision beyond cosmetic realism;
2. it is deterministic and bounded;
3. it has clear formation/active/residue presentation;
4. it has a practical counter or positional answer;
5. it works with multiple players without ambiguous ownership;
6. its performance does not scale without a hard ceiling;
7. it exactly resets where the map declares resettable state;
8. it cannot mutate worldbone or critical topology;
9. an inert response would not be clearer and better.

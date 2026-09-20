# The Wellspring shared-world contract

Status: **canonical initial-map contract**.

The Wellspring is FLUX's first large playable world: starting area, social space,
training campus, elemental laboratory, combat sandbox, application shell and
expedition threshold in one connected authored map.

It must not feel like a decorative menu that players leave to reach the “real”
game. Movement, spellcasting, environmental interaction, multiplayer coexistence,
training, discovery and local combat are already real gameplay inside the
Wellspring.

See [`CORE-GAME-DESIGN.md`](CORE-GAME-DESIGN.md) for the wider product contract.

## 1. World premise

The Wellspring spans approximately 12,800 x 7,200 design units across three
connected layers:

- **Terraces** — plazas, specialist districts, gardens, bridges, waterways and
  outer gates;
- **Crown** — rooftops, observatories, suspended gardens, race lines and airborne
  shortcuts;
- **Undercroft** — foundry machinery, flooded laboratories, utility passages,
  hidden practice spaces and reset infrastructure.

These layers form one authored sandbox. Streaming/culling may divide technical
work, but players experience a coherent connected world.

## 2. Districts

| District | Shared-world function | Signature systemic/movement role |
| --- | --- | --- |
| Nexus Court | arrival, onboarding, attunement and central orientation | radial routes, safe social core, world overview |
| Wayfarer Concourse | social, appearance, host/join, teams and travel | balconies, gatehouse routes, shared lobby visibility |
| Movement Conservatory | movement fundamentals, advanced routes, races | wallrun/kick, slide/jump, aerial reversal and wavedash lines; no vault requirement |
| Alchemical Proving Grounds | aiming, spell geometry, bots, chemistry and destructibles | reaction basins, resettable terrain, projectile-pattern drills |
| Living Archive | codex, builds, replays, analytics and discoveries | traversal through stacks/observatory, replay/training analysis |
| Verdant Recovery | recovery, interaction, low-pressure crafting and growth systems | vegetation/growth/material experimentation |
| Foundry Deep | fabrication, transmutation, structures, heat and water systems | machinery routes, furnace/magma/sluice interactions |
| Crown Observatory | settings, accessibility, diagnostics and session monitoring | rooftop movement/readability testing |
| Seasonal Expanse | biome pockets, private trials and later world events | changing surfaces and localized rule experiments |

District boundaries do not require global mode changes.

## 3. Several players in one world

The current first acceptance target remains up to **eight connected players** in
a host-authoritative session.

Players may simultaneously:

- explore different districts;
- train movement;
- test spells;
- spectate nearby activity;
- form teams;
- enter a duel or local trial;
- cooperate against an event;
- use social/configuration stations;
- manipulate permitted chemistry regions.

A local activity may temporarily seal a bounded region or participant set. It
must not pause, unload or force unrelated players elsewhere into that activity.

## 4. Activity-zone classes

| Zone | Hostile damage | Hostile chemistry | Typical purpose |
| --- | --- | --- | --- |
| Safe/social | Off | Rejected or cosmetic-only | spawn, social, configuration |
| Training | Configurable | Resettable/bounded | movement/spell practice |
| Contested | Explicit policy | Enabled with budgets | free skirmish/objective activity |
| Sealed trial | Ruleset-owned | Ruleset-owned | duel, race, chemistry challenge, boss/event |
| Private laboratory | Owner/party configurable | Strong resettable interactions | experimentation |

Rules are simulation data. A visual sign alone never defines safety.

## 5. Route model

The 2026-09-04 [movement revision](PLAYER-CONTROLS-AND-POV.md#movement-revision-no-vaulting-2026-09-04)
removes vaulting from runtime activation; no route requires it. Use ordinary openings around solid
cover, long runnable wall faces and broad reversal/landing pockets. A visual
jump does not grant general solid-obstacle clearance. The
[campus movement dimensions](proposals/wellspring-campus-v2/README.md#movement-led-layout-revision-2026-09-04)
now inform the validated 3072x1728 source layout. [Current acceptance](WELLSPRING-MOVEMENT-ACCEPTANCE.md)
distinguishes implemented geography from pending independent activity isolation.

Every major region provides:

1. **ordinary route** — clear and accessible without advanced techniques;
2. **advanced route** — faster/more expressive and skill-dependent;
3. **systemic route** — created/removed by element, structure, device or world
   state;
4. **recovery route** — prevents one failed movement technique from trapping the
   player.

Systemic route examples:

- freeze water to create a crossing;
- cool Magma into basalt;
- fracture a wall into rubble ramp/shortcut;
- open a sluice and use the new current;
- activate a wind lane;
- redirect Light into a relay;
- construct temporary ice/earth geometry.

No advanced or systemic route may be the only way to leave spawn, reach required
services or satisfy baseline accessibility.

## 6. Worldbone, mutation and reset

The shared world has three authority layers:

### Immutable worldbone

Contains:

- critical outer bounds;
- spawn safety;
- essential district connectivity;
- objective/service foundations;
- reset machinery;
- critical portals/transition anchors.

It cannot be damaged or converted.

### Authored mutable structure

May include walls, supports, doors, bridges, glass, trees, devices and cover.
Each declares structural rules, route-safety constraints and reset behavior.

### Transient world state

Includes liquids, gases, fields, residues, loose matter, growth, temporary
geometry and element-created state. It has hard capacity/lifetime/work budgets.

Mutable state belongs to a reset group so several players cannot permanently ruin
the world for the rest of the lobby.

## 7. Element/environment behavior

The Wellspring is the primary place to learn that element interactions are
**selective**.

A player should be able to discover, for example:

- authored Water freezes and conducts Charge;
- soil becomes Mud;
- selected Earth can become Magma under sufficient heat;
- Wind moves gas and loose matter;
- prism surfaces redirect Light;
- relays/capacitors route Charge;
- vegetation can grow/burn where authored;
- some visually plausible interactions are deliberately inert.

The environment response contract is
[`ELEMENT-ENVIRONMENT-RESPONSES.md`](ELEMENT-ENVIRONMENT-RESPONSES.md).

## 8. Local encounters and events

The Wellspring supports activity without forcing every combat into a sealed room:

- spontaneous skirmishes in contested spaces;
- opt-in duel circles;
- movement races;
- chemistry challenges;
- training targets/bots;
- cooperative enemy events;
- localized objectives;
- major world/boss events that seal only the necessary area;
- secrets requiring movement + material/element understanding.

Encounter spawning must consider nearby unrelated players and existing material
state so one activity cannot create unavoidable crossfire in another.

## 9. Attunement and fast travel

Fast travel remains diegetic infrastructure, not the primary navigation method.

1. The central attunement point is available after onboarding.
2. District destinations unlock through discovery/attunement.
3. Every destination remains reachable by ordinary traversal.
4. Travel fails closed during incompatible combat/trial/reset states.
5. The host validates multiplayer travel and consent where party movement is
   involved.
6. Fast travel does not unload the logical existence of unrelated players in the
   shared session.

Local movement remains valuable because the world contains routes, interactions,
secrets and other players between destinations.

## 10. Host/session tools

The host can manage:

- capacity/privacy;
- teams and readiness;
- spectators/late join;
- bots/training targets;
- friendly-fire/self-damage/healing/collision policy by activity;
- local trial start/reset;
- laboratory resets;
- shared waypoints;
- moderation and diagnostics;
- clean session end.

Host authority never grants remote file/shell access or arbitrary client-setting
control.

## 11. Visual and LOS behavior

Foreground terrain, roofs, foliage, buildings and constructs may fade/cut away
or expose ownership-readable silhouettes when they occlude an actor that is
already permitted by authoritative visibility rules.

Presentation cannot reveal actors or projectiles the simulation/network did not
permit the client to know about.

Combat readability priority remains:

1. local actor state;
2. hostile spell geometry;
3. immediate collision/terrain;
4. strong telegraphs/reactions;
5. other actors;
6. persistent world state;
7. decoration.

## 12. Implementation sequence

1. **Connected authored world slice** — replace remaining schematic geometry with
   a coherent Nexus -> Movement -> Proving -> Foundry route including elevation,
   landmarks, ordinary/advanced routes and visible district context.
2. **Concurrent-world activity layer** — several players occupy different local
   activities without global round transitions.
3. **Mutable region/reset system** — explicit safe/training/contested/lab zone
   rules and independent reset groups.
4. **Spell delivery proving space** — Bolt + Burst pattern drills, then remaining
   delivery kernels.
5. **Selective environment responses** — water/sluice, furnace, mutable
   structure, relay, prism, vegetation, rubble and wind-device archetypes.
6. **Live chemistry** — flagship Magma chain plus Freeze/Steam/Mud/Charge network
   fundamentals.
7. **Encounter ecology** — roaming/local PvE, objectives, chemistry/movement
   challenges and major events.
8. **Polish/acceptance** — streaming, map UI, settings, accessibility, physical
   Windows packaging and eight-player readability/performance evidence; portable
   Linux source remains frozen outside the active release gate.

## 13. Acceptance

The first Wellspring product gate passes only when a player can launch directly
into a coherent shared world and, without requiring another mode, meaningfully:

- explore;
- meet other players;
- practice deep movement;
- cast multiple delivery forms;
- manipulate permitted environment state;
- trigger/counter elemental reactions;
- participate in or ignore local activities;
- use social/configuration/travel systems;
- reset experiments safely;
- save/quit/reconnect;
- understand what is dangerous and why.

Procedural dungeons and larger modes are later applications of these accepted
systems, not substitutes for this gate.

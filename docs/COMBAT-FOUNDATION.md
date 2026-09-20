# Deterministic combat foundation

Status: **canonical current combat-runtime contract**.

FLUX combat runs only in the authoritative protocol-32, 120 Hz simulation.
`content/abilities/foundation_abilities_v1.json` is validated and compiled once
by `CombatDefinitionTable`; simulation, the Spell Loom, HUD ordering and
Farflow compatibility consume that immutable definition set. Stable wire IDs
are protocol adapters and are never reused.

Sixteen spells currently execute end to end across projectile, five-lane Burst,
beam, spray and persistent-field delivery. The exact live set, economy and
timing belong to the catalog and `ABILITY-CONFIGURATION.md`; this document owns
behavioral invariants rather than a hand-copied balance table.

## 1. Authority and ownership

| Owner | Responsibility |
| --- | --- |
| Ability catalog/compiler | Stable identity, element, delivery, integer cost/timing/geometry/control fields, validation and compatibility hash |
| Input/commands | Bounded aim, held primary and twelve semantic Plain/Ctrl/Alt spell presses |
| Combat simulation | Cast legality, Flux spend, startup/release, cooldown, recovery, spawn, target/world contact, damage, control and semantic events |
| Movement/resources | Intangibility, control state, Health/Flux/Stamina recovery and defeat-safe movement state |
| Session/round | Teams, spawn protection, knockout/respawn, score, round flow and rematch |
| Chemistry | Element exposure, reaction formation and material mutation; gated until C6+ acceptance |
| Presentation/audio | Interpolated shape, hands-only telegraph, ownership, impact and feedback; never an outcome |
| Network/replay | Validated semantic commands plus bounded authoritative state/events; never client-authored damage or endpoints |

No champion renderer, particle, sound, UI cell, client packet or animation may
spend Flux, release a spell, choose a victim, grant intangibility or create a
reaction.

## 2. Authoritative tick order

For each fixed 120 Hz tick, `SimWorld`:

1. validates tick/entity uniqueness and sorts commands by entity ID;
2. advances resources and defeat-safe state;
3. resolves movement, collision, grounding, intangibility and control state;
4. advances or starts casts and snapshots quantized aim at startup;
5. allocates field/projectile IDs in stable actor and lane order;
6. resolves instant beams/sprays after every actor has moved;
7. advances fields, then projectiles, in stable entity order;
8. emits bounded semantic events and increments the world tick;
9. hashes canonical player, projectile and field state for replay/proof.

Chemistry contact will enter this order only through the dedicated C6 boundary;
it may consume confirmed contact events but cannot reorder movement, hits or IDs.

## 3. Casting and action language

`content/gameplay/action_transition_matrix_v1.json` is the fail-closed policy
for casting during movement and control states. A cast request has exactly one
result:

| Result | Contract |
| --- | --- |
| Accepted | Positive Flux is reserved once, readable startup begins immediately, aim is fixed for that cast and release owns its cooldown/recovery |
| Empty/kit refusal | Slot or wire is unavailable; no resource or cooldown changes |
| Resource/cooldown refusal | The named Flux or cooldown cause is reported; nothing else is consumed |
| Physical-state refusal | Startup commitment, launch, grapple, charge, stun or root names the owning state |
| Obstruction refusal | Placement/spawn geometry is illegal; no partial fan or hidden projectile appears |

Movement continues through spell startup/recovery where the transition policy
allows it. Generic visual recovery is not a hidden global cast lock. A second
press during committed startup refuses clearly; held-primary cooldown checks
remain quiet so they cannot create per-tick feedback spam.

## 4. Delivery invariants

| Delivery | Current invariant |
| --- | --- |
| Projectile | Swept collision, explicit radius/owner/team/source/element, bounded lifetime and optional canonical ricochet/control |
| Burst | Five ordered lanes at `-24,-12,0,+12,+24`; one cost/startup, all-or-nothing legal spawn, stable child IDs and one-hit-per-target fan protection |
| Beam | Host-owned finite cover trace and nearest legal target; peers receive only the confirmed legal lane event |
| Spray | Host-owned bounded cone, stable target order, per-target cover and at most one hit/launch per legal actor |
| Field | Collision-safe aimed placement, fixed radius/lifetime and at most one trigger per hostile target |

Every attack costs positive Flux. Stronger geometry is balanced through explicit
cost, startup, cooldown, recovery, position and counterplay—not through hidden
global locks or automatic elemental damage advantage.

## 5. Damage, evasion and feedback integrity

- Shared collision shapes, teams, spawn protection, defeat state and explicit
  target legality decide contact before presentation.
- Jump and roll intangibility is read from canonical movement state; visuals do
  not widen its interval.
- A projectile hit, near-miss Edgeweave reward, block, bounce, expiry or evade
  is mutually consistent and produces bounded deduplicated feedback.
- Edgeweave rewards only a deliberate hostile swept near-miss above its movement
  threshold, never a hit, friendly/training shot or duplicate projectile.
- Damage, control, protection, victim/source and Health feedback must agree in
  the same semantic event chain.
- Reduced effects, grayscale and zoom may simplify ornament but preserve shape,
  owner, collision lane, phase and escape information.

## 6. Chemistry boundary

The first-eight element payload already travels with each live source, but the
36-reaction catalog remains mutation-gated. C6–C9 must add bounded exposure,
shared spatial primitives, lifecycle, reset, replay, snapshot and Crucible
evidence without branching combat into per-element copies. Elements change
space through chemistry; they do not create a hidden damage matchup wheel.

## 7. Expansion rule

```text
validated spell definition
  = existing delivery kernel
  + elemental payload
  + bounded modifiers
  + economy/timing
  + target/world policy
  + presentation recipe
```

A spell using an existing kernel should require content, presentation and
tests—not edits keyed to its champion or element inside `CombatSystem`. A new
delivery kernel is admitted only when it creates a distinct spatial decision
and proves cast/refusal, target/world contact, capacity, replay, Farflow,
accessibility, reset and package behavior before any spell using it is
selectable.

## 8. Acceptance

- Catalog/compiler and simulation definitions agree with no mirrored values.
- The same semantic command produces stable state/events at 120 Hz across
  source, replay, host and packaged journeys.
- Maximum legal actor/projectile/field/event pressure stays bounded and reports
  overflow rather than silently dropping authority.
- Every accepted cast exposes commitment, owner, active geometry, consequence,
  counter and recovery at all supported zoom/accessibility profiles.
- Player-facing feel, clarity and fun claims cite the named journeys in
  `PLAYER-EXPERIENCE-OVERHAUL.md`; tests alone prove rules, not experience.

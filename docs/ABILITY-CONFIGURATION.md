# Ability, spell and loadout configuration

Status: **canonical configuration boundary for current combat foundations**.

This contract began as the validated canonical configuration checkpoint and now
records the boundary consumed by deterministic runtime combat. Sixteen catalog
entries now cast end to end: Arc Primary, Vector Lance, the three foundation
champions' paired kit spells, and the complete comparable
Earth/Fire/Water/Wind/Ice/Charge/Light/Dark Burst set (with Cinder Fan as its
Fire member). Remaining entries are
configuration only. Network-visible identities, resource rules, loadout legality, affinity
behavior, and compatibility hashes remain trustworthy before any additional
combat code may promote an entry.

Combat is organized around **spell delivery geometry + elemental payload +
authored constraints**, not weapon classes. Existing names remain valid content
entries inside this broader reusable casting grammar. See
[`SPELLCASTING-DELIVERY-FOUNDATIONS.md`](SPELLCASTING-DELIVERY-FOUNDATIONS.md)
and [`CORE-GAME-DESIGN.md`](CORE-GAME-DESIGN.md) for the shared-sandbox model.

## Scope and authority

Runtime boot validates:

- `content/abilities/foundation_abilities_v1.json`;
- `content/champions/foundation_champions_v1.json`;
- `content/loadouts/foundation_practitioner_v1.json`.

Invalid content fails boot and the headless gate. Definitions are canonicalized
and hashed. Array order remains meaningful. Stable wire IDs may be deprecated but
must never be silently reassigned.

Animation, equipment and VFX present a confirmed cast; they do not create the
cast, hit, reaction or movement authority.

Schema 3 requires each ability to declare a bounded shape (`projectile`, `beam`,
`spray`, `field`, `defense`, `movement`, plus passive/ultimate), delivery,
impact, residue and planned material operation. `runtime_status` separates the
sixteen end-to-end spells from catalog-only designs, while
`material_runtime_enabled` remains false until a deterministic grid operation,
reset rule and route-safety proof actually exist.

The schema also owns the runtime economy: all playable spells pay positive
Flux, recovery waits 700 ms after a spend, and each spell must fit a declared
pressure, tempo or control cooldown range. Costs, cooldowns and the recovery
delay are compiled into integer simulation values and checked against content.

## Element-family gate

The twelve intended family IDs remain stable:

`Earth, Fire, Water, Wind, Ice, Charge, Light, Dark, Spirit, Chaos, Gravity, Time`

Only the first eight are runtime-enabled during the current fundamental phase.
Abilities referencing gated families fail closed.

Affinity is governed by the weighted three-point champion contract. Affinity may
modify **explicitly authored build efficiency/access**, never raw spell damage,
reaction magnitude, radius, duration, movement speed or resistance implicitly.

## Spell definition model

A spell is conceptually:

```text
elemental payload
+ delivery foundation
+ optional pattern modifier(s)
+ targeting
+ resource/timing constraints
+ ownership/friendly-fire rules
+ explicit counterplay
= stable ability ID
```

The first universal delivery set is:

| Delivery | Geometry |
| --- | --- |
| Bolt | One discrete projectile. |
| Burst | Several symmetric projectiles around true aim. |
| Beam | Sustained/charged line. |
| Spray | Continuous cone/stream. |
| Rapid Fire | Repeated small casts/projectiles. |
| Whip | Flexible sweep/tether. |
| Orb | Slow/persistent/lob-capable payload. |
| Wave | Wide moving front. |

These are reusable simulation/presentation foundations. Fire Burst and Water
Burst share Burst geometry; their elemental payload and world interactions are
different.

## Targeting families

Delivery does not replace targeting validation. The host still validates the
actual semantic request:

- projectile/swept projectile;
- ray/line;
- cone/volume;
- bounded curve/tether;
- ground/elevation region;
- placed geometry/structure;
- mobility destination/anchor.

Clients request approved spell IDs and bounded aim/target information. They never
send arbitrary damage, reaction, radius or geometry parameters.

## Loadout shape

The current competitive baseline remains:

| Slot | Count | Rule |
| --- | ---: | --- |
| Passive | 1 | Champion-defining behavior; no duplicate hidden passive stack |
| Primary | 1 | Reliable aimed pressure; positive Flux cost and pressure-tier cadence |
| Catalog actives | 3 | Unique, positive build/Flux/cooldown/startup/recovery; total at most 13 points after affinity discounts |
| Champion mobility | 1 | Flux-paid, collision-safe, bounded route |
| Ultimate | 1 | Ultimate charge, readable startup, interruption/destruction and recovery rules |
| Ordered spell weave | 12 | Plain, Ctrl and Alt layers each expose four buttons; up to twelve globally proven runtime spells are selected without duplicates and the remainder stay explicitly empty |

The current active budget remains 13 points until a deliberate balance migration.
Alternative modes may publish another hashed budget rather than mutate a live
session.

The foundation loadout uses two affinities and exactly fills 13 active points:
Vector Lance 5→4 (Charge), Prism Ward 5→4 (Light), and Stone Channel 5 (Earth).
This demonstrates discounts without granting elemental damage superiority.
The original schema-v3 validation fixture places Arc Primary, Vector Lance,
Prism Ward, Stone Channel and Phase Step first, followed by seven explicit
empties. Only the first two entries in that fixture are runtime-promoted;
additional live champion and Burst spells come from the same global catalog and
are arranged by champion attunement or Loom selection. Unpromoted fixture
entries remain validated content rather than fake casts.
Pocket Eclipse is the first promoted non-projectile shape: a finite Light beam
resolved after all actors move for the tick, stopped by cover, and applied once
to the nearest legal target along its lane.
Tideline is the first spray: a finite Water fan resolved at the same post-move
boundary, with stable actor order, per-target cover, one hit/launch per legal
actor and no projectile-only Edgeweave behavior.
Rimewake is the first persistent field: an aimed, collision-safe Ice sigil with
a fixed lifetime and radius. Each hostile can trigger it once; allies, protected
actors and dead actors remain unaffected, and planned material cooling is sealed.

## Current Spell Loom boundary

One of the Wellspring's twelve current walk-up stations is a host-authoritative
Spell Loom. It exposes
a 3×4 Plain/Ctrl/Alt grid and all end-to-end runtime-proven spells regardless of
the selected champion.
Placing one into a position swaps it with its previous position, so canonical
state keeps selected wires unique, carries an independent cooldown with a spell
through swaps, and retains explicit zero-valued empties. A proven spell outside
the current weave replaces the target position, which lets the fixed 12-position
control surface select from the planned 48-spell library.
The host accepts a bounded catalog-index/position request only while
the actor is inside the Loom radius; guests wait for the next validated snapshot
instead of applying a speculative loadout.

The arrangement is session-scoped. Champion attunement reorders that champion's
kit to the front, then appends every other globally proven spell in stable wire
order; it never hides another champion's runtime-proven spell. Left/right click
and the existing active key remain explicit legacy access paths during migration.
Catalog-only abilities never appear in the Loom, and no material operation is
enabled by rearranging a slot. The bounded request lane reserves 48 future
global library entries, while only the sixteen currently proven spells resolve
to wires.

## Promotion sequence

1. Canonical catalog/loadout validation and boot integration — complete.
2. Match compatibility metadata and save migration for selected loadouts.
3. Deterministic positive-Flux Arc Primary projectile — complete foundation.
4. Vector Lance with startup, Flux spend, cooldown, recovery, and impact —
   complete foundation; full visual/audio counterplay acceptance remains.
5. Oh Tipi Rillshot/Tideline plus resettable sparring effigy — complete basic
   projectile/spray pair; defense, full kit, final art/audio and balance remain.
6. S. Wayne Eclipse Disc/Pocket Eclipse — complete basic pair with a canonical
   single ricochet and a cover-stopped finite beam/slow; deeper dummy and
   accessibility reads remain.
7. Host-authoritative 3×4 Spell Loom for globally proven spells — complete
   foundation with independent cooldown replication; persistence and the first
   element-complete expansion remain.
8. One approved champion through bot, replay, network, reconnect, spectator,
   accessibility, and platform gates.
9. Compile optional Flux Formula variants from approved source-family,
   geometry, operation, catalyst, and constraint components; the host accepts
   stable variant IDs, never client-authored outcome parameters.

## Resources and timing

Every active spell declares, as applicable:

- build points;
- affinity discount ceiling;
- Flux cost;
- startup;
- active/travel duration;
- recovery;
- cooldown;
- lifetime;
- capacity/count limits;
- targeting bounds;
- collision class;
- friendly-fire policy hook;
- pattern modifier limits;
- cleanup/reset behavior;
- counterplay.

The current primary remains positive-Flux; it is not exempt from cadence,
collision, ownership and readability rules. Future modes may publish a different
resource policy only as an explicit, versioned content boundary.

## Delivery and element separation

Neutral delivery code owns:

- spawn pattern;
- geometry;
- trajectory/movement;
- lifetime;
- collision query;
- neutral animation phases;
- deterministic child ordering.

Element payload owns:

- heat/wet/cold/charge/etc. operations;
- actor status/control intent;
- material/structure/device operation;
- reaction eligibility;
- elemental presentation overlay.

This separation is mandatory for scalability and testing.

Example:

```text
Burst kernel:
  count = 5
  angles = -24,-12,0,+12,+24
  speed/radius/lifetime = authored

Water payload:
  wet + bounded displacement + Water world operation

Charge payload:
  Charge deposition + authored interrupt + conductor operation
```

The Burst kernel is tested once; each payload is tested against the same contract.

## Current foundation implementations

The current projectile combat code already proves:

- independent quantized aim;
- startup/release/recovery;
- deterministic projectile IDs and movement;
- swept world/player collision;
- lifetime/expiry;
- one bounded ricochet for content that authors it;
- damage/control events;
- edgeweave near-miss integration;
- replay/network authority.

Current content examples remain useful migration fixtures:

| Spell | Current role | Delivery interpretation |
| --- | --- | --- |
| Arc Primary | Charge aimed pressure | Bolt |
| Vector Lance | Charge high-commitment line projectile foundation | Bolt today; future Beam variant should be distinct rather than silently changing behavior |
| Rillshot | Water cadence pressure | Bolt / Rapid-Fire-like cadence fixture |
| Tideline | Water displacement lane | Wave candidate; current projectile implementation remains compatibility evidence until migrated deliberately |
| Eclipse Disc | Dark angle pressure with one bounce | Bolt + ricochet modifier |
| Pocket Eclipse | Light tempo/slow pressure | Current projectile compatibility spell; final delivery classification requires design migration |

Do not silently reinterpret a live wire ID when promoting a new delivery kernel.
If geometry changes materially, create/migrate a versioned ability definition.

## Flux Formulas

The expandable magic layer remains a validated content compiler rather than a
runtime scripting language.

The refined formula model is:

```text
element family
+ delivery foundation
+ operation/payload
+ optional pattern modifier/catalyst
+ constraints
-> stable spell variant ID
```

Examples of operations include heat, cool, wet, charge, push, lift, fracture,
grow, decay, cleanse, reveal, refract and redirect.

Catalysts may include:

- second approved element;
- carried reagent;
- device;
- champion-specific hook;
- material already present in the world.

Competitive play exposes curated legal formulas. The shared sandbox, Proving
Grounds and experimental/PvE modes may expose broader catalogs while using the
same validation and authority rules.

## Multiplayer spell rules

Several players may cast simultaneously in the same world.

Therefore:

- projectile/field IDs are host-authoritative and stably ordered;
- player/team ownership is explicit;
- physical reactions resolve from world state, not affinity contests;
- assist/environment credit is recorded separately from physical outcome;
- hostile/allied spell geometry is readable by shape/motion/audio as well as
  color;
- safe regions may reject hostile spell outcomes before mutation is created;
- dense effects have hard count/work/network budgets.

## Longer-term delivery sequence

1. Preserve current Bolt-like projectile foundation and its deterministic tests.
2. Implement **Burst** as the first true multi-projectile delivery kernel.
3. Normalize Bolt as a named reusable kernel rather than per-spell projectile
   special cases.
4. Implement Beam.
5. Implement Spray.
6. Implement Rapid Fire.
7. Implement Whip.
8. Implement Orb, including an explicit elevation/lob contract before any
   authoritative 2.5D arc behavior.
9. Implement Wave as a moving region/front rather than a shotgun approximation.
10. Apply at least two contrasting elemental payloads to each kernel before
     declaring the kernel accepted.
11. Expand to all first-eight element/delivery combinations through authored
     content after the fundamental kernels are proven.

No additional spell breadth is useful if its geometry, counterplay, world-state
operation or multiplayer readability cannot pass the shared core acceptance
criteria.

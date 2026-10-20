# Combat and grounded motion — rules 14

This pass makes existing elements and terrain interact more usefully. It keeps
the six elements, 63 exact field combinations, 30 champions, four equipped
spells plus signature, Story affinity progression, seeded maps and simultaneous
team commitment. There are no new resources, spell levels or turn phases for
the player to manage.

## Combat contract

1. **Move together.** Legal swaps and cycles remain possible; competing
   destinations and occupied landings can bounce. Voluntary movement never
   causes collision damage.
2. **Cast from the shared post-movement snapshot.** Existing marks enable
   conditional spell bonuses. A mark promised by another spell in this same
   volley does not. New control does not cancel an already sealed spell.
3. **Form one exact field.** Existing ingredients, natural substrate, spells and
   public creature releases combine once. A larger mixture does not secretly
   retain its constituent pairs' effects.
4. **Resolve spell damage, healing and ordinary field effects.** Aggregate
   protection is applied once. Healing, Flux grants and mitigation use the
   exchange position, as in rules 13. Liquid magical Water grants Wet for one
   planning round and extinguishes Burn before its tick. Frozen Water does not
   grant Wet. Ordinary map biome movement rules are unchanged. If incoming
   ingredients transform Water into Steam or another mixture, that exact
   mixture supplies its own declared effects instead.
5. **Resolve combined force.** Add all push and pull vectors before resistance.
   Guard subtracts one strength; existing Anchored prevents displacement. At
   most two forced steps are attempted, each of which can follow an Ice lane.
6. **Apply final contact.** A champion actually displaced onto another hex
   receives that final field's statuses and cleansing once. Crossed Ice hexes
   do not each apply contact. This creates useful traps and rescues: Water and
   Dark can form Black Ice while an ally's Gale pushes a rival onto it;
   Quagmire wets a landing occupant; a cleansing landing removes ailments.
   This step grants no second healing, Flux or protection calculation, and does
   not undo damage already taken. Clarity, Resolve and cleansing still protect
   against control. Fresh contact control grants Resolve before later impact
   control can apply.
7. **Resolve hard impacts and hazards.** A forced step blocked by a ruin or
   temporary barrier causes one damage and attempts Concussed for one planning
   round. A barrier raised in the same exchange can catch force; a simultaneous
   dispel can open the route. Units and map edges cause no impact damage.
   Impact and field hazards share the existing cap of one environmental damage
   per champion per exchange. Multiple casters cannot stack collision damage.
   Defeat and well scoring then follow the existing rules.

Contact never creates another cast, force or field. The system cannot recurse
through reactions, extend statuses by repeated path contact, or produce an
unbounded collision chain. A freshly granted Anchored still begins protecting
on the next exchange, matching the existing spell descriptions.

## Tactical outlook and CPU decisions

The aiming outlook shows a **stationary-rival scenario**, using only known
allied orders and public creature intentions. It shows the combined spell
volley, its guarded alternative and the selected spell's marginal contribution.
Ward and cover apply once; adding Water can create Steam and reduce the total
damage. Allied positions include known collision outcomes, including blocks by
stationary rivals and the allies following them.

This is not a prediction of sealed enemy orders. It excludes healing, Burn,
environmental damage and collision impacts. A rival can move or change the
field. The separate public-geometry displacement helper likewise does not
claim to know whether another unit will move away.

The CPU now values direct control only when it survives known Resolve,
Clarity, cleansing and Wet. It avoids redundant marks and theft against an
empty reserve, and evaluates coordinated healing after Wither once. Friendly
fire checks include zero-damage pulls and impairments. Public solid terrain can
make a push valuable away from a well; the scorer considers both guarded and
unguarded force without using a previous Guard flag as knowledge of a new
order. These are bounded public-state estimates, not access to enemy plans.

## Motion contract

Scenery atlas images and idle champion bodies stay anchored. Whole trees,
rocks, walls, planted creature bodies and shells do not sway or levitate to
simulate life. Creature movement is limited to appropriate local parts, such
as a tail flick, wing ruffle, moth wings or a flickering ember; readable public
release cues remain.

Casting keeps the existing character-specific motion voices, with anticipation,
release and recovery timed to the projectile leaving 120 milliseconds into
the 450-millisecond cast. A moving or pushed figure receives a short landing
accent at its actual final endpoint, using the same route clock: water ripples,
Ice fragments, leaves or dust. Blocked movement and stationary casts do not
invent footsteps. These accents are presentation only and do not change map
geometry or combat. Reduced motion disables body animation and contact
particles.

## Compatibility and verification

New matches use rules and protocol 14. Rules 13 combat, spell catalogue and
combination tables remain frozen; historical saves and sealed matches retain
their original resolver. The transport integration retains explicit version
dispatch and requires the established rematch consent path to adopt new rules.

The focused engine suite has **17 passing cases**. It covers liquid versus
frozen Water, new and surviving fields, voluntary versus forced contact timing,
same-exchange Black Ice traps, barriers and dispels, all relevant immunities,
the shared environmental cap, occupancy and edge negatives, final-only Ice
contact, no duplicate healing or Flux, deterministic simultaneous order
resolution and strict historical restoration.

The focused CPU suite has **7 passing cases**, including reproducible rules-13
mistakes corrected in rules 14, useful positive alternatives, seat symmetry,
immutable input and a complete seeded match restored after every round.
Outlook, landing feedback and old sealed-room compatibility have separate
focused regression files. Global type, production build, HTTP and published
browser evidence belong to the release record.

Automated correctness does not establish competitive balance or human enjoyment.
Damage outlooks intentionally show a bounded scenario. Physical-phone feel,
fresh-player comprehension and the attraction of these new tactical decisions
still require human play. Saved unit-array order continues to represent squad
slot identity for respawn placement; arbitrarily reordering that array is not
equivalent to changing simultaneous order submission order.

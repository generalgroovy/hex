# H.E.X. current design contract

Status: **current contract, locally qualified with p60-6d80c3bce71e, October 9, 2026.**
Exact source/package evidence and remaining human acceptance gates are recorded
in the [resume](.agent/HEX-RESUME.md) and [integration record](docs/element-expansion-evidence-20261009/integration.md).

H.E.X. (Help, Everything eXploded!) is a movement-led, top-down elemental combat
sandbox for Windows. Its depth comes from movement execution, finite resources,
projectile interception and temporary hex-based terrain—not an ever-growing set
of unrelated rules.

This is the current intent and scope. Validated content and simulation define
exact executable values. A disagreement is a defect to investigate, not permission
to silently retune the game. Build qualification belongs in the
[resume handoff](.agent/HEX-RESUME.md); pending work belongs only in the
[implementation queue](.agent/OVERHAUL-IMPLEMENTATION.md).
The [player guide](docs/PLAYER-GUIDE.md), [roster](docs/CURRENT-CAST.md) and
[balance contract](docs/HEX-BALANCE-CONTRACT.md) supply focused detail.

## Authority and scope

| System | Current contract |
|---|---|
| Platform | Windows x64; pinned Godot 4.7.1; Compatibility renderer |
| Cadence | 120 Hz authoritative simulation; 60 Hz snapshots; independent presentation interpolation |
| Session | Offline-first, host-authoritative, maximum 8 players; same-build joining |
| World | Screen-cardinal 6144 × 5376 Wellspring; seven districts, 13 map travel destinations, 12 services grouped in four Academy buildings; connected movement and chemistry routes |
| Cast | 30 named playable profiles; 0 reserved; 21 ancestries; Small/Middle/Large |
| Magic | Water, Fire, Air, Earth, Light, Dark; 504 selectable spells from 63 nonempty mixtures × eight deliveries; 12 equipped positions; Ice and Charge are derived effects |
| Chemistry | 63 bounded reactions: six self-pairs and every distinct subset of two through six elements; stationary whole-hex impact fields |
| Grid | 24 px face-to-face; 59,466 eligible Wellspring cells; topology cap 65,536 and selection cap 511; unchanged 64 paid casts / 32 products |
| Wire | Protocol 60 / SessionSnapshot 24 / SessionRound 2 / HexWorldSnapshot 5 / HexChemistrySnapshot 5; mixture/delivery state, finite reaction provenance and local prediction context |
| Delivery | Latest tested source and existing portable/installer are distinct; exact paths and evidence live in the resume |

At least 64 players is a future capacity target, not an enabled option.
Spirit, Chaos, Gravity and Time, arbitrary recursive
chemistry, vaulting, non-vault landing bursts and generic material-assisted
drift/grip are outside current scope. Retained IDs and compatibility helpers
are not selectable mechanics.

## Design principles

- Easy initial actions, meaningful execution and timing mastery; clarity before added mechanics.
- Every element, family, ancestry and champion should be independently useful and counterable.
  Implemented coverage and different numbers do not prove balance or unique playstyles.
- Walking and positioning remain useful; paid evasions are choices, not permanent immunity.
- Creative combinations change space, timing and decisions; costs and consequences stay legible.
- Original retro fantasy art: Game Boy Zelda charm, Gungeon threat hierarchy,
  Melee/movement-shooter execution and Noita/Magicka experimentation as principles,
  not copied assets, exact frame data or claims about those games' internals.
- Stable runnable checkpoints, small reviewed changes and measured optimization precede expansion.

### Reference-game adaptations

These are H.E.X. design translations, not copied implementation details or frame
data. Each must produce an observable player benefit under the existing contract.

| Influence | Adopt in H.E.X. | Keep out / acceptance boundary |
|---|---|---|
| Melee | Intentional directional evasions, earned momentum, readable commitment and precise follow-ups | No global hit-stop, input stall or automatic infinite chain; discarded held input cannot buy a later action |
| Apex / Titanfall | Independent aiming while moving, useful route transitions and an approachable movement practice space | No blanket speed buffs, free reattachment or ability that removes ordinary positioning |
| STRAFTAT | Short readable confrontations, useful cover/angles and quick return to experimentation | Do not equate more maps or one-shot weapons with depth; same geometry must work for both players |
| Noita | Consistent material rules, explainable combinations and player-created terrain | Keep finite paid hex matter, complete bounded ingredient subsets and explicit fusion, without every-pixel simulation or arbitrary recursion |
| Magicka | A small shared elemental vocabulary that composes into tactical choices | Preserve twelve configured slots; no obligatory recipe or hidden affinity damage bonus |
| Mega Man 11 | Defeat a rival that demonstrates a signature, then learn that spell | Real clean victory and explicit new access; no invented character grind or claim that the reference proves H.E.X. balance |
| Street Fighter training modes | Optional basics, specific practice, clear dummy/resource controls | Temporary local testing with visible overrides; practice tools do not fabricate progression |
| Enter the Gungeon | Clearly separated threats, impacts and safe movement; environment matters during a fight | Compact confirmed-hit feedback, not overlapping spell-name banners, false ranges or screen-filling effects |

Primary reference material: [Melee overview](https://www.nintendo.com/en-gb/Games/Nintendo-GameCube/Super-Smash-Bros-Melee-268951.html),
[Apex practice-space design](https://www.ea.com/ea-play/news/arsenal-season-game-updates),
[Respawn controls interview](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right),
[STRAFTAT developer store page](https://store.steampowered.com/app/2386720/STRAFTAT/),
[Noita](https://www.noitagame.com/),
[Magicka](https://www.paradoxinteractive.com/games/magicka/about), and
[Dodge Roll developer interview](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-),
[Capcom's Mega Man 11 explanation](https://news.capcomusa.com/lets/browse/ready-mega-man-11-is-out-now),
and [Street Fighter 6 Practice manual](https://game.capcom.com/manual/SF6/en/ps5/page/6/3).

The [reference and identity refinement](docs/REFERENCE-IDENTITY-REFINEMENT.md)
records source-backed mechanisms, H.E.X. adaptations, testable benefits and
transfer limits. A reference game's success does not prove a particular H.E.X.
number or combination is balanced.

### Race and character passives

Every supported race has one situational passive; every playable character has
one additional distinct personal passive. Both use existing controls and actor
state. Names, trigger windows, benefits and drawbacks are available together in
the Gallery and in full through Details and the Compendium. Base body stats and
flight/double-jump capability remain separate from these conditional modifiers.

The shared identity policy applies only to living champions. Race and personal
ratios multiply, with a final 75–135% bound. Positive payments and damage cannot
round to zero. Perks never grant material, reset air allowance, extend protection,
skip recovery delays or amplify outgoing damage. Existing control, coverage,
cooldown, Stamina and Flux admission remain authoritative.

Spell startup samples the pre-payment admission state; that spell's cooldown
duration samples the release state. A condition changing during a cast never retimes its existing
windup. Defensive posture is sampled before a hit interrupts movement. Actual
Health loss, including mitigation and lethal clamping, is the reported hit value.
Movement prediction carries the identity and resource/cast context needed to
evaluate the same windows; protocol 60 rejects incompatible prediction and reaction layouts.
Distinct definitions and passing regressions establish implementation coverage,
not equal viability or human acceptance of all fifty-one choices.

## Movement and resources

Aim and travel are independent. Keyboard input resolves eight normalized
directions; analog movement/aim remains continuous. Presentation never delays
input or changes authoritative momentum.

| Action | Contract |
|---|---|
| Walk / sprint | Base walk270px/s and sprint594px/s (2.2x), before profile/surface modifiers. Walking is free; sprint pays its full pending fractional Stamina tick before receiving speed. Refusal cannot add sprint acceleration; earned overspeed settles naturally and ordinary recovery remains available. |
| Ground Jump | Press prepares; release launches. Held preparation preserves travel and gradually brakes it at 600 world units/s² before existing surface/slow modifiers, including from Slide; no held-input acceleration or direction snap. Release inherits remaining velocity. External pushes still work. Charge caps at 300 ms. An instant same-command tap retains momentum. |
| Jump height | Approximately 47 px tap / 60 px charged apex; air movement remains controllable. |
| Double jump | One paid use per airborne period for non-flying races; walls do not replenish it. Non-flying first and second jumps use a tucked ball pose; hurtboxes and height remain authoritative. |
| Flight | Every race first uses the ordinary ground Jump. Sylph, wyrmborn, angel and demon use a deliberate airborne second Jump for paid held flight instead of double jump; size limits 2400 / 2100 / 1800 ms. Releasing ends flight without refilling its budget. No flight-granted invulnerability. |
| Slide | Paid entry adds 90 px/s once, capped at 900 px/s; 120 px/s² drag, 900 px/s² bounded side carve and 1800 px/s² opposed braking preserve actual remaining speed. Ordinary excess ground carry settles at 900 px/s². Entry needs 225 px/s, the current cost and cooldown; body faces travel. Fresh airborne Slide requests free fast-fall and, outside an active air dodge, buffers a paid landing Slide for 100 ms. Landing rechecks speed, resources, commitment and cooldown. |
| Roll / air dodge | Directional evasion with existing paid cost, commitment and finite protection; neutral aerial Evade requests fast-fall. |
| Wallrun / walljump | Suitable airborne held Jump attaches; release requests a legal outward/tangential walljump. No wall penetration, free reattachment or refreshed air budgets. |
| Technique / chains | Air redirect, wall actions, wavedash and impact tech compose under existing costs, cooldowns and commitments. Spent resources/air allowance are not refunded. |
| Deliberate fast-fall wavedash | A paid directional air dodge can convert on actual landing inside its existing 85 ms opening window when fresh airborne Slide has committed fast-fall. The natural low-dodge route stays valid. Landing ends dodge protection; existing speed, 240 ms route duration, 50 ms commitment and paid follow-ups remain. Forced control or impact cannot manufacture this extra qualification. |
| Input priority | Effective Evade → Jump → Slide → Technique. Refused/buffered Jump owns its chord; ignored held-Jump repeats do not. Lower-priority input must not change the accepted action. |
| Held intent ownership | A Jump gesture discarded by another effective action, or consumed by a wallrun, cannot later auto-buy flight or wall attachment. Release/repress rearms it; a genuine fresh buffered Jump remains eligible when legal. |
| Interruption | Menus, focus loss and stale remote input cancel anticipation/flight/wall intent without a release jump. A fresh Jump press during the last 100 ms of forced recovery may buffer until legal control returns; existing pre-interruption intent is canceled. Paid held actions must be released and pressed again; the shared game never pauses. |

Default keyboard keys: movement WASD, sprint Shift, slide/crouch C, Jump Space,
Roll/Air Dodge B and Wall/Air Technique V. Q is unassigned. Saved custom bindings
win; only the complete recognized old default layout migrates automatically.
Wheel impulses cannot perform a held jump/flight/wallrun gesture; coaching must
say so. All current bindings, including controller controls, are shown in-game.

Health determines defeat. Spells pay positive **Flux**; paid movement actions
use **Stamina**. Physical attacks/infusions are a gated future contract below,
not current playable actions. Walking, ordinary aiming and
free cancellation do not acquire invented costs. Preserve independent recovery
delays, quiet-time ramps and fractional accounting. Refused admission cannot
spend, start a cooldown or lose material; a paid startup is not refunded by
releasing its key. Casting and movement remain independent where their explicit
commitments permit them.

## Bodies, height and protection

| Size | Hurt radius | Wall clearance | Authored visual height | Base Stamina |
|---|---:|---:|---:|---:|
| Small | 17 px | 18 px | 58 px | 620 |
| Middle | 18 px | 18 px | 63 px | 660 |
| Large | 19 px | 18 px | 68 px | 700 |

Validated profile overrides remain authoritative. Size controls hurtboxes;
race, pose, visual scale and animation cannot silently alter them. Similar skull
sizes and increasing body volume distinguish sizes more than height alone.

Crouch/Slide avoids ordinary projectile bodies, not ground effects or radial
ground impacts. Ordinary airborne clearance begins at 18 px, but each attack
has its explicit plane/ceiling: Steam reaches 48 px. Wallrun remains exposed
despite elevated artwork. Roll/dodge protection is separate from height.
All visual protection, charge, height and landing cues must reflect real state.
Spawn protection uses a shield cue; timed roll/air-dodge damage avoidance uses
a visibly different broken dodge marker. Neither represents wall phasing.
Slower pose cadence must preserve immediate input and exact protection timing.

## Spells and planned physical combat

All characters can configure Plain 1–4, Ctrl+1–4 and Alt+1–4 at the Spell Loom.
These are twelve independently configured positions, not twelve spell families.
Spell-owned cooldowns survive equipment changes and swaps.

| Family | Strength | Delivery and intended niche |
|---|---:|---|
| Bolt | 5 | Readable travelling baseline; repeats while held |
| Heavy | 15 | Larger committed impact and area control; fresh press |
| Rapid | 1 | Low-strength repeated pressure/interception; repeats while held |
| Spray | 3 | Short cover-aware fan with finite ingredient and interception; fresh press |
| Mantle | Compiled definition | Short-lived close-contact coverage following its owner; approach and spacing matter |
| Fuse | Compiled definition | Land a delayed explosive; visible warning precedes its finite blast |
| Split | Compiled definition | One paid shot divides into a bounded set of branches; branches share finite matter |
| Rebound | Compiled definition | A bounded number of wall banks opens angles; no homing or unlimited bounces |

Every one of the 63 nonempty ingredient sets is available across all eight
delivery families, giving 504 runtime definitions. The original 24 IDs and
wires remain stable. Thirty explicit signature combinations are earned by
defeating their corresponding rival; all others remain available, and the Range
can borrow every definition. Valid previously saved/equipped spells survive
the introduction of progression. Wave, Beam, standalone
Field and Vector Lance remain disabled in selection and live admission.
Use compiled definitions for damage, speed, reach, cost, startup and cooldown;
do not duplicate stale numeric tables in the documentation.

The original Rapid, Bolt and Heavy families use a bounded inverse launch tradeoff:
`speed_px_per_second = 3600 / (reaction_strength + 5)` gives Rapid600/1,
Bolt360/5 and Heavy180/15. This is compiled launch data, not per-tick division
or a claim that HP damage equals chemical/interception strength. Slowing a
projectile through a field does not increase its payload, damage or blast area;
strength subtraction still consumes finite paid matter. Heavy's120px-radius
blast and Spray's90-degree fan trade coverage for paid startup, cadence and
exposure. Bolt remains a focused hit, not a new radial-damage attack.

Fresh explicit spell presses have priority, including refusal. Otherwise, the
lowest held repeat-enabled position is selected; a held single-press spell does
not suppress Bolt/Rapid. Failure never silently spends on a different slot.
Admission locks aim/endpoint; releasing input prevents new casts, not an already
paid release. Projectile scale follows remaining strength without inventing reach.
The pre-creation muzzle segment must not cross cover: check its center line,
then full-radius spawn occupancy and full-radius flight contacts. Sweeping a
Heavy's full radius from inside the actor would incorrectly reject legal shots
away from an adjacent wall. Blocked paid releases use existing expiry/no-refund
rules; cover cannot be bypassed by spawning the shot on its far side.

Spray retains its authored cursor-limited fan when its center meets narrow cover.
Each actor/contact/material-cell ray must independently clear physical cover;
world bounds still bound the envelope. Whole-cell deposition and the five cached
presentation spokes use the same analytic physical-radius query. A pulse cannot
pass through cover that it breaks in its own phase. The existing nearest selected
field-contact witness remains conservative: a shadowed nearest witness is not
replaced by an exhaustive search for another exposed part of that field.
Prepared fan visuals are gated per spoke from the current observer, not by the
hidden full center endpoint. With active chemical concealment, a remote spoke
whose observer/start/end bounds overlap a concealing product's whole-cell bounds
is omitted conservatively; near-field false positives are preferable to hidden
pixel disclosure. This uses bounded rectangle tests, not per-pixel sight scans.
The physically clipped cache and gameplay authority remain unchanged.

Punch and Kick have reserved left/right mouse bindings but are currently marked
UNAVAILABLE; bindings are not a completed combat path. Their future contract is
Stamina-paid bare attacks with different contact/knockback tradeoffs, and Flux-paid
elemental infusion that deposits only on valid contact, never a free miss-field.
Enable only after end-to-end admission, cost, contact and prediction acceptance.
Art never gates current spellcasting.

## Elements and chemistry

Display order is Water, Fire, Air, Earth, Light, Dark. Water includes Ice and Fire
includes Charge effects. Internal `wind` and live wires Earth1, Fire2, Water3,
Air4, Light7, Dark8 remain stable. Historical Ice5 and Charge6 are rejected by
live admission. Saved local weaves offer a per-slot migration preview and keep
an original-file backup before the player's explicit Apply; network IDs never
silently migrate.

| Element | Current distinctive self-reaction or delivery role |
|---|---|
| Water | Frostway damages first contact and slows ordinary ground travel/physical projectiles; Water Spray launches |
| Earth | Rampart creates finite destructible shot/movement cover and wall routes |
| Fire | Raw burning material and Conflagration exert shared area pressure; Fire/Air produces a warned electrical Arcstorm |
| Air | Vortex changes grounded routes through tangential motion |
| Light | Radiance damage/reveal and optical interactions; no invented healing |
| Dark | Larger Bolt, Umbral occupation pressure and concealment |

All six elements have offensive direct spells. Most raw ingredients are setup
material, not damage fields; raw Fire is an explicit exception. Each combination
must have a useful purpose, understandable cost and counter. Exact live effects,
phases and exceptions come from `src/sim/hex/hex_recipe_policy.gd`; names do not
grant undocumented healing, status, friction or projectile redirection.

Each paid cast owns 600 finite material units, immutable initial strength and
provenance, and separately decreasing remaining strength. Reserve required
capacity before payment; never evict paid state to accept another cast.
Clashing sources consume matched strength from both: a stronger survivor loses
the weaker amount, and only accounted portions feed the supported reaction.
Distinct paid sources may react; fragments of one source cannot self-react.
Source consumption, ground/flight portions, reaction stock and expiry must balance.

Every one of the 63 recipes has a damaging trigger and situational/environmental
behavior. Higher-order combinations compose finite shape, timing, movement,
visibility and recovery rules. Their complete named definitions, tells and
counters are in the in-game combination builder and
[reaction reference](docs/reference-refinement-evidence-20261009/six-element-combat.md).
Larger unions require a new ingredient and disjoint paid sources. Fusion consumes
parents atomically, transfers only their unspent damage and material, preserves
the earliest expiry, and carries one-time contact latches. It cannot refresh
damage already spent or loop through repeated duplicate ingredients.

Each consumed strength unit funds four Health of shared reaction damage.
Actual Health lost across all victims debits that pool, including perk effects
and lethal clamping; separate per-hit and control bounds still apply. At most
twelve source records and 180 funded strength belong to a result. The snapshot
includes each source's canonical spell and contribution, original ancestry time,
element mask, remaining damage and actor latches. This is a conservation and
counterplay contract, not a claim of proven PvP balance.

Impact or clash occurs at the exact world point. Shape/radius selects intersected
canonical hexes; the resulting **whole stored hexes** are the effect authority.
Positive-area intersection counts; edge/vertex tangency alone does not. Point
effects use their containing cell. There is no nearest-N clipping or second
analytic damage disk inside selected cells. Cover/occlusion, contact ordering,
height and protection remain exact.

All reaction footprints are stationary; current compact extents apply the
authored 75% factor once after overrides. Formation and decay are harmless.
No moving/growing Hailstream/Freeze or repeated reaction retile is enabled.
Neighboring material may merge visually, never its owner, clocks, budgets or
simulation identity. Compatible duplicate records count once for visible
adjacency; exterior and safe-hole boundaries must survive source removal.

### Steam and shared hazards

Steam applies increasing occupation pressure, not opaque smoke. It uses one
actor exposure history and the strongest eligible Fire/Steam pulse, not a sum
over overlapped cells/products. Fire/Steam/Conflagration can harm self and allies.

Fresh Fire may heat Steam once, consuming its own remaining paid material and
shortening remaining life. Fresh Water may cool it once, preserving all incoming
material, provenance, footprint and expiry. Cooling starts with the authored
thermal reduction, then accounts for old/new per-cell density and exact integer
pressure rounding so **realized scald damage cannot increase**. This bounded
calculation runs on the accepted modifier event, not per actor/tick.
Zero-intensity Steam retains finite residue without a danger flag; unused paid
Fire heating can restore pressure. There is no cooling-based broadening, refresh
or arbitrary recursive product chemistry.

### Glow and visual movement wakes

Magic uses restrained element-colored luminous cores and active-hex highlights;
real contact/field bounds, phase cues and safe holes remain authoritative. No
fullscreen bloom, scene lights, flashing halos or additional gameplay radius.

Characters leave short neutral pixel wakes sampled from their actual displayed
travel, with stronger slide/dodge accents. These are presentation only, not
copied bodies or elemental residue; they fade within 120–180 ms and are cleared
on discontinuity, invisibility, scene reset, menus or Reduced Effects. Retained
history is bounded to eight actors and six strokes each; stationary bodies do not emit.

Decorative projectile tails and idle affinity orbits remain disabled.
The admitted Mantle trail draws from that same paid source's finite matter;
it never creates free material. Other deliveries retain their authored finite
split/contact/terminal allocation. Existing
takeoff, landing, wall, casting, height and protection cues remain separate.

## Wellspring, modes and UX

Players enter Wellspring, not a detached main menu. Lodge, Academy, Farflow Hall
and Rest Pavilion group all twelve services through their real doors; no
dedicated menu signs/huts. Every option independently checks reach, permissions
and current availability. Keep normal routes, movement chains, recoverable
practice targets and safe exits; apparent paths must match collision.

The 24 px chemistry grid shares one canonical origin. Terrain/cap art uses it,
but existing worldbone/practice walls still use their admitted collision
geometry. Decorative hexes do not imply a completed all-hex physical migration.

The Element Garden occupies 63 separated plots in Tideglass. Its six single-element
plots alternate raw deposits and matching-source reactions; the remaining 57
plots demonstrate mixed reactions. Together they show six raw materials and all
63 recipe identities. Exhibits use isolated, finite 61-cell authorities with
ordinary source accounting and expiry. They cannot change live player resources,
collision, progression or saves. Their boundaries clip spread deliberately;
Spell Range tests full effects. Only visible plots remain resident (at most 63).
Nearby cards show actual phases, ingredients, effects and counters; real player
spells remain live and render above the harmless exhibits.

| Mode | Admission / intent |
|---|---|
| Open Commons | Up to eight; shared practice and configuration |
| Duel Knot | Exactly two; 1v1 |
| Sparring Circle | Four-player FFA |
| Duos | Exactly four; 2v2 |
| Trios | Exactly six; 3v3 |
| Solo Duel Trial | Separate offline, 72-second paid-rival challenge; disclosed temporary kit |
| Signature Challenges | Thirty offline rivals; unique paid mixture/delivery signatures, earned only from clean authoritative victory |
| Spell Range | All 504 spell definitions; temporary twelve-slot loaners, explicit refill/reset/clear, no automatic casting or save |
| Element Garden | Offline Wellspring ground exhibits, 63 plots and a named map arrival; nearby explanation without another control |
| Optional Introduction | Skippable nonmodal observation of actual movement, jump, payment, recovery and a mixed Range cast |
| Developer tools | Explicit offline session; all-spell override, protection, Flux/Stamina/cooldown tools and pause rival commands; no earned rewards |

Resolve every defeat from a completed tick before choosing a winner; equal
winning trades draw. Team rosters freeze through sorted alternating assignment;
enemy-only shared points, departed scores and reconnect teams remain stable.
Late arrivals observe until admitted. Returning to Hearth restores charter teams.

The offline trial's visible rival has one compact world badge: gold HEAVY during
planned windup, cyan PAUSE during the actual recovery beat after paid cast startup
and recovery finish. Six static segments count down on the policy clock. PAUSE
means no new rival casts, not safety: existing shots and fields remain dangerous.
The badge follows ordinary actor visibility and never exposes a hidden opponent.
Round end and permanent departure expire owned temporary material through the
ledger without a refund or removal of permanent terrain; surviving provenance
must remain valid. Hidden enemies must not leak through labels or cues.

Gallery inspection is separate from Attune confirmation, which restores that
character's saved weave or its starter kit if uncustomized. Loom inspection must agree with highlighted element/family/filter,
preview replacement versus swap, and show real costs/readiness. No-op equipment
requests do not send commands. Menus own focus without pausing the world.
Compact cards show essentials; Details contains full source-derived rules.
The Gallery exposes all 30 champions at once in six columns and five rows,
sorted Small, Middle, Large and then name. Race is descriptive, not a column
or pagination system. Navigation follows the visible grid; size shortcuts move
focus without hiding anyone. Canonical catalog order and network IDs do not change.
The Gallery overview identifies actual paid flight versus double jump before
Attune. Its twelve-slot starter explanation and saved-weave wording must agree
with live restoration; an identity acknowledgement is not proof a guest's weave
request has finished. Affinities guide starters, not live damage/cost bonuses.
The paid chemistry demo retains observed result/cost and manual retry guidance,
then restores the original weave; no automatic recast or refund.

Normal Loom starts with the selected slot's ingredients and four core forms.
More Forms exposes all eight deliveries. Ingredient buttons compose an exact
mixture filter; family filters and bounded pages expose every definition without
filling the screen. Locked signatures explain the rival and the free Range route.
The Range uses the same validated weave transaction with persistence disabled.
Changing loaners preserves spell-owned cooldowns. Restoring a weave on the same
actor preserves the later of its current and elapsed original cooldowns. Leaving
the practice world restores the original weave in a fresh ordinary world; it
does not carry practice-world timers into that new world.

Signature progression is separate from preferences and saved weaves. Read-only
loading, bounded versioned records, exact pre-save backup and verified staged
replacement preserve existing bytes. Save failure is visible; a new spell can
remain available this session without falsely claiming it was saved. A cheated
attempt stays ineligible even if the player disables its tools before victory.
All sandbox characters remain available; no character-unlock grind is invented.
Developer overrides end at a world/network transition. Pausing rival commands
does not stop existing motion, startup, projectiles or fields. Resetting/clearing
uses explicit local actions and finite material retirement, never a time-scale
change or an unbounded source. See the [progression/testing decision record](docs/element-expansion-evidence-20261009/progression-testing-design.md).

## Visual and audio contract

Use original charming, readable pixel fantasy art consistent with approved
repository references. S. Wayne remains dark-skinned, Biggy Bob brown-haired,
Mifu Water/Air/Light, and the unnamed Angel is absent; the current roster owns
all identities and affinities. Style references are not gameplay data.

Detailed Gallery illustrations are a separate presentation resource from body
animation and HUD/card crops. Keep one portrait per live catalog identity,
recognizable current features, practical clothing and no baked magic, weapons or
lettering. Retain full-resolution source/provenance; ship 512px imported textures,
load on selection only, cache at most two and release on close. Enlargement is
read-only and must preserve selection, explicit Attune and menu input ownership.
Missing optional art falls back to the existing sprite portrait. Illustrations
do not establish animation completeness, alter stats or authorize roster changes.
Portrait personalities should vary through expression, gaze and posture, not
just ancestry, palette or the same confident smirk. Ground their visual direction
in current resource profiles, affinity priorities and available actions; do not
invent exclusive abilities or racial personalities. The [cast expression matrix](docs/CHARACTER-PERSONALITY.md)
records that distinction. Preserve originals and exact edit provenance.

Registered authored pixel frames use fixed scale and a 128×128 cell with foot
pivot (64,104). Eight art headings are S=0/360, SE=45, E=90, NE=135, N=180,
NW=225, W=270, SW=315, distinct from mathematical aim angles. Do not rotate a
side view to fake a rear quarter, resize per pose, or resume mesh morphing.
No staffs/wands, baked spells, shadows or environment pixels in body sheets.
The Gallery consumes these native 128px cells without a second shrink-to-fit;
card head crops remain native 32px before the common viewport transform. Similar
cranial sizes and volume-led size differences remain the artwork target. Equal
alpha bounds or fixed draw scale do not prove matching head/torso anatomy across
poses: review landmarks and actual motion before accepting an authored correction.

Thirty identities have admitted ground/cast pixels and held whole-body jump
keys. This is **not** complete authored strafe/slide/roll/flight cycles.
Travel owns gait/contact cadence; aim owns relevant facing and casts. Slide
follows travel. Fixed source-wide registration and explicit fallbacks remain.
The full pixel-cast route never falls back to deforming body-part meshes:
unsupported actions use registered rigid low/air whole-body keys, facing travel
for lane actions. These are visibly stable substitutes, not authored roll,
slide, flight, stagger or defeat cycles; missing independent cast arms remain
explicitly incomplete. Legacy fullbody mode remains an explicit separate option.
Review real moving gameplay, not only filled sheets or static portraits.

Non-flying jump and double-jump presentation uses compact native-part tucks.
Ball keys follow physical vertical phase rather than the global render clock;
double jump retains its reverse tuck through descent. Flight keys follow its
actual paid budget. These held keys never delay accepted input, landing,
forced control or protection expiry. Timed dodge protection uses a translucent
body with split marks and discrete remaining-window pips; spawn protection uses
an opaque body and a separate shield. Recovery restores the ordinary body on
the exact vulnerable sample. Reduced effects retain the same state meaning.
See the [animation decision record](docs/reference-refinement-evidence-20261009/animation-followup.md)
for measured cadence, established precedents and current qualification.

The single 75% gameplay zoom uses subtle bounded look/velocity lead; reduced
motion removes anticipatory pan. Screen-cardinal floors use the approved
illustrated elevation, without automatic scenery fading. Characters and active
danger get strongest contrast; floors and decorative wear stay quiet.
Shapes/value/timing supplement element colors. Normal/reduced effects preserve
the same threat footprint, phase, contact and identity; art cannot invent a hit
area or hide safe holes. Occlusion keeps visible wall faces and the local body
readable without revealing hidden opponents. The optional ground arrow shows aim.
Confirmed Spray contacts use the same compact exact-damage labels as projectile
hits. The cast-wide hit count is not shown: target-specific visibility owns hit
information, while the existing fan, element color and impact art own identity.

Local sound is feedback, not another sensor: confirmed eligible on-screen
contacts and local casts, four bounded voices, controlled peak and reusable
clips; mute, focus loss, menus and exit silence it. Volume defaults to 30%.
Listening comfort, low-resolution readability and accessibility remain separate
acceptance gates; the custom-drawn UI is not certified screen-reader accessible.

## Architecture and optimization

`input → semantic command → authoritative simulation → validated snapshot → presentation`

| Owner | Responsibility |
|---|---|
| content | Validated definitions, stable IDs, composition and compiled values |
| sim | Integer deterministic movement, combat, chemistry, collision and resource outcomes |
| net | Admission, exact same-build compatibility, prediction, reconciliation and strict snapshots |
| app | Input ownership, preferences, services, lifecycle and sessions |
| presentation | Permitted-state art, interpolation, GUI and sound; never gameplay authority |
| tools/tests | Reproducible checks, paid production routes, build identity and evidence |

Optimize measured repeated work, not assumed complexity. Conservative broad
phases reject only impossible contacts; exact fallbacks preserve tangency,
rounding, order, events, state hashes and bytes. Preserve caps, cadence, geometry,
paid budgets, warning windows and all essential visible threats.

Share only admitted immutable topology/compiled definitions; each world owns
mutable material, actor state and dynamic collision. Caches must be bounded,
invalidated by actual relevant data and independent of caller-supplied trust
flags. Concrete fast paths preserve extension/callback fallbacks.
Incoming validation remains strict. World, collision/prediction geometry and
application epoch publish atomically after successful preparation; refusal
preserves the previous world and pending commands. Never publish stale state
after callback mutation or count diagnostic render actors as network capacity.

Menu → Performance owns Low/Standard presentation detail and a 60/120/unlimited
frame limit. New and migrated preferences default to Low and 60. Low reduces
optional glows and decorative Garden samples while every paid footprint, phase,
ownership cue and essential warning remains available. Reduced Motion/Effects
retains its independent accessibility setting. Simulation cadence stays 120 Hz.

Wellspring ground is prepared as exact, lossless chunks up to 512×512 pixels before play.
Runtime admits at most two background decodes and two texture uploads per frame,
with bounded residency, visible-area priority and a prefetched neighborhood.
Offline arrivals wait for their required pixels without banking catch-up time;
network authority continues with local input neutral while its view prepares.
Leaving the campus stops queued demand and polls completed work without waiting.
Final teardown collects outstanding load handles. Rejected asset replacement
preserves the existing owner, map identity and resident textures.

Static Range stone, Garden plot geometry, material outlines and unchanged HUD
layout reuse bounded resident data. Painter order, alpha, native coordinates,
direct source mutation and cache overflow require explicit comparison controls.
Paid-field geometry conversion retains at most 512 exact fixed/expected polygon
pairs and returns detached geometry. Dynamic phase, stock, owner and lifetime
remain fresh. Retro fill/mark meshes retain at most 512 six-vertex polygons;
Standard surface glow retains at most 256 polygon entries and 512 meshes.
Retained mesh capacity uses the original drawing fallback without evicting RIDs
that may still be referenced. Compatible same-cell boundary deduplication is
limited to 64 temporary keys and never merges paid effects or their lifetimes.
The current implementation and its limits are recorded in the
[October 10 performance report](docs/performance-implementation-20261010.md).

Measure setup, memory, complete capture/encoding/application and p95/p99/cold
tails under real paid loads. A faster helper, correct headless simulation or
120 Hz setting is not a sustained rendered-performance pass.
[Scale dependencies](docs/HEX-CAPACITY-64.md) and
[historical performance evidence](docs/HEX-PERFORMANCE-EIGHT.md) retain specialized detail.

## Acceptance and documentation

Each bounded change needs a player problem, exact ownership, regression/positive
controls and a stopping condition. Freeze source for root-owned engine runs.
Use focused tests, relevant actual-input/render/network checks, then Full,
identity/import and boot at the integrated checkpoint. Keep failed evidence.

Source-tested, packaged, installed, native-reviewed, human-accepted and publicly
released are distinct states. Dense sustained 120 Hz remains historically
FAILED. Physical Internet play, complete animation quality and competitive
balance are not established by local unit tests or localhost success.

Only the [single queue](.agent/OVERHAUL-IMPLEMENTATION.md) schedules work.
The [resume](.agent/HEX-RESUME.md) identifies source/package versions and launchers;
evidence reports retain their own frozen receipts. The historical
`docs/current-checkpoint.json` pointer is not silently promoted.
Do not duplicate checkpoint histories in this contract.

Exact pre-consolidation text is preserved in
[the October 7 archive](docs/archive/core-docs-20261007/SPECIFICATION.md).
It is history, not a competing set of current instructions.

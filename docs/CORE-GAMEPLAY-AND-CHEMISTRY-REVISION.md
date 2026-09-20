# Core gameplay and first-level chemistry revision

Status: design revision and measured source audit, 2026-09-05; runtime baseline
`5b2b6c7`, protocol 37. Proposed behavior below is not implemented acceptance.
This is the latest ordering overlay for Q3/C6-C9. It preserves the Windows-only
scope, five playable champions, three body roles, 120 Hz simulation and the
post-chemistry playtest pause.

## One coherent game

**Move to create an opening, cast to shape a lane, leave material to set up the
next decision, and combine or counter that material before it disappears.**

| Language | Question it answers | Design boundary |
|---|---|---|
| Movement | Where and when can I act? | Universal techniques, clear commitment and resource cost |
| Spell form | How do I deliver magic? | Bolt, Burst, Spray, Beam, Field each solve a different geometry problem |
| Element | What temporary material do I leave? | Color, symbol, motion and lifetime remain consistent across forms |
| Reaction | What changes when two materials meet? | One readable spatial result, a counter and a finite lifetime |
| Champion/body | Which resource tradeoffs suit me? | Same movement access and honest collision; no affinity damage multipliers |
| Wellspring | Where can I learn and experiment? | Safe circulation, purpose-built practice areas and immediate reset |

Do not add more elements, forms or champions to compensate for weak composition
among the existing ones. Forty selectable grid cells are a foundation; chemistry
must give their elemental choices a useful consequence.

## Measured current-state problems

The ignored diagnostic `.godot/diagnostics/core_concept_audit.gd` executed the
ordinary `SimWorld.step` path in Godot 4.7.1, at 120 Hz. Results are in
`.godot/diagnostics/core-concept-audit.log`; this is a diagnostic, not a full suite.

| Finding | Evidence | Smallest correction to implement |
|---|---|---|
| Slow compounds accumulated velocity | After 120 walking ticks: normal 324 units/s; ratio 0.70 gives 38.497; ratio 0.65 gives 30.641 | Apply slow to target speed and an explicit acceleration policy, once; verify steady speed, expiry and every action family |
| Holding Slide can eat a Jump tap | Same ordinary command sequence, Jump at 100 ms: released Slide converts; held Slide does not | Base conversion on elapsed minimum commitment, independent of optional held duration; preserve costs, speed cap and protection |
| Spell input forgiveness differs from movement | Movement buffers 180 ms; `CombatSystem.step_player` discards taps during occupied startup or own cooldown | Candidate one-slot 100 ms intent buffer, newer deliberate input replaces older, revalidate at acceptance, spend only once |
| The complete grid is not complete elemental behavior | Generic fields all apply the same 0.70 slow; projectiles leave no persistent world material | Separate delivery, deposit and reaction; do not disguise generic slows as eight different materials |
| Field presentation has incorrect lifetime source | `bootstrap._draw_field` reads Rimewake lifetime for every field | Read the actual source spell; drive formation/active/decay from authoritative age |
| Visual vocabularies still diverge | Shared glyphs reach HUD/live bullets, but specimen and generic crystal-like field spokes remain | One element presentation profile for all phases and interfaces |
| Planned chemistry is not gameplay | All 36 recipes compile, but mutation is hard-disabled and compiled definitions omit authored actor/map effect arrays | Explicit validated primitive execution mappings and live acceptance per pair |
| Some design prose is stale | Player-experience contract still reported protocol 32, three champions and sixteen spells | Correct current facts; keep historical evidence labelled |

Source seams: `src/sim/movement/movement_system.gd`,
`src/sim/combat/combat_system.gd`, `src/sim/core/sim_world.gd`,
`src/app/bootstrap.gd`, `src/sim/chemistry/reaction_definition_table.gd`.

## Movement and casting decisions

| Area | Optimized rule | Acceptance |
|---|---|---|
| Ordinary travel | Responsive acceleration, confident braking and normalized diagonals; reserve extreme speed for paid actions | Direction/reversal traces for all bodies; no drift introduced by visual smoothing |
| Jump | Hold purchases height/time and air steering opportunity; protection remains a short opening | Height and invulnerability cues are independent; a tall jump never implies full-flight immunity |
| Slide | Hold purchases distance; Jump may convert after one clear minimum commitment | Early/middle/late taps work consistently with held/released C in eight directions |
| Evasion | Roll is dependable grounded escape; air dodge is a directed airborne commitment; slide is lane conversion | Preserve differentiated 130/120/50 ms opening windows until playtest evidence supports retuning |
| Chains | Retain earned momentum inside the 900-unit/s cap; preserve the 10%-step, 40%-cap premium and 333 ms reset | No passive hold or rejected action increments combo cost; show premium when relevant |
| Spell intent | One short queued intent; visible small marker in that slot; no macros or long queue | Death, stun, unequip, UI takeover and session reset clear intent; held primary cannot displace deliberate intent |
| Cast aim | Aim locks at accepted startup, with hands showing that line; queued intent captures aim when accepted | Consistent host/replay/prediction behavior; do not silently change aim-lock policy |
| Resources | Flux buys casting; Stamina buys movement; ordinary repositioning remains possible at low reserves | Measure regeneration downtime and viable escape sequences before further global cost cuts |
| Beginner controls | Four useful Plain spells by default; Ctrl/Alt are optional mastery layers | Same twelve configurable positions; no forced modifier choreography to learn one reaction |

The current 700 ms Flux regeneration delay can create a useful breathe-and-weave
rhythm, but its actual downtime needs measurement. Do not lower every cooldown:
that increases projectile/material density and can erase movement decisions.

## Temporary elemental deposits: next feature after grid clarity

These are **candidate playtest defaults**, not chemistry laws or current runtime.
Colors use the existing `content/visual/visual_language_v1.json` palette.

| Element | Base color | Deposit life | Flight/end placement character | Motion and read |
|---|---|---:|---|---|
| Fire | Orange-red `#dd5930` | 3 s | Sparse embers, concentrated terminal ember patch | Angular upward flicker, bright broken edge, visible cooling |
| Water | Blue `#368cf0` | 4 s | Spaced droplets, terminal shallow pool | Low expanding ripples; no opaque splash sheet |
| Earth | Ochre `#936f3f` | 5 s | Mostly terminal loose fragments | Quick settle, square cracks; outline distinguishes it from stone floor |
| Wind | Mint `#67cf92` | 2 s | Sparse directional air patches | Open curved streamers, visible travel vector, clear interior |
| Charge | Yellow `#e2b82f` | 2 s | Small charge nodes and terminal node | Intermittent broken arcs; no whole-screen flash |
| Ice | Pale cyan `#91e6ef` | 4 s | Sparse frost seeds, terminal frost patch | Faceted growth then clean edge retreat |
| Light | Ivory `#fff1c7` | 3 s | Spaced light marks and terminal seal | Measured ray pulse, diamond/cross silhouette |
| Dark | Violet `#9450c9` | 3 s | Sparse wisps, terminal veil patch | Inward crescent motion; legible perimeter and actor feet |

Delivery controls placement, element controls material. Bolt concentrates a
deposit; Burst distributes a cast's material across lanes; Spray eventually
paints a short cone; Beam deposits at contacts/terminal extent rather than an
unlimited full-length carpet; Field maintains a deliberately purchased area.
Implement Bolt/Burst first, then extend through the same deposit resolver.

Each accepted cast has one finite material budget. All five Burst children share
that budget and source-cast identity. Emission uses deterministic distance/cell
crossings with a minimum interval, a per-cast cap and a global capacity. Never
emit one persistent object per tick or multiply material by projectile count.

Deposit at the reachable terminal point on expiry or collision; never behind
worldbone. Bounces do not create repeated terminal deposits. Repeated contact
from one cast cannot count as a second source for self-pair recipes. Coalesce
same-source deposits deterministically without extending them indefinitely.
New paid casts can maintain pressure only inside published ownership/area caps.

First promotion makes real, replicated, resettable material available without
silently giving all colored patches damage or slow. Each deposit has ID,
source-cast/spell, owner/team, element, fixed-point position, radius/strength,
creation/expiry ticks and reset scope. Render age from this authority. The next
slice consumes those sources into reactions.

## Level 1 interaction contract

Reuse the existing 36 recipe identities in
`content/reactions/first_eight_element_reactions_v1.json`: 28 distinct-element
pairs plus eight self-pairs. Pair order is symmetric. Existing names stay stable;
the following are proposed minimum decision signatures for runtime acceptance.
They narrow expansive historical descriptions into testable first-level effects.

One overlap resolves one pair after visible formation. It consumes finite input
strength; each result has a bounded area, owner attribution, active interval and
counter. Level 1 products do not recursively react into arbitrary chains. A third
source is deferred or handled by an explicitly ordered later overlap, never by
frame/dictionary iteration accident. Initially allow one reaction result per
occupied chemistry cell. Costs and caps are admission rules; never drop active
harmful state merely to hide a rendering/network overflow.

| Pair | Existing recipe | Minimum distinct decision/effect | Counter/read |
|---|---|---|---|
| Earth + Earth | Fortify | Low temporary ridge intercepts low projectiles | Preview footprint; break or flank |
| Earth + Fire | Magma | Slow advancing hot front with a cooling rear | Visible hot edge; leave its travel lane |
| Earth + Water | Mud | Grounded speed reduction while inside a shallow patch | Correct proportional slow; step or evade clear |
| Earth + Wind | Dustfront | Directional moving veil with weak lateral push | Side boundary and drift arrow; use cover |
| Earth + Ice | Permafrost | Brittle temporary cover breaks into a warning-only crack pattern | Visible cracks; repeated impact |
| Earth + Charge | Grounding Network | Ground node absorbs a bounded incoming charge amount | Visible stored capacity; break the node |
| Earth + Light | Crystal Prism | One previewed projectile reflection plane | Facet arrow; reposition or fracture |
| Earth + Dark | Blightsoil | Patch suppresses regeneration while occupied | Vein perimeter; leave or cleanse |
| Fire + Fire | Conflagration | Stationary pulsed burn ring with a safe outer edge | Pulse countdown; exit before next pulse |
| Fire + Water | Steam | Expanding then thinning sight veil | Keep dangerous geometry/feet readable; leave or disperse |
| Fire + Wind | Firestorm | Narrow translating flame lane | Show direction and gaps; cross behind it |
| Fire + Ice | Thermal Shock | Delayed one-shot fracture pulse against temporary constructs | Crack countdown; avoid pulse radius |
| Fire + Charge | Plasma Arc | One short previewed branch between nearby nodes | Break line/connectivity before release |
| Fire + Light | Solar Flare | Brief reveal pulse followed by visible bright embers | Cover blocks pulse; no blinding screen wash |
| Fire + Dark | Cinderveil | Low ember veil with delayed contact burn | Ember perimeter and warning before damage |
| Water + Water | Flood | Shallow directional flow displaces grounded actors gently | Visible flow vector; cross perpendicular |
| Water + Wind | Mistcurrent | Narrow drifting mist corridor without Steam's radial spread | Read corridor edges; leave sideways |
| Water + Ice | Freeze | Growing frost strip applies a short slow on crossing | Advancing front and safe edge; no grip/drift mutation in Level 1 |
| Water + Charge | Conductive Flood | Timed warning pulse follows connected water deposits | Bright path preview; break or leave connectivity |
| Water + Light | Mirrorwater | Calm patch reveals crossing footprints/projectile disturbances | Disturbance rings show observation area; flank |
| Water + Dark | Blackwater | Local veil whose motion trails reveal occupants briefly | Read disturbed edge; keep moving out |
| Wind + Wind | Vortex | Bounded tangential force around a safe center | Draw rotation and center; enter/exit deliberately |
| Wind + Ice | Hailstream | Spaced icy pulses travel down a narrow lane | Gaps and direction visible; sidestep |
| Wind + Charge | Ion Storm | Drifting node zone emits bounded telegraphed pulses | Node countdown; leave predicted path |
| Wind + Light | Lightbend | One marked region bends an entering ray by a capped angle | Preview outgoing line; avoid repeated bends |
| Wind + Dark | Shadowdraft | Alternating moving concealment bands | Clear bands/windows; cross in a gap |
| Ice + Ice | Glacier | Thick temporary cover segment with slower formation than Fortify | Growth silhouette and HP cracks; break/flank, never vault |
| Ice + Charge | Superconduct | One narrow extended conduction path through connected frost | Line preview; break frost connectivity |
| Ice + Light | Crystal Lens | One ray splits into two weaker previewed paths within the original damage budget | Split marker and two escape lanes |
| Ice + Dark | Black Ice | Frost patch marks entrants then gives a delayed brief slow | Readable dark/frost perimeter; no hidden slippery controller change |
| Charge + Charge | Overload | Stationary node visibly charges then emits one radial push pulse | Countdown; leave or ground before release |
| Charge + Light | Arcflash | Short conduction line reveals actors it crosses | Bright line preview; break line of sight |
| Charge + Dark | Static Shroud | Veil reveals entry/exit silhouettes with a short static warning | Clear perimeter; avoid crossing at pulse time |
| Light + Light | Radiance | Sustained reveal area rather than Solar Flare's one-shot pulse | Bounded rays; solid cover remains meaningful |
| Light + Dark | Penumbra | High-contrast border briefly outlines anything crossing | Border itself is the readable effect; choose crossing timing |
| Dark + Dark | Umbral Field | Stationary concealment zone with motion ripples and delayed attrition | Visible boundary, movement disturbance, time to leave |

Every row needs a distinct silhouette/motion, at least one different spatial or
timing choice, one counter and a deterministic test. Different colors or names
alone do not count as unique effects. Products may share physics primitives.
The 2-5 s proposal applies to elemental deposits; reaction formation/active/decay
is separately authored and must not silently inherit the longer old profiles.

Material-assisted drift/grip remains deferred as explicitly requested earlier.
Freeze/Black Ice/Mud get first-level status/shape behavior; changing friction,
terrain rebuilding, recursive chemistry and four extra elements remain later.

## Visual, champion and world cohesion

| Layer | Optimization |
|---|---|
| Read priority | Actor/active threat first, reaction boundary second, deposit third, terrain texture last |
| Ownership | Element hue identifies material; outline/notch pattern identifies ownership/danger without borrowing another element's hue |
| Animation | Authoritative start/release/impact times; a small reusable per-element motion profile; no simulated lifetime in renderer |
| Spell families | Bolt = focused moving core; Burst = separated lanes; Spray = short widening cone; Beam = precise line; Field = persistent bounded region |
| Bodies | Preserve 58/68/76 templates, body-only layers and Baron proportions; repair contact/facing before adding ornament |
| Collision | Shared body hitbox stays honest despite visual size; feet/shadows and optional training overlay teach the actual footprint |
| Floors | Lower local texture contrast in combat lanes so Earth and Dark read; keep rich detail at borders/landmarks |
| Wellspring | Short safe loop connects Loom, movement course, duel court and Crucible; paired-source basins include immediate reset and repeat-last-recipe |
| Practice | A dry lane, a primed lane and a combined lane teach one rule at a time; tiny contextual result labels replace manual reading |
| Interface | Always Health/Flux/Stamina and four active slots; queued cast/nearby interaction only when relevant; complete tables stay in overlays |

## Delivery order and stop conditions

| Slice | Scope | Required exit |
|---|---|---|
| G0 correctness before exposure | Correct compounded slow and held-slide conversion; regression fixtures | Actual steady ratios; eight-direction hold/tap chains; prediction/replay; no immunity extension |
| G1 complete grid visual acceptance | Common symbols/cadence through startup, flight, terminal cue and fields; correct source lifetime | Eight elements and five forms distinguishable at 50/75/100%, grayscale and reduced effects |
| G2 elemental deposits | Bolt/Burst flight/end deposits, finite cast budgets, expiry and rendering; extend other forms only through the same resolver | All eight survive 2-5 s as authored; deterministic collision/expiry/owner/reset; no multiplying Burst material |
| G2 network gate | Compact persistent deposit snapshots, late join, packet loss recovery and reset | Varied worst-case eight-player packet sizes and visible state agreement; reject admission before hiding dangerous state |
| G3 Steam vertical slice | Fire + Water via overlap -> formation -> active veil -> cleanup | Both input orders, two players, expiry/range/impact sources, reset and reproducible in-world demonstration |
| G4 full Level 1 table | Promote the remaining 35 pairs in small primitive-based batches | Each pair's unique signature/counter and full lifecycle execute; no name-only completions |
| G5 integrated playtest | Movement + casting + deposits + pairs + full Windows package/Farflow | Full/Release checks, 120 Hz stress traces, accessibility and remote-play checks; pause for user |
| G6 measured refinement | Short spell intent buffer and targeted economy/body changes, before or after G5 if input evidence requires | A/B command traces and playtest; no broad cooldown reductions without density evidence |

G0 fixes are narrowly scoped prerequisites, not a new movement expansion. G1
finishes the projectile grid. G2/G3/G4 implement the user's explicit next order.
Q4's wider character polish is supporting work and must not indefinitely delay
deposits and the requested interaction table. Intent buffering can be pulled
forward as a tiny tested slice if it blocks ordinary weaving acceptance.

Network/performance work is part of every gameplay promotion. The current
snapshot's 1,392-byte compressed ceiling is already tight; adding arbitrary
positions can reject the whole packet. Do not overload combat FieldState or the
detached material-yard preview. Own sparse residue in SimWorld, include it in
hash/replay/snapshot/reset, and set runtime capacities from worst-case tests.
The old 128-reaction/512-cell/256-work-unit declarations are ceilings, not proof
that all can run simultaneously; execute cheap dormant phases separately and
admit active work deterministically. 120 Hz affords 8.33 ms per tick/frame target;
fixed-tick configuration alone cannot certify sustained rendering performance.

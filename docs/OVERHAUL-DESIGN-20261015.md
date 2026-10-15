# H.E.X. complete overhaul design

Status: **proposed illustrated overhaul; runtime implementation has not started.**
Date: October 15, 2026. The separate [product-loop candidate](BREAKTHROUGH-ASSESSMENT-20261015.md)
does not implement this artwork, architecture or AoE overhaul.
The user selected **illustrated 2.5D with smooth animated sprites**. The qualified
playable build remains **p61-d6d1bfb9c529**. Its foreground frame pacing is still
unmeasured. This document proposes changes to that build; it does not replace
[the implemented rules](../SPECIFICATION.md), [delivery evidence](performance-evidence-20261014/stationary-qualification-d6d1/README.md)
or [the single implementation queue](../.agent/OVERHAUL-IMPLEMENTATION.md).

## Direction and acceptance

Make Wellspring feel like a lively illustrated miniature: expressive characters,
solid architecture, warm natural materials and luminous, readable magic. Movement
and experimentation remain the core. A player should be able to predict what a
spell will hit, understand why it hit, see where their character is moving and
learn the next useful action without reading a catalogue.

The overhaul is complete only when the same integrated slice proves animation,
combat clarity, architecture, learning and performance together. Content counts,
still images and simulation assertions each prove narrower properties. None
alone establishes a smooth or enjoyable game.

Every numerical target below is a proposed H.E.X. acceptance criterion or tuning
hypothesis, unless explicitly identified as a current executable value. Reference
games support the technique and context; their success does not establish the
correct number, cost or balance for H.E.X.

## Audit baseline

| Area | Verified current state | Overhaul problem |
|---|---|---|
| Core | Six elements, 63 mixtures, eight deliveries, 504 spell definitions; 30 characters, 21 ancestries and 51 conditional passives | A large vocabulary needs a small, consistent visual and learning grammar |
| Animation | Independent presentation interpolation, directional action poses, tuck/flight and protection cues exist | Complete authored locomotion and transition cycles remain incomplete; interpolation cannot manufacture missing poses |
| World | Seven districts, thirteen travel destinations and 63 harmless Garden exhibits | Existing facade relief remains shallow and confined to original footprints; taller buildings need actual height, visibility and room rules |
| Combat | Deterministic contacts, finite budgets, height/protection and whole-hex chemistry | Direct hit, blast and residue use different rules that can look similar; hidden damage allocation can feel inconsistent |
| Menus | Remaps, scaling, device navigation, optional basics, Range tools and Details already exist | Important choices compete with status labels and explanations; teaching needs a shorter action-to-result loop |
| Performance | A qualified stationary movement optimization; bounded terrain/body residency and several reviewed rendering trials | Current packaged frame pacing is unmeasured. Earlier instrumented results and rejected trials cannot support a smoothness claim |
| Delivery | A qualified local portable and stable desktop wrapper exist | A source checkout still requires tools; a new player needs a separately verified downloadable package and clean first-run journey |

Source inspection and the existing [depth record and native captures](depth-clarity-20261013.md)
support this audit. They are historical captures, not a fresh playtest. The isolated
HUD fixtures are not evidence of an empty game world. No engine was started for
this design audit.

### Source anchors for implementation

| Contract / observed gap | Current source |
|---|---|
| Custom stepping, interpolation, owned-body redraw | [bootstrap.gd](../src/app/bootstrap.gd), accumulator around line 1072 and viewpoint redraw around line 4124 |
| Incomplete strafe/backward and advanced pose authoring | [pixel_flipbook_presenter.gd](../src/presentation/pixel_flipbook_presenter.gd), declarations at lines 13–29; [fullbody_cast_presenter.gd](../src/presentation/fullbody_cast_presenter.gd), actual action/phase selection |
| Body size and distinct height declarations | [body_type_profile_catalog.gd](../src/content/body_type_profile_catalog.gd), template validation around line 67; pixel presenter's nominal heights |
| Current presentation-only facade relief | [wellspring_architecture_skin.gd](../src/presentation/wellspring_architecture_skin.gd), authority comment and specifications; [visual_language.gd](../src/presentation/visual_language.gd), current cutaway restriction |
| Deterministic projectile contact and blast | [hex_projectile_combat.gd](../src/sim/hex/hex_projectile_combat.gd), eligibility/contact/blast around lines 197/594/689 |
| Current shared pools, statuses and combinations | [hex_expanded_delivery.gd](../src/sim/hex/hex_expanded_delivery.gd), [spell_status_policy.gd](../src/sim/combat/spell_status_policy.gd), [hex_composite_policy.gd](../src/sim/hex/hex_composite_policy.gd) |
| Current service directories and map | [wellspring_service_buildings.gd](../src/presentation/wellspring_service_buildings.gd), [campus content](../content/maps/sanctum_campus_g2_v1.json) |
| Loading/residency and shutdown ownership | [wellspring_async_terrain_stream.gd](../src/presentation/wellspring_async_terrain_stream.gd), [wellspring_terrain_stream.gd](../src/presentation/wellspring_terrain_stream.gd) |
| Saved settings, earned progress and transport cap | [player_preferences.gd](../src/app/player_preferences.gd), validation/backups around line 770; [signature_progression.gd](../src/app/signature_progression.gd); [session_transport.gd](../src/net/session_transport.gd) |
| Source versus portable launcher routes | [launch-hex.ps1](../scripts/launch-hex.ps1), Profile route; [current-delivery.json](current-delivery.json) |

Line numbers describe this inspected checkout and may move during implementation.

## 1. Art, characters and animation

Use one style sheet across characters, buildings, effects and interface icons:
rounded but distinctive silhouettes; restrained line weight; warm stone, worn
wood, cloth and foliage; a common light direction; clear contact shadows; and
stronger contrast reserved for actors and immediate threats. Charm comes from
shape, gesture and small environmental stories rather than constant particles.
Nintendo's Link's Awakening art director describes balancing miniature-world
detail against simplicity at the character's scale. That is the useful precedent
for H.E.X.'s illustrated world, not a mandate to copy its models or blur. [R2]

Keep all 30 identities and their original visual character. Build three pilot
characters first, spanning small, middle and large sizes and including a flyer.
Give each a readable face/pose, ancestry silhouette, personal motif and restrained
secondary motion. Avoid solving identity with recolours alone. Review all three
in gameplay scale, monochrome, reduced effects, bright paving and dark rooms.

Author idle, start, walk, run, strafe, backpedal, brake, jump, tuck, second jump or
flight, landing, roll, slide, wall attach/run/release, cast, hit and defeat states.
Use shared body-family rigs/templates where anatomy permits, with bespoke keys
for unusual bodies. A flyer does not inherit a ground character's tuck pose.
Feet, hands and the contact shadow must agree with the receiving surface.

Animation is driven by authoritative state, action phase, travel and aim. Smooth
visual blending must not delay input, prolong immunity, retime payment or conceal
the actual release. Decorative settling can outlive an action only while a new
action interrupts it immediately. Preserve the exact first/last protection ticks
and distinguish protection from a cosmetic flash. Review at 30, 60 and 120 Hz,
including frame drops, teleports and network correction.

Use body lean, cloth/ear movement and clean anticipation/recovery poses to make
actions readable. Keep the torso/hand aim independent of travel. Wallrun needs
clear wall contact, sideways lean and release direction. Jump and double jump
show the requested ball tuck; flying characters visibly deploy into flight on
the second jump. Trails record the recent path with a fading tail and clear head;
teleports and discontinuities clear them. Mantle's damaging trail gets a separate
ground boundary so a movement trail cannot be mistaken for an attack.

Choose the sprite production method through the pilot: hand-keyed animation,
2D skeletal animation with painted parts, or offline rig-rendered sprite frames.
All target the approved illustrated 2.5D presentation. A live 3D character rewrite
is not part of the selected direction.

Budget example: 12 motions × 8 directions × 8 frames × 128² × 4 bytes is **48 MiB
per character**, before atlas padding, extra layers or mipmaps. Three resident
characters would be 144 MiB; all thirty would be about 1.41 GiB. Doubling each
frame dimension quadruples that cost. Therefore pilot atlas sizes, reuse,
direction counts, trim/padding, loading and eviction before authoring the roster.
Texture file size is not a substitute for runtime residency measurement.

Acceptance: no missing or misleading gameplay state; consistent feet/shadow
contact; recognisable body and direction in representative moving scenes; exact
action/protection parity; bounded memory through repeated roster changes. A human
review decides whether the result is charming and natural.

## 2. Projectiles, area effects and elemental identity

Every travelling projectile is a luminous circular energy core with a restrained
halo, material motion, a short directional tail and a surface-aware shadow. The
core communicates its contact body; the halo is decorative and must never imply
a larger hit. Deliveries change rhythm and composition. Elements change material,
motif and status. Power changes must not produce an unannounced hitbox expansion.
Riot's clarity guidance supports accurate hitboxes, recognisable silhouettes and
visual emphasis proportional to threat. H.E.X.'s exact grammar is a proposal. [R1]

### One combat contract

Expose one source-derived description to simulation, renderer, Range and spell
Details: contact shape, explicit height/avoidance policy, wall policy, impact trigger, warning
phase, active footprint, damage policy, status, residue and expiry. Presentation
consumes the resolved result; it must not reconstruct a similar-looking radius
using a second formula.

First reproduce one reported surprise through a real paid cast and preserve its
command, contact point, cover witness, target footprint, protection state and
remaining stock. Classify the result as a contact defect, boundary mismatch,
timing mismatch, allocation surprise or missing explanation before changing rules.
Only show an exact miss reason if an actual event/diagnostic contract records it.

Distinguish four phases:

1. **Travel:** bright core and direction tail. A ground/contact anchor connects
   the orb to its actual planar hit position. Decorative lift or shadow does not
   create continuous projectile altitude or extra immunity; either would require
   a separately versioned gameplay model.
2. **Arming:** a quiet, unmistakable boundary with an inward timing cue. Its
   countdown comes from authoritative arming state. Do not promise safety after
   an impact-triggered projectile can already detonate.
3. **Active hit or pulse:** a brief high-priority edge/impact, exactly matching
   the resolved disk, fan, sweep or selected hexes. The edge remains readable
   while the interior flashes.
4. **Residue:** lower-intensity material inside the actual affected cells, with
   a distinct expiry cue. Harmless aftermath loses the harmful boundary.

Round blasts and whole-hex residue may coexist, but they must look different.
Hit detection must account explicitly for the actor's hurt radius, current height/avoidance rules,
protection, terrain clipping and contact order. Add Range modes that show those
boundaries and a short optional reason for a hit/miss; normal combat gets only
the necessary visual/audio response.

Current Heavy area damage and shared Fuse/Mantle budgets have different
allocation semantics. Audit and explain them before visual replacement. Proposed
breaking change: give area pulses an explicit finite budget and fair simultaneous
allocation. Freeze eligible targets for that pulse, calculate capped demands,
then scale demands uniformly if the pool is insufficient. Demands are actual
post-mitigation, Health-clamped loss, calculated with checked integer/rational
arithmetic. Equal targets must not
receive unequal damage because of entity iteration order. For example, a pool of
20 against two equal demands of 12 yields 10 each. Fixed-point remainder stays
unspent or expires under the authored rule; it is not awarded to the first entity.
Zero allocation causes no damage, debit, damage-derived status or hit confirmation;
commit must not apply mitigation or a minimum-one rule a second time. Under this
proposal Mantle consumes its one-positive-contact marker only on positive loss,
without extending lifetime or creating stock. Fuse's unspent terminal remainder
expires after its sole pulse. Freeze cover/protection state for the whole pulse,
then evaluate changes for the next pulse. Distinct paid products retain their own
clocks and budgets.

The single-target ceiling, multi-target utility and resource price need a new
balance pass. Shared pools also allow additional bodies to dilute damage, so test
body-shielding incentives and Heavy's crowd-clearing role before choosing a uniform
model. Do not place its current per-target damage into a small shared pool and
call that equivalent. Keep the current explicit per-target category if the new
model fails its role. This is a separately versioned gameplay change, not VFX cleanup.

### Delivery grammar

| Delivery | Readable energy-ball form | Tactical rule and demonstration |
|---|---|---|
| Bolt | One clean core and short tail | Fast aimed contact; show core versus miss at the hurt-radius edge |
| Heavy | Larger dense core with a weighty pulse | Committed, costly impact; preview the actual blast separately from the travel body |
| Rapid | Small equally readable cores in rhythmic packets | Sustained lane pressure with recognisable recovery gaps; no random flash clutter |
| Spray | A fan of separated globes or coherent bounded fan | Close spread coverage; show fan limits and do not imply one large circular blast |
| Mantle | Orbiting energy around the body plus ground-stamped wake | Offensive contact envelope, not a protective bubble; distinguish paid contact/trail, fresh damaging trail and harmless movement trail |
| Fuse | An orb settling at the committed point; any visual arc is cosmetic | Predictable delayed area denial; one readable timer and resolved footprint, no implied over-wall travel |
| Split | One parent with visible seam/orbiting seeds, then separated cores | A declared split trigger and finite child budget; no invisible extra explosion |
| Rebound | Ringed core with a pronounced heading mark | Visible legal reflection, bounded bounces and retained finite strength |

Fast deliveries must outrun the fastest legal player movement in their intended
chase context, with intercept and collision checked at that speed. Fuse's lob or
delayed mine is allowed to be slower because it communicates a different job.
Do not solve every delivery with the same speed, radius or bigger explosion.

### Six material families, all combinations

| Element | Core/material motif | Required distinction |
|---|---|---|
| Water / Ice | Rolling blue water with a pale crest; crystalline facets for actual recipe-specific ice | Chilled on hit and Frostway/other ground rules remain distinct; no new Wet or frozen status is implied |
| Fire / Charge | Amber ember core and warm rising flicker; separate charge cue where the actual derived effect applies | Burn and derived charge cannot share a generic sparkle |
| Air | Pale cyan pressure orb with rotating arcs and an open spiral motif | Direction/pressure reads without hiding the core |
| Earth | Warm mineral sphere, dark contour and restrained orbiting grit | Solid cover/impact differs from airborne decorative debris |
| Light | Ivory/gold lens with ordered rays and a sun motif | Brightness remains bounded and readable on pale ground |
| Dark | Violet core, strong rim and inward wisps/crescent motif | Darkness does not erase the hit body or imply concealment when none exists |

Current on-hit channels are Chilled, Burning, Gusted, Fractured Focus, Revealed
and Withered. Exact effects remain sourced from the implemented catalogue until a
versioned change is accepted. Mixtures use one dominant motion pattern for the
actual battlefield effect and a limited secondary accent. A stable six-position
ingredient mark belongs in selection/Details; normal projectiles need at most
two prominent accents. They keep their unique names in selection/Details, without
floating spell-name text during combat. All-six is a coherent convergence orb,
not six full emitters stacked together.

Keep 63 distinct compositions and 504 delivery combinations testable. For every
recipe record: a useful situation, immediate damage, additional environmental
effect, duration/area/resource limit, counter and comparison against a simpler
subset. More ingredients buy a different situational tradeoff, not automatic
superiority. Noita and Magicka support consistent experimentation; their open
combination systems do not prove H.E.X.'s recipes are balanced. [R3, R4]

Acceptance: boundary hit/miss/height/cover/protection cases, simultaneous victims,
all deliveries and all masks; payment and deterministic replay parity where rules
are unchanged; version/migration tests where they change. Human identification
tests must distinguish travel, warning, active damage and harmless residue in
dense casts, monochrome and reduced-effects settings.

## 3. World, building height, visibility and interiors

Use a common authored height scale and projection. The minimum wall/building
height is **2 × the largest approved character's opaque standing height**, feet
to crown, excluding glow, shadow, jump and atlas padding. Current pixel art has a
nominal large height of 68 while the body-profile catalogue declares 76: their
136/152 doubled values illustrate the discrepancy, not a final target. Freeze a
reference silhouette and reconcile these declarations before production. Apply
the requirement to map and practice walls and buildings. A low-cover exception
requires an explicit design decision with the user; merely renaming a short wall
does not satisfy the request. Test visible ground-to-top height at the same
projection/zoom. Visual rise must convey the actual blocking class. Current planar
contact and explicit avoidance rules remain until a separately versioned height
model is approved; taller artwork alone cannot create projectile clearance.

Author wall bases, faces, caps, corners, doors, windows, roof sections and contact
shadows. Separate the ground footprint from vertical artwork, with stable depth
ordering and coherent intersections. Decorative ledges never imply an accessible
platform. Raised walkways/ramparts require explicit walk surfaces, connectors,
fall/flight rules, cover, AI navigation and projectile-height tests.

Extend the existing self redraw into a complete occlusion system:

- Keep the local character's readable silhouette, facing and ground anchor when
  architecture hides it.
- Cut away only the relevant roof/front wall, with stable room/occluder selection
  and a short visual transition; boundary contact must not flicker.
- Show already-observable immediate threats where necessary for fair play.
  Cutaways do not grant sight through walls or reveal unseen opponents.
- Preserve doors, collision edges and hazardous floor boundaries during fading.
  A translucent wall is still solid. Protection and concealment retain separate
  cues and gameplay authority.
- Treat ordinary line of sight, local architectural visibility and network
  visibility as separate inputs to the final view.

Buildings become actual traversable rooms with doors, furniture, character-scale
space and a purpose. Pilot one Academy room connected to the outdoor movement
court; then cover the existing service buildings. Suggested roles: Academy for
practice, Archive for learned spells, Foundry for loadout experimentation and
Hearth for quiet preparation. Preserve convenient menu access to repeat actions;
entering a room should add place and interaction, not a compulsory walk to change
one setting. Link's Awakening's authored miniature interiors provide an art and
exploration precedent, not proof of a specific H.E.X. streaming scheme. [R2]

Start with one useful continuous planar room and a real doorway aperture, so
ordinary movement and contact can use the existing world. Define whether attacks
and chemistry cross an open door, how a closed door blocks, and what happens to
already formed fields when door state changes. Dynamic doors are a separate
rule decision; closing one must not silently recompute paid ground coverage.
Walking through a same-world doorway preserves held movement and live paid
attacks. Travel admission and input handoff guards apply only to an actual scene
transfer; ordinary doorway crossing must not behave like a modal fast-travel menu.
Use stable room IDs and explicit doorway transitions. Define arrival position,
camera bounds, visibility, combat admission, projectile/field lifetime and save
recovery. No resource refill, cooldown reset or damage evasion from repeatedly
crossing a door. Preserve live simulation rules or explicitly gate the transition
while in combat; never silently delete an incoming attack to make streaming easy.
Network peers must agree on room and transition state before multiplayer delivery.

Recompose the seven existing districts around landmarks and different routes:
garden terraces, a sheltered academy plaza, movement courts with wall chains,
quays with bridges, wooded paths, a tall foundry yard and an observatory ascent.
Vary enclosure, materials and sightlines before increasing land area. Each combat
space needs a safe approach, a useful alternate route, readable cover and room
for the largest character to move and dodge. Verify low/high scenery from every
approach, including bottom-of-screen occlusion.

Retain fast travel through the map: show the player's position, named destination
and arrival preview. Persist selection, provide obvious cancel/back and use one
travel confirmation only where it prevents a meaningful mistake. Do not fill the
map with simultaneous service descriptions.

The Element Garden keeps all 63 exhibits. Arrange six introductory beds around
a clear central junction, then grouped pair and higher-mixture sections. Selected
exhibits show exact cells, phase and effect; distant exhibits can use static
representations or low-frequency harmless animation after parity/performance
measurement. Player-created hazards remain fully authoritative. Use one selected
exhibit panel and an optional “Try in Range” action. A quiet exhibit must never
look dangerous and a real hazard must never inherit the exhibit's harmless cue.

Oracle of Seasons provides a precedent for understandable environmental changes
that alter routes. H.E.X. should use a few authored, resettable material/route
demonstrations in teaching spaces before proposing systemic destruction or an
entire puzzle campaign. [R5]

Acceptance: full-height comparisons beside every body size; self visibility and
hidden-opponent negative tests; cover/aim/wallrun/door/camera routes; large-body
navigation; room save/reopen and repeated travel memory tests; representative
busy Garden traversal within the performance gate.

## 4. Menus, HUD and learning

First launch opens to a ready character and usable starter loadout. Offer **Play**,
**Learn** and **Settings**, with Resume when there is a saved session. Network
setup belongs under Play with others; development diagnostics stay in Developer.
Do not make a new player choose among 504 spells before moving.

During play show only health, the resources needed for the next action, the four
slots in the active bank, relevant cooldowns/statuses and one contextual action.
Keep a compact bank indicator; changing/holding a bound bank modifier immediately
shows its slots. No duplicate character/location headings, persistent offline
banner, build identity or paragraphs over the arena. Vital information remains
discoverable; “compact” does not mean hiding an unavailable cast's reason.

The pause/menu structure is Map, Loadout, Character, Learn and Settings, with
session, return and quit actions consistently available; Developer is separate.
A spell card answers: what it does, what it costs, when it can be
used and what ground effect remains. Comparison shows meaningful differences to
the currently equipped spell. Exact numbers, recipes and advanced rules live in
Details, using the same source as combat. Keep search/filter/selection through
back navigation. Locked and practice-loaned spells have clear, different states.

Optional introduction teaches one outcome at a time: move and aim, fire at a
target, evade a telegraphed threat, use a movement chain, combine two elements,
then choose a practice task. Show one short prompt using the actual current
binding. Completion follows the observed result, not merely a key press. Allow
skip, replay and immediate free play; never hide the full controls or accessibility
settings behind tutorial completion.

Use existing Range tools as the learning backend. Present three simple entry
choices: **Try a spell**, **Practice movement**, **Fight a rival**. Advanced target,
resource and statistics controls expand on demand. After a defeat, optionally
offer one specific retry scenario from the observed cause. After a victory, show
the learned signature and a direct Equip / Try action. Preserve earned progress
separately from local developer loaners.

Microsoft documents contextual help, consistent labels and realistic setting
previews with examples from Forza Horizon, Minecraft and Immortals Fenyx Rising.
These support H.E.X.'s compact progressive disclosure and previews; they do not
justify removing essential explanatory context. [R8]

Acceptance: a new player can launch, move, cast, understand one avoided/hit area,
equip the learned spell and travel without external documentation. Run small
formative tests first, record misinterpretations, then revise; do not declare
universal usability from one successful tester. Check keyboard, mouse and pad,
remaps, device switching, 960-wide windows and 200% UI scale.

## 5. Movement, identity, rivals, progression and sound

Movement retains independent aim, paid expressive chains and meaningful recovery.
Make starts, braking, landings and wall transitions readable before raising speed.
Teach sprint → slide → jump → wall contact → release as optional route practice,
with visible alternatives and a paid failure/recovery path. Teach the actual
press-then-release Jump control rather than silently changing it to press-only.
Existing input buffering
must be measured before adding grace windows; any new buffer needs exact admission,
expiry and no-stored-free-action rules. Apex's training/movement guidance supports
useful route choices. Melee and Titanfall remain requested inspiration; exact
cancellation, grace-window or advanced movement transfers require specific
primary evidence before implementation. No frame data is imported here. [R6, R7]

Character and ancestry passives stay situational and use existing controls.
Audit all 51 for natural activation, recognisable benefit, combined caps and a
meaningful weakness. Present one concise ancestry sentence and one personal
sentence with a small real demonstration. Retune or redesign redundant passives
only after matched scenarios show overlap or negligible usefulness. Body size,
flight and visual silhouette must remain understandable tradeoffs.

Rivals demonstrate their signature through a consistent windup, attack and recovery
loop. Give each a readable spacing objective and response to cover/movement; limit
simultaneous high-priority attacks in groups through encounter design. Difficulty
comes from timing and decisions, not hidden resource exemptions. Learning a rival's
signature after a clean victory remains the progression core. Expand the current
three lessons into a coherent path only after the pilot shows learning transfer;
a thirty-rival list is not a finished campaign. [R9, R10]

Sound follows the same hierarchy as effects: imminent threat and confirmed impact,
then personal action/status, then ambience. Element timbre and delivery rhythm
work together. Give multiple simultaneous events a bounded priority policy;
avoid stacked identical impact sounds and random volume peaks. Preserve the
existing four-voice/eight-queued-cue ownership, mute/focus/modal/reset behavior and
no-hidden-source policy. Retain visible equivalents for audio cues and reduced-flash/
reduced-motion settings. Separate music/ambience/effects/UI controls are proposed
only alongside introduction of those mix channels; the current local cue system
does not establish a complete music mix. Listening tests remain separate from
screenshot review.

Acceptance: equal-resource moving/cover/group scenarios; meaningful alternatives
for all deliveries and identities; no infinite protection/resource chains; rivals
remain counterable with ordinary controls; earned unlock/reopen works; sound and
visual cues agree with actual contact and status transitions.

Enter the Gungeon is the relevant bullet-hell precedent for movement, rolls,
cover and distinct weapon behavior. Apply that relationship between readable
attacks and usable evasive space, while retaining H.E.X.'s finite elemental rules;
it does not justify copying projectile counts or dodge timings. [R12]

## 6. Performance and implementation architecture

Establish a **packaged, foreground baseline on the target PC** before expanding
the map or art workload. Use the desktop launcher for every player/performance
session. Match resolution, detail, cap, renderer, route, cast admissions, effect
coverage and host memory context; compare opposite orders. Record frame interval
distribution and stalls as well as average rate. Calibrate observer cost separately;
isolated simulation savings cannot be called gameplay FPS improvements.

The existing launcher's Profile mode runs a **source** diagnostic. Its Full/Light
comparison remains source observer calibration. Ordinary packaged play needs
external presented-frame measurement or a separately qualified diagnostic package
with matched runtime instrumentation; there is no assumed portable observer switch.
Keep source CPU intervals, packaged engine intervals and OS presented frames
separate. Record normal host app/memory load; do not silently close the user's apps
or change power settings to improve a result.

Proposed shipping target on the agreed low-spec profile: sustained 60 Hz with
approximately 16.67 ms frame intervals, no repeatable casting/Garden spikes and
enough headroom for the integrated art/world slice. Define exact percentile/stall
thresholds from the baseline before accepting a candidate. If the target cannot
be met, report the limitation and next measured bottleneck; do not disguise it
with empty scenes, fewer paid casts or an unannounced lower simulation cadence.

Provisional engineering envelope for the pilot, to freeze against a declared
hardware/driver profile in Stage A:

| Measure | Initial target, not a current result | Qualification |
|---|---|---|
| Frame work | At 1280×720, uncapped engine work p95 ≤16.7 ms, p99 ≤25 ms; no recurring >50 ms stall in a two-minute paid route | Three repetitions, first-use and warm, moving/casting/Garden/interior; presented pacing recorded separately |
| Headroom | Main CPU work around ≤10 ms p95 and valid GPU timing ≤12 ms p95 | Overlapping CPU/GPU work is not an additive 22 ms allowance; calibrate observer and unassigned cost |
| Memory | Aim for ≤768 MiB warm private memory, ≤1 GiB transient and ≤256 MiB unique textures | Measure actual private/working-set/resource residency and repeated travel plateau; shared GPU accounting remains explicit |
| Texture split | Initial terrain/characters/world/UI+VFX envelopes 128/64/32/32 MiB | A naive three-character 144 MiB sheet library already fails the 64 MiB proposal; prove a feasible pipeline before adopting the budget |
| Startup | First controllable scene within 5 s warm / 10 s cold on the declared SSD | Real package, no developer runtime; shader/import/load work included and controller/keyboard exercised |

These budgets can reject a pipeline. Revise representation, residency or the
declared hardware target transparently if they prove infeasible; do not quietly
replace the proposed targets with measurements that happened to pass.

Investigate in measured order: observer overhead and host pressure; authoritative
simulation children; ground-effect preparation/drawing; transparent overdraw and
state changes; texture residency/upload; UI invalidation; travel/startup work.
Use a minimal frame observer for ordinary packaged comparisons and a detailed
observer for attribution, with calibration linking the two. Riot's Swarm account
supports measuring representative load and simplifying only work the mode does
not need. It does not imply H.E.X. needs Swarm's flow-field pathfinding. [R11]

Keep the existing 120 Hz authoritative simulation and Compatibility renderer
until a separately justified migration proves net benefit and correctness. Use
bounded effect pools, prepared immutable geometry, material/atlas batching and
visible-region work only where profiling shows a cost. Maintain stable ordering,
contact outcomes and expiry. Cosmetic LOD may remove particles, small texture
detail and secondary motion; it may not erase a threat boundary, shorten a tell,
hide an opponent or reduce the server's combat work selectively.

Godot's optimization guidance supports separating steady cost, spikes and loading,
then measuring the limiting stage; its GPU guidance covers transparency and
batching tradeoffs. These are engineering methods, not a prediction of which
H.E.X. subsystem is currently slowest. [R13, R14]

Introduce narrow interfaces as needed: resolved combat presentation data,
character animation state, room/visibility state, asset residency and menu view
models. Extract these from the large bootstrap behind behavior tests rather than
attempting a simultaneous engine rewrite. Content schemas own height, door/room
IDs, spell footprint and art budgets. Import validation catches missing animation
states, unsupported combinations and mismatched visual/gameplay bounds.

Architecture and networking share the new contracts. Stable room IDs and content
hashes cross the wire; same-build gating remains. Authority changes require the
appropriate protocol/snapshot/content version and replay fixtures. Save migration
preserves settings, learned signatures, unlocks and legal arrival positions.
Cancel/close/unload paths must release owned resources without deleting user data.

## 7. Plug and play, tools, QA and repository maintenance

Ship an independently qualified Windows package containing the executable,
content and one obvious launcher. It must start offline for a standard Windows
user without Godot, Git, an editor, source paths or a separately installed shell.
The local desktop shortcut continues through the existing stable wrapper; the
redistributable player launcher must be self-contained. Test a clean Windows
environment, non-ASCII and spaced paths, read-only install location with writable
user data, graphics fallback, controller reconnect, first launch and normal reopen.

Unify accepted production defaults between the executable and bundled launcher;
current source still uses flags to select presentation paths. Direct double-click
must not silently select a different art mode. Developer alternatives stay explicit.

Choose conservative defaults, remember settings, provide a useful icon and show
plain actionable startup errors with an optional diagnostic log location. Keep
developer telemetry/console text out of ordinary play. Signing, installer choice
and public distribution require their own release work; a locally qualified ZIP
does not establish those properties.

Developer mode exposes focused tools: unlock loans, finite/infinite practice
resources with an obvious override indicator, target behavior, collision/AoE/height
overlays, animation state, room/cutaway inspection, fixed seed and controlled effect
stress scenes. It must neither write earned unlocks nor silently persist cheats
into a normal session. Reuse current tools before adding new panels.

Automated checks cover content legality, deterministic boundaries, exact action
timings, damage allocation, room transitions, save migration, input/UI navigation
and packaging. Visual review covers moving animation, dense effects, cutaways,
small screens and accessibility variants. Human acceptance covers feel, clarity,
learning and sound. Real two-PC sessions cover network claims. Full unfiltered
validation and delivery review remain necessary before changing the launcher.

Keep one active queue and clear current/proposed/historical labels. Derive build
identity and executable values from authoritative records. Remove an asset or
document only after dependency/reference checks and peer review show it is truly
unused or redundant; preserve original art, user saves, fallbacks and useful failed
evidence. Do not delete fixtures because their visuals look older than the target.

## 8. Implementation sequence

| Stage | Reviewable result | Exit gate |
|---|---|---|
| A — Freeze and measure | Exact baseline, scene routes, observer calibration, dependency map and proposed combat/height contracts | Repeatable packaged results and agreed budgets; qualified fallback preserved |
| B — Integrated pilot | Three body types, full animation transitions, six elemental cores, all eight delivery motifs, selected mixtures, one ≥2× wall, one enterable room, cutaway, revised HUD and a short lesson | Mechanical/visual agreement, human readability and frame/memory budget together |
| C — Combat and world contracts | Versioned AoE allocation if accepted, resolved footprints, room/height/visibility schemas and migrations | Determinism, edge cases, fairness, saves and two-peer boundaries reviewed |
| D — Full production | All 30 identities, 63 masks/504 spells, seven district kits, existing service-building interiors and all Garden exhibits | Coverage plus practical usefulness; repeated travel/casting/memory gates |
| E — Learning and polish | Revised progression path, rival presentation, sound, settings and accessible navigation | New-player and experienced-player acceptance; no critical information lost |
| F — Delivery | Clean portable, docs, exact Full/package/lifecycle evidence and fallback | Independent review before launcher promotion; publish/install claims separately qualified |

Stages overlap only where contracts are stable. For example, art production can
continue while room migration is reviewed, but a new room format cannot be rolled
through the whole map before the pilot passes. If a performance or comprehension
gate fails, repair the pilot instead of multiplying its problems across content.

The requested tall architecture, real interiors, art/animation replacement, spell
clarity, learning and plug-and-play work belong to this overhaul. Separate optional
expansions are multi-floor simulation, destructible buildings, a full campaign,
new multiplayer modes and public matchmaking. Their design/dependencies must be
approved separately rather than being implied by a new facade or service room.

## 9. Agent ownership, cross-review and next implementation prompt

Technical, Gameplay and Experience specialists each audit their domain. Every
work package needs an independent peer; root integrates and alone serializes
engine/import/test/capture/export sessions. No specialist approves its own result.

| Work package | Lead | Independent review |
|---|---|---|
| Art direction, sprites, animation | Experience | Technical + Gameplay |
| Projectile form, AoE, element grammar | Gameplay | Experience + Technical |
| Map, height, cutaways, interiors, Garden | Experience | Gameplay + Technical |
| Movement, camera, protection, trails | Gameplay | Experience + Technical |
| Characters, ancestries, balance | Gameplay | Experience |
| Rivals, progression, practice | Gameplay | Experience + Technical |
| Menus, first-run, learning, accessibility, audio | Experience | Gameplay + Technical |
| Rendering, CPU, memory, asset pipeline | Technical | Experience + Gameplay |
| Room/save/network architecture | Technical | Gameplay |
| Launcher, package, recovery, QA, cleanup, docs | Technical + Root | Experience + Gameplay |

For each subtask, the implementation owner must record: current evidence and
source path; the reference technique and transfer limit; intended player benefit;
smallest coherent change; dependencies and version impact; deterministic/human/
performance acceptance; independent reviewer findings; and rollback route.

> Continue from the qualified delivery identified by current-delivery.json. Read
> this proposed design, SPECIFICATION.md, HEX-RESUME.md and the single queue.
> Start Stage A and the smallest integrated Stage B pilot. Assign bounded
> implementation owners and separate reviewers using the coverage table. Split
> animation, combat footprint, architecture/visibility and first-run work into
> explicit subpackages; share contracts before parallel edits. Preserve dirty
> user work and qualified fallbacks. Use the desktop launcher for every game
> session. Root serializes engine work. Reject changes that obscure mechanics,
> exceed measured budgets or cannot demonstrate a player benefit. Update the
> single queue and evidence after each stable checkpoint. Check credits at stage
> boundaries and stop with a coherent checkpoint before 20,000 credits remain.

Independent design cross-review findings are recorded below.
This prompt describes future implementation; no game
changes or fresh performance claims are made by this planning pass.

### Completed independent design review

Gameplay (`audit_gameplay_next`), Experience (`audit_experience_next`) and Technical
(`checkpoint_audit`) each wrote a source-grounded draft, reviewed both other
drafts, and reviewed the integrated plan. Root reconciled their findings. All
three reported no remaining design blocker after corrections. This is review of
the proposal, not acceptance of future implementation.

| Cross-review finding | Incorporated resolution |
|---|---|
| Inconsistent element/height references in preliminary material | Keep Water/Fire/Air/Earth/Light/Dark; Ice/Charge are subordinate. Resolve nominal 68 versus template 76 using the approved opaque silhouette; no implicit practice-wall exception |
| Smoothness confused with interpolation | Complete missing pose coverage; preserve authoritative action clocks and reset custom history at discontinuities |
| Circular/lobbed art implying extra mechanics | Core/halo/ground separation, cosmetic lift, exact planar/avoidance policy and offensive Mantle envelope |
| Shared pool proposal underspecified | Integer post-mitigation allocation, zero-loss semantics, same-pulse cover snapshot, finite remainder and crowd/body-shielding review |
| Cutaway and doorway information/ownership risks | Preserve self-only redraw, visibility restrictions and live same-world doorway behavior; scene-transfer guards apply only to transfers |
| Sprite budget infeasible under naive full libraries | Explicit 48 MiB example and 64 MiB character-envelope rejection test before roster production |
| Source profiler mistaken for packaged benchmark | Separate source observer calibration from packaged/presented-frame qualification |
| Existing audio capability overstated | Preserve current bounded cue model; new music/ambience channels remain proposed |

The [reviewed specialist inputs](overhaul-design-evidence-20261015/README.md) are
preserved as exact-byte historical design evidence for the Linux handoff. This
consolidated document is the durable proposal; the single queue remains the only
active task ledger. The supporting drafts are not additional implementation queues.

## Sources and transfer limits

- **R1 — Riot, Clarity in League:** https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/ — accurate effects, hierarchy and recognition. No claim that H.E.X.'s exact effects are validated.
- **R2 — Nintendo, Link's Awakening graphic direction:** https://www.nintendo.com/de-de/News/2019/Oktober/Grafikdirektor-Yoshiki-Haruhana-enthullt-was-hinter-dem-uberarbeiteten-Grafikstil-von-The-Legend-of-Zelda-Link-s-Awakening-steckt--1656228.html — miniature scale, balanced detail and authored interiors. Not a sprite-pipeline or performance prescription.
- **R3 — Noita developer description:** https://www.noitagame.com/ — consistent material interaction and spell experimentation. H.E.X. retains bounded hex simulation rather than copying pixel physics.
- **R4 — Paradox, Magicka:** https://www.paradoxinteractive.com/games/magicka/about — elemental combination premise. Not proof that each H.E.X. subset has a distinct niche.
- **R5 — Nintendo, Oracle of Seasons:** https://www.nintendo.com/en-gb/Games/Game-Boy-Color/The-Legend-of-Zelda-Oracle-of-Seasons-266263.html — environmental changes can make route solutions understandable. Proposed H.E.X. examples need their own tests.
- **R6 — EA, Apex beginner guide:** https://help.ea.com/en/articles/apex-legends/how-to-play/ — useful movement choices and cover displacement. Not evidence for specific H.E.X. acceleration or cancellation values.
- **R7 — Nintendo, Super Smash Bros. Melee:** https://www.nintendo.com/en-gb/Games/Nintendo-GameCube/Super-Smash-Bros-Melee-268951.html — identifies the requested reference game only. This overview does not substantiate advanced movement techniques; specific transfers require more precise primary evidence.
- **R8 — Microsoft, Xbox Accessibility Guideline 114:** https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/114 — contextual help and consistent controls with established-game examples. Accessibility is verified with users as well as checks.
- **R9 — Capcom, Mega Man 11:** https://news.capcomusa.com/lets/browse/ready-mega-man-11-is-out-now — defeat a boss and obtain its weapon. H.E.X.'s progression pacing remains its own design.
- **R10 — Capcom, Street Fighter 6 Practice manual:** https://game.capcom.com/manual/SF6/en/ps5/page/6/3 — optional practice tools and learning. H.E.X. reuses its Range rather than duplicating the reference UI.
- **R11 — Riot, The Tech Behind Swarm:** https://www.riotgames.com/en/news/the-tech-behind-swarm — representative profiling and mode-specific simplification. No automatic migration of Swarm algorithms or performance claims.
- **R12 — Dodge Roll / Devolver, Enter the Gungeon:** https://store.steampowered.com/app/311690/Enter_the_Gungeon/ — movement, dodge rolls, cover and distinct weapon behavior in bullet-hell rooms. No transfer of exact counts or timings.
- **R13 — Godot, General optimization:** https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html — measure limiting work, spikes and loading before selecting an optimization.
- **R14 — Godot, GPU optimization:** https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html — batching, transparency and draw-cost tradeoffs; renderer-specific results still need measurement.

Sources were checked for this design audit where reachable. Specialist review
used official developer/publisher accounts and engine documentation. The Capcom
Practice page returned 403 on direct fetch; its official indexed text explicitly
describes tutorials, character guides and customizable/simple training settings.
Reference links support the stated technique only; they are not endorsements of
this game. No reference assets are copied into the project.

# H.E.X. current design contract

Status: current authority, amended 2026-09-21; replaces the historical production specification.

## H.E.X. smaller-hex amendment — September 21

The public game name is **H.E.X.**, repository `generalgroovy/hex`. ASCII
filenames (`hex.cmd`, `hex.exe`, `HEX-*.zip`), the Flux resource and the existing
Windows profile directory remain compatible. The original FLUX checkout and
previous verified packages are preserved.

Hexes are now **48 px face-to-face**, 25% narrower than the previous 64 px grid.
The Wellspring bounds, obstacles, character sizes/hurtboxes, common 18 px wall
clearance, movement costs and world-space spell radii do not change. The finer
lattice has 2,766 eligible whole cells inside the existing 4,096-cell cap.
Radius still selects cells; each selected hex is fully affected. Finite paid
material is distributed across that selection, never multiplied per cell.

Protocol **55** rejects peers/replays with the old geometry. SessionSnapshot21,
HexWorldSnapshot3, chemistry3 and envelope1 remain unchanged. The existing
always-on 360-degree/720-unit character-centered visibility policy is retained.
The finer topology requires fresh functional, visual and networking checks;
previous timing receipts are not evidence of performance for this build.
Fire/Steam currently scale pressure from material per selected cell. A finer
selection may spread the same paid budget thinner: unchanged coefficients do
not imply identical per-actor damage. Preserve this rule in this geometry-only
slice; measure density-normalized balance separately before further expansion.

Historical FLUX baseline `p53-cb264f9358a4` (not verification of subsequent HEX source): chemistry works on eligible ground throughout Wellspring, without a dummy. Final Full passed **152 suites /775,657 assertions**, zero failures/stderr, import, asset audit and120Hz configured boot. Protocol53 / legacy snapshot20 / HexWorldSnapshot3 / chemistry snapshot3 / world envelope1. Native review passed7 frames. Production localhost lifecycle: **FAILED**. This is not a release or120Hz capacity claim.

## HEX integration amendment — September 20

The unified sight correction supersedes Full/cone modes: every observer has
360-degree character-centered sight with a fixed 720 ground-unit range under
the existing 55-degree projection. Aim and camera zoom do not change eligibility.
Opaque authored buildings and active solid hex cover block other characters,
their names, health, speech and attached feedback. Ordinary low cover remains
non-opaque. Transparent Steam and the first-four reaction policy remain intact.
The living local character, or followed living spectator character, supplies
the viewpoint. Missing or dead viewpoints fail closed. Rendering and visibility
use the same interpolated ground positions, including around cover edges.

Legacy Full/cone, angle and range preferences migrate to Relative/360/720;
other settings, controls and custom weaves are preserved. F8/F9/F10 no longer
change sight. Saved binding metadata remains compatible. The shared visibility
predicate also gates contact feedback; it grants no additional combat authority.
This is presentation visibility, not network packet redaction: supported
same-build snapshots still carry the world state. No wire or simulation change
is part of this correction. Human sight/readability acceptance remains pending.

H.E.X. is the game name; `hex` is the repository name, explicitly authorized by the user.
Flux remains the paid resource; internal identifiers and the existing Windows
`Godot/app_userdata/FLUX 2` profile location remain compatible. Renaming does not
rebalance gameplay or promote the selected historical checkpoint.

The HEX contact-feedback correction deliberately advances protocol to54 and
SessionSnapshot to21. HexWorldSnapshot3, chemistry schema3 and world envelope1
remain. New event kind27 carries exact clash position, two spell identities and
their remaining strengths within the existing bounded row/queue budget. Earlier
same-version event layouts remain unchanged. Older peers are rejected by version
and same-build checks; no profile or loadout migration is introduced.
Product-flow and Conflagration diagnostic events remain off-wire because their
current authority and knockout outcomes are already snapshotted. Event-pressure
measurements distinguish encoder omissions, queue trims and envelope inclusion;
none alone proves remote delivery.

Snapshot optimization must preserve exact canonical bytes, full malformed-input
validation, independent mutable ownership and presentation revision semantics.
A verified hash may be reused only within the same synchronous operation after
its underlying authority is validated; no stale mutable-authority cache is allowed.

Spell Loom shows twelve named positions and effective saved keyboard bindings.
Empty assignment, unavailable spell and unbound key/modifier are distinct states.
Contextual station prompts must show an unbound action honestly. Custom weaves,
all eight elements and all four delivery families remain available.

Steam's transparent whole-cell vents and expiry cues read authoritative phase;
normal and reduced effects cover the same selected cells. Recovered handoff PNGs
are reference material, not live atlases. No balance coefficients change in this
integration. Shared bodies remain templates pending human animation acceptance.
Existing Wellspring routes receive bounded activity labels and wayfinding only.

## Accepted whole hexes and unified Wellspring milestone — September 19

The user playtested and approved the whole-hex approach on September 19. This
acceptance supersedes the prior coverage-approval pause. It does not approve
unrelated regressions, performance, networking or unreleased artwork. Preserve
the accepted exact-impact, positive-area selection and whole-cell membership
rules below throughout this migration; no second approval of that approach is
required.

The next target is one authoritative chemistry system in normal shared
Wellspring, with Water/Earth/Fire/Air through Bolt/Heavy/Rapid/Spray and all ten
symmetric pairs including distinct-source mirrors. The standalone court is a
training configuration, not a second production resolver. Preserve later-four
Ice/Charge/Light/Dark behavior and saved choices through explicit parity gates;
do not cut over by disabling spells or secretly co-running old chemistry.

Stable recipes: Flood316, Mud303, Steam310, Mistcurrent317, Rampart/fortify301,
Magma302, Dustfront304, Conflagration309, Firestorm311 and Vortex322. Each needs
real paid-input gameplay, finite selected-cell allocations, phases, ownership,
height/obstruction/stacking rules, expiry and practical counterplay. Steam is
transparent scalding exposure with exit decay, never concealment. Structures
must have true six-face collision and stable wall normals. Directional movement
and spread must conserve quantity and never refresh lifetime automatically.

Prepare schemas before parallel edits. The existing single queue owns U0–U5:
baseline/contracts, shared Water/Fire authority, Earth/structures, Air/products,
practice and synchronized lifecycle, then integrated verification/performance.
Preserve eight-player limits, 120 Hz authority, profiles, original assets,
unfinished S4 and fallback builds. No unrelated melee or character art expansion.
Normal Wellspring cutover requires later-element parity, safe campus eligibility,
authoritative snapshots/late join/reset, and no double resolution. Keep the solo
refusal until the new network path actually passes; version protocol/schema when
semantics require. Do not call catalog/schema preparation gameplay completion.

Full failures must be reproduced and relevant stale contracts repaired without
skipping or weakening tests. A red Full gate blocks release-ready claims.
Continue between bounded completed slices; pause only for a concrete unresolved
authority/design blocker or the final unified-milestone human playtest. Latest
request is preserved in docs/evidence/unified-hex-20260919/user-request.txt.

Implementation status: normal Wellspring now uses HexChemistryWorld, protocol52,
legacy snapshot20, HexWorldSnapshot2 and WorldSnapshotEnvelope1. The sixteen
first-four spells and ten pairs are implemented through paid input; current
verification and limits belong to docs/HEX-COURT-CHECKPOINT.md. This records
implementation, not performance, release or human acceptance of the milestone.

Lethal Fire/Steam pressure and Conflagration must emit the standard champion
knockout lifecycle event once, preserving scoring and respawn. Strongest pressure
wins; an equal Fire/Steam tie prefers Fire, equal Fire sources use stable source
ID (cast fallback), and equal Steam products use stable product ID. Training
targets use their own lifecycle. Snapshot actor validation admits their authored
zero movement ratio while retaining positive champion ratios and all bounds.

### Unified ownership and migration schema

One world chemistry object owns cast records, pending reservations, source-to-cast
index, cell allocations, product records, structures, exposure/flow remainders,
IDs, clock and reset epoch. Map configuration supplies eligible whole cells throughout Wellspring, never a
second resolver. The September 20 correction supersedes Crucible-only eligibility
and the old spawn/station safe-space exclusions. No dummy is required; normal
actor height, spawn protection and combat eligibility still apply. Immutable
wall clearance and whole-cell map bounds remain. Topology is bounded at4096
cells separately from unchanged64 cast/32 product limits and600 material per
paid cast. Snapshot schemas advance to3/protocol53 for sparse cell allocation
indices; legacy snapshot20/world envelope1 remain. Preserve source ledgers
with immutable initial strength and mutable remaining strength/quantities.
Product records retain original source IDs, owner/team, exact contact/aim,
nonnegative integer cell allocations (selected zero-allocation cells remain covered),
original quantity, intensity, lifecycle ticks
and finite movement/suppression/structure state. Rendering reads those records.

The snapshot schema must encode all authority needed to resume the same next
step: pending reservations, ledgers, allocations, contact/pulse state, exposure,
integer carries, structure faces/health, ID counters and reset epoch. Decode
into a temporary object, reject malformed/oversized/inconsistent state without
mutating the live world, rebuild derived cell indices, and validate conservation.
Display caches are excluded. A full round trip and identical subsequent commands
must preserve canonical hashes before the solo refusal can be removed.

Geometry phases change coverage only at authored formation or explicit movement/
reshape transitions. A translating front conserves the original total quantity,
retains expiry and stops at obstacles and the eligible-domain boundary. A move
that would leave that domain is refused as a whole; it cannot shed or clone stock.
Contact trigger ordering remains explicit: instantaneous Spray at phase zero,
then ordered continuous flight contacts with walls winning ties and later events
revalidated; same-cell deposited ingredients use stable source ordering. A cast
never reacts with itself. Current finite field-resistance rules remain separate
from direct projectile damage and from harmless ingredients.

The following are required gameplay contracts, not completion claims. Existing
verified Flood/Steam/Conflagration numeric timing/force/damage/modifier constants
remain the parity reference; new primitive values must be explicit, bounded and
tested before enabling them. Every row uses symmetric recipe identity, distinct
paid source budgets, whole selected cells, visible formation/active/decay,
independent ownership/expiry, no automatic visual-neighbor refresh, obstruction
and per-effect/pulse actor deduplication. Each applicable trigger needs its own
paid-input test; catalog presence alone is insufficient.

| Pair / stable ID | Observable purpose and use | Height, overlap and counterplay |
| --- | --- | --- |
| Water+Water / flood316 | Directional grounded flow, bounded displacement used to steer a route | Common wall clearance; airborne escape; no repeated-cell force multiplication |
| Water+Earth / mud303 | Viscous acceleration/braking alters route choice | Ground only; no immobilization or persistent penalty after exit |
| Water+Fire / steam310 | Transparent scalding volume with capped exposure ramp and explicit exit decay | Preserve height48px, heat/cool finite modifiers; visible actors/projectiles; escape/cool |
| Water+Air / mistcurrent317 | Wet directional steering corridor with finite suppression stock | No Steam damage or concealment; steering/cover/exit counterplay |
| Earth+Earth / fortify301 | Temporary stronger six-face pillar arrangement; cover and wall movement | Stable face normals; safe creation/escape, break/go around/jump, expiry cleanup |
| Earth+Fire / magma302 | Strong grounded damage with bounded slow and readable cooling | Airborne escape; overlapping cells do not multiply a pulse; slow ends on exit |
| Earth+Air / dustfront304 | Directional debris front with bounded lateral positioning pressure | Transparent threats; lateral escape/cover; no indefinite trapping |
| Fire+Fire / conflagration309 | Concentrated high-pressure ground burn with warning and commitment | Ground eligibility; leave/jump before active pressure; finite expiry |
| Fire+Air / firestorm311 | Directional advancing burning front cuts routes | Obstacle-aware finite movement; no cloned payload/lifetime refresh; cross/escape |
| Air+Air / vortex322 | Rotational redirection and movement slingshot | Bounded force and projectile speed; no permanent trap/stun lock; center/exit |

## Whole-hex area correction — September 19 (current)

This correction explicitly supersedes the clipped-circle/sector coverage rule in
S1–S3 below. Exact continuous impact coordinates remain unchanged. Disk/sector
geometry selects eligible court cells once at formation; positive-area overlap
selects a cell, edge/vertex tangency alone does not. A zero-radius point selects
its canonical containing cell. Every selected live cell is covered across its
whole applicable layer. The selected finite allocation map is the authority for
exposure, chemistry, field interception, previews and rendering; the selection
radius is not a second boundary. No nearest-N truncation is permitted.

Grounded exposure follows the canonical foot cell and swept movement, with
existing height/protection/landing gates and per-effect/pulse deduplication.
Continuous direct projectile/actor collisions and cover remain continuous.
Finite paid material is deterministically allocated, never cloned per cell;
remaining strength, ownership, independent expiry and product rules are retained.
Compatible visuals may hide internal edges without joining budgets or lifetimes.
Normal/reduced presentation must show the same selected area, including holes.

Historical scope of the original correction: the September 19 area-only slice
covered the solo Water/Fire/Steam/Flood/Conflagration adapter. At that point it
left ordinary production chemistry and unsupported hex networking unchanged and
authorized no strengths, costs, durations, characters, controls or melee changes.
The unified Wellspring milestone above supersedes that old runtime boundary; the
whole-hex mechanics in this section remain current. S4 was existing unfinished
work and S5/S6 remained staged. Area expansion and dense cost had to be reported,
not silently compensated by balance changes. Its acceptance required geometry
edge cases, authority/render/preview identity, swept/height/protection, finite
ledger/expiry/reactions, native before/after and matched field profiling, Focused
and frozen-source Full checks, then a human playtest pause.

## Historical S1–S6 instruction (clipped coverage superseded above)

The new instruction authorizes continuation beyond H2's pause without implying
human acceptance. The preserved baseline is p50-32f72538c682: solo Water/Fire/Steam
with whole selected hex coverage, immutable clash strength, unchanged dominant
survivors, one product per cast, temporary eight-spell court kit and preceding
Q/mouse controls. These are current implementation facts until each slice passes.

The target supersedes whole-cell radial effects, nearest-N coverage, displaced
impact origins, forced neighboring-cell Water expansion, unchanged survivor
strength, and single-product accounting for successive paid clash portions.
Initial family strengths stay Rapid1/Spray3/Bolt5/Heavy15; remaining strength is
separate mutable combat state. Eligible contacts consume min(a,b) from both,
emit one catalogued reaction at exhaustion, and partition finite paid matter by
consumed strength. Unsupported products must be explicit, never fake Steam.

One shared presentation palette owns element/reaction colors and shape/phase
roles. Water is saturated blue, Earth ochre, Fire orange-red, Air mint, Ice pale
cyan, Charge yellow, Light ivory/gold and Dark violet. Steam uses blue-gray curls
with warm scalding accents. Damage, previews and artwork use the same continuous
analytic footprint; hex polygons only partition storage/display. Radial origins
are actual swept contact points or range endpoints. Boundary cells are clipped,
not expanded to their full hex. Spray retains its actual clipped release sector.

S1 acceptance: off-center/edge/vertex/tiny/negative-coordinate disks, obstacle and
actor contact origins, overlapping footprints and no exposure beyond the disk;
actual normal/reduced native phases and canonical palette. Existing finite
ledger/lifetimes remain until S2 replaces their strength accounting. Shared body
templates, 58/63/68px standing targets,620/660/700 Stamina,17/18/19px hurt radii,
18px clearance, continuous movement/aim and120Hz authority remain preserved.

Next integrated target slices: S2 ordered remaining-strength subtraction and
finite medium catalogued reactions; S3 monotonic strength visuals and once-only
finite field interception; S4 canonical twelve-slot starters and reversible Q→B,
dedicated mouse-melee migration; S5 paid Stamina punch/kick with bounded phases,
buffer and wall-aware knockback; S6 atomic paid Flux material-only infusion,
first confirmed enemy contact hex before knockback and one payload per attack.
All slots remain configurable and custom saved weaves must survive switching.

S2 implemented in the solo court: actual source IDs own initial/remaining strength
and finite600 matter. Each contact consumes min strengths, partitions cumulative
integer material portions, and emits exactly one supported Steam310, Flood316 or
Conflagration309. Successive products cannot clone a paid payload. Walls win exact
ties; all later projectile/actor events revalidate exhausted sources and live
targets. Instant Spray is phase zero; released pulses survive their owner's same-
phase defeat. This adapter requires one flight per source and rejects unsupported
unpartitioned fragments. Production ElementChemistrySystem remains a legacy path.
The trial medium is64px radius,24 formation/360 active/60 decay ticks. Intensity
is min(1500,100*consumed_strength); quantity is the two newly consumed portions.
Flood moves grounded eligible feet at40000*intensity/1000 units/second using18px
wall clearance; Conflagration pulses8000*intensity/1000 per600ms. Both effects and
Steam are clipped to stored court cells as well as their analytic disk. A fresh
Fire or Water source may modify Steam once each, consuming only its current live
budget: heat adds50*remaining strength capped1500 and halves remaining lifetime;
cool subtracts min(current intensity/2,50*remaining strength), never broadens or
refreshes. Radial terminal radius is authored radius*sqrt(remaining/initial),
rounded once. Spray geometry stays authored; damage and material scale separately.
Capacity reserves one potential product per live source before payment; no paid
product is silently dropped. Expiry releases capacity before the next admission.
Uninfused physical attacks use Stamina (superseding the universal attack-Flux
rule for those two actions only); spells and elemental infusions still pay Flux.

Root owns shared schemas and every serialized engine run. Focused checks during
development, Full on frozen integrated candidates, exact logs and actual captures
are required. Solo hex mode remains explicitly unnetworked; eight-player production
lobby stays bounded. Historical W4 failure is not cleared by art or headless boot.
Preserve profiles, original assets, dirty work and selected P48. No incidental
publication/commit/push/installer or checkpoint promotion. Continue S1–S6 until
the integrated playtest checkpoint or a material unresolved design decision.
The older contracts below remain historical wherever this amendment conflicts.

## Hex court amendment — September 15

The current instruction reprioritizes the next milestone to H0–H2: one isolated,
playable hex chemistry court. Existing Wellspring chemistry remains the preserved
ordinary path until replacement gates pass. A court world must use exactly one
chemistry authority: its hex state, with legacy deposits/reactions disabled there.
Character template acceptance and remaining B2 work stay open, but no longer block
this isolated candidate. Larger production fields/campus and live hex networking
still require measured correctness/performance and migration gates.

Current versus target: ordinary source uses continuous collision, circular/sector
effects and cast-owned deposits; MaterialGrid and square admission buckets are
not hex terrain. H1 adds one canonical geometry oracle and layered court. H2 adds
paid Water/Fire/Steam and simple interpolated projectiles. H3 adds true six-face
Earth columns; H4 reconciles the ten first-four pairs; H5 expands the campus and
validates multiplayer/performance. Stop after H2 for human acceptance. No artwork,
selected portable, user profile, body dimensions or original asset is replaced.

Superseded only within this staged migration: template-first priority; circular
environmental coverage and blanket doubled persistence as immediate goals; the
absolute no-result-chemistry rule for the two expressly authored Steam modifiers
below. Continuous actor/projectile collisions, eight-direction keyboard input,
analog aim, paid motion, 120 Hz authority and eight-player live lobby remain.
Strength remains Rapid1 / Spray3 / Bolt5 / Heavy15 across all eight elements.
Strength is not quantity, damage, radius or visual brightness. Rapid has no trail.
Historical adapter restriction, superseded by the unified milestone above: Court
Fire replaced harmless Fire ground ingredients with a finite ignition/active/
cooling hazard that retained paid reaction provenance, while Water was harmless
setup ground. Its Court-only restriction no longer describes ordinary Wellspring;
current active Fire uses the same authored finite hazard there as well.

H1 geometry: pointy-top axial(q,r), cube distance/neighbor operations; integer
world units at 1000 per pixel. Opposite-face width48px, half-width24000,
half-height27712, row pitch41568. Centers=(48000q+24000r,41568r); local vertices
(0,-27712),(24000,-13856),(24000,13856),(0,27712),(-24000,13856),(-24000,-13856).
This fixed rational approximation tiles exactly; it is not a final art scale
acceptance. Screen projection remains a separate presenter concern. Closed-cell
edge/vertex ownership chooses lexicographically smallest(q,r). Swept, radius-aware
queries include all contacts, deduplicate cells, and cannot infer traversal from
endpoints alone. Local candidate traversal and an independent exhaustive oracle
must agree for tangency, negative coordinates, high speed and reversed paths.

H1/H2 authoritative responsibilities: one record per cell separates terrain,
elevation/structural occupancy, finite ground contributions, thermal contributions
and atmosphere references. Cast ledger owns immutable provenance/strength/payment
and the single finite ingredient budget; cells allocate that budget, never mint it.
Reaction ledger accounts one multi-cell product footprint and shared exposure,
not independently reacting cell entities. Wet ground may coexist with atmosphere
and unrelated structures. Neighbors may merge visually without merging ownership,
expiry or paid budgets. Renderer reads dirty local state, draws outer footprints
and meaningful boundaries, and does not mutate authority or hide actors/projectiles.

Provisional H2 numerical budgets (candidate, validate before broader rollout):
finite court of radius6 (127 cells), at most64 retained cast ledgers and32 products;
no production cap increases. Reserve complete cast/contribution/product capacity
before ordinary Flux payment, reject without spend and never evict paid state.
Each accepted cast carries600 matter units; authored coverage ceilings are Rapid1,
Bolt3, Spray5, Heavy7 cells, with delivery geometry restricting the footprint.
More cells divide the same quantity. Water lasts at most720 ticks, Fire480,
Steam600; there is no blanket doubling. Fire has a24-tick ignition warning and
60-tick harmless cooling tail. No automatic neighbor ignition. Ground exposure
uses the grounded foot path, once per actor/pulse; no hurt-radius cell stacking.
Steam height eligibility is explicit and capped; airborne immunity is not guessed
from artwork. Damage/exposure use a single actor accumulator with overlap maximum,
bounded ramp and exit decay, plus existing invulnerability rules.

Eligible distinct equal-strength Water/Fire casts consume only accounted matched
quantities into one Steam footprint; unmatched ingredients remain. A fresh
equal-strength Fire cast can heat a product once, increasing intensity while
shortening remaining duration. A fresh equal-strength Water cast can cool/broaden
once, lowering intensity with a bounded footprint and no expiry extension.
These are authored product modifiers, not unrestricted recursive chemistry.
Original reactants cannot modify their own result; each modifier has one paid
budget, one application, bounded extent and no free ingredients or infinite refresh.
Exact pulse/ramp/modifier numbers must be recorded with executable H2 content and
source-derived help before H2 acceptance.

H2 executable choices: each original cast can form at most one product. A partial
match consumes twice the per-cell minimum and leaves unmatched ground until its
original expiry; that leftover cannot form a second product. Bolt selects up to3
nearest hexes intersecting its34px terminal capsule; Heavy up to7 from64px. Rapid
selects the single canonical terminal owner. Spray selects up to5 hex centers
inside its actual compiled, cover-shortened release sector, nearest the terminal;
whole selected hexes become the persistent coverage. These are coverage ceilings,
not a promise that every edge-of-court cast fills the ceiling. A paid miss expires
its unused budget. No projectile or actor is moved to a hex center.

Fire exposure requires foot height0. Steam includes foot heights0..48px. A landing
tick or descent through the Steam ceiling queries its eligible endpoint only;
ordinary eligible movement queries the full continuous foot segment. Combat
intangibility prevents pressure and decays exposure. Grounded Fire has at most
4 damage per30-tick pulse scaled by its local matter/600; overlapping contributions
take a maximum. Steam increases exposure once per eligible tick to240 (2seconds)
and decays2 per tick outside, above height, or intangible (up to1second to clear).
Re-entry retains any exposure that has not decayed. Steam base pulse ramps2..8,
scaled by local product matter/400 and capped at8 before its intensity multiplier;
absolute cap12. Fire and Steam together apply the strongest single actor pulse,
never a sum over cells/products. All damage uses the existing resource system.

One fresh Fire modifier adds its paid600 matter, multiplies intensity by1.5 with
a1500/1000 ceiling, and halves remaining life (minimum1tick). One fresh Water adds
its paid600, halves intensity (floor250/1000), adds at most6 adjacent cells to the
existing footprint with a19-cell absolute ceiling, and never extends expiry.
Both orders end at750/1000 intensity when both modifiers are applied; heating a
cooled cloud remains less intense than heating an uncooled cloud. Each modifier
consumes its entire budget once, even on partial overlap. New product quantity
is redistributed exactly across its footprint. Source IDs never reuse spent
parents. Total duration stays within the original600 ticks; no product refresh.

Migration gates: enter the court explicitly from safe Wellspring, offer quick
reset/return, preserve character/loadout/profile, and refuse unsynchronized court
entry in live sessions. H1/H2 are disclosed solo candidates; H5 must add complete
late-join state, prediction/deltas and matched eight-player proof before live use.
Never run old and new chemistry over the same cast. Keep stable element/spell IDs.
Unavailable court elements must be refused before payment with clear help.

Validation: root alone serializes engine wrappers and isolated profiles. H1 needs
geometry oracle/state conservation checks and a playable scale comparison. H2
needs paid-command replay, refusal/conservation/expiry/strength/self-reaction/
exposure/modifier tests, actual before/after native and reduced-effects captures,
fresh final identity/Full/120Hzboot, matched requested/admitted work and timing.
Separate simulation, rendered timings, snapshot/queue, physical multiplayer,
packaging and human acceptance. Historical host p95 10.592–11.085ms still fails
the8.333ms budget. Do not raise caps, shed demand or weaken tests to clear it.
Rollback is exit to the preserved ordinary Wellspring or use the selected P48
package; preserve starting source and new receipts with referenced logs. No
incidental commit/push/publication/installer/checkpoint promotion.

## Four-delivery overhaul — current instruction

September14 first playable milestone: a72second solo Wellspring interception
encounter, using ordinary paid commands and the existing Small shared body.
B2a implements unequal Spray/projectile contact at instantaneous release, ordered
by Spray cast ID then projectile entity ID before projectile travel or actor
Spray damage. Exact closed sector-circle overlap plus zero-width center-ray
visibility against current cover decides eligibility. Stronger removes the
entire weaker flight cast; a negated Spray cannot later damage, damage cover or
deposit. Existing unequal deposited ingredients remain intact. One material slot
is reserved before payment and retained through startup and deferred resolution;
a surviving pulse leaves one strength3 ingredient with one cast ID and budget.
Locked ground targets shorten reach within its authored maximum; movement during
startup recomputes release aim, and the wire cue carries actual radial reach.
Integer distance uses a ceiling envelope so an oblique selected point is included.
Protocol50/snapshot20 describe this candidate. Direct equal contacts, simultaneous
Spray equality and projectile-to-projectile sweeps remain B2 follow-ups. Actor
Spray's existing radius/slack cover behavior is distinct from interception's
exact center-ray policy; later broken cover does not rerun the earlier phase.
The encounter has retry/return buttons, finite Water/Earth Mud experimentation,
and a real opponent using Rapid, Bolt and Heavy. Human feel/art acceptance,
rendered120FPS and physical two-PC play remain separate gates.

September14 area/scaling amendment: preserve the four deliveries and strengths,
Spray ingredient reservation/interception transaction, one chemistry payload,
movement rules and eight-player live lobby. Establish the measured supported load
envelope on the target hardware before raising capacity. The single queue owns
baseline/limits, ordered contact, measured optimizations, then larger footprints
and at least doubled intended persistence. Appropriate circular terminal-impact
and reaction radii start near1.4x as a measured tuning experiment, never a global
scale. Steam volume, Magma escape space, Heavy warning/impact, short-range Spray,
directional width/length, Rampart clearance and narrow trails require separate
decisions. Rapid remains trail-free; hurtboxes/common wall clearance stay fixed.
Collision, snapshots/bounds, identity, material rendering and source-derived
guides must agree on actual occupied geometry, without fake coverage or separate
range circles. Do not increase all offensive properties together.

Required scaling matrix: normal8; sustained legal Rapid/Spray with ingredients;
dense enlarged-area/interception bursts; boundary/corridor/cluster adversaries;
experimental4x/16x contact demand; isolated32actors only after all actor limits
are audited. Report requested/admitted/active/processed work, not just timing of
refusals. Measure tick/frame p50/p95/p99/stalls/deadline misses, input-to-visible
latency, snapshot bytes/packets/cost, queue/backpressure/recovery, memory/allocation
and pair/exact-query/index costs with matched settings/seeds/hardware and soak.
Any unmeasured dimension remains explicit. Preserve exact oracles, whole-bounds
spatial coverage and canonical ordering; measure dense fallback and relevant
effect filtering; cache only valid invariants. No offscreen authority decimation,
unbounded queues, hidden outcome loss, headline-only capacity or universal120FPS
claim. Full-system evidence is required before raising production caps.

The September13 four-delivery request supersedes the seven-family expansion,
Steam concealment and five-second elemental/reaction ceiling below. Historical
paragraphs describe prior executable behavior, not permission to retain those
rules in the completed overhaul. Source is implemented incrementally; the single
queue records what has actually passed. Overnight P48 remains the selected
playable fallback until a separately identified candidate passes its gates.

Only baseline Bolt, Heavy, Rapid and Spray will be selectable/admissible across
all eight elements:32 spells, twelve positions (plain/Ctrl/Alt1–4). Wave/internal
burst, Beam, standalone Field and Vector Lance are disabled, with stable IDs,
reusable implementation and original assets retained. Reaction-created areas
remain gameplay. Existing saved choices must remain recoverable and visibly
disabled; no silent replacement attack. Preserve bindings and a pre-migration
profile before any migration write. Authoritative admission rejects disabled IDs
without spending Flux, starting cooldown or erasing paid matter.

Display/development order is Water, Earth, Fire, Air, Ice, Charge, Light, Dark.
Internal wind and all element/spell wire IDs remain stable. Display order never
derives serialization identity. Guides must describe the current executable
candidate and distinguish pending changes from available behavior.

Delivery targets: Bolt precision/range/economical setup; Heavy slower telegraphed
area punishment with high cost/recovery; Rapid individually paid tracking pressure
with no flight trails and no future starts after release; Spray short broad
positioning pressure implemented as a bounded cone pulse. Balance practical
encounter-distance contact times, complete release-to-release intervals, damage,
area, range, commitment, Flux/time, reaction usefulness and counterplay. Flux is
the sole mana resource. Every delivery needs a useful role and disadvantage.

The numeric B substep authors and compiles reaction strength on all32 spells.
Numeric source validation was Full104/681530, zero failures/stderr,
p48-2781b0c576ef. The completed B1 source substep propagates strength through
projectile releases, optical children, trails and terminals; deposit admission
preserves same-cast consistency and pairing requires exact strength equality.
Unequal deposits remain intact. Protocol49/snapshot19 carry the additional state;
replays from earlier protocols are refused before stepping. This describes the
historical B1 boundary; B2a above adds unequal Spray contact. Final B1 candidate p49-5e49b41aac92 passed
fresh Full105/696784 with zero failures/stderr and isolated120Hz boot;32 native
interface frames preserved authority, with independent source/visual review.
The3132 frozen inputs and referenced logs are retained with the B1 handoff.
These B1 and numeric-only receipts are historical evidence of their own source.
User-selected cast-owned integer ladder (latest September13 correction):
Rapid1, Spray3, Bolt5, Heavy15. These values supersede both the proposed1/2
ladder and the user's preceding Rapid1/Spray2/Bolt3/Heavy5 message. Every element
uses the same four delivery values. Cross-family equality is no longer a live
catalogue acceptance requirement: different families have different strengths;
equal-strength setup uses distinct casts of the same family across elements.
The resolver compares actual integer values, never family names or a tolerance.
Exact
equality plus normal eligibility permits one reaction; unequal projectile
strength negates the weaker before damage/deposit, stronger unchanged. No
absorption/subtraction, extra lifetime, rewards or budget refresh. Persistent
ingredients retain reaction strength and unequal ingredients do not react;
projectile dominance never deletes terrain/structures/deposits implicitly.
Reaction strength is separate from existing material strength, geometry, damage,
quantity, visual brightness and Flux. Fragments inherit it and share one spent
payload; no same-cast combination or recursive result chemistry. Spray needs one
bounded ordered interception query and one chemistry payload. Contact priority,
tie-breaking and projectile/deposit behavior must be explicit and tested in B.

Persistence slice C must at least double verified terminal/eligible trail and
sustained-active lifetimes using the authoritative duration table in this file.
Warnings, pulse damage/frequency, cast timing, control-lock/protection/airtime and
instant reactions are not doubled. Rapid remains trail-free. Maintain bounded
occupancy/interception, paid reservations and understandable capacity refusals;
no blanket cap increase, silent early paid-effect eviction or spend on refusal.

First complete the ten Water/Earth/Fire/Air pairs before later-element redesign.
Current(flow), Mud(ground braking), Steam(capped exposure-ramp scalding, no vision
denial), Mistcurrent(travelling screening lane), Rampart(breakable legal wall),
Magma(strong ground damage+substantial exposed slow), Dustfront(lateral pressure),
Furnace(timed heat pulses), Firestorm(predictable travelling flame lane) and
Gust(bounded displacement) are the target functions. Steam needs per-actor
deterministic exposure/ramp/exit decay and nonmultiplicative overlap; Magma needs
explicit nonstacking, protection/height/airborne escape and no lingering slow.
Leaving must remain effective; none grants a movement/protection budget reset.
These are intended changes until their individual queue slices pass.

Keep the nine batches of four unique pairs as bookkeeping only; first-four
priority overrides a batch crossing into later elements. Future Ice must model
ordinary slippery momentum/braking/steering separately from paid Slide; Charge
stored/conducted force, Light bounded information/protection, Dark concealment/
attrition remain preparation only. No dormant surface hook without a consumer.

Finish Small/Middle/Large slide entry, sustained glide, braking and exit across
eight travel directions with independent aim, then retained landing/jump/Float/
air-dodge/roll/wall/moving-cast work before named skins. Fixed scale/pivots,
size-only hurtboxes, shared clearance, natural gait, legal cast/movement timing
and finite protection remain authoritative. Particles cannot replace body poses.

The prior W4 failure remains explicit. Measure realistic eight-player sustained
four-delivery casting, compare matched workloads and preserve120Hz. Every slice
has one integration owner, isolated preferences, canonical import paths, fresh
targeted/full/snapshot/replay/network/visual evidence as applicable, and retained
rollback inputs. Package, physical two-PC, rendered performance, human acceptance
and release are separate. No publication, security changes or destructive cleanup.

Selected local checkpoint (2026-09-13): Overnight P48, build p48-111d911c27fa.
Fresh Full102/691,883,221 paid-gameplay frames plus52 interface frames,
frozen3122-input portable/PCK/raw boot and exact-export localhost passed.
Protocol48 requires full canonical production-source identity; snapshot18 and
preferences11 remain unchanged. Generated manifest status is provenance only;
docs/current-checkpoint.json owns local selection. Chemistry P3 remains intact.
W4 still fails: final real-map simulation p95 16.658/16.934ms versus8.333ms.
No simulation optimization was retained. Human/controller/two-PC, rendered
performance, installer and publication remain separate. The test wrapper now
checks all117 canonical class paths after import; evidence backups are excluded
from imports. See docs/OVERNIGHT-P48-CHECKPOINT.md for the settings incident and
the final playtest handoff. The new four-delivery request now resumes source work.

Overnight implementation amendment (2026-09-13): prioritize reliable input and
same-build multiplayer, measured 120 Hz progress, source-derived launch guidance,
and bounded route/body presentation improvements. The single active queue owns
ordering. One integrator schedules all Godot validation and promotion; freeze the
candidate before final checks. Preserve Chemistry P3 as the verified portable
until a separately named candidate passes applicable gates. Human/controller/
physical two-PC, rendered performance and installer acceptance remain separate.
This authorization permits continuing independent slices while taste or hardware
acceptance is pending; it does not authorize publication or weakening invariants.

Overnight input candidate contract: eight-player input admission remains bounded
to four queued records per remote peer and 28 total. Coalescing keeps the latest
continuous state and pending action edges, without adding simulation ticks.
Hosts poll between bounded catch-up steps and abort catch-up when that poll
replaces the world or ends hosting. Frame clamp loss and catch-up discard are
reported separately. Controller aim remains independent of travel when the stick
returns to neutral; real mouse motion returns control to the pointer. The default
D-pad addresses four spell positions with LB/RB layers for all twelve. Existing
custom or partial controller maps are preserved, including explicit empty maps.
Binding capture reserves fixed UI shortcuts. Fresh targeted evidence is recorded
in the active queue; physical controller feel and integrated presentation remain
pending until exercised.

Continuous-development amendment (2026-09-12): movement, map, spell and character
work is reopened after consolidation. Implement the bounded remappable Q input
slice first, then attribute the real-map chemistry hotspot before admitting more
runtime workload. Prepare layout, art and spell candidates independently; keep
template, performance and human acceptance gates explicit. This supersedes the
prior maintenance-only milestone and its fixed mirror-first sequencing. The
single implementation queue owns dependency order; delivered status remains in
docs/current-checkpoint.json.

Q / Roll-Air Dodge input contract (authorized, candidate until verified): while
airborne, a fresh Evade press with current meaningful movement intent requests
the existing paid directional air dodge. The same press with neutral intent
requests vertical fast-fall. Aim, facing, momentum and previous direction never
turn neutral airborne Evade into a dodge; screen-down remains a horizontal-plane
dodge direction. Sample movement intent at admission after cancellation,
controller deadzone/hysteresis and the chosen movement transform. Preserve the
existing remappable action, saved bindings, explicit unbinds and V's separate
wall/air-tech role. Fast-fall uses height/vertical velocity, never teleportation,
horizontal dodge impulse, new protection or a movement-budget reset. Explicit
Float exit uses the existing fast-fall transition: end held Float and its
protection immediately, retain its spent allowance, preserve horizontal coast/
ordinary steering and clamp downward velocity using existing fast-fall tuning.
Detach an active wallrun through its normal finite exit first. Existing Slide
fast-fall remains an alias. Fast-fall costs zero, adds no cooldown or protection,
and does not require an unspent air dodge; ordinary control/commitment gates apply.

The existing100ms newest-press buffer samples direction at admission, not press
time. Evade has priority over simultaneous Jump, Slide and Technique; combat then
uses its existing cast/transition policy. Admission precedes height integration:
a last-airborne-tick neutral Q fast-falls and lands normally, without a ground
roll. Buffered airborne Evade is discarded if its airborne/grounded context
changes before admission. A fresh press after landing uses grounded semantics.
Holding Q emits no repeated edge; interruption requires release/repress. Holding
Jump after Float cancellation cannot restore its consumed allowance. A later
fresh paid action still requires its own current eligibility and finite budget.
The router's existing0.25 movement deadzone and fixed-point quantization determine
neutral versus meaningful input; no new hysteresis or momentum threshold is
introduced. Other neutral movement rules are documented before any separate
behavior change. Consolidation remains the playable fallback.

Warm-style/trail amendment: the current cast-sheet art direction now applies to
the live shared body foundation, basic magic and terrain. Bodies are baked at
92% visual scale, without changing source bones, size-specific hurtboxes or
common wall clearance. Race-specific skins remain a separate production layer.
Bolt, Heavy and Wave can leave optional 20px-radius material trails lasting
0.8-1.5s; Rapid is too weak to leave trails and retains terminal matter only.
Trail + trail and same-cast combinations never react. A new terminal can
combine with a strictly older trail; sustained recipes receive 60% active time, while instant
windows, damage-per-pulse and baseline terminal recipes stay unchanged. Four
trails per owner / 32 globally share the existing 16/128 material cap. Paid
terminal reservations have priority; trail-role snapshot limits are enforced.
Each cast has one chemistry payload: a reaction spends all fragments of both
source casts and permanently zeros their still-flying material strength. Direct
projectile damage remains; prism splitting cannot replenish spent matter.
This uses the existing snapshot fields, plus a changed compiled-content fingerprint.
The user disregarded all historical percentage cutoffs on 2026-09-12.
Platform limits still apply; usage purchases/reset credits require permission.

M2b implemented (2026-09-12): Charge mirror wire331/internal overload is
Capacitor: stationary 200px centreline/30px radius,650ms formation,2000ms active,
450ms harmless decay. Both teams' ordinary ground walk/sprint target125%,
nonstacking with Frostway priority750; existing authored carry/speed caps remain.
Final500ms warns before one14px cast-direction displacement of grounded enemies
on the last active tick; at most one discharge per actor/tick, stable lowest
eligible reaction ID. No damage, stun or cast cancellation, no resource/protection/
airtime reset. Temporary cover collision uses ordinary18px clearance and overlap
escape. Trail-assisted active duration stays60%. Prediction captures required
team/health/protection and exact lane rows; intervening combat/cover changes still
reconcile from host authority. Current-checkpoint.json owns delivered status.

Mirror-first expansion is now authorized, starting with Earth + Earth temporary
cover usable for wallrun/kick, then bounded Ice/Charge movement opportunities
and the remaining mirror personalities. The active queue and
docs/MIRROR-AND-WORKSHOP-PLAN.md distinguish planned rules from verified runtime.
Race-wide basic visuals are next, followed by a larger interactive Wellspring
with compact access to essential options. These changes must not be claimed for
the preserved playtest-clarity portable; each needs its own acceptance evidence.

Playtest-clarity amendment: a successful paid whole-cast admission may reclaim
only the minimum oldest eligible optional trails owned by that actor. Refused
casts never erase matter. Terminal deposits, other owners, paid reservations
and anchors linked to non-expired reactions remain protected. The read-only
HUD offer uses the same admission calculation; compiled trail policy is v4.
That playtest-clarity amendment retained costs, damage, durations, caps,
protocol 47 and snapshot 18. The overnight same-build candidate advances only
the protocol to 48; snapshot 18 and those gameplay contracts remain unchanged.

Under this preserved pre-unification presentation contract, non-burning terminal
matter and optional trails were harmless ingredients, rendered quieter than active
reaction hazards without removing footprint cells. The
HUD shows four quiet readiness/progress cells and exact protection state;
resource recovery detail appears on pointer inspection. Practice cards show
one action/effect first and expand to existing source-derived detail. Four
sparse floor stages connect Commons, Movement, Crucible and Sparring; guide
data is presentation-only and does not alter the map fingerprint or walls.

Shared-body counter-swing v3 improves garment planes and alternating arms while
retaining all fixed bone/foot registrations. Moving-cast arm variants are an
isolated feasibility candidate, not a live feature or a reason to grow runtime
texture banks. Human template acceptance still gates detailed named skins.

Historical awareness presentation (superseded by unified 360-degree sight): cone geometry uses the55-degree ground projection;
72ground-pixel near awareness reveals slightly behind the observer but never
bypasses opaque cover or chemistry concealment. The observer's body alone draws
above the mask; it creates no rectangular world reveal. Full-view default stays.
Sprint multiplier is1.60, not1.28; base walk speed and existing carry caps remain.
Three shared sprint banks add stronger stride/lean without changing size or hit
geometry. Temporary matter lasts3-5s. Sustained first-grade active windows rise
about25%; five instant reaction windows, per-pulse damage and control-lock
durations remain unchanged. All total reaction lifetimes remain at most5s.

September9 amendment: explicit gameplay-readability tuning is authorized:
all33 moving deliveries20% slower/larger, with approximately25% longer flight
lifetime to preserve reach; eight Fields and eight Heavy blast radii20% larger.
Damage, firing cadence, economy and chemistry outcomes unchanged. The southern
Wellspring movement annex is implemented; full race art remains gated by neutral
template acceptance. Current source/checkpoint evidence is separate from release.

Cursor-facing amendment: every character body pose follows current cursor or
controller aim immediately at the existing eight-direction sprite resolution.
Movement-facing stays independent; grounded neutral roll retains its documented
facing fallback, while neutral airborne Evade requests vertical fast-fall;
backward/strafe cadence derives from aim versus travel. Committed shots retain
their recorded start aim; visual turning must never silently retarget them.
All voluntary movement modes permit paid casting; one occupied spell startup,
forced control, own cooldown, capacity and positive Flux remain explicit gates.
Menus/death/spectating do not grant gameplay input or free casts.

The active shared body is a compact fantasy adventurer rasterized over the editable
rig (`slide_v1`, retaining proportion_v4 anatomy): about4.14/4.20/4.25 heads tall,
visible standing south heights58/63/68px. The bounded slide refinement reclines
and rolls the fixed torso with one long and one tucked grounded leg so South
reads seated. Only the24 slide base cells change; wallrun shares that silhouette.
North/NE detail and real wall-contact transitions remain human-review limits.
This does not complete the slide travel/aim and entry/hold/brake/exit banks.
Source authoring envelopes remain58/68/76px; per-size baked scales are1,63/68,68/76,
constant across every pose. All30 playable identities use the matching size in gameplay
and selection; old race skins stay on disk as historical assets, never silent
fallbacks. Fixed bones and inverse-kinematic contacts support 64 travel/aim pairs
with eight distance-driven stride phases per size. Upper body follows aim;
opposed travel uses backpedal/strafe rather than a 180-degree waist twist.
Hurtbox radius comes exclusively from Small / Middle / Large (17/18/19px),
never race, skin, frame, aim or travel direction. All use 18px wall clearance.
Stamina maxima are620/660/700, with prior recovery rates retained. Health, Flux,
speed, movement timing and ability budgets remain profile-driven and unchanged
by this proportion pass. Visual playback does not alter authority;
complete human animation acceptance still gates later detailed character skins.

## Authority and scope

This file owns current scope. Validated content and simulation own exact executable
rules; discrepancies are defects, not permission to invent behavior. README is
the player entry, .agent/OVERHAUL-IMPLEMENTATION.md is the only task queue, and
docs/CURRENT-CAST.md is the roster. Historical checkpoints prove only their named
build. Reference artwork supplies style, never gameplay data.

| System | Current contract |
| --- | --- |
| Platform | Windows x64, pinned Godot 4.7.1, GL compatibility |
| Cadence | 120 Hz authoritative simulation; 60 Hz snapshots; independent visual interpolation |
| Session | Offline-first Farflow, host authority, maximum 8 players, same-build joining |
| World | Wellspring: screen-cardinal 3072 x 2304 campus, 9 districts, 12 stations, immutable worldbone; southern movement loop and optional wallrun line |
| Cast | 30 named playable profiles; 0 reserved Angel; Small/Middle/Large only |
| Magic | Water, Earth, Fire, Air, Ice, Charge, Light, Dark; 32 selectable spells; 12 positions |
| Chemistry | 36 symmetric finite first-grade pairs including same-element pairs |
| Sound | Local cast and on-screen confirmed contact cues; eight editable PCM identities; four voices; adjustable 0-100%, default 30% |
| Delivery | Current verified portable EXE/PCK/ZIP selected by docs/current-checkpoint.json; older installer is explicitly historical; unified per-user installer/updater remains the delivery target |

No new element, race identity, mode or larger lobby is implied by this
pass. The explicit Q/fast-fall rule and bounded existing movement refinements are
authorized. Existing races may receive basic visual implementations over the
shared three-size skeleton. Bounded mirror terrain/movement interactions are
authorized only through M0-M4; generic material drift/grip remains deferred.
No dual-element attacks, recursive chemistry, vaulting or landing burst is
introduced. Old serialized IDs are tombstones,
not active moves. Keep tested save/network migrations until explicitly retired.

## Gameplay invariants

Eight normalized keyboard directions; continuous analog movement/aim. Existing
walk, sprint, low jump, finite held Float, slide/slide-jump, roll, air dodge/
wavedash, wallrun/kick, air redirect, fast fall and impact tech compose through
paid transitions. Preserve costs, cooldowns, input buffers, height, protection
and per-airtime budgets during visual work.

Current keyboard defaults are V for Wall/Air Technique and Q for Roll/Air Dodge;
all other defaults and controller bindings remain unchanged. Saved customized
layouts win over defaults. Only a complete, untouched old schema11 keyboard
layout migrates automatically; partial profiles and explicit unbinds do not.
An additive keyboard-default revision keeps deliberate rebindings stable without
raising the saved-settings schema. Older readers may discard that marker; the
exact-old-default downgrade ambiguity must be documented, not silently denied.

Every attack spends positive Flux. Stamina pays movement; Health governs defeat.
Preserve independent quiet-time recovery and character stats. All characters can
use the Spell Loom's Plain 1-4, Ctrl+1-4 and Alt+1-4 positions. Four families:
Bolt, Heavy, Rapid and Spray. Wave, Beam, standalone Field and Vector Lance
retain their authored identity but are disabled in selection and live admission.

Menus and application focus loss send neutral local gameplay commands without
pausing shared simulation. Queued wheel actions are discarded. Paid actions
held during interruption require release and a fresh press before reactivation;
directional movement may resume. UI interaction must never become a delayed
jump, dodge or cast. Gallery reconfiguration clears requests and borrowed
previews and requires a deliberate reopen, even after failed validation.

Historical B2a contract, superseded by the unified milestone above: Bolt/Heavy/
Rapid terminated at collision, range or their captured endpoint and left finite
3-5 second deposits. Its non-burning matter caused no direct damage/status.
Different casts could combine; same-cast fragments could not react together. A
surviving B2a Spray deposited one finite ingredient; direct equality was pending.
Those 3–5 second lifetimes remained until slice C passed its gates. Only active
reaction phases applied effects. Worldbone is
immutable. The C1 Earth mirror uses a cardinal 80 x 45px temporary movement
surface, with the same shot/ray footprint. It supports ordinary paid wallrun/
kick while active and healthy, permits escape on formation overlap, and releases
contact on destruction/decay. All teams meet the same 18px movement clearance.
Other reaction cover still blocks shots/rays, not walking. Names do not imply
unimplemented healing, burning, draining or friction changes.

The southern annex adds 576 pixels of height, an ordinary 160-pixel-wide loop,
two optional non-vaultable wallrun surfaces and an eastern return to existing
practice. Original objects, stations, targets, spawns and arena rules remain.
All body roles retain common 18-pixel wall clearance. New space is not a new
technique, timed challenge, minimap or material-assisted movement feature.

## Architecture

The player-facing learning loop is observe -> act -> combine -> counter -> reset.
Teach one reliable action before multi-action combinations. Every guide must
answer what a result does, when it applies and how to respond, using executable
values. Element names/colors alone never imply a status. Keep the distinction
between spell impact, harmless terminal matter, a Field spell and active chemistry.
Matrix selection and its detailed reader must identify the same pair. Show
warning/active/harmless-decay durations distinctly, and label base recovery versus
idle-ramped recovery. Station guides use the device that activated the station.

Context cards are read-only personal practice helpers, not objectives or new
mechanics. The Crucible recognizes actual active Radiance/Steam overlap from
separate local reaction origins; it explains conditional reveal and expiry
without asserting visibility behind worldbone. Both reactions retain their own
rules and clocks. The southern loop uses current bindings and paid movement
state for at most two next-action lines. Only deliberate gameplay input changes
its keyboard/mouse versus controller labels. Menus, focus/rearm guards, spectators,
invalid guests and non-HEARTH rounds suppress both cards; never borrow host state.

Post-cast owner material capacity may be gathered in one stateless pass for
multiple players, provided the unchanged per-owner query is an exact oracle.
Keep sequential pre-payment admission, global orphan-material accounting,
alive pending-cast reservations, player order and per-owner limits identical.
No persistent cache, raised cap or timing-dependent simulation branch is allowed.

input -> semantic command -> host/simulation -> snapshot -> presentation

| Owner | Responsibility |
| --- | --- |
| content | Validated versioned definitions, stable identity, data composition |
| sim | Deterministic movement/combat/chemistry, bounds, collision and outcomes |
| net | Admission, compatibility, prediction/reconciliation, snapshots |
| app | Input, preferences, stations, sessions and lifecycle |
| presentation | Art, motion, interpolation, GUI and feedback from permitted state |
| tools/tests | Reproducible builds, production-route scenarios and evidence |

Dependencies point toward simulation/content. No texture, render age or decoration
determines damage, geometry, visibility, timing or network results. Invalid data
fails closed. Historic internal names are not another gameplay system.

Contact-query optimization is a stateless conservative bounds rejection before
the unchanged sampled narrow phase. Strict separation only; tangencies retained;
linked paths fall through. Equivalence of contact point, ordering, authoritative
hashes and non-timing counters is required before using a measured improvement.

Projectile/actor circle contact likewise permits strict axis-separation rejection
before the unchanged clamped integer projection. Preserve tangency, truncation,
zero-length and negative-radius fallback. Evaluate both far misses and dense
near-contact overhead; a median improvement does not close the mixed p95 gate.

Projectile reactions may use a batch-local ordered candidate list only while
tick, recipe identities and membership cannot gain eligibility within that
synchronous batch. Preserve live references, duplicate/order semantics and the
inner active checks; all Heavy/cover/blast paths retain the full reaction list.
Any future within-batch formation/activation invalidates this optimization's
proof and requires a new same-input every-tick equivalence gate. Never reuse
this list between ticks or treat measured p95 as sustained120FPS acceptance.

Sound is feedback, not a sensor or new combat rule. It follows local authoritative
cast-starts and validated projectile/beam/spray/field contacts, never guessed
damage, other players' casts, chemistry activation or raw terminal deposits.
Contacts require an on-screen target visible through the shared relative-sight
predicate; the historical cone-mode blanket mute is superseded. Menus, spectating,
focus loss, mute and exit silence it. Six/eight-tick contact/cast admission gaps,
four fixed voices and a bounded peak prevent effect pileups; clips are generated
once, never in the simulation or per shot. Controls Lectern owns volume/mute.
The additive optional sound_volume_percent preference preserves schema 11 and
older controls; unmute restores 30%. Actual listening comfort remains a human gate.

## Visual contract

Original Oh Tipi supports neutral construction's natural proportions, crisp pixels,
layered practical clothing and empty-hand casting. The newer cast sheet in
`reference/art/cast_proportions_v5/flux-current-cast-final.png` is the current shared
proportion and later named-skin target; named skins still require complete template
playback/user acceptance. The September14 roster amendment has30 playable identities,
no unnamed Angel: H. Lenee retains `h_le_ne`/wire28, Mifu retains `fimu_yashiha`/wire29
and replaces Fire with Air (Water1/Air1/Light1); Sai Laas is a Small Nymph with
Air2/Fire1 (`sai_laas`/wire30). Faab I Yaina remains the named Angel.
The group image contains no text or elemental effects and is not a runtime atlas.
S. Wayne stays dark-skinned;
Biggy Bob has brown hair. No staff/wand, projectile, aura, shadow or environment
pixels in body sheets.

Three source body envelopes58/68/76px, baked to visible58/63/68px about the feet pivot;
shared 96 x 96 cell and feet pivot (48, 84), fixed
body scale across all actions/directions. Small/Middle/Large retain distinct core
stats and fixed hurtboxes; wall clearance stays identical for all three. Neither
hurtboxes nor wall clearance may be inferred from pose pixels or animation scale.
The size/footprint follow-up is tracked in the active queue until verified. Directions
S/SE/E/NE/N/NW/W/SW; south faces camera symmetrically. Reuse pose guides/timing,
but preserve unique anatomy, clothing and silhouettes. Filled cells do not prove
quality: opposite walk contacts and derived motion must be reviewed and labeled.

Art heading labels use South=0/360, SE=45, E=90, NE=135, N=180, NW=225,
W=270, SW=315, distinct from mathematical aim angles. Head, shoulders, hips and
feet must agree on the selected world-plane yaw. Side profiles are not acceptable
rear-quarter substitutes. Gallery now inspects actual grounded cells in these
eight steps without rotating/blending artwork; this does not certify source poses.

Production order is generic Small, then Middle, then Large, including complete
eight-direction action/contact coverage and user visual acceptance of the basic
templates together. Character-specific repairs/additions are deferred until that
gate. Fixed-bone construction references and partial cells are not finished art.
Coverage must include reviewed playback of every live movement/action mapping in
all eight headings; merely filling80 cells or repeating a held pose is insufficient.
Reuse one assembler and live presenter; review assets never become roster IDs.

Walking cadence follows actual ground travel, not a free-running idle clock or
prediction correction offsets; contact/pivot phases agree and persist through
ordinary direction and walk/sprint changes. Two authored contacts remain labeled
as such. Portraits use the exact top third of occupied South-grounded sprite
bounds, proportionally nearest-fit with transparency, not separate portrait art.

Menus favor compact source-derived tables/matrices and visual element identifiers.
Movement lists inputs, base costs/drain, protection and cooldown; chemistry shows
the complete8x8 matrix with concise selection feedback. Complete rules stay under
Details; presentation must not invent effects or imply unconditional invincibility.
The shared visual-language validator uses the same three heights, eight headings
and ten rows as production. Its twelve compatibility palettes explicitly separate
eight active elements from four reserved styles; compatibility is not new scope.

About 55-degree illustrated elevation over unrotated screen-cardinal floors;
50/75/100% zoom; no automatic worldbone fade. Quiet routes; actors/threats/
interactive matter/scenery in that priority. Element identity uses shape, value
and motion as well as color. Reduced effects preserve extent, phase and identity.
No unborn/expired effect is displayed as active.

Element deposits and reaction fields express their occupied area with repeated
native-pixel material, not separate range circles, outlines or perimeter markers.
Fire fills the area with flame tongues; Steam spreads billows; Earth uses stone
chunks and actual cover silhouettes. Tile placements stay world-anchored and are
clipped by authoritative geometry. Reduced/zero optional decoration retains this
essential material coverage. Earth artwork never invents walking collision.

## Acceptance

Scoped diff -> focused tests -> applicable actual-render/network proof -> Full
checkpoint -> exact receipt/state/queue. Keep the last working build. New art
needs alpha, gutters, fixed scale/pivot, eight-direction action coverage and
gameplay-scale review. Never call a portrait/tint a complete unique sprite.

Source, packaged, locally tested, human-accepted and publicly released are
separate states. 120 Hz configuration does not certify 120 FPS. Mixed-player timing,
physical friend-session proof, signing and public online updates remain open.

## Four-delivery authoritative duration transition table

Status: source-inspected P48 baseline to planned C targets; not implemented by A. Values are nominal milliseconds. Formation/decay, damage/pulse timing, control and protection are unchanged unless a later named slice explicitly amends them. No lifetime extension is claimed until C tests pass.

| Element (stable wire) | Terminal old -> C target | Eligible trail old -> C target |
| --- | ---: | ---: |
| Water (3) | 5000 -> 10000 | 1400 -> 2800 |
| Earth (1) | 5000 -> 10000 | 1500 -> 3000 |
| Fire (2) | 4000 -> 8000 | 1100 -> 2200 |
| Air/internal wind (4) | 3000 -> 6000 | 800 -> 1600 |
| Ice (5) | 5000 -> 10000 | 1400 -> 2800 |
| Charge (6) | 3000 -> 6000 | 800 -> 1600 |
| Light (7) | 4000 -> 8000 | 1200 -> 2400 |
| Dark (8) | 4000 -> 8000 | 1300 -> 2600 |

Trails apply only to eligible retained families; Rapid emits none. Material geometry strength remains separate from planned reaction strength.

| Reaction stable ID/wire | Active old | C target | Treatment |
| --- | ---: | ---: | --- |
| fortify / 301 | 3125 | 6250 | sustained active window doubled |
| magma / 302 | 2750 | 5500 | sustained active window doubled |
| mud / 303 | 3250 | 6500 | sustained active window doubled |
| dustfront / 304 | 2250 | 4500 | sustained active window doubled |
| permafrost / 305 | 3000 | 6000 | sustained active window doubled |
| grounding_network / 306 | 3250 | 6500 | sustained active window doubled |
| crystal_prism / 307 | 2750 | 5500 | sustained active window doubled |
| blightsoil / 308 | 3000 | 6000 | sustained active window doubled |
| conflagration / 309 | 3000 | 6000 | sustained active window doubled |
| steam / 310 | 2625 | 5250 | sustained active window doubled |
| firestorm / 311 | 2250 | 4500 | sustained active window doubled |
| thermal_shock / 312 | 100 | 100 | instant contact window unchanged |
| plasma_arc / 313 | 120 | 120 | instant contact window unchanged |
| solar_flare / 314 | 100 | 100 | instant contact window unchanged |
| cinderveil / 315 | 3000 | 6000 | sustained active window doubled |
| flood / 316 | 3125 | 6250 | sustained active window doubled |
| mistcurrent / 317 | 2750 | 5500 | sustained active window doubled |
| freeze / 318 | 2500 | 5000 | sustained active window doubled |
| conductive_flood / 319 | 2625 | 5250 | sustained active window doubled |
| mirrorwater / 320 | 3250 | 6500 | sustained active window doubled |
| blackwater / 321 | 3000 | 6000 | sustained active window doubled |
| vortex / 322 | 2750 | 5500 | sustained active window doubled |
| hailstream / 323 | 2813 | 5626 | sustained active window doubled |
| ion_storm / 324 | 2625 | 5250 | sustained active window doubled |
| lightbend / 325 | 3000 | 6000 | sustained active window doubled |
| shadowdraft / 326 | 3000 | 6000 | sustained active window doubled |
| glacier / 327 | 3500 | 7000 | sustained active window doubled |
| superconduct / 328 | 2250 | 4500 | sustained active window doubled |
| crystal_lens / 329 | 2875 | 5750 | sustained active window doubled |
| black_ice / 330 | 3125 | 6250 | sustained active window doubled |
| overload / 331 | 2000 | 4000 | sustained active window doubled |
| arcflash / 332 | 140 | 140 | instant contact window unchanged |
| static_shroud / 333 | 2750 | 5500 | sustained active window doubled |
| radiance / 334 | 3125 | 6250 | sustained active window doubled |
| penumbra / 335 | 3000 | 6000 | sustained active window doubled |
| umbral_field / 336 | 3500 | 7000 | sustained active window doubled |

Baseline is ElementChemistrySystem.ELEMENT_LIFE_MS/TRAIL_LIFE_MS/RECIPE_ROWS, inspected before source changes. C must update integer expiry bounds, prediction/snapshots/compiled identity and source-derived guides together. Trail-assisted sustained60% scaling remains unchanged unless separately reviewed. This is the single old/new duration table; implementation evidence references it.


### HEX integration evidence clarification (2026-09-20)

Current p54 source is a verified human-playtest candidate: Full 157 suites /
776,169 assertions, zero failures/stderr, native package identity and safe close.
See docs/HEX-INTEGRATION-CHECKPOINT.md and docs/HEX-FIRST-FOUR-REVIEW.md.
Configured 120 Hz is unchanged; measured dense and rendered capacity remains
unaccepted. Do not infer human acceptance or physical two-PC networking.
The current first-four review supersedes older descriptive shorthand where it
conflicts with implemented behavior: Dustfront and Mistcurrent are stationary,
transparent steering fields; Firestorm is not ground-only and jumping alone
is not its counter. A Vortex analytic inner opening does not establish a safe
whole-cell center. That center coverage and exact Mistcurrent Fire suppression
need independent targeted oracles; no mechanic was silently changed here.

# Six-element combat contract and reference evidence

Status: INTEGRATED SOURCE QUALIFIED, October 9, 2026. Build p59-6336a7ba6067 passed the complete 227-suite gate with 5,713,342 assertions and zero failures/error output, plus both actual input journeys. The [integration evidence](six-integration.md) owns final source and delivery receipts. Sixty-three canonical recipes, finite fusion and shared damage pools are implemented. No human match-balance or enjoyment result is claimed.

The user's later instructions supersede the earlier eight-element, pair-only slice. Canonical selectable elements are Water, Fire, Air (internal `wind`), Earth, Light and Dark. Ice and electrical effects are derived techniques. There are six self-reactions, fifteen distinct cross-pairs and forty-two subsets of three through six elements. Stable core recipe wires remain; higher-order wire is `400 + mask`, with Earth=1, Fire=2, Water=4, Air=8, Light=16, Dark=32.

## Primary evidence and adaptation boundary

- [Noita, Nolla Games](https://www.noitagame.com/) establishes material simulation, temperature and electricity, and spells that alter the environment. H.E.X. borrows the consistent elemental grammar; it retains whole hexes, paid finite stock and immutable worldbone rather than claiming to reproduce pixel simulation.
- [Magicka, publisher-hosted official manual](https://cdn.akamai.steamstatic.com/steam/apps/42910/manuals/Magicka%20manual%20body%20--%20English.pdf) documents elemental combinations, Water displacement/wetness, Cold slowing, Lightning interactions and Ice projectiles. The indexed elements section was inspected; the browser could not open the full15MB manual. This supports deriving frozen/electrical techniques from combinations, not these exact63 recipes or numbers.
- [Apex Legends, EA abilities guide](https://help.ea.com/en/articles/apex-legends/abilities/) provides shipped precedents for movement-sensitive reveal, proximity hazards, damaging route boundaries, repeated area pressure and displacement. H.E.X. adapts those readable conditions into Mirrorwater, Black Ice, Penumbra, pressure fields and bounded impulses. No opponent loses all movement or input control. The source establishes shipped behavior, not measured causal benefit.
- [Enter the Gungeon, interview with designer Dave Crooks](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-) describes environmental combat, repeatedly testing authored rooms and keeping optional execution depth from overwhelming the basic controls. That informs distinct shapes, attack timing, exits and retained existing inputs. It does not establish optimal H.E.X. cadence or damage.
- [Nintendo, official Fox special-move description](https://www.smashbros.com/wii/en_us/characters/fox.html) documents projectile reflection and rapid fire without flinching. This is a Smash-series precedent from Brawl, not a claim about Melee frame data. H.E.X.'s Prism retains projectile ownership and only changes trajectory, so its offensive optical use is banking one's own paid shots; its separate hostile contact cut is explicit.

Each following row is an original H.E.X. adaptation. Repetition, geometry, displacement, visibility and damage budgets must be tested locally. Shipping or commercial success of an example is not causal evidence that these exact transfers improve play.

## Finite execution contract

The live catalog is `content/reactions/six_element_reactions_v2.json` (schema3, status/mutation gate `bounded_combinations`), loaded through `ReactionCatalog.DEFAULT_PATH`. The former `first_eight_element_reactions_v1.json` is restored byte-exact as the36-recipe art archive.

Every product stores its exact element mask, sorted unique paid source IDs (maximum12), flat sorted funding triples `[source_id, spell_wire_id, contributed_strength]`, funded consumed strength (maximum180), ancestry creation tick and a remaining shared damage pool. Initial capacity is4000 Health units per consumed strength unit. This number is an authored hypothesis, not an external-game statistic. Rapid1 therefore funds4000 units; Bolt5 funds20000; Heavy15 funds60000. The effect quote is separately bounded by matched strength and never scales exponentially with arity. A new ingredient cannot raise its parent's per-hit strength: fusion takes the lesser strength.

Funding records retain the actual remaining-strength deltas, including repeated partial contacts against one strong source. Snapshot validation can cross-check source spell identity, elemental union, scalar sum, compiled per-source ceilings, shared-source aggregate allocations and live ledger consumption after old full casts retire. This is structural consistency evidence; it does not cryptographically authenticate an entirely substituted server history.

Damage first applies an exact inverse bound for the current incoming-damage perk, then debits actual Health lost. Overkill, vulnerability, resistance, one-unit rounding, protection and intangible movement cannot overdraw the pool. Actors share the pool. Pool exhaustion leaves the paid environmental effect until ordinary expiry, but cannot create another damaging pulse.

Fusion requires a strictly larger element union and disjoint provenance. Product plus ingredient consumes that source's remaining paid stock; product plus product transfers both parents' stock without charging it again. Parents disappear atomically. The child gets a fresh visible formation phase, but never extends the earliest parent's expiry. The complete formation warning and at least one active tick take priority over harmless decay; the reserved fade tail clips when a short-lived ancestor cannot fit the normal48-tick tail. Earliest expiry remains exact. A longer-lived ancestor can instead leave a longer harmless fade after the child's authored active window ends; neither damage nor control remains active during that tail. This also applies when a self-product becomes a cross-pair, not only when the result contains three or more elements. If warning plus one active and one decay tick cannot fit, refusal occurs before mutation. Short-lived starting pairs cannot support leisurely six-cast chains. Source capacity or actor-contact capacity also refuses before mutation. One terminal performs at most one upgrade; no idle recursive cascade exists. Spent one-time actor latches are OR-merged. Repeated crossings cannot regenerate damage.

Movement ratios take their bounded minimum once. Overlapping products can apply only one current and one14px impulse to an actor in a step, selected in stable product order. They cannot multiply movement controls without bound. No recipe changes worldbone or generates unpaid projectiles/material.

## Pair and self roles

| Wire | Recipe | Inputs | Executable role | Counter |
|---|---|---|---|---|
| 301 | Rampart | earth + earth | one eruption hit raises a breakable pillar that cuts a firing lane or creates a wallrun approach | break the 32-Health pillar, go around, or wait; trapped occupants can escape |
| 302 | Magma | earth + fire | grounded damage and route denial | leave or jump before the next pulse |
| 303 | Quagmire | earth + water | 70% ground acceleration and braking; staying for 350 ms starts grounded attrition | jump or leave before 350 ms; movement ratios end immediately outside |
| 304 | Sandblast | earth + wind | one grounded hit and 14 px sideways displacement per hostile actor | jump across or leave during formation; solid cover stops the displacement |
| 307 | Crystal Prism | earth + light | one hostile contact cut; bank existing paid projectiles off a breakable reflection plane | change approach or break the 18-Health plane with Spray; ownership never changes |
| 308 | Blightsoil | earth + dark | grounded pulses deny Health, Flux and Stamina recovery while occupied | jump or leave the soil; ordinary recovery waits still apply afterwards |
| 309 | Conflagration | fire + fire | committed concentrated ground burn | leave or jump during warning |
| 310 | Steam | fire + water | visible capped scald pressure | exit or cool with a fresh Water cast |
| 311 | Arcstorm | fire + wind | one warned electrical line burst; one separate paid Fire source can extend the arc | leave the previewed line before activation or consume its optional Fire link |
| 314 | Solar Flare | fire + light | one radial flash deals damage and reveals targets for 700 ms | leave the forming disk; this pulse cannot fire again |
| 315 | Backdraft | fire + dark | concealing fuse becomes transparent for its last 600 ms, then bursts once | leave during the visible final warning; no damage before detonation |
| 316 | Frostway | water + water | one grounded freezing hit; ground travel is 75% and physical projectiles travel at 65% | slide, jump, or leave; air movement and slide speed remain unchanged |
| 317 | Hailcurrent | water + wind | narrow hail pulses combine with a grounded current along the cast direction | leave laterally; jumping avoids current and ground-level hail |
| 320 | Mirrorwater | water + light | disturbing the mirror surface reveals movement and triggers damage on each pulse | stand still between pulses after the entry reveal, or leave the disk |
| 321 | Black Ice | water + dark | entry briefly slows; the first grounded exit fractures the ice for one hit | jump out to avoid the exit fracture; each actor can be hit only once |
| 322 | Vortex | wind + wind | rotating ground current and pulses guard an annulus around an open center | use the center opening, jump, or leave between pulses |
| 325 | Lightbend | wind + light | one hostile contact flash; bend paid Light projectiles by 15 degrees for a different attack angle | change the Light approach angle or leave the redirected firing lane |
| 326 | Shadowdraft | wind + dark | a stationary corridor alternates 300 ms of concealing damage and 300 ms of clear safety | cross during the transparent interval or leave laterally |
| 334 | Radiance | light + light | continuous reveal and regular searing pulses also threaten airborne actors | leave between 600 ms pulses; jumping alone does not escape |
| 335 | Penumbra | light + dark | one damaging revealed boundary crossing per actor, with a safe interior | avoid the marked ring or shelter inside; repeated crossings cannot repeat the hit |
| 336 | Umbral Field | dark + dark | concealed dwell pressure grows from 2 to 6 Health per pulse after one second | move to reveal occupants or exit before one second; exit resets dwell pressure |

Every utility pair now also has a real finite damaging trigger. Rampart's eruption and Prism/Lightbend contact attacks spend one actor latch. Frostway's first grounded contact deals damage; its ongoing motion effects remain75% ordinary ground travel and65% physical projectile travel, leaving slides and airborne movement unchanged. These additions follow the user's explicit requirement that every interaction damage an opponent, rather than being inferred from the references.

## Higher-order authored definitions

These42 profiles compose independent executable mechanics. Earth changes ground acceleration/braking; Fire supplies one directed electrical impulse and an activation attack except where a Light/Dark boundary selects crossing; Water changes ordinary ground and physical projectile travel; Air creates directional ground flow and a lane except for boundary rings; Light reveals; Dark adds concealment/motion reveal, or recovery denial when Light is also present. A static enumeration confirms42 distinct mechanism signatures ignoring names and all numerical values. This is mechanical distinction, not proof that all42 are equally enjoyable.

| Wire | Name | Elements | Trigger | Geometry | Secondary rules |
|---|---|---|---|---|---|
|407|Caldera|earth + fire + water|activation|disk|ground acceleration/braking; one directed discharge; ground/projectile slowdown|
|411|Cinder Cyclone|earth + fire + wind|activation|directional capsule|ground acceleration/braking; one directed discharge; directional ground flow|
|413|Silt Surge|earth + water + wind|pulse|directional capsule|ground acceleration/braking; ground/projectile slowdown; directional ground flow|
|414|Thunderhead|fire + water + wind|activation|directional capsule|one directed discharge; ground/projectile slowdown; directional ground flow|
|415|Tempest Forge|earth + fire + water + wind|activation|directional capsule|ground acceleration/braking; one directed discharge; ground/projectile slowdown; directional ground flow|
|419|Sunforge|earth + fire + light|activation|disk|ground acceleration/braking; one directed discharge; continuous reveal|
|421|Geode Spring|earth + water + light|moving|disk|ground acceleration/braking; ground/projectile slowdown; continuous reveal|
|422|Scalding Halo|fire + water + light|activation|disk|one directed discharge; ground/projectile slowdown; continuous reveal|
|423|Opaline Furnace|earth + fire + water + light|activation|disk|ground acceleration/braking; one directed discharge; ground/projectile slowdown; continuous reveal|
|425|Prism Gale|earth + wind + light|moving|directional capsule|ground acceleration/braking; directional ground flow; continuous reveal|
|426|Corona Arc|fire + wind + light|activation|directional capsule|one directed discharge; directional ground flow; continuous reveal|
|427|Daybreak Engine|earth + fire + wind + light|activation|directional capsule|ground acceleration/braking; one directed discharge; directional ground flow; continuous reveal|
|428|Aurora Current|water + wind + light|moving|directional capsule|ground/projectile slowdown; directional ground flow; continuous reveal|
|429|Glacial Cathedral|earth + water + wind + light|moving|directional capsule|ground acceleration/braking; ground/projectile slowdown; directional ground flow; continuous reveal|
|430|Stormglass|fire + water + wind + light|activation|directional capsule|one directed discharge; ground/projectile slowdown; directional ground flow; continuous reveal|
|431|Prismatic Monsoon|earth + fire + water + wind + light|activation|directional capsule|ground acceleration/braking; one directed discharge; ground/projectile slowdown; directional ground flow; continuous reveal|
|435|Ashen Mire|earth + fire + dark|activation|disk|ground acceleration/braking; one directed discharge; concealment and moving reveal|
|437|Gravefrost|earth + water + dark|dwell|disk|ground acceleration/braking; ground/projectile slowdown; concealment and moving reveal|
|438|Night Boil|fire + water + dark|activation|disk|one directed discharge; ground/projectile slowdown; concealment and moving reveal|
|439|Volcanic Undertow|earth + fire + water + dark|activation|disk|ground acceleration/braking; one directed discharge; ground/projectile slowdown; concealment and moving reveal|
|441|Burial Gale|earth + wind + dark|dwell|directional capsule|ground acceleration/braking; directional ground flow; concealment and moving reveal|
|442|Black Thunder|fire + wind + dark|activation|directional capsule|one directed discharge; directional ground flow; concealment and moving reveal|
|443|Funeral Storm|earth + fire + wind + dark|activation|directional capsule|ground acceleration/braking; one directed discharge; directional ground flow; concealment and moving reveal|
|444|Sleet Veil|water + wind + dark|dwell|directional capsule|ground/projectile slowdown; directional ground flow; concealment and moving reveal|
|445|Winter Sepulcher|earth + water + wind + dark|dwell|directional capsule|ground acceleration/braking; ground/projectile slowdown; directional ground flow; concealment and moving reveal|
|446|Night Tempest|fire + water + wind + dark|activation|directional capsule|one directed discharge; ground/projectile slowdown; directional ground flow; concealment and moving reveal|
|447|Abyssal Tempest|earth + fire + water + wind + dark|activation|directional capsule|ground acceleration/braking; one directed discharge; ground/projectile slowdown; directional ground flow; concealment and moving reveal|
|449|Obsidian Crown|earth + light + dark|crossing|annulus with safe center|ground acceleration/braking; continuous reveal; recovery denial|
|450|Eclipse Flare|fire + light + dark|crossing|annulus with safe center|one directed discharge; continuous reveal; recovery denial|
|451|Eclipse Crucible|earth + fire + light + dark|crossing|annulus with safe center|ground acceleration/braking; one directed discharge; continuous reveal; recovery denial|
|452|Dusk Mirror|water + light + dark|crossing|annulus with safe center|ground/projectile slowdown; continuous reveal; recovery denial|
|453|Onyx Tide|earth + water + light + dark|crossing|annulus with safe center|ground acceleration/braking; ground/projectile slowdown; continuous reveal; recovery denial|
|454|Eventide Cauldron|fire + water + light + dark|crossing|annulus with safe center|one directed discharge; ground/projectile slowdown; continuous reveal; recovery denial|
|455|Eventide Forge|earth + fire + water + light + dark|crossing|annulus with safe center|ground acceleration/braking; one directed discharge; ground/projectile slowdown; continuous reveal; recovery denial|
|456|Twilight Gyre|wind + light + dark|crossing|annulus with safe center|directional ground flow; continuous reveal; recovery denial|
|457|Twilight Bastion|earth + wind + light + dark|crossing|annulus with safe center|ground acceleration/braking; directional ground flow; continuous reveal; recovery denial|
|458|Corona Eclipse|fire + wind + light + dark|crossing|annulus with safe center|one directed discharge; directional ground flow; continuous reveal; recovery denial|
|459|Eclipse Engine|earth + fire + wind + light + dark|crossing|annulus with safe center|ground acceleration/braking; one directed discharge; directional ground flow; continuous reveal; recovery denial|
|460|Moonless Aurora|water + wind + light + dark|crossing|annulus with safe center|ground/projectile slowdown; directional ground flow; continuous reveal; recovery denial|
|461|Obsidian Aurora|earth + water + wind + light + dark|crossing|annulus with safe center|ground acceleration/braking; ground/projectile slowdown; directional ground flow; continuous reveal; recovery denial|
|462|Celestial Tempest|fire + water + wind + light + dark|crossing|annulus with safe center|one directed discharge; ground/projectile slowdown; directional ground flow; continuous reveal; recovery denial|
|463|Convergence|earth + fire + water + wind + light + dark|crossing|annulus with safe center|ground acceleration/braking; one directed discharge; ground/projectile slowdown; directional ground flow; continuous reveal; recovery denial|

## Authored acceptance and remaining limits

`test_hex_six_element_reactions.gd` exercises63 paid terminal formation paths and actual damage, protection and pool debit; all720 input orders for six elements; all unordered disjoint product partitions with at least two elements on each side; finite transfers, expiry/duplicate refusal, perk rounding and lethal loss. The policy suite checks all masks, symmetric pairs, retired-element refusal, immutable contracts and valid canonical geometry. The product-effects suite retains independent coverage, seam, sweep, height, landing, zero-allocation and contact-cap oracles and adds one-time edge attacks, stillness, terminal-warning and nonstacking-flow controls.

The focused receipt below records actual execution. Snapshot mutation/restore acceptance belongs to root's protocol59 work. The no-hex legacy ElementReactionState has only two source IDs and is not an alternative63-recipe authority; playable mode routing must use the unified court. Archived36 recipe rows remain explicit art/fixture provenance.

No automation proves that none of63 recipes is overpowered in human play. Needed evidence includes equal-Flux confrontations, opponent escape opportunities, reaction visibility at native scale, input load and live match telemetry. The implementation does establish finite ceilings and executable counters that make those trials meaningful.

Peer review repairs: delayed fusion inherits stored owner/team/aim after consumed source records retire; self-products can upgrade only when the union strictly adds an element; inherited one-use actor latches suppress activation descendants as well as crossing descendants; and authority material ordering matches the six-element renderer surface. These chemistry regressions are included in the root-owned focused pass below; broader compatibility migrations still await integrated qualification.

## Rapid cadence refinement

The inherited Rapid baseline was20 ms preparation plus90 ms post-release cooldown: at120Hz this was3+11=14 ticks between held releases (116.7 ms,8.57 shots/s). The candidate changes only those family values to8 ms and80 ms, or1+10=11 ticks (91.7 ms,10.91 shots/s). All six Rapid spells inherit it. Each shot still costs2Flux and has3000 damage, one reaction strength,600 paid material units,4px radius and600units/s travel. Fixed stock buys the same number of shots and total quoted damage, spent faster. Rapid remains fragile in clashes and less Flux-efficient than the baseline Bolt; releasing fire is still needed for the existing recovery wait. No volley adds projectile damage or chemistry funding.

Gungeon's designer account above supports treating firing rhythm, authored opponent gaps and uncomplicated core controls as design variables. Nintendo's Fox example supplies a shipped rapid-fire/low-interruption contrast. Neither source supplies these H.E.X. timings. The local11-tick target is a testable tuning hypothesis, with native readability and human pacing acceptance still required. Bolt remains held pressure at27 to 34ticks by element; Heavy remains deliberate/manual at132ticks; Spray remains manual at101ticks,108 for Water. These counterpart cadences are inherited, not newly optimized.

`test_six_element_cadence.gd` uses actual held commands to verify all six Rapid streams, one-tick release warning, exact Flux/material payment, ordinary movement, exhaustion, physical capacity and stun gates, manual Heavy contrast, and an actual six-input cast/flight/fusion route starting from the longer-lived Earth+Water pair. `test_hex_six_element_reactions.gd` additionally keeps all720 permutations, short-parent lifetime boundaries, fifteen partial contacts exhausting one Heavy15 without rounding-based funding, and an actual ordered-queue split-source regression with a positive sibling hit control. Root records execution results; this document does not treat authored assertions as passes.

## Root-owned execution and migration receipt

`.godot/six-combat-v2/tests.log` records **hex-six-element-reactions:10839 assertions/0 failures**, **six-element-cadence:662/0**, and **balance-audit:12040/0**. This qualifies the executed finite-funding, all720-order, paid-input and cadence scenarios. It does not imply that every suite in that receipt passed: its older SessionSnapshot fixture had four failures, subsequently repaired and independently rerun by root.

The root-owned broad diagnostic runs exposed older tests still using retired Ice/Charge actors,36-recipe metadata or incomplete no-Hex snapshots. Current acceptance now uses live63 metadata, actual24-spell ledgers, complete HexWorldSnapshot capture/prepare/restore, and exact conservation/geometry/height/capacity boundaries. Four migrated suites are `test_element_chemistry`, `test_projectile_chemistry_integration`, `test_element_trails`, and `test_reaction_strength_provenance`; their exact old versions remain under `.godot/reference-refinement-baseline/six-element-regression-migration/`. These migration edits are not labelled passed before root executes them.

Derived electrical integration now distinguishes Arcstorm311's finite activation from Caldera407's one14px directed impulse. The preserved three-radius/eight-direction prediction comparisons, solid-cover clipping, shared displacement cap and full snapshot/network replay use real paid source records. The old no-Hex Capacitor331 movement bonus is not claimed current. Frostway316 has an independently checked22.5px radius/150px centerline and75% ground/65% projectile travel; the removed32730px/200px corridor remains baseline history. Peer reviews found no further concrete blocker in these field fixtures; engine acceptance remains root-owned.

The actor adapter suite independently checks live Solar Flare's late one-use activation, optional Fire-link survival for Arcstorm, Black Ice's250ms65% entry slow and one grounded4Health exit fracture, its jump/repeated-exit counters, exact concealment phase/whole-cell boundaries, and inert retired wires. Its intentionally isolated already-formed products carry explicit finite pools; those adapter fixtures do not claim paid-input admission. The actual projectile terminal test checks the Water720-tick lifetime at its exact last-live and first-expired ticks.

All chemistry production is frozen pending root's final integrated run. Latest native aerial fixture migrations are test-only and separately preserve the30×8×23×2 matrix, exact unaffected ground/legacy descriptors, native source/UV bounds, held/reduced keys and bounded immutable geometry caches. No screenshot or automated assertion certifies human readability, fun or competitive balance.


## Inherited-lifetime snapshot repair

A root-run probe found an authority/decoder mismatch for a real paid Caldera407: creation tick1, activation49, decay349 and inherited expiry456. The300-tick active interval was correct; the old decoder incorrectly limited expiry to the child's own48-tick fade. The authoritative fusion timeline is preserved. Snapshot admission now bounds the tail by the unchanged ancestry tick plus the longest legitimate first self/pair lifetime contained in that product's ingredient mask. The active interval remains bounded by the result's own definition, and the full formation warning remains required.

The same issue exists in self-product upgrades whose result is still a pair. Water self316 can become Steam310 while retaining the parent's570-tick deadline. More than two distinct funded sources identify a possible inherited pair; same-tick fusion is legitimate, so ancestry can equal creation. Ordinary fresh two-source products retain their strict authored lifetime. Every accepted record still requires matching live source identities, exact elemental union, conserved funding, canonical geometry and a verified authority hash. This is a bounded possible-history check; the schema does not retain the destroyed parent tree and cannot prove that historical tree from a wholly forged self-consistent replacement.

The production maximum-lifetime memo contains only immutable recipe metadata and accepts only masks1..63, bounding it to63 entries. The independent pre-E9 reference decoder calculates the same bound with its own uncached loop. The new acceptance cases capture and restore all42 paid composites both during formation and after an actual attack, all30 ordered self-to-pair routes on same and later ticks, and all15 unordered self-product partitions on same and later ticks. Partition cases form their second product through the public paid source-contact route. Exact407 and Frostway-to-Steam timelines are independent numeric controls. Fresh-hash excessive expiry, future/negative ancestry and extended active intervals are refused; the fresh two-source limit remains covered. Root's `.godot/six-repairs-v4/summary.json` records the expanded reaction suite at12839 assertions/0 failures, chemistry snapshots1837/0, complete-world snapshots17386/0 and the independent snapshot optimization/reference comparisons764/0. Pixel-cast also passed86792/0. The receipt has empty stderr. This is scoped qualification: its capacitor integration suite still had one invalid16-character guest-name fixture, corrected afterward to the existing15-character transport boundary with explicit rejection and positive controls. The complete electrical network rerun and final integrated gate remain root-owned and pending.

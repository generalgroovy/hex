# H.E.X. BALANCE — FLUX integration handoff

**Status:** Source-limited balance review and experiment specification. No implementation audit, code patch, or runtime acceptance is claimed.

**Recommended contribution:** Keep production mechanics and values unchanged. First map and measure the existing Steam exposure path, then consider **one existing exposure-rate coefficient** using BAL-E1. Retain the baseline when it passes. The other reaction roles below are audit criteria, not instructions to add mechanics.

## 1. Source basis and evidence boundaries

Only **S1 — `Pasted text.txt`** was received: the specialist assignment with `TASK_ID: <BALANCE>`. It contains no authoritative commit, build identifier, implementation, balance table, or executable harness. Conversation/library searches did not recover the referenced design contract, active implementation queue, or checkpoint; that does not establish that those files do not exist.

- Assignment fingerprint: SHA-256 `00dbf3516287d746be3f7127bd0b36eb1cddb35b5df90392bac138a140bbb549`; 11,049 bytes. This identifies the assignment, **not a game build**.
- Observed implementation facts: **none available**.
- Documented intentions: S1 lines 21–31 and 112–127.
- Hypotheses/proposals: the provisional roles, abuse cases, and numeric experiment targets in this handoff.
- Checks executed: attachment fingerprinting and the structural validation described in section 7.
- Source audit, Godot, Windows, replay, multiplayer, and playtests: **NOT_RUN**.

**Required integration input:** the current design contract, active queue, checkpoint with commit/build identifier, all ten reaction and four delivery definitions, and the actual payment, impact selection, finite-strength allocation/interception, reaction consumption, Steam accumulation/overlap/exit/decay, and spawn-protection code with relevant tests. Their filenames were not supplied; this handoff does not invent repository paths.

### Preserved boundaries

Godot remains authoritative and Windows the release target. The simulation target is 120 Hz; eight players is a target, not a demonstrated capacity. Movement, aim and projectile flight remain continuous. Exact origins/radii select eligible hexes, and those selected cells remain fully affected. Chemistry remains available on eligible Wellspring ground, including stations/spawns, with existing protection unchanged. Strength and ingredients remain finite. Keep Bolt, Heavy, Rapid, Spray; all twelve plain/Ctrl/Alt 1–4 slots; player-facing **Air** and existing internal `wind` identifiers; the three size templates, their hurtboxes, and shared wall clearance. No live source, assets, user changes, or working builds are modified. [S1:21–31]

## 2. Current-versus-proposed reaction review

The pair/name associations follow the parallel list order in S1; **verify the registry before integration**. S1 names all ten identities and explicitly describes Steam as accumulating scald rather than concealment. It does not establish other mechanics or numerical values. [S1:116–125]

All proposed roles are conditional audit lenses. They do **not** authorize adding slow, blind, silence, knockback, pull, walls, transport, immunity, a cleanse, or new elemental cancellation. When a role requires a mechanic absent from the current contract, mark that row blocked or discard that role rather than redesign the reaction.

| Pair / identity | Current evidence | Provisional purpose and expressive option | Clear proposed counter |
|---|---|---|---|
| Water / Water — **Flood** | Identity listed; behavior and numbers not supplied. | Broad Water preparation rather than concentrated finishing damage. Seed an anticipated route for a later paid reaction instead of aiming only at the opponent. | Rotate through untreated ground before committing to the prepared route. |
| Water / Earth — **Mud** | Identity listed; behavior and numbers not supplied. | Chokepoint tempo control, conditional on existing movement-affecting behavior. Place at a likely turn or landing point rather than covering an entire arena. | Use an untreated alternate route; do not assume jumping grants immunity. |
| Water / Fire — **Steam** | Accumulating scalding exposure; not concealment. Numbers unknown. | Punish sustained occupation through accumulating scalding exposure, not concealment. Force a choice between holding a useful position and leaving before exposure becomes costly. | Leave affected cells promptly; recovery follows the existing exit/decay rule, which is not supplied. |
| Water / Air — **Mistcurrent** | Identity listed; behavior and numbers not supplied. | Pressure an approach or escape route using the existing Water/Air behavior. Prepare a flank rather than compete with Flood for stationary area coverage. | Enter from an unprepared angle rather than follow the prepared route. |
| Earth / Earth — **Rampart** | Identity listed; behavior and numbers not supplied. | Defensive Earth positioning; cover is conditional on source-confirmed blocking geometry. Split approach angles using existing blocking behavior, rather than seal every route. | Flank the position; do not assume the effect is destructible. |
| Earth / Fire — **Magma** | Identity listed; behavior and numbers not supplied. | Committed ground pressure, conditional on the actual hazard behavior. Threaten a predicted landing or return route instead of chasing current position. | Bait the placement and change route. |
| Earth / Air — **Dustfront** | Identity listed; behavior and numbers not supplied. | Earth/Air approach disruption through its existing effect. Time pressure to an opponent crossing an exposed lane. | Change approach angle or stagger entry rather than repeatedly contest the same lane. |
| Fire / Fire — **Conflagration** | Identity listed; behavior and numbers not supplied. | Concentrated Fire escalation using paid follow-up commitment. Commit the second Fire contribution only when the opponent chooses to stay. | Disengage before the follow-up expenditure is useful. |
| Fire / Air — **Firestorm** | Identity listed; behavior and numbers not supplied. | Fire/Air pressure along a moving fight, without assuming the effect itself moves. Lead an escape route instead of firing at the current location. | Reverse or leave the threatened route laterally. |
| Air / Air — **Vortex** | Identity listed; behavior and numbers not supplied. | Air-based positional control, conditional on source-confirmed force behavior. Set a reversal or crossfire point using existing displacement behavior. | Contest from outside the affected cells and another angle; do not assume an escape button or immunity. |

### Base-element synergy, resource price, and abuse hypotheses

Every row below is proposed analysis, not observed behavior. A two-element recipe does not imply a 1:1 consumption ratio, leftover reagents, equal output allocation, or a new yield multiplier; obtain those from the current implementation.

| Identity | Base-element synergy | Resource tradeoff | Likely abuse to investigate |
|---|---|---|---|
| **Flood** | Use Water as the setup ingredient for a later first-four pair, only where the actual registry permits retained ingredients. | Commit two Water contributions to preparation; spreading one finite output budget must not create a full-strength copy in each cell. | Repeated wetting or refreshing reissues the original quantity without new payment. |
| **Mud** | Water supplies one ingredient and Earth the other; time the second contribution when the route matters. | Spend two elements on position-dependent utility instead of immediate direct pressure. | Tiny repeat contributions renew a maximum movement penalty or create a station/spawn trap. |
| **Steam** | Combine paid Water and Fire contributions at a chosen position; check real consumption before assuming leftovers remain. | Commit setup and Fire expenditure to dwell-time pressure rather than an immediate direct hit. | Boundary re-entry creates repeated entry damage, or overlapping fields charge the same exposure contribution twice. |
| **Mistcurrent** | Combine Water setup with the actual Air interaction; no new movement boost, projectile redirection, or cleanse is implied. | Spend two ingredients on route utility; carrying or relocating an effect, if supported, cannot replenish its budget for free. | Relocation or cell traversal recreates full ingredient quantity or strength. |
| **Rampart** | Concentrate two Earth contributions at a useful defensive position. | Commit Earth resources to a location an opponent can choose not to contest. | Cheap indefinite refresh, impassable trap combinations, or denied station access. |
| **Magma** | Combine Earth positioning and Fire expenditure through the existing recipe. | Trade two-element commitment for local pressure; do not assume a longer lifetime or higher damage than Steam without evidence. | Every selected cell receives the full output budget, or small additions renew a full-strength hazard. |
| **Dustfront** | Combine Earth and Air to support a follow-up shot; no blind, silence, or stagger is assumed. | Pay for a timing opportunity instead of guaranteed burst damage. | Each tiny Rapid/Spray contribution grants a full-strength control or reaction effect. |
| **Conflagration** | Combine two Fire contributions without assuming an extra multiplier or new stacking mechanic. | Spend additional Fire resources on a punish window rather than retain them for a later exchange. | Refresh increments output indefinitely or increases strength without consuming new ingredients. |
| **Firestorm** | Combine Fire threat and the existing Air interaction. | Spatial reach, where supported, must be paid for or distribute a finite budget rather than duplicate it. | Spread, relocation, or repeated contact reissues an undiminished reaction budget. |
| **Vortex** | Combine two Air contributions to support subsequent aimed pressure. | Commit resources to control whose value depends on positioning and follow-up. | Repeated applications or several casters create an inescapable control loop. |

**Priority distinction:** Steam is the only reaction with enough supplied behavioral intent to motivate a narrowly scoped tuning pilot. Its actual implementation remains unverified. The strongest current conclusion about the other nine is a source requirement, not a balance verdict.

## 3. Projectile-role comparison

Current speed, cadence, strength, mana costs, footprint, interception behavior, and reaction yields are **unknown for all four families**. The table describes the proposed comparison and specialization to test; it is not a statement of current rankings. [S1:28,125–127]

| Family | Speed / cadence | Strength | Mana efficiency | Coverage | Interception | Reaction usefulness |
|---|---|---|---|---|---|---|
| **Bolt** | Reference flight time and cast cadence; no current velocity ranking is known. | Concentrated, readable per-projectile commitment. | Reference aimed damage and delivered quantity per actual mana spent. | Precision rather than broad initial distribution; impact footprint still follows the actual selector. | Reference equal/unequal encounters; apply the real resolver rather than assume mutual deletion. | Finish a planned pair at a specific position. |
| **Heavy** | Test a slower arrival or larger cast commitment as the price of concentration; do not change both automatically. | Larger individual packet, not automatically more strength per mana. | Potential interception value, with a punishable miss or timing commitment. | Do not equate Heavy with a larger radius without the current definition. | Potential stronger-packet niche; any survivor/remainder is determined by the existing finite-strength rule. | Commit a substantial paid contribution to a chosen reaction site. |
| **Rapid** | Shorter firing intervals are distinct from higher projectile velocity. | Smaller independently paid packets where the current definition supports them. | Value from correction and frequent opportunities, not an assumed best damage-per-mana ratio. | Repeated aimed contacts over time rather than automatically broad simultaneous coverage. | Track cumulative spent strength and hostile remainder across every contact. | Fine ingredient dosing, without a free full reaction for every tiny contact. |
| **Spray** | Measure actual flight speed, emission duration, and arrival spread separately. | One cast budget distributed among its source-defined components. | Breadth and hit probability in exchange for concentrated yield, as a hypothesis. | Candidate broadest initial distribution; eligible affected cells remain whole cells. | Many contacts cannot imply unlimited hostile-strength removal. | Prime multiple cells only with the ingredient quantities each actually receives. |

### Measurement definitions

Separate **flight speed**, **command-to-useful-impact time**, and **legal firing cadence**. Compare per-projectile strength, total paid strength per cast, and strength per second separately. Mana efficiency must distinguish delivered ingredient quantity/mana, damage/mana, hostile strength neutralized/mana, and complete reaction cost. Recipe cost includes setup and failed or intercepted attempts, not only the finishing shot.

Coverage is the count/area of eligible whole cells receiving the applicable effect or a nonzero allocated ingredient quantity, plus duration where relevant. Broad coverage is not evidence of proportionally greater strength. Record size-specific hit results without normalizing away the established hurtboxes. Use authoritative measurements; rendered particles are not gameplay accounting.

### Finite-budget accounting — preserve the current resolver

For each payment, record cast/lineage identity, source element, mana spent, issued strength, issued quantity per ingredient, projectile components, interception outcomes, exact impact origin, selected cells, reaction consumption, and finite output allocation.

For a **recipe-authorized output budget B**, allocation to its children must not exceed B. Check each ingredient reservation/consumption against that ingredient's available quantity. Use documented conversion yields when they exist; do not equate raw damage, ingredient units, exposure, and reaction strength. Do not assume equal per-cell allocation or a 1:1 ingredient recipe.

Do not invent an interception formula such as “both projectiles vanish” or “always subtract the smaller from the larger.” Preserve the actual finite-strength resolution and any documented elemental reaction.

Whole-cell eligibility and finite allocation are separate concerns: a selected cell must not be circularly clipped around the original impact, but selecting more cells must not mint a fresh full output budget in each. Likewise, refreshing or relocating an effect cannot silently recreate spent inputs. [S1:24–27]

**Important:** Conservation of paid input is not a global cap on health damage across all victims. An area effect may legitimately damage several actors under the current contract. Do not turn this audit into a new per-field victim budget or change multi-target semantics.

## 4. Controlled balance experiments — all NOT_RUN

The following are exactly three experiments. Their numeric targets are **untested hypotheses**, not accepted balance constants. Integrate through the real authoritative code and existing harness, not a replacement chemistry model. Freeze the build and archive its baseline before running any variant.

### BAL-E1 — Steam crossing versus holding — recommended first

**Question:** Can a brief crossing remain affordable while holding a useful position becomes meaningfully dangerous?

**Prerequisites:** Obtain the real Steam rule and a separately adjustable existing exposure-rate coefficient. Without that coefficient, do not add a new system to make the experiment possible. The naturally paid baseline field must support the 240-tick dwell fixture without free renewal; otherwise that fixture is BLOCKED.

**Single change:** Multiply the existing coefficient by **0.80, 1.00, or 1.20**. Leave cost, recipe inputs/yields, radius, duration, allocation, stacking, exit/reset/decay, movement, hurtboxes and defenses unchanged.

**Fixtures:** Use the three actual size templates, an interior position and an outer portion of a selected hex outside the selection circle where such a portion exists, and ten paired seed repetitions. Generate real contact traces of **12/30/60/120/240 ticks**, equivalent to **0.10/0.25/0.50/1.00/2.00 seconds** at the documented target frequency. Reset state between trials; do not grant extra ingredient or effect lifetime to complete a trial.

Track contact ticks, exposure, first scald tick, and all Steam-attributed damage through natural status expiry, so delayed damage is not omitted.

**Numeric hypotheses and acceptance:** For every size/placement stratum, median damage from 30 contact ticks is at most **5% of maximum health**, with p95 at most **8%**; median damage from 240 contact ticks is **25–45%**. Longer matched contact must not produce less accumulated Steam-attributed damage.

Compare one 60-tick exposure with five 12-tick visits separated by 15 outside ticks. Apply the current reset/decay semantics. In the absence of an explicitly paid entry bonus, the repeated-entry result should not exceed **1.05×** continuous-contact damage; when the continuous result is zero, repeated-entry damage must also be zero. This is an abuse hypothesis, not permission to overwrite documented exit behavior.

**Decision:** Keep 1.00 when it passes. Otherwise accept only a passing coefficient nearest the baseline. Break an equal-distance tie by lower brief-crossing damage; if still tied or no candidate passes, make no production change. Every accepted candidate must preserve finite budgets, exact whole-cell behavior, replay and existing spawn protection. Human playtesting remains a separate NOT_RUN acceptance step.

### BAL-E2 — Equal-budget delivery-role comparison

**Question:** Do the families offer distinct useful opportunities without one being better on every measured axis?

Change only the chosen family inside each matched scenario. Use a gross mana cap equal to **20 current Bolt casts**, a **600-tick / 5-second** input window, **12 paired seeds**, and all three actual size templates. Use the same base element, source-legal aim policy, target motion and initial range within shared reach. Cast only complete legal casts; stop before exceeding the cap, report unused mana and normalize by actual spending. Record both window-end outcomes and all naturally completing already-paid outputs so delayed Heavy impacts are not hidden.

Use three role fixtures: a moving target with a stationary precision control; actual unequal-strength interception; and broad ingredient preparation/recipe completion. No invented interception ratios or projectile speeds are needed to run the source-defined encounters.

| Candidate niche | Untested numeric hypothesis relative to Bolt | Explicit price / guardrail |
|---|---|---|
| Heavy: concentrated interception | At least **1.10×** hostile strength neutralized per mana | At least **1.15×** arrival time at matched range |
| Rapid: frequent aim correction | At most **0.75×** the median interval between independently aimable legal emissions | Stationary-target damage/mana at most **1.05×** Bolt |
| Spray: broad preparation | At least **1.50×** distinct cells receiving nonzero paid ingredient per mana | Stationary single-target damage/mana at most **0.90×** Bolt |

Both benefit and price must hold in each size stratum on the paired-seed aggregate to validate that **proposed niche**. Report all paired outcomes and their range; twelve seeds do not establish population-wide balance. A zero Bolt denominator makes the ratio NOT_COMPARABLE, not infinite success. Failed targets falsify this proposal rather than prove the game is broken. This experiment authorizes no automatic buff, nerf, or family redesign.

### BAL-E3 — Paid-budget fan-out and fragmentation

**Question:** Does distributing the same paid opportunity create free reactions, free full-strength copies, or refresh amplification?

Request source-supported paid partitions of **1/4/16 components** and geometry yielding **1/7/19 selected cells**, holding the paid ingredient vector and recipe-authorized output budget fixed. These are fixture targets, not new family configurations or production radii. Unsupported combinations remain NOT_RUN; do not create a synthetic replacement resolver. Repeat each supported authoritative fixture **10 times** from the same input state.

**Numeric hypotheses:** Total child allocation / authorized budget must be at most **1.0**. Each ingredient's consumed / available ratio must be at most **1.0**, using the actual finite transformation rules. Integer accounting is exact; a proposed floating-point screen is **1e-6 relative error**, subject to the source's stricter arithmetic contract.

For fragmentation cases expected by the contract to be equivalent, use **0.95–1.05×** baseline single-target damage as a coarse sensitivity screen. Where the contract requires the same merged state, additionally require exact authoritative state/replay equivalence: the five-percent screen does not excuse deterministic state differences. Where thresholds intentionally change the recipe outcome, report that distinction instead of calling it duplication.

**Acceptance:** No new full budget per packet, cell, refresh, or lineage restart; no overspent ingredient; no lost remainder contrary to source rules; and no change to actual interception semantics. Never interpret legitimate multi-victim area damage as evidence that input strength was cloned.

## 5. Recommendation and strongest objection

Recommend the **source-locked Steam pilot**, not a reaction-system redesign. Its advantage is a falsifiable question tied to the one supplied behavioral requirement: accumulating scald. Its principal tradeoff is narrow coverage; it cannot establish balance for the other nine reactions or delivery families.

The strongest counterargument is that Steam may already be correct, or its real problem may concern accounting, stacking, geometry, feedback or counterplay rather than its coefficient. A coefficient sweep can hide such defects. Therefore inspect and measure first, fix no unobserved bug, and preserve the baseline when evidence does not justify a change.

## 6. Smallest integration slice

At a supplied current checkpoint, map the existing Steam definitions and authority functions, capture the baseline paid-input/contact/exposure trace, and execute BAL-E1 without modifying any other reaction or projectile family. Adopt one existing coefficient only if the trace and numerical criteria support it; **NO_CHANGE is a valid result**. Unsupported prerequisites are BLOCKED, not permission to add mechanics.

Acceptance requires a pinned source/build, reproducible baseline, accepted one-coefficient result or explicit no-change finding, preserved finite inputs and whole-cell behavior, unchanged spawn protection, matching replay results under the existing determinism contract, and no unrelated gameplay edits. Runtime/build approval belongs to the integrating task. [S1:5,164–173]

## 7. Checks and artifacts

The companion `HEX_BALANCE.experiments.json` is a standalone review specification, **not** a drop-in game configuration or executable harness. It contains the source fingerprint, all ten provisional reaction reviews, six comparison axes for all four families, three source-gated experiments, and integration prerequisites. `HEX_BALANCE.validation.json` records only local document/manifest checks.

Executed local checks: input file fingerprint; exact coverage of ten unordered first-four pairs; ten unique listed reaction identities; four correct family names; all six requested comparison axes; three unique experiments; every runtime experiment marked NOT_RUN; tick/second arithmetic; unknown implementation/build fields kept unknown; and source file unchanged while generating the handoff.

**NOT_RUN:** source-level implementation audit; Godot execution; Windows build; authoritative replay; multiplayer/eight-player operation; all three experiments; and human playtesting. No performance or balance measurements are claimed.

## Integration handoff

**Source basis:** S1 assignment only; SHA-256 above; authoritative build unknown. **Recommended contribution:** source-locked Steam exposure pilot with at most one existing coefficient change after acceptance. **Artifacts:** this Markdown report, the JSON review/experiment manifest, structural-validation report, and a ZIP containing those three files. **Proposed contract changes:** none; incompatible provisional roles are held/discarded, not implemented. **Checks:** local structural checks executed; all engine/build/replay/playtest checks NOT_RUN. **Unresolved risks:** missing contract/source, inferred pair/name associations, unknown costs/yields/stacking/interception/geometry, and untested target bands. **Next slice:** baseline Steam trace plus BAL-E1 with unchanged other mechanics; accept a measured coefficient or explicit NO_CHANGE, never an unsupported runtime claim.

### Source references

S1 is the original user attachment, `Pasted text.txt`, identified by the SHA-256 in section 1. Relevant original line ranges: 5–19 (assignment and evidence); 21–33 (boundaries and recommendation); 112–127 (BALANCE scope); 160–173 (handoff and no-publication boundary). The assignment fingerprint is not a substitute for the missing authoritative checkpoint.

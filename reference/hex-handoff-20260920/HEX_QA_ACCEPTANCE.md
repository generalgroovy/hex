# HEX QA — Independent adversarial acceptance pack

**Task:** QA only. **Revision:** QA-PROPOSAL-1, 2026-09-20. **Execution status:** all twelve game tests are **NOT_RUN**. No implementation patch, executable test code, repository change, or runtime acceptance is included.

## 1. Source basis and evidence limits

The only received file is `Pasted text.txt`: 173 lines, 11,044 bytes, upload ID `file_00000000a73081f4a01b57f86c86cafc`.

Attachment SHA-256: `11c869b8c4125c56cecdfb21009f25dc91c41cad591bdde80ef9d3cbc04aecb2`.

This hash identifies the assignment brief, **not a game source revision or build**. Game commit, checkpoint, working-tree changes, build identifier, Godot version, and test-harness revision are **UNKNOWN**. No separate design contract, active implementation queue, checkpoint, game source, harness, logs, profiles, map geometry, or captures were supplied.

**Observed implementation facts:** none; no game implementation or run was inspected.

**Documented intentions/boundaries:** the brief specifies Godot authority, Windows targeting, a 120 Hz simulation target and eight-player target; continuous movement/aim/projectile flight; exact-origin selection of whole affected hexes; eligible chemistry at stations/spawns while preserving spawn protection; finite paid strength and ingredient quantities; Bolt/Heavy/Rapid/Spray; and three shared size templates. These are requirements, not demonstrated capabilities. Source: brief lines 21–30.

**Reported evidence, not independently observed:** the brief says a localhost run reached first-round play, late-guest replication and exact-actor reconnect but not the later lifecycle milestones before its watchdog (lines 37–49). It also mentions retained-event evictions and unencodable diagnostics/cues without supplying the records (line 64). Neither statement establishes a root cause.

**Hypotheses:** the failure mechanisms named in the cases below are adversarial possibilities, not findings about the current implementation.

**Proposed contribution:** the twelve acceptance specifications below and their evidence record. No gameplay or contract changes are proposed. Added test schedules and human-review thresholds are proposed QA criteria, not existing product promises.

## 2. Recommended solution

Use one **source-pinned acceptance pack**, initially integrating only QA-01, QA-02 and QA-04 around a small geometry fixture and a paid-resource ledger. Reuse the same fixture data and recorded authoritative events in later replay, multiplayer and visual checks.

The principal tradeoff is deliberate: exact expected outputs remain blocked until the integration owner supplies the current rules. This is less immediately executable than guessing a selector or subtraction formula, but avoids validating an invented version of the game.

The strongest counterargument is that a source-pinned oracle can reproduce the implementation's own bug. Expected cell sets, resource allocations and transition outcomes must therefore be calculated independently from the approved written rules and hand-reviewed fixture values—not obtained by calling the production helper under test. If the written rule and implementation disagree, record the disagreement; do not silently redefine the oracle to match the code.

## 3. Required integration inputs and fixture binding

Supply the current design contract, active queue and checkpoint, plus the actual harness and the relevant source excerpts identified below. Actual filenames are unknown; none are invented here.

| Binding | Exact information required | Main cases blocked |
|---|---|---|
| P — Provenance | Source commit and any local diff; build/configuration identifiers; Windows/Godot versions; map and harness revisions | All |
| G — Geometry | World-to-hex transform; cell-selection predicate; edge/vertex tangency and zero-radius policy; collision-origin precision/quantization; actor-to-cell/hurtbox contact rule | 01–04, 12 |
| R — Resolution | Per-family payment/pulse rules; allocation and conversion units; unequal interception and tie rules; simultaneous reaction ordering; exposure, stacking, decay and expiry rules | 04–07 |
| N — Lifecycle | Snapshot/delta boundary; reconnect identity/grace/disconnected-actor policy; round transitions, persistent versus round-scoped state; administrative-release postcondition and watchdog deadlines | 08–10 |
| E — Events/performance | Event classes and retention limits; eviction/recovery policy; actual unencodable examples; target workload, hardware and accepted timing/memory bounds | 11 |
| V — Presentation | Current Wellspring geometry, Steam captures, effects settings, layer rules, bindings and the three body templates | 02–03, 07, 12 |
| H — Harness | Existing fixture/reset/step/input/assertion interfaces, multiplayer fault hooks and evidence capture facilities | All automated cases |

**Binding discipline.** Each case starts from a reset fixture. `T` is its first authoritative simulation step; actions are tick-indexed, not timed with arbitrary sleeps. Bind every symbolic value to a concrete value in a versioned fixture before execution: world coordinates, radii, legal strengths, quantities, action identifiers, expiry ticks and deadlines. A missing binding leaves the case **NOT_RUN**; it is not permission to decide the expected result after seeing the output.

`o` is the independently established impact point, `r` the configured radius, and `S(o,r)` the independently approved selected-cell set. `epsilon` is a nonzero boundary perturbation that survives the build's supported precision and quantization; record the actual transmitted values. `A > B > 0` denotes legal strength values. `n >= 2` is a pinned exposure window supported by the fixture's lifetime. `C` is the relevant configured retention capacity. `g` is the documented reconnect grace boundary. Deadlines require both an authoritative-tick limit and a monotonic wall-clock limit so a stopped simulation cannot defeat the watchdog.

Three especially important unknowns cannot be filled by intuition: whether hex selection uses centers or polygon intersection; what happens at exact tangency; and whether unequal interception is subtractive. The brief does not specify them.

## 4. Twelve acceptance cases

### QA-01 — Exact impact origin and hex-selection boundary

**Status:** NOT_RUN — requires P/G/H. **Gates:** unit, replay. **Basis:** brief lines 24–25.

**Setup:** Bind an off-center impact `oA` and a second point `oB` inside the same hex such that independently calculated sets differ at a chosen radius. For an adjacent eligible cell, establish its selection threshold `rStar`. Prepare edge-tangent, vertex-tangent and zero-radius variants. Include a translated geometry fixture crossing the coordinate origin where supported.

**Exact input sequence:** Reset before every variant. At `T`, submit one supported projectile action with a trajectory whose next authoritative collision is the pinned point. Advance through that collision. For `oA`, execute radii `rStar-epsilon`, `rStar`, `rStar+epsilon`, then `0`. Execute the corresponding discriminating-radius shot at `oB`. Repeat a trajectory whose sampled endpoints lie on opposite sides of the impact surface, so its true contact differs from either endpoint. Replay each identical input trace three times.

**Expected authoritative state:** The selected set equals the independently enumerated set for the actual collision point and each radius. The selector must not substitute the cell center, caster position, previous projectile position or end-of-step position. Tangency and zero-radius results match the bound rule; they are not guessed here. The two deliberately discriminating within-cell impacts yield their respective different sets.

**Expected visible result:** The impact is anchored to the real contact location; the gameplay footprint matches the selected cells. Flight is not snapped from cell center to cell center. Decorative particles are not used as the coverage oracle.

**Failure detected:** Origin snapping or stale origin, collision overshoot, incorrect negative-coordinate conversion, boundary rounding/tie defects and a radius test that accidentally exercises the same quantized input three times.

### QA-02 — Whole-cell effect, without a second circular clip

**Status:** NOT_RUN — requires P/G/R/V/H. **Gates:** unit, replay, human-playtest. **Basis:** brief lines 24–25 and 30.

**Setup:** Select a cell with two valid actor-probe placements: one inside the generating circle and one outside it, both qualifying for that same cell under the actual hurtbox/contact rule. Add a control placement qualifying only for an unselected cell. Use identical actor state and the same nonzero allocated cell effect. Bind placements separately for all three size templates; do not assume center-only actor sampling.

**Exact input sequence:** For each placement and size, restore the fixture, activate the identical field at `T`, and evaluate the first `n` active exposure steps with no movement. In a separate reset, traverse the two selected-cell placements over exactly 12 input steps, then cross into the control cell over 12 more; record actual continuous positions and contacted cells. Use a collision-clear legal route, or retain NOT_RUN for that variant.

**Expected authoritative state:** The outside-circle placement is not rejected once its cell is selected. Identical placements in the same cell follow the same per-cell application rule, subject only to documented actor modifiers. The unselected-only control receives no field effect. Crossing behavior follows the existing size-based contact rule, without movement snapping or a radius recheck. This does not require equal strength in different selected cells.

**Expected visible result:** Coverage communicates the complete selected cells, including their outside-circle portions; entry/exit remains understandable. Harmless particle overhang is distinguishable from the hazard footprint.

**Failure detected:** Circle clipping after selection, accidental center-only hurtbox tests, hidden hazardous corners, visible-but-inactive cell portions and cell-stepped movement.

### QA-03 — Chemistry at Wellspring stations and protected spawns

**Status:** NOT_RUN — requires P/G/R/N/V/H. **Gates:** unit, replay, human-playtest. **Basis:** brief line 26.

**Setup:** Bind eligible cells at an actual station, spawn and ordinary ground. Record any legitimate terrain differences. At the spawn, prepare otherwise equivalent protected and unprotected actors using the existing protection rules; bind the precise protection expiry tick `e`.

**Exact input sequence:** Reset for each ground/protection variant. At `T`, apply the same legal first-four reaction input with the same paid budget and local geometry. At `T+1`, submit the existing station interaction in the station variant. Observe ground chemistry and actor state through the active window. In independent expiry fixtures, evaluate exposure at `e-1`, `e`, and `e+1` without further protection-granting actions.

**Expected authoritative state:** Eligible station/spawn ground participates in chemistry; it is not silently excluded as a chemistry-free hub. The ground effect and actor protection are evaluated separately. Actor damage/status restrictions and protection expiry match the existing policy exactly. Station interaction does not introduce an undocumented exception to ground eligibility. Do not require identical damage across different protection states.

**Expected visible result:** The field remains legible in station/spawn space. Protected-actor feedback, where present, must not imply that the ground is safe for unprotected players. Existing station information remains readable.

**Failure detected:** Blanket safe-hub masking, bypassed or accidentally renewed spawn protection, off-by-one expiry and station UI state changing world chemistry authority.

### QA-04 — Finite strength and ingredient accounting across coverage

**Status:** NOT_RUN — requires P/G/R/H. **Gates:** unit, replay. **Basis:** brief lines 27–28 and 125.

**Setup:** Bind legal configurations for Bolt, Heavy, Rapid and Spray. For each family, prepare a one-cell and a multi-cell footprint with the same accepted payment sequence. Specify all pulses, split projectiles, deposits, reactions and terminal balances. Bind zero-quantity and insufficient-quantity controls using the actual acceptance/payment rules.

**Exact input sequence:** Reset; submit the pinned cast or finite trigger interval at `T`; release at the exact fixture tick. Permit the complete descendant/reaction chain to resolve, then advance one additional step. Repeat with the larger footprint and unchanged accepted inputs/payment. Repeat after reducing one required ingredient to zero, then just below the accepted requirement. Record balances after every resolution transaction, not only at the end.

**Expected authoritative state:** Independently reconcile each paid-strength lineage and each ingredient quantity with residual balances, transfers, documented consumption/conversion and losses. One budget may be split; it may not be copied at full value into each selected cell or each descendant. Balances cannot become negative. Insufficient payment follows the declared reject/partial-resolution policy, not an invented one. Apply actual conversion coefficients; do not add mana, damage, duration, strength and ingredient units together. Persistent exposure samples are not automatically extra ingredient expenditure.

**Expected visible result:** All selected cells remain affected, but wider coverage does not create unfunded power. Feedback, projectile/reaction presence and any resource display agree with the authoritative allocation.

**Failure detected:** Per-cell strength cloning, Spray/Rapid pulse undercharging, double-consumed ingredients, free reactions, underflow, and a false conservation test that double-counts transfers or treats repeated damage as resource creation.

### QA-05 — Unequal interception, residual ownership and collision chains

**Status:** NOT_RUN — requires P/R/G/H. **Gates:** unit, replay. **Basis:** brief lines 27, 125 and 149.

**Setup:** Bind a supported interception path, two legal strengths `A > B > 0`, exact trajectories, the expected residual/reaction allocation and a downstream target. Include equal-strength and reversed-strength controls. Parameterize across applicable delivery-family pairings; record unsupported combinations rather than silently skipping them.

**Exact input sequence:** At `T`, launch the opposing projectiles so the fixture resolves their encounter at `T+k`. Sample immediately before and after resolution. In a separate reset, collide the stronger projectile with two weaker inputs on successive pinned collision ticks, tracking the same lineage into the second encounter. Repeat with `A=B`, with the strengths swapped, and with an exhausted residual reaching the next encounter.

**Expected authoritative state:** Survivor, remaining strength, consumed quantities and any reaction match the independently bound resolver. The second encounter uses the actual residual, never the original strength. A spent lineage cannot later damage the downstream target. No unit is allocated simultaneously to a survivor and an unfunded reaction. The brief alone does not establish that the stronger projectile survives: `5-2=3` is an oracle only if subtractive resolution is actually specified.

**Expected visible result:** The surviving projectile, reaction or mutual disappearance matches authority; no destroyed projectile delivers a later ghost hit. Impact/depletion feedback corresponds to the committed result.

**Failure detected:** Unconditional mutual deletion, resetting residual strength, negative strength, phantom post-interception hits and duplicated reaction/survivor budgets.

### QA-06 — Simultaneous reactions competing for finite ingredients

**Status:** NOT_RUN — requires P/R/H. **Gates:** unit, replay. **Basis:** brief lines 116–125 and 149.

**Setup:** Parameterize isolated checks over all ten unordered Water/Earth/Fire/Air pairs, including same-element pairs, with expected identities bound from the current reaction table. Separately prepare a contested cell where simultaneous Water, Earth and Fire inputs compete for a quantity that cannot fund every candidate reaction.

**Exact input sequence:** Reset and resolve each pair at the same pinned tick. Then reset to the contested fixture and deliver the three inputs at `T+k`; replay that exact trace three times with stable event identities. Where the harness can vary irrelevant candidate-container enumeration, exercise all six enumeration orders while preserving the declared scheduling order. Finally run distinct counterexamples with one impact moved to `T+k-1`, and then `T+k+1`.

**Expected authoritative state:** Identical complete inputs produce the same committed result. The documented conflict/tie rule chooses affordable outcomes; ingredient debits occur once, with no negative inventory or unfunded second product. Same-element input may react only if that path is supported by the bound rule. Changed arrival ticks or order-sensitive command identities are different inputs and need not yield the same chemistry. No arbitrary universal commutativity requirement is imposed.

**Expected visible result:** Presented reaction identities and transitions correspond to committed products, not uncommitted intermediate candidates. No double field appears for one consumed budget.

**Failure detected:** Double-spending simultaneous inputs, container-order dependence where order should be irrelevant, nondeterministic replay, missing same-element cases and false tests that require legitimate order-dependent chemistry to commute.

### QA-07 — Accumulating Steam exposure, re-entry and render cadence

**Status:** NOT_RUN — requires P/R/G/V/H. **Gates:** unit, replay, human-playtest. **Basis:** brief lines 72–74, 123 and 149.

**Setup:** Bind a Steam field lifetime, active ticks, per-actor exposure/stacking rule, decay and expiry. Prepare adjacent selected cells belonging to that field, plus a truly outside placement. Pin `n` so all scheduled windows are valid; include a second overlapping field only with a declared overlap rule.

**Exact input sequence:** Reset for each schedule. A: remain exposed for `2n` steps. B: expose for `n`, leave for `n`, re-enter for `n`. C: remain continuously exposed while crossing the same field's adjacent-cell seam at the midpoint. D: apply the documented overlapping-field fixture for `n` steps. Replay each identical tick-input trace at 30, 60 and 144 presentation frames per second; at `T+n`, pause presentation for 0.1 seconds without intentionally changing authoritative simulation inputs or frequency. Continue through expiry plus one step.

**Expected authoritative state:** Exposure, damage/status thresholds, decay, overlap and expiry match the bound tick rules. Re-entry is not assumed to equal continuous exposure when decay exists. Render count, duplicate render callbacks and visual cell seams cannot create extra applications outside those rules. Compare state at matching authoritative ticks, not wall-clock instants. Steam is evaluated as accumulating scalding exposure, not as a newly invented concealment mechanic.

**Expected visible result:** Continued exposure and expiry are understandable; targets remain trackable through/around Steam. Feedback matches the actual exposure cadence rather than rendering frequency.

**Failure detected:** Per-frame damage, seam double-application, undocumented overlap multiplication, re-entry reset exploits, post-expiry exposure and visibility falsely suggesting a smoke screen.

### QA-08 — Late join across a snapshot/delta boundary

**Status:** NOT_RUN — requires P/R/N/H. **Gates:** multiplayer, replay. **Basis:** brief lines 23, 39 and 149.

**Setup:** Start with seven total player actors, including the host actor, and admit an eighth. Bind an active field, a projectile due to disappear after the snapshot cut, and independently recorded server state at the relevant tick/version.

**Exact input sequence:** Create the field at `T`; begin the guest's baseline at `T+1`; commit the projectile's destruction at `T+2`; admit/apply the guest baseline at the next bound admission point. Exercise baseline/delta overlap using supported harness hooks while the server continues to advance. Repeat with a field expiring immediately before the baseline cut and immediately after it. Do not inject packet reorderings that the transport contract makes impossible; bind faults at a supported boundary.

**Expected authoritative state:** Joining adds exactly one legitimate actor without resetting existing world state. Once synchronized to a named server version, the guest's replicated authoritative fields match that version, including resource quantities, effect expiry and ownership. Post-cut mutations apply once; expired/transient state does not resurrect. Old one-shot gameplay effects are not replayed as new actions. Client prediction, if present, is not a second authority.

**Expected visible result:** The guest sees the current footprint, roster and relevant statuses without stale projectiles, doubled formation/damage cues or replayed historical bursts. Any transient presentation tolerance must be declared before the run.

**Failure detected:** Snapshot/delta gaps, duplicate delta application, incorrect as-of comparisons, resurrected effects and granting replicated state gameplay authority.

### QA-09 — Exact-actor reconnect after a committed, unacknowledged action

**Status:** NOT_RUN — requires P/R/N/H. **Gates:** multiplayer, replay. **Basis:** brief lines 23, 39 and 149.

**Setup:** Use an eight-player session. Record actor A's stable identity, resources, cooldowns, protection and exposure. Bind reconnect grace `g`, command deduplication policy and the disconnected actor's actual simulation policy.

**Exact input sequence:** At `T`, submit a valid paid action; verify its server commit, but prevent its acknowledgement reaching that client. Disconnect at `T+1`. Continue the world for a pinned interval inside `g`; reconnect with the same authorized player identity and resend the same already-accepted action identifier once. Attempt delivery of one queued message from the old session via the supported harness. In separate resets, reconnect immediately before, exactly at and immediately after the grace boundary.

**Expected authoritative state:** Within the permitted exact-actor window, the same actor is restored once. The committed action is not charged or executed twice. Resources, cooldowns, exposure and protection equal the legitimate current state under the disconnected-actor policy—not an invented frozen snapshot or fresh-spawn reset. Superseded-session traffic cannot control a replacement session. At and after grace expiry, follow the declared identity/admission rule rather than assuming indefinite actor preservation.

**Expected visible result:** Exactly one roster entry/body corresponds to the returning actor. Current resources and effects are shown without a phantom fresh spawn, duplicated spell or misleading protection reset.

**Failure detected:** Duplicate actors, reconnect refunds, invulnerability/cooldown exploits, stale-session control, replayed paid commands and grace-boundary off-by-one errors.

### QA-10 — Full lifecycle through Hearth, round two and release

**Status:** NOT_RUN — requires P/R/N/H. **Gates:** multiplayer, replay, performance. **Basis:** brief lines 39–49 and 149.

**Setup:** Bind legal lifecycle actions, phase-entry signals, per-phase tick/wall deadlines and the authorized administrative-release postcondition. Track which state persists across rounds. Build a first-round roster with one late join and one subsequent exact-actor reconnect, never exceeding eight players.

**Exact input sequence:** Enter first-round play; execute QA-08 and QA-09's admitted-player paths; finish the round legally. On the first legal input tick after the eligible phase entry, send Return to Hearth once. At the next legal Hearth phase, send the existing ready/start actions for round two. In round two, have every admitted actor send 12 steps of collision-clear movement and one legal paid action. Finish round two and issue the authorized release action. In separate fault variants, replay one already-consumed transition command and one old-round gameplay event at round two's second active tick.

**Expected authoritative state:** Every transition reaches the documented phase within both deadlines. Each admitted actor actually participates in round two; a menu or connection alone is insufficient. A transition is not committed twice; stale round-scoped events do not change the new round. Persistent Wellspring/session state survives or resets exactly as documented—do not assume everything clears. Administrative release reaches its named postcondition; process exit is not invented as a requirement.

**Expected visible result:** Hearth and round-two states are usable and agree with server phase. No permanent loading overlay, ghost old-round field or disconnected-looking active participant remains. Release feedback matches the real outcome.

**Failure detected:** The lifecycle gap reported in the brief, duplicate/stale transitions, partial roster reactivation and a watchdog that never fires because it counts only stalled simulation ticks. Capture the earliest demonstrated divergence; log silence alone is not a networking diagnosis.

### QA-11 — Event pressure, eviction and unencodable records

**Status:** NOT_RUN — requires P/R/N/E/H. **Gates:** performance, multiplayer, replay. **Basis:** brief lines 23, 53–64 and 149.

**Setup:** Bind an eight-player, legally funded workload using the four delivery families, active chemistry, snapshots and lifecycle activity. Bind retention capacity `C` separately for each relevant event class and the real diagnostic/cue records mentioned by the checkpoint. Predeclare Windows hardware, accepted performance bounds and recovery behavior.

**Exact input sequence:** Replay a fixed legal workload for 12,000 authoritative steps, checking the retained-event boundary at `C-1`, `C` and attempted `C+1`. Delay one client's consumption past the retained-history horizon and exercise the documented recovery path. In separate resets, submit one captured unencodable diagnostic and one captured unencodable cue at the actual codec boundary. Repeat the same accepted-input trace without induced client lag. Finish with a drain period exceeding the bound effect and retention lifetimes. Use a wall-clock watchdog throughout. If the trace never reaches a specified pressure condition, that condition is untested, not passed.

**Expected authoritative state:** No paid gameplay event silently disappears or applies twice. Legitimate retention evictions are counted/classified and preserve required state through the declared retention/resync mechanism; zero evictions is not the acceptance rule. Classify an unencodable record before deciding its permitted handling: authoritative event, gameplay-required cue, or optional diagnostic. Optional diagnostic failure may be contained and reported; gameplay-required information cannot simply be discarded as cosmetic. Equivalent gameplay inputs yield equivalent authoritative outcomes despite a slow observer, within the declared session policy.

**Expected visible result:** Required hazards, damage/status feedback and phase transitions remain truthful. A recovered client neither bursts through expired cues nor misses a still-active hazard. Any permitted cosmetic reduction does not change simulation outcomes.

**Failure detected:** Gameplay loss under queue pressure, unsafe eviction, codec failure taking down snapshots, silent loss of required cues, unbounded backlog and starvation. Record tick p50/p95/p99/max, simulation debt, snapshot preparation/encode time, queue peaks, evictions by type/reason, codec failures, resyncs and memory before/after drain. The 120 Hz target implies about 8.333 ms between scheduled steps; that is not a fabricated measured result or a complete acceptance budget.

### QA-12 — Reduced-effects Steam readability and whole-cell truth

**Status:** NOT_RUN — requires P/G/R/V/H and human reviewers. **Gates:** human-playtest, replay. **Basis:** brief lines 72–76, 30 and 149.

**Setup:** Use actual full/reduced-effects modes, three representative current terrain backgrounds and all three body templates, with up to eight actors. Include a connected Steam footprint with selected portions outside the generating circle. Bind authoritative formation/active/warning/expiry/disappearance timestamps. If a mode or phase is not implemented, record that as a blocker rather than presenting a mock-up as evidence.

**Exact input sequence:** Replay the same tick-indexed scene in 12 viewing conditions: two effects modes × three terrains × normal color/grayscale. Each clip contains all bound phases, a character crossing between affected and unaffected ground, and an actor behind the field. Repeat the scene as needed to cover every body template. Have five reviewers identify marked safe/danger probes, track the actor and describe what Steam does; randomize order and hide authoritative overlays until scoring. Compare server-state traces for the two effects settings.

**Expected authoritative state:** Effects settings and color presentation leave selected cells, resources, exposure and expiry unchanged. A presentation setting is not gameplay authority.

**Expected visible result:** Whole-cell coverage, active danger and expiry remain distinguishable without hue alone; actors stay trackable. Steam communicates scalding rather than concealment. Proposed smoke-gate criteria: no false-safe classification at mandatory affected probes, and at least four of five reviewers identify scalding rather than concealment in each effects mode. Record errors by condition, not only an aggregate score. This is a small human smoke gate, not a claim of population-wide accessibility validation.

**Failure detected:** Reduced effects hiding danger, color-only signals, opaque Steam concealing targets, false circular coverage, seams misread as safe lanes and visuals outliving or ending before authoritative danger without an understandable distinction.

## 5. Evidence and result record

For every attempted case, retain the case/variant ID; source/build/configuration/fixture/harness identifiers; concrete inputs and tick schedule; the independent expected result and its source; actual authoritative checkpoints; component-level state differences; relevant event/resource lineage; and final status with reason. Multiplayer evidence also needs actor/session/round identifiers, sender/receiver tick or sequence, monotonic timestamps and each phase deadline. Visual cases require the actual clips and per-condition human judgments.

Compare like-for-like authoritative state at the same tick/version. Use documented canonical fields; exclude presentation-only counters, not gameplay state merely because it differs. Preserve raw values behind hashes so a mismatch can be localized and the production hash implementation is not its own oracle. Do not require client-local transport counters or prediction internals to equal server state.

**Result policy:** NOT_RUN remains the status for every game case in this delivery. Missing inputs, unsupported fault hooks or unreached workload conditions cannot be reported as PASS. A failed test establishes only its evidenced discrepancy, not a guessed root cause. Any subsequently discovered contract conflict requires an explicit decision by the integration owner.

## 6. Concise integration handoff

**Source basis:** only the received 173-line `Pasted text.txt`, identified above. No game checkpoint/build is known. Assignment requirements: lines 145–158; completion boundaries: lines 160–173.

**Recommended contribution:** one independently derived, source-pinned twelve-case acceptance pack. Integrate geometry and budget cases first, without changing gameplay to make an unapproved oracle pass.

**Artifacts produced:** this Markdown acceptance specification, fixture-binding register and evidence/result record. No test code or patch.

**Proposed contract changes:** none. Test schedules and the stated human smoke-gate thresholds are proposals for acceptance review, not asserted existing contract clauses.

**Checks executed:** read the complete supplied brief; checked conversation-file inventory; verified attachment byte/line count and SHA-256; checked the specification for twelve unique case IDs, explicit NOT_RUN status and all required case fields. These are document/provenance checks, not game tests.

**NOT_RUN checks:** all twelve game cases, including unit, replay, multiplayer, performance and human-playtest execution; Windows build/runtime acceptance; all visual capture review.

**Unresolved risks:** stale/missing authoritative source; unspecified selection/tangency and actor-contact semantics; unknown allocation/interception/exposure rules; unknown reconnect/round persistence and deadline rules; unprovided event/codec evidence; no actual harness or visual modes to verify.

**Smallest next integration slice:** bind P/G/R/H and implement QA-01, QA-02 and QA-04 in the existing harness. Acceptance requires independently enumerated selected-cell sets including exact boundaries, a valid outside-radius placement affected inside a selected cell with an unselected control unaffected, and reconciled finite strength/ingredient budgets for one-cell versus multi-cell coverage across each supported delivery family. Run each identical trace three times; retain exact inputs and matching authoritative outcomes. Missing or disputed rules block acceptance rather than being chosen opportunistically. Only then advance to the multiplayer lifecycle and pressure cases.

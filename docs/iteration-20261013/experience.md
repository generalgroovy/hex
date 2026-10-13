# October 13 experience evidence and next action

Current state: canonical source is frozen at **`p61-500be306a26a`**. Root reports
clean Full validation: **265 suites / 7,572,978 assertions / zero failures and
empty stderr**. The [fresh package](delivery-500be/package.json),
[archive verification](delivery-500be/delivery-files.json) and
[exported-terrain gate](delivery-500be/terrain/terrain-pack.json) have passed.
The [untouched portable lifecycle retry](portable-lifecycle-500be-passed-b/receipt.json)
passes all five cases, with twelve Fire and twelve all-six Mantle admissions,
zero refusals, empty stderr and preserved package/preferences. The linked
[independent delivery review](delivery-review-500be/review.json) passes 3,784
checks. This is the current qualified local portable; sustained foreground
acceptance remains open. T7 complete-step instrumentation, the bounded paid-startup
witness with an honest unknown fallback, and the protection-only lower HUD row
are applied. Their focused/native evidence below remains scoped to the exact
sources and workloads tested; Full and package qualification are separate.
Preserve commit `1068759`, the qualified `p60-1e084a50a029` portable, original art,
personal profiles and all failed evidence.

The [prefix-key experiment](prefix-key-shape/README.md) and
[crowded paid-ground trail preflight](trail-crowded/README.md) are **withdrawn**:
correctness passed, but useful active-work savings did not survive order/tail
controls. The [terminal coach probe](coach-terminal/README.md) did not reproduce
the suspected terminal edge, so it establishes no coach defect and justifies no
fix. The recent sustained foreground setup expired without Start and collected
no gameplay; it does not replace the separate admitted `500be` diagnostic.

The remapped-shortcut hint draft remains unapplied. Its
[native menu/guide fit gate](remap-guide-hints/README.md) passes 1,192 checks across
12 contexts and 36 PNGs with empty stderr. Source, hash and sampled visual
review approve root integration after the frozen-source probes; the actual
supported-remap/paid-input regression still requires execution after application.
Next are root's functional gates for the ignored terminal-audio reproduction and
seven-interval simulation attribution in
[Technical's ledger](technical.md#next-diagnostic-prompt-split-movement-and-cast-work).
Root has authorized these isolated diagnostics and the unapplied hint patch;
canonical source stays frozen.
No new cache, balance change or runtime edit is authorized by this document.
Physical-input feel, listening, authored
animation completeness and human counter recognition remain acceptance gaps,
not automatically source defects. Root owns all engines/integration; Experience
owns this ledger, with Gameplay correctness and Technical cost/lifecycle review.

The initial ranking, alternatives and implementation checkpoints below are
**historical decision/evidence records**. Later executed results supersede their
then-pending wording; they are retained to explain choices and failed attempts,
not to reopen completed or rejected tasks.

## Historical initial ranking

| Rank / item | Evidence classification | Smallest next action | Owner / independent reviewer |
| --- | --- | --- | --- |
| P1 E13.1: truthful paid cast/readiness timing | Confirmed source defect: both HUD startup and cooldown fractions use authored base durations, while authority commits modified durations | Compare remaining-time-only display with an actual-admission presentation witness; implement only the reviewed bounded choice, including visible/hidden HUD and world startup telegraph | Experience; gameplay correctness, technical cost/lifecycle; root Bootstrap hook |
| P2 E13.2: expensive unchanged spell-card submission | Measured lead, not an established optimization: previous admitted warm HUD means 1.806/1.910/1.890 ms; layout misses do not explain them | Complete T7 attribution and observer-cost gate first; then at most four retained complete-card commands with exact painter-order proof, or reject the experiment | Experience; technical measurement/CanvasItem review and gameplay dynamic-state review |
| P2 E13.3: actual input and action readability | Acceptance gap, not a newly demonstrated source defect: prior native images and synthetic input routes do not prove physical-controller feel, listening or fast-projectile counter recognition | One bounded real-device and paid-motion acceptance matrix; change only a reproduced failure | Experience fixture/observation; gameplay route/counter review and root execution |

No speculative movement speed, new menu, extra tutorial paragraph, new asset or
protocol migration is justified by this audit. These three candidates cover the
most useful next experience work; lower-ranked observations remain checks.

## Historical E13.1 proposal — paid startup, cooldown and world cue

### Source ownership and defect

1. `src/sim/combat/combat_system.gd:99` samples perk and status startup before
   Flux payment at line 102. `_begin_cast` at lines 396–404 commits only the
   resulting remaining timer. The cast cannot be retimed by a later movement,
   status or resource change. The release independently samples cooldown at
   lines 421–426. This is existing intended combat behavior.
2. `src/sim/entities/player_state.gd:69` stores pending wire and remaining ticks;
   its canonical values include those fields at lines 519–520. The
   `cast_started` event at `combat_system.gd:111` contains entity and wire, not
   the committed total. Its snapshot codec also carries no total:
   `src/net/session_snapshot.gd:809–810` and `:880–881`.
3. `src/presentation/compact_combat_hud.gd:387–401` divides that actual remaining
   startup by `ability.startup_ms`. The paid hidden-layer cue reuses the same
   fraction at lines 443–459. Cooldown uses the analogous base denominator at
   lines 407–412, although its displayed seconds are already derived from the
   actual remaining cooldown. A shorter startup begins partly filled; a longer
   startup can stay clamped empty before the base-sized final segment.
4. `src/app/bootstrap.gd:2188–2204` repeats the same denominator for the world
   startup cue. `foundation_spell_presenter.gd:198–225` uses it for effect age,
   shape and intensity. The same assumption also informs authored-pose
   selection at `fullbody_cast_presenter.gd:365–378` and additive arm phases at
   `pixel_cast_hands.gd:14–17`. Those pose paths are related scope to review,
   not permission to flatten or replace animation arbitrarily.
5. Existing `tests/unit/test_compact_combat_hud.gd:415–459` seeds authored base
   timers and asserts the same quotient. It proves clamping/purity but cannot
   prove that real paid modified casts display honestly.

Current-perk recomputation is not a fix: payment can cross the high/low Flux
threshold. Nor is the first timer seen when opening a view an admission total.
Network events can arrive after several ticks, and a view can open mid-cast.

### Alternatives to review before implementation

| Choice | Information provided | Cost / correctness boundary |
| --- | --- | --- |
| A. Remaining-time-only | Use authoritative remaining seconds in the existing status area; retain the active casting border/identity and existing cooldown countdown; do not paint an ungrounded completion fraction. No extra explanatory prose or panel | Universally valid for offline, replica, replay, late view and changed perk conditions; gives up a relative-completion fraction. Unknown/invalid clocks must not advertise readiness. Positive remaining ticks should not round to an apparently ready 0.0 s |
| B. Actual-admission presentation witness | Preserve fractional startup only when an actual synchronous admission was witnessed; otherwise use A. Continue reading remaining ticks live | Can preserve useful anticipation without adding authority fields, but creates bounded lifecycle and mixed known/unknown paths. Must never promote a late snapshot event or first observed timer to a total |
| C. Replicated committed-total field | Exact startup/cooldown fraction available after reconnection | Widening canonical values, snapshots, replay and compatibility for a UI fraction is currently disproportionate. Defer unless user-information tests show A/B inadequate |

**Provisional smallest option is A; B remains under peer challenge.** A does not
mean a full ready-looking bar while casting. Keep the active-cast shape and omit
the fractional fill. Any remaining-time number replaces content in the existing
status space, rather than adding a row. Cooldown retains its existing numeric
countdown. Timing or status wording must not imply a new gameplay rule.

B has one promising real observation boundary: the host/offline loop ingests
`world.combat_events` at `bootstrap.gd:1223` immediately after each completed
step and before the next catch-up. A matching `cast_started` event plus the
same-step pending state can witness admission, subject to checking all later
same-step interruption/mutation paths. In contrast, client ingestion at
`bootstrap.gd:2444` follows an already advanced snapshot and is ineligible.
The witness would be keyed by explicit presentation world scope, entity, wire
and admission tick; store the witnessed initial ticks once; reject continuity
if current remaining does not equal witnessed total minus elapsed world ticks.
Clear on teardown/world/reset/reconnect, cancellation/death and actor reuse.
One current cast per admitted actor is enough; do not add per-tick history.
Cooldown witnesses need an independently proven actual release boundary and
more slot state, so they are a separate cost decision rather than an assumed
extension. The universal remaining-clock fallback is still required.

The world cue must retain element identity, direction and paid commitment until
authority releases or cancels. Before choosing a nonfractional cue, inspect
normal/reduced actual moving clips to ensure anticipation has not become less
useful. A pose or glow may encode bounded proximity to release from remaining
ticks, but must not be presented as fraction of a known total. Do not guess an
admission age for an atlas merely to keep its old phase formula.

### Subtasks and independent acceptance

1. E13.1.1 — lock the presentation contract, owner Experience; reviewers Gameplay
   and Technical.
   1. Build a source table of every base-duration consumer above and distinguish
      literal completion indicators from artistic anticipation phases.
   2. Compare A/B with one fast admission, one slow admission, unknown total and
      a changed condition after payment. Choose the smallest readable result.
   3. Record exact owned files and root hooks before edits; no parallel writes to
      Bootstrap, combat or snapshot code.
2. E13.1.2 — real paid regression, owner Experience with Gameplay reviewing.
   1. Use an actual champion/perk whose paid Heavy crosses a Flux threshold;
      use actual timed Chilled/Fractured or a grounded condition for slower
      startup. Retain neutral control. Arrange initial fixtures only; issue
      ordinary commands and pay finite Flux thereafter.
   2. Verify initial admission, every remaining tick, release and actual modified
      cooldown. Change movement/status after payment and assert authority timer
      remains committed. No mid-run timer/resource writes.
   3. Cover hidden layer, opening view mid-cast, replica/snapshot round-trip,
      cancellation/death, same-ID actor replacement, invalid rate, minimum tick
      and unsupported wire. For B, delayed/unseen/duplicate events and multiple
      catch-up steps must remain unknown or match the genuine admission.
   4. Compare canonical state, event ordering, paid amount and released payload
      before/after presentation sampling. Keep zero/refusal cases distinct from
      successful admission.
3. E13.1.3 — native information test, owner Root executes, Experience and Gameplay
   independently review.
   1. Capture visible and hidden-layer HUD with the actual world startup cue in
      the same paid trajectory; normal/reduced, ground/air/wall transition and
      at least front/side/back aim. Preserve original body art.
   2. Include smallest supported viewport and current 100–200% reading paths;
      verify the current card/status width with actual shaped text. No new
      panel, overlap or clipping is acceptable.
   3. A still checks fit only. Moving capture must show immediate start,
      distinguishable commitment and disappearance at real release/interruption;
      no false ready state. Compare cost and allocation with the same fixed
      workload before keeping a new observer or formatter.

Precedent: Riot's [League clarity account](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
prioritizes recognizable actions and visual hierarchy, including warnings that
stay visible during opening sequences. It supports truthful threat cues, not a
specific H.E.X. timer formula. Respawn's [Titanfall developer interview](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right)
describes anticipation and repeated movement-context playtesting; it supports
checking the world cue during movement rather than accepting a static meter
test. Neither source proves that removing a fraction is the right H.E.X. choice.

## Historical E13.2 proposal — measured presentation cost after T7

The qualified [foreground record](../iteration-20261012/foreground-current-record.json)
has warm Garden/Fire/Mantle p95 intervals 29.420/49.174/51.784 ms. Previous
isolated HUD attribution found expensive spell-card submission and exact
reference pixels, with observable instrumentation overhead. Warm Garden added
no layout builds. These support a submission experiment, not a new cache-miss
claim or adding nested times as independent whole-frame costs.

1. E13.2.1: Root applies the archived T7 set after exact base verification;
   Technical owns counters, Gameplay owns paid equivalence, Experience reviews
   the consumer. Run default/full/light policy, actual 0/1/8-step processes,
   failed/reset/world boundaries, raw-to-summary validation and native lifecycle.
   Compare observed/unobserved cost; preserve old last-step fields and explain
   residual process work. No FPS claim from counter tests.
2. E13.2.2: Only if current attribution still supports the lead, prototype four
   retained complete spell cards. Keep live readiness queries. Keys must include
   exact displayed ability/empty copy, binding/device, readiness/countdown,
   capacity/control/death, font identity and changed revision, scale/rectangle,
   colors/material/clip and visibility/world/actor scope. Do not allocate
   continually growing historical keys.
3. E13.2.3: Establish pre-HUD/card/post-HUD order first. Bootstrap's later coach,
   Garden card, controller reticle and modals currently share the parent draw;
   a naive child would paint over them. Reject the approach if the bounded seam
   cannot preserve order. Native first-changed-frame equality must include every
   overlap, hidden layer, rebinding, resize and world/spectator replacement.
4. E13.2.4: Alternate actual submission order in independent native runs; include
   key preparation, child draw work and observed overhead. Keep only a repeatable
   useful saving, then repeat admitted foreground workloads. No default retained
   campus promotion or revival of the previously slower general Court cache.

Godot documents that [CanvasItem draw commands are retained until redraw](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html#updating).
Riot's [real-world profiling account](https://www.riotgames.com/en/news/profiling-real-world-performance-league)
supports identifying repeatable workload costs and bounded trail work. These are
mechanism/workflow precedents; they do not establish a H.E.X. frame-rate gain.

## Historical E13.3 audit — all-aspect checks and acceptance gaps

| Area / current evidence | Next bounded check and ownership | Acceptance / current limit |
| --- | --- | --- |
| Movement and wall/air animation: actual-path trail slots are bounded at `character_movement_trail.gd:7–18`; scoped wall-contact reset and paid flier layers have prior native proof | Experience fixture, Gameplay authority review: one finite slide→jump→wall→release→aerial-cast route with deliberate turn, correction and reused actor; review normal/reduced moving clips | Every stroke follows witnessed motion; protection opens/closes on actual ticks; no detached contact/duplicate limb. Prior clips do not establish feel or every pose |
| Projectiles, elemental status and depth: previous all-mask exact geometry and intentional visual reductions are recorded separately | Experience/Gameplay: use moving Range target and two paid crossing threats, compare short/medium range, six-element and singleton cues against varied ground | Recognizable travel, collision boundary, Fuse countdown, owner and status/protection hierarchy; no hidden danger. Source tests alone do not prove human counter recognition |
| Menus/input/accessibility: last iteration repaired real remapped-pointer leakage and compact pad Options; binding cache compares actual device and values at `compact_hud_layout_cache.gd:61–74` | Experience/Gameplay: real keyboard→pad→mouse switch while opening/closing Loom, Range Setup, map and dev menu; hold the closing binding, release, then fresh press. Include remap and 200% text | No accidental paid cast, lost current selection or stale prompt; full loop with actual device still required. No fresh source defect claimed in these already tested paths |
| Teaching, Range and loaners: `optional_introduction.gd:69–155` observes actual commands/events; target statistics are isolated at `range_target_scenario.gd:103–133` | Gameplay route / Experience observation: optional intro→Garden preset→paid Range→challenge→exit/reopen, with known original weave and no cheats earning progress | Correct restored weave/resources and truthful direct/status/ground attribution; ask a new player to execute one taught counter without adding prose first |
| Map/wayfinding/environment: complete funded/visual Garden arrival is staged only during explicit travel; ordinary walking remains live | Technical arrival / Experience UX review: cancel/rekey via resize, failed destination, held input and immediate return; inspect current map identity/district route and first complete view | No partial visible exhibit, hidden modal, false 100% or held-key cast; native prior journey is functionality proof, not faster total travel. Existing paired work increased total CPU while lowering peaks |
| Audio: `element_audio.gd:7–15` fixes four voices/eight queued cues; `:148–181` prioritizes consequences without stealing playing tails | Experience listening fixture / Technical admission review: actual paid burst + damage + movement and mute/unmute/world-reset, with bounded counters and a short recorded output | Damage/confirmation audible when expected; no stale carryover or clipping. Pool/model tests and generated wave shape are not listening acceptance |
| Character/race explanation and UI hierarchy | Gameplay contract / Experience compact view: current projected perk versus already-paid timing at threshold, then encounter reuse; preserve purpose/counter before long ingredient lists | No implication that a current perk retimes an admitted cast; no claim that distinct percentage rows alone prove interesting or balanced choices |
| Documentation/dev tools | Experience docs / Root integration: reconcile only tested current behavior; dev loaners, replay recording and preserved saves retain explicit scope | No debug toggle silently grants durable progression; no old capture, schema or package receipt promoted to changed source |

Microsoft's [XAG text guideline](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)
supports validating legibility and sizing options; this is guidance, not a
certification of the current native matrix. Respawn's interview above supports
evaluating movement through body, camera and sound together. The developers'
[Enter the Gungeon interview](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-)
is a relevant reference for deliberately designed combat pressure and readable
projectile encounters; it supplies no direct H.E.X. speed or difficulty numbers.

## Historical review handoff

Experience sent E13.1 A/B to Gameplay and Technical for information-loss,
post-step witness, reconciliation and per-frame cost challenge. Root requested
the comparison before assigning runtime files. No engine, import, asset
generation, Git mutation or source/test edit was performed for this audit.
Once a choice is reviewed, publish exact ownership and execute one bounded
slice before expanding the backlog.

Peer findings on October 13: Technical favors A for the first HUD-only slice,
with positive remaining time rounded upward to tenths and no growing time-keyed
cache. Gameplay confirms that B's synchronous local witness is feasible:
`step_player` decrements an existing pending cast before reaching admission,
where `_begin_cast` sets the full paid clock and returns. Later same-step
combat can cancel or kill, so the witness must require an alive matching
pending cast after that successful step. Clients and replaced states remain
unknown. Both reviewers reject a constant phase substituted into the world
effect: phase selects atlas age and fallback anticipation, so that would alter
useful motion rather than simply correct a meter. Root can choose the smallest
HUD-only correction with this related limitation explicitly open, or assign
the shared bounded witness plus fallback as one larger reviewed slice. No
runtime choice has been applied by this agent.

Experience's independent T7 native/cost-plan review approves the proposed old
step / old profiler references with controlled 0/1/8-step actual process groups,
64 alternating pairs plus two warm-ups and a reversed independent process.
Require authority/event/packet parity outside clocks, finite paid Fire/Mantle
admissions and refusals, default/light disabled counters and source hashes.
The outer process clock must include snapshots, delta validation and retained
rows. Separately report case-begin/reset cost, final summary and raw-copy cost,
and JSON serialization; JSON timing alone would omit endpoint aggregation.
The predecessor step inherits the current constructor and Bootstrap, so it
qualifies only steady execution of the changed paths, not historical allocation
footprint or the entire previous executable. Controlled deltas are declared
simulation groups, not measured native FPS. No helper was executed by Experience.

## Historical E13.1 selected contract — peer-approved before implementation

Root selected B, a bounded actual-admission witness with A as the honest unknown
fallback. Cooldown is remaining-time-only for this slice. No event, canonical
state, protocol, replay schema or asset bytes change. The following API is a
contract approved by Gameplay for lifecycle and Technical for bounded cost; execution gates remain separate.

**Experience-owned files:** new `src/presentation/cast_startup_witness.gd`;
`compact_combat_hud.gd`, `cartoon_champion_presenter.gd`,
`fullbody_cast_presenter.gd`, `pixel_cast_hands.gd`,
`foundation_spell_presenter.gd`; existing presentation unit suites after exact
fixture ownership is agreed. Root owns Bootstrap and test registration.
Gameplay can own a new real-paid witness regression suite, avoiding edits to
the same presentation test files. An ignored native helper is Experience-owned
and executed only by root. `pixel_aerial_pose.gd` needs no geometry changes.

Proposed witness API:

```gdscript
const MAX_WITNESSES := 8 # Existing maximum casting player roster, no history.
func clear() -> void
func observe_local_step(world: SimWorld, events: Array[Dictionary], step_started_tick: int) -> void
func describe(world: SimWorld, actor: PlayerState) -> Dictionary
static func for_state(actor: PlayerState, config: SimConfig, timing: Dictionary = {}) -> Dictionary
```

- `observe_local_step` is called only following a successful local authoritative
  step, with `world.tick == step_started_tick + 1`, before another catch-up step.
  Root must never call it from replica event ingestion. It prunes old records,
  then admits only a genuine `cast_started` matching an alive current pending
  actor with a positive timer. Duplicate observation of a completed world tick
  cannot replace a witness or reset elapsed time. More than eight eligible
  casters fall back rather than extending the bound.
- Store only a WeakRef to world and a WeakRef to each authoritative actor plus
  scalar entity/wire/admission-tick/total. No strong authority reference, actor
  clone, catalogue or event array is retained. World replacement, backwards
  tick, dead/cancelled cast, changed actor object for the same entity, changed
  pending wire or remaining-clock discontinuity invalidates the record.
  `clear` is unconditional and bounded. New ordinary casts can create new
  records after an old cast ends; repeated event delivery cannot.
- `describe` receives the actual authority actor, not an interpolated rendering
  clone. It validates identity and `remaining == total - (world.tick - admitted_tick)`.
  It returns detached scalars: `entity_id`, `wire_id`, `remaining_ticks`,
  `known_total`, `total_ticks`, `elapsed_ticks`, `progress`, `animation_progress` and the supported tick rate.
  The HUD alone lazily formats the quantized remaining-time label. Unknown total uses `total_ticks=0`, `elapsed_ticks=-1`,
  `progress=-1.0`; consumers must never clamp that sentinel into a claimed
  known fraction. No active cast returns an empty record.
- `for_state` rechecks optional context entity/wire/remaining against the
  current displayed state and supported cadence. It is pure and bounded. A
  copied presentation state can therefore use separately derived authority
  context safely. Missing, stale or malformed context yields the same honest
  remaining-only fallback. Positive clocks use ceiling to tenths, not 0.0 s.
  No raw-tick-keyed text history; at most the currently displayed text is reused.

**Presentation plumbing:** append optional `cast_timing: Dictionary = {}` to
HUD draw/readiness/hidden-cue methods and character draw→movement_frame→fullbody
frame→CastHands.decorate. Existing callers remain valid and receive unknown
fallback. Add the same optional context to Foundation startup drawing. Known
startup uses witnessed elapsed/total for HUD completion and authored body/hand
anticipation. Unknown HUD displays actual remaining time and the current active
border/identity without fractional fill. Cooldown uses its actual countdown
without a base-sized completion bar in either visible or waiting cards.

Unknown world/hand presentation keeps the established direction, element and
active-cast shapes. It may use actual remaining time within the existing
authored anticipation window (base startup duration) as **release proximity**,
not a claimed total or elapsed admission age. If an atlas sample is selected
from that proximity, name it a sample coordinate and map to admitted clip
metadata; do not invent an admission timestamp. Known atlas sampling can use
witnessed elapsed ticks. No new anticipation constant or geometry is introduced
without native evidence; body/action art and recovery clocks retain their
existing ownership. This fallback requires source tests and moving review.

**Root Bootstrap hooks:**

1. Own one witness instance; capture `step_started_tick` immediately before the
   existing local world step and call `observe_local_step` on success before
   the next fixed step, separately from `_ingest_combat_cues`.
2. Clear in `_reset_motion_history`, on world/authority replacement and before
   any replica snapshot/reconciliation publication. Client and replay-only
   snapshot views get empty context; only a future explicitly instrumented
   local replay execution may witness its genuine admissions.
3. Derive a context once per drawn actor from its actual authority state, then
   pass it to the body and world startup cue. Derive the local/spectated HUD
   context from the matching actual actor, and recheck against the displayed
   state. Interpolated positions/aim do not confer a new timing witness.
4. No state-field assignment, clock mutation or event payload enrichment.

**Specific review questions:** Gameplay checks interruption/death later in the
admission tick, same-ID replacement, same-wire repeated casts, catch-up, replay
and replica late events. Technical checks bounded WeakRef/scalar storage, no
per-tick history, current-only text formatting and expiry cleanup. Both review
the information lost only in unknown contexts. Root chooses exact hooks after
the API converges, before implementation.


## Historical E13.1 implementation checkpoint and subsequent gate evidence

Root and both peers selected and approved B with the exact unknown fallback.
The new `cast_startup_witness.gd` stores at most eight weak actor records and a
weak world reference. It records the **post-step** tick and the actual remaining
startup immediately after admission. Clock gaps, mismatched clocks or identities,
death, explicit reset and released casts withdraw that evidence. The actual
local Bootstrap hook is separate from replica event ingestion; no field or
packet was added to authority. Detached scalar context follows the ordinary,
remote and POV body paths and the visible/hidden HUD. HUD strings are generated
only when needed there; body/world queries do not format countdown text.

Unknown startup and all cooldowns now use actual remaining seconds rounded up
to tenths, with no ungrounded fraction. World/body unknown anticipation retains
its authored release-proximity coordinate; unknown pixel preparation samples
are positions within admitted clip metadata, explicitly not claimed elapsed
admission time. Known local casts use their witnessed total/elapsed time. No art,
collision, movement, payment or authoritative clock changes were made.

Gameplay's new `test_cast_startup_witness.gd` uses actual paid threshold crossing,
paid Water followed by Urzh Heavy, same-step lethal contact, natural repeated
casts, complete snapshot replacements, weak lifetime and inherited Bootstrap
catch-up. Experience's existing HUD and Foundation suites cover scalar display,
visible/hidden parity, last-positive-tick countdown, current card fit and admitted
clip sampling. The first parser found two inferred `weakref()` fixture locals;
Gameplay preserved that failed file and added only explicit `WeakRef` types.
Experience independently checked that exact two-line repair. Runtime behavior
and assertions were unchanged by it. Execution results are not inferred from
source review; root owns the remaining gates.

The ignored native helper `E13-native/capture-startup-witness.gd` is a proposal
for eight actual paid aim directions, moving bodies, known/unknown comparison,
normal/reduced effects and real phase boundaries. Its sequence cadence is declared
simulation sampling, not wall-clock FPS. Compact/full 100% HUD and an isolated
200% card are distinct scopes; the latter cannot qualify whole-HUD reflow. It
must pass parser, paid-route and image inspection before any native acceptance.

Root's T7 strict focused gate has passed 13,511 assertions (2,212 completed-step,
11,256 empty-work, 43 catch-up), with no failures or stderr. Technical's native
cost helper was independently reviewed: whole-call clocks include observer work,
summary/deep-copy/JSON endpoints are separate, and current constructor/Bootstrap
(including the shared witness) are disclosed as common to both variants. The
paired native runs are pending; no speed improvement or zero observer overhead
is claimed from these focused tests.


### Subsequent gate findings

The focused presentation suites passed, while one new paid witness assertion
found a real existing snapshot inconsistency: an actor admitted Heavy and took
lethal projectile damage in the same step, leaving a dead actor with a positive
pending timer after its Hex reservation was removed. Strict capture rejected
that completed state. This is a gameplay publication defect, not permission to
weaken the witness's packet assertion. Gameplay owns the separately reviewed
minimum cleanup; root owns its compatibility decision and engine gate. No
Experience-owned authority mutation was introduced.

T7's two independent native cost runs both passed **31,122 checks / 12 cases /
zero errors and stderr**. Experience independently read both receipts. The full
cumulative observer has measurable cost; its balanced whole-process deltas are
about 0.16–0.30 ms for these controlled groups, with substantial first-call/order
variation. Summary, raw deep copy and JSON serialization add roughly 21–23 ms
per 198-record case outside the trajectory clocks. These are diagnostic overhead
measurements, not zero-cost claims or physical frame pacing. See Technical's
ledger for the full strata.

The ignored E13 cost helper is separately prepared for old Bootstrap versus
current Bootstrap, with **current simulation shared and construction excluded**. It
admits one or eight actual Heavy casts before the timed continuation, reports
that admission observer separately, then measures ordinary inherited 0/1/8-step
process groups and four-card/hidden readiness model batches. All eight actors
must actually pay and retain known witnesses while active. It preserves raw
order/warm-up strata and outside-clock complete state/event/packet parity. This
helper has passed independent source review. The first execution's main-window
visibility error is preserved; removing that fixture-only call produced one
clean forward run, but the reverse process encountered a concurrently edited
terrain dependency. Neither incomplete pair is comparative cost evidence.
The final helper pins the terrain dependencies and was frozen for the replacement pair.

**Subsequent final cost pair passed:** `cost-forward3.json` and
`cost-reverse3.json` each contain **11,120 checks / 816 raw groups / zero
errors and stderr**, with 768 measured groups after declared warm-ups.
Experience independently recomputed both raw receipts, whose SHA256 values are
`b476b25171ce637a329943f013f68d906f35b68cacab95342ce1a8b45b2b3979`
and `3a343af10e8fef561ab70043fb05c99e07c8f8c4d4cca19998889acdd7b3ade4`.
The table pools equal counts from both invocation orders and both processes;
units are microseconds per actual inherited process call, not rendered frames.

| Actual actors | Fixed steps in call | Predecessor mean | Candidate mean | Paired mean delta | Paired median delta |
| --- | --- | --- | --- | --- | --- |
| 1 | 0 | 492.01 | 525.17 | +33.16 | +8.5 |
| 1 | 1 | 688.79 | 691.09 | +2.30 | +33.0 |
| 1 | 8 | 3575.22 | 3689.04 | +113.82 | +111.5 |
| 8 | 0 | 552.74 | 509.02 | −43.72 | +19.5 |
| 8 | 1 | 2018.07 | 2056.17 | +38.10 | +40.5 |
| 8 | 8 | 16293.22 | 16654.89 | +361.67 | +352.0 |

Zero-step order strata have roughly +845–885 microseconds when the candidate
runs first and −818–933 when it runs second. That large first-call effect rules
out interpreting the negative aggregate as a speedup or claiming zero overhead.
The separate real-admission observation averages **21.91–23.47 microseconds for
one** and **55.53–55.78 for eight** simultaneous paid cast witnesses across the
two processes.

Readiness-model batches include projection/validation, four spell-card queries
and one hidden-layer query, repeated 16 times per actual actor. Normalized per
actor and complete five-query set, active known-startup means change from
**64.24–64.97 to 90.36–91.15 microseconds**; post-release means change from
**40.16–41.43 to 44.63–45.79**. The added active cost is approximately
25–27 microseconds for the truthful context/countdown bundle. The experiment
does not independently attribute hidden status versus formatting, nor measure
unknown-startup fallback in isolation. It excludes constructors, draw submission,
GPU execution, full-flight expiry, physical input and game frame pacing. Strict
authority/event/complete-packet parity passed outside all clocks. The finite
current-witness implementation is accepted as a measured correctness cost;
these results establish no global smoothness improvement.

For reproducibility, model strata use the **post-process query state**:
`models_batch_us.last_projection_entries > 0` identifies the active hidden cast
(512 measured groups per actor count across both processes); the remaining 256
groups are post-release. This agrees with the fixture's actual `tick_after`
boundary. `pending_before` belongs to the process-entry state and would
incorrectly include its release-crossing eight-step call in the active model
stratum, although the subsequent model queries already see the released cast.

The E13 native visual gate passed **2,345 checks / 54 PNGs / zero stderr**
(`.godot/iteration-20261013/E13-native/output-a/receipt.json`, SHA256
`9fbb5e20218c6d092da9804a690363ff216215bf5e05ae9272112e56aa3cc7e1`).
Independent review sampled Urzh's eight facings at admission, midpoint, final
startup, release and recovery expiry in normal/reduced presentation, plus the
960-pixel visible/hidden HUD. The poses remain connected during the ordinary
movement and return to resting poses after recovery; the actual remaining-time
labels fit. Root separately checked Nico and the isolated 200% card. This is
declared 15 Hz trajectory sampling, not measured FPS, physical input, every
champion, complete 200% HUD fit or human anticipation-comprehension proof.
The clipped 200% fixture caption is diagnostic text, not a game control.

Terrain streaming's ignored native comparison is also source-reviewed: actual
ResourceLoader and ImageTexture, sequential fully closed predecessor/candidate
arms, three views, two warm-ups plus six measured repetitions, ordinary moving
view trace and real cancellation/re-entry. Pixel readback occurs at explicit
endpoints outside pump clocks. Construction is excluded, and diagnostic
readiness wall times include scheduling/observation work. Its native execution
is pending; no loading or frame-time improvement is established by source review.

The subsequently repaired death-boundary suite passed **21,570 assertions**, the
real-paid startup witness **1,287**, and terrain streaming **439**, within root's
five-suite gate with zero stderr. These are focused results, not a new Full or
portable qualification. The completed-Hex cleanup belongs to Gameplay; it closes
the dead actor's unfired reservation at the same boundary as existing stock
retirement, preserving the strict snapshot assertion.

Before native terrain measurement, review identified a necessary acceptance
boundary: ordinary offline Bootstrap can pause authority when required terrain
is missing. The native helper therefore retains its 48 drained-halo cases and
adds six separate traces beginning at the first actual required-ready boundary.
Both arms receive identical requested view positions; the receipt records any
unfinished halo, each unready frame, the longest consecutive gap and an explicitly
synthetic last-ready-view proxy. This proxy does not replace the planned actual
Bootstrap movement check and cannot establish smooth live movement by itself.

**Terrain native result: correctness passed; the current scheduling policy has
not yet met user-experience acceptance.** The forward/reverse receipts passed
75,798 / 75,706 checks respectively, each with 48 full-halo cases, six early-walk
traces, two cancellation/re-entry cases and zero errors/stderr. Their SHA256
values are `3d87136c38a3213634ffbfc72bb614499e4dfd80e6d62ba07c69ea141b8c3b99`
and `1851c6e8bf3cfd88ee1748d432347e1ed479bed59fa7247a1922cdf1bff5daf4`.
The following independent recomputation excludes the two warm-ups and balances
both arm orders: 12 measured cases per view/arm. Pump p95 uses nearest rank on
all arrival-phase pump calls; CPU totals and readiness are means per case.

| View | Arrival pump p95, before → candidate | Total pump CPU per case | First-ready pump frames | Instrumented first-ready wall time |
| --- | --- | --- | --- | --- |
| Garden | 7.300 → 2.390 ms | 196.527 → 224.979 ms | 9.08 → 21.67 | 276 → 736 ms |
| 28 required tiles | 7.264 → 2.344 ms | 386.478 → 441.945 ms | 45.25 → 93.00 | 1456 → 3006 ms |
| Partial edge | 7.155 → 2.241 ms | 38.113 → 42.877 ms | 2.00 → 3.00 | 48 → 88 ms |

The candidate reduces individual validation spikes while increasing total pump
CPU by roughly 12.5–14.5% and substantially delaying required readiness. Maximum
arrival pumps are still 3.125 / 5.529 / 2.614 ms for these three views, so the
2 ms target is not a hard cap. The separate image-reconstruction stage averages
only 0.355 / 0.676 / 0.082 ms per whole case; most added measured work is in
incremental validation rather than reconstruction. End-of-pump stored payloads
reach 2 MiB; the separate logical overlap counter peaks at 3 MiB. Neither is
an allocator/RSS or GPU memory measurement.

The additional early-walk traces reveal a material regression in both process
orders. Across each 24-sample fixed demand sequence, Garden changes from five
unready samples with longest run three to 13–23 with longest run 13–23; the large
view changes from eight/longest five to 15–23/longest 15–23; the edge changes
from two/longest two to four–five/longest four–five. The synthetic last-ready view
can lag requested demand by 576 pixels in the candidate's Garden/large traces.
All traces eventually return to the same ready endpoint. Even after initial
halo draining, the large candidate records 17 unready walking samples across
its 12 measured cases, against zero in the predecessor.

Exact uploaded pixels, strict publication, bounded job ownership, cancellation
without extra uploads and re-entry all pass. These correctness results do not
erase the readiness regression. The subsequent actual Bootstrap comparison
completed both 480-command paid routes in both arms with **zero later walking
pauses**; this is useful counterevidence to the synthetic camera-demand traces,
not grounds to generalize those traces into a live walking failure. Root's
arrival observations nevertheless increased from 27 to 46 callbacks at Garden
and 21 to 37 at Verdant. The fixed main-frame slicing policy was therefore
[withdrawn from runtime](terrain-stream-slices/withdrawal.json), with exact
original stream and existing fixture restored. The rejected prototype, helper,
receipts and all fixture changes remain archived. The actual comparison used
explicit synthetic application-input-active mode with actual window focus
separately recorded, real scene/map/router/loading behavior and screenshots
after traversal. Neither that declared-cadence route, proxy wall time nor the
improved isolated pump p95 qualifies game FPS or physical input responsiveness.

**HUD panel follow-up: both native diagnostic orders passed; no optimization implemented.** The
earlier seven-case native HUD probe attributes mean panel submission of
0.505–1.038 ms inside mean total observed HUD submission of 1.951–4.275 ms.
Those nested totals do not identify the expensive operation. Current
`CompactCombatHud._panel_geometry` already retains the fill ArrayMesh and exact
outline points in a bounded 64-entry geometry cache. Another fill/descriptor
cache would duplicate existing work.

The smallest useful next experiment is the ignored
`.godot/iteration-20261013/profile-hud-panels.gd` helper: unchanged production HUD
versus the same panel operations with fixed scalar timers for geometry lookup,
fill color, fill submission, outline color and outline submission. Ten cases
cover a real paid Heavy admission, its witnessed and unknown presentation,
hidden layer, later paid startup and release, viewport resize/return, 125/150%
transforms and an explicitly isolated 200% card. Each case has four warm-ups and
32 measured pairs with verified alternating callback order; a separate reversed
process is required. First/final RGBA must match, actual paid authority/events/
complete packets and cache build counts must remain unchanged, and only 20
representative PNGs are saved. Whole-HUD observed/plain deltas disclose timer
overhead; component intervals are nested in the parent totals and must not be
added to them. Root owns engine execution and independent technical review
precedes the gate. The completed results and their limits follow below.

If outline submission proves material in both process orders, the bounded
hypothesis is to retain only its immutable geometry at the existing same-parent
draw seam, preserving live color/opacity and painter order. It is not yet a
candidate: native equality must first establish exact positive-width join,
scale, clipping and raster behavior. A child CanvasItem or whole-card cache
would require a wider overlay/invalidation proof and is outside this slice.

The precedent is methodological. Riot's [real-world League profiling report](https://www.riotgames.com/en/news/profiling-real-world-performance-league)
reproduces costly effects and separates CPU geometry generation from GPU work
before changing them; its Swain outline fix preserves the clarity cue while
reducing the actual expensive work. This does not show that H.E.X.'s 2D panel
outline has the same cost or implementation. [League's clarity principles](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/) support keeping
the hierarchy and useful cues intact. [Godot's drawing documentation](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html#updating)
explains retained draw commands and explicit redraw; it does not prove a custom
outline mesh equals `draw_polyline` or benefits this renderer. Native submission
evidence still cannot establish whole-frame pacing, physical input response or
human comprehension.

The executed helper `95d962c822eacbca6f1defe43f5bfc338de1cdc69dc98615841ae967508855f2`
passed 1,288 checks in each process with empty stderr. [The independent review](hud-panel-attribution/review.json)
pools 64 measured pairs per case, excluding eight warm-up pairs. All 40 archived
PNG hashes match the raw receipts. First/final native RGBA and cache counts
match; paid authority, events and complete packets remain unchanged. The first
pair of a later case may use retained geometry from an earlier case: the old
receipt's `cold_and_final` field does **not** establish a universal cold-cache
test. Exact executed bytes, raw receipts and logs remain in the archive.

| Case | Plain / observed HUD | Panel total | Geometry | Fill draw | Outline draw |
| --- | --- | --- | --- | --- | --- |
| Idle, 1280 | 1.073 / 1.116 ms | 0.244 ms | 0.028 ms | 0.013 ms | 0.175 ms |
| Paid known startup, 1280 | 1.240 / 1.247 ms | 0.281 ms | 0.030 ms | 0.016 ms | 0.205 ms |
| Paid unknown startup, 1280 | 1.129 / 1.110 ms | 0.250 ms | 0.026 ms | 0.015 ms | 0.180 ms |
| Paid hidden layer, 960 | 1.273 / 1.261 ms | 0.256 ms | 0.027 ms | 0.015 ms | 0.184 ms |
| Later startup after resize return | 1.498 / 1.586 ms | 0.374 ms | 0.037 ms | 0.020 ms | 0.280 ms |
| Isolated 200% card | 0.290 / 0.291 ms | 0.078 ms | 0.006 ms | 0.004 ms | 0.061 ms |

Outline submission dominates the panel-only intervals, but its absolute scale
is roughly **0.175–0.280 ms for the full HUD**, not the earlier aggregate
0.5–1.0 ms panel assumption. Even eliminating that entire call cost would only
provide a small theoretical upper bound; a replacement has its own submission
cost. The two runs also show a strong execution-order effect: observed-first
draws are about 0.122–0.222 ms slower than plain, while observed-second draws
are about 0.014–0.181 ms faster. Balanced observer deltas are therefore not
proof that timers are free, and negative deltas are not speedups. Color and
geometry work remain separately recorded in the machine-readable review.

After both valid fresh-path runs closed, technical review's rejected-output
finding was repaired in the ignored helper only: `output_authorized` is set
after guarded fresh directory creation, and receipt writes require that flag.
The revised helper hash is `bbc6dd912b7cd13cafd16df940dad4c1b7ac7c89540b3119d85a437143972b2a`;
it also renames the first/final field. It has not been re-executed here. Neither
change alters the valid-path drawing operation that produced these receipts.

**Small UI subtraction applied; existing HUD suite passed, new Full pending.** The
native paid/hidden HUD
frames repeat the same champion name above and below the playfield. Bootstrap
1454–1457 chooses a single local or spectated `observed_state`; 1543–1572 passes
that actor's one name/identity to the HUD. `CompactCombatHud`127 prints it in
the top title, including `WATCHING` when spectating; 187 repeats it beside the
resources unless the actual protection warning replaces it. These are not two
different owners. Gameplay independently checked that data path.

The smallest useful change is to omit only the idle lower name, while retaining
the real `PROTECTED` / `PROTECTED / SPAWN` label, top identity/location/spectator
mode, portrait and resource values. Keep resource positions and the warning
slot stable rather than shifting bars whenever protection begins. This removes
redundant text; it does not reduce panel area or establish a performance gain.
Owner: experience after root approval; reviewer: gameplay. Acceptance needs
native self/spectator and observed-actor switching at 960/1280, actual protection
opening/expiry, unchanged bar/tooltip hit geometry and no authority mutation.
The original proposal was first kept outside canonical source. The ignored
`hud-name/candidate_hud.gd` prototype now has exact source review from experience
and gameplay. Its only runtime-method difference is protected-only drawing of
the existing lower text call; all geometry and other drawing remain unchanged.
The isolated native helper `hud-name/compare-hud-name.gd` is frozen at
`59504845a6349444a5d4ae7a4f8950c3d5f2f1e19ab7d21f2e884235bdc48dec`,
with candidate `09a32a9801ed6fe4adf530189bf7c10f411a5b5b60f7ff624f5c0ea901eee689`.
It guards the preserved canonical HUD `a6a62bc23cceed6c9e9f4e75d2b4d19120a89929f5cbceac6b4d4bf183bceb73`.
Fourteen paired cases require exact protected images, changes confined to the
old idle-name row, unchanged resource-pointer inspection, observed-actor
switch/return, and complete authority/packet/event purity. Its protection comes
from ordinary finite Evade followed by natural expiry. The native prototype
passed **285 checks / 14 paired cases / 28 PNGs**, with zero stderr. Experience
independently verified all 28 PNG hashes and 19 watched source hashes and
inspected local before/after, spectator, protected-inspection and expired-
inspection frames. The four protected cases are entirely pixel-identical;
the ten idle cases remove only 181 or 235 pixels in the duplicate-name row.
The actual Evade spends Stamina from 620,000 to 596,000 at tick 1; protection
expires naturally at tick 17. Identity switching and the pointer details remain
visible, with unchanged resource geometry. Root then applied only the reviewed
method. Experience independently compared the current method against the exact
archived candidate and confirmed that the rest of the normalized HUD source is
unchanged. Applied HUD SHA:
`62d17fa1c5125a9f1d259f2b42f677234073a8135c22ed48db4fb85375f89280`.
The native evidence above belongs to the exact isolated candidate. The applied
source then passed the existing `compact-combat-hud` suite: **54,746 assertions,
zero failures and zero stderr**. Its source, logs and separate
[promoted receipt](hud-name/promoted/review.json) preserve that distinction;
the original prototype receipt and pre-apply hashes remain unchanged. New Full
qualification remains pending.
Exact executed
helper/candidate/predecessor, native receipt, all images and logs are retained
in [hud-name/review.json](hud-name/review.json) and its archive manifest; receipt
SHA `6d1681ae852d138b3a735623e83d23e0e0341db60d7663f6d665b7afe8d9425a`.
This HUD argument-contract probe does not
exercise Bootstrap spectator navigation, physical input, modal overlap or
200% layout and is not a timing comparison.

An official comparable precedent is Blizzard's [Diablo II: Resurrected technical
alpha learnings](https://news.blizzard.com/en-gb/article/23695734/technical-alpha-learnings):
the team made repetitive comparison prompts optional after players reported HUD
clutter, while preserving access to the comparison itself. That supports
removing repetition without removing useful state; it does not prove H.E.X.'s
specific placement is better, nor justify adding another settings toggle for
an already duplicated identity. [World of Warcraft's HUD revision](https://news.blizzard.com/en-us/article/23841481/world-of-warcraft-dragonflight-hud-and-ui-revamp)
similarly prioritizes visible health/action information while reducing clutter.
Neither source supplies a measured frame-time benefit for this one-label change.

## Paid-ground attribution: retained boundary lookup and submission

**Both native orders passed; attribution only, no renderer optimization.** The
complete raw/source/image archive and independent analysis are in
[ground-boundary-attribution](ground-boundary-attribution/README.md). Each
process passed 7,188 checks across 22 cases with empty stderr. All 88 PNG hashes
and plain/observed pixel pairs matched. The design below is the historical
proposal; its completed evidence and limits follow it.

The qualified
`1e084` foreground record put Fire/Mantle paid-ground submission near 5 ms,
including roughly 1.9 ms bundle preparation and 3 ms remaining draw work.
Those historical nested intervals do not establish the current protocol-61
cost or identify an outline bottleneck. The previous broad ground metadata/
style cache was slower and remains withdrawn.

One different operation worth isolating is **repeated resolution of an already
retained boundary into its submitted mesh**. Current `HexCourtPresenter` already
retains topology, exposed masks, triangle points and meshes. No additional
geometry cache is proposed. Source evidence:

| Current seam | Repeated work that a diagnostic can separate |
| --- | --- |
| `hex_court_presenter.gd:1341` `_region_edge_counts` | Builds an exact current topology key, including dynamic owner/phase rules, before the existing retained lookup. |
| `:1483` `_region_edge_prefix` | Builds the current compound key on each request; the bounded per-draw prefix cache is cleared at `:247`. |
| `:1518` `_draw_region_outline` | Resolves an exposed mask, resolves retained points, and submits each visible region in existing painter order. |
| `:1526` `_region_exposed_edges` | Reads the current prefix and exact vertex sequence, then retrieves the existing mask or uses its generic fallback. |
| `:1552` `_outline_batch_points` | Creates a polygon/width/mask lookup key even on a retained hit. |
| `:1580` `_submit_outline`, `:1592` `_resident_outline_mesh` | Looks up the retained points-to-mesh mapping, then submits a mesh or the existing bounded overflow triangles. The hit path currently uses `has()` followed by indexed retrieval. |

The hypothesis is that some of the residual draw cost belongs to repeated
lookup/submission work, rather than absent geometry retention. A measured small
contribution is a valid result and should end this line of work. This design
does not propose merging regions, changing colors/widths, retaining complete
draw lists or caching live material state.

1. **Freeze and admit exact inputs.** Experience owns an ignored diagnostic;
   technical reviews timing/cache semantics, gameplay reviews ordinary paid
   trajectories, and root alone parses/runs it. Pin current Court, surfaces,
   catalogs, authority and build files. Compare a plain current presenter with
   an observed subclass whose copied method bodies are guarded against those
   exact current sources. Both use the same unchanged concrete paid world.
2. **Separate the costs without changing rendering.** Fixed scalar counters
   and clocks record topology/count resolution, exposed-mask resolution,
   point lookup, mesh lookup and actual RenderingServer submission. Outline
   and whole-ground totals remain parent intervals. A prefix sub-timer, if
   needed, is explicitly nested rather than added to those totals. Collect
   cache hit/build/fallback deltas and visible region/edge counts outside the
   clocks. The plain/observed whole-draw difference exposes instrumentation
   overhead; it must not be interpreted as an optimization.
3. **Use actual paid states.** Initially bound the timed matrix to six observed
   snapshots in normal and reduced effects: one Fire cast's ignition/active/
   cooling boundaries, a real Fire self-reaction, an active all-six Mantle, and
   a two-owner boundary. Reuse the existing finite paid-field route principles:
   legal loadouts prepared before the route, ordinary commands, actual cast
   admission/payment/terminal deposit, positive source stock, conserved matter,
   natural expiry, and no refill or injected phase/owner. Every claimed phase
   and ownership distinction must actually occur or the fixture fails honestly.
4. **Keep visual and dynamic controls.** Exact RGBA must agree for both effects
   profiles and current phase/owner boundaries. A small separate pixel-only
   matrix covers translated camera, fractional translation, 0.5/0.75/1.0 zoom,
   phase changes, full expiry and subsequent paid re-entry using the same
   presenter instances. Adjacent owners and Backdraft's distinct fuse endpoint
   remain boundaries when present; no cue may disappear merely to reduce cost.
   Hash complete world/packet/events before and after every paired draw outside
   timing. These are renderer controls, not player-input or camera-feel proof.
5. **Bound and interpret the probe.** At most 12 timed cases, each 32 measured
   pairs plus four retained warmups; deterministic alternating actual callback
   order, then a fresh reverse-order process. First/final exact image checks and
   representative saved pairs stay bounded to at most 48 PNGs. Report raw
   order strata, medians/tails and observer differences, keeping cold admission
   and steady retained work distinct. No per-region event history, no hash/
   readback/JSON inside clocks, and no sum of nested stages or CPU/GPU claims.
   Only a substantial reproducible operation justifies a later isolated
   candidate; even then it needs its own exact native A/B and integrated gates.

Riot's [clarity account](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
explicitly describes repairing Jhin's ultimate borders so they stay visible
through opening, and preserving an effect's gameplay hierarchy. That is the
relevant visual constraint here: danger, ownership and phase boundaries remain
legible while measuring their implementation. It does not identify H.E.X.'s
CPU bottleneck or prove any cache or mesh optimization. The previously verified
[League real-world profiling account](https://www.riotgames.com/en/news/profiling-real-world-performance-league)
supports reproducing the actual costly workload before selecting a mechanism;
its concrete game fixes are examples, not H.E.X. performance estimates.

The ignored probe executed unchanged under
`.godot/iteration-20261013/ground-boundary/`. Its driver is
`da3ca4ec1ca10770e1cf27de1f4b24edfab34a56a91cabb5f304313a3d830f46`;
the observed subclass is
`af45eadd3a8d0b9353755be01d2d7333f35ad8a913740406907389108d3815cb`.
Only the copied submission method is transformed, and an independent text
comparison confirms its original operations match current/preserved Court
`3190aa2683205bfdd1ebcc297e1002b3f3e624e4b59a61ecf64b76889733b92c`.
The other method overrides delegate to the unchanged production implementation.
Technical and gameplay source review, checked parsing, actual paid-state
reachability and both ordered native runs passed at these exact bytes. This
establishes the attribution fixture's scope, not an improvement to rendering.

The executable boundary is 12 timed cases × 32 measured plus four warmup pairs,
10 additional pixel controls, two 640×480 viewports and 44 saved PNGs. Its
two-owner route requires two actual owner values in paid ground; adjacency or
overlap is not claimed merely because both owners appear in one image. The
first sample in a case is not called cold: presenter and native resource caches
persist, with actual build/hit deltas recorded. Source inspection also clarified
the timer hierarchy: bundle preparation, topology construction and outline
drawing are separate children of the whole ground call; prefix work is nested
under topology or mask resolution. Parent and child durations must not be added.

Across the two processes, 768 measured pairs and 96 warmup pairs retained
actual callback-order strata; another 20 pairs covered pixel-only controls.
All measured rows built zero new meshes and topologies. The dense Fire cases
contain 150 Conflagration regions over 25 cells; the Mantle cases contain 91
regions over 33 cells, including 84 unified all-six regions. These isolated
workloads are not interchangeable with the earlier whole-game profile.

| Paid snapshot | Plain whole draw mean, normal / reduced | Bundle mean | Topology mean | Outline mean | Nested prefix mean |
| --- | --- | --- | --- | --- | --- |
| Dense Fire | 10.693 / 9.934 ms | 3.709 / 3.578 ms | 0.898 / 0.822 ms | 1.517 / 1.426 ms | 0.977 / 0.908 ms |
| All-six Mantle | 7.394 / 7.345 ms | 2.656 / 2.675 ms | 0.533 / 0.521 ms | 1.041 / 1.030 ms | 0.498 / 0.483 ms |

Actual outline command submission contributed only 35–44 microseconds in these
four cases; mesh lookup was 111–130 microseconds. This does not justify another
geometry cache. The observed whole-draw means exceeded plain means by 47–534
microseconds across the timed cases, with substantial callback-order effects;
the raw outliers and both order strata remain in the archive. Prefix time is
inside topology/mask work, and cannot be added to those intervals or treated
as recoverable speedup.

Root and experience sampled six representative stills covering dense Fire,
mixed Mantle, separate owners, cooling and decay. They show nonblank bounded
fields with visible exterior boundaries and no sampled clipping. All-image
equivalence is supplied by exact RGBA checks, not by claiming every image was
visually inspected. This proves neither animated counter recognition nor
whole-campus/player readability, GPU performance or foreground frame pacing.

The subsequently **withdrawn, unapplied** candidate was an exact key-shape experiment:
ordinary unified prefixes can use their four meaningful fields, cinderveil can
add its real decay endpoint, and legacy materials retain the original eight
fields. Owner serialization, current phase/danger, readonly keys, the existing
cap and per-draw clearing must remain unchanged. Mantle is the likely target;
legacy Conflagration is a useful unchanged cost control. This requires an
isolated prototype, direct mutable-owner/deadline equivalence and its own paid
native pixel/order comparison before any runtime proposal.

The ignored prototype was source-reviewed by gameplay and technical at
`.godot/iteration-20261013/prefix-key-shape/`: candidate
`cb76c827d1fe6fe73a5bfcab0292a371b20e28b903772639564b3943ec4a6f19`,
driver `39299f88babc28742f157b22024f31a72c0f91fc052f19225050a83d4c31a0d1`.
Its copied-method guard reverses exactly the one key-construction block, and
all ten actual paid preparation/snapshot methods match the completed attribution
fixture. Mixed owner types, nested same-object mutations, key-space interleaving,
live deadlines and shared 512-key saturation are explicit direct controls.
The new cost pair uses only identical outer draw clocks, with no nested observer
instrumentation. Parsing and both native orders passed: each **9,077 checks / 22
cases**, including **2,334 direct prefix checks**, with empty stderr and all 88
PNG hashes/pair equality verified. All measured draws built zero new meshes or
topologies. [The complete archive](prefix-key-shape/README.md) records the
withdrawal: normal Mantle's mean delta was −338.469 µs forward but +51.469 µs
reverse; reduced Mantle was −170.094 / +142.375 µs. Its pooled reduced paired
median was +63.5 µs. Legacy dense Fire normal worsened +254.078 µs pooled, with
both order means positive. The result does not justify a production patch;
canonical Court remains unchanged. Both independent peers agree.

## Crowded paid-ground trail and terminal coach follow-ups

**The trail preflight is withdrawn; the coach edge remains unconfirmed.** These
are separate from the previously accepted real-path character trail rendering.

The [crowded trail archive](trail-crowded/README.md) preserves a three-actor
960-tick ordinary paid episode in each native order, exact authority, 69 paid
admissions, 41,400 matter and 38 actual trail emissions per episode. Independent
experience recomputation agrees with gameplay and technical: across 1,872
measured pairs, emitter time falls 26.187 µs overall, but 404 sampled-positive
rows rise 20.475 µs and 76 actual-emission rows rise 90.592 µs. Actual-emission
regression persists in both invocation-order strata (+79.921 / +101.263 µs).
The overall whole-step delta is heavily order-dependent (+88.947 µs when the
candidate runs first, −194.520 µs when it runs second). These results do not
support promoting this preflight as smoother casting. No canonical trail change
was made.

The [terminal coach probe](coach-terminal/README.md) passed integrity checks but
did not reach the simultaneous protected-contact/saved-victory terminal event.
Its real introductory prerequisites and finite encounter attempts do not prove
the suspected terminal teaching defect. No production coach fix is justified
by this unreproduced route; the exact bounded attempts remain available for
future review.

## Next-cycle selected issue: convenience hints after a supported remap

**Confirmed by independent source review; ignored prototype authorized, not
applied or engine-tested.** F5 and F6 are legal gameplay remaps: the binding
editor reserves only Escape and F4 (`control_binding_editor.gd:62–65`), and its
normal capture/validation commits those function keys. The expansion input
handler deliberately preserves custom gameplay ownership at
`element_expansion_controller.gd:275`. However, the keyboard guide still reports
`F5 / Skip guide` and `F6 / Spell Range` at line 248; the introduction notice,
navigation menu and practice footers also advertise those keys. A player who
assigns slot 1 to F5 or F6 can follow a displayed lesson shortcut and invoke the
configured paid spell instead of the promised guide/Range action. The input
priority is correct; the displayed shortcut is stale. Gameplay independently
confirmed this exact supported path. Technical found no cost objection to
reusing the current bounded preference lookup at existing label construction.

Concrete self-prompt for the next slice:

1. Preserve exact current controller, navigation and existing testing-suite
   bytes/hashes under `.godot/iteration-20261013/remap-guide-hints/`. Prepare an
   unapplied canonical-path patch and a manifest; do not modify frozen source.
2. Use one shared availability projection with the existing gameplay-key
   ownership predicate. Preserve default labels, actual routing/remaps, modal
   quarantine, geometry and pointer targets. When the convenience key is owned,
   use the existing Menu route for guide/practice instructions and omit only the
   unavailable menu hint, including the Shift variants. No new warning panel,
   explanation row, tick-keyed cache or copied preference history.
3. Draft a bounded existing-suite regression that captures F5/F6 through the
   real binding editor, closes/rearms input, then uses real parsed key events
   through Bootstrap/router and an ordinary paid world. Check actual action and
   hint agreement, accessible Menu/Skip fallback, unchanged world on label
   queries, and restoration of defaults. Preserve InputMap/held state afterward.
   Prepared UI selection is not physical-device or full-boot proof.
4. Gameplay independently reviews supported remapping, payment, event ownership
   and cleanup. Technical reviews bounded lookup/no extra lifetime. Root may
   apply only after the qualified `500be` delivery checkpoint and source guards;
   root alone runs strict focused/native gates. Review the longest fallback at
   960/1280 and 100/200% plus controller mode, without changing layout to conceal
   clipping. Keep actual keyboard input distinct from physical human testing.

Primary precedent: Microsoft's [Xbox Accessibility Guideline 107](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107)
requires remapped labels to remain correct across hints/tutorials and illustrates
game-specific remapping with Gears 5. This supports consistent instructions; it
does not certify H.E.X. accessibility or dictate its gameplay bindings. The page
was reopened on October 13. The repair is justified by the concrete source
disagreement, not by borrowing another game's controls.

This bounded audit found no second established defect. Existing modal input
quarantine already precedes Loom close dispatch; audio reset guards its first
movement sample; the active cast witness validates current identity and clocks.
Ending a developer loaner while pending may intentionally cancel isolated work
without refund, so source inspection alone does not make that an error. The
Split rival's centered shot remains a possible pressure/usability experiment,
not a demonstrated balance defect. Unfinished authored animation, listening,
physical-controller feel and fast-projectile counter recognition remain separate
human acceptance work, without an invented code fix.

The proposed seven-interval attribution also passed experience source review.
Its revised prompt closes/counts actor setup before both early continues,
records zero-call groups and failed partial steps, preserves inclusive parent
and residual, and explicitly owns fresh output/cleanup/source-pin checks. That
source review established only the proposal. Root subsequently authorized
Technical to prepare its ignored helper; Experience will review exact timers and
cleanup, and no execution or runtime change is implied.

The ignored remap patch is now frozen and Gameplay source-approved at
`93628c4843e11611f0420222d568c07ced1e635b9d9f483abdfac66869e9cc16`.
Its three current canonical files remain byte-identical to the pinned `before/`
copies, and an independent Python hunk reconstruction reproduces every proposed
file. Four fresh cases draft actual paid F5/F6 with and without Shift, Menu
Introduction/Skip, default F5 action restoration and controller fallback. The
minimal Bootstrap harness manually decrements the existing input guard; it is
not inherited process/full-boot/physical-device evidence. The practice-menu
Challenges row is absent, so its Shift+F6 label branch remains source-reviewed
rather than covered by that row loop. Root's parsing, focused execution and
native fallback fit checks are all still pending. No canonical patch is applied.

## Bounded audio audit: terminal confirmation lifetime

**One source-supported issue selected for a future paid reproduction; no audio
code, assets or settings changed.** The ordinary audio path is deliberately
local and non-positional. Bootstrap checks source ownership and visible contact
targets before admission (`bootstrap.gd:1902–1940`); ElementAudio bounds playback
to four voices and eight queued cues, coalesces duplicate keys and preserves
playing tails instead of stealing them (`element_audio.gd:7–15`, `:102–231`).
Mute clears queued/playing feedback. Preference validation and serialization
preserve explicit zero and the requested gain across load/save
(`player_preferences.gd:394–398`, `:702`, `:733`). Reduced Effects is a separate
visual preference, not a hidden audio mute. These source/test contracts do not
establish listening comfort, loudness balance or device behavior.

The selected issue is the **earned-confirmation cue crossing the trial's input
block boundary**. A real owned paid defeat is observed by
`signature_challenge_session.gd:99–121`; victory makes
`solo_duel_trial.gd:75–76` report blocked gameplay. The controller then directly
admits `confirmed` (`element_expansion_controller.gd:131–137`), whose existing
clip is 220 ms (`element_audio.gd:31`, `:246–261`). On the next process iteration,
Bootstrap's blocked-input branch calls `silence()` (`bootstrap.gd:1006–1009`)
before its finished-trial return at line 1065. That stops all players and clears
their reservations, so an otherwise valid confirmation is cut short whenever
that iteration arrives before the clip finishes. Conversely, a previously paid
shot may finish during focus loss or an open modal: live trials continue neutral
commands, and this direct confirmation call does not apply the normal external
eligibility guard. Master mute still rejects it. This is one terminal-feedback
lifecycle mismatch, not a claim about the audible severity of either route.

Gameplay independently confirmed both source paths and found no intervening
challenge guard. The next useful gate is one ordinary paid victory through the
real controller and inherited process, followed by frozen-result frames, with
an empty voice pool control and the same route under focus loss, an unrelated
menu, mute and world reset. Require unchanged result/payment/save authority,
one admission, no replay on regain, natural cue completion for the eligible
result, and prompt silence for the existing external stop conditions. A blanket
post-victory `_gameplay_input_blocked()` check would suppress every confirmation
and is not an acceptable repair. Root must authorize any later fixture or
bounded distinction between terminal-result audio and unrelated input blocking.
No engine or mixer capture was run here.

For a later behavior repair, Riot's [Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
prioritizes meaningful audio information and limits unnecessary noise. Reopened
October 13, it supports preserving the existing useful cue without adding more
sounds; it does not prescribe H.E.X.'s focus policy or prove this cue is pleasant
or recognizable. The bounded audit stops here with no second audio issue.

Root subsequently authorized the ignored reproduction, initially source-reviewed by
Gameplay at driver SHA
`dbe8ab83d24dcaaa56600b3f9e1ceae250c284819be4e4fa1783c892c30f36b6`
under `.godot/iteration-20261013/terminal-audio/`. Its two paid-route methods are
exact copies of the existing progression suite, with 28 canonical source pins.
One actual district encounter must reach a genuine owned paid victory and saved
reward. The primary witness requires the reserved confirmation voice still
playing at the recorded `silence()` call, strictly before its actual clip could
finish, then stopped after the inherited frozen-result callback. Alternate
focus/menu/mute/handoff checks re-arm only the presentation notice marker on the
same genuine result; they are explicitly synthetic eligibility controls, not
new victories. The handoff check is an existing audio/input reset seam, not a
complete world replacement. Actual authority, payment, reward and save bytes
must remain fixed through those callbacks. The root-owned wrapper at
`3698384dc786c8055bdb1c740ba9e6ecc3b106a4e2a10916188f9977051af55f`
uses a fresh isolated APPDATA, strict parser/runner and bounded watchdog. The
first run parsed but stopped before the encounter at its backend admission
check; it establishes no audio behavior. Exact helper, wrapper, checkpoint,
source pins, logs and the three-check rejected receipt are preserved under
`terminal-audio/backend-admission-failed-1/` in the ignored work area. The helper
had looked for engine flags in `OS.get_cmdline_args()`. The sole correction uses
`AudioServer.get_driver_name()`—already used by the passing ElementAudio suite—
and records the actual selected driver. Gameplay approved this exact delta at
`814e048fba57713b6af60b9cb92de84970eba4812e7483314586a4714cb3fece`;
the second run admitted Dummy but stopped at local-session binding before the
encounter (75 checks, empty stderr). The fixture name was 20 characters against
the existing 15-character limit. Exact failed bytes/logs/receipt are preserved
under `terminal-audio/session-binding-failed-2/`; a short-name-only correction
also records `last_error` and requires unchanged world state/hostile teams across
binding. It remains an ignored fixture correction awaiting a fresh root gate,
not audio-defect evidence. Dummy-backed playing/stop calls cannot establish
listening comfort, physical focus or full-boot behavior. No repair is applied.

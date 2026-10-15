# Gameplay breakthrough audit and bounded implementation

15 October 2026. Source was inspected against the qualified `p61-d6d1bfb9c529` baseline and the prior complete-overhaul design. This is a product hypothesis with source evidence, not a forecast of sales or retention. Root owns engines, tests, packages, profiles, Git integration and the qualified Windows fallback. The user selected illustrated 2.5D with smooth animated sprites; this first gameplay slice does not claim to deliver that art overhaul.

## Decision

The clearest existing hook is **read a rival, defeat them, learn their signature, then choose to use it against the next rival**. H.E.X. already has most of its underlying authority. What is missing is a small intentional route with an obvious start, consequence, next decision and stopping point. The first approved implementation is an optional Rival Circuit over the three authored lessons, not another roguelike authority mode or a new currency economy.

This is a sharper test than expanding the spell count. Thirty signature spells are gated; the other 474 of the 504 current combinations are ordinarily available, and the Range already offers broad practice. A promise of hundreds of combinations does not by itself tell a new player why they should choose one now. The three rivals provide concrete situations in which to compare delivery timing, positioning and learned tools.

## Current source and implications

| Source | Established behavior | Limitation / candidate |
|---|---|---|
| `src/content/signature_learning_path.gd:7` | Three optional lessons cover Rapid gaps, delayed ground and a reflected second lane; selected earned reuse is already separated from the next unearned objective | Connect the existing sequence with an explicit session boundary rather than inventing another tutorial or claiming the lessons are absent |
| `src/content/signature_arena_catalog.gd` | Wa Bidi, Oh Tipi and S. Wayne have authored Conservatory, Tideglass and Basalt campus courts | Use these real places and collision contracts; the first route needs no new district |
| `src/app/signature_challenge_session.gd:99` | The current bound world, paid damage, actual owned defeat, offline eligibility and sticky developer taint govern the once-only reward | Coordinator consumes this result; it cannot decide damage, grant a spell or infer victory from health alone |
| `src/app/signature_rival_policy.gd` | Family-specific windup/pressure/recovery, committed aim, real movement and real wall-bank geometry supply eight patterns | Rivals are more than differently coloured health bars. Future content should strengthen recognizable decisions; do not claim a missing attack system |
| `src/app/solo_duel_trial.gd` and `src/sim/combat/interception_practice.gd` | A valid 120 Hz encounter lasts at most 8,640 ticks, including the four-second ready interval; death, timeout, leaving and interruption are explicit outcomes | Three successful legs have at most 216 seconds of encounter time. Learning, menus, retries and loading are outside that claim. A 5–15 minute first session is an observation question, not an authored duration promise |
| `src/app/signature_progression.gd:56` | Real victories can earn for the session even if persistence fails; retry/recovery and existing saved-weave compatibility already exist | A route must distinguish earned from saved and must not turn a save failure into a fake durable success or a forced gameplay dead end |
| `src/app/element_expansion_controller.gd:start_challenge` | Each challenge admits a fresh actual campus world and applies the chosen character/weave through existing setup | This is explicitly fresh encounter resources, not resource carry across three arenas |
| `src/app/range_target_scenario.gd` | Actual paid casts, health loss and six overlapping status durations already have an optional inspection surface | Link a learned spell to this existing tool; no new permanent HUD or inferred dodge score is needed |
| `tests/unit/test_signature_progression.gd` | Real paid counterplay already clears all delivery families and reloads learned access | Strong authority evidence; not proof that unfamiliar players perceive distinct choices or enjoy the route. The shared counter helper's Fire strategy is not evidence that every learned spell is necessary |

## Approved first slice: Rival Circuit

Owned new files are `src/app/signature_circuit.gd`, `src/presentation/signature_circuit_panel.gd` and `tests/unit/test_signature_circuit.gd`. Root owns controller integration, real paid integration tests and registry. Experience owns the menu entry/compact-map repair. Technical and Experience independently source-review the new state and panel.

The model contains only bounded current route/result state: run, leg, attempt, detached terminal result and aggregate observed encounter ticks. It owns no world, cast, audio, save file or event history. Start/admit, next/admit and retry/admit are separate; the coordinator advances only after the existing real world transition succeeds. A terminal callback is consumed once for the matching rival. Optional captured tickets reject deferred callbacks from a different run/attempt; root's synchronous observation reads the current bound challenge. Clean victory requires the existing reward `ok`, matching signature wire and no developer taint. Save refresh can update saved/notice only, never result eligibility.

The three legs are Wa Bidi → Oh Tipi → S. Wayne. A clean nonfinal result offers **Next with learned spell**, ordinary **Next** and **Leave**. Learned use is an explicit temporary slot-1 choice for the next fresh encounter; the saved weave remains unchanged. It is not mandatory, not an automatic cast, and does not create a free authority source. Defeat, timeout, leaving the court or unqualified victory offers a fresh retry of the same rival. Final completion offers exact learned-spell Range practice, a fresh replay or leave. External transitions discard the route but preserve legitimately earned progression.

The result panel is deliberately compact at 480×270 logical: rival/stage, observed elapsed/health/casts or route time, learned/already-known plus saved/not-saved, fresh-resource/time rule, and one relevant action hint. Four actions at most, meaningful hit targets, keyboard/pad/stick/pointer parity, no always-on second combat HUD. Existing save retry/recovery remains available. Native visual and real first-session acceptance remain separate from source/font/geometry assertions.

Do **not** force use of the reward before admitting the next leg. It can narrow legitimate counters, turn an optional learning route into an equipment chore, and conflate a persistence problem with combat qualification. The explicit learned-next option tests whether players voluntarily experiment while preserving the normal weave choice.

## Acceptance and failure criteria

1. Pure coordinator tests cover mismatched rival, nonterminal view, duplicate result, failed admission, clean/tainted/unearned victory, defeat/timeout/interruption, new retry/run tickets, detached views, persistence-only refresh and exit. Prepared views are labelled as coordinator tests, not paid combat evidence.
2. Root's real controller journey must start each authored court, admit/pay/release real attacks, produce genuine owned victories, preserve saved normal weave, equip the actual learned wire, complete exactly three legs and return through Range/free exploration. A bare-health terminal must not earn/advance. No health cuts, resource grants or fabricated events are allowed in the successful route.
3. Input/geometry checks use actual transformed pointers and physical control paths. Compact result targets never overlap. All three authored reward strings, unsaved/recovery and complete states fit. New result focus resets; echo/held input cannot advance two worlds. Current controllers retain modal quarantine and the original gameplay router.
4. Persistence requires its own real earn/save/close/reload boundary before advertising durable progression. Memory-only integration intentionally says not saved. Current preferences-only lifecycle evidence is not a substitute.
5. Observe unfamiliar players launching, identifying the objective, explaining one rival tell, finishing or deliberately leaving, understanding the reward/save status and voluntarily choosing next/retry/learned use. Record misunderstood decisions before coaching. No fixed percentage is promised from a tiny formative sample.
6. Stop expansion if players cannot explain what changed after a win or if the route feels like three identical fights. Investigate clarity/decision design first; do not compensate with currency, procgen, more recipes or blanket speed/damage buffs.

## Later candidates, distinct from this implementation

- **Rival identity and rematches:** one additional bounded pattern variation in the same authority, after the first route shows a meaningful decision. Telegraph, commitment and recovery must remain real. Avoid adaptive health/speed or hidden resource cheating.
- **Chemistry consequence:** one authored encounter asks a readable choice between direct pressure, delayed zone and a committed reflected lane. Use existing six-element/63-mixture grammar and finite sources. A new AoE allocation policy is a separate protocol/balance migration from the prior design, not part of Circuit.
- **Action readability:** complete one coherent illustrated action set, then three anatomies in this route. Foot contact, strafe/backpedal, release and recovery synchronize to actual state; cosmetic interpolation adds no authority delay. Existing explicit missing action art is stronger evidence than another generic smoothing pass.
- **World purpose:** one useful continuous workshop/Academy doorway attached to a route courtyard. Tall-wall/self-visibility contracts and room/LOS authority must be designed together. Decorative height is not projectile altitude or a climbable roof. Continuous door walking preserves held movement and paid attacks; only genuine transfers use travel quarantine.
- **Replay variety:** optional challenge restrictions or a remix can be considered after replay intent is observed. Do not introduce a second persistent economy or promise procedural replayability from a fixed three-leg route.
- **Multiplayer:** Circuit remains offline. Cooperative competitive route ownership, join/reconnect, rewards and shared target credit need an explicit new contract and real multi-device acceptance; existing snapshot tests alone do not qualify that expansion.

## Primary developer precedents and limited inference

- [Supergiant, Hades FAQ](https://www.supergiantgames.com/blog/hades-faq/) describes varied attempts, knowledge carried between attempts, optional story engagement and an iterative development structure. Transfer: a readable attempt/return/choice loop and feedback-led scope. It does not establish that H.E.X. needs Hades' story volume, permanent stat growth, or that a similar loop predicts commercial success.
- [Noita, official developer site](https://noitagame.com/) presents spell construction and simulated material interactions as a core reason to experiment, with learning across deaths. Transfer: make a combination's visible consequence worth testing in a concrete situation. It does not justify adding full pixel destruction or assuming combinatorial breadth alone creates retention.
- [Paradox, Magicka](https://www.paradoxinteractive.com/games/magicka/about) describes combining elements and using that system in campaign/challenge play. Transfer: a small common verb grammar can support situational expression. The current H.E.X. six elements and delivery structure remain its own contract; no imported extra element list is needed.
- [Dodge Roll/Devolver, Enter the Gungeon on Steam](https://store.steampowered.com/app/311690/Enter_the_Gungeon/) presents the fight/roll/cover loop, distinctive weapons and authored rooms combined into runs. Transfer: recognizable verbs in compact authored challenge units. A complete procedural roguelike is not a prerequisite for a useful first Circuit.

These are design references, not market proof. A commercial assessment still lacks external audience observations, distribution testing and comparative demand evidence. The concrete product bet is small enough to test using already-working authority while protecting the qualified package.

## Cross-review record

Technical's breakthrough draft was reviewed for Circuit/reward/network and source-versus-portable boundaries: no blocker. It preserves one simulation owner, actual save semantics, matched observer calibration and separate physical-player evidence. Experience's draft was reviewed for phase/height/occlusion/learning truth: no blocker. Richer pre-leg inspect/loaner briefing and a historical three-leg recap are future refinements; the present slice starts the existing ready countdown and presents the actual current result/aggregate time. Both peers source-approved the coordinator/panel scope; root parser, test and native gates are still pending at this writing.

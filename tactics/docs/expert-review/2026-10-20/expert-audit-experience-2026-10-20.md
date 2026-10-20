# H.E.X. experience audit — maps, progression, encounters, co-op

Analysis and implementation plan only. Source inspected at `592855cbd88c070683d0c1fdc1fa0eaf235a0514` on 20 October 2026. No runtime edits, build, deployment, heavy test run, or new player study were performed. Paths and line references below are relative to `outputs/hex-confluence`.

**Design judgment:** H.E.X. already has enough mechanical ingredients and content for a distinctive game. Its highest-value next step is to make a smaller set of encounters deliberately express those ingredients, then measure whether players recognize and exploit the choices. More map area, catalogue entries, or explanation panels would not solve the structural issues below.

The intended experience is worth preserving: choose where to fight and whom to bring; predict a simultaneous exchange; change the battlefield together; learn a defeated opponent's technique; arrive upstairs with a changed party and a reason to choose differently.

## What the raw implementation establishes

### Strengths to protect

- **Reproducible decisions.** Room identity, enemy kits, reward candidates, terrain, routes, and scouting are seeded. A seed is a useful shared challenge and a debugging fixture. Existing save variants and private seats are preserved.
- **A coherent combat vocabulary.** Terrain, spells, statuses, displacement, affinity, and creature bonds matter both in battle and in preparation. This is a better basis for depth than disconnected room minigames.
- **Understandable victory.** Defeat the opposing team. Closing ground and healing reduction pressure stalemates without changing the victory condition into points. See `lib/tactics-v22.ts:35`, `:42`, and `lib/tower-endgame-v22.ts:7–15`.
- **Knowledge survives a meaningful loss in Story.** Individual enemies teach their own techniques; field encounters let players pursue a particular teacher rather than grind random drops. See `lib/campaign-encounters-v20.ts:25–31`, `lib/spells-v20.ts:43`.
- **Small active parties and reversible preparation.** Each player begins with two fighters and can reach three; four equipped spells plus a signature constrain the actual decision set. Reconfiguration between rooms supports experimentation.
- **Co-op permits both independent and joint play.** Different destinations produce separate fights; equal destinations form one battle. A common next-floor destination makes reunion possible. Floor barriers share knowledge while preserving each squad's wounds and rewards. See `lib/tower-rooms-v23.ts:54–62`, `:67–89`; `lib/tower-route-map.ts:15–21`.
- **The latest route UI addresses genuine usability barriers.** Every path fits the screen, large destination cards duplicate small map targets, committed destinations differ from inspected ones, and friend destinations have direct actions. Keep this work; do not redesign it again merely for novelty.

### Exact lightweight probe

I ran a read-only construction probe, not a combat simulation: seed `AUDIT43`; the unedited `steam` preset for every occupied seat; first floor; joined comparison uses `floor-1-0` for every squad; split comparison uses the first N displayed doors, A through F for six players. No optimized routing, victories, reward claims, or human behavior is assumed.

| Occupied players | Visible branches | Choices after first floor* | Joined map cells | Joined allies / enemies | Joined enemy species | Joined enemy teachings | Teachings across first N separate doors |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 2 | 271 | 2 / 2 | 2 | 2 | 2 |
| 2 | 4 | 3 | 271 | 4 / 4 | 2 | 2 | 4 |
| 3 | 5 | 3 | 331 | 6 / 6 | 2 | 2 | 6 |
| 4 | 6 | 3 | 397 | 8 / 8 | 2 | 2 | 7 |
| 5 | 7 | 3 | 469 | 10 / 10 | 2 | 2 | 8 |
| 6 | 8 | 3 | 547 | 12 / 12 | 2 | 2 | 9 |

*Before the final mandatory room. Numbers are direct model output, not proof of balance, difficulty, enjoyment, or victory probability.

### The run's tension should be judged floor by floor

The relevant question is what the player risks, gives up, and learns at a fork—not how many doors are drawn.

| Floors | Existing tension | What the next prototype should establish |
|---|---|---|
| 1–2 | Safe combat versus an elite; knowledge and recovery compete with lasting growth | A novice understands what makes the elite riskier; the first wound changes a later choice |
| 3 | Recruitment, recovery/practice, or tuition paid in health | All three can be reasonable for different parties; exact reward uncertainty does not obscure the known cost |
| 4–5 | Continue the build under pressure; floor five may offer recruitment | A new third actor is a deliberate change in role/bond, not automatically better than every alternative |
| 6 | Recovery, recruitment, tuition; a companion upgrade may appear at camp | A route can repair a weakness without erasing all consequences of earlier fights |
| 7–8 | Risk for final preparation versus conserving wounds; a camp exists on floor eight | Some information about the final threat makes this a preparation decision rather than a generic “more power” choice |
| 9 | Spend the build's accumulated options to defeat the final party | The fight calls back to a learned skill and rewards adapting to its arrangement |

This is a proposed evaluation lens, not a claim that every current seed achieves the intended tension. Co-op overlays the choice to gather for safety/coordination or split to expose more teachers; both choices should remain credible for some party states.

## Findings and bounded implementation proposals

### P1 — Co-op scales quantity more convincingly than composition

**Confirmed structure.** `createSharedTowerBattle` concatenates each squad's independently generated enemies, then increases map radius through the player count (`lib/tower-shared-battle-v23.ts:8–17`). Enemy generation uses seed, floor, lane, and immutable starting affinity tier (`lib/tower-v23.ts:114–137`). Matching starters at the same door therefore bring repeated enemy kits. Learned spells are unioned across all squads when the floor barrier opens (`lib/tower-rooms-v23.ts:54–62`).

The probe above is a concrete example: a six-player first room contains six copies of each of two enemy species. Splitting across six destinations exposes nine distinct teachers instead of two.

**Interpretation, not a defect claim.** Broader knowledge is a sensible reward for splitting and accepting independent risk. It should not be equalized automatically. Joining needs an observable compensating benefit: rescue, flexible positioning, richer coordinated exchanges, or a safer way through a difficult composition. The current code supplies a shared allied pool and one paid link bonus, but this audit does not establish whether that compensation is sufficient.

**Smallest useful change.** Author a group composition pass over the existing creature/champion catalogue, preserving the encounter's rough threat budget and its shown identities. Keep the original encounter's key teacher; vary support, controller, and pressure roles for additional squads instead of repeating the complete kit. First prototype only two joined encounters, at two and six seats. Do not grant techniques from enemies that were not defeated.

**Owner/dependency.** Encounter/progression owner defines the composition contract. Combat owner supplies effect-budget measures and verifies AoE/bond interactions. Co-op service owner owns grouping, canonical scout identity, and persistence. UI consumes the final encounter, never a separate estimate. New generation must be versioned so an existing door or saved battle cannot silently change.

**Acceptance.** Correctness: deterministic composition; no duplicate actor IDs; every learned enemy technique maps to an actual defeated actor; scout reports match the launched roster; mixed 4/7/10-affinity starters restore correctly. Play hypothesis: compare joined/split loss risk, remaining HP, time per floor, distinct meaningful player actions, and reasons given for joining. At least one joined configuration should be preferred for an articulated tactical reason beyond social politeness. No numeric win-rate target is justified yet.

### P1 — Large maps do not yet imply different tactical problems

**Confirmed structure.** The arena always uses a hexagonal outline, fixed biome proportions, short patches, roads toward the centre, and a connectivity repair (`lib/arena-v17.ts:23–24`, `:41–76`). Tower deployments override the peripheral camps and place the first three fighters near the same two central positions on every seed (`lib/tactics-v22.ts:169–175`). Starting room variations are six central field cells using only flooded, embers, draft, or plain (`lib/tower-v23.ts:148–151`; `lib/tactics-v22.ts:176–177`). Closing ground is also centred on the origin.

**Interpretation.** Central deployment is a good fix for empty walking turns and should stay. However, variable terrain patches around a common engagement can produce cosmetic diversity without a different first decision. More than doubling map area from solo to six players does not demonstrate that the additional area matters.

**Smallest useful change.** Add three deterministic Tower layout motifs using current tiles and rules:

1. **Broken crossing:** two passages across shallow water, one wide exposed approach and one narrow covered approach; pushing and freezing alter the route.
2. **Boiler passage:** a broken wall and a wet pocket create two projectile angles; fire can trade direct damage for steam cover.
3. **Terraced grove:** one existing-height ridge, interrupted forest cover, and a flank that takes one extra movement decision; concentrated support competes with spreading against area damage.

Use seeded rotation, reflection, and bounded decoration within each motif. Do not add elevation levels, new objectives, destructible systems, or longer walks. Keep elimination and an early useful action. Room identity should select a compatible motif so “Boiler room” is a place, not an arbitrary caption over the same generator.

**Owner/dependency.** Level/generation owner; combat owner validates movement, line-of-sight, force, fields, and closure on the motifs; art owner places only existing coherent assets. The map ID/generator version and saved geometry must preserve old runs.

**Acceptance.** Correctness: unique legal spawns; reachable alternatives; no forced spawn damage; no disconnected walkable pockets; no route made impossible by the initial field; all closure phases remain solvable by movement. Experience: ask players to name the map's distinguishing decision after two rounds. Compare first contact, hexes actually used, repeated opening plans, and time spent moving without a useful cast. Provisional target: first meaningful attack/control/position contest by round two, with two credible approaches; validate rather than enforce blindly.

### P1 — “Elite” and the final room need authored tests of mastery

**Confirmed structure.** Floor progression chooses a few count/budget templates (`lib/tower-v23.ts:120–137`). The final room is two randomly selected champions plus one creature; its name and flavor are fixed (`:141–147`). Late non-boss rooms already contain a champion and two creatures. Elite rewards can grant two affinity, but there is no dedicated elite encounter grammar beyond stronger members/counts. Names are independent of enemy element or tactics (`:104–151`).

**Interpretation.** Difficulty can rise numerically while encounters remain hard to remember. A final room should test a skill the player has had opportunities to learn, not merely contain a larger number.

**Smallest useful change.** Create three final-room compositions from existing actors: a protected support pair that must be separated, a displacement formation with a dangerous landing, and a clear two-element field setup with a visible counter. Seed chooses one; the route reveals its broad threat early, while exact kits remain partly unknown. Give each a deliberately compatible map motif. Preserve full-team elimination and the teacher mapping. Do not add boss health bars, immunity phases, or extra systems before these compositions work.

**Owner/dependency.** Encounter designer after map motif and threat measurement work. Combat/AI owner checks whether AI actually performs the composition's advertised tactic. UI owner displays only the useful threat cue.

**Acceptance.** Correctness: enemy planning can legally execute the intended pattern; at least two legal counterplans exist from the opening; display and actual roster agree. Play hypothesis: players identify why the fight was difficult and change their second attempt accordingly. “I needed bigger numbers” should not be the only intelligible lesson. Evaluate all seven suggested starters plus deliberately weak/strong custom examples, not only one bot build.

### P1 — Initial-tier scaling should be measured as a progression curve, not mistaken for ongoing balance

**Confirmed structure.** Tower enemy tiers depend on starting team affinity, not earned upgrades, current wounds, recruited members, or the actual starting kit (`lib/tower-v23.ts:92–94`, `:114–137`). This avoids punishing successful drafting with automatic enemy inflation. Champions can be reconfigured freely between rooms while preserving total affinity and primary constraints (`:262–268`). Recruitment offers two shuffled champions and one shuffled creature (`:207–212`). Training offers prioritize a champion's primary affinity (`:186–200`).

**Interpretation.** The predictable difficulty curve and free experimentation are strengths. They also mean “Fire practice” is ultimately a fungible affinity increase once the player reconfigures, while acquiring a third actor creates a large action-economy change. A random recruit can therefore be much more consequential than +1 affinity, depending on timing. This requires whole-run evidence; first-fight win rates cannot answer it.

**Smallest useful change.** First gather draft exposure/selection, party count, total affinity, actual equipped kit, wound burden, and room outcome over full runs. Keep immutable initial scaling. For recruit offers, guarantee one credible relationship with the current party and one contrasting option, using existing affinities/perks rather than inventing new bonuses. For training, show the before/after kit and explicitly retain reallocation freedom. Avoid selling the chosen element as a permanent commitment.

**Owner/dependency.** Progression owner with local observation/export support from integration owner; UI owner retains exact existing reward consequence previews. Encounter budgets should be tuned only after this evidence.

**Acceptance.** Correctness: every shown recruit is legal and every claimed reward changes what its preview says; all-creature squads still have useful rewards; primary caps and four-spell loadouts remain valid. Experience: offer choices are explained in terms of current wounds, counters, synergy, or future plans. Track whether a category is ignored conditional on availability and need, not its global pick rate. A high heal pick rate among badly wounded parties is not automatically a problem.

### P2 — Scouting spends a scarce action on facts of very unequal decision value

**Confirmed structure.** Each living champion scouts once per floor. The choice of the additional fact is deterministic but random in type (`lib/tower-scouting-actions.ts:18–41`). Facts include identity, every affinity rank, exact health, individual spells, and environment; one spell per enemy is deliberately excluded (`lib/tower-scouting-state.ts:27–42`). The baseline clue varies by floor/lane (`lib/tower-scouting.ts:41–69`). For the probe's first room there are eight extra facts; one champion reveals one.

**Interpretation.** Partial information is central to the user's requested route decisions and should stay. Learning the normal health of a familiar creature can be far less actionable than seeing a control spell or discovering the room's field. Adding champions increases scouting actions, but does not ensure those actions help choose a room. Mixed starter tiers intentionally cannot share incompatible encounter facts; preserve that protection.

**Smallest useful change.** Keep one random aspect per champion, but select from three useful categories before selecting the exact fact: enemy threat/role, an equipped technique, or terrain. Rank already-baseline or redundant facts lower; preserve a concealed technique and genuine uncertainty. Before changing RNG, instrument whether scouting caused a different destination, loadout, formation plan, or verbal confidence. Do not add a new scouting menu.

**Owner/dependency.** Progression/information owner; service owner for shared canonical reports; UI owner for concise concrete wording. Requires the encounter composition contract first.

**Acceptance.** Correctness: scouts cannot reveal a different squad's variant or an unearned full kit; repeat/reconnect cannot reroll; one actor cannot spend twice. Experience: participants can state what the clue changed or ruled out. If most scouting is described as routine clicking, redesign the fact pool rather than increasing the number of clicks.

### P2 — The route's structure has limited seed-level character

**Confirmed structure.** The solo graph has two outgoing choices; larger graphs have three, including a fixed central rendezvous lane and the current lane (`lib/tower-route-map.ts:11–24`). Room categories repeat by lane modulo three and floor (`lib/tower-v23.ts:154–158`). Floors three and six are entirely service floors. The common meeting lane is 1 for two players, 2 for three/four, and 3 for five/six.

**Interpretation.** Guaranteed reunion is valuable and matches the user's synchronized-floor intent. However, fixed meeting lanes plus fixed category stripes can become a memorized policy: the same central lane has the same type of service regardless of seed. Visible extra branches do not mean each squad has eight available choices after the first floor, and the UI should not imply otherwise.

**Smallest useful change.** Keep one reachable rendezvous from every prior branch, but seed its lane by depth and rotate the category assignment with constraints. Guarantee at least one meaningful preparation alternative before the finale, and avoid repeated equivalent choices within a three-room fork where possible. Preserve mandatory shared floor progression and every path's visibility.

**Owner/dependency.** Route/progression owner; service owner and route UI reviewer. Requires a generator version because old runs reconstruct route edges from seed.

**Acceptance.** Correctness: every node is reachable, every split group can reunite next floor, all routes terminate, choices remain reproducible, old seeds keep old semantics. Experience: the player can point to a future room that influenced a current route choice. Measure category diversity of reachable forks, not just distinct room IDs or map seeds.

### P2 — Co-op coordination has a costly unanimity point and an idle-time floor

**Confirmed structure.** Every living squad must choose before rooms launch, and every active squad must finish its room/reward before the floor advances (`lib/tower-rooms-v23.ts:30`, `:54–62`, `:67–70`). Shared exchanges require all surviving controllers to lock (`:84–89`). The link flag is true only when every required plan consents (`:88`), but the resolver spends one Flux from exactly two casters and awards only one extra damage to one target (`lib/tactics-v22.ts:495–503`).

**Separate the barriers.** Local animation/review is a presentation state: it blocks that player's planning until they continue (`app/components/TowerBattleV23.tsx:63`, `:77`, `:92–94`). The shared Ready barrier is server state and advances only when the required controllers lock. Preserve the no-rush local review; its purpose is understanding the last exchange, not synchronizing everybody's animation clock. An observer with no surviving controlled fighter is not required to lock, so their ongoing review must not be used to hold the fight.

**Absence and rejoining limits.** An existing token can recover its seat after launch; a new participant cannot join an active climb (`lib/tower-rooms-v23.ts:118–125`). Closing/leaving the UI saves the seat rather than retiring it (`app/components/CoopTowerV23.tsx:105`). Retirement is explicit and terminal for that squad (`lib/tower-rooms-v23.ts:152–155`). The room expires seven days after creation (`:8`, `:114–115`); the update query changes `updated_at`, not `expires_at` (`:49`). Thus “resume later” currently means a valid original seat within that window, not an indefinitely resumable campaign or a drop-in replacement. A disconnected required seat can leave others waiting; do not misreport this as resolved merely because reconnection tests pass.

**Interpretation.** Synchronization is requested behavior, not a bug. It nevertheless creates downtime when one squad enters a service room while another fights, or when a single participant repeatedly takes much longer. Likewise, a six-person consent switch for one two-caster bonus may be more coordination overhead than tactical pleasure. Existing watch actions and visible friend phases already help; preserve them.

**Smallest useful change.** First observe real two-, four-, and six-person runs. Measure active decision time, waiting time, and whether watching is used. For link, prototype an explicit preview of the actual contributing pair and target using the existing mechanic; consider consent from only the participating controllers if that improves comprehension. Do not auto-submit another person's plan, impose an unseen timer, or let a squad skip the floor barrier. A resumable inactive seat policy is a separate product decision, not a casual QoL patch.

**Owner/dependency.** Co-op service owner plus interaction/preview owner; combat owner only if link consent semantics change. Requires explicit saved/protocol treatment.

**Acceptance.** Correctness: no non-consenting player spends Flux; displayed pair and charge match resolution; retired/defeated seats cannot deadlock exchanges; unlock/relock remains safe; original-seat reconnect preserves draft and review expectations; expired and missing-key cases describe the actual recovery limit. Experience: measure the waiting share of a floor and whether link is voluntarily used for an understood purpose. Test a mixed service/combat floor, one slow participant, a tab closed without retirement, and a returning original seat—not only synchronized scripted clients.

### P1 — The onboarding sequence explains rules but does not yet ensure a player has learned the central skill

**Confirmed structure.** Tower offers seven editable solo suggestions, full character configuration, seeds, route selection, and scouting. Battle help describes movement, simultaneous casts, friendly fire, collapse, healing reduction, wounds, and keyboard input (`app/components/TowerGameV23.tsx:156`, `:171`; `app/components/TowerBattleV23.tsx:122`). Story has authored lessons and progressive champion counts, but uses the same general arena generator and ordinary battle rules (`lib/campaign-encounters-v20.ts:8–23`; `lib/tactics-v20.ts:137–139`).

**Interpretation.** Concise help and precise previews are necessary, but reading them is not the same as correctly predicting a simultaneous exchange. Ground-fixed aim, next-round status timing, friendly fire, collision cancellation, and centre/rim strength are several interacting concepts. The first experience should expose them in a controlled order without forcing a large tutorial campaign.

**Smallest useful change.** Turn the opening Story encounter into an optional, replayable three-exchange learning situation using the same engine: move and aim at a landing; deliberately see two elements combine; prepare then exploit a status or safe displacement. Teach by highlighted existing controls and one task at a time; let experienced players skip. Keep the full configurable Tower start available. A subsequent normal encounter must test transfer without the highlight.

**Owner/dependency.** Experience owner authors the fixture and success conditions; combat owner guarantees deterministic setup; UI owner supplies tiny contextual prompts and dismiss/skip. No custom tutorial-only combat rules.

**Acceptance.** Correctness: tutorial and real engine agree, no forced impossible action, keyboard/touch both work, skip never destroys a save. Human study: five to eight first-time players explain the predicted movement/cast order, identify an unsafe ally hit, and produce a useful interaction unaided in the next encounter. Record completion without moderator help; treat a proposed 80% success threshold as a starting target, not a scientific guarantee.

### P2 — Story has a good teaching skeleton but weak consequence and payoff

**Confirmed structure.** Thirty champions map to thirty sequential Story encounters, with one/two/three opposing champions by chapter (`lib/campaign-encounters-v20.ts:8–23`, `:33–36`). Hero affinity reaches its cap after thirteen victories; stronger/more mixed creatures unlock by count (`lib/campaign-profile-v20.ts:22–35`). The legacy source has individual encounter situations and creature relationships (`lib/story-v16.ts:16–49`, `:83–120`), while the current encounter model imports the situation and lesson but has no relationship/consequence field. Tower humor is a small bank of room/service jokes (`lib/tower-v23.ts:104–150`).

**Interpretation.** A sequence of lessons can teach strategy without feeling like a journey. Increasing catalogue access is not the same as seeing a character remember something. Random room names disconnected from the actual terrain also weaken place and humor. The existing short, specific comic tone is better than adding generic banter.

**Smallest useful change.** Use three existing chapter anchors to create a tiny before/after thread: one concrete dispute, its battle, and a changed line on return or recruitment. Reuse established relationships rather than inventing lore. Tie one short reaction to an actual event—Treevor's failed wall, a wet fire caster, a companion rescued from a bad landing—with a per-run repetition cap and no interruption. Give the final Tower room a setup/payoff connected to its composition.

**Owner/dependency.** Narrative/experience owner after encounter decisions are fixed; UI owner for optional nonblocking presentation. Canonical cast/world review is mandatory.

**Acceptance.** Correctness: lines trigger only when their events occurred; no reference to absent actors or unavailable mechanics; no repeated bark spam. Experience: players recall one character relationship or amusing consequence unprompted after a session. Do not measure charm by word count or number of lines.

## Primary-source principles that transfer

These are principles, not instructions to copy another game's combat system or visual identity.

- **Slay the Spire: metrics support judgment; they do not replace it.** Anthony Giovannetti's own GDC presentation describes iterative balancing, skilled playtesters, feedback tools, and skill stratification. Its explicit warning is that data is evidence rather than a conclusion. Applied here: segment by starter, player experience, party size, room type, and offer availability; pair outcomes with observed decision explanations. [Original GDC slides](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf), particularly pages 6–15.
- **Gloomhaven/Jaws of the Lion: preserve the satisfying core while removing barriers; teach in encounters.** Isaac Childres describes introducing rules gradually through carefully designed opening scenarios. Applied here: teach H.E.X.'s movement/cast/interaction sequence in a small real battle, rather than asking players to absorb the catalogue first. [Designer article](https://cephalofair.com/blogs/chronicle/so-i-should-probably-talk-about-the-new-thing).
- **Gloomhaven: complexity belongs in choices rather than rule bookkeeping.** The designer specifically distinguishes rich card decisions from adding every interesting rule. Applied here: vary arrangements of existing actors, fields, and geometry before adding another status, upgrade track, or room currency. [Simplicity is key](https://cephalofair.com/blogs/chronicle/simplicity-key).
- **Battle Brothers: terrain is strategic context, not decorative randomness.** Its official combat overview links generated terrain to the world location and describes movement, sight, and elevation consequences. Applied here: a route's room identity should predict a meaningful geometry/field problem. H.E.X. should retain simultaneous magic rather than copy initiative or opportunity attacks. [Official tactical combat overview](https://battlebrothersgame.com/tactical-combat/).
- **Final Fantasy Tactics: character presence and controls sustain appreciation of the systems.** The remake's director describes contextual battle dialogue that develops recruited characters, together with extensive usability work. Applied here: a small amount of event-true character response can make the existing roster feel alive without adding mandatory dialogue. [Official developer interview](https://blog.playstation.com/2025/07/21/the-secrets-behind-final-fantasy-tactics-the-ivalice-chronicles-makeover/).
- **Buttons & Bugs: being interesting to analyze is not proof of being enjoyable to play.** The developer diary describes a design the creators enjoyed examining but most testers did not continue playing, leading to a major redesign. Applied here: catalogue size, deep audits, and bot wins are not acceptance evidence for fun. [Cephalofair designer diary](https://cephalofair.com/blogs/chronicle/cephalofair-designer-diary-issue-5-buttons-bugs).

## Implementation order and cooperative ownership

Use four active lanes with explicit data contracts, not four simultaneous rewrites of the same components.

| Stage | Lead owner | Deliverable | Required review |
|---|---|---|---|
| 0. Baseline | Integration / QA | Reproducible run sheet and opt-in local run export: offers, choices, wounds, rounds, waiting, actual interactions | Experience reviewer checks that data can answer a player question |
| 1. Readable first mastery | Experience / UX | One optional opening fixture and one unguided transfer encounter | Combat verifies exact consequences; fresh-player observation |
| 2. Meaningful battlefields | Level / progression | Three existing-asset motifs with seeded variants | Combat path/LoS/closure checks; art coherence review |
| 3. Joined encounters | Combat / co-op | Two group compositions using actual existing teachers and measured budgets | Progression/UX verify scouting, displayed threats, rewards, and consent |
| 4. Run-level decisions | Progression | Recruit relationship offers, constrained route variation, useful scout pool | Full-run balance review and save-compatibility review |
| 5. Character payoff | Experience / narrative | Three chapter callbacks and a few event-bound lines | Canonical identity review; repetition/readability review |

Cross-review each stage in four roles: rules correctness, decision quality, interface comprehension, and observed play. Finish and evaluate stages 1–3 before expanding stage 4. If the first prototype fails to change how people play, do not build the rest of its content.

## What would show the result is right

**Correctness evidence:** deterministic fixtures and old-save replay checks; route/rejoin invariants; preview-to-resolution agreement; player ownership and consent; teacher-to-learned-spell identity; varied legal custom builds; keyboard and phone decision paths. The current tests already cover valuable invariants, including seeded forks/reunion (`tests/tower-route-scaling-v42.test.ts:7–58`), service/reconnect width (`tests/tower-scaling-review-v42.test.ts:30–118`), and bounded first fights (`tests/tower-model-v23.test.ts:85–89`). They should remain intact.

**Balance evidence:** whole runs, not only openings; seven proposed solo starters and boundary custom teams; two/four/six-player matching and mixed squads; joined, split, and rejoined routes; wounded and healthy states. Track deaths/HP, rounds, collapse damage share, learned/equipped techniques, recruit timing, and room/reward choice. Existing model helpers sometimes bypass combat to reach later floors (`tests/tower-model-v23.test.ts:15–16`); those are excellent progression tests but cannot be presented as full-run balance proof.

**Experience evidence:** first-time players can state what will happen before committing; returning players choose a different valid plan when geometry or enemy composition changes; co-op participants can explain their contribution and spend an acceptable share of time deciding rather than waiting; players voluntarily start another seed and can name a specific moment they enjoyed. Observe behavior and ask short, concrete questions after the action. Do not substitute enthusiastic design prose, simulated completion, aggregate clicks, or a single “did you like it?” answer.

**First experiment recommendation:** preserve the current release; prepare one optional teaching encounter, one new geometry motif, and one two-/six-player joined composition behind a new generation identity. Compare against the current seed-matched experience. That is a deeper test of H.E.X.'s identity with a controlled scope.

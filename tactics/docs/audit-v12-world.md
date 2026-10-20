# Rules 12 world and inhabitant audit

Audit role: third independent reviewer across all 24 game-design areas. Read-only findings preceded implementation. Sources inspected: `lib/tactics-v11.ts`, `lib/story-v11.ts`, `lib/spells-v11.ts`, `lib/arena-v7.ts`, `lib/practice-v11.ts`, `lib/game-audio-v11.ts`, `lib/battlefield-motion-v11.ts`, `app/TacticsGame.tsx`, `app/components/PixelBattlefieldV11.tsx`, `app/components/StoryJourneyV11.tsx`, and `docs/V11-STORY-AFFINITY.md`.

The central opportunity is a predictable, inhabited elemental landscape. Creatures should have recognizable desires and public intentions that players can exploit or interrupt. Their behavior connects tactical depth, story character, environmental life and clear feedback.

The main structural problem in rules 11 was `reactionsFor()`: it returned every contained pair, so six elements accumulated fifteen pair effects. The renderer consequently showed two names followed by an overflow count. A full mixture needs one identity and a bounded consequence, not every subset running underneath it.

## All 24 areas: finding, creative response, acceptance

| Area | Finding in the inspected source | Proposed response | Acceptance |
| --- | --- | --- | --- |
| Identity | Simultaneous fields are distinctive; story is mostly tactical descriptions of champion duels. | Make the landscape a predictable third participant with creatures that use the same elements. | A newcomer describes coordinated simultaneous action and environmental interaction after one encounter. |
| Turn structure | Movement, spells, statuses, displacement and recovery have distinct timing. | Publish creature intentions before planning; collect their ingredients in the same spell batch. | Input-order permutations produce the same mechanics and event order; previews agree with resolution. |
| Tactics | Current valuation concentrates on damage and wells. | Give local opportunities: shelter, a route, an inconvenient pulse, a contested benefit. | Every inhabitant permits using it, interrupting it, or ignoring it; none requires a routine extra click. |
| Elements | Fifteen contained pair reactions make larger fields cumbersome. | Exact six-bit lookup for all 63 nonempty subsets. | Each complete mixture resolves once; subset effects do not leak into higher mixtures. |
| Spells | There are already 48 ordinary spells and 30 signatures with varied footprints. | Let existing spells manipulate creatures and mixtures before adding more spells. | Basic spells remain useful environmental tools; precise consequence previews share resolver data. |
| Characters and races | Affinity and signatures carry mechanical character identity; race is mainly presentation. | Give champions concrete relationships with local inhabitants while preserving public rules. | Introductions contain a specific situation, not an invented hidden race bonus. |
| Team composition | Three characters can cover all six elements while individually retaining three-element limits. | Show available elemental coverage and relevant encounter opportunities. | Players identify a missing ingredient without inspecting three separate panels; six-element coverage is optional. |
| Progression | Thirty selectable encounters grant affinity for the first thirteen unique wins and signatures thereafter. | Introduce inhabitants in increasing complexity without adding collection currency. | Existing progress survives; no replay farming or new competitive access grind. |
| Resources/statuses | Existing environment caps, Resolve protection, healing reduction and Flux rules limit abuse. | Reuse these limits for inhabitants and exact fields. | No environmental damage bypass, indefinite control or unbounded recovery loop. |
| Objectives | All encounters share wells and score targets. | Change access and timing around existing objectives using creature fields. | No hidden victory requirement; a creature changes a genuine positioning decision. |
| Maps | Terrain is connected and varied, but permanent tile borders and repeated miniatures read as a board. | Join water and ground visually; draw elevation boundaries where height changes; soften idle grid. | Mechanical borders, feet, target shapes and passability remain legible. |
| Procedural generation | Mirrored, connected seeded geography is a useful foundation. | Deterministically constrain inhabitant perches away from spawns and solid terrain. | Every authored placement is legal and reproducible, with no first-turn spawn exposure. |
| Balance | Equal affinity is a gauge, not measured equality of composition strength. | Keep inhabitants story-only; use symmetric shared exact-field rules elsewhere. | No mixture wins every trade; compare seeds, seats and compositions rather than asserting balance from totals. |
| Story | Thirty fixed duels have no independent environmental cast. | One early inhabitant, two later, three in the final encounters; preserve bosses and rewards. | All 63 species appear across the existing campaign; each has a name, desire and visible behavior. |
| AI | Pair-specific estimates such as Steam damage reduction occur outside the resolver. | Consume exact-field definitions and public creature intentions when evaluating choices. | Never read hidden plans; avoid visible danger and exploit a useful public field when appropriate. |
| Multiplayer | Versioned rooms, sealed orders and fixed builds already preserve trust boundaries. | Preserve historical engines; keep NPCs out of player-team validation and affinity totals. | Replay and reconnect restore identical state; old rooms continue under old rules. |
| Onboarding | The opening already exposes three heroes, four spells, signatures and a large map. | Teach one creature and one field interaction through visible play. | A novice predicts the next pulse and plans a legal coordinated turn without reading a manual. |
| Interface | Order state repeats across cards, aim panel, selected unit, phase panel and turn bar. | Show one selected action, target consequence and remaining team actions; disclose details on demand. | Planning a common move plus cast requires no modal and no duplicate confirmation. |
| Controls/mobile | Many camera controls compete with planning and inspection. | Contextual camera focus and footprint fit; creature inspection reuses the board's interaction language. | Complete a turn at 320px without hidden controls, horizontal overflow or accidental casts during pan. |
| Visuals/animation | Existing route motion follows authoritative paths, but the landscape is tile-centric. | Continuous ground, clustered foliage, species silhouettes and readable anticipation. | Motion tells the truth; reduced motion preserves poses and warnings; assets do not obscure targeting. |
| Audio | Short synthesized notes mostly vary pitch rather than material character. | Distinct envelopes for water, air, stone, fire, light and dark; prioritize meaningful events. | Muted play remains understandable; busy resolution does not become an undifferentiated wall of sound. |
| Accessibility | Keyboard navigation and detailed tile labels exist; compound labels become long. | One mixture name and short consequence, expandable detail, shapes as well as colors. | Equivalent conclusions through text, keyboard, low-motion and muted modes. |
| Pacing/replayability | Repeated travel and well holding can dominate identical-size encounters. | Put meaningful public opportunities along routes; vary placement, not opaque rules. | Early rounds have choices; later rounds justify changing a plan; repeat seeds remain learnable. |
| Validation | Extensive automated tests establish rules, not charm or enjoyment. | Separate invariant tests, browser/input evidence and human play observations. | Exhaustive content and restore checks plus real phone planning and novice observation; no unsupported fun claims. |

## Concrete creature contract

Do not put neutral creatures into the player champion roster. They have no owner, affinity budget, loadout, knockout reward, respawn or extra currency. Rules 12 uses immutable `speciesId`, `q` and `r` state. The next intention is derived from those values and the public round.

Each species has a name, kind, body family, elemental mask, short desire, bounded footprint, interruption element and alternating rest/release cadence. Its pulse contributes ingredients to the same field batch as player spells. A spell of the stated counter element reaching its perch interrupts that release for either team. Existing terrain may change the resulting mixture. The creature rests the following turn regardless of whether it was interrupted; no concealed phase is introduced.

The body families are fox, otter, tortoise, bird, moth, cat, heron, salamander, toad, stag, serpent, bison and garden. They use distinct pixel silhouettes, element details, tails, wings and quiet motion rather than 63 copies of one colored shape. Their gameplay differences come from the exact mixture, geometry, public phase and counter element. They share bounded rule primitives to keep the game learnable.

The authored story allocation is one creature in each of the first three encounters, two in the next twenty-one, and three in the final six: 3 + 42 + 18 = 63. The six singles precede fifteen pairs, twenty triples, fifteen groups of four, six groups of five and the all-element Firstbud. Creature order does not add prerequisites or remove the existing encounter selection.

## Original creative directions and implementation boundary

The audit proposed creatures with a few reusable verbs: shelter, nourish, channel, displace, obstruct, consume, reveal and warn. Examples included Hush the kettle heron hiding a pool in Steam; Pebble packing loose ground into shelter; Nimbus leading a gentle shower across a crossing; Hollowbell tending seedlings beneath its antlers; and Firstbud carrying a seed from every place it has visited.

The implemented first pass deliberately represents these through real, bounded elemental releases and interruptions. It does not claim to implement bespoke wandering, nest simulation, creature quests, autonomous combat, or dialogue trees. Those would need further design and evidence. The current species' written desires provide character without creating misleading controls or hidden objectives.

## Five implementation priorities

1. Replace subset-pair accumulation with exact complete-mixture definitions in a new rules version, retaining old matches.
2. Prove a small deterministic inhabitant system end to end; keep it separate from player units and obey existing caps.
3. Simplify planning around who acts, where, the consequence, and remaining team actions.
4. Make the landscape continuous and animation purposeful without compromising the exact tactical grid.
5. Validate every species and mixture, then observe real players before calling the result intuitive or fun.

## World implementation evidence

`tests/inhabitants-v12.test.ts` covers all 63 masks and authored identities; the full 30-encounter allocation; safe deterministic placements independent of cell order; all public footprints and alternating phases; canonical intention order; strict immutable restoration; actual same-batch pulses; real counter spells from either player; existing v11 story storage compatibility; rejection of victory rewards with missing or moved inhabitants; and a complete legal inhabited match restored after every round.

These checks establish content coverage, deterministic mechanics and save/reward correctness. They do not establish competitive balance, professional art quality or human enjoyment.

## Final world-agent integration review

Status meanings: PASS means inspected implementation or focused automated evidence supports the bounded change; PENDING means visual/human/transport evidence remains for the integration owner; PRESERVED means this work intentionally leaves the established system unchanged.

1. Identity — PASS: an actual neutral elemental cast inhabits Story; charm and appeal remain human judgements.
2. Turn structure — PASS: engine batches public pulses with spells and announces interruptions; focused tests exercise release/rest/counter timing.
3. Tactics — PASS: either side may exploit or interrupt the same predictable local event; strategic quality remains PENDING playtesting.
4. Elements — PASS for all 63 lookup/inhabitant matches; systems reviewer owns effect-distinction and interaction regression gates.
5. Spells — PRESERVED catalogue; existing spells supply the counterplay without new slots or currencies.
6. Characters/races — PRESERVED original 30 champions; PASS on 63 separately authored names, kinds, desires and 13 visual body families.
7. Team composition — PRESERVED three-character teams and original affinity constraints; NPCs never count as units or team strength.
8. Progression — PASS: same v11 profile key and format, trained builds retained, original signature/affinity reward rules tested.
9. Resources/statuses — PRESERVED bounded shared effect kernel; systems integration owns the complete status/cap regression run.
10. Objectives — PRESERVED well scoring and win conditions; inhabitants introduce local environmental decisions only.
11. Maps — PASS on legal safe deterministic creature locations; continuous-landscape visual judgement PENDING browser review.
12. Procedural generation — PASS on all 30 story seeds and cell-order-independent placement; generator itself unchanged.
13. Balance — PENDING human and seeded comparison evidence; equal affinity is still a gauge, not proof of fairness.
14. Story — PASS: all 63 species appear once across 30 existing encounters, with 1/2/3-creature introductory progression.
15. AI — PASS by source inspection that practice planning reads public pulses and exact-field helpers; no claims about opponent skill.
16. Multiplayer — PRESERVED NPC-free ordinary creation; versioned room integration and HTTP checks belong to root.
17. Onboarding — PASS on one creature in the first three encounters and plain next-action/counter tells; novice comprehension PENDING.
18. Interface — PASS on collapsed encounter details and compact inhabitant preview; integrated interaction quality PENDING browser review.
19. Controls/mobile — PENDING physical/browser interaction checks; creature renderer exposes no blocking hit targets itself.
20. Visuals/animation — PASS on distinct code-native pixel body families, element details, grounded poses and reduced-motion CSS; visual quality PENDING observation.
21. Audio — PASS by source inspection of material/combination-aware new audio path; sound mixing and listening PENDING.
22. Accessibility — PASS on text tells, counter labels and reduced motion in owned components; integrated keyboard/phone checks PENDING.
23. Pacing/replayability — PASS on fixed public alternating phases, no added currencies, tasks or campaign screens; match feel PENDING.
24. Validation — PASS: 11 focused tests, including full legal match and actual either-team counters. Full build, HTTP, browser and human evidence are separate.

Cross-review raised a concrete integration issue: the board's local 'Forms' forecast initially omitted public creature pulses while the main action preview included them. Reported directly to the experience owner for correction before release. Also raised duplicate single/pair mechanic profiles with the systems owner for explicit design review instead of assuming 63 named records guarantee 63 distinct effects.

## Final content cross-review and fixed-seed diagnostic

A second content pass reviewed all 63 field names, short rules and generated descriptions against their authored mechanics, plus every inhabitant's identity and placement. The systems owner resolved the initially duplicated single/pair effect profiles. The final catalogue retains distinct full mechanics for all 63 masks. Desires remain characterization; they do not promise unimplemented creature quests or independent wandering.

All 30 story introductions now contain one concrete relationship between the champion and every local inhabitant. These short scenes replace the tactical paragraph in the immediate introduction; the original useful mechanical advice remains under `Opponent tactics`. No new objective is implied. The shared story profile, signature rewards and encounter strength remain unchanged. A focused assertion verifies that every introduction names its champion and all assigned inhabitants, and stays below 200 characters.

The new `spells-v12.ts` wrapper was reviewed. Active UI cards use `effectiveSpell`, whose generated freezing description correctly states that unmixed Water freezes and mixed fields follow their own rule. The wrapper initially retained older static freezing prose in `getSpell` and catalogue constants; this was reported to root so those exported descriptions can be aligned as well. No engine edits were made by the world reviewer.

The independent AI diagnostic ran two equal-affinity teams on three fixed seeds, then swapped seats on every seed. Every result was restored through the strict state validator after each resolution. JSON evidence is at `../../work/v12-world-diagnostic.json`; its reproducible script is beside it.

- Team A: Oh Tipi, Wa Bidi, Treevor Mason — 15 total affinity.
- Team B: Grace Riva, Spai Si, Haara — 15 total affinity.
- Ordinary matches only: no story inhabitants or earned-point allocation.

| Seed | Result in both seating orders | Rounds | First score | First damage | Longest run with no score | Casts / moves / damage events |
| --- | --- | --- | --- | --- | --- | --- |
| WELLSPRING | A wins 18–15 | 10 | Round 2 | Round 2 | 1 opening round | 42 / 27 / 21 |
| WINDWARD | B wins 16–12 | 8 | Round 1 | Round 2 | 0 | 35 / 21 / 19 |
| THREE-RIVERS | A wins 16–12 | 12 | Round 2 | Round 2 | 1 opening round | 51 / 25 / 30 |

The seat swaps reproduced the same score, length and activity counts by team for all three seeds. No match reached the round cap. After initial approach, none had a round where both teams failed to score. This is a bounded regression diagnostic for these two deterministic policies and starting builds, not a claim about human enjoyment, competitive balance, high-affinity compositions, or all procedural seeds.

Measured full-match planning time was 3.34–5.77 seconds and resolution time 0.60–1.00 seconds on the current machine while other integration work was running. These are summed JavaScript wall times across each complete 8–12-round match, not per-frame performance or player turn durations.

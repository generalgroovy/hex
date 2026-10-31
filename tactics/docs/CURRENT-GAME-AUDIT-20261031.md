# H.E.X. current game audit and improvement proposals

Reviewed 31 October 2026 against browser-game commit `01c2369` and the existing working-tree edits. Scope: active Story, Tower, co-op Tower, and Arena routes; combat rules and previews; the guide; campaign and tower progression; input, responsive layout, animation/audio contracts, and maintenance documentation.

This is a source audit, not a new-player study or a fresh physical-device acceptance pass. The source audit began before the candidate verification listed below; findings are limited to behavior visible in the active code and documentation.

## Product judgment

H.E.X. has a strong, distinct core: choose a landing and a ground-aimed spell, commit privately, then see every fighter move before projectiles meet and transform the field together. Its main risk is no longer a lack of mechanics. It is the gap between a large rules catalogue and a player's ability to see the one useful consequence that matters now.

Keep the game organized around four questions: **Where can I go? What can I do from there? What will this change? What is still uncertain?** Put the first three beside the current decision and reserve the fourth for a clear, honest caveat. Preserve simultaneous resolution, the original cast, four configured spells plus signature, teachable enemy spells, elimination victory, seeds, and private multiplayer.

## Audit by game area

| Area | What the current implementation establishes | Main friction or risk | Proposal |
| --- | --- | --- | --- |
| Core identity and turn flow | Planning and commitment are distinct from movement, simultaneous casts, effects, and review. Victory is team elimination. | The interaction is richer than a conventional turn game, so long explanations can hide the simple decision loop. | Keep one short phase label and one next-action cue on screen. Explain simultaneous timing once, then show consequences in the current exchange. |
| Elements and mixtures | Six base elements feed 57 multi-element recipes. A read-only source audit found 63 distinct mechanics profiles across all 63 exact recipes; every recipe has a tactical purpose and a specific pressure note in the guide. | Tactical prose is hand-authored separately from field mechanics and can drift when effects change. Some recipes benefit both teams. | For every recipe, maintain one concrete pressure play and one real counter/tradeoff. Review suggestions against `CombinationMechanics` whenever a field changes; avoid suggesting an effect that is merely present in an ingredient pair. |
| Spells and targeting | Spell buttons pair their element with an area-shape glyph; selected actions have range, cost, footprint, impact, and terrain inspection. | In short landscape layouts, the compact consequence line was hidden; players had to open inspection to see what the selected action does. | Keep the consequence visible in one compact line while preserving the full spell profile in inspection. **Implemented in this review.** |
| Combat rules and cross-mode consistency | Tower, Story, and Arena retain separate versioned resolvers. Current-profile regression fixtures cover Sunburst behavior across all three; current projectile contact uses volume intersections while old saves retain their historical model. | Separate resolvers make a future fix easy to apply to only one mode. Existing common fixtures do not prove total rules parity. | Extend focused parity cases whenever a shared interaction changes: contact, field replacement, status timing, damage channels, displacement, and preview-to-resolution agreement. Keep legacy profiles explicit. |
| Enemy AI | The current-profile AI evaluates movement and spell positions together using public state; it scores fields, damage, statuses, force, and projectile contacts. It now gives bounded value to attacks aimed at likely legal movement lanes. | The movement model is a heuristic. It does not prove fair difficulty, human counterplay, or exact rival intent; uncertain movement can still cause a miss. | Compare seeded encounters across starters and party sizes; record wasted actions, repeated loops, attack pressure, and counterplay. Never use sealed human orders as AI input. |
| Character, creature, and spell progression | Characters preserve affinity identity; Story grants enemy-taught spells and affinity growth; Tower starts fresh and develops within a run. | Content breadth can make roster and reward screens feel like a catalogue rather than a build decision. | Keep selection comparisons local: affinity legality, four slots, signature, creature perk, and the expected tactical role should be visible together. Prefer curated encounter teaching over additional unlock currencies. |
| Story, Tower, and co-op | Story, seeded Tower, and private Arena have distinct purposes. Tower co-op supports up to six players, parallel rooms, shared fights, scouting, spectator viewing, and a synchronized floor barrier. | Co-op's flexibility creates more state and timing to explain than solo Tower. Large shared fights can raise information and screen-load costs. | Keep “join this fight,” “watch friend,” and “wait for floor” as explicit states. Measure six-player shared-room readability and response time before adding more co-op systems. |
| Maps and terrain | Natural biomes, temporary elemental fields, barriers, height, springs, and forced displacement have separate rules. Seeded maps make repeated decisions reproducible. | Large maps can dilute encounter pressure; visual terrain can be mistaken for a rule-bearing field if the layers converge. | Make each encounter's meaningful lanes, blocking geometry, and active fields legible at play scale. Use terrain to create two or more viable routes, not just more hexes. Keep scenery motion physically motivated. |
| Visual effects, animation, and sound | Resolution has shared timing boundaries; character reactions and elemental effects are bounded; sound is opt-in and can be canceled during playback. | Impact, damage source, status, and terrain change can compete for attention. Sound must not be the only explanation, and effect density can rise sharply in large fights. | Preserve event hierarchy: projectile contact, changed field, direct hit/status, then aftermath. Keep effects readable at phone scale and provide equivalent visible feedback when muted or reduced-motion. |
| UI, input, and accessibility | Keyboard, pointer, touch, status inspection, undo, and compact layouts are represented in code and handoff docs. | Responsive layouts have less room to show action consequences, and versioned style layers make later changes easy to regress. | Keep action, cost, and one-line effect visible at each viewport. Reserve detailed explanation for inspection; remove only redundant copy, not information needed before commitment. Consolidate CSS only after a scoped layout pass. |
| Engineering and reliability | Saved states, private seats, seeds, and mode-specific rules are versioned; migration and recovery are documented. | Resolver duplication and accumulated versioned style modules increase the chance of mode drift. A broad rewrite would put saves and multiplayer at risk. | Prefer shared pure helpers only after parity behavior is captured. Keep save/protocol adapters stable and scope visual changes to the active component and stylesheet. |

## Priority proposals

1. **Keep selected-action consequences visible on every layout.** The short-landscape compact panel hid its effect line. It now keeps a single-line summary visible; the inspector remains the place for full timing, footprint, and assumptions.
2. **Treat recipe advice as executable-facing content.** Each elemental setup must name its actual field use and a credible risk/counter. Recheck all 63 exact recipes when their mechanics change; do not inherit pair behavior into larger recipes.
3. **Expand combat parity around changes, not by merging engines.** Add or update cross-mode cases for the rule being changed, including forecast and replay/save behavior. This is safer than an unbounded resolver consolidation.
4. **Tune difficulty from decisions and counterplay.** Use fixed seeds and starter/party strata to inspect attack pressure, idle rounds, survival, and whether advertised counters work. Bot completion rates alone are insufficient.
5. **Keep co-op state visible without duplicating instructions.** Show each friend's destination, active fight state, and the exact condition needed to advance the floor where those choices happen.
6. **Protect visual causality.** Audit fields, movement lanes, barriers, statuses, and hit feedback at actual phone and compact-landscape sizes. Remove motion only when it has no physical or informational purpose.
7. **Run unfamiliar-player sessions before declaring the experience clear.** Ask a new player to predict an exchange, explain a surprising interaction, recover from a changed plan, and choose another run. Code review cannot establish those outcomes.

## Active-code checks that retire older findings

- Current projectile resolution and planning previews use the volume-contact solver; pre-volume saves/replays keep the old interpretation. See `lib/projectile-interception-v20.ts`, `lib/tactics-v22.ts`, and `tests/projectile-contact-v23.test.ts`.
- The current Sunburst profile has a distinct protection-breaking role and matching cross-mode forecast coverage. Historical focused profiles keep the older spell. See `lib/combat-contract-v44.test.ts` and `lib/spell-profile-v42.ts`.
- Current-profile Tower AI has a joint movement-and-cast candidate pass plus a small probability-weighted forecast over public enemy movement options. It does not read sealed orders; older spell profiles do not use the new forecast. `tests/ai-targeting-v45.test.ts` proves a legal four-hex advance can be met with a damaging lead shot and checks determinism and state purity. See `lib/tactics-v22.ts` (`chooseAIPlan`).

These source checks are not claims that the tests were rerun here, that every seed is balanced, or that the UI passed a new human/device review.

## Candidate verification

After the audit, the current UX candidate passed:

- `npm run docs:check`: 221 local handbook links.
- `npm run typecheck` and `npm test`: passed; 1,442 tests, 0 failures, 0 skipped.
- `npm run build` and `npm run assets:check`: production Worker/client build passed; 244 RSC asset references verified.
- Local D1 initialization and production Worker smoke: Arena, 636 checks; six-squad shared Tower, 3,774 checks; six-player split Tower, 4,031 checks. No transient retries.
- Local browser check at 789 × 438 CSS pixels: Tower restored at round two with both remaining enemies and health shown before resuming. The active battle showed explicit phase markers, selected character health/status, spell costs and footprints, and map terrain/effect explanations.

This does not establish physical-phone touch comfort, human comprehension or balance, a public deployment, or verification of the live service's production database. Public deployment remains a separate Sites operation; a local Worker build or GitHub push does not publish the live game.

## Follow-up hardening: simultaneous target reading

The focused-profile Tower AI previously scored enemy occupancy at the current location but had little reason to lead a legal movement lane. The update evaluates a bounded weighted set of public legal landing cells using current ready attack ranges, allied projected positions, visible terrain, and the collapse boundary. Current occupancy retains weight, so a lead is valuable without becoming a claim about a sealed order. Damage, control, Flux theft, and field value use the same current combat scoring helpers as direct hits.

Validation on the focused `FOCUS42-B` opening diagnostic reduced the Treevor-and-Puddle fight from 12 exchanges before the change to 8 after it. An additional eight-seed first-room diagnostic covered each of the seven suggested solo starters (56 AI-versus-AI fights):

| Starter | Mean exchanges | Max | Owner-0 starter wins | No-direct-damage rounds per run | Collapse runs |
| --- | ---: | ---: | ---: | ---: | ---: |
| Steam | 5.13 | 11 | 7/8 | 1.13 | 2 |
| Dusk | 7.25 | 11 | 8/8 | 2.63 | 3 |
| Red Baron | 5.50 | 11 | 7/8 | 1.75 | 2 |
| Steezo | 6.25 | 11 | 7/8 | 2.75 | 2 |
| Treevor and Puddle | 8.25 | 11 | 8/8 | 3.88 | 4 |
| Oll' I | 4.38 | 11 | 7/8 | 1.25 | 1 |
| Wa Bidi | 8.25 | 11 | 6/8 | 2.25 | 3 |

These are reproducible AI pacing diagnostics, not evidence of human balance or starter fairness. This original sample kept the starter party on owner 0, so its win column alone could not separate seat from party strength.

The follow-up [`tower-seat-swap-diagnostic.mjs`](../tests/tower-seat-swap-diagnostic.mjs) pairs the same eight seeded first rooms for each starter, then puts the starter party in each seat (112 AI-versus-AI matches total):

| Starter | Starter-party wins / 16 | Mean exchanges | Draws |
| --- | ---: | ---: | ---: |
| Steam | 15 | 5.50 | 1 |
| Dusk | 15 | 8.25 | 0 |
| Red Baron | 16 | 5.69 | 0 |
| Steezo | 14 | 7.00 | 1 |
| Treevor and Puddle | 12 | 9.75 | 2 |
| Oll' I | 16 | 5.00 | 0 |
| Wa Bidi | 14 | 7.56 | 2 |

Across the paired set, seat 0 won 52, seat 1 won 54, there were 6 draws and no match hit the 28-exchange diagnostic cap. The starter party won 102/112 (91%). This suggests the opening is forgiving under the mirrored game AI, with a slower and less reliable Stone opening; it does not establish what human players will experience or justify tuning encounter strength on its own. The controlled check separates seat symmetry from party outcome, but only a human playtest can assess whether the opening teaches well and feels satisfying.

The follow-up candidate passed `npm run typecheck`, the full `npm test` suite (1,443 tests, 0 failures, 0 skipped), `npm run build`, `npm run docs:check` (221 links), and `npm run assets:check` (244 references). ESLint passed on `lib/tactics-v22.ts` and `tests/ai-targeting-v45.test.ts`; the repository-wide lint command exits with 301 errors and 316 warnings across the codebase. A local Worker smoke was not repeated for this AI-only follow-up. Public publication remains blocked on the official Sites publisher connection described above.

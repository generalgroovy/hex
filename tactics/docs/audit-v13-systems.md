# Systems audit and implementation — rules 13

Audited the raw rules-12 engine, spell catalogue and access functions, character
records, seeded arena, practice AI, Story encounters, planner advice, current UI,
audio implementation and regression fixtures at `eb572976914cf3024154b4c1039b5c6965e6b4b8`.
The previous release report was context, not proof of good design. Source was
opened through the Sites workflow before edits. Historical rules remain frozen.

## Independent review of all 24 areas

| Area | Strongest existing feature | Raw weakness | Decision and acceptance |
| --- | --- | --- | --- |
| Core identity | Shared elemental landscape makes simultaneous actions interact. | Catalogue breadth obscures the distinctive promise; element access allowed every level-one ingredient at zero affinity. | Change access to allocated affinity ≥1, preserve earned third elements. A company must use actual equipped ingredients to construct its combinations. |
| Turn structure | Common post-move snapshot prevents order priority exploits. | Destination-only collisions and landing-dependent fizzles are easily mistaken for path blocking or sequential spells. | Retain phases; explain destinations, swaps and fallback legality. Known allied conflicts must be distinguished from hidden rival risks. |
| Tactical depth | Geometry, timing, support, displacement and shared fields interact. | Guard's unconditional displacement immunity duplicated Anchored and defeated coordinated pushes. | Sum forces, subtract one Guard strength, cap at two steps; Anchored remains immunity. Test cooperation, cancellation, diagonals, Ice and fresh Anchored timing. |
| Element personalities | All 63 exact fields have bounded effects and distinct fingerprints. | Mathematical uniqueness alone does not establish useful tactical distinction; unfamiliar names impose recall cost. | Retain fields and show exact ingredient/result/consequence locally. Do not add more combinations or status primitives. |
| Spells | Shapes, support, marks and signatures supply complementary verbs. | Old wrapper reexports call old access functions internally; merely replacing displayed access would leave loopholes. | Override access, availability, validation, repair and defaults together. Every zero-affinity equip/cast/restore route rejects; old saves retain old rules. |
| Characters and races | Thirty original champions and creator signatures preserve H.E.X. identity. | Imported biographies promise stamina, racial bonuses and different recovery that the tactics engine does not implement. | Current display-only roles describe affinity, kit and signature. Keep equal baseline stats; no fabricated racial passives. |
| Team composition | Three champions with four fixed spells give camp decisions lasting consequences. | Generic default kits obscure useful combinations; unrestricted level-one access weakens roster identity. | Curated native starter kits with support and explicit roles; migration preserves valid custom slots. All thirty kits validate at five points. |
| Progression | Story earns points and teaches defeated signatures; no mid-match grind. | Generic high-level spell replacement can erase support or practical elemental coverage. | Curated slot upgrades; preserve baseline membership, total cap, creator discount and first-victory-only rewards. |
| Resources and statuses | Guard/Flux, delayed Ward, Resolve and cleanse provide timing choices. | Protection math is duplicated in AI, and prior Guard flags can be mistaken for current intent. | Share aggregate mitigation; treat Guard only as an explicit conservative AI scenario. Keep status duration and anti-lock rules. |
| Objectives | Five wells and defeat points reward space rather than elimination alone. | The score display alone does not explain the next decisive scoring exchange. | Retain target 16/limit20; improve objective context. No overtime introduced solely to remove deterministic mirror draws. |
| Maps and terrain | Radius-nine maps provide flank routes, cover, high ground and obstacles. | 271 cells for six units can dilute early decisions; scenery cannot establish meaningful occupancy rules. | Preserve dimensions; explain local terrain and objective routes before changing geometry. Require novice travel/decision observation for later size tuning. |
| Procedural generation | Mirrored costs, safe spawns and connected ruin placement are explicit. | Mirrored layout does not prove equal compositions or interesting every-seed approaches. | Retain frozen generator and reproducible seed links. Validate multiple seeds/sides and inspect encounter-specific obstruction. |
| Balance | Fixed allocations and equal-affinity competitive checks bound entry. | Equal points do not imply equal build power; signature and support combinations matter. | Keep gauge wording honest. Run bounded paired diagnostics and targeted counterplay cases; do not report them as competitive balance proof. |
| Story | Existing champion teams, rewards and neutral creatures give a foundation. | Encounter introductions sometimes promise Guard stops any displacement; boss kits drift from authored tactics. | Update current advice and kit selection together. Every taught action must exist in the actual encounter build. |
| AI | Public-only plans, field forecasts and paid creature counters respect secrecy. | Per-spell scoring subtracts protection repeatedly, ignores marginal chemistry and rewards blocked pushes. | Shared aggregate marginal volley damage and bounded guarded/unguarded force estimates inside existing candidates; maintain affordability and friendly-fire filters. |
| Multiplayer | Sealed plans, strict restoration, retries and frozen historical engines are strong. | New access and Guard rules cannot safely alter existing rooms. | New versioned engine and route; transport rejects forged affinity/equipment changes; old pending orders resolve under old rules. |
| Onboarding | Playable default squad and one-creature early encounters reduce setup. | The first match still introduces five actions, three units, terrain, fields and simultaneous uncertainty together. | Contextual coach and consequence feedback; no mandatory catalogue memorization. Observe first independent turn and prediction later. |
| Interface | One End Turn and editable orders reduce duplication. | Resolution summaries can prioritize generic creature prose above defeats, fizzles and real health changes. | Consequence-first recap and direct field inspection; no exact forecast of hidden enemy orders. |
| Controls and mobile | Keyboard targeting, pan, Undo and dedicated inspection exist. | Reachable destinations outside the current view and manual camera controls add navigation burden. | Test actual selecting/moving/casting/undo/inspection at phone sizes, not overflow alone. Keep action and inspection modes distinct. |
| Visuals and animation | Original environment atlases and anatomical creatures establish material continuity. | Continuous idle motion can compete with intention, impact and useful tactical contrast. | Retain art; use timing hierarchy and meaningful local emphasis. Preserve reduced motion and explicit footprints. |
| Audio | Element/material envelopes, voice budget and cancellation are implemented. | Oscillator variety is not evidence of attractive listening quality or correct perceived timing. | Preserve bounded semantic cues; verify scheduling and separately listen before claiming sound polish. |
| Accessibility | Text, symbols, keyboard and reduced motion supplement colors. | Hundreds of hex buttons and field vocabulary can overload focus and speech. | Contextual inspected-unit information and meaningful focus behavior; keyboard/muted acceptance, separate screen-reader observation still required. |
| Pacing and replayability | Seeds, fixed builds and simultaneous response produce variation without more phases. | AI mirror ties were initially easy to misdiagnose as inactivity. | Read complete event traces; adjust demonstrated decisions, not the result label. Human repeat-play remains the relevant enjoyment evidence. |
| Validation | Strict engine/wire tests and preserved engines make behavior reviewable. | Existing exhaustive field tests validate descriptors, not player understanding or fun. | Add counterexamples, integration and real browser journeys; retain a clear boundary between correctness, usability and enjoyment. |

## Raw diagnostic before changes

Three default-team mirror matches used actual `choosePracticePlan` and
`resolveRound`, without private information or browser state injection:

| Seed | Rounds | Score | Casts | Damage | Moves | Bounces | Entirely quiet rounds | First score | Runtime |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| WELLSPRING | 20 | 40–40 | 76 | 100 | 30 | 14 | 0 | 2 | 7.323 s |
| IRONWOOD | 20 | 39–39 | 54 | 116 | 34 | 10 | 2 | 2 | 5.663 s |
| CINDER | 20 | 37–37 | 52 | 116 | 30 | 14 | 3 | 1 | 7.094 s |

These are deterministic policy mirrors, not human matches. The draws contain
substantial combat; they do not justify an arbitrary overtime mechanic. Their
useful evidence is the opportunity to inspect collisions, coordination and
protection across complete matches.

## Implemented systems contract

- Every ordinary spell requires at least one allocated point in its element.
  Higher ranks still require their displayed rank; signatures retain creator
  three/non-creator five-point requirements and the two-Flux creator discount.
- Current spell functions own access, available actions, validation and repair.
  Repair reserves all legal custom slots before filling only invalid slots from
  the authored kit and remaining legal catalogue. Historical wrappers are intact.
- All push/pull vectors combine first. Anchored blocks them. Guard subtracts one
  strength from the net force, then the usual two-step limit applies. One step
  onto a connected Ice lane can still slide farther. Newly granted Anchored
  protects next exchange, exactly as before.
- The resolver and AI share aggregate mitigation. AI values the marginal damage
  of adding a spell to its earlier allied volley, including changed chemistry.
  It cannot trigger a bonus from a mark newly promised in that same volley.
- Guarded damage is a conservative planning scenario, not access to a hidden
  order. Force value considers both guarded and unguarded outcomes. Earlier
  Guard flags never certify what the rival is doing now. The candidate search
  space remains unchanged.

Focused and integration evidence is appended after execution. Human fun,
competitive fairness, physical-device comfort and market potential are not
established by this source audit or automated matches.

## Final systems evidence and cross-review

The focused regression files are `systems-v13.test.ts` and
`ai-counterplay-v13.test.ts`. They exercise all thirty champions and every
ordinary spell threshold, earned third elements, creator/non-creator signatures,
slot-preserving migration, rejected forged equips/casts/restores, preserved
rules-12 behavior, actual aligned and opposing force, fractional diagonals,
unit-array order independence, old/fresh Anchored, a long Ice slide, aggregate
Ward/cover/Steam/piercing, existing-mark timing, paid creature counters and their
negative cases, coordinated AI force and a complete restorable match. A
TypeScript check passed after the current rules and character modules integrated.

The final diagnostic was rerun after the character specialist's last kit change.
It validates both plans and restores every resulting state. Team A is Oh Tipi,
Wa Bidi and Treevor; team B is Grace Riva, S. Wayne and Haara. Both have fifteen
total affinity points. Each asymmetric matchup ran with both seating orders.

| Seed | Mirror score / casts / damage | A–B result in both seatings | Rounds | First score | Completely quiet rounds |
| --- | --- | --- | --- | --- | --- |
| WELLSPRING | 41–41 / 38 / 86 | A wins 23–22 | 12 | 2 | 0 |
| IRONWOOD | 33–33 / 90 / 122 | B wins 16–15 | 10 | 2 | 0 |
| CINDER | 37–37 / 80 / 130 | A wins 17–11 | 8 | 1 | 0 |

Mirrors still reach the twenty-round draw limit. No match has an entirely quiet
exchange. Asymmetric outcomes match exactly after reversing seats, but one
composition pair over three seeds is not a balance study. Mean single-plan CPU
time in the final Node run ranged from 89 to 201 ms; the largest pair of plans
took 726 ms while other agents were also running work. This is a bounded desktop
diagnostic, not isolated performance benchmarking or physical-phone evidence.
Raw commands and all nine records are retained in the workspace's
`work/systems-v13-diagnostic.mjs` and `.json`.

Cooperative review retained the original phases, score limit and map dimensions.
The character specialist supplied canonical ingredient coverage and meaningful
starter roles; the experience specialist independently corrected consequence
priority and hidden-order wording. The integrating and fourth-review agents
challenged Guard timing and compatibility. All 24 areas in the audit matrix were
revisited against these final decisions: changes to access, cooperation and
readability address concrete contradictions; deferred geometry, audio listening,
screen-reader, novice and human-balance work is not disguised as completed proof.

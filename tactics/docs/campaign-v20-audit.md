# Campaign 20: knowledge, readable consequences and recovery

## Design decision

The central promise is simultaneous elemental tactics with consequences players can explain. Progression should give reasons to fight and change a party, while never making a loss erase the spell knowledge already earned. This update deepens that loop rather than adding a second economy or another match mode.

Every enemy type has exactly one teaching: 30 named champions and 93 elemental creature species. Defeating one of them awards its spell once, regardless of which damage source finishes it or whether the party later loses. The actor must actually be defeated; starting, abandoning, replaying or importing the same battle cannot duplicate the reward. Only a first story victory earns affinity and unlocks further recruitment. Combat uses the profile and spell library frozen at battle creation; new knowledge becomes equippable between battles.

The catalogue now contains 171 spells: 48 base spells, 30 champion signatures and 93 creature techniques. Each creature uses its own technique in battle, so the learned move is the move that enemy demonstrated. Mixed techniques carry their full ingredient set into ground reactions and projectile interception. Bigger ingredient sets are bounded by footprint, Flux, cooldown and, where appropriate, self-cost. Existing signature creator discounts and affinity scaling remain intact.

Optional field encounters provide an obtainable source for every creature technique. They become available with that species' recruitment tier, pair the target with two lesser escorts, and award knowledge without extra affinity. The library exposes these sources explicitly. The ordered 30-encounter story remains the progression spine.

## Cooperative audit and response

| Area | Finding | Implemented response |
| --- | --- | --- |
| Core loop and rewards | Victory-only signature unlocks left creatures disconnected from progression. | Actual defeats teach a unique spell immediately; losses preserve knowledge. Story victories retain their separate role. |
| Choice and catalogue | Hidden locked entries and immediate slot replacement obscured both goals and consequences. | Ready/Learned/All search, source and exact affinity requirements, four persistent slots, explicit Equip/Swap and effective-stat comparison. |
| Encounter accessibility | Many species never appeared on the main story path. | Available species have dedicated optional field encounters from their spell entry. |
| Combat chemistry | A mixed technique could otherwise be reduced to its primary element in previews, flights or AI valuation. | Full ingredient unions flow through the resolver, projected volleys, field forecast and AI. Primary color remains the spell's authored element. |
| Planning clarity | Queued actions hid movement and used a cost that omitted Concussion. | Landing, spell and authoritative Flux cost appear together. Auto Guard is explicit. |
| Planning recovery | Undo alone could not recover a restored phone move. | Undo/redo, clear order, next unplanned and a Move/ Hold control that can cancel a restored move without a history entry. |
| Results | Short summaries could omit events, and identical actor names collapsed into one row. | Actual before/after HP and Flux, status changes, complete phase report, side labels and no deduplication of actor actions. Only repeated field tiles aggregate. |
| Playback | Reload discarded the previous exchange, and short phone layouts buried review controls. | Save the prior state; report/replay remains available. Compact review removes duplicate party information and keeps its actions together. Instant results respect reduced-motion preference. |
| Save integrity | Separate writes could separate knowledge from the battle that earned it. | A validated atomic profile/battle/draft/previous-round envelope, export/import preview, recovery copy before replacement and protection against stale async file reads. |
| Migration | Applying newer encounter lineups to old story victories could invent creature defeats. | Rules19 victories infer their actual lineups; older16 progress infers champions only. Old keys and routes remain available. |
| AI and pacing | The opening policy repeated opposing direct shots until a needless mutual wipe. | After a revealed enemy interception, prefer a small safe change of firing angle when both casters remain at their known release cells. No hidden orders are read; future boundary exposure cannot increase. |
| Visual consistency | New spell IDs could fall through the old renderer registry and mixed spells could use the wrong primary color. | Optional versioned spell-rule injection in the shared renderer, tested through planning and impact. Existing classic/online fallback remains supported. |
| Accessibility and input | Modal controls could leak battle shortcuts; narrow review layout hid learned-spell feedback. | Planning is disabled behind modals, explicit side labels supplement colors, focus transfers to inspected spell details and phone review retains learning feedback. |

## Validation and limits

Focused tests cover the one-to-one catalogue, all 93 native techniques actually casting on legal maps and restoring, all 30 story plus 93 field constructions, ongoing defeat learning, loss retention, idempotent repeated progress, story-only affinity, migration provenance, fixed battle libraries, malformed draft/replay repair, spell comparison and slot swapping, full mixed forecasts and flights, side attribution and classic renderer compatibility.

The independent final 12-match corpus uses two contrasting parties at encounters 1, 2, 10, 11, 21 and 30. It recorded 137 resolved rounds, 274 validated plans and 149 strict state restorations, with progress applied twice every round. Results were six wins, four losses and two actual mutual eliminations, lasting 5–18 rounds. The default opening won in 17 rounds; the ordinary rank-4 Water/Tidal party won encounter 2 in 14. A saved opening counterexample admitted a one-hex sidestep and a win at full 8 HP, confirming the problem was positioning rather than insufficient spell damage.

These are deterministic diagnostic matches, not a win-rate estimate or proof of human difficulty. The later mutual wipes reveal remaining AI limitations around contested centre entry and final-turn displacement. The corrected bot adapts to revealed shots; it is not a complete opponent modeller. Do not tune the entire spell economy against this small corpus.

Browser verification covers actual library filters and enemy detail, field launch, move/Guard orders, undo/redo, next unplanned, a creature cast and report, save export and import, and responsive planning/review. Browser viewport checks are not physical-phone performance or touch tests. No new music or voice assets are claimed; sound controls and the existing synthesis remain. Original sprite atlases and environmental art are preserved.

## Remaining evidence worth obtaining

Observe new players attempting the first battle without guidance: record time to first valid cast, whether they can explain a miss or collision, whether they identify a learned spell and equip it, and whether they understand when a bond is active. Then run several human rematches with contrasting compositions before judging difficulty or fun. Device testing should include sustained playback, touch panning, small-screen text and save recovery on real iOS and Android browsers. These are empirical follow-ups, not completed validation.

## Release boundaries

Home and `/story` use campaign20. `/v19` keeps the prior campaign and unfinished saves. `/v16` keeps older local modes. Public online rooms remain on rules18 with private match codes and separate seat keys; this update does not silently import campaign-earned techniques into competitive rosters. No database migration is required.

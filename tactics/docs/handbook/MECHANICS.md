# H.E.X. mechanics and compatibility

This reference covers the release 45 web implementation, source-checked on 2026-10-20. It complements [GAME-DESIGN.md](GAME-DESIGN.md). It deliberately links executable definitions instead of copying every spell, creature or recipe into a second catalogue.

## Select the correct rules first

| Contract | Current authority | Compatibility rule |
| --- | --- | --- |
| Arena | [`tactics-v18.ts`](../../lib/tactics-v18.ts), `rulesVersion: 18` | Two–six owners; free-for-all or four/six-player teams. Uses the standard/signature catalogue through spells-v16. |
| Story | [`tactics-v20.ts`](../../lib/tactics-v20.ts), `rulesVersion: 20` | Campaign profile and encounter identity are part of state. Uses creature techniques through spells-v20. |
| Tower | [`tactics-v22.ts`](../../lib/tactics-v22.ts), `rulesVersion: 22` | Tower configuration includes carried HP, owner/controller mapping, environment and optional supplies. Run format 3 and service protocol 23 are separate numbers. |
| Spell shape/effect profile | [`spell-profile-v42.ts`](../../lib/spell-profile-v42.ts) | New battles use `focused-v44`. `focused` keeps the previous Sunburst role. Missing `spellModel` keeps original footprints/effects. Do not default old saves to the current profile. |
| Recorded projectile contact | [`projectile-interception-v20.ts`](../../lib/projectile-interception-v20.ts) | `projectileModel: 'volume'` validates recorded volume contacts; absent marker validates old point contacts. Current native resolvers use volume contact for newly resolved exchanges and mark the resulting state. |
| Tower generation | [`tower-v23.ts`](../../lib/tower-v23.ts), [`arena-v17.ts`](../../lib/arena-v17.ts) | `routePlayers`, `encounterModel`, `encounterVariant`, map motif suffix and `suppliesModel` are explicit persisted gates. Their absence must retain old generated content/rewards. |

Restorers reject unknown fields, invalid geometry/events and inconsistent actor/encounter data. Shared render snapshots are not native save formats. Keep old storage keys and historical IDs, including strings containing `confluence`, where they are compatibility identifiers. The public product name is H.E.X.

## One exchange

Each living fighter receives at most one order: optional movement plus a cast, or optional movement plus Guard. Missing orders become Guard. Four-spell kits and affinity allocations cannot change during battle. Ground targets are validated against the planned landing, then checked again after simultaneous movement.

| Stage | Reads / changes | Consequence |
| --- | --- | --- |
| 1. Validate | Current legal kit, cost, cooldown, path and aimed target | Invalid input is rejected; it is not silently converted to a stronger action. |
| 2. Move | Existing movement statuses and terrain; all requested destinations together | Conflicting landings bounce. The resulting location becomes the cast origin. |
| 3. Release | One common post-move, pre-effect state | A now-illegal aim fizzles without spending Flux/cooldown/scroll. All legal casts release before new control. |
| 4. Advance clocks and pay | Old status/cooldown values remain in the combat snapshot; carried durations decrement once; new cooldowns are set | A fresh effect does not lose its first duration immediately. Released scrolls are spent even if later intercepted. |
| 5. Contact and fields | Same-clock projectiles, surviving spell areas, public inhabitant pulses, old fields and substrate | Intercepted target hits are removed. Each affected hex forms one complete ingredient-set phenomenon. |
| 6. Direct effects | Snapshot conditional bonuses, old Ward/Guard, resulting field, all incoming spells | Sum damage/healing; account for cleanse/Wet/Clarity; commit HP together. Fresh support cannot act as an earlier Ward. |
| 7. Force and landing | Sum force vectors; use old Anchored and this exchange's Guard | Resolve forced steps, obstacle impacts and final terrain. Fallen fighters do not continue moving. |
| 8. Aftermath | Surviving nearby creature bonds, then closing ground | Bonds cannot rescue a fighter already defeated by ordinary effects. Closing damage ignores protection. |
| 9. Recovery and finish | Flux gains, field/barrier lifetime, surviving teams | Restore Flux, age terrain, determine elimination/draw, enter the next planning state if needed. |

The readable clock is also exported in [`combat-consequence-v44.ts`](../../lib/combat-consequence-v44.ts). Use native `resolveRound` for final ordering, including mode-specific aftermath.

## Movement, occupancy and sight

- Base movement is **4 effort**. Rooted sets it to zero. Chilled reduces base effort to three. Haste or starting on a current adds one, without stacking those two bonuses.
- Entering marsh, climbing, entering/leaving flooded ground or entering/leaving rough ground costs two effort; ordinary movement costs one.
- Entering ice costs one and slides in a straight direction through contiguous ice to the last ice hex before dry ground or a solid obstacle. A slide is one path edge and may cover several cells.
- Ruins and active barriers are solid. Unit occupancy is resolved at destinations, not as permanent terrain in pathfinding. Multiple requests for one hex fail; a destination occupied by a fighter that fails to leave also fails. Simultaneous swaps/cycles can succeed. Living fighters end on unique hexes.
- Sight is available if at least one shortest hex path is clear. Intermediate solid cells or cells higher than both endpoints block that path. This is not unrestricted curved pathfinding.
- `legalMoves`, `movementPath`, `movementEffort`, `legalCasts` and `spellArea` in the native resolver are the authority. A UI highlight or AI cache must call the same geometry.

An aim can remain legal after a blocked move; otherwise it fizzles. New walls do not retroactively cancel the batch of spells already released. Wall creation skips occupied cells, springs and ruins.

## Spell access, strength and area

Champion creation starts with **5 affinity points**, at most **3 elements**, and **4 distinct equipped spells**. The native primary element must have at least two points and be tied for or above every other element. Initial ranks cannot exceed three. A signature occupies a fixed fifth option when eligible; it cannot occupy one of its creator's four configurable slots.

| Rule | Value / source |
| --- | --- |
| Standard spell access | Allocated rank at least the spell level, 1–6. An unallocated element grants no normal spell access. [`spells-v13`](../../lib/spells-v13.ts) overrides the older level-one rule. |
| Advanced branch | Levels 3–6: Fire→Lightning, Water→Ice, Earth→Metal, Air→Storm, Light→Radiance, Dark→Void. Base ingredient/color identity remains. |
| Creator signature | Required affinity 3; Flux cost 3. |
| Borrowed signature | Learn from its champion, require affinity 5, Flux cost 5; occupies a normal slot. |
| Ordinary cost scaling | Printed cost, minus one at affinity ≥2, minimum one; Concussed adds one at casting. Signature costs do not receive another affinity discount. |
| Creature technique access | Must be learned and meet its level in the technique's primary element. Native creatures possess their own kits. [`spells-v20`](../../lib/spells-v20.ts) |
| Maximum allocation | Three elements × rank six = 18 points. Mode/build validators impose the available budget. |

Affinity strength is derived before applying the saved spell profile:

| Rank reached | Additional effect |
| --- | --- |
| 2 and 5 | +1 aimed reach each, if the spell has nonzero range |
| 3 and 6 | +1 to one primary channel each: damage, else healing, else Ward power, else recharge, else theft |
| 4 | +1 duration to eligible non-control marks/beneficial statuses within the catalogue's caps |

Affinity does not enlarge the footprint, lengthen control locks or increase recoil. Use the complete derived object from `effectiveSpell`/`battleSpell` rather than multiplying every numeric field. The creature extension has its own explicit duration caps. Blind reduces aimed reach by one, minimum one; self-targeted spells remain range zero.

For `focused` and `focused-v44`, eligible aimed hex/burst spells become at least radius two:

| Band | Direct effects |
| --- | --- |
| Centre, distance 0 | +1 damage and/or healing when present. For a pure status spell, +1 status duration within caps instead. Display a crit only when a real centre benefit exists. |
| Inner ring, distance 1 | Ordinary effective spell values |
| Rim, distance ≥2 | Positive damage/healing halved, rounded down, minimum one. Conditional bonus damage is halved as part of the combined per-spell hit, not separately rounded up. Non-control statuses last one round with halved positive power, minimum one. No direct Rooted/Chilled/Concussed/Blind. |
| Entire footprint | Elemental terrain ingredients still apply. Field-granted control can therefore occur on the rim. |

Self, line, sweep/fan, ring and wall identities remain. Deliberate precision exceptions are Gust, Gale, Vacuum, Undertow, Immolate, Shatter and Reap. Broadening a formerly single-hex force spell preserves caster-relative force via `forceFromCaster`; existing radial bursts/rings use the aim centre. Rim force, recharge, theft and other unspecified utility channels are not generally halved by the focus helper.

`focused-v44` Sunburst deals enemy-only piercing Light damage and has no direct Blind application; its resulting Light field still protects either side from control. Older `focused` Sunburst remains unchanged. Never repair the old data globally to implement a new battle rule.

## Projectile contact and full-set fields

All travelling releases use one normalized linear flight clock. A projectile has a world-space material radius of one-quarter hex; trails and screen pixels are irrelevant. Contact uses closest approach of simultaneous trajectories within a combined half-hex radius. Merely crossing the same location at different times is insufficient.

Shared aimed endpoints remain normal simultaneous impacts, not mid-flight interceptions. Stationary effects and helpful/non-travelling actions are excluded by `isTravellingProjectile`. Allies' projectiles can contact too. Contacts are processed by time; already consumed projectiles cannot clash again. Connected simultaneous contacts form one group:

- Two participants create a radius-one interception field.
- Three or more create radius two.
- The participating original target effects are canceled, but release costs, self effects and spent scrolls remain.
- The field uses the union of participants' ingredients; Story/Tower creature techniques can contribute several ingredients.

Authority: [`projectile-interception-v20.ts`](../../lib/projectile-interception-v20.ts), with historical point solver in [`projectile-interception-v16.ts`](../../lib/projectile-interception-v16.ts).

The field catalogue defines all **63 nonempty sets** of the six base elements. Ingredient order and duplicates do not matter. Existing field ingredients, natural Earth/Water substrate, surviving casts, clashes and inhabitant pulses are combined as one batch per hex. Exactly one phenomenon resolves; contained pair recipes do not also trigger.

| Example set | Result and tactical meaning |
| --- | --- |
| Fire + Water | Steam: halves the combined spell volley before protection, rounded up |
| Water + Earth | Quagmire: rough passage and Wet |
| Water + Air | Hailcurrent: ice and Chilled |
| Earth + Light | Crystal Prism: Ward for a later exchange |
| Fire + Water + Earth | Hot Spring: rough passage, cover and healing; replaces the pair results |
| Fire + Water + Light | Dawn Mist: damage shelter and cleansing |
| All six | Worldseed: damage shelter, cleansing and Flux; consumed after this exchange |

The complete definitions and generated rules text are in [`combinations-v16.ts`](../../lib/combinations-v16.ts). Effects apply to both teams. Ordinary refreshed fields persist through a two-resolution lifetime; special consumed fields discharge immediately. Freezing affects unmixed Water; mixed fields use their own movement rule. Terrain expiry restores the underlying biome, not an arbitrary Plain tile.

Public ambient inhabitants are distinct from recruitable creature fighters. Their scheduled pulse and counter element are inspectable. A surviving spell covering the perch with the counter ingredient suppresses the pulse; an intercepted cast or its resulting clash field cannot do so. See [`inhabitants-v16.ts`](../../lib/inhabitants-v16.ts) and [`element-counter-v41.ts`](../../lib/element-counter-v41.ts).

## Damage, statuses and force

**Mitigation is per recipient per volley**, not a separate Ward allowance for each attacker. Ordinary and piercing spell damage are accumulated; damage-halving fields act on the combined amount first. Piercing bypasses Ward and cover, but not Guard or field halving. Cover is the maximum of forest cover and field cover, not their sum. Guard reduces the resulting volley by one. The exact integer allocation is `mitigatedSpellDamage` in each resolver.

Burn, recoil, linked bonus damage and final environmental effects are separate channels. Old Ward is consumed when any positive raw harmful spell total arrives, even when fully blocked or piercing. Fresh Ward is merged after direct effects. HP commits as `clamp(oldHP + healing - damage, 0, maxHP)`, so simultaneous healing can offset damage; reported healing can exceed the final net HP rise.

| Status | Operational clock |
| --- | --- |
| Burn | Existing Burn ticks during the next effects stage; Wet or cleansing prevents it. New Burn does not tick immediately. |
| Wet | Removes existing/incoming Burn immediately. Conditional damage requiring Wet reads the earlier combat snapshot, so newly applied Wet does not enable a same-exchange bonus. |
| Rooted | No movement in the next planning state; casting/Guard remain available. |
| Chilled | Next movement base becomes three effort. |
| Concussed | Next normal spell costs +1 Flux. Free scrolls bypass this surcharge. |
| Blind | Next aimed reach −1, minimum one; applies to scrolls too. |
| Ward | Old power protects this volley; fresh Ward protects later. |
| Anchored | Old Anchored stops this exchange's force; fresh Anchored starts later. Voluntary movement remains possible. |
| Haste | +1 movement effort when planning; does not stack with a starting current. |
| Wither | Reduces healing; cleansing removes that tax before recovery. Tower's separate late-healing tax is not cleanseable. |
| Clarity | Existing **or newly incoming** Clarity blocks incoming control immediately; it does not cleanse old ailments. |
| Resolve | Receiving control grants Resolve against subsequent control. It does not remove the control just received. |

Control means Rooted, Chilled, Concussed and Blind. Ailments additionally include Burn and Wither. Cleansing blocks incoming ailments, except the explicit friendly Cauterize Burn cost; Wet still prevents that Burn. Status merges take the maximum duration and power, not a sum. Old durations decrement once before fresh applications merge. Consult [`spells-v11.ts`](../../lib/spells-v11.ts) and the resolver status application block for caps/exceptions.

All force vectors sum from the common post-move snapshot. Old Anchored stops them; Guard subtracts one from combined strength; ordinary displacement is capped at two steps. An ice step can slide farther. Force applies to occupants in the spell's area, including allies where the force rule permits; do not infer its safety from damage targeting alone.

A solid ruin/barrier collision inflicts one environmental damage and Concussed, subject to control protection. Units or the map edge can stop displacement without that obstacle-impact damage. Final hazardous ground and solid impact share a one-damage environmental cap per fighter. Final terrain can apply statuses/cleanse after landing; it does not recursively cast another spell.

Current consequence events may include a validated `breakdown`: raw contributing sources, total prevented and resulting total. These values do not assign a fictional post-mitigation share to each caster. Old events may omit the structure. A fully prevented contact can produce a zero-damage explanation without a hit animation or positive crit. See [`combat-consequence-v44.ts`](../../lib/combat-consequence-v44.ts).

## Recovery and elimination

Living fighters recover **2 Flux per exchange**, plus **1 for Guard**, plus spell/field/bond/spring adjustments, capped at max Flux. An occupied spring supplies one extra Flux; a field's spring bonus can add another. Champions normally have 8 HP/6 Flux; creature classes have their own maxima.

Only surviving teams decide victory. No survivors is a draw; one surviving team wins. Defeated actors remain as records for teaching/replay, with zero HP and no active statuses/cooldowns. There is no respawn within the battle and no well-score victory.

| Mode | Closing ground |
| --- | --- |
| Arena / Story | Board radius is player count +7. First closure round is player count +8: round 10 for the two-company Story board, round 14 for six-player Arena. Every two rounds the safe radius shrinks by two. Damage rises with each wave; the final radius-zero wave deals eight. Final bounds range from round 18 to 26. |
| Tower ordinary / elite | First closure round 6; four waves every two rounds, damage 1/2/3/8, final bound round 12 |
| Tower boss | First closure round 8; same four-wave sequence, final bound round 14 |

Closing ground uses the **final position after displacement**, bypasses Guard/Ward and preserves simultaneous elimination. Tower's safe radius is calculated from its map radius, even when a shared fight uses a larger board. Tower healing tax is zero through round five, one in rounds six–eight and two from round nine; it is applied per recipient across ordinary healing and later bond recovery, equally to both sides.

Authority: [`endgame-v18.ts`](../../lib/endgame-v18.ts), [`tower-endgame-v22.ts`](../../lib/tower-endgame-v22.ts). `MAX_ROUNDS = 26` is a save-validity ceiling, not a new draw-at-26 rule.

## Progression, equipment and shared ownership

| System | Persisted rule |
| --- | --- |
| Story | Profile format 4 tracks ordered victories, learned spells, one hero and two companions. Budget `min(18, 5 + victories)`; rank cap `min(6, 3 + victories)`. Individual enemy defeats teach even on a later loss; first ordered victories alone add affinity. |
| Tower | Run format 3, nine floors, two starting fighters, maximum three. Starting power bands 4/7/10 come from the original pair and remain fixed. Rewards/route are seeded; own learned library and wounds persist. Battle victory restores one HP to every fighter, including fallen fighters. |
| Arena | Exactly three distinct appearances and exactly five affinity each: 15 per player. Teams assign seats alternately; two-team mode requires four or six players. No in-match progression. |

Tower supplies require the persisted `suppliesModel: 'v45'` gate:

| Slot | Effect | Limits |
| --- | --- | --- |
| River stone | Start each fight with Ward 2, duration 2 | Opening condition; consumed Ward is not continuously reapplied |
| Swallow pin | Start with Haste, duration 2 | No ongoing permanent movement stat |
| Clear lens | Start with Clarity, duration 2 | No permanent control immunity |
| Iron knot | Start with Anchored, duration 2 | No permanent force immunity |
| One scroll | One printed-strength cast of Immolate, Frostbite, Bulwark, Gale, Mend or Essence Theft | Uses the normal cast action, zero Flux/cooldown, bypasses affinity/learning/normal spell recovery; still obeys reach/sight/Blind and the saved area profile |

Scrolls are consumed on **actual release**, including interception. A fizzle retains the scroll. They do not teach the spell or use affinity strength scaling. A fighter has one charm and one scroll slot; replacing a reward discards the old slot item. Between rooms, a transfer to another fighter swaps that slot's contents. There is no duplicate stack or unbounded bag. Supply rewards occur on eligible combat/elite floors 1, 2, 4, 7 and 8; odd floors prefer a charm, otherwise a scroll. They preserve training and needed recovery within the three-choice limit. See [`tower-supplies-v45.ts`](../../lib/tower-supplies-v45.ts).

Co-op keeps individual runs while sharing battles. [`tower-shared-battle-v23.ts`](../../lib/tower-shared-battle-v23.ts) prefixes actor IDs with their seat, combines exact participants' opponents and maps controllers separately from combat teams. Completion carries HP/spent scrolls back only to the owning run. Joining a door before launch can replace an earlier choice; launch freezes the group. View/watch cannot mutate another seat's plan.

Optional linked casting is available in a shared Tower fight only when every currently required living controller opts in. The resolver selects at most one eligible pair per allied volley: surviving casts from different controllers, with different primary elements, aimed at the same enemy. That pair spends one extra Flux each for one bonus damage in the exchange. Intercepted casts cannot link; other eligible pairs receive no additional link bonus, and solo play has no link.

The authoritative service validates actions rather than accepting a client-supplied victory. Request IDs and payload receipts make retries idempotent; a different payload with a reused ID is rejected. Room membership uses private seat credentials in addition to an invitation code. See [`tower-rooms-v23.ts`](../../lib/tower-rooms-v23.ts), [`tower-http-v23.ts`](../../lib/tower-http-v23.ts), [`tower-client-v23.ts`](../../lib/tower-client-v23.ts). Solo local state is validated for consistency but is not a remote anti-cheat boundary.

## Seeds, route identity and AI

Arena map IDs have the form `arena:<2–6>:<seed>` with an optional explicit `:m44-crossing`, `:m44-courtyard` or `:m44-grove` motif. Canonical arena seeds are uppercase 1–24 letters/digits/hyphens. Radius is player count +7, with `1 + 3r(r+1)` cells. Generation protects camps and connecting routes, creates biomes/high ground/springs, and repairs inaccessible walkable components by removing necessary ruin blockers.

Tower seed input additionally accepts spaces; the run derives its room/map identities. Reproducing a run requires its starting builds, frozen route participant count and generation/profile gates as well as its seed. A seed alone does not promise identical encounters across different starting power bands or code versions.

Route width is launch participants +2; an absent persisted count means the legacy three-room route. The ninth floor has one boss room. Wider graphs offer local movement and a shared rendezvous route so separated squads can rejoin. Do not regenerate chosen/history room IDs because a player disconnects. See [`tower-route-map.ts`](../../lib/tower-route-map.ts).

`planAI` in each resolver uses public state. Current-profile joint planning evaluates at most three landing candidates for small battles and two for larger ones; it also evaluates cast utility, ally hazards, field interactions, status value and closing pressure. Search is deterministic and bounded. [`support-value-v44.ts`](../../lib/support-value-v44.ts) models marginal support rather than counting every Ward refresh as a new full shield; threat estimates remain heuristics, not access to sealed orders. [`planning-geometry-v44.ts`](../../lib/planning-geometry-v44.ts) caches geometry within a planning pass.

Do not add hidden enemy-order reads to improve apparent AI performance. Preserve old-profile planning behavior where explicitly gated, and measure request CPU/latency on large shared battles when extending candidate search.

## Regression anchors

These files are executable contracts to consult and extend. Their listing is not a claim that the documentation-only handoff reran them.

| Concern | Tests |
| --- | --- |
| Current/legacy effects, timing and contribution explanation | [combat-contract-v44](../../tests/combat-contract-v44.test.ts), [joint-planning-v44](../../tests/joint-planning-v44.test.ts) |
| Map generation / endgame | [arena-v17](../../tests/arena-v17.test.ts), [endgame-v18](../../tests/endgame-v18.test.ts), [endgame-symmetry-v18](../../tests/endgame-symmetry-v18.test.ts) |
| Story teaching and real combat | [campaign-progression-v20](../../tests/campaign-progression-v20.test.ts), [campaign-clash-counterplay-v20](../../tests/campaign-clash-counterplay-v20.test.ts) |
| Tower generation, starts and pacing | [tower-model-v23](../../tests/tower-model-v23.test.ts), [tower-model-v22](../../tests/tower-model-v22.test.ts), [tower-experience-v44](../../tests/tower-experience-v44.test.ts) |
| Route/scout/shared ownership | [tower-route-scaling-v42](../../tests/tower-route-scaling-v42.test.ts), [tower-scaling-review-v42](../../tests/tower-scaling-review-v42.test.ts), [tower-scouting-service](../../tests/tower-scouting-service.test.ts), [tower-shared-battle-v23](../../tests/tower-shared-battle-v23.test.ts) |
| Supplies, authenticated retries and display | [tower-supplies-v45](../../tests/tower-supplies-v45.test.ts), [tower-supplies-service-v45](../../tests/tower-supplies-service-v45.test.ts), [tower-supplies-render-v45](../../tests/tower-supplies-render-v45.test.ts), [tower-transport-v43](../../tests/tower-transport-v43.test.ts) |

For a rule change, test the native result, restored result/replay, preview and AI view of the same fixture. Include a legacy fixture and a current-profile fixture rather than changing the default constructor underneath an old expectation. Multiplayer tests must include mixed starting powers, four/six seats, ownership rejection and retried identical actions. Browser/phone readability and human pacing remain separate validation work.

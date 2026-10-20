# Story, signature spells and affinity strength

Rules 10 adds shared signature learning and bounded spell scaling. It keeps simultaneous team orders, four configurable spells, the creator's fixed fifth action, five starting affinity points, seeded maps and the existing win condition.

## Story and learning

All thirty canonical characters have one freely selectable encounter. Each uses a fixed seed, the signature's creator and two fixed companions. The selector shows the opponent's race, affinities, company, a short tactical introduction and the reward. Every encounter can be replayed; there are no prerequisite victories.

Win the complete encounter as player 0 to learn its creator's signature. A character falling in combat is not sufficient. Losses, draws, unfinished rounds, practice, local duels and online matches award nothing. Repeated victories do not duplicate rewards. The award path validates the current-rules result, matching seed and exact enemy company, in addition to the UI's active Story session.

Progress is a separate browser-local profile under `hex-confluence-story-v10`, containing a version and known defeated encounter IDs. It applies to the player's entire roster. It does not alter previous match saves, transfer between devices or verify achievements against an account. Malformed or oversized progress is read safely without preventing unrelated save and loadout initialization. If storage cannot write a victory, learned spells remain available in the open tab and the interface explains the limit.

## Creator and borrower rules

| Rule | Creator | Another character |
| --- | --- | --- |
| Must win the creator's Story encounter | No | Yes |
| Matching affinity required | 3 | 5 |
| Flux cost before statuses | 3 | 5 |
| Equipped position | Fixed fifth action | One of four configurable slots |
| Recovery | 3 planning rounds | 3 planning rounds |

A signature uses its creator's highest **starting** affinity. Training another element higher does not change the spell's identity or element. Only its creator receives the two-point and two-Flux discount. Ordinary affinity cost discounts do not stack with signature discounts. Concussion still adds one Flux.

Learning makes a spell available across the roster; each borrower must still develop its element to five within the usual three-element limit. The fixed fifth action cannot be equipped again in an ordinary slot. A borrowed signature can be trained for, equipped and cast in the same sealed round. Unequipping preserves its cooldown.

## Effective strength

Every spell uses the caster's current matching affinity for strength, independently of its catalogue level or creator discount. Preview, targeting, resolution, AI evaluation and numerical descriptions share the derived spell. The reward selector explicitly previews effects at the normal five-affinity requirement.

| Affinity milestone | Added strength |
| --- | --- |
| 2 | +1 aimed hex of reach |
| 3 | +1 to one primary effect |
| 4 | +1 round to eligible statuses, capped at 3 |
| 5 | Another +1 aimed hex of reach |
| 6 | Another +1 to the same primary effect |

Primary effect selection is ordered: damage if present; otherwise healing; otherwise the first friendly/self Ward's power; otherwise Flux restored; otherwise Flux stolen. A mixed damage/healing spell gains damage, not both. A healing spell with Ward gains healing, not Ward too. Spells without those effects gain only their applicable reach and duration bonuses.

Rooted, Blind, Chilled and Concussed keep their original one-round duration. Eligible hostile marks and beneficial friendly/self statuses gain duration. Harmful self/ally costs, including Cauterize's allied Burn and Soul Chain's self-Wither, do not grow. Given the catalogue's starting durations, Burn and Ward can reach two rounds; Wet, Wither, Haste, Anchored and Clarity can reach three. Strict restoration enforces these bounds.

Self-targeted spells remain self-targeted. Footprint size, displacement, cooldown, recoil, conditional bonus damage, drain healing and temporary elemental field lifetime do not grow. The map's height modifier and Blind still apply after affinity reach. Environmental hazards retain their one-damage-per-round aggregate cap.

Examples at matching affinity 6, before mitigation and field interactions:

- Ember deals 4 damage instead of 2 and reaches two hexes farther. Its hostile Burn lasts two rounds.
- Mend heals 5 instead of 3.
- Bulwark gives Ward 5 instead of 3, for two rounds; the ward is still consumed by the next spell hit.
- Tailwind restores 3 Flux instead of 1 and gives Haste for two rounds.
- Radiant Bolt deals 4 damage to an enemy while its allied healing stays 1.

## Match and save boundaries

Each online seat declares its learned library in the lobby. The library is copied into the new match and cannot be changed by training or order submissions. The server validates known, unique signature IDs, player ownership, matching affinity, equipped slots, costs and cooldowns. These libraries are declared local progression, **not authenticated achievements**; this implementation does not provide account-backed anti-cheat for Story completion.

All new local modes use rules 10. Local duel uses the same browser's library for both players; Story and practice keep the opponent's library separate. Story retries keep the company actually played, including after Resume. Rematches reset affinities and repair only spells that become unavailable at starting ranks. Learned knowledge persists independently of that reset.

Rules 9's engine, saves and `/v9` route remain available, as do older versions. Current local matches use `confluence-tactics-v10`; reading a Story profile does not migrate a match. Current online rules use protocol 10 and separate draft storage. The existing database schema stores the expanded match data without a new migration.

## Verification checkpoint

Local checks passed: **446 automated tests**, TypeScript, production build and **52 HTTP checks** against the built Worker.

Coverage includes all thirty creator identities and discounts, borrower learning plus affinity, same-round training/equipping/casting, effective-stat bounds, retained cooldowns, strict save restoration, malformed libraries, private sealed orders, retries, real match completion and rematch repair. Story tests run a complete legal seven-round win with save restoration after every resolution. Client tests execute the actual Story launch, resume, retry and award handlers, including no reward outside Story, corrupted profile recovery and storage-write failure.

A real browser Story playthrough with Grace Riva, Spai Si and Haara beat Oh Tipi in seven rounds, 16-12. The result awarded Current Anchor; reload retained 1/30 learned spells. Wa Bidi's catalogue showed that learned signature at 5 Flux with only the unmet Water-affinity requirement. Browser checks at 390x844 and 320x568 found no horizontal overflow; at 320x568 all five spell buttons remained above the fixed turn bar. No console errors were observed. Publication and public-endpoint checks are reported separately. Simulations and handler tests do not establish physical-phone comfort, human learning speed, competitive balance or enjoyment; those require independent playtesting.

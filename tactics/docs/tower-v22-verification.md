# Tower v22 verification

The final v22 model shortens the observed fights, makes all three presets capable of clearing the tower under a common adaptive policy, and adds cooperative choices with an explicit cost. It does **not** establish a balanced player win rate. The fixed reward/equipment policy still loses eight of nine climbs; Dusk loses on floor 2 in two seeds. Ordinary fights have a median of 9 exchanges, above the desired 5–8 target. These remain useful playtest targets rather than claims that balance is finished.

## Exact scope

- Frozen v21 remains separate. New v22 models are `lib/tactics-v22.ts`, `lib/tower-v22.ts`, and `lib/tower-endgame-v22.ts`.
- Starting builds allow all 30 champion appearances, exactly five affinity points across at most three elements, four legal equipped spells, and the champion's intrinsic signature. Between rooms, names, affinity allocation and learned spells can be changed within the earned budget. Creatures keep canonical kits and stats.
- Closer deployment preserves the full seeded board. Distinct room lanes begin with six central flooded, burning or draft hexes for two exchanges, or plain ground. Early two-creature enemy parties have distinct primary elements and at least one spell with base damage of two or more.
- AI now values actual firing positions and displacement out of shelter, and avoids predicting a movement collision merely because an enemy could reach that hex. Cast scoring uses public Guard likelihood, never secret orders or the stale previous Guard flag.
- Public Overtime reduces each fighter's combined healing once per exchange: one from round 6, two from round 9. It includes spells, fields and bonds, is symmetric, and cannot be cleansed. Closing-ground damage starts at 6 in ordinary rooms and 8 at the boss. There is no arbitrary round-limit winner; victory requires eliminating the other party. Simultaneous elimination remains a loss for the run.
- Defeated enemies teach their own distinct spell; surviving enemies do not. Training offers are useful to owned spells. Camp 6 can offer a canonical standard companion alongside healing and training. S. Wayne starts with a Light attack and Whisk's displacement instead of an exclusively supportive companion; the starting affinity and health budget is unchanged.
- Cooperative founders retain their own fighters. The shared third fighter changes controller each floor. Link requires both controllers' consent and qualifying cross-element casts from different controllers on the same enemy: each pays one additional Flux and the volley deals one extra damage. No valid pair means no payment or bonus.

## Actual climb results

All outcomes below came from the real plan validation, AI, simultaneous resolver, strict restoration and room/reward transition APIs. No winners or battle HP were edited. The three final v22 suites contain 15 climbs and 78 battles; the v21 comparison contains nine climbs and 49 battles. The same final model hashes were verified against every v22 suite before this report was generated.

| Suite | Clears | Battles | Median / mean rounds | Ordinary median | Boss median | Battles ≥18 | Ending exchange had collapse |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| v21 fixed policy | 4/9 | 49 | 10 / 10.94 | 10 | 11 | 7 | 8 |
| v22 fixed policy | 1/9 | 44 | 8 / 7.86 | 9 | 7 | 0 | 6 |
| v22 cooperative policy | 2/3 | 16 | 9 / 8.56 | 8.5 | 11.5 | 0 | 2 |
| v22 adaptive policy | 3/3 | 18 | 9 / 8.67 | 9 | 9 | 0 | 3 |

The 41 battle pairs sharing seed, starter and floor average 10.8 rounds in v21 and 7.88 in v22. This comparison reduces the effect of early losses omitting later rooms, but does not hold all mechanics and enemy draws constant: the opening composition, Dusk preset and reward catalogue intentionally changed.

| Suite | Starter | Clears | Battles | Ordinary median | Boss median | Ending exchange had collapse |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| v22 fixed policy | steam | 0/3 | 16 | 8 | 8 | 1 |
| v22 fixed policy | stone | 1/3 | 18 | 9 | 6 | 2 |
| v22 fixed policy | dusk | 0/3 | 10 | 8 | 7 | 3 |
| v22 adaptive policy | steam | 1/1 | 6 | 9 | 9 | 1 |
| v22 adaptive policy | stone | 1/1 | 6 | 9 | 12 | 1 |
| v22 adaptive policy | dusk | 1/1 | 6 | 8 | 8 | 1 |

The fixed suite uses TOWER1, TOWER2 and TOWER3 for each preset. The adaptive suite uses TOWER3 for all three presets: Steam won in 55 exchanges, Stone in 55 and Dusk in 46. It preserves two attack elements, drafts an available spell when it improves the weakest equipped slot, and recruits a creature on floor 6 when sufficiently healthy. This demonstrates viable builds and meaningful route/equipment decisions on that seed; it does not prove equal difficulty across seeds. It also does not directly retest the two floor-2 Dusk losses with the adaptive policy.

The cooperative suite uses Steam + Stone on TOWER1, Stone + Dusk on TOWER2, and Dusk + Steam on TOWER3. Two clear; Stone + Dusk is simultaneously eliminated on floor 5. Across 16 battles it produces 31 paid Links. This is model cooperation with allied AI orders partitioned by controller; it is not a human cooperation, latency or connection test.

## Repeatable policy and evidence

Fixed policy: equip the two highest scored attacks, one heal, then the best remaining card. Recruit on floor 3; camp on 6 and 8; select ordinary combat otherwise. Choose recruitment first, healing when the party is missing at least five HP, then primary affinity, other training and the first remaining offer. The v22 camp-6 companion is selected by that same priority; v21 did not offer it. Neither suite uses free respec as an optimization policy. Rewards, enemy names, map seeds, final health, per-battle casts, Link counts and collapse damage are preserved in [tower-v22-balance.json](tower-v22-balance.json), together with source SHA-256 hashes and the full policy descriptions.

An ending exchange containing collapse damage is reported as such, without attributing the whole outcome to collapse. In the final fixed suite, six of 44 ending exchanges contain collapse damage; most fights end without it. Exact damage totals and counts of battles containing any collapse are in the JSON. Final v22 has no observed 18-round stall, although five fixed-policy battles still reach round 12 and two end in mutual elimination there.

## Model checks and timing

The focused model suite passed **24/24 tests**:

`node --test tests/tower-model-v22.test.ts tests/tower-combat-v22.test.ts`

Coverage includes canonical build budgets and signature ownership, all 93 creature kits, multi-element interactions, variable party size, injured restores, malformed saves, deterministic rooms, 192 early-room enemy previews, actual Dusk TOWER3 elimination before collapse, per-enemy spell teaching, camp choices, cooperative ownership and consent/payment, forged Link events, aggregate Overtime healing, public-state AI and elimination rules. Scoped strict TypeScript compilation passed for the three models and the two test files. Network, browser and rendered effects have separate integration evidence maintained by their owners; these model checks do not substitute for it.

A final local timing pass sampled 13 real positions, including a cooperative boss position. Enemy AI median wall time was 45.6 ms (maximum 103.03 ms); resolution median was 49.04 ms (maximum 110.82 ms). These are Windows Node measurements under the current host load, not production edge timings, animation durations or phone frame rates. Raw wall and CPU timings are in the JSON.

## Remaining validation limits

This bounded deterministic sample establishes functioning progression, legal choices, reproducible fights and reduced observed stalling. It does not measure human readability, enjoyment, retention, optimal play or population win rates. Ordinary pacing remains slightly longer than the 5–8-round design target; fixed-policy Dusk outcomes and boss difficulty merit human playtests. No additional mechanics were changed after the final evidence source hashes were captured.

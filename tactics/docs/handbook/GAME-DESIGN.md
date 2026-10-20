# H.E.X. game design

This is the design map for the **release 45 web game**, checked against its executable source on 2026-10-20. It describes the implemented game, including its constraints; it is not a list of promised features. The original Godot game and this web adaptation share a cast and elemental identity but have different combat systems. When the web app is stored under `tactics/`, all paths below remain relative to this handbook.

For numerical rules, timing and compatibility, read [MECHANICS.md](MECHANICS.md). Historical design documents explain earlier decisions; the active constructors, validators, resolvers and their tests determine current behavior.

## Identity and decision loop

H.E.X. is a simultaneous, turn-based elemental tactics game. Players arrange a small party, choose movement and one action for each fighter, commit, and watch everyone move before spells resolve together. Victory means eliminating the opposing team or companies. Springs replenish Flux; they are not capture objectives.

The distinguishing decision is **where a spell will land after everyone moves, and what its element will make with the other spells and ground there**. Terrain, interception, support timing, ally exposure and future positioning should matter together. Four configurable spells constrain a champion's available answers; a signature adds an identity-specific option once its three-point affinity requirement is met. A large catalogue supplies alternatives between encounters rather than requiring a large action bar during an exchange.

The design constraints used to continue this game are:

| Principle | Implementation consequence |
| --- | --- |
| Depth comes from interacting rules | Prefer a new use for movement, a field, a status or an existing spell over another isolated subsystem. All ingredient sets resolve through the same field catalogue. |
| Commitment must remain meaningful | Opposing orders are private. Aim at ground, not an enemy's guaranteed future position. Do not let a newly inflicted status retroactively cancel a released spell. |
| Preparation should be legible | Show effective reach, footprint, costs, access and consequences for the selected fighter and saved rules profile. Catalogue values alone are insufficient. |
| Information must state its limits | A legal attack envelope is a possibility, not an announced enemy action. A selected-action preview is not the whole unknown exchange. |
| Cooperation should change decisions | Shared Tower battles combine parties and enemy encounters, allow coordinated drafts and optional linked casts; nearby complementary creatures grant bounded bonds. |
| Progression should create tradeoffs | Four slots, at most three affinity elements, limited party size, carried Tower wounds and one charm/scroll slot prevent unlimited accumulation in combat. |
| Pace should be enforced by the battlefield | Closing ground creates positional pressure. Tower additionally reduces late healing. Neither mode awards a score victory at an arbitrary round limit. |
| Character identity survives customization | A champion's appearance, native primary element and signature remain linked. Creation changes legal affinities, name and loadout, not base-stat advantages. |
| Charm must not obscure causality | Pixel animation and humor support the action. Terrain, range, status and event explanations must remain readable without relying on decorative motion or flavor text. |

These are continuation constraints, not a claim that all pacing or usability problems have been solved.

## Active modes and boundaries

| Mode | Player decisions and progression | Authoritative implementation |
| --- | --- | --- |
| Story | One customizable champion plus two creature companions; ordered champion encounters and optional creature-learning fights. Individual enemy defeats teach spells; first victories in ordered encounters grow the hero's affinity budget. | [Story adapter/progression](../../lib/story-v20.ts), [profile](../../lib/campaign-profile-v20.ts), [encounters](../../lib/campaign-encounters-v20.ts), [rules 20](../../lib/tactics-v20.ts) |
| Tower, alone or with friends | A fresh run starts with two freely chosen legal fighters. Choose routes, scout, fight, choose one reward and rebuild between rooms. Nine floors; party limit three per player. Story progression does not carry in. | [Run model](../../lib/tower-v23.ts), [rules 22](../../lib/tactics-v22.ts), [co-op service](../../lib/tower-rooms-v23.ts) |
| Arena | Two to six players; free-for-all, or two teams with four/six players. Every player brings three distinct champion appearances, five affinity points each. Builds remain fixed within the match. | [Character creation](../../lib/character-creation-v17.ts), [rules 18](../../lib/tactics-v18.ts), [room service](../../lib/skirmish-rooms-v18.ts) |

The active web Arena is an equal-budget private-room mode, not a ranked matchmaking or persistent Story-power ladder. Its team accounting should not be described as an implemented rating system. Tower is one player-facing mode with solo and cooperative entry; internally each co-op participant retains a personal `TowerRun`, and the service coordinates them.

The runtime files keep versioned names intentionally. Story 20, Tower 22 and Arena 18 are all active; a higher number elsewhere does not mean that mode should use it. Presentation adapters may produce a rules-16-shaped view for shared rendering. That view must never be submitted to a rules-16 resolver or saved in place of the native state.

## Element and character identities

There are six base elements. Lightning, Ice, Metal, Storm, Radiance and Void are advanced branches of those elements, unlocked by affinity thresholds; they are not six additional mixing ingredients.

| Base / advanced branch | Tactical personality supported by the current rules | Important tension |
| --- | --- | --- |
| Fire / Lightning | Pressure, Burn, conditional damage, recoil and hazardous ground | Wet and cleansing deny Burn; mixing can turn dangerous Fire into shared shelter. |
| Water / Ice | Wet, cleansing, pulling, flooded passage and freezing | Flood costs movement; ice creates long straight landings. Water helps some enemy conditional attacks too. |
| Earth / Metal | Ward, anchoring, roots, terrain obstruction and piercing tools | Fresh Ward and Anchored prepare the next exchange; they do not erase damage or force already resolving. |
| Air / Storm | Push/pull, Haste, currents and displacement combinations | Guard reduces net force, existing Anchored stops it, and opposing vectors can cancel. |
| Light / Radiance | Healing, cleansing, immediate control protection and protection-breaking Sunburst | Healing is capacity-limited and can be taxed. Light fields protect either side from incoming control. |
| Dark / Void | Wither, resource theft, drain, impaired reach and conditional finishers | Theft uses Flux remaining after spell costs; drain requires actual enemy spell damage; cleansing and spending Flux provide counterplay. |

Use the [spell catalogue and branches](../../lib/spells-v11.ts), [current access/description layer](../../lib/spells-v13.ts), [creature spell extension](../../lib/spells-v20.ts) and [field catalogue](../../lib/combinations-v16.ts) for individual rules. A spell can deliberately cross a broad personality; the table is not an exclusive ability whitelist.

Canonical champion identity comes through [roster-v13](../../lib/roster-v13.ts) → [roster-v11](../../lib/roster-v11.ts) → [roster-v7](../../lib/roster-v7.ts). The roster-v11 transformation preserves original element membership and adds the fifth starting affinity point to the primary element. Custom creation has a separate validator: it may redistribute points within the three-element limit, while keeping the native primary at least as high as every other allocated element. Do not replace canonical data with an earlier reference poster or infer mechanical bonuses from race/artwork.

Creatures are combatants with authored identity, class, native kit, elemental ingredients and a partner perk. Lesser, standard and greater classes have different health, Flux and kit budgets. Their native kits are fixed; recruited champions use configurable four-spell kits. Creature spells have one-to-one teachers, so teaching and reward code must preserve `creatureId`, not identify a creature solely by its champion mechanics proxy. See [creatures](../../lib/campaign-creatures-v20.ts), [class/perk definitions](../../lib/campaign-creatures-v19.ts), [techniques](../../lib/creature-spells-v20.ts).

Creature bonds make formation matter: a living compatible pair can benefit a surviving ally within two hexes of both. Matching benefits do not stack; a fallen source contributes nothing. Health/Flux recovery happens after ordinary combat, while protective statuses prepare subsequent action. This creates a reason to stay together and a vulnerability to area attacks and separation.

## The exchange as a design unit

A fighter may move, then cast or Guard. Orders without a cast default to Guard. Movement is simultaneous; contested destinations can leave a fighter at the original hex, changing the origin from which its already chosen target is checked.

The readable presentation sequence is:

1. **Planning:** inspect public positions, terrain, status duration, legal movement and spell reach; assign ground targets.
2. **Movement:** show landings and blocked moves before spell flight.
3. **Casting:** all legal releases share one clock. Moving projectiles may contact; ordinary target impacts may create fields together.
4. **Consequences:** damage, healing and status results, then forced movement and final terrain.
5. **Aftermath:** creature bonds, closing ground, Flux recovery and the next planning state.

This sequence must reflect the authoritative resolver, not alter it for animation convenience. Health changes are simultaneous, not a series of screen-order attacks. Slowing or replaying an animation must not change collisions, damage or room state.

Current broad spells have a deterministic stronger centre, an ordinary inner ring and a weaker outer rim. Precision, line, fan, ring, self and wall tools retain their distinct footprints. This creates a choice between exact placement, broad terrain coverage, ally exposure and specific utility. A centre “crit” is deterministic; there is no random critical-hit roll.

The full interaction set is more important than pair recipes. Fire + Water makes Steam, but adding Earth makes Hot Spring; it does not run Steam and two other pair reactions underneath. Six elements make Worldseed, a temporary shelter/cleanse/Flux event. Many mixtures impose costs alongside benefits. Fields are neutral opportunities affecting both sides rather than ownership-colored buffs.

## Information contract

| Situation | Show as known | Keep conditional or unavailable |
| --- | --- | --- |
| Own planned action | Cost, access, projected origin, legal footprint, focus bands, known allied contacts, supported target consequences | Enemy movement, Guard and unseen casts; combined exchange totals |
| Enemy inspection | Current kit, affinities, statuses and maximum legal threat envelope | Chosen move/target; the envelope is not an enemy intent telegraph |
| Arena team battle | Own controllable orders and geometry | Other players' allied orders are private too; exact team impact/field forecasts are suppressed when those orders are missing |
| Tower shared battle | Public state and authorized allied drafts/locks | Enemy sealed plan |
| Tower route | Connected paths, room category and baseline clues; earned scout facts for the exact encounter | Unscouted identity/affinity/technique/environment details; at least one equipped technique per foe is reserved from scouting |
| Replay/consequence readout | Recorded native events and optional validated contribution breakdown | Reconstructed per-caster post-mitigation damage, or new-rule interpretations of an old event |

Room discovery is a gameplay information policy, not a claim that client-visible solo data is cryptographically secret. Network services must still keep opposing sealed plans and seat credentials private. Source-backed preview boundaries live in [Arena presentation](../../lib/arena-presentation-v44.ts), [target impact](../../lib/target-impact-v41.ts), [Tower party route](../../lib/tower-route-party-v43.ts) and [scouting](../../lib/tower-scouting-state.ts).

## Story structure

Story offers thirty ordered champion encounters in three chapters. Enemy parties progress from one champion plus creatures to two and then three champions. Completing the next encounter opens the following one; completed encounters remain replayable. Optional seeded field encounters teach available creature techniques without advancing ordered Story affinity rewards.

Each individually defeated enemy type teaches its own spell, even if the player's party later loses. A first valid Story victory increases the hero's affinity budget by one, from five to a maximum of eighteen; rank access rises to six. Companion availability expands by completed Story count. Repeated victories do not farm extra affinity. The current starting party is Oh Tipi with Puddle and Cinder.

Profile progression and battle state are separate validated records. Do not award knowledge by parsing combat prose or assume a room win is necessary for an individual teaching. See [progress application](../../lib/story-v20.ts), [profile validation](../../lib/campaign-profile-v20.ts) and [progression tests](../../tests/campaign-progression-v20.test.ts).

## Tower structure and rewards

Tower starts from suggestions, not locked classes: choose two different legal champions/lesser creatures. The starting composition sets an immutable encounter power band of four, seven or ten affinity. Later training does not retroactively inflate the encounter tier. A run owns its learned library, builds, wounds, items, route and seed.

The choice cycle is route → battle or safe room → one reward → next route. Ordinary and elite fights offer bounded progression/recovery choices; recruits, camps and tuition have their own roles. Tuition costs the first fighter two health and requires at least three beforehand. Recruiting can grow the party to three; founding champions are protected from replacement.

Victory heals each fighter by one, including returning a fallen fighter at one health. Wounds otherwise persist. Statuses, cooldowns and combat Flux do not carry between fights. Every defeated enemy supplies its own teaching; the extra spell reward is a draft choice, not the sole way to learn spells. At a route checkpoint, a champion can rearrange its existing affinity budget and known four-spell kit while retaining appearance and signature.

Release 45 adds a small supplies system: one opening-condition charm and one one-use scroll per fighter. There is no stockpile, random stat-roll system or permanent equipment-stat growth. Eligible combat rewards can offer a supply without displacing regular training and needed recovery; camps, recruitment and tuition retain their identities. See [run/reward authority](../../lib/tower-v23.ts), [supplies](../../lib/tower-supplies-v45.ts), [reward consequence previews](../../lib/tower-reward-preview-v42.ts).

Cooperative Tower supports up to six players:

- Launch freezes occupied participant count. Each floor has `players + 2` parallel rooms, except the single final boss room. Solo therefore has three; six players have eight. Departures do not regenerate the route.
- Players choose reachable doors independently. Those choosing the same door fight together in one map; others fight separate encounters at the same depth.
- Shared opponents are the union of the participating squads' actual encounters, each generated for its own starting band. Do not multiply one squad's opponent count to estimate a mixed group.
- Wider route graphs retain a shared next-floor rendezvous option. Each living champion can reveal one additional scout fact per floor. Shared reports only apply to the exact matching encounter.
- All continuing players finish their floor and reward before the service advances the depth together. Knowledge is shared at the checkpoint; wounds, affinity, equipment and equipped slots remain local.
- Choosing a door can be changed before launch. Once battle begins, another player may watch but cannot join that already assembled battle.

Authority: [route topology](../../lib/tower-route-map.ts), [shared battle assembly](../../lib/tower-shared-battle-v23.ts), [service synchronization](../../lib/tower-rooms-v23.ts), [scout actions](../../lib/tower-scouting-actions.ts). Avoid implementing “join” only in the UI: reachability, floor, gathering phase, actor ownership and tuition health must agree with the service.

## Pacing, AI and continuation priorities

Arena/Story closing ground scales with map/player count. Tower pressure begins earlier, and healing is taxed after the fifth exchange. These mechanics constrain stalling without changing the elimination objective. They do not guarantee that every ordinary encounter feels short.

Current AI is deterministic bounded search over public state, not a learned agent or perfect solver. For `focused-v44`, it compares a small set of move/cast alternatives, considers actual geometry, friendly exposure, elemental contacts, status value, barriers, support and closing ground. Marginal support valuation avoids repeatedly treating an already supplied Ward as wholly new protection. Candidate and cache bounds matter on shared server requests. See [joint planning](../../lib/joint-planning-v44.ts), [support value](../../lib/support-value-v44.ts), [geometry cache](../../lib/planning-geometry-v44.ts) and each native engine's `planAI`.

Continue by tightening existing decisions before adding content. A useful vertical slice has two allies against two or three foes, one terrain transformation, a possible projectile contact and a visible counterplay alternative. Check whether the player can understand the choice before committing and explain the result afterward. Repeat across mobile and desktop, a defensive starter, a custom pair, and a shared encounter.

Any future mechanical change should first add native parity/compatibility fixtures, then update resolver, legal geometry, AI, forecast, reference text and replay together. Preserve intentional mode differences. Simulated wins, regression tests and browser checks are different evidence; none alone establishes human enjoyment or competitive balance. Relevant regression anchors are collected in [MECHANICS.md](MECHANICS.md#regression-anchors).

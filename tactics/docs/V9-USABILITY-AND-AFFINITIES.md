# Usability and affinity unlocks

Rules 9 combines clearer team preparation and direct battle controls with affinity progression earned during a match. It retains thirty original characters, four configurable spells, a fixed signature, seeded geography and simultaneous resolution. Previous rules remain available for ongoing matches.

## Player-facing changes and acceptance

| Observed friction | Change | Acceptance |
| --- | --- | --- |
| Comparing the team's moves requires selecting each character. | Three complete team cards show race, named affinity counts, unlocked branches, four equipped spells with costs and the signature. | All twelve ordinary spells are available without changing selection. Any slot opens the correct editor in one action. |
| Recruitment requires a details modal even when the player knows the character. | Race, affinity and text filters; every result includes the kit, with separate Recruit and Details controls. | Direct Recruit changes one slot; existing teammate selection never creates duplicates. Keyboard focus returns to the selected team member. |
| Forty-eight catalogue entries are hard to search. | Effect, name, element, branch and shape search; purpose filters; current/other-slot labels and locked-spell reasons. | Filters compose, empty results have recovery, duplicate and affinity-locked spells cannot be equipped. |
| Phone casting requires opening a spell chooser. | Five direct spell choices, adjacent Move/Guard controls; optional expanded descriptions remain. | Spell → target is two taps rather than menu → spell → target. Browsing a spell never replaces a queued cast until a target is chosen. |
| Character selection resets the map zoom. | Preserve explicit Overview across selection, planned movement and completed resolution. | Center or Focus deliberately restores the close camera. |
| Axial coordinate pairs are difficult to follow in orders and logs. | Canonical tile labels use screen columns A–S and rows 1–19. Active targets show their reference beside the hex. | The same tile has the same label in targeting, orders, logs and keyboard inspection; axial coordinates remain unchanged in game state. |
| Interface repetition competes with the board. | Compact battle navigation, direct spell controls and optional detail disclosures keep actions and their consequences together. | Queued orders remain distinct from a browsed spell; the selected action, target and resource cost stay readable. |

## Six affinity levels

Characters start with five affinity points across their original two or three elements: 3+2 or 3+1+1. The primary element starts at three. Allocations are capped at three different elements and level six per element; invested points cannot be removed or reassigned during the match.

Every character on both teams earns one point after each two completed rounds. The available total is `5 + floor((round - 1) / 2)`: six points at round 3, seven at round 5, eight at round 7. Unspent points remain banked. Kills and scoring do not change this income.

Each element's eight ordinary spells span six ranks: two at rank 1, two at rank 2, and one each at ranks 3–6. Rank 1 is universal; ranks 2–6 require the corresponding number of points in the parent element. The derived branch starts at three:

| Parent | Derived branch | Rank 3 | Rank 4 | Rank 5 | Rank 6 |
| --- | --- | --- | --- | --- | --- |
| Fire | Lightning | Lightning Flash | Lightning Lance | Flashburn | Overload |
| Water | Ice | Frostbite | Deep Freeze | Snowmelt | Meltwater Vortex |
| Earth | Metal | Steel Shard | Iron Rampart | Iron Fault | Iron Quake |
| Air | Storm | Wind Shear | Thunderclap | Stormguard | Cyclone |
| Light | Radiance | Sunburst | Prism Lance | Inspire | Sanctuary |
| Dark | Void | Essence Theft | Reap | Null Field | Eclipse |

Training and loadout changes are sealed with the team's orders. Both teams' preparation applies before movement and casting, so a newly unlocked and equipped spell can be cast in that exchange. Neither training nor equipment choices appear in the opponent's snapshot before resolution. Unequipping a spell preserves its cooldown; re-equipping cannot bypass recovery. A character's fixed signature remains available to its owner at every level.

Two or more affinity points reduce Flux cost by one, one point pays base cost, and zero costs one extra. Higher levels unlock options without stacking this discount. New starter kits include the primary rank-3 unlock and only spells that character can currently use.

The catalogue retains 48 ordinary IDs and 30 signatures. Lightning Lance changes from 2 ordinary damage to 1 piercing damage, with +1 against an already-Wet target. Wet applied during the same exchange gives no bonus. All other spell combat properties retain parity with rules 8. Derived branches use their parent element for field reactions; Snowmelt heals and wets its footprint without freezing it.

## Motion and feedback

Projectiles anticipate, travel along the cast geometry and arrive on the impact clock. Lightning and Metal have distinct impact silhouettes; freezing spells retain a separate frost impact. Existing character motion follows actual movement paths. Flames and embers, steam puffs and ice glints make fields visible between exchanges. Overview suppresses ambient animation, and reduced-motion styles retain static material cues. These are presentation changes; animation timing does not change simultaneous combat ordering.

## Save and online boundaries

Rules 9 has a separate engine, save key, draft namespace and spell catalogue. Rules 1–8 retain their own resolution and strict-restoration paths. Rules 8 local saves remain accessible through Older saves and `/v8`; reads do not rewrite active matches. New invitations and mutually accepted rematches use rules 9.

New submissions must contain four distinct unlocked spells. For previously stored preparation kits, only locked, unknown or duplicate slots are repaired; legal choices stay in their original positions. A notice explains migration. Shared server validation checks ownership, earned budget, element limits, unlocks and cooldowns independently of UI controls.

Local and online rematches both reset affinities to the five-point starting allocation. They preserve legal choices from each character's final kit and repair only slots that become locked or otherwise invalid. They retain the map seed and initial geography. Old rules 1–8 matches keep their own engines and saves until players explicitly start a new match.

## Evidence scope

Automated coverage includes actual UI handlers, all character/spell thresholds, earned allocations and banking, simultaneous training/equipping/casting, retained cooldowns, migration, strict restoration, forged plans, old-room resolution and rematch consent. Every catalogue action is exercised on seeded terrain. Camera tests execute renderer hooks and controls; rendering tests inspect component output. Targeted terminal-round checks cover progression on round 20 and on an early winning exchange.

Final local verification passed: 394 automated tests, TypeScript, production build and 45 HTTP checks against the built Worker. The HTTP suite covers earning a point through two real rounds, private preparation, same-round unlock/equip/cast, retries, a complete eight-round match and rematch repair/reset. Publication and public-endpoint results are reported separately in the release handoff.

A development-browser playthrough verified round-3 training to Water 4, equipping Deep Freeze and casting it at D11, producing Ice. Phone checks at 390×844 and 320×568 found no horizontal overflow; all five direct actions fit above the fixed turn bar at the top of the battle screen. The catalogue fits both widths. The built game also resolved Ember followed by Water Jet, and the Water projectile carried the expected 570 ms start, 330 ms travel and 900 ms arrival timing. Earlier interaction checks covered direct editing, filters, focus return, two-step casting, queued-order preservation, Undo and camera persistence. Browser viewports establish layout and interaction behavior, not physical-device comfort or measured frame rate. Human playtesting remains the evidence for learning speed, enjoyment and sustained tactical balance.

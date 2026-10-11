# Character personality and expression direction

Status: 2026-10-08 source-grounded visual-direction audit of all 30 playable identities. Eleven expression refinements are integrated and source-tested; nineteen current portraits are retained. Table decisions describe the art brief, not unimplemented gameplay powers. Packaging and human acceptance are tracked separately in the [identity checkpoint](CHARACTER-IDENTITY-CHECKPOINT.md).

These are portrait expression directions, not unique abilities, canonical biographies, morality, racial stereotypes or new simulation rules. Preserve each existing identity, face, age, gender presentation, ancestry, anatomy, skin/material palette, hair, outfit and parchment background. Expressions may differ even where profiles and starter kits are identical.

## Gameplay evidence and limits

The [live champion catalog](../content/champions/foundation_champions_v1.json) owns stats and authored affinity order. The [identity registry](../content/champions/champion_roster_plan_v1.json) and [current cast contract](CURRENT-CAST.md) own names and identity constraints. [Body profiles](../content/champions/body_type_profiles_v1.json) bound size roles, not race bonuses. The [catalog application](../src/content/champion_catalog.gd) determines paid flight versus double jump.

The actual twelve-slot starter is produced by [CharacterStarterKit](../src/content/character_starter_kit.gd), not just the older `foundation_kit` primary/active subset. Each starter contains all eight elemental Bolts, one highest-affinity Heavy (authored order breaks ties), then Rapid / Spray / Rapid from the first three priority elements. All 32 current spells are configurable by every champion. Affinity strength is not an automatic damage multiplier; aligned build-cost discounts are bounded by the authored rules, not racial passives.

The [spell matrix](../content/abilities/foundation_abilities_v1.json) defines shared capabilities: Heavy is reactable splash and chemistry setup; Rapid is sustained precision pressure; Spray is close fan pressure. Light Spray is an attack, not healing or shielding. Earth does not grant armor, Dark does not grant invisibility or lifesteal, and ordinary Ice projectile hits do not inherently slow. Tideline has an authored launch component, shared by anyone equipping it. Chemistry fields are shared simulation rules, not champion-exclusive powers. A reassuring or protective expression does not add an ally-protection mechanic.

## Actual profile shorthand

Resource recovery figures are base rates, not delayed idle-ramp rates. Speed is a ratio of base ground speed. S, G and W are Small; M is Middle; L is Large. These are candidate tuning values, not proof of competitive balance.

| Profile | Grounded playstyle basis | Health / recovery per second | Flux / recovery per second | Stamina / recovery per second | Speed |
| --- | --- | ---: | ---: | ---: | ---: |
| S | Quick repositioning, lean Health reserve | 90 / 2.2 | 123.2 / 23 | 620 / 28 | 106% |
| G | Grace's Small variant; largest current Flux reserve | 92 / 1.8 | 132 / 21 | 620 / 29 | 103% |
| W | Wa Bidi's Small variant; strongest current Flux recovery | 98 / 1.8 | 116.6 / 25 | 620 / 32 | 105% |
| M | Balanced resource and position commitments | 108 / 1.8 | 114.4 / 19 | 660 / 30 | 98% |
| L | Deeper Health/Stamina, slower repositioning and Flux recovery | 132 / 1.2 | 105.6 / 17 | 700 / 32 | 91% |

`DJ` means one paid double jump per airtime. `F` means paid flight instead, at most 2.4 seconds for Small, 2.1 for Middle or 1.8 for Large, with cost/drain and no invulnerability. Only Grace Riva, Spai Si, Ha Rekt, Juul I Yaina and Faab I Yaina fly. The Red Baron and the Nymphs do not. Core ground movement remains shared; size does not create unique attacks.

## All-30 matrix

Rows retain live catalog order, not Gallery display order. Affinities retain authored order; triples without numbers are 1+1+1. Air is display text for internal `wind`. Each starter-extra triple means **first element: Heavy and Rapid; second element: Spray; third element: Rapid**, in addition to the eight shared Bolts. Together the profile, air action and starter columns describe actual playstyle choices; expressions are visual interpretation only.

The exact runtime portrait path for each ID is `assets/portraits/champions_v1/<id>.png`. Full-resolution originals live in [the portrait reference folder](../reference/art/portraits_20261008/). Versioned candidates must not overwrite those originals. `Revise` identifies the eleven integrated expression briefs; it does not certify human visual acceptance.

| Champion / portrait ID | Ancestry / profile / air | Affinities | Starter extras | Expression and revision rationale |
| --- | --- | --- | --- | --- |
| Oh Tipi / `oh_tipi` | Seakin / M / DJ | Water 2, Charge 1 | Water / Charge / Earth | Retain warm composure: approachable steady-ground baseline. |
| S. Wayne / `s_wayne` | Hobbit / S / DJ | Dark 2, Light 1 | Dark / Light / Water | Revise: quiet watchful resolve replaces a repeated half-smile; quick precision, not villainy. Preserve rich dark-brown skin. |
| The Red Baron / `red_baron` | Undead / L / DJ | Fire 2, Ice 1 | Fire / Ice / Water | Retain solemn authority through skull angle/posture; distinctive anatomy needs no invented fleshy expression. |
| Grace Riva / `grace_reava` | Sylph / G / F | Air, Water, Light | Air / Water / Light | Revise: open curiosity; generous Flux and paid aerial options support an experimenting read. |
| Wa Bidi / `wa_bidi` | Goblin / W / DJ | Charge, Air, Fire | Charge / Air / Fire | Revise: spirited engagement and bright lively eyes, reflecting strong recovery without manic or aggressive caricature. |
| Steezo / `steezo` | Goblin / S / DJ | Charge, Fire, Light | Charge / Fire / Light | Revise: distinct mischievous delight with expressive cheeks/brows; preserve goggles and identity, not another identical closed smirk. |
| Treevor the Mason / `treevor_mason` | Treefolk / L / DJ | Earth, Air, Fire | Earth / Air / Fire | Revise: tired but steadfast, weighted kindly eyes and level mouth; measured commitments, not a wise-tree stereotype or fatigue mechanic. |
| Oll' I / `oll_i` | Werewolf / L / DJ | Earth, Fire, Light | Earth / Fire / Light | Retain restrained confidence; recognizable canine face and silhouette already contrast with the humanlike faces. No compulsory aggression. |
| Fluup / `fluup` | Orc / L / DJ | Air, Charge, Ice | Air / Charge / Ice | Revise: openly reassuring calm and confident warmth, distinct from Joh's measured reserve; no protector ability is added. |
| Waka Aren Si / `nico_lai` | Gnome / S / DJ | Charge 2, Light 1 | Charge / Light / Water | Retain alert delighted curiosity; goggles, cheeks and head angle already create a distinct read. |
| Spai Si / `spai_si` | Demon / M / F | Air, Earth, Light | Air / Earth / Light | Revise: calculating attentive curiosity, level mouth without smirk; balanced resources and aerial placement, not sinister intent. |
| Leaf the Hidden / `leaf_hidden` | Treefolk / M / DJ | Water, Earth, Light | Water / Earth / Light | Retain quiet observation through covered face, eyes and head angle; name does not confer stealth. |
| Ha Rekt / `ha_rekt` | Wyrmborn / L / F | Ice, Air, Fire | Ice / Air / Fire | Retain composed resolve: distinct draconic face, short paid flight and deliberate ground pace, not automatic ferocity. |
| Dr. Apex / `dr_apex` | Stoneborn / L / DJ | Earth, Light, Water | Earth / Light / Water | Retain mild attentive reassurance; distinct broad stone face. Name and Light do not supply healing. |
| Haara / `haara` | Nymph / S / DJ | Light 2, Air 1 | Light / Air / Water | Revise: stern vigilance and a direct gaze; focused lean-reserve skirmisher, not a default nature healer. |
| Hesus Christo / `hesus_christo` | Elf / M / DJ | Earth 2, Water 1 | Earth / Water / Fire | Retain grounded patience in this bounded batch; no religious or support-power inference. |
| Grimm Bow / `grimm_bow` | Troll / L / DJ | Earth 2, Water 1 | Earth / Water / Fire | Retain reviewed v2 warm curiosity; useful contrast already achieved, no immediate additional edit. |
| Biggy Bob / `biggy_bob` | Dwarf / M / DJ | Earth, Fire, Light | Earth / Fire / Light | Retain earnest determination, brown hair/beard and direct brows; already readable without a new facial redesign. |
| Jan Wicked / `jan_wicked` | Human / M / DJ | Ice, Dark, Charge | Ice / Dark / Charge | Retain restrained sternness, already breaking the smile pattern. Neither name nor Dark establishes morality. |
| Ba Djoh / `ba_djoh` | Minotaur / L / DJ | Earth, Fire, Water | Earth / Fire / Water | Retain steady self-possession and distinctive muzzle/horns; no compulsory raging-bull expression. |
| Urzh / `urzh` | Stoneborn / L / DJ | Earth, Fire, Charge | Earth / Fire / Charge | Retain austere focus as a useful serious anchor; no extra hostility or new glowing features. |
| Don Doko Don / `donnok` | Dwarf / M / DJ | Earth, Fire, Water | Earth / Fire / Water | Retain lively attention; cap, goggles and orange beard already separate the read from Biggy Bob. |
| Djonah Thaan / `djonah_thaan` | Vampire / M / DJ | Dark, Charge, Fire | Dark / Charge / Fire | Retain restrained mischievous amusement; keep fangs without new blood/lifesteal or menace cues. |
| Luuh I Zeh / `luuh_i_zeh` | Spiderkin / S / DJ | Dark 2, Water 1 | Dark / Water / Earth | Retain inquisitive alertness; distinctive nonhuman face should not acquire a human mouth or creepy stereotype. |
| Juul I Yaina / `juul_i_yaina` | Demon / S / F | Ice 2, Air 1 | Ice / Air / Water | Revise: shy but resolved, inward chin, soft brows and steady gaze; reserved adult male, not fragile or frightened. |
| Faab I Yaina / `faab_i_yaina` | Angel / M / F | Fire 2, Light 1 | Fire / Light / Water | Retain firm unshowy determination; no compulsory saintly smile or healer claim. |
| Joh Haynes / `joh_haynes` | Orc / L / DJ | Earth 2, Charge 1 | Earth / Charge / Water | Retain reviewed v2 calm measured steadiness, distinct from Fluup's more openly reassuring expression. |
| H. Lenee / `h_le_ne` | Stoneborn / M / DJ | Earth, Air, Fire | Earth / Air / Fire | Revise: determined concentration, firm mouth and focused brows; preserve female identity, stone pattern and exact braids. |
| Mifu / `fimu_yashiha` | Treefolk / S / DJ | Water, Air, Light | Water / Air / Light | Retain gentle interested warmth; leaf silhouette and wooden face already provide variety, avoiding unnecessary rewrites. |
| Sai Laas / `sai_laas` | Nymph / S / DJ | Air 2, Fire 1 | Air / Fire / Water | Revise: mischievous delight and lively cheeks; preserve existing unspecified gender presentation, hair and leaf clothing. |

## Edit and acceptance contract

The bounded batch is S. Wayne, Grace Riva, Wa Bidi, Steezo, Treevor, Fluup, Spai Si, Haara, Juul I Yaina, H. Lenee and Sai Laas. The other nineteen are deliberately retained for the reasons above. Joh/Grimm retain their earlier v2 refinements; this does not count them as new edits in this batch.

Change expression through brows, eyelids, mouth, cheeks and only a modest necessary head-angle adjustment. Do not replace face anatomy to manufacture variety. Preserve age and adult presentation; keep Wa Bidi female, Spai/Juul male, H. Lenee/Mifu female, Faab a bald male Angel, and Sai Laas gender unspecified. No race, skin, gender, costume, palette or gameplay changes. No props, weapons, magical effects, text or invented storytelling accessories.

The four Treevor/Fluup/Spai/Juul edits have their full prompts, input paths, generated original paths, hashes and review limits in [personality-momentum-prompts.json](../reference/art/portraits_20261008/personality-momentum-prompts.json). Other batch owners retain their own actual generation provenance. An agent's image review is not human identity/style acceptance, native Gallery acceptance, animation acceptance, or packaged-release verification. The root integration task alone updates production portraits, manifest and browser selection after candidate review.

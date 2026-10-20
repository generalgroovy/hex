# H.E.X. source analysis and asset provenance

Inspected 2026-10-15 in `C:\Users\sende\Projects\hex`. This standalone spinoff reuses the user's H.E.X. setting, named identities and original portrait assets. Source repository files were read and copied; no H.E.X. source files, art originals, packages or working builds were changed. No Godot session was run for this analysis. No `AGENTS.md` was found in the source tree or its checked parent directories.

## Authority read

- `SPECIFICATION.md`: current implemented gameplay contract, separate from the October 15 overhaul proposal.
- `.agent/HEX-RESUME.md` and `.agent/OVERHAUL-IMPLEMENTATION.md`: preserve current and fallback builds and distinguish implementation from acceptance.
- `docs/CORE-GAME-DESIGN.md`, `docs/CURRENT-CAST.md`, `docs/PLAYER-GUIDE.md`: current rules, exact roster and player-facing vocabulary.
- `content/champions/foundation_champions_v1.json`: live IDs, names, ancestry, size, affinities and playstyle text.
- `content/maps/sanctum_campus_g2_v1.json`: current seven-district campus.
- `content/reactions/six_element_reactions_v2.json`: current reaction identities, effects and counters.
- `assets/portraits/champions_v1/manifest.json`: portrait selection and source digests.
- `reference/art/portraits_20261008/personality-integration.json` and `docs/CHARACTER-PERSONALITY.md`: expression provenance and identity-preservation notes. The latter is older and still contains superseded Ice/Charge roster entries; the current roster and live catalog take precedence.

## What transfers from H.E.X.

H.E.X. is Help, Everything eXploded!, an elemental combat sandbox set in Wellspring. Its current cast has 30 named playable champions and 21 ancestries. The six fundamental ingredients are Water, Fire, Air, Earth, Light and Dark. The internal ID for Air is `wind`. Ice and Charge are derived effects, not additional selectable ingredients. The original game makes terrain interaction, route choice, finite resources and counterplay central to chemistry.

The original supports 63 bounded reactions and 504 spell definitions. Those counts are source context, not features claimed for Confluence. This spinoff translates the vocabulary into a smaller turn-based ruleset. Its scoring wells, squad composition, turn actions, roles, damage, movement ranges, reactions and victory conditions are newly designed adaptations; they are not claims about H.E.X.'s existing executable rules or canonical biographies. Original H.E.X. champions can configure all six elements; assigning a clear elemental role here does not retroactively restrict them.

## Selected six

| Exact name | Stable ID and original PNG filename | Canonical identity | Current affinities | Identity and expression cues |
|---|---|---|---|---|
| Oh Tipi | `oh_tipi` / `oh_tipi.png` | Seakin, Middle | Water 2, Fire 1 | Warm composure; steady current keeper with deliberate footwork |
| Wa Bidi | `wa_bidi` / `wa_bidi.png` | Female Goblin, Small | Fire 2, Air 1 | Spirited engagement and lively eyes; quick pressure skirmisher |
| Grace Riva | `grace_reava` / `grace_reava.png` | Sylph, Small | Air 1, Water 1, Light 1 | Open curiosity; nimble stream dancer; original game allows finite paid flight |
| Treevor the Mason | `treevor_mason` / `treevor_mason.png` | Treefolk, Large | Earth 1, Air 1, Fire 1 | Tired but steadfast, kindly eyes; large-body anchor |
| Haara | `haara` / `haara.png` | Nymph, Small | Light 2, Air 1 | Stern vigilance and direct gaze; focused light-pressure skirmisher |
| S. Wayne | `s_wayne` / `s_wayne.png` | Hobbit, Small | Dark 2, Light 1 | Quiet watchful resolve; preserve rich dark-brown skin; swift boundary tactician |

Light does not establish a canonical healer, Dark does not establish evil or invisibility, and names do not grant extra abilities. Portrait expression notes are art direction, not biography or mechanics.

Additional readily reusable identities include The Red Baron (`red_baron`, Undead, Large, Fire 2 / Water 1), Grimm Bow (`grimm_bow`, Troll, Large, Earth 2 / Water 1), Mifu (`fimu_yashiha`, female Treefolk, Small, Water / Air / Light), and Sai Laas (`sai_laas`, Nymph, Small, Air 2 / Fire 1; gender unspecified).

## Wellspring places

The current live campus has these seven districts, rather than the nine entries retained in older `wellspring_hub_v2.json` visual metadata:

| District | Source purpose and useful motif |
|---|---|
| Conservatory Gardens | Movement and recovery; garden routes, practice walls and recovery grove |
| Nexus Commons / Wellspring Academy | Central academy, living archive and observatory traditions; Spell Loom, Farflow Hall and Crucible services |
| Wayfarer Proving Quarter | Pattern practice and duels; useful framing for friendly tactical contests |
| Tideglass Quays | Coast and spell waterworks; long waterfront approaches and jetty walls; Element Garden |
| Verdant Reaches | Grove, long open paths and quiet return routes |
| Basalt Foundry | Tight stone corners, solid cover and broken sightlines |
| Starward Terraces | Observatory, broad approaches, elevated terraces and clear retreat routes |

The live map offers 13 named destinations. Wellspring, Academy, Movement Garden, Farflow Hall, Pattern Range, Duel Court, Crucible and Recovery Grove are established player-facing locations. No source-grounded political factions, wars, historical catastrophe or antagonist biography were found in the inspected authority. A practice contest around shared elemental wells fits the setting without inventing a campaign history.

## Source chemistry worth adapting

The original prioritizes map interaction before damage multipliers. Every effect has finite area, lifetime and work limits, visible formation, active and decay phases, and a counter.

| Source ingredients | Exact reaction name | Original tactical idea |
|---|---|---|
| Fire + Water | Steam | Capped scald pressure; leave or cool it with a fresh Water cast |
| Earth + Earth | Rampart | Breakable temporary pillar that cuts a firing lane |
| Earth + Fire | Magma | Ground damage and route denial |
| Earth + Water | Quagmire | Impaired ground acceleration/braking and delayed attrition |
| Earth + Air | Sandblast | One hit and bounded sideways displacement |
| Water + Water | Frostway | Freezing hit and slower ground/projectile travel |
| Fire + Air | Arcstorm | Warned electrical line burst |
| Light + Dark | Penumbra | Dangerous boundary with a safe interior |
| Fire + Light | Solar Flare | One radial damage-and-reveal flash |
| Water + Light | Mirrorwater | Movement-sensitive reveal and damage pulses |

A compact turn-based adaptation should expose the outcome before commitment, make spatial control and displacement compete with direct attacks, and give each strong reaction a readable response. These are design recommendations, not inherited numeric balance.

## Portrait assets and browser derivatives

All six source PNGs were copied byte-for-byte from `C:\Users\sende\Projects\hex\assets\portraits\champions_v1`. Those preserved copies now live in `work/portrait-originals`, which is excluded by the project's `/work/` Git ignore rule. The H.E.X. source files remain unchanged. These originals are 1254 × 1254 PNGs, totaling 14,188,859 bytes; the source manifest's 512 × 512 fields describe the bounded Godot import.

The browser uses separate 512 × 512 WebP derivatives in `public/portraits`, encoded at quality 85. This operation only resized and encoded the existing images: no generation, repainting, cropping, composition changes or character redesign. The six runtime files total **434,136 bytes**, about **434 KB** combined, a roughly 96.9% byte reduction from the original PNGs. Dimensions, byte sizes and hashes below were read from the actual derivative files. This is asset-transfer reduction, not a measured page-load or frame-rate claim.

Preserved original PNG copies in `work/portrait-originals`:

| File | Bytes | SHA-256 |
|---|---:|---|
| `oh_tipi.png` | 2347943 | `16fa22c07c13b689b9b7880512e9306113f45fbb2aa0d09fed127cc0e2c275cc` |
| `wa_bidi.png` | 2255662 | `37a384efefd7662e444e8356209187ffbd1b07d3776532c0ae8eccf0739ee0d6` |
| `grace_reava.png` | 2382200 | `ef253152fac3d348321da6be2069a6dd5d23ea1093ad13042edd7ba9d1413ed5` |
| `treevor_mason.png` | 2462394 | `b6bababea0ede788b8708b9161f19c64e168e6d4a7eabcaa148553dc17c77901` |
| `haara.png` | 2474433 | `531decace7cf05314162cfce98ffeef5b115f8243fb5cccf795a2fd85d52e262` |
| `s_wayne.png` | 2266227 | `a5d5e453b56d49bdab150fd6fb7931c11c053b75119a7eb9bec1f84708cee84b` |

Browser derivatives in `public/portraits` (all 512 × 512):

| File | Bytes | SHA-256 |
|---|---:|---|
| `oh_tipi.webp` | 63976 | `cda9cf7661b845511ea8702c717d690b0f234dfcc3f2cca00b4c2d7fdb1603f4` |
| `wa_bidi.webp` | 62464 | `fa1262409dfc7889411824596ba12f26ded8b91b89c3ef6dea004c65a13834d9` |
| `grace_reava.webp` | 84184 | `d894538d953888a31a3b66d734b51e187ede1717efdfb5d17fd7be4ef9de2c7a` |
| `treevor_mason.webp` | 79376 | `0b9491f7399d9d6e4a3ee5427dc5216a75a8fb25d96676551ac4e7982689af6a` |
| `haara.webp` | 85690 | `94e910edc7559691a64e8c868c60d941bcf55b960e1d85d13c08731c597dd1ab` |
| `s_wayne.webp` | 58446 | `b04c00801e5410205a54769935090971ff685580182f934420d07fb7b0c59fed` |

Oh Tipi uses the retained original; the other five select reviewed v2 expression refinements. Source full-resolution versions, original prompts and generation provenance remain in `reference/art/portraits_20261008`. That package identifies eleven identity-preserving built-in image-generation edits and retains the originals. This local reuse does not assert external licensing or completed human visual acceptance.

For future full-body tokens, existing source banks are `assets/sprites/pixel_cast_v1/<id>.png` and `assets/sprites/pixel_actions_v1/<id>.png`, each with a manifest; their 128px cells use foot pivot `(64,104)`. These are bounded ground/cast or action-key sheets, not complete authored animation sets. They have not been copied into this spinoff.

## V3 presentation and writing — 2026-10-16

The simultaneous version keeps the six canonical names, IDs, ancestry labels and portrait derivatives above. Its battlefield figures are newly authored SVG shapes in `app/components/IsometricBoard.tsx`, with costumes, silhouettes, skin tones and expression cues informed by those portraits. They are not extracted Godot sprite sheets, new source-game assets or evidence of human visual acceptance. Movement, spell and reaction animation is browser presentation around the deterministic Confluence result.

The labels Tidecall, Sparkshot, Crosswind, Stonework, Daybreak and Nightfall, and the short first-person character remarks in `app/SimGame.tsx`, are new Confluence writing. They are not quotations from source lore and do not establish biography, canonical spell names, gender, affiliations or events. The earlier identity table remains the source-grounded authority; a tactical Light healing action does not change Haara's established identity into a healer biography, and Dark does not imply evil or invisibility.

V3 reuses the source reaction names Steam, Magma, Quagmire and Penumbra while assigning explicit simultaneous-game effects: combined damage reduction, end-of-exchange burn, movement effort and well scoring. Ingredient accumulation, shared simultaneous reactions, raised hexes, sealed three-champion plans, Guard, friendly fire, respawn timing and victory scoring are Confluence adaptations. The real-time H.E.X. reaction catalog and mechanics remain separate. Existing v1/v2 Confluence matches also retain their own rules through the Classic interface.

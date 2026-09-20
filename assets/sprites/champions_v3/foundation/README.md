# Foundation eight-direction body atlas provenance

This directory contains the active body-and-clothing-only production candidate
for Oh Tipi, S. Wayne and The Red Baron. Every grounded, empty-hand cast, hit/recovery, jump,
slide, and roll state has dedicated `S/SE/E/NE/N/NW/W/SW` art. Walk and sprint
also have two opposite contact frames in all eight directions, selected on the
editable presentation motion profile's half-cycle. Spells,
elements, auras, projectiles, shadows, environments, tools, and equipment remain
independent runtime layers, so a pose or spell can be replaced without redrawing
the other.

The active runtime is `runtime_atlas_eight_v12.png`: 768×2880 RGBA, 96×96
cells, eight fixed direction columns, ten state/contact rows per champion and
pivot `(48,84)`. The three reusable body templates are rebuilt in strict
smallest-to-largest order: S. Wayne (`small`), Oh Tipi (`middle`), then The Red
Baron (`large`). It is built in two deterministic stages:

```powershell
python scripts/build_cardinal_champion_atlas.py assets/sprites/champions_v3/foundation/source_cardinal_oh_tipi_v4.png assets/sprites/champions_v3/foundation/source_cardinal_s_wayne_v4.png assets/sprites/champions_v3/foundation/runtime_atlas_eight_v8.png --oh-tipi-movement assets/sprites/champions_v3/foundation/source_movement_oh_tipi_v5.png --s-wayne-movement assets/sprites/champions_v3/foundation/source_movement_s_wayne_v5.png --oh-tipi-diagonal-core assets/sprites/champions_v3/foundation/source_diagonal_core_oh_tipi_v6.png --s-wayne-diagonal-core assets/sprites/champions_v3/foundation/source_diagonal_core_s_wayne_v6.png --oh-tipi-diagonal-locomotion assets/sprites/champions_v3/foundation/source_diagonal_locomotion_oh_tipi_v7.png --s-wayne-diagonal-locomotion assets/sprites/champions_v3/foundation/source_diagonal_locomotion_s_wayne_v7.png --oh-tipi-locomotion-phase-b assets/sprites/champions_v3/foundation/source_cardinal_locomotion_phase_b_oh_tipi_v8.png --s-wayne-locomotion-phase-b assets/sprites/champions_v3/foundation/source_cardinal_locomotion_phase_b_s_wayne_v8.png --oh-tipi-diagonal-actions assets/sprites/champions_v3/foundation/source_diagonal_actions_oh_tipi_v8.png --s-wayne-diagonal-actions assets/sprites/champions_v3/foundation/source_diagonal_actions_s_wayne_v8.png
python scripts/build_red_baron_foundation_atlas.py assets/sprites/champions_v3/foundation/runtime_atlas_eight_v8.png assets/concept/red-baron-eight-direction-source-v1.png assets/sprites/champions_v3/foundation/runtime_atlas_eight_v12.png
```

The second stage adds The Red Baron from his authored source poses, removes
legacy direction/source-sheet scale drift, applies a bounded source-time
anatomy pass in `small`, `middle`, `large` order, preserves 58/68/76 px authored
upright heights and runtime scale `1.00`, then derives one
restrained exterior ink from the darkest visible Red Baron material clusters.
The proportion pass reduces head dominance on upright S. Wayne and Oh Tipi
poses without changing total pose height, cell or feet alignment; slide and
roll keep their authored tucked silhouettes. The one-pixel ink pass is bounded
to each cell and cannot recolor, merge or bleed silhouettes.
Current file SHA-256 is
`640abbf46c2442506e12a31542c9a0ad375d32f53062e433d0787b88e920bd38`;
Godot-decoded RGBA SHA-256 is
`75eb623c9ee8ed4559bc8d1edf481d12d87470501c003b83dd279c40abd53c89`.

## Reproducible layout

| Asset | Contract |
|---|---|
| `source_cardinal_oh_tipi_v4.png` | 1254×1254 matte source; 4 directions × 4 states |
| `source_cardinal_s_wayne_v4.png` | 1254×1254 matte source; 4 directions × 4 states |
| `source_movement_oh_tipi_v5.png` | 1254×1254 matte source; walk/sprint/slide/roll × 4 directions |
| `source_movement_s_wayne_v5.png` | 1254×1254 matte source; walk/sprint/slide/roll × 4 directions |
| `source_diagonal_core_oh_tipi_v6.png` | 1254×1254 matte source; SE/NE/NW/SW × grounded/cast/hit |
| `source_diagonal_core_s_wayne_v6.png` | 1254×1254 matte source; SE/NE/NW/SW × grounded/cast/hit |
| `source_diagonal_locomotion_oh_tipi_v7.png` | generated 4×2 matte source; SE/NE/NW/SW × walk/sprint |
| `source_diagonal_locomotion_s_wayne_v7.png` | generated 4×2 matte source; SE/NE/NW/SW × walk/sprint |
| `source_cardinal_locomotion_phase_b_oh_tipi_v8.png` | generated 4×2 matte source; S/E/N/W × opposite walk/sprint contact |
| `source_cardinal_locomotion_phase_b_s_wayne_v8.png` | generated 4×2 matte source; S/E/N/W × opposite walk/sprint contact |
| `source_diagonal_actions_oh_tipi_v8.png` | generated 4×5 matte source; SE/NE/NW/SW × opposite walk/sprint, jump, slide, roll |
| `source_diagonal_actions_s_wayne_v8.png` | generated 4×5 matte source; SE/NE/NW/SW × opposite walk/sprint, jump, slide, roll |
| `runtime_atlas_eight_v8.png` | 768×1920 RGBA; 96×96 cells; pivot `(48,84)` |
| Columns | south/front, south-east, east, north-east, north/back, north-west, west, south-west |
| Rows per champion | grounded, jump, empty-hand cast, hit/recovery, walk A, sprint A, slide, roll, walk B, sprint B |
| Atlas row layout | champion-major, state-minor: all Oh Tipi rows, then all S. Wayne rows |

Rebuild deterministically from repository root:

```powershell
python scripts/build_cardinal_champion_atlas.py assets/sprites/champions_v3/foundation/source_cardinal_oh_tipi_v4.png assets/sprites/champions_v3/foundation/source_cardinal_s_wayne_v4.png assets/sprites/champions_v3/foundation/runtime_atlas_eight_v8.png --oh-tipi-movement assets/sprites/champions_v3/foundation/source_movement_oh_tipi_v5.png --s-wayne-movement assets/sprites/champions_v3/foundation/source_movement_s_wayne_v5.png --oh-tipi-diagonal-core assets/sprites/champions_v3/foundation/source_diagonal_core_oh_tipi_v6.png --s-wayne-diagonal-core assets/sprites/champions_v3/foundation/source_diagonal_core_s_wayne_v6.png --oh-tipi-diagonal-locomotion assets/sprites/champions_v3/foundation/source_diagonal_locomotion_oh_tipi_v7.png --s-wayne-diagonal-locomotion assets/sprites/champions_v3/foundation/source_diagonal_locomotion_s_wayne_v7.png --oh-tipi-locomotion-phase-b assets/sprites/champions_v3/foundation/source_cardinal_locomotion_phase_b_oh_tipi_v8.png --s-wayne-locomotion-phase-b assets/sprites/champions_v3/foundation/source_cardinal_locomotion_phase_b_s_wayne_v8.png --oh-tipi-diagonal-actions assets/sprites/champions_v3/foundation/source_diagonal_actions_oh_tipi_v8.png --s-wayne-diagonal-actions assets/sprites/champions_v3/foundation/source_diagonal_actions_s_wayne_v8.png
```

The builder uses proportional source-cell boundaries because the generated
1254px canvas is not divisible by four. It removes only edge-connected magenta,
uses one bounded scale per champion, aligns every cell to the shared feet pivot,
packs the versioned atlas, and fails if any required source cell is empty.
Source sheets are normalized by their four-column cell width before the shared
champion scale is calculated, so generated sheets with different canvas sizes
cannot silently resize one action family.
Exact source, PNG, and Godot-imported RGBA hashes
are pinned in `provenance.json`.

## Exact ImageGen prompts

Oh Tipi:

```text
Use case: precise-object-edit
Asset type: production-candidate body-only source sheet for a 2D top-down cartoon pixel-action game
Input image: Image 1 is the identity, clothing, proportion, palette, and pixel-treatment reference. Use only the blue seakin champion Oh Tipi from the top row.
Primary request: Create a clean 4 by 4 equal-cell sprite source sheet of Oh Tipi with exactly sixteen isolated full-body poses.
Grid contract: columns from left to right are SOUTH/front camera-facing, EAST/right profile, NORTH/centered back, WEST/left profile. Rows from top to bottom are IDLE, JUMP, EMPTY-HAND CAST PREPARATION, HIT/RECOVERY. Keep every figure centered in its cell with the same feet baseline, scale, outline weight, outfit, face, fin crown, cheek fins, tail, and compact proportions. South is balanced and symmetrical; north is a true centered back; east and west are readable opposing profiles. Jump, cast, and hit silhouettes must remain visibly distinct in every direction.
Scene/backdrop: one flat opaque vivid magenta matte across the entire canvas; generous clear space between cells.
Style/medium: original charming compact cartoon pixel art, crisp 1-2 pixel outlines at intended gameplay scale, readable top-down cardinal facing, no smooth painted rendering.
Constraints: champion pixels contain body and clothing only; all hands empty; no text or labels; no cell borders; no shadows; no magic; no elemental effects; no aura; no projectiles; no particles; no weapons; no staff, wand, rod, scepter, trident, focus, equipment, props, or environment. Preserve the non-sexualized compact body design. Do not add or remove limbs, fins, tail, clothing, or ancestry features. Keep exactly one Oh Tipi in each of sixteen cells and no other character.
Avoid: cropped figures, overlapping cells, inconsistent identity or scale, three-quarter/diagonal poses, isometric perspective, duplicated direction, spell pixels, detached objects, extra characters, logos, watermark.
```

S. Wayne:

```text
Use case: precise-object-edit
Asset type: production-candidate body-only source sheet for a 2D top-down cartoon pixel-action game
Input image: Image 1 is the identity, clothing, proportion, palette, and pixel-treatment reference. Use only the small hobbit champion S. Wayne from the bottom row.
Primary request: Create a clean 4 by 4 equal-cell sprite source sheet of S. Wayne with exactly sixteen isolated full-body poses.
Grid contract: columns from left to right are SOUTH/front camera-facing, EAST/right profile, NORTH/centered back, WEST/left profile. Rows from top to bottom are IDLE, JUMP, EMPTY-HAND CAST PREPARATION, HIT/RECOVERY. Keep every figure centered in its cell with the same feet baseline, scale, outline weight, face, round dark hair, purple-and-gold short cloak, large bare hobbit feet, and compact proportions. South is balanced and symmetrical; north is a true centered back; east and west are readable opposing profiles. Jump, cast, and hit silhouettes must remain visibly distinct in every direction.
Scene/backdrop: one flat opaque vivid magenta matte across the entire canvas; generous clear space between cells.
Style/medium: original charming compact cartoon pixel art, crisp 1-2 pixel outlines at intended gameplay scale, readable top-down cardinal facing, no smooth painted rendering.
Constraints: champion pixels contain body and clothing only; all hands empty; no text or labels; no cell borders; no shadows; no magic; no elemental effects; no aura; no projectiles; no particles; no weapons; no staff, wand, rod, scepter, focus, equipment, props, or environment. Preserve the non-sexualized compact body design. Do not add or remove limbs, hair, clothing, or ancestry features. Keep exactly one S. Wayne in each of sixteen cells and no other character.
Avoid: cropped figures, overlapping cells, inconsistent identity or scale, three-quarter/diagonal poses, isometric perspective, duplicated direction, spell pixels, detached objects, extra characters, logos, watermark.
```

Oh Tipi movement/evasion:

```text
Use case: precise-object-edit
Asset type: production-candidate body-only locomotion source sheet for an original 2D top-down cartoon pixel-action game
Input image: Image 1 is the exact identity, clothing, proportions, palette, outline, and pixel-treatment reference for the blue seakin champion Oh Tipi.
Primary request: Create a clean 4 by 4 equal-cell sprite source sheet of Oh Tipi with exactly sixteen isolated full-body movement/evasion poses.
Grid contract: columns from left to right are SOUTH/front camera-facing, EAST/right profile, NORTH/centered back, WEST/left profile. Rows from top to bottom are WALK CONTACT, SPRINT DRIVE, LOW SLIDE, TUCKED ROLL. Maintain one consistent champion scale, feet baseline, outline weight, outfit, face, fin crown, cheek fins, tail, and compact proportions across the sheet. WALK shows a clear planted step with opposing arm/leg cadence; SPRINT has a stronger controlled directional lean and drive; SLIDE is low, elongated, and immediately distinct from running; ROLL is a compact tucked invulnerability silhouette. South stays balanced and camera-facing, north is a true centered back, east and west are opposing profiles.
Scene/backdrop: one flat opaque vivid magenta matte across the entire canvas; generous clear space between cells.
Style/medium: original charming compact cartoon pixel art, crisp 1-2 pixel outlines at intended gameplay scale, readable top-down cardinal facing, economical action silhouettes, no smooth painted rendering.
Constraints: champion pixels contain body and clothing only; all hands empty; no text or labels; no cell borders; no shadows; no magic; no elemental effects; no aura; no speed lines; no dust; no projectiles; no particles; no weapons; no staff, wand, rod, scepter, trident, focus, equipment, props, or environment. Preserve the non-sexualized compact body design. Do not add or remove limbs, fins, tail, clothing, or ancestry features. Keep exactly one Oh Tipi in each of sixteen cells and no other character.
Avoid: cropped figures, overlapping cells, inconsistent identity or scale, three-quarter/diagonal poses, isometric perspective, duplicated direction, spell pixels, detached objects, motion-effect pixels, extra characters, logos, watermark.
```

S. Wayne movement/evasion:

```text
Use case: precise-object-edit
Asset type: production-candidate body-only locomotion source sheet for an original 2D top-down cartoon pixel-action game
Input image: Image 1 is the exact identity, clothing, proportions, palette, outline, and pixel-treatment reference for the small hobbit champion S. Wayne.
Primary request: Create a clean 4 by 4 equal-cell sprite source sheet of S. Wayne with exactly sixteen isolated full-body movement/evasion poses.
Grid contract: columns from left to right are SOUTH/front camera-facing, EAST/right profile, NORTH/centered back, WEST/left profile. Rows from top to bottom are WALK CONTACT, SPRINT DRIVE, LOW SLIDE, TUCKED ROLL. Maintain one consistent champion scale, feet baseline, outline weight, face, round dark hair, purple-and-gold short cloak, large bare hobbit feet, and compact proportions across the sheet. WALK shows a clear planted step with opposing arm/leg cadence; SPRINT has a stronger controlled directional lean and drive; SLIDE is low, elongated, and immediately distinct from running; ROLL is a compact tucked invulnerability silhouette. South stays balanced and camera-facing, north is a true centered back, east and west are opposing profiles.
Scene/backdrop: one flat opaque vivid magenta matte across the entire canvas; generous clear space between cells.
Style/medium: original charming compact cartoon pixel art, crisp 1-2 pixel outlines at intended gameplay scale, readable top-down cardinal facing, economical action silhouettes, no smooth painted rendering.
Constraints: champion pixels contain body and clothing only; all hands empty; no text or labels; no cell borders; no shadows; no magic; no elemental effects; no aura; no speed lines; no dust; no projectiles; no particles; no weapons; no staff, wand, rod, scepter, focus, equipment, props, or environment. Preserve the non-sexualized compact body design. Do not add or remove limbs, hair, clothing, large bare feet, or ancestry features. Keep exactly one S. Wayne in each of sixteen cells and no other character.
Avoid: cropped figures, overlapping cells, inconsistent identity or scale, three-quarter/diagonal poses, isometric perspective, duplicated direction, spell pixels, detached objects, motion-effect pixels, extra characters, logos, watermark.
```

Oh Tipi diagonal core:

```text
Use case: precise-object-edit
Asset type: production-candidate body-only diagonal source sheet for an original 2D top-down cartoon pixel-action game
Input images: Image 1 is the exact identity, outfit, proportions, palette, outline, and pixel-treatment reference for the blue seakin champion Oh Tipi.
Primary request: Create a NEW clean 4-column by 3-row equal-cell sprite source sheet containing exactly twelve isolated full-body poses of the same Oh Tipi.
Grid contract: columns left to right are SOUTH-EAST/front-right three-quarter facing, NORTH-EAST/back-right three-quarter facing, NORTH-WEST/back-left three-quarter facing, SOUTH-WEST/front-left three-quarter facing. Rows top to bottom are GROUNDED/IDLE, EMPTY-HAND CAST PREPARATION, HIT/RECOVERY. Each diagonal must sit exactly halfway between the matching cardinal views from Image 1, clearly distinct from front/profile/back. Keep one consistent scale, centered feet baseline, outline weight, face, fin crown, cheek fins, tail, black-and-gold clothing, and compact non-sexualized proportions. Cast uses expressive empty hands; hit/recovery has a readable recoil silhouette.
Scene/backdrop: one flat opaque vivid magenta matte across the entire canvas, with generous clear space between equal cells.
Style/medium: original charming compact cartoon pixel art matching Image 1; crisp economical pixel clusters and gameplay-readable silhouette; no smooth painted rendering.
Constraints: body and clothing pixels only; exactly one Oh Tipi per cell; no text, labels, borders, shadows, magic, elements, auras, projectiles, particles, speed lines, weapons, staff, wand, trident, equipment, props, or environment. Preserve identity and anatomy. No cropped figures or overlaps.
Avoid: cardinal-only poses, duplicated columns, isometric view, spell pixels, detached objects, extra characters, logos, watermark.
```

S. Wayne diagonal core:

```text
Use case: precise-object-edit
Asset type: production-candidate body-only diagonal source sheet for an original 2D top-down cartoon pixel-action game
Input images: Image 1 is the exact identity, outfit, proportions, palette, outline, and pixel-treatment reference for the small hobbit champion S. Wayne.
Primary request: Create a NEW clean 4-column by 3-row equal-cell sprite source sheet containing exactly twelve isolated full-body poses of the same S. Wayne.
Grid contract: columns left to right are SOUTH-EAST/front-right three-quarter facing, NORTH-EAST/back-right three-quarter facing, NORTH-WEST/back-left three-quarter facing, SOUTH-WEST/front-left three-quarter facing. Rows top to bottom are GROUNDED/IDLE, EMPTY-HAND CAST PREPARATION, HIT/RECOVERY. Each diagonal must sit exactly halfway between the matching cardinal views from Image 1, clearly distinct from front/profile/back. Keep one consistent scale, centered feet baseline, outline weight, face, round dark hair, purple-and-gold short cloak, large bare hobbit feet, warm skin tone, and compact non-sexualized proportions. Cast uses expressive empty hands; hit/recovery has a readable recoil silhouette.
Scene/backdrop: one flat opaque vivid magenta matte across the entire canvas, with generous clear space between equal cells.
Style/medium: original charming compact cartoon pixel art matching Image 1; crisp economical pixel clusters and gameplay-readable silhouette; no smooth painted rendering.
Constraints: body and clothing pixels only; exactly one S. Wayne per cell; no text, labels, borders, shadows, magic, elements, auras, projectiles, particles, speed lines, weapons, staff, wand, focus, equipment, props, or environment. Preserve identity and anatomy. No cropped figures or overlaps.
Avoid: cardinal-only poses, duplicated columns, isometric view, spell pixels, detached objects, extra characters, logos, watermark.
```

Diagonal locomotion sheets:

```text
Use case: precise-object-edit
Asset type: production-candidate body-only diagonal locomotion source sheet for an original 2D top-down cartoon pixel-action game
Input images: Use the champion's repository-owned cardinal walk/sprint sheet as the exact action identity and the diagonal-core sheet as the exact three-quarter facing reference.
Primary request: Create a NEW clean 4-column by 2-row equal-cell sprite source sheet containing exactly eight isolated full-body poses of the same champion.
Grid contract: columns left to right are SOUTH-EAST/front-right three-quarter, NORTH-EAST/back-right three-quarter, NORTH-WEST/back-left three-quarter, SOUTH-WEST/front-left three-quarter. Rows top to bottom are WALK CONTACT and SPRINT DRIVE. Walk has a natural planted step with opposing arm/leg cadence; sprint has stronger controlled drive and lean. Keep one consistent scale, feet baseline, outfit, face, ancestry features, compact non-sexualized proportions, and empty hands.
Scene/backdrop: one flat opaque vivid magenta matte across the entire canvas, with generous clear space between equal cells.
Style/medium: original charming compact cartoon pixel art matching the repository-owned champion sources; crisp economical pixel clusters and gameplay-readable silhouettes.
Constraints: body and clothing pixels only; exactly one champion per cell; no text, labels, borders, shadows, magic, elements, auras, projectiles, particles, dust, speed lines, weapons, staff, wand, focus, equipment, props, or environment. No cropped figures or overlaps.
Avoid: cardinal-only poses, duplicated columns, idle poses, sliding or rolling, isometric view, spell pixels, detached objects, extra characters, logos, watermark.
```

The exact ImageGen prompts used for the v7 files were:

Oh Tipi:

```text
Use case: precise-object-edit
Asset type: production-candidate body-only diagonal locomotion source sheet for an original 2D top-down cartoon pixel-action game
Input images: Image 1 is the exact cardinal walk/sprint identity, outfit, proportions, palette, outline, and movement-energy reference for the blue seakin champion Oh Tipi. Image 2 is the exact three-quarter diagonal facing and current identity reference.
Primary request: Create a NEW clean 4-column by 2-row equal-cell sprite source sheet containing exactly eight isolated full-body poses of the same Oh Tipi.
Grid contract: columns left to right are SOUTH-EAST/front-right three-quarter facing, NORTH-EAST/back-right three-quarter facing, NORTH-WEST/back-left three-quarter facing, SOUTH-WEST/front-left three-quarter facing. Rows top to bottom are WALK CONTACT and SPRINT DRIVE. Every diagonal must sit exactly halfway between matching cardinal views and agree with Image 2. WALK shows a natural planted step with opposing arm/leg cadence. SPRINT shows a stronger controlled directional drive and lean while preserving a stable feet baseline and instantly readable silhouette. Keep one consistent scale, centered feet pivot, outline weight, face, fin crown, cheek fins, curling tail, black-and-gold clothing, and compact non-sexualized proportions.
Scene/backdrop: one flat opaque vivid magenta matte across the entire canvas, with generous clear space between equal cells.
Style/medium: original charming compact cartoon pixel art matching the inputs; crisp economical pixel clusters at gameplay scale; no smooth painted rendering.
Constraints: body and clothing pixels only; exactly one Oh Tipi per cell; empty hands; no text, labels, borders, shadows, magic, elements, auras, projectiles, particles, dust, speed lines, weapons, staff, wand, trident, equipment, props, or environment. Preserve identity and anatomy. No cropped figures or overlaps.
Avoid: cardinal-only poses, duplicated columns, idle poses, sliding or rolling, isometric view, spell pixels, detached objects, extra characters, logos, watermark.
```

S. Wayne:

```text
Use case: precise-object-edit
Asset type: production-candidate body-only diagonal locomotion source sheet for an original 2D top-down cartoon pixel-action game
Input images: Image 1 is the exact cardinal walk/sprint identity, outfit, proportions, palette, outline, and movement-energy reference for the small hobbit champion S. Wayne. Image 2 is the exact three-quarter diagonal facing and current identity reference.
Primary request: Create a NEW clean 4-column by 2-row equal-cell sprite source sheet containing exactly eight isolated full-body poses of the same S. Wayne.
Grid contract: columns left to right are SOUTH-EAST/front-right three-quarter facing, NORTH-EAST/back-right three-quarter facing, NORTH-WEST/back-left three-quarter facing, SOUTH-WEST/front-left three-quarter facing. Rows top to bottom are WALK CONTACT and SPRINT DRIVE. Every diagonal must sit exactly halfway between matching cardinal views and agree with Image 2. WALK shows a natural planted step with opposing arm/leg cadence. SPRINT shows a stronger controlled directional drive and lean while preserving a stable feet baseline and instantly readable silhouette. Keep one consistent scale, centered feet pivot, outline weight, face, round dark hair, purple-and-gold short cloak, warm skin tone, large bare hobbit feet, and compact non-sexualized proportions.
Scene/backdrop: one flat opaque vivid magenta matte across the entire canvas, with generous clear space between equal cells.
Style/medium: original charming compact cartoon pixel art matching the inputs; crisp economical pixel clusters at gameplay scale; no smooth painted rendering.
Constraints: body and clothing pixels only; exactly one S. Wayne per cell; empty hands; no text, labels, borders, shadows, magic, elements, auras, projectiles, particles, dust, speed lines, weapons, staff, wand, focus, equipment, props, or environment. Preserve identity and anatomy. No cropped figures or overlaps.
Avoid: cardinal-only poses, duplicated columns, idle poses, sliding or rolling, isometric view, spell pixels, detached objects, extra characters, logos, watermark.
```

## Exact ImageGen prompts for v8

The cardinal phase-B prompt was run once per champion. The Oh Tipi version was:

```text
Use case: precise-object-edit
Asset type: versioned production-candidate body-only locomotion phase sheet for the FLUX 2D top-down pixel action game
Input images: Image 1 is the exact Oh Tipi walk/sprint identity, outfit, proportions, palette and first-contact reference; Image 2 is the exact cardinal facing reference.
Primary request: Create a NEW clean 4-column by 2-row equal-cell sprite source sheet containing exactly eight isolated full-body poses of the same Oh Tipi. This is the opposite gait contact phase, not a copy of Image 1.
Grid contract: columns left to right SOUTH/front, EAST/right profile, NORTH/back, WEST/left profile. Rows top to bottom WALK OPPOSITE CONTACT and SPRINT OPPOSITE DRIVE. In every cell swap the planted and passing legs compared with Image 1 and counter-swing the arms naturally; sprint has stronger lean and stride. Preserve facing, stable feet baseline, centered feet pivot, scale, fin crown, cheek fins, tail, dark navy armor with aged-gold trim, cyan skin, compact non-sexualized proportions and crisp outline.
Scene/backdrop: one flat opaque vivid magenta matte over the entire canvas with generous separation between equal cells.
Style/medium: original charming compact cartoon pixel art matching the input; economical pixel clusters readable around 60 pixels tall; no smooth painting.
Constraints: body and clothing pixels only; exactly one Oh Tipi per cell; empty hands; no text, labels, borders, shadows, magic, elements, aura, projectiles, particles, dust, speed lines, weapons, tools, equipment, props or environment; no cropped figures or overlap.
Avoid: duplicated first-contact poses, wrong facing, extra limbs, inconsistent scale, spell pixels, detached objects, logos, watermark.
```

The S. Wayne phase-B prompt was:

```text
Use case: precise-object-edit
Asset type: versioned production-candidate body-only locomotion phase sheet for the FLUX 2D top-down pixel action game
Input images: Image 1 is the exact S. Wayne walk/sprint identity, outfit, proportions, palette and first-contact reference; Image 2 is the exact cardinal facing reference.
Primary request: Create a NEW clean 4-column by 2-row equal-cell sprite source sheet containing exactly eight isolated full-body poses of the same S. Wayne. This is the opposite gait contact phase, not a copy of Image 1.
Grid contract: columns left to right SOUTH/front, EAST/right profile, NORTH/back, WEST/left profile. Rows top to bottom WALK OPPOSITE CONTACT and SPRINT OPPOSITE DRIVE. In every cell swap the planted and passing legs compared with Image 1 and counter-swing the arms naturally; sprint has stronger lean and stride. Preserve facing, stable feet baseline, centered feet pivot, scale, round dark hair, warm dark skin, purple-and-gold short cloak, large bare hobbit feet, compact non-sexualized proportions and crisp outline.
Scene/backdrop: one flat opaque vivid magenta matte over the entire canvas with generous separation between equal cells.
Style/medium: original charming compact cartoon pixel art matching the input; economical pixel clusters readable around 58 pixels tall; no smooth painting.
Constraints: body and clothing pixels only; exactly one S. Wayne per cell; empty hands; no text, labels, borders, shadows, magic, elements, aura, projectiles, particles, dust, speed lines, weapons, tools, equipment, props or environment; no cropped figures or overlap.
Avoid: duplicated first-contact poses, wrong facing, extra limbs, inconsistent scale, spell pixels, detached objects, logos, watermark.
```

The diagonal action prompt was run once per champion. The Oh Tipi version was:

```text
Use case: precise-object-edit
Asset type: versioned production-candidate body-only diagonal locomotion and evasion sheet for the FLUX 2D top-down pixel action game
Input images: Image 1 is the exact Oh Tipi diagonal walk/sprint identity, outfit, proportions, palette and first-contact reference; Image 2 is the exact Oh Tipi cardinal movement-action reference for jump, slide and roll; Image 3 is the exact diagonal facing and body reference.
Primary request: Create a NEW clean 4-column by 5-row equal-cell sprite source sheet containing exactly twenty isolated full-body poses of the same Oh Tipi.
Grid contract: columns left to right SOUTH-EAST/front-right, NORTH-EAST/back-right, NORTH-WEST/back-left, SOUTH-WEST/front-left. Rows top to bottom: (1) WALK OPPOSITE CONTACT, swapping planted/passing legs and counter-swinging arms compared with Image 1; (2) SPRINT OPPOSITE DRIVE with stronger lean and stride; (3) JUMP with both feet visibly airborne, compact rising pose and arms balancing; (4) SLIDE, low elongated feet-first pose aligned precisely with facing; (5) ROLL, compact tucked somersault silhouette aligned precisely with facing. Preserve all four diagonal facings, stable centered feet pivot where applicable, scale, fin crown, cheek fins, tail, dark navy armor with aged-gold trim, cyan skin, compact non-sexualized proportions and crisp outline.
Scene/backdrop: one flat opaque vivid magenta matte over the entire canvas with generous separation between equal cells.
Style/medium: original charming compact cartoon pixel art matching the inputs; economical pixel clusters readable around 60 pixels tall; no smooth painting.
Constraints: body and clothing pixels only; exactly one Oh Tipi per cell; empty hands; no text, labels, borders, shadows, magic, elements, aura, projectiles, particles, dust, speed lines, weapons, tools, equipment, props or environment; no cropped figures or overlap.
Avoid: cardinal facings, duplicated first-contact poses, ambiguous direction, extra limbs, inconsistent scale, spell pixels, detached objects, logos, watermark.
```

The S. Wayne diagonal action prompt was:

```text
Use case: precise-object-edit
Asset type: versioned production-candidate body-only diagonal locomotion and evasion sheet for the FLUX 2D top-down pixel action game
Input images: Image 1 is the exact S. Wayne diagonal walk/sprint identity, outfit, proportions, palette and first-contact reference; Image 2 is the exact S. Wayne cardinal movement-action reference for jump, slide and roll; Image 3 is the exact diagonal facing and body reference.
Primary request: Create a NEW clean 4-column by 5-row equal-cell sprite source sheet containing exactly twenty isolated full-body poses of the same S. Wayne.
Grid contract: columns left to right SOUTH-EAST/front-right, NORTH-EAST/back-right, NORTH-WEST/back-left, SOUTH-WEST/front-left. Rows top to bottom: (1) WALK OPPOSITE CONTACT, swapping planted/passing legs and counter-swinging arms compared with Image 1; (2) SPRINT OPPOSITE DRIVE with stronger lean and stride; (3) JUMP with both feet visibly airborne, compact rising pose and arms balancing; (4) SLIDE, low elongated feet-first pose aligned precisely with facing; (5) ROLL, compact tucked somersault silhouette aligned precisely with facing. Preserve all four diagonal facings, stable centered feet pivot where applicable, scale, round dark hair, warm dark skin, purple-and-gold short cloak, large bare hobbit feet, compact non-sexualized proportions and crisp outline.
Scene/backdrop: one flat opaque vivid magenta matte over the entire canvas with generous separation between equal cells.
Style/medium: original charming compact cartoon pixel art matching the inputs; economical pixel clusters readable around 58 pixels tall; no smooth painting.
Constraints: body and clothing pixels only; exactly one S. Wayne per cell; empty hands; no text, labels, borders, shadows, magic, elements, aura, projectiles, particles, dust, speed lines, weapons, tools, equipment, props or environment; no cropped figures or overlap.
Avoid: cardinal facings, duplicated first-contact poses, ambiguous direction, extra limbs, inconsistent scale, spell pixels, detached objects, logos, watermark.
```

Human visual/originality acceptance is still required before final-art
promotion; automated validation proves structure, provenance, importability,
layer separation, and live mapping only.

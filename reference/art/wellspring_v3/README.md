# Original illustrated visual sources

Generated using Codex's built-in image generator on 2026-09-04, not the API/CLI.
These originals are source inputs, never gameplay authority. No protected game
assets were imported. The final reproducible prompt specifications are below.

| Source | Purpose | SHA-256 |
|---|---|---|
| surfaces-source.png | 4 x 4 opaque material board | d223057d25b7943957e4bb3a79b733dad952fefe7a63765e8ce7fcdaaed9c187 |
| props-clean-source.png | Selected corrected 4 x 4 prop board | 49dce18219ff23e69f6a5e3f732231bcebfb2a3d624b0318a4f47cc2ce8e1d |
| props-source.png | Earlier white-matte candidate; not runtime input | 4c1c5b547582788a5797ad14aab364e04535d8c123a16946aa73a38ce8c62dea |
| s_wayne-source.png | Small body, 8 directions x 8 pose families | 8cf064938719226a38ce3ddca80d3de44485cc670b01d9bb62a44f739478c41f |
| oh_tipi-source.png | Middle body, same grid | acf3cbd5a3de7a900800d153a7c56106da5f84b1ad0337aff07d91d756a5d0cf |
| red_baron-source.png | Large body, same grid | 8608e8744055dd6ed9ba6b0fde1985d5b5eb6bfb971ffbda5f2f60056319bc45 |

## Shared final prompt specification

Original FLUX old-world fantasy pixel artwork; warm carved stone, dark timber,
indigo slate, aged brass, olive planting and deep teal water. Mature cartoon
silhouettes, dark ink edges, restrained highlights, upper-left lighting.
Consistent approximately 55-degree elevated camera: shoulder/roof tops visible,
front facades short; cardinal ground axes, not a diamond/isometric floor.
No copied game assets, logos, watermarks or text.

### Surface board

Exactly four by four equal square cells, edge-to-edge opaque materials, no
margins. Row 1: warm flagstone A, warm flagstone B, moss flagstone, small
flagstone. Row 2: olive grass, fern grass, earth, moss earth. Row 3: deep teal
water A, water B, indigo slate shingles, warm masonry. Row 4: timber planks,
cobble, dark retaining masonry, terracotta brick. Screen-aligned repeatable
material textures, quiet enough below combat projectiles.

### Prop board and correction prompt

Exactly four by four equal cells. Row 1: oak, small tree, purple flowering bush,
ferns. Row 2: horizontal wall, vertical wall, mossy rocks, wooden planter.
Row 3: short-crystal fountain, book lectern, training dummy, brass bell.
Row 4: timber/slate doorway, bench, lantern post, blue banner. One complete
object per cell, consistent elevated camera, at least 10% clear margin.

Correction: background-extraction, change only background and cell separation;
remove opaque white backing and disconnected adjacent-cell fragments, preserve
all subjects, colors, proportions, layout and style; actual transparency, no
checkerboard, paper tiles, glow or extra objects.

The corrected tool output still contained an opaque preview matte. The asset
importer therefore explicitly extracts border-connected near-white neutral
matte before packing. It preserves internal highlights and source files.
The runtime acceptance test rejects opaque prop cards; generation alone is
never sufficient evidence of a usable alpha channel.

### Champion boards

Exactly eight equal columns: S, SE, E, NE, N, NW, W, SW. Eight rows: grounded,
walk contact A, walk contact B, sprint contact A, jump, empty-hand cast, slide,
tucked roll. Preserve character mass and anatomy across poses; feet tucked
while jumping, low grounded slide, compact roll. No weapons, staff, wand,
spells, particles, auras, shadows, scenery or detached accessories. Front/back
poses centered; profile and diagonal poses clearly differentiated. Ordinary
head roughly 26-28% of standing body height, excluding ancestry features.

| Character | Prompt-specific identity |
|---|---|
| S. Wayne | Adult male hobbit, tan skin, dark wavy hair, indigo-violet short coat, gold trim, brown leggings, broad bare feet; compact low-center build |
| Oh Tipi | Upright anthropomorphic turquoise-blue seakin, fin crest, cheek fins, curling tail, dark indigo vest with gold trim, webbed feet; balanced sturdy build |
| Red Baron | Broad undead noble, ivory skull and short bone crown, burgundy coat, crimson cape, charcoal clothes/boots, gold trim, empty bone hands; large high-mass build |

## Rebuild and review

Run the pinned Godot with `--headless --path . --script
res://scripts/build_illustrated_visuals.gd`, import the project, then run
`res://scripts/audit_illustrated_visuals.gd`. Use the checked process helper in
`scripts/flux2-common.ps1`, not an unattended GUI-executable invocation.

The compiler proportionally samples the generated grid boundaries, isolates
each connected body, anchors feet at (48,84), applies a shared 64-color material
palette and one-pixel exterior ink, and packs the existing ten runtime rows.
Hit uses grounded recoil; sprint B reuses walk B with sprint timing. Upright
heights are 58/68/76 before exterior ink; crouches use the neutral body scale,
not the standing bounding-box height. Runtime scale is always 1.0.

After every rebuild update pinned source/imported pixel hashes, inspect the
actual game and contact sheet, and run the focused visual suites. The reference
sheet is built from runtime pixels; it is not a separate idealized drawing.

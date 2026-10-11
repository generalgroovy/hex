# Ba Djoh fixed-pixel jump-key source

Date: 2026-10-03. Built-in image generation only; one initial generation call.

Runtime identity: `ba_djoh`, Ba Djoh, ancestry `minotaur`, body_type `large` from `content/champions/foundation_champions_v1.json`.

## Reference paths

- `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/ba_djoh.png` - primary runtime identity, proportions, costume and headings.
- `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/ba_djoh-detail.png` - supporting identity and anatomy details.
- `C:/Users/sende/Pictures/styleref1.png` - style only, never identity or props.

All three local images were visually inspected before generation. The S. Wayne v3 proportion contract was read; oversized heads and per-pose scaling are prohibited.

## Exact generation prompt

Use case: identity-preserve.
Asset type: H.E.X. Ba Djoh transparent pixel-art jump-key source sheet, ONE existing character in 32 complete full-body sprites.

Input images and roles:
Image 1 (assets/sprites/pixel_cast_v1/ba_djoh.png) is PRIMARY CURRENT RUNTIME CANON: exact brown minotaur identity, compact full-bodied proportions, armor, palette and eight genuine directions.
Image 2 (assets/sprites/fullbody_cast_v1/ba_djoh-detail.png) supports facial features, gold-studded leather straps and bracers, hoof and tail anatomy, costume details and profile/back views.
Image 3 (styleref1.png) is STYLE ONLY: charming retro fantasy pixel figures, deliberate dark colored outlines and clustered material shading. Ignore ALL its labels, identities, weapons, shields, magic and extra characters. Do not copy its alternate minotaur costume.

Create one new genuinely transparent RGBA source image, approximately 2048x1024 landscape, EXACTLY 8 equal columns by 4 equal rows, exactly 32 complete sprites of Ba Djoh. Wide regular transparent gutters; all horns, fingertips, hooves and tail tips completely inside their own cells. NO title, caption, numbers, direction labels, grid marks or border.

Every row has these EXACT eight columns:
1 S: front, faces the viewer.
2 SE: front three-quarter facing screen RIGHT.
3 E: true right profile, muzzle faces screen RIGHT.
4 NE: BACK three-quarter facing screen RIGHT, back and right shoulder visible, not a front view.
5 N: directly away, full back, no visible face.
6 NW: BACK three-quarter facing screen LEFT, back and left shoulder visible.
7 W: true left profile, muzzle faces screen LEFT.
8 SW: front three-quarter facing screen LEFT.
Rotate the whole anatomy honestly, not just the head. Draw all views naturally, not mirrored copies.

Rows from top to bottom, four distinct authored anatomical jump keys:
1 ANTICIPATION: hooves planted, knees visibly bent, pelvis moderately lowered, broad torso poised forward, bent elbows with empty hands by the sides.
2 RISING TUCK: airborne pose with knees folded and hooves drawn slightly backward/up toward the hips, clearly compact lower-leg silhouette; torso remains long and open, elbows raised and arms opened outward for balance. Not a sitting ball, no missing shins.
3 DESCENDING FEET-READY: hips and knees OPEN compared with row 2, both hooves extended down beneath body and separated ready to land; elbows lower and hands forward/outward. Clearly distinct leg AND arm silhouette from tucked rise.
4 DEEP LANDING: both hooves firmly planted wide, knees bent substantially deeper than row 1, pelvis settled low between the knees, torso naturally leans forward with hands beside/forward for balance. This row must be visibly shorter and more compressed than row 1 through JOINT BENDING, never by scaling or flattening anatomy.

Identity invariants: same broad masculine brown-furred minotaur as Images 1 and 2, dark tousled mane running down upper back, brown bull face and dark muzzle, two modest ivory curved horns, small ears, heavy strong torso and arms, leather chest harness with gold studs and medallions, gold-trimmed dark leather bracers, wide belt with round gold buckle, red/burgundy ragged loincloth with gold edging, gold ankle bands, dark cloven hooves, tufted brown tail. Preserve reference armor coverage and exact palette. Large body class is conveyed mainly by breadth and mass, not extreme height or an inflated head. Preserve tail with transparent clearance, do not turn it into a weapon or effect.

Proportion contract: one COMMON character scale for all 32 sprites. Skull including mane crown to chin should be about one third of neutral standing height, NOT half-height baby/chibi. Think neutral standing-equivalent height 60 units and skull+hair height about 18-20 units, with the same head dimensions in every pose. Horns are separate protrusions that keep the modest source-reference size and curve; DO NOT inflate horns to fill a cell. Maintain substantial real neck, torso, waist, pelvis, thighs, knees, shins and hooves. Shared anatomical limb lengths and broad body volume across all poses/headings; crouching only rotates joints. Aim posed heights roughly 51-54 units anticipation, 55-58 rise, 58-60 descent, 45-49 deep landing, without independently fitting any pose to its own box. Skull and torso are never squash-scaled.

Registration: same cell-coordinate framework and common horizontal body root in all cells. Similar imaginary hoof/root baseline within each row. Do NOT move whole airborne characters upward to bake a jump trajectory; the game supplies world-height lift. Change only anatomical poses. Lighting consistently upper-left. Crisp readable pixel-art clusters and colored outlines, limited brown/gold/burgundy/ivory palette, no soft painterly blur.

Hands are completely EMPTY in every view, naturally usable for hand casting but with no magic drawn. No weapons, shield, axe, staff, wand, props, VFX, particles, dust, speed lines, baked glow, ground shadows, floor, environment, watermark or other marks. True transparent alpha background, no checkerboard pattern painted into the artwork.

## Review and acceptance boundary

Source-size review and original-byte verification are recorded in `source/ba_djoh/receipt.json`. Native-scale comparison, deterministic assembly, engine import, runtime transition capture and human acceptance are NOT_RUN by this source-art ticket.

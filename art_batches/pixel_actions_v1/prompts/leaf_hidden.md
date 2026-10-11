# Leaf the Hidden jump-key source prompt

Date: 2026-10-03. Built-in image generation, one initial call. Source-art ticket only; native-scale, runtime and human acceptance are NOT_RUN.

## Reference paths

- `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/leaf_hidden.png` — primary runtime identity and proportions.
- `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/leaf_hidden-detail.png` — identity detail and anatomy.
- `C:/Users/sende/Pictures/styleref1.png` — style only; noncanonical labels, character variants and props excluded.
- `C:/Users/sende/Projects/hex/art_batches/pixel_actions_v1/prompts/s_wayne.md` — textual v3 proportion contract inspected; not an image input.

## Exact generation prompt

Use case: stylized-concept.
Asset type: production source sprite sheet for the existing H.E.X. character Leaf the Hidden (leaf_hidden), canonical ancestry treefolk and middle body type. Create FOUR authored jump key poses in EIGHT directions.

Input roles: Image 1, leaf_hidden.png, is PRIMARY CURRENT RUNTIME CANON for exact identity, compact full-bodied proportions, costume colors and eight facings. Image 2, leaf_hidden-detail.png, supplies supporting anatomy, leaf layers, bark joints, hood, face and costume details. Image 3, styleref1.png, is STYLE ONLY for charming fantasy pixel clusters and colored outlines; ignore its labels, older identities, antlers, props, weapons and magic. Do NOT copy the old staff-bearing Leaf from Image 3. Preserve the current hooded character from Images 1 and 2.

Create one genuinely transparent RGBA landscape sprite sheet, approximately 2048x1024, exactly 8 equally spaced columns by 4 equally spaced rows, exactly 32 complete full-body sprites of this ONE character. Generous clear transparent margins around every complete figure, including all fingertips, toes, hood point and leaf cape. No frame borders, grid marks, captions, numbers, arrows, text, shadows, floor or environment.

Directions in EVERY row, from left to right:
1 S: directly front, facing viewer.
2 SE: front three-quarter facing screen RIGHT.
3 E: true right profile facing screen RIGHT.
4 NE: BACK three-quarter facing screen RIGHT; rear cape and back/right shoulder readable, NOT another front-quarter.
5 N: full back, directly away; hood rear and leaf cape, NO visible face.
6 NW: BACK three-quarter facing screen LEFT.
7 W: true left profile facing screen LEFT.
8 SW: front three-quarter facing screen LEFT.
Rotate the WHOLE anatomy consistently; never turn only the head. Author genuine different directions, not synthetic mirrored copies.

Rows top to bottom:
1 Jumpsquat/anticipation: planted feet, knees bent moderately, pelvis lowered, balanced torso slightly forward, elbows bent and empty hands lightly outward, preparing to spring.
2 Airborne rising TUCK: hips flex and both knees bend, lower legs tuck backward/up beneath the body, both feet visibly lifted toward the pelvis; elbows bent and hands spread outward for balance. Maintain real torso and thigh length, never curl into a head-with-feet ball. A distinct folded-leg silhouette.
3 Airborne descending FEET-READY: extend thighs and lower legs DOWN beneath pelvis with soft knees, feet separated and ready to land, hands forward/outward for balance. Visibly longer open leg silhouette than row 2, no tucked-up feet.
4 Compressed LANDING: both feet fully planted and spread, knees bend MORE DEEPLY than row 1, pelvis naturally low between knees, torso leans forward moderately, arms open low for balance. The hood crown sits visibly lower than in row 1 through joint bending only, never squash-scaling.

Identity and anatomy invariants: the SAME compact middle-bodied hooded treefolk as the primary runtime reference. Pointed green leaf hood with fine gold edges; dark brown wooden face set within hood shadow; two warm amber eyes WITHOUT glow spilling outside them; short neck; green gold-trimmed leaf tunic, gold belt and buckle; layered broad green leaf cape covering the back; brown articulated bark forearms, hands, knees, shins and root-like feet. No antlers, branches, extra horns or added accessories. Maintain the current gender presentation without sexualization. Keep a real neck, torso, waist, pelvis, thighs, knees and shins. Head plus hood envelope about ONE THIRD of NEUTRAL standing crown-to-sole height, never half. Preserve the same skull/hood size, limb lengths, body volume and costume in all 32 poses. Middle body type means body volume, not taller stretched anatomy. Crouched poses shorten only by joint rotations; do NOT independently enlarge short poses.

Registration: one common body scale and same cell coordinate system for every figure. Keep body roots over each cell horizontal center with consistent local foot/root registration, without translating entire airborne figures to fake a jump trajectory. Game supplies world-height motion. No per-cell bounding-box fitting. Keep all limbs clearly connected and both empty hands usable for hand casting. Leaf cape may naturally overlap parts of rear legs but must not conceal the difference between tuck and descending feet-ready.

Style: deliberate crisp retro pixel-art clusters, clean dark colored outlines, readable at tiny native game size, restrained green/gold/bark-brown palette and consistent top-left lighting as the current runtime character. No blurry painterly rendering or oversized chibi head. Actual transparent alpha, no baked checkerboard or colored matte. No wands, staffs, weapons, shields, held objects, spells, magic effects, particles, dust, motion lines, environmental shadows, watermarks, or other characters.

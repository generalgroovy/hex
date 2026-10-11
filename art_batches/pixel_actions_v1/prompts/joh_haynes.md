# Joh Haynes fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation; no CLI/API fallback.

Canonical identity: joh_haynes / Joh Haynes / orc / large, verified in content/champions/foundation_champions_v1.json.

## Reference paths

- C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/joh_haynes.png
- C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/joh_haynes-detail.png
- C:/Users/sende/Pictures/styleref1.png

## Exact generation prompt

Use case: stylized-concept.
Asset type: transparent production pixel-art sprite-sheet source for the existing H.E.X. character Joh Haynes, Large Orc; four authored jump-chain key poses in eight directions.

Input images and roles: Image 1 (assets/sprites/pixel_cast_v1/joh_haynes.png) is PRIMARY CURRENT RUNTIME CANON for identity, costume, colors, full-bodied compact proportions and eight genuine headings. Image 2 (assets/sprites/fullbody_cast_v1/joh_haynes-detail.png) is supporting identity, costume detail and actual back/profile anatomy. Image 3 (styleref1.png) is STYLE ONLY: charming retro pixel clusters and colored outlines. Ignore all its names, races, characters, weapons, effects and layout. In particular do NOT substitute the different orc Fluup shown in Image 3.

Create one genuinely transparent RGBA sprite sheet, approximately 2048x1024 landscape, EXACTLY 8 equally spaced columns and 4 equally spaced rows, 32 complete full-body sprites of this ONE character. Generous transparent gutters, all hair/hands/boots completely inside their cells, no overlapping sprites. No text, labels, cell borders, numbers, arrows, shadow or backdrop.

Identity invariants: Joh Haynes is the broad muscular male olive-green orc in Images 1 and 2, with pointed ears, small ivory lower tusks, stern warm readable yellow eyes, black tied-back ponytail/topknot and full black beard. Preserve his distinctive bronze-brown riveted shoulder plates with gold rims, brown leather torso armor with diagonal straps, bronze bracers, round gold belt buckle, dark green gold-edged hanging waist tabard, leather hip panels, dark trousers and stout brown armored boots. Arms/hands are green. No redesign, no Fluup's spiky black steel armor, no giant protruding spikes, no weapon. Preserve masculine presentation without sexualization.

PROPORTION CONTRACT: common skull/head dimensions, anatomical limb lengths and body volume in all 32 poses. Head including hair/beard approximately ONE THIRD of equivalent neutral standing crown-to-sole height, not one half. A standing-equivalent 64-unit figure uses a 20-22-unit head envelope; below the chin keep substantial broad armored torso, waist, hips, thighs, knees, shins and boots. Large size is mainly broad chest, shoulders and powerful limbs, not stretched height or giant baby head. Do not shorten the body into head-and-boots chibi. Crouches lower the pelvis by real joint rotation, not shrinking or squash scaling.

Columns left to right in EVERY row:
1 S = front, faces viewer;
2 SE = front three-quarter facing screen RIGHT;
3 E = true RIGHT profile;
4 NE = BACK three-quarter facing screen RIGHT, visible back/right shoulder and rear armor;
5 N = directly away, full BACK with ponytail and back torso;
6 NW = BACK three-quarter facing screen LEFT;
7 W = true LEFT profile;
8 SW = front three-quarter facing screen LEFT.
Rotate the entire anatomical figure and armor correctly, not merely the head. Rear quarters must show back armor planes, rear tabard/leather panels, back hair and rear shoulders, not a front chest with the face erased. Keep genuine separately authored eight-facing anatomy, not synthetic mirrored directions.

Rows top to bottom:
1 Jumpsquat/anticipation: both boots planted, moderate knee bend, lowered pelvis and torso balanced over knees; elbows bent, naturally empty hands visible beside body. Posed height roughly 54-57 standing-equivalent units.
2 Rising tucked jump: both legs genuinely flexed at knees, boots tucked modestly up/back under hips, arms spread/up for airborne balance. Compact but not a seated ball; armored torso remains full length. Distinct bent/tucked leg silhouette from row 3. Posed height roughly 56-61 units.
3 Descending feet-ready jump: hips and knees open, both boots extended below pelvis and ready for landing, knees soft, hands forward/outward for balance. Clearly more extended legs and different arm silhouette than row 2. Posed height roughly 61-64 units.
4 Deep compressed landing: both boots planted wide, visibly deeper knee flexion and lower pelvis than row 1, hips settle between bent knees, upper body naturally inclines forward; hands spread beside/forward for balance. Keep anatomical thighs/shins and same skull/body scale, never shrink whole figure. Posed height roughly 48-52 units.

Registration: one common model scale across all cells. NEVER fit/resize each pose independently to its own bounding box. Same horizontal body root in each cell, consistent imaginary feet/root baseline across each row. Do not translate the entire airborne figure upward for a jump trajectory: game supplies world-height lift. Only authored anatomical pose changes. Empty hands in all cells, no hidden weapon, no effects or spell casting glow.

Style: charming deliberate crisp pixel-art clusters, clean dark colored outlines, bronze/gold and dark green costume against olive skin, consistent top-left lighting and tiny controlled material highlights. Strong readable full-body silhouettes for eventual small native game rendering. Actual transparent alpha, no baked checkerboard or colored matte. No ground, cast shadows, dust, motion streaks, props, environment, extra characters, watermark or any text.


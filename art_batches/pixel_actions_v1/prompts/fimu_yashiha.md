# Mifu fixed-pixel jump-key source

Date: 2026-10-03. Built-in image generation; one initial call. Source-only ticket, no runtime edits.

## Reference paths

- C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/fimu_yashiha.png
- C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/fimu_yashiha-detail.png
- C:/Users/sende/Pictures/styleref1.png

Runtime identity verified in content/champions/foundation_champions_v1.json: fimu_yashiha, display_name Mifu, ancestry treefolk, body_type small. Existing approved references own costume and face. The s_wayne v3 prompt contract supplies the common approximately one-third head/standing-height policy.

## Exact generation prompt

Use case: stylized-concept.
Asset type: H.E.X. production pixel-art jump-key source sheet for ONE character, Mifu (id fimu_yashiha), a small adult treefolk woman.

Input reference roles:
Image 1, assets/sprites/pixel_cast_v1/fimu_yashiha.png, is the PRIMARY CURRENT RUNTIME CANON for identity, exact compact full-bodied proportions, costume, colors, face, and genuine eight-direction anatomy. This is a small treefolk woman, not a tall elf or a baby/chibi.
Image 2, assets/sprites/fullbody_cast_v1/fimu_yashiha-detail.png, supports her face, detailed leafy braided hair, bark anatomy, teal/gold clothing and rear/profile construction. Do not upscale her head.
Image 3, styleref1.png, is STYLE ONLY: charming readable retro fantasy pixel clusters and colored outlines. Ignore all names, ancestry labels, unrelated characters, weapons, magic, text and background in Image 3.

Produce exactly one true transparent RGBA landscape sheet, approximately 2048x1024, exactly 8 uniformly spaced columns by 4 uniformly spaced rows, 32 complete separate full-body sprites of the SAME Mifu. Wide transparent gutters, full extremities inside each cell, no borders or marks.

Column headings in EVERY row, left to right:
1 S = front, facing viewer;
2 SE = front three-quarter facing screen RIGHT;
3 E = genuine full right profile;
4 NE = BACK three-quarter facing screen RIGHT, back/right shoulder readable, not front quarter;
5 N = full back, directly away, no face;
6 NW = BACK three-quarter facing screen LEFT;
7 W = genuine full left profile;
8 SW = front three-quarter facing screen LEFT.
The torso, shoulders, hips, feet, face and leaf-hair mass must all rotate coherently. Genuinely draw every direction; do not merely mirror or turn the head.

Rows top to bottom:
1 Jumpsquat / anticipation: knees visibly bent, pelvis moderately lowered, both root-like bare wooden feet planted, torso balanced over knees, arms bent slightly back/outward, empty hands visible.
2 Rising tucked jump: clearly airborne anatomical pose with knees naturally folding, heels and root toes tucked modestly back toward the body; arms bent outward/upward for balance. Keep the real torso and thigh length, not a curled sitting ball. Distinct folded-leg silhouette from row 3.
3 Descending feet-ready jump: knees opening and legs extending below pelvis, both feet hanging ready beneath the body with toes ready to plant; elbows and empty hands forward/outward for balance. Distinct extended-leg and lowered-arm silhouette from row 2.
4 Deep compressed landing: convincingly deeper than row 1; root feet firmly planted and spread for stability, knees deeply flexed, pelvis low between knees, torso naturally inclines forward, hands outward and slightly forward. Preserve anatomical limb length by joint bends only. Do not flatten or squash the body. Leaf-hair drapes naturally with the torso.

Identity locks: same warm brown bark-skinned small treefolk woman, amber brown eyes, pointed leafy ears, kind expressive face, leafy braided hair cascading down back and sides in green/olive and autumn orange-brown layers, small white blossoms as in primary canon. Preserve teal cloth bodice and long front panel, gold edge trims, gold round belt fitting and leaf-shaped side panels, wooden forearms and root-like bare feet. Maintain modest adult feminine presentation without sexualization; fully covered torso, no cleavage, no exaggerated anatomy. Same costume geometry and palette in all views, proper rear costume and back leaf layers in back views. No staff, wand, weapon or prop; both hands empty.

CRITICAL proportions and consistent scale: head crown-to-chin excluding long hanging leaf hair is approximately one-third of neutral standing crown-to-sole height, NEVER one-half. At a common neutral standing equivalent of 58 units, keep the SAME 18-20 unit head across all 32 cells, with genuine neck, torso, waist, pelvis, thighs, knees and lower legs below. Lower leaf hair extending down the back is not a larger skull. Preserve small body volume rather than stretching height. All 32 poses share one body-model scale, skull size, limb lengths and body volume. No individual bounding-box fitting or rescaling. Approximate pose heights: anticipation 48-51 units, rising tuck 52-56, descending feet-ready 56-58, deeper landing 44-47. This compression comes from actual joint articulation, not a scaled-down body. Leave enough space for every leafy tip, fingertip and root toe.

Animation registration: center each body root on its cell horizontal center, consistent imaginary root/feet baseline across matching directions, no baked upward whole-sprite translation; runtime supplies jump world height. These are four authored key poses, not motion trails. Crisp deliberate pixel-art clusters, clean dark colored outlines, restrained material highlights and consistent top-left lighting, readable at small native game scale. No antialiased painted illustration look.

Background and exclusions: actual transparent alpha, no colored matte or baked checkerboard. No captions, labels, numbers, grid marks, shadows, ground, environment, dust, glow, spells, effects, speed lines, extra characters, watermark, weapons or props.

## Scope and acceptance limits

The untouched generated original is source/fimu_yashiha/source.png. Provenance, original SHA256, image metadata and source-size visual review are recorded in receipt.json after review. Native-scale, engine/runtime, rendered transition and human acceptance are NOT_RUN. Alpha cleanup, registration and downsampling remain lead-owned.

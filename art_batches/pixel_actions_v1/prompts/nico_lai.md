# Waka Aren Si fixed-pixel jump source

Character ID: `nico_lai`. Current runtime identity: Waka Aren Si; ancestry `gnome`; body type `small`.
Date: 2026-10-03. Built-in image generation, single initial call. No CLI/API fallback.

## Reference paths

- C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/nico_lai.png
- C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/nico_lai-detail.png
- C:/Users/sende/Pictures/styleref1.png

## Exact final prompt

Use case: stylized-concept.
Asset type: H.E.X. fixed-pixel jump-chain source sheet for ONE existing character, nico_lai, current display name Waka Aren Si, a small male gnome.
Input images and roles: Image 1 (assets/sprites/pixel_cast_v1/nico_lai.png) is PRIMARY CURRENT RUNTIME CANON for exact identity, costume, compact proportions and eight headings. Image 2 (assets/sprites/fullbody_cast_v1/nico_lai-detail.png) is supporting costume, white hair, goggles, beard and genuine profile/rear anatomy reference. Image 3 (styleref1.png) is STYLE ONLY: charming fantasy pixel clusters and colored outlines. Ignore ALL text, labels, old names, races, other characters, staffs, robots and magical effects in Image 3. This is a NEW action sheet, not an edit of the runtime atlas.
Create one genuinely transparent RGBA landscape sprite sheet, approximately 2048x1024, exactly 8 equally spaced columns and 4 equally spaced rows: 32 complete full-body poses. Generous transparent gutters, no borders, titles, labels, numbers or marks.

Identity invariants: preserve the small mature male gnome, warm tan skin, prominent pointed ears, swept spiky white hair, white moustache and short white beard, round brass goggles with cyan blue glass worn over eyes and dark strap around back of head. Preserve the dark navy short coat with bright gold piping and gold shoulder/sleeve edging, brass belt buckle and small pouches, dark trousers, brown gloves and sturdy brown boots. Navy back coat panels and goggle strap distinguish rear views. Maintain this exact outfit across all 32 poses. No redesign, no long wizard robe, no robot companion, no staff or wand. All hands empty.

Proportion contract: small but FULL-BODIED adult gnome, not oversized baby-chibi. Head including hair crown to chin is approximately ONE THIRD of neutral standing crown-to-sole height. Use one shared standing-equivalent 58-unit anatomical model and approximately 18-20-unit head across all cells. Below chin retain a real neck, torso, waist, pelvis, thighs, knees, calves and boots. Body mass stays compact with broad volume, not a stretched tall body. Crouches get shorter ONLY by natural joint rotation. Keep SAME skull size, limb lengths, body mass and coat dimensions for every action and direction. Do not fit or independently rescale poses to their bounding boxes.

Exact headings in EVERY row, left to right:
Column 1 S = straight front, faces viewer;
Column 2 SE = front three-quarter facing screen RIGHT;
Column 3 E = true screen-RIGHT profile;
Column 4 NE = BACK three-quarter facing screen RIGHT, back/right shoulder prominent, NOT a front-quarter face;
Column 5 N = straight BACK, facing away, no face or goggles on the back;
Column 6 NW = BACK three-quarter facing screen LEFT, back/left shoulder prominent;
Column 7 W = true screen-LEFT profile;
Column 8 SW = front three-quarter facing screen LEFT.
Turn the entire torso, pelvis, feet and head consistently; genuine eight-direction anatomy, never only head turns or synthetic mirrored poses.

Rows top to bottom:
1 JUMPSQUAT anticipation: boots planted, knees visibly bent, pelvis lowered, torso poised over legs, elbows bent with empty hands lightly forward. Posed height about 48-51 units with SAME 18-20-unit head.
2 RISING TUCKED jump: thighs and knees naturally folded, boots modestly tucked backward, arms comfortably spread for balance. Real extended torso and connected thighs, not a sitting ball. Posed height about 53-56 units with SAME head.
3 DESCENDING FEET-READY jump: legs extend beneath hips, knees soft, boots point downward ready to land, arms forward/outward for balance. Clearly different leg and arm silhouette from tucked row 2. Posed height about 56-58 units with SAME head.
4 DEEP COMPRESSED LANDING: boots planted apart, knees bend more deeply than row 1, pelvis lower, torso leans naturally forward, hands spread beside knees for balance. Posed height about 45-48 units with SAME head. Visible anatomical compression, not a scale-squashed duplicate of row 1.

Registration: one common cell coordinate system, root horizontally centered in every cell, consistent imaginary sole/root baseline across headings in each row. Do not shift whole airborne sprites upward to draw world-space jump motion; engine provides world-height. Only anatomical pose changes. Keep full hair, ears, fingertips and boot toes inside their cells.
Style: deliberate crisp pixel-art clusters, clean dark colored outlines, restrained navy/gold/cyan/white/brown palette, coherent top-left material lighting, charming and readable at small game size.
Background: actual alpha transparency, no opaque black or white matte and no checkerboard artwork. No shadows, floor, environment, dust, speed lines, spell effects, glow, captions, labels, watermark, weapons, held tools, accessories beyond canonical costume, robots or other characters.

# Fluup fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation; one initial call, no corrective call or CLI/API fallback.

Current runtime identity: `fluup`, display name `Fluup`, ancestry `orc`, body type `large`, verified from `content/champions/foundation_champions_v1.json`.

## Reference paths

1. C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/fluup.png
2. C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/fluup-detail.png
3. C:/Users/sende/Pictures/styleref1.png

## Exact generation prompt

Use case: stylized-concept.
Asset type: production-source transparent pixel-art sprite sheet for the existing H.E.X. character Fluup; exactly four authored jump key poses in eight true directions.

Input image roles: Image 1 (assets/sprites/pixel_cast_v1/fluup.png) is PRIMARY CURRENT RUNTIME CANON: exact Fluup identity, green skin, dark short spiky hair, face, costume, colors, compact full-bodied proportions and genuine eight directions. Image 2 (assets/sprites/fullbody_cast_v1/fluup-detail.png) supports precise armor, leather straps, face and rear/profile anatomy. Image 3 (styleref1.png) is STYLE ONLY: charming retro fantasy pixel clusters and colored outlines. Ignore all Image 3 names, ancestry labels, props, weapons, effects and unrelated characters. Current runtime identity wins: Fluup is a LARGE ORC, masculine presentation.

Create one true-transparent RGBA sprite sheet approximately 2048x1024 landscape, EXACTLY 8 uniformly spaced columns by 4 uniformly spaced rows, 32 complete full-body poses of ONLY Fluup, ample transparent gutters around all hands, toes and armor spikes. No text, names, captions, cell borders, grid marks, arrows, background, floor, shadow, effects, checkerboard artwork or watermark.

Direction order in EVERY row:
Column 1 S: directly front, face and chest toward viewer.
Column 2 SE: front three-quarter facing screen RIGHT.
Column 3 E: true right profile.
Column 4 NE: back three-quarter facing screen RIGHT, genuine back and right shoulder visible, NOT another front quarter.
Column 5 N: directly away, full back, no face on back.
Column 6 NW: back three-quarter facing screen LEFT.
Column 7 W: true left profile.
Column 8 SW: front three-quarter facing screen LEFT.
Rotate the complete anatomy and costume, not merely the face. Genuinely author each direction, no synthetic mirrored sprites.

Rows, top to bottom:
1 Jumpsquat anticipation: broad booted feet planted, knees clearly bent, pelvis lowered, torso balanced above legs, elbows bent and empty hands out beside the body. Moderate preparatory crouch.
2 Rising tucked jump: airborne anatomical pose, knees flexed and lower legs tucked backward, boots visibly lifted closer to hips, arms spread outward and slightly upward for balance. Keep torso extended and readable, not seated in a ball.
3 Descending feet-ready: both legs opening beneath hips, boots extending downward ready to land, knees softly bent, arms down/outward and forward for stability. Clearly distinct from the tucked legs and higher arms of row 2.
4 Deep compressed landing: feet firmly planted wider, knees bent deeply, pelvis low between thighs, torso slightly leaning forward and arms balancing forward/outward. Noticeably deeper compression than row 1, produced by joint bending, never by resizing or squashing body parts.

Proportion and model invariants: one common fixed anatomical scale throughout ALL 32 cells. Maintain the primary runtime's compact but full-bodied powerful orc, broad muscular shoulders, chunky muscular arms, sturdy torso and real visible thighs, knees, shins and boots. Skull including hair is about ONE THIRD of neutral standing crown-to-sole height, NOT half; do not make an oversized-head chibi baby or a stretched tall adult. Illustrative common standing-equivalent 64 units with a fixed 20-21-unit head: row 1 approximately 55-58 units, row 2 55-60 units with natural tuck, row 3 61-64 units, row 4 47-52 units. Head, torso, limb lengths and body volume never change between poses. Large-body identity comes mostly from width, muscle and armor volume, not exaggerated height. Do not independently fit each sprite to its bounding box.

Identity: same green-skinned broad-faced adult male orc with small pale tusks, pointed ears, short black/dark spiky hair, stern expressive brows, paired silver steel spiked pauldrons, brown leather cross-body harness and brown leather torso armor, brass/gold buckled belt, brown waist flap, dark brown trousers, silver kneecaps and rugged armored brown boots. Keep back straps and back armor coherent in rear views. Preserve the primary reference costume rather than copying the style reference's different armor. Keep empty naturally articulated hands: no weapons, shields, staffs, wands, props or baked magic. No added wings or tail.

Registration: common cell centers and body root coordinate system. All same-direction row poses use the same model scale. Imaginary root baseline consistent within each row; do not lift the entire airborne sprite to fake world motion because the game supplies jump height. Preserve transparent clearance and complete extremities in every cell, with no neighboring overlap.

Style: crisp deliberate retro pixel-art clusters, dark colored outlines, readable simple high-contrast material shading, green/brown/silver/gold palette and consistent top-left illumination as runtime canon. No blur, painterly gradient, realistic rendering, ground shadow, glow, dust, speed lines, scene, text or extra elements. True alpha transparency, no colored matte.

## Source-size review and limits

The original generated 8x4 sheet contains 32 complete sprites with the expected S/SE/E/NE/N/NW/W/SW facing order, empty hands, silver shoulder armor and brown leather costume. Row 2 shows tucked boots and higher/outward arms; row 3 shows opened legs and lower arms. Row 4 is wider and lower at the pelvis than row 1, but final native-scale compression/readability needs lead review. Head size appears broadly constant across poses at source size. Naturally occluded far hands, armor overlaps, and slight pose-to-pose contour changes remain. No gross grid, facing, cropping or anatomy defect justified another generation call.

Saved PNG is the untouched original, copied byte-identically. Alpha includes partial pixels; deterministic alpha cleanup, registration, any downsampling, exact runtime head/volume comparison and integration are lead-owned. This is source-art acceptance only. Native-scale acceptance: NOT_RUN. Runtime/import/rendered-transition acceptance: NOT_RUN. Human acceptance: NOT_RUN.


# Haara fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation; no CLI/API fallback.

Scope: Haara, small nymph. One original 8-heading by 4-key sheet. Source-only review; native-scale, runtime, and human acceptance are NOT_RUN.

## Reference paths

- C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/haara.png — primary runtime identity and proportions.
- C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/haara-detail.png — identity detail.
- C:/Users/sende/Pictures/styleref1.png — style only.

## Exact generation prompt

Use case: stylized-concept.
Asset type: H.E.X. Haara production sprite-sheet SOURCE for four authored jump keys in eight genuine directions, with true transparent RGBA.

Input images and roles:
Image 1 (assets/sprites/pixel_cast_v1/haara.png) is PRIMARY CURRENT RUNTIME CANON for Haara's identity, costume, colors, compact full-bodied proportions, and eight headings. This is a small nymph named Haara, not any alternate character.
Image 2 (assets/sprites/fullbody_cast_v1/haara-detail.png) supports facial, costume, flower, and rear/profile detail. Preserve the green-haired modestly clothed nymph with pointed ears, warm skin, small pink/cream flowers woven through long leafy hair, gold-trimmed green leaf-panel tunic, cream sleeves, belt and gold buckle, dark fitted legwear and brown boots. Feminine presentation without sexualization. Empty hands throughout.
Image 3 (styleref1.png) is STYLE ONLY: charming retro fantasy pixel clusters and colored outlines. Ignore all its labels, races, identities, weapons, staffs, and magic. Do not copy its older Haara redesign.

Create exactly 8 equally spaced columns by 4 equally spaced rows, 32 complete full-body sprites of ONLY Haara, approximately 2048x1024 landscape. Generous true-transparent gutters; no cell lines, titles, captions, numbers, other characters, scenery, ground, shadows, motion lines, glow or effects. No staff, wand, weapon or held object.

Column order in EVERY row:
1 S = front facing viewer.
2 SE = front three-quarter facing screen RIGHT.
3 E = true right profile facing screen RIGHT.
4 NE = BACK three-quarter facing screen RIGHT, back/right shoulder visible, not front-quarter.
5 N = directly away, full back and rear hair, no face.
6 NW = BACK three-quarter facing screen LEFT.
7 W = true left profile facing screen LEFT.
8 SW = front three-quarter facing screen LEFT.
Rotate the entire torso, pelvis, feet and head coherently; do not merely turn heads. Author genuine views, not synthetic mirrored copies. Rear quarters remain visibly different from front quarters.

Critical invariant: one common anatomical scale for all 32 poses. Head INCLUDING hair crown down to chin about one third of the neutral standing-equivalent height, approximately 18-20 units for a 58-unit standing figure, NEVER a half-height oversized chibi/baby head. Skull dimensions, torso and limb lengths are CONSTANT across all headings and rows. Long hanging rear hair is not an enlarged skull. Below chin retain a real neck, torso, waist, pelvis, thighs, knees, calves and boots. Haara is compact and small primarily by body volume, not a stretched or abbreviated body. Do not fit each figure to its own bounding box. Do not enlarge heads on compressed poses.

Rows top to bottom:
1 JUMPSQUAT / ANTICIPATION: boots planted, knees visibly bent, pelvis lowered, torso balanced, arms bent lightly behind/outward ready to spring. A restrained crouch, posed height approximately 48-51 units with the same 18-20-unit head.
2 RISING TUCKED JUMP: knees distinctly flexed and boots pulled upward/back toward the pelvis, readable tucked lower-leg silhouette; elbows flexed and hands upward/outward for balance. Keep torso real and full-length, do not curl into a sitting ball. Tucked boots must be clearly different from row 3.
3 DESCENDING FEET-READY JUMP: hips and knees open, both boot soles clearly beneath the body with legs near extended and softly bent, feet ready for landing; arms open lower/outward to stabilize. Approximately 56-58 units tall. Never duplicate tucked row 2.
4 DEEPLY COMPRESSED LANDING: both boot soles planted apart, knees bent visibly more than row 1, pelvis lower between the knees, torso naturally leaning forward, arms forward/outward balancing. Approximately 45-48 units tall. Compression comes from actual joint bending only, never skull/torso squash or separate scaling.

One shared cell coordinate system and horizontal root center. Keep matching root/baseline placement across headings, no baked whole-character jump trajectory; game supplies world-height lift. All hands, fingertips, boots, ears and hair tips completely inside each own cell with transparent clearance. Natural occlusion is fine; no missing or extra limbs. Preserve the tunic coverage and dark legwear throughout every action. No upskirt view or exposed torso. Rear hair and clothing maintain consistent length and outline while joints animate.

Style: deliberate crisp pixel-art clusters, clean dark colored outlines, restrained green/gold/cream/brown palette, readable expressive face and top-left material lighting like the primary runtime reference. No smooth painterly reskin, no glossy 3D, no checkerboard painted into the image. Genuine transparent alpha.

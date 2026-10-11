# Treevor the Mason fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation, one initial call, true transparent background requested. No CLI/API fallback.

## Reference paths

1. `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/treevor_mason.png`
2. `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/treevor_mason-detail.png`
3. `C:/Users/sende/Pictures/styleref1.png`

## Exact generation prompt

Use case: stylized-concept.
Asset type: H.E.X. fixed-pixel jump-key sprite-sheet source for ONE existing character, Treevor the Mason (treevor_mason), a large treefolk.

Input images and roles:
Image 1 (assets/sprites/pixel_cast_v1/treevor_mason.png) is PRIMARY CURRENT RUNTIME CANON for identity, broad body volume, head/body proportions, leaf costume, bark face, colors and genuine eight directions.
Image 2 (assets/sprites/fullbody_cast_v1/treevor_mason-detail.png) supports the SAME current identity and detailed anatomy/costume: pointed twig crown, warm brown carved wooden face with bright amber eyes, dense green leaf collar/mantle, broad bark torso and limbs, belt with golden square buckle, hanging green leaf panels, two large segmented gray stone gauntlets flecked with moss, root-toed bare wooden feet.
Image 3 (styleref1.png) is ONLY a charming retro pixel-cluster style reference. IGNORE its old names, labels, character redesigns, weapons, hammer, staff, shields, magic, backdrop and roster arrangement. Do not copy a hammer. Both hands remain EMPTY inside the established stone gauntlets.

Create one true transparent RGBA landscape source sheet, approximately 2048x1024, EXACTLY 8 equal columns by 4 equal rows: 32 complete full-body poses of this SAME character, uniformly spaced with generous transparent gutters. No drawn cell boundaries, text, labels, numbering, logos or background. Every fingertip, twig, leaf and root toe fits comfortably inside its own cell.

EXACT column order in EVERY row:
1 S = front facing viewer;
2 SE = front three-quarter facing screen RIGHT;
3 E = true profile facing screen RIGHT;
4 NE = BACK three-quarter facing screen RIGHT, back and right shoulder visible, not a front view;
5 N = directly away, full back with layered leafy mantle, NO face;
6 NW = BACK three-quarter facing screen LEFT;
7 W = true profile facing screen LEFT;
8 SW = front three-quarter facing screen LEFT.
Turn the WHOLE body naturally through these directions, not just the head. Genuine independently authored orientations, no synthetic mirrored directions.

Rows, top to bottom:
1 JUMPSQUAT/ANTICIPATION: feet fully planted, knees visibly bent, pelvis lowered, balanced forward torso angle, heavy empty stone-gauntleted hands slightly back and outward preparing to jump. Moderately crouched, about 84-88 percent of neutral standing crown-to-sole height.
2 RISING TUCKED JUMP: a clearly AIRBORNE articulated pose, both knees bent and feet modestly folded backward/up beneath the hips, open upright trunk, empty gauntleted arms lifted outward for upward balance. Thighs, knees, shins and wooden feet remain anatomically connected; not a sitting ball. Height about 88-93 percent of neutral standing height. This must read as tucked rise, NOT feet-down descent.
3 DESCENDING FEET-READY JUMP: legs extend downward beneath the trunk, knees softly open, both root-toed feet oriented ready for ground contact; empty arms held outward and forward rather than lifted like row 2. Taller open silhouette, about 97-100 percent neutral standing height. Row 3 leg and arm silhouettes must be unmistakably different from row 2 even when small.
4 COMPRESSED LANDING: both feet planted, visibly deeper knee flexion and lower pelvis than row 1, torso leans anatomically over legs, heavy empty gauntlets spread beside/front of body for stability. Approximately 77-82 percent neutral standing height. Do not merely duplicate row 1. Compression comes ONLY from bent joints, never squash-scaling the trunk, head or limb lengths.

CRITICAL common proportion contract: This is a FULL-BODIED compact adult treefolk with LARGE broad woodbody volume, NOT a giant-headed baby/chibi and not a tall stretched human. Use one shared model scale for ALL 32 cells. Head including twig/leaf crown down to chin is about ONE THIRD of neutral standing crown-to-sole height; never one half. Keep identical skull/crown size across all rows, a substantial distinct bark torso below the chin, waist, pelvis, thick thighs, knees, shins and large root-toed feet. Large size is conveyed primarily by broad torso/shoulders and thick limbs, not extra stretched height. Maintain source identity and male presentation without sexualization. The leafy shoulder mantle is clothing/foliage, not a giant enlarged head. Stone gauntlets remain the same size and construction in every pose.

Registration: same character-root horizontal center in each cell, consistent foot/root baseline per row. Do NOT fit each pose independently to a bounding box and do NOT translate entire airborne sprites upward to simulate world-space jump height; engine supplies that lift. Only articulate body poses at the same underlying scale. Preserve natural occlusion in rear headings while retaining readable hands where possible.

Style: deliberate crisp fantasy pixel-art clusters with clean dark colored outlines, green leaf shading, warm brown wood, cool gray segmented stone gauntlets, gold buckle and consistent top-left light as runtime reference. Charming and readable at small game size, not blurry or painterly.
Hard constraints: EMPTY HANDS, no hammer, tools, weapons, staff, wand, shield, held props, spells, magic, glow, motion trails, dust, ground shadow, floor, environment, checkerboard art, captions, text or watermark. Actual transparent alpha background. Exactly 32 complete non-overlapping sprites.


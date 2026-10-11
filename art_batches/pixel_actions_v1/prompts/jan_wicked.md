# Jan Wicked fixed-pixel jump-key source

Date: 2026-10-03. Built-in image generation; no CLI/API fallback.

Runtime identity: `jan_wicked`, Jan Wicked, ancestry `human`, body type `middle`, from `content/champions/foundation_champions_v1.json`.

Reference paths, in input order:

1. `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/jan_wicked.png`
2. `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/jan_wicked-detail.png`
3. `C:/Users/sende/Pictures/styleref1.png`

All three references were visually inspected before generation. Source output must remain byte-identical to the selected generated PNG. Source-size review is not native-scale, runtime or human acceptance.

## Exact generation prompt

Use case: stylized-concept.
Asset type: H.E.X. Jan Wicked fixed-pixel jump-key source sheet, one character only, true transparent RGBA.

Reference images and roles: Image 1 (assets/sprites/pixel_cast_v1/jan_wicked.png) is the PRIMARY CURRENT RUNTIME CANON for Jan Wicked's face, black hair, dark costume, compact full-bodied proportions and eight headings. Image 2 (assets/sprites/fullbody_cast_v1/jan_wicked-detail.png) supports exact coat construction, fur collar, hands, legs and real profile/rear anatomy. Image 3 (styleref1.png) is STYLE ONLY: charming retro fantasy pixel clusters and colored outlines; ignore ALL its labels, other people, props, weapons and magical effects. Runtime identity is Jan Wicked, a middle-body male human. Do not redesign or change ancestry.

Create exactly 8 columns by 4 rows, 32 complete full-body sprites of this one identical character, approximately 2048x1024 landscape. Equally spaced cells, generous transparent gutters, same common anatomical scale in every cell. Actual alpha transparency, not a checkerboard painting. No text, cell marks, captions, numbering, arrows or background.

Column order in EVERY row:
1 S: directly facing viewer, front torso and both eyes.
2 SE: front three-quarter facing screen RIGHT, front and right side of body both visible.
3 E: strict right profile, nose points screen RIGHT, one eye and one ear, torso and feet truly side-on.
4 NE: BACK three-quarter facing screen RIGHT, mostly back of head and back/right shoulder, rightward nose only a tiny edge if visible; NOT a front-quarter.
5 N: directly away from viewer, full rear torso, back of hair, no face.
6 NW: BACK three-quarter facing screen LEFT, mostly back of head and back/left shoulder; NOT a front-quarter.
7 W: strict left profile, nose points screen LEFT, one eye and one ear, torso and feet truly side-on.
8 SW: front three-quarter facing screen LEFT, front and left side of body both visible.
Draw genuine eight-direction full-body anatomy, not head turns on a front torso. Profiles must be clearly distinct from diagonals; rear quarters must be clearly distinct from front quarters.

Rows from top to bottom:
1 Jumpsquat anticipation: both boots planted, moderately bent knees, lowered pelvis, torso balanced above legs, elbows bent with naturally open empty hands slightly behind/out beside body. A prepared but not fully compressed crouch.
2 Rising tucked jump: airborne-pose knees folded naturally and boots tucked backward/up toward hips; visible bend in thighs, knees and shins, torso remains long and balanced, arms spread upward/outward for balance. This is not a sitting ball and not a standing pose.
3 Descending feet-ready jump: legs unfold down under pelvis, both boots clearly lower and farther from hips than row 2, knees soft but largely extended, empty hands out/forward and slightly lower than row 2. Silhouette must be visibly different from row 2 at small size.
4 Compressed landing: both boot soles firmly planted, knees deeply flexed, pelvis distinctly LOWER than row 1 and settled between spread bent knees, torso leans slightly forward, arms balance forward/outside knees. Stronger knee compression and lower hips than anticipation, never a duplicate row 1.

Identity invariants: preserve the same young-adult masculine human presentation, pale warm skin, expressive serious dark eyes, short tousled layered black hair, charcoal-black long fitted coat with pale silver-gray stitched edge trim, thick gray-white fur collar, front buckles and belt, dark trousers and black boots, dark sleeves and cuffs, visible bare empty hands as reference. Front buckles belong only on the front; rear coat seam/split panels and rear belt belong on the back. Preserve hair shape and skull dimensions, limb lengths, coat construction and body mass for all 32 sprites. No beard, horns, pointed ears, tail or wings.

Fixed proportion contract: when the neutral standing crown-to-sole height is 60 units, the head INCLUDING hair is approximately 19-20 units, about ONE THIRD of standing height, NEVER one half. Below chin retain real neck, torso, waist, pelvis, thighs, knees, calves and boots. Same head size across all four rows. Crouches become shorter by joint rotation, not by shrinking or squash-scaling. Preserve torso and limb anatomical lengths even when folded. Middle body volume, not stretched height or huge chibi head. Do not normalize individual poses to fill their bounding boxes.

Registration: body root stays centered on the same horizontal center within each cell; use a consistent imaginary boot/root baseline. Do NOT translate the entire airborne sprite upward to simulate world-height: the game handles that. Only anatomical pose changes. Complete hair, coat tails, fingertips and boots stay inside their own cells with transparent clearance. Natural rear-hand occlusion is allowed but arms must remain readable.

Style: crisp deliberate retro pixel-art clusters and clean dark colored outlines, restrained charcoal/black/silver/gray palette with warm skin, stable top-left material lighting. Clean readable cloth, fur and hair clusters. Preserve full-body readability rather than adding tiny detail. No weapons, blades, staffs, wands, items, spell energy, particles, glow, ground shadows, floor, dust, motion trails, watermarks or other characters. All hands are empty.

## Source review

One initial generation call, no correction. Original 1774x887 RGBA PNG is copied byte-identically to `source/jan_wicked/source.png`. Source-size inspection found 32 complete sprites, distinct tucked-rise versus feet-ready-fall keys, and a visibly deeper landing than anticipation. Heads remain approximately one-third standing-equivalent height, subject to native measurement by lead. Front-quarter/profile facial angles are close, with torso/coat/boot orientation providing the stronger facing distinction. Dark coat panels naturally occlude some knee detail. Real alpha includes generated partial-alpha pixels and two alpha=1 border specks; no cleanup was performed. Full evidence and limitations are in `source/jan_wicked/receipt.json`. Native-scale, runtime and human acceptance are NOT_RUN.

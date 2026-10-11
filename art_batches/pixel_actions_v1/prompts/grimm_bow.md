# Grimm Bow fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation; one initial call; no CLI/API fallback.

Runtime identity: `grimm_bow`, Grimm Bow, ancestry `troll`, body type `large` from `content/champions/foundation_champions_v1.json`.

## Reference paths

- `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/grimm_bow.png` - primary runtime identity, costume, proportions and headings.
- `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/grimm_bow-detail.png` - supporting costume/anatomy detail.
- `C:/Users/sende/Pictures/styleref1.png` - style only; no names, props or magic adopted.

All three references were visually inspected before generation. The S. Wayne proportion-repair-v3 prompt was read for the common one-third-head proportion contract; its character identity was not reused.

## Exact generation prompt

Use case: identity-preserve.
Asset type: H.E.X. Grimm Bow fixed-pixel jump-chain source sheet, one character, 32 complete full-body sprites with true transparent RGBA.

Input images and roles:
Image 1 (assets/sprites/pixel_cast_v1/grimm_bow.png) is the PRIMARY CURRENT RUNTIME CANON for this exact character's identity, compact full-bodied proportions, costume, colors and eight headings. Preserve this figure; do not redesign.
Image 2 (assets/sprites/fullbody_cast_v1/grimm_bow-detail.png) supports armor construction, purple skin, horns, tusks, black mane and rear/profile anatomy.
Image 3 (styleref1.png) is STYLE ONLY: charming retro fantasy pixel-art clusters and colored outlines. Ignore all old names, race labels, magic, props and weapons in that poster. The runtime roster says Grimm Bow, LARGE TROLL.

Subject: exactly the same masculine broad purple troll, heavy muscular shoulders and torso, thick real arms/legs, purple face, prominent lower ivory tusks, two short pale curved horns, swept black hair and long black back mane. Preserve dark brown/charcoal rounded shoulder armor and forearm/shin guards with warm gold edging and rivets, crossed leather chest straps, broad gold-buckled belt, dark split hip armor, short muted maroon cloth tabs, bare purple fingers and substantial exposed purple toes. His large body is primarily broad volume, not stretched height. No tail, no wings, no added accessories. No bow despite the name.

Create exactly 8 equally spaced columns by 4 equally spaced rows, 32 separate sprites, approximately 2048x1024 landscape. Every sprite is complete and centered within its cell, with generous transparent gutters around horns, fingers and toes. No cell outlines, labels, text or other marks. Fixed gently elevated game camera; rotate actual full-body anatomy rather than rotating only the face. Same scale and same skull dimensions throughout.

Columns in EVERY row, left to right:
1 S = FRONT facing viewer, chest and both eyes visible.
2 SE = FRONT-RIGHT three-quarter, chest still visible, face points screen RIGHT.
3 E = TRUE RIGHT PROFILE, nose/tusk point screen RIGHT.
4 NE = BACK-RIGHT three-quarter, back armor and black mane dominate, face mostly hidden, facing away toward screen RIGHT.
5 N = DIRECT BACK, black mane and rear armor, no face or eyes.
6 NW = BACK-LEFT three-quarter, back armor and black mane dominate, facing away toward screen LEFT.
7 W = TRUE LEFT PROFILE, nose/tusk point screen LEFT.
8 SW = FRONT-LEFT three-quarter, chest still visible, face points screen LEFT.
Author genuine eight-view poses; do not synthesize headings with mirrored pixels.

Rows, top to bottom, each carrying that exact eight-heading order:
1 ANTICIPATION / JUMPSQUAT: feet planted apart, knees visibly bent and pelvis lowered moderately, torso balanced slightly forward, elbows bent and empty hands slightly back/out for the coming jump.
2 RISING TUCKED JUMP: clearly airborne anatomical pose, thighs raised, knees folded and feet tucked backward/up toward hips, toes below or behind knees, elbows lifted and empty hands outward/up for balance. Keep a real torso and visible thigh/shin structure; do not collapse him into a ball. This must be visibly different from row 3 in every heading.
3 DESCENDING FEET-READY JUMP: legs unfold downward underneath pelvis with only soft knee bend; both feet visibly extend lower than row 2 and are ready to receive landing. Arms lower/outward or slightly forward, hands open and empty. Longer leg silhouette than tucked row 2; no duplicate rise poses.
4 DEEP COMPRESSED LANDING: both feet planted wide, deep natural knee and hip bend, pelvis settles low between knees and torso inclines forward. Head crown is visibly lower than row 1 while skull and limb lengths remain unchanged. Arms extend lower/forward/out beside knees for balance; hands stay empty and readable. This is a real loaded crouch produced by joint articulation, never a shrunken or vertically squashed copy.

Proportion contract: head plus hair crown to chin is about ONE THIRD of neutral standing crown-to-sole height, NOT one half. Preserve a common 18-20-unit head on a standing-equivalent 58-60-unit model, scaled uniformly across all 32 sprites. Beneath chin retain a substantial neck/chest, abdomen, belt, pelvis, thighs, knees, calves and feet. Broad shoulder armor may be wider than the head, as in the runtime reference. Do not enlarge heads in crouches, shorten legs, lengthen horns, stretch the torso, or independently fit each pose to its cell. Crouches become shorter only by joints bending. Preserve anatomy, body mass, armor panels, mane volume and gold trim across every direction.

Animation/registration intent: one common model scale and per-cell horizontal root center. Keep comparable foot/root baselines across a row. Do not move entire airborne figures upward to simulate a jump trajectory; game code supplies world-height. Draw only articulated body-pose changes. Rise/fall readable leg and arm differences are crucial.

Style: deliberate crisp pixel-art clusters and clean dark colored outlines, charming compact fantasy tactics character, warm top-left lighting, restrained shading and exact primary purple/brown/gold/black/maroon palette. Clean small-scale silhouettes, not painterly or soft 3D. Genuinely transparent alpha, no baked checkerboard.
Avoid: weapons, bows, arrows, staffs, wands, shields, held items, magic, glow, sparks, spell effects, dust, speed lines, ground shadows, floor, scenery, captions, labels, watermarks, other characters, cropped fingertips/toes/horns. Empty hands only.

## Review boundary

Source-size visual review and untouched-source provenance are recorded in `source/grimm_bow/receipt.json`. Native-scale review, engine/runtime testing and human acceptance are NOT_RUN. Lead owns alpha cleanup, registration, downsampling and integration.

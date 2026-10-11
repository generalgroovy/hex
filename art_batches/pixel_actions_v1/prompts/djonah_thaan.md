# Djonah Thaan fixed-pixel jump source

Built-in image generation, 2026-10-03. One initial call plus one permitted gross-facing correction; no CLI/API fallback. Source-only ticket; no runtime integration or acceptance claim.

## Reference paths

- Primary current runtime identity: `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/djonah_thaan.png`
- Supporting identity detail: `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/djonah_thaan-detail.png`
- Style only: `C:/Users/sende/Pictures/styleref1.png`

## Exact initial generation prompt

Use case: stylized-concept.
Asset type: H.E.X. Djonah Thaan fixed-pixel jump-chain sprite-sheet source; exactly four authored action keys in eight headings.

Input images and roles:
Image 1 (assets/sprites/pixel_cast_v1/djonah_thaan.png) is the PRIMARY CURRENT RUNTIME CANON for this character's identity, face, costume, compact full-bodied proportions, palette and headings.
Image 2 (assets/sprites/fullbody_cast_v1/djonah_thaan-detail.png) supports costume detail and genuine rear/profile anatomy, subordinate to Image 1.
Image 3 (styleref1.png) is STYLE ONLY: charming retro fantasy pixel figures, colored outlines and clustered material shading. Ignore ALL labels, names, races, weapons, effects and unrelated characters in Image 3.

Create one genuinely transparent RGBA sprite sheet, approximately 2048x1024 landscape, exactly 8 equally spaced columns by 4 equally spaced rows, 32 complete full-body sprites of this ONE character. Generous transparent gutters and edge padding. No title, labels, grid lines, captions, numbering, backdrop, floor or shadows.

Canonical subject: Djonah Thaan, a middle-bodied masculine vampire. Preserve his pale white-gray skin, angular face, red eyes, long pointed ears, slick swept-back black hair with widow's peak, black long coat and cape-like rear coat panels, high deep-red collar, red lining and trim, fine gold clasps and edging, gold-buckled belt, dark trousers and black boots. Preserve the reference's menacing but charming face, not a generic different vampire. No hat, wings, tail or added equipment. Both hands EMPTY, naturally visible and usable. No weapons, staffs, props, magic or effects.

Proportion contract: compact but FULL-BODIED, not oversized-head baby/chibi. One invariant model and skull size across all 32 cells. If neutral standing height is 60 units, crown-to-chin including hair is about 19-20 units, roughly ONE THIRD, never half. Beneath the chin retain a real neck, long coat/torso, waist, pelvis, thighs, knees, shins and boots. Body class is middle: moderate torso/limb volume, not stretched tall and not heavy. Never enlarge heads in crouches or shorten anatomy; pose height changes only through natural joint bending. Keep hair shape, skull dimensions, costume panel lengths and limb lengths consistent across headings and rows.

Column order in EVERY row, left to right:
1 S: full FRONT facing viewer.
2 SE: front three-quarter facing screen RIGHT.
3 E: true RIGHT PROFILE, face/nose and both boots orient right; one eye and proper side torso.
4 NE: BACK three-quarter facing screen RIGHT, back/right shoulder readable, not front-right.
5 N: full BACK facing directly away, rear hair and coat panels, no face.
6 NW: BACK three-quarter facing screen LEFT.
7 W: true LEFT PROFILE, face/nose and both boots orient left; proper side torso.
8 SW: front three-quarter facing screen LEFT.
Turn the entire anatomy and costume in every direction, not just the head. Draw genuine directional anatomy; no synthetic mirrored poses.

Rows top to bottom:
1 JUMPSQUAT / ANTICIPATION: boots planted, knees bent, pelvis lowered, torso balanced over legs, empty hands slightly behind/outward preparing lift. Posed height roughly 50-53 of the same 60 standing-equivalent units.
2 RISING TUCKED JUMP: knees naturally bent and drawn modestly upward/back, boots clearly tucked under/behind pelvis, elbows open and empty hands spread for lift/balance. Keep a real extended torso and thigh anatomy; not a sitting ball. Posed height roughly 55-58 units with unchanged 19-20-unit head.
3 DESCENDING FEET-READY: legs open downward beneath the pelvis, knees softly flexed, both boots extended down ready for contact, arms forward/outward for balance. A visibly different arm AND leg silhouette from tucked row 2. Posed height roughly 58-60 units with unchanged head.
4 DEEP COMPRESSED LANDING: both boots planted and separated, deeply bent knees, pelvis lower than row 1, torso leaning naturally forward and arms balancing beside/forward. Clearly deeper and shorter than anticipation, roughly 46-49 units. Do not scale or flatten the skull or torso.

Registration: one common model scale and sprite-cell coordinate system throughout; NEVER fit or rescale each pose to its own bounding box. The body root stays horizontally centered in each cell with matching per-direction roots. Do not bake in upward world translation for airborne rows: the game supplies jump trajectory. Change only anatomical poses. Complete fingertips, coat tails, ears, hair and boot soles must remain inside each cell with transparent clearance. Rear hands may be naturally partly occluded, but do not hide both arms. Coat movement follows jumping body and stays consistent, not a rigid replacement silhouette.

Style: deliberate crisp pixel-art clusters, clean dark colored outlines, restrained black/deep-red/gold palette with pale skin, top-left material highlights, charming retro readability at small native game size. True transparent alpha, no painted checkerboard, no colored matte, no antialias haze, no watermark, text, decoration, ground shadow, glow, dust or speed lines.

## Exact final correction prompt

Edit target: `C:/Users/sende/.codex/generated_images/01a100d5-be6d-7f83-b29d-2b0041b8e65f/exec-66397483-2f3c-4506-a46d-2548bc93f08f.png`

Use case: identity-preserve.
Edit target: Image 1 is the newly generated Djonah Thaan 8-column by 4-row jump-sheet source. Correct the GROSS FACING DEFECT ONLY in columns 3 and 7 throughout all four rows. Other columns 1, 2, 4, 5, 6 and 8, grid positions, four action states, costume, anatomy, skull scale and transparency are preservation references: do not redesign or alter them.

Column 3 is E and MUST be a strict RIGHT PROFILE facing screen right, a 90-degree side view of the entire head AND torso AND pelvis AND knees AND boots. Nose projects horizontally to the RIGHT; only the right-facing side of the pale face and ONE eye are visible. Do NOT show both eyes or a broad front chest. The two shoulders overlap in depth, the gold front clasp is near the right edge of the torso, and the coat's back is on the LEFT. All hands and feet articulate in a genuine SIDE-ON body. No front-right three-quarter pose.
Column 7 is W and MUST be a strict LEFT PROFILE facing screen left, a 90-degree side view of the whole body. Nose projects horizontally to the LEFT; only the left-facing side of the face and ONE eye are visible. Shoulders overlap in depth, gold front clasp near the LEFT edge of the torso, coat back on the RIGHT. No front-left three-quarter pose. Draw genuine directional anatomy, no synthetic mirrored pasted pose.

For these side columns preserve the existing four row actions:
row 1 planted bent-knee anticipation;
row 2 airborne tucked rise, knees and boots folded back, arms out balancing;
row 3 descending with legs OPENED DOWNWARD and both boots reaching below the pelvis ready to land, distinct from tucked rise;
row 4 planted deep compressed landing with pelvis lower and knees more bent than anticipation.
Preserve full anatomical limb lengths and exactly the same crown-to-chin head size in all four rows. Head remains approximately one third neutral standing height, not half. Never stretch, squash or individually rescale a sprite. Full compact middle-bodied masculine vampire, pale white-gray face, pointed ears, black swept-back widow's-peak hair, red eyes, black long coat, deep-red high collar and red lining/edge, gold clasps and belt, black trousers and boots. Empty pale hands, no props, no weapons, no magic.

Keep exactly 8 columns by 4 rows, 32 complete sprites with generous transparent gutters. Facing sequence remains S front; SE front-right; E STRICT RIGHT PROFILE; NE back-right; N full back; NW back-left; W STRICT LEFT PROFILE; SW front-left. Do not shift rows or columns. All extremities stay in their cells. Preserve genuinely transparent RGBA alpha and the crisp clustered pixel-art style, no checkerboard pixels, floor, shadow, text, labels, glow, dust, decoration or watermark.

# Steezo fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation only; one initial generation.

Runtime identity: `steezo`, display name `Steezo`, ancestry `goblin`, body type `small`, verified in `content/champions/foundation_champions_v1.json`.

## Reference paths

- Primary runtime identity: `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/steezo.png`
- Supporting identity detail: `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/steezo-detail.png`
- Style only: `C:/Users/sende/Pictures/styleref1.png`
- Proportion contract read: `C:/Users/sende/Projects/hex/art_batches/pixel_actions_v1/prompts/s_wayne.md` (successful v3 contract)

All three image inputs were viewed before generation. Original output will be copied byte-identically; no cleanup, resampling or runtime changes are part of this ticket.

## Exact generation prompt

Use case: stylized-concept.
Asset type: transparent production pixel-art sprite-sheet source for existing H.E.X. character Steezo; exactly four authored jump-chain key poses in eight directions.

Input image roles: Image 1, assets/sprites/pixel_cast_v1/steezo.png, is the PRIMARY CURRENT RUNTIME CANON for identity, exact compact full-bodied proportions, costume, colors and eight headings. Image 2, assets/sprites/fullbody_cast_v1/steezo-detail.png, supports costume detail and genuine profile/rear anatomy. Image 3, styleref1.png, is STYLE ONLY: charming retro fantasy pixel clusters and colored outlines; ignore all labels, other characters, weapons, props and magic from that image.

Subject: ONE character only, Steezo, runtime ancestry GOBLIN and body_type SMALL. Preserve the green-skinned male-presenting goblin's pointed long ears, short dark swept-up hair, round cyan-blue goggles in gold/brass rims across his forehead/upper face, expressive green face and small nose, brown/dark charcoal leather coat with brass/gold piping and shoulder armor, belt and square golden buckle, brown gloves, dark trousers and sturdy brown boots. Exactly this costume and palette, not a new steampunk redesign. Both hands empty and naturally usable; no bomb, staff, weapon, gadget, spell, sparks or glow. Preserve skull, anatomical limb lengths, outfit panels and body volume across all poses.

Proportion contract: compact but FULL-BODIED adventurer, not baby/chibi. Head including hair crown to chin is about ONE THIRD of neutral standing crown-to-sole height. Use one standing-equivalent common scale of 60 units and a constant 19-20-unit head for all 32 sprites. Below the chin preserve an actual torso, waist, pelvis, thighs, knees, calves and boots; no oversized head resting directly on tiny torso and feet. Small body class is expressed by compact body volume, not omitted legs or a giant skull. Do not stretch height or independently resize any pose to fill a bounding box.

Layout: one genuine transparent RGBA sheet, approximately 2048x1024 landscape, exactly 8 equal columns and 4 equal rows, 32 complete full-body sprites. Generous transparent gutters around all ears, fingertips and boot soles. No frames, borders, names, text, numbers, headings, arrows or markings.
Exact column order in EVERY row:
1 S: faces viewer, full front;
2 SE: front three-quarter facing screen RIGHT;
3 E: true screen-RIGHT profile;
4 NE: BACK three-quarter facing screen RIGHT, back/right shoulder clearly visible;
5 N: directly away, full back;
6 NW: BACK three-quarter facing screen LEFT;
7 W: true screen-LEFT profile;
8 SW: front three-quarter facing screen LEFT.
Whole torso, pelvis, boots and head must genuinely face the correct heading. Rear views show back of hair, goggle strap and rear coat panels, never faces on backs. Draw all eight directions independently, no synthetic mirrored headings.

Rows top to bottom:
1 JUMPSQUAT / anticipation: boots planted, knees bent, lowered pelvis, torso balanced over legs and elbows lightly bent with empty hands away from hips. Posed height about 51-54 units with same 19-20-unit head.
2 RISING TUCK: airborne rising pose with knees clearly folded and feet tucked slightly backward/upward, torso upright with full anatomical length, elbows lifted outward for balance. Posed height about 53-56 units; do not curl into a sitting ball.
3 DESCENDING FEET-READY: legs visibly OPEN and almost extended downward beneath the pelvis, knees soft, both boot soles oriented ready to land; arms lower and slightly forward/outward for balance. Posed height about 58-60 units. This row MUST have a clearly different leg and arm silhouette from the tucked second row in every heading, not a duplicate or another tuck.
4 COMPRESSED LANDING: both boots planted and spread enough to support the body, knees deeply bent, hips lowered between knees, slight natural torso inclination and hands outward for balance. Posed height about 47-50 units, distinctly deeper than row 1. Compress through real joint rotation, never squash or scale head/torso.

Registration: single common character scale and cell coordinate system across all 32 cells; same skull size and limb lengths. Root horizontally centered in each cell. Keep a consistent imaginary root/feet baseline within rows. Do not translate the airborne characters upward to simulate trajectory; the game supplies world-height lift. Only anatomical pose changes.
Style: deliberate crisp pixel-art clusters, clean dark colored outlines, compact readable forms, warm brown/brass material shading with green skin and cyan goggles, subtle consistent top-left light matching runtime reference. No soft painted blur, photographic detail or noisy microtexture. Genuinely transparent alpha, no checkerboard or colored matte baked into pixels, no floor, ground shadow, dust, effects, environment or watermark. Every body, hand, ear and boot is complete inside its own cell.

## Source review

One 1774x887 RGBA sheet generated and reviewed at source size. It contains 32 complete sprites in the expected 8-column, 4-row facing/action sequence, with empty hands and no visible cell-border, caption, shadow, prop or gross clipping. Row 2 visibly tucks knees and lifts arms; row 3 opens the legs beneath the pelvis and lowers arms; row 4 is visibly more compressed than row 1. Rear-quarter descent retains some knee flex and foreshortening, so its readability still needs native-scale review. Source-size head/body continuity looks generally consistent, but exact native skull-size continuity and the one-third proportion target are not quantitatively certified.

The original is copied byte-identically to `source/steezo/source.png`. SHA256: `6785b9a7032f02eafc0d4214d7b6d910d79e94acc2b2cd109f33f7fd9472f5a5`. Genuine transparency is present; partial alpha is retained unchanged for lead-owned deterministic assembly. No corrective generation was performed. Native-scale, runtime and human acceptance: `NOT_RUN`.

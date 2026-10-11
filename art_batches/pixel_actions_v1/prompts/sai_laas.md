# Sai Laas fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation; one initial call plus one gross-facing/proportion corrective call, no CLI/API fallback.

Scope: one small nymph identity, four authored jump key poses in eight directions. Source-only work; native-scale/runtime/human acceptance is NOT_RUN.

## Reference paths and roles

- Primary runtime identity and proportions: `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/sai_laas.png`
- Supporting costume and anatomy detail: `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/sai_laas-detail.png`
- Style only, not canonical names or props: `C:/Users/sende/Pictures/styleref1.png`

## Exact initial generation prompt

Use case: stylized-concept.
Asset type: H.E.X. Sai Laas fixed-pixel jump-key sprite sheet, one character, four authored action keys in eight genuine headings, true transparent RGBA.

Input references and priority: Image 1 (assets/sprites/pixel_cast_v1/sai_laas.png) is the PRIMARY CURRENT RUNTIME CANON for exact identity, small body proportions, costume, colors and genuine facings. Image 2 (assets/sprites/fullbody_cast_v1/sai_laas-detail.png) supports readable costume details and rear/profile anatomy. Image 3 (styleref1.png) is STYLE ONLY: charming compact fantasy pixel figures with colored outlines and deliberate clustered shading; ignore ALL its names, ancestries, props, weapons, magic and other characters. Do not turn Sai Laas into the long-haired robed nymph Haara pictured in Image 3.

Create one transparent source sheet approximately 2048x1024 landscape, exactly 8 equally spaced columns by 4 equally spaced rows: 32 complete full-body sprites of the SAME Sai Laas. Wide transparent gutters around each sprite, no printed grid or labels. Every extremity stays safely inside its cell.

Identity: Sai Laas, small nymph. Preserve the primary reference's warm peach skin, expressive green eyes, long pointed ears, short swept-up/spiky auburn-copper hair with green leaf accents and layered green leaf hair at the back/nape; not long flowing teal hair. Preserve the fully clothed forest adventurer outfit: layered green leaf tunic with copper/orange-gold edges, brown leather shoulder pieces and bracers, brown belt with rectangular brass buckle, dark fitted trousers, sturdy brown boots. Keep its modest youthful-adventurer gender presentation as pictured; no sexualization, no exposed chest, no exaggerated body curves. No new wings, tail or decorative accessories. Both hands EMPTY, naturally usable for balancing and hand casting, without any spells.

Proportion contract is critical: head INCLUDING hair crown down to chin is approximately ONE THIRD of hypothetical neutral standing crown-to-sole height, NOT one half. At a common illustrative neutral standing equivalent of 58 units, head plus hair measures about 18-20 units. Keep real neck, torso, waist, pelvis, thighs, knees, lower legs and boots. SAME skull size, anatomical limb lengths and body scale in ALL 32 cells. Compact does not mean huge-headed baby/chibi. Crouching lowers height by knee and hip articulation only; never squash anatomy or rescale individual poses to fit their bounding boxes.

Columns in EVERY row, strictly left to right:
1 S: directly front, faces viewer.
2 SE: FRONT three-quarter facing screen RIGHT.
3 E: true full RIGHT profile.
4 NE: BACK three-quarter facing screen RIGHT, back/right shoulder and rear leaf panels clearly readable.
5 N: full BACK, directly away, no face painted on back.
6 NW: BACK three-quarter facing screen LEFT, back/left shoulder.
7 W: true full LEFT profile.
8 SW: FRONT three-quarter facing screen LEFT.
Rotate the whole torso, pelvis and feet correctly, not only the head. Author each direction genuinely, do not copy/mirror the opposite direction.

Rows top to bottom:
1 ANTICIPATION / JUMPSQUAT: both boots planted, moderately bent knees, lowered pelvis, torso balanced over feet, bent elbows, empty hands open beside body. Approximate posed height 48-51 units on the common 58-unit standing model scale.
2 RISING TUCKED JUMP: knees fold naturally and both boots are visibly tucked back/up under thighs, arms open upward/outward for balance. Preserve torso and limb length; do not curl into a seated ball. A readable tucked-leg silhouette, unlike the next row.
3 DESCENDING FEET-READY JUMP: knees and hips open, legs nearly extend down beneath the pelvis, both boot soles ready below the body, soft knees; elbows bend with empty hands forward/outward. Visibly different leg and arm silhouette from the tucked rising row. Approximate posed height 56-58 units, same 18-20-unit head.
4 DEEP COMPRESSED LANDING: both boots planted broadly, knees much more deeply flexed than row 1, pelvis lower between knees, torso naturally inclined, arms low/forward to balance. Visibly deeper compression than anticipation, yet real joint bending with unchanged skull/body/limb dimensions; no squash stretching and no enlarged crouching heads.

Registration: all sprites share one common body scale and their cell center/root. Keep consistent implied local root/feet baselines across corresponding headings; do not bake whole-character upward world translation into airborne poses. The game supplies jump trajectory. Pose height may change only through articulation, not per-frame scaling.

Style: crisp deliberate retro pixel-art clusters, clean dark colored outlines, green/copper/brown palette and top-left material shading from primary reference. Readable expressive faces without overlarge heads. True transparent background with alpha, not a checkerboard drawing or colored matte. No floor, cast shadows, dust, movement lines, glow, fire, leaves blowing around, magic effects, weapons, staff, wand, props, names, captions, grid borders, numbering or watermark.

## Corrective reference paths

- Edit target, initial generated source: `C:/Users/sende/.codex/generated_images/01a100e4-5d74-7862-a3c7-88f0aeb806d7/exec-04b2130f-5c6b-4b45-88ec-030e845849c1.png`
- Primary proportion/identity reference: `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/sai_laas.png`
- Supporting full-body detail: `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/sai_laas-detail.png`

## Exact final corrective prompt

Use case: identity-preserve.
Edit target: Image 1 is Sai Laas's newly generated 8-column by 4-row jump-key sprite sheet. Make one corrected version fixing TWO gross defects: the incorrect column-2 facing and oversized heads. Keep the actual character, costume, four pose rows, generous gutters and genuine transparency.
Reference image 2 (current runtime assets/sprites/pixel_cast_v1/sai_laas.png) is the PRIMARY PROPORTION/IDENTITY CANON. Reference image 3 (fullbody_cast_v1/sai_laas-detail.png) supports full torso/leg length. Their short spiky copper/auburn hair, green leaf hair at nape, green eyes, pointed ears, fully clothed green/copper leaf tunic, leather shoulder pieces/bracers/belt, dark trousers and brown boots are invariants.

PROPORTION FIX across ALL 32 sprites: shrink head including hair crown to chin by approximately 25 percent relative to Image 1 and restore taller torso and anatomically complete thighs/lower legs like Image 2. In a hypothetical neutral standing crown-to-boot-sole height of 58 units the head+hair must measure only 18-20 units, approximately ONE THIRD, never half. Keep one common 18-20-unit head and same real limb lengths across all cells. Compact FULL-BODIED nymph adventurer, NOT huge-headed chibi/baby. Skull must not enlarge in crouches. Keep leaf-tunic torso, pelvis and leg segments visible below chin rather than placing a large head directly on tiny legs. Compression comes solely from joints, not scaling.

FACING FIX: Column 2 in Image 1 incorrectly looks toward SCREEN LEFT. Redraw EVERY column-2 sprite looking 45 degrees toward SCREEN RIGHT with front chest still visible: nose and gaze offset toward the RIGHT side of its cell, near left ear readable at the LEFT outer head edge; torso/pelvis/boots also turned front-right. Column 2 must be the actual right-facing counterpart of column 8, not another left-front pose, and should be between column 1 front and column 3 right profile.
All rows MUST follow this exact eight-heading sequence: 1 S front faces viewer; 2 SE FRONT-RIGHT toward screen right; 3 E true RIGHT profile; 4 NE BACK-RIGHT with back visible and face toward screen right; 5 N full back; 6 NW BACK-LEFT with back visible and face toward screen left; 7 W true LEFT profile; 8 SW FRONT-LEFT toward screen left. Genuinely draw different directional anatomy, not synthetic mirroring.

Keep four row actions with clear silhouettes: row 1 moderate knees-bent planted anticipation; row 2 airborne RISE with boots tucked up/back and arms spread upward; row 3 airborne FALL with legs open and boots extending down beneath pelvis ready to land, hands forward/outward; row 4 DEEP planted landing with hips between deeply bent knees, lower than row 1, arms low/forward. Preserve common skull/body scale and real limb lengths across all rows. Row 2 tucked legs must not become row 3 extended legs.
Exactly 8 equally spaced columns by 4 rows, 32 complete full-body sprites, approximately 2048x1024 landscape, all ears/hair/hands/boots entirely inside cells, consistent root center, no baked upward whole-character translation. Crisp retro pixel clusters and colored outlines as runtime references, not smooth illustration. Modest fully clothed presentation.
TRUE transparent RGBA with no floor, background, checkerboard art, shadows, text, grid lines, weapons, staffs, wands, baked magic, glow, dust or other effects. Empty hands. No other characters.

## Source review and handoff

The final corrective image is copied byte-identically to `source/sai_laas/source.png`. It has 32 complete poses, transparent alpha and distinct rising/falling/landing silhouettes. Column 2 now faces screen right, but SE and E remain too similar, and heads still look too large relative to the one-third standing-height requirement. Candidate status is HOLD for lead proportion/direction review, not approved runtime source acceptance. No third call was made.

Generated partial alpha is retained unchanged. Actual occupied row bands are y=86-237, 268-429, 468-647 and 700-834 inclusive at alpha >=128. Raw equal-height canvas quarter cropping would clip/cross the first visual row; assembly and registration remain lead-owned. Native-scale, runtime and human acceptance: NOT_RUN.

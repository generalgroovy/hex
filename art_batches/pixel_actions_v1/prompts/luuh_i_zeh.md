# Luuh I Zeh fixed-pixel jump-key source

Date: 2026-10-03. Built-in image generation only; one source-art ticket.

Canonical roster identity: `luuh_i_zeh`, Luuh I Zeh, `spiderkin`, `small`, verified in `content/champions/foundation_champions_v1.json`.

## Reference paths (inspected before generation)

- C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/luuh_i_zeh.png — primary runtime identity and anatomy.
- C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/luuh_i_zeh-detail.png — supporting costume and appendage detail.
- C:/Users/sende/Pictures/styleref1.png — style only, not names/races/props.
- C:/Users/sende/Projects/hex/art_batches/pixel_actions_v1/prompts/s_wayne.md — textual v3 proportion contract, not an image-generation input.

## Exact generation prompt

Use case: stylized-concept.
Asset type: H.E.X. production pixel-art source sheet for Luuh I Zeh, one small Spiderkin character, four authored jump-chain keys in eight genuine directions.

Input image roles:
Image 1 (assets/sprites/pixel_cast_v1/luuh_i_zeh.png) is PRIMARY CURRENT RUNTIME CANON: preserve its precise recognizable anatomy, compact full-bodied proportions, face, purple chitin, dark purple armor with fine gold trim, yellow eyes, spiked crown silhouette, and established heading appearances.
Image 2 (assets/sprites/fullbody_cast_v1/luuh_i_zeh-detail.png) supports anatomy and costume detail ONLY. Match the number and attachment sites of its characteristic jointed back appendages; do not redesign them as wings, weapons, or random extra limbs.
Image 3 (styleref1.png) is STYLE ONLY: charming retro fantasy pixel clusters and colored outlines. Ignore ALL its names, races, props, weapons, magic and backgrounds.

Create a new genuine transparent RGBA image approximately 2048x1024, exactly 8 equal columns by 4 equal rows, 32 complete full-body sprites of ONLY this same Spiderkin. Every sprite entirely inside its cell with generous transparent gutters and clearance around every back appendage, fingertip, toe and head spike. No captions, text, numbered cells, lines, grid marks or checkerboard art.

Column order in EVERY row:
1 S, front directly facing viewer;
2 SE, front three-quarter facing screen RIGHT;
3 E, full right profile;
4 NE, BACK three-quarter facing screen RIGHT, back/right shoulder clearly readable;
5 N, full rear directly away, no face visible;
6 NW, BACK three-quarter facing screen LEFT;
7 W, full left profile;
8 SW, front three-quarter facing screen LEFT.
Rotate the whole anatomy and armor consistently, not only the head. No synthetic mirroring. The primary image owns exact appearance; this specified facing order is mandatory.

Rows top to bottom:
1 JUMPSQUAT anticipation: two main feet planted, knees bent, pelvis moderately low, empty main hands drawn back/out beside body. Back appendages naturally held clear.
2 RISING tucked jump: visibly bend knees and fold lower legs backward/up underneath pelvis; feet clearly tucked, not simply dangling. Two empty main hands spread up/out for balance. Keep torso length and skull size unchanged, do not curl into a baby-like sitting ball. Back appendages articulate at their existing joints and remain identifiable.
3 DESCENDING feet-ready: clearly untuck both legs, knees slightly soft, feet extended DOWN beneath the pelvis ready for contact; empty main hands forward/out for balance. Make leg and arm silhouettes distinctly different from row 2, without stretching anatomical limb lengths.
4 DEEP COMPRESSED LANDING: main feet planted wider, knees deeply flexed, pelvis visibly lower than row 1, torso leaned forward naturally; head and torso NOT squashed or scaled. Hands out/forward to balance. More deeply compressed than anticipation through real joint bends.

Identity and proportion invariants: the same small compact purple-and-gold Spiderkin in all 32 poses, non-sexualized and faithful to the reference presentation. This is a biped humanoid core with TWO main arms and TWO main legs, PLUS ONLY the established two pairs of thin jointed spider appendages attached to the back as seen in the primary reference. No added arms, fingers, feet, tails, random antennae, wings, giant spider abdomen, or conventional eight-legged spider body. Keep those four back appendages consistent in attachment, length, joints and count, allowing natural direction-dependent occlusion. Empty main hands throughout.
Head INCLUDING crown/spikes is about ONE THIRD of neutral standing crown-to-sole height, NOT one half; below chin preserve genuine torso, waist, pelvis, thighs, knees, calves and feet. Keep skull dimensions, armor panels, body volume, limb lengths and colors constant across headings and poses. Smallness comes from compact body volume, never enlarged chibi head or shortened missing shins.

One common model scale for the entire sheet. Never fit or resize poses to their bounding boxes. Keep per-direction body roots horizontally centered within cells, comparable foot/root baselines across cells; no baked whole-character upward trajectory because world height is supplied by the game. Only anatomical pose changes. Deliberate crisp pixel-art clusters, clean dark-purple colored outlines, readable purple/gold armor shading with consistent top-left light, yellow eyes without glow effects.
Absolutely no weapons, props, floor, ground shadow, dust, magic, spell effects, glows, environment, watermark or backdrop. True transparent alpha.

## Review boundary

Source-size visual review only. Deterministic alpha cleanup, registration, downsampling, native-scale comparison, engine import, runtime capture and human acceptance remain lead-owned. Native-scale/runtime/human acceptance: NOT_RUN.

## Exact corrective prompt (gross rear-quarter facing defect)

Corrective image inputs, in order:

1. C:/Users/sende/.codex/generated_images/01a100d7-1174-73b0-bf1f-f0d1bf874fe0/exec-b6b7dd8e-c888-4ea1-b5c1-3c68cc3a3602.png — initial generated sheet, rejected for front-facing rear quarters.
2. C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/luuh_i_zeh.png — runtime reference.
3. C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/luuh_i_zeh-detail.png — supporting detail.

Use case: identity-preserve.
Edit target Image 1 is the generated 8-column by 4-row Luuh I Zeh jump sprite sheet. It has a GROSS DIRECTION ERROR: columns 4 and 6 show faces/front armor when they must be BACK three-quarter. Correct this facing defect across all four rows, retaining the same sheet layout, transparency, identity, armor, compact body volume, exact skull size, and jump row poses.
Image 2 is current runtime identity/directional anatomy. Image 3 is supporting detail. Use their TRUE rear-quarter back/shoulder views to repair.

Mandatory columns 1 through 8 in EVERY row: FRONT, FRONT-RIGHT, RIGHT PROFILE, BACK-RIGHT, FULL BACK, BACK-LEFT, LEFT PROFILE, FRONT-LEFT. This is a turntable progressing smoothly around the same character, not repeated front-right portraits.
Column 4 BACK-RIGHT must show the BACK of the head and neck, rear armor and right shoulder; the face points away from viewer toward screen-right. NO visible yellow eye, NO front chest panel, NO frontal belt. Four back appendage roots are readable from behind.
Column 6 BACK-LEFT must show the BACK of the head and neck, rear armor and left shoulder; the face points away from viewer toward screen-left. NO visible yellow eye, NO front chest panel, NO frontal belt. It must be different from column 7 left profile.
Keep column 5 full back, no face. Columns 3 and 7 are clean true side profiles, with only one yellow eye visible and torso side-on. Columns 2 and 8 are FRONT quarters. Columns 4 and 6 need distinctly more back view than profile. Do not merely turn the head, rotate complete torso/pelvis/feet/appendage anatomy.

Maintain 8 columns x 4 rows, 32 complete sprites and generous transparent gutters. Rows unchanged in intent: row 1 planted bent-knee anticipation; row 2 airborne rise with knees folded and feet clearly tucked up; row 3 descent legs untucked and feet beneath body ready to land; row 4 genuinely deeper compressed landing with knees bent, pelvis lower than row 1, no body squash.
Same small purple-chitin Spiderkin and dark purple gold-edged armor; two main arms with empty hands, two main legs, and exactly two paired sets of jointed back spider appendages established in reference. NO new appendages or redesign. Main head/crown-to-chin about one-third neutral standing height, same skull and full-bodied real torso/limb proportions throughout. Do not increase the head. No per-cell fitting or scaling. No baked upward translation.
True transparent RGBA, preserve alpha. Crisp retro pixel clusters and colored outlines. No props, weapons, magic, shadows, environment, labels or other marks.

## Historical v2 source review: HOLD

One initial call and one permitted gross-facing correction were made. The corrected output is preserved byte-identically as `source/luuh_i_zeh/source.png`; the generated original and rejected initial output remain in their generated-images location.

Source-size review found a complete 8-by-4 grid, readable tucked rise versus feet-ready descent, and a visibly deeper landing. However, columns 4 and 6 still do not convincingly rotate the torso to rear-quarter; removing/obscuring most eyes did not resolve the anatomical direction. Row 3 column 6 still shows a yellow eye. Back appendages merge into broad plate/wing-like clusters and their canonical jointed count is not reliably readable. The crown/head also appears large compared with the one-third-standing-height target, which has not been validated at native scale. The source is HOLD, not integration-ready. No additional generation calls were made.

Actual PNG: 1774x887, RGBA, 1032086 fully transparent pixels, 540882 partially transparent pixels, 570 fully opaque pixels. Original alpha is untouched; deterministic cleanup remains lead-owned. SHA256: `495547F96C747AE54CED621C4355A7D17651A9BCCACCF94188EE34495F1D5D98`.

## Authorized clean regeneration v3

The lead confirmed a gross rear-torso defect including the full-back front gold bib and explicitly authorized one additional clean generation. Before replacement, both earlier outputs were copied byte-identically to `source/luuh_i_zeh/source-v1-facing-defect.png` and `source/luuh_i_zeh/source-v2-facing-defect.png`. No rejected sheet is used as a v3 input or pose guide.

Sole image input: C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/luuh_i_zeh.png, re-inspected and hash reverified, for current face/costume identity.

### Exact v3 generation prompt

Use case: stylized-concept.
Create a NEW clean transparent pixel-art animation source sheet: Luuh I Zeh, the small purple Spiderkin from the provided runtime reference. Use Image 1 ONLY for face, purple/gold costume identity and general small biped shape. Do not copy its animation poses or treat its rear gold trim as front-facing armor. This is a genuine rotating 3D-anatomy turntable across each row, NOT eight variants of the same frontal torso.

A modest small purple Spiderkin, slim compact full body, yellow eyes, swept spiky purple crown, purple chitin, dark purple fitted armor with restrained gold edges. Head including crown is exactly about one-third neutral standing height; plenty of torso and real legs below chin. Avoid huge armored beetle bulk, oversized skull, wingbug shapes, or baby proportions.
Anatomy: two normal humanoid arms with empty hands, two normal legs/feet, PLUS exactly FOUR DISTINCT NARROW JOINTED SPIDER APPENDAGES rooted on the upper back: two on each side. Each of these four back appendages is a slim angular bent rod, with clear transparent gaps between the appendages. They are NOT wings, NOT membranes, NOT broad plates, NOT extra hands. Keep those four separate appendages constant across poses, with natural occlusion in side views.

Transparent RGBA landscape sheet, approximately 2048x1024. Exactly 8 columns and 4 rows, 32 complete separate sprites. Generous equal gutters and margins, no cell borders or text, no cropped fingers, crown, feet or appendages. One identical character model scale throughout. No props, weapons, magic, glow, ground shadows or floor.

Eight mandatory directions, columns left to right in EVERY row:
1 SOUTH = full FRONT facing the viewer: two yellow eyes, front breastplate and small front gold detail visible.
2 SOUTHEAST = FRONT-RIGHT three-quarter, face and chest aimed diagonally toward viewer and screen right.
3 EAST = TRUE RIGHT SIDE PROFILE, body side-on, one yellow eye, narrow edge of chest. Arms, knees and toes face right.
4 NORTHEAST = TRUE BACK-RIGHT three-quarter. See back of skull, back of neck, BACK of right shoulder, DARK REAR CARAPACE and rear pelvis. Face points AWAY and right. ZERO visible yellow eyes. ZERO frontal chest/bib/buckle. The four distinct jointed back appendages visibly originate on the upper back. Arms, knee armor and feet all rotated away toward right.
5 NORTH = DIRECT FULL BACK. Back of spiky head with NO face, rear shoulders, plain DARK PURPLE REAR CARAPACE, rear pelvis, backs of calves and heels. NO yellow eyes, NO FRONT GOLD BIB, NO FRONTAL BELT BUCKLE, NO FRONT LOIN PANEL, no kneepads facing the viewer. FOUR separate thin jointed back appendages and their upper-back roots visible with gaps. Both arms seen from behind.
6 NORTHWEST = TRUE BACK-LEFT three-quarter. Back of head, rear left shoulder, DARK REAR CARAPACE; face points AWAY and left. ZERO visible yellow eyes. ZERO front breastplate/bib/buckle. Both limbs, armor and feet rotate away toward left, never just a turned head.
7 WEST = TRUE LEFT SIDE PROFILE, one yellow eye, whole body side-on; arms, knees and toes aimed left.
8 SOUTHWEST = FRONT-LEFT three-quarter, face and chest aimed diagonally toward viewer and screen left.
Columns 4, 5 and 6 must read unmistakably as BACK VIEWS of the entire body. Their back carapace is anatomically different from the front gold-trimmed breastplate. Never solve rear views by erasing eyes from a front-facing body.

Four action rows:
Row 1: JUMPSQUAT anticipation, both feet planted, bent knees, moderately lowered pelvis, arms held back/out. Modest crouch.
Row 2: RISING AIRBORNE TUCK, knees genuinely folded, lower legs and feet pulled up underneath pelvis, hands spread up/out for balance. Same skull and torso, only joints bend. Back appendages stay separated.
Row 3: DESCENDING FEET-READY, main legs visibly untucked and extended down below pelvis with soft knees, soles ready to land, hands forward/out. Very clearly different silhouette from tucked row 2.
Row 4: DEEPEST LANDING, feet planted apart, deep knee bend and low hips, natural forward torso lean, arms forward/out. Visibly lower than row 1 by joint flexion, NOT by resizing or squashing.

Preserve skull size, body volume, limb lengths, appendage count/length, outfit and common drawing scale across ALL cells. Maintain local root centering and do not bake upward jump trajectory into rows. Crisp deliberate retro pixel-art clusters and dark colored outlines, restrained purple/gold highlights, recognizable expressive face only where visible. No blurry rendering, fake transparency checkerboard, mirror-copy substitutes, watermark or labels. True transparent background.

### Latest v3 review: HOLD, improved candidate

The clean generation materially improved full-back anatomy: column 5 now shows dark segmented rear carapace and heels rather than the earlier frontal gold bib. The four narrow back appendages are more clearly separated with transparent gaps, although overlap remains in profile. All 32 sprites are complete, rise is tucked, descent is untucked, and landing is compressed.

The all-heading requirement is still not satisfied. Column 3 E remains too similar to column 2 SE rather than a clean pure profile across the rows. Column 7 W also reads as a forward-biased quarter/profile. Column 8 SW is nearly full-front instead of a clear front-left quarter. Rear-quarter heads retain thin yellow eye slivers, clearly including row 1 columns 4 and 6, despite the zero-eye rear-quarter requirement. Thus no claim is made that every heading is correct. Skull/volume continuity, exact appendage counts under occlusion and one-third neutral-standing head proportion still need lead-owned native-scale checking.

Latest `source.png` is copied byte-identically from C:/Users/sende/.codex/generated_images/01a100d7-1174-73b0-bf1f-f0d1bf874fe0/exec-89bbac3f-1600-483d-be63-d1c0ee6ece09.png. SHA256: `C8C0629720A718C69429362D6B286A89ECCBB70425BB341462022A844D945E4D`. Dimensions 1774x887, RGBA; 1106829 fully transparent, 465583 partially transparent, 1126 fully opaque pixels. No image pixels were edited or cleaned. This uses the one additionally authorized clean-generation call, three calls total including v1 and v2. Native-scale/runtime/engine-import/human acceptance: NOT_RUN.


## Authorized surgical heading repair v4

The lead explicitly authorized ONE built-in imagegen edit of v3, limited to zero-based columns 2 (E), 6 (W), and 7 (SW) across all four rows. Before editing, v3 was copied byte-identically to `source/luuh_i_zeh/source-v3-facing-defect.png`; SHA256 `C8C0629720A718C69429362D6B286A89ECCBB70425BB341462022A844D945E4D`. Earlier v1/v2 originals remain untouched. Exactly one edit call was used, bringing historical total to four calls.

Sole image input/edit target: C:/Users/sende/Projects/hex/art_batches/pixel_actions_v1/source/luuh_i_zeh/source-v3-facing-defect.png. Runtime atlas, fullbody detail, style reference and the existing final-review board were inspected for context but were NOT passed as edit inputs.

### Exact v4 edit prompt

Use case: identity-preserve.
Asset type: H.E.X. Luuh I Zeh jump-key sprite sheet, surgical heading repair.
Input Image 1 is the EXISTING SOURCE SHEET TO EDIT, not a loose style reference. Keep this same image: exactly 8 columns x 4 rows, 32 full-body sprites, same canvas and uniform grid, existing genuinely transparent background. Preserve the source's pixel-art rendering, small compact purple Spiderkin identity, spiky crown, yellow eyes, dark purple armor with fine gold trim, exact skull/body proportions and scale.

CHANGE ONLY THREE COLUMNS across all four rows: zero-based columns 2, 6, 7 (the THIRD, SEVENTH, EIGHTH columns counting from the left). Leave zero-based columns 0, 1, 3, 4, 5 completely unchanged. Do not regenerate, re-pose, re-center or restyle the unaffected sprites. Do not change the back views, their dark rear carapace or rear limb anatomy. No face on the full back.

THIRD COLUMN / zero-based 2 = EAST, exact 90-degree SIDE PROFILE facing IMAGE RIGHT. The existing version wrongly repeats front-right three-quarter. Turn the WHOLE head, torso, pelvis, knees and feet fully right, so there is ONLY ONE VISIBLE YELLOW EYE and NO FAR EYE whatsoever. The far cheek, far eye, front of breastplate and frontal belt panel are occluded, not presented to the viewer. Skull is a clean side silhouette, face at right edge. Chest is a narrow edge viewed side-on, with one leading arm and one leading leg visible; far arm and far leg are behind/occluded. Both toes point right. Do not simply erase one eye while leaving a frontal body. A true narrow profile distinctly different from the SECOND column.

SEVENTH COLUMN / zero-based 6 = WEST, exact 90-degree SIDE PROFILE facing IMAGE LEFT. Rotate the entire head, torso, pelvis, knees and feet fully left. ONLY ONE VISIBLE YELLOW EYE, NO FAR EYE, no frontal chest/belt view, face at left edge of skull. One leading arm and leg visible, far limbs occluded behind. Both toes face image left. Draw genuine left-facing anatomy with the source's existing lighting; no mirrored-copy substitute.

EIGHTH COLUMN / zero-based 7 = SOUTHWEST, strong unmistakable 45-degree FRONT-LEFT THREE-QUARTER, NOT STRAIGHT FRONT. Head, chest, pelvis, knees and feet ALL aim diagonally toward viewer and IMAGE LEFT together. Show the near side broad and far side visibly foreshortened: nose/face offset toward left, asymmetrical eye presentation, foreshortened chest width, nearer arm and leg offset, toes pointing diagonally left. It must be clearly distinct from full-front FIRST column and pure-left SEVENTH column. Never rotate just the face over a frontal torso.

Within the edited columns retain the original row actions: row 1 planted anticipation crouch; row 2 rising with knees and feet tucked up; row 3 descending with legs untucked and feet ready below body; row 4 deep compressed landing, lower pelvis by genuine knee bending, not shrinking. Preserve original anatomical limb lengths, skull dimensions, body volume, costume and pose scale. The head including crown stays about one-third neutral standing height; do not enlarge the head or shorten the torso. Two main arms with empty hands, two main legs, plus EXACTLY FOUR NARROW JOINTED SPIDER APPENDAGES rooted on upper back, two each side. Thin bent rods with transparent gaps, naturally occluded in exact profiles; never broad wings or plates, never additional appendages.

Keep every complete crown, fingertip, foot and appendage inside its existing cell with transparent gutters. No weapons, props, effects, magic, shadows, environment, labels, grid lines, watermark, extra sprites or baked checkerboard. Preserve true transparent alpha. ONLY the third, seventh and eighth columns are allowed to change.

### Latest v4 source review: HOLD

The returned sheet retains 32 complete sprites in an 8-by-4 layout, transparent gutters, purple/gold identity, genuine full-back torso, distinct tucked rise and feet-ready descent, and deeper landing. SW now has a more evident leftward three-quarter head/body presentation instead of repeating straight front. E and W have greater limb overlap and a single conspicuous eye, but still expose substantial frontal chest/hip armor and forward-biased head/limb anatomy. Exact 90-degree side profiles are NOT confirmed, so the all-heading requirement remains unmet. Rear-quarter yellow eye slivers remain in the intentionally untargeted columns. The four appendages are narrow rather than broad wings, but exact counts under occlusion remain unverified.

The generator also changed pixels in non-target columns despite the explicit preservation instruction; this output is not an exact masked-column repair. The preserved v3 source is available for lead-owned assembly, but this worker did not composite, mirror, paint, clean alpha, resample or register any image. Source-size inspection only does not establish exact skull/volume continuity or one-third head proportion at native scale.

Current `source.png` is copied byte-identically from C:/Users/sende/.codex/generated_images/01a100ec-d5a1-7f62-b703-377d2b0f6faf/exec-7dbe5c8c-5972-4e05-930a-b2472b6cb1ae.png. SHA256: `4A3DBF4B59CF52CEFB5C182AECA1B00A44F5DAB7ADAFA9C13277C0BF49DBCE11`. Dimensions 1774x887, RGBA; 1057687 fully transparent, 515371 partially transparent, 480 fully opaque pixels. Source and generated-original hashes match. Native-scale/runtime/engine-import/human acceptance: NOT_RUN. No runtime, shared builder, manifests, engine or imports were changed.


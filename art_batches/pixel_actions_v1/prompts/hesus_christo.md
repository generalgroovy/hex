# Hesus Christo fixed-pixel jump source

Date: 2026-10-03. Built-in image generation, one initial call plus one explicitly authorized functional landing correction. Source-art scope only; no runtime integration or acceptance.

## Reference paths

- C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/hesus_christo.png — primary current runtime identity and proportions.
- C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/hesus_christo-detail.png — identity, costume and direction detail.
- C:/Users/sende/Pictures/styleref1.png — pixel-art style only; old identity labels explicitly excluded.

## Exact generation prompt

Use case: identity-preserve.
Asset type: H.E.X. Hesus Christo fixed-pixel jump-key sprite sheet; exactly 32 complete poses of ONE character; genuinely transparent RGBA.

Input image roles:
Image 1 (hesus_christo.png) is PRIMARY CURRENT RUNTIME CANON for identity, costume, face, anatomy proportions and eight facings.
Image 2 (hesus_christo-detail.png) is supporting identity, costume-panel and rear/profile anatomy detail.
Image 3 (styleref1.png) is STYLE ONLY: charming retro fantasy pixel figures, crisp colored outlines and clustered material shading. Ignore ALL its labels, races, names, props and characters. The old green dragon labelled Hesus Christo is NOT this character and must NOT appear.

Canonical subject: Hesus Christo, a middle-body male-presenting ELF, as Images 1 and 2. Warm light tan skin, long sharply pointed ears, expressive dark eyes, swept layered black hair with long nape, forest-green fitted tunic/coat armor with gold edging and shoulder panels, gold center chest detail, brown belt with gold buckle, green split coat panels over dark trousers, brown forearm bracers and brown boots. Hands EMPTY. No horns, scales, tail, wings, dragon anatomy, weapons, staffs, wands or spell effects. Preserve current costume colors and the confident youthful face, without redesign.

Proportion contract: one shared anatomical scale for ALL 32 sprites. Keep a compact FULL-BODIED elf with a real neck, torso, waist, pelvis, thighs, knees, shins and boots. Head including hair crown through chin approximately 18–20 units when neutral standing crown-to-sole would be 58 units: about ONE THIRD standing height, NOT half. The skull and hair volume stay constant across every row; do not enlarge heads in crouches or shorten limbs. Longer nape hair is hair lying down the back, NOT a giant skull. No baby-doll proportions, huge head, tiny torso or omitted shins. Compression comes only from joint bending.

Composition: approximately 2048x1024 landscape, exactly EIGHT equal columns by FOUR equal rows, 32 distinct complete sprites, generous transparent gutters all around every figure. All hands, ears, hair and boots entirely inside each cell. Equal cell centers; no borders, grid, headings, text, captions, numbers, arrows or watermark.
Every row has EXACT column directions:
1 S: full front, facing viewer.
2 SE: front three-quarter facing screen RIGHT.
3 E: true profile facing screen RIGHT.
4 NE: BACK three-quarter facing screen RIGHT, back and right shoulder clearly visible; NOT a front quarter.
5 N: full back, facing away, no face on rear.
6 NW: BACK three-quarter facing screen LEFT, back and left shoulder visible.
7 W: true profile facing screen LEFT.
8 SW: front three-quarter facing screen LEFT.
Whole torso, pelvis, feet and head turn together. Draw genuine direction-specific poses, not synthetic mirrored figures.

Four action rows, top to bottom:
ROW 1, anticipation/jumpsquat: both boots planted, moderately bent knees and lowered pelvis, natural forward lean, elbows bent and empty hands lightly back/out. Crown-to-sole about 48–51 units with SAME 18–20-unit head.
ROW 2, rising tucked jump: knees visibly bend, boots fold back/up under the body, torso and thighs remain anatomical and open; arms lift/spread out for balance, empty hands distinct from row 1. A recognizably AIRBORNE TUCKED silhouette, not standing and not curled into a sitting ball. SAME head and limb lengths.
ROW 3, descending feet-ready jump: untuck and extend legs beneath hips, knees soft, both boots clearly below body ready to land; arms shift forward/out for landing balance. Crown-to-sole about 56–58 units. Visibly DIFFERENT leg and arm silhouette from tucked row 2 in EVERY facing. SAME 18–20-unit head.
ROW 4, compressed landing: both boots fully planted and spread for stability, knees flex substantially more deeply than row 1, pelvis settles down between knees, torso inclines naturally with empty hands forward/out for balance. Clearly deeper crouch than first row, approximately 43–47 units high, SAME head scale. Do not squash or resize torso or head to lower the pose.

Registration: common character model scale across sheet, never independently fit or enlarge each pose to fill its cell. Consistent horizontal root center per cell. No whole-character vertical jump trajectory baked into placement; world lift is added by the game. Change anatomical pose only.
Pixel-art finish: preserve runtime green/gold/brown/black palette and charming expressive style, crisp colored pixel outlines, discrete readable shading clusters; no soft painted blur, no photorealism. Transparent alpha background, no checkerboard pixels, no colored matte, floor, ground shadow, dust, environment, glow or VFX. Exactly one same elf repeated in all 32 cells, no extra characters or objects.

## Source-size review

Single initial call returned a 1774x887 RGBA source, copied byte-identically to `source/hesus_christo/source.png`. All 32 full-body figures and requested heading sequence are present. Green/gold costume, black hair, pointed elf ears and empty hands are retained; no old wyrm identity, weapons or effects appear.

The source is complete for lead review, not accepted for runtime integration. Row 2 has raised balancing arms and a tucked silhouette; row 3 lowers/reaches the arms and extends the lower envelope, but its knees remain visibly bent. The landing changes arm placement but is not convincingly deeper than anticipation: alpha>=128 whole-row envelope heights are 129, 157, 176 and 132 source pixels. This is a HOLD for the intended deeper landing and native-scale rise/fall readability. Head scale appears broadly consistent at source size but has not been measured at native scale. No gross grid, facing or cropping defect was found, so no corrective generation was spent on the remaining pose refinement. Original partial alpha is preserved for lead-owned deterministic cleanup. Native-scale, runtime, rendered transitions and human acceptance remain NOT_RUN.

## Authorized landing correction

The lead confirmed the landing defect on `review/pose-check/boards/hesus_christo.png` and explicitly authorized one targeted edit. The original was preserved byte-identically as `source/hesus_christo/source-original-v1.png` before replacement. The only image-generation edit reference was that preserved original. The review board was inspected but not supplied as a generation input.

### Exact correction prompt

Use case: identity-preserve.
Edit target: Image 1 is the existing transparent 8-column by 4-row jump-key sprite sheet for Hesus Christo, a black-haired male elf in forest-green and gold clothing. It is the exact edit target, not a loose style suggestion.

Make ONE targeted functional correction: replace ONLY the fourth/bottom row with a much deeper, convincingly compressed landing. Preserve the FIRST THREE ROWS as closely and exactly as possible: their character designs, action poses, facing order, pixel scale, dimensions and spacing must remain unchanged. Retain the same landscape canvas and exact 8 columns x 4 rows (32 complete sprites), true transparent alpha and ample gutters.

The existing fourth row is too similar to row 1. In every one of the EIGHT bottom-row facings, lower the pelvis noticeably between deeply flexed knees; both brown boots fully planted with the feet visibly wider apart; thighs slope out/down, knees strongly bent, heels stay down. Tilt the intact torso forward naturally over the lowered pelvis. Bring elbows outward and hold empty hands out/forward to counterbalance, with a visibly wider arm silhouette than anticipation. This is the compressed impact instant after landing, not a standing guard pose and not sitting on the ground.
IMPORTANT measurable silhouette change: bottom-row hair crown should sit about 20–25 percent of the first-row posed body height LOWER than the corresponding first-row crown, relative to a common foot baseline. Lower the head by genuine knee/hip flexion, NOT by shrinking the head or squashing any body part. This is a deep athletic crouch with connected pelvis, thighs, knees, shins and boots visible wherever naturally possible.
Do not merely move the entire character down or shift its arms while leaving the squat unchanged. Do not enlarge the crouch to fill its cell. No body part changes anatomical length or volume.

Strict preservation: SAME skull and hair-envelope size as rows 1–3, same ear length, face, long layered black hair, warm tan skin, green/gold tunic and coat panels, brown bracers, gold belt buckle, dark trousers, brown boots. Head size is approximately one-third neutral standing height, never enlarged or reduced for the crouch. Maintain one consistent common character scale. No severed, extra, missing or fused limbs. Both hands empty and natural.

BOTTOM-ROW heading sequence must remain exactly:
1 S full front facing viewer;
2 SE front-right three-quarter;
3 E true right-facing profile;
4 NE back-right three-quarter with back/right shoulder;
5 N full back facing away;
6 NW back-left three-quarter;
7 W true left-facing profile;
8 SW front-left three-quarter.
Body, pelvis, face and feet agree on direction; back views do not show faces. Keep complete hair, ears, fingertips and boot soles inside their own cells.

Preserve crisp clustered retro pixel-art style and palette; no blur or redesign. Absolutely no text, row labels, grid outlines, arrows, checkerboard artwork, floor, background, shadow, dust, glow, spell effects, weapons, staffs or extra objects. Genuine transparent RGBA background. First three rows preserved; only bottom row receives the deeper landing correction.

### Corrected-source review

The untouched correction is now `source/hesus_christo/source.png` (1774x887, SHA256 `dc4252841eeaf069913bb6eb615ae9322ca373d66e10b903a2435b520d91350c`). The landing has wider planted boots, lower hips between flexed knees and outward counterbalancing elbows in every facing. All 32 figures are complete and the green/gold elf identity, heading order and approximate head scale remain. First three rows are visually close but re-rendered, not pixel-identical.

The requested 20-25 percent crown-height reduction was not achieved: alpha>=128 whole-row envelope heights are 133/162/181/129 source pixels, so landing is only approximately 3 percent shorter than anticipation. Its improvement comes chiefly from broader feet, pelvis and arm silhouettes. This is a corrected candidate for lead review, not an acceptance claim. Descending knees remain somewhat bent. Corrected native-scale, runtime, rendered transitions and human acceptance remain NOT_RUN. No second correction was attempted; both original generated files remain preserved.

# S. Wayne fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation; no CLI/API fallback.

Scope: one identity, four authored key poses in eight directions. This is not a full animation-cycle or human-acceptance claim. Existing ground banks and original images remain unchanged.

Reference roles are specified in the exact prompt below. New output is preserved unmodified under `source/s_wayne/` before any lead-owned deterministic assembly.

## Exact generation prompt

Use case: stylized-concept.
Asset type: transparent production sprite-sheet source for the existing H.E.X. character S. Wayne; four authored jump-chain key poses, not a storyboard.

Input images and roles: Image 1 (s-wayne.png from pixel_body_pilot_v1/source) is the PRIMARY identity, exact compact proportions, outfit, color and eight-facing reference. Preserve that specific character, not an alternate redesign. Image 2 (styleref1.png) is STYLE ONLY: charming compact fantasy pixel figures, colored outlines and clustered material shading; ignore ALL its labels, other characters, magic and weapons. Image 3 (s_wayne-detail.png) is supporting costume and genuine rear/profile anatomy reference only; primary Image 1 owns the compact body and face.

Create one genuinely transparent RGBA sprite sheet, approximately 2048x1024, exactly 8 equally spaced columns and 4 equally spaced rows (32 complete sprites), with generous transparent gutters and no cell borders, titles, labels, numbering, arrows or other marks.
Column order in EVERY row must be exactly:
1 S = faces viewer/front;
2 SE = front three-quarter facing screen RIGHT;
3 E = true right profile;
4 NE = back three-quarter facing screen RIGHT (back/right shoulder readable, NOT front three-quarter);
5 N = directly away, full back;
6 NW = back three-quarter facing screen LEFT;
7 W = true left profile;
8 SW = front three-quarter facing screen LEFT.
Draw genuine eight-direction anatomy; never turn just the head while keeping a front torso.

Rows, top to bottom:
1. Crouched jump anticipation: planted bare feet, visibly bent knees and lowered pelvis, torso balanced over legs, arms bent lightly away from torso, both empty hands readable.
2. Compact airborne rise/apex: knees naturally folded and feet lightly tucked, body open and balanced, arms and hands comfortably spread for balance. Do NOT stretch the torso or enlarge the head.
3. Descending feet-ready: hips and knees opening, both feet ready beneath body for landing, hands forward/outward in a balanced usable pose. Clearly distinguish this from tucked row 2.
4. Compressed landing: both bare feet contact ground, knees flex more deeply than row 1, pelvis low, upper torso inclined naturally but not flattened, arms balance beside body, hands stay visible. Real joint bending only, never a squash-scaled body.

Identity invariants: SAME compact male hobbit figure as Image 1, warm brown skin, dark tightly curly rounded hair, warm expressive face, big dark eyes; purple short gold-trimmed coat with central belt/gold buckle, dark short trousers and bare substantial feet. Preserve consistent skull width/height, limb length, body mass, costume panels, neckline and gold trims across every pose and heading. Keep primary reference's small compact body, not tall adult proportions. Full body including toes and all hands must remain inside its cell. Rear views have rear coat panels and back hair, not faces painted on the back.

Registration and animation intent: one common sprite-cell coordinate system and one common body scale across all 32 cells; NEVER rescale individual poses to their bounding boxes. Crouches become shorter by joints bending, skull stays same-sized. Center the body's root over the same horizontal center in every cell. Keep a consistent imaginary feet/root baseline within each row's cells. Do not translate the entire airborne sprite upward to simulate a jump trajectory: world-height lift is supplied by the game. Only change anatomical pose. No ground shadow, floor, dust, speed lines, baked glow, spell VFX, weapons, props, caption, watermark or colored matte. Empty hands must remain naturally usable for hand casting without any spell drawn.
Style: deliberate crisp pixel-art clusters with clean dark colored outlines, readable at small native game size, same purple/gold/brown palette and top-left lighting as primary source. Preserve actual transparent alpha, no checkerboard baked into pixels.

## Review status

The initial 1774x887 transparent source is preserved as `source/s_wayne/source-v1.png`. It has 32 complete sprites and the expected direction sequence, but anticipation and landing look too similar. A targeted correction is preserved as `source/s_wayne/landing-correction-v2.png`. Select only its bottom row: upper rows also changed despite the preservation instruction. Selected source is v1 rows 0-2 plus correction v2 row 3. The landing is more clearly bent at the knees with planted spread feet; source-size review found no cropped extremity or gross facing swap.

All eight headings and complete empty hands are present, but rear hands can be partly occluded naturally. These are four authored keys, not completed cycles or independently authored cast poses. Exact native-scale skull/volume continuity and timing remain unverified. Both PNGs retain generated partial alpha; approved threshold128 cleanup and hidden-RGB removal must occur in deterministic assembly, leaving originals intact. Full crop bands, hashes, reference roles and review limits are recorded in `source/s_wayne/receipt.json`. Runtime, import, native capture and human acceptance are not performed by the source-art worker.

## Native proportion cross-review: HOLD v1/v2

Lead comparison against the actual runtime atlas found that v1/v2 heads occupy approximately half the body, versus the intended approximately one-third in the58px standing character. Uniform whole-body scaling cannot repair this without a large size jump. Both versions are rejected for runtime integration pending a proportion-specific repair. Original files remain preserved; the earlier source-size check is not native acceptance.

## Latest source candidate: proportion-repair-v3

`source/s_wayne/proportion-repair-v3.png` is the current source candidate. Use all four rows from v3 together, not the superseded v1/v2 selection. It visibly reduces the head and restores torso/leg length while retaining the eight facings. At illustrative common scale58/195, complete row envelopes are approximately46.4/56.2/58/43.1px; the landing remains deeper than the requested47-50px target. Do not enlarge the landing independently or use per-pose fitting to hide this. Rough source-size head estimate is19-20px at that scale, but exact native comparison remains pending with the lead. No native-size, rendered-transition or human approval is claimed.

## Exact proportion-repair prompt

Use case: identity-preserve.
Asset type: H.E.X. S. Wayne fixed-pixel jump-key sprite sheet, a proportion-corrected NEW VERSION, true transparent RGBA.
Input image roles:
Image 1 (assets/sprites/pixel_cast_v1/s_wayne.png) is the PRIMARY CURRENT RUNTIME CANON for head/body proportions and exact identity. Preserve this compact but FULL-BODIED adventurer, NOT a large-headed baby/chibi redesign.
Image 2 (assets/sprites/fullbody_cast_v1/s_wayne-detail.png) supports the longer purple jacket, torso, limbs and readable anatomy.
Image 3 (source-v1.png) supplies ONLY the four intended action rows and eight-facing order. Its heads are TOO LARGE and bodies/legs TOO SHORT, so DO NOT copy its proportions.

Specific correction: relative to Image 3, reduce head+hair envelope substantially and restore the longer jacket/torso and actual leg length visible in primary Image 1. Retain the exact primary face, dark tight curls, warm brown skin, purple gold-trim jacket, belt, dark trousers and bare feet. Head size remains CONSTANT for all32 sprites. Measure head including hair crown down to chin as approximately18–20 units when the character's neutral standing crown-to-sole height would be58 units. Thus head is about ONE THIRD of standing height, never one half. Below chin, keep a real neck/torso, waist, pelvis, thighs, knees, calves and feet. In front/back views do not let the head sit directly on a tiny coat and feet. Long purple jacket with gold edge extends to upper thighs. No baby-doll proportion, no huge hair ball, no shortened torso or omitted shins.

Layout: exactly8 columns by4 rows,32 distinct complete sprites, equally spaced wide transparent gutters. One common model scale for ALL cells. Approximately2048x1024 landscape. No headings, labels, cell outlines, numbers, shadows or backdrop.
Directions every row: S front facing viewer; SE front-quarter screenRIGHT; E full profile screenRIGHT; NE BACK-quarter screenRIGHT with back/right shoulder; N full back; NW BACK-quarter screenLEFT; W full profile screenLEFT; SW front-quarter screenLEFT.
Rows:
1 jumpsquat/anticipation: knees bent, feet planted, torso over pelvis, total posed crown-to-sole height about48–51 units with SAME18–20-unit head.
2 rising/near-apex: knees gently folded backward, feet tucked only modestly; torso and thigh anatomy stay extended and balanced, total posed height54–57 units with SAME18–20-unit head. Do NOT curl into a sitting ball.
3 descending feet-ready: legs nearly extend beneath body, knees soft and feet ready; total posed height56–58 units with SAME18–20-unit head.
4 compressed landing: deep but anatomical bent knees, lowered pelvis, feet planted, total posed height47–50 units with SAME18–20-unit head. Do not scale or squash the torso to compress it.

The numerical proportions are important: the body must remain longer than Image3 while the head becomes visibly smaller. Do not make all32 sprites fit their own bounding boxes: one standing-equivalent58-unit common scale and18–20-unit head across sheet. Keep matching per-direction roots, no baked whole-character jump trajectory, no floor or shadow; only pose changes. Bent elbows and visible empty hands held ready for balancing and hand casting, no hidden-arms pose, no weapons or magic. Preserve all toes and fingertips inside own cell. Crisp colored pixel outlines, clustered purple/gold cloth shading and warm expressive face as current runtime. Transparent background with actual alpha, no checkerboard art. NO extra characters, VFX, glow, text or watermark.

## Exact targeted correction prompt

Use case: identity-preserve.
Edit target: Image 1 is the newly generated 8-column by 4-row S. Wayne jump sprite sheet. Correct ONLY the fourth/bottom row. The first three rows, their spacing, character scale and pixels are preservation references and must remain unchanged. Retain genuine transparent alpha.

Bottom-row correction: make a convincingly compressed landing pose in all eight headings, visibly different from first-row anticipation. Keep both bare feet fully planted on the same baseline; bend knees deeply out/forward and lower pelvis by joint rotation, so the hair crown is approximately 12 percent of the standing character height lower than in first row. Hips settle between bent knees; thighs and lower legs remain anatomically connected and visible where not naturally occluded. Maintain exactly the same skull dimensions, limb lengths, body volume, purple/gold costume, curly hair, face and skin. DO NOT shrink, squash, stretch, warp or scale the head or torso. Torso can lean forward naturally with gold belt and coat maintaining shape. Arms held comfortably out and slightly forward to balance, both hands visibly empty and usable for hand casting. This is a real bent-joint crouch landing, not a shorter duplicate produced by scaling.

Keep entire sheet at the same 8-column by 4-row layout, generous transparent gutters, exact facing sequence in every row: front S; front-right SE; right profile E; back-right NE; direct back N; back-left NW; left profile W; front-left SW. Never swap the rear quarters or turn only heads. Preserve first three rows exactly. No text, labels, watermark, ground, shadows, effects, weapons or props. Keep all complete toes, hands and hair inside their own cells.

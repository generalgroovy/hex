# S. Wayne south contact pilot

Built-in imagegen; 2026-09-08. Original outputs retained unchanged. No runtime promotion.

## Initial generation

Use case: stylized-concept
Asset type: original FLUX game sprite source, THREE poses only.
Input images: Image 1 is S. Wayne identity reference (dark-skinned adult male Hobbit, black curled hair, pointed ears, charcoal long coat, plum waistcoat/cuffs, ivory collar, restrained brass trim and chain, bare Hobbit feet). Image 2 is the original Oh Tipi STYLE reference only: intentional crisp pixel clusters, natural articulated body proportions, charming expressive face, carefully layered materials. Do not transfer Oh Tipi fins, scales, teal skin, trident, magic or costume to S. Wayne.
Primary request: draw exactly the SAME S. Wayne three times in one horizontal row, three equally wide cells. All three face straight SOUTH toward the camera, full body visible, equal standing body scale, same head/torso/limb lengths. Left cell idle; middle cell walk contact A; right cell walk contact B. This is a small-body58px gameplay target, so simplify material details into strong clusters. Do not draw tiny final58px figures on a large canvas; provide crisp source figures at the same large drawing scale to be downsampled together later.
Pose clarity is essential: left cell neutral relaxed ready stance with both feet grounded evenly. Middle cell anatomical RIGHT leg (image-left) reaches toward camera and plants LOWER in the image; anatomical LEFT leg (image-right) is behind with visibly bent knee and raised heel. Anatomical LEFT arm (image-right) swings forward while right arm swings back. Right cell reverses those anatomical roles: LEFT leg (image-right) reaches forward and plants LOWER; RIGHT leg (image-left) bends behind with raised heel; RIGHT arm swings forward and LEFT arm back. Make the two walking silhouettes visibly opposite, not the same pose with different toes. Keep costume asymmetry and chain on the SAME anatomical side; never mirror the whole character.
Technical output: genuinely TRANSPARENT RGBA background with zero-alpha outside the three body-and-clothing silhouettes and between limbs. No simulated checkerboard, white/black/magenta matte, parchment, floor, grid, shadow, caption, typography, number or border. Empty hands, no equipment, no spell, no aura, no glow, no particles.
Style: sharp pixel-art edges, no soft painted blur or antialiased haze. Natural adult proportions and compact Small stature, not a baby/chibi oversized head. Match skin darkness and clothing identity faithfully. All three figures fully isolated with generous transparent gutters and comparable soles/baseline. Three figures only, one row.

## Single allowed targeted correction

Use case: background-extraction.
Edit target: the supplied three-pose S. Wayne sprite source.
Change ONLY the background into GENUINE TRANSPARENCY with an actual RGBA alpha channel. The gray and white checkerboard currently visible is baked into the source RGB pixels; REMOVE it completely to zero alpha, including between fingers, arms, legs and coat tails. Do not draw a replacement checkerboard or a white/black/colored matte. The delivered PNG must have real transparent empty regions.
Preserve the existing three character silhouettes, exact idle/walk-A/walk-B poses, reversed planted legs and arms, image layout, equal body measurements, dark skin, face/hair, all charcoal/plum/ivory/brass clothing and side-specific chain. Do not redraw, restyle, resize or mirror any subject. Preserve crisp pixel edges without halos. No shadows, floor, text, grid, props or effects. Output the same three isolated characters on actual transparent pixels, not a preview rendering of transparency.

## Observed QA

Both outputs are 1774x887 RGB24 with baked checkerboard pixels, not alpha.
Neither source is approved for sprite import. No deterministic background removal
or additional generation was performed. The initial source shows genuinely
opposite planted-foot and arm silhouettes, and keeps the chain on the same side;
native58px clarity and exact body registration still require a valid cutout.

## Authorization update

User explicitly approved reviewed background removal and assembly after the above
two built-in attempts. Source-v1 was retained as the better input; a hash-locked
edge-connected neutral-checker rule is in source-layout-v1.json. OriginalRGB files
remain unchanged. The native3-pose review is a separate derived resource.

## East companion source

Use case: identity-preserve.
Asset type: FLUX Small-body S. Wayne animation source; exactly THREE full-body figures in one horizontal row.
Input image: identity, anatomy, costume, drawing scale and three-contact reference. Produce a matching EAST-facing strip; this is not a new character design.
Change only camera/body orientation to a true EAST right-facing SIDE PROFILE for every figure, not front-three-quarter. Left cell idle standing; middle walk A; right walk B. Preserve the same adult dark-skinned Hobbit, head size, curled black hair, pointed ears, charcoal long coat, plum lining/waistcoat, ivory collar, brass trim/chain, bare feet, proportions and pixel-cluster style. Empty hands. Keep body/camera scale and source canvas framing equivalent to the input: three equally spaced figures around the same standing height, aligned at a common floor baseline, generous gutters, no per-pose size changes.
Both walk profiles need unmistakably opposite ANATOMICAL contacts: in the middle cell the near leg extends straight to screen-right/front while the far leg bends trailing screen-left; the far arm swings forward and near arm back. In the right cell the far leg extends to screen-right/front and the near leg bends trailing screen-left; the near arm swings forward and far arm back. Swap limb overlap and knee/ankle positions clearly, not just move the toes or repeat the A drawing. Do not mirror the character; the coat fastenings/chain stay on the correct anatomical side.
Technical background: genuine transparent RGBA with no painted checkerboard if possible. No floor/shadow, effect, glow, staff, weapon, prop, letters, numbers, arrows, border or grid. Complete silhouettes with clear gaps around feet and hands. Keep intentionally crisp pixels, no soft blurred rendering.
Three figures, one row, all looking exactly right.

Observed: actual right-facing profiles and opposite arms, but the two leg
silhouettes appear repeated rather than clear anatomical contact reversal.
East walk-B is NOT accepted; this page is preserved for targeted correction.

## East targeted contact correction

Use case: precise-object-edit. Edit target: this three-pose right-facing S. Wayne strip.
Change ONLY the legs and feet of the RIGHTMOST walking figure, plus the minimal lower coat hem occlusion needed around those legs. Leave the first two figures completely unchanged. Leave all heads, torsos, arms, clothing identity, body measurements, camera profile, positions, scale and background unchanged.
The rightmost figure must be the true opposite leg contact to the middle figure. Currently both show the same near-leg-forward silhouette. For the RIGHTMOST figure, bend the visible NEAR knee up and toward screen-left/back, with its bare heel lifted near the rear of the body; put that NEAR foot visibly behind. Extend the FAR leg forward to screen-right, emerging from BEHIND the bent near thigh and shown partly occluded at the hip. Draw the nearer folded thigh in front of the far straight thigh, reversing the current limb overlap. Show a clear bent near-knee shape at screen-left rather than another identical long near-leg diagonal to screen-right. The near arm already swings forward and must stay forward, opposite the now trailing near leg.
Keep a natural walking stride, not a kicking/jumping pose. One planted forward foot, one raised trailing heel. No mirroring, no new prop, no text, no extra figures. Same precise EAST right-facing profile and source scale. Preserve all pixel-cluster material details outside the changed leg area.

Observed v2: the near leg now visibly folds behind, in front of the straight far
leg, while the near arm remains forward. This removes the repeated-leg silhouette.
It is a candidate pending native comparison; no wholesale page mirroring occurred.

## Back idle headings N/NE/NW

Use case: identity-preserve.
Asset type: FLUX S. Wayne Small-body directional sprite source, exactly THREE full-body figures in one horizontal row.
Input image is the identity, anatomy, clothing and source-scale reference. Draw the SAME dark-skinned Hobbit S. Wayne in three different STANDING IDLE headings. Left cell exact NORTH centered BACK view; middle cell NORTHEAST rear-right three-quarter looking away toward upper-right; right cell NORTHWEST rear-left three-quarter looking away toward upper-left.
Change only the view and natural idle arm/foot stance. All three have BOTH feet grounded evenly, hands empty at the sides, no walking or jumping. Keep the same standing body height, modest adult head/body proportions, curled black hair, pointed ears, charcoal long coat with plum inside and small brass/gold details, dark trousers and bare Hobbit feet. Same body dimensions/drawing scale/canvas framing as the supplied three-figure horizontal sheet; same soles baseline and generous gutters. Small58px final target after ONE common downscale, so preserve crisp readable pixel clusters and identity rather than adding fine noise.
For NORTH show the back of the curled hair, back of ears, back of collar/coat with sensible center seam and two lower tails; NO face, eyes, front tie, waistcoat buttons or front gold chain painted onto the back. For NE/NW show mostly back plus correct side, not a clean right/left profile and not a frontal chest. Rotate the actual body and asymmetric costume; do not mirror shortcuts. Keep the left/right anatomical ornament placement consistent.
Technical backdrop: actual transparent RGBA empty pixels preferred; no painted transparency grid. No text, labels, frame borders, weapons, staff, bags, magic, halo, ground, floor shadow or effects. Three complete isolated silhouettes, one row, natural adult proportions, sharp original pixel-art style.

## West/front-diagonal idle headings W/SW/SE

Use case: identity-preserve.
Asset type: FLUX S. Wayne Small-body directional sprite source, exactly THREE standing idle figures in one horizontal row.
Input image is the immutable identity, costume, proportions, drawing scale and framing guide. Draw the SAME dark-skinned adult male Hobbit in three headings: LEFT cell exact WEST left-facing side profile; MIDDLE cell SOUTHWEST front-left three-quarter facing toward lower-left; RIGHT cell SOUTHEAST front-right three-quarter facing toward lower-right.
All three must stand idle with both bare feet grounded evenly and empty hands relaxed at sides. No walking contacts. Keep the same head/torso/limb measurements and source height as the reference's idle figure; same broad transparent margins and common soles baseline. All figures fully visible and equally scaled, three equally spaced cells, one row. Small58px final envelope after one common downscale. Maintain black curled hair, pointed ears, charcoal long coat, plum waistcoat/lining/cuffs, ivory collar, brass trim and chain, practical clothes, friendly alert face and natural adult proportions.
WEST shows a true left profile with only one eye, not a front view. SW/SE show clearly rotated front three-quarter heads, shoulders, pelvis and feet together; no isolated head turns. On the front diagonals retain the plum waistcoat and tie; keep the gold chain on the same ANATOMICAL side through rotation. Do not mirror the entire outfit as a shortcut or copy the WEST profile into a diagonal cell.
Sharp pixel clusters and stepped contours, no soft blurry painted edges. Actual transparent RGBA background preferred; no baked checkerboard. No text, grid, captions, numbers, props, bags, staff, magic, glow, floor or shadow. Same identity and material style as input, only heading changes.

Observed: all six idle headings are distinct; N is centered back without a face,
NE/NW show rear quarters and W a true profile. SW/SE turn the head, shoulders and
feet together, though exact diagonal yaw remains a visual review criterion.

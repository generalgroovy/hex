# Don Doko Don fixed-pixel jump source

Date: 2026-10-03. Built-in image generation, one call; no CLI/API fallback and no corrective call.

Canonical runtime identity: `donnok`, Don Doko Don, middle-body dwarf, verified in `content/champions/foundation_champions_v1.json`.

## Reference paths and roles

- `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/donnok.png`: primary runtime identity, costume, proportions and colors.
- `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/donnok-detail.png`: supporting identity details and directional anatomy.
- `C:/Users/sende/Pictures/styleref1.png`: retro pixel-art style only; labels, identities, props and effects are not canonical.

All three references were inspected before generation. The character ticket and successful S. Wayne v3 proportion contract informed the prompt.

## Exact generation prompt

Use case: stylized-concept.
Asset type: H.E.X. fixed-pixel jump-key sprite-sheet source, one existing character, 32 complete poses on true transparent RGBA.

Input images and roles:
Image 1 (assets/sprites/pixel_cast_v1/donnok.png) is the PRIMARY CURRENT RUNTIME identity, costume, colors and proportion canon. Create new action poses of THIS specific character, not another dwarf.
Image 2 (assets/sprites/fullbody_cast_v1/donnok-detail.png) is supporting fine identity/costume and genuine profile/rear anatomy reference. Primary Image 1 owns body scale.
Image 3 (styleref1.png) is STYLE ONLY: charming retro fantasy pixel clusters and colored outlines. Ignore every label, other character, prop, weapon and magical effect in it.

Subject: Don Doko Don, canonical middle-body dwarf. Preserve his adult masculine presentation, warm light skin, strong nose, thick copper-orange eyebrows, copper-red curled hair and substantial beard/moustache, blue tied headscarf, brass goggles resting on forehead, dark blue gold-trimmed long tunic/coat, brown belt with square brass buckle, brown padded gauntlets and sturdy brown boots. Preserve the current reference costume paneling, shoulder armor and rear hair curls. Both hands EMPTY. No tools, weapons, handheld objects, magic or effects. This is a stout full-bodied dwarf with real thighs, knees and calves, NOT a huge-headed baby or a beard on feet.

Proportion contract: one common model scale for ALL 32 cells. Head including skull/hair crown down to chin is about ONE THIRD of neutral standing crown-to-sole height, never half. Beard can overlap upper torso without enlarging skull. Use a notional standing-equivalent height of 60 units and a constant approximately 19-20-unit head in every heading and pose. Keep actual torso, waist, pelvis and leg length. Body type is expressed by stout breadth and volume, not stretched height. Never independently fit/rescale sprites to their own bounding boxes. Joint bending changes posed height; skull size and anatomical limb length do not change.

Layout: approximately 2048x1024 landscape, exactly EIGHT equally spaced columns by FOUR equally spaced rows, 32 full-body sprites, generous transparent gutters. Every pose entirely inside its own cell with complete fingertips, hair and boots. No captions, numbering, lines, cell outlines or other marks.
Column order, identical in all four rows:
1 S: faces viewer, true front.
2 SE: front three-quarter facing screen RIGHT.
3 E: strict full RIGHT profile, one side of face visible; torso and boots sideways, not front-quarter.
4 NE: BACK three-quarter facing screen RIGHT; rear/right shoulder and back coat visible, no front-facing chest.
5 N: full back, directly away; rear headscarf knot, copper curls and back coat, no face.
6 NW: BACK three-quarter facing screen LEFT; rear/left shoulder and back coat visible.
7 W: strict full LEFT profile, one side of face visible; torso and boots sideways.
8 SW: front three-quarter facing screen LEFT.
Genuine independently drawn directional anatomy, not copied/flipped sprites or head turns on an unchanged torso. Make profile versus diagonal unmistakable.

Rows from top to bottom:
1 Jump anticipation/jumpsquat. Boots planted apart, moderate knee bend, lowered pelvis, chest balanced over hips. Elbows bent beside body, empty gloved hands slightly behind/outward for launch. Posed height about 51-54 units with the SAME 19-20-unit head.
2 Airborne RISING TUCK. Knees bend and fold so boots are clearly drawn upward/back toward body, visible tucked lower-leg silhouette. Torso remains long and balanced, elbows bent with empty hands lifted/spread for balance. Tuck by actual knee/hip articulation, never make a sitting ball. Posed height about 53-56 units with SAME head.
3 Airborne DESCENDING FEET-READY. Unfold knees and extend both lower legs DOWN beneath pelvis, boots separated and soles aimed toward landing. Arms spread lower/outward compared with rise to balance. Obvious open-legged silhouette different from tucked row 2. Posed height about 58-60 units with SAME head.
4 Deep COMPRESSED LANDING. Both boots firmly planted wide on common baseline, knees bend visibly MORE than row 1, hips sit lower between knees, torso leans forward naturally without flattening or scaling. Hands reach slightly forward/out to counterbalance. Posed height about 47-50 units with SAME head. This must be a deeper anatomical crouch, not a duplicate anticipation pose or squash-scaled body.

Registration: shared cell-coordinate system and body scale; root centered horizontally in each cell, consistent imaginary root/baseline across headings. Do not move the whole airborne figure upward to simulate trajectory; engine provides world-height. Only anatomical pose changes. Maintain consistent costume construction and head size across front, rear, quarter and profile views.

Style/medium: crisp deliberate retro pixel-art clusters, clean dark colored outlines, restrained clustered material shading, matching primary blue/gold/copper/brown palette and top-left lighting, readable at small game size. True transparent alpha background; no baked checkerboard, matte, scenery, floor, ground shadows, contact blobs, dust, motion lines, glow, weapons, text, watermark, or extra characters.

## Source review and limits

The generated original has 32 complete, separated full-body figures in the required eight headings and four rows. Costume, copper hair/beard, headscarf and goggles are retained. Profiles read side-on and rear quarters show the back. Rise/fall differ in knee fold and arm placement, although boot separation and tuck differences are modest in the rear headings. Landing has a lower crouched body and forward hands relative to anticipation; the difference is subtle in some quarter views and remains subject to lead review at native scale. No visible cropped extremities, props, weapons, text, environment or effects were found.

The unmodified generated PNG is preserved byte-identically as `source/donnok/source.png`. Generated partial alpha remains untouched. Any threshold cleanup, registration or downsampling belongs to lead-owned assembly. These are four authored jump keys, not complete cycles. Source-size visual review is not native-scale or runtime acceptance. Native-scale acceptance, runtime import/capture and human acceptance: NOT_RUN.

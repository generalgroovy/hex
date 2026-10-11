# Spai Si fixed-pixel jump source

Built-in image generation; one initial call. Runtime identity: `spai_si`, Spai Si, middle body, demon, verified in `content/champions/foundation_champions_v1.json`.

## Reference paths

- `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/spai_si.png` - primary runtime identity, costume, proportions and eight headings.
- `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/spai_si-detail.png` - supporting identity detail and profile/rear anatomy.
- `C:/Users/sende/Pictures/styleref1.png` - pixel-art style only; its old elf label and bow are not authoritative.

## Exact generation prompt

Use case: identity-preserve.
Asset type: H.E.X. Spai Si fixed-pixel jump-key sprite sheet, true transparent RGBA, 32 complete full-body poses of ONE character.

Input image roles:
Image 1 (assets/sprites/pixel_cast_v1/spai_si.png) is PRIMARY CURRENT RUNTIME CANON: identity, colors, head/body proportions, costume, and eight headings.
Image 2 (assets/sprites/fullbody_cast_v1/spai_si-detail.png) supplies supporting costume, facial detail, real profile/rear anatomy and tail.
Image 3 (styleref1.png) is STYLE ONLY: charming retro pixel clusters and colored outlines. IGNORE ALL its labels, ancestries, names, props and weapons. Its old elf labeled SPAI SI IS NOT THE CHARACTER. Draw the DEMON from images 1 and 2, never that elf.

Subject invariants: same masculine-presenting medium-build demon adventurer, warm red skin, red upward/outward curling paired horns, tousled black hair, pointed red ears, expressive face; rich forest-green long jacket with gold piping, gold shoulder accents and belt buckle, dark trousers, black substantial boots, slender red pointed/spade tail. No wings. Keep horns and tail fully visible when physically visible from a heading, with generous transparent clearance. Preserve costume panels, collar, gold trims and anatomy consistently. Empty hands: no bow, staff, wand, weapon, object, spell or effects.

PROPORTIONS: compact but FULL-BODIED, not big-headed baby/chibi. Head including hair crown to chin is about ONE THIRD of neutral standing body height, not half. Use a neutral standing-equivalent 60-unit body scale and approximately 19-20-unit hair-crown-to-chin head, excluding horns. Keep SAME head width/height, horn dimensions, limb lengths and body mass in all 32 cells; real neck, torso, waist, pelvis, thighs, knees, calves and boots. Middle-body volume means balanced medium width/mass, not taller stretched anatomy. Crouches shorten by joint bending only. Never resize each pose to fit its bounding box.

LAYOUT: landscape approximately 2048x1024, EXACTLY 8 equally spaced columns and 4 equally spaced rows, total 32 complete sprites. Wide transparent gutters, identical cell coordinate systems, no touching or cropping. No captions, headings, labels, numbers, lines, grid marks or watermark.
Every row must contain this exact direction order:
1 S front facing viewer;
2 SE front three-quarter facing screen RIGHT;
3 E true right profile;
4 NE BACK three-quarter facing screen RIGHT, showing back/right shoulder, not front;
5 N full back directly away, no face;
6 NW BACK three-quarter facing screen LEFT;
7 W true left profile;
8 SW front three-quarter facing screen LEFT.
Turn the entire torso, pelvis, limbs, coat and tail naturally with the heading, not just the head. Genuine independently articulated directions, not synthetic mirrors.

Rows top to bottom:
1 ANTICIPATION / jumpsquat: feet planted, bent knees, moderately lowered pelvis, torso balanced over feet; bent elbows and visible empty hands out for balance. Approximately 51-54-unit posed hair-crown-to-sole height at the shared 60-unit neutral scale.
2 RISING TUCK: airborne anatomical jump pose, knees naturally folded, feet tucked backward/up beneath pelvis, hands and arms lifted/open for balance. Keep torso long and head unchanged; do not curl into a sitting ball. Clearly tucked leg silhouette unlike row 3. Approximately 53-57-unit posed hair-crown-to-sole height.
3 DESCENDING FEET-READY: knees opening and legs extending downward under hips, soft knees, both boot soles prepared to receive landing, arms lowered forward/outward for balance. This is visibly distinct from tucked row 2. Approximately 58-60-unit posed height.
4 COMPRESSED LANDING: both boots planted, knees flex visibly deeper than row 1, pelvis low between knees, torso inclined naturally but not flattened; arms reach slightly forward/out to counterbalance. Approximately 48-51-unit posed height, retaining the SAME 19-20-unit head. Real joint bending, not scaled/squashed anatomy.

Registration: one common model scale over every cell and row. Center pelvis/root on each cell's same horizontal axis. No baked whole-character trajectory; game supplies world-height lift. Only anatomical pose changes. Keep complete horns, tail tips, boot soles, fingers within their cells. Rear-view hands may naturally overlap torso but must not disappear through it.
Style: deliberate crisp retro pixel-art clusters, clean dark colored outlines, readable simple forms, green/gold/red/black palette with consistent top-left illumination. Preserve masculine presentation without sexualization. Actual transparent alpha, no checkerboard painted into pixels, no matte, ground, floor, shadows, glow, particles, magic, motion trails or background.

## Scope limits

Source-size visual inspection only. Native-scale, runtime, animation-timing and human acceptance are NOT_RUN. Deterministic alpha cleanup, registration, downsampling and integration remain lead-owned.

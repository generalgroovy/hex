# Steezo complete body-sheet candidate

Status: source generation and visual review only; no runtime promotion.

Tool: built-in image generation. References are existing artwork, not edit targets. Background removal and deterministic assembly are user-authorized; source hashes and exact masks must be retained.

## Full sheet v1

Use case: stylized-concept.
Asset type: complete production pixel-art character animation source sheet for FLUX, ONE character STEEZO, exactly 8 columns by 10 rows (80 figures).
Image 1 is the canonical Steezo identity reference: olive-green adult male goblin, long pointed ears, short dark swept-back hair, brass goggles resting on forehead, ochre scarf, dark brown leather tinkerer coat and trousers, small brass fasteners/pouches, sturdy boots. Image 2 supplies ONLY the crisp restrained pixel-cluster rendering language and gameplay-friendly 2.5D top-down perspective; do not copy the fish character, clothing, staff, colors or magic.
Create the SAME distinct small goblin in every cell with useful charming clean adult-like proportions: compact body, readable modest head, visible separate knees/ankles/feet and empty hands. Clothes must not obscure leg alternation. Olive face and hands, ochre scarf and brass goggles are identity markers. Retain one consistent body/head size for all poses. NO weapons, staffs, wands, bombs, tools, machines, spell glows, auras, speed lines, environmental pixels, companions, floor or shadows.
Layout: 1536x1920 source preferred, exactly8 equal columns and10 equal rows, ample empty gutters, every full figure separate, NO text, labels, borders or frame lines. Ask for genuine transparent background with no painted checkerboard. Runtime target is96x96cells, small standing height58pixels with feet at(48,84); at192px sourcecells standing116px tall and feet at(96,168). Keep common scale and feet baseline, do not enlarge compact crouches/rolls to fill cells.
Columns from left to right, exact on EVERY row: (1) SOUTH straight toward viewer, face and torso symmetric, both eyes equally visible; (2) SOUTH-EAST front three-quarter down-right; (3) EAST side profile right; (4) NORTH-EAST rear three-quarter up-right; (5) NORTH straight away, centered back of head/coat, NO face visible; (6) NORTH-WEST rear three-quarter up-left; (7) WEST profile left; (8) SOUTH-WEST front three-quarter down-left.
Rows top to bottom:
1 GROUNDED: relaxed balanced standing, arms resting, empty hands.
2 JUMP: knees raised slightly, arms balancing, still aligned with the column heading.
3 CAST: one EMPTY hand extended in column travel direction, no spell effect.
4 HIT: brief controlled backwards recoil, facing still belongs to column.
5 WALK A: LEFT anatomical leg forward and right leg back, right arm forward; small step with clearly different foot contacts.
6 SPRINT A: LEFT anatomical leg forward in wider stride and right leg back; mild forward lean in COLUMN direction, not every pose toward screen-right. South and north remain front/back views.
7 SLIDE: low braced seated/crouched pose, feet leading in column direction.
8 ROLL: compact tucked somersault pose oriented along column direction, identifiable ears/scarf.
9 WALK B: RIGHT anatomical leg forward and left leg back, LEFT arm forward. Clearly opposite contacts to row5 but identical head/body proportions and almost identical head height.
10 SPRINT B: RIGHT anatomical leg forward and left leg back, LEFT arm forward. Clearly opposite contacts to row6; same torso height, not squat-versus-standing. South/north front/back cannot turn sideways.
Top priorities: EXACT80 cells; correct all8 headings (especially centered north with face hidden); real opposite-foot walk/sprint A/B contacts (not just cloth changes); fixed adult small-body proportions; clean high-contrast native-style pixel clusters and dark outlines; no blurry painterly edges or fine grain. Original FLUX game body layer only.
## Targeted gait correction v1

Use case: identity-preserve / stylized-concept game sprite production.
Image1 is the exact Steezo character to preserve from the existing sheet: small olive-green goblin, short dark hair, brass goggles forehead, ochre scarf, brown leather coat/trousers/brass fittings and boots. Preserve face, head-to-body proportion, costume, colors and clean pixel-cluster style. We need ONLY a corrected locomotion source sheet, not the other actions.
Output EXACTLY8 columns by4 rows,32 separate full-body poses on genuine transparent background; no painted checkerboard, text, grid, border, ground shadow or effects. Suggested1536x768canvas,192x192cells, each goblin approx116px tall with feet near168px in itscell; all32 the SAME stature/headwidth. Ample empty gutters. No held props and hands empty.
Columns exact every row: SOUTH directly facing camera with symmetric face/torso; SOUTH-EAST front3/4 down-right; EAST profile right; NORTH-EAST rear3/4 up-right; NORTH directly away centered back withNOface; NORTH-WEST rear3/4 up-left; WEST profileleft; SOUTH-WEST front3/4 downleft.
Rows:
1 WALK A: LEFT anatomical leg extends forward, RIGHT leg extends back, RIGHT arm forward.
2 WALK B: RIGHT anatomical leg extends forward, LEFT leg extends back, LEFT arm forward. MUST reverse foot contacts from row1 visibly; not just a different coat hem. Keep same torso/headheight.
3 SPRINT A: LEFT foot reaches forward in a wide stride, RIGHT foot well behind, RIGHT arm forward. Tilt torso slightly in column direction.
4 SPRINT B: RIGHT foot reaches forward, LEFT foot behind, LEFT arm forward. MUST be the opposite stride to row3, not the same run pose with longer pants. Exactly same torso/headheight and anatomical lengths as row3.
Critical side-view rule E/W: one row shows near thigh forward while the opposite row shows near thigh backward; two feet remain individually legible. Do not repeat identical limb orientation.
Critical front/back rule S/N: visible nearer knee and toe alternate left-right with opposite arm swing; face/torso cannot rotate to profile. North is always back-facing. Do not change a squat into standing as an animation substitute.
Keep bent arms held a little away from body without forming closed loops against the coat: empty gaps must connect to the exterior, no trapped opaque white holes. Transparent alpha everywhere outside the actual goblin. This is body-only artwork. Compact adult-like small proportions, expressive but not an oversized baby head. No bombs/tools/magic/aura/shadow, no blur, no light outline halo.
## Opposite-contact B correction v2

Use case: identity-preserve. Create only16 corrected opposite-contact sprites for this exact Steezo goblin, 8columns by2rows. Preserve the reference's olive skin, goggles on forehead, ochre scarf, dark brown coat/boots, compact body and proportionate head. Body layer only, emptyhands, no effects or shadows. True transparent background, no baked checkerboard. Large empty gutters, no text, no border. Suggested1536x768canvas; each figure116px tall, SAMEscale.
COLUMN HEADINGS:1SOUTH straight front;2SEfront-downright;3EASTstrictprofile-right;4NErear-upright;5NORTHstraightbackNOface;6NWrear-upleft;7WESTstrictprofile-left;8SWfront-downleft.
ROW1 is WALK B opposite foot contact. ROW2 is SPRINT B opposite foot contact.
This correction is about an unmistakably DIFFERENT STEP, NOT new clothing. In reference A poses the leading boot is centered/right-foot-down. Change which boot is LOWER and which knee is bent. BOTH legs must be separately visible, not merged behind coat.
EXPLICIT SCREEN-SPACE LEGS:
SOUTH: screen-RIGHT boot visibly planted LOWER near right side of body; screen-LEFT knee raised and boot higher to left. This is the opposite of the source's screen-left planted boot. Both shoulders/eyes stay square to camera.
SOUTH-EAST: near foreground leg trails DOWN-LEFT behind hips with large visible boot at lower-left; far leg reaches UP-RIGHT forward with smaller boot higher-right.
EAST: near foreground leg extends BACK to screenLEFT, clearly bearing weight with large boot at bottom-left; far leg reaches FORWARD screenRIGHT, higher small boot. This reverses source's big front boot at bottom-right.
NORTH-EAST: near leg trails DOWN-LEFT with large planted boot low-left, far knee/boot raised UP-RIGHT.
NORTH: screen-LEFT boot planted LOWER to left; screen-RIGHT knee raised, boot higher right. Keep central symmetric back of coat/head, face hidden.
NORTH-WEST: near leg trails DOWN-RIGHT planted low-right; far leg reaches UP-LEFT.
WEST: near foreground leg extends BACK screenRIGHT, large planted boot low-right; far leg reaches FORWARD screenLEFT higher. Reverse source's big front boot bottom-left.
SOUTH-WEST: near leg trails DOWN-RIGHT low-right; far boot forward UP-LEFT.
ROW2 uses those SAME opposite-contact leg identities but a broader RUN stride, elbows swing in opposition and torso leans only in its heading; no different head/body scale. Row1walk androw2run visibly distinct but natural. The two forearms must NOT close a loop against coat: open each arm-body gap to outsidebackground to avoid enclosed white holes.
Strictly all16 directions correct; north neverfront; SOUTH neverturnsprofile. Deliberately prioritize clear alternating LEGS/feet over decorative clothing. Do not repeat the reference's leading foot arrangement.

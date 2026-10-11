# Oh Tipi fixed-pixel jump-key source

Date: 2026-10-03. Built-in image generation only; no CLI/API fallback.

Scope: one character, four authored jump keys in eight directions. Source art only; no runtime, import, animation-cycle, or human-acceptance claim.

## Exact generation prompt

Use case: stylized-concept.
Asset type: true-transparent fixed-pixel production sprite-sheet source for H.E.X. character Oh Tipi, Middle Seakin. Generate a NEW sheet of four authored jump key poses across eight directions.

Input images and roles:
Image 1 (assets/sprites/pixel_cast_v1/oh_tipi.png) is PRIMARY CURRENT RUNTIME CANON for identity, compact body proportions, exact navy/gold outfit, colors and eight-facing anatomy. Preserve this specific full-bodied compact character; not a giant-headed baby/chibi redesign.
Image 2 (assets/sprites/fullbody_cast_v1/oh_tipi-detail.png) supports costume details, real torso and limb anatomy, fins, tail and genuine profile/rear anatomy. Do not lengthen into a tall adult or copy a neutral pose as the jump.
Image 3 (styleref1.png) is STYLE ONLY: charming readable fantasy pixel clusters and material shading. Its title, roster, text, trident, weapons and effects are NOT content to copy.

Canvas/layout: genuinely transparent RGBA, landscape approximately 2048x1024, exactly 8 equally spaced columns by 4 equally spaced rows, precisely 32 separate complete sprites. Generous empty transparent gutters, no overlaps, no cell lines or labels. Keep every fin tip, tail tip, fingertip and toe within its own cell.

Identity invariants: SAME charming compact blue scaled amphibious/reptilian Seakin adventurer in every cell. Cyan/blue expressive angular snout, gold/amber eyes, swept spiky blue fin crest and side head fins. Preserve dark navy articulated armor/tunic, gold shoulder and cuff edges, central round gold chest ornament, belt and gold buckle, gold-edged divided thigh panels, clawed blue hands and substantial blue clawed feet. One curled blue tapering tail, attached naturally at rear pelvis; tail must match heading and stay visible outside the silhouette where anatomically possible. No added wings, fur, hair, horns, alternate costume, or new accessories. All hands EMPTY.

Volume-first proportions: match primary runtime character. Head INCLUDING crest and chin is approximately ONE THIRD of neutral standing crown-to-sole height, never one half. Think one neutral standing-equivalent model of 60 units: head/crest 19-21 units, real visible torso/waist/pelvis/thighs/knees/shins/feet below. Same skull size, crest dimensions, limb length, torso mass and armor panels for ALL 32 cells. No big-headed baby/chibi, no omitted shins, no giant head on tiny feet. Use one common physical body scale for entire sheet, NEVER fit each pose independently to its bounding box. Pose compression is anatomical joint bending, not squash/stretch, shrinking or morphing.

Column sequence in EVERY row:
1 S: front, directly toward viewer.
2 SE: front three-quarter facing screen RIGHT.
3 E: true screen RIGHT profile.
4 NE: BACK three-quarter facing screen RIGHT, showing back/right shoulder, NOT another front-quarter.
5 N: directly away, full BACK, rear crest and rear armor, no face painted on back.
6 NW: BACK three-quarter facing screen LEFT.
7 W: true screen LEFT profile.
8 SW: front three-quarter facing screen LEFT.
Turn the entire torso, pelvis, limbs and tail honestly with the heading, not only the head.

Rows top to bottom:
1 JUMPSQUAT / anticipation: both feet planted apart, knees visibly bent and pelvis lowered, torso balanced over knees, elbows bent, empty hands slightly out and forward. Posed height about 50-53 units with SAME 19-21-unit head.
2 RISE / near-apex: visibly airborne anatomical key, knees gently folded backward and feet modestly tucked, arms open comfortably to balance; body long and balanced, not curled into a sitting ball. Posed height about 56-59 units with SAME head.
3 FALL / feet-ready: both legs opening and nearly extending beneath body, knees soft, feet ready beneath hips for landing, empty hands forward/outward for balance. Clearly different from tucked rise. Posed height about 58-60 units with SAME head.
4 COMPRESSED LANDING: both feet fully planted wider, knees more deeply flexed than row1, low pelvis between knees, torso inclined naturally without flattening, elbows and empty hands out to stabilize; visibly deeper than anticipation. Posed height about 48-51 units with SAME head.

Registration: each sprite's body root centered at the same horizontal cell position. Consistent imaginary root/feet baseline within each row's eight cells. Do not translate the whole airborne sprite upward to bake in jump trajectory; the game supplies world-height movement. Only anatomical pose changes. Real empty hands and readable full limbs, with only unavoidable natural far-side profile occlusion. No clipped or missing extremities.

Style: deliberate crisp pixel-art clusters, dark colored outlines, simple controlled navy/gold/blue shading, readable and expressive at tiny game scale, consistent top-left lighting. No smooth painted texture, blur, fake checkerboard pixels, or anti-aliased scenic background.

Avoid absolutely: trident, staff, sword, shield, any weapon or held object, spell effects, magic, glow, particles, dust, trails, ground, floor, contact shadows, backdrop, text, labels, numbering, arrows, grid borders, watermarks, extra characters. Output only the 32 complete Oh Tipi sprites on genuine transparency.

## Review status

Generated source is preserved untouched at `art_batches/pixel_actions_v1/source/oh_tipi/source.png` (1774x887 RGBA). One built-in generation call; no repair call. Exact source hash, transparent-alpha counts, grid and per-sprite alpha128 bounds are recorded in the adjacent `receipt.json`.

Source-size visual review found32 complete sprites in the requested direction sequence, recognizable blue fin crest/curled tail/navy armor/gold trim, no props or VFX, and no cropped extremities. Anticipation and deeper landing differ visibly. Rise has tucked/pointed feet with arms wider; fall places feet beneath the body with lower balancing arms. Head/crest appears near one-third of standing-equivalent height, not the rejected giant-head ratio; exact native skull/volume continuity is unverified.

Natural occlusion: the tail can hide behind the body in direct front views; far-side hands, feet and tail roots can overlap nearer anatomy in profile/rear-quarter views. No artificial limb removal was observed.

Known limits: substantial generated partial alpha requires the lead's approved deterministic threshold128/hidden-RGB cleanup, leaving this original intact. Rise/fall height envelopes overlap (167-173 and165-174 pixels); temporal distinction requires native review. Anticipation heights are135-142 pixels; landing128-129 pixels. Cell baselines vary modestly and need root registration without independent pose resizing. Source-size inspection is not native-scale, transition, runtime or human acceptance. No runtime PNG, manifest, build, Godot/import/capture/export, git index, commit, or remote was changed by this ticket.

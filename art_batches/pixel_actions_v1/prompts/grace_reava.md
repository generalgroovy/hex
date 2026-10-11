# Grace Riva fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation; no CLI/API fallback.

Scope: one identity, four authored action keys in eight headings. The generated original is preserved unchanged. Runtime integration, native-scale acceptance and animation timing are lead-owned and are not claimed by this source-art ticket.

## Exact generation prompt

Use case: stylized-concept.
Asset type: H.E.X. fixed-pixel character action source sheet for Grace Riva (grace_reava), Small Sylph.

Input roles: Image 1 (assets/sprites/pixel_cast_v1/grace_reava.png) is PRIMARY CURRENT RUNTIME CANON for identity, body/head proportions, colors, costume, face and eight headings. Image 2 (assets/sprites/fullbody_cast_v1/grace_reava-detail.png) supports costume, four-wing anatomy and rear/profile details. Image 3 (styleref1.png) is STYLE ONLY: charming compact retro fantasy pixels, colored outlines, strong clustered material shading. Ignore its characters, names, text, magic and weapons. Current runtime Grace wins over every style-reference difference.

Create ONE genuinely transparent RGBA sprite sheet, landscape approximately 2048x1024, exactly 8 equally spaced columns by 4 equally spaced rows: 32 separate complete full-body Grace poses. Generous transparent gutters. No titles, labels, numbers, borders, arrows, marks, floor or shadows.

Every row has exactly this left-to-right directional order:
1 S: direct front, faces viewer.
2 SE: FRONT three-quarter facing screen RIGHT.
3 E: true profile facing screen RIGHT.
4 NE: BACK three-quarter facing screen RIGHT; show back/right shoulder, not front-quarter.
5 N: directly away, complete back view.
6 NW: BACK three-quarter facing screen LEFT.
7 W: true profile facing screen LEFT.
8 SW: FRONT three-quarter facing screen LEFT.
Turn the full skeleton, torso, tunic, arms, legs and attached wings genuinely with each heading; do not merely turn heads. Back views show back hair and rear tunic, not a face.

Rows top to bottom, four authored action keys:
1 JUMPSQUAT anticipation: both booted feet planted, knees bent, pelvis moderately lowered, torso balanced over knees, bent arms lightly out and both hands empty. Crown-to-sole pose height roughly 48-51 units at a neutral standing-equivalent 56-58-unit model.
2 RISING tucked jump: airborne knees folded modestly back, feet gently tucked; torso and thighs remain anatomically substantial, arms comfortably spread for balance. About 52-55 units posed height, not a curled sitting ball. Wings tilt naturally without magical effects.
3 FALLING feet-ready: legs nearly extend beneath body, knees soft, feet ready for landing, arms forward/out for balance. About 55-58 units posed height. Distinct from tucked row 2.
4 COMPRESSED LANDING: booted feet planted apart, knees deeply bent and pelvis lowered more than row 1, upper torso naturally inclined, arms balancing at sides with empty hands visible. About 46-49 units posed height, anatomical joint flexion not squash scaling.

Identity lock: the SAME compact small sylph as current runtime Image 1, not a redesign. Short side-swept teal/turquoise hair and swept forelock, warm light skin, large expressive dark eyes, long pointed ears, same normal gender presentation and friendly face. Dark emerald/teal green sleeveless gold-edged long tunic with pointed split skirt panels, pale short sleeves, gold ornamental neckline, waist belt with gold buckle, dark trousers and sturdy small brown/gold boots. Preserve the exact reference costume construction and coverage in all poses. Exactly four delicate pale cyan insect-like wings attached to upper back, two long upper wings and two shorter lower wings, thin teal/gold veining and dark cyan edge. All wing tips remain within their cell. No added head ornaments, tail, jewelry or equipment.

CRITICAL body proportions: compact and full-bodied, with real torso, waist, pelvis, thighs, knees, calves and boots. Head including hair crown to chin is about 18-19 units for 56-58-unit neutral standing height, approximately ONE THIRD, never one half. Keep head dimensions constant across all 32 sprites. Do not make a tall slender adult, a baby-doll chibi, a huge head on a tiny coat, or missing shins. Preserve sufficient body volume beneath the head. Wings are not included in the crown-to-sole proportion measurement.

Registration: ONE common model scale and common pixel density across all cells. Never independently resize poses to bounding boxes. Crouching shortens the pose through joint bending only; skull and limb dimensions stay fixed. Same horizontal body-root center per cell and consistent imaginary feet/root baseline across each row's headings. Do not bake whole-body jump elevation into the sheet; the engine supplies trajectory. Maintain consistent wing size and attachment anatomy even when wings rotate or partly occlude one another. Entire character, wing tips, fingertips and boots must fit within its own cell without touching neighbors.

Style: crisp charming retro game pixel art, deliberate visible square pixel clusters, clean dark colored outlines, limited coherent teal/cyan/green/gold/brown palette, restrained top-left material highlights. Readable at small native game scale, not soft painterly, smooth vector or 3D.
Avoid: weapons, staffs, wands, shields, props, magic, spell effects, particles, dust, glows, speed lines, ground, shadows, checkerboard pixels, colored matte, captions, text, watermark, extra characters or extra limbs. EMPTY HANDS. True transparent alpha background.

## Source review

One built-in generation call produced a 1774x887 RGBA original, saved unchanged at `art_batches/pixel_actions_v1/source/grace_reava/source.png`. Original and destination SHA256 match. The original has 32 complete sprites with the expected eight-heading order, retained identity and wings, and no apparent clipped extremities or forbidden props. Landing reads lower than anticipation; rising and falling are relatively similar and require transition review. No gross error warranted another generation call.

This is a source candidate, not accepted runtime art. The original contains extensive partial alpha and visible cyan/green edge fringe or isolated speckles; no cleanup or resampling was applied. Exact one-third-head proportion, common body/wing scale, native-size readability and timing remain lead-owned review items. Read-only diagnostics and full provenance are in the character receipt. No runtime, manifest, build, shared documentation, Godot import/test/export, commit or push was performed.

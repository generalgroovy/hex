# Wa Bidi fixed-pixel jump-chain source

Date: 2026-10-03. Built-in image generation; no CLI/API fallback.

Scope: one small-goblin identity, four authored jump-chain key poses in eight directions. Source-art generation only; native assembly and runtime acceptance remain with the lead.

## Exact generation prompt

Use case: stylized-concept.
Asset type: transparent game-production sprite-sheet source for H.E.X. Wa Bidi, a SMALL GOBLIN. Four authored jump-chain key poses in eight headings.

Input images and roles:
Image 1, assets/sprites/pixel_cast_v1/wa_bidi.png, is the PRIMARY CURRENT RUNTIME CANON for exact character identity, costume, colors, compact full-bodied anatomy and eight-heading sequence.
Image 2, assets/sprites/fullbody_cast_v1/wa_bidi-detail.png, is supporting costume, profile/rear anatomy, face and hair detail.
Image 3, styleref1.png, is STYLE ONLY: crisp charming retro fantasy pixel rendering, colored outlines, deliberate clustered shading. Ignore every label, weapon, effect and alternate character design in that poster. In particular its old winged figure labeled WA BIDI is WRONG for this request. Our Wa Bidi is the green-skinned, black-haired SMALL GOBLIN in images 1 and 2, NOT a sylph, fairy or winged humanoid.

Create one genuine transparent RGBA sprite sheet, approximately 2048x1024 landscape, exactly 8 evenly spaced columns by 4 evenly spaced rows, precisely 32 complete full-body sprites. Generous transparent gutters; no borders, cell labels, titles, numbers, arrows or other marks. Every whole hand, foot, pointed ear and hair spike remains inside its own cell.

Directions left to right in EVERY row:
1 S: front, facing viewer.
2 SE: front three-quarter facing screen RIGHT.
3 E: full right profile.
4 NE: BACK three-quarter facing screen RIGHT, back/right shoulder visibly readable; NOT front-quarter.
5 N: directly away, full back.
6 NW: BACK three-quarter facing screen LEFT.
7 W: full left profile.
8 SW: front three-quarter facing screen LEFT.
Rotate the full head, chest, pelvis and feet as genuine 3D volumes. Never just turn a head on a front-facing torso. Direct rear views show back hair and rear costume, no face. Rear-quarter poses must unmistakably display back anatomy.

Identity invariants: exactly the same small goblin throughout: lime/yellow-green skin, long outward pointed ears, lively warm amber/dark eyes, confident youthful face, thick tousled spiky charcoal-black hair with longer nape locks. Dark forest/teal-green short leaf-panel tunic with gold edging and gold shoulder/neck details, brown leather belt with rectangular gold buckle, brown wrist/forearm leather bracers, short dark leggings and substantial brown leather boots with gold details. Preserve leaf-shaped lower tunic panels and the rear crossed straps visible in Image 2. No wings, antennae, horns, hat or added costume. Body is small but properly volumetric: real chest, waist, pelvis, thighs, knees, shins and boots, not a tiny torso hanging directly from an oversized head.

Critical consistent proportions: neutral standing-equivalent crown-to-sole height is 60 design units; head INCLUDING HAIR from crown to chin is only 19-20 units, approximately ONE THIRD, NEVER half. Below chin preserve the other 40 units as actual neck, torso, pelvis and leg length. Match runtime head/body balance rather than baby/chibi proportions. Same skull size, hair mass, body volume, limb lengths and costume geometry across all 32 sprites. No stretched torso, shortened shins, huge head, paper-flat body or per-pose deformation.

Rows top to bottom:
1. Jumpsquat anticipation: knees bent, feet planted, hips lowered with balanced torso over pelvis; elbows bent, both empty hands readable slightly apart from body. Crown-to-sole posed height around 50-53 units, with the SAME 19-20-unit head.
2. Rising/tucked jump: airborne pose, knees naturally bent and feet modestly tucked backward, torso remains open with real thigh/leg anatomy. Arms comfortably spread for balance. Approximately 55-58 units posed height, SAME 19-20-unit head. Clearly lift/fold the boots relative to the descending row but do not curl into a sitting ball.
3. Falling feet-ready: legs nearly extended below hips, knees soft, both boots preparing for landing, hands held forward/outward for balance. Approximately 58-60 units posed height with SAME head. This must be distinct from row 2's tucked feet.
4. Compressed landing: both boots planted, knees bent more deeply than anticipation, pelvis low between knees, upper torso leans naturally but retains volume, empty hands balance beside and slightly ahead of body. Approximately 48-51 units posed height, SAME head. Real joint bending, never squash-scaled body.

Registration: one common model scale and one common sprite-cell coordinate system across the entire sheet. Never fit or rescale individual poses to their bounding boxes. Keep each body root centered over the same horizontal cell center and matching per-direction roots. Preserve a common imaginary support/root baseline within each row. Do not move the entire airborne figure upward to bake in a jump trajectory; the game provides world-height movement. Only anatomy and limb pose change. Crouches become shorter solely through joint rotation while skull and body mass remain constant.

Style: charming crisp retro pixel-art clusters, clean dark colored outlines, controlled green/gold/brown/charcoal palette, expressive face and deliberate small material highlights, consistent upper-left light. No soft airbrushing, photoreal texture, 3D glossy render or blurry edges. Transparent alpha only: no colored matte, checkerboard painted into pixels, floor, ground, drop shadow, props, weapons, wand, staff, spell effects, light trails, dust, glow, text, watermark or extra characters. All hands are empty and anatomically usable.

## Review status

One built-in generation produced the unchanged 1774x887 RGBA candidate at `source/wa_bidi/source.png`. All 32 complete sprites and the intended heading sequence are present in source-size visual review; the current small-goblin face, hair, green/gold costume, brown boots, true rear headings and empty hands are preserved. No wings, weapons, ground or effects were found. No repair call was made.

Landing is only modestly more compressed than anticipation, so native-size transition review remains necessary. At alpha threshold 128, inclusive occupied row bands are 59-208, 239-412, 450-641 and 684-825, giving maximum row envelopes 150/174/192/142px. An illustrative single scale of 60/192 gives 46.875/54.375/60/44.375 units; this is not final runtime calibration, and the landing envelope is deeper than the prompt target. Do not independently enlarge crouches or fit each pose to its bounding box.

The original contains actual transparent alpha, 494697 partial-alpha pixels and 2168 transparent pixels with hidden RGB. Original bytes remain unchanged and match their generated-source SHA256. Approved deterministic cleanup, native assembly, exact skull/body checks, frame registration, runtime integration and rendered/human acceptance are entirely lead-owned and unperformed here. This is four authored keys, not complete animation cycles. Full provenance and limitations are in `source/wa_bidi/receipt.json`.

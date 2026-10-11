# Biggy Bob fixed-pixel jump-key source

Date: 2026-10-03. Built-in image generation; no CLI/API fallback.

Canonical roster: `biggy_bob`, display name Biggy Bob, ancestry dwarf, body_type middle. Runtime art is the identity authority.

## References in supplied order

1. `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/biggy_bob.png` — primary runtime costume, face, proportions, palette and headings.
2. `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/biggy_bob-detail.png` — supporting costume and anatomy detail.
3. `C:/Users/sende/Pictures/styleref1.png` — pixel-art style only; no identity, labels, props or effects.

## Exact generation prompt

Use case: stylized-concept.
Asset type: H.E.X. Biggy Bob transparent pixel-art jump-key source sheet; one existing character, four authored keys in eight headings.

Input references: Image 1 (assets/sprites/pixel_cast_v1/biggy_bob.png) is the PRIMARY current runtime identity, exact costume, face, palette, compact FULL-BODIED proportions and eight headings. Image 2 (assets/sprites/fullbody_cast_v1/biggy_bob-detail.png) supplies supporting costume and rear/profile anatomy detail. Image 3 (styleref1.png) is STYLE ONLY: charming fantasy pixel clusters and dark colored outlines. Ignore all its names, races, other people, props, weapons, effects and head proportions.

Create exactly 8 equally spaced columns by 4 equally spaced rows, 32 COMPLETE full-body sprites of only Biggy Bob on actual transparent alpha. Approximately 2048x1024 landscape, generous transparent gutters and outer margins. No visible grid, labels, writing, icons, floor or shadow.

Canonical identity: masculine middle-body DWARF, stocky broad chest, sturdy arms and real articulated legs, fair warm skin, stern expressive brown-haired face, brown swept-back shoulder-length hair and full brown beard with the small gold details from Image 1. Preserve charcoal/dark steel segmented armour, rounded shoulder plates edged in gold, gold-edged forearm plates and empty dark gauntlets, dark belted waist with round gold buckle, short layered gold-trimmed armour skirt, dark leggings and heavy dark boots. No helmet. Costume panels and back hair arrangement remain continuous through headings. Hands empty: no hammer, shield, staff, weapons or magic.

Proportion contract: head/hair crown to anatomical chin is approximately ONE THIRD of neutral standing crown-to-sole height, not one half; beard may overlay upper chest but must not replace the torso. Consistent skull and hair-envelope dimensions across ALL 32 poses. One shared model scale, same anatomical limb lengths, body mass and costume sizes. This is a compact adult dwarf, not oversized-head chibi or baby-doll. Below head retain a real chest, waist, pelvis, thighs, knees, calves and feet; crouching must rotate joints, never squash the head or shorten the legs. Body category is conveyed by width and volume, not stretched height. Do not fit each sprite to a matching bounding-box height.

Column order in EVERY row:
1 S: front toward viewer.
2 SE: front three-quarter looking toward screen RIGHT.
3 E: full profile looking toward screen RIGHT.
4 NE: BACK three-quarter toward screen RIGHT, back and right shoulder dominant; face mostly occluded.
5 N: full BACK, directly away, rear hair and back armour, no face.
6 NW: BACK three-quarter toward screen LEFT, back and left shoulder dominant; face mostly occluded.
7 W: full profile looking toward screen LEFT.
8 SW: front three-quarter looking toward screen LEFT.
Draw genuinely oriented whole-body anatomy, not just turned heads and not synthetic mirrors.

Row 1, top: JUMP ANTICIPATION. Moderate knees-bent preparation, boots planted moderately apart, hips slightly lowered, arms bent slightly away from body and hands ready.
Row 2: RISING TUCKED JUMP. Airborne anatomical pose with knees flexed and both boots pulled backward/up toward the hips, especially readable in profile; elbows open and arms out to balance. Torso stays upright and real-length, not a sitting ball. Both boots remain complete.
Row 3: DESCENDING FEET-READY. Visibly different from row 2: thighs and lower legs extend below pelvis, boots aimed down underneath body ready to plant, knees only softly bent; arms forward/outward for balance. Full-length body, no tucked feet.
Row 4, bottom: DEEPLY COMPRESSED LANDING. Much deeper than anticipation row 1: hips clearly LOW between widely bent knees, thighs angled almost horizontal, heels and soles fully planted farther apart, torso leaning slightly forward with armour retaining its shape, both empty hands lowered/out to balance. Crown visibly lower by about 10-15 percent of neutral standing height relative to anticipation, without changing skull size or squashing torso. It must read as a deep joint-bent landing rather than another mild ready stance.

Registration: each cell uses one common character scale, horizontal root center and consistent notional ground/root baseline. Do not bake a whole-character upward jump trajectory into the source: world-height lift is game-supplied. Change limb pose only. Keep every hair strand, gauntlet and boot fully inside its own cell with generous transparent clearance. Rear hands may be naturally occluded but no missing limbs.

Rendering: crisp deliberate pixel-art clusters, dark colored outlines, controlled gold and dark steel shading, brown hair/beard, warm skin; lighting consistent with primary. Clean readable silhouettes suitable for later native-scale processing. Genuine transparent RGBA, no baked checkerboard or colored matte. No effects, dust, motion trails, cast shadows, environment, extra characters, captions, watermark or props.

## Scope and review boundary

One original generated PNG is preserved byte-identically. Deterministic cleanup, registration, downsampling and integration are lead-owned. Source-size visual review is not native-scale, runtime or human acceptance; all three are NOT_RUN for this ticket. Exact findings and provenance are in `source/biggy_bob/receipt.json`.

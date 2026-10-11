# Red Baron fixed-pixel jump-key source

Date: 2026-10-03. Built-in image generation only; no CLI/API fallback.

Scope: one Large Undead identity, four authored jump-chain keys in eight directions. Source-art candidate only; not full-cycle, native-scale, runtime, or human acceptance.

## Exact generation prompt

Use case: stylized-concept.
Asset type: H.E.X. Red Baron fixed-pixel character jump-key sheet, true transparent RGBA production sprite source. Generate only this ONE existing character in 32 poses.

Input image roles: Image 1 (assets/sprites/pixel_cast_v1/red_baron.png) is PRIMARY CURRENT RUNTIME CANON for character identity, proportions, palette and eight headings. Image 2 (assets/sprites/fullbody_cast_v1/red_baron-detail.png) supports costume, profile and genuine rear construction only. Image 3 (styleref1.png) is STYLE ONLY for charming crisp clustered fantasy pixel art; do not reproduce its roster, text, weapons, spells or background.

Identity: the SAME Large Undead Red Baron from Image 1: ivory skull with dark eye sockets and exposed teeth, upright jagged bone crown integrated with skull silhouette, substantial broad armored body, massive dark charcoal pauldrons with small gold spikes, dark segmented arms and gauntlets outlined in gold, black breastplate with gold trim, gold belt buckle, deep crimson neck scarf, short crimson front tabard with gold edging, broad armored thighs and black/gold boots. A crimson ragged-hem cape is visible down his back, attached at shoulders beneath the scarf. No hair, no face skin, no added helmet visor, no huge horns. Preserve the compact but full-bodied large build: breadth and armor volume, not an elongated skinny skeleton, and NOT an oversized-headed baby/chibi redesign.

Proportion contract: ONE common character model and skull/crown size across all 32 cells. Neutral standing-equivalent height is 66 arbitrary units; skull including crown down to chin about 20-22 units, approximately ONE THIRD, never one half. Below the chin retain substantial neck/chest, waist, pelvis, thighs, knees, calves and boots; total armor volume must stay broad and large. The head remains exactly the same size while knees bend. Do not shorten the body to tiny feet directly beneath a giant skull. Do not stretch, squash or morph body volume.

Canvas/layout: approximately 2048x1024 landscape, EXACTLY 8 equally spaced columns by 4 equally spaced rows = 32 full-body sprites. Generous genuinely transparent gutters around every sprite. No cell borders, labels, titles, numbering or arrows. Keep each figure centered over the same per-cell root; same camera, light and common drawing scale in all cells. Do NOT independently fit each pose to its bounding box.

Column sequence in EVERY row, left to right:
1 S: directly toward viewer, full front.
2 SE: front three-quarter facing screen RIGHT.
3 E: true right-side profile.
4 NE: BACK three-quarter facing screen RIGHT; rear cape and back/right shoulder dominate, NOT a front-quarter torso.
5 N: directly away, full BACK, rear crown/skull and rear cape; NO face or chest drawn on back.
6 NW: BACK three-quarter facing screen LEFT; rear cape and back/left shoulder dominate.
7 W: true left-side profile.
8 SW: front three-quarter facing screen LEFT.
Rotate the entire anatomy/costume correctly; never rotate only the skull. All eight headings are essential.

Four action rows from top to bottom:
ROW 1 JUMPSQUAT / ANTICIPATION: both broad boots planted, visibly bent knees and lowered pelvis, torso balanced over legs; arms bent slightly outward, both empty gauntlets visible. Posed height around 55-59 units with the SAME 20-22-unit skull/crown. The character is preparing to jump.
ROW 2 RISE / NEAR APEX: body open with torso and thighs still substantial, knees folded modestly backward and feet tucked lightly, empty hands spread for balance. Posed height around 61-64 units with SAME head size. Do not curl into a ball. Cape moves only by natural cloth articulation.
ROW 3 FALL / FEET READY: both legs extend below hips with soft knees, both boots pointing to land, arms slightly forward/out for balance. Posed height around 64-66 units with SAME head size. Clearly different from tucked row 2.
ROW 4 COMPRESSED LANDING: both boots planted apart, knees deeply bent and hips lowered between them, torso leaning naturally forward, arms balancing out beside knees with both empty hands visible. Posed height around 53-57 units with SAME head size. Visibly deeper than row 1 through real joint bending, never body scaling or squash. Keep thighs/shins/boots readable and cape from hiding all legs.

Registration: preserve a common imaginary feet/root baseline within each row. Do not bake world jump trajectory into positions; the game supplies vertical lift. Only anatomical pose changes. All skull/crown tips, shoulder spikes, fingertips, cape hem and boot toes must be complete and comfortably inside their cell; no cropping or touching neighboring cells. Keep gauntlets clearly empty and usable for hand casting, no props.

Style: charming deliberate pixel-art clusters, crisp dark colored outlines, controlled charcoal/gold/crimson/bone palette, top-left material lighting consistent with primary runtime. Readable silhouette and bright ivory skull balanced by substantial broad body. Genuine transparent alpha, not a baked checkerboard or colored matte. NO floor, ground, cast shadow, dust, motion trails, weapons, staff, sword, shield, magic, particles, glow, spell effects, floating decorative objects, text, watermark or extra characters.

## Review status

The initial built-in result is preserved untouched at `source/red_baron/source.png` (1774x887 RGBA; SHA-256 `7a35a99337c304dd27bc653a009efae004440550ba15907e6c009d934db6fdb9`). Saved copy is byte-identical to the generated original. No targeted correction was needed for a gross source-size defect.

Source-size review finds 32 complete figures, expected eight-heading sequence with genuine rear quarters and cape-back views, preserved skull/crown and charcoal/gold/crimson identity, and distinguishable anticipation, tucked rise, feet-ready fall and lower landing poses. The head remains relatively small against substantial armor volume. No obvious clipped crown tips, gauntlets, cape hems or boot toes; far-side limbs naturally overlap in profile/rear quarters and cape obscures parts of rear-view legs.

The generated PNG contains extensive partial alpha (483017 partial-alpha pixels); lead-owned deterministic threshold/hidden-RGB cleanup is needed before assembly, without modifying the original. Exact native-scale skull/volume continuity, pixel registration, rendered transitions and timing remain unverified. No Godot/import/runtime/capture work or human acceptance is claimed. See `source/red_baron/receipt.json` for complete evidence and limitations.

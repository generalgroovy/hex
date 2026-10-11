# Red Baron neutral-calibrated action source v2

Date: 2026-10-04. Mode: built-in image_gen, with transparent_background=true. One initial generation; at most one targeted correction for a gross facing, anatomy, grid, or cropping defect.

This is an isolated source-art candidate. Existing originals, runtime sprites, and shared assembly remain unchanged. Native assembly, integration-lead acceptance, runtime transitions, and human acceptance are NOT_RUN.

## Reference inputs in order

1. `C:/Users/sende/Projects/hex/assets/sprites/pixel_cast_v1/red_baron.png`: PRIMARY approved runtime identity, skull/crown and body proportions, outfit, colors, and eight headings. Neutral first row owns anatomy.
2. `C:/Users/sende/Projects/hex/assets/sprites/fullbody_cast_v1/red_baron-detail.png`: supporting costume and profile/rear detail, subordinate to the approved runtime proportions.
3. `C:/Users/sende/Pictures/styleref1.png`: charming retro pixel style only; not roster, ancestry, names, props, or proportions.

All three inputs were inspected with view_image before generation. The catalog identity is `red_baron`, display name `The Red Baron`, ancestry `undead`, body type `large`. The Oh Tipi neutral-calibration-v2 recipe informs the separate neutral-row and bent-joint contract, not this character's anatomy.

## Exact initial prompt

Use case: stylized-concept.
Asset type: production pixel-art sprite-sheet source for H.E.X., The Red Baron (red_baron), large-bodied undead armored champion. New neutral-calibrated whole-body jump sheet, not a redesign.

Input image roles: Image 1 is the PRIMARY APPROVED current runtime sprite atlas. Its FIRST ROW owns the exact neutral anatomy, skull/crown mass, body volume, costume, colors and eight headings. Image 2 supports costume details and genuine profile/rear anatomy only. Image 3 is STYLE ONLY: charming readable retro pixel clusters and colored outlines. Ignore every label, other character, spell, weapon, prop and anatomy in Image 3. Do not copy a different character's proportions.

Create one genuinely transparent RGBA image, approximately 2048x1280, exactly EIGHT equal columns by FIVE equal rows: 40 complete separate sprites of this ONE identical character. Generous transparent gutters, uniform cell centers, no borders, labels, text, arrows, background, checkerboard art or contact shadows. Every crown point, fingertip, cape tip and boot stays well inside its own cell.

Exact column order in EVERY row:
1 S: directly front, facing viewer.
2 SE: front three-quarter, facing screen RIGHT.
3 E: true right-facing profile.
4 NE: BACK three-quarter facing screen RIGHT, torso and back of skull turned 45 degrees AWAY; not another side or front view.
5 N: full direct back, no face on back of head.
6 NW: BACK three-quarter facing screen LEFT, torso and back of skull turned 45 degrees AWAY.
7 W: true left-facing profile.
8 SW: front three-quarter facing screen LEFT.
Whole-body orientation is genuine in each direction; do not merely turn the head, rotate a flat sprite or fake headings.

Rows top to bottom:
ROW 1 NEUTRAL CALIBRATION: relaxed upright standing with soft straight legs, armored boots planted, arms slightly clear of sides, empty fists/hands. Match Image 1 first-row anatomy and stance. This is the scale reference for all following rows, not an action.
ROW 2 ANTICIPATION: visibly flex knees, lower pelvis and bend elbows, boots planted apart; roughly 10 percent shorter overall than neutral. Real knee/hip articulation, no body scaling or compressed skull.
ROW 3 RISING TUCKED JUMP: BOTH knees fold up toward pelvis and boots tuck backward/under the body, arms open for balance. Crown-to-lowest-boot height roughly 10 percent shorter than neutral. Do not extend both legs down like standing; do not curl the whole character into a ball. Torso and head remain their neutral sizes.
ROW 4 DESCENDING FEET-READY: legs open downward beneath pelvis, knees soft, boots ready below body and arms slightly forward/outward for balance. Near-neutral height. Visibly different leg and arm silhouette from tucked ROW 3.
ROW 5 COMPRESSED LANDING: deeply bent knees and lowered pelvis with both boots spread and planted, torso leaning forward naturally, arms balancing beside knees. Clearly deeper and shorter than ROW 2, approximately 18 percent shorter overall than neutral. Preserve all actual limb lengths; no squash-scaled anatomy.

CRITICAL IDENTITY AND SIZE CONTINUITY: The approved Image 1 character has a substantial ivory skull with readable dark eye sockets, cheekbones, teeth and jaw, topped by an irregular bone crown of upward spikes/horns. Keep that exact crown-plus-skull envelope and mass CONSTANT in ALL 40 poses. The standing-equivalent native target is approximately 68 pixels tall, with the crown-plus-skull around 23-25 of those units, matching Image 1; do not miniaturize his skull to make room for armor. Neutral skull/crown and action skull/crown are the SAME size. The bare skull face has real broad cheeks and jaw, not a pinhead. Preserve the skull shape and crown points under perspective rather than replacing them with a helmet. Large body means wide solid torso, shoulder armor, thighs and heavy boots, not a taller stretched skeleton. Do not make him baby-like or huge-headed either: the approved neutral atlas is the authority.

Costume invariants: broad charcoal-black plate armor with antique gold edging, gold-rimmed spiked shoulder plates, segmented dark gauntlets, articulated gold-edged knees, substantial armored boots with small gold details, central gold belt buckle, narrow crimson/gold front tabard, red neck scarf, and ragged crimson cape down the back. Preserve the same panel shapes, skull identity, limb lengths and body volume throughout all poses. Rear views show the crimson cape and rear crown/skull. Cape can follow the body action but must not hide every leg silhouette. Empty hands only.

One common anatomical model scale and camera in every cell. NEVER enlarge a crouch, fit individual poses to their bounding boxes, shorten limbs, shrink heads, stretch torso, or squash landing. Each pose is a newly authored whole-body articulation of the same model. Keep roots centered per cell and a consistent imaginary lower registration baseline per row. Do not move the whole airborne figure upward to fake jump trajectory; runtime supplies world height. Crisp deliberate pixel clusters, dark colored edges, readable at 68px standing native height, same charcoal/gold/crimson/ivory palette and steady top-left material light as approved Image 1. No weapons, staffs, shields, spells, fire, ice, glow, particles, dust, ground plane, shadows, props, text, watermark or extra figures. True transparent alpha.

## Assembly contract

Use source row 0 only for neutral calibration. Actions select rows 1, 2, 3, 4 in anticipation, rise, fall, landing order. All columns remain S, SE, E, NE, N, NW, W, SW. One scale only; deterministic cleanup and native review are integration-lead work.

## Source review and result

One initial built-in image_gen call produced a 1586 x 992 RGBA original. No corrective call was used: source-size inspection found 8 columns x 5 rows, complete extremities, the requested heading order including genuine rear quarters, and readable action changes without a gross anatomy/grid/cropping defect. The substantial ivory skull and crown appear consistent from neutral to the four action rows. This is a qualitative source-size observation, not a measured native-scale continuity approval. The anticipation is subtler than the deep landing; cape naturally occludes some rear legs and far-side limbs. The tucked rise and feet-ready fall have different boot/arm arrangements.

Original generated file: `C:/Users/sende/.codex/generated_images/01a106a3-1c20-75d1-bb18-92725dded5ca/exec-01ad9a25-68b9-462d-a2d4-9738f959ba7b.png`.

Selected workspace source: `C:/Users/sende/Projects/hex/art_batches/pixel_actions_v2/source/red_baron/source.png`, copied byte-identically with SHA256 `da46f4dafe5403826b50c2e6058a50fbffc7cdcb70c9ea6f42344d3d91003109` (1,407,368 bytes). The PNG includes actual transparency and extensive partially transparent pixels; originals retain that alpha unchanged. Lead-owned threshold cleanup and one shared neutral-row scale remain required before native review.

No runtime files, other character files, builders, imports, exports, or lead-review records were changed. Native assembly, integration-lead acceptance, rendered idle-to-jump continuity, timing, full animation cycles, and human acceptance remain NOT_RUN.

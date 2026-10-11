# Large cast fixed-pixel source generation

Built-in image generation only. Immutable sources and original output paths are recorded in per-character receipts. No engine, runtime, import, export, deletion or commit operations were performed by this source-generation worker.

All base sheets: 1536 x 1024 RGBA, eight columns [S, SE, E, NE, N, NW, W, SW], four rows [idle, left-foot/right-arm contact, opposite contact, empty-hand cast]. Exact contact choreography and final 68px/128px calibration remain lead integration verification, not generated-source proof.

The Oll I and Ha Rekt rear diagonal source gaps were addressed by separately authorized 1024 x 1536 RGBA two-column [NE, NW] x four-row strips. Original sheets remain unchanged. See correction receipts for the Ha Rekt cast far-hand wing-occlusion note. The earlier wide Oll I correction is retained as evidence, not the preferred correction.

## Shared base prompt

```text
Use case: style-transfer.
Asset type: production pixel-art character animation source sheet for H.E.X.
Input image 1 is the character identity/costume reference only. Input image 2 is the retro pixel-art style reference only; IGNORE its old labels, held objects and magic. Input image 3 is the approved sheet/proportion/style reference only; do NOT copy its character.
Primary request: redraw the identity in image 1 as one coherent compact 16-bit pixel-art sheet, exactly 32 full-body sprites in an invisible 8-column by 4-row grid, on a genuinely transparent RGBA background. Landscape canvas, preferably 1536 x 1024. One character in each equal cell with generous empty gutters; keep every head, hand, foot, cape, horn, tail and wing completely inside its cell. Do not render grid lines or labels.
Style: charming dense handmade retro pixel clusters, crisp stepped edges, restrained 3-4 shade material ramps and readable dark outlines, matching the references. NO smooth vector/Flash shapes, airbrush, glossy 3D, high-definition painting, blurry outlines or noise. Large tier means broad bulky chest, heavy arms and thick legs; a compact head comparable to other character sizes, not a thin stretched giant or oversized bobblehead. Complete connected anatomy in every pose.
Columns in EVERY row, left to right: 0 S = precisely symmetrical direct front, both eyes; 1 SE = 45-degree front-right three-quarter; 2 E = strict 90-degree right-facing profile; 3 NE = 135-degree rear-right three-quarter, show BACK of head/torso, NO frontal eyes or front chest; 4 N = direct full back, NO face; 5 NW = 225-degree rear-left three-quarter, show BACK of head/torso, NO frontal eyes or front chest; 6 W = strict 270-degree left-facing profile; 7 SW = 315-degree front-left three-quarter. All eight directions must be clearly distinct, proper rotation of one design, not repeated front views.
Rows top to bottom: row 0 neutral idle standing; row 1 walking contact with anatomical LEFT FOOT forward and RIGHT ARM forward, opposite limbs behind; row 2 opposite walking contact with RIGHT FOOT forward and LEFT ARM forward, visibly different from row 1; row 3 active empty-hand casting stance, BOTH HANDS lifted and extended toward the character's facing direction, open palms/fingers. Exactly these FOUR rows, no additional rows.
Keep the identity, clothing, colors, anatomy and head size stable across all 32 sprites. Hands are EMPTY, including the casting row; keep intrinsic armor gauntlets, but remove all weapons, staves, shields and held props. No baked spells, elemental effects, aura, sparkles, floating debris, smoke, shadows, floor, scenery, text or symbols outside clothing. All unused pixels must have alpha 0, not a checkerboard picture or colored matte.
```

## Treevor the Mason (treevor_mason)

- Race/tier: treefolk / large
- Source: `../source/treevor_mason/source.png`
- Receipt: `../source/treevor_mason/receipt.json`
- Original output: `C:\Users\sende\.codex\generated_images\01a0f9b8-7f02-7203-8a99-a2a2e2cf443d\exec-56220ed5-ab6b-4ce4-afd3-7e7124952eb1.png`
- Status: `accepted_source_candidate`

Identity prompt appended to shared base:

```text
Character identity: TREEVOR THE MASON, a LARGE TREEFOLK. Living warm-brown bark body, expressive small yellow eyes and carved wood face, branch crown with green leaves, layered leafy green shoulder mantle and leaf skirt, brown belt with gold square buckle, huge segmented stone masonry gauntlets on BOTH arms, thick rootlike feet. No staff, no detached leaves or magic. Preserve the heavy tree trunk torso and iconic stone fists.
```

## Oll' I (oll_i)

- Race/tier: werewolf / large
- Source: `../source/oll_i/source.png`
- Receipt: `../source/oll_i/receipt.json`
- Original output: `C:\Users\sende\.codex\generated_images\01a0f9b8-7f02-7203-8a99-a2a2e2cf443d\exec-84f6339e-d102-48be-93b4-f595337e1649.png`
- Status: `source_candidate_with_facing_gap`

Identity prompt appended to shared base:

```text
Character identity: OLL' I is a LARGE WEREWOLF, never a minotaur. Use only the WEREWOLF identity in image 1: muscular brown fur, lupine long muzzle with visible ivory fangs, pointed wolf ears, shaggy mane, thick furry tail, massive clawed wolf hands and clawed feet, brown leather wrist cuffs with gold studs, leather cross-body harness with a gold center ring, broad dark belt with square gold buckle, short tattered burgundy-red studded loincloth panels. No horns, no cattle nose, no weapons or shield. Keep the compact wolf head with heavy broad shoulders, thick arms and short strong legs.
```

## Fluup (fluup)

- Race/tier: orc / large
- Source: `../source/fluup/source.png`
- Receipt: `../source/fluup/receipt.json`
- Original output: `C:\Users\sende\.codex\generated_images\01a0f9b8-7f02-7203-8a99-a2a2e2cf443d\exec-f5ac60eb-a34c-4b15-bfd5-ed7ade0342f8.png`
- Status: `accepted_source_candidate`

Identity prompt appended to shared base:

```text
Character identity: FLUUP, a LARGE ORC. Broad muscular olive-green orc, short black spiky mohawk, compact square orc face and two modest lower ivory tusks, pointed ears. Two rounded silver-steel plate pauldrons with several stout spikes, chunky brown leather bracers with metal plates, green chest with brown crossed leather straps and central steel ring, ragged brown leather skirt, belt with square gold buckle, rounded steel kneeguards and heavy brown leather armored boots. Match image 1 design exactly; do not change the outfit to the older poster outfit. In rear diagonals show green rear skull and black hair rather than eye/tusks; the head faces away in alignment with the back-facing torso. Empty green fists in first three rows, empty open hands in casting row.
```

## Ha Rekt (ha_rekt)

- Race/tier: wyrmborn / large
- Source: `../source/ha_rekt/source.png`
- Receipt: `../source/ha_rekt/receipt.json`
- Original output: `C:\Users\sende\.codex\generated_images\01a0f9b8-7f02-7203-8a99-a2a2e2cf443d\exec-7851a6a8-7336-47a8-a54a-7444678fcb06.png`
- Status: `source_candidate_with_facing_gap`

Identity prompt appended to shared base:

```text
Character identity: HA REKT, a LARGE WYRMBORN HUMANOID, never a quadrupedal dragon. Exactly TWO strong legs, TWO arms, and TWO separate attached batlike wings. Compact dark indigo-blue dragon head with paired ivory backward horns, small amber eyes, short dragon snout; broad muscular blue scaled humanoid body. Deep burgundy-red plate-and-leather breastplate/shoulder armor trimmed with gold, red-gold front tabard, gold buckle, stout dark gauntlets, thick clawed feet, one thick dark-blue scaly tail connected to pelvis. Wings are purple-blue membrane with dark navy bones, lifted beside shoulders but not enormous; keep BOTH wings and full tail inside each cell, never cropped or fragmented. Match image 1 costume (red and gold), not the old poster black outfit. Heads in the fourth and sixth sprite of every row face away along the rear-facing torso: only back skull, horns, ear/cheek edge, NO visible eyes or open mouth. No staff, sword, shield, effects or fire.
```

## Dr. Apex (dr_apex)

- Race/tier: stoneborn / large
- Source: `../source/dr_apex/source.png`
- Receipt: `../source/dr_apex/receipt.json`
- Original output: `C:\Users\sende\.codex\generated_images\01a0f9b8-7f02-7203-8a99-a2a2e2cf443d\exec-9124d945-5ee8-426f-8a74-a88b555e4537.png`
- Status: `accepted_source_candidate`

Identity prompt appended to shared base:

```text
Character identity: DR. APEX, a LARGE STONEBORN. Broad living dark-gray stone humanoid with compact bald angular stone head, small cyan-blue eyes, carved heavy brows and jaw. Entire body dark grey stone segmented plates with natural cracks; thick rounded stone fists and broad heavy boots. Slate-gray full plate armor with thick polished gold edging, rounded pauldrons, knee guards and shin plates. Bright cyan diamond-shaped chest crystal in a gold setting is INTEGRATED INTO ARMOR, never floating or glowing aura. Narrow teal-green tabard with gold border and square gold belt clasp. Match image 1. No staff or shield, no worn tools, no generated particles. Make fourth and sixth sprites in every row show BACKS of stone heads, no blue eyes, chest diamond fully hidden behind back armor. Keep every pose comfortably centered with 24+ pixels of empty room above and below, especially casting fingers.
```

## Grimm Bow (grimm_bow)

- Race/tier: troll / large
- Source: `../source/grimm_bow/source.png`
- Receipt: `../source/grimm_bow/receipt.json`
- Original output: `C:\Users\sende\.codex\generated_images\01a0f9b8-7f02-7203-8a99-a2a2e2cf443d\exec-89908dfa-4f7e-4077-87af-9fc35185b37d.png`
- Status: `accepted_source_candidate`

Identity prompt appended to shared base:

```text
Character identity: GRIMM BOW, a LARGE TROLL. Muscular bulky purple-skinned troll, compact broad face, yellow eyes, two short cream horns curving up and out at temples, ivory lower tusks, swept thick black hair and a black mane down upper back. Heavy dark brown rounded leather/metal shoulder pads edged gold with small gold rivets, crossed brown chest straps, dark brown bracers with gold bands, layered dark leather hip armor with gold edging, short tattered burgundy center loincloth, large round gold belt buckle, thick armored shin cuffs but PURPLE exposed clawed toes. Preserve current costume in image 1. No bow despite his name, no weapon or shield, no magic. Rear diagonals should show the thick black rear hair/mane completely hiding the eyes and tusks. Wide thick torso and limbs, medium-small compact head; never a skinny elongated monster. All figures have 24-pixel minimum vertical padding, and no sprite crosses a cell.
```

## Ba Djoh (ba_djoh)

- Race/tier: minotaur / large
- Source: `../source/ba_djoh/source.png`
- Receipt: `../source/ba_djoh/receipt.json`
- Original output: `C:\Users\sende\.codex\generated_images\01a0f9b8-7f02-7203-8a99-a2a2e2cf443d\exec-7026ad23-9948-4af5-98a3-bea9d5faa01f.png`
- Status: `accepted_source_candidate`

Identity prompt appended to shared base:

```text
Character identity: BA DJOH, a LARGE MINOTAUR. Warm dark-brown fur, very broad muscular shoulders/chest, compact bull head with a wide dark muzzle, black nostrils, two cream horns curving out then upward, shaggy black-brown mane. Brown leather diagonal chest harness joined with gold rings, bare fur chest, thick dark brown bracers with gold rims and rivets, broad belt with LARGE ROUND GOLD buckle, burgundy-red ragged loincloth panels trimmed gold, short thick furry legs and large black CLOVEN HOOVES. One brown bull tail with a dark tuft, visibly attached, fully contained in each cell. Current identity and costume come from image 1; ignore the old poster names entirely. Not a wolf: no pointed canine muzzle, no clawed feet, no wolf ears. No axe, shield, weapon or held item. Fourth and sixth sprites of each row show rear skull, mane and horns: no eyes, no muzzle front. Cast with empty open humanoid hands. Leave at least 24px clear space above horns and below hooves inside each cell.
```

## Urzh (urzh)

- Race/tier: stoneborn / large
- Source: `../source/urzh/source.png`
- Receipt: `../source/urzh/receipt.json`
- Original output: `C:\Users\sende\.codex\generated_images\01a0f9b8-7f02-7203-8a99-a2a2e2cf443d\exec-d06f17e2-7bb6-4c1c-ac1b-7414a4190c22.png`
- Status: `accepted_source_candidate`

Identity prompt appended to shared base:

```text
Character identity: URZH, a LARGE STONEBORN. Broad heavy humanoid built from rugged dark charcoal and slate-gray volcanic rock slabs. Jagged compact stone crown/skull, orange-yellow eyes, chiseled angular face and small stone teeth; large stone spikes are INTEGRAL to the shoulders and head. Thick forearms and legs, blocky connected hands and feet. Thin ochre-orange fissures within the rock surfaces are part of skin, not projected magic or emitted glow. A plain dark-brown belt with gold buckle and one small dark rock/leather front loin plate. Unlike Dr Apex, NO polished plated suit, NO cyan gem, NO teal cloth, no external armor silhouette. Preserve image 1 rocky body and rock color balance. Rear heads must show only jagged rear stones and NO eyes/face; exact front S has equal eyes and centered face. No fire, particles, detached rocks, smoke, aura or shadow. Every rocky finger, toe and shoulder spike fully inside each cell with 24px clear vertical padding.
```

## Joh Haynes (joh_haynes)

- Race/tier: orc / large
- Source: `../source/joh_haynes/source.png`
- Receipt: `../source/joh_haynes/receipt.json`
- Original output: `C:\Users\sende\.codex\generated_images\01a0f9b8-7f02-7203-8a99-a2a2e2cf443d\exec-59661e9b-9b07-4538-b6ac-99f54ca5fd65.png`
- Status: `accepted_source_candidate`

Identity prompt appended to shared base:

```text
Character identity: JOH HAYNES, a LARGE ORC. Broad stocky olive-green veteran orc with compact stern face, modest ivory lower tusks, thick black beard and tied-back black hair in a short ponytail/topknot held with gold band. Heavy rough dark-brown fur shoulder mantle/collar, bronze-brown pauldrons with gold edges and rivets, rugged layered brown leather chest armor/straps and hip panels, wide belt with ROUND gold buckle, short forest-green tabard with gold border, thick leather/brass wrist bracers and big brown armored BOOTS. Preserve image 1 design. Clearly distinguish him from Fluup: black beard/ponytail, fur collar, bronze rather than silver pauldrons, green tabard. Hands uncovered green and EMPTY, open in casting row. Fourth/sixth sprites face rear-diagonally and show black ponytail/back of head, no eyes/tusks or forward beard face. No helmet, axe, shield, staff, tool, floating effects or particles. Full body in all cells with generous empty gutters.
```

## Supplemental rear-only corrections

### oll_i

- Source: `../source/oll_i/rear-correction.png`
- Receipt: `../source/oll_i/rear-correction-receipt.json`
- Mapping: columns NE, NW; rows idle, left-foot/right-arm contact, opposite contact, empty-hand cast.

```text
Use case: precise-object-edit.
Create a NARROW REAR-VIEW CORRECTION STRIP for the same OLL' I brown WEREWOLF in the input source sheet. Preserve that exact pixel-art identity, costume, colors, compact head scale, broad heavy torso and chunky arms/legs. Do not redesign or add objects.
Output exactly EIGHT full-body sprites in TWO columns and FOUR rows, tall canvas, genuinely transparent RGBA. No other views anywhere.
LEFT column = BACK-RIGHT at 135 degrees: the whole character, including skull, is turned diagonally AWAY from camera toward upper-right. Camera sees the broad BACK, back of ears, rear mane, rear belt, tail, and rear of limbs.
RIGHT column = BACK-LEFT at 225 degrees: the whole character, including skull, is turned diagonally AWAY from camera toward upper-left.
CRITICAL: EVERY HEAD IS A REAR HEAD. Zero visible eyes. Zero front muzzle. Zero teeth. Zero front chest. Do NOT look sideways or look back at viewer. Do NOT use profile heads. Make back-facing wolf ears and shaggy rear mane, with the muzzle hidden on the far side. A face must never be drawn anywhere on this sheet.
Rows: top neutral idle with empty hands lowered; second walking contact anatomical LEFT foot forward / RIGHT arm forward; third opposite contact RIGHT foot forward / LEFT arm forward; fourth casting BOTH EMPTY hands lifted and reaching AWAY from the camera in facing direction. Make the two walking rows genuinely opposite leg/arm contacts.
Keep original brown furry werewolf identity, gold-ring leather cross-back harness, studded dark bracers, burgundy-red ragged loincloth, large brown furry tail attached to pelvis, clawed feet. Not a bull, no horns. Keep charming crisp dense pixel clusters, no smooth painting.
Huge clear transparent gutters between all eight sprites, minimum 30px all around every body including hands and tail. Whole head/body/feet always in frame. NO effects, shadows, particles, held weapons, spells, text, grid, background, matte, floor or extra rows. Background alpha zero.
```

### ha_rekt

- Source: `../source/ha_rekt/rear-correction.png`
- Receipt: `../source/ha_rekt/rear-correction-receipt.json`
- Mapping: columns NE, NW; rows idle, left-foot/right-arm contact, opposite contact, empty-hand cast.

```text
Use case: precise-object-edit.
Create a NARROW REAR-VIEW CORRECTION STRIP for exactly the same HA REKT dark-indigo WYRMBORN HUMANOID in the input sprite sheet. Keep his red-and-gold armor, ivory horns, purple-blue bat wings, thick blue tail, compact dragon head, broad heavy torso, chunky arms and legs, and dense crisp handmade pixel style unchanged.
Output exactly EIGHT full-body sprites in TWO columns and FOUR rows, tall canvas, actual transparent RGBA. All eight are BACK views, no front or side views anywhere.
LEFT column = BACK-RIGHT at 135 degrees: whole body and head face diagonally AWAY from the camera toward upper-right.
RIGHT column = BACK-LEFT at 225 degrees: whole body and head face diagonally AWAY toward upper-left.
CRITICAL every head shows only the BACK of skull, rear horn bases and rear neck scales. Absolutely ZERO eyes, ZERO nose or front muzzle, ZERO mouth, ZERO teeth. No head looking sideways or over the shoulder. The face is fully hidden beyond the far side of the head. We see backs of heads, backs of shoulder armor and back cross-straps, NOT fronts.
Rows: top neutral idle, empty hands lowered; second LEFT foot forward and RIGHT arm forward contact; third RIGHT foot forward and LEFT arm forward opposite contact; fourth both EMPTY open hands raised and reaching AWAY in the facing direction, no spell effect.
Exactly TWO arms, TWO legs, TWO attached wings, ONE tail in each sprite. Never a four-legged dragon. Preserve whole connected purple bat wings and tail; no detached wing fragments or clipping, no new cape. Casting hands remain visible to either side of the torso/wings. Keep a broad chunky body and head scale matching original, no skinny stretched anatomy.
Full bodies fully inside their own generous cells, at least 30px empty gutters around horns, wings, tail, hands and feet. No grid/text, weapons/staves/shields, aura, magic, fire, ice, particles, shadows, scenery, ground or colored matte. Do not add rows. All unused pixels alpha zero.
```

## Earlier wide-sheet corrections

These exact prompts and immutable original paths are retained in the corresponding base receipt; they were not accepted as clean rear-only repairs.

### oll_i

```text
Use case: precise-object-edit. Edit only the provided 32-sprite OLL' I WEREWOLF sheet. Make ONE targeted correction: in all FOUR rows, column 3 (fourth from left, NE rear-right) and column 5 (sixth from left, NW rear-left), rotate the HEAD to face AWAY together with its torso. Show rear skull/mane and back of ears. Absolutely NO EYES, NO front of face and NO teeth in these eight rear-diagonal cells. The nose may only protrude very subtly beyond far silhouette; do not show muzzle front. Rear diagonal must be 135 and 225 degrees, midway between strict profile and full back. Maintain the original character identity, muscular brown fur, leather gold harness, burgundy loincloth, bushy tail, compact bulky proportions, colors, pixel clusters, scale, and every body/hand/foot pose unchanged. All OTHER 24 cells must remain unchanged. Preserve exactly EIGHT columns and FOUR rows, idle, left-contact, right-contact, casting. Empty hands and no effects. Keep full bodies within their cells with clear gutters and genuine transparent alpha 0 background, no visible matte, grid, text, shadows, particles or extra row.
```

### ha_rekt

```text
Use case: precise-object-edit. Repair only FACING DIRECTIONS in this Ha Rekt 8-by-4 sprite sheet; retain character identity, costume, pixel style, proportions, full-body size, connected wings/tail, four distinct action rows, and transparent RGBA.
Use ONE-BASED column numbers, eight columns across:
FIRST sprite of each row, center x96: exactly symmetrical straight FRONT. Face looks directly at viewer, TWO equal eyes, centered snout and pair of horns. No three-quarter head.
SECOND sprite, center x288: keep front-right three-quarter.
THIRD sprite, center x480: keep right profile.
FOURTH sprite, center x672: rotate entire head and upper torso to REAR-RIGHT 135 degrees. We see its BACK and back of dragon skull, NOT face, NOT eyes. Look toward upper-right away from viewer. Right horn/cheek silhouette may peek, but absolutely ZERO eyes or teeth. Use the fifth sprite's back design turned slightly toward right.
FIFTH sprite, center x864: keep full back.
SIXTH sprite, center x1056: rotate entire head and upper torso to REAR-LEFT 225 degrees. We see its BACK and back of dragon skull, absolutely ZERO eyes or teeth. Look upper-left away from viewer. Use fifth sprite's back design turned slightly left.
SEVENTH sprite, center x1248: keep left profile.
EIGHTH sprite, center x1440: keep front-left three-quarter.
Apply this same facing correction independently in ALL FOUR existing rows. Do not change the idle, opposing walk contact, and hands-forward cast poses. Do not remove wings or tail. NO extra rows, spells, props, text, scenery, shadows or background. Keep hands empty. Canvas1536x1024, generous gutters, all heads and feet in frame. Actual alpha-zero transparent background.
```


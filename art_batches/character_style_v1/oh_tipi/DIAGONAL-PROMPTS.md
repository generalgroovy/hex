# Oh Tipi diagonal source prompts

Built-in imagegen; immutable source outputs. No runtime promotion implied.

## Diagonal core v1 — rejected

Target: four columns SE/NE/NW/SW and four rows grounded/jump/cast/hit.
References: original `C:/Users/sende/Pictures/oh tipi` for style and
`cardinal-core-matte-v2.png` for identity, proportions and drawing scale.
Technical background: exact uniform magenta #FF00FF. Body/clothing only,
empty hands, no effects/shadow/text. Fixed body dimensions across actions.

Full generation specification: a separate matching 4x4 companion sheet with
SE front-right three-quarter, NE rear-right three-quarter, NW rear-left
three-quarter and SW front-left three-quarter. Retain teal scales, fin crown,
small ivory face, navy/plum layered robe, ivory tabard, brass fasteners and
restrained red ribbons. Row1 ready stance; row2 bent-knee jump; row3 empty-hand
cast along facing; row4 balanced hit recoil. Every figure isolated with clear
gutters; no mirroring that swaps costume asymmetry.

Observed: generator copied cardinal views S/E/N/W instead of requested diagonal
views. Preserved as `diagonal-core-rejected-cardinals-v1.png`; not accepted.

## Diagonal core v2 — targeted correction

Use case: precise-object-edit. Input is the rejected 4x4 source sheet.
Change ONLY the character orientation in every cell by rotating the body
heading 45 degrees toward the next diagonal. Column1 must become SE
front-right three-quarter; column2 NE rear-right three-quarter; column3 NW
rear-left three-quarter; column4 SW front-left three-quarter. Preserve all
sixteen action poses, character identity, natural body proportions, source
scale, pixel material style, grid placement and exact uniform magenta matte.
Every body part and garment turns together; no cardinal/profile duplicates,
no mirrored shortcut, no added props or effects. For back diagonals show the
back and one side, not a full front tabard or a clean side profile.

Observed: v2 changes all four columns to visibly distinct front/rear diagonal
body views. Saved as `diagonal-core-matte-v2.png`; candidate, pending native-size
cross-page registration and animation review.

## Diagonal motion v1

Use case: precise-object-edit. Corrected diagonal core is the input identity,
four-heading and body-scale reference. New4x4 source on exact uniform #FF00FF.
Keep columns SE/NE/NW/SW. Change rows to walk A (left foot forward/right arm
forward), sprint A (same contact with stronger lean and longer stride), low
feet-first seated slide, tightly tucked forward roll (not another seated pose).
Keep head/torso/limb lengths, robe material length, scale, natural anatomy,
palette and side-specific costume details identical. All sixteen complete
body-and-clothing figures isolated in generous gutters. No props, magic,
weapons, staff, shadows, dust, speed lines, arrows, labels or grid.

## Diagonal phase B v1

Use case: precise-object-edit. Input is diagonal motion v1. Produce only the
opposite contacts to its first two rows as a separate4-column2-row sheet.
Keep columns SE/NE/NW/SW, same drawing scale/canvas width/body measurements.
Row1 walk B and row2 sprint B: RIGHT foot forward/LEFT trailing, LEFT arm
forward/RIGHT back, exactly opposite input A contacts in each corresponding
column. Do not mirror entire figures or swap asymmetrical ornaments. Preserve
head, torso, robe, proportions, identity, palette and pixel style. Same pure
flat #FF00FF matte, no text/grid/FX/props/shadows. No extra slide/roll rows.

Observed v1: repeated apparent A extension/foot positions. Retained as
`diagonal-phase-b-rejected-repeat-v1.png`, not accepted as opposite contacts.

## Diagonal phase B v2 — targeted limb correction

Change only legs/feet and arm swing. Column1 front-right requires the image-left
foot visibly lower/forward planted, image-right foot raised higher/back;
column4 front-left requires image-right foot lower/forward planted and image-left
foot raised back. Back diagonal columns likewise swap their currently planted
anatomical leg. Sprint must reverse the long straight front leg to the other
side and bend the former front leg backward. Change limb occlusion/order and
counter-swing clearly, not just toes. Preserve torso/head/clothing/scale,
side-specific costume, original4x2 layout and exact flat magenta. No mirrors,
new props/effects, shadow, labels or redesign.

Observed v2: some foot placement changes, but several headings still appear to
use the same leading anatomical leg as phase A. Saved as
`diagonal-phase-b-matte-v2.png` for review, NOT certified as a correct B contact.

## Final technical rejection, 2026-09-08

All six selected cardinal/diagonal pages are opaque. Their apparent magenta
background is not exact uniform #FF00FF: sampled outside-edge colors vary within
R228–251, G3–39, B228–251. No source has been chroma-keyed, painted over, or silently
accepted using a tolerance. The strict importer fails closed. No runtime PNG is
produced or promoted. Original generated files and rejected iterations remain.

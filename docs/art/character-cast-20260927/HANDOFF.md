# Full-body cast and volume-first templates

## Current user direction

The user liked the Seakin pipeline review, requested compact reference-like
proportions where size reads mainly through **volume rather than height**, then
explicitly clarified: **full-body sprites like the reference**. Complete authored
character bodies supersede the interim generated-head/shared-body combination.
The head sources and tested assembler remain reusable; they are not promoted.

Style authority: `C:/Users/sende/Pictures/styleref1.png`. Current catalogs, not old
labels on that image, own the 30 identities, race assignments and body sizes.

## Deliverables and honest scope

| Layer | Delivered design / boundary |
| --- | --- |
| Shared volume rig | Anatomy-space width/depth changes; compact fixed-length limbs; original motion keys and feet contacts |
| Whole-character art | Six generated source sheets, five identities per sheet, eight standing views per identity |
| Game-sized sprites | Measured transparent 96px cells, feet anchor (48,84), one uniform scale per character across all views |
| Inspection | Standalone native gallery; source/decoded-pixel hash checks; dark/light review; one identity resident at a time |
| Animation | The new authored full bodies have **standing directions only**; walk/run/slide/roll/cast animation remains to be authored/rigged |
| Live game | Working movement build and existing moving actors are preserved; no half-static replacement |

240 authored standing views are not 240 movement frames or 30 fully animated
playable skins. No exact numerical yaw-angle certification is inferred from the
generator's eight labeled columns. Near-front and rear-quarter readability still
require visual acceptance at game scale.

## Volume template measurements

These are measurements of the shared template comparison, **not claims that
every race's appendages occupy the same rectangle**.

| Size | Previous front width x height | New front width x height | New profile width |
| --- | --- | --- | --- |
| Small | 35 x 58 px | 37 x 58 px | 21 px |
| Middle | 39 x 63 px | 45 x 63 px | 25 px |
| Large | 41 x 68 px | 57 x 68 px | 31 px |

Large has approximately 1.77 times Small's opaque template area but only 1.17
times its height. Reprojection in anatomical space preserves real side depth;
there is no screen-horizontal stretch or per-frame silhouette normalization.
Source limbs are shortened to compact fixed lengths while support-leg and gait
phase classification remain intact. No stamina, health, hurtbox or clearance
changes belong to this art slice.

## Paths

- Volume implementation and comparison: `art_batches/character_volume_v1/`.
- Cast authority map: `art_batches/character_cast_v1/catalog.json`.
- Whole-body sources: `art_batches/character_cast_v1/reference/bodies-01.png` through `bodies-06.png`.
- Exact built-in generation prompts: `art_batches/character_cast_v1/prompts/bodies-01.txt` through `bodies-06.txt`.
- Measured source recipes: `art_batches/character_cast_v1/fullbody-recipes/`.
- Assembly: `art_batches/character_cast_v1/fullbody.py`.
- Current candidate output: `art_batches/character_cast_v1/output/fullbody-v2/` (v1 retained).
- The historical art-only ZIP duplicated all 41 files in `art_batches/character_cast_v1/output/fullbody-v2/`. The October 11 cleanup retains those source files and keeps the redundant ZIP only in the local recovery archive; it is not a Git deliverable.
- Native gallery: `art_batches/character_cast_v1/fullbody_preview.cmd`.

Generated originals are preserved. Assembly uses reviewed source rectangles,
explicit normalization of existing alpha and nearest-neighbour scaling. It does
not infer transparency from background colors or invent missing directions.

## Next integration sequence

1. Review all complete bodies at native scale; correct ambiguous direction,
   costume continuity, appendage and footprint issues in the source artwork.
2. Fit accepted art to the volume-first skeleton with separate near/far limb,
   torso, head and appendage layers. Preserve fully authored reference pixels.
3. Finish one complete Small character's real gait, slide, jump, dodge, cast and
   transition coverage, then Middle and Large. Independent travel/aim remains
   required; do not rotate a whole standing sprite to pretend it is an animation.
4. Reuse the accepted layered pipeline across the remaining 27 identities.
5. Integrate actors, Gallery, top-third portraits and afterimages coherently;
   validate bounds/hand attachments, memory residency and actual gameplay before
   replacing the selected playable checkpoint.

This is a quality dependency order, not authorization for another indefinite
iteration loop. Return bounded checkpoints with exact completed coverage.

## Verification

Freshly executed on 2026-09-27:

| Check | Result |
| --- | --- |
| Combined cast/volume Python suite | PASS: 25 tests, 15.283 seconds |
| Native preview contract | PASS: 34 checks |
| Native v2 manifest/cell validation | PASS: 30 characters / 240 authored idle direction cells |
| Native v2 rendered capture | PASS: all-character front board and S. Wayne eight-view dark/light boards |
| Isolated identity correction | Only S. Wayne's atlas changed from v1; other 29 atlas SHA256 hashes identical |
| Production identity check | PASS: p56-5dc9b5f3bdc0, 2,800 canonical production records unchanged |
| New full-body movement animations | NOT IMPLEMENTED |
| Live replacement / human acceptance / rendered performance | NOT RUN / PENDING |

S. Wayne's source skin tone was corrected using built-in image generation in
`reference/bodies-01-s-wayne-v2.png`; the other four identities on the original
sheet still use their untouched source. The exact correction prompt is saved.
V2 manifest SHA256: `b2ce2323524ecf9c625840f9c50c53d2c58f1f70866a0a632ca67f12dba11e1b`.

Lead visual review inspected the full roster and native S. Wayne dark/light
turnarounds: complete bodies, visible feet and transparent surroundings; darker
skin correction retained. This is not acceptance of every angle. Some diagonal
views remain too close to adjacent views (notably front-quarter silhouettes),
and all 240 views still need the directional-readability acceptance pass before
animation integration. Do not interpret the eight columns as exact yaw proof.

Native evidence is preserved in `evidence/` and the original isolated logs:
`.godot/fullbody-preview/20260927-112017-cae4bfba` (contract),
`20260927-114029-156aaf25` (v2 validation),
`20260927-114031-44844d47` (v2 captures). Native stderr is empty.
No gameplay source, gameplay balance, selected checkpoint, installer, commit or
remote was changed by this artwork slice. Existing dirty gameplay work remains
preserved. Offline checks do not prove live gameplay or human acceptance.

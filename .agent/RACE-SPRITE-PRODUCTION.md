# H.E.X. reusable race sprite production prompt

## Latest steering — full-body cast / volume-first sizes

Newer correction: skulls approximately the same size (18px target) across Small,
Middle and Large; body/limb volume grows. Use separate identity-locked head/body
calibration and connected source-pixel registration, not independent trim fitting.
See `docs/art/character-motion-20260927/SHARED-HEAD-UPDATE.md`.

Follow-up: refine proportions across all three sizes and expand all relevant
action/movement sprites. User explicitly approved layered skeletal animation
with reviewed authored corrections. The current motion handoff is
`docs/art/character-motion-20260927/HANDOFF.md`; its visual failure gates override
any blanket claim that logical frame coverage is complete character animation.
Measure anatomical crown-to-sole separately from horns, hair, wings and tails.

The user approved the pipeline direction, requested fuller compact size
templates, then clarified **full-body sprites like styleref1**. Work now targets
the 30 current named identities with complete authored bodies, not head grafts.
Read `docs/art/character-cast-20260927/HANDOFF.md` and its catalog audit first.
Shared templates distinguish volume/depth more than height; gameplay is unchanged.
The 189 generic race/size/presentation matrix below remains a longer-term scope,
not the active deliverable. Full-body standing turnarounds are tracked separately
from complete movement animation and live integration. Preserve the working build.

The prior Seakin pilot and its implementation contract below are historical
pipeline evidence, not a reason to undo the newer full-body instruction.

## Objective

Create coherent, reusable in-game raster sprite families for the current21 races,
three sizes and masculine/feminine/neutral appearance options. Use
`docs/art/race-sprite-production-20260927/contract.md` and its source-derived
inventory. The user's `styleref1` is style authority; current catalogs own names,
race assignments and gameplay. Do not assign unknown character genders.

## Execute with bounded delegation

1. Verify checkout `C:/Users/sende/Projects/hex` / origin generalgroovy/hex and
   preserve dirty work plus movement candidate p56-5dc9b5f3bdc0. No gameplay edits,
   commit/push, installer or selected-checkpoint changes in this art slice.
2. Lead owns reference inspection, built-in image generation, source preservation,
   final assembly review, Godot imports/runs and acceptance. Reference roles must
   be explicit; never copy obsolete weapons, magic, labels or roster from a sheet.
3. Inventory worker owns only the source-derived race/size/presentation matrix.
   Factory worker owns only offline raster assembly and its tests. Viewer worker
   owns only a standalone native candidate lab. No overlapping writes/engines.
4. First prove one reusable race family with real generated directional anatomy,
   all three sizes and appearance options. Reuse rig poses and foot contacts;
   do not generate thousands of inconsistent full-frame images or fake a side
   view by rotating a front portrait. Preserve original generated pixels and
   declared source rectangles, alpha policy, calibration anchors and hashes.
5. Reuse the existing96px cell/(48,84) pivot, visible58/63/68px size envelope,
   80base cells and512walk+512sprint logical frames per family. Keep independent
   travel/aim and travel-aligned slides. Test phase/support-leg alternation,
   genuine8facings, exact indices, alpha/gutters, clipping and stable anatomy.
   Review jumpsquat, crouch, flight, wallrun and moving-cast transitions separately
   from inherited atlas coverage. A full logical grid is not visual approval.
6. Use modest practical outfits and recognizable anatomy/materials, not only
   palette swaps. Style: crisp colored outlines, readable clustered shading,
   charming compact fantasy proportions. Body pixels exclude VFX, weapons,
   ground shadows, environment and UI. Keep race anatomy separate from physics.
7. Stage generated candidates in a native art lab. Load one family at a time;
   do not eagerly load189baked families (~7GiB). Reject bad alpha, missing poses,
   stale hashes or ambiguous headings. Keep partial anatomy/approval explicitly
   pending; never replace complete live bodies with unfinished art.
8. Return a reviewed sample, exact usable paths, evidence and defect list at the
   next bounded checkpoint. Extend to the next race only when the reusable
   pipeline and pilot style are satisfactory. Complete live promotion requires
   visual/motion acceptance and full integration coverage for portraits, Gallery,
   actors and afterimages; keep previous playable builds intact.

## This execution

-21races /30named identities /189generic appearance families inventoried.
-Seakin directional raster-part pilot selected; not a named Oh Tipi replacement.
-Image generation plus fixed-rig offline raster assembly; no new live paper-doll
 renderer and no new simulation/network state.
-Delivery target: working asset factory, complete pilot logical frames and
 native inspection lab, with any visual/anatomical defects honestly held.
-Remaining races and named-character skins are expansion work, not silently
 reported complete by template or atlas coverage counts.

## Current checkpoint

Seakin v3 is the durable technical candidate under
`art_batches/race_sprite_factory_v1/output/seakin-v3/`: nine families / 9,936
logical frames and zero geometric fallbacks. Source-generated heads and short
vests use the original motion rig. Shared geometric limbs, missing tail and
ambiguous rear-quarter art are explicitly held. See the handoff and
`pilot-status.json` in `docs/art/race-sprite-production-20260927/` for evidence.
Do not expand the same unresolved look across the other 20 races. Correct the
pilot's limb/anatomy and facing readability first, then repeat the bounded
sample, bake, native review and integration gates.

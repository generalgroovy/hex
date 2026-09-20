# Wellspring warm-ground production slice

Terrain-only, integer-pixel derivative of `art_batches/pixel_v1/map/source/build_kit.py`.
The supplied fantasy character reference informs warm sandstone, muted moss/soil,
deep water and readable dark material edges. It is a style reference, not a map
layout, texture source, collision mask or accepted character asset.

The original135 terrain IDs,32px cells, cardinal/diagonal resolution, alpha
footprints and registered rectangles are retained. Two staggered stone courses
replace the former sparse isolated paving marks. Quiet broad slab interiors
leave contrast for chemistry. Grass/earth detail stays clustered and low-density.
No structures, trees, props, obstructions, routes or chemistry areas are added.

The original four-category pixel pack is preserved byte-for-byte. The isolated
1024x180 terrain PNG is decoded once, hash-checked and cut into cached tiles;
the existing ground composer builds one campus-sized texture at configuration.
Frame rendering remains two ground calls (outside fill + ground texture), with
zero new per-tile calls. Buildings and props still use their existing assets.
Normal/reduced share identical terrain. No collision, layout, camera, physics,
visibility or navigation data is edited by this slice.

Rebuild: `python art_batches/wellspring_style_v2/source/build_ground.py`.
The editable palette and generator accompany raw/source/RGBA hashes in the
runtime manifest and a bounded alpha/seam receipt in `source/build-receipt.json`.
The adapter fails closed if the base manifest, page hashes or registrations differ.

Focused Godot suites: `wellspring-illustrated-kit,pixel-map-library` plus the raw
atlas export gate. Run `source/capture_ground.gd` through hidden Compatibility
rendering with a fresh `.godot/wellspring-style-v2-render*` output. It captures
actual production gameplay at50/75/100% in normal/reduced settings, before and
during real Steam from two paid casts; every draw must preserve world hash and
the once-built terrain texture. It does not measure sustained frame time or
claim human acceptance. Runtime/export promotion requires their actual logs,
not merely this source or Python receipt.

## Current local evidence

The first import passed. A new loader dimension comparison initially rejected
JSON floating-point arrays against integer arrays; it was corrected to compare
explicit dimension integers, without weakening page dimensions or hash checks.
The retained failed log is `wellspring-style-v2-focused.log`; the final focused
run passes9,493 assertions (1,586 illustrated-kit +7,907 pixel-map-library), with
empty stderr. Python's independent build passes1,550 alpha/seam checks.

`.godot/wellspring-style-v2-render` contains12 production screenshots plus its
receipt: quiet and actual recipe310 active state from two separately paid casts,
each at50/75/100% normal/reduced. Terrain preparation measured242ms in that
capture (159/220ms in the focused configurations), remains one build throughout,
and each draw preserves world hash. Global draw-call snapshots are288/284 for
quiet normal/reduced and393/386 during the selected active reaction state; these
are static diagnostics, not sustained120FPS proof or a before/after benchmark.

Visual review confirms the new terrain is visible at all three zooms, structures
keep their dark edge definition, and bright elemental pixels remain distinct
from the muted floor. The exact first active Steam tick still includes Fire/Water
deposit pixels; these shots do not accept final standalone Steam artwork.
No user art acceptance or exported-build acceptance is claimed here. The root
integration owner handles the strict raw-PNG export allowlist and final package.

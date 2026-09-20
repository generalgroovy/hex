# Live element artwork refinement v3

This slice supplies editable pixel drawings, not another opaque concept sheet.
The supplied character-and-magic reference informed warm inked edges, economical
highlights and readable material shapes. No pixels were copied from that image.
No new image-generation call was needed: the existing palette-index source format
is the production input and supports direct, exact-grid authorship.

## Delivered source scope

All eight elements, normal and reduced variants, across seven roles: flight,
directional flight tail, contact impact, deposit formation/active/decay and field
tile. That is **112 sequences / 480 frames** within the unchanged 474-sequence
pack. Hand accents, beam strips/caps, spray grains, reaction artwork, movement
and essential warning geometry are outside this art refinement.

- Fire: orange tongues with red/umber edges and hot yellow interiors.
- Water: blue curled flight core and lobed pools with foam highlights.
- Earth: ochre fractured mass, chips and low clusters of rubble.
- Wind: pale mint open curls and travelling ribbon fragments.
- Charge: gold broken bolts and angular branching sparks.
- Ice: cyan crystal teeth and low jagged crystal beds.
- Light: warm ivory stars and linked radiant facets.
- Dark: violet-edged inky wisps with deliberately dark interiors.

Each element retains its existing exact palette. Source cells stay 32 x 32 with
binary alpha and existing pivots; frame counts, timings, lifetime metadata,
direction conventions, composition roles and IDs are unchanged. The original
112 source files are preserved in `original-element-frames.zip`, not recovered
from Git (which contains other ongoing changes).

`source/restyle_elements_v3.py` in the pixel pack is a reproducible, bounded
authoring pass. It never runs the broad original author, changes authority or
exports an atlas. Its source comparison checks every non-pixel metadata value
against the preserved originals. Re-running it intentionally replaces only this
slice's seven basic-element roles; do not run it over later manual pixel edits.

## Contact integration

The full authored impact is now the guaranteed stationary contact stamp. The
previous workaround overlaid a borrowed looping flight core on sparse fragments;
it is no longer drawn. There is exactly one stamp even with spare decoration
capacity, and zero optional budget cannot remove it. The existing 1.5x finite
sampling, cosmetic scale and exact one-shot/outer-authority expiry are preserved.
The historical 18-tick checkpoint constant remains for old capture scripts; it
does not start or stop a borrowed imprint.

The visual bloom is not a damage disk. Matter is tiled from actual silhouettes
and must remain clipped by the live presenter to authoritative coverage. This
art does not decide whether a deposit is a short narrow trail or a larger
terminal deposit, grant a hit, change a lifetime, or create a reaction.

## Review and evidence boundary

`before-after-normal-3x.png` and `before-after-reduced-3x.png` were visually
inspected. Their left cells show the preserved previous drawings; their right
cells show the new source drawings at exact integer scale. The GIFs are labelled
authoring previews: they demonstrate a bounded contact and formation/active/decay
ordering, **not simulation timing or a gameplay capture**.

`source-proof.json` records all 112 current source hashes, exact metadata
preservation, and the original ZIP hash. Every opening contact has more opaque
material pixels than its flight core; all eight opening contact alpha shapes
are distinct in both modes. These checks establish file structure and coarse
silhouette differentiation, not human readability or artistic acceptance.

Atlas export, strict source/PNG reconstruction validation, engine import,
focused runtime tests and actual gameplay capture are coordinated separately
with the integration owner after the chemistry source freeze. See
`integration-receipt.json` when present for the observed results; source previews
alone do not establish that a running build contains these pixels.

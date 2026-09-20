# FLUX compact character baseline reference v1

Status: `concept/reference` only. These PNGs define the approved compact handheld-era proportion and silhouette direction; they do **not** replace the canonical runtime skeleton atlas.

## Size ladder

- `size_1_tiny.png`
- `size_2_small.png`
- `size_3_medium.png` — visual midpoint / primary proportion anchor
- `size_4_large.png`
- `size_5_huge.png`

Each reference sheet is 128×144 pixels, arranged as an 8-direction × 9-pose board with 16×16 reference cells. The visual direction is original compact fantasy-action pixel art: large readable heads, short bodies, strong silhouettes, restrained shading, and clear pose exaggeration.

Reference-board direction order:

`N, NE, E, SE, S, SW, W, NW`

Reference-board pose order:

`idle, walk, run, jump_takeoff, airborne/fall, landing, slide, walljump, cast/attack`

## Runtime translation contract

Production ancestry/champion overlays must still follow `docs/SPRITE-PIPELINE.md`:

- 32×32 virtual-pixel cell;
- pivot `(16, 28)`;
- canonical runtime direction order `south, south_east, east, north_east, north, north_west, west, south_west`;
- all 25 canonical animation states from the skeleton manifest;
- stable feet baseline and event frames;
- attachments may extend the silhouette but may not silently alter collision, reach, or pivot.

Use these boards for proportion, silhouette, pose language, and character paintover reference. Redraw and promote through the deterministic sprite pipeline rather than resizing these concept boards directly into runtime atlases.

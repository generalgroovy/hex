# H.E.X. full-body cast — standing turnarounds v2

30 named characters, 8 authored standing views each. **No movement animations.**
S. Wayne's darker skin is corrected in v2; the other 29 character strips are
preserved from v1. Original sources/prompts/measurement recipes remain in the repo.

Each named PNG is transparent RGBA, 768 x 96: eight 96 x 96 cells.
Order: S, SE, E, NE, N, NW, W, SW. Feet pivot inside every cell: (48,84).
Use nearest-neighbour filtering and no mipmaps. One scale per character across
all views preserves source volume; intended Small/Middle/Large front heights
are 58/63/68 pixels, with nearest-pixel quantization.

`manifest.json` contains character IDs, race/body metadata, exact rectangles,
decoded pixel hashes, source provenance and visual-review limits. These are
candidate art assets, not an installer or a complete replacement animation set.
Do not install these standing cells into every walking or casting frame.

In the source checkout, run `art_batches/character_cast_v1/fullbody_preview.cmd`
for the native gallery. Left/Right selects character; 1-8 or Tab selects direction;
B switches background; Esc closes. The playable game remains unchanged.

# Current reusable champion pages

Status: v15/extension fallback plus active new-style Steezo, Oh Tipi, S. Wayne, Waka Aren Si and Jan Wicked complete pages; further production in review.

The runtime uses `CartoonChampionPresenter` and
`content/visual/foundation_champion_visuals_v1.json`. The foundation contains
Oh Tipi, S. Wayne and The Red Baron. Wa Bidi and Grace Riva have separate pages;
The catalog retains22 same-size template declarations as fallback provenance;
the [current cast contract](../../../docs/CURRENT-CAST.md) and source-derived
`character_art` report own effective coverage after validated overrides. Remaining
substitutes are playable, not unique finished character art.

| Contract | Current value |
|---|---|
| Body guides | Small58px, Middle68px, Large76px |
| Source cell / pivot | 96x96 / (48,84), transparent gutters |
| Directions | S, SE, E, NE, N, NW, W, SW |
| Ten rows | grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b |
| Complete identity page | 768x960 RGBA, 80 registered cells |
| Sampling | Nearest, no mipmaps, fixed body scale; no per-pose fitting |
| Layers | Body, clothing and anatomy only; hands empty; effects/shadows separate |
| Gameplay | Hurtboxes15/18/21px; common18px wall clearance; sprites have no authority |

An optional validated `content/visual/champion_page_overrides_v1.json` promotes
complete reviewed pages one identity at a time without modifying fallback
provenance or changing the appearance of characters borrowing older templates.
Its active full-page residency is bounded to eight identities; the Gallery uses
small cached portraits, not the entire cast's decoded animation pages.

`foundation/runtime_atlas_eight_v15.png` and referenced source/provenance inputs
remain live dependencies. Older filenames are not grounds for deletion. Consult
`docs/SPRITE-PIPELINE.md`, `reference/art/CURRENT-CHARACTER-REFERENCE.md` and
`art_batches/character_style_v1/` before replacing any input.

# QA — Wellspring standalone map kit

## Result
**PASS for the executed standalone raster/metadata checks.**
**NOT production-approved; shared palette and authoritative checkout remain unverified.**

250 independently addressed asset IDs; 274 frame rectangles; 4 category atlases.
Terrain 135; architecture 94; props 13; ambient clips 8.
95 opaque terrain bases/interior variations. All export images use PNG RGBA.
49 opaque palette colors were actually used. Alpha is exclusively 0 or 255.

## Executed checks
- Every asset path stays inside the batch and exists. All namespaced IDs are unique.
- Every frame rectangle, pivot and descriptive footprint is within its frame/canvas.
- Every canvas is a 32px cell multiple. Durations are positive integers at 120Hz.
- All export colors belong to the source-local provisional palette. This is NOT a comparison to the unavailable shared palette.
- Individual-strip frame pixels equal the corresponding atlas regions exactly.
- All atlas frame rectangles are non-overlapping; category atlases use 2px edge extrusion.
- Five terrain families each have all masks 0–15, three extra interior variations and eight explicit corner overlays.
- 2,560 binary 3x3 neighborhoods were resolved across five family tests.
- 15,360 complete 32-pixel RGBA seam-profile comparisons at equal-material joins; 0 mismatches.
- All ten unordered material pairs have actual mixed 3x3 and 5x5 PNG examples (20 examples).
- Ambient frames share stable registration. The preview GIF uses a common cycle period to avoid a mismatched global wrap. Frame-to-frame and wrap changed-pixel counts are in `source/qa_results.json`.
- OpenRaster files have an uncompressed mimetype, stack XML, independent PNG layers and merged previews.

## Visual review scope
The contact sheets and sample courtyard are rendered from the delivered PNGs, not
concept paintings. The generated browser viewer also displays the same PNG bytes.
Review focuses on hard pixel edges, readable ground bases, upper-left light, low
floor contrast, separated occluders and restrained motion. Automated seam equality
is a technical continuity test, not proof of artistic beauty or in-game readability.
A pixel-grid courtyard and component-only/layer-separated views are supplied.

## Ambient cycles
- `map.ambient.water.ripple_a`: 180 ticks / 1.50s; changed pixels including wrap [6, 0, 6, 0].
- `map.ambient.water.ripple_b`: 180 ticks / 1.50s; changed pixels including wrap [6, 0, 6, 0].
- `map.ambient.banner.indigo`: 144 ticks / 1.20s; changed pixels including wrap [200, 201, 201, 200].
- `map.ambient.banner.heather`: 144 ticks / 1.20s; changed pixels including wrap [200, 201, 201, 200].
- `map.ambient.lantern.flame`: 72 ticks / 0.60s; changed pixels including wrap [14, 14, 14, 14].
- `map.ambient.foliage.planter`: 216 ticks / 1.80s; changed pixels including wrap [7, 0, 7, 0].
- `map.ambient.fountain.overflow`: 96 ticks / 0.80s; changed pixels including wrap [52, 58, 52, 58].
- `map.ambient.fountain.water`: 144 ticks / 1.20s; changed pixels including wrap [34, 34, 34, 34].

The GIF preview is sampled at 10fps and is not the authoritative timing artifact.
Manifest and browser timing use the actual 120Hz tick durations. No performance or
simulation determinism claim is made from the browser review.

## Explicitly unverified / not supplied
Authoritative `C:\Users\sende\Projects\flux`; reference commit `286bd8f`;
shared `visual_language_v1.json`; real character sprite references; world-unit scale;
actual Godot/runtime importer; camera pipeline; in-engine visibility and sorting;
frame rate, texture memory on target devices; gameplay, collision, navigation and
wallrun/walljump behavior. No repository content was modified or pushed.

Missing modular coverage is listed in integration.md: interiors and full directional
facades, complex roof junctions, inside water-bank corners, variable bridge spans,
functional door sequences, named per-element workbench internals and special water
structures. The completed terrain-mask coverage must not be mistaken for complete
coverage of every architectural arrangement.

## Reproduce
Run `python source/build_kit.py`, then `python source/validate_kit.py` from this
batch. The generator exits nonzero for failed raster tests. Machine-readable evidence:
`source/qa_results.json`. Neither script writes outside this batch folder.

## Independent export and browser checks
The separately executed read-only checker `source/validate_kit.py` passed on the
delivered PNGs: all 1,280 eight-neighbor signatures across five terrain families,
47 effective binary topologies per family (235 total), all 15,360 full edge-profile
comparisons, all 274 frame/atlas identities and edge extrusions, four OpenRaster
packages, and the 36-second common-period GIF. The manifest also passed the included
`source/manifest.schema.json` schema. Evidence: `source/independent_qa.json`.

Browser functional QA passed 19 checks, including every embedded PNG, searching,
category filtering, native-resolution/integer zoom, pivot overlays, exact PNG
download bytes, manifest saving, preview tabs, tick selection/wrap, no JavaScript
errors, no external page requests, and a 390px-wide mobile viewport.
Evidence: `source/browser_qa.json` and the desktop/mobile browser screenshots.

This container blocks direct file-URL navigation by administrator policy. Browser
QA therefore loaded the exact self-contained HTML via Playwright `set_content`,
not by relaxing browser policy. Direct double-click/file-URL behavior on the user's
machine is an unverified integration assumption. No engine or game was launched.
Reports carry hashes of the tested manifest/HTML. After editing or rebuilding,
rerun the independent and optional browser checks rather than reuse their results.

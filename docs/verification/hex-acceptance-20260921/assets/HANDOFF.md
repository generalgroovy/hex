# Asset audit: staged, not integrated

Audit at live HEAD `1559a566e33255c59337c5963f1c3c685d757f1f`, 2026-09-21. All writes are inside this evidence directory and `reference/acceptance-20260921/`. The staging root has `.gdignore`. No runtime, simulation, catalog, map, profile, export, or fallback was edited. No Godot process or supplied script ran. Original archives remain untouched. Spell Loom P0 remains the prerequisite for any runtime visual integration.

`inventory.json` contains every archive payload hash, byte length, raster dimensions, pixel mode, frame count, alpha statistics, decoded RGBA hash, existing duplicate paths, and 48 input-source comparisons. `audit_packs.py` is our own guarded auditor; it rejects traversal, drive paths, symlinks, duplicate names, and replacement of differing staged bytes. Re-run with `python -X utf8 docs/verification/hex-acceptance-20260921/assets/audit_packs.py`.

| Pack | Manifest payloads verified | Raster files | Existing asset duplicates | Disposition |
|---|---:|---:|---:|---|
| Animation | 58/58 | 38 | 9 | Useful references/design implementation; all nine source body PNGs already exist |
| Chemistry | 15/15 | 0 | 0 | Design/test proposals; contains no runtime PNGs |
| Map/UX | 82/82 | 17 | 3 | Useful references; geometry proposal needs new 48 px acceptance |
| VFX | 91/91 | 48 | 3 | Six useful motif sheets need a 48 px presentation adapter and actual runtime acceptance |

Archive total: 250 files, including four manifests; 246 payload hashes match their manifests. Current `assets/` and `art_batches/` contain 1,954 PNG files / 1,832 unique PNG hashes. This is an inventory count, not a claim of accepted content.

All packs reference the same old FLUX packet input manifest (`b0a9d9a54f575d6e4f056cdf0b35988ba843779d30bb0deaed130744b44175d1`). Against current H.E.X., 39/48 repository inputs match and nine differ: specification, active queue, README, court checkpoint, HexGrid, HexChemistryWorld, HexWorldSnapshot, HexCourtPresenter, SimConfig. The source packet is not a compatible replacement baseline. H.E.X. now has 48 px face-to-face cells (`HALF_WIDTH=24000`, `HALF_HEIGHT=27712`), while the VFX sheets and map's recorded 1493/1474 cell counts describe the old 64 px grid.

## Proposal decisions

| Proposal | Decision | Reason / smallest next step |
|---|---|---|
| Animation copied originals, crop strips, GIF/browser previews | Accept as reference only | Nine atlases duplicate current assets; none is newly authored replacement art |
| P01 support/contact and P03 backpedal readability | Defer implementation | Preserve eight phases and three existing rigs; first native Small contact trace is needed |
| P02 travel-aware diagonal slide | Defer implementation | Requires current action/travel/aim binding; source crops alone do not implement it |
| P04 moving cast | Defer implementation | Must bind committed shot direction and independent gait; no new production bank supplied |
| P05 cosmetic 14-tick landing | Defer implementation | New immediately interruptible visual envelope needs native transitions; no gameplay recovery delay |
| Chemistry E01 Vortex 30-to-74 px eye | Defer; incompatible unchanged geometry assumptions | Recompute actual 48 px whole-cell coverage first; intended balance change, not a performance fix |
| E02 Conflagration overlap | Defer | Alters pulse/stacking behavior and requires unchanged paid demand / event comparisons |
| E03 aggregate flow | Defer | Simulation/event ownership and fixed-point carry need explicit implementation gate |
| E04 Magma matched-strength damage | Defer | Deliberate balance rule; source/execution validation required |
| E05 Steam cooling/decay modifiers | Defer | Changes matter ledger and admission semantics; cannot ride an art change |
| E06 Steam per-region heat | Adapt after P0 | Current HEX still reads aggregated `steam_heat` in `_draw_steam`; fix within presenter only and prove overlap/heat behavior |
| VFX six Water/Fire/Steam sheets | Adapt after P0 | Transparent authored pixel motifs are useful, but require 0.75 presentation scale, exact polygon clip, phase mapping, native normal/reduced checks |
| VFX proposed material JSON | Incompatible as direct replacement | Proposal schema is not the live VisualLanguage schema; preserve current catalog and map only explicit pilot metadata |
| VFX optional UI icons and exposure ticks | Defer | Current element IDs preserved; exposure has no proved local binding and icons need actual UI contrast review |
| VFX rejected generated board | Incompatible | Explicitly rejected taxonomy/geometry/opaque-cloud exploration; retained only as evidence |
| Map two 72x72 shoulder walls / patch | Defer | Source map bytes match, but geometry algorithm/grid and acceptance changed; 64 px eligibility evidence is stale |
| Map fountain/station/ground art | Accept as reference only | Not delivered as separated production atlases; composition images are not runtime assets |
| Map remote Company / future modules | Defer | Capability and multiplayer acceptance must precede player-facing expansion |

## Smallest useful runtime asset slice after P0

Water first: use the unchanged `water-normal.png` and `water-reduced.png` from staging; copy only these into a new runtime-owned asset folder after lead approval of the implementation slice. They are 512x240 RGBA, eight 64x80 cells per row, pivot `(32,40)`, rows forming/active/decaying, nearest/no mipmaps. At 48 px geometry, sample with a 0.75 cosmetic scale (frame 48x60, pivot 24x30), retaining the exact received polygon as the clip. This does not resize or alter any original asset. Do not use an unclipped texture rectangle. Select a representative phase pose if phase-age metadata is absent rather than inventing activation/expiry timers.

Exact hook: `src/presentation/hex_court_presenter.gd::_draw_water` currently computes validated per-region style, draws fill and semantic outline, then calls `_draw_water_region_mark`. Replace only the internal mark call with a bounded texture sampler with a `false`/fallback return. Preserve `_collect_render_regions`, `_prepare_region`, `_region_edge_counts`, fill, edge, phase, expiry, and whole-cell selection. Keep all unrecognized/failed texture cases on existing mark rendering. Draw below existing bodies/aim/projectiles. Existing `draw_ground` already uses `TEXTURE_FILTER_NEAREST`.

Once Water passes, apply Fire rows ignition/active/cooling with `danger`-gated accents, then Steam rows forming/active/hot/cool/decaying with each region's intensity. Steam must remain open curls; it must not suggest concealment. `_draw_steam` currently obtains a cell heat at line 468 and passes it to `_steam_region_style`; old FLUX E06 is not present in HEX. Each normal/reduced Steam sheet is 512x400 with the same frame/pivot. All six atlases decode to 3,604,480 RGBA bytes total; that is not measured GPU cost.

Visual inspection of the three normal sheets confirms distinct low water crests, forked fire, and open steam curls. Inventory confirms transparent backgrounds with partial alpha detail, not opaque white fields. Their edges should be checked at native zoom after the 0.75 adaptation; partial-alpha pixels are authored, not a reason to enable filtered sampling. No new image generation is needed for this first slice. Reduced sheets are separately supplied and must be selected, not merely globally faded.

Required lead-owned execution: verify imports and PNG/RGBA hashes; same authoritative paid Water workload before/after; actual source and exported game capture at default/zoomed-out, normal/reduced, contrasting ground, expiration, holes/seams, dense overlap; evidence textures loaded in exported PCK; rendered cost; independent visual review. Until those run, runtime asset acceptance remains **NOT_RUN**.

## Provenance and limitations

No pack includes a LICENSE-named file or a separate explicit license grant. They are user-supplied local return packs. Their manifests and handoffs record the old source inputs; VFX says the pixel motifs were authored independently from the supplied contract and contains a reproducible `tools/build_assets.py`. That script was inspected as text for provenance and was not executed. Animation originals are byte-identical user source. Map compositions are references. These facts support traceability, not a legal certification or a redistribution grant. No third-party content was downloaded. Preserve the full source pack evidence beside any later derived asset metadata.

This handoff changes no gameplay acceptance state. It supplies staged, hash-verified candidates and integration instructions. Concept images, old screenshots, browser checks, and proposed tests are not acceptance.

# Integration map — proposal, not validated drop-in code

## Ownership

Only the local integration lead edits the current repository and schedules imports/tests/captures. This return owns its standalone package only. It contains no patch against the user's dirty checkout and no replacement for a live catalog.

Proposed live targets are `content/visual/visual_language_v1.json`, `src/presentation/hex_court_presenter.gd` and a new lead-owned texture folder such as `assets/sprites/element_material_v1/`. The exact `VisualLanguage` loader and renderer caller are missing from this packet; inspect them before naming/creating their edits. Do not add the copied historical screenshots/body sheets to the live asset catalog: they are preview dependencies, and the bodies already exist.

## Binding map

| Existing boundary | Proposed bounded change | Preserve |
|---|---|---|
| `VisualLanguage` / `visual_language_v1.json` | Parse an explicitly named optional pilot definition or map the authored fields into the current schema. Keep all original fallback keys. | Eight internal IDs, explicit Steam phase/legacy palettes, reserved style IDs, all other materials. This JSON is not schema-compatible by declaration. |
| `_collect_render_regions`, `_prepare_region` | No gameplay/coverage rewrite. Continue source validation before any asset draw. | Six exact vertices, ownership, recipe identity, quantity/presence, expiry, direction, footprint ID. |
| `_water_region_style`, `_draw_water_region_mark` | Wet meniscus, bounded hooked crest and flat harmless residue. | Water ingredient `danger=false`. No Flood chevrons or new movement effect. |
| `_fire_region_style`, `_draw_fire_region_mark` | Low ignition bud → tall unequal fork → flat ash; hot seam gated by danger. | Source ignition/active/cooling boundaries and all damage/height rules. |
| `_draw_steam`, `_steam_region_style`, `_draw_steam_region_mark` | Read **this region's** intensity for palette selection; open curl atlas and sparse scald perimeter. | `danger`, original timestamps, product identity, no concealment. Do not rewrite chemistry to fix a visual aggregation. |
| `_region_edge_counts`, `_region_edge_key`, inward strips | Retain legacy equivalence for Water/Fire/Steam; texture fill and inward material seam follow the same cells. | No cross-owner or different-expiry seam suppression. No analytic clipping after selection. |
| `draw_projectile`, `strength_scaled_size`, size cache | No formula/timer changes. Retain the current atlas or its source fallback. | Four families, remaining strength, fixed collision radius, six-tick transition, no persistent Rapid trail. |
| Renderer caller / actor ordering | Map ground fills and motifs below existing actor/projectile/aim layers after inspecting the caller. | Current occlusion/visibility rules; no global list reorder, actor skin rewrite or new mask on the simulation. |

## Safe staging sequence

First compare live source against the recorded packet and understand newer edits. Import the six PNGs under new names in a scoped branch/worktree chosen by the lead, not by replacing the source screenshot/body inputs. Validate decoded RGBA hashes, dimensions and atlas layout. Existing rendering must remain a fallback until textures and schema resolve successfully.

Switch one material at a time, starting with Water. Keep the exact received region polygon for both the low-opacity fill and the texture mask. Map the existing textured-polygon route (already used for projectiles in this presenter) to the motif atlas: for a polygon vertex `p`, local frame texel position is `frame_origin + p - motif_origin`, divided by atlas dimensions to obtain UVs. Texture sampling must stay inside the chosen frame. Nearest sampling and the transparent margins are intentional; do not enable linear filtering/mipmaps globally. Runtime backend/import behavior remains unverified.

For output-pixel snapping, adjust only cosmetic sample/draw translation, not authoritative vertices, cell selection, actor positions or collision. At 50%/75% zoom, keep at least one output pixel of legible inward boundary ink. Do not expand the outer contour to solve contrast. If unknown phase/schema/texture data reaches the adapter, retain the current validated presenter fallback; never erase a dangerous region because a new atlas lookup failed.

After Water passes local comparison, stage Fire's danger-gated morphology and Steam's regional heat palette. Leave optional actor-exposure ticks disabled until a real read-only binding and current exposure eligibility/contact are verified. Do not infer exposure from `tick-created`, intensity or a fresh timer; do not authorize new replication fields in an art slice. Missing nested snapshot code makes that client path unproved here.

## Lifecycle without new gameplay timers

The full-cell field appears as soon as authority says it is present. Formation only develops the internal material. Active marks loop without changing region membership. At `danger=false`, replace all harmful accents immediately; visual decay cannot prolong damage or imply concealment. At actual expiry, remove everything even if a final frame would otherwise persist.

Use actual `created`, `active_tick`, `decay_tick`, `expiry_tick` where locally available. `_prepare_region` does not currently preserve all phase-age fields, so an adapter may need read-only local presentation context. Missing phase age means hold a representative pose; it does not mean fabricate an activation/expiry schedule. Do not hardcode the example 24/360/60 sequence for modified Steam or shorter-lived trails. The legacy `STEAM_TICKS=600` constant is not the current unmodified product lifetime shown by `_apply_current_water_fire`.

## Coverage and overlapping records

Equivalent same-record neighbors share one continuous material silhouette; internal bright rims vanish. Retain seams when owner, footprint, phase, danger, intensity or expiry differs, matching the legacy key in this presenter. This conservative policy prevents an attractive merged surface from lying about ownership or end times. More aggressive visual clustering needs a separately tested semantic representation, not a silent tuple deletion.

Nonconvex unions, holes, isolated cells and selected cell corners must remain exact. Never discard a present zero-allocation cell. Never draw a flattened convex hull around a cluster, flood a hole, smooth the boundary into a circle or add neighboring hexes for a prettier splash.

Water sits low, Fire keeps its forks, and Steam stays open. In the pilot, the ground fill alphas at normal active intensity are Water 0.46, Fire 0.22 and Steam 0.10, the same in reduced mode. Same-cell, same-material base fills are unioned at maximum opacity rather than accumulated as cloud veils. The dangerous active record wins over fading residue; highest intensity breaks ties for the base color. Each record still retains its own edge and motif, so this does not merge gameplay records or erase other cells. Sequential three-material source-over fills leave approximately 37.9% of the background contribution before motifs: `(1-.46)*(1-.22)*(1-.10)`. This is arithmetic for the offline compositing proposal, not an engine transparency/performance measurement. Actors/projectiles/aim are rendered afterward; no opaque cloud volume, screen distortion or bloom is required.

The motif count is one atlas sample per received material-region entry; a Steam sample contains two open ribbons. There are zero free particles in either mode. Existing owner/lifecycle information wins over a decorative budget: drop cosmetic duplicate movement before an essential hazard signal. Do not reject paid effects, shorten life or reduce test demand to claim a performance gain.

## Pixel assets

All six sheets are straight-alpha sRGB RGBA8. Transparent texels have zero RGB. Cell size is 64×80, pivot `[32,40]`, 8 columns, no gutter, 2-world-pixel authored clusters. Water and Fire are 512×240 each; Steam is 512×400. Rows are listed in `definitions/atlas-layout.json`. Frame 7 of each harmless expiry row has empty motif alpha. The field's separate fill/edge still obey actual presence/expiry.

At 4 bytes per texel, all six decoded sheets contain 3,604,480 bytes of RGBA data; selecting one complete quality mode uses 1,802,240 bytes. These are texture-content sizes only, not measured GPU allocation, import overhead or FPS. Optional UI identity icons are 48×48 and do not participate in collision. The optional audio entries are descriptions only: no sound files are supplied.

Body preview inputs remain byte-identical. Their 96×96 cell and `[48,84]` foot pivot are not effect pivots. The source already bakes 58/63/68 display references; do not multiply by those presentation scales again. This task does not replace or validate the existing 64 travel/aim combinations, locomotion banks, hitboxes or character roster.

## Rollback / acceptance

Maintain the lead's previous renderer and assets. Switching a material proposal off must restore that baseline without touching sim/network files. Keep failed capture evidence and exact source identity. Only after new actual Godot captures, semantic regression, representative rendered profiling and independent human review should the lead consider integrating/promoting the slice. The historical failed dense probe is not fixed by this package.

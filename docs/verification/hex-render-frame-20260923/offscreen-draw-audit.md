# Offscreen whole-Hex draw audit

## Verdict

A function-local, conservative rejection of wholly offscreen **material-region submission** is a justified small next candidate. The source has a clean boundary after full frame preparation and full cover extraction, and the five material loops perform many pure style/geometry calculations followed only by `CanvasItem.draw_*` calls. The candidate must not cull cells from preparation, validation, cover storage, or neighbor-edge counting. It must also leave the apron, stone base, outer rim, authority, simulation, cadence, quantities, and region ordering unchanged.

This is a source-backed candidate, not a measured result. The supplied D6 state says the frozen integrated preparation candidate and native pixels passed and total draw remains 25–33 ms; this audit neither reran nor reinterpreted that evidence. It also does not establish how much of the remaining time offscreen submission consumes.

## Current coordinate and call contract

`Bootstrap._draw()` computes the interpolated focus and `camera_origin`, then installs the world transform before calling the court presenter (`src/app/bootstrap.gd:1148-1163`). The transform is:

```text
screen = world * zoom + translation
zoom = camera_zoom_percent / 100
translation = round(-camera_origin * zoom)
```

The exact source is `PixelPresentation.snapped_canvas_origin()` (`src/presentation/pixel_presentation.gd:8-17`) and `_set_world_transform()` (`src/app/bootstrap.gd:4450-4464`). Supported runtime zoom is bounded from 50% through 100% (`src/app/player_preferences.gd:27-28,778-779`). `camera_origin_for()` uses the full viewport, canvas bounds, reserved UI top, zoom, and edge clamping (`src/app/bootstrap.gd:4424-4447`). World drawing still clips against the complete viewport; the reserved UI top affects camera focus, not a safe clipping rectangle.

`HexCourtPresenter.draw_ground()` currently receives only the canvas, court, tick, reduced flag, and district-base flag (`src/presentation/hex_court_presenter.gd:110`). A presenter cannot safely reconstruct the active `draw_set_transform` from those arguments: that transform is draw-command state, and using a Node/Canvas transform getter would not be an equivalent inverse. The visible rectangle therefore must be computed once by Bootstrap from the exact translation and zoom and passed explicitly. A persistent presenter field or setter would create stale-state and reentry hazards; keep the rectangle local to the one call.

For a viewport of size `V`, the exact world-space viewport before safety growth is:

```text
Rect2(-translation / zoom, V / zoom)
```

Using `Rect2(camera_origin, V / zoom)` is close but not exact because the translation is rounded. At 50% zoom the rounding difference is up to one world pixel, which matters at a viewport boundary.

## Work that must remain global

The candidate must retain the following work exactly, even for regions wholly offscreen:

1. `_prepare_court()` and its membership/cache update (`hex_court_presenter.gd:268-300`). In normal Wellspring, `draw_district_base == false` means it uses `occupied_cells()` rather than all empty court cells (`:272-275`), but every retained occupied cell still participates.
2. `_prepare_frame_bundle()` or the generic `_current_frame_bundle()` (`:329-402`). These paths validate/read all retained cells and create complete views and canonical region dictionaries. Skipping offscreen records here could hide malformed presentation data, change the method's `false` result, or weaken the D6 behavior.
3. The empty-regions/active-material rejection (`:120-121`). It must continue to observe the complete prepared result.
4. `_cover_surface_regions` construction for all active fortify, permafrost, grounding-network, crystal-prism, and crystal-lens regions (`:122-129`). POV replacement later reuses that complete frame data (`:149-160` and `src/app/bootstrap.gd:3132-3144`). Ground visibility must not decide what cover authority/presentation data exists.
5. `_region_edge_counts()` over each complete material dictionary (`hex_court_presenter.gd:861-869`). Outline suppression depends on an offscreen adjacent region sharing the same semantic edge key (`:872-896`). Filtering before counting would invent a visible boundary at the viewport edge.
6. `canvas.texture_filter = TEXTURE_FILTER_NEAREST` (`:116`), existing material order (`:133-143`), and the order of retained regions inside each existing loop.
7. `_draw_apron`, `_draw_stone`, and `_draw_outer_rim` (`:130-145,246-326,923-933`). They are not per-material-region work. The normal distributed fixture already skips the district base; changing these paths would broaden the candidate without evidence. The rim also has a 4-pixel downward shadow and separate topology-neighbor semantics.

Authority is never filtered or mutated. Culling receives already prepared presentation dictionaries and suppresses only draw/style work whose complete conservative bounds cannot touch the viewport.

## Minimal hook and placement

The smallest production-shaped hook is an optional final `visible_world_rect` input on `draw_ground`, with an empty/default value disabling culling for existing direct callers and old-oracle tests. Bootstrap supplies the exact local rectangle. Because GDScript subclass overrides must follow the base signature, the current test-only timed and native presenter subclasses would have to add the same optional argument and forward it; that signature change is a real integration cost.

If preserving the existing overridable signature is preferred, add a second `draw_ground_visible(..., visible_world_rect)` entry and have both public entries call one private implementation. That avoids changing legacy call acceptance but requires the current draw body to move intact into the private implementation and requires draw instrumentation to wrap the new Bootstrap entry. Either form is small; do not use a presenter member cache for the view.

Propagate the local rectangle only to these submission helpers:

- `_draw_water` (`hex_court_presenter.gd:547-556`)
- `_draw_fire` (`:559-567`)
- `_draw_steam` (`:570-581`)
- `_draw_mirror_product` (`:512-544`)
- `_draw_shared_material` (`:584-596`)

Each helper must first compute `_region_edge_counts(regions_by_cell)` from the complete dictionary. Inside the existing nested `cell`/`region` loops, add one fail-open visibility test before style selection, centroid/clearance work, water sampling, mark geometry, and any `draw_*` call. Use `continue`; do not build a filtered dictionary, sort it, or change iteration order.

`draw_cover_surfaces()` should continue selecting from the complete `_cover_surface_regions` map (`:151-160`). It may pass the same local visible rectangle to `_draw_shared_material` so offscreen cover repaint submission is also rejected, but it must not filter the stored cover map or the occluder list. The POV code still needs every occluder for observer containment and shadow construction (`src/app/bootstrap.gd:3118-3163`). A simpler first candidate may leave cover repaint unculled; that is safer and still tests the dominant ground loops.

The helper should reject by the region's validated world polygon AABB, not by cell center. It should draw on any empty/non-finite/invalid bound, and it should treat boundary contact as visible. Conceptually:

```text
if culling is enabled and finite_region_bounds does not intersect(grown_visible_world, including_borders):
    continue
```

The existing preparation requires six finite world vertices and verifies them against the canonical cell polygon (`hex_court_presenter.gd:433-483`), so failures should be exceptional. Fail-open behavior still protects generic/subclass callers and future geometry changes.

## Conservative bound

Current region fills and water texture sampling use the authoritative polygon itself (`hex_court_presenter.gd:523,552,564,576,593`; `hex_water_material_presenter.gd:69-96`). Region outlines are triangulated inward (`hex_court_presenter.gd:885-920`). Most material marks derive a clearance smaller than the polygon and remain inside it (`:661-750,936-1027`). The largest explicit region-local overdraw facts are:

- active fortify's raised earth geometry requests at most 7 world pixels of height, and its implementation keeps the top and faces inside the convex source hex (`:753-783`);
- magma uses a 6-pixel polyline, whose half-width is 3 world pixels (`:691-695`);
- fire and steam use up to 4-pixel polylines (`:951-973,1000-1027`);
- normal-mode animation drift is bounded to about 2 world pixels in the shared marks (`:679-707`) and smaller fractions in fire/steam (`:975-1021`);
- the material outlines are at most 3 world pixels and are drawn inward (`:808-857,885-920`).

A conservative source-derived growth is therefore:

```text
region_margin_world = 8.0 + 1.0 / zoom
```

The eight world pixels cover the maximum authored rise and present line/motion extents; `1 / zoom` reserves one screen pixel for snapping and raster edge coverage. Across the supported 50–100% zoom range, the total margin is 9–10 world pixels. Grow the visible-world rectangle by this amount and use inclusive intersection. This intentionally keeps extra offscreen regions near an edge. It is a rejection test, not tight clipping.

There is no current material-region drop shadow beyond this polygon-local geometry. The outer-rim shadow at `+Vector2(0, 4)` is outside the candidate and remains submitted. If a future material adds a shadow, glow, displaced sprite, or height beyond this bound, its declared maximum must enlarge the margin before it can use the helper. Do not infer safety from the present `shape` name alone.

## Side effects and mutation hazards

The style and mark functions are currently read-only with respect to presenter and authority state. They read `_language`, region fields, and tick, then issue drawing commands. `HexWaterMaterialPresenter.draw_region()` performs deterministic sampling and one `draw_polygon`; textures are loaded during `configure()`, not lazily during drawing (`src/presentation/hex_water_material_presenter.gd:21-57,69-97`). Skipping these calls for a rejected region is therefore source-justified.

The following operations are not safe culling hooks:

- `_prepare_frame_bundle`, `_current_frame_bundle`, `_collect_render_regions`, or `_prepare_region`: these provide full validation and canonical data.
- `_region_edge_counts`: its result must include offscreen neighbors.
- `_cover_surface_regions`: it is reused after the ground pass.
- `_prepare_court`: it owns renderer membership and geometry caches.
- `_draw_outer_rim`: it derives topology boundaries from `_cell_set` and adds an offset shadow.
- `draw_ground` return conditions: offscreen active material must still be a successfully prepared/drawn frame, even if it submits zero region primitives.

Do not store visibility on the presenter, on each region dictionary, or in the retained frame bundle. A stored rectangle could leak between normal/reduced calls, different viewports, POV cover redraw, or test canvases. Do not mutate `regions_by_cell` or the region dictionaries: D6's prepared data and `_cover_surface_regions` share those dictionaries during the frame. The rejection counter, if added for diagnosis, must be local/test-only or reset per call and must not affect drawing.

## Required old-oracle coverage

The candidate needs an exact old-presenter versus candidate pixel oracle, with identical authority hashes and prepared frame inputs. Pixel comparisons must use full-frame RGBA8 bytes after `RenderingServer.frame_post_draw`; source/static checks alone are insufficient. Required views are:

1. Normal and reduced effects at 50%, 75%, and 100% camera zoom.
2. Camera focus in the center and at every clamped canvas edge/corner, because `camera_origin_for()` changes behavior at clamps.
3. Camera origins that produce both integer and half-step snapped translations, exercising the rounded transform inverse.
4. A region wholly outside each of the four viewport edges and corners, at distances just below, equal to, and just above the conservative margin.
5. A polygon crossing each viewport edge/corner by one screen pixel. Boundary-touching polygons must remain submitted.
6. Two semantically cohesive adjacent regions with one visible and one wholly outside, proving full edge counts prevent a new internal outline. Repeat with differing owner/phase/danger, where the real semantic boundary must remain.
7. The widest/current extreme marks: textured water, 6-pixel magma crack, active fortify/earth cover height, fire, steam/harmful steam, flood, conflagration, and at least one atmospheric shared material.
8. A visible POV physical-cover region at the viewport boundary, including the later `draw_cover_surfaces()` repaint, plus an offscreen occluder whose shadow or containment calculation still affects POV work. The material cull must not change POV mask geometry.
9. No active visible region, all active regions offscreen, and a mixture of visible/offscreen regions. `draw_ground()` must still return the same boolean as the old oracle in every case.
10. Normal Wellspring (`draw_district_base == false`) and isolated practice (`true`). Pixel equality must include the unchanged apron, stone, and outer rim even though the candidate does not optimize them.

For every oracle frame, record the old and candidate full-frame hash, world/state hash before and after, zoom, camera origin, exact visible-world rectangle, total/full/retained/rejected region counts by material, and `draw_ground` result. The counts are diagnostic only and must sum to the same prepared region cardinality. Run the existing malformed/generic/subclass presenter cases through the default no-cull path to prove public rejection behavior is unchanged.

## Practical limit

This candidate can avoid offscreen style generation, polygon/mark construction, and CanvasItem command submission after all paid global preparation. It cannot reduce the full D6 frame preparation, validation, cover extraction, or global edge-count work, and it does not touch non-region Bootstrap drawing. A pixel-equivalent result with fewer submitted regions would justify a native timing comparison; without that evidence, no draw-time improvement or release-capacity claim follows.

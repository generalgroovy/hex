# Wellspring map kit — integration notes

## Boundary and status
This is a standalone presentation-only asset batch. Everything belongs below
`art_batches/pixel_v1/map/`. It does not contain a production scene, a project-setting
change, an import plugin, a collision shape, navigation data, a gameplay script or
a shared manifest change. The courtyard is only a visual arrangement demonstration.

The authoritative Windows checkout `C:\Users\sende\Projects\flux` was not mounted.
The GitHub connector could read a remote main tree, but the requested checkpoint
`286bd8f` could not be verified (commit request returned an error). Remote main was
observed at `6d9b81875ca53c759e8001c450f262e2980e396a6c8d`; that remote tree is not
accepted as the local checkout. It did not expose the named shared palette.

**Palette approval is blocked.** `source/palette.json` is a source-local provisional
material palette, not an assertion that `visual_language_v1.json` has been matched.
No other worker's scale, palette or production assets were modified. Do not promote
these candidates until the real palette is supplied and mapped/reviewed.

## Use the standalone files
Unpack the archive into a staging folder. Its paths begin with
`art_batches/pixel_v1/map/`. Open `previews/review.html` directly in a browser; it is
self-contained and makes no network requests. It can filter all assets, play exact
frame timings, change integer zoom, inspect pivots/footprints and save individual
PNGs. Generated previews and UI labels are not importable game art.

Each `export/{terrain,architecture,props,ambient}` folder has individual PNG strips
and an optional separate category atlas. Select ONE representation in the game,
not both. `frames[].rect` addresses the individual asset PNG; `atlas_frames[].rect`
addresses the atlas. The corresponding rects have identical decoded RGBA pixels.
Rectangles are `[x,y,w,h]`, zero-based, half-open extents. Atlas padding is excluded.
PNG strips have no inter-frame padding; atlases have 2px padding/edge extrusion.

Import losslessly as RGBA, nearest sampling, no mipmaps, no smooth scaling. These
are import recommendations, not installed engine settings. Preview at integer
scales first. The archive has no engine-specific resource files. An integrator
must resolve Sprite2D/TileMap versus Sprite3D/3D texture placement from the real
checkout instead of inferring it here. If the art is textured onto a 3D surface,
check the camera and avoid applying a second perspective skew to the authored
55-degree-style imagery. World units per pixel remain unverified.

## Coordinates, layers, visibility
All ground cells are 32x32 pixels with cardinal horizontal/vertical axes. Sprites
have cell-multiple canvases. `pivot_px` is relative to a frame, not its sheet. It is
the center of the descriptive ground footprint. For placement with the top-left
of a ground footprint at `(gx,gy)`, use `(gx-fx,gy-fy)` as the sprite image origin,
where `[fx,fy,fw,fd]` is `visual_ground_footprint.rect_px`.

Footprints describe the art. **They are not collider, navigation, wallrun, jump,
step, ramp, bridge or door authority.** Cells may include transparent margins.
Follow the existing game's visibility and sorting policy, once inspected.

Facade and roof pieces share a 64x160 canvas and the same ground anchor. Combine
facade, optional closed panel and roof. A door's alpha aperture is not permission
to create a gameplay passage. Roof middle pieces connect between west/east end
pieces. Arch supports and lintel share a 96x160 canvas; retain the opening and keep
the lintel separable. Bridge decks and rails have identical registration within
each cardinal orientation. Render bridge deck first, rear/detail rails as the
existing policy requires, and keep front rails independently selectable.

Normal worldbone walls (48px visual rise), low versions (20px) and ledges (8px)
have complete 16-mask plan coverage. They use closed ends and 24px-wide connecting
arms inside the 32px cell. Sort the ground anchor consistently. Low variants are
alternatives for a reviewed visibility policy, not automatic fading or collision
substitutions. Roof, lintel and foreground rails may be grouped for a future
visibility policy; this batch does not implement one.

## Terrain — complete coverage rules
For each cell compute `mask = N*1 + E*2 + S*4 + W*8`, where each bit is 1 when that
neighbor belongs to the SAME family. Use the corresponding opaque `mask_00` to
`mask_15` tile. Outside the test grid counts as different terrain.

After placing the base, for each corner NW/NE/SE/SW:
* Add `corner_concave_*` when both adjacent cardinal neighbors match and the
  diagonal does not. The 2x2 patch closes the otherwise ambiguous inner junction.
* Optionally add `corner_convex_*` when neither adjacent cardinal matches. This
  adds inward corner wear; it does not cut alpha holes or round away walkable art.
* Add nothing in the other cases. Diagonals are immaterial unless both adjacent
  cardinals match. This represents every one of the 256 eight-neighbor signatures.

`fill_v1` to `fill_v3` substitute the base of mask 15 only. Their 2px outer collar is
identical; add needed concave corner overlays afterward. The basic mask 15 is v0.
No frame is randomly rotated or mirrored: lighting is upper-left in every export.

This is a crisp, inset material-rim transition system, not an organic 47-tile blob
with transparent bite-outs. All material pairs are supported with the same rule.
The ten unordered pairs have both 3x3 and 5x5 mixed examples. These are in
`source/seam_examples.json` and `previews/seam_*.png`; exhaustive binary local
neighborhood tests are recorded in QA. Different-family seams intentionally show
each material's border. The test asserts continuity at same-material joins.

## Ambient clips — exact 120 Hz durations
Use cumulative frame durations, not an assumed animation FPS. At tick `t`, reduce
`t` modulo the sum of durations, then select the first cumulative boundary greater
than that value. The source viewer uses this rule without changing a simulation
clock. Static assets have one frame with duration 1 and `loop=false`.

Water: add sparse ripple overlays on top of static water; recommended density at
most one animated tile in four. Do not animate all terrain. Banner: pole is static,
cloth moves by up to 2px. Lantern: flame is an ordinary physical flame below the
static housing. Planter: use either static planted version, or empty planter plus
foliage overlay; never both foliage sources. Fountain: water, basin, optional spout and ordinary overflow. Keep overflow locally bounded.
All variants retain fixed canvases, pivots and descriptive footprints. Water stays
inside the basin or tile. No magical clouds, combat effects or hazards are supplied.

## Editing and regeneration
`source/build_kit.py` is deterministic, integer-pixel raster source for every asset,
atlas, preview and manifest. `source/palette.json` holds named material ramps.
Layered `source/*.ora` documents preserve actual PNG layers for an OpenRaster-capable
editor. The individual PNGs are also directly editable. OpenRaster package structure
was checked, but opening in external editors was not tested in this environment.

Python 3.10+ and Pillow are required. No other dependency is needed:

```powershell
# Run inside this batch folder, not a production asset folder.
py -3 -m pip install Pillow
py -3 source/build_kit.py
py -3 source/validate_kit.py
```

On Linux, replace `py -3` with `python3`. To apply approved shared colors, copy only
the desired color values into a separate semantic mapping JSON below `source/`;
retain the names in `source/palette.json`. Do not point the generator blindly at an
unknown production JSON schema. Run `--palette source/approved_palette_map.json`.
The generator deliberately keeps approval marked unverified until an actual human
integration review updates the batch-local approval record. Rebuilding overwrites
this batch's generated files, including PNG edits, but never files above the batch.
Back up edits in this same batch before rebuilding. There are no network requests.

## Promotion gates and known missing coverage
1. Read the authoritative commit and shared palette; reconcile the palette exactly.
2. Compare against real 58/68/76px character sprites at the actual camera/zoom.
3. Test existing movement, visibility and sorting with a separate approved task.
4. Review environment/character contrast, roof occlusion and atlas sampling in-engine.

Not supplied: full academy interiors or four-direction building facades; roof valleys,
roof cross/T junctions and multi-story stacks; inside/re-entrant water-bank corner
pieces; a water lock or waterfall kit; arbitrary bridge spans beyond supplied 3x2
and 2x3 cell modules; functional door animations; per-element named workbench internals;
production terrain painting; integration scripts; collision/navigation/gameplay data.
The source-local palette, camera mapping and actor comparison are unverified.

### Browser-test scope
The delivered self-contained review was functionally exercised in Chromium via
an in-memory document load (`set_content`). This container blocks file-URL
navigation; direct double-click opening on the target computer was not tested.
The file has no fetch calls, external images, external fonts or CDN dependencies.
The optional `source/browser_smoke_test.py` requires Playwright and an existing
Chromium binary; it installs nothing and cleans its batch-local temporary profile.
`source/manifest.schema.json` provides an optional formal schema; the included
read-only validator does not require a JSON Schema package.

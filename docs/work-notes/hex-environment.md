# Hex-first environment foundation

Status: integrated and lead-validated in `p56-168a6c987ad5`; see
[checkpoint evidence](../HEX-RETRO-REFINEMENT.md). Complete physical hex migration
and human art acceptance remain separate. Original handoff details follow.

## Delivered scope

| Surface | Implementation | Authority |
|---|---|---|
| Whole Wellspring floor | Existing warm authored material palettes reassembled into quiet24px pointy-top hex tiles; material transitions follow whole canonical hexes | `HexGrid` geometry and existing map material classification |
| Paving, earth, grass, worldbone, water | Three deterministic material variants; low-contrast seams and short pixel clusters rather than square brick grout | Presentation only; no new water/grass physics |
| Roofs and practice-wall caps | Cached canonical hex joints clipped inside each current structure | Existing collision rectangles remain visibly intact |
| Render cost | One compiled terrain texture and cached architecture line batches; no per-frame floor classification, images or grid scan | Existing render path |
| Visible-world rejection | Optional final `Rect2` on campus drawing skips only fully distant buildings/stations using conservative visual AABBs; floor stays GPU-clipped | Presentation only; no sight or interaction changes |

Hex raster stamps use the exact fixed-point lattice:24px across and20.784px row
pitch. Pixel-center ownership shares the chemistry grid's tie breaking. There
are at most125 subpixel row phases, five families and three material variants;
temporary stamps are discarded after one setup composition. No new raster
asset pack, simulation cap, route, station, obstacle or trail was introduced.

Visible-world culling preserves the uncropped path when given an empty `Rect2`,
including native whole-map captures and unseen-terrain backdrops. Building
bounds include48px decoration/shadow padding; service bounds reach112px north
of the door and112px either side, retaining100px-high roofs and titles as they
enter the view. Tests cover boundary-touching retention and offscreen anchors
with onscreen roofs. There are no new per-frame image, array or cache builds.

## Not yet a complete hex-world conversion

Existing buildings, practice walls, doors and obstacle clearance are still
rectangular authority. Painting clipped hex joints does **not** make them
hexagonal obstacles. Do not describe this slice as full map/asset migration.
The next authority slice must atomically add authored `footprint_cells` axial
coordinates plus `grid_origin` to a versioned building definition, derive its
outer polygon from the same occupied-cell set, and feed that identical set to
collision, projectile impact, sight, topology exclusion and presentation.
Reject mixed rectangle/hex authority for one structure. Migration must preserve
18px common wall clearance, current size-specific hurtboxes, wallrun normals,
door approaches, ordinary-route widths and arena/target reachability. Replay,
snapshot identity, native visual review and wall/corner movement regressions
must pass before using six-sided poles or rounded hex-building silhouettes.

## Validation requested from integration owner

Run `hex-environment-layout` after registering it in `tests/run_all.gd`, and
`wellspring-illustrated-kit`; capture whole campus plus Commons/Chain Courtyard
at gameplay zoom. Inspect quiet terrain behind Water/Fire/Steam and dense
reaction fields. Preserve proof that floor setup never mutates map content.
No engine, import, test, capture, export or publication was run by this worker.

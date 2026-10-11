# Expanded Wellspring environment and bounded rendering

Status: **implemented and locally qualified in p60-6d80c3bce71e, October 9, 2026.**
The [final integration record](../element-expansion-evidence-20261009/integration.md)
links the passed Full/native/package gates. Native map images inspect arrivals,
menus, map pages, garden phases and paid-ground overlaps; they do not establish human wayfinding or full district art acceptance.

The authored campus is 6144 × 5376, four times the preceding canvas area. Its
original 25 buildings, six landmarks, twelve stations, four targets, thirteen
activity areas, twenty routes, ten connections and two reset zones remain exact
array prefixes. Four expeditions add distinct coast, grove, foundry and
observatory districts, twenty-four real solid walls and separate practice routes.
Movement/layout evidence and travel authority are owned by the other contributors.

Current implementation is in the [shared district palette](../../src/presentation/wellspring_district_style.gd),
[campus renderer](../../src/presentation/sanctum_campus_renderer.gd),
[illustrated ground and wall cache](../../src/presentation/wellspring_illustrated_kit.gd),
[hex ground compositor](../../src/presentation/hex_environment_layout.gd), and
[POV backdrop](../../src/presentation/pov_terrain_backdrop.gd).
[Large-world rendering tests](../../tests/unit/test_large_world_rendering.gd)
and the [native journey](../../tests/visual/capture_wellspring_expansion.gd) cover
their respective structural and sampled-rendering boundaries.

Players reach these districts through the compact Menu (Esc/controller Back or
its pointer button) and World map (M). F4 still opens the Compendium, with its
M/L3 Map action; Start remains gameplay emote. The [map contract](map-overview.md)
owns the thirteen offline arrivals and unchanged resources, spell cooldowns and
weave. The shared palette identifies places without granting a gameplay effect.

## Reference, transfer and limits

Respawn's official [Arsenal design announcement](https://www.ea.com/ea-play/news/arsenal-season-game-updates)
describes an expanded training space with a reorganized equipment core, agility
course, duel pit and town for combat practice. The applicable technique is a
legible core with purposeful surrounding practice spaces. H.E.X. preserves its
existing services and adds traversable districts instead of moving familiar
stations. The exact fourfold area, route widths and number of walls are H.E.X.
choices. The announcement describes design intent and shipped features; it does
not establish a measured learning or enjoyment improvement for this game.

Respawn's official [Upheaval map notes](https://www.ea.com/de/games/apex-legends/apex-legends/news/upheaval-game-updates)
explain replacing repetitive science-building encounters with an industrial kit,
adding smaller points of interest and changing connections between them. The
transfer is distinct architecture combined with actual route and cover geometry.
H.E.X. uses pier joints, moss-bound stone, industrial ribs and observatory plates
on real wall footprints. Ground colors alone are not presented as different
gameplay. Exact colors, silhouettes and district names are authored hypotheses,
requiring native readability and human navigation review.

The primary interview [Apex Legends: Living Legends](https://gameinformer.com/feature/2024/02/04/apex-legends-cover-story-living-legends)
quotes Respawn's world director on using controlled saturation, lighting and
landmarks to preserve gameplay priorities and guide routes. H.E.X. applies this
hierarchy with quiet stationary floor motifs and unambiguous solid wall edges.
This source supports the design principle, not an assertion that these particular
H.E.X. marks improve performance or are accepted by players.

## Concrete visual contract

- Coastal, grove, foundry and observatory cover uses real authored worldbone.
  All masonry pixels remain inside collision rectangles. No new lava, water
  damage, vertical physics, concealment or protection comes from a visual style.
- Four distinct open-line landmark motifs remain different without color or
  animation. Each new authored landmark margin has six flat decoration clusters.
  The central arrival point remains clear. Their low opacity, fixed geometry and
  absence of animation avoid suggesting a spell warning or protection halo.
- Normal and Reduced Effects share these static floors and cover. Gameplay
  projectiles, protection and field effects retain their existing render paths.
- Ground, floor segments, practice lanes, district titles, real buildings and
  landmarks are culled to their conservative visual bounds. Culling changes no
  collision, paid material, sight authority or network visibility rule.

## Allocation and cache bounds

Small-map `compose` remains available. Large maps use `compose_region`, which
keeps absolute hex cell ownership, source pixel UVs and finish classification.
The image allocation follows the requested rectangle; it does not allocate a
6144 × 5376 native RGBA image (126 MiB).

| Resource | Bound and behavior |
| --- | --- |
| Native ground regions | 512 × 512, clipped at world edges |
| Ground cache | 24 regions; at most 24 MiB decoded RGBA; least-recently-used eviction |
| Prepared source/stamp set | Existing shared 16 MiB cap; source pixel hash invalidates cached preparation |
| Explicit uncropped overview | Quarter scale, 1536 × 1344; about 7.88 MiB decoded; generated a region at a time |
| POV terrain viewport | At most 2560 × 1536; view-relative origin and UVs |
| Practice masonry | At most 1024 px per edge and 3 MiB total; actual 41 walls use 2,248,960 bytes |
| Landmark decoration | Six clusters per new district, at most 48 line vertices per cluster |

These bounds describe the owned decoded resources, not total GPU memory or the
game's total working set. Driver copies, viewport attachments, source images and
temporary composition buffers add overhead. Cold region preparation and the
explicit full overview still cost CPU time. No frame-rate claim is made without
root measurements on the current frozen source.

The POV texture has an explicit prepared world rectangle and revision. A camera
teleport, expansion or court-context change invalidates it. Bootstrap uses opaque
fallback until the matching revision is ready, so a stale image cannot be sampled
with a new origin. Unit tests simulate completion tokens; only native captures
can qualify the real renderer/compositor timing.

## Regression and peer-review boundaries

`.godot/wellspring-expansion-focus-v4/engine.log` records
`large-world-rendering` at 485 assertions/zero failures and
`wellspring-illustrated-kit` at 2,641/zero, within the seven-suite focused pass.
Its stderr is empty. Earlier v3 retained three stale assertion failures and
468 bytes of malformed-JSON stderr; quiet invalid-file parsing and the stale
oracles were repaired before v4. [Map evidence](map-overview.md#coverage-and-remaining-gates)
lists all seven results and preserves the distinction from Full qualification.
The 22-image native journey covers menus, map pages and sampled district
arrivals, not every landmark or full district traversals. Final-source review
passed separately below; no frame-time acceptance follows from this focused result.

New `large-world-rendering` tests compare real region bytes with cropped existing
whole-map composition, including non-aligned and negative origins, native source
UV wrapping, bounded absolute extents and source-pixel cache invalidation. Cache
replacement tests deliberately use a deterministic region probe to isolate the
allocation policy; they do not claim native artwork performance. Existing
`hex-environment-layout` and `wellspring-illustrated-kit` keep native pixel,
material, silhouette, source preservation and actual authored floor controls.

`pov-terrain-context` retains its full named encounter and real lifecycle checks
after explicitly preparing a bounded view. Its spy remains a forwarding oracle,
not evidence of final native frame contents.

Topology fixtures retain the literal 16,384-cell witness and the unchanged
4,096-cell validator in independent batches. New controls exercise the 65,536
cell boundary, sparse indices 0 and 65,535, shorter caller topology refusal and
the non-encodable 65,536 index. Paid cast/product caps remain unchanged.

Movement's independent renderer review found a genuine wall-art admission issue:
the old 512 px edge limit rejected new 640–832 px spans. The corrected 1024 px
edge bound is paired with the unchanged 3 MiB total cap and a one-past negative
test. Our reciprocal map review verified exact preserved prefixes and identified
a stale travel-directory reload edge for the layout owner to repair. These are
source reviews; the subsequent engine and final native receipts are linked below
as separate evidence.

## First root engine checkpoint

The preserved `.godot/wellspring-expansion-focus-v3/engine.log` passed native
terrain ownership/material tests (473,032 assertions), POV context lifecycle
(84), canonical topology bytes (432), hash specialization (316), chemistry
snapshot (1,843), shared authority (12,200) and map topology (416,316). This was
not a clean acceptance run: three test expectations failed, and the malformed
JSON reload negative emitted an engine diagnostic.

After that process ended, exact-byte-checked candidate repairs changed the
minimum viewport expectation to Godot's actual 2 × 2, floor labels to the actual
23 areas plus ten hints, and the invalid axial witness from newly legal 257 to
385. The latter uses a counter-offset so world-coordinate overflow cannot mask
the axial bound. An explicit accepted-257 control and warm-cache rejection remain.
The separate collision test now distinguishes expanded-domain acceptance from
the unchanged frozen old-domain oracle. Candidate originals and installed hashes
are retained in `.godot/large-world-baseline/renderer-focus-v3/`.

The first run reported 69 ms for illustrated setup and 3,721 ms for its complete
2,641-assertion test. These are diagnostic timings, not gameplay frame-time or
performance guarantees. At that checkpoint the repaired focused gate and actual
native travel captures were still required; later results are recorded below.

## Compact UI and cold-region follow-up

Map v2 completed its 5,531-checkpoint, 1,656-step journey and root individually
reviewed all 22 images. Its four-frame settling plus forced-draw samples were
107–3,523 ms, mean 1,098 ms. These are **historical pre-optimization capture
intervals**, not frame times or FPS. They exposed material cold CPU preparation
cost even with bounded image memory. Final v3 timings are recorded separately
below; these prior values are not measurements of the revised sampler.

The revised `WellspringIllustratedKit.GroundRegionSampler` prepares a short-lived
candidate list for each region. It includes the compositor's off-image sampling
fringe, preserves authored order and exact segment-distance tests, and falls
back to the original sampler for out-of-region requests. It changes neither
material rules nor native art/texture residency. This avoids scanning every
area, route segment and district for each local sample.

The `large-world-rendering` suite compares the optimized sampler with an
independently retained original. It visits more than 65,000 actual compositor
callback centers and 60,000 distinct cells, checks boundaries and fallback,
and compares native image bytes at ten selected seams/precedence regions.
The actual map's retained ordered segment candidates are less than one quarter
of the full-scan candidate total. These are equivalence/work-count checks, not
a measured frame-rate improvement. Layout content hashes and texture residency
remain unchanged through sampling.

`.godot/wellspring-final-ux-focus-v1/engine.log` records the following scoped
results, with zero stderr for the run:

| Suite | Assertions | Failures |
|---|---:|---:|
| `large-world-rendering` | 260,234 | 0 |
| `spell-testing-tools` | 34,833 | 0 |
| `natural-map-kit` | 81 | 0 |
| `wellspring-illustrated-kit` | 2,641 | 0 |
| `pixel-map-library` | 7,921 | 0 |
| mistaken `wellspring-architecture-kit` candidate | 142 | 3 |

That aggregate failed. The architecture candidate assumed the wrong beacon
identity and an unsupported-art refusal; it was withdrawn rather than weakening
production admission. The exact original architecture test then passed all
133 assertions with zero stderr in `.godot/wellspring-architecture-original-v1/`.
The failed log and candidate history remain preserved. No combined Full pass is
inferred from these separate runs.

The UI follow-up derives introduction height from actual bound text/font metrics
and reduces Range's maximum height to 520px, retaining its 508px small-window
height. Both independent peers found no concrete static blocker, and all 504
spell/font bounds plus lesson/Skip/HUD controls remain covered. Teaching v6
reviewed the changed cards; map v3 verified the revised renderer at sampled
arrivals. The six camera-v3 images passed 44 checks and match previously reviewed
pixels; none of these checks certifies complete exploration.

## Historical pre-garden native equivalence and cold-settling observation

The [historical pre-garden native review](../element-expansion-evidence-20261009/native-review.md)
and [receipt](../element-expansion-evidence-20261009/native/pre-garden-review.json)
verify 76 images and 141 source-hash entries for `p60-6bf50929aa6c`.
Teaching v6 passed 125 checkpoints/1,516 steps: nine changed images were
individually inspected and fifteen match individually reviewed v5 pixels.
Map v3 passed 5,531 checkpoints/1,656 steps; all 22 native images are byte-identical
to individually reviewed v2 images. Camera's six v3 images match v2; retained
wallrun and delivery pixels were reverified. This is sampled appearance and
scripted input/simulation evidence, not every landmark or full district traversal.

The [paired terrain receipt](terrain-optimization-comparison.json) records:

| Observation | Samples per capture | Before | After |
|---|---:|---:|---:|
| Mean first-arrival normal-view settling interval | 8 | 2,449.625ms | 737.75ms |
| Mean subsequent cached-view interval | 8 | Historical baseline retained in receipt | 94.625ms |
| Exact native image bytes | 22 | Baseline v2 | All identical in v3 |

The measured first-arrival mean is 69.9% lower in this sequential local
comparison. Each interval includes four frames plus forced draw/readback, so
it is not a frame duration, FPS measurement or sustained performance benchmark.
The subsequent views also used Reduced Effects; cache warmth and setting order
were not experimentally isolated, so no effects-setting causal benefit is claimed.
Synchronous cold preparation still costs hundreds of milliseconds in these
samples. The sampler has bounded work and demonstrated sampled equivalence,
but steady gameplay frame-time acceptance remains open. Full and portable qualification passed; the final integration record links their separate receipts.


## Element Garden follow-up and current gates

[garden focused v2](garden-focused-v2.json) passed four suites / **112,746 assertions**, with zero failures and zero stderr (66,360 exhibition, 993 map, 2,643 illustrated kit and 42,750 layout).

[Element Garden](element-garden.md) adds 63 physical plots in Tideglass, ordered
by ingredient count and stable mask. Six plots alternate raw deposits with their
two-source self reaction; the other 57 show mixed reactions. Across those cycles
the garden presents six raw materials and all 63 recipe identities. Its bounded
61-cell courts use actual material and lifecycle rendering without exposing live
actors to exhibit damage. All visible plots are admitted; at most 63 courts
contain 3,843 cells. Real paid ground is drawn above harmless exhibit pads.

The thirteenth destination, `element-garden`, arrives at (4880,720). Its location
label uses the 288×288 forecourt at (4736,576); the full plot directory still
covers Tideglass. The 288px plot lattice preserves 160px clearance from existing
walls and at least 72px between pad outlines. All previous geometry and travel
records remain exact; the new forecourt contributes the twenty-fourth activity
and the thirty-fourth floor label. No resources, cooldowns or weave are reset.

The [Full v3 interrupted receipt](../element-expansion-evidence-20261009/full-v3-interrupted.json)
records 79 completed suites and zero stderr but no completed Full receipt.
The final native inventory passed: **96 images**, including 42 map/region/garden images (16 garden frames, including 2 real paid-ground overlap views), 24 teaching, six camera, eight wallrun and sixteen delivery images. Full v6 passed all **237 registered suites**; native review and exact portable verification passed separately.

The historical 69.9% reduction in cold arrival capture intervals belongs to
the **pre-garden 22-image** comparison. It neither benchmarks exhibition updates
nor certifies final garden frame time; each sample included four frames and
forced draw/readback. Keep it separate from the forthcoming garden capture.

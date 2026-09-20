# Current character sprite pipeline

Status: compact shared-body source contract,2026-09-14. See
[proportion/roster checkpoint](PROPORTION-CAST-CHECKPOINT.md) for fresh validation.
Live visible heights58/63/68px and4–4.5-head anatomy are baked per size around the
same pivot; source authoring envelopes58/68/76 remain historical calibration.

Active gate: playtest the shared Small, Middle and Large skeletons before any
named-character repair or addition. The current production front door is
[wireframe motion v2](../art_batches/character_style_v1/wireframe_motion_v2/README.md),
which reuses the fixed-bone template-v2 guide and supplies 64 independent
travel/aim pairs with eight phases in each of two distinct gaits, walk and sprint,
per size. All30 live identities use their corresponding size skeleton.

Deferred character-look authority: the [current label-free cast sheet](../reference/art/cast_proportions_v5/README.md),
only after all three basic templates are complete in every direction and live
action/animation mapping and receive user acceptance. Filled80-slot coverage is
not itself proof of complete motion. Use accepted skeletons for construction and
the new sheet for later silhouette, face, clothing and material treatment.

The live path is CartoonChampionPresenter delegating to WireframeBodyPresenter
and assets/sprites/wireframe_motion_v2/manifest.json, schema 2. It loads nine shared
textures: three base, three walk and three sprint. The 3,312 registered cells
decode to 116.44 MiB total (8.44 MiB base, 54 MiB walk, 54 MiB sprint), with no
per-character copies. Source and imported-RGBA hashes must match. Lossless
imports disable alpha-border repair and mipmaps; draw sampling stays nearest.
The [current cast contract](CURRENT-CAST.md) owns identity and size mappings.
Historical foundation/override pages and catalog fallback declarations remain
provenance only; the old32px/cardinal skeleton remains retired. Detailed skin
assembly steps later in this document resume only after neutral-body acceptance.

| Invariant | Value |
| --- | --- |
| Guides | Small 58 px, Middle 68 px, Large 76 px |
| Cell/anchor | 96 x 96, feet (48, 84), transparent gutters, fixed global body scale |
| Direction columns | south, south_east, east, north_east, north, north_west, west, south_west |
| Pose/contact rows | grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b |
| Base page | 8 columns x 10 rows = 80 cells per size; 240 total |
| Each gait bank | 8 travel x 8 aim x 8 phases = 512 cells per size, packed 16 x 32 |
| All shared pages | 240 base + 1,536 walk + 1,536 sprint = 3,312 cells; nine textures |
| Sampling/layers | Nearest, no mipmaps; body/clothing/anatomy only; independent effects/shadows |
| Physics separation | Three fixed, size-specific hurtboxes; common wall clearance; neither derives from animation pixels |

Reuse size guides, landmarks, timing, direction resolution and registration.
Related anatomy shares construction guides, not cloned identity pixels. Tails/
fins/wings require reviewed pivots/occlusion. Prefer offline page assembly into
the existing renderer, not a second live paper-doll stack.

## Motion truth

Real ground distance drives a shared normalized gait phase, including contact
frames and body-pivot motion. Distance maps to one cycle per 1.30 body heights,
subject to mode-specific readable cadence limits: walking at three visual
cycles/s, sprinting at five. Stops/blocked travel freeze stepping; heading changes and
walk/sprint switches preserve phase. Air/slide/roll motion and local prediction
correction offsets do not masquerade as footsteps. Authoritative actor metadata
owns character identity, body and lifecycle; predicted data supplies motion only.

HUD and Gallery portraits are the exact top third of occupied south-grounded
source bounds (full width, ceil(height/3)), proportionally nearest-fit into a
transparent 32px cache. They do not require separately authored portrait artwork.

Both live gait banks visibly exchange anatomical support and passing legs.
Pelvis, chest and head face aim B together with zero waist yaw twist; legs stride
along travel A, using backpedaling or a short non-crossing side shuffle when
needed. Hands stay aim-ready rather than counter-swinging away from the cursor.
Sprint has independently baked longer steps, stronger lean and higher foot lift,
not simply faster playback of walking pixels. Bones, 58/68/76 body scales and
size-specific hurtboxes stay fixed. Preserve volume/direction during other base
actions; physical lift and receiving-surface shadows stay separate.

The older [six-texture skeleton checkpoint](SKELETON-MOTION-CHECKPOINT.md) is
historical: it used one shared walk/run gait bank, 1,776 cells and 62.44 MiB.
Its six base/walk PNGs were retained byte-for-byte; the current sprint bank is
additive. That checkpoint does not establish acceptance of the new nine-texture
integration. The [latest checkpoint](MOTION-AWARENESS-CHECKPOINT.md) owns combined
test, game-capture and export status. Source/asset checks and focused runtime
passes are not human movement acceptance or sustained-120-FPS evidence.

## Deferred named-character production and historical skin checkpoint

The remaining instructions and receipts describe the retained skin pipeline,
not current default skeleton texture residency. Resume named-character promotion
only after the shared neutral-body acceptance gate above.

### Skin promotion workflow

1. Small-size idle/walk-A/walk-B true-alpha pilot; light/dark background and native flipbook review.
2. Complete all 8 headings/10 rows in small boards; repeat Middle then Large raster-template acceptance, not merely construction-guide approval.
3. Obtain user acceptance of the basic sizes together; only then reuse guides for remaining identities, with unique anatomy/clothing/palette, one complete identity at a time.
4. scripts/build_character_style_pack.gd verifies SHA-locked explicit crops, gutters and global scale. Reviewed deterministic background removal is explicitly authorized; retain originals, record the source-specific mask and inspect all edges. Never use an unreviewed blanket color threshold.
5. scripts/test_character_style_pack.gd, presenter/catalog/selection tests, real 50/75/100% motion captures and Full gate.

Original Oh Tipi supports neutral pixel grammar while Small goes first; the newer
cast-look target applies only after the template gate. Portraits are not
atlases. Invalid mattes/contacts never enter the game. Keep working sheets until
replacement passes. Source provenance and accepted build inputs remain until
their consumers migrate.

The existing assembler accepts explicit `asset_kind: neutral_body_template` only
with `template_small`/Small58, `template_middle`/Middle68 or
`template_large`/Large76. These are review assets, not roster IDs. It shares
hash/crop/matte/global-scale/actual-foot checks with champion assembly, requires a
South-grounded scale reference even for partial reviews, and never promotes live.

Historical skin promotions: Steezo, S. Wayne and Waka Aren Si Small, plus Oh Tipi and Jan Wicked Middle have complete80-cell
source-playtest pages with original art, documented cleanup and native render review;
Red Baron's complete Large candidate remains unpromoted for six walk-B contacts.
Biggy Bob is held for contact repairs; Fluup's complete candidate is held for11
repeated-foot pairs, matte islands and yaw issues. Treevor's complete candidate is
held for swapped rear-diagonal contacts, west walk-B facing right and other gait/yaw defects.
Jan's NE/NW action yaw, brisk stride/coat-shading variation and single-pose roll
remain explicit visual limits, not hidden behind complete slot coverage.
Each batch records exact generation prompts, immutable sources, cleanup masks,
calibration and remaining visual limitations. No source pilot is runtime coverage.

The assembler measures the actual occupied rectangle after nearest downscaling
before applying the fixed bottom-center anchor. Resampled transparent padding
cannot create an undetected one-pixel foot shift. The independent QA viewer checks
all80 decoded baselines, binary alpha and gutters, while visual contact review
remains necessary. `scripts/review-character-sheet.ps1` provides light/dark1x/2x
pages and A/B playback without modifying source pixels.

In the retained skin path, all27 unique pages would decode to about76MiB. Its complete-page registry retains
at most eight active full textures (22.5MiB) and32px Gallery portraits; default
v15/extension fallback ownership is separate. Startup validates pages one at a
time, active-set changes prepare atomically, and stable sets do not decode per draw.
Neutral sources are test/reference fixtures, not finished body art.

For the retained skin path, `scripts/current-state.ps1 -Check` reports source-derived `character_art` coverage:
baseline/override union, exact effective template identities, and separate catalog
fallback declarations. It checks contained PNG source hashes and dimensions, not
imported RGBA or art quality. Invalid inputs withhold effective totals rather than
claim partial approval. Run `scripts/test-current-state-art-coverage.ps1` for its
isolated descriptor regressions alongside the Godot art and runtime checks.

Historical skin verification is scoped: the five-page Full passed 87 suites / 419,651 assertions
with zero failures/stderr, strict import/120 Hz boot and an isolated Windows
release EXE/PCK boot. Clone-guard focused regression passed 33,088 assertions;
source coverage passed 109 assertions/34 cases. This is not a new installer. The
[character-page checkpoint](CHARACTER-PAGES-CHECKPOINT.md) retains exact receipts.

# Staged race raster factory

This candidate-only adapter attaches **authored eight-facing RGBA head art** to
the existing `slide_v1` rig. It does not generate substitute art, rotate a front
view into profiles, change skeleton geometry, or write production assets.

The body uses the existing motion renderer's statements before its single
`head_bounds` assignment, compiled into an isolated namespace with a material
palette. The original renderer and its palette remain untouched. The adapter
fails if its source boundary changes. Head scale is measured once per body size
and locked across facings, genders, actions and phases. Only the head's anchor
moves with the original rig. There is no per-frame bounding-box normalization.

## Recipe

Create a JSON recipe beside the source PNG. Required fields:

```json
{
  "schema_version": 1,
  "race_id": "seakin",
  "source_png": "reference/seakin-heads.png",
  "source_sha256": "optional exact file hash",
  "directions": ["S", "SE", "E", "NE", "N", "NW", "W", "SW"],
  "genders": ["neutral", "masculine", "feminine"],
  "reference_head_height": 140,
  "alpha_threshold": 128,
  "heads": {
    "neutral/S": {
      "rect": [0, 0, 256, 256],
      "crown_anchor": [128, 50]
    }
  }
}
```

The sample is incomplete: supply all 24 `gender/direction` entries. Rectangles
are **measured `[x, y, width, height]` source pixels**, not assumed equal grid
divisions. `crown_anchor` is a measured `[x, y]` relative to that rectangle, at the
central skull crown (not the top of a protruding fin). `reference_head_height`
is the shared source skull crown-to-chin height corresponding to the original
rig's head sphere. Source art should keep that scale across the 24 parts. The
single uniform scale preserves differences in side fins and head silhouettes;
individual facings are never resized to their own alpha bounding box. Tune the
measurement against the first contact sheet before accepting the candidate.
Alternatively, use `chin_anchor` to attach a measured chin/neck-base anchor to
the original head bounds' bottom. Both modes retain one shared source scale.

Every normalized crop must contain nonempty art with a fully transparent border
and may not overlap another crop. The PNG must be actual RGBA with transparent
and near-opaque pixels (maximum alpha at least250). Opaque fake checkerboards
are rejected. Existing alpha is converted by the explicitly recorded threshold;
background colors are never inferred or color-keyed away. Seakin v2 source has
maximum alpha254, body alpha around253, and low-alpha background pixels; threshold127
is binary normalization of that existing alpha channel. Opaque disconnected noise inside a crop is not semantically
detectable by this validator and requires visual review.

`palette` optionally overrides the source renderer material-role dictionary;
default is cyan skin, navy clothing and subdued gold. No tail, body fins, or
other new anatomy is fabricated. All candidates explicitly remain partial
anatomy and head-only gender differentiation until a separate authored body-part
workflow exists.

## Commands (from repository root)

```powershell
python art_batches/race_sprite_factory_v1/factory.py inspect --recipe art_batches/race_sprite_factory_v1/seakin.recipe.json --out .godot/race-sprite-candidates/seakin-inspection
python art_batches/race_sprite_factory_v1/factory.py sample --recipe art_batches/race_sprite_factory_v1/seakin.recipe.json --out .godot/race-sprite-candidates/seakin-sample-v1
python art_batches/race_sprite_factory_v1/factory.py build --recipe art_batches/race_sprite_factory_v1/seakin.recipe.json --out .godot/race-sprite-candidates/seakin-v1
python art_batches/race_sprite_factory_v1/factory.py check --out .godot/race-sprite-candidates/seakin-v1
python -m unittest discover -s tests/art -p test_race_sprite_factory.py -v
```

Use a fresh candidate output directory; a directory containing `manifest.json`
will not be overwritten. Outputs are restricted to `.godot/race-sprite-candidates`
or this factory's `output` directory. Generation and Godot are not invoked.

## Preview contract

`manifest.json` has nine `variants`, keyed `small/neutral`, etc. Each points to an
RGBA atlas and a JSON frame array. Each record contains `key`, `state`, `aim`,
`atlas_index`, `bounds`, and pixel hash. Motion frames also contain `travel`,
`phase` and original-rig `support_legs`. Index addressing is:

```text
x = (atlas_index % atlas_columns) * 96
y = floor(atlas_index / atlas_columns) * 96
source rectangle = [x, y, 96, 96]
draw pivot = [48, 84]
```

Base frame keys are `state/aim`, such as `grounded/2`. Walk keys are
`locomotion/travel/aim/phase`; sprint keys are
`sprint_locomotion/travel/aim/phase`. Every variant retains all **1,104 logical
frames** (80 base + 512 walk + 512 sprint), even when byte-identical images share
an atlas index. Draw cells at native 1x pixel scale; the existing body display
heights 58/63/68 are already baked. Head ornament may extend above those skull
reference heights, which is disclosed in per-frame alpha bounds.

The export includes dark/light native and 4x direction/size boards, forward /
strafe / backpedal GIFs for both gaits, provenance hashes and an integrity
receipt. `production_ready`, `human_approved`, and `runtime_verified` are false.
Integrity PASS is not a visual style, gameplay, anatomy or human-acceptance claim.

## Optional authored torso (v2)

`seakin-v2.recipe.json` extends the unchanged head-only recipe and supplies 24
measured torso crops, collar-neck anchors and belt/pelvis anchors. Its source is
the generated `reference/seakin-torsos-v1.png`; no directional image is inferred
by rotating or mirroring another facing.

For each body/facing/gender, standing projected neck-to-pelvis length calibrates
the source scale once. Every frame uses the original rig's projected neck and
pelvis to derive an affine longitudinal axis and its perpendicular. Transverse
scale stays fixed; longitudinal scale follows rig foreshortening. Both anchors
map exactly, determinant stays positive, and transforms use nearest-neighbour
sampling. No per-frame alpha bounding-box fitting occurs. This is textured
2D bone skinning, not a new body rig or 3D garment simulation.

The adapter suppresses the old coat, torso mesh and shoulder decorations only
when this optional layer is enabled. Both leg chains lie underneath the new
coat; near arms/hands lie above it. Existing limb points and timing are unchanged.

Slide/roll are explicitly held for anatomical review. An oversized projected
hem can cross the ground even when both rig anchors map exactly. For a declared
held state only, such a pose uses the original headless geometric body instead
of clipping or secretly resizing the raster. Each occurrence is recorded under
`torso.held_pose_fallbacks` with its exact pose key and attempted overscan bounds.
Any equivalent boundary failure outside declared held states stops the build.
The source garment is not claimed to fit every extreme pose.

```powershell
python art_batches/race_sprite_factory_v1/factory.py sample --recipe art_batches/race_sprite_factory_v1/seakin-v2.recipe.json --out .godot/race-sprite-candidates/seakin-sample-v2
python art_batches/race_sprite_factory_v1/factory.py build --recipe art_batches/race_sprite_factory_v1/seakin-v2.recipe.json --out .godot/race-sprite-candidates/seakin-v2
```

The optional sample includes standing, slide and roll comparison boards before
a full bake. V2 retains the same atlas/frame-index preview schema as v1, adding
torso provenance and honest head-and-torso anatomy metadata. Tail and dedicated
race limb anatomy are still not authored. The v1 recipe and output stay intact.

## Short-vest correction (v3, technical candidate)

`seakin-v3.recipe.json` uses a separate generated short-vest source,
`reference/seakin-torsos-v2.png`. All 24 crop rectangles and neck/belt anchors were
remeasured against that image rather than copied from the longer-coat source.
The source correction removes coat tails; no body scale, rig, gameplay or cell
clipping rule changed. V1 output and the V2 sample remain historical evidence.

The V3 standing/slide/roll sample has 216 frames and zero geometric fallbacks.
Its exhaustive in-memory preflight checks all 9,936 logical frames without
exporting an atlas, including real alpha bounds and distinct eight-phase gaits.
Both extreme actions remain **visually held**: zero fallbacks proves bounds and
transform consistency, not anatomical or artistic acceptance. Generic geometric
limbs/boots, head/body proportions, ambiguous rear-quarter art and missing tail
remain explicit holds in the recipe and candidate manifest.

```powershell
python art_batches/race_sprite_factory_v1/factory.py sample --recipe art_batches/race_sprite_factory_v1/seakin-v3.recipe.json --out .godot/race-sprite-candidates/seakin-sample-v3
python art_batches/race_sprite_factory_v1/factory.py preflight --recipe art_batches/race_sprite_factory_v1/seakin-v3.recipe.json --out .godot/race-sprite-candidates/seakin-sample-v3
python art_batches/race_sprite_factory_v1/factory.py build --recipe art_batches/race_sprite_factory_v1/seakin-v3.recipe.json --out art_batches/race_sprite_factory_v1/output/seakin-v3
python art_batches/race_sprite_factory_v1/factory.py check --out art_batches/race_sprite_factory_v1/output/seakin-v3
```

Durable candidate exports live beneath `output/.gdignore`, preventing Godot
asset-import proliferation. Preview must use explicit image loading and keep
only one family atlas/frame index resident. Manifest entries report actual PNG
and frame-index file sizes plus uncompressed RGBA byte estimates; these are not
measured runtime RAM/VRAM or performance acceptance.

The durable V3 technical bake and independent integrity check passed: nine
families, 9,936 logical/unique frames, zero geometric fallbacks, binary alpha,
96px cells and the original 48/84 pivot. Seventeen offline unit tests passed.
No production promotion or engine verification is implied by those checks.

The 35 primary export files total **19,869,568 bytes (18.95 MiB)**, comprising
14,274,229 bytes of compressed family atlases, 4,219,739 bytes of frame indices,
and the remaining manifests, receipt, review boards and GIFs. Each family atlas
is 1536×6624 and decodes to **40,697,856 RGBA bytes (38.8125 MiB)**. Eagerly loading
all nine would require 349.3125 MiB for RGBA pixels alone, so the viewer loads one
family at a time. CPU/GPU duplication, driver overhead and transient decode
buffers are additional; these figures are capacity estimates, not native
memory measurements. Extra preserved review-sample receipts/boards are separate
from the 35 primary export-file total.
Including the six preserved slide/roll boards and final sample/preflight receipts
under `review-samples`, the durable candidate has **43 files, 20,499,155 bytes
(19.55 MiB)**. The copied exhaustive preflight receipt's factory and recipe hashes
match the final candidate manifest.

# Shared anatomy and volume contract

This is a **correction target for the current 30-character cast**, not a claim
that the new anatomy has already been applied to its idle sheets or animation.
Machine-readable values and per-character priorities are in
[`proportions.json`](../../../art_batches/character_motion_v1/proportions.json).

## Immediate correction

The full-body v2 builder calibrates from the **entire front opaque height**. Its
recipes explicitly include crowns, crests and horns. That means a taller horn
can shrink a character's actual skull, torso and legs. Do not carry this method
into the motion assets. Measure **anatomical skull crown to support sole**, then
use stable calibrated body and head groups for every direction and animation
frame. The latest art direction supersedes the old uniform-whole-actor rule:
**heads remain approximately the same physical size across all three sizes**;
body width, depth, torso and limb mass establish the larger class.

Wings, horns, hair volume, ears, tails, leaf canopies, coat tails and extra spider
legs are identity features, not the size template. Give them separate bounds and
draw-order annotations; preserve them without letting them determine body scale.

## One family, three volumes

| Construction measure | Small | Middle | Large |
|---|---:|---:|---:|
| Neutral anatomical height | 58 px | 63 px | 68 px |
| Anatomical skull height | 18 px | 18 px | 18 px |
| Skull height / body height | 31.0% | 28.6% | 26.5% |
| Neutral neck gap | 2 px | 2 px | 2 px |
| Shoulder-to-hip length | 15.83 px | 17.92 px | 20 px |
| Hip-to-sole length | 22.17 px | 25.08 px | 28 px |
| Core shoulder width / height | 36% | 43% | 52% |
| Core waist width / height | 28% | 34% | 43% |
| Core chest depth / height | 22% | 26% | 30% |

These are neutral construction guides before camera projection, not an instruction
to stretch existing sprites. Skull widths, muzzles, leaf faces and dwarf breadth
retain racial character. Femininity, masculinity or unspecified presentation does
not silently change the size profile or gameplay statistics. The already tested
`character_volume_v1` adapter is a reusable rig starting point, not proof that the
full-body raster artwork fits those bones.

The default anatomical skull target is **18 pixels**, with explicit reviewed
race/identity exceptions from **16 to 20 pixels**, never automatic size-class
exceptions. Hair, horns, ears, crowns, beards and foliage are excluded from skull
measurement. Head width retains the source's anatomical aspect ratio; no
independent horizontal stretching to force every race to a human-shaped head.
The remaining neutral height, after skull and 2-pixel neck, is divided 5:7
between torso and legs. This is a construction budget, not per-frame resizing.

### Stable head-group integration

[`head_contract.py`](../../../art_batches/character_motion_v1/head_contract.py)
contains pure helpers with no image, runtime or filesystem side effects:

| API | Purpose |
|---|---|
| `make_head_plan(cranial_bounds, target_height_px=18)` | Calibrate once from explicitly annotated frontal skull bounds; returns fixed isotropic `head_scale` and preserved-aspect target width. No body size parameter. |
| `relative_head_scale(plan, body_scale)` | Correct the head layer beneath an already body-scaled parent without multiplying body scale twice. |
| `place_head_point(point, source_neck, destination_neck, plan)` | Place source head geometry around the registered neck in final destination-pixel coordinates. |
| `body_budget(size, skull_height_px=18)` | Return consistent neutral crown-to-sole construction lengths totaling 58 / 63 / 68 px. |

Use `destination_neck + (source_point - source_neck) * head_scale`. Source and
destination necks may move with view/pose; the calibration does not. Head-turn
rotation and projection belong to the pose system, not a new scale inferred
from its rendered bounding box. Hair/horns attached to the head follow its
uniform transform but never determine its size. Preserve authored directional
widths and genuine depth rather than flattening every view into the frontal one.

**Integration hold:** the current automatic head partition can cut above the
chin, leaving jaw pixels on the torso. A complete head/jaw mask, stable neck
attachment, and seam/occlusion review are required before applying separate
head transforms. Opaque body bounds are not annotated skull bounds. Estimates
beneath hair remain estimates; helper validation cannot certify anatomical
accuracy. Enlarging/shrinking the head alone also changes total neutral height:
reconcile torso/neck construction once, retaining the target sole registration,
instead of resizing the full actor again. No runtime conformance is claimed.

## What the current board shows

The v2 roster and all-direction board were visually inspected. The following are
**review priorities**, not invented anatomical measurements:

| Priority | Characters | Required action |
|---|---|---|
| P0: adornment-biased scale | Oh Tipi, The Red Baron, Waka Aren Si, Spai Si, Grimm Bow, Ba Djoh, Urzh, Juul I Yaina | Annotate skull below crest, hair, crown or horns; recalibrate whole identity once. |
| P0: wings/back appendages | Grace Riva, Ha Rekt, Luuh I Zeh, Faab I Yaina | Separate core and appendage bounds; do not use wing/leg span as body volume. |
| P0: plant canopy/hood | Treevor the Mason, Leaf the Hidden, Mifu, Sai Laas | Annotate underlying head/trunk; preserve foliage as a distinct layer. |
| P1: Middle core consistency | Hesus Christo, Jan Wicked, Djonah Thaan, H. Lenee | Compare real shoulders/hips beneath costume; avoid a tall, narrow Middle family. |
| P1: dwarf exception | Biggy Bob, Don Doko Don | Keep stocky identity but share a deliberate Middle core budget; beard is not skull. |
| P1: stable reference anchors | S. Wayne, Wa Bidi, Steezo, Oll' I, Fluup, Dr. Apex, Haara, Joh Haynes | Retain identity and use annotated bodies as comparison anchors; verify rather than assume conformance. |

Current whole-alpha front widths vary from 39 to 70 pixels and include appendages.
For example Grace Riva is 62 pixels wide with wings while Juul I Yaina is 39; that
does **not** prove their Small bodies differ by that ratio. The roster's observed
overall frontal heights are 57–59 / 62–64 / 67–69 pixels, but those include adornment
and therefore cannot establish the anatomical height gate.

## Small implementation sequence

| Step | Work | Exit condition |
|---|---|---|
| 1 | Annotate skull crown/chin, shoulders, hips, sole contacts and core/appendage masks on the 30 front sources. | Every coordinate measured or explicitly unresolved; no inferred opaque-bounds substitute. |
| 2 | Register body plus a separate fixed head calibration per identity; reconcile neutral construction and compare Small/Middle/Large together. | Total heights within 1 px; skull target 18 px with reviewed 16–20 px identity exceptions; identities recognizable. |
| 3 | Transfer those anchors to all eight authored directions. | No direction-specific resizing; skull size stable to 1 px in neutral views; no wing/crest clipping. |
| 4 | Animate with fixed character proportions and genuine limb articulation. | Alternating feet, stable garment attachment, no changing skull/body scale between actions. |
| 5 | Render the complete contact sheets and movement loops in the isolated lab, then at gameplay scale. | Human visual acceptance before production replacement. |

## Required checks

- Use the same 96×96 cell and 48,84 foot pivot; source margin remains transparent.
- A posed slide, roll or crouch must get lower through anatomy and articulation,
  never by rescaling the whole actor back to a target bounding box.
- Each identity has fixed limb lengths; allowable authored-frame measurement drift
  is 3%, not an invitation to squash/stretch the skull or feet.
- Grounded support sole stays within 1 pixel of the registered baseline. Airborne
  frames follow the air-offset contract and must not be auto-planted by bbox fitting.
- Check shoulder, waist and depth ratios within 5 percentage points; torso/leg
  vertical divisions within 3.5 points; skull height 18 px by default with
  reviewed ±2 px identity exceptions and no more than 1 px neutral-view drift.
- Head scale is identity-locked across sizes and actions, neck-registered and
  isotropic; large bodies cannot silently receive proportionally larger heads.
- Inspect front/profile/rear-quarter separately: real camera projection changes
  visible width, not the character's actual anatomy.
- Keep corrected S. Wayne dark skin and all current catalog identities. The old
  reference image's weapon, race and affinity labels are not roster authority.
- Out-of-cell wings/horns require source posing/placement corrections or a held
  candidate, not shrinking its core until the attachment fits.
- No gameplay hurtbox, collision clearance, stamina or movement setting changes
  belong to this art correction. Idle acceptance does not prove motion acceptance.

## All-cast frontal calibration and three-pilot registration

[`calibration_overrides.json`](../../../art_batches/character_motion_v1/calibration_overrides.json)
now records frontal anatomical core bounds, skull crown, chin and a single scale
candidate for **all 30 identities**, plus all eight-direction joint registrations
for S. Wayne, Oh Tipi and The Red Baron. Each of those 24 pilot views has 20 named
pivots. Every front was inspected at integer 4x enlargement; pilot direction
sheets were also inspected at that scale. Hidden skull crowns, shoulders, pelvis
and joints underneath hair/coats/capes are explicit anatomical estimates, not
visible measurements or physically validated bone lengths. Source SHA256 values
lock all 30 annotations to fullbody-v2. The other 27 identities' movement joints
remain heuristic and are labeled accordingly.

| Pilot | Estimated front anatomical height | Target | Historical uniform scale candidate |
|---|---:|---:|---:|
| S. Wayne | 54 px beneath hair | 58 px | 1.0741 |
| Oh Tipi | 52 px beneath crest | 63 px | 1.2115 |
| The Red Baron | 59 px below crown | 68 px | 1.1525 |

| Other frontal cores | Confidence and excluded silhouette features |
|---|---|
| Dr. Apex, Faab I Yaina | Higher confidence: visible stone dome / bald skull; angel wings excluded. |
| Grace Riva, Ha Rekt, Ba Djoh, Luuh I Zeh | Medium: scalp or central skull plane visible enough to estimate; wings, horns and extra spider legs excluded. |
| Treevor, Leaf the Hidden, Waka Aren Si, Urzh, Don Doko Don, Mifu | Lower: canopy/hood/tall hair/stone crest/cap conceals or merges with skull. A new annotated-source review can revise the estimate. |
| Remaining named identities | Medium: forehead and jaw establish an estimate beneath hair/fur or beside horns; not an exact hidden-skull measurement. |

Important appendage-heavy scale candidates are Grace Riva **1.1373**, Ha Rekt
**1.1930**, Faab I Yaina **1.0500**, Ba Djoh **1.1148**, and Luuh I Zeh **1.1600**.
These are preserved historical body-registration candidates. They no longer
authorize scaling the head with the full actor. Keep the body candidate stable
across views, apply the new separately calibrated head group at the neck, and
resolve total neutral-height construction. Do not derive a new scale from a
differently spread wing or moving tail.

These scales are **registration candidates**, not permission to transform and
promote every asset automatically. Proportional head differences remain: the
small human and crested Seakin read with fuller heads than the skull-faced Baron.
Review split-layer overlays and posed renders before adopting a numerical head
target. Current artistic head/crown silhouette must not be mistaken for skull size.
The fullbody-v2 and authored-keys-v1 manifests/recipes remain unchanged historical
receipts; the new shared-skull contract does not retroactively approve those
assets or imply that their baked full-body heads have already been corrected.

Fresh offline checks accepted exact 30 identity/size coverage in the target
contract, all 30 source hashes and scale arithmetic, and contained coordinates
in all 24 pilot views. The expanded `layers.py` check also loaded **30 characters /
240 direction layers** successfully. This is a technical load/partition check,
not visual approval. No engine run or rendered motion acceptance was performed
by this annotation task.

**State:** target contract, all-cast frontal core review and three-pilot joint
registration complete; 27 identities still need full directional joint/mask
annotation, while corrective artwork and motion acceptance remain pending. No
source images, recipes, runtime files or existing gameplay checkpoints were
changed by this audit.

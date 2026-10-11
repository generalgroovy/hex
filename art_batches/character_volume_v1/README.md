# Volume-first body templates (staged)

This is an **offline anatomy adapter**, not a gameplay or production sprite edit.
It reuses the existing fixed-bone animation rig, with compact limbs and a wider,
deeper torso. The reference is `C:/Users/sende/Pictures/styleref1.png`; its old
roster, gear and element labels are not current design authority.

| Profile | Front height | Torso width factor | Torso depth factor | Limb girth |
|---|---:|---:|---:|---:|
| Small | 58 px | 1.00 | 1.02 | 1.06 |
| Middle | 63 px | 1.23 | 1.23 | 1.19 |
| Large | 68 px | 1.46 | 1.44 | 1.33 |

Factors apply to the source anatomy, not the final screen image. All templates
shorten leg chains to 80% and arms to 82%; one standing calibration per size keeps
the height ladder modest. The new head radius is 110% and head offset 94% of the
source. The result is more compact and fuller, not a tall model scaled in 2D.

`adapt_data(original_rig)` returns a clone with all 3,312 source pose records,
new fixed bone lengths, projected meshes, depth ordering and provenance metadata.
`adapt_pose(pose, original_rig)` adapts a single pose. Do not pass adapted data to
either function again. Old source hashes remain provenance, not a claim that the
new anatomy has identical bone lengths. The original rig remains unchanged.

The raster factory can render the new points directly. To apply the additional
limb girth, pass its render function AST through `girth_ast(fn)` before compiling.
`load_renderer()` provides the existing full renderer with that wrapper for
offline comparisons. Head-part size/anchor calibration must use the adapted data.

Foot contact/lift classification and the eight authored yaw directions are
preserved in anatomical 3D space. There is no per-frame bounding-box fit, fake
rotation, screen-horizontal squash, or gameplay hurtbox/stat change. Fixed cell
96x96 and foot pivot48,84 are retained. Profile heights can vary by 1–2 raster
pixels because the camera genuinely sees increased torso depth; the front
calibration is exactly58/63/68, not forced for every yaw.

## Rebuild and verify

```powershell
python art_batches/character_volume_v1/volume.py --out art_batches/character_volume_v1/review-new
python -m unittest discover -s tests/art -p test_character_volume.py -v
```

Use a fresh output directory; existing reviews are never overwritten.
`review-v1/volume-before-after.png` compares all eight standing directions.
`review-v1/metrics.json` records measured alpha bounds and coverage.
These are generic skeleton clothing, not completed character identity artwork.

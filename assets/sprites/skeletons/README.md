# FLUX 2 skeleton animation assets

Runtime source:
- exactly three canonical body types: `small`, `middle`, and `large`;
- one clean atlas and one overlay-debug atlas per body type;
- exact metadata in `content/animations/skeleton_animation_manifest_v1.json`.

The retained `size_*` folder names are compatibility storage paths only. Tiny
maps to `small`, medium maps to `middle`, and huge maps to `large`; they are not
additional runtime body types. New characters must select one of the three
canonical IDs and add ancestry/champion detail as separate visual layers.

Human-review exports:
- `skeleton_animation_pngs_v1.zip` contains one simple transparent PNG per
  animation and size;
- `skeleton_overlay_validation.png` shows pivot/envelope acceptance samples.

See `docs/SPRITE-PIPELINE.md`.

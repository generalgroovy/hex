# Skeleton production notes v1

The runtime paths declared by `content/animations/skeleton_animation_manifest_v1.json`
now resolve to committed assets for all five size classes.

Each size directory contains:

- `skeleton_atlas.png` — 960×1280 clean runtime atlas;
- `skeleton_overlay_debug_atlas.png` — identical atlas layout with envelope,
  centerline, pivot and feet-baseline diagnostics.

Repository-level review files:

- `skeleton_overlay_validation.png` — nearest-neighbor size/direction review;
- `skeleton_animation_pngs_v1.zip` — archived transparent sheets from the five-size prototype; current runtime uses three body types × 25 animations.

Regenerate and validate with:

```bash
python tools/assets/generate_visual_assets_v1.py
python tools/assets/validate_visual_assets_v1.py
```

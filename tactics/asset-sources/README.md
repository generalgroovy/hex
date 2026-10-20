# Accepted artwork inputs

These are the exact accepted inputs needed by the current character-animation and reactive-environment packers. Runtime output remains in `public/pixel/`; running the game does not repack or regenerate art.

[manifest.json](manifest.json) records portable input paths, SHA-256, byte counts, output paths and the one required mirror override. It covers thirty character sheets and one environment sheet, copied without changing the source images. The original per-frame audits in `docs/animation-assets/` retain their historical local paths as provenance; use this manifest to locate the bundled equivalents.

## Repack intentionally

Run from the tactics project root after installing the pinned dependencies. Packing writes runtime atlases and audit records, so use a working branch and inspect the diff.

```sh
node scripts/pack-character-animation.mjs oh_tipi asset-sources/frames/raw-a/oh_tipi.png
node scripts/pack-character-animation.mjs djonah_thaan asset-sources/frames/raw-a/djonah_thaan-corrected.png
node scripts/pack-character-animation.mjs juul_i_yaina asset-sources/frames/raw-b/juul_i_yaina.png 2,4
node scripts/pack-environment-v17.mjs asset-sources/environment/reactive-props-v17.png
```

All other characters use the input and ID in the manifest without a mirror argument. Character packing also reads the matching committed `public/pixel/champions/<id>.png` standing frame for scale. Environment packing also reads the committed `wellspring-surfaces-crafted.webp`. Preserve both.

The packers import Sharp from the locked dependency graph. The shipped images, raw inputs and recorded hashes remain the reference if a future native-library upgrade changes encoding. Per-frame audits, alpha checks and hashes do not replace visual inspection of complete animation cycles.

## Scope and provenance

Prompts and audits are retained in `docs/character-animation-prompts-*.json`, `docs/animation-assets/`, and `docs/environment/`. The current raw inputs preserve accepted generation output; rerunning a prompt is not guaranteed to recreate the same drawing. Exploratory rejects and machine caches are not required by these packers and are not included.

Original character atlases, portraits, other environment assets and their manifests are already committed under `public/`. Their provenance is described in `docs/SOURCE-PROVENANCE.md` and the [art handbook](../docs/handbook/ART-AND-AUDIO.md). This package adds no new redistribution license and does not replace existing notices or provenance.

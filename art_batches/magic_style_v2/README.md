# Eight-element magic style reference v2

Status: reference candidate only — not live, not an animation pack, not an import-ready atlas.

## Selected design

Use `reference-sheet-v2-ground-study.png` as the style-direction reference. It contains eight rows and three role columns: **24 original single-pose studies**. The initial unedited output remains in `reference-sheet-v1-original.png`.

The brief combines the charming, compact visual economy of Oracle-era top-down adventure games with the readable impacts associated with Enter the Gungeon. These are general visual-design cues only: no game sprites, screenshots, characters, logos or interface assets were supplied or copied into the sheet. This statement records the input workflow, not independent legal clearance.

| Element | Shape vocabulary | Projectile / contact / ground distinction |
| --- | --- | --- |
| Fire | Orange-red forked tongues, yellow hot cores | Traveling flame / separated upward tongues / low embers and scorch |
| Water | Blue rounded lobes, curled droplets | Plump wave / scalloped splash / connected blue ripple material |
| Earth | Ochre faceted chunks and fractures | Weighty rock / broken shards / cracked stone and grit |
| Wind | Pale mint open ribbons, negative space | Curling gust / open arc burst / shallow repeating wind strokes |
| Charge | Gold angular zigzags | Broken bolt / snapped branching spark / electric trace material |
| Ice | Pale cyan facets and crystalline teeth | Pointed shard / hard chips / flat angular frost motifs |
| Light | Warm ivory stars and radiant diamonds | Compact star / measured starburst / sparse luminous floor motifs |
| Dark | Violet ink, inward crescents and hollow curls | Crescent core / curling ink burst / pooling ink material |

The palette targets come from the current `content/visual/visual_language_v1.json`; its source hash and eight exact dark/base/bright ramps are recorded in `provenance.json`. Generated color values have **not** been constrained or measured against those ramps pixel by pixel.

## What was actually produced and reviewed

- Built-in image generation only: one initial design pass and one targeted ground-column refinement. No API-key CLI, service installation or game-engine run.
- Both original generated PNG files are preserved byte-for-byte in this folder; no cleanup, palette conversion, background removal, resizing or alpha manipulation was performed.
- Both outputs are **1086 × 1448, 8-bit RGB PNGs with no alpha channel**. They are opaque reference boards, including labels and grid lines.
- Visual review found all eight labels and all 24 element/role cells present, with readable element differences. The refinement replaces isolated ground effects with top-down material arrangements and visually retains the projectile/contact designs.
- The ground studies suggest 2×2 tile arrangements; their four units are not certified copies, and opposing edges are **not seam-validated**.
- The first two columns were visually compared, not proven pixel-identical after the generated edit.
- The sheet provides one pose per role, not eight directional frames, phase sequences, loops, impact timing, pivots, collision-aligned radii or reduced-effects variants.

## Files and provenance

- `prompt.txt`: exact initial prompt submitted to the built-in tool.
- `prompt-ground-refinement.txt`: exact targeted edit prompt; its input was the preserved v1 image.
- `reference-sheet-v1-original.png`: original unedited design output.
- `reference-sheet-v2-ground-study.png`: selected refined reference.
- `provenance.json`: generation paths, hashes, dimensions, palette-source pins and explicit review boundaries.
- `INTEGRATION-CONTRACT.md`: mandatory gates before any runtime use.
- `.gdignore`: excludes this reference folder from game asset import.

The existing pixel-magic pack and every runtime/content file remain untouched. This folder is not referenced by runtime presenters and does not replace any live effects. Human gameplay acceptance and original visual-feel approval remain open.

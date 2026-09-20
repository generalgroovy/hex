# Concept assets

These images communicate direction; they are not runtime textures, authored
collision, material cells, or ship-ready tile sets. This directory is excluded
from Godot import so high-resolution boards do not inflate the editor cache or
release package.

## `flux-champions-visual-style-v1.png`

- Purpose: user-passed mandatory character-style and expression baseline for
  the eighteen champions visible on the board.
- Received: 2026-08-09 as direct project input.
- Dimensions: 1536 x 1024, RGBA PNG.
- SHA-256:
  `cb8aa1b3f4e1c41498a35dd37303a3783b0f8fa2c0bbb0b75a89cbd02934732f`.
- Authority: visual reference only. Canonical roster definitions override its
  labels; the image never defines collision, timing, statistics, palettes, or
  network/simulation state.
- Production requirement: every pictured champion receives an original
  gameplay-scale sprite set covering the manifest-required directions and
  actions. Promotion requires frame/pivot/alignment metadata, a stable ground
  anchor, native and 4x review, accessibility checks, Godot import, runtime
  animation evidence, and deterministic presentation tests.

The reference may guide compact proportions, silhouette, materials, equipment,
expression, and elemental personality. It is not itself cropped, traced, or
treated as an animation sheet.

## `sanctum-hub-visual-direction-v1.png`

- Purpose: expanded Sanctum hub, district, palette, material, and fast-travel
  visual target.
- Generated: 2026-08-01 with OpenAI image generation, using a user-supplied map
  solely as broad style and use-case reference.
- Prompt direction: an original asymmetrical magical-academy archipelago with
  combined functional districts, layered traversal, deep-movement shortcuts,
  and repeated cyan/violet/brass attunement shrines; no labels, logos, copied
  layout, or final collision authority.
- SHA-256: `50cc75b356129141db65bbf0e239db21237fda93d04de5270f4e6389b58d9677`

The source reference is intentionally not copied into the repository. Promotion
to runtime art requires an original modular tile kit, sprite budgets, authored
collision/material layers, accessibility review, and in-engine performance
validation.

## `wellspring-gameplay-specimen-v3.png`

- Purpose: bridge the district-scale concept into a concrete 16:9 play view
  with readable champion scale, tilted facades, clean lanes, material identity,
  translucent bubbles and a compact three-resource/five-slot HUD.
- Generated: 2026-08-13 with the Codex built-in OpenAI image-generation tool;
  the supplied images informed only broad readability, density and perspective
  principles and were not copied into the repository.
- Dimensions: 1672 x 941 PNG.
- SHA-256:
  `4d3017d9151ced969d0ed7f95d45a1d66e609202d4ada83ed461e03a58d4bdad`.
- Authority: specification target only. It is not runtime art, collision,
  camera metrics, a tile atlas, HUD assets or proof of visual acceptance.

The adjacent provenance manifest records the originality boundary and review
criteria. Runtime promotion still requires original modular assets, aligned
authoritative geometry, whole-pixel import, accessibility checks, performance
budgets and in-engine captures.

## `sanctum-modular-kit-generated-source-v2.png`

- Purpose: original twelve-module G2 environment-kit candidate generated for
  bounded asset-pipeline validation; it is not runtime-approved art.
- Generated: 2026-08-08 with the Codex built-in OpenAI image-generation tool,
  without an input/reference image or named-game style target.
- Prompt direction: one consistent 4 x 3 contact sheet containing ground,
  worldbone, path, shore, garden, bridge, rail, doorway, roof, shrine, orrey and
  proving-basin modules on a uniform magenta removal key; no characters, text,
  UI, logos or gameplay authority.
- Source SHA-256:
  `4e3d89758e1f74d1db70844348b29683c18a87cdbe60f16e44f48ec1562aeb8b`.
- Alpha candidate: `sanctum-modular-kit-alpha-candidate-v2.png`, produced with
  the standard local chroma-key removal helper; SHA-256
  `aae1d241392d97c24fc65a8d894993a5a57e1a9276d64fcef89cca54f14aa91d`.
- Validation: 1402 x 1122 RGBA, transparent corners, nonempty foreground and
  background coverage, zero retained opaque magenta-key pixels, twelve unique
  declared grid slots, and fail-closed manifest mutations.
- Review state: candidate, presentation-only, runtime approval false, license
  review pending. The entire concept directory remains excluded from Godot
  import.

The canonical candidate metadata is
[`content/assets/sanctum_modular_kit_candidate_v2.json`](../../content/assets/sanctum_modular_kit_candidate_v2.json).
Promotion requires deterministic cropping, per-module bounds/pivots, a coherent
world-unit and nearest-neighbor policy, collision/elevation/reset alignment,
gameplay-zoom/grayscale/color-vision review, import/performance budgets and an
explicit approval record. Generated pixels never define those gameplay fields.

The first preparation stage is implemented by
`godot --headless --path . --script scripts/prepare_g2_environment_kit.gd`.
It splits the declared 4 x 3 cells, trims alpha with a fixed four-pixel pad, and
writes twelve presentation-only crops beneath the excluded
`assets/concept/sanctum_modular_kit_candidate_v2/` directory. Each output has a
manifest-bound path, SHA-256, dimensions and deterministic bottom-center
presentation pivot. Re-running the tool produced byte-identical hashes. These
crops remain candidates, not approved imports or gameplay geometry.

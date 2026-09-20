# Wellspring environment modules v2 — source provenance

This project-bound source sheet was generated with the built-in OpenAI image
generation tool on 2026-08-31, then corrected with a background-extraction
edit so the PNG contains genuine alpha. It is production **source**, not a
runtime atlas: the deterministic extractor in
`scripts/prepare_wellspring_environment_v2.gd` crops and downsamples bounded
modules into the runtime directory.

- source: `wellspring-environment-modules-source-v2.png`
- source SHA-256: `526f42093c3392789adbbc91abb4420c594a1365d2d25a4e4ee319d94359e7e0`
- dimensions: 1536×1024 RGBA
- grid: 4 columns × 4 rows
- input reference: `wellspring-gameplay-specimen-v3.png`, used only for broad
  mood, materials, perspective and readability
- third-party pixel inputs: none
- runtime authority: presentation only
- distribution status: pending the project-wide license/release review

## Final extraction-edit prompt

> Remove only the gray-and-white checkerboard background and replace it with
> genuine transparent alpha. Preserve the exact sixteen environment modules,
> their positions, equal 4-by-4 grid spacing, colors, proportions, pixel edges,
> lighting, and internal details. Change only the background; retain every
> module fully opaque including white flowers, cyan portal interior edge, and
> tiny highlights; no added shadow or halo outside modules; no text, labels,
> grid, border, watermark, or new objects; output must be a PNG with genuine
> transparency.

The initial generation prompt and the exact runtime crop contract are recorded
in `content/assets/wellspring_environment_source_v2.json`.

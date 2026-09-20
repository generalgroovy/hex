# Oh Tipi style pilot — source drafts, not accepted runtime art

Status on 2026-09-08: **runtime import rejected; live promotion false**.
Six selected original pages describe 80 planned cells across eight headings
and ten physical pose states. There is **no accepted 80-cell runtime PNG**.
This is one identity pilot, not 27 completed character animation sets.

## Why this candidate is blocked

- All six selected sources have fully opaque alpha. The requested magenta
  technical background is nonuniform near-magenta, not exact #FF00FF.
- Outside-edge samples span R228–251, G3–39, B228–251, with 50–68 sampled colors
  per page. Cardinal core's corner is #EB0AED, for example.
- The importer rejects these pages before crop extraction. No tolerance-based
  chroma key, repainting, matte repair, or source alteration was performed.
- Several phase-B walk/sprint poses still appear to repeat the phase-A leading
  anatomical leg. Front cardinal B contacts changed more clearly; the entire
  eight-direction gait is not certified.
- Cross-page anatomy, exact diagonals/cast direction and fixed-pivot registration
  remain unapproved. A filled grid is not proof of a coherent animation cycle.

## Selected immutable sources

| Page | Dimensions | States | Headings |
| --- | --- | --- | --- |
| cardinal-core-matte-v2.png | 1254×1254 | grounded, jump, cast, hit | S, E, N, W |
| cardinal-motion-v1.png | 1254×1254 | walk, sprint, slide, roll | S, E, N, W |
| cardinal-phase-b-v1.png | 1774×887 | walk_b, sprint_b | S, E, N, W |
| diagonal-core-matte-v2.png | 1254×1254 | grounded, jump, cast, hit | SE, NE, NW, SW |
| diagonal-motion-matte-v1.png | 1254×1254 | walk, sprint, slide, roll | SE, NE, NW, SW |
| diagonal-phase-b-matte-v2.png | 1774×887 | walk_b, sprint_b | SE, NE, NW, SW |

`source-layout-v1.json` records SHA-256 hashes and every planned source-cell
rectangle explicitly. Row boundaries are manually proposed from visible gutters,
not inferred from an assumed uniform grid; they remain provisional because strict
alpha validation fails before extraction. Rejected prior iterations are retained
and excluded from that specification. Generation intent and observed failures are
in `CORE-PROMPT.md` and `DIAGONAL-PROMPTS.md`.

## Import contract and reproducible checks

`scripts/build_character_style_pack.gd` adapts the existing isolated
`reference/art/neutral_body_templates_v1/build_pack.gd` resource assembler.
It checks source hashes, explicit rectangles, complete empty gutters and semantic
slots. It accepts actual transparent alpha or exact uniform supported matte,
never a checkerboard or approximate chroma-key rule.

For valid sources only, source cell widths normalize to the cardinal-core width,
then one common body scale derives from south grounded height. Nearest sampling,
96×96 cells, pivot(48,84), eight direction columns and ten state rows yield
768×960. Oversized poses fail; no pose gets a different fitting scale. Shared
assembly also checks the existing Small/Middle/Large sizes58/68/76. This pilot
would write only the Middle atlas. Existing output directories are not overwritten.
No live asset registry, gameplay, collision, export or roster is touched.

From the repository, using the pinned Godot executable:

```text
godot --headless --path . --script res://scripts/test_character_style_pack.gd
godot --headless --path . --script res://scripts/build_character_style_pack.gd -- --inspect
```

The second command **must currently exit1**, naming the invalid opaque matte.
No candidate directory is produced. Synthetic tests cover exact matte, real
alpha, empty/clipped/overlapping cells, semantic duplicates, immutable sources,
page normalization, fixed sizes/pivots, overflow rejection and all six real-source
rejections.

## Raw-source review image

The hidden Godot diagnostic `scripts/capture_character_style_sources.gd` renders
all80 planned regions from the unchanged source PNGs with nearest sampling.
It retains the magenta surround visibly, uses one display scale after page-width
normalization and labels all states/headings. It does not generate or repair art.

```text
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://scripts/capture_character_style_sources.gd
```

Output: `.godot/artwork-20260908/oh-tipi-source-proof-v1.png` (1030×1140).
The diagnostic refuses to overwrite this proof. It is a source-review sheet,
**not native runtime, transparent-atlas, foot-registration or flipbook acceptance**.

Next art work requires a genuinely usable background/alpha source and corrected
opposite contacts, followed by exact facing/anatomy/registration review. This
checkpoint does not approve the drafts for runtime; future bounded artwork
iterations should address those defects before expanding the cast's source art.

# FLUX material animation studies v2

**Isolated art-review batch, not a live game replacement.** The integrated v1 magic pack remains untouched. These are generated material masters, not a complete replacement for its 474 component/phase/variant sequences.

**User stop boundary: eight basic elements only.** Stop before first-level interactions. No Steam formation/active/decay or other interaction artwork has been generated in this batch. The later stages below are a future queue, not active work or completed deliverables.

## Ordered production

| Stage | Deliverable | Acceptance before the next stage |
|---|---|---|
| 1 | Eight basic-element active loops, eight poses each | Stable anchor/scale; distinct material behavior; legible at32px and64px |
| 2 | Fire + Water = Steam: separate formation, active and decay | Buoyant vapor; no rock-shaped cloud; actual29/252/60-tick phase limits respected |
| 3 | Other27 unlike-element reactions | One independent reaction at a time; exact occupied geometry and mechanics preserved |
| 4 | Eight same-element reactions | Distinct intensification, never silently counted as completed by basic-element loops |
| 5 | Component adaptation and runtime integration | Hand/core/tail/impact/beam/spray/field variants, reduced effects, gameplay captures and loader integrity |

## Material language

| Element | Physical cue | Charm and readability | Avoid |
|---|---|---|---|
| Fire | Unequal rising tongues, pinching ember tips | Warm bright pockets and rounded curls | A breathing flame logo or opaque explosion |
| Water | Connected liquid, curling crest, returning droplets | Broad clear highlights and a soft rolling rhythm | Separate blobs or a static wave symbol |
| Earth | Weight, rigid faces, descending grit | Rounded silhouette around angular mineral faces | Elastic rocks or perpetual glitter |
| Wind | Open ribbons and eddies | Thin sweeping curves, abundant empty space | Solid green ball or dense steam |
| Ice | Fixed facets, traveling glint, rime | Quiet crisp edges | Liquid wobble or spinning snowflake icon |
| Charge | Leader, snap, branch, recovery gap | Short angular surprises, restrained bright contacts | Continuous glare or full-area strobing |
| Light | Stable radiance, measured glint | Calm pale-gold presence | Electrical jitter or bloom hiding projectiles |
| Dark | Inward wisps around empty space | Controlled plum curls and negative space | Purple fire or opaque smoke |

“Realistic” means convincing material motion within the established pixel-art style, not photorealistic rendering. Generated colors and silhouettes are art proposals, not an automatic change to the canonical palette or collision.

## Files and workflow

- `sources/`: immutable generated4x2 source sheets; one material/purpose per file.
- `prompts/`: exact built-in image-generation prompts and edit prompts.
- `packed/`: engine-assembled32px-cell studies and measured metadata, when validated.
- `preview/`: offline frame/loop viewer; source and packed modes, scale/background/grayscale checks.
- `build_studies.gd`: isolated validation and packing. No per-frame bounding-box fitting or art-generated collision.

The stage is deliberately excluded from the live Godot project. No runtime manifest, player installer, release asset or character art is replaced by creating these files.

## Compatibility rules

| Contract | Rule |
|---|---|
| Material cell |32x32; ground-relative pivot(16,26); fixed whole-sheet scale/anchor |
| Source grids | Four columns, two rows; proportional cell boundaries allow generated odd dimensions |
| Alpha | Actual alpha or explicitly validated magenta-family matte; a painted checkerboard is rejected |
| Sampling | Nearest; no lossy compression or frame blending; original source preserved |
| Time | Absolute phase age at120Hz; loops never extend authoritative lifetimes |
| Geometry | These are material stamps, NOT whole hazard shapes; clip to actual masks, worldbone, ring holes and live links |
| Scope | Material study only; new gameplay effects, damage, concealment and optical rays are not inferred from art |
| Performance | No new particles/nodes per visual grain; existing decoration budgets remain unchanged |

This batch contains only the eight basic loops. The entire reaction queue is paused before its first asset. Numeric packing tests do not establish seamless animation, exact palette compliance, human visual acceptance or120FPS performance.

## Steam acceptance

Formation must communicate conversion within29 ticks; active may loop only inside its252 ticks; decay lasts60 ticks. Visual expansion is NOT a replacement for the real30-to90px radius progression over108 active ticks. Concealment can end before the last vapor disappears, so essential state cues remain separate from decorative vapor.

Its material ramp is neutral gray-green: #7C999A / #BECFC7 / #DFEBDF. Steam should rise, roll and thin, not become an orange fire cloud or a static triangular mound.

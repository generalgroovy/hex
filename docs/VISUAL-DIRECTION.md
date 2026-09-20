# FLUX current visual direction

Status: current art contract, 2026-09-08; replaces accumulated historical overrides.

The original [Oh Tipi](../reference/art/oh_tipi_authority_v1/oh-tipi-authoritative-reference.png)
supports current neutral-template pixel grammar: sensible proportions, layered
clothes, intentional clusters and charming anatomy. After all three basic templates
pass animation/direction coverage and user acceptance, the new
[cast style target](../reference/art/cast_style_post_templates_v1/README.md) becomes
the primary look for character rework. [CURRENT-CAST](CURRENT-CAST.md) still owns
identity, size allocation and affinities; neither sheet overrides those facts.

Current production gate: finish and visually accept generic Small/Middle/Large
templates before named-character repairs/additions. Construction diagrams and
partial technical proofs are not accepted sprite templates. See SPRITE-PIPELINE.md.
The new sheet's expressive faces, compact silhouettes, dark outlines, practical
clothing and restrained material highlights must survive native pixel scale.
Its spells, auras, weapons, ground shadows, borders and parchment are excluded
from bodies, and its quarter-view poses do not replace eight-way facing.

| Layer | Required treatment |
| --- | --- |
| Bodies | Small 58/Middle 68/Large 76 px; 96 px cells, pivot 48, 84; no per-action resizing |
| Identity | Unique ancestry/costume silhouette; practical nonsexualized clothes; S. Wayne dark-skinned, Biggy Bob brown-haired |
| Motion | S/SE/E/NE/N/NW/W/SW; symmetric front, centered back, true opposite contacts |
| Portraits | Exact occupied top third of South-grounded sprite, proportional nearest fit, transparent32px cache |
| Casting | Bare hands; independent magic/shadows/auras |
| World | Warm stone, dark timber, brass, deep water, plants; detail at edges |
| Perspective | 55-degree illustration over screen-cardinal floors; 50/75/100% zoom; opaque worldbone |
| Threats | Discrete owned projectiles and real extent; no lane-hiding bloom |
| Matter | Tileable native-pixel material itself shows the footprint; no separate range circles/outline markers |
| UI | Health/Flux/Stamina, 4 active spell cells/modifier; compact movement table and chemistry matrix, full rules under Details |
| Accessibility | Grayscale/color-vision review, reduced decoration retaining essentials |

Each visual read needs more than color: silhouette/topology identifies the
element, occupied material shows extent, and phase/motion shows when it matters.
Guide diagrams are labeled explanations, not extra world effects. Reaction
Details follows the selected pair and uses a source-proportional phase strip.
The runtime visual-language metadata now enforces the same three sizes, eight
headings, ten rows and opaque-worldbone policy as this document. Four extra palette
families remain reserved compatibility styles, not active spells/elements.

| Element | Visual language, not added gameplay |
| --- | --- |
| Fire | Orange/red pointed tongues, bright core, rising sparks |
| Water | Deep blue/cyan flat ripples, rounded splashes |
| Earth | Ochre angular slabs, cracks, compact rubble |
| Wind | Pale teal directional open ribbons |
| Charge | Yellow branching zigzags, separated sparks |
| Ice | Icy cyan/blue facets and cold motes |
| Light | Ivory/gold rays, geometric highlights |
| Dark | Violet/ink voids, broken inward wisps |
| Steam | Pale warm-gray rising billows; unlike blue water, pointed fire or directional wind |

Steam retains its actual concealing windows; stronger art adds no damage.
Flame tongues, spreading billows and stone clusters tile inside authoritative
shapes, including obstacle cuts; formation/expiry remain truthful. Reduced or
zero optional decoration keeps the essential material coverage. A stone-looking
deposit is not automatically a wall: only actual reaction cover blocks shots.
Reuse usable pixel packs first. Source/manifests/hashes/import rules accompany
promotion. References/rejected drafts stay out of runtime export.

Follow [SPRITE-PIPELINE](SPRITE-PIPELINE.md). Every changed material needs actual
normal/reduced, zoom and formation/active/quiet/decay/expiry captures, visibility/
budget tests. Automated coverage is separate from human charm and performance.

Every accepted pixel-page replacement also updates the reviewed raw-export
allowlist in `addons/pixel_assets_export/atlas_source_contract.gd` in the same
slice. Run `pixel-assets-export` alongside the presenter/library suites and
verify an actual exported PCK. Do not automatically trust a newly authored hash
or weaken mutation/missing-file rejection. Source rendering alone is not export
readiness.

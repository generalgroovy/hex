# Oh Tipi style character production

Status: Steezo, Oh Tipi, S. Wayne, Waka Aren Si and Jan Wicked complete pages active in source; remaining production and human visual acceptance in progress.

The user's 2026-09-08 request restores the original supplied Oh Tipi artwork as
the character style authority. The v4 group reference remains useful for names,
ancestries, colors and body allocations, not an override of this newer request.

Authority image: `reference/art/oh_tipi_authority_v1/oh-tipi-authoritative-reference.png`.
SHA256: `d50ed37439cc788dd36d1a8216d3621c034d1d7cc68d91200fdd4bafd25ee106`.

Keep crisp pixel clusters, natural proportions, layered clothing and legible
material highlights. Body sprites have empty hands: reference equipment, magic,
auras, shadows and environmental pieces must remain separate. S. Wayne remains
dark-skinned; practical nonsexualized clothing, three fixed body sizes and all
eight animation directions are preserved.

## Production gate

Each accepted character needs 80 cells: eight directions by grounded, jump, cast,
hit, walk A, sprint A, slide, roll, walk B and sprint B. Existing action aliases,
timing and simulated protection are retained. A portrait or idle pose is not a
complete animation pack. Use small source grids, one global scale per body,
transparent gutters and the shared (48,84) pivot in 96px cells. Do not normalize
the size independently for each action. Reject opaque checkerboard backgrounds.

The 27 named characters require 2,160 accepted cells. Unnamed Angel remains a
reserved identity unless the user approves a real character. All27 named profiles
are now testable. The [current cast contract](../../docs/CURRENT-CAST.md) and
source-derived `character_art` report own effective individual/template counts;
the22 catalog fallback declarations remain intentional rollback provenance.
Template substitutes are not finished unique artwork. Rejected near-magenta/
motion drafts are retained as evidence, not loaded by the game.

| Identity | Latest production state |
|---|---|
| Steezo / Small | `candidate-v4-registration`: complete80, active source; side sprint contact polish remains |
| Oh Tipi / Middle | `full-candidate-v5-registration`: complete80, active source; diagonal acting/contacts merit playtest |
| S. Wayne / Small | `candidate-v2`: complete80, active source; restrained diagonal arms/yaw microvariation merit playtest |
| Waka Aren Si / Small | `nico_lai/candidate-v2`: complete80, active source; brisk gait-B and correction-detail variation merit playtest |
| Biggy Bob / Middle | `candidate-v2-north-repair`: complete80 format-valid, not promoted; repeated profile/diagonal contacts and south slide facing need repair; fourth source rejected |
| Fluup / Large | `candidate-v1`: complete80 format-valid, held for11 repeated-foot pairs, enclosed matte islands and yaw; old same-size template remains live |
| Jan Wicked / Middle | `jan_wicked/candidate-v2`: complete80, active source; NE/NW actions too profile-like, brisk stride/coat-shading differences and single-pose roll remain open |
| Red Baron / Large | `candidate-v5-registration`: complete80, fixed registration; six walk-B contacts block promotion |
| Treevor the Mason / Large | Complete candidate held: rear-diagonal walk-B headings swapped, west walk-B faces right and other gait/yaw defects; old same-size template remains live |

For active pages, `assets/sprites/champions_v3/style_v1/` contains exact copied
runtime PNGs with lossless/native-alpha import settings. The override registry
pins PNG and decoded-RGBA hashes. Technical build manifests remain candidates;
the separately reviewed registry is the live-promotion decision.

Built-in image generation is used for new raster artwork; immutable generated
sources and prompts stay here. Existing tested Godot assembly performs technical
packing only. No live atlas is replaced until the complete new page passes art,
registration, animation, headless and real-render acceptance.

Current verification boundary: final five-page Full passed 87 suites / 419,651
assertions with zero failures/stderr; strict import/120 Hz boot and isolated Windows
release EXE/PCK boot passed. Clone-guard focused 33,088 and source audit 109/34
passed. Full-cast human art acceptance and a refreshed installer remain separate.
See the [character-page checkpoint](../../docs/CHARACTER-PAGES-CHECKPOINT.md) for
unchanged historical receipts and current limits.

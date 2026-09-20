# Treevor the Mason — isolated complete-page candidate

Status: **80-cell format-valid review candidate; blocked on directional/gait acceptance; not promoted**. Four of four authorized built-in image-generation calls are used. This lane is frozen; working live art remains unchanged.

The current candidate is `candidate-v2-contact-repair/treevor_mason.png`. The word *complete* describes its 80 supplied cell slots, not correctness of every heading/contact or acceptance as production animation.

## Canonical identity

Verified against the current foundation catalog and `docs/CURRENT-CAST.md`:

- Stable ID `treevor_mason`, wire ID **7**, display name **Treevor the Mason**.
- **Large Treefolk**, Earth 1 / Wind 1 / Fire 1.
- Warm dark bark body, friendly knot-like face, green foliage crown/shoulders, two mobile branch legs with separated rooted feet, wooden fingers.
- Dark brown mason's work apron, leather straps, ochre ties, worn stone wrist/ankle cuffs; empty hands. No staff, hammer, weapon, magic, environment, ground shadow or detached plants.
- Existing catalog template source remains `red_baron`; no catalog, stats, affinities, template or live registration was changed.

The official individual identity reference is `reference/art/front_cast_v2/05-treevor-mason.png`, SHA-256 `c5d51878b841a629aea58224ae238a7766729af33b7bae028f6f9a7bc8626665`. Its description was checked in that folder's generated manifest and the current cast reference. The original `reference/art/oh_tipi_authority_v1/oh-tipi-authoritative-reference.png` supplies pixel style and natural proportions, SHA-256 `d50ed37439cc788dd36d1a8216d3621c034d1d7cc68d91200fdd4bafd25ee106`. Neither reference was modified.

## Four source boards and decisions

| Call | Preserved PNG / prompt | Source poses | Final use |
| --- | --- | ---: | --- |
| 1 | `core-poses-v1.png` / `CORE-POSES-PROMPT.md` | 48: grounded, jump, cast, hit, slide, roll × eight headings | 42 retained; six front-like north poses replaced |
| 2 | `walk-pairs-v1.png` / `WALK-PAIRS-PROMPT.md` | 16: eight adjacent walk A/B pairs | 14 retained for review; south/north B replaced; known side-direction/contact defects remain |
| 3 | `sprint-back-v1.png` / `SPRINT-BACK-PROMPT.md` | 16 sprint poses plus six corrected north core actions | 21 retained; south sprint-B replaced |
| 4 | `contact-repair-v1.png` / `CONTACT-REPAIR-PROMPT.md` | South walk-B, north walk-B, south sprint-B | All three retained as targeted contact corrections |

The corrected north core actions show crossed rear apron straps and no frontal face/bib. North grounded, tucked jump, reaching cast, recoiling hit, low seated slide and curled roll now have distinct articulated silhouettes. The final small board exchanges the requested support foot rather than just changing arms/head position.

All generated originals, earlier partial reviews (`core-review-v1`, `core-walk-review-v1`), first complete candidate (`candidate-v1`), extraction masks and exact crop specifications remain intact. Reference-extraction scripts only copy source cells and use integer nearest-neighbor enlargement; they do not synthesize poses.

## Assembly and registration

Output is **768 × 960 RGBA8**, 8 columns × 10 rows, **96 × 96** cells, native Large **76 px** standing guide, pivot **(48,84)**. All 80 cells have the actual last occupied pixel at **y83**.

Columns are south, south-east, east, north-east, north, north-west, west, south-west. Rows are grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b. These are 80 source cells, **not 80 unique animated sequences**. The page does not change runtime action aliases, motion timings, root motion or physical height.

`source-layout-v2.json` maps explicit crops into those slots. The builder applies one Large-body scale, **0.406417112299465**, derived from the first grounded-south source. Source-page width normalization is fixed for each entire board:

| Board | Nominal cell width | Reviewed calibration width | Scope |
| --- | ---: | ---: | --- |
| Core | 181 | 181 | All original core poses |
| Walk pairs | 305.5 | 258 | Every walk pose, no individual A/B fitting |
| Sprint/back | 256 | 236 | All sprint and north-core poses together |
| Three-contact repair | 724 | 560 | All three repaired poses together |

Calibrations match crown-to-foot and trunk/cuff scale; no pose receives an independent body fit. Post-resize transparent padding is trimmed before fixed bottom-center translation. No limb repainting, stretching or action-dependent resizing is performed by the assembler.

## Alpha extraction and provenance

The generator returned **opaque neutral checker backgrounds**, not genuine source alpha, despite the transparent-background requests. All four sources passed the existing strict, explicitly reviewed edge-connected neutral rule: minimum channel **170**, maximum channel spread **18**. Measured source perimeter minima were respectively **193, 202, 197, 196**. The shared guard was not weakened. This is authorized assembly cleanup, not an automatic guarantee of perfect anatomy or costume edges; light/dark review remains necessary, particularly on stone cuffs and foliage gaps.

| Source | Raw SHA-256 | Removed pixels in final selected crops | Removal-mask SHA-256 |
| --- | --- | ---: | --- |
| Core | `1b7d8e5304e12de634049059465598a13591991abd16d468605c3186735321c2` | 445231 | `e6f678ed613d90a86860e497d6d7ab14037feeca7836a2397b967d618d280bb8` |
| Walk | `cd4accbeda0041fb3b5624d8dcc38cad356d37f9f65d7ee107b240fc78cf99d6` | 338170 | `0ae0cbc16ad2596062df10eddccd02135a50d3fb1bf38fdf55718a9eba00a7e3` |
| Sprint/back | `3f2fec3573809602fe755cc25b13eedf47d9b503d68ea2def817710ce3b268a9` | 405056 | `dc4d52a470c40a1007c388c03c8d5d1b535f3b9f01eae560e3dddcd96331fe54` |
| Contact repair | `46a8b7c26ec2c43a9a0bafd292c87a3ca83bbc1fe4598fdfcb19f04ecfce0de6` | 363853 | `73a3631845a1f15b9e64c124248cf567cbb6963c4c2c0a9126ee4c8007f5e2c5` |

Final source masks are saved beside the candidate PNG and manifest. Original source crops, output regions and measured occupied bounds are recorded per cell in the manifest.

## Verification and remaining blockers

Actual local checks on 2026-09-08:

- Shared strict importer regression suite: **1,022 assertions, 0 failures**.
- Real `CartoonChampionPresenter._validate_override_pixels` admission: **PASS**, Large 76 / feet 83 / binary alpha / 80 cells. No live registry was loaded with this candidate.
- Independent exact-region check: only **cell 64 (south walk-B), 68 (north walk-B), and 72 (south sprint-B)** differ from `candidate-v1`; the other **77 decoded cell regions are byte-identical**.
- All 80 cells are nonempty and registered at y83, with intact gutters, no clipping, no partial alpha, **581,373 transparent pixels**, no format errors or warnings.
- **32 actual Godot PNG captures** plus `review-v2/report.json`, covering all cells on light/dark backgrounds at native 1×/2× and A/B comparison pages. Viewer cadence is only a review aid, not a gameplay timing change.
- Logs in `.godot/treevor-art-20260908/` have empty stderr. The importer, admission and capture runs rejected engine warnings/errors.

The corrected front/back dimensions remain coherent: south walk A/B both **56 × 77 px**; north walk A **58 × 76**, B **59 × 76**; south sprint A **55 × 68**, B **54 × 68**. The repaired support feet visibly alternate; north sprint A/B also changes support. These observations are a candidate review, not human acceptance.

**Known blockers still prevent promotion:**

- `walk_b/north_east` faces back-left instead of back-right, while `walk_b/north_west` turns back-right instead of back-left.
- `walk_b/west` turns into a right-facing profile; `walk/north_east` reads too much like a front/right profile rather than a rear three-quarter view.
- Several side and diagonal walk/sprint pairs retain the same apparent leading/support branch or substitute a torso turn/stride-length change. Correct anatomy and leg occlusion cannot be inferred from differing frame hashes.
- Cross-board palette, head/crown and volume continuity still need human acceptance at game zoom. All-direction movement correctness has **not** been established.

No further generation is authorized within this four-call lane. Preserve the working runtime art rather than promoting this partially successful candidate.

## Artifacts and reproduction

| Final artifact | SHA-256 |
| --- | --- |
| `candidate-v2-contact-repair/treevor_mason.png` | `2f7326615410946e65c18ca91785ae0846bb80bc04181c28582d1090ff3527ed` |
| `candidate-v2-contact-repair/manifest.json` | `e544561af23c334c53fe03a4e663737a06ba99b7901cc57d157c557080a23c69` |

Decoded full-page size is **2,949,120 bytes (2.8125 MiB)**; this is not a live residency or performance claim.

From the repository root:

```powershell
.\scripts\review-character-sheet.ps1 -Sheet .\art_batches\character_style_v1\treevor\candidate-v2-contact-repair\treevor_mason.png -Mode Check
```

Use `-Mode View` for read-only manual inspection or `-Mode Export` for new unique captures. Reassembly uses `scripts/build_character_style_pack.gd`, `--spec=res://art_batches/character_style_v1/treevor/source-layout-v2.json`, and a **new nonexistent** output directory. The builder refuses to overwrite previous evidence. The owned `validate_candidate.gd` checks real presenter pixel admission and the exact three-cell replacement boundary.

No shared source, current-state script, live registration, gameplay, hitboxes, network, catalog, export package, commit or push was changed by this art lane.

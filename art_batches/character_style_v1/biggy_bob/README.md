# Biggy Bob — complete 80-cell review candidate

Status: **complete format-valid candidate; staged and blocked on gait acceptance; not promoted into the live game**. The final fourth correction failed; the candidate remains unchanged. This folder is isolated artwork and provenance, not a gameplay or roster change.

## Identity and visual authority

The current foundation catalog identifies `biggy_bob` as wire ID **18**, a **Middle Dwarf**, with Earth 1 / Fire 1 / Light 1. His established identity is brown hair, a full brown beard, heavy eyebrows, a broad nose, an ochre scarf, a dark leather work coat, sturdy boots, and empty hands. This candidate adds no weapon, magical body effect, floor shadow, or element-dependent costume.

Identity was checked against `content/champions/foundation_champions_v1.json`, `docs/CURRENT-CAST.md`, `reference/art/cast_sheet_v4/cast-reference.json`, and `reference/art/front_cast_v2/PROMPTS.md`. There is no separate existing Biggy Bob portrait in the front-cast image set. `identity-reference.png` is an exact, unscaled crop `[729,393,123,139]` from the current size-banded cast sheet. Original Oh Tipi is the rendering/style authority; the group reference supplies Biggy's identity rather than its chibi proportions.

| Reference | SHA-256 |
| --- | --- |
| Original Oh Tipi authoritative reference | `d50ed37439cc788dd36d1a8216d3621c034d1d7cc68d91200fdd4bafd25ee106` |
| Current size-banded cast reference | `d65c50c558b2f8f6189008cfd3175bb8d21a000bbb0090400a08bdfbfa7e2d63` |
| Exact Biggy identity crop | `2161cb4301fedb3a39e4065c4f513d29f6daa0c0d4156e503ad1590cfe2b3644` |

## Candidate and source decisions

The current review page is **`candidate-v2-north-repair/biggy_bob.png`**. Its manifest records every source crop, fixed source-page calibration, output region, occupied bounds, and extraction mask. The immutable generation results and their prompts are retained:

1. `full-page-v1.png` / `FULL-PAGE-PROMPT.md`: complete 80-cell source. It has an opaque neutral checker background, not native alpha. The original supplies 78 final cells.
2. `full-page-v2-rejected.png` / `MOTION-REPAIR-PROMPT.md`: rejected full-sheet correction. It misplaced a seated action and changed the rendering more broadly. **No pixels from this result enter the final candidate.**
3. `north-actions-v1.png` / `NORTH-REPAIR-PROMPT.md`: isolated north-facing slide and sprint-B repair, guided by the exact `north-reference-4x.png` crop. These two cells supply the remaining final poses.

Those three calls produced the current candidate. A final fourth call, documented below, was subsequently rejected and is not assembled. No generated result was overwritten. Per-cell decoded-RGBA comparison against `candidate-v1` confirms **only slide/north (cell 52) and sprint_b/north (cell 76) changed; all other 78 cells are byte-identical**.

The original sheet puts walk A/B and sprint A/B in adjacent rows. `source-layout-v2.json` explicitly maps those source cells into the runtime-compatible row order below; source row positions are not assumed to be output row positions.

## Assembly contract

- Output: **768 × 960 RGBA8**, 8 columns × 10 rows, **96 × 96** cells.
- Columns: south, south-east, east, north-east, north, north-west, west, south-west.
- Rows: grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b.
- Native Middle standing guide: **68 px**; measured grounded headings are 66–69 px high.
- Stable pivot: **(48,84)**; all 80 cells' last occupied pixels end at **y83**.
- Nearest-neighbor assembly only. One fixed body scale, `0.515151515151515`, applies to the first page. The two-pose north board has one common source-cell-width calibration of **660** instead of its nominal 887, recorded explicitly. Neither north pose is fitted or resized independently.
- The builder trims post-resize transparent padding and translates occupied pixels to the shared pivot. It does not stretch body parts, add root motion, or create vertical gameplay motion.
- Walk/sprint A and B are two source poses; the other rows are single source poses per heading. This is **80 source cells, not 80 unique animated sequences**. Existing runtime semantic aliases and timings are unchanged.

The reviewed extraction uses edge-connected neutral-checker removal (`minimum_channel=170`, `maximum_spread=18`), under the user's explicit background-removal authorization. Exact source PNGs and removal masks are retained. This is not a claim of native generated transparency or perfect automatic masking: light neutral costume boundaries must still be reviewed on light and dark backgrounds.

| Used source | Source SHA-256 | Removed pixels | Removal-mask SHA-256 |
| --- | --- | ---: | --- |
| `full-page-v1.png` | `33ca9659dabd8c392ea9bc2dbda8ce569414c2a1c97b76be858ea4421391d201` | 452849 | `142c913b6b38d6517c62b608cec67adf57afa8202327836fad6279569aa0711d` |
| `north-actions-v1.png` | `cad807444e27278e0a46848651173d1cae8c6e17c861cb2ab9d8a32ad8a8092c` | 338046 | `1d546ca06d03102ac54a58a096a6de7d639b520e6e4bab6ff1b0e8ffdf78f0d2` |

The rejected full-sheet correction is retained with SHA-256 `c1889c90d29cca06984a32651bf0a0cfffa1d7a43611748bde4253dd3cd8b0ac`.

## Verification and review limits

Actual local verification on 2026-09-08:

- Shared strict importer regression suite: **1,022 assertions, 0 failures**.
- Final page: 80/80 nonempty cells, gutters intact, no clipped cells, all feet y83, no partial-alpha pixels, **572,334 transparent pixels**, and no format warnings/errors.
- Real `CartoonChampionPresenter._validate_override_pixels` accepts this page for Middle height 68 and feet y83. This checks pixel admission only; no art registry or runtime promotion was performed.
- All eight walk A/B pairs and all eight sprint A/B pairs differ in decoded pixels. **Difference is not proof of correct alternating anatomical contacts.**
- **32 actual Godot review captures** plus `report.json` are preserved in `review-v2/`, covering contact sheets and movement comparison views at 1×/2× on light/dark backgrounds. Preview speed is a review aid, not new gameplay timing.
- Every isolated log in `.godot/biggy-bob-art-20260908/` has empty stderr. The importer, pixel-admission, and export runs used strict warning rejection.

Visual inspection confirms the repaired north slide is genuinely low/seated rather than another standing pose, and north sprint-B changes the planted screen-side boot while retaining a 63 px overall height (A width 59 px, B width 57 px). Parent review confirmed useful south/north walk contacts, but east/west and diagonal walk B still use the same lead/support foot as A. The other seven sprint pairs also lack defensible opposite-contact acceptance. The existing south slide faces south-east instead of straight south. These are **known art blockers**, not defects fixed by format checks. This folder does not claim all-cast animation completion or human acceptance.

## Final fourth-call correction — rejected, unassembled

`FINAL-CONTACT-REPAIR-PROMPT.md` requested one 6-column × 3-row board: six side/diagonal walk-B corrections, seven sprint-B corrections, and a straight-south slide. `final-repair-reference-3x.png` contains 14 exact current-candidate source crops at nearest 3×, generated by a hash-locked extraction script; four unused cells are blank. The prompt explicitly required swapping the anatomical lead/support leg, not merely changing arms, head height, or stride length.

The result, `final-contact-repair-v1.png` (**1774 × 887**, SHA-256 `7c988d8d78683fb875783892990b1949a6182e3465794289360b355222c629ff`), again largely repeats the source A leg patterns. Its south-facing slide is visibly front-facing, but that isolated improvement is not assembled or accepted. The page also generated an opaque, nonuniform neutral checker: its perimeter minimum channel is 144, below the shared importer's minimum allowed value of 160; diagnostic probes at 130/140 still reveal isolated background artifacts. These read-only measurements are **not approved extraction rules**.

At the parent's explicit stop boundary, the shared guard was not weakened, no custom lower-threshold extraction was run, and no derivative alpha sheet, removal mask, replacement layout, or new candidate was manufactured from this result. Exact source bytes and prompt are retained for honest failed-attempt evidence. All **four of four** generation calls are now used. The current candidate PNG and manifest hashes below are unchanged; this art lane is frozen with the gait blockers above.

| Final artifact | SHA-256 |
| --- | --- |
| `candidate-v2-north-repair/biggy_bob.png` | `bba1f89ded22f654d95d4622640ee92e7ec65063af3de2776f97e3fe27d6eece` |
| `candidate-v2-north-repair/manifest.json` | `bb1f4450b490cc3960f40532917b6380c2e7dff61fde7b4c91a8d118f1e04e20` |

The decoded full page occupies **2,949,120 bytes (2.8125 MiB)**. This is not a live texture allocation or a performance measurement.

## Reproduce the checks

From the repository root:

```powershell
.\scripts\review-character-sheet.ps1 -Sheet .\art_batches\character_style_v1\biggy_bob\candidate-v2-north-repair\biggy_bob.png -Mode Check
```

Use `-Mode View` for the read-only interactive reviewer, or `-Mode Export` for new uniquely logged captures. Reassembly uses `scripts/build_character_style_pack.gd` with `--spec=res://art_batches/character_style_v1/biggy_bob/source-layout-v2.json` and a **new, nonexistent** output directory; the builder refuses to overwrite prior candidate evidence. `validate_candidate.gd` is the isolated real-presenter pixel-admission check.

No live catalog, override registry, simulation, network, movement, hitbox, installed package, or shared runtime source was changed by this art slice.

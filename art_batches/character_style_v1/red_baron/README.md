# Red Baron / complete new-style candidate

Status: **80-cell technical candidate; visual review pending; NOT live promoted.**

This isolated Large-body study preserves The Red Baron's current Undead identity: ivory skull, compact crown, black armor, oxblood noble coat and brass trim. The original Oh Tipi authority image informed rendering and natural proportions, not species or costume. No gameplay, current atlas, manifest registry, character stats or spell effects were changed.

## Latest technical successor: v5-registration

The root-owned strict builder was corrected to anchor the occupied pixels after nearest reduction. Rebuilding the unchanged `source-layout-v4.json` produced `candidate-v5-registration/red_baron.png`: **all80 actual decoded baselines now equal y83**, no mismatches, all gutters clear, no partial alpha, and584,141 transparent pixels. No new generation or pose fitting occurred. The three previously reported1px registration errors are resolved in this successor; older candidate folders remain immutable historical evidence.

The new full32-page native/2× light/dark Godot capture set and report are under `review-v5-registration/`. Unique strict logs are `.godot/red-baron-art-20260908/{build-v5-registration,qa-v5-registration,export-v5-registration}.log`, with no warnings/errors. The candidate remains **unpromoted because six walkB directions still lack accepted opposite-leg contacts**; this technical registration fix does not resolve that visual blocker.

PNG SHA-256: `52c15f10e57406ec20dc98629926eae07a247c5b1952805d911d67331923e66e`.

Manifest SHA-256: `5fe7d84168e48ce8709c83f4c8c85cb97bb6115557064910bd5625b135eb028e`.

## Final focused S/N correction (v4)

Generation is frozen after the final requested repair. `candidate-v4/red_baron.png` is complete80-cell staging art, using `source-layout-v4.json`. It preserves **78 byte-identical cells** from v2 and changes only SOUTH/NORTH `walk_b` (verified using decoded per-cell RGBA hashes).

A subsequent bounded audit of existing sprint-B as derived walk-B rejected all six remaining substitutions: high-knee running poses create8–11px crown/top discontinuities and do not reliably demonstrate opposite walk contacts. See `GAIT-REUSE-REVIEW.md` and exact comparison crops under `reuse-review-v2/`. No v5 layout or assembly was made from rejected choices.

The final edit restores the shoulder/torso silhouette and darker steel/oxblood treatment while retaining opposite planted boots. One fixed606 source-cell-width calibration applies equally to both new poses. Compared with the exact v2A crops, assembled rectangle bounds are:

| Heading | Walk A x,y,width,height | Walk B x,y,width,height |
| --- | --- | --- |
| South | 23,14,51,70 | 23,13,50,71 |
| North | 25,15,46,69 | 25,14,46,70 |

The earlier8px apparent crown shift is reduced to1px, and widths match within1px. This is the best S/N contact correction in this pass, still requiring visual approval; the other six walkB directions remain unresolved. Exact source pixels and technical reference crops are preserved. `WALK-SN-B-STYLE-REPAIR-PROMPT.md` records the fifth and final built-in generation request; `extract_walk_reference.gd` produced the exact6×nearest reference, not edited artwork.

**Historical v2/v4 registration blocker, resolved only in v5-registration above:** `slide/east`, `slide/north_west` and `walk_b/north_east` inherited from v2 end at actual exclusive y83 (last pixel82), not y84. The old builder's manifest calculated bounds from resized canvas dimensions, missing a final opaque row disappearing during nearest reduction. All80 gutters were clean, but only77 actual pixel baselines reached expected y83. The immutable v2/v4 pages must not be mistaken for the corrected successor.

V4 structural checks still pass80/80 with zero errors/warnings and zero partial alpha,584,141 transparent pixels, and32 actual Godot captures saved under `review-v4/`. These structural results **do not supersede the decoded baseline finding or visual acceptance**. Compare `walk-dark-0.png` and `walk-dark-1.png` there. Logs are `build-v4.log` and `export-v4.log` under `.godot/red-baron-art-20260908/`, both with empty stderr.

| V4 artifact | SHA-256 |
| --- | --- |
| `walk-sn-b-v2.png` | `1d295f14497008fcc7e449dca1fa146fabfb3c9938597be241df1722606edd63` |
| `candidate-v4/red_baron.png` | `cd8a7ed4d7646993af17f0e224df2cffaed64dcc2bd9059ca47ba3e12398141a` |
| `candidate-v4/manifest.json` | `d6cfa858cfebe1cd5396b94afe518a6b813ed4655ac62968fe7966c48333f153` |
| `candidate-v4/walk_sn_b_v2-removal-mask.png` | `d33be9fc73a6c88662227e78ada7366a76ae3c2033dc13e49f7c4faa1b42931a` |

## Rejected S/N proportion experiment (v3)

`candidate-v3/red_baron.png` is another complete80-cell candidate: it preserves78 cells from v2 and replaces only SOUTH/NORTH `walk_b` using `walk-sn-b-v1.png`. `source-layout-v3.json` records explicit rectangles and one board-wide calibration (670 calibrated source-cell width; both source figures679px tall, both output76px). This is not per-pose fitting. The source, masks and v2 remain unchanged.

The two new poses **do** visibly exchange the nearest/planted boot relative to walk A: screen-right for SOUTH B, screen-left for NORTH B. However, their torso/cape stance is narrower and more upright, and their gold treatment differs from the existing A cells. Thus this is a useful contact experiment, **not yet a seamless-style approval**. The other six walking headings remain uncorrected. Review S/N compatibility before generating more headings or selecting v3 over the more consistently rendered v2.

V3 strict build and structural QA pass80/80, with zero errors/warnings, zero partial-alpha pixels,584,607 transparent pixels and the unchanged2,949,120-byte decoded page. A second set of32 actual Godot light/dark1×/2× contact/playback PNGs plus report is preserved in `review-v3/`; compare `walk-dark-0.png` with `walk-dark-1.png`. Exact prompt: `WALK-SN-B-PROMPT.md`, built-in imagegen.

| V3 artifact | SHA-256 |
| --- | --- |
| `walk-sn-b-v1.png` | `03f02165b2e18068b95d318f372d5765a46af08eaca02931f4810b6c35334b7b` |
| `candidate-v3/red_baron.png` | `0da936a28d1df70ee1c793832bc8acb5799209d91460d7c3eb22bd6aa31d6f00` |
| `candidate-v3/manifest.json` | `ae0954859cbc3a0458202f12418844432f9d93011c1b00849729bc7abe52bdc9` |
| `candidate-v3/walk_sn_b_v1-removal-mask.png` | `8111f69d91206e45ee08a2fb6e84eed872d0416f5f321dd4030841cf1f0b70ba` |

## Consistent full-sheet baseline (v2)

`candidate-v2/red_baron.png` is a complete 768×960 RGBA page. Ten state rows are `grounded`, `jump`, `cast`, `hit`, `walk`, `sprint`, `slide`, `roll`, `walk_b`, `sprint_b`; each has S, SE, E, NE, N, NW, W, SW. These are 80 source poses, **not 80 independent animations**. Existing movement timing and mode aliases have not been changed.

- Native cells: 96×96; intended feet pivot: (48,84). Decoded audit found77 actual frames at exclusive y84 and3 inherited frames at y83, as detailed above; the manifest alone overstates this check.
- One Large-body page scale: 0.535211267605634. South standing is 76 px; the other seven standing headings are 75 px. There is no per-action fit or rescaling.
- All 80 cells are nonempty, have transparent gutters, and retain complete outlines inside their cells. All80 gutter checks passed; actual pixel-baseline correction is still required for3 cells.
- Binary alpha only: 583,687 transparent pixels; zero partially transparent pixels. Decoded page: 2,949,120 bytes (2.8125 MiB).
- Source PNGs are immutable. Measured explicit crops are in `source-layout-v2.json`; `inspect_sheet.gd` is a read-only foreground-run diagnostic, not an automatic pose acceptance tool.

## Actual visual review and limits

The complete v2 source improves north-facing cast/recoil/air articulation compared with v1. The skull, crown, black plate and oxblood silhouette remain consistent across the ten rows. Native and 2× Godot contact sheets were inspected on both dark and light backgrounds, including enlarged walk and sprint pairs.

**Remaining blocking art issue:** several `walk_b` headings still read as standing or retain the same leading-foot contact as `walk`. Byte inequality does not establish a proper gait. The north cast is more legible, but all eight walking contacts still need an anatomical opposite-leg review/correction before this page should be accepted as the new complete runtime art. Sprint pairs are more clearly opposed, but are not independently human-approved.

The additional `walk-contact-v1.png` attempt is **rejected and unused**: it repeats several leading-foot contacts and shifts head/torso treatment toward chunkier proportions. Its source and prompt are preserved for provenance; none of its pixels enter `candidate-v2`.

Generated sources have an opaque light neutral checker, not real alpha. The user-authorized importer removes only edge-connected near-neutral checker pixels (minimum RGB channel170, maximum spread18), preserving enclosed skull highlights. It removed562,974 source pixels and saved the exact removal mask. This operation can still erode light neutral boundary pixels; that is an explicit art-review risk, not a claim of perfect extraction. The originals have not been edited.

## Verification

- Strict complete pack build: **80/80 PASS**, exact dimensions, nearest sampling, one body scale, fixed registration; no warnings or stderr.
- Character sheet structural QA: **valid**, no errors/warnings; no byte-identical walk or sprint pairs. This does not grant visual acceptance.
- Shared strict importer suite: **997 assertions, 0 failures**, empty stderr.
- Actual Godot export: **32 review PNGs**, source unchanged, no warnings or stderr. Copies and `report.json` are preserved in `review-v2/`; cadence is viewer-only 6 poses/sec, not gameplay timing.
- Unique diagnostic receipts: `.godot/red-baron-art-20260908/{build-v2,qa-v2,export-v2,importer-contract}.log`.

Recheck without modifying sources:

```powershell
./scripts/review-character-sheet.ps1 -Sheet ./art_batches/character_style_v1/red_baron/candidate-v2/red_baron.png -Mode Check
```

Rebuilding requires a **new output directory**; the strict packer refuses to overwrite an existing candidate. Use `scripts/build_character_style_pack.gd` with `--spec=res://art_batches/character_style_v1/red_baron/source-layout-v2.json` and a new isolated `--output` path.

## Provenance and hashes

All five image attempts used the **built-in imagegen tool**, not a fallback API/CLI. The initial three prompt sets are `FULL-PAGE-PROMPT.md`, `MOTION-CORRECTION-PROMPT.md`, and `WALK-CONTACT-PROMPT.md`; the focused fourth/fifth prompts are listed above.

| Artifact | SHA-256 |
| --- | --- |
| `full-page-v1.png` | `18c1b10dd7d8c4ae5dc5e157cdb77e080af8e69e394b2aa48657b2cd609959c3` |
| `full-page-v2.png` | `c85a7be4fa8c3efe0351713fade3ea79cd0febba461abe08aa77c3707c3f3eba` |
| `walk-contact-v1.png` (rejected) | `d9125f711e82dbc221d6e259f2df5649aa8445f88c25ae4e348376a5694cb47a` |
| `candidate-v2/red_baron.png` | `a1001e67654f04fdbefcb66e7010ff4b93a13bdf1003f4088cdbb7b37e794fe8` |
| `candidate-v2/manifest.json` | `e6fe1efd73d4963c091d32eda7d138b18988d8ddae4e8829a682824aa3154c32` |
| `candidate-v2/complete_page_v2-removal-mask.png` | `91f29045bcf5c9bfce7de8e9210c8ce60d5ecba5e328cb8a47738b6f264c5e49` |

No live promotion, commit or push was performed.

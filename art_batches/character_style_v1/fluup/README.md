# Fluup Large — complete-coverage source candidate, NOT approved animation

Current checkpoint: **80/80 populated cells; technical assembly passes; visual animation acceptance is blocked.** No live character registry, gameplay, collision, size tuning or runtime files were changed. All four permitted image-generation calls were used. Do not interpret the atlas, distinct cell hashes or “complete coverage” as 80 accepted animation frames.

## Identity and authority

Canonical identity was checked against `content/champions/foundation_champions_v1.json`, the current affinity catalog and `reference/art/cast_sheet_v4/cast-reference.json`:

- **Fluup**, Large Orc, wire9; **Wind1 / Charge1 / Ice1**.
- Identity reference: `reference/art/front_cast_v2/07-fluup.png`.
- Style reference: `reference/art/oh_tipi_authority_v1/oh-tipi-authoritative-reference.png`.
- Broad green Orc, short upright black hair, modest tusks, charcoal spiked shoulder armor, indigo cloth/scarf, restrained brass hardware, exposed green toes.
- Empty hands, no elemental props, no baked effects or ground shadows.
- The previously loaded temporary Red Baron body alias was not edited or promoted by this source-only task.

## Available artifacts

- `candidate-v1/fluup.png`: 768×960 RGBA, 96×96 cells, 8 directions ×10 existing states.
- `candidate-v1/manifest.json`: exact source/atlas hashes, source rectangles, scale and actual post-nearest occupied bounds.
- `candidate-v1/technical-qa.json`: decoded-pixel and source/mask conservation checks, explicit failed gait pairs.
- `prepared-v1/source-layout-calibrated-v1.json`: the exact assembler input.
- `prepared-v1/extraction-receipt.json`: immutable source hashes, original alpha statistics, exact removal-mask hashes and component translations.
- Four `prepared-v1/*-removal-mask.png` images: white marks removed backdrop; black marks untouched pixels.
- `PROMPTS.md`: all four actual prompts.
- `prepare_sources.py`, `audit_candidate.py`, `capture_review.gd`: isolated repeatable technical processing/QA. These refuse to overwrite existing evidence.

Canonical atlas order:

- Columns: S, SE, E, NE, N, NW, W, SW.
- Rows: grounded, jump, cast, hit, walk A, sprint A, slide, roll, walk B, sprint B.

## Source provenance and normalization

| Immutable board | Source layout | SHA-256 |
|---|---|---|
| core-cardinal-v1.png | S/E/N/W; grounded, jump, cast, hit, roll | 9abedf03430d2e2f6788c0f4e45ca2358bb48947150ba1425f862b3887956425 |
| core-diagonal-v1.png | SE/NE/NW/SW; grounded, jump, cast, hit, roll | 69585eb4d27a3bb540e5dd546dc2d9dd9892a6cbe957da719b5ecd4356d5731e |
| motion-cardinal-v1.png | S/E/N/W; walk A, walk B, sprint A, sprint B, slide | 31027f0646b39ff9dcc1e28fe02052b61905d170aa914d4ebfae1dcd3ff57389 |
| motion-diagonal-v1.png | SE/NE/NW/SW; walk A, walk B, sprint A, sprint B, slide | 05f750591c7b045b188811965cd77643a790f681bd66cf4af8fdfd535fe5c65e |

Generated originals are preserved both here and in the built-in image-generation output directory. Requested transparency was baked as a neutral checker. The user explicitly authorized “reviewed background removal and assembly”; processing therefore removes only reviewed **edge-connected** neutral backdrop (minimum channel170, RGB spread≤18). It does not paint, recolor, mirror or synthesize body pixels.

The reused tested separation primitive is `art_batches/character_style_v1/s_wayne/separate_review_boards.py`; its exact hash is locked in the receipt. It finds20 substantial figures per board, preserves detached subject pixels, records translations and adds transparent gutters. Uniform raw row slicing is not used because the first cardinal idle row crosses a nominal fifth-sheet boundary.

One diagonal-family normalization applies to **both entire diagonal pages**:

- South cardinal idle:331px high.
- Mean of four diagonal idles:302.75px.
- Diagonal page normalization:331/302.75 =1.09331131296.
- Global Large body scale after page normalization:76/331 =0.229607250755.
- Cardinal pages unchanged; no per-pose fitting or anatomy correction.

The standard Godot importer performs nearest sampling and then translates the actual surviving opaque bounds to pivot(48,84). The actual final opaque row is **y83 in all80 cells**. Standing heights in canonical direction order are **76,76,76,77,75,76,76,76px**.

Candidate PNG SHA-256:
`d03cb54ef65301ca62f2745967c358f678f3cae60f23e284a2ad8fd4f79f7f00`

Decoded RGBA SHA-256:
`d68f6589a4ea860cc30d3162495d59a3d0ee93922184638e1affcbb239adf4ed`

## Actual visual review — hold, do not promote automatically

Godot rendered and the artwork lane inspected both dark/light80-cell sheets and native1×/nearest2× A/B gait frames. The identity, eight directional groups and jump/cast/hit/slide/roll silhouettes are useful review material. **The following defects prevent a claim of complete usable animation:**

1. **11 of16 walk/sprint directional A/B pairs repeat the leading foot.** Failed pairs: walk N; sprint S/N; walk and sprint SE/NE/NW/SW. Changed arms, cloth or different image hashes do not fix the anatomical contact.
2. The remaining five pairs have more plausible contact variation but are not individually certified as final animation.
3. Some enclosed pale neutral islands remain under arms/inside silhouettes after edge-connected removal. They are visible in the native sheets; removing them automatically could delete real pale armor highlights. They need explicit source-region review, not broad color deletion.
4. Exact E/W upper-torso yaw and diagonal shoulder/cloth details vary; perfect orthographic profile consistency is not established.
5. Two source contact phases are not a hand-authored multi-frame gait overhaul. Current pixel density at76px is high and deserves gameplay readability review after source defects are fixed.

No fifth generation was made. The smallest next correction, if separately approved, is to replace only the11 failed B-contact cells with genuine opposite-foot poses while preserving identity/facing and page measurements, plus reviewed enclosed-backdrop cleanup. Keep all current originals and receipts.

## Verification and native evidence

Completed:

- Strict Godot pack:80/80, no warnings/errors in `.godot/artwork-20260908/fluup-pack-v1.log`.
- Decoded atlas audit:80 distinct RGBA cells, canonical semantic mapping, transparent outer gutters, exact actual y83 baseline, Large envelope, binary alpha, PNG/RGBA/source/prepared/mask hashes.
- Exact retained subject RGBA conservation through background removal and component translation.
- Existing reused extraction primitive tests: **5 passed**.
- Hidden Godot OpenGL capture:10 actual rendered PNGs; clean log `.godot/artwork-20260908/fluup-native-v1.log`.

Evidence directory: `.godot/artwork-20260908/fluup-complete-native-v1/`

- `sheet-dark.png` and `sheet-light.png`: all80 cells at native size.
- `gait-00.png` through `gait-07.png`: walk/sprint A/B in all8 directions at1× and2× nearest.
- `contacts.gif`: standard FFmpeg assembly of those actual renderer frames at5fps.

Commands actually used:

```powershell
python.exe art_batches/character_style_v1/fluup/prepare_sources.py
. scripts/flux2-common.ps1
$taskGodot = Get-FluxGodot
Invoke-FluxGodotChecked $taskGodot @('--headless','--path',(Get-Location).Path,'--script','res://scripts/build_character_style_pack.gd','--','--spec=res://art_batches/character_style_v1/fluup/prepared-v1/source-layout-calibrated-v1.json','--output=res://art_batches/character_style_v1/fluup/candidate-v1') '.godot/artwork-20260908/fluup-pack-v1.log' -RejectWarnings
python.exe art_batches/character_style_v1/fluup/audit_candidate.py
Invoke-FluxGodotChecked $taskGodot @('--path',(Get-Location).Path,'--rendering-method','gl_compatibility','--rendering-driver','opengl3','--script','res://art_batches/character_style_v1/fluup/capture_review.gd') '.godot/artwork-20260908/fluup-native-v1.log' -RejectWarnings
python.exe -m unittest discover -s art_batches/character_style_v1/s_wayne -p test_separate_review_boards.py
```

The initial extraction writes the uncalibrated specification; the separately retained calibrated specification contains the single reviewed diagonal-family factor described above. Existing output directories intentionally cause repeat commands to fail closed rather than overwrite provenance.

**Frozen source-only checkpoint. No live promotion, no commit, no push.**


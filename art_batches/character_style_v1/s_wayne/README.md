# S. Wayne complete Small-body candidate

Current checkpoint, 2026-09-08: **80/80 distinct source-derived cells**, now promoted
by the parent into the live complete-page registry after native review, strict
import and focused tests. This art lane itself changed no gameplay files. Exact
runtime copy: `assets/sprites/champions_v3/style_v1/s-wayne-v1.png`. Human animation
acceptance remains open and the old installer is unchanged.

- Final PNG: `candidate-v2/s_wayne.png`, 768×960 RGBA.
- Full source specification: `prepared-v5/source-layout.json`.
- Actual pixel audit: `candidate-v2/technical-qa.json`.
- PNG SHA256: `363c33754ebd38829fb3478c162a77ca4946987af4e5d186e9ce583987337770`.
- Decoded RGBA SHA256: `d7269d6e574405d240429eba3cb0125c0b3d67371a56c4dc2687940e81d0ca04`.
- Eight columns S/SE/E/NE/N/NW/W/SW; ten rows grounded, jump, cast, hit,
  walk A, sprint A, slide, roll, walk B, sprint B.
- Fixed 96×96 cells, pivot48/84, actual occupied exclusive bottom84 in every
  cell, standing idle57–58px, one global Small scale58/787. No per-pose fitting.
- `live_promotion=false`; parent must explicitly integrate/review the candidate.

## Production and immutable provenance

The previous12-cell pilot remains unchanged. The missing68 cells are genuine
new raster source poses made with the built-in imagegen skill, not cloned slots
or code-generated character artwork. Sources and full prompts remain in this
folder; `PROMPTS-EXPANSION-V1.md`, V2 and V3 record the new iterations.

The user explicitly authorized reviewed background removal and assembly.
`separate_review_boards.py` only removes edge-connected light-neutral backdrop
(RGB minimum170, spread at most18), then translates existing connected figures
into separated cells. Every other RGBA pixel, including detached dark edge
islands, is preserved; there is no recoloring, limb synthesis or source resizing.
This handles wide slide figures whose bounding rectangles overlap even though
their actual pixels do not.

`prepared-v4/extraction-receipt.json` records the ten initial selected boards;
`prepared-v5/extraction-receipt.json` records the final two-profile Sprint B
replacement and locks the previous specification hash. Each board has its exact
original-space removal-mask PNG, raw-source hash, prepared-source hash, component
bounds, translation and retained pixel count. The established Godot importer
does the single nearest-neighbor body-size reduction afterwards.

Original failed/revised sources remain preserved but are not counted twice:
the all-diagonal walk v1 had wrong aspect and repeated contacts; front/rear walk
v1 repeated contacts; sprint B v1 repeated several A contacts; jump/cast eastv1
had weak SE facing. Corrected v2 sources are selected. Of sprint-b-all-v2, its
E/W cells were replaced by `sprint-b-profiles-v2.png`; the other six remain.
No unreviewed checkerboard image is used directly as runtime pixels.

## Actual acceptance evidence

- Strict full Godot pack:80/80, 768×960, no errors or warnings, log
  `.godot/artwork-20260908/swayne-complete-pack-v2.log`.
- Five pure technical extraction regressions passed: actual alpha, retained
  RGBA conservation, enclosed ivory highlight, detached edge preservation,
  transparent gutters, ambiguous extra body rejection, clipping rejection and
  path containment. These are pipeline tests, not art-quality certification.
- Independent decoded-PNG audit:80 distinct cells; exact actual baseline84;
  source/mask hashes unchanged; all cell bounds agree with manifest.
- Actual hidden Godot renderer output, personally inspected:
  `.godot/artwork-20260908/swayne-complete-native-v2/sheet-dark.png`,
  `sheet-light.png`, `gait-00.png`, `gait-01.png` and `contacts.gif`.
  The flipbook assembles eight captured frames at5fps; it is not an in-game
  performance/feel test. No checkerboard, black rectangle or clipped limb appears
  in the actual renderer. Some generic image viewers ignore transparent RGB;
  judge transparency using the Godot captures.

## Honest remaining review points

This is a complete **playtest candidate**, not final human art acceptance or a
claim that all27 named characters have distinct finished art. All eight headings
and ten action silhouettes are present. Walk contacts visibly reverse feet;
side sprint B received a separate near-arm/near-knee correction. Some diagonal
walk arms remain quiet rather than fully counter-swung. Exact diagonal yaw,
costume microdetails and small source-epoch body changes deserve in-game review.
Only two authored contact poses exist per walk/sprint cycle; this is not a
hand-drawn many-frame animation overhaul. Edge-connected ivory highlights can
be affected by the authorized neutral-backdrop rule; exact masks expose that risk.

Reproduce to NEW output folders only:

```text
python art_batches/character_style_v1/s_wayne/test_separate_review_boards.py
python art_batches/character_style_v1/s_wayne/separate_review_boards.py --config expansion-plan-v3.json --output prepared-next
godot --headless --path . --script res://scripts/build_character_style_pack.gd -- --spec=res://art_batches/character_style_v1/s_wayne/prepared-next/source-layout.json --output=res://art_batches/character_style_v1/s_wayne/candidate-next
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://art_batches/character_style_v1/s_wayne/capture_complete_review.gd -- --candidate=candidate-v2 --tag=swayne-complete-next
```

The original12-cell checkpoint is preserved below as historical evidence.


## Previous12-cell Small-body checkpoint

Earlier2026-09-08 historical checkpoint:12 cells had a derived transparent native review.
That older output was not a complete80-cell character or a live sprite replacement.

Output at that checkpoint: `review-v4/s_wayne-partial-review.png`,768×192 RGBA.
Specification at that checkpoint: `source-layout-v3.json`. It contains all8 grounded
headings plus south/east walkA/B. The original three-pose and six-pose reviews
remain as earlier, non-overwritten evidence. Remaining coverage:68 cells.

## Sources and authorization

- Identity: `reference/art/front_cast_v2/02-s-wayne.png`.
- Style: `reference/art/oh_tipi_authority_v1/oh-tipi-authoritative-reference.png`.
- `south-idle-walk-ab-v1.png`:1774×887 RGB24; three genuine opposite-contact
  silhouettes, but baked checkerboard.
- `south-idle-walk-ab-alpha-attempt-v2.png`: the one built-in extraction edit
  still has RGB24 checkerboard, and is not the processing input.
- `east-idle-walk-ab-v1.png`: real right-facing profiles, but repeated apparent
  A/B leg silhouette; superseded by v2 and excluded from final review coverage.
- `east-idle-walk-ab-v2.png`: targeted correction bends the near leg behind and
  changes its overlap with the forward far leg. Included in the final review.
- `idle-n-ne-nw-v1.png`: centered back and both rear quarters; no face on north.
- `idle-w-sw-se-v1.png`: west profile and both front quarters.

After these transparency failures the user explicitly authorized reviewed
background removal and assembly. `source-layout-v1.json` locks the original
SHA256 and a narrow edge-connected light-neutral checker rule: RGB channels
at least170 and spread at most18. Enclosed highlights remain. Dark coat, brown
skin and gold are outside the rule. Original files are never rewritten.

## Actual native result

`review-v1/s_wayne-partial-review.png`:288×96 RGBA, three96px cells, pivot48/84,
nearest sampling and one global scale0.0736975857687421. Visible bounds:
idle27×58, walkA26×58, walkB26×57. The1px height difference is from the authored
bent pose, not per-pose resizing. The source's1,055,290 edge-connected background
pixels were removed; original hash remains
`dc659fdf21e2bde8c237905e2b08b98937927543f10b8bc4c18205ebd7907bae`.

Actual hidden Godot native+4× nearest light/dark captures:
`.godot/artwork-20260908/swayne-native-review-v1/frame-00.png` and
`frame-01.png`, plus `contacts.gif`. I inspected both: the feet and arms switch
sides, the chain stays on the same side and the checkerboard is gone. A few pale
edge pixels around the hair remain a review risk; light neutral highlights that
touch the outer background may be affected by this rule. This is not blanket
edge/anatomy acceptance, nor proof of the other seven headings.

## Generic pipeline

`scripts/build_character_style_pack.gd` now takes an explicit source spec and
resolves the character and body against the live canonical catalog. It supports
all27 named IDs, exactly three body heights58/68/76 and arbitrary explicit page
layouts. Full output requires80 unique state/direction cells; `--review` emits a
compact partial strip with honest metadata. Every output has live_promotion=false.
Existing output folders are not overwritten.

```text
godot --headless --path . --script res://scripts/build_character_style_pack.gd -- --spec=res://art_batches/character_style_v1/s_wayne/source-layout-v3.json --output=res://art_batches/character_style_v1/s_wayne/review-next --review
godot --headless --path . --script res://scripts/test_character_style_pack.gd
```

Focused final result:997 assertions, zero failures in
`.godot/artwork-20260908/character-pack-generic-v3.log`. The all27 synthetic packing checks
validate metadata and technical compatibility, not authored art for those27.
No runtime registry, character stats, simulation, collision or gameplay changed.

## Final masks and visual review

The final manifest retains all four exact grayscale removal masks and their
SHA256 hashes, original source hashes, original alpha range, thresholds, removed
pixel counts, source rectangles, cropped bounds and common scale.
White mask pixels mean removed source background; black pixels were not removed.
Four source hashes and four mask hashes were independently rechecked and match.
Removed pixels per source: south1,055,290; east1,144,004; rear1,076,276;
west/front1,109,278. Originals remain unchanged.

Native/2× Godot contact sheet:
`.godot/artwork-20260908/swayne-twelve-native-v1.png` (1280×824), inspected.
All12 selected cells are technically valid review candidates; the8 idle headings
are distinct and south/east contacts reverse visible limbs. Source-epoch body
drift is not corrected with per-pose fitting: idle heights57–58, east walk56.
Exact diagonal yaw, pale hair-edge pixels and the stronger eastB heel lift remain
human quality-review points. At that checkpoint there were **zero runtime-approved new-style frames**
and no claim of a complete animation set. The two superseded3-figure sources
(six unused figures) remain preserved; their existence is not counted as coverage.

Use a new output directory on each reproduction; existing evidence is never
overwritten. That earlier tranche stopped at the parent80%-remaining checkpoint.
The user later explicitly resumed production with a50%-remaining cutoff; the
complete80-cell candidate and current acceptance evidence are documented above.

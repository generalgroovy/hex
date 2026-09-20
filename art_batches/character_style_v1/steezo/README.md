# Steezo - unique small Goblin body candidate

Status: **candidate-v3 is complete and technically checked; runtime promotion and independent animation acceptance remain pending.** No live sprite registry, catalog, simulation, collision, controls or network files were changed.

Steezo retains olive-green skin, pointed ears, dark swept-back hair, brass forehead goggles, an ochre scarf and practical brown leather clothing. All hands are empty; magic, projectiles, environment and ground shadows are excluded from the body sheet. Identity comes from `reference/art/front_cast_v2/04-steezo-corrected.png`; pixel treatment comes from the original `reference/art/oh_tipi_authority_v1/oh-tipi-authoritative-reference.png`, not the old temporary S. Wayne body.

| Artifact | Purpose / result |
|---|---|
| `candidate-v3/steezo.png` | 768x960 RGBA8; 80 source cells; 96x96 cells; feet pivot48,84; nearest sampling |
| `candidate-v3/manifest.json` | Complete source/crop/hash provenance; fixed Small58px standing guide; explicitly not live |
| `candidate-v3/review-report.json` | All80 cells checked: nonempty, transparent borders, binary alpha, no exact duplicate walk/sprint A/B |
| `candidate-v3/native-dark-01.png`, `native-light-02.png` | Actual Godot native-size review of all80 cells, not a generated mockup |
| `full-page-v1.png` | Immutable built-in generated80-cell source; original proportions/actions retained except B contacts |
| `gait-rejected-repeated-contacts-v1.png` | Rejected32-cell correction: too little actual opposite-contact change; never assembled into final |
| `gait-b-contact-v2.png` | Final16 B-contact source; measured crop bands, no assumed equal grid |
| `reviewed-source-v2/`, `reviewed-gait-v3/` | Derived background-only extraction, exact masks and source-hash receipts; originals retained |
| `source-layout-v3.json` | Authoritative candidate assembly specification; prior layouts/candidates retained as review history |
| `PROMPTS.md` | Exact built-in generation and correction prompts |

Rows: grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b. Every row has S, SE, E, NE, N, NW, W, SW. These are **80 source poses, not80 fully animated clips**. Walk and sprint use supplied A/B contacts; single-pose actions remain honestly single-pose.

## Visual review and limitations

Front faces the camera; north presents the back. S/N foot contacts now visibly alternate. North walk A/B is58/57px occupied height and north sprint55/57px, with common bottom83; south walk57/56px and sprint54/56px. The extreme scale change in the first B poses is removed through one correction-page-wide anatomical calibration, never individual pose fitting. The correction page uses one0.5 source normalization for all16 cells, documented in the layout; its physical column pitch is not misrepresented as that calibrated reference width.

Five visible trapped neutral background patches were specifically reviewed and removed:147px in the original source plus418px in the B source. Each component has a fixed seed and exact pixel count. The retained masks prove every non-mask RGBA pixel unchanged. Eyes, brass highlights, anatomy and clothing were not globally erased or recoloured.

**Remaining acceptance concern:** E/W sprint contacts are visually subtler than S/N and still need motion review; small shade/detail variation between the separately generated B page and original page is visible at2x. Distinct frame hashes do not prove natural foot alternation, and successful format checks do not approve charm, anatomy, movement feel or a release. This is a usable unique candidate for review, not a claim of final all-direction animation polish.

## Reproduce review

From the repository root:

```powershell
.\scripts\review-character-sheet.ps1 -Sheet '.\art_batches\character_style_v1\steezo\candidate-v3\steezo.png'
.\scripts\review-character-sheet.ps1 -Sheet '.\art_batches\character_style_v1\steezo\candidate-v3\steezo.png' -Mode Export
```

The final actual Godot32-page light/dark export is `.godot/character-qa/99cdd7d802ad405fbe1f99f9f7f340cb/`; its unique log is the sibling `.log`. Assembly log: `.godot/steezo-pack-v3.log`. Background guards: `.godot/steezo-source-background-v2.log` and `.godot/steezo-gait-background-v3.log`.

To rebuild with the pinned Godot executable, run `--headless --path . --script res://scripts/build_character_style_pack.gd -- --spec=res://art_batches/character_style_v1/steezo/source-layout-v3.json --output=res://art_batches/character_style_v1/steezo/NEW-CANDIDATE`. The assembler refuses overwrite. Reviewed extraction can be reproduced by `prepare_reviewed_source.gd` (original) and `prepare_reviewed_source.gd -- --gait` (B sheet), but also refuses existing output; retained source/mask receipts allow checking the existing result without rewriting it.

Final sheet SHA256: `6871b5fa9357d8c24ed375db3ebcb8e1840dfd61f1ffd87f99fe069a664b4111`.

## Source-playtest promotion, 2026-09-08

`candidate-v4-registration/steezo.png` was rebuilt with the shared actual-foot
registration fix and is pixel-identical to v3. Root reviewed all80 cells and
native A/B captures, then copied the exact page to
`assets/sprites/champions_v3/style_v1/steezo-v1.png`. The reviewed complete-page
registry now makes Steezo an individual sprite set instead of a S. Wayne alias.
Strict32-page QA: `.godot/character-qa/8555f4f41b6e4a8fad2c12eb19196166`.
Actual Wellspring/Gallery captures confirm world body, HUD and Gallery use it.
The old candidate manifest's non-live wording remains historical provenance;
the registry is the current promotion decision. Subtle profile sprint contacts
and human motion acceptance remain open; the old installer was not rebuilt.

# Reusable wireframe base v1

Candidate-only, geometric pixel mannequin. This is the simple base underneath later character designs: no race, costume, weapon, magic, aura, ground, or environment. Existing artwork is untouched; this directory is not a runtime override or a new live paper-doll renderer.

## Files and coverage

- `small-wireframe.png`, `middle-wireframe.png`, `large-wireframe.png`: transparent RGBA atlases, each 768 x 960, 96 x 96 cells, feet pivot (48,84), last opaque row 83. South-standing occupied heights are 58 / 68 / 76 pixels.
- Columns: South, South-East, East, North-East, North, North-West, West, South-West.
- Rows match `template_v2/contract.json`: grounded, jump, cast, hit, walk A, sprint A, slide, roll, walk B, sprint B.
- `overview-1x-dark.png` / `overview-1x-light.png`: native pixel comparison of all three sizes and eight headings.
- `overview-4x-dark.png` / `overview-4x-light.png`: exact nearest-neighbor enlargement of the same review.
- `small-all-poses-2x.png`, `middle-all-poses-2x.png`, `large-all-poses-2x.png`: all 80 cells per body.
- `rig-data.json`: reusable, named 3D anatomical landmarks and their registered 2D projections for all 240 cells, plus immutable bone lengths, contacts, ordering, and source hash.
- `evidence.json`: image hashes, per-cell bounds, measured heights, automated coverage, and explicit limitations.

The same normalized anatomical skeleton is reused at three fixed scales, not redesigned or distorted per pose. Rose limbs are anatomical left, blue limbs anatomical right. The warm nose/sternum mark the front; rear views have an occipital seam and stippled spine, with no face or nose. Opaque dark mesh interiors occlude far limbs while the cell background remains transparent. A/B contacts exchange the supporting leg and swing the opposite arm.

## Editable source and rebuild

The existing `../template_v2/pose_guide_model.gd` remains the canonical editable fixed-bone/IK source. `export_rig.gd` calls that source directly: no duplicate pose equations. `build.py` is a deterministic offline pixel rasterizer for these candidate PNG files, not game code. Its `PALETTE`, segment widths, and torso/head mesh treatment can be changed independently of the skeleton.

From the repository root, with Godot 4 and Python/Pillow available:

```powershell
& $Godot --headless --path . --script res://art_batches/character_style_v1/wireframe_base_v1/export_rig.gd
python art_batches/character_style_v1/wireframe_base_v1/build.py
& $Godot --headless --path . --script res://scripts/test_character_pose_guides.gd
```

Set `$Godot` to the local executable path. The export/build commands intentionally regenerate only files in this candidate directory. PNG alpha is binary, drawing uses integer pixels directly, and preview enlargement uses nearest-neighbor sampling. The builder verifies the source hash, template contract, all 240 cells, 2,400 fixed-bone lengths, anatomical opposing contacts, all cell bottoms, and exact south-grounded heights.

## Boundaries and next decision

Current local result: the builder passed for all 240 cells. Agent visual inspection covered the native light overview, enlarged dark overview, and all 80 Middle cells. The front/back markings, limb-side colors, alternate contacts, and three size steps are visible. Side-facing torsos are deliberately spare, box-like construction volumes. This is an agent check, not user approval or in-game acceptance.

This is one bounded prototype, not an accepted character pack. Ten contact/key poses are not complete smooth animation clips. All three sizes share normalized proportions. This atlas contains a casting body pose in each facing; it does not implement independent cursor aiming or change gameplay, timing, hitboxes, collisions, network state, character selection, or live artwork. Full in-game and user acceptance remain separate.

If accepted, later characters can be drawn around the named joints, same camera, cell registration, facing order, and opposite contact grammar. Keep character identity and costume pixels separate from this neutral construction source.

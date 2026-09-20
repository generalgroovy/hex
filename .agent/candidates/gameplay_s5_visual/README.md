# Shared melee body presenter candidate

Status: isolated candidate. Godot import, tests, native capture, timing review and visual acceptance are **NOT RUN** in this lane.

## Candidate files

- `melee_body_presenter.gd` promotes to `src/presentation/melee_body_presenter.gd`.
- `test_melee_body_presenter.gd` promotes to `tests/unit/test_melee_body_presenter.gd` and needs one root-owned `tests/run_all.gd` registration.
- `build_attachments.py` is a standalone root-run post-bake helper; it stays outside runtime source.
- `.gdignore` keeps this preparation outside Godot imports.

The presenter expects future runtime files under `res://assets/sprites/wireframe_melee_v1/`:

- `manifest.json` (the accepted bake manifest, promoted from `candidate-manifest.json`)
- `small-melee.png`
- `middle-melee.png`
- `large-melee.png`
- `attachments.json`, when the accepted manifest references the compact table

It validates the fixed 96x96 cell, 48/84 pivot, 768x2880 page dimensions, shared style, 58/63/68 baked display heights, three page hashes, decoded RGBA hashes, all 720 manifest frame records, and the exact baker row formula. It never fits or rescales a frame at runtime.

## Frame selection API

```gdscript
melee_body.frame(
    body_type,
    physical_kind,              # 1 Punch, 2 Kick
    physical_phase,             # 1 startup, 2 active, 3 recovery
    Vector2i(physical_aim_x, physical_aim_y),
    Vector2i(velocity_x, velocity_y),
    physical_phase_ticks_remaining,
    physical_phase_ticks_total,
) -> Dictionary
```

Inactive, malformed, zero-aim, or out-of-duration physical state returns an empty dictionary so the ordinary `WireframeBodyPresenter.frame()` remains the fallback. Each valid frame returns the same texture/source-region and body metadata shape consumed by `CartoonChampionPresenter`, plus physical phase, relative stance, and attachment metadata. It deliberately omits `offset`, `scale`, and `aura_scale`, allowing the existing composite movement result to retain its current travel offset, unit draw scale, and aura response.

`phase_selector()` selects the exact authoritative startup, active, or recovery key and reports bounded progress from remaining/total ticks. There is no presentation clock and no interpolation into a different frame.

`relative_gait_index()` compares current travel to the latched attack aim using integer dot and cross products:

- zero travel -> idle
- dominant nonnegative dot -> forward
- dominant negative dot -> backward
- positive cross -> right strafe
- negative cross -> left strafe

This chooses lower-body stance independently from physical kind and phase. The attack aim never follows later pointer drift.

## Root-only compact attachment build

After the accepted pass-two exporter and bake have finished, run from the checkout root:

```powershell
python .\.agent\candidates\gameplay_s5_visual\build_attachments.py --check
python .\.agent\candidates\gameplay_s5_visual\build_attachments.py
```

The check form reads and validates the actual `art_batches/character_style_v1/wireframe_melee_v1/candidate-manifest.json` and `rig-data.json` without writing. The build form writes one compact `attachments.json` beside them and replaces the candidate manifest with an equivalent document containing one additive `attachment_table` record. The helper validates all 720 frame/pose keys, the exact row formula, body/gait/attack/phase/direction labels, the raw rig hash already recorded by the bake manifest, and every striking point before writing atomically.

The compact file stores numeric arrays with this declared order:

```text
body_index, gait_index, physical_kind, physical_phase, aim_index,
point_x, point_y, pixel_x, pixel_y
```

`point_x/point_y` are already-baked subpixel coordinates in the local 96x96 cell. The helper applies the same one-time per-size transform around `(48,84)` that the baker used. `pixel_x/pixel_y` use the baker's Python rounding. The table records the raw `rig-data.json` SHA-256 and a normalized pre-attachment manifest SHA-256. The additive manifest record stores the table path, table SHA-256, raw rig provenance, coordinate-space identifier, and exact record count. It adds presentation metadata only and does not add gameplay or collision values.

For promotion, copy the three accepted pages, the updated candidate manifest as `manifest.json`, and the generated compact table into `res://assets/sprites/wireframe_melee_v1/`. The 3.2 MB source `rig-data.json` remains in the art batch and is not a runtime dependency.

## Runtime attachment contract

When the manifest contains `attachment_table`, the presenter requires the canonical runtime path and verifies the compact file hash, raw-rig provenance, schema, coordinate space, matrix labels, display heights, body scales, nine-field record layout, all 720 unique rendered-frame keys, in-cell points, and matching rounded pixels. Punch exposes `hand_r`; Kick exposes `toe_r`.

Frames return both subpixel `attachment_point` and rounded `attachment_pixel`. The caller converts the local point to world/canvas space with:

```gdscript
world_attachment = body_draw_anchor - MeleeBodyPresenter.PIVOT + frame.attachment_point
```

If the manifest has no `attachment_table` field, body configuration remains usable and every frame explicitly returns `attachment_available = false`, `attachment_name = "missing"`, `attachment_point = Vector2.INF`, and `attachment_source = "missing_attachment_table"`. Once a table is referenced, a missing, malformed, incomplete, path-changed, provenance-mismatched, or hash-mismatched table fails configuration; it cannot silently supply guessed anchors.

## Root integration location

The shared integration point is `CartoonChampionPresenter.movement_frame()`, immediately where it currently calls `wireframe_body.frame(...)` and merges that dictionary into the composite result. Selecting the melee frame there covers all three existing consumers without duplicate logic:

1. Local body rendering through `CartoonChampionPresenter.draw()` from `bootstrap.gd`.
2. Remote body rendering through the same `draw()` path.
3. POV observer repaint through `CartoonChampionPresenter.movement_frame()` in `bootstrap.gd`.

Configure and clear one `MeleeBodyPresenter` beside the existing `wireframe_body`. When authoritative physical state is active, call the melee adapter with the character recipe's existing `body_type`, latched physical aim, current velocity, and authoritative phase timing. Otherwise call the current body presenter unchanged. Merge the selected body dictionary into the already-created composite result exactly where `body_frame` is merged today. The composite keeps the current movement offset, jump lift, shadow anchor, aura, afterimages, world transform, and `Vector2.ONE` draw size.

Root still owns the PlayerState fields, snapshot/transport propagation, interrupt legality, bootstrap hook-up, runtime asset promotion, serialized tests, and captures. The presenter does not infer physical state from spell casts or movement animation names.

## Prepared checks

The test candidate covers all 240 distinct source cells per body, page bounds, row endpoints, dot/cross stance selection, phase validation and progress, compact-table schema, promoted resource hashes, all 720 runtime frame selections and attachments, unit runtime scale preservation, exact body heights, explicit missing-table behavior, and failures. These checks are prepared only and have not been executed.

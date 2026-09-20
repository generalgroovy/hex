# Wireframe motion v2 — shared size-based body source

This batch supplies three neutral bodies for the user's authorized skeleton replacement. The offline art has no authority over statistics, collision, hurtboxes, races, chemistry, or network outcomes; the separately authorized sprint-speed change is documented below. Current output is the nine-texture, schema-2 base/walk/sprint system. Combined integration verification is pending; the [latest motion and awareness checkpoint](../../../docs/MOTION-AWARENESS-CHECKPOINT.md) owns current test, capture, export and acceptance status.

## Delivered geometry

- Three fixed scales: Small 58 px, Middle 68 px, Large 76 px in the south-grounded calibration pose. All actions use the same scale per body.
- Each size has an eight-direction, ten-pose base page (768×960), a 512-cell walking page, and a distinct 512-cell sprint page (each 1536×3072): eight travel directions A × eight aim directions B × eight cyclic phases per gait.
- Every cell is 96×96 with pivot (48,84), binary alpha, and final opaque row 83. No weapons, wands, auras, ground marks, or environment.
- Chest is now a 24-vertex, three-ring 3D volume. The chest has normalized half-depth 0.12, including at E/W profile; it is not the thin flat template-v1 torso.
- Head/chest/pelvis face B together. Waist yaw twist is exactly zero. Feet stride along A, so opposing A/B becomes backpedaling and side A/B becomes a side shuffle rather than twisting the spine through 180 degrees.
- Lateral step length is reduced to avoid crossing left and right feet. The support foot stays flat, the opposite foot lifts, and contacts exchange after half a cycle. Arms remain free-handed and aim-ready toward B rather than counter-swinging away from the aim.
- Sprint increases normalized stride from 0.165 to 0.208 (26%), torso lean from 0.09 to 0.22, swing lift from 0.085 to 0.105, and adds slight aim-preserving hand follow-through. Bones, head size, torso dimensions and all three body scales stay fixed.

## Reuse and atlas contract

The existing `../template_v2/pose_guide_model.gd` remains the fixed-bone/IK authority. `export_rig.gd` calls its `two_bone`, `landmarks`, and projection routines directly, adding the bounded cyclic locomotion and torso mesh. `rig-data.json` retains named 3D landmarks, projected joints, mesh faces, scale, travel, aim, and phase for all 3,312 cells. `build.py` draws integer pixels directly; there is no new live procedural body renderer.

Directions, in both axes: S, SE, E, NE, N, NW, W, SW. Locomotion index:

```text
index = ((travel * 8 + aim) * 8 + phase)
column = index % 16
row = floor(index / 16)
```

Base rows: grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b.

Runtime outputs are in `assets/sprites/wireframe_motion_v2/`: `manifest.json`, `{small,middle,large}-base.png`, `{small,middle,large}-locomotion.png`, and `{small,middle,large}-sprint.png`. Manifest schema 2 requires all three banks and includes source-PNG and raw-RGBA SHA-256 checksums, body reference heights, dimensions, registration, and exact indexing. Nine shared pages decode to 116.44 MiB total (54 MiB walk + 54 MiB sprint + 8.44 MiB base), regardless of character count. All six pre-existing base/walk PNGs were verified byte-identical to their prior imported sources; the sprint bank is additive.

The earlier six-texture, 1,776-cell, 62.44-MiB [skeleton checkpoint](../../../docs/SKELETON-MOTION-CHECKPOINT.md) is historical. It shared one gait geometry between walking and sprinting. The present system has 3,312 cells and separate fixed-bone banks; prior checkpoint acceptance or test receipts must not be treated as verification of this larger integration.

## Verification and visual review

`evidence.json` records 240 base cells, 1,536 walk cells, 1,536 sprint cells, all 384 complete eight-phase move/aim pairs, 33,120 bone-length checks, and 6,144 planted-foot/non-crossing checks. It pins the original fixed-bone guide, motion exporter, exported rig data, and pixel rasterizer by SHA-256. All phases within each pair have different pixels, and every sprint frame differs from its corresponding walk frame. Every frame has a support foot, no toe penetrates the construction ground, and named bones retain their exact original lengths.

Measured locomotion included joint angles:

- Ankle: 55.000–115.062 degrees (within floating-point tolerance).
- Knee: 88.194–171.498 degrees.
- Waist yaw twist: zero degrees.

The first bake exposed overcompressed ankles; the final source raises the pelvis, shortens the step, and bounds airborne ankle flexion. Swing lift follows a squared-sine envelope with zero lift velocity at the plant transitions. Ankle pitch is continuous at those transitions, not a binary swing/plant switch. These are construction constraints, not biomechanical or medical certification.

Native Small, then Middle and Large 64-pair boards were visually inspected. `*-64-pairs-1x.png` and `*-64-pairs-4x.png` show phase 1 so travel displacement is visible. `motion-examples-4x.gif` shows forward, strafe, and backpedal cycles for all three bodies with the same eastward aim; `small-eight-phase-cycles-2x.png` exposes every phase as a static strip.

The added `*-sprint-64-pairs-*.png` boards cover the stronger gait. `small-walk-sprint-eight-phases-2x.png` exposes every walk/sprint phase side-by-side, and `walk-run-comparison-4x.gif` shows the distinct geometry at a slowed 3:5 cadence ratio. Runtime distance-driven walking is capped at three cycles/second and sprinting at five, preserving phase across transitions and stopping phase advancement when blocked or stationary.

## Authorized speed contrast

Only the authoritative sprint multiplier changes: 1.28 to 1.60. Base walking remains 372,600 fixed-point units/second; nominal sprint changes from 476,928 to 596,160. Acceleration, braking, stamina costs, slide/roll/wallrun authored values, body radii, and the existing 900,000 authored ceiling remain unchanged. Momentum-carrying moves can inherit the faster sprint entry, as their existing bounded retention rules intend; this is not a blanket speed boost to those actions. Movement compatibility ID is `movement-tuning-v14-walk-sprint-contrast`, which changes the movement handshake hash and requires matching builds.

## Rebuild

From the repository root, set `$Godot` to the installed Godot executable:

```powershell
& $Godot --headless --path . --script res://art_batches/character_style_v1/wireframe_motion_v2/export_rig.gd
python art_batches/character_style_v1/wireframe_motion_v2/build.py
python art_batches/character_style_v1/wireframe_motion_v2/preview_cycles.py
```

The first command exports only this batch's editable rig data. The second regenerates this batch's nine runtime PNGs, manifest, and evidence. The third refreshes animation evidence from the existing final PNGs without modifying runtime assets. Godot checked-export output is preserved in `export.log`.

## Honest limits

These are bounded eight-phase pixel cycles, not motion capture, continuous skeletal rendering, or a claim of complete realism. Walk and sprint have distinct stride geometry and cadence but no separate aerial running-flight phase. Pure side movement uses a short, non-crossing shuffle. Ground-foot registration follows the established atlas convention; it is not world-space foot locking. There is no per-character anatomy or identity in these neutral bases. Runtime tests, live rendering checks, and user acceptance must be reported separately from these passed source/asset checks.

Scoped batch runtime receipt: checked import plus nine focused suites passed with **120,857 assertions and zero failures**. This includes movement response, revision, overhaul, core movement, actor motion history, minimal motion, wireframe presentation, champion presentation, and session transport. `sprint-runtime-verification.json` records that run's exact movement/manifest hashes, preserved six-page identity check, texture memory, counts, and raw log locations. The [latest integration checkpoint](../../../docs/MOTION-AWARENESS-CHECKPOINT.md) supersedes this receipt for combined reruns, Full, captures and export status; live/human acceptance remains a separate gate.

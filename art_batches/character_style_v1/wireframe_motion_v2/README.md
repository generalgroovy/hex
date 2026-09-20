# Warm adventurer foundation — compact proportions v4

The current producer is `motion_revision: proportion_v4`: a sturdy, readable-face shared body with a shorter neck and modest Small/Middle/Large differences. This is still a shared body foundation, not distinct named-character or race anatomy. The reference-driven change affects only source art, baked pixels, validation metadata and visual-effect alignment; it does not change movement, reach, casting timings, hurtboxes or outcomes.

## Current proportion contract

- Historical authoring envelopes remain Small 58, Middle 68 and Large 76. Actual south-standing opaque heights are **58 / 63 / 68 pixels**, baked respectively at `1.0`, `63/68` and `68/76` about the unchanged `(48,84)` feet pivot. Every pose for a size uses that same scale; no pose-dependent stretch or runtime rescale is introduced.
- The guide and locomotion exporter now share `HEAD_RADIUS = 0.13`, `HEAD_OFFSET = 0.145` and `NECK_OFFSET = 0.04`. The neutral projection span derives from the existing limb/torso lengths plus those explicit head constants. The larger head is approximately four to four-and-a-half visible heads tall after native-pixel rounding; `proportion-v4-verification.json` records measured heights rather than a metadata-only claim.
- Chest/waist/hip clothing rings have half-widths `0.200 / 0.150 / 0.140` and half-depths `0.150 / 0.115 / 0.110`. Broader sleeves, trousers, boots, gloves and shoulder pads give the unchanged limb chains visible volume. The neck is thicker as well as shorter. These volumes are rasterized directly at the target size.
- All original thigh, shin, foot, humerus, forearm and torso lengths are unchanged. Limb and torso 3D landmarks remain exact against the saved `counter_swing_v3` checkpoint. Head/neck/nose positions and projected coordinates intentionally change; old tests requiring unchanged W2 head geometry do not apply.
- Atlas dimensions, row/index layout, binary alpha, final opaque row 83, eight facing directions, 64 travel/aim pairs, eight phases, separate walk/sprint banks and all 3,312 cells remain unchanged. Nine shared pages still decode to 122,093,568 bytes (116.44 MiB); character count adds no texture pages.
- Manifest schema 2 uses `presentation_scale_policy: per_size_baked_about_feet_pivot` and a numeric `sizes.<body>.presentation_scale`. The loader rejects the old global scale, invalid size scales, outdated revisions or mismatched PNG/decoded-pixel hashes. Movement afterimages and protection contours now use each frame's visible `display_height`, while legacy art mode retains its recipe height.

## Current rebuild and evidence

The integration owner serializes Godot export/import and runtime checks. From the repository root:

```powershell
& $Godot --headless --path . --script res://art_batches/character_style_v1/wireframe_motion_v2/export_rig.gd
python art_batches/character_style_v1/wireframe_motion_v2/build.py
python art_batches/character_style_v1/wireframe_motion_v2/review_proportions.py
```

`build.py` checks 3,312 cells and 33,120 limb lengths, every gait phase, planted/noncrossing feet, angles, binary alpha, cell bounds and exact south-standing heights before writing the production manifest. `review_proportions.py` checks all saved gait/limb landmarks, constant head/neck/torso attachments, the unchanged nine-page allocation, all final pixels against deterministic re-rasterization, and measured visible head counts. It writes only `proportion-v4-verification.json` and new `proportion-v4-*` review boards; W2 receipts stay historical.

Review `proportion-v4-{small,middle,large}-{native,4x}-{light,dark}.png` for all eight facings across stand, walk, sprint and stationary cast. `proportion-v4-before-after-{native,4x}.png` compares old/new front, three-quarter and profile bodies. The standard `adventurer-overview-*`, full 64-pair walk/sprint boards and motion example also regenerate with current pixels. Source/PNG results do not constitute checked runtime import, live gameplay capture, performance validation or user acceptance; those are separate gates.

Rollback inputs are retained under `previous-export-counter-swing-v3/`: old guide/exporter/rasterizer, rig data, loader, manifest and all nine atlases. Restore the complete coherent checkpoint only through the integration owner, never mix an old loader/manifest with new PNGs.

The remaining sections are archived W2 producer notes. Their old scale, head-invariance statements, review commands and runtime counts describe the pre-v4 checkpoint only, not current v4 evidence.

# Historical W2 producer notes (pre-proportion-v4)

This batch supplies one shared warm fantasy adventurer foundation in three sizes, dressed from the existing fixed-bone rig across every live pose. It is not 27 unique named-character or race skins. The supplied reference is retained in `reference-warm-fantasy.png`: charcoal cloth, brown leather, antique-gold trim, boots, gloves, readable faces and rear hair are carried into the native pixel rasterizer; weapons, spells and auras are excluded.

Current W2 output remains nine textures and manifest schema 2, with `style_id: warm_adventurer_foundation_v1`, `motion_revision: counter_swing_v3`, and a uniformly baked `presentation_scale: 0.92`. W2 brightens broad material planes, gives the collar/neck/face more separation, expands the clothing torso volume, and replaces perpetual ready-hands with real walking/sprinting arm counter-swing. The offline art has no authority over statistics, collision, hurtboxes, races, chemistry, or network outcomes. The earlier, separately authorized sprint-speed change below is unchanged by this style pass. Source/asset checks passed; current runtime verification and human acceptance must be reported separately from the earlier [motion and awareness checkpoint](../../../docs/MOTION-AWARENESS-CHECKPOINT.md).

## Delivered geometry

- Source-body calibration remains Small 58 px, Middle 68 px, Large 76 px. Every projected joint, mesh and clothing volume is baked at the same 0.92 scale about the existing (48,84) feet pivot. Integer-pixel south-grounded visible heights are now Small 53 px, Middle 63 px and Large 70 px; no second runtime shrink is applied.
- Each size has an eight-direction, ten-pose base page (768×960), a 512-cell walking page, and a distinct 512-cell sprint page (each 1536×3072): eight travel directions A × eight aim directions B × eight cyclic phases per gait.
- Every cell is 96×96 with pivot (48,84), binary alpha, and final opaque row 83. No weapons, wands, auras, ground marks, or environment.
- Chest clothing is a 24-vertex, three-ring 3D volume. The top ring now has normalized half-width 0.178 and half-depth 0.135, including at E/W profile; the actual pelvis/shoulder/head rig anchors and torso bone length are unchanged.
- Head/chest/pelvis face B together. Waist yaw twist is exactly zero. Feet stride along A, so opposing A/B becomes backpedaling and side A/B becomes a side shuffle rather than twisting the spine through 180 degrees.
- Lateral step length is reduced to avoid crossing left and right feet. The support foot stays flat, the opposite foot lifts, and contacts exchange after half a cycle. W2 leaves every leg/head/neck/shoulder landmark and projected anchor byte-exact against the previous volume checkpoint. Free hands now counter-swing against their same-side foot. Lateral arm displacement is bounded so strafing does not pull hands through the torso; head/chest still face B.
- Sprint increases normalized stride from 0.165 to 0.208 (26%), torso lean from 0.09 to 0.22, and swing lift from 0.085 to 0.105. W2 adds more bent elbows and a stronger opposed arm swing (0.115 versus walking 0.082). The existing leg cycle, head size, all bone lengths and all three body scales stay fixed.
- Clothing is baked around each actual rig pose: shaded jacket, short split leather coat following thigh chains, collar/pauldron trim, belt, brass right kneepad, cuffed boots and free-handed gloves. Front/three-quarter views have faces and lapels; rear views have no eyes or nose. The small asymmetrical kneepad preserves leg-contact readability without color-coding anatomy.
- One bounded garment-volume refinement broadens tapered sleeves/trousers, boot cuffs and toes, and rounded gloves. Filled light-facing material panels replace thin highlight-only limb strokes. Hair/cheeks widen laterally without moving the crown or chin. This changes clothing volume around the same joints, not bones or pose coordinates; all eight grounded crown and foot rows remain exact for every size.

## Reuse and atlas contract

The existing `../template_v2/pose_guide_model.gd` remains the fixed-bone/IK authority. `export_rig.gd` calls its `two_bone`, `landmarks`, and projection routines directly, adding the bounded cyclic locomotion and torso mesh. `rig-data.json` retains named 3D landmarks, projected joints, mesh faces, scale, travel, aim, and phase for all 3,312 cells. `build.py` draws integer pixels directly; there is no new live procedural body renderer.

Directions, in both axes: S, SE, E, NE, N, NW, W, SW. Locomotion index:

```text
index = ((travel * 8 + aim) * 8 + phase)
column = index % 16
row = floor(index / 16)
```

Base rows: grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b.

Runtime outputs are in `assets/sprites/wireframe_motion_v2/`: `manifest.json`, `{small,middle,large}-base.png`, `{small,middle,large}-locomotion.png`, and `{small,middle,large}-sprint.png`. Manifest schema 2 requires all three banks and includes source-PNG and raw-RGBA SHA-256 checksums, source `reference_height`, measured `display_height`, the approved baked scale, dimensions, registration, and exact indexing. Nine shared pages still decode to 116.44 MiB total (54 MiB walk + 54 MiB sprint + 8.44 MiB base), regardless of character count.

`previous-export-wireframe-v2/` preserves all nine previous wireframe PNGs, manifest, fixed-rig data, original exporter/baker and earlier evidence. Every saved PNG was checked against its old SHA-256. The first clothing/scale pass reused that exact motion source; W2 subsequently changes only arm IK targets and clothing mesh volume, not simulation, bone lengths, or leg/head/neck/shoulder pose anchors.

`previous-export-adventurer-v1/` separately preserves the first dressed bake's nine PNGs, manifest, rasterizer and evidence before the garment-volume refinement. `verify_volume.py` and its receipt are historical evidence for that pre-W2 comparison; their same-rig precondition intentionally no longer describes the W2 arm changes. `adventurer-volume-comparison-{1,4}x.png` is the historical before/after front and side comparison.

`previous-export-adventurer-volume-v2/` preserves the complete pre-W2 nine-page checkpoint, exporter, rig data, rasterizer and receipts. Current W2 invariance is checked against it by `review_w2.py --proof` and recorded in `w2-verification.json`: all 3,312 keys, all fixed bone lengths, every leg/head/neck/shoulder 3D and projected anchor, all 24 grounded crown/foot rows, and nine-page indexing remain exact. All 768 paired arm/foot phase checks prove opposite swing. No per-identity texture pages were added.

The earlier six-texture, 1,776-cell, 62.44-MiB [skeleton checkpoint](../../../docs/SKELETON-MOTION-CHECKPOINT.md) is historical. It shared one gait geometry between walking and sprinting. The present system has 3,312 cells and separate fixed-bone banks; prior checkpoint acceptance or test receipts must not be treated as verification of this larger integration.

## Verification and visual review

`evidence.json` records 240 base cells, 1,536 walk cells, 1,536 sprint cells, all 384 complete eight-phase move/aim pairs, 33,120 bone-length checks, and 6,144 planted-foot/non-crossing checks. It pins the original fixed-bone guide, motion exporter, exported rig data, and pixel rasterizer by SHA-256. All phases within each pair have different pixels, and every sprint frame differs from its corresponding walk frame. Every frame has a support foot, no toe penetrates the construction ground, and named bones retain their exact original lengths.

Measured locomotion included joint angles:

- Ankle: 55.000–115.062 degrees (within floating-point tolerance).
- Knee: 88.194–171.498 degrees.
- Waist yaw twist: zero degrees.

The first bake exposed overcompressed ankles; the final source raises the pelvis, shortens the step, and bounds airborne ankle flexion. Swing lift follows a squared-sine envelope with zero lift velocity at the plant transitions. Ankle pitch is continuous at those transitions, not a binary swing/plant switch. These are construction constraints, not biomechanical or medical certification.

Native Small, then Middle and Large 64-pair boards were visually inspected. `*-64-pairs-1x.png` and `*-64-pairs-4x.png` show phase 1 so travel displacement is visible. `motion-examples-4x.gif` shows forward, strafe, and backpedal cycles for all three bodies with the same eastward aim; `small-eight-phase-cycles-2x.png` exposes every phase as a static strip.

Current styled overview: `adventurer-overview-{1,4}x-{dark,light}.png` compares all three visible sizes and all eight facings. The native light and enlarged dark boards, plus the walk/sprint phase strip, were inspected after dressing. These show a reusable foundation with the reference's warm material palette, not a claim that its detailed chibi proportions, all individual races, or illustrated source quality have already been reproduced.

The added `*-sprint-64-pairs-*.png` boards cover the stronger gait. `small-walk-sprint-eight-phases-2x.png` exposes every walk/sprint phase side-by-side, and `walk-run-comparison-4x.gif` shows the distinct geometry at a slowed 3:5 cadence ratio. Runtime distance-driven walking is capped at three cycles/second and sprinting at five, preserving phase across transitions and stopping phase advancement when blocked or stationary.

W2 was reviewed Small, then Middle, then Large using `w2-{body}-native-{light,dark}.png` and their 4x companions. These include stand, east-travel walk/sprint across all eight aims, and stationary cast. `w2-normal-speed-native.gif` is a precisely 1,000-ms offline loop sampled from the final runtime PNGs: three walking and five sprint cycles, with forward/strafe/backpedal cases for every size. It is normal cap-cadence evidence, not a game capture or proof of movement feel under live input.

## Authorized speed contrast

Only the authoritative sprint multiplier changes: 1.28 to 1.60. Base walking remains 372,600 fixed-point units/second; nominal sprint changes from 476,928 to 596,160. Acceleration, braking, stamina costs, slide/roll/wallrun authored values, body radii, and the existing 900,000 authored ceiling remain unchanged. Momentum-carrying moves can inherit the faster sprint entry, as their existing bounded retention rules intend; this is not a blanket speed boost to those actions. Movement compatibility ID is `movement-tuning-v14-walk-sprint-contrast`, which changes the movement handshake hash and requires matching builds.

## Historical W2 rebuild (do not run against current v4)

From the repository root, set `$Godot` to the installed Godot executable:

```powershell
& $Godot --headless --path . --script res://art_batches/character_style_v1/wireframe_motion_v2/export_rig.gd
python art_batches/character_style_v1/wireframe_motion_v2/build.py
python art_batches/character_style_v1/wireframe_motion_v2/preview_cycles.py
python art_batches/character_style_v1/wireframe_motion_v2/review_w2.py --body small
python art_batches/character_style_v1/wireframe_motion_v2/review_w2.py --body middle
python art_batches/character_style_v1/wireframe_motion_v2/review_w2.py --body large
python art_batches/character_style_v1/wireframe_motion_v2/review_w2.py --proof
```

The first command exports only this batch's editable rig data. The second regenerates this batch's nine runtime PNGs, manifest, and evidence. The third refreshes animation evidence from the existing final PNGs without modifying runtime assets. Godot checked-export output is preserved in `export.log`.

## Honest limits

These are bounded eight-phase pixel cycles, not motion capture, continuous skeletal rendering, or a claim of complete realism. Walk and sprint have distinct stride geometry and cadence but no separate aerial running-flight phase. Pure side movement uses a short, non-crossing shuffle. Ground-foot registration follows the established atlas convention; it is not world-space foot locking. There is no per-character anatomy or identity in these neutral bases. Runtime tests, live rendering checks, and user acceptance must be reported separately from these passed source/asset checks.

Moving-cast limitation: the current body-frame caller supplies aim/travel/phase but no casting-state input, so W2 locomotion uses counter-swing even during moving casts. A future narrow caller hook plus bounded upper-body pose support is needed for genuine casting anticipation/recovery without freezing legs. A hand effect alone must not be described as changed casting anatomy. Stationary cast remains the distinct eight-facing existing base pose; this pass does not change bootstrap or simulation to invent a new cast state.

Historical wireframe runtime receipt: checked import plus nine focused suites passed with **120,857 assertions and zero failures** before this clothing/shrink pass. `sprint-runtime-verification.json` and its saved copy record that prior run, not approval of the new styled pixels.

First dressed bake receipt is `adventurer-runtime-verification.json`, with preserved import and focused logs. Checked import passed. The styled body presenter passed **30,522 assertions**; gallery integration (236), minimal motion (17,736), and actor history (944) also had zero failures. The combined six-suite run **failed nine assertions**: four in the pixel-movement registry dependency and five in production POV fixture setup, followed by an invalid `offset` access and exit leaks. The magic metadata was under integration at that point; no unrelated source was changed to bypass these checks.

The garment-volume refinement was newer than that first runtime receipt. Its `adventurer-volume-verification.json` is now historical too. Current W2 evidence is `w2-verification.json` plus `w2-runtime-verification.json`: checked export/import and six focused suites passed with **96,066 assertions and zero failures** (body presenter 33,598; cartoon presenter 42,670; minimal motion 17,736; actor history 944; POV 882; gallery integration 236). Preserved W2 logs pin those results to the exact current manifest. Full, game captures and human acceptance remain separate integration gates; no old receipt is presented as approval of these refined pixels.

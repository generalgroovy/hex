# Full-body movement expansion: actual runtime versus required artwork

Inspected 2026-09-27 in the dirty `generalgroovy/hex` checkout at HEAD `1559a566e33255c59337c5963f1c3c685d757f1f`. This is a source audit and art contract, not a runtime test or an animation-completion receipt. No engine was run by this audit.

Machine-readable companion: [`motion_contract.json`](../../../art_batches/character_motion_v1/motion_contract.json).

## Important distinction

The selected shared-size presenter currently has **80 base poses + 512 walk + 512 sprint frames per size**. Those walk/sprint matrices cover 8 travel × 8 aim × 8 phase combinations. The new named full-body sources contain **30 characters × 8 standing views**, not that movement coverage. Historical 32-pixel skeleton animation manifests are not evidence that the new full bodies move.

Do not replace the game with idle images sliding over the floor or body-wide squash/rotation and report full animations. Preserve the current working motion presenter until a whole character clears the replacement gate.

## Coverage and timing

Frame counts below are **proposed production counts**, not existing named-character animation counts. Preview FPS is deliberately secondary: live phase follows accepted state timers, physical height or travelled distance at the existing 120 Hz simulation rate.

| Family | Required clips (frames) | Current collapse | Required visual / clock |
|---|---|---|---|
| Ground | Idle 4, walk 8, sprint 8 | Grounded; full shared-size walk/sprint matrices | Alternating planted feet, distinct run stride; distance phase, capped at 3 walk / 5 sprint cycles per second. |
| Low stance | Crouch 4, slide 6, wavedash 4 | Slide row | Bent knees and low torso; slide 150–480 ms, wavedash 240 ms; slide body follows travel, not mouse. |
| Takeoff | Jumpsquat 4, jump 4, slide-jump 4 | Grounded upper-section offset, then jump | Charge 0–300 ms then hold compression until release; physical-height lift belongs to runtime, not sprite sheet. |
| Air control | Double-jump 4, fall 4, fast-fall 4 | Jump row | Distinct fresh second launch, ascending/descending silhouette and tucked fast-fall; no animation arc restarts on air turn. |
| Flight | Fly 6 | Jump row | Finite sustained pose / wing cycle only for Sylph, Wyrmborn, Angel and Demon; Small 2400 / Middle 2100 / Large 1800 ms limits remain authoritative. |
| Evasion | Roll 8, air-dodge 4 | Roll or jump | Roll 240 ms, air-dodge 180 ms; separate 130/120 ms protection outline; committed movement direction, separate aiming hands. |
| Walls | Wallrun 8, walljump 4 | Sprint or jump | Wall-contact-side leg placement and tangent running; wallrun up to 420 ms; release-kick follows accepted outward movement. |
| Landing | Land 4 | General motion response | 110 ms compression/recovery, cancelled immediately by next accepted action; dust separate at ground anchor. |
| Magic | Cast 6, cast-recovery 3 | Cast when standing; movement silhouette wins otherwise | Hands-only additive action over walking, low and airborne bodies; per-spell startup/recovery clocks, no leg freeze. |
| Reactions | Hit 3, stunned 4, rooted 2, defeated 6 | Hit/semantic aliases | Accepted control/death state drives pose; stop/resume cleanly, reset on respawn; do not add gameplay hitstop. |
| Optional social | Interact 4, taunt 4 | No dedicated active selector | Separate event-driven presentation; not a blocker for movement acceptance. |

**Excluded from current action completeness:** punch/kick bindings are explicitly labelled unavailable; vault/superglide state IDs remain reserved but no action activates them. Do not create implementation claims or re-enable those mechanics because an old atlas contains the names.

## Direction and height contract

| Concern | Implementation rule |
|---|---|
| Eight views | S, SE, E, NE, N, NW, W, SW; diagonals need visible depth/limb overlap differences, not sideways duplicates. |
| Independent inputs | Ground locomotion needs all 64 travel/aim pairs; airborne and casting overlays must preserve that separation. |
| Slide | Use current meaningful velocity, then retained slide vector, then movement-facing fallback. Crouching is not a slide lane. |
| Other facing | Existing presenter follows live aim immediately; movement facing is fallback. Proposed directional roll/wall-body changes require explicit integration tests, not merely different image metadata. |
| Air placement | Apply `JumpPresentation.body_lift_pixels` once outside the sprite; leave shadow/landing ring on the floor. Do not put the entire jump trajectory inside each cell. |
| Intangibility | Height clearance and actual evasion protection are different simulation facts; distinct cues must reflect actual authoritative flags. |
| Registration | 96×96 cell / feet pivot 48,84; one anatomy calibration per character reused for every action and direction. |
| Proportions | Preserve the 58/63/68 display-height baseline unless deliberately accepted; unify core mass, limb lengths and head ratios, not total wing/horn/tail bounding boxes. |

## Surgical implementation order

1. Calibrate core body landmarks on all 30 idle turnarounds; review Small/Middle/Large beside each other with wings, tails and horns excluded from core measurements.
2. Use one representative from each size for real segmented limb/body animation, with clean arm/leg occlusion; preserve character-specific full-body attire, not a generated head pasted onto an unrelated body.
3. Prove walk/run contacts and all 64 aim/travel pairs before scaling the pipeline. One or two source poses bobbed or stretched are explicitly insufficient.
4. Add low stance, release jump, double-jump/flight, dodge, wall and landing families using the source-backed clocks above; keep spell hand layers independent.
5. Expand all 30 identities only after those representative motions pass. Share skeleton timing and semantic anchors, not identical silhouettes; appendages require their own secondary-motion policy.
6. Review native-size and 4× integer previews on dark and light backgrounds; then run real-game movement/cast captures in all eight directions and only then replace the live presenter per complete character.

## Concrete oversights to avoid

- Current `silhouette_state` collapses float, air-dodge, rise and fall into `jump`; adding PNG rows alone cannot expose the new animations.
- Current crouch and jumpsquat are not dedicated authored clips. New body atlas integration needs a selector capable of distinguishing them before the generic grounded/airborne fallback.
- Aiming while moving is already a 64-direction-pair contract. An eight-direction walk strip alone would regress current behaviour.
- Current gallery can demonstrate an isolated loop, not accepted cast timing, remote replication, collision shape or gameplay feel.
- Wallrun currently uses sprint. A convincing replacement needs the **contact side** as well as travel direction; otherwise the planted foot can face away from the wall.
- Casting cannot replace the entire locomotion/air/slide pose. Rendering the hands as an overlay or a layered rig avoids multiplying every character sheet by every spell and movement combination.
- Current `flight_capable` ancestry check uses **wyrmborn/demon**, not historical naming such as dragonborn/devil. Roster metadata, not art wings, grants flight.
- Preserve the original art and measured recipes. Candidate outputs must declare incomplete action coverage explicitly and must not promote themselves to the live checkpoint.

Source evidence: `WireframeBodyPresenter.frame`, `CartoonChampionPresenter.silhouette_state/semantic_action/presentation_facing_vector`, `ActorMotionHistory.capture_gaits`, `JumpPresentation.sample/height_contract`, `MovementSystem._try_air_float/_try_double_jump/_try_wall_skim`, `MovementTuning`, `ChampionCatalog` and `ControlBindingEditor`.

## Offline pose sampler delivered

`art_batches/character_motion_v1/poses.py` supplies `pose(body, action, aim, travel, phase)` and `rest(body, aim)`. It reads the existing 3312-pose source without mutating it, applies the existing volume adapter, and emits final 96×96 display-space points, fixed-length anatomical landmarks, sorted limb depths, contacts and explicit pending-review metadata. No raster image is synthesized by this module.

Walk/sprint use the source travel×aim matrix; intermediate targets are solved using fixed-length two-link IK. Other clips use the source grounded/jump/slide/roll/cast/hit targets with rigid-joint rotations and fixed-length interpolation. The world jump trajectory is not baked into any pose. Wallrun deliberately declares `wall_contact_side_required`: it is a tangent running candidate until contact-side skinning is supplied, not a certified wall-contact animation.

Fresh offline verification: `python -m unittest discover -s tests/art -p test_character_motion_poses.py -v` — **9 tests passed**, covering all 26 action identifiers / all three sizes / all eight facing indices, sampled limb and torso lengths, independent walk/sprint travel and aim, seam closure, alternating feet, owned result dictionaries and rejected invalid input. `git diff --check` on owned files passed. These checks do not certify skinning quality, character anatomy fit, exact directional appearance or runtime integration.

# Restrained retro body response

Status: shared-rig response integrated and lead-validated in `p56-168a6c987ad5`;
[checkpoint evidence](../HEX-RETRO-REFINEMENT.md) includes three-size native
keyframes. Human motion-feel acceptance remains pending. Original handoff follows.

The existing detailed cast uses fixed18px skull calibration and58/63/68px baked body anatomy, alternating-leg IK, independent casting arms,24phase source poses and continuous render interpolation. This slice adds small **upper-body** squash/stretch and delayed upper-body mass response without changing those foundations or rescaling complete sprites.

| Action | Added response |
|---|---|
| Jump anticipation | Smoothly gathers the chest by up to1.65world pixels as charge is held. |
| Takeoff / double jump / walljump / slide jump | Extends chest by up to1.1pixels, fading before apex; adds subtle counter-travel upper-body displacement. |
| Stationary landing | Maximum2.2pixel chest compression at contact, settling during the existing110ms landing phase. |
| Walk / sprint | Existing distance-based alternating gait, continuous casts and70ms ordinary pose settling retained; no extra lag or scale pulsing. |
| Slide / roll / dodge / control states | No new smoothing or secondary deformation; exposure, protection and directional response remain immediate. |
| Reduced motion | Added secondary body response disabled; base pose and all gameplay indicators remain. |

## Anatomy and efficiency

Pelvis, hips, knees, ankles and toes remain exactly where the existing rig places them. The chest alone can compress to90% or extend to105.5% of its bone length, with restrained reciprocal width; skull and arm bones never scale. The head translates rigidly with the neck. Arm chains translate with their shoulder, retaining length and subsequent independent casting blend. Counter-travel offset is at most0.4pixel and never changes ground registration, aim or authoritative height. This is an art response, not additional jump motion.

Responses use existing bounded source/render mesh caches. No new actor nodes, particles, image files, trails, GPU readback or per-frame mesh allocation is introduced. Reduced-motion source poses have distinct cache keys; total cache limits remain384source and256render entries. No performance improvement is claimed until measured.

## Authored keyframe boundary

Wa Bidi, Jan Wicked and Fluup have reviewed painted low/air key poses. Those poses remain intact and retain their existing drawn squash rather than blindly warping a painted head using standing-pose weights. Their shared-rig actions still use existing animation.27other characters use the new shared-rig response in supported actions. Moving landings currently continue locomotion and its existing contact effects; this slice intentionally does not interrupt them with a stationary landing clip.

## One-line integration owned by lead

In `CartoonChampionPresenter.movement_frame`, forward the existing accessibility argument: `fullbody_art.frame(champion_id, state, presentation_tick, config, locomotion_phase, reduced_effects)`. The sixth parameter is optional for existing direct/diagnostic callers. Shared presenter code was deliberately not edited by this delegate.

## Validation status

Added tests cover three sizes×eight headings, all supported response actions, exact lower-body registration, skull and arm lengths, finite/bounded vertex output, nonzero response, reduced-motion metadata, unchanged gameplay state and preservation of the three authored key sheets. Existing gait, interpolation, cast and protection tests were not weakened. No Godot engine was run by this delegate. Lead must run the fullbody suite and native takeoff/landing captures, particularly side/back head seams, before claiming visual acceptance.

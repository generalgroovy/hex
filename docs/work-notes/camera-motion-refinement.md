# Gentle camera and distinct action posture

Status: integrated and lead-validated in `p56-ae1c09164b5b`; Full/native/export checks passed, dense timing failed, and human feel remains open. See [current checkpoint](../HEX-BUILDING-DIRECTORIES.md). Previous playable fallback remains `p56-168a6c987ad5`. Original delegate handoff notes below do not replace final evidence.

This supersedes the tuning values in the historical camera-direction and retro-motion handoffs, not their ownership or acceptance boundaries. No simulation, collision, stamina, input, authoritative timing, image assets or package pointer was changed.

## Camera

| Setting | Previous | Refinement |
|---|---:|---:|
| Gameplay zoom | 75% | 75%, unchanged |
| Look anticipation cap | 72 world px | 36 world px |
| Speed anticipation | 160 ms, cap 72 px | 60 ms, cap 24 px |
| Combined framing cap | 112 world px | 48 world px / 36 screen px |
| Offset half-life | 120 ms | 220 ms |
| Pointer framing rest zone | 24 screen px | 36 screen px, smoothstep shoulder |

Only the framing offset is filtered. Interpolated feet following and actual cursor aim remain immediate. The existing fixed screen anchor prevents a camera/aim feedback loop. Exponential settling remains render-rate independent and cannot overshoot for held intent. Modal/focus freeze, resume/teleport rebasing, bounds, spectator snaps and reduced-motion feet following are unchanged.

The new camera tests retain all old coverage and add: screen-space amplitude bound, monotonic pointer gain, sub-0.0001 gain just outside the dead zone, maximum reversal below 1.9 screen px per 120 Hz frame, monotonic return without wobble, and return within 1.6 screen px after one second. These last two figures are analytic expectations for the tested maximum-offset release, not measured gameplay performance.

## Character readability

| Action | Refinement |
|---|---|
| Jumpsquat | Chest gather rises to 2.55 world px, previously 1.65; no extra squat time or delayed exposure. |
| Jump / double jump / walljump / slide jump | Chest extension up to 1.4 world px, previously 1.1; short takeoff hold, gone before apex. |
| Stationary landing | Chest compression up to 3 world px, previously 2.2; hold first 12% of existing pose, settle by 88%. |
| Walk | Up to 1.8 degrees projected travel lean. |
| Sprint | Up to 4.5 degrees projected travel lean, clearly distinct from walk. |
| Wallrun | Up to 5.5 degrees projected travel lean; existing airborne gait clock retained. |
| Accessibility | Reduced motion suppresses new lean and secondary compression; authored base poses remain. |

Lean rotates the upper-body chain about its existing pelvis. Feet, knees, hips and ground registration remain exactly unchanged; torso and arm bone lengths are preserved by this new rotation. Head orientation and size remain rigid. Existing body-only chest compression still has its separate bounded volume response; no complete sprite or head scaling is introduced. Lean is strongest at each of the two foot contacts and relaxes slightly between them; braking reduces it continuously. Front/back movement deliberately has no invented sideways tilt, and retains its authored alternating-foot gait.

Casting still blends its arm rotations after posture, independently of leg phase. Slide, roll, dodge, control and defeat poses receive no new locomotion lean or smoothing. Three reviewed painted low/air sheets (Wa Bidi, Jan Wicked, Fluup) remain untouched; their shared-rig locomotion still benefits. Moving landings keep locomotion instead of interrupting it with a stationary clip.

## Efficiency and acceptance

No nodes, textures, particles, trails, motion-history buffers, GPU readback or new cache dimensions were added. Existing source/render cache limits and sampled/continuous pose paths remain. This is a bounded constant-size presentation change, not a measured speed-up claim.

Added fullbody tests cover contact/takeoff envelopes, ordered walk/sprint/wallrun lean, stride periodicity and bilateral symmetry, no lean on other actions, all three sizes and eight headings, exact lower-body registration, rigid head orientation, torso/arm lengths, finite mesh output, reduced motion, unchanged authority and special-sheet preservation. Existing tests were not weakened.

Lead validation: run the camera and fullbody suites followed by normal regression validation; capture three-size side/diagonal sprint and wallrun, full-charge squat, early takeoff and landing, plus reduced-motion counterparts. Check arm/cape seams at the stronger contact poses. Playtest fast reversals, pointer resting near the player, stationary aiming, zoom/bounds and modal resume. Still captures cannot establish movement feel or live frame-time acceptance. No shared integration call-site changes are required.

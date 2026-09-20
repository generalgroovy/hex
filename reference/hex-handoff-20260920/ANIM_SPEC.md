# HEX / FLUX — ANIM contribution

**Package:** HEX-ANIM-PROPOSAL-2026-09-20-v1  
**Status:** Source-unbound proposal. No production patch, body sprites, animated demonstration or game acceptance.

## 1. Source and evidence boundary

Received exactly one file: **Pasted text.txt**, the multi-assignment brief selecting **ANIM**. Its relevant supplied ranges are lines 95–110 (assignment), 21–31 (established boundaries), and 164–173 (handoff). Its SHA-256 is recorded in `SOURCE_BASIS.json`; this identifies the brief, **not a repository revision**.

No design contract, active implementation queue, checkpoint/build identifier, current Godot version, source code, shared-template assets, captures or animation clips were provided. There are therefore **no observed implementation facts** about the current animation system. This package does not rely on historical FLUX revisions or unseen paths.

**Documented requirements:** three shared sizes first; eight presentation facings; continuous movement/aim/projectile flight; preserved size-based hurtboxes and shared wall clearance; distinct idle/walk/run/slide/jump/float/air-dodge/landing; separate bodies, spells and environment. Godot remains authoritative, Windows the current release target and 120 Hz the simulation target. These are requirements from the brief, not independently verified build properties.

**Hypothesis:** an aim-facing pelvis/torso with explicitly authored strafe and reverse lower-body gaits will read more coherently than turning only the torso through extreme angles. No comparison has been performed.

**Specific inputs needed before a source patch:** supply the current design contract, active queue and checkpoint/build identifier; the three template sources/atlases with dimensions, pivots, hurtbox and clearance definitions; and the current body-presentation controller/state adapter, including direction convention and correction/teleport flags. Missing bindings are `null`, never guessed dimensions or implementation behavior.

## 2. One recommendation

Use **aim-facing pelvis and torso, with contact-aware lower-body locomotion selected by movement relative to aim**. In steady state the pelvis and torso share one of eight review facings. The legs have forward, diagonal, lateral and reverse gaits. A backwards-moving actor uses an authored backrun, not a forward run played backwards and not a forward-facing pelvis with a 180°-twisted chest.

This is an authoring and presentation contract, not a replacement movement controller. Use the current renderer's supported output; reusable source layers may be baked to combined sprites. Do not require an unverified Skeleton2D conversion. If the existing renderer cannot honor the contact tracks, that is a pilot blocker—not a reason to claim distance-clocked sprites have proven foot planting.

**Principal tradeoff:** the eight relative gait families still need their correct camera projections. Eight generic cycles are not enough for all 64 combinations. A fully unique 8-keyframe implementation would require 64 cycles × 8 keys × 2 ground gaits × 3 templates = **3,072 lower-body keys**, before legal reuse and excluding upper-body/special-state artwork. Do not commission the full set before the narrow pilot passes.

**Strongest counterargument:** movement-facing legs with a separately aimed upper body would be cheaper and preserve a conventional forward sprint. It fails the opposing-aim cases unless it adds a substantial whole-body/backrun fallback anyway. The recommended solution accepts more art and a brief visible turn so it does not disguise a 180° torso twist. Whether full-speed reverse running looks convincing within existing body reach remains unverified; do not solve a failure by secretly slowing the player.

## 3. Angles, intent and actual gameplay

Proposed **review-only** convention: **0° N/up, then clockwise**. `u(theta) = (sin(theta), -cos(theta))`. The engine adapter must be checked against the missing current convention; do not rename internal directions or wind identifiers.

Let `M` and `A` be presentation movement and aim indices 0…7. Select:

`relative_gait = (M - A) mod 8`

The corresponding codes are `F FR R BR B BL L FL`. Only clip choice is quantized. Authoritative movement, velocity, aiming, hitboxes, projectile origins and firing times remain untouched. Diagonal animation never rescales actual travel.

Use **realized** grounded displacement, not held movement input, for gait playback. Pressing into a blocking wall must not create forward stepping. Zero movement selects a supported idle/turn pose and retains a meaningful current facing. Actual aim remains immediate and continuous even while a cosmetic body turn settles.

A proposed 3° extra hysteresis beyond a 22.5° sector half-width switches a retained facing only after 25.5° deviation, then selects the nearest sector. This prevents boundary chatter; it does not quantize the authoritative aim. Current input dead zones, teleport and correction classifications must come from the source adapter, not guessed thresholds.

### Eight-direction coverage

| Index / angle | Facing | Required body view | Near-limb bias |
|---|---|---|---|
| 0 / 0° | N | Back; clear back-of-head/torso cue | Pose-dependent |
| 1 / 45° | NE | Back three-quarter; not an E frame rotated | Anatomical right |
| 2 / 90° | E | Right-facing profile; clear front/back silhouette | Anatomical right |
| 3 / 135° | SE | Front three-quarter | Anatomical right |
| 4 / 180° | S | Front; distinct from rear | Pose-dependent |
| 5 / 225° | SW | Front three-quarter | Anatomical left |
| 6 / 270° | W | Left-facing profile | Anatomical left |
| 7 / 315° | NW | Back three-quarter | Anatomical left |

This assumes the proposed screen projection only; individual frames record actual occlusion. Each facing is required for each shared template and all eight body states. N/S do not imply a universal left/right depth order. Never equate anatomical left with screen-left or use a mirrored frame without remapping limb IDs, contact tracks, sockets and occlusion.

## 4. Three templates: proportions and anchors

**S/M/L are temporary review aliases** for the smallest/middle/largest existing templates, not new character sizes. Bind them to actual source IDs before authoring. Never manufacture the other two templates by uniformly scaling one body.

For each template, record the existing native canvas, root baseline, head extent, torso length, shoulder/hip span and limb reach from its neutral reference. Preserve those template-specific values across poses; foreshortening and bending are intentional per-facing pose changes, not unexplained limb growth. No numeric proportions can be asserted without those references.

Required per-frame anchors are **ground_root, pelvis, torso_join, neck, hand_L, hand_R, foot_L, foot_R and cast_visual_socket**. Ground root/pivot is invariant within a template; bobbing, lean, compression and jump presentation are relative to it. Record local frame bounds and layer order as well as contact intervals/targets. Across frames, the torso seam must close and feet must keep anatomical identity.

Size-based hurtboxes and shared wall clearance remain the current authoritative definitions. Lean, slide compression and jump pose do not create a smaller collider. Visual extent must be reviewed against those definitions; any source conflict blocks the affected pose. Use the existing height/ground projection, not a new animation-side gravity model. The visual hand socket is **not** a new spell-spawn authority.

## 5. Pose and timing specification

All durations below are **untuned proposal defaults**, not reported build timings or gameplay windows. Reference ticks use the brief's 120 Hz target only for reproducible fixtures; they do not require rendering at 120 fps. Existing authoritative state changes always interrupt presentation immediately.

| State | Readable pose and motion | Proposed timing |
|---|---|---|
| Idle | Balanced support, relaxed knees, restrained upper-body breath; feet remain planted | 4 keys; 800 ms / 96 reference ticks |
| Walk | Alternating heel/forefoot placements, modest counter-swing, no flight pose | 8 keys; nominal 600 ms / 72 ticks per full stride; distance-clocked |
| Run | Clear loading, push-off, opposing limb swing and brief flight; lean follows travel without changing facing | 8 keys; nominal 400 ms / 48 ticks per full stride; distance-clocked |
| Slide | Low extended/compressed silhouette, tucked non-supporting limbs; intentional skid, not walk contact | 2 entry keys / 100 ms; 2 hold keys / 200 ms loop; 2 exit keys / 100 ms; actual state may cut any part short |
| Jump | Brief push-off, elongated rise, compact apex, prepared fall; distinguish rise from float | 2 takeoff keys / 66.7 ms; rise/apex/fall keys follow existing airborne phase, never force a flight duration |
| Float | Suspended torso, loosely bent legs, small controlled drift; no stride contacts | 4 keys / 400 ms loop only while the existing float state is active |
| Air-dodge | Compact protective/leading pose with strong travel-direction silhouette, then extension | 3 keys / 100 ms reference accent, subordinate to the existing action state |
| Landing | Prepared contact → compression → recovery; preserve support leg where possible | 3 keys / 133.3 ms reference recovery; a new state cancels recovery without input delay |

An upper-body-only cast accent may use two keys over 100 ms as an initial art fixture; repeated casts must not restart the gait. This is not a change to Bolt/Heavy/Rapid/Spray cadence or recovery. No effects, spell shapes or trails are baked into the body atlas.

### Alternating support and foot planting

Use one normalized left-to-left gait cycle: key 0 = **L contact**, key 4 = **R contact**. Walk support labels are `[LR,L,L,L,LR,R,R,R]`; run support labels are `[L,L,L,none,R,R,R,none]`. Keys 0/4 of walking include a brief double-support handoff. These are proposed pose/contact landmarks; detailed contact times and positions must be authored between keys.

Advance `phase = (phase + realized_ground_distance / calibrated_stride_distance) mod 1`. The calibrated full-stride distance is per template/state/relative gait and is currently unbound. Nominal periods only help calibrate a reference speed; they must not set player speed.

A planted foot has a world/render-ground target captured at contact. Its required local target is `foot_local(t) = planted_world - rendered_ground_root(t)` after converting through the existing visual transform. Proposed acceptance is **no more than 1 native texel of L-infinity drift from the original contact position over the entire stance**, not 1 texel of cumulative allowance per frame. Remove common camera motion when measuring. During double support both feet must meet the targets; revise pose reach/contact duration if they cannot.

**Distance-based playback alone does not prove foot locking.** Discrete frames still need compatible subframe contact tracks and renderable limb placements. The lower-body authoring must supply reachable support poses; do not drag a detached foot sprite, stretch pixel limbs arbitrarily or shift the gameplay root. A renderer unable to meet this gate remains unaccepted. At excessive actual speed, test cadence and reach honestly; never silently cap authoritative speed or lengthen collision shape.

Do not reverse forward-playback time for backrunning. Preserve phase/contact identity across casting and direction changes. Walk/run transfer preserves the actual support semantic; if the run is in flight, wait for the next valid contact instead of asserting a new planted foot at the same numeric phase. Slide/airborne state entry releases gait contacts. Teleports, spawn snaps and flagged corrections invalidate old contact targets and are not counted as walked distance.

### Hard aim turns

Steady-state pelvis and torso share aim facing. A proposed **45° maximum temporary torso/pelvis difference** is an artistic limit, not an anatomical measurement or known current rule.

For a 45° retarget, use a compatible support/passing pose while preserving the planted foot target. If the new orientation exceeds the authored leg reach, release into the turn rather than stretching the limb or snapping the contact.

For a 90°–180° retarget, use **loaded-foot pivot → support release → compact unweighted turn → new contact**, with four keys over a reference 100 ms / 12 ticks. Never keep a foot marked planted while moving it to the other side of the body. The unweighted pose is cosmetic: it adds no gameplay hop, airborne state or immunity. A fixed 180° cosmetic tie can turn clockwise without consuming simulation RNG.

The rendered body may lag a sudden retarget for this brief allowance; actual aim/projectiles do not. A stable final target should settle within the proposed 100 ms. Repeated target changes update the destination without endlessly restarting the timer. This limit does not promise exact facing under indefinitely moving aim input. If the turn cannot fit its reach/contact envelope, the pilot fails rather than stretching the body or delaying a shot.

## 6. Coverage and acceptance

`ACCEPTANCE_MATRIX_64.md` contains the complete 8×8 table; JSON contains one individually identified record for every cell. Each cell covers all three templates × walk/run, for **384 steady-state variants**. Both L-loaded and R-loaded retarget entries are additional transition coverage. Every static, animated-fixture and Godot/Windows field is **NOT_RUN**.

The common gates cover untouched authority, correct relative gait, torso limits, alternating world-space support, contact-preserving transitions, stable anchors/occlusion, separate cast presentation, and 30/60/120 Hz presentation reviews against the same existing target-rate simulation trace. No such trace was provided. Idle/air/slide/turn transitions require the pilots in addition to the matrix.

## 7. Small representative pilot selection

| Pilot | Coverage that exposes a difficult failure | Status |
|---|---|---|
| P0 | S/M/L neutral eight-facing turntable; root and landmark overlays; native-size readability and enlarged inspection | NOT_RUN; no static sprites supplied or created |
| P1 | Aim N; run N → E → S (forward → strafe → backrun), two cycles per segment, movement retarget on both support legs, cast accent without gait reset | NOT_RUN |
| P2 | Aim N; all eight travel directions, walk and run, both support entries; diagonal and reverse transitions | NOT_RUN |
| P3 | Travel E, aim E → W on either loaded foot; 21/24° boundary jitter then 26° crossing; 358/1° wrap; blocked travel and flagged teleport | NOT_RUN |
| P4 | Independent slide/jump-rise/apex/fall/float/dodge/landing pose samples; interrupt slide entry at reference tick 4 and landing at tick 6 | NOT_RUN; pose fixture only |

`PILOT_SELECTION.json` defines exact reference fixture sequences and sample IDs. P4 is deliberately **not** an asserted legal gameplay combo. The integrator must map only source-confirmed state transitions for the real replay.

## 8. Sprite sheets and reusable layers

Work on reusable body-template sources before character-specific art. Retain **pelvis_legs**, **torso_head**, **arms_rear** and **arms_front** groups, plus a foreground lower-body mask when a slide/jump knee must pass in front of the torso. Per-frame occlusion decides actual order. These are authoring groups, not an instruction to add a particular engine node hierarchy. Bake compatible groups if the current renderer requires that.

For walk/run, use separate sheets per **template × state × relative gait × layer**. A sheet has **8 columns of phase keys** and **8 rows of aim facings**. This layout accounts for the full 64 projections; it does not pretend the same screen-space strafe drawing works in every facing. Torso/arm layers may be reused across relative gaits only when their socket and occlusion tracks actually match.

Native cell dimensions and pivots must be inherited from each source template. A proposed 2-pixel transparent gutter lies *outside* each native cell. For gutter `g`, native width `Cw` and height `Ch`, the frame rect is `[col*(Cw+2g)+g, row*(Ch+2g)+g, Cw, Ch]`; pivot remains relative to the native frame. Do not trim frames independently. Special-state clips list explicit frame count and duration; unused padding is never an animation frame.

Export real transparent RGBA, no checkerboard background. Keep all corresponding layers on identical frame rectangles and timing. Use native-pixel review and the current pixel sampling pipeline; do not claim alpha, padding, filter behavior or scale quality until actual exports are checked. Separate spells/environmental effects and any shadow asset from the body atlas. Do not rotate a cardinal bitmap into an allegedly authored diagonal.

Per-frame metadata must record rect, duration/phase, anchors, anatomical support/contact tracks, layer order, bounds and optional **cosmetic** markers. These markers must not decide attacks, damage, immunity, landing authority or sound/gameplay events without existing ownership being verified. An automatically mirrored neutral body is acceptable only after limb IDs, sockets, contact phase, asymmetry and layer order are audited.

## 9. Actual validation and limitations

Run `python validate_bundle.py` from this folder to check the proposal package. The validator checks only data coherence: source identity metadata, 64 unique mappings, family counts, template/state expansion, explicit NOT_RUN fields, timing arithmetic, contact landmarks, null source bindings and valid pilot references. It does not load Godot, render a body, inspect an atlas or execute a game test. `VALIDATION_REPORT.md` records the actual local result.

**Static pose review: NOT_RUN. Animated quality/foot drift review: NOT_RUN. In-game Godot/Windows acceptance: NOT_RUN.** No PNG, GIF, video, scene or production patch has been produced. The authored visual work is a future source-bound integration slice, not a hidden completed deliverable.

## 10. Integration handoff

**Source basis:** one assignment brief, identified in `SOURCE_BASIS.json`; build/revision unknown.

**Recommended contribution:** aim-facing shared body templates plus contact-aware relative-direction gait specification, complete acceptance matrix and narrowly selected pilots.

**Artifacts:** this specification, proposed JSON contract, 64-cell Markdown/JSON matrices, JSON pilots, source-basis record, package validator and validation report.

**Proposed contract changes:** none to the established gameplay boundaries. The angle convention, timing defaults, contact tolerance, layers and cosmetic-turn limit are proposed presentation details requiring reconciliation with the missing current contract.

**Executed:** local package consistency validation only; exact result in the report. **NOT_RUN:** static/animated asset review, alpha/atlas review, renderer binding, gameplay trace comparison, Godot/Windows runtime and multiplayer visual review.

**Unresolved risks:** unknown template reach and renderer support, expensive projected gait coverage, reverse locomotion at current maximum speed, short-turn readability, no recorded legal state transitions, and no current source identifier.

**Smallest next slice:** first obtain the required source bindings; implement **P1 only for all three existing templates**, aim N and run travel N/E/S, with both anatomical support entries and a cosmetic cast accent. The nominal authoring budget is 72 lower-body pose keys before reuse, plus required torso/arm work. Do not begin character-specific expansion.

**Acceptance:** unchanged source dimensions/hurtboxes/shared clearance; continuous authoritative aim and movement; ≤1 native texel stance drift; preserved support semantics through retarget/cast; no seam/occlusion failure; separate static, animated and runtime evidence. Expand directions only after this slice passes. Do not commit/publish from this independent contribution.

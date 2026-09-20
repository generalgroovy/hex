# Shared template slide review checkpoint

Status: verified local-source candidate p50-9011a3cfa6dc, September 15, 2026;
paused for human slide review. The broader shared-template milestone remains open.

Protocol50/snapshot20; Godot Windows source. Run `scripts/run.cmd` for this
candidate. Existing EXEs contain earlier builds. No export, installer, commit,
publication or selected-checkpoint change was made in this slice.

## Current change and playtest

The shared South-facing slide looked nearly upright in actual paid gameplay.
Two bounded rig passes produced a seated, asymmetric pose with one long planted
leg and one tucked leg. Small was inspected first, then Middle/Large. The change
uses a rigid torso recline/roll and fixed-bone IK; no per-frame scaling or fitting.
Only24 slide cells changed. Wallrun currently shares that body and inherits it.

Standing display targets remain58/63/68px, Stamina620/660/700, hurt radii17/18/19px
and common18px clearance. All30 identities and affinities remain unchanged.
Source anatomy, neck/head dimensions and pivot(48,84) are retained. No named skins
were promoted; the isolated attachment/layer package is preparation only.

1. Run `scripts/run.cmd`; select S. Wayne in the Gallery.
2. Sprint across open ground, hold C to slide, and aim South, then SE/SW and North
   while keeping travel independent. Compare the lower body and feet at normal zoom.
3. Repeat with Oh Tipi and The Red Baron. Inspect start/hold/release into movement;
   the pose change does not add newly authored entry/braking/exit animation phases.
4. Compare the [actual before/after scenes and direction boards](evidence/template-motion-20260915/comparison.html).

## Fresh evidence and limits

Evidence root: `docs/evidence/template-motion-20260915/`.

- Baseline source identity Check verified p50-53a535028e4f on dirty main,977 entries;
  the prior Full-v3 receipt's three log hashes matched. Its109/707626 and32 frames
  remain historical proof of that earlier source.
- New capture:144 frames per baseline/pass1/pass2. Each set includes72 controlled
  presenter boards and72 actual paid-slide frames at75% camera zoom. All three
  sizes, all eight aim headings,11 held action selections and64 travel/aim pairs
  for walk and sprint over8 phases are represented. Controlled boards are not
  continuous gameplay or admission evidence for airborne/wall actions.
- Pass1 Focused passed2 suites/83,337 assertions,zero failures/stderr. It was
  rejected visually because South still looked upright. Pass2 is the retained
  art candidate. Fresh final `full-final-v3.json` passed 109 suites / 707,626
  assertions, zero failures / stderr, import and 120 Hz boot in 283,718 ms overall.
  The first two attempts timed out at the 180-second engine guard after 106/107
  completed suites, with no assertion failures or stderr. Both are failed gates
  retained with their logs. The final frozen source includes a reviewed, tested
  300-second Full-suite watchdog; all other engine calls retain 180 seconds.
  This is test supervision, not a change to the simulation performance budget.
  Release packaging was NOT RUN and still has its prior watchdog.
- Offline pass2 proof:3312 poses,3288 non-slide poses unchanged exactly;216 non-slide
  base cells and all six gait pages pixel-identical.24 slide cells changed;
  fixed bones,96 grounded ankle/toe endpoints, rigid dimensions, gaze yaw-plane
  and intended pitch checks pass. PNG containers were re-encoded; that is not
  a claim of byte-identical source image files. Nine banks/decoded allocation stay
  unchanged. Source/rig/bake proof and prior pass remain preserved.
- Independent Astra source/native review recommends retaining pass2 for human
  review. South slide heights43/46/50px versus53/58/63px before reflect the pose,
  not a change to standing display size. Human template approval is still pending.
- The final identity check and `final-summary.json` verify 3,164 frozen inputs,
  150 unchanged gameplay/content hashes, personal profile, selected pointer and
  all eight selected fallback members. All 144 before/after capture authority
  records match; all 48 rendered gait boards are byte-identical. The `referenced/`
  tree retains 575 evidence files, including all capture sets and receipt logs
  from failed attempts. Guard supervision passed
  13 ownership/cancellation checks plus the configurable-timeout fixture.

Remaining issues: North/NE have tight head/torso overlap at native scale. Slide
still follows aim using one base pose, without a separate travel/aim or entry/exit
phase bank. Wallrun inherits the deeper recline; physical wall-contact sequences
and their transitions were NOT RUN here. Jump,Float,air-dodge and walljump retain
shared jump-body selection; landing lacks a newly authored body transition;
moving casts retain gait legs without a new casting-arm layer. Held-state boards
are not approval of those animations. This completes the bounded slide-review
slice, not the entire shared-template milestone.

Performance/latency, physical multiplayer, eight-socket new-event validation,
audio listening, new portable/installer and human acceptance: NOT RUN. Historical
B2a host p95 10.592–11.085ms remains over the8.333ms budget. Presentation proof
does not clear that gate. After human template acceptance, follow the existing
queue's B2 contact and measured host/event-retention work before field expansion.

P48 and B2a packages remain operational fallbacks. The selected pointer still
names P48; its EXE is `exports/windows-overnight-p48-20260913/windows/flux2.exe`.
The baseline presentation ZIP and rig preserve the actual dirty source inputs;
do not partially restore old atlas files into new source as a rollback procedure.

## Files in this bounded slice

- Rig: `art_batches/character_style_v1/template_v2/pose_guide_model.gd`;
  exporter, baker and regenerated rig under
  `art_batches/character_style_v1/wireframe_motion_v2/`.
- Runtime: `src/presentation/wireframe_body_presenter.gd`,
  `assets/sprites/wireframe_motion_v2/` and generated runtime identity.
  Presenter test revision updated in `tests/unit/test_wireframe_body_presenter.gd`.
- Capture: `scripts/capture-template-motion.ps1` and
  `tests/visual/capture_template_motion.gd`.
- Supervision: `scripts/flux2-common.ps1` and `scripts/test.ps1`;
  the changed timeout is recorded in the final Full receipt.
- Isolated preparation/proof: `art_batches/character_style_v1/template_layers_v1/`
  and `art_batches/character_style_v1/wireframe_motion_v2/slide_v1/`.
  Attachment anchors/layer validation are preparation, not a live compositor or
  new named-character artwork.
- Contract and handoff: `SPECIFICATION.md`, `docs/CURRENT-CAST.md`, `README.md`,
  this checkpoint, `.agent/PROPORTION-CAST-CONTINUE.md` and the single queue
  `.agent/OVERHAUL-IMPLEMENTATION.md`.

## Historical compact-proportion and roster checkpoint

Historical state: PAUSED at a verified local-source checkpoint, September 14, 2026;
build `p50-53a535028e4f` (protocol 50 / snapshot 20). No new export, installer, publication or
checkpoint-pointer promotion. The prior B2a Windows candidate and selected P48
fallback remain intact. Human visual/size-balance acceptance remains open.

## Scope

| Change | Current source |
| --- | --- |
| Anatomy | Shorter neck, fuller face with anatomically placed features, stronger torso and limbs; approximately4.14/4.20/4.25 visible heads tall |
| Visible height | Small58 / Middle63 / Large68px; source calibration58/68/76 retained |
| Stamina maximum |620/660/700; existing recovery rates,Health,Flux,speed and movement timing unchanged |
| Hurt radius |17/18/19px by size only; common18px wall clearance |
| Roster |30 playable identities,10 per size; no unnamed Angel; Faab I Yaina stays |
| Names/affinities |H. Lenee (`h_le_ne`,28); Mifu (`fimu_yashiha`,29) Water/Air/Light and Squall starter; Sai Laas (`sai_laas`,30) Small Nymph Air2/Fire1 |
| Art |Updated label-free30-character group reference; shared body atlases rebuilt; individual named skins not claimed |

## Evidence

- Offline exporter/baker/proportion proof passed:3312 distinct reproducible cells,
  49680 unchanged limb/torso landmark checks and9936 head/neck attachment checks;
  all64 travel/aim combinations ×8 phases ×2 gaits ×3 sizes,
  binary transparency,pivots and containment. Dedicated receipt:
  `art_batches/character_style_v1/wireframe_motion_v2/proportion-v4-verification.json`.
- Nine texture pages remain122093568 decoded bytes. This is unchanged allocation,
  not a new performance result or proof of120 rendered frames per second.
- Fresh Full v3 passed109 suites /707626 assertions,zero failures/stderr;
  import and120 Hz boot passed. Earlier documentation and test-number-type
  failures are retained alongside the corrected passing run.
- Fresh hidden Compatibility-renderer capture passed32 frames:24 actual
  gameplay/Gallery/cast/cone frames and8 controlled production-presenter phases.
  No draw authority mutation,network,audio or persisted preference changes.
  Root inspected representative rendered frames; independent static source/art
  review found no actionable defects. Human animation/size-balance review is open.
- Read-only runtime identity Check passed after validation:2732 production
  records,`p50-53a535028e4f`. Durable receipts,logs and captures are in
  [the evidence index](evidence/proportions-v4-20260914/README.md).
- New performance,physical multiplayer,portable and installer checks:NOT RUN.
  B2a's historical host p95 of10.592–11.085ms still exceeds8.333ms; this Full
  result does not supersede that failure or prove120 rendered FPS.

## Test / rollback

Run `scripts/run.cmd` from the repository for the new source. In the Gallery,
compare S. Wayne,Oh Tipi and The Red Baron,then inspect H. Lenee,Mifu and Sai Laas.
Try all eight facings,strafe/backpedal while aiming,jump/Float,slide and sprint.
Look for stable scale,clear gaze,alternating feet and a modest resource difference.
Existing portable EXEs do **not** include this source-only update.
Both participants must use matching source/build identities for multiplayer;
sharing protocol50 alone does not make different content builds compatible.

Pre-change shared source/nine-page art is preserved under
`art_batches/character_style_v1/wireframe_motion_v2/previous-export-counter-swing-v3/`
and excluded from import. Original attached references and generation prompts are
in [cast_proportions_v5](../reference/art/cast_proportions_v5/README.md).
The unnamed Angel's archived source art is retained as history; current adapters
exclude only its retired ID. No saved-profile reset or destructive Git operation.
The art backup is not a complete rollback of roster,stats or affinities. The
untouched P48/B2a portable packages are the operational fallbacks; do not partially
restore atlas files into new source and describe that as reverting this slice.

Next acceptance: human template/proportion playtest before race-specific skins;
the single queue retains B2 contact and measured-performance dependencies.
No further implementation slice is active. The continuation brief is
[PROPORTION-CAST-CONTINUE.md](../.agent/PROPORTION-CAST-CONTINUE.md); it delegates
work against the existing queue, not a second competing backlog.

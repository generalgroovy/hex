# HANDOFF · FLUX-ANIMATION-v1

**Task:** 07-CHAT-ANIMATION.md. **Overall status:** PROPOSAL. **Human acceptance:** PENDING.

## Open first

Open `REVIEW.html` in a desktop browser. It is self-contained and needs no network, server, game installation or profile changes. Start with Small, pilot P01, 1×, arrows hidden; then pause and inspect at 3×/4×. The browser shows source-cell playback or a labeled storyboard—not the game. The five annotated PNG boards provide the same source/proposal distinction without JavaScript.

Read `ANIMATION_REVIEW.md` for source-backed findings, `POSE_TIMING_SPEC.json` for candidate values/units/interrupt rules, and `COVERAGE_MATRIX.md` for present versus missing coverage. `pilots/image-manifest.json` records every crop and annotation board. Source originals live under `originals/`.

## Ownership and unchanged boundaries

Only this standalone delivery folder was written. No live checkout was accessed; no game code, atlas in the user's repository, shared catalog, README, checkpoint, settings, profile, protocol, stats or physics was edited. No Godot process was run. No commit, branch change, push, installer, skin promotion or whole-roster generation was performed.

Source identity `p53-cb264f9358a4`, Git head and dirty count are copied from the input snapshot, not reverified on the user's machine. The current-checkpoint file still selects an older P48 portable; it is not evidence that the p53 animation candidate is packaged. Original packet and extracted originals were preserved. This package does not authorize replacing dirty work.

Frozen: 96×96 cells, feet (48,84); display heights 58/63/68; original per-size rig/baked scale; hurt radii 17/18/19; common wall clearance 18; stamina maxima 620/660/700; all other stats, paid budgets and timing. Maintain independent spell/equipment/shadow layers. The body pixels in our source crops are unchanged; no spell effects were generated into them.

## Proposed live targets — inspect before editing

`src/presentation/wireframe_body_presenter.gd`, `src/presentation/eight_direction_resolver.gd` and `assets/sprites/wireframe_motion_v2/manifest.json` are read integration constraints, **not supplied patches**. Direction order and phase indexing must stay intact. No resolver change is recommended for this slice.

The checkpoint names `art_batches/character_style_v1/template_v2/pose_guide_model.gd` and the corresponding `wireframe_motion_v2` exporter/baker; they are absent here. Obtain those exact current files, the actual `CartoonChampionPresenter`/gait-phase producer, cast-priority integration and aerial/landing sampler before authoring live poses. Do not reconstruct canonical bone lengths from the PNGs or assume guessed caller field names.

## Single-owner integration sequence

1. **Small contact pilot.** Record baseline source/configuration hashes and a continuous walk/backpedal/strafe trace. Change sole/passing-leg readability in the existing rig, not the clock or stats. Keep eight phases. Accept only with distinct support at native zoom and no new sampled contact/volume regressions. Revert the coherent owned rig/bake/manifest set on failure.
2. **Small diagonal slide.** Use NE travel/S aim, then reciprocal/opposed headings. A real travel-aware action selection is required; changing only the NE aim drawing cannot fix T3/A0. Preview entry/hold/brake/exit without changing their authoritative rules. Keep wallrun separate in the regression because it currently shares the slide silhouette.
3. **Small landing.** Author the dedicated two-foot compression pose. The proposed post-contact envelope is 14 ticks/116.7 ms, cosmetic and immediately interruptible, with 3 px maximum pelvis lowering for Small. No walk-frame shortcut or forced recovery. Test fast fall, Float exit, air dodge, wall exit, moving landing and immediate re-jump/cast.
4. **Moving cast; then size transfer.** Verify real cast state/ticks before binding the proposed hand stages. Preserve gait phase and committed shot direction while current body aim turns. Reject combinatorial full-body expansion unless measured and approved. After each Small rule is accepted, transfer it to Middle and Large using their original rigs, identical event semantics and one bake scale. Obtain shared-template human approval before individual skins.

The stages above are recommendations for the lead's existing queue, not permission to start four simultaneous code branches or Godot jobs.

## Evidence and exact limits

`evidence/input-integrity.json` checks 63 input records. `evidence/static-source-audit.json` checks nine source PNG/RGBA hashes, all 3,312 nonempty cells, binary alpha and clear cell edges; all 64 pairs have eight distinct phases per bank/size. The body bounds verify standing 58/63/68, not fixed bones or runtime contacts. `evidence/verification.json` and `evidence/browser-test.json` record only checks actually executed for this delivery. Run `python tools/verify_package.py` from this folder for a repeatable integrity/structure check (Python and Pillow required).

The offline viewer passed **69/69 Chromium checks** with the exact self-contained HTML loaded through `set_content`, including image decoding, source-pixel selection and zero external HTTP requests. Direct `file://` navigation was **blocked by this sandbox browser’s administrative policy**, so ordinary local-file launch was not verified here. The failed attempt remains in `evidence/browser-file-navigation-attempt.json`; no security settings were changed. This is a viewer-environment limitation, not a passed game test.

**NOT_RUN:** Godot import/boot, actual source animation/rig unit tests, Full game suite, paid gameplay sequence capture, network/prediction integration, hardware input, wall-contact regression, frame-time/GPU measurement and human playtest. Historical greens are not relabeled as new passes. No normal/reduced airborne sampler was exercised; the two saved Steam stills do not establish that behavior.

The GIF/HTML clock is an **800 ms viewing aid**, not a new gait speed. Slide and landing repeats/cuts intentionally show missing source transitions. L/R phase labels are proposed annotations, not automatic extraction of source anatomical feet. No new production-compliant sprite sheet is claimed, so nothing under `images/` or `pilots/` should be installed as a body atlas.

## Atomic integration / rollback

Before any live change, preserve the current dirty baseline and its exact owned rig, exporter, nine atlas files, manifest and matching tests. Do not restore a single old atlas into a new manifest. Import verification checks both PNG and decoded RGBA hashes; maintain revision/layout agreement with the presenter. A new action bank or masked-arm path requires coordinated schema/presenter/tests, explicit residency/draw costs and independent review. Keep the accepted baseline playable until all focused gates pass. Remove or disable only this owned candidate set on rejection—never reset, stash or clean the user's shared checkout.

## Next decision

Accept or reject **Small contact readability and the five proposed action/contact roles** using source boards first, then schedule actual runtime sequences with the lead. The deliverable is ready for that review, not for automatic live promotion.

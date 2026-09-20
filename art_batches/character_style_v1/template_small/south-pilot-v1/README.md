# Small neutral template — South-only technical pilot

Status: **1 of 80 required cells, source-only partial review; not a completed or approved template.** No character identity, live registry, gameplay, installer or imported runtime page changed. No generation calls were used for this assembly slice.

| Artifact | Current evidence |
|---|---|
| [Partial PNG](review-v1/template_small-partial-review.png) | One actual grounded/South cell, 96×96 RGBA8 |
| [Manifest](review-v1/manifest.json) | `asset_kind=neutral_body_template`, `frame_count=1`, `complete_coverage=false`, `live_promotion=false` |
| [Technical report](review-v1/technical-review.json) | Actual occupied bounds `(36,26,25,58)`; last opaque row83; binary alpha; transparent gutters |
| [Native dark](review-v1/native-dark.png) / [light](review-v1/native-light.png) | Exact native58px standing anatomy |
| [4× dark](review-v1/4x-dark.png) / [light](review-v1/4x-light.png) | Nearest inspection enlargements, not additional source art |
| [Exact removal mask](review-v1/south_base-removal-mask.png) | Only reviewed edge-connected neutral checker removed; original source preserved |
| [NE pair metadata](ne-pair-held.json) | Explicit measured crops retained; no invented scale, no assembled pair or accepted contact claim |

## Source and registration

The immutable `template_v2/small-south-base-v1.png` has SHA256 `b67f0ae46673f51350f56cb7d23764109a01a0bfbd45b4bbc36a43fa5e4852e3`. The actual measured crop is `[408,118,438,1031]` with visible anatomy `[1,1,436,1029]` inside it. The existing assembler applies one scale `58/1029`, nearest sampling and exact occupied-bottom registration at pivot48/84. No per-pose fitting, anatomy warping or synthesized movement occurs.

Candidate PNG SHA256: `786607ea6f6b94aed977d6624432792727b520e71367ca8ed65998e35c13f238`.
Decoded RGBA SHA256: `7f4714cbe34cd28491d7e926c1e737063fd59c18d865c26da5c5ae5e1943a5ce`.

The source's fake checker was inspected and removed only with the existing explicit source-hash-locked `edge_connected_neutral_checker` rule: minimum channel170, maximum spread18. No global white removal; enclosed colors/highlights remain. Both original source hashes were rechecked after the native proof.

## Review limits

The front silhouette is centered, hands empty, clothing separate from effects, and the native light/dark proof has no remaining exterior white matte. Fine facial and boot detail is sparse at58px, as expected from this first downsampled pilot; final charm/proportion acceptance remains with the user.

The latest NE pair has clearer rear skull/back and different limb silhouettes. It lacks a neutral calibration pose on its own source board, however, and its head/torso scale relative to the independent South image is not confidently established. `ne-pair-held.json` records both measured crops with **null** scale. Do not fit each pose independently or treat a changed silhouette as proven anatomical left/right support. No walk, sprint, other action or other heading is accepted here.

## Reproduce

Use the existing `scripts/build_character_style_pack.gd` with `--review`, this folder's `source-layout.json`, and a new isolated output folder. Omitting `--review` correctly rejects this incomplete page. `review-proof.gd` creates the four native/4× evidence images and checks the one-cell size/feet/alpha contract; it refuses to overwrite existing proof.

Focused builder tests: `scripts/test_character_style_pack.gd`. No shared Full gate or live editor import was run by this lane. The old generic crop-inspection helper emits a Godot resource-loading warning for the unimported NE source; its measured rectangles were used only as read-only diagnostics, not as an exported-runtime or green validation claim.

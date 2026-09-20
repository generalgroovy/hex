# Existing sprint-B as derived walk-B / bounded review

Decision: **no substitutions approved**. No new image generation, source-layout-v5 or candidate assembly was performed in this review. V4's focused south/north B poses remain the best current correction; the other six walking headings remain visually unresolved.

Source: immutable `candidate-v2/red_baron.png`, SHA-256 `a1001e67654f04fdbefcb66e7010ff4b93a13bdf1003f4088cdbb7b37e794fe8`.

`inspect_gait_reuse.gd` extracts exact96px source cells and enlarges the comparison by4× nearest only. In every image under `reuse-review-v2/`, **LEFT is existing walk A; RIGHT is existing sprint B**. This is diagnostic presentation only, not generated art, pose fitting or proposed runtime scaling. The final strict diagnostic log `.godot/red-baron-art-20260908/inspect-gait-reuse-v2.log` passes with empty stderr. The initial diagnostic emitted Godot's raw-resource Image.load_from_file export warning; the final helper reads raw PNG bytes explicitly and does not claim runtime-export use.

## Per-heading decisions

The decoded bounds come from `review-v2/report.json`. Both pose cells retain the same intended foot anchor. Crown/top movement here therefore means a visible gait-frame displacement, not the avatar's authoritative jump height.

| Heading | Existing walk A bounds x,y,w,h | Existing sprint B bounds x,y,w,h | Top moves upward | Choice |
| --- | --- | --- | ---: | --- |
| South-east | 21,14,55,70 | 16,5,64,79 | 9px | Reject. High forward knee and sprint lean do not establish a reliable opposite walk contact; torso/head would noticeably surge upward. |
| East | 25,14,47,70 | 18,5,59,79 | 9px | Reject. The visible forward knee remains forward and elevated; this reads as a running-flight phase, not a clearly opposite planted walk leg. |
| North-east | 21,15,54,69 | 16,6,64,78 | 9px | Reject. Strong running lean and lifted lead knee/cape create a different run phase, with no dependable opposite walking contact. |
| North-west | 20,15,56,69 | 16,4,65,80 | 11px | Reject. Largest top discontinuity; high-knee running articulation is not compatible with the upright walk A contact. |
| West | 27,15,43,69 | 19,6,59,78 | 9px | Reject. Foreground knee remains elevated forward while trailing leg descends; opposite anatomical contact is not reliably demonstrated, and the silhouette becomes16px wider. |
| South-west | 21,14,54,70 | 17,6,63,78 | 8px | Reject. Lower/near boot changes are not sufficient proof of opposite anatomical contact; the sprite reads as a sprint bound with a large head/torso displacement. |

The costume, palette and underlying identity are broadly consistent, so these remain useful **sprint** poses. They are not rejected artwork in their current role. The rejected proposal is specifically reusing them as walk-B without changing scale, registration or gameplay motion. No per-pose shrink, head relocation or other pixel repair was applied to make them fit.

## Next checkpoint

The root-owned shared builder correction subsequently landed and the unchanged v4 source selection was rebuilt into `candidate-v5-registration`, with all80 actual baselines verified. No rejected sprint-to-walk reuse was applied. The registration correction does not resolve missing opposite-leg walking art or turn these rejected proposals into accepted frames. This bounded review adds no new claim of80 independent animations or all-direction gait acceptance.

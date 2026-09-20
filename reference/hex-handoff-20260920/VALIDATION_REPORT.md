# Validation report

**Scope: local proposal-data consistency only.**

21/21 package consistency checks passed.

The original source brief byte hash was compared.

| Check | Result |
|---|---|
| Required proposal files exist. | PASS |
| Source metadata lists exactly one received ANIM brief. | PASS |
| Brief SHA-256 metadata has a valid shape. | PASS |
| Original supplied brief byte hash matches the recorded SHA-256. | PASS |
| Missing revision/build/engine and implementation evidence are not fabricated. | PASS |
| Eight proposed clockwise screen directions match their unit vectors. | PASS |
| Eight relative gait codes use the declared order. | PASS |
| Matrix contains exactly 64 unique movement/aim cells, with no omissions. | PASS |
| All matrix gait mappings and stable aim-facing body expectations are coherent. | PASS |
| Gait counts are eight each; grouped counts are 24 forward / 16 lateral / 24 reverse. | PASS |
| Matrix expands to 384 steady-state template/gait variants; both retarget supports are specified separately. | PASS |
| Every visual/runtime matrix and contract status remains NOT_RUN. | PASS |
| All three source templates, dimensions, colliders, anchor tracks and stride distances remain explicitly unbound. | PASS |
| All eight required body states are represented. | PASS |
| All 12 proposed timing records have coherent key counts and 120 Hz reference arithmetic. | PASS |
| Contact metadata uses anatomical limb IDs and alternating L/R entry landmarks. | PASS |
| Walk double support, run flight and the distance-clock limitation are explicitly represented. | PASS |
| Proposal flags preserve continuous authority and body/effect separation. | PASS |
| Proposed hysteresis, atlas layout and turn allowance are internally consistent. | PASS |
| All five proposed pilot records reference valid cells and remain NOT_RUN. | PASS |
| Engine/event/correction adapter bindings remain explicit source blockers. | PASS |

## Checks not run

| Review | Status |
|---|---|
| Static template/silhouette/proportion review | NOT_RUN |
| Animated contact drift, turning, timing and occlusion review | NOT_RUN |
| Real sprite alpha, frame boundaries, gutters and sampling | NOT_RUN |
| Current-source adapter binding and renderer compatibility | NOT_RUN |
| Gameplay/replay/collider/continuous-aim comparison | NOT_RUN |
| Godot on Windows runtime | NOT_RUN |
| Eight-player visual readability | NOT_RUN |

No game assets, game process, repository checkout, network session or animation renderer were exercised. No visual quality or performance claim follows from these consistency checks.

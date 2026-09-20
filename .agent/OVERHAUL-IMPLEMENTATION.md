# H.E.X. active implementation queue

Status: **Smaller-grid/title slice complete; source publication and user playtest**,
September 21, 2026. Local gameplay candidate; multiplayer acceptance FAILED.

Work only in `C:\Users\sende\Projects\hex`, public `generalgroovy/hex`, branch
`main`. Preserve original FLUX, profiles, assets and fallback packages. The user
authorized a normal source push, not a force-push or binary release. Stop before
33% weekly remaining; latest check 42%. No credits/reset purchase.

Runtime **p55-c7b7694f8d23**; protocol 55 / SessionSnapshot21 / HexWorldSnapshot3 /
chemistry3 / envelope1. Current contract: [SPECIFICATION.md](../SPECIFICATION.md).
Exact handoff: [HEX-RESUME.md](HEX-RESUME.md). One engine integration owner.

## Current bounded slice

| Part | State / evidence |
| --- | --- |
| Smaller cells | COMPLETE: 64 to 48 px face-to-face; 2,766 eligible cells within 4,096 cap; exact shared faces and canonical ownership |
| Preserved scale | Map/obstacles, characters, 18 px wall clearance, spell radii/costs and authored damage coefficients unchanged |
| H.E.X. title | COMPLETE: project/launchers/help; ASCII `hex` filenames, Flux resource and legacy profile path preserved |
| Completed vision work | INCLUDED: 360/720 character-centered, opaque-cover-aware view; saved controls/weaves preserved |
| Functional regression | PASS: unfiltered Full 157 suites / 803,865 assertions / zero failures/stderr, import, asset audit and 120 Hz boot |
| Native gameplay | PASS: 7 reviewed normal/reduced frames, actual paid Water/Fire casts, Steam and whole-cell contact |
| Windows package | PASS: frozen source/PCK identity, actual native EXE launch/safe close, 7-entry ZIP SHA256 audit |
| Same-export multiplayer | FAILED: 300 s lifecycle deadline; first round, reconnect and late spectating observed, second round/stewardship not completed |
| Source publication | User-authorized normal push to public `main`; exact commit/remote status is Git, not a binary-release claim |

Current checkpoint: [HEX-SMALL-GRID-CHECKPOINT.md](../docs/HEX-SMALL-GRID-CHECKPOINT.md).
Evidence: [smaller-grid receipts/logs/gallery](../docs/verification/hex-small-grid-20260921/).
Launch locally: `exports/hex-small-grid-20260921/windows/PLAY-HEX.cmd`.
Human playtest: [five-minute route](../docs/HEX-PLAYTEST.md).

## Next slices after playtest / explicit continuation

| Order | Bounded slice | Acceptance before advancing |
| --- | --- | --- |
| 1 | Snapshot/topology cost on the 48 px map | Profile identical workload; preserve exact bytes, malformed-input rejection, mutable ownership, MTU/event budgets and full authority; pass unchanged 300 s same-export lifecycle |
| 2 | Capacity and responsiveness | Measure simulation/snapshot/render costs separately at fixed workloads; meet the 8.333 ms (120 Hz) budget with headroom; no claims from the light native capture alone |
| 3 | Finer-grid balance | Measure Fire/Steam cell-density pressure versus actor exposure before changing coefficients; conserve paid material; review map-center and off-center impacts |
| 4 | Narrow reaction correctness | Actual Vortex safe-center occupancy across impact positions; real Fire/non-Fire Mistcurrent ground/projectile suppression and exact capacity; same-tick three-input contention |
| 5 | Human readability and movement feel | Review 48 px cover edges, sight, normal/reduced Steam, clear eight-direction movement/aim and saved twelve-slot weaves; preserve three reusable body templates |
| 6 | Friends-ready delivery | Same-export lifecycle and physical two-PC/Internet acceptance, frozen package/rollback audit; installer/updater or GitHub binary release only when separately authorized |

Do not enlarge the lifecycle timeout or reduce correctness to make a gate pass.
Whole-cell authority remains approved: radius selects cells; selected cells are
fully affected. More cells never create more material. No new mechanics/content
expansion while snapshot performance and the multiplayer gate remain red.

## History and boundaries

The [integration checkpoint](../docs/HEX-INTEGRATION-CHECKPOINT.md) and
[sight checkpoint](../docs/HEX-VISION-CHECKPOINT.md) retain their own dated receipts.
Their passed checks are not fresh evidence for protocol 55. The
[first-four review](../docs/HEX-FIRST-FOUR-REVIEW.md) identifies remaining oracles;
its old Vortex geometry must be re-evaluated on 48 px cells.

All 30 profiles remain playable through three shared size templates; individual
character art is not complete. Historical dense host p95 348.571 ms and rendered
frame p95 153-192 ms were failed prior-build measurements, not current results.
The current lifecycle trace also shows severe snapshot pressure, without a new
aggregate benchmark. Correctness does not establish capacity or human acceptance.

Selected `docs/current-checkpoint.json` remains the historical P48 delivery in
original FLUX. No installer/updater, external binary release, pointer promotion or
physical two-PC certification is implied. Preserve failed and passed evidence.

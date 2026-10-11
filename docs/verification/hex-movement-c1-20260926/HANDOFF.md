# H.E.X. movement/height checkpoint 1

Status: LOCAL SOLO CHECKPOINT DELIVERED, September26. Human acceptance pending.
Build **p56-5dc9b5f3bdc0**. Open
`exports/hex-movement-c1-20260926/windows/PLAY-HEX.cmd`, keeping EXE/PCK together.
Portable ZIP: `exports/hex-movement-c1-20260926/HEX-p56-5dc9b5f3bdc0-Windows-x64.zip`
(98283719 bytes). Stop for feedback; no CP2/CP3, commit, push, publication,
installer replacement or checkpoint-pointer promotion. D9 remains the fallback.

## Scope

| Delivered source | Player contract |
| --- | --- |
| Release jump | Ground press prepares; release launches; up to300ms charge increases the arc. A complete quick tap remains valid. |
| Air options | Non-fliers: one double jump. Sylph/wyrmborn/angel/demon: finite held flight instead. No replenishment from a wall touch. |
| Wall chain | Hold airborne Jump beside a suitable wall; release to walljump. Neutral release uses the outward wall normal, not cursor or previous facing. |
| Exposure | Ground/upright/wallrun exposed; crouch/slide avoids ordinary projectile bodies only; air above18px clears ordinary ground effects and projectiles. Steam retains its explicit48px ceiling. |
| True protection | Timed roll/air-dodge and spawn protection remain separate; jump/slide/flight do not grant blanket immunity. |
| Visual/UI | Travel-aligned slide in eight directions, planted anticipation, height cues, finite flight meter, accurate coach and resource hints. |
| Input recovery | Modal/focus/stale-network cancellation cannot create release jumps or consume the first fresh action after the guard. |
| Compatibility | Protocol56, SessionSnapshot22, HexWorldSnapshot4; new action fields are canonical/replicated. Old builds cannot connect. |

The existing48px grid,30 catalog identities, three shared body templates, common
wall clearance and size-specific stats/hurtboxes remain. Southern conservatory
walls serve the compact test route. Smaller hexes and large Wellspring expansion
are next checkpoints, not silently included here.

## Evidence ledger

| Run | Meaning |
| --- | --- |
| import-v1/v2 | FAILED pre-engine static gate; version/identity parsing corrected. |
| focused-v1.json | FAILED initial integration; retained with logs. |
| diagnostic-v2/v3/v4.log | Intermediate focused diagnostics, not frozen acceptance; uncovered fixture, cancellation and obsolete-contract expectations. |
| capture-v1.log | Native production presenter:24 controlled slide poses and36 simulated motion frames, all sizes. Source capture before final freeze; not physical-controller acceptance. |
| .godot/movement-cast-c1-source-v1 | FAILED input-reset fixture. |
| .godot/movement-cast-c1-source-v2 | PASSED192router combinations,24paid routes,3focus and3low-Flux cases;11763checks. Intermediate source identity, not final PCK. |
| .godot/movement-advanced-c1-source-v2 | FAILED first fresh action after guard; actual cancellation delivery fixed and regression added. |
| .godot/movement-advanced-c1-source-v3 | PASSED12real-input routes /7751checks:3flight,3double jump,3dodge/fast-fall,3wall chains. Intermediate source, not final PCK. |

Additional implementation repair: a charged slidejump retains its prepared
movement family after the finite slide timer expires. Physical friction continues;
the charge does not extend low-profile protection, create speed or refill budgets.
Eight-direction regressions cover this boundary.

## Historical pause checkpoint

`full-v1.json`: FAILED,164 suites /832794 assertions /1606 failures; stderr0.
The four new checkpoint suites passed11099 assertions. Import and asset audit
ran, but this is NOT a final acceptance receipt. Production changed after the
preflight identity was generated; `p56-853da269dc71` is stale candidate metadata,
not a frozen build. Regenerate after the outstanding fixes and review, then Full.

The following table is the historical pause boundary, superseded by the resume
results below; it is retained to explain the failed first Full run.

| Remaining at pause | State at pause |
| --- | --- |
| Cartoon presenter assertions |1535 failures in existing all-character/direction tests; file inspected, NOT migrated. Preserve all coverage while updating slide travel, wallrun gait and removed Float shield expectations. |
| Actual flight-meter issue | `JumpPresentation.height_contract` should require positive float_ticks AND stamina before showing flight meter; height clearance must stay independent. NOT fixed. |
| Actual legacy shield embellishment | `CartoonChampionPresenter.protection_contract` retains Float wing/budget decoration when independent spawn protection overlaps flight. Remove obsolete decoration; NOT fixed. |
| Input-router fixtures |16 failures: cancellation control bit is now present after quarantine/configuration. Verify intended lifecycle; preserve exact paid-action checks and explicitly test cancellation, never broadly ignore unexpected bits. NOT migrated. |
| Later narrow test edits | UI/Gallery/Compendium, whole-coverage, Heavy matrix, core protocol, resource recovery, controls round-trip and authoritative release-jump updates are saved but NOT rerun. |
| Magic source-hash audit | COMPLETE, not rerun. Verified old HEAD digest26d35914… and currentde173e73…; only actor exposure changed in `_apply_result`, not recipe geometry/quantities/phases/pulses/lifetimes. Magic art/manifest and recipe policy have no diffs. Narrow guard and audit comment updated. |
| Frozen acceptance | Review first, regenerate runtime identity, focused residual suites, then Full. Repeat real-input journeys and native capture on final source. |
| Delivery | Fresh Windows portable export and exact-PCK journeys remain NOT_RUN. No movement installer exists. Stop for feedback when this checkpoint eventually passes; do not start CP2. |

Full-v1 logs: `.godot/windows-tests/e3183aa7786e4a54b1c7f23ed301f0d1/`.
Native capture: `.godot/movement-checkpoint1-20260926-v1/` (37frames). The capture
script now positions future motion captures lower to avoid header overlap; that
test-only layout edit is not rerun. No engine process remains from this work.

The collision review also fixed prepared-slide momentum resurrection: after a
wall impact, retain ordinary jumpsquat and clipped momentum, not the blocked
slide impulse. Eight before/after-slide-expiry wall regressions passed in the new
focused suite within Full-v1. The source manifest must still be regenerated.

## September26 resumed validation

All worker edits are frozen. Two presentation defects were fixed: a flight meter
now requires capability, positive time and stamina; independent spawn protection
no longer inherits obsolete Float wing/budget decoration. Height clearance stays
independent of both. Existing all-character/action/direction coverage is retained.

| Fresh run | Result and scope |
| --- | --- |
| resume-focused-v1.log | PASS: ten selected suites, including saved control/release-jump, authority, resource, coverage, Heavy blast and magic-hash migrations. Source diagnostic, not package acceptance. |
| resume-input-v1.log / resume-presentation-v1.log | FAILED: test preload/type inference and invalid suite selection; retained. |
| resume-presentation-v2.log | FAILED: one walljump contact fixture still used the retired jump-protection timer instead of upward velocity and movement commitment. |
| resume-presentation-v3.log | PASS: four suites /51011 assertions /zero failures; input949, cartoon48208, checkpoint visuals823, jump presentation1031. |
| Frozen source identity | p56-5dc9b5f3bdc0,2800 production records; regenerated after all production repairs. |
| full-v2.json | PASS:164 suites /835139 assertions /zero failures /zero stderr; import, asset audit, current-state check and120Hz boot passed. Logs in `.godot/windows-tests/6b067b176f2645bab056c2558a4a2d5b/`. |
| .godot/movement-cast-c1-final-source-v1/receipt.json | PASS:192 router combinations,24 paid routes,3 focus and3 low-Flux cases;11763 checks against final source. |
| .godot/movement-advanced-c1-final-source-v1/receipt.json | PASS:12 actual-input routes /7751 checks:3 each flight,double jump,dodge/fast-fall,wall chain. |
| capture-v2.log | PASS:24 controlled slide poses plus36 simulated motion frames from frozen source; native renderer, unchanged canonical state. |
| exports/hex-movement-c1-20260926/receipt.json | PASS:Windows portable export, packed identity, native1280x720 boot and safe close in an isolated profile; no installer. |
| .godot/movement-cast-c1-final-pack-v1/receipt.json | PASS:exact exported PCK,192 router combinations,24 paid routes,3 focus and3 low-Flux cases;11763 checks. |
| .godot/movement-advanced-c1-final-pack-v1/receipt.json | PASS:exact exported PCK,12 real-catalog input routes /7751 checks, covering flight,double jump,dodge/fast-fall,wall chains. |

The input regression includes eight complete Bootstrap modal/focus cancellation
routes, exact paid/control bits and first-fresh-action recovery. The cartoon
matrix retains30 identities x8 directions x10 actions x2 effects profiles.
Walljump dust now tests the current non-invulnerable action contract.

Visual review directly inspected `slide-directions.png`, `motion-020.png`,
`motion-052.png` and `motion-112.png` in
`.godot/movement-checkpoint1-20260926-v2/`: all three shared sizes fit, the
slide lane changes in eight travel directions despite opposite aim, anticipation
is grounded, airborne bodies separate from shadows, flight has a distinct meter,
and release removes that meter. No header overlap in reviewed motion frames.
These are shared skeleton bodies, not finished character skins. The remaining
33 captured images were generated but not individually visually reviewed; human
motion/feel acceptance remains open. Capability is forced only in the six-body
visual comparison; the input journey separately uses real catalog flight gates.

PCK SHA256: `90ef313a0733348094f8a5bced716b3a722bb9559bfe6f6c6e941ed11e7ea181`.
ZIP SHA256: `da5c16f7d0599eb3b4a63e8f5a28b70f41f0748d161b5d5632a02b69ff8b21c1`.
Do not use the selected checkpoint pointer to infer this candidate was promoted.
All saved preferences were isolated during tests; no personal profile reset.
Final read-only verification: runtime identity still matches all2800 production
records after export/journeys; ZIP/PCK hashes match the package receipt and all
seven ZIP entries byte-match delivered files. Native smoke and both PCK journey
stderr logs are empty. No Godot/hex.exe processes remained at handoff. D9/E2
launchers are still present. Existing unrelated CRLF warnings in the dirty diff
were not bulk-normalized during this frozen checkpoint.

## Human review / limitations

Try tap/charged Jump, double jump versus flight, release walljump and all eight
slides while aiming the other way. Use Small/Middle/Large and normal/reduced
effects. Walk/slide/jump through a projectile lane and a Fire field; height cues
must not suggest universal invulnerability. Open a menu during anticipation and
release the key there: returning must not launch or stick the action.

This is a local solo checkpoint. Historical dense-field frame deadlines and
multi-EXE lifecycle failures remain unresolved. Configured120Hz is not measured
render/capacity acceptance. Internet/two-PC/controller hardware/human feel and
installer/updater acceptance remain open. No new installer or checkpoint-pointer
promotion is authorized. Preserve D9 at
`exports/hex-native-sort-20260923/windows/PLAY-HEX.cmd` and the E2 fallback.

## Continuation boundary

One lead owns imports, tests, captures and exports. Workers receive exact paths,
current contracts and short test receipts; no overlapping production ownership.
Retain success/failure evidence, remove only owned disposable helpers, and leave
one active queue. Finish this checkpoint and return for feedback; do not start
another automatic loop or change the user's profiles.

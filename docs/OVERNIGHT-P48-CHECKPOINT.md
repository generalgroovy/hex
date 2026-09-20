# Overnight P48 checkpoint — 13 September 2026

Status: local Windows portable verified and selected; paused for user playtest.

Build **p48-111d911c27fa** is selected by docs/current-checkpoint.json. Open
[flux2.exe](../exports/windows-overnight-p48-20260913/windows/flux2.exe) with its
adjacent PCK, or extract the complete
[portable ZIP](../exports/windows-overnight-p48-20260913/release/FLUX2-Windows-x86_64.zip).
PCK SHA256: `ddce9451e871096ca02190deb9092cba71db96bd8d732cd2181fd7c5cd452083`.
ZIP SHA256: `5e49c599f026453917e3eb8201456e86089e9fe0d794efe3b9bcebe1385c041f`.
Keep both players on this same ZIP; protocol47 P3 cannot join protocol48.

Fallback: open the preserved
[Chemistry P3 EXE](../exports/windows-chemistry-p3-p47-20260912/windows/flux2.exe)
with its own adjacent PCK, or extract its
[complete ZIP](../exports/windows-chemistry-p3-p47-20260912/release/FLUX2-Windows-x86_64.zip)
to another folder. Never mix PCKs or replace either build folder. Fresh final
identity checks verified all three payloads and five evidence files for both
new selection and fallback. The separate historical installer remains unavailable.

## Changes prepared for play

| Slice | Player-facing result | Remaining boundary |
| --- | --- | --- |
| A1 input admission | Host polls between catch-up ticks; seven remote peers have four bounded queued records each. Newest continuous state and displaced action edges coalesce without extra simulation time. Host shutdown/world replacement aborts the old catch-up loop. | Physical eight-player play |
| A2 aim ownership | Releasing the right stick retains its eight-direction aim; real mouse motion returns pointer control. | Physical controller feel |
| A3 controls | Fixed UI shortcuts cannot be captured as gameplay bindings. Default D-pad plus LB/RB reaches twelve spell positions. Existing custom, partial and empty mappings survive migration. | Check personal settings and controller ergonomics |
| A4 LAN browser | Vanished hosts expire; empty-state errors remain visible; retry refreshes the browser. | Physical UDP discovery/two-PC play |
| A5 feedback | Bounded feedback queue prioritizes actionable cues and exposes queue pressure as a finite FEEDBACK BUSY notice. Capture/acknowledgement mutations cannot age newly unsent feedback. | Live loss/feel acceptance |
| B0 diagnostics | Frame clamping and catch-up discard are reported separately. | 120 Hz performance still fails |
| C1/C2 delivery | Current launch summary derives from the checkpoint pointer. Protocol48 hosts/joins validate full production-source identity, display a short build ID, and explain same-ZIP recovery on mismatch. | Local package gates passed; physical network acceptance pending |
| D route/readability | Commons/Source Court and Sparring/Duel Court labels match their destinations. HUD warning, LAN panel and court plaque no longer overlap. | Human route learning and animation acceptance |
| E reusable bodies | Original three reusable rigs preserved. Proposed walk-frame landing shortcut rejected after actual art review because it would slide stationary feet. | Dedicated planted landing pose and sequence review |

The authoritative 120 Hz simulation, eight-player limit, three size hurtboxes,
common wall clearance, independent aim/travel, paid attacks and movement,
eight elements/twelve positions, finite chemistry, and trail-free Rapid remain
the contract. No new simulation optimization was retained during this run.

## Fresh evidence and performance

Evidence root: `docs/evidence/overnight-20260913/`. Package evidence is preserved
separately in `docs/evidence/windows-overnight-p48-20260913/`.

| Fresh final gate | Result and receipt |
| --- | --- |
| Full | **102 suites / 691,883 assertions; zero failures/stderr**,213.862s; final/full-v3.json and copied referenced logs |
| Import identity | **117 canonical class paths**, no violations; final/class-cache-green-v3.json |
| Paid gameplay draw | **221 frames**, actual paid admissions, draw preserves authoritative hash; package inputs/capture and inputs/capture.log |
| Interfaces | **52 v4 frames**,720/1080 normal/reduced, draw preserves authority; presentation/referenced/.godot/overnight-interfaces-v4 |
| Independent visual review |16 final interface frames plus31 representative gameplay frames; no material finding in bounded static sample |
| Freeze/export | **3,122 unchanged inputs**, including directly preloaded ground_style.gd;2720 production identity records; fresh Windows EXE/PCK/ZIP, PCK runtime identity and isolated raw boot passed |
| Exact export localhost | Host/join, reconciliation, late spectator/Hearth, reconnect, rematch and reason-bearing host release passed at120Hz on UDP24980; final/same-export-farflow and package-driver-v1.log |
| Preference isolation | Full boot wrote a3011-byte isolated profile; real observed profile hash unchanged and environment restored; final/isolated-boot-proof.json and preferences-guard-v3.json |
| Final timing correctness |47,398 exact checks passed with zero failures; performance/final-real-map-drill-v1.log |
| Pointer and fallback bytes | Each current_portable group verified; overall verifier remains unavailable only because the separately retained historical installer is absent |

Earlier targeted boundaries remain intermediate evidence: C2:15 suites/8,840;
route:4 suites/2,100; layout:5 suites/2,653. Final Full v1 exposed old .gd backup
classes imported from the evidence directory, plus a stale protocol expectation.
Those results and v3 interface captures cannot prove canonical loaded controls.
The run evidence root now has .gdignore; a new exact-class-path guard reproduced
the fault and validated its correction. Full v2 stopped in documentation preflight
on a missing draft Status line. Both failures and all logs remain preserved.
Full v3 and v4 interfaces are the corrected final evidence. Interface network/UI
states are fixtures, not physical network traffic or a human playthrough.

Early and final source timing used the production real-map drill,
two repeats with120 warm-up and720 measured ticks, plus360 snapshot samples per
repeat. Ryzen3 7320U, four cores/eight threads, approximately7.28GiB usable RAM,
pinned Godot4.7.1 Windows. No controlled thermal/power claim.

| Metric (ms unless count) | Early P47 repeat1 | Early P47 repeat2 | Final P48 repeat1 | Final P48 repeat2 |
| --- | ---: | ---: | ---: | ---: |
| Simulation p50 | 10.168 | 10.322 | 10.686 | 10.374 |
| Simulation p95 | 18.331 | 17.207 | 16.658 | 16.934 |
| Simulation p99 | 24.737 | 21.798 | 19.745 | 19.597 |
| Simulation maximum | 64.826 | 40.076 | 23.435 | 24.444 |
| Ticks above8.333ms /720 | 465 | 466 | 494 | 471 |
| Snapshot capture+pack p95 | 10.505 | 9.949 | 9.535 | 9.812 |

Each drill passed47,398 exact state/order/trace checks. W4 **FAILED**. Final
P48 timing ran after export with no competing engine/export job. Its source
fingerprint is f6c0dfce694c569ae3136c8500ecd2932e0609e541045617a1592a3305b37cd7
(338 source records in the drill scope). These source/codec measurements are
not rendered FPS, socket transmission or packaged-game timing. No simulation
optimization was retained; the table is a temporal observation, not a controlled
before/after improvement claim. Historical P3 p95 14.160/14.065ms is another
unmatched older reference. Cross-protocol hashes differ because state_hash
includes protocol version; each current production/mirror comparison passes.
The ordered-state sort fast-path remains only a proposal requiring matched
baseline/candidate/control measurements. Full timing quantiles, worst cases and
snapshot samples are preserved in performance/final-real-map-results.json.

## Known incident and acceptance limits

An early new test harness inherited preference persistence and wrote defaults to
the personal FLUX settings file at00:16:02UTC. No proven pre-run backup was found,
so no speculative restoration was attempted. The harness now forbids saving and
the test wrapper isolates APPDATA. Subsequent guarded runs preserved the observed
profile hash. **Please check your saved controls and settings before play.**
The exact incident and retained post-write profile are in
`integration/preferences-incident.md` and `integration/preferences-after-harness.json`.

Human acceptance, physical controller ergonomics, physical two-PC/WAN play,
sustained rendered performance, installer/updater and publication remain separate.
No reset credits or purchases, destructive cleanup, security changes, commits,
pushes or publication were performed. The extensive pre-existing dirty working
tree remains on main at a1aa02807626823d0fbc1e25e75441ca3b7f4d36.

## Playtest plan (10–15 minutes)

1. Open the candidate directly from its new folder; check its displayed P48 build
   ID. Both PCs must use the same extracted ZIP. Keep the P3 folder as fallback.
2. Check saved settings and bindings. Rebind Jump, close the UI, release then
   press the new input. Try F4/Escape during capture and confirm they are reserved.
3. Aim with the right stick, let it return to neutral, and move independently.
   The aim should stay fixed; moving the mouse should take ownership back.
4. With the new default map, use D-pad U/R/D/L, then LB+D-pad and RB+D-pad to
   reach all12 spell positions. Try a paid attack while moving, jumping and evading.
5. Follow Commons/Source Court → Movement Garden → Crucible → Duel Court.
   Check route labels, ingredient versus active-effect clarity, and reduced effects.
6. Host and join with the same build. Check the full short build ID and LAN list.
   Close the host, verify its row disappears, and retry. A different/old build
   should be refused with instructions to use the same ZIP.
7. Try a short sparring exchange. Note any missed action, stale aim, unreadable
   warning or movement hitch, along with the build ID and what you pressed.

## Next three slices

1. Measure the proposed chemistry strict-order fast-path with exact order/state
   oracles and prospective matched performance gates; retain only a real win.
2. Exercise physical controller and two-PC discovery/input/lifecycle with this
   exact portable, recording hardware, build IDs and observed failures separately.
3. Author one planted landing/compression pose in the shared size-rig contract,
   then review actual stationary/moving landing sequences before skin expansion.

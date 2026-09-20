# Coordinated foundation acceptance — 2026-09-06

Status: source-verified pause checkpoint, 2026-09-06. The user requested a safe
pause for playtesting; do not begin another slice until asked. Full, local Farflow,
compendium captures and the actual launcher smoke test passed. Windows is the
active platform. This is not a new installer release, internet connectivity
certification or human art approval.

## Run this checkpoint

Double-click `C:\Users\sende\Projects\flux\flux.cmd`, or run `./flux.cmd play`
from that folder. The older `Documents\FLUX` checkout and already-exported apps
may not contain this checkpoint. F4 / controller Select-Back opens the compendium;
Tab / bumpers switches sections. Escape / B closes it. The world keeps running.

| Final gate | Actual result |
|---|---|
| Full | 74 suites / 60,230 assertions; import and 120 Hz boot; zero failures and zero stderr bytes; 49,650 ms |
| Local Farflow | Host/join, shared greeting, reconciliation, rounds, late join, rematch and reason-bearing host shutdown passed |
| Strict eight-player diagnostic | 6,319 assertions; two repeats; all 40 paid projectiles represented, zero rejected snapshots |
| Source launcher | `./flux.cmd play -SmokeTest` exited successfully; protocol 39 / snapshot 14 |
| Rendered compendium | Movement and character pages inspected at 720p, without clipping |

Receipt: `.godot/receipts/team-pause-full.json`; logs:
`.godot/runtime-audit/pause-strict-eight.log`, `.godot/farflow-smoke/`,
`.godot/run/launcher-smoke.log`. Captures:
`.godot/visual-captures/compendium-movement-v2/` and
`.godot/visual-captures/compendium-characters-v1/`.

## Player-facing slices

| Stream | Implemented candidate | Next acceptance / deliberately not claimed |
|---|---|---|
| Gameplay | All 17 moving spells are 20% slower; practical reach changes by less than 0.3%. All five playable champions have 10% more Flux and Stamina. | Human feel/balance review; ordinary movement speed and damage are unchanged. |
| Network integrity | Protocol 39 / snapshot 14 represents all admitted projectiles and fields, using bounded MTU-sized fragments and atomic reconstruction. | Real internet/NAT/signing journeys remain separate; future 32-player play is not supported. |
| Fair admission | Whole-pattern reservations before payment: 128 projectiles / 32 fields globally; 16 projectiles / 4 fields per traveller. A refusal spends nothing and tells the player to let an existing spell fade. | These are finite correctness limits, not an unconditional 120 FPS guarantee. |
| Runtime | Deterministic obstacle-grid lookup with exact original narrow-phase behavior and safe mutation/fallback handling. | Actor/projectile interaction scaling, full rendered-frame budgets and larger-map profiling. |
| Element art | Eight reusable field/impact motions, shared symbol language, fixed effect perimeters and actual spell lifetime countdown. Live atlas borders are transparent. | Full 8-by-5 motion/grayscale/reduced-effects/density acceptance; persistent projectile deposits are not implemented by drawing these motifs. |
| Map practice | Dummies return at their authored anchor three seconds after defeat, with 250 ms visible readiness grace; countdown, anchor and protection replicate. | Larger campus/course geometry, route bypasses and matching collision/camera/art. The map remains 3072 by 1728. |
| Usability | Integrated F4 / controller Select-Back compendium with 16 active movement techniques: current bindings, execution, costs, holds, timings, protection and counters; inspected 720p pages. | Physical controller and human readability/feel acceptance; the compendium shortcut is not yet rebindable. |
| Characters | Read-only alphabetical race rows containing all 24 identities and exact live stats; five playable, 18 planned, one placeholder. | Remaining character promotions need distinct body-only art, eight-way motion and individual gameplay/network acceptance. A table is not an implemented champion. |

## Measured defects and proof

The legal eight-traveller Burst scenario exposed a real old-network defect:
40 paid projectiles, 22 omitted from presentation, and 246 of 360 snapshots
rejected in each repeat. The repaired strict scenario reconstructs every threat
with reverse fragment delivery and rejects no snapshot. The actual ENet test
also transfers 80 varied projectiles exactly, not just a synthetic codec packet.

Every fragment is at most 1,392 bytes. A complete snapshot expands to at most
32,768 bytes, uses at most 32 fragments, and the client retains at most three
incomplete snapshots for at most 350 ms between receives. Old, duplicate,
inconsistent, invalid, missing and non-host fragments are tested; an incomplete
frame never overwrites live state. Reconciliation keeps its separate channel.

The 8-actor / 256-projectile / 16-field / 64-obstacle diagnostic dropped from
21.384/21.049 ms median with the original linear resolver to 11.721/11.899 ms
with indexing, with identical checkpoint and final hashes. This approximately
44% improvement is measured on this host, at an intentionally unsupported
injected projectile load; it is not a rendered frame-rate result.

The additional admitted-envelope fixture covers 8 actors, 128 projectiles,
32 fields and 64 obstacles. Its initial integrated run replicated all objects
without overflow or packet rejection, then expired all 128 projectiles and all
32 fields. Median simulation was 5.369–5.660 ms and snapshot capture/packing was
4.268–4.507 ms; some ticks exceeded 8.333 ms. Snapshot work and rendering must be
included before accepting the complete 120 Hz performance target.

## Evidence and commands

| Evidence | Actual scope |
|---|---|
| `.godot/runtime-audit/protocol39-quick.log` | Strict legal eight-traveller reconstruction; two deterministic repeats, no omitted threat/rejected frame |
| `.godot/runtime-audit/admitted-envelope.log` | Initial admitted-capacity timing, exact expiry and complete replication |
| `.godot/runtime-audit/collision-differential.log` | 21,781 frozen-reference assertions across 4,000 seeded traces and edge cases |
| `.godot/diagnostics/gameplay-tuning-20260906-r2.log` | Five suites / 7,565 assertions; production-path projectile A/B measurements |
| `.godot/diagnostics/gameplay-admission-20260906-r2.log` | Seven suites / 6,808 assertions; paid whole-pattern reservation and deterministic ordering |
| `.godot/diagnostics/target-overviews-integrated-v2.log` | Four suites / 2,334 assertions; target world/snapshot lifecycle and both guide data models |
| `.godot/diagnostics/complete-snapshot-v2.log` | Five suites / 1,706 assertions; motifs and snapshot/ENet/reconciliation |
| `.godot/visual-captures/artwork-shared-motifs-20260906` | Four real 720p specimen frames; later label-only correction needs final capture |

Run `.\scripts\test.ps1 -Tier Full`, then
`.\scripts\smoke-farflow.ps1 -TickRate 120` before publication. Run the standalone
`tests/scenarios/runtime_stress_probe.gd` with `--quick --require-network-clear`
for the strict legal journey, or `--scenario=admitted-eight-envelope` for the
bounded maximum fixture. Use isolated diagnostic logs; never run the shared
test runner concurrently.

## Continuing order

| Order | Coherent next outcome |
|---:|---|
| 1 | Completed: compendium, Full, real local Farflow, rendered captures and source launcher smoke. Pause here for the user. |
| 2 | Complete the current element/form visual review and remaining movement contact/landing/wallrun animation clarity. |
| 3 | Expand the connected practice course and campus with collision, readable routes, camera and visuals changed together. |
| 4 | Add finite authority-owned 2–5 second projectile deposits with bounded cast budgets, expiry, snapshots and reset. |
| 5 | Implement Steam end to end, then all 36 first-level pairs with distinct decisions/counters; no recursive chemistry or hybrid casts. |
| 6 | Rebuild and verify the Windows package, then pause for the required chemistry playtest. |

Character promotions continue one at a time using the three existing body
templates; do not delay a playable checkpoint for an unfinished roster-wide
asset batch. Preserve the latest migration IDs without exposing retired vault
or crest-superglide as live movement options.

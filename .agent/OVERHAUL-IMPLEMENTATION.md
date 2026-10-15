# H.E.X. single implementation queue

Status: **WINDOWS CHECKPOINT FOR LINUX HANDOFF — October 15; stop at 20,000 credits remaining.**
The [Git handoff](LINUX-HANDOFF.md) transfers the complete current source, tools,
evidence and design state through the presentation branch. No Windows
implementation continues while the receiving CLI restores it.
The user approved the cross-reviewed improvement proposals, requested multiple
agents per point, stronger visual depth and environment variety (including
higher wall/rampart forms), removal of unused/redundant material, and use of the
desktop launcher. This queue supersedes the earlier pause; older task lists are
historical evidence, not additional active queues.

Completed design request: analyze and design the complete overhaul. The user selected
**illustrated 2.5D with smooth animated sprites**. The
[consolidated proposal](../docs/OVERHAUL-DESIGN-20261015.md) includes gameplay,
experience and technical audits, reciprocal peer reviews, a complete ownership
matrix, staged acceptance and the next implementation prompt. This is proposed
work, not new runtime behavior. The design request produced documentation only;
the subsequent user-authorized Git handoff publishes the whole existing checkpoint.
Qualified delivery and existing source changes remain intact. Use its Stage A
baseline and Stage B integrated pilot when implementation resumes; this file
remains the only active task ledger.

Qualified playable build: **p61-d6d1bfb9c529**. Full passed 265 suites /
7,574,524 assertions; package/archive, 133-image terrain, all five desktop-wrapper
lifecycle cases and the **4,076-check** [independent delivery review](../docs/performance-evidence-20261014/stationary-qualification-d6d1/delivery-review/review.json) passed.
Preserve **6459** as the immediate fallback, with 7804 and older builds intact.
Current-build foreground performance and portable FPS remain unmeasured.
The [previous-build 6459 source performance review](../docs/performance-evidence-20261014/foreground-6459-b/review.json)
retains Profile B; its measurements do not transfer to d6d1. Root alone runs engines,
imports, tests, captures and exports.

## Ownership and completion gates

Every point has an implementation owner plus another agent reviewing the result.
Root integrates and verifies. Dependencies determine order; parallel ownership
must not produce simultaneous engine runs or conflicting edits.

| Point | Implementer | Independent reviewer | Current work / gate |
|---|---|---|---|
| Casting/Garden performance | Root + Technical | Experience | Previous-build Profile B admitted for 6459; current d6d1 Full/Light matched-observer measurement remains pending |
| Loading/memory | Technical | Root + Experience | Repeated travel/cancel/close and real memory residency; no speculative prefetch |
| Movement/control/camera | Gameplay | Technical | Independent camera look-ahead preference, legacy migration and normal/reduced-motion combinations |
| Defense/readability | Gameplay | Experience | Actual protection, height and cover outcomes; concise optional practice feedback |
| Spell delivery/tempo | Gameplay | Technical | Equal-resource moving/cover/group scenarios; tuning requires demonstrated weak niches |
| Chemistry/statuses | Gameplay | Experience | Compare shared-mechanic recipes with simpler subsets and actual finite follow-up effects |
| Characters/ancestries | Gameplay | Experience | Natural activation and combined contribution; existing controls remain sufficient |
| Rivals/AI | Gameplay | Technical | Check spacing, paid pressure and usable responses before behavior changes |
| Progression/learning | Gameplay | Experience | Earn, equip, use, choose next; reuse existing Range and three lessons |
| World/Garden/visual depth | Experience | Gameplay + Root | District wall facade/material/parapet variation inside truthful cover footprints; no added per-frame draw count |
| Animation/audio | Experience | Gameplay | Readable moving poses, ground/height contact and bounded sound hierarchy |
| Menus/accessibility/dev tools | Gameplay | Experience + Technical | Compact independent camera control; preserve navigation/remaps and readable layouts |
| Architecture/assets | Technical | Experience | Narrow lifecycle seams and dependency checks; avoid broad rewrites |
| Networking/save recovery | Technical | Gameplay | Actual two-peer and earned-save/recovery acceptance remain explicit |
| Documentation/CI/cleanup/launcher | Root + Technical | Experience | Correct active status, add omitted regression suites, remove proven redundancy and fix desktop target |

## Current batch

- [x] Implement and cross-review camera preference/menu/migration; execution gates below.
- [x] Implement and cross-review district wall depth within current collision bounds; native gate below.
- [x] Implement and cross-review Range status durations and earned signature guidance.
- [x] Correct CI regression inventory with bounded shards and exact selection checks.
- [x] Verify desktop shortcut and standard launch route; preserve original shortcut.
- [x] Consolidate current docs and remove five independently reviewed disposable caches.
- [x] Freeze p61-64590c45c7a5; focused checks, native parity and Full passed.
- [x] Independently inspect native texture, wallrun, settings and architecture comparisons.
- [x] Profile B source CPU diagnostic admitted for 6459: Garden/Fire/Mantle p95 73.910/117.084/110.507 ms, including full observer. Attempt A expired before Start; portable FPS remains open.
- [x] [Withdraw the occupied-membership shortcut](../docs/performance-evidence-20261014/occupied-membership/README.md): correctness passed, all eight primary cost gates failed; never applied. The experiment made no canonical change.
- [x] [Withdraw duplicate ground-speed projection reuse](../docs/performance-evidence-20261014/movement-ground-speed/README.md): correctness passed; the reverse run missed both benefit thresholds. No idle/Mantle expansion or application.
- [x] [Complete Garden attribution](../docs/performance-evidence-20261014/garden-attribution/README.md): four native passes, warm geometry reused; sparse phase captures are not continuously drawn lifecycle proof.
- [x] [Withdraw Low Garden marker-budget preparation](../docs/performance-evidence-20261014/garden-sample-budget/README.md): continuous three-cycle correctness passed; both normal-effect cost gates failed and ordinary draws regressed. No reduced expansion or application.
- [x] [Complete casting-stage attribution](../docs/performance-evidence-20261014/casting-stage-attribution/README.md): four native Fire/Mantle processes; movement is the largest ordinary-step child. This is attribution, not a measured optimization.
- [x] [Retain and integrate the stationary ground-velocity change](../docs/performance-evidence-20261014/stationary-ground/README.md): all eight paid-case benefit gates passed across four native processes; movement negatives and isolated tails remain explicit. Root applied six runtime lines and the reviewed 96-line behavior regression; both peers confirmed exact measured-code equivalence.
- [x] [Qualify **p61-d6d1bfb9c529**](../docs/performance-evidence-20261014/stationary-qualification-d6d1/README.md): 1,693 frozen inputs; Full 265 suites / 7,574,524 assertions, zero failures/error output and 120 Hz boot. Package, all 18 portable checks, 133-image terrain, five lifecycle cases and 4,076 independent delivery checks passed. The normal launcher now selects d6d1; the immediate 6459 fallback is preserved. Current-build foreground performance remains unmeasured.
- [x] [Withdraw Low-detail Conflagration decoration grouping](../docs/performance-evidence-20261014/conflagration-decoration-coalescing/README.md): both native correctness runs and captured readability passed, but three of four primary cost gates failed and one-field drawing repeatedly regressed. No canonical renderer change or additional variant.
- [ ] Next measurement after qualification: compare existing Full/Light observers on the same 15-second sustained Fire route, in opposite orders. Keep focus, Low/1280x720/60 cap, campus mode and memory context matched; report actual ticks, paid admissions and effect coverage. Full's reported observer head/tail excludes instrumentation inside simulation/drawing, and its wall denominator includes endpoint summary work. Disabled ordinary-play guards passed two-agent source audit; neither observer mode establishes portable FPS.
- [x] The 6459 Full, portable export, archive and isolated exported-terrain checks passed.
- [x] The 6459 desktop-wrapper lifecycle and final independent delivery review passed; 7804 remains preserved.

## Optional expansion boundary

The user specifically added environment variety/depth. The broader optional
three-district mini-campaign, mastery trials, replay viewer and cooperative
encounters remain separate expansion scope. Do not silently add every proposed
mode while implementing the approved improvement pass.

## Historical evidence

The previous queue's completed narrative is retained in Git at **38f1bc3** and
in the [October 13 checkpoint ledger](../docs/iteration-20261013/README.md).
The [resume](HEX-RESUME.md) owns current delivery and acceptance limits;
[SPECIFICATION.md](../SPECIFICATION.md) owns rules and
[CORE-GAME-DESIGN.md](../docs/CORE-GAME-DESIGN.md) owns feature intent.
Withdrawn caches, prefix keys and trail preflights must not be revived without
new measurements. Continued work is authorized until **20,000 credits remain** (57,349 recorded at resume). This replaces the earlier 1% cutoff and no-paid-credit restriction. Check the balance at phase boundaries and reserve enough to stop at a coherent checkpoint.

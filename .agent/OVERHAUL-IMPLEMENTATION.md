# H.E.X. single implementation queue

Status updated **October 16, 2026**: **ACTIVE PRODUCT IMPLEMENTATION; stop before 20,000 credits remain.**
Active playable profiles: 30.
The user resumed work after the Git handoff and authorized deep product analysis
and implementation with creative freedom. Work is isolated on
`codex/hex-breakthrough-20261015`, based on `aec900a`. The original presentation
branch remains the published [Linux handoff](LINUX-HANDOFF.md) checkpoint.
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
baseline and Stage B integrated pilot for the later illustrated overhaul; this file
remains the only active task ledger.

## October 15 product loop

The [breakthrough assessment](../docs/BREAKTHROUGH-ASSESSMENT-20261015.md) identifies
the central product hypothesis: read a rival, earn its signature, and use it in
the next encounter. Broad content expansion is secondary to a coherent playable
slice and current performance evidence. Commercial demand remains untested.

| Work | Owner / independent reviewers | Gate |
|---|---|---|
| Optional three-rival Circuit and result surface | Gameplay / Experience + Technical | Real paid victories only; explicit next/retry/leave; compact mouse/controller/keyboard access |
| Controller integration and temporary learned-spell reuse | Root / Gameplay + Technical | Actual admission, paid reuse, save/exit recovery and normal weave restoration |
| First-menu route and compact-map overlap | Experience / Technical + Root | No hidden tool/input regression; 960×540 at 200% layout and hit targets |
| Launcher Full/Light selector | Technical / Experience + Root | Honor downstream observer admission; label differing evidence coverage |
| Product priorities, documentation and verification | Root / all three | Current/proposed and source/package/human evidence remain distinct |

- [x] Source audits and primary-reference research; three specialists review each other.
- [x] Implement the Circuit, navigation/map repair and observer selector.
- [x] Record candidate **p61-6618873387e2**, 3,450 runtime records, and preserve qualified d6d1 selection.
- [x] Record initial Circuit focused **548 / 0**, map **1,403 / 0** within an earlier failed overall run, and eight prepared native UI captures; [evidence and limits](../docs/breakthrough-evidence-20261015/README.md).
- [x] Preserve the failed local [Full-a](../docs/breakthrough-evidence-20261015/full-a/tests.json): **112 / 267** suites completed, **5,280,932** assertions, **nine failures**, **2,700-second timeout**; 155 suites incomplete and boot not run. The later clean CI pass does not retroactively pass it or establish the historical capture cause.
- [x] Seven-suite `focused-review-a` passed **65,133 assertions / zero failures and stderr**, **264,217 ms**, after the reviewed test-only changes. Tools **58,514 / 0** and Circuit integration **314 / 0** cover the repaired menu route and global InputMap teardown. The seven suites exclude the failing eight-player network scenario; no production network fix is established. Runtime identity is unchanged.
- [x] Record local outage diagnostics [A](../docs/breakthrough-evidence-20261015/network-outage-a/independent-review.json) **6,478 / 0** and [B](../docs/breakthrough-evidence-20261015/network-outage-b/independent-review.json) **6,465 / 0**, each with **241 trace rows** and no rejected capture reproduced. Different receive-check totals do not prove identical trajectories; the historical cause remains unresolved.
- [x] Push candidate source checkpoint [932f597](https://github.com/generalgroovy/hex/commit/932f597) on `codex/hex-breakthrough-20261015`.
- [x] Complete clean Windows source Full at **932f5974fe17a8d2432d8f82873eb86faf564543**: [CI 38817305452](https://github.com/generalgroovy/hex/actions/runs/38817305452) passed **267 suites / 7,576,123 assertions / zero failures**, three empty stderr files and correct **661887 / 120 Hz / protocol 61** boot; [independent review](../docs/breakthrough-evidence-20261015/ci-full-38817305452/independent-review.json). All signature and network-impairment suites pass.
- [ ] Qualify a replacement candidate package through its own package/archive, terrain, launcher lifecycle and independent delivery gates before promotion. Clean CI validates source correctness; desktop Play remains d6d1.
- [ ] Complete the narrow Circuit process-reopen gate below before claiming durable normal-launcher Circuit recovery.
- [ ] Compare current-source Full/Light observers on matched 15-second paid workloads,
  reversing observer order. Keep focus, Low/1280×720/60 cap, campus mode, memory,
  actual ticks, paid admissions and effect coverage explicit. Compare common
  metrics only: Light omits full completed-step attribution and detailed draw
  diagnostics. Neither observer establishes portable FPS. The Light attempt
  expired before manual Start (armed=false, empty results), producing no
  gameplay measurement. Other Codex tasks were running; they do not establish
  the missed-Start cause. No automatic restart or new availability request.
- [ ] Obtain current packaged performance and unfamiliar-player evidence before claiming smoothness or product success.

Qualified playable build: **p61-d6d1bfb9c529**. Full passed 265 suites /
7,574,524 assertions; package/archive, 133-image terrain, all five desktop-wrapper
lifecycle cases and the **4,076-check** [independent delivery review](../docs/performance-evidence-20261014/stationary-qualification-d6d1/delivery-review/review.json) passed.
Preserve **6459** as the immediate fallback, with 7804 and older builds intact.
Current-build foreground performance and portable FPS remain unmeasured.
The [previous-build 6459 source performance review](../docs/performance-evidence-20261014/foreground-6459-b/review.json)
retains Profile B; its measurements do not transfer to d6d1. Root alone runs engines,
imports, tests, captures and exports.

## Next five player-facing investments

The clean Windows source Full gate has passed. Candidate delivery and player
acceptance remain open. These are ordered next investments, not five simultaneous
implementations or proof of commercial appeal.

| Rank / kind | Concrete player benefit | Evidence and dependency | Acceptance / owner + reviewer |
|---|---|---|---|
| 1 — Improvement | Make an earned spell a useful optional next-fight choice | Payment/release is proven; tactical usefulness is not. Reuse one existing rival situation, ordinary Next and the learned option. | Player explains and demonstrates a benefit/tradeoff without a forced loadout or unproved buff. Gameplay / Experience |
| 2 — Improvement | Understand the first fight without coaching | First-menu placement and result-panel fit are implemented; entry still begins the current countdown. Observe one unaided launch→fight→result journey before changing teaching. | Player identifies the goal, one tell and a response; change only observed ambiguity using existing lesson information. Experience / Gameplay |
| 3 — Improvement | Smooth paid casting, Garden and travel | Current packaged frame pacing is unmeasured. Establish common-metric Full/Light and presented-frame evidence before optimizing or adding art cost. | Repeatable whole-workload tails, authority parity and memory limits; no isolated microbenchmark presented as FPS. Root + Technical / Experience |
| 4 — Improvement | One coherent hero/rival illustrated action pilot | Current art retains directional/action fallbacks. Prove one pair before three anatomy sets or the roster. | Readable locomotion, turns, windup/release/recovery, jump/landing and hit response at play scale; pivots/clocks/residency within budget. Experience / Gameplay + Technical |
| 5 — Expansion | One purposeful tall courtyard/interior | New playable space, not a facade repaint. Depends on approved largest-body scale, collision/door, visibility and residency contracts. | Room changes a route or encounter; self stays visible without revealing hidden opponents. Experience + Gameplay / Technical |

Small optional copy polish for a later separately validated source change: display
`casts started` instead of `paid casts`, and `including countdown` instead of
`including ready time`. Keep temporary slot 1, saved-weave, persistence and
recovery distinctions. No runtime copy change is included in this checkpoint.

### Narrow Circuit process-reopen gate

Existing signature-progression coverage already includes three real paid lesson
victories, disk save plus fresh Progress reload per win, and paid release of each
loaded reward; recovery has separate coverage. The new Circuit integration is
memory-only. The remaining gate is one normal-launcher journey on the same
isolated profile: normal startup → saved first Circuit win → learned-next paid
release → normal close while the temporary weave is active → fresh-process
reopen. Verify earned progress persists, the ordinary weave is unchanged,
Circuit is idle, no reward duplicates, and ordinary paid reuse succeeds. This
specific path is untested; no source bug or new generic save framework is implied.

## Ownership: delivered capability versus remaining acceptance

This matrix preserves domain coverage, not a second parallel feature queue.
Root integrates and serializes engines; each change has an independent reviewer.
October 14 delivered capabilities remain in qualified d6d1. October 15 Circuit,
map and observer-selector changes passed clean Windows Full but remain source
candidate work without a replacement package or promotion.

| Point | Owner / reviewer | Existing capability | Remaining concrete acceptance |
|---|---|---|---|
| Casting/Garden performance | Root + Technical / Experience | Stationary optimization qualified; rejected renderer trials preserved | Current-build whole-workload frame tails and common Full/Light metrics |
| Loading/memory | Technical / Root + Experience | Bounded body/terrain residency and owned shutdown | Repeated travel/cancel/close plateau under measured actual memory |
| Movement/control/camera | Gameplay / Technical | Camera look-ahead setting/migration and reduced-motion independence delivered | Unaided movement response and physical controller combinations; no reimplementation of the setting |
| Defense/readability | Gameplay / Experience | Protection, height and cover outcomes exist | Read and use those outcomes in the selected rival situation |
| Spell delivery/chemistry/statuses | Gameplay / Technical + Experience | Eight deliveries, mixtures and Range status observations exist | Useful paid alternatives and finite follow-up comparisons; no catalog growth as proof |
| Characters/rivals | Gameplay / Experience + Technical | Existing identities, passives and three lesson rivals | One natural passive benefit and one authored hero/rival action pilot before roster expansion |
| Progression/learning | Gameplay / Experience | Earned reuse guidance delivered; Circuit route is candidate | Useful choice, first-fight comprehension and the specific process-reopen gate above |
| World/depth | Experience / Gameplay + Technical | Six wall treatments and two taller masonry facades delivered within existing footprints | One new useful tall room/courtyard with truthful collision and visibility, not all interiors claimed complete |
| Animation/audio | Experience / Gameplay | Existing animation fallback and bounded audio lifecycle | Authored action pilot, readable threat/release/hit hierarchy and separate listening acceptance |
| Menus/accessibility | Experience / Gameplay + Technical | Camera/text settings delivered; Circuit discovery and compact-map fix are candidate | Unaided route and real remapped/pad/pointer access at supported scales |
| Networking/save recovery | Technical / Gameplay | Existing protocol, save/reload and recovery tests | Historical capture cause remains unexplained; replacement delivery, actual two-device acceptance and narrow Circuit reopen remain separate |
| Documentation/CI/launcher | Root + Technical / Experience | Desktop route and prior CI inventory delivered; Full/Light selector is candidate | Exact terminal receipts, correct branch/qualification status and pending measurement; no pointer promotion from a subset |

## Qualified October 14 history

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
- [x] Record the next matched-observer measurement method, now carried forward into the active product-loop gates above. Full's reported observer head/tail excludes instrumentation inside simulation/drawing, and its wall denominator includes endpoint summary work. Disabled ordinary-play guards passed two-agent source audit; no current portable FPS claim follows.
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

# Breakthrough pass: technical audit and implementation priorities

Date: 2026-10-15. Baseline inspected: commit `aec900adeea74bc9c16bb5807ef8758d73696edb`, clean at the start of this pass. Qualified runtime remains `p61-d6d1bfb9c529`. This is a technical audit, not a new performance or Linux qualification. Root owns engine execution, integration and delivery. The 20,000-credit floor and launcher-only player sessions remain in force.

## Recommendation to the integration owner

The next useful build should make an existing interesting activity easy to start, finish and repeat, while retaining control responsiveness. The best immediate implementation combination is the peers' goal-led navigation/map repair and a bounded Circuit over the existing earned-signature encounters. It can turn existing systems into a coherent player session without another combat engine, save schema, giant art batch or renderer replacement.

The highest-value technical support is a measurable performance baseline, explicit encounter/asset ownership, and a real new-player package journey. The previous optimization cycle established several things that *do not* produce a worthwhile win. Those negative results should save work now.

No source inspection can establish an indie hit. The falsifiable product question is whether unfamiliar players understand the next action, enjoy the consequence, and voluntarily start another encounter. Automated assertions establish the safety of that experiment; they do not answer the product question.

## Current facts and their limits

| Area | Current source/evidence | Implication |
|---|---|---|
| Current frame pacing | `docs/current-delivery.json` says `current_build_not_measured`; qualified d6d1 Full is 265 suites / 7,574,524 assertions, with package, terrain and lifecycle gates | Safe local candidate, not demonstrated smooth play |
| Historical frame diagnostic | `docs/performance-evidence-20261014/foreground-6459-b/` measured source with the full observer and substantial host-memory pressure | Do not transfer its frame times to d6d1, call them portable FPS, or infer a regression from unmatched older runs |
| Casting stage | `docs/performance-evidence-20261014/casting-stage-attribution/README.md` records about 1.06-1.18 ms isolated plain steps after the first four rows; movement was the largest observed child | This justified the now-qualified stationary branch. It is not an additional current optimization opportunity or a whole-frame share |
| Garden | `src/presentation/element_garden_surface.gd:27` retains geometry by court/revisions/material and refreshes phase/style independently. The native attribution archive shows warm reuse | More geometry or style caching is not justified by the old inclusive prepare bucket |
| Rejected changes | Occupied membership, duplicated ground-speed lookup reuse, Garden sample reduction and Conflagration decoration grouping all have preserved failures of their predeclared cost gates | Do not reintroduce them under new names. A changed workload or mechanism must justify a new experiment |
| Full/light measurement | `scripts/profile-gameplay.ps1:11` already accepts `LightObserver`; the previous `launch-hex.ps1` Profile branch did not forward it | A narrow launcher option closes a concrete prerequisite without changing runtime |
| Body art | `pixel_flipbook_presenter.gd:13-29` has two walking contacts, reused neutral beats, explicit rigid fallbacks and incomplete strafe/backward art | Interpolation cannot replace missing authored motion. Art completeness is a player-facing limitation |
| Residency | `pixel_flipbook_presenter.gd:159` caps requested body pages at 15; `pixel_action_bank.gd` separately retains the requested action pages; terrain has bounded owners/uploads | Existing admission/lifetime controls are valuable. There is no demonstrated general leak to fix by speculative caching or prefetch |
| Linux | Existing `scripts/run.sh`, `doctor.sh`, `test.sh` and installer are stored CRLF and mode 100644; the toolchain file pins Godot 4.7.1 | A pull is a source handoff, not a runnable or qualified Linux release. Repair and validate that platform separately |

## Authorized implementation in this pass: observer selection

Root authorized only this technical script change during the audit:

- `scripts/launch-hex.ps1`: optional `-LightObserver`, admitted only in Profile mode. Default Full is unchanged. The same fixed Low, 1280x720, 60 cap, 15-second Garden/sustained Fire/sustained Mantle route remains selected. Light forwards the existing profiler switch and omits `AllFixedSteps`, which the producer explicitly forbids in Light mode. Inspect reports both the observer and whether complete-step attribution is enabled; the normal qualified portable selection is unchanged.
- `scripts/test-launcher-profile.ps1`: pure invocation-construction and actual Inspect admission controls. It checks fixed arguments, shared workload settings, default behavior, other-mode rejection including explicit-false selectors, Lifecycle exclusion and arbitrary game-argument exclusion. It also evaluates the actual producer's two observer-admission statements without executing setup or an engine, proving the selected arguments satisfy its contract.
- 36 pure assertions passed; no engine, profile, package or new runtime measurement was executed. Experience found the initially incompatible Light-plus-AllFixedSteps combination, then independently approved the corrected exact source. Root owns the CI hook.

The implementation exposes a measurement choice. It does not reduce ordinary-play work or prove a speedup.

## Performance decision contract

1. Run the existing full/light source observations through the same desktop front door, with opposite process orders. Match source, settings, viewport, foreground admission and route. Report shared actual tick, paid-admission and frame/process/draw metrics plus available memory endpoints and outliers. Light deliberately omits complete-step cumulative-stage attribution, detailed draw/Garden/terrain timing and some paid-coverage/memory diagnostics; absent fields are unmeasured, not zero. Compare equivalent phases using available shared evidence, not only two averages with different simulation progress.
2. Treat this as observer calibration. Full's head/tail observer counter excludes instrumentation inside drawing/simulation; its endpoint wall denominator includes summary work. Neither variant is packaged-game presented-frame latency.
3. Separately establish ordinary packaged play on the user's machine through the qualified launcher. Preserve input settings, recording/power conditions and available-memory context. Record loading, walking, repeated paid casting, Garden entry/exit and menus. A native capture or external presentation tool must identify its scope; engine callbacks are not automatically display presents.
4. Choose the largest reproducible player-visible limitation. If the whole-frame problem is memory pressure or graphics submission, another microsecond simulation optimization is the wrong intervention. If cold arrival dominates, focus on staged work and loading feedback rather than steady-state draw caching.
5. Require a useful whole-workload gain and preserved tails/authority; retain raw order/phase strata. The earlier failed trials are evidence that local call-count reduction alone is insufficient.

Godot's official optimization guidance separates steady slow frames, intermittent stalls and loading delays, recommends measured bottlenecks, and notes that CPU-only improvement cannot remove a GPU bottleneck. This supports the method above; it supplies no H.E.X. timing target. Source: https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html

**Proposed acceptance, not an achieved result:** aim for stable 60 Hz presentation at the selected Low resolution on the target machine; report p50/p95/p99 and long-frame counts rather than average FPS alone. If the machine cannot meet that target, explicitly select a stable lower cap/quality contract after observing it. Never lower authoritative tick rate, skip payment/status updates or fabricate dropped-time explanations to meet a display target.

## Memory, animation and loading: bounded design

Current logical atlas arithmetic is straightforward: a 1024x512 RGBA8 bank is 2 MiB without mipmaps. One cast plus one action bank is 4 MiB per character; 30 complete registered pairs would be 120 MiB, while 15 admitted IDs with both banks would be a 60 MiB logical payload upper-bound case. Actual requested/action-page admission can be a subset. These figures are not measured RSS or GPU residency: portraits, temporary Image copies, uploads, allocator retention and driver storage are additional.

The selected illustrated-sprite overhaul should first finish one authored action cycle on one character, then validate its production rules on three representative anatomies. A naive 12 motions x 8 directions x 8 frames x 128x128 x 4-byte atlas set is 48 MiB per character, 144 MiB for three and about 1.406 GiB for 30. Doubling each dimension multiplies that by four. Do not accept this expansion merely because PNGs are small on disk. Compare trimmed sprite pages, bounded clip residency, and 2D skeletal or offline rig-baked art over the unchanged planar authority. Confirm silhouette, pivots, hand/foot contact, diagonal movement and asymmetric actions before producing the roster.

Godot documents that lossless and lossy image storage do not provide the same VRAM saving as GPU compression, that GPU compression can damage low-resolution 2D art, and that mipmaps add memory. Recommendation: define compression/import policy per asset family, verify it on the selected renderer and inspect actual output; do not globally compress the existing pixel bank or switch renderer to make a spreadsheet budget appear satisfied. Source: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html

Concrete startup hypothesis worth measuring, not yet a proven defect: `pixel_flipbook_presenter.gd:56-64` validates every registered page and extracts portraits during bounded startup; `_load_page:151-156` reads uncached pages and `_page_error` reads pixel images. Action-bank admission performs its own validation. This is bounded and defensive, but the full initial pass can still be an observable cold-start cost. If measured startup is unacceptable, use the existing loading/input quarantine to stage identical page checks with bounded work and publish only a complete valid owner. Do not skip integrity checks or perform texture creation in a worker as an unreviewed shortcut.

Retain `wellspring_terrain_stream.gd:11-18` limits: 132 chunks, base residency 24, two pending owners, two uploads and the caller's elapsed pump budget. `wellspring_async_terrain_stream.gd` owns worker joins and detached bytes; worker elapsed remains separate from main elapsed. Neither logical cache bytes nor the 2 ms nominal pump interval is a hard whole-frame/RSS guarantee.

Meaningful residency acceptance: cold start, repeated travel between opposite districts, cancel during arrival, menu/focus interruption, roster changes and normal close. Check required textures, owner/task drainage, stale-generation refusal, resident counts and post-cycle memory trend. A one-time high-water mark is not a leak. Preserve a prior qualified package for rollback.

## Concrete integration review: Circuit and navigation

Gameplay's candidate reuses `SignatureChallengeSession` and the three authored lessons. `signature_challenge_session.gd:102-118` already observes terminal state once, carries developer taint and delegates a real victory to progression. `element_expansion_controller.gd:370` owns challenge launch and replaces the world. A Circuit coordinator must consume that result; it must not invent a victory, reward, mana refill or second authority engine.

Required coordinator contracts:

- Bounded run/leg/attempt identifiers; duplicate observations do not advance twice.
- Retry is a new attempt; abort and failed admission do not become a victory.
- Existing challenge code owns finite payment, result freeze and reward eligibility; existing progression code owns disk persistence. A save failure is displayed honestly and is not silently upgraded to a durable reward.
- Fresh encounter resets are explicit. Three fresh trials do not imply a continuous shared resource pool.
- Keep one current world, renderer, audio/input owner and session. Return/menu/focus paths must leave no stale coordinator reference acting on a later world.
- Use the current meaningful session/trial/recovery tests and add coordinator transition cases. Do not inflate the test suite with copies of source conditions.

Experience's compact map/navigation proposal has high confidence as a usability repair. One computed logical content rectangle should drive draw, hit targets and focus navigation; no separately tuned visual and input coordinates. Preserve a route to current tools even when the first page becomes goal-led. Check 960/1280 viewports, 100/200% text, keyboard/pad/pointer, remapped convenience keys, error/empty states and menu exit quarantine. Existing `test_wellspring_map.gd` and `test_local_navigation.gd` are the natural homes.

The exact navigation/map, Circuit model/panel and controller integration source checkpoints passed independent technical review. The integration suite steps the three real encounters and observes prior-earned local payment/release, duplicate callbacks, unsaved status, temporary weave isolation, Range/leave and retry. Execution remains the root gate. Their player-value claim needs a new-player observation, not only a geometry assertion or a coordinator unit test.

## Shipping, saves, network and player evidence

The current local package has strong controlled evidence: export/source identity, terrain, exact paid lifecycle and normal close/reopen. Git contains evidence rather than EXE/PCK/ZIP payloads. The desktop wrapper points to a local export; it is not an installer or a publicly hosted distribution path.

For the first coherent new loop, prepare a separately versioned candidate with one obvious launch route, offline defaults, readable missing/corrupt-package failure and no silent source fallback. Test on a clean user profile outside the development checkout, without Godot or Python on PATH. Include actual save-earned progress, exit, reload, recovery and remapping; the prior preferences-only lifecycle boundary does not prove every earned-save journey. Root keeps the current d6d1 pointer until the new candidate passes its own gates.

Linux repair is a small separate delivery task: normalize only shell helpers and sourced toolchain text to LF, set deliberate executable bits, inspect the pinned installer/doctor/test contract, then establish a Linux launcher with the same presentation defaults. This changes tooling, not gameplay authority, but still needs actual Linux execution. Do not infer cross-platform support from historical FLUX scripts or a Windows Full pass.

For multiplayer, retain strict snapshots, actor authority and existing impairment tests, then perform a real two-device route: paid cast before/after disconnect/resume, duplicate admission/release refusal, focus/menu quarantine and state continuation. A new Circuit should remain explicitly offline unless its coordinator ownership and admission have been designed for network sessions. Do not expand the packet schema merely for presentation clip metadata.

For player evidence, select a small unfamiliar-player pilot: launch unaided, identify the goal, finish or deliberately abort one encounter, understand the result, equip/use an earned signature, and choose whether to start another. Record where help was necessary and what was misunderstood. Target numbers are product hypotheses, not proof of commercial success. Keep automated receipt counts, human usability, performance, multiplayer and distribution states separate.

Steam's official Playtest facility uses a separate associated application, and developers remain responsible for collecting feedback. That is a possible later controlled-distribution channel, not a reason to publish now or assume an account/store readiness. The immediate test can remain a private build; ask for targeted player feedback rather than promising that a larger content catalogue is a retention strategy. Source: https://partner.steamgames.com/doc/features/playtest

## Priority and stop criteria

| Priority | Work | Acceptance / stop |
|---|---|---|
| P0 | Goal-led navigation/map and existing-encounter Circuit | No unreachable controls or double rewards; fresh player understands next action and result; no false carry/save claim |
| P0 | Observer selector and matched measurement | Pure admission/invocation checks, then real launcher-driven matched observations; no runtime performance claim from the script change |
| P1 | One complete illustrated motion slice | One character/action-cycle proves the pipeline, then three anatomies with clear pivots/contacts and bounded resident art; reject naive atlas expansion if it exceeds the agreed machine budget |
| P1 | Cold-start/arrival staging if measured necessary | Same validation/pixels/ownership, responsive honest loading, no later stalls or retained-owner growth |
| P1 | Clean-profile package and Linux launch path | Real platform first-run/save/reopen/control evidence; current qualified Windows pointer preserved until replacement qualifies |
| Defer | Broad renderer switch, new cache families, full roster generation, all interiors, new networked run mode | Only after the integrated loop and actual bottleneck justify the cost |

No more small optimization variants should precede a player-visible reason and a current measurement. The successful stationary optimization is already integrated; the next build should demonstrate a more coherent game, not just another microbenchmark.

## Review record

Technical sent independent constraints to Gameplay for Circuit lifecycle/reward authority and to Experience for navigation/map geometry, input access and asset economics, then approved the exact navigation/map, Circuit model/panel and controller integration source checkpoints. Technical also reviewed Experience's draft and the root assessment, preserving the source-versus-player-evidence boundaries. Gameplay approved this technical draft's authority and measurement scope. Experience approved its art/input/delivery scope and the corrected launcher contract after finding the initial producer incompatibility. The checks above describe only pure source tooling; root integrates and runs all engine-dependent gates. This draft does not authorize parallel engines, package promotion or credit-floor bypass.

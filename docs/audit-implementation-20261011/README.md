# H.E.X. audit implementation — October 11–12, 2026

This is the implementation and qualification record for the local changes after
`791b00a` on `codex/hex-screen-smoothness-20261011`. The earlier presentation
checkpoint and the October 10 portable remain separate, preserved evidence.

## Scope and review

Three specialist agents implemented gameplay, experience and performance in
parallel. Each reviewed another agent's changes. Root owned integration,
network/save repairs, CI, and serialized every Godot process. Existing dirty
documentation and original assets were preserved. No paid asset generation or
external service purchases were made.

Cross-review covered actual command payment and damage ownership, whole-tick
perk promises, compact-panel pointer routes, cache invalidation and exact pixel
coverage. Independent reviewers also checked both Full-test repairs: all eleven
renderer counters must first be populated, and the map test permits only eight
separately asserted course-metadata changes before checking the original map
hash. The final release review requires exact package identities, preserved
fallback payload checksums and honest focus/cast-count limits on measurements.
The [review summary](review-summary-final.json) records this coverage and the
two corrected documentation findings. The previous portable's
[nine payload checksums](fallback-payload-final.json) still match its manifest.
The [final handoff checks](final-handoff-checks.json) record documentation,
PowerShell syntax and frozen-source verification. The
[evidence inventory](evidence-inventory.json) records each retained file's size
and SHA-256; it verifies file identity, not the quality of the underlying claim.

| Audit area | Implemented change | Verification boundary |
|---|---|---|
| Release and CI | Full and Release share a 1,800-second complete-suite watchdog; pull requests run pinned-engine Fast plus focused checks; manual/main runs Full | Local checks do not claim a GitHub run or publication |
| Rendering | Bounded immutable terrain-outline and warning-geometry reuse; HUD layout, text metrics and input-label preparation retained with exact invalidation | Dynamic danger, authority and resource state remain fresh; native timings below own any speed claim |
| Loading | Terrain pump stops starting work after its 2 ms budget; count/byte limits remain; bounded destination prefetch is canceled or replaced with menu intent | One indivisible validation/upload can still exceed the budget |
| Movement | Real paid movement-chain comparison, action-based district practice, clearer vulnerable recovery and consequence cues | Physical input feel remains a playtest question |
| Combat and AI | Eight delivery-specific rival pressure patterns, range decisions, committed aim, gaps, actual solid-face Rebound banks and direct-shot fallback | All attacks still use ordinary commands, costs and cooldowns |
| Perks | Startup/cooldown tradeoffs require both promised directions to survive 120 Hz quantization; contextual Loom timing explains suppressed pairs | No extra active buttons; all 21 race and 30 personal passives remain |
| Balance | All 504 spell diagnostics plus eight bounded paid experiments cover mixtures, twelve-slot rotations, moving targets and cover; direct/status/ground loss reconciles with Health | Six-second cast windows plus three-second drain are not sustainable DPS or a PvP ranking |
| Progression | Shared authoritative damage decoder counts paid ground-effect contributions to signature victories | Victory still requires an owned defeat event; bare Health mutation grants nothing |
| Teaching and world | Optional tactical continuation observes play; four district courses observe actual wall, braking, chain and recovery criteria | Courses grant no resources or automatic combat outcomes |
| UX and accessibility | Active-device prompts; 100/125/150% text; small-window reflow, pagination and pointer routes; consistent hit-test transforms | Native render checks are separate from human readability acceptance |
| Save recovery | Explicit Retry and Recover actions; invalid primary preserved before valid-backup restoration; pending legitimate progress merged | Oversized/unreadable preservation refuses safely; no automatic overwrite on inspection |
| Network admission | Five-second HELLO lease reclaims silent ENet peers; one bounded refusal-delivery grace cannot be renewed by malformed traffic | Local ENet tests do not prove Internet or physical two-PC performance |
| Project maintenance | Isolated helpers, targeted behavioral regressions, updated player/design/developer guides and one current queue | Historical evidence and working packages remain intact |

The six ingredients, 63 compositions, eight deliveries, 504 spells, twelve slots,
30 characters and paid 120 Hz simulation are retained. New controls, unbounded
effects, free casts and fabricated balance rankings were not required.

## Design precedents

The implementation applies these existing practices to H.E.X.'s measured and
tested problems; success in another game is a rationale to test, not proof that
H.E.X. has achieved the same player response.

- [Riot's League profiling](https://www.riotgames.com/en/news/profiling-real-world-performance-league)
  motivates representative workloads, tail latency and explicit machine/settings.
- [Factorio's retained drawing work](https://www.factorio.com/blog/post/fff-323)
  motivates retaining immutable preparation while invalidating changing state.
- [Titanfall's controls discussion](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right)
  supports learning movement through responsive, repeatable physical actions.
- [Enter the Gungeon's developer interview](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-)
  informs readable attack identities, burst gaps and distinct delivery behavior.
- [Mega Man 11's enemy-weapon loop](https://news.capcomusa.com/lets/browse/ready-mega-man-11-is-out-now)
  is the precedent for fighting, reading and earning a rival's signature.
- [League's clarity principles](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
  support distinguishing real danger, protection and vulnerable recovery.
- [Xbox text guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)
  informs explicit text sizing and reflow rather than shrinking dense panels.

## Qualification

The frozen candidate is **p60-d8e6ea1cd808**, Protocol 60 / SessionSnapshot 24,
with 3,412 canonical production records. The [source identity](source-identity.json)
records SHA-256 `d8e6ea1cd808ee4e43ca93fb45c1af414ba4f714df399e4b973ac76aaaccedf3`.
This is local work after `791b00a`; no commit, push or main merge was performed.

| Gate | Recorded result |
|---|---|
| Source and asset checks | Current-state and asset inventory passed; editor import and final identity Check passed |
| Final focused regressions | [17,785 assertions](final-focused.log): 41 recovery, 11,254 polygon-cache and 6,490 paid-field assertions; zero failures |
| Complete registry | [Clean Full rerun](full-final.json): **251 suites / 7,081,662 assertions**, zero failures and stderr, including import, identity checks and 120 Hz boot; [suite log](full-final.log), [import](full-import.log), [boot](full-boot.log). The [first failed attempt](full-first-failed.json) and its [log](full-first-failed.log) remain preserved |
| Full-test repairs | [167,991 assertions](full-repair-focused.log) passed across renderer reset and campus layout; all counters are populated before reset, and only eight separately asserted course-metadata changes normalize before the original full-map hash |
| Paid rendering | [614 exact RGBA comparisons](paid-pixels-final.json), including 176 real paid-sequence comparisons; zero mismatches |
| Interface fixtures | [64 native frames](native-ui/receipt.json), eight surfaces, two viewport sizes, 100/150% text and keyboard/controller presentation; pointer routes pass and world authority is unchanged |
| Character fixtures | [21 native images](native-character/receipt.json), all independently reviewed; tucked jumps, finite flight and protection/recovery distinctions remain visible |
| Profile admission regression | Twelve source-only assertions passed for dimensions, drift, payment and source stability; build-summary checks passed 45 assertions |
| Windows portable | [Fresh export and native boot](portable-package.json), [exact ZIP/payload verification](portable-delivery.json) and [executed PCK identity](portable-build-state.json) passed; **p60-d8e6ea1cd808**, 153.6 MiB ZIP; previous portable preserved |
| Exported terrain | [All 132 chunks and overview](terrain-pack.json) decoded exactly from the exported PCK; [isolated-copy provenance](terrain-pack-provenance.json) passed |
| Actual release executable | [Four normal-close runs](portable-measurement.json), each requesting close at 45 seconds, passed strict warning/stderr/identity checks; both paid cases recorded all twelve admitted casts and safe-close confirmations |

The UI and character fixtures precede the final edge-mask reuse and external-save
notice refinements. The final field pixel gate and recovery regression cover
those subsequent changes; the fixtures are not a human movement or readability
acceptance test. Gallery and Compendium still use fitted reference views.

The new local launcher is
`exports/hex-audit-overhaul-20261011/windows/PLAY-HEX.cmd`; the archive is
`exports/hex-audit-overhaul-20261011/HEX-p60-d8e6ea1cd808-Windows-x64.zip`.
These are local artifacts, excluded from Git. The archive SHA-256 is
`b4e75bc26f094f2e72e848c916d892606c93d91bba5b913f278e012c9b951790`.

The actual release's emitted one-second FPS samples averaged **59.82 at Hearth,
60.00 at Garden entry, 55.65 for finite Fire and 46.74 for finite all-six Mantle**.
All sampled visible windows were in the foreground. Fire's lowest one-second
sample was 31 FPS and Mantle's was 38 FPS. These are finite workloads with idle
periods, not sustained-casting, frame-present or input-latency acceptance.
Process wall time also contains startup/teardown that need not emit FPS samples.

The earlier [forced-exit measurement](portable-forced-exit-failed.json) failed:
Fire and Mantle completed their casts but reported seven and six audio objects
alive at shutdown. A [verbose reproduction](portable-forced-exit-verbose.log)
identified audio streams/playbacks. The unchanged executable then passed an
[independent normal-window-close probe](portable-window-close-probe.json) and
all four normal-close measurements. The measurement-only helper now supports
normal closing, requires all twelve cast events and retains strict errors and
watchdogs. This identifies an observed exit-path difference, not a proven engine
root cause or a reason to discard the failed results. Runtime bytes stayed fixed.

**No overall frame-time gain or consistent 60 FPS is established.** The
[native performance report](native-performance.md) and
[comparison data](native-performance-comparison.json) retain all three runs,
including unfavorable results and the final run's focus/memory/camera limits.
The final focused sustained-Mantle case measured 34.69 ms mean / 42.70 ms p95
process-start intervals. The 60 FPS budget is 16.67 ms; simulation advancement
near 120 Hz does not establish smooth displayed frames.

The native baseline at `p60-33606f016138` requested 1280×720 but actually rendered
1290×730; its strict wrapper correctly failed. Those timings remain diagnostic.
The repaired profiler sets the window flags before its dimensions and validates
the actual viewport for every case. Comparisons must use the same actual size.
Exact copied wrapper receipts are retained for the [baseline](baseline-profile-wrapper.json),
[intermediate candidate](candidate-profile-wrapper.json) and
[final candidate](final-candidate-profile-wrapper.json). A wrapper's `measured`
status is not a continuous-focus or performance acceptance gate.

Failed checks are retained in `.godot/audit-overhaul-20261011/`, including the
initial baseline mismatch and integration repairs. A passing assertion summary
never overrides a script error or nonempty error log.

Complete authored movement cycles remain unfinished. Human movement/animation
feel, listening, balance, route comprehension and physical multiplayer still
require their own acceptance. A portable boot or a screenshot cannot substitute
for them.

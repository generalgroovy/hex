# H.E.X. contact efficiency and hazard clarity

Status: READY FOR LOCAL PLAYTEST; automated correctness/native/export gates passed.
Repository: `C:\Users\sende\Projects\hex`, origin `generalgroovy/hex`, base `1559a56`.
Build: `p56-fa6d17ce9f39`, 2,940 runtime records, protocol 56 / snapshot 22.

Open [PLAY-HEX.cmd](../exports/hex-contact-clarity-20260928/windows/PLAY-HEX.cmd),
or extract the complete [Windows portable ZIP](../exports/hex-contact-clarity-20260928/HEX-p56-fa6d17ce9f39-Windows-x64.zip)
and use its launcher. It enables all 30 detailed identity skins; keep EXE/PCK together.
This is local solo feedback, not a friends-ready installer or sustained 120 FPS release.

## Bounded execution contract

Improve the existing game before adding systems: measure dense combat, remove
redundant exact hex queries without changing any gameplay outcome, strengthen
Steam's visible harm cue, and fix the Spell Loom heading collision. Preserve all
dirty work, existing art, old builds, paid budgets, movement, reaction geometry,
event order, and source ownership. No trails, balance changes, new menus, network
claims, installer promotion, commits or pushes. Return one tested local portable
for feedback rather than starting another unbounded iteration.

The lead owns all engine runs, integration, profiling and packaging. One delegate
owns the product-effects helper and its oracle tests; a second owns Steam/Loom
presentation and their tests. All writers freeze before any engine run. Native
captures establish visible output, not human acceptance or frame-rate capacity.

## Decisions and evidence

| Work | Evidence / boundary |
|---|---|
| Profile before optimizing | Eight actual paid casters, first four elements and all four deliveries; 120 warmup + 720 measured ticks in each command order |
| Isolate effects cost | Diagnostic subclasses delegate unchanged behavior; nested collision time is part of the effects total, not additional time |
| Exact contact reuse | Only derived endpoint membership inside one pre-movement call or frozen post-movement sample; never cache across ticks, movement phases or changing height policy |
| Steam warning | Broader static outlined angular vents inside each real 24 px hex; identical warning geometry in normal/reduced effects; vapor and damage unchanged |
| Spell Loom | Short instruction line with actual-font bounds tests; no control/hit-target relocation |
| Determinism | Compare every measured tick's full authority and ordered events, plus canonical final hashes and finite-matter metrics |

The fresh instrumented baseline measured p95 **19.631 / 20.286 ms**, max
244.136 / 236.407 ms. The late effects phase averaged about 4.1–4.4 ms per tick
over its 120-tick block; nested collision pushes accounted for less than 5%.
These are diagnostic, machine-dependent results; no 120 Hz acceptance is implied.

The per-tick trace includes all hex cells/metadata, casts, products, counters,
exposure, flow carry, canonical player/projectile state and ordered events.
Native Variant encoding is insertion-order-sensitive and is test-only, never a
wire format or runtime hash. The initial full-JSON-per-tick diagnostic was stopped
after its first complete order because measurement overhead was excessive; its
partial log is retained and is not an acceptance receipt. A first attempted path
already existed and was safely rejected without replacing its evidence.

## Completion gates

| Gate | Status |
|---|---|
| Original-behavior helper oracles and targeted regression | PASSED; ten focused suites, then complete final regression |
| Matched before/after authority + event trace | PASSED; all 1,440 measured tick states/events and final canonical hashes match |
| Native Steam normal/reduced and Loom review | PASSED bounded visual review; 7 paid Steam + 16 directory/Loom frames, copied hashes verified |
| Full suite, import and boot | PASSED; 171 suites / 1,476,258 assertions, zero failures/stderr, 120 Hz initialization |
| Fresh identity, separate Windows export and safe close | PASSED; 30 skins admitted, PCK identity and isolated native safe-close verified |
| Dense simulation timing | FAILED; production-class p95 18.315 / 20.027 ms versus 8.333 ms |
| Human readability, feel and physical two-PC play | NOT RUN |

## What improved, and what did not

The matched instrumented late effects block used about 39–41% less time after
endpoint reuse. This is a component/block improvement, not a whole-game FPS claim.
The final production-class workload measured medians 5.919 / 5.914 ms, p95
18.315 / 20.027 ms and maxima 255.474 / 242.068 ms. Worst ticks remain unacceptable
for the target; attribute the expensive cast/contact stages next before choosing
another optimization. No damage, duration, movement, mana, size or reaction radius
was changed to obtain this result. See [fresh evidence](contact-clarity-evidence-20260928/README.md).

Steam's warm outlined vents are stronger at actual 75% zoom without covering the
tested actor; normal and reduced modes retain the same hazard marks. Its repeated
tile motif still needs art refinement and unfamiliar-player danger-recognition
testing. The Loom no longer overlaps its instruction/header, and filtering,
twelve-slot starter preview/cancel and selected parent return remain intact.
Stills do not prove fluid temporal animation or all-character readability.

## Short playtest

| Try | Assess |
|---|---|
| Academy door, Spell Loom, filter Fire; preview/cancel a starter weave | Clear headings, legible twelve-slot layout, unchanged weave after cancel, selected menu item on return |
| Equip Water and Fire Bolts, cast at the same nearby empty floor spot | Steam appears only on affected hexes and reads as harmful, not merely smoke |
| Cross Steam, leave it, compare normal/reduced effects | Actor stays readable; ground warnings remain visible; no flight residue or movement streaks return |
| Chain movement while casting in the practice areas | Existing controls/budgets feel intact; note any obvious hitch with the spell and location |

Previous playable fallback: `p56-ae1c09164b5b`,
`exports/hex-building-directories-20260928/windows/PLAY-HEX.cmd`.
Older retro builds, source art and dirty work remain. Historical
`docs/current-checkpoint.json` and installers stay unchanged. No commit, push,
publication or remote acceptance is implied. Only lead-owned engine runs were
used; native/export processes closed and isolated profiles left as test evidence.

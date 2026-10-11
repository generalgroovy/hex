# H.E.X. single implementation queue

Status: **PAUSED, October 11, 2026, at the user's request to pause and push at
the next best state.** Current branch: `codex/hex-screen-smoothness-20261011`;
source identity: **p60-33606f016138**. The
[presentation checkpoint](../docs/presentation-checkpoint-20261011/README.md)
records completed implementation, tests, cross-reviews and the remaining
qualification. No automatic continuation is authorized while paused.

## Historical completed performance/publication batch

The following completed queue belongs to the preceding **p60-be3efd332e1a**
source and its own portable, not the paused presentation checkpoint.

Status: **source maintenance and publication record, October 11, 2026.**
The gameplay/performance implementation and local qualification completed on
October 10. The October 11 request authorizes repository cleanup, documentation,
commit and push; [its record](../docs/source-publication-20261011/README.md) owns
that delivery evidence. Exact source and package identities
live in [the resume handoff](HEX-RESUME.md); rules live in
[the specification](../SPECIFICATION.md).

Active playable profiles: 30.

## Completed request

Implement the researched optimizations and measured additional improvements so
movement, casting and Element Garden run more smoothly on this PC. Preserve paid
combat, all six elements/63 compositions/504 spells, movement chains, collision,
visibility, statuses, progression, player profiles and the existing world.

## Implemented and reviewed

- Reuse Garden plots, material meshes, static Range stone and unchanged HUD geometry.
- Remove empty material work while preserving exact generic and dense API behavior.
- Retain exact paid-cell conversion, shared fills/layouts and Standard glow;
  skip only equivalent same-cell boundary work, with bounded original-path fallback.
- Bake exact terrain before play; bound background decode, uploads and residency;
  prepare offline arrivals; drain outstanding resource ownership on departure/exit.
- Keep tiny cast portraits available and large character pages within a residency budget.
- Batch opaque visibility terrain while preserving cover painter order.
- Remove measured idle simulation work with exact reference comparisons.
- Add compact Low/Standard and frame-limit settings through normal Menu navigation.
- Keep reproducible native and actual-portable diagnostics, separate from acceptance claims.

Three specialists and root reviewed the work and checked one another. Details,
primary engineering precedents and failed/corrected evidence are in
[the performance report](../docs/performance-implementation-20261010.md).

## Completed qualification

1. **Completed for p60-be3efd332e1a / 3,390 records:** import, source checks,
   154,856 focused assertions and 614 exact native pixel comparisons. Final native
   v3 completed 25 records / 18 warm rows, including nearby twelve-cast Fire,
   all-six Mantle and both sixty-second Garden loops, with an independent raw audit.
2. **Completed:** Full v5 passed 244 suites / 6,880,581 assertions, zero failures
   and zero stderr, followed by boot. [Receipt](../docs/performance-qualification-20261010/full-v5.json).
3. **Completed:** final export at `exports/hex-smooth-fields-20261010` passed native
   boot/pixel-bank admission/safe quit, **18 standalone checks** and exact **ten-entry
   ZIP/payload verification**. Its **2,062 terrain checks** decoded all 132 chunks
   plus the overview with exact pixel/provenance agreement. The d64 fallback's
   PCK/ZIP hashes remained unchanged. [Package](../docs/performance-qualification-20261010/package-final.json),
   [ZIP](../docs/performance-qualification-20261010/zip-verification-final.json),
   [terrain](../docs/performance-qualification-20261010/terrain-pack-final.json).
4. **Completed:** actual visible be3 EXE measured all four cases with unchanged
   hashes and empty stderr: Hearth mean **57.64 FPS**, Garden **59.00**, nearby
   twelve-Fire sequence **49.125**, all-six Mantle **38.714**. Both spell cases
   admitted twelve casts with zero refusals. Finite casting and post-expiry idle
   are included; these are engine FPS observations, not sustained 60 FPS or
   physical presentation. [Receipt](../docs/performance-qualification-20261010/portable-visible-final.json).
5. **Closed:** final gameplay evidence and measured limits are recorded. The
   October 11 source publication preserves that runtime and validates the
   repository and developer entrypoints separately.

Final source Mantle means were 28.17/27.58 ms (Low/Standard); close Fire means were
25.75/24.86 ms. Both Garden loops, Mantle and close Fire had no intervals above
50 ms, but Low distant Fire had seven. Finite close-Fire rows include post-expiry
idle and prior-case cache warming; these are not sustained 60 FPS results.
Cold startup/travel and the complete distributions remain in the report.
Intermediate p60-6980b3dcafec retains its own separate timing and pixel receipts.

First-pass p60-d649c4d1d99c already passed Full, native rendering and UI review,
portable export, all exported terrain checks and visible-window measurements.
Those historical results remain preserved. The final be3 source and package have
their own completed qualification above; the first-pass receipts are not reused.

## Separate product acceptance

| Topic | Evidence still needed before a stronger claim |
|---|---|
| Sustained frame pacing | Measured workload-specific tails, including heavy overlapping paid fields; a target setting is not an achieved frame rate |
| Movement and readability | Physical keyboard/controller play, continuous motion, smallest-window reading and listening |
| Learning, balance and fun | Human play across characters, movement, spell choices and rival counters |
| World wayfinding | Human exploration of all seven districts and comprehension of destinations |
| Multiplayer | Same-build two-PC and different-home trials; capacity and relay acceptance are separate |
| Publication | Explicit release scope and exact-source delivery qualification |

These boundaries do not create an endless automatic backlog. Earlier completed
expansion work and its failures remain in [the October 9 integration record](../docs/element-expansion-evidence-20261009/integration.md).
Keep inherited dirty work, original art, saves, failed receipts and working fallback
packages. Use included allowance and available free reset options before credits.

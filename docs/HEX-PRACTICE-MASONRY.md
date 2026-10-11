# Practice masonry and rendering attribution

Status: Full/native/Windows package gates passed, 2026-09-29; human feedback pending.
Source `p56-558bf72b754f`, protocol 56/schema 22, 2,946 canonical production records.

Open [PLAY-HEX.cmd](../exports/hex-practice-masonry-20260929/windows/PLAY-HEX.cmd)
or extract the [portable ZIP](../exports/hex-practice-masonry-20260929/HEX-p56-558bf72b754f-Windows-x64.zip)
(106,674,545 bytes). Keep EXE/PCK together. Quality-foundation is the retained
fallback. [Five-minute trial](HEX-PLAYTEST.md). No installer or delivery pointer
was promoted; no commit, push or publication.

## Bounded change

| Area | Implementation | Guardrail |
|---|---|---|
| Practice obstacles | Setup-rasterized stone caps, shaded south faces, continuous rim, clipped canonical hex joints | Exact existing collision rectangle; fully opaque corners; no overhang or invented cover |
| Room identity | Limestone for movement practice, cool slate for chain/sparring rooms, restrained moss on Cover Garden stone | Presentation only; no new surface physics, elemental state or interactive decoration |
| Drawing cost | One cached nearest-filtered texture per real obstacle; eight colors per family | No per-frame masonry generation; 15 textures / 363,776 decoded bytes (355.25 KiB) |
| Diagnostic maintenance | HUD profiling wrapper passes saved binding preferences; regular HUD suite compiles wrapper | No silently stale profiling API |
| Idle field rendering | After validated occupied membership is empty, skip material preparation and drawing on the normal campus | Clears prior cover state; checks actual membership each call; standalone court base and active fields unchanged |
| Rendering investigation | Frozen native attribution plus nested membership/frame-preparation/Water timers | Nested times are not added to parent totals; not GPU, moving gameplay or 120 Hz acceptance |

No movement, chemistry, affinity, hitbox, input, network or camera rules change.
All 30 existing skins and the previous animation refinements remain available.
The physical worldbone is still rectangular; canonical hex masonry is not a
collision migration. Original artwork and unrelated dirty work are preserved.

## Review

Three native 1280x720 production captures follow 24 ordinary movement ticks each:
Chain Courtyard, Cover Garden and Open Laboratory. All three were inspected at
the actual 75% game zoom. Stone reads above the floor without covering legal
space, saturating hazard colors or introducing new sprites/particles.

## Evidence and next decision

The first attribution attempt failed before measurement because its test-only
HUD override lacked the current preferences parameter. A repaired rerun passed
2,096 assertions and exact native original/disabled/enabled pixel controls.
The first Focused attempt also caught a new test's invalid static Script call;
the corrected guard constructs the RefCounted HUD wrapper instead.
Failed receipts remain distinct from the subsequent passing results.

Fresh timings and final release checks belong in the accompanying evidence
index. A rendering component timer identifies a cost centre, not the underlying
cause or a demonstrated optimization. Keep the next performance slice isolated
and prove output/authority equivalence before integration.

The native stress fixtures retain coverage even when active quantity is zero.
All four frame/state hashes remain exact across the early-exit change, but the
timing variation in those cases does not measure its benefit. A separate
zero-membership CPU diagnostic compares against the frozen previous draw body.
It measured p50/p95 **0.152/0.162 ms before**, **0.005/0.006 ms after** across 768
samples per arm, alternating order and both effects settings. This is a small
CPU saving on a genuinely empty field, not a 6 ms saving or an FPS result.
The new benchmark initially failed on a typed conditional-array assignment;
that owned diagnostic process was stopped, the test repaired, and rerun passed.

Full validation: **172 suites / 1,754,688 assertions**, zero failures/stderr;
import, post-import identity and configured 120 Hz boot. Native attribution:
2,096 assertions; four before/after image/state hashes and three room PNGs equal.
[Complete evidence](practice-masonry-evidence-20260929/README.md).

## Next performance slice, not implemented here

| Priority | Work | Acceptance |
|---|---|---|
| Active-field drawing | Separate region assembly, material dispatch and boundary/mark submission in a genuinely field-dense moving fixture | Same whole-cell coverage, phase/owner boundaries, native pixels and authority; no decorative-radius approximation |
| Moving full-body cost | Combine camera movement, turns, 30-skin admission and realistic simultaneous casting | CPU/GPU frame pacing and worst tails, not frozen default-actor timings |
| Snapshot/simulation | Continue sparse canonical state and contact-work reductions from prior evidence | Exact replay and wire compatibility before any timing claim |

The current rectangular wall footprint and 8-way controls remain unchanged.
Later geometry redesign is a separate authority/network migration, not an art fix.

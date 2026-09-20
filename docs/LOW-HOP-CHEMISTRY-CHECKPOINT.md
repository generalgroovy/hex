# Low-hop and first-grade chemistry playtest checkpoint

Historical September6 checkpoint. Its Q/V defaults and payload identity are not
current: see [README](../README.md#controls-and-movement) for Technique V /
Roll-Air Dodge Q and the latest local build. Original evidence below is retained.

Status: source-verified pause checkpoint; 81 suites / 165,441 assertions passed; human playtest requested.

2026-09-06; Windows source checkout on `main`; protocol **43**, snapshot **18**,
preferences **11**, deterministic simulation **120 Hz**. Previous rollback
checkpoint: `12a17de`. This source revision does not update an old installer.

## What to test

| Test | How | Expected result |
|---|---|---|
| Low jump | Tap / hold Jump (Space by default) while steering | About 22 / 28.9 px high; low projectiles pass beneath above 18 px; beams and area hazards still matter |
| Float | Release Jump, press it again in the air and hold | Holds current height, steers freely, visibly protected while paid; small 1.8 s, middle 1.5 s, large 1.2 s maximum |
| Air chain | Walljump, fresh airborne Jump for Float, then V with a direction | Independent allowances permit walljump -> Float -> air dash; wall touches cannot refill Float or dodge |
| Wallrun | Use Q / Technique near a wall while airborne and give tangent movement | Immediate valid contact, tangent reversals and inside-corner transfer; corners do not renew the timer |
| Aim and impact | Shoot at a cursor point, then move the cursor | Original point remains locked; projectile stops at that distance, first obstacle/actor, or authored maximum range |
| Chemistry | At the Spell Loom equip Fire and Water projectile spells, shoot both into one spot | Finite sources form Steam after its telegraph; repeated lanes of one Burst cannot react with themselves |
| Other pairs | Equip any first-eight element projectiles in the twelve positions | All 28 mixed pairs and 8 self-pairs have first-grade results; F4 -> Chemistry lists all pairs and timings |
| Recovery | Spend Stamina or Flux, then leave that resource unused | Independent quiet recovery ramps to 3x; Blightsoil seals positive recovery without erasing quiet age |
| Remote play | Both players use this source revision; use Host / Join Farflow | Shared authoritative movement, endpoints, deposits, reactions and optical Beam segments |

Default keys are V evade / air dash, Q technique, C slide, Shift sprint and
Space jump / Float. Only a complete old default keyboard profile migrates;
custom profiles are preserved. Four spell buttons plus Ctrl / Alt make twelve
individually configurable slots. Controller aiming remains directional with
authored maximum range, not a mouse-point lock.

## Implementation boundaries

| System | Contract |
|---|---|
| Material lifetime | Earth 5 s; Fire 3 s; Water 4 s; Wind 2 s; Ice 4 s; Charge 2 s; Light 3 s; Dark 3 s |
| Capacity | 128 combined deposits/projectile reservations, 16 per owner; 32 simultaneous products; up to four linked deposits per conduction path |
| Fair admission | Capacity is reserved before Flux payment; split projectiles share the original damage/material budget; no silent threat truncation |
| Chemistry | Distinct finite cover, fronts, veils, slow/push regions, delayed pulses, reveal/conceal, recovery seal, connectivity and optics; products never recursively react |
| Presentation | Shared element colours, original reusable shapes, authority-derived occupied geometry, formation/active/decay, normal and reduced-effects drawing |
| Untouched scope | Five playable champions / three body sizes, existing map and spell forms; no new installer, remote push, Linux release work or permanent worldbone mutation |

Source deposits are reactive matter, not eight generic damage zones. Terminal
explosions communicate the material release; they do not add an unrequested
universal blast-damage bonus. Temporary cover intercepts attacks; it does not
rewrite permanent map collision. Concealment changes the presented view, not
the existing full-authority snapshot's anti-cheat policy.

## Verification and limitations

Final Full checkpoint receipt is recorded in `.godot/receipts/low-hop-chemistry-checkpoint.json`.
It passed at 2026-09-06 14:11 UTC in 59,653 ms: 81 suites, 165,441 assertions,
zero failures and stderr zero bytes, including current-state/content/asset checks,
import and 120 Hz headless source startup. The preceding failed runs are not
acceptance evidence; their stale fixtures were corrected before this final run.

| Evidence | Executed result |
|---|---|
| Real paid-cast integration | 9,538 assertions; all 36 formations, locked aim, shared Burst budgets, terminal sources, jump clearance, 8-player reservations, exact replay and optical Beam paths |
| Reaction behavior | 827 assertions; effects/lifecycle, cover, connectivity, suppression, optics and narrow-veil sight |
| Network envelope | Worst complete tested mixed snapshot 26,804 raw bytes; 8 fragments, largest 1,296 bytes; zero omitted state |
| Farflow | Local real host/join, reconciliation, Court transition, late join, spectator handoff, reconnect, rematch and stewardship passed |
| Production render | Paid Fire + Water formed Steam at tick 65 in a 120-frame isolated source capture; all 36 render fixtures inspected in normal/reduced modes |
| Heavy-load correctness | 8,251 assertions, exact repeated hashes, zero missing-threat samples or rejected snapshots |

**Performance is not accepted as sustained 120 FPS.** On the Ryzen 3 7320U,
the two legal eight-player headless probe runs measured simulation medians
5.457 / 7.090 ms, p95 39.256 / 36.891 ms, and 206 / 330 of 720 ticks over the
8.333 ms budget. The previous game was still open. This is a CPU diagnostic,
not rendered FPS or a representative uncontended benchmark. The next technical
priority after human playtest is profiling chemistry scans and snapshot packing,
then proving a bounded 120 Hz frame budget under repeatable isolated load.

The first Full run exposed outdated test fixtures: old command/world canonical
order, a retired ricochet fingerprint, old jump-height expectations and manually
seeded Float states without their new positive duration. Fixes must preserve
independent byte comparisons and meaningful visual/physical assertions.

Human feel/readability review, real controller hardware and an internet session
with a friend remain separate acceptance checks. No AAA-ready or universal
plug-and-play networking/performance claim is made.

## Pause and resume

The user requested a checkpoint pause and game launch. Do not start another
feature slice until they resume. Start this source with `flux.cmd` or
`flux.cmd play`; use the Wellspring Spell Loom and F4 guide for this playtest.
Preserve personal untracked files and do not publish remotely without approval.

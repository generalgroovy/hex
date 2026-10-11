# Core movement and Steam integrity evidence

Status: October 7, 2026 source candidate `p57-339c9876cd3a` passes focused and
Full validation. The previous M1 source and packaged candidates remain separate;
no release or human acceptance is claimed.

## Bounded changes

| Repair | Required result |
|---|---|
| Jump and Slide chord | Shared effective input priority prevents a refused aerial Jump from also triggering free fast-fall and a buffered landing hop; Slide-only and ignored held-Jump repeat controls still work |
| Sprint payment | A speed tick requires its entire remainder-aware Stamina payment; refusal behaves as walking, including ordinary recovery; simultaneous Flux casting remains independent |
| Water cooling Steam | Actual scald damage never increases after cooling, including integer rounding and partial paid stock; all matter/provenance survives with unchanged coverage and expiry |

## Evidence

| Gate | Result |
|---|---|
| Advanced movement baseline | PASS on prior source p57-0a679f632a77: twelve actual Bootstrap input routes / 7,547 checks, covering three sizes each for flight, double jump, dodge/fast-fall and walls |
| Red regressions v1 | FAILED as intended for the three production defects: three suites / 78,681 assertions, 1,013 failures, zero stderr; includes additional invalid zero-reach Spray coolant fixtures, corrected before the green run |
| Focused green v1 | PASS: sixteen suites / 302,439 assertions, zero failures / stderr; includes movement, payment, chemistry, prediction, snapshots and field presentation |
| Full v1, import, identity, configured 120 Hz boot | PASS: 220 suites / 3,963,715 assertions, zero failures / stderr; exact-hash log and state copies retained |
| Post-fix actual input journey | PASS on p57-339c9876cd3a: twelve actual Bootstrap input routes / 7,547 checks, three sizes each for flight, double jump, dodge/fast-fall and walls; zero stderr |
| Human feel, native visual, dense timing, physical Internet | Not accepted by headless correctness tests; historical dense timing failure remains |

Red details: movement 248 failures, resources 646, Steam 119. Valid weak Water
controls demonstrate increased Steam damage. Spray fixtures originally used the
same origin and terminal, correctly producing zero reach and no modifier; their
correction supplies a real endpoint rather than changing production geometry.
Keep the complete failed receipt/log with that limitation, not a cleaned success.

The cooling bound is calculated only on accepted one-use coolant events, over
deduplicated old/new effective density pairs and exposure levels 1 through 240.
No new per-tick modifier calculation, persistent cache, protocol or schema field.
Chemistry matrix fixtures commit finite paid-source ledgers; they do not prove
an independent player Flux debit for every matrix row. The resource suite does
exercise simultaneous real casting through HexCourt.
Its 720 sprint boundary cases use three controlled speed/hurt-radius profiles
(900/1000/1100), eight headings, six signed remainders and five reserves. Those
profiles are not exact catalog champion stats; actual catalog size/air capability
coverage belongs to the separate twelve Bootstrap routes.

Independent code review covers the movement debit/recovery path and Steam's
integer pressure proof, retained material, zero-intensity cues and snapshot
continuation. Valid cooling covers all four family strengths (1, 3, 5, 15),
normal/clipped footprints, heated products and partial-stock rounding cases.
Native visual and human balance acceptance remain separate.

Source identity: 3,109 production records; SHA-256
`339c9876cd3af5c90de3d57c6520e6281ae454f338183896d7bd7b00766b4c13`.
Protocol 57 / SessionSnapshot 23 / SessionRound 2 are unchanged. There is no new
portable, installer, checkpoint promotion, commit, push or publication.

## Human playtest route

Run [the source launcher](../../scripts/run.cmd). Existing portable builds do not
contain these changes. Try Jump and Slide together after using the second jump,
then compare Slide alone; spend Stamina nearly empty while holding Sprint and
confirm ordinary walking/recovery; form Steam and cool it with a weak Water
cast. Compare its pressure before and after without changing exposure history.

All test-owned engine processes exited and the run-guard owner is released.
The journeys used isolated preferences; no player profile was replaced.

Also preserve the M1 controls: held jumpsquat plants self-motion, instant tap
jumps retain momentum, Slide follows incoming travel, and safe field holes keep
their visible boundaries. See the [single queue](../../.agent/OVERHAUL-IMPLEMENTATION.md).

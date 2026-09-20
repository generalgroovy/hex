# Capacitor M2b

Status: locally verified Windows portable, 2026-09-12; human playtest pending.
Current pointer selects `capacitor-m2b-p47-20260912`; prior Frostway is preserved.
The exact selected playable artifact is always docs/current-checkpoint.json.
Do not infer delivery from this document or historical Frostway receipts.

## Player outcome

Two paid distinct Charge casts can form Capacitor. Ride its 200 px centreline,
60 px-wide round-ended lane; both teams' ordinary ground walk/sprint targets 125%.
Frostway takes priority when lanes overlap. Slide, jump, Float and air dodge
retain ordinary payment, carry caps, protection and airtime budgets.

The lane forms harmlessly for 650 ms, remains active 2000 ms, then decays harmlessly
for 450 ms. Its last 500 ms displays cream warning bars. The final active tick moves
a grounded unprotected enemy 14 px along the cast direction, respecting static
walls and active Rampart. Leave sideways or jump before discharge. It deals no
damage, stun or cast cancellation. Simultaneous discharges move each actor at
most once per tick; source IDs determine priority. Trail-assisted sustain remains
60%, with warning/release derived from the actual shortened interval.

The old internal ID overload/wire331 is stable. The compiled policy fingerprint
changes. Reconciliation requires Charge lane geometry/timing/team rows and
actor team/health/protection. Prediction agrees in the tested movement context;
intervening combat, other chemistry pushes and destroyed cover reconcile from
host authority. Old-content peers cannot enter a same-build session.

## Fresh acceptance and evidence

Root alone ran every engine job; candidate source is frozen for final delivery.
Evidence lives in [the M2b evidence directory](evidence/capacitor-m2b-20260912).
Final acceptance was executed against 3,093 frozen files, unchanged through export:

| Gate | Fresh result |
|---|---|
| Full | 98 suites / 690,459 assertions; zero failures/stderr; import and 120 Hz boot passed |
| Frozen captures | 221 frames / 101 paid admissions; all 36 pairs, eight elements, three-size M1/M2a/M2b and paid protection |
| Visual review applicability | All 54 frozen Capacitor PNGs exactly match the independently reviewed v2 PNGs by SHA256 |
| Portable | Fresh Windows EXE/PCK/ZIP; exported content/atlas identity and isolated raw boot passed |
| Same exported EXE networking | Localhost UDP24975: HELLO, movement reconciliation, round, late join/spectating, return, rematch, stewardship passed; all three stderr logs empty |
| Current pointer | Exact payload/evidence hashes freshly verified after promotion |

Build receipt: [checkpoint.json](evidence/windows-capacitor-m2b-p47-20260912/checkpoint.json).
Full receipt and referenced logs: [full-v1](evidence/capacitor-m2b-20260912/full-v1/receipt.json).
Source inventory: [freeze-v1/source-state.json](evidence/capacitor-m2b-20260912/freeze-v1/source-state.json).
Localhost logs: [same-export-farflow](evidence/capacitor-m2b-20260912/same-export-farflow).
The immutable export receipt records the state before pointer promotion. The
current pointer was promoted afterward, then freshly verified; the preserved
Frostway pointer also verified. The older QV installer remains unavailable.
Portable ZIP: 97,732,030 bytes.
PCK SHA256: `df48043eeac76ea498c51b3288d77568ea6b6877b9a92efd73afa73aec4a9b9b`.
ZIP SHA256: `191c5853d256acdc3cc85b3a3262a01e09486d4eae935c20cdf22549e7e286c3`.

- Fresh current-state/source consistency and exact Frostway fallback hashes passed.
- Focused movement/integration/presentation: 3 suites, 26,404 assertions, 0 failures.
- After the visual correction: presenter 21,504 assertions, 0 failures, empty stderr.
- Native pack validation: 20,482 assertions, 0 failures; no PNG or frame JSON changed.
- Review captures: v1 and v2 each 77 actual paid-game frames/17 admissions, including
  three sizes, normal/reduced phases, paid slide/jump and actual enemy discharge.
- Independent runtime review caught and closed missing prediction eligibility,
  defeat-state parity and redundant per-tick temporary-wall reconstruction.
- Independent Astra image review rejected the first bright decay/obscured warning;
  v2 closed that static phase-readability issue. Dynamic perception/feel remains
  human acceptance, not an inference from isolated PNGs.
- Failed attempts remain: focused-v1 typed-array/quantization/text fixtures;
  focused-v2 visual test type inference and Rampart fixture origin mismatch;
  focused-v4 stale generic opacity expectation after deliberate visual correction.
  Their raw receipts and referenced logs are retained, never relabelled passed.

## W4 is still a failed performance gate

Current production SimWorld paid eight-player mixed deliveries, 120 warmup ticks
then 720 measured ticks, two repeats with reversed command order, empty obstacles:

| Measurement | Repeat 1 | Repeat 2 |
|---|---:|---:|
| Simulation median | 8.074 ms | 8.262 ms |
| Simulation p95 | 13.296 ms | 13.626 ms |
| Ticks above 8.333 ms | 349/720 | 349/720 |
| Snapshot capture/packing p95, separately measured | 7.846 ms | 8.187 ms |

Correctness 12,595 assertions passed, deterministic hashes agree, missing-danger
and rejected-snapshot counts are zero. This is neither rendered performance nor
network throughput. Historical 9.868-10.606 ms used different source/content;
these observations establish a current failure, not a causal optimization delta.
Raw log: [w4-current-v1.log](evidence/capacitor-m2b-20260912/w4-current-v1.log).

## Playtest and handoff

Run [flux2.exe](../exports/windows-capacitor-m2b-p47-20260912/windows/flux2.exe)
with its adjacent PCK, or extract the complete
[portable ZIP](../exports/windows-capacitor-m2b-p47-20260912/release/FLUX2-Windows-x86_64.zip).
At the Spell Loom,
equip Charge Rapid/Spark Stream. Cast twice at one nearby endpoint, walk/sprint
along the lane, then try paid slide and jump. Watch the final warning and residue
in both effects settings. In a same-build opposing-team practice session, compare
standing through the final discharge with leaving or jumping before it.

Human acceleration/discharge feel, warning perception in combat, basic body
animation, physical two-PC Internet play, rendered load, installer/updater and
publication remain separate open categories. No visible game was launched for
the user; fixtures rendered hidden. No commit, push, security change or original
asset cleanup was authorized/performed. Earlier playable packages are retained.
Four run-owned scratch helpers were archived as text under the evidence helpers
directory and removed from .godot. All owned engine processes are closed.

The single active queue owns continuation. After human M2b feedback, address the
measured W4 budget dependency before growing the remaining mirror/visual load;
then resume M3 one mirror at a time. This document is a checkpoint, not a backlog.

![Actual frozen Capacitor final warning](evidence/windows-capacitor-m2b-p47-20260912/inputs/capture/oh_tipi-capacitor-final-warning.png)

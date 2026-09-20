# Frostway M2a

Status: locally verified Windows portable, 2026-09-09; human acceptance pending.
The current checkpoint pointer selects `frostway-m2a-p47-20260909`.

| Rule | M2a contract |
|---|---|
| Create | Two paid, distinct Ice projectile casts whose matter overlaps; Rapid leaves no trail |
| Geometry | Stationary capsule, 200px centreline and 30px radius; oriented along the older cast |
| Lifecycle | 650ms warning, 3500ms active, 600ms harmless decay; existing trail-assisted sustain reduction retained |
| Ground | Both teams' ordinary walk/sprint target75%; steering/braking remain normal, no lingering status |
| Movement counter | Slide, jump, Float, air dodge and forced control retain ordinary rules/costs; no reset or speed grant |
| Projectiles | Physical projectile displacement65% inside; base velocity, damage, range budget and finite lifetime unchanged |
| Ray counter | Beam/Spray pass unchanged; lane has no cover health or blocking |
| Overlap | Fixed nonstacking ratio, bounded32 reactions; no worldbone mutation |
| Sampling | Actor/projectile centre at tick start, shared120Hz authority/prediction; very fast crossings can occur between samples |
| Visuals | Native tileable cyan floor, shallow cracks/skate glints, six normal/reduced sequences; actual corridor clipping, no range outline |
| Compatibility | Stable wire327/internal `glacier`; new displayFrostway and fingerprinted policy; required exact-tick lane rows |

## Acceptance

| Gate | Evidence |
|---|---|
| Independent review | No blocking issue under explicit tick-centre sampling contract; read-only, not a test pass |
| Focused | 14 suites / 290,674 assertions; zero failures and empty stderr |
| Full | 96 suites / 681,500 assertions; zero failures and empty stderr |
| Native magic pack | 20,482 assertions; 474 sequences / 1960 frames / 3 atlases; only six Frostway sequences reauthored |
| Actual game captures | 167 frames / 95 paid cast admissions; all36 pairs plus three-size Frostway walk/paid slide/paid jump/decay/expiry |
| Source freeze | 3,087 scoped runtime/test/package files unchanged before/after export; not the entire repository or source-art tree |
| Windows | Fresh EXE/PCK, lossless raw atlas checks, isolated raw boot; portable ZIP97,716,511 bytes |
| Local networking | Same exported EXE: host/join, HELLO, movement reconciliation, round/late join/rematch/stewardship on UDP24974; all three stderr logs empty |

Initial focused failure was stale editor class/texture import, corrected by an
explicit import. Initial Full found an obsolete327-as-cover fixture; it now
explicitly excludes Frostway and preserves all other candidate-order/alias checks.
Failed receipts/logs and previous freezes remain intact; no assertion was disabled.

Human readability/feel, physical two-PC Internet play and sustained rendered120FPS
remain open. The existing W4 simulation budget miss is not erased by this slice.
No installer/publication is implied. Prior C1 and Rampart exports remain intact.

## Run and test

Open [flux2.exe](../exports/windows-frostway-m2a-p47-20260909/windows/flux2.exe)
with the adjacent PCK, or fully extract the [portable ZIP](../exports/windows-frostway-m2a-p47-20260909/release/FLUX2-Windows-x86_64.zip).
Both friends need this same build. Equip Ice Rapid/Sleet Stream at the Spell
Loom; cast twice at one nearby endpoint. Walk/sprint into the cyan lane, then
cross with paid slide or jump. Compare physical shots with instantaneous
Beam/Spray. F4 describes the actual rule. Formation and decay are harmless.

Next: M2b Charge mirror, bounded speed opportunity/discharge without stun loops,
then the remaining mirrors one at a time. Race/map expansion remains separate.

Owned test helpers are closed and smoke profiles isolated/restored. No original
art or previous build was deleted. Failed diagnostic logs and ignored capture
evidence remain retained; the earlier cleanup policy block was not bypassed.

[Immutable build receipt](evidence/windows-frostway-m2a-p47-20260909/checkpoint.json).
PCK SHA256: `6bd29a5724a569766ec1b67699f68f32aa35df5755846f77519b85d6ee10fa6b`.

![Actual paid Frostway and walking](evidence/windows-frostway-m2a-p47-20260909/inputs/capture/oh_tipi-frostway-active-walking.png)
![Large body paid jump above Frostway](evidence/windows-frostway-m2a-p47-20260909/inputs/capture/red_baron-frostway-active-jump.png)

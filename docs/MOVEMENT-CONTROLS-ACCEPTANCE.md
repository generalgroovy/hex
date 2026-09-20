# Movement controls and learning: low jump / size-limited Float / progressive recovery

Historical slice record: its Q/V assignments describe that revision. Current
defaults are Technique V / Roll-Air Dodge Q; see [README](../README.md#controls-and-movement)
and [SPECIFICATION.md](../SPECIFICATION.md). Earlier evidence below is unchanged.

Status: **low-jump, size-limited Float, chemistry recovery seal and Q/V default migration implemented; this revision's final integrated and human feel acceptance remains open**.

Final suite, visual review and player acceptance are
recorded by the integration lead in `MOVEMENT-M1-M5-ACCEPTANCE.md`.

## Current resource and air-action contract

All five playable champions retain exactly five times their earlier Stamina
maximum. Health, Flux maxima, role speed ratios and other action costs remain
unchanged. Base recovery rates are unchanged, but each resource now ramps
independently to 3x over three quiet seconds after its own spending delay. The generic
movement fallback is 560 Stamina, but the HUD and compendium use the selected
champion's actual values.

| Champion | Size | Stamina before -> now | Base -> quiet recovery / second |
|---|---|---:|---:|
| S. Wayne | Small | 118.8 -> 594 | 28 -> 84 |
| Grace Riva | Small | 123.2 -> 616 | 29 -> 87 |
| Wa Bidi | Small | 127.6 -> 638 | 32 -> 96 |
| Oh Tipi | Middle | 132 -> 660 | 30 -> 90 |
| The Red Baron | Large | 158.4 -> 792 | 32 -> 96 |

| Action | Current rule | Readable practice check |
|---|---|---|
| Ordinary travel | Base speed 372.6 units/s; champion ratio and 1.60 sprint multiplier apply | Compare actual speed and distinct walk/sprint stride with the optional practice trace |
| Tap / held jump | Continuous low arc; release caps upward speed at 330 units/s; full approximately 28.9 px, tap approximately 22 px; landing refreshes readiness | Above 18 px, low ground projectiles pass underneath; beams, areas and explosions are not cleared; only ascent pays 80 Stamina/s sustain |
| Float (replaces second jump) | Fresh release and press/hold; maintains current height, fully steerable and protected; 24 Stamina + chain premium, then 100/s; small 1.8 s, middle 1.5 s, large 1.2 s cap | Hold near apex, turn, release: shield must disappear immediately; no new lift or repeat Float before landing |
| Air dodge | One per real airtime; 180 ms decaying directional burst, then steerable flight; landing refills it without a cooldown wait | Turn or coast after the burst, then land and start a new jump/dodge chain |
| Wall route | Independent walljump, Float and air-dodge opportunities; only actual landing restores spent air budgets | Walljump -> Float -> air dodge is legal, but touching another wall never refills a spent Float or dodge |
| Fast fall | Fresh airborne Slide press sets at least 1,000 units/s downward speed; gravity continues until landing | Carrying C through takeoff does nothing; release and re-press to descend |
| Protection | Ordinary jump opening 90 ms and air-dodge opening 120 ms, ending immediately on landing; Float explicitly protected while held, paid and active | Only the visible active Float shield represents maintained immunity; release/exhaustion/dodge/wallrun/fast fall/forced control ends Float |

The guide labels airborne durations as nominal lift cycles, not hard landing
timers. Runtime tuning owns these values; guide tests detect obsolete remaining-
flight limits, shared-cooldown air-dodge claims and frame-counter fast falls.
Shared body envelopes are scaled exactly fivefold with an 800-Stamina global
ceiling; oversized authored resources still fail closed. Network resource
bounds already support these values without an additional resource-cap change.

## Current focused verification

The canonical deferred runner passed **8 suites / 1,831 assertions** with zero
failures and clean stderr: input-router (472), player-preferences (155),
control-binding-editor (32), movement-guide-model (339), compact-combat-hud
(42), player-resources (88), burst-projectile-presenter (117), and
element-chemistry-presenter (586). Evidence:
`.godot/compendium-audit/lowhop-chem-ui-final.log`.

This verifies source-derived low-jump and Float instructions, remaining Float
time, fixed-world pointer endpoints, legacy-default migration without stealing
custom keys, chemistry recovery seals, and bounded effect presentation models.
An initial resource fixture omitted the newly required positive Float duration;
the corrected fixture exercises the actual held-drain path. Integrated chemistry,
Full/Farflow, real controller feel and human visual acceptance remain separate.

Original Godot-rendered 36-reaction / eight-deposit-and-impact specimens were
inspected in standard and reduced-effects modes at
`.godot/visual-captures/chemistry-native-final-normal/frame00000003.png` and
`.godot/visual-captures/chemistry-native-final-reduced/frame00000003.png`.
These are scaled render fixtures, not gameplay or performance acceptance.

## Earlier verification (before the current low-hop / Q-V revision)

On 2026-09-06 the isolated `champion-catalog` (979), `movement-guide-model`
(334), `player-compendium` (957), `compact-combat-hud` (39) and `player-resources`
(81) suites passed **2,390 assertions, zero failures**, clean stderr:
`.godot/compendium-audit/float-quiet-recovery-v2.log`. These check independent
quiet timers, base-to-3x actual resource rates, positive-spend resets, failed/free
actions, champion reset, truthful drain/refill HUD and Float instructions.
The integrated Full/Farflow/render evidence is in the canonical movement ledger.
Earlier receipts below are historical, not proof of this revision.

## Intent before extra inputs

Current defaults are **WASD**, **Shift** sprint, **Space** jump, **C** slide,
**V** evade and **Q** Technique. Ctrl / Alt remain the twelve-slot spell layers.
Preference schema 11 migrates the complete previous default keyboard profile;
any customized keyboard profile, including explicit unbindings, retains its
exact meanings. Mouse/controller bindings and spell layers are unchanged.

| Input | One deliberate meaning | Safety rule |
|---|---|---|
| Space / jump button | Jump; hold for paid height, release then press/hold for Float | Wheel cannot fabricate a held jump or sustained Float |
| C / slide button | Ground slide; deliberate second press brakes | Carrying C through takeoff does not immediately fast-fall |
| Fresh airborne C | Commit to an earlier landing | Release a previously held C, then press it again |
| Wheel up | One short Jump intent | Same-direction notches group until 120 ms of quiet |
| Wheel down | One short Slide intent, or explicit airborne Fast Fall | Same scrolling gesture does not immediately brake its own slide |
| V / Evade | Roll on ground, air-dodge in air; late air-dodge can wavedash | No angle threshold for the late landing conversion |
| Q / Technique | Contact/direction-specific wallrun, turn or impact recovery | Always subject to the authoritative movement state and cost |

Wheel grouping is a local input filter, not an automatic action or macro. Each
accepted gesture produces at most one pressed edge, no held flag and no
scheduled repetitions. A new notch extends the quiet-time window. Jump and
Slide gestures are independent, so opposite wheel directions remain usable in
deliberate chains. Keyboard/controller presses bypass wheel grouping, including
a button press in the same render frame as a wheel event.

An accepted short pulse survives a render frame with no fixed simulation tick,
but expires after 120 ms if not sampled. Opening a modal discards pending wheel
pulses; wheel releases neither rearm a gesture nor erase an unsampled pulse.
The normal no-wheel polling path remains unchanged.

## Learn a small grammar, then combine it

| Group | Skills | First useful drill |
|---|---|---|
| Travel | Move / brake, sprint, jump / hold, slide / hold | Run one lane, slide, release C, jump, steer and land deliberately |
| Escape | Roll, air dodge, fast fall, impact recovery | Cross one threat lane with the protected opening, then finish outside danger |
| Expression | Float, slide brake, slide jump, wavedash, air turn, wallrun, wall jump, landing reversal | Choose two different exits from the same approach without changing the opening |

The live compendium marks each skill's group and derives bindings, base cost,
hold drain, duration, cooldown and protection from current source tuning.
Shared rules distinguish ground release-to-brake from airborne
release-to-coast, held drain from the paid-start chain premium, and visible
ordinary airtime from its shorter protection window, with held Float as the
explicit protected exception. The newest movement intent replaces
older buffered intent; the simulation still checks legality and affordability.

Use the optional practice trace (F2 by default) and restart it (F3 by default)
to compare routes. It exposes actual movement mode, speed, current/maximum
Stamina and the next chain premium. The in-game guide resolves these shortcuts
from saved bindings, not hard-coded letters.

No new deadzone setting or ergonomic preset is introduced here: those require
their own saved-preference migration and physical controller acceptance. The
existing Controls Lectern remains the supported rebinding path. No material
grip/drift, vault or extra automatic movement is added.

## Evidence boundary

Focused tests exercise the real InputMap and InputRouter sampling path, gesture
quiet gaps, release-before-sample, deliberate keyboard override, simultaneous
holds, catch-up ticks and modal discard. Existing eight-direction chord tests
remain in the same suite. Guide tests verify source-derived instructions and
costs; real controller feel and player learning still require human playtest.

Focused verification on 2026-09-06: the canonical deferred headless runner
executed `input-router` (457 assertions), `movement-guide-model` (298) and
`player-compendium` (870), all with zero failures and clean stderr. Evidence:
`.godot/compendium-audit/input-canonical-final.log`. The fixture explicitly
flushes synthetic engine events before feeding the production observer,
matching normal event delivery; immediate startup-only input tests are not
used as the final evidence. Full integration, captures and human acceptance
remain the lead's delivery gate.

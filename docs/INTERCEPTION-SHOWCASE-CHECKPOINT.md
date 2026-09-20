# Wellspring interception playtest — September14

Status: playable Windows candidate delivered for human playtest; unpromoted.

Candidate source: `p50-83f914b3144f`, protocol50/snapshot20, Windows x64,
Godot4.7.1. Source SHA256:
`83f914b3144fc6e6880f6ca9c9c6c4fd18c5341d0baa15802ce8d203c4e0c4d8`.
Final integrated validation and portable packaging passed against3160 frozen
inputs. This document does not promote the selected checkpoint.

## Play the encounter

Launch the fresh portable with
`exports/windows-interception-p50-20260914/release/FLUX2-Windows-x86_64/PLAY-FLUX.cmd`.
Its adjacent `flux2.exe` must retain `flux2.pck`. This destination is a candidate,
not the selected Overnight P48 fallback.

Extractable archive: `exports/windows-interception-p50-20260914/release/FLUX2-Windows-x86_64.zip`
(97,808,689 bytes). ZIP SHA256:
`0b22116333858e2bb96ad7cba90507843affa9504c9504cf0461f68d6f988319`.
PCK SHA256: `587f545d48381659c722352006af0e97def35d1185c35a0b79c00fcd0188dad3`.
The EXE is the shared Godot executable; the adjacent PCK and BUILD-STATE.json
identify the new game. Preserve the complete folder when copying it.

Click **PLAY 72s INTERCEPTION TRIAL** near the upper left. The trial gives S.Wayne
a temporary first-four kit: Water Spray, Earth Spray, Fire Bolt, Fire Rapid.
Existing personal bindings remain in effect; check the HUD if you rebound slots.
Default controls: WASD move, mouse aim,1/2/3/4 cast; Shift sprint, C slide,
Space jump, Q evade. Other eight configured positions stay available.

1. Intercept incoming Rapid with a timed Water Spray. It is one paid pulse,
   not a held shield; try moving while keeping aim on the incoming line.
2. During the quiet beat, cast Water then Earth Spray at the same nearby ground
   point, within Water's reach. Mud is the soil patch labeled **GROUND SLOW**.
   Walk through it and then reposition or jump across it to compare the effect.
3. Sidestep the stronger Bolt/Heavy phases; those shots cancel an intersecting Spray.
4. **RETRY 72s ENCOUNTER** restarts immediately. **RETURN TO WELLSPRING** restores
   normal solo setup. Hosting/joining also exits the trial; pending joins exclude entry.

Source launch remains `scripts/run.cmd`; its equivalent direct engine user option
is `-- --interception-trial`. No saved loadout migration or personal profile reset
is needed. The trial itself is solo; ordinary same-build Farflow remains separate.

## What changed

| Change | Player benefit | Verification and limit |
|---|---|---|
| Unequal Spray/projectile interception | Read a small incoming shot and spend a timed pulse to stop it; stronger shots reward evasion | Exact closed sector-circle overlap, stable cast/projectile ordering, whole-flight-cast negation. Equal direct contacts and projectile sweeps remain B2 work. |
| One surviving Spray ingredient | Water/Earth Spray can form Mud with one paid cast budget each | Prepayment reservation survives startup and deferred resolution. Negation prevents later damage/cover/terminal outcomes. Existing unequal deposits survive. |
| Ground-target reach | Nearby ground experiments line up despite different authored maximum ranges | Shared actual range for interception/actor damage/terminal and networked display; inclusive oblique target and moving startup tested. |
|72second pressure circuit | Immediate practice, stronger-shot warning, quiet experiment and fast retry | Two real champions, ordinary paid commands, no attack/ingredient injection or post-setup resource refills. Human timing/feel acceptance pending. |
| Bounded feedback and Mud distinction | Clear interception confirmation and an identifiable slowing area | Existing native soil reused without changing original assets; exact reaction masks/phases retained; normal/reduced labels. Audio uses the existing bounded synthesized bank; listening acceptance pending. |

The Small shared body, size-only hurtboxes, common wall clearance, paid movement,
independent aim/travel,120Hz authority,8player live limit,32 legal spells and12
positions remain. No new detailed skins, global geometry scaling, longer lifetimes,
Steam/Magma redesign, cap raise or future32player support is included.

## Evidence boundary

Fresh final evidence:

- `full-v4.json`:109 suites,700,712 assertions, zero failures/stderr; final
  Inventory-v3 predates this Full and the final captures.
- `referenced/.godot/interception-playthrough-final-playthrough-v1.json`: all8640
  ticks/72seconds,105 paid starts/releases,13 successful interceptions, one Mud
  plus26 Flood formations, zero refusals. Real damage and ordinary recovery occur;
  no post-setup resource refill. Automated formation is not a human movement test.
- `referenced/.godot/warm-style-trails-render-showcase-final-capture-v2/`:38 native
  normal/reduced frames; every replay state hash matches; drawing leaves authority
  unchanged; no invalid production footprint parts. Independent Astra review
  found the interception/Mud/countdown readability findings resolved. All38 final
  image hashes match the reviewed v1 set (`capture-comparison.json`).
- [Actual before/after gallery](evidence/interception-showcase-20260914/comparison.html)
  and preserved `before-capture/` include the same recorded inputs and selected ticks.
- `../windows-interception-p50-20260914/checkpoint.json` relative to the evidence
  directory: export, exact PCK identity, full source freeze and isolated raw boot
  passed. This is a portable candidate, not an installer/release acceptance.
- `referenced/.godot/interception-package-checks-v1/`: actual exported trial
  bootstrap ran1200 fixed headless frames. The same EXE passed localhost host,
  guest and late guest, HELLO/build matching, movement reconciliation, Court
  round, late spectating/Hearth handoff, exact-actor return, rematch and stewardship
  at120Hz. These are three localhost processes, not eight physical machines or
  dedicated socket delivery of the new interception event. Its codec is covered
  by the Full suite. Personal-profile hash remained unchanged.

Matched eight-player load results on AMD Ryzen3 7320U / Godot4.7.1:

| Workload | Candidate simulation p95 | Candidate host work p95 / p99 | Historical B1 host p95 |
|---|---|---|---|
| Campus, two720-tick repeats |4.749–4.787ms |8.479–8.523 /9.105–9.172ms |8.445–8.463ms |
| Three pressure cases, two720-tick repeats each |6.657–7.017ms |10.718–11.184 /11.227–11.963ms |approximately11.1ms |
| Open pressure, two7200-tick repeats |6.528 /6.968ms |10.592 /11.085ms p95;11.238 /13.435ms p99 |10.047 /10.157ms |

The matrix passed28,332 assertions and the simulated soaks53,216. Host work
includes the step, event queue and every-other-tick snapshot packing, before
rendering or sockets. The120Hz budget is8.333ms: **W4 remains FAILED**. The
candidate soak is slower than the recorded B1 soak; no optimization improvement
is claimed. Each candidate repeat records1383 paid starts,1365 surviving releases
and18 negated Spray pulses,577 refusals of720 discrete intents, plus23040 held
Rapid input-ticks counted separately. It evicts488 queued events, versus450 in
B1; zero snapshot rejections does not prove complete transient feedback delivery.
Peaks of64 projectiles,127 deposits and10 reactions occur separately. Shared
projectile/deposit capacity remains128 with16 per owner. Capacity was not raised.
See `performance-summary.json` and its hashed raw records for all distributions.
The raw probe's capacity_acceptance text retains an obsolete B1 sentence; the
embedded identity and actual interception counters identify this B2a candidate.

All current receipts and their referenced logs live in
`docs/evidence/interception-showcase-20260914/`. Earlier B1 and scaling receipts
are historical baselines, not proof of this changed source. Failed diagnostic
runs are retained alongside the final passing receipts.

The72second input trace records both players' commands, every resulting world
hash, ordered events, paid starts, releases, refusals and reactions. Rendered
playback checks every world hash and asserts that drawing does not alter authority.
The before comparison uses the archived actual dirty B1 combat_system/sim_world
inside the same encounter and renderer scaffold, with the exact same recorded
commands. It is labeled **B1 combat behavior in the same encounter scaffold**,
not an original P48/B1 exported build. Camera follow,75% zoom,1280×720 and both
effects modes are comparable; displacement can move the camera differently.

Existing W4 host performance failure remains explicit. Headless tick timing,
step+event-queue+snapshot work, paused native captures, localhost sockets and
physical two-PC play are separate evidence. Captures do not measure FPS or
input-to-visible latency. Installer/updater, physical two-PC and human art/feel
acceptance are NOT RUN. No publication or checkpoint promotion is authorized here.

## Preserved fallback and next slice

`docs/current-checkpoint.json` still selects Overnight P48. Launch its separate
`exports/windows-overnight-p48-20260913/windows/flux2.exe` for rollback.
Personal settings, original artwork, dirty baseline archive and all referenced
fallback payloads/evidence are checked at handoff.
`preservation.json` verifies the unchanged profile, pointer and eight selected
members, with no Godot processes left running. `source-changes.json` compares
the3135-input B1 baseline to3160 final inputs:23 changed,25 added, zero removed
and zero asset changes within the frozen input scope. Full/export receipts
verify the final freeze independently. Original source artwork was not edited.

The same implementation queue owns the next slice: complete direct equal-strength
and swept projectile contact ordering with mutable-contact revalidation, while
addressing measured host cost and event retention before increasing area/lifetime.
Pause here for the user's encounter feel/readability playtest after delivery.

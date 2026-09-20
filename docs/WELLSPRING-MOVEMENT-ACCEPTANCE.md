# Wellspring campus and movement revision

Status: **implemented source candidate; human visual/feel acceptance pending**.
Windows, Godot 4.7.1, 120 Hz. Protocol 33 / snapshot 12 / preferences 10.
Both friends must run the same build. Existing local Windows exports predate
this source checkpoint: rebuild before sharing the new map/movement. No new
installer trust claim; the earlier unsigned-installer policy block remains open.

## What is playable

| Area | Implemented purpose | Remaining boundary |
|---|---|---|
| Source Court | Spawn, champion/spell configuration, controls, host/join/charter/Hearth | Shared session and round ownership, not six independent minigames |
| Movement Garden | 320-unit practice faces, eight-way marks, impact chime, open reversals | Human feel tuning and named timed courses |
| Pattern Range | Three real damageable/resettable targets; clear firing lanes | Automated pattern challenge selector |
| Duel Court | 720x600 court, four 72x72 covers, eight spawn anchors, existing round flow | Simultaneous independent duels/activity isolation |
| Crucible | Open spell-trial pocket, workshop and practice reset access | Element exposure/contact and world chemistry C6-C9 |
| Recovery Grove | Quiet loop and regrouping space | Zone-local restore/reset instead of shared practice reset |

Map envelope: **3072x1728**, 44% more area than 2560x1440. Ordinary paths
and connections are 160-192 units wide; validation samples their full half-width
every 16 units against collision. Every activity, station, target, gathering
anchor and arena spawn is validated. Houses remain solid; only practice-wall
faces support wallrun. The shared 36x36 player footprint is unchanged.

The saved painted proposal is inspiration, not a collision map or a claim of
finished art. The runtime reuses editable architecture, natural-detail and
wayfinding kits, with quiet practice-floor cues and centered overview zoom.

## Controls and limits

| Input (remappable) | Result | Bound |
|---|---|---|
| Move + Shift | Sprint | Existing drain/recovery; no speed retune |
| Space / wheel up / right shoulder | Directional jump; second jump; outward recent air-wall contact kick | Sprint never changes Jump into Slide; finite two-stage air budget |
| C / wheel down / controller A | Slide; airborne fast fall; second slide press brakes | 22 Stamina, original 300 ms / 780 ms cooldown; 6 protected ticks / 50 ms; brake gives no refund or boost |
| Q / left trigger | Ground roll or airborne dodge | Explicit intent cannot become a wallrun; existing cost/cooldown; late angled air dodge can wavedash |
| V / controller B | Wallrun, airborne redirect, impact tech | Wallrun needs tangent/contact, lasts at most 420 ms, costs 18, locks same surface 900 ms; no i-frames |
| Away input or second V during wallrun | Deliberate detach | No free jump, acceleration burst or protection |
| F2 | Local practice trace on/off | Thirty-Hz samples, maximum 60 seconds, no simulation/network/file writes |
| F3 | Start next local recording | Previous-run echo only with same champion and start within 36 units; no teleport |
| F11 / Shift+F11 | Cycle overview zoom | 50/75/100%; oversized viewport centers the campus |

Jump protection counts real accepted simulation ticks independently from
short-hop/fast-fall airtime and ends on landing. Paid actions can start their own
authored window; steering, facing, wall attachment and animations cannot refresh
one. Air wall kick spends the second air-action stage and cannot replenish an
already spent redirect. Landing direction is remembered for 80 ms and only
fills an otherwise empty first landing tick; current input wins.

## Compatibility and future chemistry

| Seam | Contract |
|---|---|
| Retired vault and crest | No runtime activation functions; numeric modes/timer slots and old geometry helpers reserved for compatibility, not live moves |
| New Evade | Command bit 16; included in transport and prediction masks |
| Jump protection | Canonical player state, prediction fields, snapshot slot 73 |
| Old controls | Schemas 1-9 migrate; new keys never steal a custom binding; new action stays unbound if occupied |
| Material movement | SurfaceMotionPolicy accepts future authoritative material IDs/status; every response is exactly 1000/neutral; no material movement enabled |
| Chemistry integration | C6 contact/exposure must supply authoritative samples, never renderer colors; separate acceptance needed before any friction/grip effect |
| Non-vault landing burst | Explicitly excluded; no activation or replacement acceleration implemented |

## Verification ledger

| Check | Evidence |
|---|---|
| Campus layout / architecture / wayfinding | 3 suites, 248 assertions, zero failures; campus-loop-second receipt |
| Final complete source gate | 66 suites, 19,076 assertions, zero failures/stderr; 36,068 ms; campus-movement-validated receipt, clean import and 120 Hz boot |
| Focused movement revision | 788 assertions: eight directions, reserve variants, exact slide/jump timing, brake, finite air-wall budget, serialized protection and rejected invalid prediction timers |
| Live overview | 1920x1080, 50% zoom; campus-loop-v2-final-overview capture inspected |
| Live movement/practice | 60 frames at 1280x720, 75% zoom; campus-loop-practice-label-720 capture inspected, including corrected character-relative practice label |
| Developer front door | flux.cmd play -SmokeTest completed successfully; current-state and whitespace checks passed |
| Multiplayer | Local real-process host/join, shared greeting, prediction, reconnect, late spectator/Hearth handoff, second round/rematch and host removal passed with a 60-second budget; the initial 40-second attempt timed out before round two |
| Human acceptance | Not run; no claim of final charm, balance, internet connectivity or guaranteed hardware frame rate |

Receipts and captures live under ignored .godot/receipts and
.godot/visual-captures. Do not fabricate published evidence from ignored files.

## Next small slices

| Order | Work | Acceptance |
|---|---|---|
| Complete | Map/movement regression and local host/join verification | Green source checkpoint, usable controls and current docs; human acceptance remains open |
| 2 | C6 bounded exposure/contact | Deterministic first-eight source deposition; immutable worldbone; neutral material motion |
| 3 | C7-C9 chemistry primitives, lifecycle and Crucible teaching | All 36 pairs deliberately testable; reset/replay/network bounded |
| 4 | Human playtest pause | Observe movement intent, readability, map routes and friend workflow |
| Later | Independent activity ownership and local resets; pattern courses | No shared-round freeze/reset leaking into unrelated activities; 2/4/8-player pressure |

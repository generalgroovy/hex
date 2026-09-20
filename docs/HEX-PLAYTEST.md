# H.E.X. five-minute playtest

Status: playtest route for smaller-grid build p55-c7b7694f8d23; human acceptance pending.
Check [the current checkpoint](HEX-SMALL-GRID-CHECKPOINT.md) for exact evidence.
Open `exports/hex-small-grid-20260921/windows/PLAY-HEX.cmd` locally, or run
`scripts/run.cmd` from the HEX checkout. Do not mix protocol54/55 clients.

First compare the 48 px hexes (previously64): the world, actor size, spell radii
and corridor clearance are unchanged. Form Earth cover beside an existing
wall, move along its faces and wait for expiry. Note any awkward seams or
unexpected blocked route. Selected whole cells remain the gameplay authority.

Check sight: aim all eight ways while standing still. Characters in clear
LOS should remain visible behind you; characters behind an opaque pavilion or
active solid hex cover should disappear with their name and health. Walk around
the corner to reveal them. Repeat with reduced effects, different body sizes,
and zoom. F8-F10 must not change the area. Your existing controls and weave must
remain saved. The following chemistry/movement route is otherwise unchanged.

1. Start in Wellspring. Follow the Source Court and Chemistry / Crucible route
   labels. Confirm the route to Loom / Settings is understandable and stations
   remain reachable from either approach.
2. Open Hex Playground and select Water + Fire. Run its ordinary paid demo, or
   equip their Bolts at Spell Loom and cast separately at the same nearby point.
   Observe Steam forming, active hot vents, expiry brackets and disappearance.
   Cross the outer whole-hex edge, then stay briefly inside and compare exposure.
   Repeat on grass and paving; no dummy is needed. Try reduced effects and check
   that the same cells remain marked and the actor remains readable.
3. Use another pair in the matrix, such as Water/Earth Mud or Fire/Air Firestorm.
   Compare its purpose and escape route. Do not expect plain harmless ingredients
   to apply the corresponding reaction automatically. Verify casts spend Flux.
4. Walk forward, sideways and backward while aiming independently. Sprint, slide,
   jump/Float and cast during movement. Compare Small, Middle and Large. The
   isolated shorter-stride experiment was rejected; live gait is unchanged.
   Note ambiguous facing, foot sliding or transition pops without treating a
   screenshot or atlas-bank existence as animation acceptance.
5. Open Spell Loom. Verify twelve labeled positions and your actual keyboard
   chords, change one spell, switch characters and return to check saved weave.
   At Controls Lectern inspect a custom or unbound action. An unbound Interact
   must not display a fictional F key. Close/reopen the game to check preferences.

Use F4 for the compendium; station prompts show your configured interaction
binding. Numbered spell keys attack. Punch/Kick remain unavailable. After menus
or focus loss, release and freshly press held paid actions.

Human questions: Can you distinguish active Steam from expiry? Are whole-cell
boundaries clear on both terrains? Can you read facing while strafing and casting?
Are empty, unbound and unavailable spell positions understandable? Is navigation
between practice and configuration easier? Record the visible build ID with issues.

Networking: use matching builds, Host/Join Farflow stations or the exact commands
in README. Check the checkpoint's localhost result before relying on multiplayer.
Physical two-PC, Internet connectivity and human latency acceptance are separate.

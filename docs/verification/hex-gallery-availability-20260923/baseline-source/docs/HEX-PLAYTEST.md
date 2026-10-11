# H.E.X. five-minute playtest

Status: local contextual Loom review candidate p55-c5d0f6accb97; human acceptance pending. Performance and multiplayer are not accepted.

**Help, Everything eXploded!** — the official expansion of H.E.X.

September23 review: use `scripts/run.cmd` in the HEX checkout for current source,
or `exports/hex-loom-availability-20260923-v2/windows/PLAY-HEX.cmd` for the frozen candidate.
Read [the current evidence and limits](verification/hex-loom-availability-20260923/HANDOFF.md).

First try the contextual Loom correction. Open Chemistry Matrix, then Spell Loom,
away from a station. Browse/filter spells and preview a starter kit: inspection
should work while final Assign/Apply explains the station requirement. Cancel the
preview, close, travel to Spell Loom and interact. Assign Water Heavy/Tide Shell
to slot1; confirm it, close, move and cast. Reopen while that spell is cooling and
try replacing it: the reason should explain the cooldown without sending a failed
request. Moving a retained cooling spell to another position remains allowed.
Wait for expiry and retry replacement, then restart to check the confirmed weave.
A pending host confirmation still permits close and may complete after closing.
This local route does not certify live network failure recovery.

The previous drawing improvements and Water sample remain in this build. Dense-field timing remains over budget; report stutters with
the build ID and the casts/movement that preceded them.
At Spell Loom, equip Water Heavy/Tide Shell and cast onto clear ground in the
Crucible. Watch its launch, travel, impact, full blue hexes and fading crests until
the field disappears. Compare normal/reduced effects and50/75/100%zoom: the same
outer boundary must remain readable. Plain Water remains an ingredient; the pilot
adds no field damage. Report whether the repeated crests look clear or too stamped.
Walk/jump/slide while aiming sideways or backward, then cast. Repeat with another
body size and check your saved controls. Default Evade is B; Q is unassigned.
Station names should remain readable nearby without distant fragments at the fog edge.

Protected visibility review:
Walk around
the Recovery Grove pavilion: its near roof/facade should stay readable while a
character behind it remains hidden with name/health/feedback. Turn aim freely;
sight remains character-centered. Unseen terrain stays visible but shaded; it does
not display live spells or actors. Form and remove Earth cover, then repeat with
50/75/100% zoom and reduced effects. Look for edge fringes during camera motion,
incorrectly bright far walls, hidden spell leaks and abrupt transitions. Human
readability/feel remains your acceptance gate. Existing Loom checks below still apply.

Historical September21 status: P0 repair candidate p55-a0952919d4d5 packaged; broader acceptance milestone incomplete.

## September21 Spell Loom repair candidate

The preserved fallback launch path is in
[the acceptance handoff](verification/hex-acceptance-20260921/HANDOFF.md).
The older smaller-grid route below remains historical. The new milestone is
incomplete: multiplayer, full option acceptance and new asset integration are open.

1. At Spell Loom, select Water Heavy/Tide Shell and assign slot1. Confirm immediate
   success, then close with Escape or X. Move and cast; Flux must be spent.
2. Reopen, filter Fire, drag a spell onto a Ctrl or Alt position. Verify the shown
   binding and press that exact chord after closing. Duplicate assignments should
   swap positions, with twelve unique entries retained.
3. Try replacing a cooling spell: refusal must retain the usable loadout. Swapping
   its position is allowed and must retain cooldown. Retry after natural expiry.
4. Switch character at Gallery, then return. Close/restart and verify your saved
   weave. Report any unsaved notice; do not reset your profile to hide a failure.
5. Check focus loss, repeated Assign and closing an unresponsive panel. A pending
   host request can still complete after closing; timeout must not silently undo it.

Record build ID and exact input sequence. Human controller feel, all32spell
journeys, physical two-PC and visual-pack acceptance remain separate checks.

Historical route for smaller-grid build p55-c7b7694f8d23; these gameplay checks also apply to the current candidate.
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

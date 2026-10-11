# Movement and impact overhaul

Status: implementation candidate; fresh verification and packaging pending. Previous identity portable remains the working fallback.

## Design and scope

This pass targets earned momentum, distinct travel gears, readable projectile
commitment and charming contact feedback. It translates reference principles,
not proprietary physics or copied frame data. [Nintendo's Melee overview](https://www.nintendo.com/en-gb/Games/Nintendo-GameCube/Super-Smash-Bros-Melee-268951.html)
describes directional defensive options; [Respawn's mobility note](https://forums.ea.com/blog/apex-legends-game-info-hub-en/evolution-collection-event-patch-notes/9464059)
explains why strong direction changes need readability/counterplay boundaries;
[STRAFTAT's developer page](https://store.steampowered.com/app/2386720/STRAFTAT/)
provides the compact arena-confrontation reference. The following numbers are
H.E.X. design choices, not measurements of those games.

| Change | Before | Candidate |
|---|---|---|
| Walk / sprint |372.6 /596.16px/s;1.6x|270 /594px/s;2.2x before profile modifiers|
| Slide turn |Heading blend could lose visible speed while retaining a larger hidden budget|Accumulated bounded carve; lost speed stays lost; opposition brakes instead of free reversal|
| Ground action exit |Fast ordinary convergence|Earned excess carry settles at900px/s²; opposing input still brakes firmly|
| Slide admission |250px/s|225px/s keeps all three actual profiles eligible from full walk|
| Air cap |Per-axis cap could admit an overlarge diagonal|Existing900px/s ceiling applies radially|
| Heavy |240px/s,19.2px collision radius,84px blast|180px/s,30px collision radius,120px blast; larger but slower and more committed|
| Rapid |456px/s,6px radius|600px/s,4px radius; weak precise pressure, not high sustained damage|
| Bolt |345.6–460.8px/s|All eight360px/s;12–18px radii and retained element-specific damage/economy|
| Spray |Narrower280/380px fans|300/320px90-degree fans; wider nearby choices, finite ingredient and cover-aware interception|

Travelling launch speeds obey `speed * (strength + 5) = 3600` in worldpx/s:
Rapid1, Bolt5, Heavy15. Direct HP damage is separate. Field slows do not increase
strength, damage, coverage or matter. Lifetimes preserve prior projectile reach;
Rapid's small collider still has a readable pixel-art core. Heavy's larger area
costs20Flux,900ms cooldown,200ms startup and180ms recovery. No new families,
recursive chemistry, global hitstop, character body morphing or paid-budget resets.

## Acceptance and playtest

Root serializes imports, correctness suites, input journeys, native captures and
Windows export. Workers separately own movement/prediction, projectile catalog
and presentation. Correctness, static visual review, human feel, dense120Hz and
different-home multiplayer remain separate gates. Historical performance failure
is not cleared by a configured120Hz boot or a large assertion count.

Try free walking then Shift sprint; sprint→C slide→hold/release Space. Side-steer
to carve; opposite input should brake without restoring speed when released.
Repeat across Small/Middle/Large and all eight directions. Test the same custom
weave with Rapid, Bolt, Heavy and Spray; compare moving targets, cover, slow fields
and an open lane. Heavy should feel committed and consequential, not unavoidable.
Reduced effects should retain the same useful footprint information.

The previous [identity build](../exports/hex-cast-identity-20261008/windows/PLAY-HEX.cmd)
remains available while this candidate is tested. Painted anatomical corrections
and complete slide/roll/flight cycles from that checkpoint remain unfinished.

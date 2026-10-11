# H.E.X. five-minute playtest

Status: current local portable `p57-ac86b7285a04` is ready for human playtest; older routes below are historical.

**Start here:** [PLAY-HEX.cmd](../exports/hex-cast-identity-20261008/windows/PLAY-HEX.cmd),
then use the [character identity and native-size Gallery route](CHARACTER-IDENTITY-CHECKPOINT.md).
The [momentum/roster route](MOMENTUM-ROSTER-CHECKPOINT.md) still describes retained
movement changes, but its evidence belongs to the preceding build.
The [portrait installer/portable `p57-30b90507f932`](PORTRAIT-WINDOWS-DELIVERY.md)
is the preceding verified delivery, not the new changes. The team-package links and October 7 evidence below remain a
preserved fallback, not the latest build. Older p56 output paths are historical
and outside the [two-build retention selection](CLEANUP-PLAN-20261008.md).

Historical October 7 team/chemistry checkpoint `p57-a41d15007f8c` passed
[final Full v3](team-checkpoint-evidence-20261007/full-v3.json): 219 suites /
3,877,314 assertions, zero failures/stderr, import, identity and configured 120 Hz
boot. [Focused v2](team-checkpoint-evidence-20261007/focused-v2.json) passed three
suites / 727 assertions; [independent native review](team-checkpoint-evidence-20261007/review.json)
covers 48 final frames with coarse 960x540 label limits. Portable, delivery,
installer, installed safe close and exact four/six-process Duos/Trios localhost
gates passed. Protocol 57 / snapshot 23 / round 2 cannot join p56 peers.
See the [checkpoint contract and gates](HEX-TEAM-CHECKPOINT.md)
and [exact source identity/handoff](../.agent/HEX-RESUME.md).

The launchers below use the preserved team package, including Duos/Trios and the retained
chemistry card. Older p56 evidence is linked at the end, not selected for play. Alongside the
new five-minute route, check contact-weighted movement, match/respawn clarity, spell setup,
the rival's warning/pressure/recovery rhythm and retained movement/spell combinations.
Sidestep the committed Heavy, use Spray against Rapid, and use the pause to counterattack or recover Flux.
Normal movement and jumps remain important; lingering projectiles are not cleared during a pause.
It is not a finished-game release or dense 120 Hz/Internet acceptance.

## Latest source or preserved package?

The installer/portable below is `p57-a41d15007f8c`; it does not include the later
M1/M2/M3 movement/chemistry fixes, glow/flow or subsequent game-feel work. Follow the
[current source handoff and acceptance status](../.agent/HEX-RESUME.md) to test
those changes. With the development runtime installed, run from the repository:

```powershell
.\scripts\run.cmd --pixel-cast
```

The source and package are separate peers/builds. Evidence below qualifies only
the named team package, not subsequent source changes.

### Preceding combat-choice source check

Source `p57-387ff8d5b670` passed Full 221 suites / 4,166,581 assertions and
12 automated input routes / 7,547 checks, with zero final failures/stderr.
See the [evidence and limitations](combat-choices-evidence-20261007/README.md).
Begin with these three changes; saved custom bindings override the examples.

| Try | Look for |
|---|---|
| Tap/release Space, hold a travel direction, use B in the air, then freshly press C | Deliberate fast-fall can turn the paid dodge into a grounded wavedash if contact is early enough; late descent simply lands. B and C are separate decisions, not one chord. |
| Aim Spray past a narrow central pillar | Exposed flank targets and clear hexes remain reachable; covered targets and covered cells stay protected |
| Watch the Solo Duel rival | Gold HEAVY announces intent; cyan PAUSE counts down a real no-new-casts beat above its nameplate. Lingering projectiles and fields remain dangerous. |

Retained foundations to regression-check if relevant:

| Try | Look for |
|---|---|
| Hold Jump through an air dodge or a consumed wallrun | No surprise flight purchase afterward; release/repress to deliberately request unused flight when legal |
| Choose Slide after buffering Jump during recovery | The newer intent wins; recovery and costs stay unchanged |
| Fire near thin cover, then aim away from the wall | The muzzle cannot bypass cover; Heavy can still fire into clear space |
| Inspect S. Wayne, Oh Tipi, Red Baron and Grace Riva | First-screen air action and actual resource differences; inspection does not equip |
| Spray visible enemies in normal/reduced effects | Element fan and impacts remain, with compact damage numbers and no aggregate hit banner |

The native Gallery overviews are readable at 1280×720; long Details paragraphs
still split across pages. Rapid accents and damage numerals remain subtle.

### Retained glow and movement-flow source check

See the [current glow/flow evidence](glow-flow-evidence-20261007/README.md) for
validation status before treating this source slice as accepted.

| Try | Look for |
|---|---|
| Walk → Shift sprint → C slide, while aiming sideways | Short neutral strokes follow actual travel; no body ghosts, size changes or elemental residue |
| Slide → tap Space → directional B air dodge | Paid, legal transitions remain predictable; current held preparation gradually brakes travel and release inherits remaining velocity |
| Fresh Jump just before forced recovery ends | The existing 100 ms buffer should admit it when legal, not during stun; older/canceled input must not resurrect |
| Bolt / Heavy / Rapid / Spray | Clear element-colored cores and release/contact accents; consumed strength still reads smaller |
| A paid Fire impact | Active material lights its occupied hexes only; no new radius or glow in empty holes |
| Reduced Effects, stop, or open Spell Loom | Trails disappear; steady material glow is suppressed; essential threat shapes and protection cues remain |

Compare S. Wayne, Oh Tipi and Red Baron. These are human playtest questions,
not claims that screenshots establish smooth animation or universal balance.

## Start the preserved team package

Run [HEX-Setup, 110.7 MiB](../exports/hex-setup-teams-20261007/HEX-Setup-p57-a41d15007f8c.exe)
and choose **Install and play**. Later, use the H.E.X. shortcut. The complete
game is included; no Godot or administrator installation is needed. Setup is
unsigned: Windows may warn or block it; do not disable security controls.

Alternatively open [PLAY-HEX.cmd](../exports/hex-teams-20261007/windows/PLAY-HEX.cmd),
or extract the complete [portable ZIP, 110.7 MiB](../exports/hex-teams-20261007/HEX-p57-a41d15007f8c-Windows-x64.zip).
Keep `hex.exe`/`hex.pck` together; direct EXE launch retains
skeleton mode. Saved controls override defaults. Close the window normally to quit.

| Character comparison | Launcher |
|---|---|
| Middle / Oh Tipi | [TEST-OH-TIPI.cmd](../exports/hex-teams-20261007/windows/TEST-OH-TIPI.cmd) |
| Small / S. Wayne | [TEST-S-WAYNE.cmd](../exports/hex-teams-20261007/windows/TEST-S-WAYNE.cmd) |
| Large / Red Baron | [TEST-RED-BARON.cmd](../exports/hex-teams-20261007/windows/TEST-RED-BARON.cmd) |
| Any other identity | Academy > Champions > Attune; or `PLAY-HEX.cmd --champion=grace_reava` |

Approach a service door and press F, or your saved interaction binding.
Attune restores that character's saved weave, or its starter kit if uncustomized.
Inspection alone changes neither character nor spells.

| Action | Default |
|---|---|
| Move / aim | WASD / mouse |
| Sprint / slide | Shift / C |
| Jump | Space: press to gather, release to launch |
| Evade / technique | B / V |
| Spell positions | 1–4, Ctrl+1–4, Alt+1–4 |
| Services | F at a door; Spell Loom changes spells, Controls changes bindings/effects |
| Compendium | F4 / controller Back |

## Five-minute team and chemistry route

Ensure every participant uses **p57-a41d15007f8c** from the current links above.
Do not use the p56 fallback to test these new features or mix peer builds.

1. Before hosting, choose **Duos (2v2)** or **Trios (3v3)** in Farflow Rules.
   Gather exactly four or six connected players; verify each P# and READY/WAITING
   state, then start when everyone is ready. Preview teams lock at round start.
2. Identify AMBER/TEAL and YOU/ALLY/ENEMY without relying on color alone. Check
   shared enemy-knockout points, local respawn, final winner/draw and real rematch.
   Departed scores persist; a whole-team departure forfeits, and a reused ID
   waits as an observer instead of claiming the departed player's team.
3. Read the sealed Charter's damage policy. Shared Fire, Steam and Conflagration
   can hurt allies and self; those knockouts must award no points. Open Farflow
   details and other modals: the LAN panel must not cover them. Compare the
   complete six-person roster and labels at 1280x720 and 960x540; the smaller
   world labels are still coarse, not accepted as universally readable.
4. Offline, run a finite paid two-Bolt chemistry demo. Read its retained observed
   result, paid cost and counter; hover for details, then reproduce it manually
   using the displayed restored-weave/current-binding instructions. Escape/X
   dismisses the card; there is no automatic retry, refund or retained loaner kit.
5. Close normally and relaunch. Confirm saved controls/weaves survive; with a
   wheel-only Jump binding, wallrun help should request a holdable button rather
   than instructing you to hold a wheel pulse.

These are human checks, not completed acceptance. The configured cap remains
eight; dense 120 Hz historically failed, complete authored action cycles are
unfinished, and human balance, audio and physical Internet play remain open.

## Retained movement and solo trial checks

| New match checkpoint | Test |
|---|---|
| Compare movement rhythm | Walk, sprint, stop, reverse and aim sideways while moving with all three size launchers; feet should spend more time planted, without body-size pops. Judge smoothness during actual play, not just frame boards. |
| Filtered spell drop | Filter the Loom away from an equipped spell's element, then drag that equipped spell back to the library. Its exact card and matching filter/footer should become visible; close the panel and cast. |
| Solo court context | Start, retry and leave Solo Duel; both visible and dimmed terrain should describe DEFEAT OH TIPI only during the trial. |
| Multiplayer result/respawn | With available local peers, use Duel Knot or Sparring Circle. Track YOU/P# standings, respawn countdown and final score; active material must stop harming anyone during RESULT. Do not assume every wall disappears: authored permanent walls remain. |
| Reconnect | Leave and return during an active round through the supported return flow; identity and round ownership should remain stable. This is not permission to bypass network or account controls. |

The current package retains 1v1, four-place FFA, Solo Duel and free practice
alongside Duos/Trios. The Internet relay is not deployed, so skip friend-network
checks if local peers are unavailable.

| New checkpoint | Test |
|---|---|
| Find the encounter | Click **SOLO DUEL TRIAL** on the left, or interact at the Rest Pavilion and choose the trial card |
| Understand the kit | Read the displayed bindings for the S. Wayne loaner: Water Spray, Earth Spray, Fire Bolt and Fire Rapid; your own weave is preserved |
| Fight | After four seconds, defeat Oh Tipi before the 72-second clock ends; use ordinary paid spells, movement and cover; remain inside the marked court |
| Read the warning | Watch the six-segment HEAVY badge above Oh Tipi; compare Normal/Reduced Effects. It should disappear when the windup ends, after leaving the court and when the rival is hidden by existing visibility rules. It announces intent, not a guaranteed shot. |
| Recover safely | Inspect the outcome, retry, then return to Wellspring; verify your selected champion and original spell weave return unchanged |
| Compare the environment | Visit Commons, Chemistry and Movement; authored stone/soil should be more continuous, without distracting repeated bars or loss of active-field clarity |

This is an introductory practice encounter. The tested paid movement/jump/Fire
Bolt route clears in 15.79 seconds including countdown with 44/90 health shown;
human difficulty and fun have not been accepted. The trial's court label states
DEFEAT OH TIPI, and the rival's world label is OH TIPI.

### Retained movement and casting checks

| Try | What should be clear |
|---|---|
| Jump, air-dodge with B, then after its initial commitment change direction and press V | The paid air turn redirects the remaining dodge. It must not renew protection/duration. Land before repeating the comparison. |
| At the Loom put Heavy in position 1 and Bolt or Rapid in position 2; keep 1 held while pressing and holding 2 | Slot 2 keeps repeating instead of being blocked by held Heavy. Tap a fresh Heavy to take priority. With two held repeat-enabled slots, the lowest slot owns intent even while on cooldown. |
| Try Water, Fire, Earth and Charge in Bolt/Heavy/Rapid/Spray, then compare Normal and Reduced Effects | Releases and projectile cores use distinct elemental shapes; Heavy is stronger-looking, Rapid deliberately compact. Existing collision reach, fields and impact rules stay unchanged. |
| Tap jump, then hold and release it while grounded | A temporary cue above resources shows charge and cost without mouse hover. Full charge is reached quickly (300 ms); release launches and clears the cue. |
| Sprint, slide, then gather/release a slide jump | The cue identifies slide-jump preparation and its actual cost, including movement-chain changes. It must not silently switch to ordinary jump when the slide timer ends. |
| Chain movements until Stamina is low; prepare another jump | The cue distinguishes charge from affordability: full charge can still show NEED STAMINA. Cooldown or minimum commitment can show a brief wait. Do not alter your saved profile to force this. |
| With a controller, aim outward near map edges and toward the resource HUD | The entire reticle remains visible. A nearer screen marker does not shorten spell range or change accepted aim. Open/close services: it must not leak into blocked gameplay or cover modal menus. |
| Assign a spell at the Loom, close it, cast, jump and land near cover | Confirmation stays visible, the chosen spell works and movement resumes. Compare Normal/Reduced Effects; check readable ground effects and impacts without changed reach through walls. |

If no controller is available, skip that trial and note it as untested. Mouse
placement is unchanged and does not use the controller-only clipping behavior.
For a quick size comparison, repeat jump/slide-jump with S. Wayne and The Red Baron.

## Install, update and share

Share the **single setup EXE** with friends, not files copied out of its installed
version directory. It installs in `%LOCALAPPDATA%\HEX`; existing game saves stay
in the Godot user profile. Close the game before updating. Obtain the newer
trusted setup file and choose **Update and play**; **Previous build** selects a
verified retained version. **Get updates** only opens the fixed GitHub releases
page after confirmation, not an automatic update download. Public release is not
published yet. Internet connection by join code is also not available yet.
See [delivery and manual removal instructions](../packaging/hex-windows/README.txt).

The existing thirty identities have four held jump keys, not complete authored
motion cycles. Dedicated strafe/backward, slide, roll, flight and independent
airborne-casting art remain unfinished. Judge feedback and regressions, not final art.

## Current p57 evidence and ongoing limits

These receipts qualify the linked p57 package within their stated local scope.

| Current gate | Result |
|---|---|
| [Full](team-checkpoint-evidence-20261007/full-v3.json) / [focused](team-checkpoint-evidence-20261007/focused-v2.json) | 219 suites / 3,877,314 assertions and three / 727; zero failures or stderr |
| [Native review](team-checkpoint-evidence-20261007/review.json) | 48 exact-hash frames, review with limits; static team fixtures and two real paid chemistry casts, not timed animation or human acceptance |
| [Portable](team-checkpoint-evidence-20261007/portable.json) / [delivery](team-checkpoint-evidence-20261007/delivery-files.json) | Portable verification and 16 file checks passed; preserved fallback |
| [Installer](team-checkpoint-evidence-20261007/installer-tests.json) / [installed launcher](team-checkpoint-evidence-20261007/installed-smoke/receipt.json) | 33 checks including real payload; installed rendered startup and safe close, game/launcher exit 0, zero stderr, no forced stop |
| [Duos localhost](team-checkpoint-evidence-20261007/network-duos/receipt.json) | Four same-export processes; exact roster/teams, round/result/Hearth/rematch in all participants; 71,648 ms |
| [Trios localhost](team-checkpoint-evidence-20261007/network-trios/receipt.json) | Six same-export processes; same complete team lifecycle; 98,848 ms |
| [General localhost](team-checkpoint-evidence-20261007/network-general.json) | Three processes; late spectator, exact-actor return, rematch and reason-bearing host release; 52,871 ms, zero stderr |

Both team receipts record zero stderr and unchanged package identity. Durations
measure whole-harness marker observation, not network latency, FPS or sustained
120 Hz. The harness stops its owned headless processes after completion; normal
safe close is separately tested by the installed launcher. The general lifecycle
regression is separate from exact team-mode acceptance.
Native captures use synthetic inputs, not physical-controller/resize/DPI testing.
Historical capture-local player reuse lowered complete-publication medians by
5.31% in the dense fixture and 7.30% with Rampart. Those warm diagnostics are not
fresh p57 performance measurements. Historical dense-load timings
still exceed the 120 Hz budget and eight unseen spawn notices are lost per dense
test repetition. No fresh sustained-load or rendered-FPS acceptance was performed.
Eight players are configured, not certified dense capacity; 16/32/64 are unsupported.
Physical two-PC/Internet play, audio and human feel remain open; relay undeployed.
[Historical p56 evidence](HEX-MATCH-REFINEMENT.md) ·
[Current checkpoint](HEX-TEAM-CHECKPOINT.md) ·
[Historical performance measurements](HEX-OPTIMIZATION-CHECKPOINT.md).

The old **p56-2411d5bf5c95** and **p56-460db467f9cd** packages are outside the
current two-build retention selection. Their historical acceptance evidence is
preserved, but their binaries may be retired by explicit cleanup. Use the
current portrait build or the retained team build above; never mix their files
or join peers on a different exact build.

Report the build, character, input device, action and exact cue shown; a short clip
helps. Most useful: do air turns respond predictably, do held spell combinations
match your intent, and can you recognize each element without relying on color alone?

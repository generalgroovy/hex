# H.E.X. readable rival checkpoint

Status: October 6 locally verified build `p56-59c01e55fca2`, ready for human testing.

[Install and play](../exports/hex-setup-rival-20261006/HEX-Setup-p56-59c01e55fca2.exe)
or [play without installing](../exports/hex-rival-20261006/windows/PLAY-HEX.cmd).
[Portable ZIP](../exports/hex-rival-20261006/HEX-p56-59c01e55fca2-Windows-x64.zip).
The [prior verified duel build](../exports/hex-duel-20261006/windows/PLAY-HEX.cmd)
is preserved. Setup is unsigned, bundled and per-user; do not disable Windows
security controls. No public release or automatic Internet update feed is configured.

The offline Solo Duel now uses a separate paid rival policy. The historical
interception practice schedule, combat balance, world geometry and networking
remain unchanged. This is a bounded encounter refinement, not full-game completion.

| Beat | Time | Player opportunity |
|---|---|---|
| Heavy warning | 0.8 seconds | Rival commits a facing direction and requests no movement; sidestep or use cover |
| Mixed pressure | 1.8 seconds | Paid Heavy, two spaced Bolts and a short Rapid burst; use movement and Spray interception |
| Recovery | 1.4 seconds | Rival requests no new casts or movement; counterattack or recover Flux, avoiding lingering shots |

The four-second countdown and 72-second deadline remain. Rival movement uses
normal direction/sprint inputs and court steering, not teleports or free Stamina.
Resources and cooldowns still refuse unaffordable attacks. The HUD uses the same
policy clock as commands; a warning signals intent, not guaranteed admission.
The court plaque and world name identify the actual duel; result health uses
the same integer formatter as the ordinary HUD.

## Fresh acceptance

| Check | Result |
|---|---|
| Focused regression | Six suites, 1,666 assertions, zero failures or stderr |
| Real stationary-player encounter | All three enemy families admitted through paid combat; exact first Heavy Flux cost and real projectile damage confirmed |
| Ordinary winning route | 1,895 ticks / 15.79 seconds, 28 paid Fire Bolt casts, ten direct hits, 44.138/90 health; directional movement and charge/release jump inputs |
| Production frame lifecycle | Countdown quarantine, paid rival command, result freeze, retry/return and original weave restoration pass |
| Native presentation | All 17 PNGs reviewed, including 960 by 540 menus and Normal/Reduced warnings, pressure and recovery |
| Full regression | 210 suites, 3,765,288 assertions; import, source identity and 120 Hz configured boot pass; zero failures/stderr |
| Frozen Windows delivery | 3,103 production records; portable and 13 delivery checks pass; prior package unchanged |
| Installer and safe close | 33 mechanism/payload checks; actual isolated installed launcher and game exit 0, no forced stop, empty stderr |
| Same-export localhost | Host/join, movement reconciliation, round, late join/spectating, return/rematch and host release pass in 54.058 seconds under the unchanged 120-second deadline |

Evidence is retained under [rival-evidence-20261006](rival-evidence-20261006),
including failed focused attempts, native PNGs, Full logs, package and installer
receipts and localhost logs. Localhost does not establish different-home play.

| Artifact | SHA256 |
|---|---|
| Setup EXE, 116,021,248 bytes | `c2a702e8a5699c0203597535083bcf29e757fd513a70db5cbd346bcbcd0f0947` |
| Portable ZIP, 115,991,173 bytes | `114e9f55deff5538c3f8f249b454c96a96e297e931d5ca46697419ddf793ddc6` |
| Game PCK | `4bbc365fe301ed1f476b5c37c2fbf110be0ead643529ff0910ca34d61dbedc4c` |

The earlier rush and ground-only circle fixtures lost. Their failed logs are
retained; production was not weakened to make them pass. The successful synthetic
route proves reachability, not human difficulty, fair reaction times or physical
keyboard/controller acceptance. Defeat/timeout render fixtures are explicitly
staged layouts, not separate completed gameplay runs.

## Test and next decision

Enter SOLO DUEL TRIAL from the HUD or the Rest Pavilion. Read the disclosed
S. Wayne loaner bindings, then compare rushing with dodging the Heavy and attacking
the pauses. Check whether the warning is noticeable while following your character,
whether Spray is useful against Rapid, and whether the recovery interval feels fair.
Leave or retry freely; your selected champion and normal weave remain preserved.

The execution prompt now prioritizes visible player benefit, proportionate
verification, focused context and disjoint delegation. It follows the principles
of [OpenAI's guidance on lean task instructions](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra),
while keeping the repository's required release checks and authority boundaries.

Dense 120 Hz, complete authored action cycles and physical Internet play remain
unaccepted. The relay is undeployed and eight-player configuration is unchanged.
No commit, push, publication, account change or paid limit reset is included.
Only the duplicate 115,991,173-byte installer staging ZIP was removed after
hash equality with the retained portable; embedded setup and all prior builds remain.
Previous delivery evidence remains in [the prior duel checkpoint](HEX-DUEL-CHECKPOINT.md).

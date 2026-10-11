# H.E.X. — readable freedom

Status: current design direction; bounded presentation checkpoint READY FOR LOCAL PLAYTEST.

Build `p56-6523a2fb7648`; [launch the detailed-art portable](../exports/hex-readable-freedom-20260928/windows/PLAY-HEX.cmd)
or extract the [complete Windows ZIP](../exports/hex-readable-freedom-20260928/HEX-p56-6523a2fb7648-Windows-x64.zip).
Keep EXE/PCK together. This is a local solo candidate, not a friends-ready installer.

Design direction, 2026-09-28. The user reports that the contact-clarity build is
much better and requests deeper inspiration from Melee, Apex, Noita, Magicka,
Enter the Gungeon, League and Dota. This is positive general feedback, not a
blanket acceptance of performance, multiplayer, all artwork or every mechanic.

**Core promise:** outplay through movement, change the situation with magic,
and understand what happened quickly enough to make a better next decision.
Depth comes from interacting rules and competing choices, not an ever-growing
number of buttons, particle systems or exceptions.

## Reference interpretation

These are H.E.X. design adaptations, not promises to reproduce another game's
frame data, engine, assets or controls.

| Reference | Adapt for H.E.X. | Concrete direction | Do not import blindly |
|---|---|---|---|
| SSBM Melee | Expressive execution, momentum and landing decisions | Deliberate direction, finite air options, clear spent/available feedback, meaningful action transitions; practise a chain before adding another technique | Release-to-jump is H.E.X.'s current contract, not Melee's timing; no universal invulnerability, hidden mandatory animation cancel or unbounded speed |
| Apex / Titanfall | Routes and terrain as movement decisions | Wall chains with escape paths; speed that can be redirected; cover that supports fighting while moving | Camera shake, visual streaks, battle-royale looting or exact first-person movement constants |
| Noita | Discoverable cause and effect | Finite paid ingredients, consistent material outcomes, testable experiments and tactical environmental use | Per-pixel physics or unrestricted recursive reactions inside a networked 120 Hz simulation |
| Magicka | A compact elemental vocabulary with many applications | Element + delivery + position + timing; paired experiments that teach useful answers rather than only bigger damage | More spell buttons, combinatorial exceptions or automatic friendly fire before explicit balance/remote acceptance |
| Enter the Gungeon | Readable patterns, cover and committed evasion | Recognizable projectile silhouettes, visible gaps, strong impact punctuation; walking through a gap must remain a useful alternative to dodging | A screen full of bullets without useful negative space; copying an invulnerability window to every movement action |
| League of Legends | Visual priority, recognizable silhouettes and counterplay | Threat geometry matches authority; formation/active/decay read differently; one dominant cue per important event; body facing remains identifiable | Competitive information conveyed only by colour or cosmetics; automatic camera movement that defeats aim |
| Dota | Situational tools, positional advantage and contextual learning | Explain what a spell changes, who benefits, what stops it and when to spend it; provide useful optional in-game guidance | Large item economies, long disabling chains, hidden interactions or a text-heavy HUD |

Primary research supports the direction without prescribing our tuning:
[Riot's clarity principles](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/)
emphasize conveying gameplay, attention hierarchy and limiting noise;
[Noita's official description](https://noitagame.com/) emphasizes materials and
player-created magic; the [Magicka publisher description](https://store.steampowered.com/app/42910/Magicka/)
describes combinable elements and cooperative experimentation.
[Gungeon's publisher description](https://store.steampowered.com/app/311690/Enter_the_Gungeon/)
combines bullet patterns, rolling and cover;
[EA's movement advice](https://help.ea.com/au/help/apex-legends/apex-legends/how-to-play-apex-legends/)
connects sprinting/sliding with traversal tools;
[Dota's in-game guide system](https://www.dota2.com/workshop/builds/overview?l=english)
provides contextual tactics. No exact Melee frame-data claim is made here.

## Unifying rules

| Rule | Acceptance question |
|---|---|
| Every strong action creates a decision for its opponent | Can a tester name an actual counter and execute it with the available time, space and resources? |
| Movement and magic interact without stealing control | Can the same player aim one way and travel another, read their low/air/ground state, and understand why a chain ends? |
| Costs buy different opportunities | Do Bolt, Heavy, Rapid and Spray each solve a distinct problem without one replacing the other three? |
| Threats speak through shape, timing and colour together | Can the player distinguish warning, active harm, harmless matter and decay in normal/reduced effects? |
| The hex is the field boundary, not the movement grid | Does the visible affected-cell union exactly match authority while player/projectile motion remains continuous? |
| Presentation never changes authority | Do head/feet anchors, hurtboxes, timing and contact stay unchanged through squash/stretch, impact accents and reduced motion? |
| Teaching is accurate and optional | Does a hint reflect actual bindings and spent resources, without promising an unavailable action or blocking combat input? |
| Performance is part of responsiveness | Are worst-tick costs measured without lowering caps, hiding rejected work or changing paid outcomes? |

The existing 30 identities, three volume-first sizes, same wall clearance,
size-specific hurtboxes, no live trails, compact stationary reactions, fixed
75% camera, four service directories and first-eight/four-delivery scope remain.
No new races, delivery families, recursive chemistry or physical hex-worldbone
migration is authorized by this design note alone.

## Visual direction — part of this run

The user's follow-up explicitly extends these influences to all visual asset
categories. Preserve H.E.X.'s approved character references and original art;
borrow principles, not another game's characters, textures or interface.

| Category | Design treatment | Acceptance / scope |
|---|---|---|
| Characters | Readable Gungeon/Oracle-era shapes with League-style silhouette priority; three volume-first bodies, roughly equal heads, strong hands/feet and identity accents | Front, side, back and diagonals recognizable at actual 75% zoom; aim/cast upper body and travel lower body remain understandable; no baked-in elemental effects or weapons |
| Character animation | Melee-like readable anticipation, contact and recovery; Apex-like momentum response; restrained squash/stretch, torso follow-through and alternating planted feet | Input remains immediate; feet, skulls and hurtboxes stay consistent; no added cosmetic lockout, ghost body or trail; normal/reduced review per action and size |
| Map and assets | Gungeon's clear fight spaces plus Noita's material logic; charming reusable hex-compatible architecture and landmarks | Quiet navigable floor, visible cover edges/doors, obvious wallrun surfaces; decorative detail cannot imply a collision or traversal option that does not exist |
| Elements / reactions | Magicka's recognizable ingredients and Noita's material personalities; stable element palette, mixed-component reaction palette, distinct shape/cadence | Earth looks solid, Water pools/ripples, Fire licks upward, Air gusts; avoid identical coloured disks; no RGB-only status, false movement, hidden cells or decorative range circles |
| Projectiles / impacts | Gungeon/League visual hierarchy: delivery silhouette, element identity, actual travel direction, then short contact punctuation | This run: test a small inset true-travel nose facet on existing projectiles; no tail, radius change, particle emitter or replacement atlas |
| Indicators / GUI | League/Dota-style priority and context, with retro material/framing consistency | Active danger/protection and actionable availability outrank decoration; short cards and useful details; never advertise spent/unaffordable actions as ready |

Animation grammar: anticipation communicates preparation, the active pose matches
the actual action, contact confirms an event, and recovery settles the body.
Not every event gets every effect. Protect silhouette, negative space and useful
contrast before adding particles. Keep essential cues in reduced effects. Sound
can reinforce a cue later but may not be its sole carrier.

Character, environment and full reaction re-authoring are staged follow-ups, not
claimed complete by this bounded pass. The current run includes the cross-asset
design specification, practice corrections and one reviewed projectile pilot.

## Small implementation order

| Order | Slice | Completion evidence |
|---|---|---|
| 0 — current | Truthful practice feedback plus a small inset true-direction projectile facet | Actual bindings/chain costs, compact cards, no authority mutation, bounded geometry, native normal/reduced review |
| 1 | Attribute the remaining rare cast/contact spikes, optimize one proven source | Same workload and tick/event outcomes; separate simulation, snapshot and render timing; retained 8.333 ms target |
| 2 | Movement feedback audit: squat, launch, air action, landing, recovery | Small/Middle/Large in eight directions; paid command route; show the reason for failure without input latency or extra HUD clutter |
| 3 | Three optional practice encounters using existing areas and spells | The Stitch: walk/evade readable gaps; Switchback: choose wall-chain or grounded cover; Pressure Cooker: form, leave and counter a paid field; each has a safe ordinary exit |
| 4 | First-four-element tactical workshop | Ten unordered pairs including mirrors; each has distinct purpose, visible boundary, useful counter and finite budget; test both participants' choices |
| 5 | Restrained combat/art polish | Prioritize Rapid/weakened-projectile motion recognition at native zoom, then palette-limited material silhouettes; no carpet of identical symbols, circles or trails; distinguish hit/blocked shot/reaction; cached/reused work |
| 6 | Same-build cooperative acceptance | Full lifecycle and two physical machines before installer/update promotion; guide guest/host permissions correctly |

Encounter names describe proposals, not installed features. They must use the
shared authoritative spell/movement commands, not a separate demo simulation.
Reset is explicit and cannot grant resources during a live round. Do not reward
repetitive input count: teach a tactical outcome and let players find their route.

## Current bounded implementation

Only presentation instructions, a bounded projectile cue and tests change in this slice. The ordinary
airborne hint now checks the spent dodge flag and the existing chain-adjusted
Stamina calculation. Neutral fast fall stays described as free; unbound controls
and forced-control/commitment precedence remain honest. The live Crucible card
no longer promises a generic jump escape from Steam. Retained legacy-kernel
guides are not rewritten into different mechanics or re-exposed as current rules.

Ownership: one delegate owns the movement coach and its unit tests, then the
projectile presenter and its unit tests under separate explicit ownership; the lead owns
the live Crucible wording, integration tests, native review, documentation and
serialized engine/package work. No simultaneous engine runs or balance edits.

## Validation and honest limits

| Gate | Fresh result for this build |
|---|---|
| Focused regression | 9 suites / 99,528 assertions; zero failures/stderr |
| Native presentation | 12 controlled-state/specimen frames at 1280x720; all reviewed by lead, four additionally reviewed independently; no clipping in the revised cards |
| Separate Windows portable | Source identity, export, native art admission and safe close passed |
| Full regression, dense/rendered performance, physical two-PC, human feel | NOT RUN in this bounded slice |

[Receipts, captures and retained failures](readable-freedom-evidence-20260928/README.md).
The native capture fixture was corrected after two rejected attempts; production
behavior did not change during that repair. Static projectile specimens preserve
colours and family shapes, but do not establish improved reaction time or prove
that the inset facet alone improves direction recognition. Rapid and severely
weakened shots remain very small; native moving-scene review is still needed.

No new motion/character/environment art campaign is claimed complete. Previous
contact-clarity dense simulation p95 was 18.315 / 20.027 ms against 8.333 ms and
included 240+ ms spikes; that unresolved finding remains a priority, not a fresh
measurement for this presentation slice. The `p56-fa6d17ce9f39` portable remains
the immediate fallback. Installer and historical `docs/current-checkpoint.json`
are unchanged; nothing is committed, pushed or published.

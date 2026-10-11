# Reference-led gameplay and identity refinement

Status: IMPLEMENTED AND SOURCE-QUALIFIED, October 9, 2026. Full 227-suite, actual
input and scoped native acceptance passed; portable delivery is recorded in the
current handoff. The preceding identity portable remains preserved.
The [six-element expansion](SIX-ELEMENT-DYNAMIC-REFINEMENT.md) adds the later
movement, animation and complete-combination requirements; its executed checks
are recorded in the [integration evidence](reference-refinement-evidence-20261009/six-integration.md).

H.E.X.'s objective remains movement-led elemental combat: learn a small action
vocabulary, then make deeper choices through timing, finite matter, interception
and temporary terrain. This pass adds the user's requested distinct situational
race and character passives using existing controls, and repairs concrete movement,
cover, menu and practice-help defects. It includes the inherited movement/impact
candidate; those earlier numeric changes are not newly invented by this pass.

## What the references establish

The evidence distinguishes a shipped technique, a developer's reported experience,
and an H.E.X. hypothesis. None of the sources is a controlled test of H.E.X., and
commercial success is not causal evidence for a particular tuning number.

| Reference and primary evidence | Specific useful technique | H.E.X. translation and limit |
|---|---|---|
| [Respawn developer controls interview](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right) | Repeated traversal testing; intentionally constrained slide turning; teaching wall trust through level design | Preserve accumulated momentum and deliberate braking; do not restore discarded velocity. Existing practice routes teach the real inputs. First-person camera tricks are not automatically suitable for a top-down game. |
| [Nintendo's Melee description](https://www.nintendo.com/en-gb/Games/Nintendo-GameCube/Super-Smash-Bros-Melee-268951.html) | Directional defensive options and timing-based projectile responses | Keep paid dodge, commitment and follow-up choices. The source does not establish Melee frame data or justify an exact H.E.X. dodge duration. |
| [Respawn's Apex range redesign](https://www.ea.com/ea-play/news/arsenal-season-game-updates) | Equipment core, agility course, duel area and configurable combat practice organized by purpose | Keep Wellspring's configure/practice/fight loop; repair contextual directions and bindings. More square metres are not evidence of a better map. |
| [EA's current Legend guide](https://help.ea.com/en/articles/apex-legends/abilities/) | Different passives key identity to contexts: Bangalore under fire while sprinting, Revenant movement posture, Horizon aerial control, Octane recovery outside damage, Rampart weapon handling | Race and personal perks use visible action/resource windows and explicit opportunity costs. Names, exact modifiers and thresholds are original H.E.X. hypotheses. No copied abilities, assets or extra buttons. |
| [Dodge Roll developer interview](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-) | Hand-authored rooms refined by play; reload timing creates tension; advanced reload moved out of the mandatory beginner loop | Preserve cover as a real counter, show actual damage, and put perk detail behind a readable overview. No mandatory third resource or new input sequence. |
| [Noita's developers](https://www.noitagame.com/) | Consistent interacting materials produce experiment-driven outcomes | Preserve finite paid hex matter and shared rules. Pixel-scale simulation and recursive chemistry do not transfer to H.E.X.'s bounded network model. |
| [Magicka's publisher](https://www.paradoxinteractive.com/games/magicka/about) | A shared elemental vocabulary composes into tactical effects | Use the six-element/four-family grammar with Ice and Charge as derived effects; identity perks do not mint ingredients or multiply outgoing spell damage. |
| [STRAFTAT's developer description](https://store.steampowered.com/app/2386720/STRAFTAT/) | Short confrontations with arena-specific spatial and weapon decisions | Compare cover, exit and retry choices in current arenas. Its map count and weapon lethality are not targets to copy. |

The complete domain research and independent review notes are in
[movement](reference-refinement-evidence-20261009/movement.md),
[combat](reference-refinement-evidence-20261009/combat.md), and
[world/menu](reference-refinement-evidence-20261009/world-menu.md).

## Decisions across the game

| Aspect | Change or deliberate retention | Observable acceptance |
|---|---|---|
| Movement | Retain earned slide/ground carry; repair stale air-dodge recovery speed | Counter-steer then release cannot restore discarded speed; neutral and committed controls stay exact; costs and prediction agree |
| Projectiles | Retain four distinct delivery roles; align Heavy blast cover with physical impact | Exposed and protected targets differ correctly at worldbone corners and all six hex faces; all elements/strengths keep finite ledger |
| Elements | Retain consistent first-grade matter, existing counters and exact occupied cells | Paid exchange, interception, chemistry, snapshots and all-pair regression suites; no passive-created material |
| Race | One named passive for each of 21 ancestries | Every window is satisfiable, effect is live, counterpart cost is visible, and window exit ends the effect |
| Character | One additional passive for each of 30 identities | Unique trigger/effect signatures independent of percentage values; exact wire mapping and saved selection |
| Resources | Contextual recovery rates and positive movement-cost adjustments | No skipped waits, free actions, zero-damage immunity, resource overflow or air-budget reset |
| Menus | Restore left-stick and physical-key Compendium navigation; show both perks | Neutral/rearm, diagonal arbitration, close/reopen and no gameplay-input leakage; all thirty layouts fit |
| Practice | Show current bindings and current slide/brake/impact rules | Rebinding and controller/wheel cases; no stale hardcoded V or discarded brake behavior |
| Map/environment | Repair southern district links from 128 to 160 px and spread practice targets to 160 px gaps so a centered Heavy can teach single-target aim; preserve activities and full-clearance geometry | Actual map loader, route/cover suites, every-4-px full-width sweeps and real Heavy reach; invalid links and overlapping practice lanes must fail |
| Feedback | Hit feedback reflects actual Health lost; keep clear bounded impact/landing cues | Mitigation, vulnerability, threshold crossing and lethal damage report the same amount as authority |
| Networking | Include identity/resource/cast context in movement prediction; protocol 59 | Strict packet bounds, snapshot continuation and delayed replay; no physical-Internet claim |
| Performance | Avoid copies in perk hot-path lookups; evaluate only applicable effects | Source identity and correctness gates; dense sustained 120 Hz remains a separate unresolved measurement gate |
| Art/audio | Retain original cast and existing effects rather than regenerate unrelated assets | Native normal/reduced captures; painted anatomical consistency and complete action cycles remain open |

## Passive contract

Both passives apply to living champions, using state already owned by the
simulation. A race describes a reusable posture or resource habit; a personal
perk chooses a more specific tactical situation. No affinity restriction forces
a spell choice, and a perk does not require an extra button. The full catalog is
available in-game; source definitions are `src/content/race_perk_catalog.gd` and
`src/content/character_perk_catalog.gd`.

Ratios multiply and clamp to 75–135% overall. The numeric bounds are conservative
H.E.X. starting hypotheses, not values proven by Apex or any other reference.
Outgoing damage, material strength, immunity, air uses and cooldown ownership are
unchanged by perks. Health/Flux/Stamina recovery still obey their normal delays
and seals. Resource thresholds use exact integer comparisons: low is at most a
third; high Flux/Stamina is at least two-thirds; high Health is at least three-quarters.

Startup reads the state before Flux payment; that spell's cooldown reads the release posture.
An admitted timer never changes mid-countdown. Damage and knockback read the
actual defensive window, and combat feedback reports the realized Health loss.
The visual cast-recovery timer alone is not a casting restriction; a peer review
rejected perks that only changed that timer and replaced them with actual
spell-owned cooldown modifiers. Walking/resting windows exclude forced and authored movement. Sprint windows use
the current tick's paid admission, including refusal and release.

This yields testable choices, not automatic balance acceptance. A meaningful
playtest should compare each identity with the same weave, repeat a favorable
and unfavorable encounter, and ask both players what caused the advantage and
how to counter it. Preserve a losing case; do not judge by wins alone.

## Collaboration and verification

Three workers own movement/race research, combat/character research, and world/menu
presentation. Root owns the shared policy, integration, protocol, documentation
and serialized engine runs. Movement and combat independently reviewed each
other's defect fixes; the reviews added six-face cover controls and exposed damage
reporting and sprint-window integration faults before acceptance.

Exact pre-edit copies are retained under `.godot/reference-refinement-baseline/`;
the starting dirty inventory is in the evidence directory. Original artwork,
user changes and working packages are preserved. Fresh result receipts will be
linked here after execution. Local correctness, native readability, human feel,
dense performance and different-home multiplayer are separate acceptance states.

The first focused run exposed an inherited map-loading failure: both new southern
district connections were 128 px wide, below the unchanged 144 px validator
minimum. Their 160 px correction matches existing southern bridges, preserves
the endpoints and nearby practice walls, and restores actual map loading.
The practice range also needed adjustment after Heavy's radius increased: its
120 px target gaps were inside the 138 px blast-plus-target reach. Moving only
the two outer targets and matching firing anchors 40 px outward gives 160 px
gaps; between-target placement still reaches both, and a centered hit can be
compared with it. The existing activity, center target and target count remain.
The original failed receipts are retained. Stale pre-overhaul spell expectations
were corrected while keeping independent numeric checks and a separately
validated fractional-speed formatting control. A new snapshot fixture incorrectly
removed the required host, then retained its unconfigured wire-zero default.
A gate-by-gate probe showed all thirty remote profiles valid and the real host
profile alone making the complete snapshots valid. The fixture was corrected
without relaxing identity or membership validation. Sylph's rising movement premium is now included in exact paid-route
assertions instead of applying a flat cost to every identity.

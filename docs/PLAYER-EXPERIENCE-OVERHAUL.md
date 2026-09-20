# FLUX player-experience contract

Status: **canonical experience and usability contract**.

FLUX should be immediately playable, deeply expressive and pleasant to inhabit
without explaining itself through a conventional menu or text wall. Movement,
spell geometry, elemental chemistry, champions and world state combine into a
player sandbox; the same production systems provide safe developer iteration.

Current authority is Windows, Godot 4.7.1, 120 Hz, protocol 42, five playable
champions, forty-one runtime-proven spells, twelve equipped positions and a
compiled but mutation-gated 36-reaction first-eight catalog.

Latest ordered design and acceptance:
the [expressive airborne feedback](MOVEMENT-M1-M5-ACCEPTANCE.md#expressive-airborne-feedback)
is the active movement-only revision; larger Stamina pools, physical jump
continuity and exact protection readability precede further chemistry.

Following that user playtest, the existing deferred order remains
[`CORE-GAMEPLAY-AND-CHEMISTRY-REVISION.md`](CORE-GAMEPLAY-AND-CHEMISTRY-REVISION.md).
The 2-5 second deposits and Level 1 pair effects are next implementation work,
not a claim that chemistry already runs.

## 1. Experience north star

```text
arrive in the Wellspring
-> understand movement by moving
-> cast and receive immediate readable feedback
-> discover that spells change space, not only Health
-> combine movement, geometry, elements, terrain and teammates
-> recover/reset quickly
-> form a personal style and try a harder idea
```

The game is easy to begin because defaults are strong and interactions are
contextual. It is hard to master because several simple languages compose—not
because rules, states or failures are hidden.

## 2. Fun and depth filter

Every gameplay addition must pass all six questions:

| Question | Required answer |
| --- | --- |
| What decision does it create? | Position, timing, aim, momentum, resource, world state or teamwork changes meaningfully. |
| What can the opponent/player read? | Origin, commitment, active geometry, ownership and recovery/counter are visible before consequence. |
| What can combine with it? | It connects to at least two existing languages rather than remaining an isolated gimmick. |
| What prevents repetition? | Geometry, routes, state, timing or player behavior changes the best response. |
| What is the honest cost? | Flux, Stamina, startup, cooldown, recovery, position, setup or a destructible/interruptible object. |
| How does failure teach? | One clear reason and a quick retry reveal what to change. |

If an addition only raises damage, particle count, text volume or option count,
simplify, combine or defer it.

### 2.1 Slice priority without design drift

Choose the highest unresolved row; within a row prefer the change that improves
the most acceptance journeys with the smallest new rule surface.

| Priority | Deficiency | Preferred response |
| ---: | --- | --- |
| P0 | Cannot safely obtain, start, update, host/join, leave or recover | Repair the production lifecycle and make the next safe action explicit |
| P1 | Intent, commitment, consequence, ownership or counter cannot be read | Repair timing/shape/world feedback first; add text only if the world cue cannot carry it |
| P2 | One action dominates, a resource causes dead time, or a failure teaches nothing | Tune cost/geometry/recovery and preserve a fast meaningful alternative |
| P3 | Existing languages do not combine into enough distinct plans | Add one reusable interaction seam and prove at least two real combinations |
| P4 | A proven loop is clear but emotionally flat or visually fragmented | Add restrained character/material response inside the same timing and hierarchy budget |

Do not hide a P0–P2 defect beneath more content, onboarding prose or decorative
effects. Before accepting a slice, remove duplicate rules and labels it made
unnecessary; the simplest complete feedback path is usually
`input -> commitment -> contact -> consequence -> recovery`.

## 3. Sources of player expression

| Axis | Beginner expression | Mastery expression | Integrity bound |
| --- | --- | --- | --- |
| Movement | Walk, sprint, jump, slide and roll out of danger | Momentum conversion, aerial turnarounds, wallrun/kick routes, wavedash/slide-jump chains and landing choices | No vault requirement; planned wallrun/slide-protection refinements follow the current/target movement contract, not an implied implementation claim |
| Aim/spacing | Point at a target and lead a projectile | Control gaps, crossfire, ricochets, corners, height and future escape lanes | Continuous aim; clear collision and cover |
| Spell weave | Use four visible default spells | Arrange twelve Plain/Ctrl/Alt positions around execution comfort and tactical role | Every attack costs Flux; no illegal duplicate/hidden slot |
| Delivery geometry | Choose bolt, burst, beam, spray or field by obvious shape | Layer timings, trajectories and commitments to constrain future movement | Geometry is readable without element color |
| Elements/chemistry | Observe one element changing a surface | Prime, combine, counter, redirect and exploit transient routes with allies/opponents | No automatic elemental damage advantage; bounded resettable state |
| Champion/body | Learn one clear kit and resource profile | Exploit small acceleration, middle flexibility or large stability while retaining universal movement | Shared honest collision; ancestry/body never strict upgrade |
| World route | Follow the ordinary path | Use advanced/systemic routes, material state and timing to create or deny access | Recovery route and immutable worldbone always remain |
| Social intent | Greet, point and follow | Coordinate setups, retreats, challenges and discoveries without voice | Rate-limited, visibility-safe and quickly dismissible |

Depth comes from composition across axes. Content is not approved merely
because one axis contains many choices.

## 4. Combat rhythm and decision clarity

Combat is fast but not frictionless. The natural rhythm is continuous rather
than turn-based:

```text
read -> position/setup -> commit -> observe contact/world response
     -> counter/convert -> recover or chain -> reassess
```

| System | Fun requirement | Clarity requirement |
| --- | --- | --- |
| Movement | Ordinary movement solves ordinary pressure; committed evasions create expressive saves | Grounded/airborne, direction, intangibility and recovery remain visually distinct |
| Flux | Casting creates frequent interesting resource choices, not long inactivity | Cost, remaining reserve, recovery delay and refusal update together |
| Stamina | Movement chains compete for a replenishing traversal/defense budget | Cost occurs at the authored commitment and never drains invisibly |
| Health | Damage matters without forcing excessive downtime | Hit source, magnitude class, protection and defeat/recovery state agree |
| Startup/recovery | Strong geometry has readable commitment; quick options keep interaction flowing | Hands/body/effect/telegraph and actual active timing align |
| Cooldown | Prevents dominant repetition while allowing creative sequences | The specific spell cell displays remaining wait; no global mystery lockout |
| Projectiles | Patterns create temporary navigable geometry and deliberate gaps | Owner, collision body, direction, speed class, impact and expiry survive grayscale |
| Reactions | Change routes, visibility, friction, cover, hazards and choices | Formation, boundary, active phase, residue, owner and counter are discoverable |

Chains are legal when physical state, resource and authored timing permit them.
One transition policy owns priority, buffer, cancel, cost and refusal. The game
does not add arbitrary lockout merely to slow skilled play, nor allow animation
cancels that erase all commitment.

## 5. Learning without a menu

The Wellspring teaches through geography and immediate action.

| Moment | Experience | Success signal |
| --- | --- | --- |
| First frame | Spawn facing an obvious safe route, landmark and one nearby interaction | Player can move without dismissing anything |
| First 15 seconds | Movement, aim and primary are shown only when relevant | Player moves, aims and casts without opening documentation |
| First minute | A target and responsive surface demonstrate hit, Flux and element identity | Player sees cause → effect → recovery |
| First exploration | Signs/landmarks lead to Movement, Loom, Crucible, Farflow and Archive | Player navigates by place, not persistent labels |
| First failure | Short local explanation names one cause and preserves a quick retry | Retry requires no scene reload or menu search |
| First mastery hint | Optional route grade/codex note reveals a deeper technique or counter | Expert information never blocks the basic route |

Prompts use progressive disclosure:

- one primary contextual action at a time;
- one short verb-led line before optional detail;
- current binding shown for keyboard/mouse or controller;
- demonstration and feedback before abstract terminology;
- repeated prompts fade once the behavior is demonstrated;
- urgent combat state suppresses nonessential teaching;
- the Living Archive preserves complete canonical information on demand.

## 6. Plug-and-play journey

| Stage | Intended player action | Acceptance |
| --- | --- | --- |
| Obtain | Receive one `FLUX.exe` from a trusted source | Hash/version are visible; no archive extraction or developer tool required |
| Install/update | Double-click once | Per-user install, verify, repair/update and rollback require no admin right |
| Start | Launcher opens the installed game | Wellspring appears at 120 Hz; no detached launcher/menu remains running |
| Host LAN | Walk to Farflow and choose Host | Copyable host card and automatic compatible LAN discovery explain readiness |
| Join LAN | Open Join Farflow and select/type/paste | Compatible host is one obvious action; mismatch explains exact version/content difference |
| Join internet | Paste trusted host address | Direct-IP limitation and required routing are honest; no fake NAT/relay promise |
| Leave/close | Use ordinary close or in-world leave | Preferences/network flush, guest receives reason, host confirmation is safe, no helper remains |
| Recover | Restart after interruption or failed update | Last verified version remains available and local state is not corrupted |

Experience targets for the declared Windows reference machine:

- one deliberate action after download starts install/update/play;
- at most three obvious actions from first Wellspring frame to hosting;
- at most three obvious actions from receiving a LAN host card to joined
  Wellspring, excluding firewall/network conditions outside the game;
- no external README is required for movement, casting, reset, host or join;
- every failure names the next safe player action;
- every close path terminates cleanly and preserves only versioned intended
  state.

Signing, public update distribution, NAT traversal/relay and physical two-PC
proof remain explicit release gates rather than implied functionality.

## 7. Information and usability budget

The ordinary frame shows only information that changes the player's immediate
decision.

| Surface | Always visible | Contextual/expanded |
| --- | --- | --- |
| Combat HUD | Champion, Health, Flux, Stamina, active Plain/Ctrl/Alt layer and four spell cells | Numeric detail, build explanation and complete cooldown history |
| World | Actors, threats, collision edges, nearby interaction anchor and major landmark | District map, route grades, system glossary and full objective detail |
| Prompt | Current action binding plus concise verb/object | Consequence, authority, accessibility and advanced use |
| Refusal | One primary cause and affected resource/action | Deeper rule explanation in Archive or station |
| Network | Connection/host state only when relevant | Address, version hashes, diagnostics and stewardship |
| Chemistry | Active pair, boundary/lifecycle and counter cue | Channel values, recipe history and developer diagnostics |

Usability rules:

- keyboard/mouse and controller reach equivalent gameplay and configuration;
- bindings, accessibility, camera and legal loadouts persist in versioned data;
- focus order and back/cancel behavior are deterministic;
- no critical state relies on hover, tiny text, hue or sound alone;
- prompt, notification, speech bubble and hit text have explicit priority and
  never stack into a wall;
- station interaction pauses only the interacting player's local input where
  authority permits; the shared world continues honestly;
- settings changes preview safely and provide reset-to-default.

## 8. Visual simplicity, clarity and charm

The target is not visual minimalism by emptiness. It is a small reusable visual
vocabulary with strong hierarchy and carefully placed life.

| Layer | Clarity rule | Charm rule |
| --- | --- | --- |
| Champions | Strong three-body silhouette, stable scale/pivot, readable facing/action | Restrained idle breathing, cloth/fins/horns response and personality poses |
| Movement | Shadow/contact/wake show groundedness, height and momentum | Brief squash, foot alternation, landing settle and material-specific contact |
| Spells | Shape, owner, speed, collision and phase read before ornament | Element-specific cadence, hand anticipation and quiet residue |
| Reactions | Boundary, phase and counter remain visible under combined pressure | Materials transform with compact authored motifs rather than generic particles |
| Map | Majority of traversable area uses quiet values; cover/threshold/elevation are explicit | Landmark-first masonry, timber, brass, water, growth and small ambient loops |
| HUD | Stable locations, few colors, four active cells and no debug strip | Stepped old-world framing, portrait response and tactile resource ticks |
| Prompts/bubbles | Translucent, short, source-anchored and combat-aware | Parchment/rune language, gentle motion and character-specific voice |

At every supported zoom the read remains:

```text
champion -> hostile geometry -> interaction/reaction
         -> route/cover -> architecture -> ambient detail
```

One view should normally contain one dominant landmark, a few clear interaction
anchors and quiet navigable space. Decorative loops use independent timing so
the world feels inhabited, but their contrast, motion and effect budget remain
below gameplay state. Charm never changes collision, timing or visibility.

## 9. Creativity without combinatorial collapse

Creativity comes from recombination of complete parts:

```text
movement line
+ chosen spell geometry
+ elemental payload
+ current material/world state
+ teammate/opponent timing
= emergent player plan
```

Guardrails:

- start with a small set of legible verbs and let them compose;
- every element receives complete interactions before promotion;
- every new spell delivery changes a spatial decision, not only presentation;
- every champion kit emphasizes a play pattern without removing universal
  movement or the global proven spell sandbox;
- affinities change explicit access/efficiency within budget, never hidden raw
  superiority;
- player-created state is bounded, attributable, counterable and resettable;
- presets save legal configurations, not outcomes or privileged state;
- experiments can be reproduced by players in the Crucible and developers in a
  deterministic scenario.

## 10. Experience decision record

| Tension | Rejected extreme | FLUX decision |
| --- | --- | --- |
| Immediate vs deep | Either tutorial wall or unexplained sandbox | Strong defaults and action-first learning; Archive holds optional depth |
| Fast vs readable | Unrestricted cancels or long lockouts | Physical chaining with visible startup, resource and recovery commitments |
| Many options vs usability | Large undifferentiated spell list | Four visible cells, three explicit layers, presets and role/shape filters |
| Chemistry depth vs memorization | Hidden simulation or cosmetic pairs | Complete bounded recipes with spatial effect, lifecycle and counter cues |
| Character identity vs fairness | Unique controllers and hitboxes | Shared movement/collision foundation plus bounded body/kit/ancestry composition |
| Diegetic world vs convenience | Detached menus or long mandatory walks | Walk-up stations, contextual overlays and discovered fast travel |
| Detail vs clarity | Empty arenas or uniform decoration | Quiet lanes, rich edges, landmark hierarchy and strict effect budgets |
| Charm vs responsiveness | Long flourish or sterile instant state | Immediate state cue plus short downstream personality motion |
| Social expression vs noise | Free text spam or no communication | Bounded radial intents and visibility-safe bubbles |
| Failure honesty vs friendliness | Silent refusal or technical error dump | One plain-language cause, safe next action and optional detail |

## 11. Acceptance journeys

| Journey | Must prove |
| --- | --- |
| New solo player | Install/start, move, aim, cast, read resources, hit target, reset and find major stations without external documentation |
| Movement expression | All eight directions and current techniques feel distinct, chain when legal, refuse clearly and remain readable at each zoom |
| Combat pressure | Two champions can read ownership, gaps, costs, hits and recovery under maximum legal first-phase patterns |
| Chemistry discovery | Player deliberately creates, identifies, counters and resets every first-eight pair in the Crucible |
| Character/body choice | Small, middle and large create different viable decisions without hidden collision/reach advantage |
| Friend session | One packaged host and guest discover/connect, configure, interact, duel/rematch, disconnect and close safely |
| Accessibility | Keyboard/controller, high contrast, grayscale review, reduced effects and readable prompts preserve equivalent gameplay truth |
| Recovery | Interrupted update, invalid content, mismatch, host loss and ordinary quit retain a safe understandable next state |

Every journey records observed confusion and correction, not only pass/fail.
Assertions prove rules; human evidence proves usability, charm and fun.

## 12. Implementation placement

| Earliest gate | Experience work |
| --- | --- |
| C5 close | Preserve the current playable experience; publish the reaction-catalog checkpoint without unrelated redesign |
| C5.5 | Generate current player-facing truth; remove stale protocol/counts/names; add the thin Windows task/release evidence boundary |
| C6 | Make first element contact immediately readable and resettable through production commands |
| C7 | Give every shared reaction primitive a distinct spatial decision and counter |
| C8 | Add compact lifecycle, ownership, counter and refusal presentation without expanding HUD clutter |
| C9 | Complete Crucible discovery, friend package, safe lifecycle and named player journeys; pause for feedback |
| F0–F1 | Convert confusion/missed-input evidence into scenarios; harden movement, camera, chaining and immediate feedback |
| F2–F4 | Harden combat rhythm, projectile clarity, chemistry depth and fair champion/body expression |
| F5 | Complete onboarding, Archive, presets, contextual help and safe player experimentation |
| F6–F7 | Complete developer reproduction, performance, packaged parity and final base-game acceptance |

Routine roster, spell-type, element, ancestry and map expansion begins only
after F7. Each addition then reuses these experience filters and acceptance
journeys rather than adding a separate tutorial or interface convention.

# FLUX foundation systems and expansion contract

Status: **canonical post-C9 foundation contract**.

This document defines how FLUX becomes both a deep player sandbox and a safe,
fast developer sandbox without sacrificing deterministic 120 Hz play,
competitive integrity or a coherent visual identity. It extends the current
first-eight chemistry path; it does not interrupt C5–C9 or authorize a rewrite.
Player-facing success is defined by
[`PLAYER-EXPERIENCE-OVERHAUL.md`](PLAYER-EXPERIENCE-OVERHAUL.md); these kernels
exist to make its learning, expression, clarity, charm and recovery journeys
repeatable rather than to maximize framework surface area.

## 1. Foundation objective

FLUX grows through a small set of complete, reusable kernels:

```text
validated authored content
  -> immutable compiled definitions + compatibility hashes
  -> semantic commands
  -> fixed-tick simulation
  -> authoritative state + semantic events
  -> replay/network snapshots
  -> interpolated presentation + feedback
```

Player tools, developer tools, tests and captures use these same commands,
definitions and state transitions. No editor, station, debug overlay, animation,
particle, client or test shortcut may directly invent an outcome.

## 2. System ownership and extension seams

| Foundation | Owns | Expansion seam | Must never become |
| --- | --- | --- | --- |
| Input/command | Device sampling, semantic press edges, remaps, bounded buffering | Add a semantic action and one device-independent command bit/value | Device-specific gameplay logic |
| Movement | Momentum, collision, grounding, airborne state, action transitions, Stamina and intangibility | Validated tuning/profile plus an explicit transition entry | Animation-driven movement or per-character forks |
| Spell delivery | Bolt, burst, beam, spray, wave, orb, field and future geometry kernels | Delivery definition + bounded modifiers + elemental payload | One bespoke script per spell |
| Combat | Cast legality, cost, cooldown, hit, control, defeat and recovery | Immutable compiled spell definition with stable IDs | Renderer/client-owned damage or hidden free attacks |
| Elements | Identity, affinity discount, channel contribution and presentation vocabulary | Versioned element definition with complete interaction coverage | Automatic matchup damage bonus |
| Chemistry | Exposure/contact, symmetric recipes, shared spatial primitives, lifecycle and reset | Recipe parameters compiled onto existing primitives; new primitive only for genuinely new spatial behavior | Thirty-six or more custom physics implementations |
| Materials/world | Worldbone, authored structure, transient matter, receiving surfaces and reset groups | Typed material profile and explicit response table | Pixel-derived collision or unbounded mutation |
| Champion | Ancestry + body role + stats + affinities + kit + presentation recipe | One data composition using reusable components | Deep inheritance tree or copied champion controller |
| Ancestry | Silhouette/body-plan hooks and bounded trait package | Reusable trait components inside the same budget | Hidden reach, free evasion or universal stat upgrade |
| Actor/AI | Host-owned perception, intent selection and semantic-command production | Behavior policy + actor/champion components + bounded think schedule | AI-only movement, damage or collision rules |
| Objective/mode | Participation, teams, spawn policy, objective lifecycle, score, round/reset and late join | Versioned ruleset composed from objective and session policies | A forked combat simulation or scene-script outcome |
| Progression/save | Preferences, discoveries, legal presets, cosmetics and versioned unlock state | Explicit save schema and idempotent migration | Hidden competitive stat advantage or unvalidated authority |
| Presentation | Visual hierarchy, interpolation, animation, effects, sound hooks and accessibility | Validated recipe/token/skeleton with provenance and budgets | Gameplay authority or local palette/timing invention |
| Networking/replay | Input sequences, validation, snapshots, reconciliation, compatibility and event retention | Versioned serializer plus migration/refusal path | Client trust or silent schema coercion |
| Application | Boot, lifecycle, composition, Wellspring station coordination and safe quit | Focused coordinator with explicit dependencies | A second simulation inside `bootstrap.gd` |

## 3. Smoothness and control acceptance

Smooth gameplay is an observable system property, not a subjective final pass.

| Signal | Initial acceptance target |
| --- | --- |
| Simulation | One authoritative 120 Hz cadence; no alternate gameplay rate |
| Legal input response | State changes on the sampled tick unless an authored commitment blocks it |
| Presentation response | Confirmed/local-predicted state becomes visible by the next rendered frame without an additional hidden queue |
| Digital direction | Eight normalized directions with equal authored speed, acceleration and cost |
| Analog direction | Continuous magnitude and angle through command, prediction, replay and host validation |
| Chaining | One transition table owns buffer, cancel, cost, cooldown, priority and refusal reason |
| Momentum | Acceleration, braking, reversal, landing and air steering use stable curves and never depend on frame rate |
| Refusal | Exactly one primary reason is visible; rejected input consumes no undeclared resource |
| Animation | Reads the authoritative action and direction; never moves collision or changes body scale |
| Camera | Stable dead zone/lead, whole-pixel output placement and restrained impulses; no aim/camera feedback loop |
| Spell response | An accepted cast reserves its cost/cooldown exactly once and begins its readable startup on the same state transition |
| Projectile motion | Fixed-tick positions interpolate smoothly without changing endpoints, collision radius, lifetime or ownership |
| Hit response | Authoritative contact emits one deduplicated event; flash, contour, sound hook and resource change agree on victim/source |
| Chemistry response | Contact, formation, active effect and decay use explicit phases; presentation never lags into a misleading lifecycle |
| Network feel | Local movement predicts and reconciles visibly but gently; combat/chemistry wait for authority and expose latency/refusal honestly |
| Reset/iteration | Practice and experiment reset completes deterministically without scene reload, stale entities or retained cooldown surprises |

Every movement/action change supplies repeatable journeys for start, stop,
reverse, diagonal travel, collision, landing, chain success/failure, resource
exhaustion, prediction/reconciliation and replay. Human review records route
time, corrections, missed inputs and confusion points without retaining raw
personal input history.

## 4. Composition models

### 4.1 Champion and ancestry (race)

```text
champion = stable identity
         + ancestry trait package
         + small/middle/large body profile
         + bounded stat allocation
         + 2–3 affinities
         + foundation kit
         + presentation recipe
```

Ancestry traits are reusable components with explicit hooks and budgets. A
champion-specific mechanic first attempts composition from existing movement,
combat, spell and chemistry components. New simulation code is accepted only
when it creates a distinct player decision that cannot be represented safely by
existing components.

### 4.2 Spell

```text
spell = delivery kernel
      + elemental payload
      + bounded geometry/pattern modifiers
      + cost/startup/active/recovery/cooldown
      + hit/control/material policy
      + presentation and sound recipe
```

Every attack has positive Flux cost. A new delivery kernel must support player,
target, world, replay, Farflow, accessibility, capacity and refusal cases before
the first spell is selectable.

### 4.3 Element and reaction

```text
element = stable ID + channel contribution + shape/value/motion language
reaction = canonical unordered pair + thresholds + bounded primitives + counter
```

Adding element number `n` requires `n` new unordered recipes, not placeholders.
The catalog, compatibility hash, Crucible coverage, reset behavior, network
state and accessibility read must be complete before the element becomes
playable.

### 4.4 Actors, objectives and modes

```text
enemy/bot = actor profile + command policy + movement contract + kit + presentation
objective = stable identity + participation + lifecycle + world hooks + score/reset
mode = charter + teams + spawns + objectives + scoring + round/late-join policy
```

AI observes only host-authorized state and emits the same bounded semantic
commands a player can submit; it never writes position, damage, cooldown or
chemistry directly. Modes compose existing movement, combat, chemistry and
session systems. If a mode needs a new rule, that rule enters one reusable
policy with an explicit compatibility hash rather than a scene-specific branch.

Progression may unlock discovery, presets, cosmetics or later-mode access, but
competitive outcomes never depend on a hidden permanent stat advantage.

## 5. Player sandbox

The Wellspring is the interface and the first systemic playground.

| Area | Player capability | Safety boundary |
| --- | --- | --- |
| Movement Conservatory | Try every universal technique, routes and timing grades | Immediate local reset; no combat grief |
| Spell Loom | Configure all twelve Plain/Ctrl/Alt positions from proven spells | Host validates proximity and legal catalog |
| Elemental Crucible | Combine sources, inspect recipe/counter/lifecycle and reset basin | Bounded cells, immutable worldbone, isolated reset group |
| Proving Court | Aim, pressure, duel, body-role and resource tests | Explicit charter, spawn protection and deterministic reset |
| Farflow | Host/join, readiness, observation, rematch and stewardship | Host authority, rate limits, reason-bearing disconnect |
| Living Archive | Discover controls, systems, reactions and recorded trials | Read-only authority; no hidden gameplay modifiers |

Experiments should be quick to start, quick to reset and useful without a
formal match. Safe/social areas reject hostile outcomes; contested areas expose
their rules before entry. Presets may store legal loadouts and preferences, but
never bypass validation or compatibility.

## 6. Developer sandbox

Developer tooling must shorten iteration while proving the same game players
receive.

| Tool | Contract |
| --- | --- |
| Scenario definition | Versioned data declares map, actors, loadouts, input sequence, seed, duration and assertions; it sends ordinary semantic commands. |
| Content validator/compiler | Produces immutable tables and hashes with named errors; no partially valid content enters runtime. |
| Focused journey runner | Runs one movement, spell, reaction, network or lifecycle case before the full gate. |
| Live diagnostic overlay | Reads state, collision, pivots, capacities and timings; hidden by default and unable to mutate authority. |
| Capture matrix | Reuses production rendering at supported resolutions, zooms and accessibility modes with non-overwriting evidence. |
| Tuning workflow | Presentation-only content may reload offline after validation; simulation-affecting content requires safe restart and a new compatibility hash. |
| Fault injection | Test-only commands exercise overflow, packet rejection, missing content, disconnect and incompatible hash behavior. |
| Package proof | Runs the same scenario subset against source, imported resources and the packaged Windows executable. |

New tooling belongs beside the system it verifies and exposes one documented
command. It may improve observability or setup, but cannot create a second rule
path that production never executes.

## 7. Maintainability rules

| Rule | Enforcement |
| --- | --- |
| One authority per value | Authored content compiles once; UI, simulation and compatibility consume the compiled result. |
| Stable identity | Machine ID/wire ID is separate from display name; schema changes use explicit migrations. |
| Explicit dependencies | Coordinators receive validated collaborators; no global lookup or hidden mutable singleton owns outcomes. |
| Small interfaces | Commands and immutable definitions enter systems; state/events leave them. |
| No speculative abstraction | Extract after a second real use or when the active slice needs a clean authority boundary. |
| No bespoke exceptions | Prefer reusable component/primitive/policy; document the rare exception and test its full lifecycle. |
| Current truth is generated | Protocol, schemas, hashes, counts, platform, tick rate and package identity come from machine-readable state. |
| Historical evidence is labelled | Archive plans/captures without letting them compete with current instructions. |
| Warnings are failures to classify | Expected diagnostics are explicit; normal validation remains quiet. |
| Safe interruption | Each slice has a green rollback point and leaves launch, reset and quit paths intact. |

## 8. 120 Hz performance envelope

The first measured target is an eight-player maximum-legal-pressure journey on
the declared Windows reference machine. The 8.33 ms frame is initially divided
as a review budget, then adjusted only from measurements:

| Budget | Initial p99 ceiling |
| --- | ---: |
| Authoritative simulation | 2.00 ms |
| Networking, validation and serialization | 0.75 ms |
| Presentation preparation and UI | 1.25 ms |
| Rendering/GPU submission and completion | 3.00 ms |
| Operating-system and variance headroom | 1.33 ms |

Fixed capacities bound players, commands, projectiles, beams, sprays, fields,
exposure cells, reactions, residues, events, snapshot bytes, packet bytes and
presentation effects. Inner loops avoid per-entity scene searches and repeated
content parsing. Allocation, pooling, culling and cache work is driven by p95,
p99 and worst-case evidence—not by speculative complexity.

Reduced-effects mode changes presentation cost only. It may not change active
timing, collision, visibility, ownership, damage, counters or escape lanes.

## 9. Expansion admission gates

| Addition | Required before selection/shipping |
| --- | --- |
| Movement technique | Purpose, transition entries, costs, collision cases, feedback, eight-direction journeys, replay/Farflow and player evidence |
| Spell delivery | Kernel contract, all lifecycle phases, capacity, world/target interaction, network/replay, UI/refusal and accessibility presentation |
| Spell | Compiled definition, positive cost, counterplay, delivery/payload compatibility, Loom entry, tests and live capture |
| Element | Stable identity, channel model, all new symmetric recipes, visual language, Crucible coverage, hash/migration and reset proof |
| Reaction primitive | Distinct spatial decision unavailable through existing primitives, hard bounds, counter, lifecycle, replay/network and stress proof |
| Champion | Reusable ancestry/body/stat/affinity/kit composition, every universal action, three-role balance journey and complete presentation evidence |
| Ancestry | Reusable body/trait package, honest bound, shared collision policy, at least one complete champion and no hidden advantage |
| Material/surface | Registry entry, receiving-surface read, explicit element responses, worldbone/reset policy and route/accessibility proof |
| Map/district | Ordinary/advanced/systemic/recovery routes, cover/visibility, reset groups, spawn safety, landmarks, stress and Farflow proof |
| Enemy/bot | Actor profile, ordinary semantic commands, bounded perception/think work, navigation/failure behavior, kit counterplay, replay/network and encounter proof |
| Objective/mode | Versioned ruleset, participation/teams/spawns, lifecycle, score/tie/reset, late join/disconnect, UI, replay/network and package journey |
| Progression/save | Explicit non-pay-to-win purpose, schema/migration/rollback, offline failure behavior, privacy boundary and no effect on authoritative competitive balance unless the mode hashes it openly |

## 10. Post-C9 foundation sequence

| Gate | Outcome |
| ---: | --- |
| F0 | Convert C9 playtest observations into reproducible scenarios and ranked failures. |
| F1 | Harden input, movement, action transitions, camera and feedback until the existing grammar meets the smoothness contract. |
| F2 | Harden spell delivery, combat economy, target/world contact and projectile readability under combined pressure. |
| F3 | Tune chemistry channels/primitives/counters and prove reset, replay, network and route safety. |
| F4 | Validate champion/ancestry/body composition and fair small/middle/large playstyles without adding roster scope. |
| F5 | Complete player sandbox discoverability, presets, safe experiments and fast reset loops inside the Wellspring. |
| F6 | Complete developer scenarios, diagnostics, content compilation, fault injection and packaged proof. |
| F7 | Run eight-player 120 Hz stress, source/package parity and every applicable player-experience journey; publish the foundation checkpoint only when rule correctness and human usability evidence agree. |

Only F7 opens routine expansion. Later content is introduced one complete
addition at a time through the admission table above.

## 11. Dependency and module boundaries

The scalable architecture is a directed graph, not a collection of mutually
aware managers:

```text
authored files -> validators/compilers -> immutable definitions

device/platform -> input mapping -> semantic commands
application coordinator -> simulation domains -> canonical state + events
network/replay <-> commands, state and events
presentation <- definitions, interpolated state and semantic events
tools/tests -> the same validators, commands, scenarios and packaged runtime
```

| Boundary | Allowed dependency | Forbidden dependency |
| --- | --- | --- |
| `src/sim/` | Core integer types, immutable compiled definitions and explicit policies | Scene tree, presentation, device input, launcher or remote client state |
| `src/content/` | Parsing, schema validation, compilation, stable identity and hashes | Gameplay outcome mutation or renderer-local fallback rules |
| `src/net/` | Semantic commands, bounded codecs, snapshots, validation and transport lifecycle | Champion/element special cases or client-trusted outcomes |
| `src/presentation/` | Read-only definitions, state, events, interpolation and accessibility tokens | Canonical timers, hit tests, costs, visibility authority or content invention |
| `src/app/` | Composition, lifecycle and coordinators with explicit collaborators | Duplicated simulation rules or an ever-growing all-purpose bootstrap |
| `scripts/` and tools | Public validation/scenario/package entry points | Secret alternate setup or direct authoritative-state mutation |

Cycles are defects. A lower layer never reaches upward to discover a service;
the application supplies dependencies. A new feature first identifies its
existing owner and public seam; it does not create a parallel manager because
the current interface is inconvenient.

## 12. Versioned content-unit lifecycle

“Content pack” describes a validated dependency unit, not permission for
executable third-party code. Each future champion, spell family, element set,
map, encounter or mode unit declares:

| Manifest field | Contract |
| --- | --- |
| Stable identity | Namespaced machine ID plus never-reused wire IDs where networking requires them |
| Schema/content version | Monotonic schema with explicit source version; display name changes do not replace identity |
| Dependencies | Exact required kernels, elements, materials, traits, maps or rulesets; cycles fail validation |
| Compatibility class | Local preference, presentation, authoritative ruleset, save migration or package-only |
| Budgets | Entities, events, cells, work/tick, bytes, effects and memory relevant to the unit |
| Assets/provenance | Reachable runtime outputs, source/reference classification, license and deterministic hashes |
| Player explanation | Localizable display key, one-line purpose, visible cost/commitment, consequence and counter; UI derives values from compiled definitions |
| Acceptance matrix | Generated required tests, scenarios, captures, accessibility, Farflow, stress and package proof |
| Migration/tombstones | Old IDs/schema paths and idempotent upgrade/refusal behavior; retired wire IDs remain reserved |

Promotion is monotonic:

```text
draft -> validated -> experimental -> proven -> selectable -> deprecated -> retired
```

`draft` never loads. `validated` may enter schema tests. `experimental` is
available only in named developer scenarios. `proven` has passed its admission
matrix but remains non-default. `selectable` is ordinary player content.
`deprecated` continues to read/migrate but cannot seed new content. `retired`
is absent from production only after saves, replays, network and assets have a
tested migration or explicit refusal. No feature uses “present in JSON” as a
shortcut from draft to playable.

All cross-content references resolve during validation/compilation, before a
session begins. The compiler topologically orders dependencies, rejects missing
or cyclic IDs, reserves tombstones, checks capability compatibility, and emits
compact immutable handles for fixed-tick use. Simulation code does not perform
string lookup, JSON parsing, path discovery or fallback content invention inside
a tick. Generated registries may remove repetitive wiring, but their inputs,
ordering and hashes remain reviewable and deterministic.

Availability is independent from existence: an authored record may be retained
for migration, a developer scenario or future promotion without entering the
selectable registry. Generated state therefore reports at least authored,
validated, runtime-selectable, deprecated and retired counts separately; one
aggregate “content count” is not sufficient evidence.

## 13. Change and compatibility classes

Every changed field is classified before implementation. This table plans the
C5.5 classifier; it does not relax current compatibility checks by itself.

| Class | Examples | Required response |
| --- | --- | --- |
| Local preference | Bindings, local camera/accessibility choice | Versioned local migration; never authoritative session state |
| Presentation contract | Sprite/effect/audio recipe, semantic cue mapping | Asset/provenance and readability proof; no simulation hash change unless the existing session contract explicitly requires it |
| Authoritative content | Cost, timing, geometry, stats, material/reaction/ruleset | New compiled compatibility hash; mismatch refuses before participation |
| Wire/schema | Protocol packet, snapshot, replay, save or stable-ID representation | Version bump plus backward migration or clear incompatible refusal; IDs are tombstoned, never reused |
| Package/lifecycle | Installer, executable, manifest or update channel | Signed/hash-verified build, rollback, repair, safe quit and receipt proof |
| Test/tool only | Scenario, fixture, diagnostic or source generator | Must not ship authority, alter hashes or create a production-only bypass |

## 14. Low-friction expansion workflow

Large-scale production grows by repeating one small complete promotion lane:

| Stage | Output | Exit |
| ---: | --- | --- |
| E0 intent | One player decision, combinations, counter, cost and target acceptance journey | Passes the experience filter before assets/code multiply |
| E1 definition | Manifest, stable IDs, dependencies, budgets and migration class | Invalid/incomplete content fails with one named cause |
| E2 isolated proof | Pure compiler/kernel fixtures and one deterministic scenario | No renderer, scene or network is needed to prove core rules |
| E3 production integration | Ordinary commands, world contact, reset, replay and Farflow | Source and host outcomes match; no feature-specific authority path |
| E4 communication | Body/effect/world/HUD/audio recipes and accessibility captures | Intent, owner, consequence and counter survive pressure and reduced cues |
| E5 stress/package | Capacity, 120 Hz p99, packet/asset limits and packaged Windows journey | Exact artifact remains bounded, recoverable and safe to close |
| E6 promotion | Registry status becomes selectable and current docs/state regenerate | One reversible green checkpoint; no stale parallel truth |

Expansion cost should fall after each representative slice:

| Addition | Expected implementation shape after F7 |
| --- | --- |
| Spell on existing delivery/element | Definition + presentation recipe + generated acceptance rows; no combat-system branch |
| Champion on existing ancestry/body/traits | Composition + body/action presentation + balance journeys; no private controller |
| Map using existing materials/objectives | World/route/reset manifests + art/visibility/navigation proof; no scene-owned combat rules |
| Enemy using existing actor/kit | Actor profile + bounded command policy + encounter recipe; no AI-only physics/damage |
| Mode using existing objective/session policies | Ruleset composition + lifecycle/UI/journeys; no copied simulation |
| New delivery, reaction primitive or trait hook | One new bounded reusable kernel first, followed by a separate content promotion |
| New element number `n` | Element language plus exactly `n` new unordered recipes, Crucible coverage and compatibility migration |

One slice introduces at most one new authoritative primitive. Once two or more
complete examples prove the same seam, matrix generation and batch authoring may
scale content around it; batch size never weakens per-entry validation or the
single packaged acceptance artifact.

## 15. Expansion-readiness gate

F7 is not “architecture complete” because documents exist. Before routine
large-scale content begins, representative non-selectable fixtures must prove:

- a fourth champion composition needs no edit keyed by champion identity in
  movement, combat, networking or bootstrap;
- a spell on an existing delivery needs no new simulation branch;
- a new map district composes routes/materials/objectives without owning combat;
- a bot uses semantic commands and remains replay/Farflow deterministic;
- a ruleset composes session/objective policies and handles tie, reset, late
  join, disconnect and host shutdown;
- generated acceptance rows identify every required proof from each manifest;
- focused warm feedback meets its budget and Full/package receipts remain one
  obvious command away;
- source, generated state, README, package identity and in-game Archive agree.

If a fixture fails, improve the smallest real seam and rerun it; do not retain
the fixture as selectable content or respond with a general rewrite.

## 16. Eight-to-thirty-two-player boundary

Eight remains the public cap until the complete eight-player foundation is
measured and per-peer visibility is authoritative. Thirty-two-player support is
a later capacity program, not a constant change or a promise inferred from
array sizes.

| Scale gate | Required outcome |
| ---: | --- |
| S0 workload | Reproducible 8/16/24/32 actor command, movement, projectile, field, reaction, objective and join/leave scenarios with subsystem p50/p95/p99, bytes and allocation counts |
| S1 spatial authority | Bounded spatial queries replace global actor-pair scans where measurement requires; host-owned relevance/LOS prevents hidden-state leakage before optimizing omission |
| S2 replication | Per-peer prioritized state/event envelopes, delta/baseline recovery, packet-loss/reorder handling and explicit overflow remain within measured bandwidth/MTU budgets |
| S3 lifecycle/soak | Join-in-progress, reconnect, observer, stewardship, host shutdown, abuse limits and long 32-actor soak recover without leaks, unbounded queues or state divergence |
| S4 playability | Map capacity, spawn/objective distribution, names/teams, HUD, bubbles and effect density remain understandable to humans at supported zoom/accessibility settings |
| S5 physical acceptance | Declared host/client Windows machines sustain the target 120 Hz simulation and presentation experience under real network conditions before the cap is advertised |

The host remains authoritative at every scale. AI/load generators may fill
capacity for deterministic stress, but bots cannot prove social usability,
visual clarity or internet reachability. A smaller mode may impose a lower cap
without changing transport limits or pretending unused capacity is tested.

## 17. Plug-and-play as content scales

The Windows lifecycle remains one coherent product even after content units
multiply:

```text
trusted manifest -> verify signature/hash -> stage complete version
-> verify runtime/content dependencies -> atomic activate
-> start -> safe session/quit -> retain one verified rollback
```

| Concern | Contract |
| --- | --- |
| Install | Per-user, no developer tools or administrator rights; one obvious executable owns setup/repair/update/start |
| Update | Never mutate the active version in place; incomplete or incompatible content cannot become current |
| Join mismatch | Name exact protocol/ruleset/content difference and the safe update action; never download arbitrary host-supplied code |
| Offline | Last verified compatible local version starts without network unless the selected activity inherently needs it |
| Save/profile | Migrate idempotently only after the new version validates; preserve recoverable previous data until successful start |
| Session safety | No update swaps while hosting/joined; leave/host shutdown communicates a bounded reason and flushes intended state |
| Close/crash | Every exit path terminates launcher/helper/network children; next start can repair from manifest without email or notification spam |
| Diagnostics | One player-readable summary and one exportable technical receipt expose version, hashes, logs and next action without secrets |

Content packaging may become internally modular for build/download efficiency,
but the player still receives one trusted lifecycle and one compatible product
identity. Executable gameplay mods, unsigned host payloads and silent rule
substitution remain outside this foundation.

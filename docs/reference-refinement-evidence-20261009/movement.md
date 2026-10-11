# Movement reference audit and recovery-momentum repair

Status: SOURCE_CANDIDATE; source frozen for root verification. Godot import, focused/full suites, negative control, and human feel are NOT_RUN by this worker. 2026-10-09.

Scope: audit the inherited movement-impact candidate, then repair one demonstrable recovery defect. The heavily dirty checkout and inherited tuning are preserved. This note does not qualify every movement option or a release.

## Evidence and limits

| Primary evidence | Documented mechanism and context | Positive evidence actually available | H.E.X. transfer and limit |
|---|---|---|---|
| [Respawn developers, Titanfall controls interview, 2017](https://www.gamedeveloper.com/design/designer-interview-getting-i-titanfall-i-s-controls-just-right) | John Haggerty describes slide as familiar ground movement with reduced stopping/turning freedom and a starting boost. Developers describe repeated wallrun trials, terrain checks, route incentives, and teaching trust in wall contact through levels. | Haggerty reports the initial slide experiment was liked internally. The interview author praises fluidity; neither statement is a controlled player-outcome measurement. | Preserve controllable momentum and readable commitment across chains; resolve contradictions in the actual velocity first. Do not import boosts, Source air-strafe acceleration, infinite speed chaining, or first-person camera motion into the top-down arena. |
| [Steve Fukuda, direct Titanfall 2 multiplayer interview, 2016](https://www.shacknews.com/article/96446/titanfall-2-game-director-on-a-slower-paced-multiplayer) | The director links excessive speed and many possible approaches to players struggling to infer why they died. He describes more legible routes and proactive choices as design goals. | Direct developer diagnosis and intended remedy; this pre-release account does not prove the final outcome of those changes. | A movement improvement must preserve opponent-readable travel, exposed recovery, and useful ordinary walking. More options or higher speeds alone do not satisfy the game goal. |
| [Drew McCoy, direct Apex Legends interview, 2019](https://www.pcgamer.com/titanfall-dev-explains-why-apex-legends-doesnt-have-titans-or-wall-running-or-double-jumping/) | Respawn prototyped, then removed ordinary wallrunning and double jumping in the battle-royale context because the resulting possible positions undermined strategic inference. | Reported internal iteration and developer judgment; no quantified causal estimate. | This is counterevidence to importing every Titanfall technique. H.E.X. already contracts finite wall routes and airborne budgets; retain their costs, clocks, geometry checks, and exposure rather than add unrestricted mobility. |
| [EA / Respawn, Apex Arsenal Firing Range, 2023](https://www.ea.com/ea-play/news/arsenal-season-game-updates) | Separate agility, duel, and simulated-combat spaces; configurable targets/dummies and resettable performance stats make focused practice possible. | Official shipped design and stated learning intent; the page does not report learning gains. | Teach the existing actions with actual controls and a repeatable isolated route. The world/menu worker is repairing stale movement signs separately. This movement patch does not enlarge the map or invent a challenge system. |
| [Nintendo, Super Smash Bros. Melee overview](https://www.nintendo.com/en-gb/Games/Nintendo-GameCube/Super-Smash-Bros-Melee-268951.html) | Official material identifies midair dodging as an evasion against attacks and projectiles. | Confirms the action exists; it does not substantiate particular wavedash timing, friction, input buffers, or improved retention. | Preserve intentional directional evasion and finite protection. No new frame data, wavedash rule, or numerical tuning is justified from this source. |

The sources support principles and contrasting contexts, not a claim that an established title used this exact H.E.X. repair or that popularity proves a technique is beneficial. The repair's direct warrant is the local reproducible contradiction below. Transfer success remains falsifiable in H.E.X.

## Local defect and decision

`MovementSystem._apply_velocity` reconstructs each active dodge tick from `movement_action_speed`, then allows ordinary accumulated air steering after the paid commitment. It retained the steered heading but not the speed that steering removed. Counter-steering or carving therefore visibly slowed the actor, but releasing the stick could restore part of that lost impulse on the next tick. The inherited slide repair already avoids the equivalent stale-speed problem.

Decision: after real recovery steering, lower the remaining dodge budget to at most the actual unslowed vector magnitude. Never raise that budget. Neutral input keeps its exact existing decay; the paid commitment continues to ignore early steering. Reading unslowed velocity prevents a hostile slow from becoming a second permanent momentum penalty.

This is a five-line source addition with no tuning change, new action, timer, resource, replicated field, or UI flow. It implements consistent consequences: braking actually spends carried movement and releasing stops the steering input. Ordinary air steering can still accelerate while held under its existing rules; it cannot convert that temporary output into a larger paid-dodge carry budget.

Considered alternatives were rejected:

- Increase dodge speed or shorten commitment: no isolated defect or reference evidence justifies either, and both alter the opponent's response window.
- Remove recovery steering: it would erase an existing control option instead of fixing its inconsistent result.
- Always rewrite the budget from actual speed, including neutral ticks: would add repeated direction-quantization loss and change the established neutral curve.
- Copy Titanfall air acceleration: wrong camera/combat context, conflicts with finite authored speed, and is unnecessary for the defect.
- Add further Melee techniques from community descriptions: primary evidence collected here does not establish exact mechanics or positive transfer; no such mechanics were added.

## Acceptance and regression controls

`tests/unit/test_movement_overhaul.gd` now exercises actual paid Jump-to-Evade routes for S. Wayne, Spai Si, and Fluup, eight headings, opposed and perpendicular input, and ordinary versus 550/1000 hostile slow. Each case must show real recovery speed loss, then continued decay after neutral release; costs, cooldown, duration, protection, and remaining air options must stay consistent.

Controls preserve exact neutral recovery velocity/budget, reject early steering during commitment, cover a continuous analog heading, and compare paid immediate redirect against slower ordinary counter-steering. The old redirect assertion that both actors retained identical cached speed was replaced: it explicitly concealed the now-fixed loss. Existing comparisons still require identical dodge/protection clocks, exact paid cost, real reverse direction, and unchanged airborne allowances.

Prediction tests restore a real paid pre-recovery state, apply brake/release commands, and replay after a delayed acknowledgement; every replicated value must match authority. Existing full snapshot, moving-cast, collision, wavedash, and authored-route tests remain required integration guards.

Falsification:

1. The new release regression must fail against the preserved pre-fix source and pass against the candidate.
2. Any change in neutral recovery, commitment, cost, immunity, cooldown, snapshot/prediction continuation, or unrelated route is a regression to investigate.
3. A human practice comparison must confirm that braking/release has a legible result without making the paid sharp turn or ordinary dodge feel ineffective. No human outcome is claimed here.

Exact pre-edit copies: `.godot/reference-refinement-baseline/movement/src/sim/movement/movement_system.gd` and corresponding `tests/unit/test_movement_overhaul.gd`. Pre-edit SHA-256 values: `085aa150b7b69cde0adff0d60a35ce3868057b7edd4a9e49843ad9f11c392045` and `eb4db2f7a3fc5849a171c9a2a76fa5ebd458fba8664134e90d6b2acbd2005933` respectively. Static `git diff --check` passed. Root owns all engine validation and identity updates.

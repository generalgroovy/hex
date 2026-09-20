# S5 physical attack candidate

Status: **isolated source candidate; NOT RUN; not integrated; no visual or feel acceptance**.

This directory owns only the bounded Punch/Kick state machine, validated trial
tuning, and focused tests. It does not change live `PlayerState`, `SimCommand`,
`SimWorld`, snapshots, input routing, profiles, UI, presentation, or content.
Root remains the only integration and engine-test authority.

## Candidate contract

`PhysicalAttackSystem.begin_tick(state, command, config, tick, events)` advances
one actor once after ordinary movement. Its result contains
`consumed_pressed_actions`, `started`, `buffered`, `kind`, `sequence_id`, and a
refusal `reason`. The caller owns command sanitization. Punch wins a simultaneous
Punch+Kick press, and both physical bits are consumed so one input cannot buy two
actions. Stamina is charged through the existing movement resource helper only
when startup is accepted.

`PhysicalAttackSystem.resolve_all(world)` snapshots all post-movement positions,
plans contacts, and resolves attacker ID then target ID. It honors health, team,
spawn protection, combat intangibility, 24px height difference, solid cover,
latched aim, target hurt radius, and per-sequence hit IDs. It emits the captured
target position and contact point before collision-resolved knockback. It applies
no stun or control state. The `first_contact` field is the future S6 one-payload
hook; S5 does not create or pay any infusion.

`PhysicalAttackSystem.cancel(state, reason, tick, events, preserve_debt)` clears
the active hit set and buffer. Alive movement/modal interruptions preserve the
unpaid recovery time; death/reset clears it. Roll, Air Dodge, Slide, and Wall Kick
are read after `MovementSystem`, so they cancel before an attack can resolve.

Trial tuning is fixed at the requested 120Hz values:

| Attack | Stamina | Damage | Startup | Active | Recovery | Reach | Half-arc cos² | Push |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Punch | 14,000 | 6,000 | 6 | 4 | 16 | 48,000 | 750,000 | 7,000 |
| Kick | 35,000 | 12,000 | 12 | 6 | 28 | 64,000 | 500,000 | 30,000 |

Reach is identical for all attacker body sizes. The target's authoritative hurt
radius is the only body-size contribution to radial eligibility. Every confirmed
push uses `MovementTuning.PLAYER_RADIUS` (18px) for wall clearance across all
three hurt sizes. The first push arms a 48-tick victim
guard; subsequent contacts during the guard retain full damage and use one
quarter push.

## Exact promotion map

Root can promote after shared-schema review:

| Candidate | Live destination |
| --- | --- |
| `content/combat/physical_attacks_v1.json` | `content/combat/physical_attacks_v1.json` |
| `src/sim/combat/physical_attack_tuning.gd` | `src/sim/combat/physical_attack_tuning.gd` |
| `src/sim/combat/physical_attack_system.gd` | `src/sim/combat/physical_attack_system.gd` |
| `tests/unit/test_physical_attack_system.gd` | `tests/unit/test_physical_attack_system.gd` |

During promotion, change both candidate `preload` paths and
`PhysicalAttackTuning.DEFAULT_PATH` from
`res://.agent/candidates/gameplay_s5/...` to their live `res://...` paths. Replace
the candidate bit constants with `SimCommand.PRESSED_PUNCH` and
`SimCommand.PRESSED_KICK` after assigning bits 17 and 18. Register the test only
after the shared schema compiles.

## Root-owned shared schema

Add these exact `PlayerState` fields and defaults, reset them in
`reset_for_spawn`, include them in canonical state and snapshots, validate bounds,
and bump the protocol/snapshot revisions together:

```gdscript
var physical_kind: int = 0                    # 0 none, 1 punch, 2 kick
var physical_phase: int = 0                   # 0 none, 1 startup, 2 active, 3 recovery
var physical_phase_ticks_remaining: int = 0
var physical_phase_ticks_total: int = 0
var physical_aim_x: int = 1000
var physical_aim_y: int = 0
var physical_sequence_id: int = 0
var physical_buffer_kind: int = 0
var physical_buffer_ticks: int = 0
var physical_recovery_lock_ticks: int = 0
var physical_hit_ids: PackedInt32Array = PackedInt32Array()
var knockback_guard_ticks: int = 0
```

Suggested validation bounds are kind `0..2`, phase `0..3`, phase timers
`0..240`, aim components `-1000..1000` with a nonzero vector while an attack is
live, sequence `0..2,000,000,000`, buffer kind `0..2`, buffer ticks `0..10`,
recovery lock `0..28`, unique positive hit IDs capped to the seven other lobby
actors, and knockback guard `0..48`.

Add `SimCommand.PRESSED_PUNCH = 1 << 17` and
`SimCommand.PRESSED_KICK = 1 << 18`; its existing canonical pressed mask already
transports these bits once validators admit them. Preserve all earlier bit values.

## SimWorld integration order

For each living actor, call `begin_tick` immediately after
`MovementSystem.step`. This observes newly accepted movement interruptions while
leaving WASD movement free. Pass the returned physical-bit mask through a copied
command with those bits cleared before any later consumer. Call
`resolve_all(self)` once after every actor has moved and before ordered ranged
contact resolution. This gives simultaneous physical candidates one shared
post-movement basis and lets an earlier lethal result suppress a later dead
attacker deterministically.

The future S6 insertion point is the marked line between successful damage and
`_apply_knockback`. It must use `target_position_before_knockback` to compute the
canonical occupied hex and spend at most one infusion when `first_contact` is
true. Do not infer that hex from the post-resolution target position.

Add the seven new event types to the event/snapshot validators:
`physical_attack_started`, `physical_attack_buffered`,
`physical_attack_phase`, `physical_attack_ready`,
`physical_attack_refused`, `physical_attack_cancelled`, and
`physical_attack_contact`, plus the existing `champion_defeated` form used by the
resolver. If external modal UI opens while an attack/buffer exists, call
`cancel(..., &"modal", ..., true)` and continue emitting zero physical command
bits until the input router rearms. Death/reset calls preserve-debt `false`.

Until S6, prevent a spell button from also launching a ranged cast during an
active physical sequence. S6 will replace that gate with its one accepted
material-only infusion path. This candidate intentionally does not decide or
mutate that shared `CombatSystem` policy.

## Focused evidence and remaining gates

The candidate test covers exact data, immutable profile copies, atomic malformed
reload, simultaneous-button priority, exact one-time Stamina spend, startup /
active / recovery boundaries, one hit per target per sequence, first-buffer wins,
movement cancellation debt, death cleanup, team/protection/arc/height/cover
gates, body-size reach invariance, wall collision, and guarded repeated push.

No Godot command, import, test, capture, profiling, or visual review was run while
building this isolated candidate. Root still must perform parser/import checks,
focused tests, authoritative snapshot/replay checks, native three-size/eight-way
presentation capture, normal/reduced readability review, and human timing/feel.

Rollback before promotion is deletion of this candidate directory. After
promotion, rollback must remove the four mapped live files and reverse the same
root-owned schema, command-bit, event-validator, protocol, registration, and
integration changes as one revision.

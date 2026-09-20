class_name PhysicalAttackSystem
extends RefCounted

## Deterministic S5 Punch/Kick state machine and contact resolver.
##
## This candidate deliberately reads the proposed PlayerState fields dynamically
## so it can remain isolated until root integrates the shared schema. It never
## owns movement, modal input routing, command serialization, or snapshots.

const Tuning = preload("res://.agent/candidates/gameplay_s5/src/sim/combat/physical_attack_tuning.gd")

# Candidate command bits. Promotion adds these names to SimCommand and replaces
# these references with that protocol authority in the same integration change.
const PRESSED_PUNCH_BIT := 1 << 17
const PRESSED_KICK_BIT := 1 << 18
const PHYSICAL_PRESSED_BITS := PRESSED_PUNCH_BIT | PRESSED_KICK_BIT

enum Kind { NONE, PUNCH, KICK }
enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }


## Advances one actor exactly once per authority tick. Call after MovementSystem
## so paid Slide/Roll/Air Dodge/Wall Kick state can cancel an attack before its
## active contact, and before CombatSystem so consumed bits can be quarantined.
## The returned mask is the only command mutation request; this function does not
## mutate the SimCommand itself.
static func begin_tick(state, command: SimCommand, config: SimConfig, tick: int, events: Array[Dictionary]) -> Dictionary:
	var result := {
		"consumed_pressed_actions": 0,
		"started": false,
		"buffered": false,
		"kind": Kind.NONE,
		"sequence_id": 0,
		"reason": &"",
	}
	if state == null or config == null or not config.is_valid():
		result.reason = &"invalid"
		return result

	state.knockback_guard_ticks = maxi(0, int(state.knockback_guard_ticks) - 1)
	state.physical_recovery_lock_ticks = maxi(0, int(state.physical_recovery_lock_ticks) - 1)
	var requested := _requested_kind(command)
	if command != null:
		result.consumed_pressed_actions = int(command.pressed_actions) & PHYSICAL_PRESSED_BITS

	if int(state.health) <= 0:
		cancel(state, &"death", tick, events, false)
		result.reason = &"death"
		return result

	if _movement_interrupting(state):
		if int(state.physical_phase) != Phase.NONE or int(state.physical_buffer_kind) != Kind.NONE:
			cancel(state, &"movement", tick, events, true)
		if requested != Kind.NONE:
			_refuse(state, requested, &"movement", tick, events)
			result.reason = &"movement"
		return result

	_advance_phase(state, tick, events)

	# A buffered action owns priority over a new same-tick press. Payment happens
	# only now, when recovery has actually released the next attack.
	if _ready(state) and int(state.physical_buffer_kind) != Kind.NONE:
		var buffered_kind: int = int(state.physical_buffer_kind)
		_clear_buffer(state)
		var started := _start(state, buffered_kind, config, tick, events)
		result.started = bool(started.accepted)
		result.kind = buffered_kind
		result.sequence_id = int(state.physical_sequence_id) if result.started else 0
		result.reason = started.reason
		return result

	var stored_buffer := false
	if requested != Kind.NONE:
		result.kind = requested
		if _ready(state):
			var started := _start(state, requested, config, tick, events)
			result.started = bool(started.accepted)
			result.sequence_id = int(state.physical_sequence_id) if result.started else 0
			result.reason = started.reason
			return result
		if _buffer_window_open(state):
			# First valid buffered button wins. Simultaneous input resolves Punch in
			# _requested_kind and later presses cannot replace the stored choice.
			if int(state.physical_buffer_kind) == Kind.NONE:
				state.physical_buffer_kind = requested
				state.physical_buffer_ticks = maxi(1, maxi(int(state.physical_phase_ticks_remaining), int(state.physical_recovery_lock_ticks)))
				events.append({"type": "physical_attack_buffered", "entity_id": int(state.entity_id), "kind": _kind_name(requested), "tick": tick})
				result.buffered = true
				stored_buffer = true
			return result
		_refuse(state, requested, &"busy", tick, events)
		result.reason = &"busy"

	if not stored_buffer and int(state.physical_buffer_kind) != Kind.NONE and not _ready(state):
		state.physical_buffer_ticks = maxi(0, int(state.physical_buffer_ticks) - 1)
		if int(state.physical_buffer_ticks) == 0:
			_clear_buffer(state)
	return result


## Clears attack/hit/buffer state. An alive movement or modal cancellation keeps
## the recovery that the paid attack still owed. Death/reset callers pass false.
static func cancel(state, reason: StringName, tick: int, events: Array[Dictionary], preserve_debt: bool = true) -> void:
	if state == null:
		return
	var old_kind := int(state.physical_kind)
	var old_phase := int(state.physical_phase)
	var had_state := old_phase != Phase.NONE or int(state.physical_buffer_kind) != Kind.NONE
	var debt := int(state.physical_recovery_lock_ticks)
	if preserve_debt and int(state.health) > 0 and old_kind != Kind.NONE:
		var profile := Tuning.shared().profile(old_kind)
		if old_phase == Phase.RECOVERY:
			debt = maxi(debt, int(state.physical_phase_ticks_remaining))
		elif old_phase in [Phase.STARTUP, Phase.ACTIVE] and not profile.is_empty():
			debt = maxi(debt, int(profile.recovery_ticks))
	else:
		debt = 0
	_clear_attack(state)
	state.physical_recovery_lock_ticks = debt
	if had_state:
		events.append({"type": "physical_attack_cancelled", "entity_id": int(state.entity_id), "kind": _kind_name(old_kind), "reason": reason, "recovery_debt": debt, "tick": tick})


## Plans contacts from the common post-movement positions, then resolves in
## attacker/target ID order. Knockback from an earlier result therefore cannot
## erase a simultaneous later candidate, while death/protection are revalidated.
## Returns the emitted contact records for focused callers and future S6 routing.
static func resolve_all(world) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	if world == null or world.config == null or not world.config.is_valid() or world.collision == null:
		return resolved
	var tuning := Tuning.shared()
	if not tuning.is_valid():
		return resolved
	var actors: Array = world.players.duplicate()
	actors.sort_custom(func(left, right) -> bool: return int(left.entity_id) < int(right.entity_id))
	var snapshots := {}
	for actor in actors:
		snapshots[int(actor.entity_id)] = {"position": Vector2i(int(actor.position_x), int(actor.position_y)), "height": int(actor.air_height)}
	var plans: Array[Dictionary] = []
	for attacker in actors:
		if int(attacker.health) <= 0 or int(attacker.physical_phase) != Phase.ACTIVE:
			continue
		var profile := tuning.profile(int(attacker.physical_kind))
		if profile.is_empty():
			continue
		for target in actors:
			if not _eligible_target(attacker, target, profile, snapshots, tuning, world.config):
				continue
			if int(target.entity_id) in attacker.physical_hit_ids:
				continue
			var attacker_point: Vector2i = snapshots[int(attacker.entity_id)].position
			var target_point: Vector2i = snapshots[int(target.entity_id)].position
			var direction := _contact_direction(attacker, attacker_point, target_point)
			var contact := target_point - _scaled(direction, int(target.radius))
			if not ElementChemistrySystem.clear_line(attacker_point, contact, world.collision):
				continue
			plans.append({
				"attacker": attacker,
				"target": target,
				"profile": profile,
				"sequence_id": int(attacker.physical_sequence_id),
				"direction": direction,
				"contact": contact,
				"target_position": target_point,
			})

	for plan: Dictionary in plans:
		var attacker = plan.attacker
		var target = plan.target
		if int(attacker.health) <= 0 or int(attacker.physical_phase) != Phase.ACTIVE or int(attacker.physical_sequence_id) != int(plan.sequence_id):
			continue
		if int(target.health) <= 0 or int(target.spawn_protection_ticks) > 0 or target.team_id == attacker.team_id or target.entity_id == attacker.entity_id:
			continue
		if MovementSystem.is_combat_intangible(target, world.config) or int(target.entity_id) in attacker.physical_hit_ids:
			continue
		var profile: Dictionary = plan.profile
		if not PlayerResourcesSystem.damage(target, int(profile.damage), world.config):
			continue
		var first_contact: bool = attacker.physical_hit_ids.is_empty()
		attacker.physical_hit_ids.append(int(target.entity_id))
		attacker.physical_hit_ids.sort()
		var knockback := _plan_knockback(target, plan.direction, int(profile.knockback), tuning.knockback_guard_ticks, world.collision)
		var contact_event := {
			"type": "physical_attack_contact",
			"attacker_id": int(attacker.entity_id),
			"target_id": int(target.entity_id),
			"kind": String(profile.id),
			"sequence_id": int(plan.sequence_id),
			"damage": int(profile.damage),
			"contact_position": plan.contact,
			"target_position_before_knockback": plan.target_position,
			"first_contact": first_contact,
			"knockback_delta": knockback.delta,
			"knockback_guarded": bool(knockback.guarded),
			"wall_id": int(knockback.wall_id),
			"tick": int(world.tick),
		}
		# S6 inserts its one confirmed-contact infusion callback here, using the
		# captured target position, before the following knockback mutation.
		world.combat_events.append(contact_event)
		resolved.append(contact_event.duplicate(true))
		_apply_knockback(target, knockback, tuning.knockback_guard_ticks)
		if int(target.actor_kind) == PlayerState.ActorKind.CHAMPION and int(target.health) == 0:
			world.combat_events.append({"type": "champion_defeated", "attacker_id": int(attacker.entity_id), "target_id": int(target.entity_id), "physical_sequence_id": int(plan.sequence_id)})
	return resolved


static func _requested_kind(command: SimCommand) -> int:
	if command == null:
		return Kind.NONE
	if (int(command.pressed_actions) & PRESSED_PUNCH_BIT) != 0:
		return Kind.PUNCH
	if (int(command.pressed_actions) & PRESSED_KICK_BIT) != 0:
		return Kind.KICK
	return Kind.NONE


static func _start(state, kind: int, config: SimConfig, tick: int, events: Array[Dictionary]) -> Dictionary:
	var tuning := Tuning.shared()
	var profile := tuning.profile(kind)
	if not tuning.is_valid() or profile.is_empty():
		_refuse(state, kind, &"tuning", tick, events)
		return {"accepted": false, "reason": &"tuning"}
	var cost := int(profile.stamina_cost)
	if int(state.stamina) < cost:
		_refuse(state, kind, &"stamina", tick, events)
		return {"accepted": false, "reason": &"stamina"}
	MovementSystem._spend_stamina(state, cost, config)
	state.physical_kind = kind
	state.physical_phase = Phase.STARTUP
	state.physical_phase_ticks_remaining = int(profile.startup_ticks)
	state.physical_phase_ticks_total = int(profile.startup_ticks)
	state.physical_aim_x = int(state.aim_x)
	state.physical_aim_y = int(state.aim_y)
	state.physical_sequence_id = 1 if int(state.physical_sequence_id) >= 2_000_000_000 else int(state.physical_sequence_id) + 1
	state.physical_hit_ids.clear()
	_clear_buffer(state)
	events.append({"type": "physical_attack_started", "entity_id": int(state.entity_id), "kind": String(profile.id), "sequence_id": int(state.physical_sequence_id), "stamina_cost": cost, "aim_x": int(state.physical_aim_x), "aim_y": int(state.physical_aim_y), "tick": tick})
	return {"accepted": true, "reason": &""}


static func _advance_phase(state, tick: int, events: Array[Dictionary]) -> void:
	if int(state.physical_phase) == Phase.NONE:
		return
	state.physical_phase_ticks_remaining = maxi(0, int(state.physical_phase_ticks_remaining) - 1)
	if int(state.physical_phase_ticks_remaining) > 0:
		return
	var profile := Tuning.shared().profile(int(state.physical_kind))
	if profile.is_empty():
		cancel(state, &"tuning", tick, events, true)
		return
	match int(state.physical_phase):
		Phase.STARTUP:
			_set_phase(state, Phase.ACTIVE, int(profile.active_ticks), tick, events)
		Phase.ACTIVE:
			_set_phase(state, Phase.RECOVERY, int(profile.recovery_ticks), tick, events)
		Phase.RECOVERY:
			var kind := int(state.physical_kind)
			state.physical_kind = Kind.NONE
			state.physical_phase = Phase.NONE
			state.physical_phase_ticks_remaining = 0
			state.physical_phase_ticks_total = 0
			state.physical_hit_ids.clear()
			events.append({"type": "physical_attack_ready", "entity_id": int(state.entity_id), "kind": _kind_name(kind), "tick": tick})


static func _set_phase(state, phase: int, duration: int, tick: int, events: Array[Dictionary]) -> void:
	state.physical_phase = phase
	state.physical_phase_ticks_remaining = duration
	state.physical_phase_ticks_total = duration
	events.append({"type": "physical_attack_phase", "entity_id": int(state.entity_id), "kind": _kind_name(int(state.physical_kind)), "phase": _phase_name(phase), "ticks": duration, "tick": tick})


static func _eligible_target(attacker, target, profile: Dictionary, snapshots: Dictionary, tuning, config: SimConfig) -> bool:
	if target == null or target == attacker or int(target.entity_id) == int(attacker.entity_id) or int(target.team_id) == int(attacker.team_id):
		return false
	if int(target.health) <= 0 or int(target.spawn_protection_ticks) > 0 or MovementSystem.is_combat_intangible(target, config):
		return false
	var attacker_state: Dictionary = snapshots.get(int(attacker.entity_id), {})
	var target_state: Dictionary = snapshots.get(int(target.entity_id), {})
	if attacker_state.is_empty() or target_state.is_empty() or absi(int(attacker_state.height) - int(target_state.height)) > tuning.height_tolerance:
		return false
	var offset: Vector2i = target_state.position - attacker_state.position
	var reach := int(profile.reach) + int(target.radius)
	if offset.length_squared() > reach * reach:
		return false
	if offset == Vector2i.ZERO:
		return true
	var aim := Vector2i(int(attacker.physical_aim_x), int(attacker.physical_aim_y))
	var projection := offset.dot(aim)
	return projection > 0 and projection * projection >= offset.length_squared() * int(profile.half_arc_cosine_squared)


static func _contact_direction(attacker, attacker_point: Vector2i, target_point: Vector2i) -> Vector2i:
	var delta := target_point - attacker_point
	if delta == Vector2i.ZERO:
		return Vector2i(int(attacker.physical_aim_x), int(attacker.physical_aim_y))
	return SimCommand._normalized_direction(delta.x, delta.y)


static func _plan_knockback(target, direction: Vector2i, authored_amount: int, guard_ticks: int, collision: CollisionWorld) -> Dictionary:
	var guarded := int(target.knockback_guard_ticks) > 0
	var amount := authored_amount / 4 if guarded else authored_amount
	var delta := _scaled(direction, amount)
	var old_position := Vector2i(int(target.position_x), int(target.position_y))
	# Every body shares the proven 18px movement/wall clearance. The target's
	# serialized hurt radius affects contact reach only; it never changes motion.
	var moved := collision.move_box(old_position, delta, MovementTuning.PLAYER_RADIUS)
	return {"position": moved.position, "delta": moved.position - old_position, "wall_id": moved.wall_id, "guarded": guarded, "guard_ticks": guard_ticks}


static func _apply_knockback(target, plan: Dictionary, guard_ticks: int) -> void:
	target.position_x = int(plan.position.x)
	target.position_y = int(plan.position.y)
	target.knockback_guard_ticks = guard_ticks


static func _movement_interrupting(state) -> bool:
	return (
		int(state.slide_ticks) > 0
		or int(state.air_dodge_ticks) > 0
		or (int(state.hop_ticks) > 0 and int(state.hop_mode) == PlayerState.MovementMode.WALL_KICK)
	)


static func _ready(state) -> bool:
	return int(state.physical_phase) == Phase.NONE and int(state.physical_recovery_lock_ticks) == 0


static func _buffer_window_open(state) -> bool:
	var tuning := Tuning.shared()
	if not tuning.is_valid() or int(state.physical_buffer_kind) != Kind.NONE:
		return false
	if int(state.physical_phase) == Phase.RECOVERY:
		return int(state.physical_phase_ticks_remaining) <= tuning.buffer_window_ticks
	return int(state.physical_phase) == Phase.NONE and int(state.physical_recovery_lock_ticks) > 0 and int(state.physical_recovery_lock_ticks) <= tuning.buffer_window_ticks


static func _clear_attack(state) -> void:
	state.physical_kind = Kind.NONE
	state.physical_phase = Phase.NONE
	state.physical_phase_ticks_remaining = 0
	state.physical_phase_ticks_total = 0
	state.physical_hit_ids.clear()
	_clear_buffer(state)


static func _clear_buffer(state) -> void:
	state.physical_buffer_kind = Kind.NONE
	state.physical_buffer_ticks = 0


static func _refuse(state, kind: int, reason: StringName, tick: int, events: Array[Dictionary]) -> void:
	events.append({"type": "physical_attack_refused", "entity_id": int(state.entity_id), "kind": _kind_name(kind), "reason": reason, "tick": tick})


static func _scaled(direction: Vector2i, amount: int) -> Vector2i:
	return Vector2i(direction.x * amount / SimConfig.FIXED_SCALE, direction.y * amount / SimConfig.FIXED_SCALE)


static func _kind_name(kind: int) -> String:
	return "punch" if kind == Kind.PUNCH else "kick" if kind == Kind.KICK else "none"


static func _phase_name(phase: int) -> String:
	return "startup" if phase == Phase.STARTUP else "active" if phase == Phase.ACTIVE else "recovery" if phase == Phase.RECOVERY else "none"

extends RefCounted
@warning_ignore_start("integer_division")
## Stateless Solo Duel command policy. The ordinary actor's accepted aim is the
## only commitment memory. No world, actor, resource or projectile is mutated.

const READY_END: int = 4 * 120
const DURATION_TICKS: int = 72 * 120
const WINDUP_TICKS: int = 96
const PRESSURE_TICKS: int = 216
const RECOVERY_TICKS: int = 168
const CYCLE_TICKS: int = WINDUP_TICKS + PRESSURE_TICKS + RECOVERY_TICKS
const BOLT_TICKS: Array[int] = [60, 180]
const BOLT_AIM_LEAD_TICKS: int = 24
const HEAVY_RELEASE_GUARD_TICKS: int = 24
const RAPID_START: int = 96
const RAPID_END: int = 150
const COURT_INSET: int = 64 * SimConfig.FIXED_SCALE
const NEAR_DISTANCE: int = 280 * SimConfig.FIXED_SCALE
const FAR_DISTANCE: int = 440 * SimConfig.FIXED_SCALE
const STEER_DISTANCE: int = 96 * SimConfig.FIXED_SCALE
const READY := "ready"
const WINDUP := "windup"
const PRESSURE := "pressure"
const RECOVER := "recover"
const COMPLETE := "complete"


static func status(world_tick: int, start_tick: int) -> Dictionary:
	if start_tick < 0 or world_tick < start_tick:
		return {}
	var elapsed := world_tick - start_tick
	var phase := READY
	var remaining := maxi(0, READY_END - elapsed)
	var cycle_tick := -1
	var cycle_index := -1
	var cue := "Prepare: Heavy windup, volley, then an exposed pause."
	var telegraph := ""
	if elapsed >= DURATION_TICKS:
		phase = COMPLETE
		remaining = 0
		cue = "Trial time has ended."
	elif elapsed >= READY_END:
		cycle_tick = posmod(elapsed - READY_END, CYCLE_TICKS)
		cycle_index = (elapsed - READY_END) / CYCLE_TICKS
		if cycle_tick < WINDUP_TICKS:
			phase = WINDUP
			remaining = WINDUP_TICKS - cycle_tick
			telegraph = "heavy"
			cue = "Heavy incoming: sidestep the facing line or take cover."
		elif cycle_tick < WINDUP_TICKS + PRESSURE_TICKS:
			phase = PRESSURE
			remaining = WINDUP_TICKS + PRESSURE_TICKS - cycle_tick
			telegraph = "volley"
			cue = "Heavy, spaced Bolts and a short Rapid burst: keep moving."
		else:
			phase = RECOVER
			remaining = CYCLE_TICKS - cycle_tick
			cue = "Exposed pause: attack or recover Flux; lingering shots remain."
	return {"phase":phase, "cue":cue, "telegraph":telegraph,
		"remaining_ticks":mini(remaining, maxi(0, DURATION_TICKS - elapsed)),
		"total_remaining_ticks":maxi(0, DURATION_TICKS - elapsed),
		"elapsed_ticks":mini(elapsed, DURATION_TICKS),
		"cycle_tick":cycle_tick, "cycle_index":cycle_index,
		"complete":phase == COMPLETE, "break":phase == RECOVER}


static func command_for_tick(
	world_tick: int,
	start_tick: int,
	opponent: PlayerState,
	player: PlayerState,
	slots: Dictionary,
	court_bounds_fixed: Rect2i,
) -> SimCommand:
	var current := status(world_tick, start_tick)
	if current.is_empty() or not _valid_actors(opponent, player, court_bounds_fixed) or not _valid_slots(slots, opponent):
		return null
	var phase := String(current.phase)
	var aim := Vector2i(opponent.aim_x, opponent.aim_y)
	var movement := Vector2i.ZERO
	var held := 0
	var pressed := 0
	var opponent_position := Vector2i(opponent.position_x, opponent.position_y)
	if not court_bounds_fixed.has_point(opponent_position):
		# Knockback can move the rival outside the court. Request ordinary
		# re-entry without firing, rather than becoming permanently inert.
		var return_delta := court_bounds_fixed.get_center() - opponent_position
		if phase in [WINDUP, PRESSURE]:
			movement = SimCommand._normalized_direction(return_delta.x, return_delta.y)
		return SimCommand.new(world_tick, opponent.entity_id, movement.x, movement.y, 0, 0, aim.x, aim.y)
	if phase in [WINDUP, PRESSURE]:
		var cycle_tick := int(current.cycle_tick)
		var pressure_tick := cycle_tick - WINDUP_TICKS
		# SimWorld accepts this ordinary aim even on a command without a cast.
		# Future ticks retain that accepted direction, rather than looking up a
		# past player position or tracking through the final tell. Direction-only
		# shots retain authored travel; no invented locked ground target is used.
		var rapid_window: bool = phase == PRESSURE and pressure_tick >= RAPID_START and pressure_tick < RAPID_END
		if cycle_tick == 0 or rapid_window or (phase == PRESSURE and (pressure_tick + BOLT_AIM_LEAD_TICKS) in BOLT_TICKS):
			aim = Vector2i(player.position_x - opponent.position_x, player.position_y - opponent.position_y)
		if phase == PRESSURE:
			if pressure_tick == 0:
				pressed = SimCommand.SPELL_PRESSED_BITS[int(slots.heavy) - 1]
			elif pressure_tick in BOLT_TICKS:
				pressed = SimCommand.SPELL_PRESSED_BITS[int(slots.bolt) - 1]
			if rapid_window:
				held = SimCommand.SPELL_HELD_BITS[int(slots.rapid) - 1]
		# A stationary tell preserves the committed firing line. Pressure only
		# strafes after Heavy's ordinary startup has had time to release.
		if phase == PRESSURE and pressure_tick >= HEAVY_RELEASE_GUARD_TICKS:
			movement = _movement(opponent, player, court_bounds_fixed, int(current.cycle_index))
		var separation := Vector2i(opponent.position_x - player.position_x, opponent.position_y - player.position_y)
		if movement != Vector2i.ZERO and separation.length_squared() < NEAR_DISTANCE * NEAR_DISTANCE:
			held |= SimCommand.HELD_SPRINT # Ordinary admission pays Stamina and may refuse.
	# READY, RECOVER and COMPLETE request neutral movement and no new casts.
	# Existing paid startups/flights and ordinary braking are never cancelled.
	return SimCommand.new(world_tick, opponent.entity_id, movement.x, movement.y, held, pressed, aim.x, aim.y)


static func _valid_actors(opponent: PlayerState, player: PlayerState, bounds: Rect2i) -> bool:
	if opponent == null or player == null or opponent == player:
		return false
	if opponent.entity_id < 1 or opponent.entity_id > 8 or player.entity_id < 1 or player.entity_id > 8 or opponent.entity_id == player.entity_id:
		return false
	if opponent.actor_kind != PlayerState.ActorKind.CHAMPION or player.actor_kind != PlayerState.ActorKind.CHAMPION or opponent.team_id == player.team_id or opponent.health <= 0 or player.health <= 0:
		return false
	if bounds.position.x < 0 or bounds.position.y < 0 or bounds.size.x < 320000 or bounds.size.y < 240000 or bounds.size.x > 100000000 or bounds.size.y > 100000000 or bounds.end.x > 100000000 or bounds.end.y > 100000000:
		return false
	if opponent.position_x < 0 or opponent.position_y < 0 or opponent.position_x > 100000000 or opponent.position_y > 100000000:
		return false
	return bounds.has_point(Vector2i(player.position_x, player.position_y))


static func _valid_slots(slots: Dictionary, opponent: PlayerState) -> bool:
	var seen := {}
	for role: String in ["rapid", "bolt", "heavy"]:
		if typeof(slots.get(role)) != TYPE_INT: return false
		var slot := int(slots[role])
		if slot < 1 or slot > SimCommand.SPELL_PRESSED_BITS.size() or seen.has(slot) or opponent.spell_wire_id(slot) <= 0:
			return false
		var definition := CombatTuning.cast_definition_view(opponent.spell_wire_id(slot))
		if String(definition.get("family", "")) != role or int(definition.get("flux_cost", 0)) <= 0:
			return false
		seen[slot] = true
	return true


static func _movement(opponent: PlayerState, player: PlayerState, bounds: Rect2i, cycle_index: int) -> Vector2i:
	var position := Vector2i(opponent.position_x, opponent.position_y)
	var separation := position - Vector2i(player.position_x, player.position_y)
	var distance_squared := separation.length_squared()
	if separation == Vector2i.ZERO: separation = bounds.get_center() - position
	var away := SimCommand._normalized_direction(separation.x, separation.y)
	var side := 1 if posmod(cycle_index, 2) == 0 else -1
	var tangent := Vector2i(-away.y, away.x) * side
	var desired := tangent
	if distance_squared < NEAR_DISTANCE * NEAR_DISTANCE:
		desired = away + tangent
	elif distance_squared > FAR_DISTANCE * FAR_DISTANCE:
		desired = -away + tangent
	desired = SimCommand._normalized_direction(desired.x, desired.y)
	var target := position + desired * STEER_DISTANCE / 1000
	var safe := bounds.grow(-COURT_INSET)
	target.x = clampi(target.x, safe.position.x, safe.end.x - 1)
	target.y = clampi(target.y, safe.position.y, safe.end.y - 1)
	var delta := target - position
	if delta.length_squared() < 4000000:
		# A corner blocks the preferred strafe, not the simulation. Re-center
		# through ordinary movement; collision and current momentum still own it.
		delta = safe.get_center() - position
	return Vector2i.ZERO if delta == Vector2i.ZERO else SimCommand._normalized_direction(delta.x, delta.y)

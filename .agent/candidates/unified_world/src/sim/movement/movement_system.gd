class_name MovementSystem
extends RefCounted

const ResourceRecoveryScript = preload("res://src/sim/entities/resource_recovery.gd")


static func step(state: PlayerState, command: SimCommand, config: SimConfig, world: CollisionWorld, ground_target_ratio: int = 1000, acceleration_ratio: int = 1000, braking_ratio: int = 1000) -> void:
	_advance_timers(state, config)
	state.stamina_recovery_idle_ticks = ResourceRecoveryScript.advance_idle(state.stamina_recovery_idle_ticks, state.stamina_recovery_delay_ticks, config.tick_rate)
	var direction: Vector2i = _direction(command.move_x, command.move_y, Vector2i(state.facing_x, state.facing_y))
	if command.move_x != 0 or command.move_y != 0:
		state.facing_x = direction.x
		state.facing_y = direction.y
	_capture_action_buffers(state, command, config)
	if state.wall_skim_ticks <= 0 and state.technique_buffer_ticks > 0:
		_refresh_wall_contact(state, world, config)
	_update_wall_attachment(state, command, world, config)
	if state.is_airborne() and (command.move_x != 0 or command.move_y != 0):
		state.landing_input_x = direction.x
		state.landing_input_y = direction.y
		state.landing_input_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_INPUT_BUFFER_MS)

	var impact_tech_started := false
	if state.impact_recovery_ticks > 0:
		impact_tech_started = _try_impact_recovery_tech(state, direction, config)
	var control_locked: bool = state.impact_recovery_ticks > 0 or state.control_state in [
		PlayerState.ControlState.LAUNCHED,
		PlayerState.ControlState.GRAPPLED,
		PlayerState.ControlState.CHARGING,
		PlayerState.ControlState.STUNNED,
		PlayerState.ControlState.ROOTED,
	]
	if not control_locked and not impact_tech_started and state.movement_commitment_ticks == 0:
		# Exactly one newest movement intent owns this tick, including free brakes.
		if state.evade_buffer_ticks > 0:
			_consume_evade_buffer(state, command, direction, config)
		elif state.jump_buffer_ticks > 0:
			_consume_jump_buffer(state, command, direction, config)
		elif state.slide_buffer_ticks > 0:
			_consume_slide_buffer(state, direction, config)
		elif state.technique_buffer_ticks > 0:
			_consume_technique_buffer(state, command, direction, config, world)
	if not control_locked:
		_apply_variable_air_time(state, command, config)
		_apply_variable_slide_time(state, command, config)
	elif state.air_floating:
		_end_air_float(state, "float_interrupted")

	if impact_tech_started:
		pass # The technique owns this tick's velocity; ordinary control resumes next tick.
	elif state.impact_recovery_ticks > 0:
		_apply_impact_recovery_velocity(state, config)
	elif control_locked:
		if state.control_state == PlayerState.ControlState.LAUNCHED:
			_apply_launch_influence(state, command, direction, config)
		_apply_control_velocity(state, config)
	else:
		var movement_command := command
		if state.last_event == "land" and command.move_x == 0 and command.move_y == 0 and state.landing_input_ticks > 0:
			movement_command = command.copy()
			movement_command.move_x = state.landing_input_x
			movement_command.move_y = state.landing_input_y
			direction = Vector2i(state.landing_input_x, state.landing_input_y)
			state.landing_input_ticks = 0
		_apply_velocity(state, movement_command, direction, config, ground_target_ratio, acceleration_ratio, braking_ratio)
	_integrate(state, config, world)
	_update_wall_attachment(state, command, world, config)
	_integrate_height(state, config)
	_update_mode(state, command)
	state.slide_held_last_tick = command.has_held(SimCommand.HELD_FAST_FALL)
	state.jump_held_last_tick = command.has_held(SimCommand.HELD_JUMP)


static func _capture_action_buffers(state: PlayerState, command: SimCommand, config: SimConfig) -> void:
	var buffer_ticks: int = config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS)
	var movement_pressed: int = command.pressed_actions & (SimCommand.PRESSED_EVADE | SimCommand.PRESSED_JUMP | SimCommand.PRESSED_SLIDE | SimCommand.PRESSED_TECHNIQUE)
	if command.has_held(SimCommand.HELD_JUMP) and state.jump_held_last_tick:
		movement_pressed &= ~SimCommand.PRESSED_JUMP
	if movement_pressed == 0:
		return
	_clear_action_buffers(state)
	if movement_pressed & SimCommand.PRESSED_EVADE:
		state.evade_buffer_ticks = buffer_ticks
		state.evade_buffer_airborne = state.is_airborne()
	elif movement_pressed & SimCommand.PRESSED_JUMP:
		state.jump_buffer_ticks = buffer_ticks
	elif movement_pressed & SimCommand.PRESSED_SLIDE and not state.is_airborne():
		state.slide_buffer_ticks = buffer_ticks
	elif movement_pressed & SimCommand.PRESSED_TECHNIQUE:
		state.technique_buffer_ticks = buffer_ticks


static func _clear_action_buffers(state: PlayerState) -> void:
	state.evade_buffer_ticks = 0
	state.evade_buffer_airborne = false
	state.jump_buffer_ticks = 0
	state.slide_buffer_ticks = 0
	state.technique_buffer_ticks = 0


static func _consume_slide_buffer(state: PlayerState, direction: Vector2i, config: SimConfig) -> void:
	if state.slide_buffer_ticks > 0 and state.slide_ticks > 0:
		state.slide_ticks = 0
		state.slide_buffer_ticks = 0
		state.velocity_x = 0
		state.velocity_y = 0
		state.last_event = "slide_brake"
		return
	if state.slide_buffer_ticks > 0 and not state.is_airborne() and _try_slide(state, direction, config):
		state.slide_buffer_ticks = 0


static func _consume_jump_buffer(state: PlayerState, command: SimCommand, direction: Vector2i, config: SimConfig) -> void:
	if state.jump_buffer_ticks <= 0:
		return
	var consumed := false
	if state.slide_ticks > 0:
		consumed = _try_slide_jump(state, direction, config)
	elif state.wall_skim_ticks > 0:
		if state.hop_stage < 2:
			consumed = _try_air_wall_kick(state, direction, config)
		else:
			consumed = _try_air_float(state, command, direction, config)
	elif state.hop_ticks > 0:
		var outward := direction.x * state.wall_x + direction.y * state.wall_y > 0
		if state.wall_memory_ticks > 0 and state.wall_contact_id > 0 and outward and state.hop_stage == 1:
			consumed = _try_air_wall_kick(state, direction, config)
		else:
			consumed = _try_air_float(state, command, direction, config)
	elif state.air_dodge_ticks > 0 and not state.is_rolling():
		consumed = _try_air_float(state, command, direction, config)
	elif state.air_dodge_ticks <= 0 or state.is_rolling():
		consumed = _try_hop(state, direction, config)
	if consumed:
		state.jump_buffer_ticks = 0


static func _consume_evade_buffer(state: PlayerState, command: SimCommand, direction: Vector2i, config: SimConfig) -> void:
	if state.evade_buffer_ticks <= 0:
		return
	if state.evade_buffer_airborne != state.is_airborne():
		state.evade_buffer_ticks = 0
		state.evade_buffer_airborne = false
		return
	var consumed := false
	if state.is_airborne() or state.wall_skim_ticks > 0:
		# Read current transformed movement at admission. Exact neutral must never
		# inherit facing, aim, momentum, or the direction held when Q was pressed.
		if command.move_x == 0 and command.move_y == 0:
			consumed = _try_air_fast_fall(state, config)
		else:
			consumed = _try_air_dodge(state, direction, config)
	else:
		consumed = _try_roll(state, direction, config)
	if consumed:
		state.evade_buffer_ticks = 0


static func _try_air_fast_fall(state: PlayerState, config: SimConfig) -> bool:
	if not state.is_airborne():
		return false
	# A wallrun owns height until its ordinary finite exit. Leave that state
	# first, then reuse the same canonical vertical latch as airborne Slide.
	if state.wall_skim_ticks > 0:
		_end_wall_run(state, "wall_detach", config)
	state.fast_fall_armed = true
	return true


static func _consume_technique_buffer(state: PlayerState, command: SimCommand, direction: Vector2i, config: SimConfig, world: CollisionWorld) -> void:
	if state.technique_buffer_ticks <= 0:
		return
	if state.wall_skim_ticks <= 0 and command.move_x == 0 and command.move_y == 0:
		state.technique_buffer_ticks = 0
		return
	var consumed := false
	if state.wall_skim_ticks > 0:
		_end_wall_run(state, "wall_detach", config)
		consumed = true
	elif state.is_airborne() and _has_wall_contact(state, world, state.wall_contact_id):
		consumed = _try_wall_skim(state, direction, config)
		if not consumed:
			consumed = _try_air_redirect(state, direction, config)
	elif state.is_airborne():
		consumed = _try_air_redirect(state, direction, config)
	elif _has_wall_contact(state, world, state.wall_contact_id):
		consumed = _try_wall_skim(state, direction, config)
	else:
		# An empty ground technique cannot later turn into a paid air action.
		state.technique_buffer_ticks = 0
	if consumed:
		state.technique_buffer_ticks = 0
		if state.is_airborne():
			state.variable_jump_grace_ticks = 1


static func _apply_variable_air_time(state: PlayerState, command: SimCommand, config: SimConfig) -> void:
	if not state.is_airborne() or state.wall_skim_ticks > 0:
		state.fast_falling = false
		return
	# Evade owns a same-tick movement chord. Still record held Slide below so a
	# suppressed C press cannot re-arm fast-fall on the following held tick.
	var fresh_air_slide := not command.has_pressed(SimCommand.PRESSED_EVADE) and (
		command.has_pressed(SimCommand.PRESSED_SLIDE)
		or (command.has_held(SimCommand.HELD_FAST_FALL) and not state.slide_held_last_tick)
	)
	# A takeoff grace tick excludes the C edge used for the preceding slide.
	if fresh_air_slide and state.variable_jump_grace_ticks == 0:
		state.fast_fall_armed = true
	if state.air_floating:
		if state.fast_fall_armed:
			_end_air_float(state, "float_fast_fall")
		else:
			_apply_air_float(state, command, config)
			return
	if state.fast_fall_armed:
		state.air_vertical_velocity = mini(state.air_vertical_velocity, -MovementTuning.AIR_FAST_FALL_SPEED)
		if not state.fast_falling:
			state.last_event = "fast_fall"
		state.fast_falling = true
		return
	state.fast_falling = false
	if state.variable_jump_grace_ticks > 0:
		return
	var jump_is_held: bool = command.has_held(SimCommand.HELD_JUMP) or command.has_pressed(SimCommand.PRESSED_JUMP)
	if state.air_vertical_velocity <= 0 or state.air_dodge_ticks > 0:
		return
	if jump_is_held:
		if state.stamina < config.per_tick(MovementTuning.JUMP_SUSTAIN_DRAIN_PER_SECOND):
			state.air_vertical_velocity = mini(state.air_vertical_velocity, MovementTuning.SHORT_HOP_VERTICAL_SPEED)
			state.last_event = "jump_sustain_empty"
		else:
			_apply_stamina_rate(state, -MovementTuning.JUMP_SUSTAIN_DRAIN_PER_SECOND, config)
			state.jump_sustain_ticks += 1
			state.stamina_recovery_delay_ticks = config.milliseconds_to_ticks(MovementTuning.STAMINA_RECOVERY_DELAY_MS)
		return
	if state.air_vertical_velocity > MovementTuning.SHORT_HOP_VERTICAL_SPEED:
		state.air_vertical_velocity = MovementTuning.SHORT_HOP_VERTICAL_SPEED
		state.last_event = "jump_cut"


static func _apply_variable_slide_time(state: PlayerState, command: SimCommand, config: SimConfig) -> void:
	if state.slide_ticks <= 0:
		return
	var minimum_ticks := config.milliseconds_to_ticks(MovementTuning.SLIDE_MINIMUM_MS)
	if state.slide_ticks <= minimum_ticks:
		return
	if not command.has_held(SimCommand.HELD_SLIDE):
		state.slide_ticks = minimum_ticks
		return
	if state.stamina < config.per_tick(MovementTuning.SLIDE_SUSTAIN_DRAIN_PER_SECOND):
		state.slide_ticks = minimum_ticks
		state.last_event = "slide_sustain_empty"
		return
	_apply_stamina_rate(state, -MovementTuning.SLIDE_SUSTAIN_DRAIN_PER_SECOND, config)
	state.stamina_recovery_delay_ticks = config.milliseconds_to_ticks(MovementTuning.STAMINA_RECOVERY_DELAY_MS)


static func apply_control_state(
	state: PlayerState,
	requested_state: int,
	duration_ms: int,
	direction: Vector2i,
	speed: int,
	config: SimConfig,
	slow_ratio: int = 1000,
) -> bool:
	if requested_state < PlayerState.ControlState.FREE or requested_state > PlayerState.ControlState.SLOWED:
		return false
	if requested_state == PlayerState.ControlState.FREE:
		state.control_state = PlayerState.ControlState.FREE
		state.control_ticks = 0
		state.control_speed = 0
		state.slow_ratio = 1000
		state.impact_recovery_ticks = 0
		return true
	if duration_ms <= 0:
		return false
	# A surface/field slow cannot release forced movement or its casting gate.
	# Do not queue it: a fresh contact after the hard-control deadline may apply.
	if requested_state == PlayerState.ControlState.SLOWED and state.control_ticks > 0 and state.control_state in [
		PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.GRAPPLED,
		PlayerState.ControlState.CHARGING, PlayerState.ControlState.STUNNED,
		PlayerState.ControlState.ROOTED,
	]:
		return false
	if requested_state != PlayerState.ControlState.SLOWED and state.air_floating:
		_end_air_float(state, "float_interrupted")
	if requested_state == PlayerState.ControlState.SLOWED:
		var previous_ratio := state.slow_ratio if state.control_state == PlayerState.ControlState.SLOWED else 1000
		var next_ratio := clampi(slow_ratio, MovementTuning.SLOW_MINIMUM_RATIO, MovementTuning.SLOW_MAXIMUM_RATIO)
		# Applying/reapplying a slow changes the scale once, not the stored momentum.
		state.velocity_x = state.velocity_x * next_ratio / previous_ratio
		state.velocity_y = state.velocity_y * next_ratio / previous_ratio
	var normalized := _direction(direction.x, direction.y, Vector2i(state.facing_x, state.facing_y))
	state.control_state = requested_state
	state.control_ticks = config.milliseconds_to_ticks(duration_ms)
	state.control_x = normalized.x
	state.control_y = normalized.y
	state.control_speed = clampi(speed, 0, MovementTuning.MAX_AUTHORED_SPEED)
	state.slow_ratio = clampi(slow_ratio, MovementTuning.SLOW_MINIMUM_RATIO, MovementTuning.SLOW_MAXIMUM_RATIO)
	state.impact_recovery_ticks = 0
	if requested_state == PlayerState.ControlState.LAUNCHED:
		_cancel_authored_movement(state)
	state.last_event = "control_%d" % requested_state
	return true


static func _advance_timers(state: PlayerState, config: SimConfig) -> void:
	var was_air_dodging: bool = state.air_dodge_ticks > 0
	var was_rolling: bool = state.is_rolling()
	var was_wall_skimming: bool = state.wall_skim_ticks > 0
	var was_landing: bool = state.landing_ticks > 0
	var was_impact_recovering: bool = state.impact_recovery_ticks > 0
	var had_movement_chain: bool = state.movement_chain_reset_ticks > 0
	var previous_control_state: int = state.control_state
	for property_name: StringName in [
		&"stamina_recovery_delay_ticks", &"hop_cooldown_ticks",
		&"air_dodge_ticks", &"air_dodge_cooldown_ticks", &"wave_dash_ticks",
		&"slide_ticks", &"slide_cooldown_ticks", &"vault_ticks",
		&"vault_cooldown_ticks", &"superglide_ticks", &"wall_memory_ticks",
		&"wall_skim_ticks", &"wall_skim_cooldown_ticks", &"wall_skim_lockout_ticks",
		&"landing_ticks", &"impact_recovery_ticks", &"wall_lockout_ticks", &"control_ticks",
		&"jump_buffer_ticks", &"technique_buffer_ticks", &"slide_buffer_ticks",
		&"variable_jump_grace_ticks", &"jump_protection_ticks", &"evade_buffer_ticks", &"landing_input_ticks",
		&"movement_chain_reset_ticks", &"movement_commitment_ticks", &"wall_air_ticks",
		&"chemistry_reveal_ticks", &"chemistry_conceal_ticks", &"chemistry_regen_block_ticks",
	]:
		state.set(property_name, maxi(0, int(state.get(property_name)) - 1))
	if was_landing and state.landing_ticks == 0:
		state.landing_intensity = 0
	if was_impact_recovering and state.impact_recovery_ticks == 0:
		state.technique_buffer_ticks = 0
		state.last_event = "impact_recovery_end"
	if had_movement_chain and state.movement_chain_reset_ticks == 0:
		state.movement_chain_count = 0
	if was_air_dodging and state.air_dodge_ticks == 0:
		if was_rolling:
			state.landing_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
			state.landing_intensity = MovementTuning.LANDING_WALL_SKIM_INTENSITY
			state.last_event = "roll_end"
		else:
			state.hop_mode = PlayerState.MovementMode.HOP
			state.last_event = "air_dodge_end"
	if was_wall_skimming and state.wall_skim_ticks == 0:
		_end_wall_run(state, "wall_skim_end", config)
	if previous_control_state == PlayerState.ControlState.LAUNCHED and state.control_ticks == 0:
		_begin_impact_recovery(state, config)
	elif previous_control_state != PlayerState.ControlState.FREE and state.control_ticks == 0:
		state.control_state = PlayerState.ControlState.FREE
		state.control_speed = 0
		state.slow_ratio = 1000
		state.last_event = "control_end"


static func _apply_launch_influence(state: PlayerState, command: SimCommand, direction: Vector2i, config: SimConfig) -> void:
	if command.move_x == 0 and command.move_y == 0:
		return
	var influence_step: int = config.per_tick(MovementTuning.IMPACT_INFLUENCE_PER_SECOND)
	var influenced := _normalized_fixed(
		_approach(state.control_x, direction.x, influence_step),
		_approach(state.control_y, direction.y, influence_step),
		Vector2i(state.control_x, state.control_y),
	)
	state.control_x = influenced.x
	state.control_y = influenced.y


static func _begin_impact_recovery(state: PlayerState, config: SimConfig) -> void:
	state.control_state = PlayerState.ControlState.FREE
	state.control_ticks = 0
	state.control_speed = 0
	state.slow_ratio = 1000
	state.impact_recovery_ticks = config.milliseconds_to_ticks(MovementTuning.IMPACT_RECOVERY_DURATION_MS)
	@warning_ignore("integer_division")
	state.velocity_x = state.velocity_x * MovementTuning.IMPACT_RECOVERY_SPEED_RETENTION / 1000
	@warning_ignore("integer_division")
	state.velocity_y = state.velocity_y * MovementTuning.IMPACT_RECOVERY_SPEED_RETENTION / 1000
	state.landing_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
	state.landing_intensity = MovementTuning.IMPACT_RECOVERY_INTENSITY
	state.sprinting = false
	state.last_event = "impact_recovery"


static func _try_impact_recovery_tech(state: PlayerState, direction: Vector2i, config: SimConfig) -> bool:
	var cost := _movement_action_cost(state, MovementTuning.IMPACT_RECOVERY_TECH_COST)
	if state.technique_buffer_ticks <= 0 or state.stamina < cost:
		return false
	_spend_movement_action(state, cost, config)
	state.impact_recovery_ticks = 0
	state.technique_buffer_ticks = 0
	state.movement_action_speed = _retained_speed(state, MovementTuning.IMPACT_RECOVERY_TECH_SPEED)
	_set_directional_velocity(state, direction, state.movement_action_speed)
	_clear_landing_cue(state)
	state.last_event = "impact_tech"
	return true


static func _apply_impact_recovery_velocity(state: PlayerState, config: SimConfig) -> void:
	var braking: int = config.per_tick(MovementTuning.IMPACT_RECOVERY_DECELERATION)
	state.velocity_x = _approach(state.velocity_x, 0, braking)
	state.velocity_y = _approach(state.velocity_y, 0, braking)
	state.sprinting = false


static func _cancel_authored_movement(state: PlayerState) -> void:
	var retain_air_budget := state.is_airborne()
	state.air_floating = false
	state.float_ticks = 0
	_clear_action_buffers(state)
	state.movement_commitment_ticks = 0
	state.wall_air_ticks = 0
	state.air_velocity_x = 0
	state.air_velocity_y = 0
	state.fast_fall_armed = false
	state.hop_ticks = 0
	if not retain_air_budget:
		state.hop_stage = 0
	state.hop_mode = PlayerState.MovementMode.HOP
	state.air_redirects_remaining = 0
	state.fast_falling = false
	state.jump_sustain_ticks = 0
	state.air_dodge_ticks = 0
	state.wave_dash_queued = false
	state.wave_dash_ticks = 0
	state.slide_ticks = 0
	state.vault_ticks = 0
	state.superglide_ticks = 0
	state.wall_skim_ticks = 0
	state.wall_skim_surface_id = 0
	state.movement_action_speed = 0
	_clear_landing_cue(state)


static func _try_hop(state: PlayerState, direction: Vector2i, config: SimConfig) -> bool:
	var cost := _movement_action_cost(state, MovementTuning.HOP_COST)
	if state.hop_cooldown_ticks > 0 or state.stamina < cost:
		return false
	var wall_kick: bool = state.wall_memory_ticks > 0
	if wall_kick:
		direction = _wall_kick_direction(direction, Vector2i(state.wall_x, state.wall_y))
	var entry_speed := _planar_speed(state)
	_spend_movement_action(state, cost, config)
	state.hop_ticks = config.milliseconds_to_ticks(MovementTuning.HOP_DURATION_MS)
	state.air_vertical_velocity = MovementTuning.JUMP_VERTICAL_SPEED
	state.air_floating = false
	state.float_ticks = 0
	state.air_dodge_ticks = 0
	state.wave_dash_ticks = 0
	state.wave_dash_queued = false
	state.wall_air_ticks = 0
	state.fast_fall_armed = false
	state.jump_protection_ticks = config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS)
	state.wall_skim_ticks = 0
	state.wall_skim_surface_id = 0
	state.variable_jump_grace_ticks = 1
	state.jump_sustain_ticks = 0
	state.hop_cooldown_ticks = config.milliseconds_to_ticks(MovementTuning.HOP_COOLDOWN_MS)
	state.hop_stage = 1
	state.hop_mode = PlayerState.MovementMode.WALL_KICK if wall_kick else PlayerState.MovementMode.HOP
	state.hop_speed = mini(MovementTuning.MAX_AUTHORED_SPEED, maxi(entry_speed, MovementTuning.WALL_KICK_SPEED)) if wall_kick else entry_speed
	var launch_speed := state.hop_speed
	state.hop_x = direction.x
	state.hop_y = direction.y
	state.air_redirects_remaining = 1
	_capture_air_velocity(state)
	if wall_kick:
		state.hop_speed = launch_speed
		_set_air_velocity(state, direction, launch_speed)
	_clear_landing_cue(state)
	state.wall_memory_ticks = 0
	if wall_kick:
		state.wall_lockout_id = state.wall_contact_id
		state.wall_lockout_ticks = config.milliseconds_to_ticks(MovementTuning.SAME_WALL_LOCKOUT_MS)
	state.wall_contact_id = 0
	state.sprinting = false
	state.last_event = "wall_kick" if wall_kick else "hop"
	return true


static func _try_air_float(state: PlayerState, command: SimCommand, direction: Vector2i, config: SimConfig) -> bool:
	var cost := _movement_action_cost(state, MovementTuning.FLOAT_COST)
	if state.float_used or state.air_height <= 0 or state.stamina <= cost + config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND):
		return false
	if not command.has_held(SimCommand.HELD_JUMP) and not command.has_pressed(SimCommand.PRESSED_JUMP):
		return false
	_spend_movement_action(state, cost, config)
	state.float_used = true
	state.float_ticks = config.milliseconds_to_ticks(clampi(state.float_max_duration_ms, MovementTuning.FLOAT_LARGE_DURATION_MS, MovementTuning.FLOAT_SMALL_DURATION_MS))
	state.air_floating = true
	state.wall_skim_ticks = 0
	state.wall_skim_surface_id = 0
	state.wall_air_ticks = 0
	state.air_vertical_velocity = 0
	state.air_height_remainder = 0
	# Stable enum value remains a compatibility adapter; this is Float, not lift.
	state.hop_mode = PlayerState.MovementMode.DOUBLE_JUMP
	state.air_dodge_ticks = 0
	state.wave_dash_queued = false
	state.fast_fall_armed = false
	state.hop_ticks = _remaining_air_ticks(state, config)
	state.jump_protection_ticks = 0
	state.variable_jump_grace_ticks = 1
	state.jump_sustain_ticks = 0
	state.hop_x = direction.x
	state.hop_y = direction.y
	state.last_event = "air_float"
	_capture_air_velocity(state)
	return true


static func _apply_air_float(state: PlayerState, command: SimCommand, config: SimConfig) -> void:
	state.float_ticks = maxi(0, state.float_ticks - 1)
	if state.float_ticks == 0:
		_end_air_float(state, "float_expired")
		return
	if not command.has_held(SimCommand.HELD_JUMP) and not (state.variable_jump_grace_ticks > 0 and command.has_pressed(SimCommand.PRESSED_JUMP)):
		_end_air_float(state, "float_release")
		return
	var total := state.stamina_remainder - MovementTuning.FLOAT_DRAIN_PER_SECOND
	var required: int = -(total / config.tick_rate)
	if state.stamina < required:
		_end_air_float(state, "float_empty")
		return
	_apply_stamina_rate(state, -MovementTuning.FLOAT_DRAIN_PER_SECOND, config)
	state.stamina_recovery_delay_ticks = config.milliseconds_to_ticks(MovementTuning.STAMINA_RECOVERY_DELAY_MS)
	if state.stamina == 0:
		_end_air_float(state, "float_empty")
		return
	state.air_vertical_velocity = 0
	state.air_height_remainder = 0
	# Ordinary rise age has a compact snapshot field; Float has no arc age.
	state.jump_sustain_ticks = 0


static func _end_air_float(state: PlayerState, event_name: String) -> void:
	state.air_floating = false
	state.float_ticks = 0
	state.air_vertical_velocity = mini(0, state.air_vertical_velocity)
	state.hop_mode = PlayerState.MovementMode.HOP
	state.jump_protection_ticks = 0
	state.variable_jump_grace_ticks = 0
	state.last_event = event_name


static func _try_air_redirect(state: PlayerState, direction: Vector2i, config: SimConfig) -> bool:
	var cost := _movement_action_cost(state, MovementTuning.AIR_REDIRECT_COST)
	if state.hop_ticks <= 0 or state.air_redirects_remaining <= 0 or state.stamina < cost:
		return false
	var current := _normalized_fixed(state.air_velocity_x, state.air_velocity_y, Vector2i(state.hop_x, state.hop_y))
	if _integer_sqrt(_speed_squared(state.air_velocity_x, state.air_velocity_y)) == 0 or current.x * direction.x + current.y * direction.y >= MovementTuning.AIR_REDIRECT_MINIMUM_TURN_DOT:
		state.technique_buffer_ticks = 0
		return false
	_spend_movement_action(state, cost, config)
	state.hop_x = _blend_axis(current.x, direction.x, MovementTuning.AIR_REDIRECT_BLEND)
	state.hop_y = _blend_axis(current.y, direction.y, MovementTuning.AIR_REDIRECT_BLEND)
	var redirected: Vector2i = _direction(state.hop_x, state.hop_y, direction)
	state.hop_x = redirected.x
	state.hop_y = redirected.y
	# Explicit aerial turn stays a paid, immediate redirect; ordinary steering
	# below remains input-driven and adds no jump launch impulse.
	state.hop_speed = mini(MovementTuning.MAX_AUTHORED_SPEED, _integer_sqrt(_speed_squared(state.air_velocity_x, state.air_velocity_y)))
	_set_air_velocity(state, redirected, state.hop_speed)
	state.air_redirects_remaining = 0
	state.last_event = "air_redirect"
	return true


static func _try_air_dodge(state: PlayerState, direction: Vector2i, config: SimConfig) -> bool:
	var cost := _movement_action_cost(state, MovementTuning.AIR_DODGE_COST)
	if not state.is_airborne() or state.air_dodge_used or state.stamina < cost:
		return false
	state.wave_dash_queued = (
		state.air_vertical_velocity <= 0 and state.hop_ticks > 0 and state.hop_ticks <= config.milliseconds_to_ticks(MovementTuning.WAVE_DASH_INPUT_WINDOW_MS)
	)
	state.movement_action_speed = _retained_speed(state, MovementTuning.AIR_DODGE_SPEED)
	_spend_movement_action(state, cost, config)
	state.air_floating = false
	state.air_dodge_used = true
	state.float_ticks = 0
	state.jump_sustain_ticks = 0
	state.hop_mode = PlayerState.MovementMode.AIR_DODGE
	state.jump_protection_ticks = 0
	state.wall_air_ticks = 0
	state.fast_fall_armed = false
	state.movement_commitment_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_COMMITMENT_MS)
	state.wall_skim_ticks = 0
	state.wall_skim_surface_id = 0
	state.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
	state.air_dodge_cooldown_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_COOLDOWN_MS)
	state.air_dodge_x = direction.x
	state.air_dodge_y = direction.y
	_clear_landing_cue(state)
	state.last_event = "air_dodge"
	return true


static func _try_roll(state: PlayerState, direction: Vector2i, config: SimConfig) -> bool:
	var cost := _movement_action_cost(state, MovementTuning.ROLL_COST)
	if (
		state.air_dodge_cooldown_ticks > 0 or state.air_dodge_ticks > 0
		or state.vault_ticks > 0 or state.superglide_ticks > 0
		or state.stamina < cost
	):
		return false
	state.movement_action_speed = _retained_speed(state, MovementTuning.ROLL_SPEED)
	_spend_movement_action(state, cost, config)
	state.wall_skim_ticks = 0
	state.wall_skim_surface_id = 0
	state.hop_mode = PlayerState.MovementMode.ROLL
	state.slide_ticks = 0
	state.wave_dash_ticks = 0
	state.movement_commitment_ticks = config.milliseconds_to_ticks(MovementTuning.ROLL_COMMITMENT_MS)
	state.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.ROLL_DURATION_MS)
	state.air_dodge_cooldown_ticks = config.milliseconds_to_ticks(MovementTuning.ROLL_COOLDOWN_MS)
	state.air_dodge_x = direction.x
	state.air_dodge_y = direction.y
	state.wave_dash_queued = false
	state.sprinting = false
	_clear_landing_cue(state)
	state.last_event = "roll"
	return true


static func is_combat_intangible(state: PlayerState, config: SimConfig) -> bool:
	if state == null or config == null:
		return false
	if state.air_floating:
		return state.air_height > 0 and state.stamina > 0 and state.float_ticks > 0
	if state.hop_ticks > 0 and state.air_dodge_ticks <= 0:
		return state.jump_protection_ticks > 0
	if state.slide_ticks > 0:
		# Slide duration can now be released or exhausted early. Cooldown age is
		# the authoritative accepted-action clock, so sustain can never refresh
		# or accidentally erase the separately purchased opening protection.
		return _timer_is_in_opening_window(state.slide_cooldown_ticks,
			config.milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS),
			config.milliseconds_to_ticks(MovementTuning.SLIDE_INVULNERABILITY_MS))
	if state.air_dodge_ticks > 0:
		var action_duration_ms := MovementTuning.ROLL_DURATION_MS if state.is_rolling() else MovementTuning.AIR_DODGE_DURATION_MS
		var invulnerability_ms := MovementTuning.ROLL_INVULNERABILITY_MS if state.is_rolling() else MovementTuning.AIR_DODGE_INVULNERABILITY_MS
		return _timer_is_in_opening_window(
			state.air_dodge_ticks,
			config.milliseconds_to_ticks(action_duration_ms),
			config.milliseconds_to_ticks(invulnerability_ms),
		)
	return false


static func _timer_is_in_opening_window(remaining_ticks: int, total_ticks: int, window_ticks: int) -> bool:
	return remaining_ticks > 0 and total_ticks > 0 and total_ticks - remaining_ticks < window_ticks


static func _try_slide(state: PlayerState, direction: Vector2i, config: SimConfig) -> bool:
	var cost := _movement_action_cost(state, MovementTuning.SLIDE_COST)
	if (
		state.slide_cooldown_ticks > 0 or state.slide_ticks > 0 or state.is_airborne()
		or (state.air_dodge_ticks > 0 and not state.is_rolling())
		or state.vault_ticks > 0 or state.superglide_ticks > 0
		or state.stamina < cost
		or _retained_speed(state, 0) < MovementTuning.SLIDE_ENTRY_SPEED
	):
		return false
	state.movement_action_speed = _retained_speed(state, 0)
	_spend_movement_action(state, cost, config)
	state.air_dodge_ticks = 0
	state.wave_dash_ticks = 0
	state.wave_dash_queued = false
	state.movement_commitment_ticks = config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_MINIMUM_COMMITMENT_MS)
	state.slide_ticks = config.milliseconds_to_ticks(MovementTuning.SLIDE_DURATION_MS)
	state.slide_cooldown_ticks = config.milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS)
	state.slide_x = direction.x
	state.slide_y = direction.y
	state.sprinting = false
	state.last_event = "slide"
	return true


static func _try_slide_jump(state: PlayerState, direction: Vector2i, config: SimConfig) -> bool:
	var cost := _movement_action_cost(state, MovementTuning.SLIDE_JUMP_COST)
	# Cooldown age is the accepted-action clock. Remaining slide time can be
	# shortened by release/exhaustion and must not delay a held-slide conversion.
	var slide_age := config.milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS) - state.slide_cooldown_ticks
	if slide_age < config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_MINIMUM_COMMITMENT_MS) or state.stamina < cost:
		return false
	var entry_speed := _planar_speed(state)
	_spend_movement_action(state, cost, config)
	state.slide_ticks = 0
	state.hop_ticks = config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_DURATION_MS)
	state.air_vertical_velocity = MovementTuning.JUMP_VERTICAL_SPEED
	state.jump_protection_ticks = config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS)
	state.variable_jump_grace_ticks = 1
	state.jump_sustain_ticks = 0
	state.hop_stage = 1
	state.hop_mode = PlayerState.MovementMode.SLIDE_JUMP
	state.hop_speed = entry_speed
	state.hop_x = direction.x
	state.hop_y = direction.y
	state.air_redirects_remaining = 1
	_clear_landing_cue(state)
	state.last_event = "slide_jump"
	state.fast_fall_armed = false
	_capture_air_velocity(state)
	return true


# Vault/superglide wire IDs and state slots remain reserved; no action activates them.
static func _try_wall_skim(state: PlayerState, direction: Vector2i, config: SimConfig) -> bool:
	var cost := _movement_action_cost(state, MovementTuning.WALL_SKIM_COST)
	if (
		state.wall_memory_ticks <= 0 or state.wall_contact_id <= 0
		or state.air_dodge_ticks > 0
		or state.wall_skim_ticks > 0 or state.wall_skim_cooldown_ticks > 0
		or (state.wall_skim_lockout_id == state.wall_contact_id and state.wall_skim_lockout_ticks > 0)
		or state.slide_ticks > 0 or state.wave_dash_ticks > 0 or state.vault_ticks > 0
		or state.stamina < cost
	):
		return false
	var wall_normal := Vector2i(state.wall_x, state.wall_y)
	if wall_normal == Vector2i.ZERO:
		return false
	var dot: int = direction.x * wall_normal.x + direction.y * wall_normal.y
	var tangent := HexConvexGeometry.tangent(direction, wall_normal)
	var clockwise := Vector2i(-wall_normal.y, wall_normal.x)
	if dot > 0 or tangent == Vector2i.ZERO:
		return false
	tangent = _direction(tangent.x, tangent.y, clockwise)
	state.movement_action_speed = _retained_speed(state, MovementTuning.WALL_SKIM_SPEED)
	_spend_movement_action(state, cost, config)
	state.air_floating = false
	state.float_ticks = 0
	state.wall_air_ticks = state.hop_ticks
	state.air_vertical_velocity = 0
	state.hop_stage = maxi(1, state.hop_stage)
	state.hop_mode = PlayerState.MovementMode.WALL_SKIM
	state.fast_fall_armed = false
	state.movement_commitment_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_RUN_COMMITMENT_MS)
	state.jump_sustain_ticks = 0
	state.jump_protection_ticks = 0
	state.wall_skim_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS)
	state.wall_skim_cooldown_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_COOLDOWN_MS)
	state.wall_skim_x = tangent.x
	state.wall_skim_y = tangent.y
	state.wall_skim_surface_id = state.wall_contact_id
	state.wall_skim_lockout_id = state.wall_contact_id
	state.wall_skim_lockout_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_SAME_SURFACE_LOCKOUT_MS)
	state.wall_memory_ticks = 0
	state.wall_contact_id = 0
	_clear_landing_cue(state)
	state.sprinting = false
	state.last_event = "wall_skim"
	return true


static func _apply_velocity(state: PlayerState, command: SimCommand, direction: Vector2i, config: SimConfig, ground_target_ratio: int = 1000, acceleration_ratio: int = 1000, braking_ratio: int = 1000) -> void:
	if state.superglide_ticks > 0:
		_set_directional_velocity(state, Vector2i(state.superglide_x, state.superglide_y), MovementTuning.SUPERGLIDE_SPEED)
	elif state.air_dodge_ticks > 0:
		if state.is_rolling():
			_set_directional_velocity(state, Vector2i(state.air_dodge_x, state.air_dodge_y), maxi(state.movement_action_speed, MovementTuning.ROLL_SPEED))
		else:
			if state.air_dodge_ticks < config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS):
				state.movement_action_speed = maxi(0, state.movement_action_speed - config.per_tick(MovementTuning.AIR_DODGE_DRAG_PER_SECOND))
			_set_air_velocity(state, Vector2i(state.air_dodge_x, state.air_dodge_y), state.movement_action_speed)
			if state.movement_commitment_ticks == 0:
				_apply_air_velocity(state, command, direction, config)
				var carved := _normalized_fixed(state.air_velocity_x, state.air_velocity_y, direction)
				state.air_dodge_x = carved.x
				state.air_dodge_y = carved.y
				return
			_set_directional_velocity(state, Vector2i(state.air_dodge_x, state.air_dodge_y), state.movement_action_speed)
	elif state.wave_dash_ticks > 0:
		var steered := _steer(Vector2i(state.wave_dash_x, state.wave_dash_y), direction, command, MovementTuning.WAVE_DASH_STEERING)
		state.wave_dash_x = steered.x
		state.wave_dash_y = steered.y
		_set_directional_velocity(state, steered, state.movement_action_speed)
	elif state.vault_ticks > 0:
		state.velocity_x = 0
		state.velocity_y = 0
	elif state.slide_ticks > 0:
		state.movement_action_speed = maxi(0, state.movement_action_speed - config.per_tick(MovementTuning.SLIDE_DRAG_PER_SECOND))
		var slide_direction := _steer(Vector2i(state.slide_x, state.slide_y), direction, command, MovementTuning.SLIDE_STEERING)
		state.slide_x = slide_direction.x
		state.slide_y = slide_direction.y
		_set_directional_velocity(state, slide_direction, state.movement_action_speed)
	elif state.hop_ticks > 0 and state.wall_skim_ticks <= 0:
		_apply_air_velocity(state, command, direction, config)
		return
	elif state.wall_skim_ticks > 0:
		_set_directional_velocity(state, Vector2i(state.wall_skim_x, state.wall_skim_y), maxi(state.movement_action_speed, MovementTuning.WALL_SKIM_SPEED))
	else:
		# Read material only in ordinary grounded movement, after this tick's
		# jump/slide/roll admission. Air and authored actions retain their normal
		# travel. This changes the target, never repeatedly damps momentum.
		_apply_ground_velocity(state, command, direction, config, true, 0, false, ground_target_ratio if not state.is_airborne() and state.air_height <= 0 else 1000)
		return
	# Authored actions recreate velocity from their bounded impulse each tick,
	# so they receive the ratio once. Input-driven movement applies it to its
	# target/acceleration instead of repeatedly damping accumulated velocity.
	if state.control_state == PlayerState.ControlState.SLOWED:
		@warning_ignore("integer_division")
		state.velocity_x = state.velocity_x * state.slow_ratio / 1000
		@warning_ignore("integer_division")
		state.velocity_y = state.velocity_y * state.slow_ratio / 1000


static func _apply_control_velocity(state: PlayerState, config: SimConfig) -> void:
	state.sprinting = false
	match state.control_state:
		PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.GRAPPLED, PlayerState.ControlState.CHARGING:
			_set_directional_velocity(state, Vector2i(state.control_x, state.control_y), state.control_speed)
		PlayerState.ControlState.STUNNED:
			var braking: int = config.per_tick(MovementTuning.DECELERATION)
			state.velocity_x = _approach(state.velocity_x, 0, braking)
			state.velocity_y = _approach(state.velocity_y, 0, braking)
		PlayerState.ControlState.ROOTED:
			state.velocity_x = 0
			state.velocity_y = 0
	if state.hop_ticks > 0:
		state.air_velocity_x = state.velocity_x
		state.air_velocity_y = state.velocity_y


static func _capture_air_velocity(state: PlayerState) -> void:
	var ratio := state.slow_ratio if state.control_state == PlayerState.ControlState.SLOWED else 1000
	state.air_velocity_x = clampi(state.velocity_x * 1000 / ratio, -MovementTuning.MAX_AUTHORED_SPEED, MovementTuning.MAX_AUTHORED_SPEED)
	state.air_velocity_y = clampi(state.velocity_y * 1000 / ratio, -MovementTuning.MAX_AUTHORED_SPEED, MovementTuning.MAX_AUTHORED_SPEED)
	state.hop_speed = mini(MovementTuning.MAX_AUTHORED_SPEED, _integer_sqrt(_speed_squared(state.air_velocity_x, state.air_velocity_y)))


static func _set_air_velocity(state: PlayerState, direction: Vector2i, speed: int) -> void:
	state.air_velocity_x = direction.x * speed / 1000
	state.air_velocity_y = direction.y * speed / 1000


static func _apply_air_velocity(state: PlayerState, command: SimCommand, direction: Vector2i, config: SimConfig) -> void:
	# Every lift family uses one accumulated unslowed vector. Neutral coasts;
	# opposition brakes before reversing. Slows scale output exactly once.
	if command.move_x != 0 or command.move_y != 0:
		var speed := maxi(MovementTuning.BASE_SPEED * state.movement_speed_ratio / 1000, state.hop_speed)
		speed = speed * _input_magnitude(command.move_x, command.move_y) / 1000
		var current := Vector2i(state.air_velocity_x, state.air_velocity_y)
		var rate := MovementTuning.ACCELERATION
		if current.x * direction.x + current.y * direction.y < MovementTuning.COUNTER_STRAFE_DOT_THRESHOLD:
			rate = rate * MovementTuning.COUNTER_STRAFE_MULTIPLIER / 1000
		var next := _approach_vector(current, Vector2i(direction.x * speed / 1000, direction.y * speed / 1000), config.per_tick(rate))
		state.air_velocity_x = next.x
		state.air_velocity_y = next.y
		state.hop_x = direction.x
		state.hop_y = direction.y
		state.hop_speed = maxi(state.hop_speed, _integer_sqrt(_speed_squared(next.x, next.y)))
	var ratio := state.slow_ratio if state.control_state == PlayerState.ControlState.SLOWED else 1000
	state.velocity_x = state.air_velocity_x * ratio / 1000
	state.velocity_y = state.air_velocity_y * ratio / 1000
	state.sprinting = false


static func _apply_ground_velocity(state: PlayerState, command: SimCommand, direction: Vector2i, config: SimConfig, allow_recovery: bool = true, minimum_speed: int = 0, preserve_idle: bool = false, ground_target_ratio: int = 1000) -> void:
	var moving: bool = command.move_x != 0 or command.move_y != 0
	if not moving and preserve_idle:
		state.sprinting = false
		return
	var sprinting: bool = moving and command.has_held(SimCommand.HELD_SPRINT) and state.stamina > 0
	@warning_ignore("integer_division")
	var speed: int = MovementTuning.BASE_SPEED * state.movement_speed_ratio / 1000
	@warning_ignore("integer_division")
	speed = speed * _input_magnitude(command.move_x, command.move_y) / 1000
	if sprinting:
		@warning_ignore("integer_division")
		speed = speed * MovementTuning.SPRINT_MULTIPLIER / 1000
	if moving:
		speed = maxi(speed, minimum_speed)
	var slow_ratio := state.slow_ratio if state.control_state == PlayerState.ControlState.SLOWED else 1000
	@warning_ignore("integer_division")
	speed = speed * slow_ratio / 1000
	# Independent hostile slows keep their existing semantics. Lane overlap
	# contributes one bounded target ratio and does not overwrite that status.
	speed = mini(MovementTuning.MAX_AUTHORED_SPEED, speed * clampi(ground_target_ratio, 1, 1250) / 1000)
	var desired_x: int = direction.x * speed / 1000 if moving else 0
	var desired_y: int = direction.y * speed / 1000 if moving else 0
	var opposing: bool = (
		moving
		and state.velocity_x * direction.x + state.velocity_y * direction.y
		< MovementTuning.COUNTER_STRAFE_DOT_THRESHOLD
	)
	var rate: int = MovementTuning.ACCELERATION if moving else MovementTuning.DECELERATION
	if moving:
		@warning_ignore("integer_division")
		rate = rate * slow_ratio / 1000
	# Reserved chemistry seam remains exactly neutral; no per-frame allocation.
	var surface_ratio := SurfaceMotionPolicy.acceleration_ratio() if moving else SurfaceMotionPolicy.braking_ratio()
	surface_ratio = surface_ratio * clampi(acceleration_ratio if moving else braking_ratio, 1, 1000) / 1000
	rate = rate * surface_ratio / SurfaceMotionPolicy.NEUTRAL_RATIO
	if opposing:
		@warning_ignore("integer_division")
		rate = rate * MovementTuning.COUNTER_STRAFE_MULTIPLIER / 1000
		if state.landing_ticks > 0:
			@warning_ignore("integer_division")
			rate = rate * MovementTuning.LANDING_CUT_MULTIPLIER / 1000
			state.landing_ticks = 0
			state.landing_intensity = 0
			state.last_event = "landing_cut"
	var step_amount: int = config.per_tick(rate)
	var approached := _approach_vector(
		Vector2i(state.velocity_x, state.velocity_y),
		Vector2i(desired_x, desired_y),
		step_amount,
	)
	state.velocity_x = approached.x
	state.velocity_y = approached.y
	state.sprinting = sprinting
	if sprinting:
		_apply_stamina_rate(state, -MovementTuning.SPRINT_DRAIN_PER_SECOND, config)
		state.stamina_recovery_delay_ticks = config.milliseconds_to_ticks(MovementTuning.STAMINA_RECOVERY_DELAY_MS)
	elif allow_recovery and state.stamina_recovery_delay_ticks == 0:
		_apply_stamina_rate(state, ResourceRecoveryScript.rate_per_second(state.stamina_recovery_per_second, state.stamina_recovery_idle_ticks, config.tick_rate), config)


static func _integrate(state: PlayerState, config: SimConfig, world: CollisionWorld) -> void:
	var was_launched: bool = state.control_state == PlayerState.ControlState.LAUNCHED
	var total_x: int = state.position_remainder_x + state.velocity_x
	var total_y: int = state.position_remainder_y + state.velocity_y
	@warning_ignore("integer_division")
	var delta := Vector2i(total_x / config.tick_rate, total_y / config.tick_rate)
	state.position_remainder_x = total_x - delta.x * config.tick_rate
	state.position_remainder_y = total_y - delta.y * config.tick_rate
	var result: CollisionWorld.MoveResult = world.move_box(Vector2i(state.position_x, state.position_y), delta, MovementTuning.PLAYER_RADIUS)
	state.position_x = result.position.x
	state.position_y = result.position.y
	if result.wall_normal != Vector2i.ZERO:
		if result.wall_id != state.wall_lockout_id or state.wall_lockout_ticks == 0:
			state.wall_memory_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)
			state.wall_x = result.wall_normal.x
			state.wall_y = result.wall_normal.y
			state.wall_contact_id = result.wall_id
		# Project onto the actual face. Axis-aligned worldbone retains its exact
		# previous result; a slanted hex face keeps useful tangent velocity.
		var normals := result.blocking_normals
		if normals.is_empty():
			state.position_remainder_x = 0 if result.wall_normal.x != 0 else state.position_remainder_x
			state.position_remainder_y = 0 if result.wall_normal.y != 0 else state.position_remainder_y
			if result.wall_normal.x != 0:
				state.velocity_x = 0
				state.air_velocity_x = 0
			if result.wall_normal.y != 0:
				state.velocity_y = 0
				state.air_velocity_y = 0
		else:
			var remainder := HexConvexGeometry.clip_motion(Vector2i(state.position_remainder_x, state.position_remainder_y), normals)
			var velocity := HexConvexGeometry.clip_motion(Vector2i(state.velocity_x, state.velocity_y), normals)
			var air_velocity := HexConvexGeometry.clip_motion(Vector2i(state.air_velocity_x, state.air_velocity_y), normals)
			state.position_remainder_x = remainder.x
			state.position_remainder_y = remainder.y
			state.velocity_x = velocity.x
			state.velocity_y = velocity.y
			state.air_velocity_x = air_velocity.x
			state.air_velocity_y = air_velocity.y
		if state.air_dodge_ticks > 0 or state.wave_dash_ticks > 0 or state.slide_ticks > 0 or state.superglide_ticks > 0:
			state.air_dodge_ticks = 0
			state.wave_dash_ticks = 0
			state.wave_dash_queued = false
			state.slide_ticks = 0
			state.superglide_ticks = 0
			state.last_event = "movement_impact"
		if was_launched:
			_begin_impact_recovery(state, config)
			state.last_event = "launch_impact"


static func _update_mode(state: PlayerState, command: SimCommand) -> void:
	if state.control_state != PlayerState.ControlState.FREE:
		state.movement_mode = PlayerState.MovementMode.LAUNCHED + state.control_state - PlayerState.ControlState.LAUNCHED
	elif state.impact_recovery_ticks > 0:
		state.movement_mode = PlayerState.MovementMode.IMPACT_RECOVERY
	elif state.superglide_ticks > 0:
		state.movement_mode = PlayerState.MovementMode.SUPERGLIDE
	elif state.air_dodge_ticks > 0:
		state.movement_mode = PlayerState.MovementMode.ROLL if state.is_rolling() else PlayerState.MovementMode.AIR_DODGE
	elif state.wave_dash_ticks > 0:
		state.movement_mode = PlayerState.MovementMode.WAVE_DASH
	elif state.vault_ticks > 0:
		state.movement_mode = PlayerState.MovementMode.VAULT
	elif state.slide_ticks > 0:
		state.movement_mode = PlayerState.MovementMode.SLIDE
	elif state.hop_ticks > 0 and state.wall_skim_ticks <= 0:
		state.movement_mode = PlayerState.MovementMode.FAST_FALL if state.fast_falling else state.hop_mode
	elif state.wall_skim_ticks > 0:
		state.movement_mode = PlayerState.MovementMode.WALL_SKIM
	elif state.sprinting:
		state.movement_mode = PlayerState.MovementMode.SPRINT
	elif (
		command.move_x != 0 or command.move_y != 0
		or _speed_squared(state.velocity_x, state.velocity_y)
		>= MovementTuning.MOVING_MODE_MINIMUM_SPEED * MovementTuning.MOVING_MODE_MINIMUM_SPEED
	):
		state.movement_mode = PlayerState.MovementMode.WALK
	else:
		state.movement_mode = PlayerState.MovementMode.IDLE


static func _spend_stamina(state: PlayerState, amount: int, config: SimConfig) -> void:
	if amount > 0:
		state.stamina_recovery_idle_ticks = 0
	state.stamina = maxi(0, state.stamina - amount)
	state.stamina_remainder = 0
	state.stamina_recovery_delay_ticks = config.milliseconds_to_ticks(MovementTuning.STAMINA_RECOVERY_DELAY_MS)


static func _movement_action_cost(state: PlayerState, base_cost: int) -> int:
	var continuation_steps := mini(state.movement_chain_count, MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS) if state.movement_chain_reset_ticks > 0 else 0
	var ratio := 1000 + continuation_steps * MovementTuning.MOVEMENT_CHAIN_COST_STEP_RATIO
	@warning_ignore("integer_division")
	return base_cost * ratio / 1000


static func _spend_movement_action(state: PlayerState, adjusted_cost: int, config: SimConfig) -> void:
	_spend_stamina(state, adjusted_cost, config)
	_clear_action_buffers(state)
	state.movement_commitment_ticks = config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS)
	if state.movement_chain_reset_ticks <= 0:
		state.movement_chain_count = 0
	state.movement_chain_count = mini(
		MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS,
		state.movement_chain_count + 1,
	)
	state.movement_chain_reset_ticks = config.milliseconds_to_ticks(MovementTuning.MOVEMENT_CHAIN_RESET_MS)


static func _clear_landing_cue(state: PlayerState) -> void:
	state.landing_ticks = 0
	state.landing_intensity = 0


static func _hop_landing_intensity(hop_mode: int, fast_falling: bool) -> int:
	var intensity: int = MovementTuning.LANDING_HOP_INTENSITY
	match hop_mode:
		PlayerState.MovementMode.DOUBLE_JUMP:
			intensity = MovementTuning.LANDING_DOUBLE_JUMP_INTENSITY
		PlayerState.MovementMode.SLIDE_JUMP:
			intensity = MovementTuning.LANDING_SLIDE_JUMP_INTENSITY
		PlayerState.MovementMode.WALL_KICK:
			intensity = MovementTuning.LANDING_WALL_KICK_INTENSITY
	if fast_falling:
		intensity += MovementTuning.LANDING_FAST_FALL_BONUS
	return mini(1000, intensity)


static func _apply_stamina_rate(state: PlayerState, rate_per_second: int, config: SimConfig) -> void:
	if rate_per_second > 0 and state.chemistry_regen_block_ticks > 0:
		return
	if rate_per_second < 0:
		state.stamina_recovery_idle_ticks = 0
	var total: int = state.stamina_remainder + rate_per_second
	@warning_ignore("integer_division")
	var amount: int = total / config.tick_rate
	state.stamina_remainder = total - amount * config.tick_rate
	state.stamina = clampi(state.stamina + amount, 0, state.stamina_maximum)


static func _direction(input_x: int, input_y: int, fallback: Vector2i) -> Vector2i:
	return _normalized_fixed(input_x, input_y, fallback)


static func _normalized_fixed(x: int, y: int, fallback: Vector2i) -> Vector2i:
	if x == 0 and y == 0:
		return fallback if fallback != Vector2i.ZERO else Vector2i(1000, 0)
	# Extra integer precision avoids normalizing tiny(1,1) into(1000,1000).
	# All callers are bounded planar/input vectors, so scaled squares fit i64.
	var magnitude := _integer_sqrt((x * x + y * y) * 1_000_000)
	if magnitude <= 0:
		return fallback
	@warning_ignore("integer_division")
	var normalized_x: int = x * 1_000_000 / magnitude
	@warning_ignore("integer_division")
	var normalized_y: int = y * 1_000_000 / magnitude
	# A floored square root can leave a one-unit radial overshoot at(1000,1).
	# Round the dominant component inward, preserving the strict speed ceiling.
	if normalized_x * normalized_x + normalized_y * normalized_y > 1_000_000:
		if absi(normalized_x) >= absi(normalized_y):
			normalized_x -= signi(normalized_x)
		else:
			normalized_y -= signi(normalized_y)
	return Vector2i(clampi(normalized_x, -1000, 1000), clampi(normalized_y, -1000, 1000))


static func _input_magnitude(x: int, y: int) -> int:
	var magnitude := mini(1000, _integer_sqrt(x * x + y * y))
	# The exact fixed-point diagonal is 707/707 (length 999 after integer
	# truncation); treat the final two units as a full digital/controller gate.
	return 1000 if magnitude >= 998 else magnitude


static func _integer_sqrt(value: int) -> int:
	if value <= 0:
		return 0
	var estimate := value
	var candidate := (estimate + 1) / 2
	while candidate < estimate:
		estimate = candidate
		candidate = (estimate + value / estimate) / 2
	return estimate


static func _wall_kick_direction(requested: Vector2i, wall_normal: Vector2i) -> Vector2i:
	var tangent := HexConvexGeometry.tangent(requested, wall_normal)
	return _direction(wall_normal.x + tangent.x * 72 / 100, wall_normal.y + tangent.y * 72 / 100, wall_normal)


static func _steer(current: Vector2i, requested: Vector2i, command: SimCommand, ratio: int) -> Vector2i:
	if command.move_x == 0 and command.move_y == 0:
		return current
	return Vector2i(_blend_axis(current.x, requested.x, ratio), _blend_axis(current.y, requested.y, ratio))


static func _steer_hop(current: Vector2i, requested: Vector2i, command: SimCommand, config: SimConfig) -> Vector2i:
	if command.move_x == 0 and command.move_y == 0 or config == null:
		return current
	@warning_ignore("integer_division")
	var ratio := clampi(MovementTuning.HOP_STEERING_PER_SECOND / config.tick_rate, 1, 1000)
	# Keep the blended magnitude: reversing in air should briefly trade speed
	# for control instead of snapping through a zero-angle discontinuity.
	return Vector2i(
		_blend_axis(current.x, requested.x, ratio),
		_blend_axis(current.y, requested.y, ratio),
	)


static func _blend_axis(current: int, requested: int, ratio: int) -> int:
	@warning_ignore("integer_division")
	return (current * (1000 - ratio) + requested * ratio) / 1000


static func _set_directional_velocity(state: PlayerState, direction: Vector2i, speed: int) -> void:
	@warning_ignore("integer_division")
	state.velocity_x = direction.x * speed / 1000
	@warning_ignore("integer_division")
	state.velocity_y = direction.y * speed / 1000
	state.sprinting = false


static func _approach(current: int, target: int, amount: int) -> int:
	return mini(current + amount, target) if current < target else maxi(current - amount, target)


static func _approach_vector(current: Vector2i, target: Vector2i, amount: int) -> Vector2i:
	var delta := target - current
	var distance := _integer_sqrt(delta.x * delta.x + delta.y * delta.y)
	if distance <= maxi(0, amount):
		return target
	var direction := _normalized_fixed(delta.x, delta.y, Vector2i.ZERO)
	@warning_ignore("integer_division")
	var step_x: int = direction.x * amount / 1000
	@warning_ignore("integer_division")
	var step_y: int = direction.y * amount / 1000
	return current + Vector2i(step_x, step_y)


static func _speed_squared(x: int, y: int) -> int:
	return x * x + y * y


static func _planar_speed(state: PlayerState) -> int:
	return mini(MovementTuning.MAX_AUTHORED_SPEED, _integer_sqrt(_speed_squared(state.velocity_x, state.velocity_y)))


static func _retained_speed(state: PlayerState, minimum_speed: int) -> int:
	var ratio := state.slow_ratio if state.control_state == PlayerState.ControlState.SLOWED else 1000
	return clampi(maxi(_planar_speed(state) * 1000 / ratio, minimum_speed), 0, MovementTuning.MAX_AUTHORED_SPEED)

static func _try_air_wall_kick(state: PlayerState, direction: Vector2i, config: SimConfig) -> bool:
	if state.wall_lockout_id == state.wall_contact_id and state.wall_lockout_ticks > 0:
		return false
	var redirects := state.air_redirects_remaining
	var old_cooldown := state.hop_cooldown_ticks
	state.hop_cooldown_ticks = 0
	if not _try_hop(state, direction, config):
		state.hop_cooldown_ticks = old_cooldown
		return false
	# Wall kicks have a finite lift budget independent from stationary Float.
	state.hop_stage = 2
	state.air_redirects_remaining = redirects
	return true


static func _has_wall_contact(state: PlayerState, world: CollisionWorld, surface_id: int) -> bool:
	if surface_id <= 0:
		return false
	if world is HexCollisionWorld and surface_id >= HexCollisionWorld.FACE_ID_BASE:
		return not world.nearby_hex_face(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS, MovementTuning.WALL_CONTACT_TOLERANCE, surface_id).is_empty()
	for obstacle: CollisionWorld.Obstacle in world.obstacle_view():
		if obstacle.obstacle_id != surface_id or not obstacle.wall_runnable:
			continue
		var tolerance := MovementTuning.PLAYER_RADIUS + MovementTuning.WALL_CONTACT_TOLERANCE
		if state.wall_x != 0 and state.position_y >= obstacle.minimum_y and state.position_y <= obstacle.maximum_y:
			var face := obstacle.minimum_x if state.wall_x < 0 else obstacle.maximum_x
			return absi(state.position_x - face) <= tolerance
		if state.wall_y != 0 and state.position_x >= obstacle.minimum_x and state.position_x <= obstacle.maximum_x:
			var face := obstacle.minimum_y if state.wall_y < 0 else obstacle.maximum_y
			return absi(state.position_y - face) <= tolerance
	return false


static func _refresh_wall_contact(state: PlayerState, world: CollisionWorld, config: SimConfig) -> void:
	# Contact intent can arrive before the first collision tick. Acquire only an
	# actual nearby runnable face; never attach across a corner or a wall gap.
	var best_gap := float(MovementTuning.WALL_CONTACT_TOLERANCE + 1)
	var best_id := 0
	var best_normal := Vector2i.ZERO
	if world is HexCollisionWorld:
		var contact: Dictionary = world.nearby_hex_face(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS, MovementTuning.WALL_CONTACT_TOLERANCE)
		if not contact.is_empty():
			best_gap = float(contact.gap)
			best_id = int(contact.id)
			best_normal = contact.normal
	for obstacle: CollisionWorld.Obstacle in world.obstacle_view():
		if not obstacle.wall_runnable:
			continue
		var normal := Vector2i.ZERO
		var gap := best_gap
		if state.position_y >= obstacle.minimum_y and state.position_y <= obstacle.maximum_y:
			if state.position_x <= obstacle.minimum_x - MovementTuning.PLAYER_RADIUS:
				gap = obstacle.minimum_x - MovementTuning.PLAYER_RADIUS - state.position_x
				normal = Vector2i(-1000, 0)
			elif state.position_x >= obstacle.maximum_x + MovementTuning.PLAYER_RADIUS:
				gap = state.position_x - obstacle.maximum_x - MovementTuning.PLAYER_RADIUS
				normal = Vector2i(1000, 0)
		if state.position_x >= obstacle.minimum_x and state.position_x <= obstacle.maximum_x:
			if state.position_y <= obstacle.minimum_y - MovementTuning.PLAYER_RADIUS:
				gap = obstacle.minimum_y - MovementTuning.PLAYER_RADIUS - state.position_y
				normal = Vector2i(0, -1000)
			elif state.position_y >= obstacle.maximum_y + MovementTuning.PLAYER_RADIUS:
				gap = state.position_y - obstacle.maximum_y - MovementTuning.PLAYER_RADIUS
				normal = Vector2i(0, 1000)
		if normal != Vector2i.ZERO and gap <= MovementTuning.WALL_CONTACT_TOLERANCE and (gap < best_gap or (gap == best_gap and obstacle.obstacle_id < best_id)):
			best_gap = gap
			best_id = obstacle.obstacle_id
			best_normal = normal
	if best_id > 0:
		state.wall_contact_id = best_id
		state.wall_x = best_normal.x
		state.wall_y = best_normal.y
		state.wall_memory_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)


static func _update_wall_attachment(state: PlayerState, command: SimCommand, world: CollisionWorld, config: SimConfig) -> void:
	if state.wall_skim_ticks <= 0:
		return
	var moving_away := command.move_x * state.wall_x + command.move_y * state.wall_y > 0
	if moving_away:
		_end_wall_run(state, "wall_detach", config)
		return
	if not _has_wall_contact(state, world, state.wall_skim_surface_id):
		# The axis collision resolver may supply a new solid face at an inside
		# corner. Transfer the remaining run, never buy a new clock or air budget.
		if state.wall_contact_id != state.wall_skim_surface_id and _has_wall_contact(state, world, state.wall_contact_id):
			state.wall_skim_surface_id = state.wall_contact_id
			state.wall_skim_lockout_id = state.wall_contact_id
		else:
			_end_wall_run(state, "wall_end", config)
			return
	var tangent := HexConvexGeometry.tangent(Vector2i(command.move_x, command.move_y), Vector2i(state.wall_x, state.wall_y))
	if tangent != Vector2i.ZERO:
		tangent = _direction(tangent.x, tangent.y, Vector2i(state.wall_skim_x, state.wall_skim_y))
		state.wall_skim_x = tangent.x
		state.wall_skim_y = tangent.y
	elif state.wall_skim_x * state.wall_x + state.wall_skim_y * state.wall_y != 0:
		# An inside corner can stop tangent travel for one or more input ticks.
		# Stay attached on the existing finite clock until a tangent is chosen.
		state.wall_skim_x = 0
		state.wall_skim_y = 0
	state.wall_contact_id = state.wall_skim_surface_id
	state.wall_memory_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)


static func _end_wall_run(state: PlayerState, event_name: String, config: SimConfig) -> void:
	state.wall_skim_ticks = 0
	state.wall_skim_surface_id = 0
	state.hop_ticks = _remaining_air_ticks(state, config)
	state.hop_stage = maxi(1, state.hop_stage)
	state.hop_mode = PlayerState.MovementMode.HOP
	state.jump_protection_ticks = 0
	state.variable_jump_grace_ticks = 1
	state.jump_sustain_ticks = 0
	state.fast_fall_armed = false
	state.fast_falling = false
	state.wall_air_ticks = 0
	_capture_air_velocity(state)
	_clear_landing_cue(state)
	state.last_event = event_name


static func _remaining_air_ticks(state: PlayerState, config: SimConfig) -> int:
	var velocity := state.air_vertical_velocity
	var discriminant := velocity * velocity + 2 * MovementTuning.VERTICAL_GRAVITY * state.air_height
	var numerator := (velocity + _integer_sqrt(discriminant)) * config.tick_rate
	return maxi(0, (numerator + MovementTuning.VERTICAL_GRAVITY - 1) / MovementTuning.VERTICAL_GRAVITY)


static func _integrate_height(state: PlayerState, config: SimConfig) -> void:
	if state.air_floating:
		state.air_vertical_velocity = 0
		state.hop_ticks = _remaining_air_ticks(state, config)
		return
	if state.wall_skim_ticks > 0:
		state.air_vertical_velocity = 0
		state.hop_ticks = _remaining_air_ticks(state, config)
		return
	if state.air_height == 0 and state.air_vertical_velocity <= 0:
		if state.hop_ticks > 0 or state.air_dodge_used:
			_land(state, config)
		return
	# Midpoint fixed-step integration: position and velocity use the same gravity.
	var gravity_step := config.per_tick(MovementTuning.VERTICAL_GRAVITY)
	var denominator := 2 * config.tick_rate
	var next_velocity := maxi(-MovementTuning.AIR_TERMINAL_FALL_SPEED, state.air_vertical_velocity - gravity_step)
	var total := state.air_height_remainder + state.air_vertical_velocity + next_velocity
	var delta: int = total / denominator
	state.air_height_remainder = total - delta * denominator
	state.air_height += delta
	state.air_vertical_velocity = next_velocity
	if state.air_height <= 0:
		_land(state, config)
		return
	if state.air_height >= MovementTuning.AIR_MAX_HEIGHT:
		state.air_height = MovementTuning.AIR_MAX_HEIGHT
		state.air_vertical_velocity = mini(0, state.air_vertical_velocity)
		state.air_height_remainder = 0
	state.hop_ticks = _remaining_air_ticks(state, config)


static func _land(state: PlayerState, config: SimConfig) -> void:
	var wavedash := state.wave_dash_queued
	state.air_floating = false
	state.float_used = false
	state.float_ticks = 0
	state.landing_intensity = _hop_landing_intensity(state.hop_mode, state.fast_falling)
	state.air_height = 0
	state.air_vertical_velocity = 0
	state.air_height_remainder = 0
	state.hop_ticks = 0
	state.hop_stage = 0
	state.jump_protection_ticks = 0
	state.hop_cooldown_ticks = 0
	state.air_redirects_remaining = 0
	state.air_dodge_used = false
	state.air_dodge_ticks = 0
	state.fast_falling = false
	state.fast_fall_armed = false
	state.air_velocity_x = 0
	state.air_velocity_y = 0
	state.jump_sustain_ticks = 0
	state.wall_air_ticks = 0
	state.wave_dash_queued = false
	state.landing_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
	state.last_event = "land"
	if wavedash:
		state.wave_dash_ticks = config.milliseconds_to_ticks(MovementTuning.WAVE_DASH_DURATION_MS)
		state.movement_commitment_ticks = config.milliseconds_to_ticks(MovementTuning.WAVE_DASH_COMMITMENT_MS)
		state.wave_dash_x = state.air_dodge_x
		state.wave_dash_y = state.air_dodge_y
		state.movement_action_speed = _retained_speed(state, 0)
		state.last_event = "wave_dash"

extends RefCounted

# Frozen prior movement entry/timers; only unchanged helper names are qualified.
# Source SHA-256: 9037337f0b9b58d4f158d83c4308ddb1b990c3a9b187f26f317b79bfe9944039
const ResourceRecoveryScript = preload("res://src/sim/entities/resource_recovery.gd")

static func step(state: PlayerState, command: SimCommand, config: SimConfig, world: CollisionWorld, ground_target_ratio: int = 1000, acceleration_ratio: int = 1000, braking_ratio: int = 1000) -> void:
	_advance_timers(state, config)
	var movement_cancelled := command.has_pressed(SimCommand.PRESSED_CANCEL_MOVEMENT)
	if movement_cancelled:
		MovementSystem.cancel_jump_intent(state)
		state.jump_held_last_tick = false
		MovementSystem._clear_action_buffers(state)
		if state.wall_skim_ticks > 0:
			MovementSystem._end_wall_run(state, "wall_cancelled", config)
		# The cancel edge owns all action admission, but keeps physical momentum.
		command = command.copy()
		command.pressed_actions = 0
		command.held_actions = 0
	state.stamina_recovery_idle_ticks = ResourceRecoveryScript.advance_idle(state.stamina_recovery_idle_ticks, state.stamina_recovery_delay_ticks, config.tick_rate)
	var direction: Vector2i = MovementSystem._direction(command.move_x, command.move_y, Vector2i(state.facing_x, state.facing_y))
	if command.move_x != 0 or command.move_y != 0:
		state.facing_x = direction.x
		state.facing_y = direction.y
	MovementSystem._capture_action_buffers(state, command, config)
	if state.wall_skim_ticks <= 0 and (state.technique_buffer_ticks > 0 or command.has_held(SimCommand.HELD_JUMP)):
		MovementSystem._refresh_wall_contact(state, world, config)
	if state.is_airborne() and (command.move_x != 0 or command.move_y != 0):
		state.landing_input_x = direction.x
		state.landing_input_y = direction.y
		state.landing_input_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_INPUT_BUFFER_MS)

	var impact_tech_started := false
	if state.impact_recovery_ticks > 0:
		impact_tech_started = MovementSystem._try_impact_recovery_tech(state, direction, config)
	var control_locked: bool = state.impact_recovery_ticks > 0 or state.control_state in [
		PlayerState.ControlState.LAUNCHED,
		PlayerState.ControlState.GRAPPLED,
		PlayerState.ControlState.CHARGING,
		PlayerState.ControlState.STUNNED,
		PlayerState.ControlState.ROOTED,
	]
	if control_locked:
		# Interruption entry cancels the old intent. A fresh press made during
		# recovery still owns its ordinary bounded buffer, never an early action.
		MovementSystem._cancel_jump_anticipation(state)
		if state.wall_skim_ticks > 0:
			MovementSystem._end_wall_run(state, "wall_interrupted", config)
	else:
		MovementSystem._handle_jump_hold(state, command, direction, config, world)
	MovementSystem._update_wall_attachment(state, command, world, config)
	if not control_locked and not impact_tech_started and state.movement_commitment_ticks == 0:
		# Exactly one newest movement intent owns this tick, including free brakes.
		if state.evade_buffer_ticks > 0:
			MovementSystem._consume_evade_buffer(state, command, direction, config)
		elif state.jump_buffer_ticks > 0:
			MovementSystem._consume_jump_buffer(state, command, direction, config)
		elif state.slide_buffer_ticks > 0:
			MovementSystem._consume_slide_buffer(state, direction, config)
		elif state.technique_buffer_ticks > 0:
			MovementSystem._consume_technique_buffer(state, command, direction, config, world)
	# A grounded press/release received in one command is a complete tap. A
	# released buffered press also launches instead of waiting for a future key.
	if not control_locked and state.jumpsquat_active and not command.has_held(SimCommand.HELD_JUMP):
		MovementSystem._release_ground_jump(state, direction, config)
	state.crouching = (
		not control_locked and not state.is_airborne() and not state.jumpsquat_active
		and state.slide_ticks <= 0 and state.air_dodge_ticks <= 0
		and command.has_held(SimCommand.HELD_SLIDE)
	)
	if not control_locked:
		MovementSystem._apply_variable_air_time(state, command, config)
		MovementSystem._apply_variable_slide_time(state, command, config)
	elif state.air_floating:
		MovementSystem._end_air_float(state, "float_interrupted")

	if impact_tech_started:
		pass # The technique owns this tick's velocity; ordinary control resumes next tick.
	elif state.impact_recovery_ticks > 0:
		MovementSystem._apply_impact_recovery_velocity(state, config)
	elif control_locked:
		if state.control_state == PlayerState.ControlState.LAUNCHED:
			MovementSystem._apply_launch_influence(state, command, direction, config)
		MovementSystem._apply_control_velocity(state, config)
	else:
		var movement_command := command
		if state.last_event == "land" and command.move_x == 0 and command.move_y == 0 and state.landing_input_ticks > 0:
			movement_command = command.copy()
			movement_command.move_x = state.landing_input_x
			movement_command.move_y = state.landing_input_y
			direction = Vector2i(state.landing_input_x, state.landing_input_y)
			state.landing_input_ticks = 0
		MovementSystem._apply_velocity(state, movement_command, direction, config, ground_target_ratio, acceleration_ratio, braking_ratio)
	MovementSystem._integrate(state, config, world)
	MovementSystem._update_wall_attachment(state, command, world, config)
	MovementSystem._integrate_height(state, config)
	MovementSystem._update_mode(state, command)
	state.slide_held_last_tick = command.has_held(SimCommand.HELD_FAST_FALL)
	state.jump_held_last_tick = command.has_held(SimCommand.HELD_JUMP)
	if not state.jump_held_last_tick and not movement_cancelled:
		state.wallrun_armed = true


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
		MovementSystem._end_wall_run(state, "wall_skim_end", config)
	if previous_control_state == PlayerState.ControlState.LAUNCHED and state.control_ticks == 0:
		MovementSystem._begin_impact_recovery(state, config)
	elif previous_control_state != PlayerState.ControlState.FREE and state.control_ticks == 0:
		state.control_state = PlayerState.ControlState.FREE
		state.control_speed = 0
		state.slow_ratio = 1000
		state.last_event = "control_end"

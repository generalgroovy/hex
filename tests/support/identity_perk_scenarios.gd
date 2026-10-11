extends RefCounted
@warning_ignore_start("integer_division")

# Test-only construction of positive windows. No runtime policy calls these
# fixtures. Each token writes only its concern so compatible conjunctions compose.
static func prepare(state: PlayerState, condition: String) -> bool:
	for part: String in condition.split("&", false):
		if not _prepare_token(state, part.strip_edges()):
			return false
	return true


static func _prepare_token(state: PlayerState, token: String) -> bool:
	match token:
		"grounded":
			_ground(state)
		"retreating_grounded":
			_ground(state)
			state.velocity_x = -MovementTuning.BASE_SPEED / 2
			state.velocity_y = 0
			state.aim_x = 1000
			state.aim_y = 0
			state.movement_mode = PlayerState.MovementMode.WALK
		"grounded_walking":
			_ground(state)
			# Preserve a retreating fixture when tokens are composed in either order.
			if state.velocity_x == 0 and state.velocity_y == 0:
				state.velocity_x = MovementTuning.BASE_SPEED / 2
			state.velocity_y = 0
			state.movement_mode = PlayerState.MovementMode.WALK
		"grounded_crouching":
			_ground(state)
			state.crouching = true
		"stationary_grounded":
			_ground(state)
			state.velocity_x = 0
			state.velocity_y = 0
			state.movement_mode = PlayerState.MovementMode.IDLE
		"high_flux":
			state.flux = state.flux_maximum * 3 / 4
		"low_flux":
			state.flux = state.flux_maximum / 4
		"low_stamina":
			state.stamina = state.stamina_maximum / 4
		"high_stamina":
			state.stamina = state.stamina_maximum * 3 / 4
		"high_health":
			state.health = state.health_maximum * 9 / 10
		"low_health":
			state.health = state.health_maximum / 4
		"pending_cast":
			state.pending_cast_wire_id = CombatTuning.PRIMARY_WIRE_ID
			state.pending_cast_ticks = 12
		"cast_recovery":
			state.cast_recovery_ticks = 12
		"sprinting":
			_ground(state)
			state.sprinting = true
			state.velocity_x = MovementTuning.BASE_SPEED * MovementTuning.SPRINT_MULTIPLIER / 1000
			state.movement_mode = PlayerState.MovementMode.SPRINT
		"sliding":
			_ground(state)
			state.slide_ticks = 12
			state.velocity_x = MovementTuning.SLIDE_ENTRY_SPEED
			state.movement_mode = PlayerState.MovementMode.SLIDE
		"airborne_descending":
			_air(state)
			state.air_vertical_velocity = -120_000
		"airborne_rising":
			_air(state)
			state.air_vertical_velocity = 120_000
		"jumpsquat":
			_ground(state)
			state.jumpsquat_active = true
			state.jumpsquat_ticks = 6
		"wallrunning":
			_air(state)
			state.air_vertical_velocity = 0
			state.wall_skim_ticks = 12
			state.wall_skim_surface_id = 1
			state.wall_skim_x = 0
			state.wall_skim_y = 1000
			state.wall_x = -1000
			state.wall_y = 0
			state.hop_mode = PlayerState.MovementMode.WALL_SKIM
			state.movement_mode = PlayerState.MovementMode.WALL_SKIM
		"airborne_spent_dodge":
			_air(state)
			state.air_dodge_used = true
		"flight_active":
			_air(state)
			state.flight_capable = true
			state.float_used = true
			state.air_floating = true
			state.float_ticks = 12
			state.air_vertical_velocity = 0
		"landing":
			_ground(state)
			state.landing_ticks = 12
		"slowed":
			state.control_state = PlayerState.ControlState.SLOWED
			state.control_ticks = 12
			state.slow_ratio = 750
		"impact_recovery":
			state.impact_recovery_ticks = 12
		_: return false
	return true


static func _ground(state: PlayerState) -> void:
	state.air_height = 0
	state.air_vertical_velocity = 0
	state.hop_ticks = 0
	state.wall_skim_ticks = 0
	state.air_floating = false
	state.float_ticks = 0
	state.air_dodge_ticks = 0
	state.slide_ticks = 0
	state.wave_dash_ticks = 0
	state.jumpsquat_active = false
	state.sprinting = false
	state.crouching = false


static func _air(state: PlayerState) -> void:
	state.air_height = 36_000
	state.hop_ticks = 24
	state.slide_ticks = 0
	state.wave_dash_ticks = 0
	state.jumpsquat_active = false
	state.sprinting = false
	state.crouching = false
	if state.wall_skim_ticks == 0 and not state.air_floating:
		state.hop_mode = PlayerState.MovementMode.HOP
		state.movement_mode = PlayerState.MovementMode.HOP

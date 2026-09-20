extends FluxTestSuite


func run() -> int:
	for tick_rate: int in [120]:
		_test_eight_direction_ground_parity(tick_rate)
		_test_analog_ground_magnitude(tick_rate)
		_test_sprint_and_hop(tick_rate)
		_test_directional_hop_control(tick_rate)
		_test_vertical_jump_live_control(tick_rate)
		_test_double_jump(tick_rate)
		_test_eight_direction_slide_integrity(tick_rate)
		_test_slide_and_slide_jump(tick_rate)
		_test_action_buffers(tick_rate)
		_test_variable_jump_and_fast_fall(tick_rate)
		_test_paid_jump_and_slide_sustain(tick_rate)
		_test_movement_chain_economy_and_momentum(tick_rate)
		_test_air_dodge_and_wavedash(tick_rate)
		_test_ground_roll_and_evasion_windows(tick_rate)
		_test_wall_contact_and_wall_kick(tick_rate)
		_test_same_wall_lockout(tick_rate)
		_test_wall_skim(tick_rate)
		_test_vault_and_superglide(tick_rate)
		_test_control_states(tick_rate)
		_test_impact_influence_and_recovery(tick_rate)
	_test_impact_tick_rate_parity()
	_test_air_control_tick_rate_parity()
	return finish("movement")


func _step(world: SimWorld, move_x: int = 0, move_y: int = 0, held: int = 0, pressed: int = 0) -> void:
	check(world.step([SimCommand.new(world.tick, 1, move_x, move_y, held, pressed)]), "world step succeeds")


func _test_eight_direction_ground_parity(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var collision := CollisionWorld.new(4_000_000, 4_000_000)
	var distances: Array[float] = []
	for direction_index: int in range(EightDirectionResolver.DIRECTION_ORDER.size()):
		var direction_id := EightDirectionResolver.DIRECTION_ORDER[direction_index]
		var fixed := EightDirectionResolver.FIXED_VECTORS[direction_index]
		var state := PlayerState.new(1)
		state.position_x = 2_000_000
		state.position_y = 2_000_000
		for tick: int in range(tick_rate):
			MovementSystem.step(state, SimCommand.new(tick, 1, fixed.x, fixed.y), config, collision)
		equal(Vector2i(state.facing_x, state.facing_y), fixed, "%d Hz %s movement owns the exact authored facing" % [tick_rate, direction_id])
		var displacement := Vector2(
			float(state.position_x - 2_000_000),
			float(state.position_y - 2_000_000),
		)
		distances.append(displacement.length())
		check(displacement.length() > 0.0, "%d Hz %s movement advances" % [tick_rate, direction_id])
	var baseline := distances[EightDirectionResolver.EAST]
	for direction_index: int in range(distances.size()):
		check(
			absf(distances[direction_index] - baseline) <= 500.0,
			"%d Hz %s travel has no diagonal speed advantage" % [tick_rate, EightDirectionResolver.DIRECTION_ORDER[direction_index]],
		)


func _test_analog_ground_magnitude(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var collision := CollisionWorld.new(4_000_000, 4_000_000)
	var full := PlayerState.new(1)
	var half := PlayerState.new(1)
	full.position_x = 1_000_000
	full.position_y = 1_000_000
	half.position_x = 1_000_000
	half.position_y = 2_000_000
	for tick: int in range(tick_rate * 2):
		MovementSystem.step(full, SimCommand.new(tick, 1, 1000, 0), config, collision)
		MovementSystem.step(half, SimCommand.new(tick, 1, 500, 0), config, collision)
	equal(full.velocity_x, MovementTuning.BASE_SPEED, "%d Hz full controller gate reaches authored speed" % tick_rate)
	equal(half.velocity_x, MovementTuning.BASE_SPEED / 2, "%d Hz half controller gate reaches half authored speed" % tick_rate)
	equal(full.velocity_y, 0, "%d Hz full analog fixture has no perpendicular drift" % tick_rate)
	equal(half.velocity_y, 0, "%d Hz half analog fixture has no perpendicular drift" % tick_rate)


func _test_sprint_and_hop(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	for _index: int in range(tick_rate / 2):
		_step(world, 1000, 0, SimCommand.HELD_SPRINT)
	var state: PlayerState = world.player()
	check(state.position_x > 160_000, "%d Hz sprint advances" % tick_rate)
	check(state.stamina < MovementTuning.STAMINA_MAXIMUM, "%d Hz sprint drains Stamina" % tick_rate)
	var before_stamina: int = state.stamina
	_step(world, 1000, 0, 0, SimCommand.PRESSED_JUMP)
	equal(state.last_event, "hop", "%d Hz starts hop" % tick_rate)
	equal(state.stamina, before_stamina - MovementTuning.HOP_COST, "%d Hz hop Stamina cost is exact" % tick_rate)
	check(state.hop_ticks > 0, "%d Hz hop is airborne" % tick_rate)


func _test_directional_hop_control(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	_step(world, 707, 707, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	equal(Vector2i(state.hop_x, state.hop_y), Vector2i(707, 707), "%d Hz jump records live input without a launch impulse" % tick_rate)
	equal(Vector2i(state.facing_x, state.facing_y), Vector2i(707, 707), "%d Hz takeoff facing follows startup input" % tick_rate)
	var initial_velocity := Vector2i(state.velocity_x, state.velocity_y)
	_step(world, -707, -707, SimCommand.HELD_JUMP)
	equal(Vector2i(state.facing_x, state.facing_y), Vector2i(-707, -707), "%d Hz airborne facing immediately follows current input" % tick_rate)
	check(state.hop_x < 707 and state.hop_y < 707, "%d Hz opposite airborne input starts steering velocity immediately" % tick_rate)
	check(Vector2i(state.velocity_x, state.velocity_y) != initial_velocity, "%d Hz airborne steering changes travel without a technique press" % tick_rate)
	var steer_ticks := world.config.milliseconds_to_ticks(120)
	for _index: int in range(steer_ticks):
		_step(world, -707, -707, SimCommand.HELD_JUMP)
	check(state.hop_x < 0 and state.hop_y < 0, "%d Hz sustained airborne input redirects both travel axes" % tick_rate)
	var retained_direction := Vector2i(state.hop_x, state.hop_y)
	var prior_speed := Vector2(state.velocity_x, state.velocity_y).length()
	_step(world, 0, 0, SimCommand.HELD_JUMP)
	equal(Vector2i(state.hop_x, state.hop_y), retained_direction, "%d Hz releasing direction retains the last facing reference" % tick_rate)
	check(is_equal_approx(Vector2(state.velocity_x, state.velocity_y).length(), prior_speed), "%d Hz releasing direction preserves earned air speed" % tick_rate)
	var facing_world := SimWorld.new(tick_rate)
	var facing_state: PlayerState = facing_world.player()
	_step(facing_world, 1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	for direction_id: String in EightDirectionResolver.DIRECTION_ORDER:
		var fixed := EightDirectionResolver.fixed_vector(direction_id)
		_step(facing_world, fixed.x, fixed.y, SimCommand.HELD_JUMP)
		equal(Vector2i(facing_state.facing_x, facing_state.facing_y), fixed, "%d Hz airborne facing follows current %s input" % [tick_rate, direction_id])


func _test_vertical_jump_live_control(tick_rate: int) -> void:
	for direction_id: String in EightDirectionResolver.DIRECTION_ORDER:
		var world := SimWorld.new(tick_rate)
		var state := world.player()
		var start := Vector2i(state.position_x, state.position_y)
		var input := EightDirectionResolver.fixed_vector(direction_id)
		state.facing_x = input.x
		state.facing_y = input.y
		_step(world, 0, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		for _tick: int in range(5):
			_step(world, 0, 0, SimCommand.HELD_JUMP)
		equal(Vector2i(state.position_x, state.position_y), start, "%s neutral jump is vertical regardless of facing" % direction_id)
		check(state.hop_ticks > 0, "vertical jump remains airborne")
		for _tick: int in range(7):
			_step(world, input.x, input.y, SimCommand.HELD_JUMP)
		check(state.velocity_x * input.x + state.velocity_y * input.y > 0, "air input accelerates in each direction")
		for _tick: int in range(7):
			_step(world, -input.x, -input.y, SimCommand.HELD_JUMP)
		check(state.velocity_x * input.x + state.velocity_y * input.y < 0, "air input reverses without a paid technique")
		var retained_velocity := Vector2i(state.velocity_x, state.velocity_y)
		for _tick: int in range(7):
			_step(world, 0, 0, SimCommand.HELD_JUMP)
		equal(Vector2i(state.velocity_x, state.velocity_y), retained_velocity, "releasing direction preserves earned momentum without adding thrust")
		var before_double_velocity := Vector2i(state.velocity_x, state.velocity_y)
		_step(world, 0, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		equal(Vector2i(state.velocity_x, state.velocity_y), before_double_velocity, "neutral double jump retains momentum without adding horizontal impulse")


func _test_air_control_tick_rate_parity() -> void:
	var first := SimWorld.new(120)
	var repeat := SimWorld.new(120)
	_step(first, 707, 707, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	_step(repeat, 707, 707, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	for _index: int in range(first.config.milliseconds_to_ticks(120)):
		_step(first, -707, -707, SimCommand.HELD_JUMP)
		_step(repeat, -707, -707, SimCommand.HELD_JUMP)
	equal(Vector2i(first.player().hop_x, first.player().hop_y), Vector2i(repeat.player().hop_x, repeat.player().hop_y), "120 Hz airborne steering is deterministic")


func _test_double_jump(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	_step(world, 1000, 0, 0, SimCommand.PRESSED_JUMP)
	while state.movement_commitment_ticks > 1:
		_step(world, 1000, 0)
	var after_hop: int = state.stamina
	_step(world, 0, -1000, 0, SimCommand.PRESSED_JUMP)
	equal(state.last_event, "air_float", "%d Hz second edge starts Float at current height" % tick_rate)
	equal(state.stamina, after_hop - MovementTuning.FLOAT_COST * 1100 / 1000 - world.config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND), "%d Hz Float pays continuation cost and its first maintenance tick" % tick_rate)
	check(state.float_used, "%d Hz Float consumes its independent once-per-airtime allowance" % tick_rate)
	var after_double: int = state.stamina
	_step(world, -1000, 0, 0, SimCommand.PRESSED_JUMP)
	equal(state.stamina, after_double, "%d Hz released Float cannot be restarted by another pulse during the same airtime" % tick_rate)
	check(state.float_used, "%d Hz denied Float restart preserves its spent allowance" % tick_rate)


func _test_slide_and_slide_jump(tick_rate: int) -> void:
	var direct_world := SimWorld.new(tick_rate)
	var direct_state: PlayerState = direct_world.player()
	while direct_state.velocity_x < MovementTuning.SLIDE_ENTRY_SPEED:
		_step(direct_world, 1000, 0)
	_step(direct_world, 1000, 0, 0, SimCommand.PRESSED_SLIDE)
	equal(direct_state.last_event, "slide", "%d Hz dedicated slide enters slide directly" % tick_rate)
	equal(direct_state.stamina, MovementTuning.STAMINA_MAXIMUM - MovementTuning.SLIDE_COST, "%d Hz dedicated slide has the authored Stamina cost" % tick_rate)

	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	@warning_ignore("integer_division")
	for _index: int in range(tick_rate / 2):
		_step(world, 1000, 0, SimCommand.HELD_SPRINT)
	_step(world, 1000, 0, SimCommand.HELD_SPRINT, SimCommand.PRESSED_SLIDE)
	equal(state.last_event, "slide", "%d Hz dedicated slide enters from sprint" % tick_rate)
	var late_window: int = world.config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_WINDOW_MS)
	while state.slide_ticks > late_window:
		_step(world, 1000, 0)
	var entry_speed := state.velocity_x
	_step(world, 1000, 0, 0, SimCommand.PRESSED_JUMP)
	equal(state.last_event, "slide_jump", "%d Hz late slide converts" % tick_rate)
	equal(state.hop_speed, entry_speed, "%d Hz slide jump retains actual post-drag momentum without a fixed boost" % tick_rate)


func _test_eight_direction_slide_integrity(tick_rate: int) -> void:
	for direction_index: int in range(EightDirectionResolver.DIRECTION_ORDER.size()):
		var direction_id := EightDirectionResolver.DIRECTION_ORDER[direction_index]
		var fixed := EightDirectionResolver.FIXED_VECTORS[direction_index]
		var world := SimWorld.new(tick_rate)
		var state: PlayerState = world.player()
		while state.velocity_x * state.velocity_x + state.velocity_y * state.velocity_y < MovementTuning.SLIDE_ENTRY_SPEED * MovementTuning.SLIDE_ENTRY_SPEED:
			_step(world, fixed.x, fixed.y)
		_step(world, fixed.x, fixed.y, 0, SimCommand.PRESSED_SLIDE)
		equal(state.last_event, "slide", "%d Hz %s starts slide at the same radial threshold" % [tick_rate, direction_id])
		equal(Vector2i(state.slide_x, state.slide_y), fixed, "%d Hz %s slide latches the exact direction" % [tick_rate, direction_id])
		equal(Vector2i(state.facing_x, state.facing_y), fixed, "%d Hz %s slide facing matches travel" % [tick_rate, direction_id])
		check(state.velocity_x * fixed.x + state.velocity_y * fixed.y > 0, "%d Hz %s slide advances into the requested lane" % [tick_rate, direction_id])


func _test_air_dodge_and_wavedash(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	_step(world, 1000, 0, 0, SimCommand.PRESSED_JUMP)
	var window: int = world.config.milliseconds_to_ticks(MovementTuning.WAVE_DASH_INPUT_WINDOW_MS)
	while state.hop_ticks > window:
		_step(world, 1000, 0)
	_step(world, 0, 1000, SimCommand.HELD_SPRINT, SimCommand.PRESSED_EVADE)
	equal(state.last_event, "air_dodge", "%d Hz late angled dodge starts" % tick_rate)
	check(state.wave_dash_queued, "%d Hz late angle queues wavedash" % tick_rate)
	while state.air_dodge_ticks > 0:
		_step(world, 0, 1000)
	equal(state.last_event, "wave_dash", "%d Hz queued wavedash starts once" % tick_rate)
	check(state.wave_dash_ticks > 0, "%d Hz wavedash remains bounded" % tick_rate)


func _test_ground_roll_and_evasion_windows(tick_rate: int) -> void:
	var roll_world := SimWorld.new(tick_rate)
	var roller: PlayerState = roll_world.player()
	var initial_stamina := roller.stamina
	_step(roll_world, 1000, 0, 0, SimCommand.PRESSED_EVADE)
	equal(roller.last_event, "roll", "%d Hz open-ground technique starts a roll" % tick_rate)
	equal(roller.movement_mode, PlayerState.MovementMode.ROLL, "%d Hz roll owns an explicit movement mode" % tick_rate)
	check(roller.is_rolling() and not roller.is_airborne(), "%d Hz roll remains grounded" % tick_rate)
	equal(roller.stamina, initial_stamina - MovementTuning.ROLL_COST, "%d Hz roll pays its exact Stamina cost" % tick_rate)
	check(MovementSystem.is_combat_intangible(roller, roll_world.config), "%d Hz roll begins inside its invulnerability window" % tick_rate)
	while MovementSystem.is_combat_intangible(roller, roll_world.config):
		_step(roll_world, 1000, 0)
	check(roller.air_dodge_ticks > 0, "%d Hz roll has readable recovery after invulnerability" % tick_rate)

	var jump_world := SimWorld.new(tick_rate)
	var jumper: PlayerState = jump_world.player()
	_step(jump_world, 1000, 0, 0, SimCommand.PRESSED_JUMP)
	check(MovementSystem.is_combat_intangible(jumper, jump_world.config), "%d Hz jump begins inside its invulnerability window" % tick_rate)
	while MovementSystem.is_combat_intangible(jumper, jump_world.config):
		_step(jump_world, 1000, 0, SimCommand.HELD_JUMP)
	check(jumper.hop_ticks > 0, "%d Hz jump has readable recovery after invulnerability" % tick_rate)


func _test_action_buffers(tick_rate: int) -> void:
	var slide_world := SimWorld.new(tick_rate)
	var slider: PlayerState = slide_world.player()
	# A100ms contextual buffer bridges nearby eligibility, not acceleration from rest.
	for _index: int in range(8):
		_step(slide_world, 1000, 0)
	_step(slide_world, 1000, 0, 0, SimCommand.PRESSED_SLIDE)
	check(slider.slide_buffer_ticks > 0, "%d Hz early slide intent is buffered" % tick_rate)
	while slider.slide_ticks == 0 and slider.slide_buffer_ticks > 0:
		_step(slide_world, 1000, 0)
	equal(slider.last_event, "slide", "%d Hz buffered slide fires after reaching entry speed" % tick_rate)
	equal(slider.slide_buffer_ticks, 0, "%d Hz successful slide consumes its buffer" % tick_rate)

	var expiry_world := SimWorld.new(tick_rate)
	var expiry: PlayerState = expiry_world.player()
	_step(expiry_world, 0, 0, 0, SimCommand.PRESSED_SLIDE)
	for _index: int in range(expiry_world.config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS) + 1):
		_step(expiry_world)
	equal(expiry.slide_buffer_ticks, 0, "%d Hz impossible slide intent expires" % tick_rate)
	equal(expiry.stamina, MovementTuning.STAMINA_MAXIMUM, "%d Hz expired slide spends no Stamina" % tick_rate)

	var chain_world := SimWorld.new(tick_rate)
	var chainer: PlayerState = chain_world.player()
	while chainer.velocity_x < MovementTuning.SLIDE_ENTRY_SPEED:
		_step(chain_world, 1000, 0)
	_step(chain_world, 1000, 0, 0, SimCommand.PRESSED_SLIDE)
	_step(chain_world, 1000, 0, 0, SimCommand.PRESSED_JUMP)
	check(chainer.jump_buffer_ticks > 0, "%d Hz early slide-jump intent is buffered" % tick_rate)
	while chainer.last_event != "slide_jump" and chainer.jump_buffer_ticks > 0:
		_step(chain_world, 1000, 0)
	equal(chainer.last_event, "slide_jump", "%d Hz buffered jump fires in the slide conversion window" % tick_rate)
	equal(chainer.jump_buffer_ticks, 0, "%d Hz slide jump consumes its buffer" % tick_rate)


func _test_wall_contact_and_wall_kick(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	state.position_x = state.radius + 1000
	state.velocity_x = -MovementTuning.BASE_SPEED
	_step(world, -1000, 0)
	check(state.wall_memory_ticks > 0, "%d Hz collision records wall memory" % tick_rate)
	state.hop_cooldown_ticks = 0
	state.stamina = MovementTuning.STAMINA_MAXIMUM
	_step(world, -1000, 1000, 0, SimCommand.PRESSED_JUMP)
	equal(state.last_event, "wall_kick", "%d Hz hop consumes wall memory" % tick_rate)
	equal(state.hop_speed, MovementTuning.WALL_KICK_SPEED, "%d Hz wall kick speed is authored" % tick_rate)
	equal(state.movement_mode, PlayerState.MovementMode.WALL_KICK, "%d Hz wall kick remains explicit state" % tick_rate)


func _test_variable_jump_and_fast_fall(tick_rate: int) -> void:
	var held_world := SimWorld.new(tick_rate)
	var held_state: PlayerState = held_world.player()
	_step(held_world, 1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	for _index: int in range(3):
		_step(held_world, 1000, 0, SimCommand.HELD_JUMP)
	var held_remaining: int = held_state.hop_ticks

	var cut_world := SimWorld.new(tick_rate)
	var cut_state: PlayerState = cut_world.player()
	_step(cut_world, 1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	_step(cut_world, 1000, 0)
	equal(cut_state.last_event, "jump_cut", "%d Hz releasing jump cuts the authored arc" % tick_rate)
	check(cut_state.air_vertical_velocity <= MovementTuning.SHORT_HOP_VERTICAL_SPEED and cut_state.air_height > 0, "%d Hz release cuts rising velocity without resetting height" % tick_rate)
	check(cut_state.hop_ticks < held_remaining, "%d Hz released jump lands before held jump" % tick_rate)

	var fall_world := SimWorld.new(tick_rate)
	var fall_state: PlayerState = fall_world.player()
	_step(fall_world, 1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	for _index: int in range(8):
		_step(fall_world, 1000, 0, SimCommand.HELD_JUMP)
	var before_fall: int = fall_state.hop_ticks
	_step(fall_world, 1000, 0, SimCommand.HELD_FAST_FALL)
	equal(fall_state.last_event, "fast_fall", "%d Hz airborne slide input starts fast fall" % tick_rate)
	check(fall_state.fast_falling, "%d Hz fast fall is explicit canonical state" % tick_rate)
	check(fall_state.hop_ticks < before_fall and fall_state.air_vertical_velocity <= -MovementTuning.AIR_FAST_FALL_SPEED, "%d Hz fast fall creates bounded downward velocity rather than advancing an art clock" % tick_rate)
	equal(fall_state.movement_mode, PlayerState.MovementMode.FAST_FALL, "%d Hz fast fall has an explicit presentation mode" % tick_rate)
	var stamina_before: int = fall_state.stamina
	_step(fall_world, 1000, 0, SimCommand.HELD_FAST_FALL)
	equal(fall_state.stamina, stamina_before, "%d Hz fast fall is commitment rather than a Stamina purchase" % tick_rate)
	while fall_state.hop_ticks > 0:
		_step(fall_world, 1000, 0, SimCommand.HELD_FAST_FALL)
	equal(
		fall_state.landing_intensity,
		MovementTuning.LANDING_HOP_INTENSITY + MovementTuning.LANDING_FAST_FALL_BONUS,
		"%d Hz fast-fall commitment survives as authored landing intensity" % tick_rate,
	)
	while fall_state.landing_ticks > 0:
		_step(fall_world)
	equal(fall_state.landing_intensity, 0, "%d Hz landing intensity clears with its recovery window" % tick_rate)


func _test_paid_jump_and_slide_sustain(tick_rate: int) -> void:
	var held_jump := SimWorld.new(tick_rate)
	var tap_jump := SimWorld.new(tick_rate)
	_step(held_jump, 0, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	_step(tap_jump, 0, 0, 0, SimCommand.PRESSED_JUMP)
	_step(held_jump, 0, 0, SimCommand.HELD_JUMP)
	_step(tap_jump)
	check(held_jump.player().hop_ticks > tap_jump.player().hop_ticks, "held jump buys more airtime than a tap")
	check(held_jump.player().stamina < tap_jump.player().stamina, "only held jump pays sustain Stamina")
	equal(tap_jump.player().stamina, MovementTuning.STAMINA_MAXIMUM - MovementTuning.HOP_COST, "tap jump pays only its reliable opening cost")
	var jump_protection := held_jump.player().jump_protection_ticks
	_step(held_jump, 0, 0, SimCommand.HELD_JUMP)
	equal(held_jump.player().jump_protection_ticks, jump_protection - 1, "holding jump never refreshes opening protection")

	var exhausted_jump := SimWorld.new(tick_rate)
	exhausted_jump.player().stamina = MovementTuning.HOP_COST
	_step(exhausted_jump, 0, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	_step(exhausted_jump, 0, 0, SimCommand.HELD_JUMP)
	equal(exhausted_jump.player().last_event, "jump_sustain_empty", "empty Stamina releases jump sustain honestly")
	check(exhausted_jump.player().air_height > 0 and exhausted_jump.player().air_vertical_velocity <= MovementTuning.SHORT_HOP_VERTICAL_SPEED, "empty jump cuts the rise without deleting earned height")
	var partial_jump := SimWorld.new(tick_rate)
	partial_jump.player().stamina = MovementTuning.HOP_COST + partial_jump.config.per_tick(MovementTuning.JUMP_SUSTAIN_DRAIN_PER_SECOND) - 1
	_step(partial_jump, 0, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	_step(partial_jump, 0, 0, SimCommand.HELD_JUMP)
	equal(partial_jump.player().last_event, "jump_sustain_empty", "a partial tick of Stamina cannot buy a full jump-sustain tick")

	var held_slide := SimWorld.new(tick_rate)
	var tap_slide := SimWorld.new(tick_rate)
	for slide_world: SimWorld in [held_slide, tap_slide]:
		while slide_world.player().velocity_x < MovementTuning.SLIDE_ENTRY_SPEED:
			_step(slide_world, 1000, 0)
	_step(held_slide, 1000, 0, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE)
	_step(tap_slide, 1000, 0, 0, SimCommand.PRESSED_SLIDE)
	check(held_slide.player().slide_ticks > tap_slide.player().slide_ticks, "held slide buys a longer lane crossing than a tap")
	check(held_slide.player().stamina < tap_slide.player().stamina, "only held slide pays sustain Stamina")
	equal(tap_slide.player().slide_ticks, tap_slide.config.milliseconds_to_ticks(MovementTuning.SLIDE_MINIMUM_MS), "tap slide keeps its guaranteed readable duration")
	var slide_protection := held_slide.player().slide_ticks
	for _index: int in range(held_slide.config.milliseconds_to_ticks(MovementTuning.SLIDE_INVULNERABILITY_MS) + 1):
		_step(held_slide, 1000, 0, SimCommand.HELD_SLIDE)
	check(held_slide.player().slide_ticks < slide_protection, "held slide timer remains finite")
	check(not MovementSystem.is_combat_intangible(held_slide.player(), held_slide.config), "holding slide never extends opening protection")
	var exhausted_slide := SimWorld.new(tick_rate)
	while exhausted_slide.player().velocity_x < MovementTuning.SLIDE_ENTRY_SPEED:
		_step(exhausted_slide, 1000, 0)
	exhausted_slide.player().stamina = MovementTuning.SLIDE_COST + exhausted_slide.config.per_tick(MovementTuning.SLIDE_SUSTAIN_DRAIN_PER_SECOND) - 1
	_step(exhausted_slide, 1000, 0, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE)
	equal(exhausted_slide.player().last_event, "slide_sustain_empty", "a partial tick of Stamina cannot buy a full slide-sustain tick")
	equal(exhausted_slide.player().slide_ticks, exhausted_slide.config.milliseconds_to_ticks(MovementTuning.SLIDE_MINIMUM_MS), "exhausted slide retains its guaranteed tap duration")


func _test_movement_chain_economy_and_momentum(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state := world.player()
	state.velocity_x = 840_000
	var before := state.stamina
	_step(world, 1000, 0, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE)
	equal(state.movement_chain_count, 1, "first movement action starts one explicit chain")
	equal(state.stamina, before - MovementTuning.SLIDE_COST - world.config.per_tick(MovementTuning.SLIDE_SUSTAIN_DRAIN_PER_SECOND), "first movement action pays base cost plus its requested sustain tick")
	equal(state.velocity_x, 840_000 - world.config.per_tick(MovementTuning.SLIDE_DRAG_PER_SECOND), "slide preserves earned entry momentum minus explicit friction")
	for _tick: int in range(world.config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_MINIMUM_COMMITMENT_MS)):
		_step(world, 1000, 0, SimCommand.HELD_SLIDE)
	before = state.stamina
	var entry_speed := state.velocity_x
	_step(world, 1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	equal(state.movement_chain_count, 2, "slide jump extends the same movement chain")
	equal(state.stamina, before - MovementTuning.SLIDE_JUMP_COST * 1100 / 1000, "second movement action pays a ten-percent premium")
	equal(state.hop_speed, entry_speed, "slide jump carries actual earned slide momentum")
	while state.movement_commitment_ticks > 1:
		_step(world, 1000, 0)
	before = state.stamina
	_step(world, 1000, 0, 0, SimCommand.PRESSED_EVADE)
	equal(state.movement_chain_count, 3, "air dodge is reachable as the third chained movement")
	equal(state.stamina, before - MovementTuning.AIR_DODGE_COST * 1200 / 1000, "third movement action pays a twenty-percent premium")
	check(state.movement_action_speed >= 840_000, "air dodge preserves faster legal chain momentum")
	for _tick: int in range(world.config.milliseconds_to_ticks(MovementTuning.MOVEMENT_CHAIN_RESET_MS)):
		_step(world)
	equal(state.movement_chain_count, 0, "movement chain cost resets after one third of a second")
	equal(state.movement_chain_reset_ticks, 0, "movement chain reset timer is bounded and observable")

	var refused := SimWorld.new(tick_rate)
	refused.player().stamina = 0
	_step(refused, 1000, 0, 0, SimCommand.PRESSED_JUMP)
	equal(refused.player().movement_chain_count, 0, "refused movement never increments chain cost")


func _test_same_wall_lockout(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	state.position_x = state.radius + 1000
	state.velocity_x = -MovementTuning.BASE_SPEED
	_step(world, -1000, 0)
	var contacted_wall: int = state.wall_contact_id
	_step(world, -1000, 0, 0, SimCommand.PRESSED_JUMP)
	equal(state.wall_lockout_id, contacted_wall, "%d Hz wall kick records wall identity" % tick_rate)
	check(state.wall_lockout_ticks > 0, "%d Hz same-wall lockout starts" % tick_rate)
	state.hop_ticks = 0
	state.air_height = 0
	state.air_vertical_velocity = 0
	state.hop_cooldown_ticks = 0
	state.wall_memory_ticks = 0
	state.position_x = state.radius + 1000
	state.velocity_x = -MovementTuning.BASE_SPEED
	_step(world, -1000, 0)
	equal(state.wall_memory_ticks, 0, "%d Hz same wall cannot immediately refresh a kick" % tick_rate)


func _test_wall_skim(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	state.position_x = 560_000 - state.radius - 1000
	state.position_y = 340_000
	state.velocity_x = MovementTuning.BASE_SPEED
	_step(world, 1000, 0)
	equal(state.wall_contact_id, 1, "%d Hz authored obstacle records a positive surface identity" % tick_rate)
	var before_stamina: int = state.stamina
	var start_y: int = state.position_y
	_step(world, 0, 1000, 0, SimCommand.PRESSED_TECHNIQUE)
	equal(state.last_event, "wall_skim", "%d Hz technique converts recent obstacle contact into wall skim" % tick_rate)
	equal(state.stamina, before_stamina - MovementTuning.WALL_SKIM_COST, "%d Hz wall skim Stamina cost is exact" % tick_rate)
	equal(state.movement_mode, PlayerState.MovementMode.WALL_SKIM, "%d Hz wall skim is explicit canonical state" % tick_rate)
	check(state.wall_skim_ticks > 0, "%d Hz wall skim has a bounded authored duration" % tick_rate)
	check(state.position_y > start_y, "%d Hz wall skim follows the requested wall tangent" % tick_rate)
	var skim_surface: int = state.wall_skim_surface_id
	while state.wall_skim_ticks > 0:
		_step(world, 0, 1000)
	equal(state.last_event, "wall_end", "%d Hz wall skim emits an explicit recovery event" % tick_rate)
	check(state.air_height == 0 and not state.is_airborne(), "%d Hz ground-level wallrun exit cannot fabricate extra height" % tick_rate)
	equal(state.jump_protection_ticks, 0, "%d Hz wall exit never buys fresh protection" % tick_rate)
	state.wall_memory_ticks = world.config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)
	state.wall_contact_id = skim_surface
	state.wall_x = -1000
	state.wall_y = 0
	state.stamina_recovery_delay_ticks = world.config.milliseconds_to_ticks(MovementTuning.STAMINA_RECOVERY_DELAY_MS)
	var after_first_skim: int = state.stamina
	_step(world, 0, -1000, 0, SimCommand.PRESSED_TECHNIQUE)
	equal(state.wall_skim_ticks, 0, "%d Hz same surface cannot immediately chain another skim" % tick_rate)
	check(not state.is_rolling(), "%d Hz wall intent never silently becomes an evade" % tick_rate)
	equal(state.stamina, after_first_skim, "%d Hz same-surface roll pays only its own Stamina" % tick_rate)

	var boundary_world := SimWorld.new(tick_rate)
	var boundary: PlayerState = boundary_world.player()
	boundary.position_x = boundary.radius + 1000
	boundary.velocity_x = -MovementTuning.BASE_SPEED
	_step(boundary_world, -1000, 0)
	check(boundary.wall_contact_id < 0, "%d Hz world boundary keeps its reserved surface identity" % tick_rate)
	var boundary_stamina: int = boundary.stamina
	_step(boundary_world, 0, 1000, 0, SimCommand.PRESSED_TECHNIQUE)
	equal(boundary.wall_skim_ticks, 0, "%d Hz outer world boundary cannot be skimmed" % tick_rate)
	equal(boundary.last_event, "spawn", "%d Hz reserved boundary cannot hijack wall intent" % tick_rate)
	equal(boundary.stamina, boundary_stamina, "%d Hz boundary roll pays only its own Stamina" % tick_rate)


func _test_vault_and_superglide(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	state.position_x = 760_000
	state.position_y = 340_000
	_step(world, 1000, 0, 0, SimCommand.PRESSED_TECHNIQUE)
	equal(state.vault_ticks, 0, "legacy rail cannot activate vault")
	check(state.position_x < 800_000, "technique cannot teleport across solid cover")
	_step(world, 1000, 0, SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP)
	equal(state.hop_mode, PlayerState.MovementMode.HOP, "Sprint + Jump still jumps")
	equal(state.superglide_ticks, 0, "retired vault crest cannot activate superglide")


func _test_control_states(tick_rate: int) -> void:
	var rooted_world := SimWorld.new(tick_rate)
	var rooted: PlayerState = rooted_world.player()
	var rooted_start := Vector2i(rooted.position_x, rooted.position_y)
	check(MovementSystem.apply_control_state(rooted, PlayerState.ControlState.ROOTED, 200, Vector2i.RIGHT, 0, rooted_world.config), "%d Hz root applies" % tick_rate)
	_step(rooted_world, 1000, 0, SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP)
	equal(Vector2i(rooted.position_x, rooted.position_y), rooted_start, "%d Hz root blocks movement and movement actions" % tick_rate)
	equal(rooted.movement_mode, PlayerState.MovementMode.ROOTED, "%d Hz root is explicit presentation state" % tick_rate)

	var launch_world := SimWorld.new(tick_rate)
	var launched: PlayerState = launch_world.player()
	var launch_start: int = launched.position_x
	check(MovementSystem.apply_control_state(launched, PlayerState.ControlState.LAUNCHED, 200, Vector2i.RIGHT, 2_000_000, launch_world.config), "%d Hz launch applies" % tick_rate)
	_step(launch_world, -1000, 0, SimCommand.HELD_SPRINT, SimCommand.PRESSED_TECHNIQUE)
	check(launched.position_x > launch_start, "%d Hz launch overrides player steering" % tick_rate)
	check(launched.velocity_x <= MovementTuning.MAX_AUTHORED_SPEED, "%d Hz launch respects authored speed ceiling" % tick_rate)
	equal(launched.movement_mode, PlayerState.MovementMode.LAUNCHED, "%d Hz launch is explicit presentation state" % tick_rate)

	var slow_world := SimWorld.new(tick_rate)
	var slowed: PlayerState = slow_world.player()
	check(MovementSystem.apply_control_state(slowed, PlayerState.ControlState.SLOWED, 200, Vector2i.RIGHT, 0, slow_world.config, 500), "%d Hz slow applies" % tick_rate)
	_step(slow_world, 1000, 0)
	check(slowed.velocity_x > 0 and slowed.velocity_x < slow_world.config.per_tick(MovementTuning.ACCELERATION), "%d Hz slow scales ordinary acceleration" % tick_rate)
	equal(slowed.movement_mode, PlayerState.MovementMode.SLOWED, "%d Hz slow is explicit presentation state" % tick_rate)
	check(not MovementSystem.apply_control_state(slowed, 99, 200, Vector2i.RIGHT, 0, slow_world.config), "%d Hz unknown control state fails closed" % tick_rate)


func _test_impact_influence_and_recovery(tick_rate: int) -> void:
	var neutral_world := SimWorld.new(tick_rate)
	var neutral: PlayerState = neutral_world.player()
	check(
		MovementSystem.apply_control_state(neutral, PlayerState.ControlState.LAUNCHED, 200, Vector2i.RIGHT, 720_000, neutral_world.config),
		"%d Hz neutral launch applies" % tick_rate,
	)
	while neutral.control_state == PlayerState.ControlState.LAUNCHED:
		_step(neutral_world)
	var neutral_y: int = neutral.position_y

	var influence_world := SimWorld.new(tick_rate)
	var influenced: PlayerState = influence_world.player()
	check(
		MovementSystem.apply_control_state(influenced, PlayerState.ControlState.LAUNCHED, 200, Vector2i.RIGHT, 720_000, influence_world.config),
		"%d Hz influenced launch applies" % tick_rate,
	)
	while influenced.control_state == PlayerState.ControlState.LAUNCHED:
		_step(influence_world, 0, -1000)
	check(influenced.position_y < neutral_y, "%d Hz held direction bends launch trajectory" % tick_rate)
	check(influenced.control_y < 0, "%d Hz launch influence changes canonical direction" % tick_rate)
	equal(influenced.last_event, "impact_recovery", "%d Hz launch ends in explicit recovery" % tick_rate)
	check(influenced.impact_recovery_ticks > 0, "%d Hz recovery has a bounded timer" % tick_rate)
	equal(influenced.movement_mode, PlayerState.MovementMode.IMPACT_RECOVERY, "%d Hz recovery owns a readable movement mode" % tick_rate)
	var recovery_velocity := Vector2i(influenced.velocity_x, influenced.velocity_y)
	_step(influence_world, -1000, 0, SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP)
	check(influenced.impact_recovery_ticks > 0, "%d Hz ordinary movement cannot silently cancel impact recovery" % tick_rate)
	check(
		Vector2i(influenced.velocity_x, influenced.velocity_y).length_squared() < recovery_velocity.length_squared(),
		"%d Hz unteched recovery brakes retained momentum" % tick_rate,
	)
	while influenced.impact_recovery_ticks > 0:
		_step(influence_world)
	equal(influenced.last_event, "impact_recovery_end", "%d Hz recovery ends explicitly" % tick_rate)

	var tech_world := SimWorld.new(tick_rate)
	var teched: PlayerState = tech_world.player()
	check(
		MovementSystem.apply_control_state(teched, PlayerState.ControlState.LAUNCHED, 200, Vector2i.RIGHT, 720_000, tech_world.config),
		"%d Hz tech launch applies" % tick_rate,
	)
	var tech_buffer_window: int = tech_world.config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS) - 1
	while teched.control_ticks > tech_buffer_window:
		_step(tech_world, 0, 1000)
	_step(tech_world, 0, 1000, 0, SimCommand.PRESSED_TECHNIQUE)
	var stamina_before_tech: int = teched.stamina
	while teched.control_state == PlayerState.ControlState.LAUNCHED:
		_step(tech_world, 0, 1000)
	equal(teched.last_event, "impact_tech", "%d Hz buffered context technique cuts recovery" % tick_rate)
	equal(teched.impact_recovery_ticks, 0, "%d Hz successful impact tech restores control immediately" % tick_rate)
	equal(teched.stamina, stamina_before_tech - MovementTuning.IMPACT_RECOVERY_TECH_COST, "%d Hz impact tech pays exact Stamina" % tick_rate)
	check(teched.velocity_y > 0, "%d Hz impact tech exits along held direction" % tick_rate)
	check(teched.velocity_y <= MovementTuning.MAX_AUTHORED_SPEED, "%d Hz impact tech respects authored speed ceiling" % tick_rate)

	var collision_world := SimWorld.new(tick_rate)
	var collided: PlayerState = collision_world.player()
	collided.position_x = 540_000
	collided.position_y = 340_000
	check(
		MovementSystem.apply_control_state(collided, PlayerState.ControlState.LAUNCHED, 400, Vector2i.RIGHT, 720_000, collision_world.config),
		"%d Hz collision launch applies" % tick_rate,
	)
	_step(collision_world)
	equal(collided.last_event, "launch_impact", "%d Hz authored cover converts launch into recovery immediately" % tick_rate)
	equal(collided.control_state, PlayerState.ControlState.FREE, "%d Hz cover impact ends forced travel" % tick_rate)
	check(collided.impact_recovery_ticks > 0, "%d Hz cover impact begins bounded recovery" % tick_rate)


func _test_impact_tick_rate_parity() -> void:
	var first := SimWorld.new(120)
	var repeat := SimWorld.new(120)
	for world: SimWorld in [first, repeat]:
		var state: PlayerState = world.player()
		check(MovementSystem.apply_control_state(state, PlayerState.ControlState.LAUNCHED, 200, Vector2i.RIGHT, 720_000, world.config), "120 Hz deterministic launch applies")
		while state.control_state == PlayerState.ControlState.LAUNCHED:
			_step(world, 0, -1000)
	equal(first.player().canonical_values(), repeat.player().canonical_values(), "120 Hz impact travel and directional influence are deterministic")

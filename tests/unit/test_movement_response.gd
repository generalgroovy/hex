extends FluxTestSuite


func run() -> int:
	equal(MovementTuning.BASE_SPEED, 372_600, "ordinary speed is fifteen percent above the prior checkpoint")
	equal(MovementTuning.ACCELERATION, 2_277_000, "ordinary acceleration scales with the faster run")
	equal(MovementTuning.DECELERATION, 3_450_000, "ordinary braking preserves the faster run stop timing")
	equal(MovementTuning.COUNTER_STRAFE_MULTIPLIER, 1900, "counter-strafe owns the crisp reversal profile")
	check(MovementTuning.compatibility_hash().length() == 64, "all movement tuning contributes a stable compatibility identity")
	var metrics_120 := _response_metrics(120)
	_test_bounds(metrics_120)
	_test_slow_is_a_speed_ratio()
	_test_slow_expiry_and_authored_motion()
	_test_walk_sprint_contrast()
	return finish("movement-response")


func _test_walk_sprint_contrast() -> void:
	equal(MovementTuning.SPRINT_MULTIPLIER, 1600, "held sprint is sixty percent faster than unchanged walking")
	equal(MovementTuning.COMPATIBILITY_ID, "movement-tuning-v14-walk-sprint-contrast", "new authoritative speed has a distinct compatibility identity")
	var config := SimConfig.new(120)
	var arena := CollisionWorld.new(10_000_000, 10_000_000)
	for body_ratio: int in [900, 1000, 1100]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var walker := PlayerState.new(1)
			var runner := PlayerState.new(2)
			for state: PlayerState in [walker, runner]:
				state.position_x = 5_000_000
				state.position_y = 5_000_000
				state.movement_speed_ratio = body_ratio
				state.radius = int({900: 19_000, 1000: 18_000, 1100: 17_000}[body_ratio])
			var radius_before := runner.radius
			for tick: int in range(120):
				MovementSystem.step(walker, SimCommand.new(tick, 1, direction.x, direction.y), config, arena)
				MovementSystem.step(runner, SimCommand.new(tick, 2, direction.x, direction.y, SimCommand.HELD_SPRINT), config, arena)
			var walking := Vector2(walker.velocity_x, walker.velocity_y).length()
			var running := Vector2(runner.velocity_x, runner.velocity_y).length()
			check(absf(running / walking - 1.6) < 0.001, "all size ratios and eight directions retain the 1.6 sprint contrast")
			check(running <= MovementTuning.MAX_AUTHORED_SPEED, "ordinary sprint stays below the existing authored speed ceiling")
			equal(runner.radius, radius_before, "sprinting cannot change the selected size hurt radius")
			check(runner.stamina < walker.stamina, "stronger sprint still pays its existing stamina drain")
			check(MovementSystem._retained_speed(runner, MovementTuning.ROLL_SPEED) <= MovementTuning.MAX_AUTHORED_SPEED, "roll entry retains the bounded existing authored speed policy")
			check(MovementSystem._retained_speed(runner, MovementTuning.WALL_SKIM_SPEED) <= MovementTuning.MAX_AUTHORED_SPEED, "wallrun entry cannot amplify stronger sprint beyond the existing cap")
			check(MovementSystem._retained_speed(runner, 0) <= MovementTuning.MAX_AUTHORED_SPEED, "slide entry remains bounded retained momentum rather than a new boost")
			for tick: int in range(120, 144):
				MovementSystem.step(runner, SimCommand.new(tick, 2, direction.x, direction.y), config, arena)
			check((Vector2i(runner.velocity_x, runner.velocity_y) - Vector2i(walker.velocity_x, walker.velocity_y)).length_squared() <= 4, "releasing sprint returns to unchanged walking within 200 ms")
	print("Sprint contrast: walk=", MovementTuning.BASE_SPEED, " sprint=", MovementTuning.BASE_SPEED * MovementTuning.SPRINT_MULTIPLIER / 1000, " movement_hash=", MovementTuning.compatibility_hash())


func _test_slow_is_a_speed_ratio() -> void:
	var config := SimConfig.new(120)
	var arena := CollisionWorld.new(10_000_000, 10_000_000)
	for ratio: int in [250, 650, 700, 1000]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for held: int in [0, SimCommand.HELD_SPRINT]:
				var state := PlayerState.new(1)
				state.position_x = 5_000_000
				state.position_y = 5_000_000
				check(MovementSystem.apply_control_state(state, PlayerState.ControlState.SLOWED, 2000, Vector2i.ZERO, 0, config, ratio), "authored slow is accepted")
				for tick: int in range(120):
					MovementSystem.step(state, SimCommand.new(tick, 1, direction.x, direction.y, held), config, arena)
				var expected_speed: int = MovementTuning.BASE_SPEED
				if held != 0:
					expected_speed = expected_speed * MovementTuning.SPRINT_MULTIPLIER / 1000
				expected_speed = expected_speed * ratio / 1000
				# Diagonal command components are fixed-point approximations; compare
				# the authored vector, not a floating-point length rounded to a circle.
				var expected := Vector2i(direction.x * expected_speed / 1000, direction.y * expected_speed / 1000)
				var actual := Vector2i(state.velocity_x, state.velocity_y)
				check((actual - expected).length_squared() <= 400 * 400, "slow reaches its authored steady ratio in every walking/sprinting direction")
				var stable := actual
				for tick: int in range(120, 150):
					MovementSystem.step(state, SimCommand.new(tick, 1, direction.x, direction.y, held), config, arena)
				check((Vector2i(state.velocity_x, state.velocity_y) - stable).length_squared() <= 4, "continued slow never compounds into a root")


func _test_slow_expiry_and_authored_motion() -> void:
	var config := SimConfig.new(120)
	var arena := CollisionWorld.new(10_000_000, 10_000_000)
	var walker := PlayerState.new(1)
	walker.position_x = 5_000_000
	walker.position_y = 5_000_000
	MovementSystem.apply_control_state(walker, PlayerState.ControlState.SLOWED, 1000, Vector2i.ZERO, 0, config, 700)
	for tick: int in range(119):
		MovementSystem.step(walker, SimCommand.new(tick, 1, 1000, 0), config, arena)
	equal(walker.velocity_x, MovementTuning.BASE_SPEED * 700 / 1000, "70 percent slow retains its exact speed ratio before expiry")
	MovementSystem.step(walker, SimCommand.new(119, 1, 1000, 0), config, arena)
	equal(walker.control_state, PlayerState.ControlState.FREE, "slow ends on its exact authoritative tick")
	equal(walker.slow_ratio, 1000, "expired slow clears its modifier")
	equal(walker.velocity_x, MovementTuning.BASE_SPEED * 700 / 1000 + config.per_tick(MovementTuning.ACCELERATION), "expiry resumes ordinary acceleration rather than snapping or retaining drag")
	for tick: int in range(120, 140):
		MovementSystem.step(walker, SimCommand.new(tick, 1, 1000, 0), config, arena)
	equal(walker.velocity_x, MovementTuning.BASE_SPEED, "ordinary speed is fully recoverable after slow")
	for tick: int in range(140, 160):
		MovementSystem.step(walker, SimCommand.new(tick, 1), config, arena)
	equal(walker.velocity_x, 0, "release still reaches exact rest without residual slow")
	for pressed: int in [SimCommand.PRESSED_SLIDE, SimCommand.PRESSED_EVADE, SimCommand.PRESSED_JUMP]:
		var state := PlayerState.new(1)
		state.position_x = 5_000_000
		state.position_y = 5_000_000
		state.velocity_x = MovementTuning.BASE_SPEED
		MovementSystem.apply_control_state(state, PlayerState.ControlState.SLOWED, 2000, Vector2i.ZERO, 0, config, 700)
		var held := SimCommand.HELD_SLIDE if pressed == SimCommand.PRESSED_SLIDE else SimCommand.HELD_JUMP
		MovementSystem.step(state, SimCommand.new(0, 1, 1000, 0, held, pressed), config, arena)
		for tick: int in range(1, 16):
			MovementSystem.step(state, SimCommand.new(tick, 1, 1000, 0, held), config, arena)
		var expected: int = MovementTuning.BASE_SPEED * 700 / 1000
		if pressed == SimCommand.PRESSED_SLIDE:
			expected = (MovementTuning.BASE_SPEED - 16 * config.per_tick(MovementTuning.SLIDE_DRAG_PER_SECOND)) * 700 / 1000
		elif pressed == SimCommand.PRESSED_EVADE:
			expected = MovementTuning.ROLL_SPEED * 700 / 1000
		equal(state.velocity_x, expected, "jump, slide and roll retain one authored slow multiplier instead of exponential damping")


func _test_bounds(metrics: Dictionary) -> void:
	var tick_rate := int(metrics["tick_rate"])
	check(int(metrics["walk_distance"]) >= 342_700 and int(metrics["walk_distance"]) <= 346_150, "%d Hz one-second walk scales fifteen percent above the prior checkpoint" % tick_rate)
	check(int(metrics["stop_distance"]) <= 19_550, "%d Hz stop distance grows only proportionally to the requested run speed" % tick_rate)
	check(int(metrics["stop_ms"]) <= 120, "%d Hz release reaches rest within 120 ms" % tick_rate)
	check(int(metrics["reverse_overshoot"]) <= 15_525, "%d Hz reversal drift grows only proportionally to the requested run speed" % tick_rate)
	check(int(metrics["reverse_ms"]) <= 105, "%d Hz reversal crosses zero within 105 ms" % tick_rate)
	equal(int(metrics["cruise_velocity"]), MovementTuning.BASE_SPEED, "%d Hz reaches exact ordinary steady speed" % tick_rate)
	check(bool(metrics["residual_mode_visible"]), "%d Hz braking keeps the walk response until physical rest" % tick_rate)
	check(bool(metrics["rest_mode_idle"]), "%d Hz physical rest returns to the idle response" % tick_rate)


func _response_metrics(tick_rate: int) -> Dictionary:
	var collision := CollisionWorld.new(10_000_000, 10_000_000)
	var world := SimWorld.new(tick_rate, 7, collision, "movement-response-fixture", "movement-response-v1")
	var state := world.player()
	state.position_x = 1_000_000
	state.position_y = 1_000_000
	var walk_start := state.position_x
	for _index: int in range(tick_rate):
		world.step([SimCommand.new(world.tick, state.entity_id, 1000, 0)])
	var walk_distance := state.position_x - walk_start
	var cruise_velocity := state.velocity_x
	var stop_start := state.position_x
	var stop_ticks := 0
	var residual_mode_visible := false
	while state.velocity_x != 0 and stop_ticks < tick_rate:
		world.step([SimCommand.new(world.tick, state.entity_id, 0, 0)])
		stop_ticks += 1
		if state.velocity_x != 0 and state.movement_mode == PlayerState.MovementMode.WALK:
			residual_mode_visible = true
	var stop_distance := state.position_x - stop_start
	var rest_mode_idle := state.velocity_x == 0 and state.movement_mode == PlayerState.MovementMode.IDLE
	for _index: int in range(tick_rate):
		world.step([SimCommand.new(world.tick, state.entity_id, 1000, 0)])
	var reverse_start := state.position_x
	var reverse_peak := reverse_start
	var reverse_ticks := 0
	while state.velocity_x >= 0 and reverse_ticks < tick_rate:
		world.step([SimCommand.new(world.tick, state.entity_id, -1000, 0)])
		reverse_peak = maxi(reverse_peak, state.position_x)
		reverse_ticks += 1
	return {
		"tick_rate": tick_rate,
		"walk_distance": walk_distance,
		"cruise_velocity": cruise_velocity,
		"stop_distance": stop_distance,
		"stop_ms": stop_ticks * 1000 / tick_rate,
		"reverse_overshoot": reverse_peak - reverse_start,
		"reverse_ms": reverse_ticks * 1000 / tick_rate,
		"residual_mode_visible": residual_mode_visible,
		"rest_mode_idle": rest_mode_idle,
	}

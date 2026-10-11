extends FluxTestSuite


func run() -> int:
	equal(MovementTuning.BASE_SPEED, 270_000, "walking is deliberate without inflating the sprint ceiling")
	equal(MovementTuning.ACCELERATION, 2_640_000, "responsive combat improves pickup without increasing top speed")
	equal(MovementTuning.DECELERATION, 3_960_000, "responsive combat shortens release drift without snapping")
	equal(MovementTuning.COUNTER_STRAFE_MULTIPLIER, 1900, "counter-strafe owns the crisp reversal profile")
	check(MovementTuning.compatibility_hash().length() == 64, "all movement tuning contributes a stable compatibility identity")
	var metrics_120 := _response_metrics(120)
	_test_bounds(metrics_120)
	_test_slow_is_a_speed_ratio()
	_test_slow_expiry_and_authored_motion()
	_test_walk_sprint_contrast()
	_test_paid_slide_carry_profiles()
	_test_ground_carry_and_guards()
	return finish("movement-response")


func _test_walk_sprint_contrast() -> void:
	equal(MovementTuning.SPRINT_MULTIPLIER, 2200, "held sprint is 2.2 times deliberate walking")
	equal(MovementTuning.BASE_SPEED * MovementTuning.SPRINT_MULTIPLIER / 1000, 594_000, "new sprint remains just below the previous 596160 baseline")
	equal(MovementTuning.COMPATIBILITY_ID, "movement-tuning-v20-paid-slide-chains", "paid slide chains preserve a distinct movement compatibility identity")
	var config := SimConfig.new(120)
	var arena := CollisionWorld.new(10_000_000, 10_000_000)
	for body_ratio: int in [910, 980, 1060]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var walker := PlayerState.new(1)
			var runner := PlayerState.new(2)
			for state: PlayerState in [walker, runner]:
				state.position_x = 5_000_000
				state.position_y = 5_000_000
				state.movement_speed_ratio = body_ratio
				state.radius = int({910: 19_000, 980: 18_000, 1060: 17_000}[body_ratio])
			var radius_before := runner.radius
			for tick: int in range(120):
				MovementSystem.step(walker, SimCommand.new(tick, 1, direction.x, direction.y), config, arena)
				MovementSystem.step(runner, SimCommand.new(tick, 2, direction.x, direction.y, SimCommand.HELD_SPRINT), config, arena)
			var walking := Vector2(walker.velocity_x, walker.velocity_y).length()
			var running := Vector2(runner.velocity_x, runner.velocity_y).length()
			check(absf(running / walking - 2.2) < 0.001, "all size ratios and eight directions retain the 2.2 sprint contrast")
			check(running <= MovementTuning.MAX_AUTHORED_SPEED, "ordinary sprint stays below the existing authored speed ceiling")
			equal(runner.radius, radius_before, "sprinting cannot change the selected size hurt radius")
			check(runner.stamina < walker.stamina, "stronger sprint still pays its existing stamina drain")
			check(MovementSystem._retained_speed(runner, MovementTuning.ROLL_SPEED) <= MovementTuning.MAX_AUTHORED_SPEED, "roll entry retains the bounded existing authored speed policy")
			check(MovementSystem._retained_speed(runner, MovementTuning.WALL_SKIM_SPEED) <= MovementTuning.MAX_AUTHORED_SPEED, "wallrun entry cannot amplify stronger sprint beyond the existing cap")
			check(MovementSystem._retained_speed(runner, 0) <= MovementTuning.MAX_AUTHORED_SPEED, "slide entry remains bounded retained momentum rather than a new boost")
			for tick: int in range(120, 180):
				var before := Vector2i(runner.velocity_x, runner.velocity_y)
				MovementSystem.step(runner, SimCommand.new(tick, 2, direction.x, direction.y), config, arena)
				var after := Vector2i(runner.velocity_x, runner.velocity_y)
				check(after.length() <= before.length() + 1, "sprint release never accelerates")
				check((after - before).length() <= config.per_tick(MovementTuning.GROUND_CARRY_DRAG_PER_SECOND) + 2, "sprint release spends at most one smooth carry-drag step")
			check((Vector2i(runner.velocity_x, runner.velocity_y) - Vector2i(walker.velocity_x, walker.velocity_y)).length_squared() <= 4, "releasing sprint settles to deliberate walking within 500 ms")
	print("Sprint contrast: walk=", MovementTuning.BASE_SPEED, " sprint=", MovementTuning.BASE_SPEED * MovementTuning.SPRINT_MULTIPLIER / 1000, " movement_hash=", MovementTuning.compatibility_hash())


func _test_paid_slide_carry_profiles() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "slide carry loads actual abilities")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "slide carry loads actual size/resource profiles")
	var profiles: Dictionary = {}
	for champion_id: String in catalog.ordered_champion_ids():
		var body := String(catalog.champion(champion_id).body_type)
		if not profiles.has(body): profiles[body] = champion_id
	equal(profiles.size(), 3, "slide carry covers three real body profiles")
	var config := SimConfig.new(120)
	var arena := CollisionWorld.new(10_000_000, 10_000_000)
	for body: String in profiles:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for route: String in ["release", "jump", "carve", "opposed", "roll"]:
				var state := PlayerState.new(1)
				check(catalog.apply_to_player(state, String(profiles[body])), "paid carry applies " + body)
				state.position_x = 5_000_000
				state.position_y = 5_000_000
				state.aim_x = -direction.y
				state.aim_y = direction.x
				var radius := state.radius
				for tick: int in range(45):
					MovementSystem.step(state, SimCommand.new(tick, 1, direction.x, direction.y, SimCommand.HELD_SPRINT), config, arena)
				var incoming := Vector2i(state.velocity_x, state.velocity_y)
				var stamina := state.stamina
				MovementSystem.step(state, SimCommand.new(45, 1, 0, 0, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE), config, arena)
				check(state.slide_ticks > 0, "paid sprint enters slide in every heading/profile")
				var entry := Vector2i(state.velocity_x, state.velocity_y)
				var admitted_budget := minf(incoming.length() + 90_000, 900_000)
				check(entry.length() <= admitted_budget + 1 and entry.length() >= admitted_budget - 1400, "paid slide admission adds one90k boost capped900k, then spends actual drag/normalization")
				equal(state.stamina, stamina - MovementTuning.SLIDE_COST - config.per_tick(MovementTuning.SLIDE_SUSTAIN_DRAIN_PER_SECOND), "entry pays unchanged slide and sustain costs")
				for tick: int in range(46, 58):
					var before := Vector2i(state.velocity_x, state.velocity_y)
					var before_budget := state.movement_action_speed
					var input := Vector2i(-direction.y, direction.x) if route == "carve" else -direction if route == "opposed" else Vector2i.ZERO
					MovementSystem.step(state, SimCommand.new(tick, 1, input.x, input.y, SimCommand.HELD_SLIDE), config, arena)
					var after := Vector2i(state.velocity_x, state.velocity_y)
					check(after.length() <= before.length() + 1, "sustained slide cannot create speed, including a side carve or opposed brake")
					check((after - before).length() <= config.per_tick(MovementTuning.SLIDE_DRAG_PER_SECOND + MovementTuning.SLIDE_BRAKE_PER_SECOND) + 1000, "slide steering changes velocity by a bounded per-tick amount")
					check(state.movement_action_speed <= before_budget, "slide's stored budget cannot regrow after steering")
				check(state.velocity_x * direction.x + state.velocity_y * direction.y > 0, "earned lane remains forward through bounded initial carving/braking")
				if route == "jump":
					for tick: int in range(58, 70):
						var before := Vector2i(state.velocity_x, state.velocity_y)
						MovementSystem.step(state, SimCommand.new(tick, 1, -direction.x, -direction.y, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP if tick == 58 else 0), config, arena)
						check(state.jumpsquat_active and not state.is_airborne(), "slide enters grounded gather without a stop or free launch")
						check((Vector2i(state.velocity_x, state.velocity_y) - before).length() <= config.per_tick(MovementTuning.JUMPSQUAT_DRAG_PER_SECOND) + 2, "gather lowers inherited slide speed by its bounded drag")
					var carry := Vector2i(state.velocity_x, state.velocity_y)
					var before_stamina := state.stamina
					MovementSystem.step(state, SimCommand.new(70, 1), config, arena)
					equal(Vector2i(state.velocity_x, state.velocity_y), carry, "neutral slide-jump release inherits exactly the remaining live vector")
					check(state.is_airborne() and state.hop_mode == PlayerState.MovementMode.SLIDE_JUMP, "gather release keeps its paid slide-jump family")
					equal(state.stamina, before_stamina - MovementTuning.SLIDE_JUMP_COST * 1100 / 1000, "slide jump pays its unchanged chain-adjusted cost")
				elif route == "roll":
					var carry := Vector2i(state.velocity_x, state.velocity_y)
					var before_stamina := state.stamina
					MovementSystem.step(state, SimCommand.new(58, 1, direction.x, direction.y, 0, SimCommand.PRESSED_EVADE), config, arena)
					check(state.is_rolling() and state.slide_ticks == 0, "paid roll still converts after slide commitment")
					check(Vector2i(state.velocity_x, state.velocity_y).length() >= carry.length() - 1000, "paid roll retains incoming speed or its existing roll impulse")
					equal(state.stamina, before_stamina - MovementTuning.ROLL_COST * 1100 / 1000, "roll conversion retains its chain-adjusted payment")
				else:
					var exit_observed := false
					for tick: int in range(58, 100):
						var before := Vector2i(state.velocity_x, state.velocity_y)
						var was_sliding := state.slide_ticks > 0
						# Follow actual travel: after losing speed in a carve, merely
						# returning to forward input must not restore an old budget.
						var travel := Vector2i(state.slide_x, state.slide_y)
						MovementSystem.step(state, SimCommand.new(tick, 1, travel.x, travel.y), config, arena)
						var after := Vector2i(state.velocity_x, state.velocity_y)
						if was_sliding and state.slide_ticks > 0:
							check(after.length() <= before.length() + 1, "forward/neutral continuation cannot recover speed lost during slide steering")
						if was_sliding and state.slide_ticks == 0:
							exit_observed = true
							check(after.length() > 0, "slide expiry hands off momentum instead of stopping")
							check((after - before).length() <= config.per_tick(MovementTuning.GROUND_CARRY_DRAG_PER_SECOND) + 2, "slide exit uses natural bounded carry drag rather than a speed clamp")
					check(exit_observed, "released slide reaches its finite ordinary-movement handoff")
				equal(state.radius, radius, "momentum changes never modify body collision radius")
				equal(Vector2i(state.aim_x, state.aim_y), Vector2i(-direction.y, direction.x), "travel and paid movement never redirect independent aim")
				check(Vector2i(state.velocity_x, state.velocity_y).length() <= MovementTuning.MAX_AUTHORED_SPEED, "all paid routes retain the existing global speed ceiling")
			# Reduced walking still admits each actual profile's paid slide.
			var walker := PlayerState.new(1)
			catalog.apply_to_player(walker, String(profiles[body]))
			walker.position_x = 5_000_000
			walker.position_y = 5_000_000
			for tick: int in range(30):
				MovementSystem.step(walker, SimCommand.new(tick, 1, direction.x, direction.y), config, arena)
			MovementSystem.step(walker, SimCommand.new(30, 1, 0, 0, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE), config, arena)
			check(walker.slide_ticks > 0, "deliberate full walk still admits Slide for each size and heading")


func _test_ground_carry_and_guards() -> void:
	var config := SimConfig.new(120)
	var arena := CollisionWorld.new(10_000_000, 10_000_000)
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for input: Vector2i in [Vector2i.ZERO, direction, -direction]:
			var state := PlayerState.new(1)
			state.position_x = 5_000_000
			state.position_y = 5_000_000
			state.velocity_x = direction.x * 840
			state.velocity_y = direction.y * 840
			state.stamina = 0
			state.stamina_recovery_delay_ticks = 240
			var previous := Vector2i(state.velocity_x, state.velocity_y)
			MovementSystem.step(state, SimCommand.new(0, 1, input.x, input.y, SimCommand.HELD_SPRINT), config, arena)
			check(not state.sprinting and state.stamina == 0, "empty stamina never grants unpaid sprint while carrying momentum")
			var delta := (Vector2i(state.velocity_x, state.velocity_y) - previous).length()
			if input == -direction:
				check(delta > config.per_tick(MovementTuning.GROUND_CARRY_DRAG_PER_SECOND), "deliberate counter-strafe retains its stronger braking")
			else:
				check(delta <= config.per_tick(MovementTuning.GROUND_CARRY_DRAG_PER_SECOND) + 2, "neutral and forward overspeed use bounded ground carry")
			for tick: int in range(1, 180):
				MovementSystem.step(state, SimCommand.new(tick, 1), config, arena)
			equal(Vector2i(state.velocity_x, state.velocity_y), Vector2i.ZERO, "unpowered ground carry always dissipates to exact rest")
	# Carving and then holding forward must never restore the pre-brake impulse.
	var stopped := PlayerState.new(1)
	stopped.position_x = 5_000_000
	stopped.position_y = 5_000_000
	stopped.velocity_x = 300_000
	MovementSystem.step(stopped, SimCommand.new(0, 1, 0, 0, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE), config, arena)
	var brake_per_tick := config.per_tick(MovementTuning.SLIDE_DRAG_PER_SECOND + MovementTuning.SLIDE_BRAKE_PER_SECOND)
	var brake_ticks := ceili(float(absi(stopped.velocity_x)) / float(brake_per_tick))
	check(brake_ticks <= 25, "paid390k entry still reaches rest within25 opposed ticks")
	for tick: int in range(1, brake_ticks + 1):
		MovementSystem.step(stopped, SimCommand.new(tick, 1, -1000, 0, SimCommand.HELD_SLIDE), config, arena)
	equal(stopped.velocity_x, 0, "held opposition can brake the finite slide to rest without reversing for free")
	equal(stopped.movement_action_speed, 0, "opposed stop destroys the inactive full-speed budget")
	MovementSystem.step(stopped, SimCommand.new(brake_ticks + 1, 1, 1000, 0, SimCommand.HELD_SLIDE), config, arena)
	equal(stopped.velocity_x, 0, "forward input cannot resurrect a stopped slide")
	for input: Vector2i in [Vector2i(1000, 0), Vector2i.ZERO]:
		var exhausted := PlayerState.new(1)
		exhausted.position_x = 5_000_000
		exhausted.position_y = 5_000_000
		exhausted.velocity_x = 594_000
		exhausted.stamina = MovementTuning.SLIDE_COST
		MovementSystem.step(exhausted, SimCommand.new(0, 1, input.x, input.y, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE), config, arena)
		equal(exhausted.stamina, 0, "exact-funds slide pays activation without unpaid sustain")
		check(exhausted.slide_ticks == config.milliseconds_to_ticks(MovementTuning.SLIDE_MINIMUM_MS), "empty sustain uses the existing finite released duration")
		check(exhausted.velocity_x > 590_000, "sustain exhaustion cannot erase inherited momentum")
		for tick: int in range(1, 24):
			MovementSystem.step(exhausted, SimCommand.new(tick, 1, input.x, input.y), config, arena)
		check(exhausted.slide_ticks == 0 and exhausted.velocity_x > MovementTuning.BASE_SPEED, "exhausted slide exits into finite earned ground carry, not free sprint")
		check(not exhausted.sprinting, "empty-reserve carry is not sprint admission")
	for field_ratio: int in [750, 1000, 1250]:
		var field_actor := PlayerState.new(1)
		field_actor.position_x = 5_000_000
		field_actor.position_y = 5_000_000
		field_actor.velocity_x = 594_000
		MovementSystem.apply_control_state(field_actor, PlayerState.ControlState.SLOWED, 2000, Vector2i.ZERO, 0, config, 700)
		var before := field_actor.velocity_x
		MovementSystem.step(field_actor, SimCommand.new(0, 1, 1000, 0), config, arena, field_ratio, 650, 550)
		equal(field_actor.velocity_x, before - config.per_tick(MovementTuning.GROUND_CARRY_DRAG_PER_SECOND * 700 / 1000 * 650 / 1000), "carry respects hostile slow and ground acceleration penalty exactly once")
		for tick: int in range(1, 100):
			MovementSystem.step(field_actor, SimCommand.new(tick, 1, 1000, 0), config, arena, field_ratio, 650, 550)
		equal(field_actor.velocity_x, MovementTuning.BASE_SPEED * 700 / 1000 * field_ratio / 1000, "earned carry cannot bypass the final hostile/material walking target")
	for incoming: Vector2i in [Vector2i(1_200_000, 600_000), Vector2i(-840_000, 840_000), Vector2i(840_000, -840_000)]:
		var airborne := PlayerState.new(1)
		airborne.position_x = 5_000_000
		airborne.position_y = 5_000_000
		airborne.velocity_x = incoming.x
		airborne.velocity_y = incoming.y
		MovementSystem.step(airborne, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_JUMP), config, arena)
		var carry := Vector2i(airborne.velocity_x, airborne.velocity_y)
		check(carry.length() <= MovementTuning.MAX_AUTHORED_SPEED, "over-cap inherited air velocity obeys one radial ceiling, not a ceiling per axis")
		check(absf(Vector2(carry).cross(Vector2(incoming))) <= incoming.length() * 1000, "radial cap preserves the inherited direction rather than independently clipping axes")
	for direction: Vector2i in [Vector2i(1000, 0), Vector2i(0, 1000), Vector2i(-1000, 0), Vector2i(0, -1000)]:
		var collision := CollisionWorld.new(10_000_000, 10_000_000)
		var wall_actor := PlayerState.new(1)
		wall_actor.position_x = 5_000_000
		wall_actor.position_y = 5_000_000
		wall_actor.velocity_x = direction.x * 594
		wall_actor.velocity_y = direction.y * 594
		var center := Vector2i(wall_actor.position_x, wall_actor.position_y) + direction * (MovementTuning.PLAYER_RADIUS + 2000) / 1000
		var extent := Vector2i(1000, 100_000) if direction.x != 0 else Vector2i(100_000, 1000)
		collision.add_obstacle(CollisionWorld.Obstacle.new(82, center.x - extent.x, center.y - extent.y, center.x + extent.x, center.y + extent.y))
		MovementSystem.step(wall_actor, SimCommand.new(0, 1, 0, 0, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE), config, collision)
		equal(Vector2i(wall_actor.velocity_x, wall_actor.velocity_y), Vector2i.ZERO, "actual wall collision clips slide momentum immediately")
		equal(wall_actor.slide_ticks, 0, "wall impact ends the slide before any further carve")
		MovementSystem.step(wall_actor, SimCommand.new(1, 1), config, collision)
		equal(Vector2i(wall_actor.velocity_x, wall_actor.velocity_y), Vector2i.ZERO, "ordinary carry cannot resurrect the clipped slide budget")


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
		var held := SimCommand.HELD_SLIDE if pressed == SimCommand.PRESSED_SLIDE else 0
		MovementSystem.step(state, SimCommand.new(0, 1, 1000, 0, held, pressed), config, arena)
		for tick: int in range(1, 16):
			MovementSystem.step(state, SimCommand.new(tick, 1, 1000, 0, held), config, arena)
		var expected: int = MovementTuning.BASE_SPEED * 700 / 1000
		if pressed == SimCommand.PRESSED_SLIDE:
			expected = (MovementTuning.BASE_SPEED + 90_000 - 16 * config.per_tick(MovementTuning.SLIDE_DRAG_PER_SECOND)) * 700 / 1000
		elif pressed == SimCommand.PRESSED_EVADE:
			expected = MovementTuning.ROLL_SPEED * 700 / 1000
		equal(state.velocity_x, expected, "complete jump tap, slide and roll retain one authored slow multiplier instead of exponential damping")
	var prepared := PlayerState.new(1)
	prepared.position_x = 5_000_000
	prepared.position_y = 5_000_000
	prepared.velocity_x = MovementTuning.BASE_SPEED
	MovementSystem.apply_control_state(prepared, PlayerState.ControlState.SLOWED, 2000, Vector2i.ZERO, 0, config, 700)
	var anchor := Vector2i(prepared.position_x, prepared.position_y)
	for tick: int in range(16):
		MovementSystem.step(prepared, SimCommand.new(tick, 1, 1000, 0, SimCommand.HELD_JUMP | SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP if tick == 0 else 0), config, arena)
		check(Vector2i(prepared.position_x, prepared.position_y) != anchor, "hostile slow preserves progressively slowed gathering travel")
		equal(prepared.velocity_x, MovementTuning.BASE_SPEED * 700 / 1000 - (tick + 1) * config.per_tick(MovementTuning.JUMPSQUAT_DRAG_PER_SECOND * 700 / 1000), "hostile slow scales live momentum and gather drag once, never exponentially")
	check(prepared.jumpsquat_active and prepared.control_state == PlayerState.ControlState.SLOWED, "gathering leaves the timed hostile slow active")


func _test_bounds(metrics: Dictionary) -> void:
	print("MOVEMENT RESPONSE: ", JSON.stringify(metrics))
	var tick_rate := int(metrics["tick_rate"])
	check(int(metrics["walk_distance"]) >= 257_000 and int(metrics["walk_distance"]) <= 257_500, "%d Hz deliberate walk covers the independently bounded one-second route" % tick_rate)
	check(int(metrics["stop_distance"]) <= 9_000, "%d Hz ordinary walk release drift stays below nine pixels" % tick_rate)
	check(int(metrics["stop_ms"]) <= 75, "%d Hz ordinary walk release reaches rest within 75 ms" % tick_rate)
	check(int(metrics["reverse_overshoot"]) <= 6_500, "%d Hz ordinary walk reversal drift stays bounded" % tick_rate)
	check(int(metrics["reverse_ms"]) <= 60, "%d Hz ordinary walk reversal crosses zero within 60 ms" % tick_rate)
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

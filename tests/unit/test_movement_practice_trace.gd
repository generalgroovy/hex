extends FluxTestSuite


func run() -> int:
	var trace := MovementPracticeTrace.new()
	trace.begin(0, Vector2(200, 200), 1)
	for tick: int in range(1, 17):
		trace.record(tick, Vector2(200 + tick, 200), SimCommand.new(tick, 1, 1000, 0))
	equal(trace.samples.size(), 5, "practice records a bounded thirty-Hz trail")
	trace.begin(20, Vector2(200, 200), 1)
	check(trace.compare_previous, "same champion and start permit comparison")
	trace.record(26, Vector2(209, 200), SimCommand.new())
	equal(trace.echo_position(), Vector2(206, 200), "previous-run echo interpolates smoothly")
	trace.begin(40, Vector2(1200, 200), 1)
	check(not trace.compare_previous, "different start never presents a misleading race")
	trace.begin(50, Vector2(1200, 200), 2)
	check(not trace.compare_previous, "different body role does not compare")
	for tick: int in range(51, 8000, 4):
		trace.record(tick, Vector2.ZERO, SimCommand.new())
	check(not trace.enabled and trace.samples.size() <= MovementPracticeTrace.MAX_SAMPLES, "practice recording stops at fixed memory cap")
	trace.begin(9000, Vector2.ZERO, 2)
	trace.record(0, Vector2.ZERO, SimCommand.new())
	check(not trace.enabled, "world restart safely clears active recording")
	var actor := PlayerState.new(1)
	actor.movement_mode = PlayerState.MovementMode.SLIDE
	actor.velocity_x = 300_000
	actor.velocity_y = 400_000
	actor.stamina = 80_000
	actor.stamina_maximum = 132_000
	actor.movement_chain_count = 2
	actor.movement_chain_reset_ticks = 20
	var before := actor.canonical_values()
	trace.begin(0, Vector2.ZERO, 1)
	trace.record(4, Vector2.ZERO, SimCommand.new(), 1, actor)
	check(trace.last_status.contains("SLIDE  500u/s"), "practice reports actual mode and radial speed")
	check(trace.last_status.contains("80.0/132.0"), "practice shows actual champion reserve")
	check(trace.last_status.contains("NEXT +%d%%" % (2 * MovementTuning.MOVEMENT_CHAIN_COST_STEP_RATIO / 10)), "practice explains live next-action premium")
	equal(actor.canonical_values(), before, "practice observation never mutates authority")
	trace.begin(5, Vector2.ZERO, 1)
	equal(trace.last_status, "", "new practice run clears old status")
	actor.movement_mode = PlayerState.MovementMode.DOUBLE_JUMP
	actor.air_floating = true
	trace.record(9, Vector2.ZERO, SimCommand.new(), 1, actor)
	check(trace.last_status.begins_with("FLOAT "), "practice names active Float without leaking legacy double-jump identity")
	actor.air_floating = false
	trace.record(13, Vector2.ZERO, SimCommand.new(), 1, actor)
	check(trace.last_status.begins_with("AIRBORNE "), "released state never keeps a misleading Float label")
	actor.movement_mode = PlayerState.MovementMode.FAST_FALL
	var neutral_evade := SimCommand.new(17, 1, 0, 0, 0, SimCommand.PRESSED_EVADE)
	trace.record(17, Vector2.ZERO, neutral_evade, 1, actor)
	check(trace.last_input.contains("EVADE -> FAST FALL"), "trace reports the admitted neutral Evade result without calling it a dodge")
	var slide_alias := SimCommand.new(21, 1, 600, 0, 0, SimCommand.PRESSED_SLIDE)
	trace.record(21, Vector2.ZERO, slide_alias, 1, actor)
	check(trace.last_input.contains("SLIDE -> FAST FALL"), "trace preserves the established fresh Slide fast-fall alias")
	actor.movement_mode = PlayerState.MovementMode.AIR_DODGE
	var directional_evade := SimCommand.new(25, 1, 1000, 0, 0, SimCommand.PRESSED_EVADE)
	trace.record(25, Vector2.ZERO, directional_evade, 1, actor)
	check(trace.last_input.contains("EVADE -> AIR DODGE"), "trace distinguishes paid directional air dodge from neutral fast fall")
	return finish("movement-practice-trace")

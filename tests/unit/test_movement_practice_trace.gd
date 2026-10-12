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
	_test_paid_route_feedback()
	return finish("movement-practice-trace")


func _test_paid_route_feedback() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"route comparison loads current abilities")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities),"route comparison uses an actual character")
	var burst := SimWorld.new(120,41,CollisionWorld.new(10000000,10000000))
	var ordinary := SimWorld.new(120,41,CollisionWorld.new(10000000,10000000))
	for world: SimWorld in [burst,ordinary]:
		check(champions.apply_to_player(world.player(),"oh_tipi"),"same real champion owns both route attempts")
		world.player().position_x = 5000000
		world.player().position_y = 5000000
	var trace := MovementPracticeTrace.new()
	trace.begin(0,Vector2(5000,5000),1)
	var saw_chain_feedback := false
	var saw_paid_turn := false
	var steps_ok := true
	var observer_pure := true
	for tick: int in range(180):
		var move := Vector2i(1000,0) if tick<55 else Vector2i(0,1000)
		var held := SimCommand.HELD_SPRINT if tick<40 else 0
		var pressed := SimCommand.PRESSED_SLIDE if tick==40 else (SimCommand.PRESSED_JUMP if tick==45 else (SimCommand.PRESSED_EVADE if tick==55 else 0))
		var command := SimCommand.new(tick,1,move.x,move.y,held,pressed)
		steps_ok = burst.step([command]) and ordinary.step([SimCommand.new(tick,1,move.x,move.y,held)]) and steps_ok
		var actor := burst.player()
		var before := actor.canonical_values()
		trace.record(tick+1,Vector2(actor.position_x,actor.position_y)/1000.0,command,1,actor)
		observer_pure = observer_pure and actor.canonical_values()==before
		if tick==55:
			equal(actor.movement_chain_count,3,"ordinary Sprint-Slide-Jump-Evade inputs admit a three-action paid route")
			check(actor.stamina<ordinary.player().stamina,"creative turn spends a real reserve compared with ordinary turning")
			check(actor.velocity_y>ordinary.player().velocity_y,"paid air turn produces an observable route advantage at its activation")
		if actor.movement_chain_count>=2 and trace.last_status.contains("NEXT +"):
			saw_chain_feedback = true
		if trace.last_input.contains("EVADE -> AIR DODGE"): saw_paid_turn = true
	check(steps_ok,"both route comparisons use complete authoritative ticks")
	check(observer_pure,"recording a genuine route cannot alter canonical movement or resources")
	check(saw_chain_feedback,"practice exposes the cost premium of the actually admitted chain")
	check(saw_paid_turn,"practice names the actual creative exit instead of only its input button")
	check(trace.samples.size()>20 and trace.samples.size()<100,"real route feedback stays within the existing bounded sampling cadence")
	check(burst.player().stamina>=0,"completed practice route cannot underflow its reserve")
	check(Vector2i(burst.player().position_x,burst.player().position_y)!=Vector2i(ordinary.player().position_x,ordinary.player().position_y),"compared routes end at measurably different positions")

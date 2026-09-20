extends FluxTestSuite

const Bootstrap = preload("res://src/app/bootstrap.gd")


func run() -> int:
	for tick_rate: int in [120]:
		_test_advanced_route(tick_rate)
		_test_momentum_chime_route(tick_rate)
		_test_south_annex(tick_rate)
	return finish("conservatory-route")


func _test_south_annex(tick_rate: int) -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "southern route loads the live authoritative campus")
	var walk_hash := ""
	for repeat: int in range(2):
		var world := SimWorld.new(tick_rate, 20260909, layout.build_collision_world(), String(layout.data["id"]), layout.content_hash)
		var state := world.player()
		state.reset_for_spawn(Vector2i(560_000, 1_408_000))
		var start_stamina := state.stamina
		var circuit: Array = []
		for route: Dictionary in layout.data["routes"]:
			if String(route["id"]) == "conservatory-south-loop":
				circuit = route["points"].duplicate(true)
		# Existing canopy closes the loop; then the same ordinary path reaches
		# the new bridge, the unchanged Practice Bell and the unchanged Crucible.
		circuit.append_array([[560,1408],[800,1408],[848,1536],[848,2080],[1120,2080],[1888,2080],[1888,1376],[1568,1440]])
		for waypoint: Array in circuit:
			check(_walk_to(world, Vector2i(int(waypoint[0]), int(waypoint[1])) * SimConfig.FIXED_SCALE), "ordinary movement reaches connected southern waypoint %s" % str(waypoint))
		check(state.stamina >= start_stamina, "walking the annex requires no paid traversal action")
		equal(state.hop_stage, 0, "ordinary return reaches the experiment without jumping or vaulting")
		if repeat == 0:
			walk_hash = world.state_hash()
		else:
			equal(world.state_hash(), walk_hash, "same120Hz command route gives the same authoritative world hash")
	for wall_id: int in [115, 116]:
		_test_annex_wall(layout, wall_id, tick_rate)
	for zoom: int in [50, 75, 100]:
		for focus: Vector2 in [Vector2(256,2080), Vector2(848,2080), Vector2(1888,2080), Vector2(1536,880)]:
			var viewport := Vector2i(1280,720)
			var origin := Bootstrap.camera_origin_for(focus, viewport, layout.canvas_size, layout.reserved_ui_top, zoom)
			var visible := Vector2(viewport) / (float(zoom) / 100.0)
			check(origin.x >= 0 and origin.y >= 0 and origin.x + visible.x <= layout.canvas_size.x + 0.01 and origin.y + visible.y <= layout.canvas_size.y + 0.01, "all supported zooms keep the camera inside the enlarged world")
			check(Rect2(origin, visible).has_point(focus), "southern focus remains on-screen at every supported zoom")


func _walk_to(world: SimWorld, target: Vector2i) -> bool:
	var state := world.player()
	for _index: int in range(1200):
		var position := Vector2i(state.position_x, state.position_y)
		if position.distance_squared_to(target) <= 6_000 * 6_000:
			return true
		var direction := (Vector2(target - position)).normalized() * 1000.0
		if not _step(world, roundi(direction.x), roundi(direction.y)):
			return false
		check(world.collision.can_occupy(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS), "ordinary annex traversal never enters worldbone")
	return false


func _test_annex_wall(layout: SanctumCampusLayout, wall_id: int, tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate, 20260910 + wall_id, layout.build_collision_world(), String(layout.data["id"]), layout.content_hash)
	var state := world.player()
	var bounds := SanctumCampusLayout._parse_bounds(layout.buildings_by_id[wall_id]["bounds"])
	var horizontal := bounds.size.x > bounds.size.y
	var approach := Vector2i(0,-1000) if horizontal else Vector2i(1000,0)
	var tangent := Vector2i(1000,0) if horizontal else Vector2i(0,1000)
	var outward := -approach
	var start := Vector2i(bounds.get_center().x * 1000, bounds.end.y * 1000 + MovementTuning.PLAYER_RADIUS + 1000) if horizontal else Vector2i(bounds.position.x * 1000 - MovementTuning.PLAYER_RADIUS - 1000, bounds.position.y * 1000 + 64000)
	state.reset_for_spawn(start)
	state.velocity_x = approach.x * MovementTuning.BASE_SPEED / 1000
	state.velocity_y = approach.y * MovementTuning.BASE_SPEED / 1000
	check(_step(world, approach.x, approach.y), "approach reaches authored southern wall")
	equal(state.wall_contact_id, wall_id, "collision contact identifies the actual new wall")
	var stamina_before := state.stamina
	check(_step(world, tangent.x, tangent.y, 0, SimCommand.PRESSED_TECHNIQUE), "new wall accepts the existing wallrun request")
	equal(state.last_event, "wall_skim", "new wall starts real wallrun rather than only a painted route")
	check(state.stamina < stamina_before, "southern wallrun pays its existing movement cost")
	for _index: int in range(world.config.milliseconds_to_ticks(MovementTuning.WALL_RUN_COMMITMENT_MS) + 1):
		_step(world, tangent.x, tangent.y)
	check(state.wall_skim_ticks > 0, "new wall has enough length for a readable attached run")
	check(_step(world, outward.x, outward.y, 0, SimCommand.PRESSED_JUMP), "attached jump uses existing wall-kick transition")
	check(state.last_event in ["air_wall_kick", "wall_kick"], "actual southern wallrun can kick into its clear turning space")
	check(state.wall_skim_ticks == 0 and state.is_airborne(), "wall kick leaves the wall airborne")
	for _index: int in range(world.config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS) + 1):
		_step(world, outward.x, outward.y)
	check(_step(world, -tangent.x, -tangent.y, 0, SimCommand.PRESSED_TECHNIQUE), "open annex accepts the existing paid air-turn request")
	for _index: int in range(world.config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS)):
		if state.technique_buffer_ticks == 0:
			break
		_step(world, -tangent.x, -tangent.y)
	equal(state.last_event, "air_redirect", "wall kick has room for the existing air redirect")
	check(world.collision.can_occupy(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS), "new wall chain ends in collision-safe turning space")


func _step(world: SimWorld, move_x: int = 0, move_y: int = 0, held: int = 0, pressed: int = 0) -> bool:
	return world.step([SimCommand.new(world.tick, 1, move_x, move_y, held, pressed)])


func _test_advanced_route(tick_rate: int) -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "movement route loads live campus")
	var world := SimWorld.new(tick_rate, 424242, layout.build_collision_world(), String(layout.data["id"]), layout.content_hash)
	world.player().position_x = 240_000
	world.player().position_y = 832_000
	var state: PlayerState = world.player()
	var route_events := PackedStringArray()
	var all_steps_succeeded: bool = true

	for _index: int in range(tick_rate / 2):
		all_steps_succeeded = _step(world, 1000, 0, SimCommand.HELD_SPRINT) and all_steps_succeeded
	all_steps_succeeded = _step(world, 1000, 0, SimCommand.HELD_SPRINT, SimCommand.PRESSED_SLIDE) and all_steps_succeeded
	route_events.append(state.last_event)
	var slide_jump_window: int = world.config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_WINDOW_MS)
	while state.slide_ticks > slide_jump_window:
		all_steps_succeeded = _step(world, 1000, 0) and all_steps_succeeded
	all_steps_succeeded = _step(world, 1000, 0, 0, SimCommand.PRESSED_JUMP) and all_steps_succeeded
	route_events.append(state.last_event)
	all_steps_succeeded = _step(world, 0, -1000, 0, SimCommand.PRESSED_TECHNIQUE) and all_steps_succeeded
	# The technique is queued during the jump's explicit opening commitment.
	# Prove it executes on the live route rather than weakening the event check
	# or requiring a second press after the buffer has already accepted intent.
	for _index: int in range(world.config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS)):
		if state.technique_buffer_ticks == 0:
			break
		all_steps_succeeded = _step(world, 0, -1000) and all_steps_succeeded
	route_events.append(state.last_event)

	# An explicit local trial reset starts the contact drill at the authored east wall.
	state.reset_for_spawn(Vector2i(700_000, 480_000))
	state.position_x = 736_000 - state.radius - 1000
	state.position_y = 480_000
	state.velocity_x = MovementTuning.BASE_SPEED
	state.stamina = MovementTuning.STAMINA_MAXIMUM
	all_steps_succeeded = _step(world, 1000, 0) and all_steps_succeeded
	all_steps_succeeded = _step(world, 0, 1000, 0, SimCommand.PRESSED_TECHNIQUE) and all_steps_succeeded
	route_events.append(state.last_event)
	all_steps_succeeded = _step(world, -1000, 0) and all_steps_succeeded
	route_events.append(state.last_event)

	check(all_steps_succeeded, "%d Hz Conservatory route commands all step" % tick_rate)
	equal(route_events, PackedStringArray(["slide", "slide_jump", "air_redirect", "wall_skim", "wall_detach"]), "%d Hz route reaches the same authored transitions" % tick_rate)
	check(world.collision.can_occupy(Vector2i(state.position_x, state.position_y), state.radius), "%d Hz route ends in valid collision space" % tick_rate)
	check(absi(state.velocity_x) <= MovementTuning.MAX_AUTHORED_SPEED and absi(state.velocity_y) <= MovementTuning.MAX_AUTHORED_SPEED, "%d Hz route remains under the speed ceiling" % tick_rate)


func _test_momentum_chime_route(tick_rate: int) -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "%d Hz Momentum Chime campus loads" % tick_rate)
	var world := SimWorld.new(tick_rate, 424243, layout.build_collision_world(), String(layout.data.get("id", "")), layout.content_hash)
	var state: PlayerState = world.player()
	var chime := SanctumCampusLayout._parse_point(layout.stations_by_id["momentum-chime"]["position"]) * SimConfig.FIXED_SCALE
	state.position_x = chime.x
	state.position_y = chime.y
	state.velocity_x = 0
	state.velocity_y = 0
	var origin := Vector2i(state.position_x, state.position_y)
	check(
		MovementSystem.apply_control_state(state, PlayerState.ControlState.LAUNCHED, 320, Vector2i.UP, 540_000, world.config),
		"%d Hz Momentum Chime launch applies" % tick_rate,
	)
	while state.control_state == PlayerState.ControlState.LAUNCHED:
		_step(world, 1000, 0)
	check(state.impact_recovery_ticks > 0, "%d Hz Chime route reaches the recovery decision" % tick_rate)
	check(state.position_y < origin.y - 100_000, "%d Hz Chime route grants a readable launch lane" % tick_rate)
	check(state.position_x > origin.x, "%d Hz Chime route exposes bounded steering" % tick_rate)
	check(world.collision.can_occupy(Vector2i(state.position_x, state.position_y), state.radius), "%d Hz Chime recovery remains in legal campus space" % tick_rate)
	var stamina_before: int = state.stamina
	_step(world, 1000, 0, 0, SimCommand.PRESSED_TECHNIQUE)
	equal(state.last_event, "impact_tech", "%d Hz Chime route accepts the taught impact tech" % tick_rate)
	equal(state.stamina, stamina_before - MovementTuning.IMPACT_RECOVERY_TECH_COST, "%d Hz Chime route pays the advertised Stamina" % tick_rate)
	check(world.collision.can_occupy(Vector2i(state.position_x, state.position_y), state.radius), "%d Hz Chime tech remains in legal campus space" % tick_rate)

extends SceneTree


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const SIZE := Vector2i(1280, 720)
const CHAMPIONS: Array[String] = ["s_wayne", "oh_tipi", "red_baron"]
var output := "res://.godot/skeleton-motion-render-v2"
var viewport: SubViewport
var node: Node2D
var captured: Array[Dictionary] = []


class PhaseBoard:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var config := SimConfig.new(120)
	var states: Array[PlayerState] = []
	var phase := 0.0
	var draw_failures := 0

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("15221f"))
		draw_string(ThemeDB.fallback_font, Vector2(30, 36), "PRODUCTION PRESENTER | EAST TRAVEL, INDEPENDENT AIM | PHASE %d / 8" % (floori(phase * 8.0) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("e9e6cb"))
		draw_string(ThemeDB.fallback_font, Vector2(30, 64), "Controlled distance phase, 2.5x nearest view. Not a live-world or human playtest acceptance claim.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("acb9aa"))
		for row: int in 2:
			for column: int in 3:
				var state := states[row * 3 + column]
				var champion_id := CHAMPIONS[column]
				var x := 210.0 + float(column) * 420.0
				var y := 334.0 + float(row) * 334.0
				var body_type := String(presenter.champions[champion_id]["body_type"])
				draw_string(ThemeDB.fallback_font, Vector2(x - 162.0, y - 221.0), "%s | AIM %s" % [body_type.to_upper(), "NORTH" if row == 0 else "SOUTH"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e9e6cb"))
				draw_line(Vector2(x - 140, y), Vector2(x + 140, y), Color("456456"), 1.0)
				draw_set_transform(Vector2(x, y), 0.0, Vector2(2.5, 2.5))
				if not presenter.draw(self, state, champion_id, Vector2.ZERO, phase * 120.0, config, true, Vector2.ZERO, phase):
					draw_failures += 1
				draw_set_transform(Vector2.ZERO)


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/skeleton-motion-render-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a new res://.godot/skeleton-motion-render-NAME output; existing captures are never overwritten")
		return
	node = Harness.new()
	if not node.configure_fixture(true):
		fail("Actual gameplay skeleton fixture did not configure")
		node.free()
		return
	var roster := ChampionRosterPlan.new()
	if not roster.load_from_files() or not node.character_selection_grid.configure(node.champion_catalog, roster, node.cartoon_champion_presenter):
		fail("Actual Gallery could not configure its live identities and skeleton portraits")
		node.free()
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Capture directory could not be created")
		node.free()
		return
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	var state: PlayerState = node.world.player()
	for champion_id: String in CHAMPIONS:
		node.character_selection_grid.close_panel()
		if not node.champion_catalog.apply_to_player(state, champion_id):
			fail("Live catalog could not apply " + champion_id)
			return
		state.reset_for_spawn(node.fixture_anchor)
		state.spawn_protection_ticks = 0
		node.selected_champion_id = champion_id
		node.actor_motion_history.clear()
		_sync_fixture(0.0)
		for aim_y: int in [-1000, 1000]:
			# Independent, explicitly staged trials avoid carrying a prior cast's
			# cooldown or offscreen travel into the next input/aim comparison.
			# The authored firing anchor is close to southern cover. Stage 100px
			# north in the same open court so both real projectile lanes remain
			# visible for the three delivery ticks, without changing any collision.
			state.reset_for_spawn(node.fixture_anchor + Vector2i(0, -100000))
			state.spawn_protection_ticks = 0
			node.actor_motion_history.clear()
			_sync_fixture(0.0)
			node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
			for tick: int in 24:
				var commands: Array[SimCommand] = [SimCommand.new(node.world.tick, state.entity_id, 1000, 0, 0, 0, 0, aim_y)]
				if not node.world.step(commands):
					fail("Actual east-travel command failed")
					return
				_sync_fixture(1.0 / 120.0)
			if state.velocity_x <= 0 or state.aim_y != aim_y:
				fail("Fixture must actually travel east while aiming independently north/south")
				return
			var heading := "north" if aim_y < 0 else "south"
			if not await _capture_game(champion_id + "-east-aim-" + heading, "actual_gameplay"):
				return
			if aim_y < 0:
				node.player_preferences.pov_mode = PlayerPreferences.POV_CONE
				node.player_preferences.set_pov_angle_degrees(120)
				node.player_preferences.set_pov_range(4096)
				if not await _capture_game(champion_id + "-east-aim-north-cone", "actual_gameplay_cone"):
					return
				node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
			if not await _capture_paid_cast(champion_id, aim_y):
				return
		node.character_selection_grid.open_panel(champion_id)
		if not await _capture_game(champion_id + "-gallery", "actual_gallery"):
			return
	node.hide()
	var board := PhaseBoard.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.presenter = node.cartoon_champion_presenter
	for row: int in 2:
		for champion_id: String in CHAMPIONS:
			var actor := PlayerState.new(100 + board.states.size())
			if not node.champion_catalog.apply_to_player(actor, champion_id):
				fail("Board identity setup failed")
				return
			actor.movement_mode = PlayerState.MovementMode.WALK
			actor.velocity_x = 300000
			actor.velocity_y = 0
			actor.facing_x = 1000
			actor.facing_y = 0
			actor.aim_x = 0
			actor.aim_y = -1000 if row == 0 else 1000
			actor.spawn_protection_ticks = 0
			board.states.append(actor)
	viewport.add_child(board)
	for phase_index: int in 8:
		board.phase = float(phase_index) / 8.0
		var before := _board_authority(board)
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var name := "production-phase-%02d" % phase_index
		if board.draw_failures != 0 or before != _board_authority(board) or not _save_view(name):
			fail("Production phase board failed or mutated its state")
			return
		captured.append({"file": name + ".png", "kind": "controlled_production_presenter", "normalized_distance_phase": board.phase})
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Capture receipt could not be written")
		return
	receipt.store_string(JSON.stringify({"schema_version": 1, "size": [1280, 720], "frames": captured, "authority_unchanged_by_draw": true, "network": "not_started", "audio": "not_started", "preferences": "transient_fixture_only", "human_acceptance": "not_run"}, "  "))
	receipt.close()
	print("PASS: 32 rendered frames: six actual east-travel/independent-aim, six paid cast startups, six corresponding projectile deliveries, three actual cone, three actual Gallery, eight controlled production-presenter phases; no draw authority mutation; no network/audio/persisted preferences")
	quit(0)


func _sync_fixture(delta: float) -> void:
	var state: PlayerState = node.world.player()
	node.current_position = Vector2(state.position_x, state.position_y) / 1000.0
	node.previous_position = node.current_position
	node.previous_air_height = state.air_height
	node.actor_motion_history.capture(node.world.players)
	node._update_character_gaits(delta)


func _capture_game(name: String, kind: String, evidence: Dictionary = {}) -> bool:
	var state: PlayerState = node.world.player()
	var before := state.canonical_values()
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if state.canonical_values() != before or not _save_view(name):
		fail("Actual game capture failed or changed authority: " + name)
		return false
	var record := {"file": name + ".png", "kind": kind, "tick": node.world.tick, "champion_wire_id": state.champion_wire_id, "aim": [state.aim_x, state.aim_y], "velocity": [state.velocity_x, state.velocity_y], "distance_phase": node.actor_motion_history.gait_phase(state.entity_id)}
	record.merge(evidence)
	captured.append(record)
	return true


func _capture_paid_cast(champion_id: String, aim_y: int) -> bool:
	var state: PlayerState = node.world.player()
	var wire_id := state.primary_wire_id
	var cost := int(CombatTuning.cast_definition(wire_id).get("flux_cost", 0))
	var before_flux := state.flux
	if cost <= 0 or not _step_cast_travel(aim_y, SimCommand.HELD_PRIMARY):
		fail("Primary cast trial failed to request a positive-cost authored cast")
		return false
	var started: Dictionary = {}
	for event: Dictionary in node.world.combat_events:
		if event.get("type") == "cast_started" and int(event.get("entity_id", -1)) == state.entity_id and int(event.get("wire_id", -1)) == wire_id:
			started = event.duplicate(true)
	if started.is_empty() or state.pending_cast_wire_id != wire_id or state.flux != before_flux - cost or state.velocity_x <= 0:
		fail("Moving primary must emit a real accepted cast event and pay exact Flux")
		return false
	var evidence := {"primary_wire_id": wire_id, "flux_before": before_flux, "flux_after_payment": state.flux, "flux_paid": cost, "cast_started_event": started}
	for unused: int in mini(3, maxi(0, state.pending_cast_ticks - 1)):
		if not _step_cast_travel(aim_y):
			return false
	var label := champion_id + "-east-cast-" + ("north" if aim_y < 0 else "south")
	if state.pending_cast_wire_id != wire_id or not await _capture_game(label + "-startup", "actual_paid_moving_cast_startup", evidence):
		fail("Paid cast did not remain in authored startup for its capture")
		return false
	var spawned: Dictionary = {}
	for unused: int in 120:
		if not _step_cast_travel(aim_y):
			return false
		for event: Dictionary in node.world.combat_events:
			if event.get("type") == "projectile_spawned" and int(event.get("owner_id", -1)) == state.entity_id and int(event.get("wire_id", -1)) == wire_id:
				spawned = event.duplicate(true)
		if not spawned.is_empty():
			break
	if spawned.is_empty():
		fail("Paid moving primary did not deliver an authoritative projectile")
		return false
	for unused: int in 3:
		if not _step_cast_travel(aim_y):
			return false
	var projectile_id := int(spawned["projectile_id"])
	var active_projectile: ProjectileState
	for projectile: ProjectileState in node.world.projectiles:
		if projectile.entity_id == projectile_id:
			active_projectile = projectile
	if active_projectile == null or state.velocity_x <= 0 or active_projectile.velocity_y * aim_y <= 0:
		fail("Delivery capture requires the exact spawned projectile travelling along aim while its owner travels east")
		return false
	evidence["projectile_spawned_event"] = spawned
	evidence["projectile_id"] = projectile_id
	evidence["projectile_velocity"] = [active_projectile.velocity_x, active_projectile.velocity_y]
	return await _capture_game(label + "-delivery", "actual_paid_moving_cast_delivery", evidence)


func _step_cast_travel(aim_y: int, held: int = 0) -> bool:
	var state: PlayerState = node.world.player()
	var commands: Array[SimCommand] = [SimCommand.new(node.world.tick, state.entity_id, 1000, 0, held, 0, 0, aim_y)]
	if not node.world.step(commands):
		fail("Actual moving-cast command failed")
		return false
	_sync_fixture(1.0 / 120.0)
	return true


func _save_view(name: String) -> bool:
	var pixels := viewport.get_texture().get_image()
	if pixels == null or pixels.get_size() != SIZE or pixels.save_png(output.path_join(name + ".png")) != OK:
		return false
	print("RENDERED ", output.path_join(name + ".png"))
	return true


static func _board_authority(board: PhaseBoard) -> Array:
	var result: Array = []
	for state: PlayerState in board.states:
		result.append(state.canonical_values())
	return result


func fail(message: String) -> void:
	push_error(message)
	quit(1)

extends SceneTree

# Native capture; also runs as an external absolute script against an older PCK.
# Only production resources and runtime names shared by both builds are used.
const BootstrapScene = preload("res://scenes/bootstrap/bootstrap.tscn")
const SIZE_CHAMPIONS: Array[String] = ["s_wayne", "oh_tipi", "red_baron"]
const WIDTH := 1280
const HEIGHT := 720
var output := ""
var baseline := false
var game: Node2D
var fixture: Dictionary = {}
var frames: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=").replace("\\", "/")
		elif argument == "--baseline":
			baseline = true
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or output.begins_with("res://") or output.begins_with("user://") or ".." in output or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		_fail("visible rendering and a fresh absolute --output directory are required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("could not create capture output")
		return
	root.size = Vector2i(WIDTH, HEIGHT)
	root.visible = true
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null:
		game.element_audio.set_process(false)
	game.show_debug_overlay = false
	game.hex_playground_open = false
	game.player_preferences.set_camera_zoom_percent(75)
	if baseline:
		game.player_preferences.set_pov_mode("full")
	var expected_mode := "full" if baseline else "relative"
	if game.player_preferences.pov_mode != expected_mode or (not baseline and (game.player_preferences.pov_angle_degrees != 360 or game.player_preferences.pov_range != 720)):
		_fail("wrong mounted build or effective sight policy: expected " + expected_mode)
		return
	game.world = game._new_wellspring_world(120)
	game.authoritative_session.world = game.world
	if game.world == null or game.world.hex_court == null:
		_fail("native Wellspring world unavailable")
		return
	fixture = _choose_corner()
	if fixture.is_empty():
		_fail("no legal authored opaque corner supports all four actor positions")
		return
	for size_index: int in 3:
		if not _stage(size_index):
			return
		if not await _capture_pair("size-%d-static" % size_index, false):
			return
	if not _stage(0):
		return
	for step_index: int in range(65):
		if step_index > 0:
			var commands: Array[SimCommand] = []
			for actor: PlayerState in game.world.players:
				commands.append(SimCommand.new(game.world.tick, actor.entity_id, 1000 if actor.entity_id == 2 else 0, 0, 0, 0, actor.aim_x, actor.aim_y))
			if not game.world.step(commands) or not game.world.hex_court.conservation_valid():
				_fail("ordinary edge-crossing input failed: " + game.world.last_error)
				return
			_sync()
		trace.append({"step": step_index, "tick": game.world.tick, "world_hash": game.world.state_hash(), "actors": _actor_records()})
		if step_index in [0, 32, 64] and not await _capture_pair("edge-step-%03d" % step_index, true):
			return
	var first_rows: Array = trace.front().actors
	var last_rows: Array = trace.back().actors
	if bool(first_rows[1].geometric_los) or not bool(last_rows[1].geometric_los) or first_rows[1].position == last_rows[1].position:
		_fail("legal trace did not cross the real opaque visibility edge")
		return
	if frames.size() != 12:
		_fail("expected exactly twelve native frames")
		return
	var receipt := {
		"status": "native_relative_vision_capture_complete", "baseline": baseline,
		"mode": game.player_preferences.pov_mode, "angle": game.player_preferences.pov_angle_degrees, "range": game.player_preferences.pov_range,
		"map_id": game.world.map_id, "map_hash": game.world.map_hash, "fixture": _json_fixture(),
		"camera_zoom_percent": game.player_preferences.camera_zoom_percent, "frames": frames, "legal_edge_trace": trace,
		"sources": _sources(), "helper_sha256": FileAccess.get_sha256(get_script().resource_path),
		"runtime_identity": _runtime_identity(),
		"method": "Native Bootstrap._draw. Initial champion placement is a controlled snapshot fixture outside real collision. Only the final target moves, through 64 ordinary SimWorld input steps; no artificial obstacle or product is inserted.",
		"evidence_limits": ["Local presentation visibility only; no server information filtering proof", "Controlled initial placement is not a player navigation replay", "Motion history is rebased to exact captured positions; animation continuity and contact drift are not evaluated", "Normal/reduced frames share identical authority state", "Human acceptance and performance are not established"],
		"profile_storage": "transient preferences; wrapper must provide isolated APPDATA",
	}
	var file := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if file == null:
		_fail("could not write capture receipt")
		return
	file.store_string(JSON.stringify(receipt, "  ") + "\n")
	file.close()
	print("PASS relative vision native capture frames=12 baseline=", baseline)
	quit(0)


func _choose_corner() -> Dictionary:
	var opaque: Array[Rect2] = []
	for building: Dictionary in game.campus_layout.data.get("buildings", []):
		if String(building.get("occlusion_policy", "")) == "los_cutaway":
			opaque.append(Rect2(SanctumCampusLayout._parse_bounds(building.bounds)))
	# Prefer the garden pavilion: its middle-campus corner avoids top HUD overlap.
	for building_id: int in [103, 106, 101, 105, 104, 107, 108, 109]:
		var building: Dictionary = game.campus_layout.buildings_by_id.get(building_id, {})
		if building.is_empty() or String(building.get("occlusion_policy", "")) != "los_cutaway":
			continue
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(building.bounds))
		var corner := Vector2(bounds.end.x, bounds.position.y)
		var points: Array[Vector2] = [corner + Vector2(56, 56), corner + Vector2(-104, -56), corner + Vector2(128, -56), corner + Vector2(128, 128)]
		var valid := true
		for point: Vector2 in points:
			if not game.world.collision.can_occupy(Vector2i(point * 1000), 24000):
				valid = false
		for offset: int in range(0, 225, 16):
			if not game.world.collision.can_occupy(Vector2i((points[1] + Vector2(offset, 0)) * 1000), 24000):
				valid = false
		if valid and not SightOcclusion.line_clear(points[0], points[1], opaque) and SightOcclusion.line_clear(points[0], points[2], opaque) and SightOcclusion.line_clear(points[0], points[3], opaque):
			return {"building_id": building_id, "building_name": building.get("name", ""), "bounds": bounds, "positions": points, "opaque": opaque}
	return {}


func _stage(size_index: int) -> bool:
	game.world = game._new_wellspring_world(120)
	game.authoritative_session.world = game.world
	game.world.players.clear()
	for index: int in 4:
		var actor := PlayerState.new(index + 1)
		var champion := "s_wayne" if index == 0 else SIZE_CHAMPIONS[(size_index + index - 1) % 3]
		if not game.champion_catalog.apply_to_player(actor, champion):
			_fail("real shared champion identity unavailable: " + champion)
			return false
		actor.reset_for_spawn(Vector2i(fixture.positions[index] * 1000))
		actor.spawn_protection_ticks = 0
		actor.aim_x = 0
		actor.aim_y = -1000
		if not game.world.collision.can_occupy(Vector2i(actor.position_x, actor.position_y), actor.radius):
			_fail("controlled placement overlaps production collision")
			return false
		game.world.players.append(actor)
		game.session_names_by_entity[actor.entity_id] = ["OBSERVER", "WALL TARGET", "EXPOSED TARGET", "CLEAR REAR TARGET"][index]
	game.selected_champion_id = "s_wayne"
	_sync()
	return true


func _sync() -> void:
	game.accumulator_seconds = 0.0
	game.current_position = game._player_position()
	game.previous_position = game.current_position
	game.previous_air_height = 0
	game._reset_motion_history()


func _actor_records() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var observer: PlayerState = game.world.player(1)
	var origin := Vector2(observer.position_x, observer.position_y) / 1000.0
	for actor: PlayerState in game.world.players:
		var point := Vector2(actor.position_x, actor.position_y) / 1000.0
		rows.append({"entity_id": actor.entity_id, "champion": game.champion_catalog.champion_id_from_wire(actor.champion_wire_id), "position": [actor.position_x, actor.position_y], "aim": [actor.aim_x, actor.aim_y], "visible": game._chemistry_actor_visible(actor), "geometric_los": SightOcclusion.line_clear(origin, point, fixture.opaque), "ground_distance": SightOcclusion.inverse_project_ground(point - origin).length(), "role": game.session_names_by_entity[actor.entity_id]})
	return rows


func _capture_pair(label: String, legal_trace: bool) -> bool:
	var rows := _actor_records()
	for row: Dictionary in rows:
		var expected := true if baseline else bool(row.geometric_los)
		if float(row.ground_distance) > 720.0 or bool(row.visible) != expected:
			_fail("actor visibility does not match the mounted build's expected policy: " + JSON.stringify(row))
			return false
	for reduced: bool in [false, true]:
		game.requested_capture_reduced_effects = reduced
		var before: String = game.world.state_hash()
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		var path := output.path_join(label + ("-reduced.png" if reduced else "-normal.png"))
		if screenshot == null or screenshot.is_empty() or screenshot.get_size() != Vector2i(WIDTH, HEIGHT) or screenshot.save_png(path) != OK or game.world.state_hash() != before:
			_fail("capture failed or changed authoritative state: " + label)
			return false
		var camera: Vector2 = game._camera_origin(game._camera_focus_position(game.current_position))
		frames.append({"file": path.get_file(), "absolute_path": path, "sha256": FileAccess.get_sha256(path), "world_hash": before, "tick": game.world.tick, "reduced": reduced, "legal_movement_trace": legal_trace, "camera_origin": [camera.x, camera.y], "actors": rows})
	return true


func _json_fixture() -> Dictionary:
	var bounds: Rect2 = fixture.bounds
	var positions: Array = []
	for point: Vector2 in fixture.positions:
		positions.append([point.x, point.y])
	return {"building_id": fixture.building_id, "building_name": fixture.building_name, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "positions_world_pixels": positions, "occlusion_policy": "los_cutaway", "authored_geometry_unchanged": true}


func _sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path: String in ["res://src/app/bootstrap.gd", "res://src/app/player_preferences.gd", "res://src/presentation/sight_occlusion.gd", "res://content/maps/sanctum_campus_g2_v1.json"]:
		var readable := FileAccess.file_exists(path)
		result.append({"path": path, "raw_file_available": readable, "sha256": FileAccess.get_sha256(path) if readable else "", "note": "export may remap script source; runtime identity remains recorded" if not readable else ""})
	return result


func _runtime_identity() -> Variant:
	var path := "res://content/runtime/runtime_build_identity_v1.json"
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"status": "not_available_in_mounted_pack"}


func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error(message)
	quit(1)

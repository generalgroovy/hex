extends SceneTree


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const CHAMPIONS: Array[String] = ["s_wayne", "oh_tipi", "red_baron"]
var output := "res://.godot/pov-projection-render-v1"
var node: Node2D
var viewport: SubViewport
var records: Array[Dictionary] = []


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/pov-projection-render-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh POV-projection output; previous evidence is preserved")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("POV capture fixture could not configure")
		node.free()
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	node.player_preferences.pov_mode = PlayerPreferences.POV_CONE
	node.player_preferences.set_pov_range(240)
	var state: PlayerState = node.world.player()
	for champion_id: String in CHAMPIONS:
		if not node.champion_catalog.apply_to_player(state, champion_id):
			fail("POV capture could not apply a real size identity")
			return
		node.selected_champion_id = champion_id
		for aim_index: int in 8:
			var aim := EightDirectionResolver.FIXED_VECTORS[aim_index]
			for jumping: bool in [false, true]:
				state.reset_for_spawn(node.fixture_anchor + Vector2i(0, -100000))
				state.spawn_protection_ticks = 0
				node.actor_motion_history.clear()
				node.player_preferences.set_pov_angle_degrees(15 if jumping else 360)
				var before_stamina := state.stamina
				var commands: Array[SimCommand] = [SimCommand.new(node.world.tick, state.entity_id, 0, 0, SimCommand.HELD_JUMP if jumping else 0, SimCommand.PRESSED_JUMP if jumping else 0, aim.x, aim.y)]
				if not node.world.step(commands):
					fail("POV capture could not step real heading/jump input")
					return
				if jumping:
					for unused: int in 10:
						commands = [SimCommand.new(node.world.tick, state.entity_id, 0, 0, SimCommand.HELD_JUMP, 0, aim.x, aim.y)]
						if not node.world.step(commands):
							fail("POV capture jump did not advance")
							return
					if state.air_height <= 0 or state.stamina >= before_stamina:
						fail("Raised sprite proof must use a real paid airborne jump")
						return
				_sync()
				var name := "%s-%s-%s" % [champion_id, EightDirectionResolver.DIRECTION_ORDER[aim_index], "cone15-jump" if jumping else "cone360-ground"]
				if not await capture(name, {"jump_paid": jumping, "stamina_before": before_stamina, "stamina_after": state.stamina}):
					return
	# A real opaque building corner allows two legally placed18px-radius actors
	# to be within72 ground pixels while their sightline crosses opaque worldbone.
	if not node.champion_catalog.apply_to_player(state, "s_wayne"):
		fail("Rear corner observer could not configure")
		return
	node.selected_champion_id = "s_wayne"
	var wall := SanctumCampusLayout._parse_bounds(node.campus_layout.buildings_by_id[101]["bounds"])
	var corner := Vector2i(wall.end.x, wall.position.y)
	state.reset_for_spawn((corner + Vector2i(19, 25)) * 1000)
	state.spawn_protection_ticks = 0
	state.aim_x = 707
	state.aim_y = 707
	var target := PlayerState.new(2)
	if not node.champion_catalog.apply_to_player(target, "oh_tipi"):
		fail("Rear corner target could not configure")
		return
	target.reset_for_spawn((corner + Vector2i(-25, -19)) * 1000)
	target.spawn_protection_ticks = 0
	if not node.world.collision.can_occupy(Vector2i(state.position_x, state.position_y), state.radius) or not node.world.collision.can_occupy(Vector2i(target.position_x, target.position_y), target.radius):
		fail("Rear corner actors must be outside actual collision")
		return
	node.world.players.append(target)
	node.session_names_by_entity[2] = "REAR TARGET"
	_sync()
	node.actor_motion_history.capture(node.world.players)
	node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	if not node._chemistry_actor_visible(target) or not await capture("rear-corner-full-control", {"target_visible": true}):
		fail("Full-view control must contain the real rear target")
		return
	node.player_preferences.pov_mode = PlayerPreferences.POV_CONE
	node.player_preferences.set_pov_angle_degrees(15)
	var delta := Vector2(target.position_x - state.position_x, target.position_y - state.position_y) / 1000.0
	var ground_distance := SightOcclusion.inverse_project_ground(delta).length()
	if ground_distance >= SightOcclusion.REAR_AWARENESS_RADIUS or node._chemistry_actor_visible(target):
		fail("Rear corner target must be near enough for awareness yet hidden by real opaque LOS")
		return
	if not await capture("rear-corner-cone-blocked", {"target_visible": false, "rear_ground_distance": ground_distance, "opaque_building_id": 101}):
		return
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("POV capture receipt could not be written")
		return
	receipt.store_string(JSON.stringify({"schema_version": 1, "frames": records, "projection_y_scale": SightOcclusion.GROUND_Y_SCALE, "rear_ground_radius": SightOcclusion.REAR_AWARENESS_RADIUS, "network": "not_started", "audio": "not_started", "preferences": "transient_fixture", "human_acceptance": "not_run"}, "  "))
	receipt.close()
	print("PASS: 50 actual game POV frames; all8aims/3sizes,360ground ellipse,15degree paidjump; real opaque rear-corner control/blocked pair; draw authority unchanged")
	quit(0)


func _sync() -> void:
	var state: PlayerState = node.world.player()
	node.current_position = Vector2(state.position_x, state.position_y) / 1000.0
	node.previous_position = node.current_position
	node.previous_air_height = state.air_height
	node.actor_motion_history.capture(node.world.players)


func capture(name: String, details: Dictionary) -> bool:
	var state: PlayerState = node.world.player()
	var before := state.canonical_values()
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	if pixels == null or pixels.save_png(output.path_join(name + ".png")) != OK or state.canonical_values() != before:
		fail("POV image failed or draw changed authoritative state: " + name)
		return false
	var record := {"file": name + ".png", "champion_wire_id": state.champion_wire_id, "aim": [state.aim_x, state.aim_y], "air_height": state.air_height, "angle": node.player_preferences.pov_angle_degrees, "range": node.player_preferences.pov_range}
	record.merge(details)
	records.append(record)
	print("RENDERED ", output.path_join(name + ".png"))
	return true


func fail(message: String) -> void:
	push_error(message)
	quit(1)

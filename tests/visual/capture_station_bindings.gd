extends SceneTree


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const SIZE := Vector2i(1280, 720)
const CASES := [
	{"name": "gallery-collapsed-keyboard-g", "station": "champion-loom", "expanded": false, "device": ControlBindingEditor.DEVICE_KEYBOARD, "kind": "keyboard", "value": KEY_G},
	{"name": "gallery-expanded-keyboard-g", "station": "champion-loom", "expanded": true, "device": ControlBindingEditor.DEVICE_KEYBOARD, "kind": "keyboard", "value": KEY_G},
	{"name": "host-expanded-mouse-xbutton1", "station": "farflow-host", "expanded": true, "device": ControlBindingEditor.DEVICE_MOUSE, "kind": "mouse", "value": MOUSE_BUTTON_XBUTTON1},
	{"name": "join-expanded-controller-y", "station": "farflow-join", "expanded": true, "device": ControlBindingEditor.DEVICE_CONTROLLER, "kind": "controller", "value": JOY_BUTTON_Y},
	{"name": "parting-expanded-controller-right-stick", "station": "parting-bell", "expanded": true, "device": ControlBindingEditor.DEVICE_CONTROLLER, "kind": "controller", "value": JOY_BUTTON_RIGHT_STICK},
	{"name": "host-expanded-unbound", "station": "farflow-host", "expanded": true, "device": ControlBindingEditor.DEVICE_KEYBOARD, "kind": "keyboard", "value": 0},
]

var output := ""
var viewport: SubViewport
var node: Node2D
var records: Array[Dictionary] = []


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/station-bindings-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh --output=res://.godot/station-bindings-NAME directory")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot configure inherited production draw fixture")
		return
	node.interaction_presenter = WellspringInteractionPresenter.new()
	if not node.interaction_presenter.configure(node.visual_language, node.campus_layout):
		fail("Cannot configure production station presenter")
		return
	node.session_steward = SessionSteward.new()
	node.hide_chemistry_for_visual_probe = true
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	for definition: Dictionary in CASES:
		if not apply_case(definition):
			return
		for reduced: bool in [false, true]:
			if not await capture_case(definition, reduced):
				return
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Cannot write station binding capture receipt")
		return
	receipt.store_string(JSON.stringify({
		"schema_version": 1, "size": [SIZE.x, SIZE.y], "frames": records,
		"source_hashes": source_hashes(), "campus_hash": node.campus_layout.content_hash,
		"interaction_hash": node.interaction_presenter.content_hash,
		"method": "chemistry_coach_harness.configure_fixture(true); inherited production bootstrap draw and station presenter",
		"network": "not_started", "audio": "not_started", "preferences": "transient_fixture_only",
		"authority_unchanged_by_every_draw": true, "human_acceptance": "not_run",
	}, "  "))
	receipt.close()
	print("PASS: %d actual 1280x720 station frames; source-derived labels/lines; normal/reduced; every draw world hash unchanged" % records.size())
	quit(0)


func apply_case(definition: Dictionary) -> bool:
	var station_id := String(definition.station)
	if not node.campus_layout.stations_by_id.has(station_id):
		fail("Missing authored station: " + station_id)
		return false
	match String(definition.kind):
		"keyboard": node.player_preferences.keyboard_bindings[&"interact"] = int(definition.value)
		"mouse": node.player_preferences.mouse_bindings[&"interact"] = int(definition.value)
		"controller": node.player_preferences.controller_bindings[&"interact"] = {"kind": "button", "index": int(definition.value), "direction": 0}
	node.station_activation_device = int(definition.device)
	node.focused_station_id = station_id
	node.expanded_station_id = station_id if bool(definition.expanded) else ""
	node.station_notice = ""
	node.station_notice_seconds = 0.0
	var position_values: Array = node.campus_layout.stations_by_id[station_id].position
	var position := Vector2i(int(position_values[0]), int(position_values[1]) + 56) * SimConfig.FIXED_SCALE
	var actor: PlayerState = node.world.player()
	actor.position_x = position.x
	actor.position_y = position.y
	node.previous_position = Vector2(position) / SimConfig.FIXED_SCALE
	node.current_position = node.previous_position
	node.actor_motion_history.clear()
	return true


func capture_case(definition: Dictionary, reduced: bool) -> bool:
	node.requested_capture_reduced_effects = reduced
	var before: String = node.world.state_hash()
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	var suffix := "reduced" if reduced else "normal"
	var filename := "%s-%s.png" % [String(definition.name), suffix]
	var after: String = node.world.state_hash()
	if pixels == null or pixels.get_size() != SIZE or pixels.save_png(output.path_join(filename)) != OK or after != before:
		fail("Station draw failed or mutated authority: " + filename)
		return false
	var station: Dictionary = node.campus_layout.stations_by_id[String(definition.station)]
	records.append({
		"file": filename, "station_id": String(definition.station), "expanded": bool(definition.expanded),
		"reduced_effects": reduced, "label": node._station_interact_label(),
		"source_prompt": String(station.get("prompt", "")), "action": WellspringInteractionPresenter.station_action_text(station),
		"lines": node._station_lines(station) if bool(definition.expanded) else [String(station.get("prompt", ""))],
		"draw_world_hash_before": before, "draw_world_hash_after": after, "draw_world_hash_unchanged": true,
	})
	return true


func source_hashes() -> Dictionary:
	var paths := ["res://src/app/bootstrap.gd", "res://src/presentation/wellspring_interaction_presenter.gd", WellspringInteractionPresenter.DEFAULT_PATH, "res://tests/support/chemistry_coach_harness.gd", "res://tests/visual/capture_station_bindings.gd"]
	var hashes := {}
	for path: String in paths:
		hashes[path] = FileAccess.get_file_as_string(path).sha256_text()
	return hashes


func fail(message: String) -> void:
	push_error(message)
	quit(1)

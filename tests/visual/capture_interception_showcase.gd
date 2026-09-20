extends "res://tests/visual/capture_warm_style_trails.gd"

const Playthrough = preload("res://tests/scenarios/interception_playthrough.gd")

func _run() -> void:
	var commands_path := ""
	var selection_path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--commands="):
			commands_path = argument.trim_prefix("--commands=")
		elif argument.begins_with("--selection="):
			selection_path = argument.trim_prefix("--selection=")
	if not output.begins_with("res://.godot/warm-style-trails-render-showcase-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Showcase capture requires a fresh output directory")
		return
	var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(commands_path))
	if not input is Dictionary or not input.has("command_trace"):
		fail("Showcase requires the recorded ordinary-input playthrough")
		return
	var selected_ticks: Array[int] = [0, 480, 2280, 2760, 5160, 7200, 8400]
	if selection_path.is_empty():
		var kinds := {}
		for batch: Dictionary in input.event_trace:
			for event: Dictionary in batch.events:
				var kind := String(event.type)
				if kind == "chemistry_formed" and int(event.get("recipe_wire_id", 0)) != 303:
					continue # Capture the encounter's Water+Earth consequence.
				if kind in ["spray_intercepted", "chemistry_formed"] and not kinds.has(kind):
					kinds[kind] = true
					var event_tick := int(batch.tick)
					for offset: int in [-8, -1, 0, 8, 30, 120]:
						if event_tick + offset >= 0:
							selected_ticks.append(event_tick + offset)
	else:
		var selection: Variant = JSON.parse_string(FileAccess.get_file_as_string(selection_path))
		if not selection is Array:
			fail("Comparable capture requires valid selected ticks")
			return
		selected_ticks.assign(selection)
	selected_ticks.sort()
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot configure production drawing")
		return
	node.world = SimWorld.new(120, int(input.seed), node.campus_layout.build_collision_world(), String(input.map_id), String(input.map_hash))
	node.authoritative_session.world = node.world
	var setup := InterceptionShowcase.configure(node.world, node.champion_catalog, node.ability_catalog, node.campus_layout)
	if setup.is_empty():
		fail("Cannot configure the real paid encounter")
		return
	node.interception_practice_setup = setup
	node.interception_practice_active = true
	node.selected_champion_id = "s_wayne"
	var body_ids: Array[String] = ["s_wayne", "oh_tipi"]
	if not node.cartoon_champion_presenter.prepare_override_pages(body_ids) or not node._ensure_runtime_identity():
		fail("Cannot prepare runtime identity and current shared body pages")
		return
	node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	node.player_preferences.set_camera_zoom_percent(75)
	node.current_position = node._player_position()
	node.previous_position = node.current_position
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	viewport.add_child(node)
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	for row: Dictionary in input.command_trace:
		var commands: Array[SimCommand] = []
		for record: Dictionary in row.commands:
			commands.append(Playthrough.command_from_record(record))
		if not node.world.step(commands):
			fail(node.world.last_error)
			return
		if selection_path.is_empty() and node.world.state_hash() != String(input.state_hashes[int(row.tick)].hash):
			fail("Recorded input playback differs from the actual playthrough at tick %d" % int(row.tick))
			return
		node._update_combat_cues(1.0 / 120.0)
		node.interception_feedback.advance(1.0 / 120.0)
		node._ingest_combat_cues(node.world.combat_events)
		node.current_position = node._player_position()
		node.previous_position = node.current_position
		trace.update(node.world.state_hash().to_utf8_buffer())
		if int(row.tick) in selected_ticks:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			if not await capture_modes("tick-%05d" % int(row.tick), {"kind": "recorded_paid_encounter", "input_tick": int(row.tick)}):
				return
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var selection_file := FileAccess.open(output.path_join("selected-ticks.json"), FileAccess.WRITE)
	selection_file.store_string(JSON.stringify(selected_ticks))
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"schema_version": 1, "frames": records,
		"runtime_build_id": node.session_transport.build_id, "runtime_source_sha256": node.session_transport.runtime_source_sha256,
		"method": "fresh_offline_world_per_trial_real_catalog_spells_paid_inputs_production_bootstrap_draw",
		"input_path": commands_path, "input_sha256": FileAccess.get_sha256(commands_path),
		"trace_sha256": trace.finish().hex_encode(), "ticks": input.command_trace.size(),
		"deposits": "never_injected", "authority_unchanged_by_draw": true,
		"network": "not_started", "audio": "not_started", "preferences": "transient_fixture_only",
		"human_acceptance": "not_run", "rendered_performance": "not_measured_capture_pauses"}, "  "))
	receipt.close()
	print("PASS: %d integrated actual-game frames; recorded ordinary commands, live paid encounter, no injected attacks or matter; draw authority unchanged" % records.size())
	quit(0)

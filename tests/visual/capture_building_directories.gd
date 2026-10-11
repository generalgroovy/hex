extends "res://tests/visual/capture_unified_wellspring.gd"

# Native production UI. Fixture positions put the actor at actual front doors;
# this proves rendering/routing, not physical route traversal or human usability.
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/directory-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh native directory output required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create output")
		return
	root.size = Vector2i(WIDTH, HEIGHT)
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null: game.element_audio.set_process(false)
	if game.world == null:
		_fail("production world did not boot")
		return
	var actor: PlayerState = game.world.player()
	var visited := 0
	for entry: Dictionary in [
		{"group":"training", "station":"movement-guide", "children":["controls-lectern"]},
		{"group":"academy", "station":"spell-loom", "children":["spell-loom", "champion-loom"]},
		{"group":"farflow", "station":"farflow-host", "children":[]},
		{"group":"practice", "station":"training-reset", "children":[]},
	]:
		game.service_directory.close()
		var station: Dictionary = game.campus_layout.stations_by_id[entry.station]
		actor.reset_for_spawn(Vector2i(WellspringServiceBuildings.position_of(station)) * 1000)
		actor.spawn_protection_ticks = 0
		actor.aim_x = 0
		actor.aim_y = -1000
		_sync()
		game.player_camera.clear()
		for tick: int in 240:
			game.player_camera.advance(game.current_position, Vector2.ZERO, Vector2.UP, 1.0/120.0, Vector2(WIDTH,HEIGHT), Rect2(0,0,3072,2304))
		game.focused_station_id = String(entry.station)
		game._update_station_focus()
		game.station_notice_seconds = 0.0
		if (await _capture_frame(entry.group+"-front", "existing-building-front", false)).is_empty() or failed: return
		game._open_focused_service_directory()
		if not game.service_directory.is_open or game.service_directory.group_id != entry.group:
			_fail("directory did not open: "+String(entry.group))
			return
		if (await _capture_frame(entry.group+"-directory", "grouped-directory", false)).is_empty() or failed: return
		for child: String in entry.children:
			game._dispatch_directory_station(child)
			if not game._directory_child_open() or game.service_directory.is_open:
				_fail("child transition failed: "+child)
				return
			if (await _capture_frame(child+"-child", "directory-child", false)).is_empty() or failed: return
			if child == "spell-loom":
				var before_slots := actor.spell_wire_ids.duplicate()
				if not game.spell_loom_editor.set_element_filter("fire") or game.spell_loom_editor.visible_spell_indices().size() != 4:
					_fail("Loom element filter failed")
					return
				if (await _capture_frame("spell-loom-filtered", "filtered-heading", false)).is_empty() or failed: return
				if not game.spell_loom_editor.prepare_starter_preview(actor, game.champion_catalog, game.ability_catalog):
					_fail("Loom starter preview failed")
					return
				if (await _capture_frame("spell-loom-starter-preview", "starter-confirmation", false)).is_empty() or failed: return
				game.spell_loom_editor.cancel_starter_preview()
				if actor.spell_wire_ids != before_slots or game.spell_loom_editor.starter_preview_active():
					_fail("preview cancellation changed spells or left an overlay")
					return
				game.spell_loom_editor.set_element_filter("")
			if child == "controls-lectern": game.controls_editor.close_editor()
			elif child == "spell-loom": game.spell_loom_editor.close_editor()
			else: game.character_selection_grid.close_panel()
			game._update_station_focus()
			game._update_service_directory(0.0)
			if not game.service_directory.is_open or game.service_directory.selected_station_id() != child:
				_fail("parent selection was lost: "+child)
				return
			if (await _capture_frame(child+"-return", "directory-parent-return", false)).is_empty() or failed: return
		visited += 1
	if failed or visited != 4 or frames.size() != 16:
		_fail("incomplete directory captures")
		return
	var file := FileAccess.open(output+"/receipt.json", FileAccess.WRITE)
	if file == null:
		_fail("cannot save directory receipt")
		return
	var hex_definition := HexWorldDefinition.from_campus(game.campus_layout)
	file.store_string(JSON.stringify({"status":"passed", "frames":frames, "groups":visited, "map_hash":game.campus_layout.content_hash, "eligible_cells":hex_definition.eligible_cells.size(), "scope":"native existing-door views, four directories, controls/loom/gallery child and parent return; isolated profile; no networking mutations, route traversal or human acceptance"}, "\t")+"\n")
	file.close()
	print("PASS building-directories frames=", frames.size(), " groups=", visited)
	quit(0)

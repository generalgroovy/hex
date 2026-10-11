extends "res://tests/visual/capture_unified_wellspring.gd"

# Production render, doors, fixed camera and local settings. Run with isolated
# APPDATA: production startup can save preferences before this helper owns it.
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/retro-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("native display and fresh retro output required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(WIDTH,HEIGHT)
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
	actor.spawn_protection_ticks = 0
	for entry: Dictionary in [
		{"label":"commons", "point":Vector2i(1536,880), "look":Vector2.RIGHT},
		{"label":"academy-doors", "point":Vector2i(1568,698), "look":Vector2.UP},
		{"label":"chain-courtyard", "point":Vector2i(1460,1840), "look":Vector2.LEFT},
	]:
		actor.reset_for_spawn(entry.point * 1000)
		actor.spawn_protection_ticks = 0
		actor.aim_x = roundi(entry.look.x*1000)
		actor.aim_y = roundi(entry.look.y*1000)
		_sync()
		game.player_camera.clear()
		for step: int in 120:
			game.player_camera.advance(game.current_position,Vector2.ZERO,entry.look,1.0/120.0,Vector2(WIDTH,HEIGHT),Rect2(0,0,3072,2304))
		game._update_station_focus()
		game.station_notice_seconds = 0.0
		var baseline := await _capture_frame(entry.label,"retro-camera-and-doors",false)
		if baseline.is_empty() or failed: return
		if entry.label == "academy-doors":
			for legacy_zoom: int in [50,100]:
				game.player_preferences.camera_zoom_percent = legacy_zoom
				var comparison := await _capture_frame("legacy-zoom-%d" % legacy_zoom,"fixed-zoom-compatibility",false)
				if comparison.is_empty() or failed: return
				if comparison.sha256 != baseline.sha256:
					_fail("legacy zoom changes effective world/visibility framing")
					return
			game.player_preferences.camera_zoom_percent = 75
	game.controls_editor.open_editor()
	if (await _capture_frame("controls-arrow-on","controls",false)).is_empty() or failed: return
	game._toggle_direction_indicator()
	if game.player_preferences.direction_indicator:
		_fail("local direction toggle failed")
		return
	if (await _capture_frame("controls-arrow-off","controls",false)).is_empty() or failed: return
	game.controls_editor.close_editor()
	# Every door keeps its production route. Do not execute networking mutations.
	var doors: Array[Dictionary] = []
	for station: Dictionary in game.campus_layout.stations_by_id.values():
		var point := WellspringServiceBuildings.position_of(station)
		actor.reset_for_spawn(Vector2i(point)*1000)
		_sync()
		game._update_station_focus()
		if game.focused_station_id != String(station.id):
			_fail("door cannot be focused at its accessible threshold: "+String(station.id))
			return
		doors.append({"id":station.id,"command":station.command,"focus":"passed"})
	if failed or frames.size() != 7 or doors.size() != 12:
		_fail("incomplete native review")
		return
	var file := FileAccess.open(output+"/receipt.json",FileAccess.WRITE)
	if file == null:
		_fail("cannot save native review receipt")
		return
	file.store_string(JSON.stringify({"status":"passed","frames":frames,"door_access":doors,"map_hash":game.campus_layout.content_hash,"scope":"native views, actual door focus and transient settings; no human feel or performance acceptance"},"\t")+"\n")
	file.close()
	print("PASS retro-native frames=",frames.size()," doors=",doors.size())
	quit(0)

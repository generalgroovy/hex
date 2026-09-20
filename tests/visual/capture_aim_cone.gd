extends SceneTree

const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
var node: Node2D

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/aim-cone-render-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Expected new aim-cone-render output")
		quit(1)
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Aim cone fixture setup failed")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	var state: PlayerState = node.world.player()
	var count := 0
	for champion_id: String in ["s_wayne", "oh_tipi", "red_baron"]:
		if not node.champion_catalog.apply_to_player(state, champion_id):
			quit(1)
			return
		for cone: bool in [false, true]:
			node.player_preferences.pov_mode = PlayerPreferences.POV_CONE if cone else PlayerPreferences.POV_FULL
			node.player_preferences.set_pov_angle_degrees(120)
			node.player_preferences.set_pov_range(4096 if cone else 720)
			var direction := Vector2i(0, -1000) if cone else Vector2i(0, 1000)
			# Actual input/world pipeline; movement east while aim turns north/south.
			for index: int in range(8):
				var commands: Array[SimCommand] = [SimCommand.new(node.world.tick, state.entity_id, 1000, 0, SimCommand.HELD_PRIMARY, 0, direction.x, direction.y)]
				if not node.world.step(commands):
					quit(1)
					return
			node.current_position = Vector2(state.position_x, state.position_y) / 1000.0
			node.previous_position = node.current_position
			node.previous_air_height = state.air_height
			node.actor_motion_history.capture(node.world.players)
			var before := state.canonical_values()
			node.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var path := output.path_join(champion_id + ("-cone" if cone else "-full") + ".png")
			if viewport.get_texture().get_image().save_png(path) != OK or state.canonical_values() != before:
				push_error("Capture failed or presentation mutated authority")
				quit(1)
				return
			print("CAPTURE ", path, " facing=", CartoonChampionPresenter.presentation_facing_vector(state), " movement=", Vector2i(state.facing_x,state.facing_y))
			count += 1
	print("PASS: ", count, " actual game frames; transient preferences; no network; not human acceptance")
	quit(0)

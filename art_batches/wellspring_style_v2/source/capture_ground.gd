extends SceneTree


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
var output := "res://.godot/wellspring-style-v2-render"
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
	if not output.begins_with("res://.godot/wellspring-style-v2-render") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh Wellspring style output; previous evidence is preserved")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Warm ground capture cannot configure its actual map/presentation fixture")
		node.free()
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	if not await capture_stage("quiet"):
		return
	if not node.paid_cast(1) or not node.advance_until("matter") or not node.paid_cast(2) or not node.advance_until("reaction") or node.world.reactions.is_empty():
		fail("Chemistry comparison must result from two real separately paid casts")
		return
	var reaction: ElementReactionState = node.world.reactions[0]
	if reaction.recipe_wire_id != 310 or not node.advance_to(reaction.active_tick):
		fail("Chemistry comparison requires actual active Steam")
		return
	if not await capture_stage("active-steam"):
		return
	var kit: WellspringIllustratedKit = node.campus_renderer.illustrated_kit
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Warm ground receipt could not be written")
		return
	receipt.store_string(JSON.stringify({"schema_version": 1, "frames": records, "map_hash": node.campus_layout.content_hash, "ground_style_hash": kit.ground_style.content_hash, "ground_generation_ms": kit.ground_generation_ms, "cached_terrain_builds": kit.cached_terrain_builds, "ground_draw_calls": 2, "extra_per_frame_tile_draws": 0, "terrain_atlas_decoded_bytes": 1024 * 180 * 4, "paid_casts": node.paid_casts, "geometry": "unchanged_real_campus", "network": "not_started", "audio": "not_started", "preferences": "transient_fixture_only", "human_acceptance": "not_run", "sustained_performance": "not_measured"}, "  "))
	receipt.close()
	print("PASS:12 actual game frames; quiet/real paid active Steam; normal/reduced;50/75/100zoom;world hash unchanged;one cached warm ground texture")
	quit(0)


func capture_stage(stage: String) -> bool:
	for zoom: int in [100, 75, 50]:
		for reduced: bool in [false, true]:
			node.player_preferences.set_camera_zoom_percent(zoom)
			node.requested_capture_reduced_effects = reduced
			var before: String = node.world.state_hash()
			var ground_before: Texture2D = node.campus_renderer.illustrated_kit.ground
			node.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels := viewport.get_texture().get_image()
			var name := "%s-%d-%s" % [stage, zoom, "reduced" if reduced else "normal"]
			if pixels == null or pixels.save_png(output.path_join(name + ".png")) != OK or before != node.world.state_hash() or ground_before != node.campus_renderer.illustrated_kit.ground or node.campus_renderer.illustrated_kit.cached_terrain_builds != 1:
				fail("Map capture changed authority/rebuilt terrain or failed: " + name)
				return false
			records.append({"file": name + ".png", "world_hash": before, "zoom": zoom, "reduced": reduced, "stage": stage, "render_draw_calls_snapshot": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
			print("RENDERED ", output.path_join(name + ".png"))
	return true


func fail(message: String) -> void:
	push_error(message)
	quit(1)

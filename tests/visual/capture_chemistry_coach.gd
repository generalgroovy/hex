extends SceneTree


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const SIZE := Vector2i(1280, 720)
var output := ""
var viewport: SubViewport
var node: Node2D


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/chemistry-coach-v1/render-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/chemistry-coach-v1/render-NAME directory")
		quit(1)
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot configure actual gameplay coach fixture")
		node.free()
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	if not await capture_stage("invitation"):
		return
	if not node.paid_cast(1) or not node.advance_until("matter"):
		fail("First real paid Fire cast did not create terminal matter")
		return
	if not await capture_stage("matter"):
		return
	if not node.paid_cast(2) or not node.advance_until("reaction") or node.world.reactions.is_empty():
		fail("Second separate paid Water cast did not form a real reaction")
		return
	var reaction: ElementReactionState = node.world.reactions[0]
	if reaction.recipe_wire_id != 310:
		fail("Production Fire/Water did not form Steam")
		return
	if not await capture_stage("forming"):
		return
	if not node.advance_to(reaction.active_tick) or not await capture_stage("active"):
		return
	for zoom: int in [50, 75]:
		node.player_preferences.set_camera_zoom_percent(zoom)
		if not await capture_stage("active-zoom%d" % zoom, false):
			return
	node.player_preferences.set_camera_zoom_percent(100)
	if not node.advance_to(reaction.decay_tick) or not await capture_stage("decay"):
		return
	if not node.advance_to(reaction.expiry_tick) or not await capture_stage("expired", false):
		return
	print("PASS: 13 actual 1280x720 gameplay frames; five lesson states normal/reduced, active50/75zoom, expired; two real paid casts; inherited bootstrap draw")
	quit(0)


func capture_stage(stage: String, both_modes: bool = true) -> bool:
	var modes: Array = [false, true] if both_modes else [false]
	for reduced: bool in modes:
		node.requested_capture_reduced_effects = reduced
		node.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var path := output.path_join(stage + ("-reduced" if reduced else "-normal") + ".png")
		if rendered == null or rendered.get_size() != SIZE or rendered.save_png(path) != OK:
			fail("Failed actual coach gameplay capture: " + stage)
			return false
		print("RENDERED %s | tick=%d casts=%d view=%s" % [path, node.world.tick, node.paid_casts, JSON.stringify(node._chemistry_practice_view())])
	return true


func fail(message: String) -> void:
	push_error(message)
	quit(1)

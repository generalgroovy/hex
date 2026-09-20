extends SceneTree

const SIZE := Vector2i(1280, 720)
var output := ""
var viewport: SubViewport


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/chemistry-counter-v1/render-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a new --output=res://.godot/chemistry-counter-v1/render-NAME")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot create isolated counter evidence directory")
		return
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for blocked: bool in [false, true]:
		var sheet := CounterSheet.new()
		if not sheet.configure_counter(blocked, true) or not sheet.build_counter() or not sheet.place_target(sheet.overlap_point):
			fail("Real paid-cast counter capture failed: " + sheet.failure)
			sheet.free()
			return
		viewport.add_child(sheet)
		var stage := "worldbone" if blocked else "overlap"
		if not await capture_stage(sheet, stage, true):
			return
		if not blocked:
			if not sheet.place_target(sheet.steam_origin + Vector2i(0, 20_000)) or not sheet.world.step([]):
				fail("Real reveal-tail expiry did not advance")
				return
			if sheet.world.player(2).chemistry_reveal_ticks != 0 or sheet.target_visible():
				fail("Expired reveal must restore Steam concealment")
				return
			if not await capture_stage(sheet, "reveal-expired", false):
				return
		viewport.remove_child(sheet)
		sheet.free()
	print("PASS:5 actual1280x720 frames;4 paid casts per setup;independent Radiance/Steam;overlap/worldbone normal+reduced;expired reveal normal;inherited gameplay/card drawing")
	quit(0)


func capture_stage(sheet: Node2D, stage: String, both: bool) -> bool:
	var modes: Array = [false, true] if both else [false]
	for reduced: bool in modes:
		sheet.fixture_stage = stage
		sheet.requested_capture_reduced_effects = reduced
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var path := output.path_join(stage + ("-reduced" if reduced else "-normal") + ".png")
		if rendered == null or rendered.get_size() != SIZE or rendered.save_png(path) != OK:
			fail("Failed actual counter render: " + stage)
			return false
		print("RENDERED %s tick=%d reveal=%d conceal=%d target_visible=%s view=%s" % [path, sheet.world.tick, sheet.world.player(2).chemistry_reveal_ticks, sheet.world.player(2).chemistry_conceal_ticks, sheet.target_visible(), JSON.stringify(sheet._chemistry_practice_view())])
	return true


func fail(message: String) -> void:
	push_error(message)
	quit(1)


class CounterSheet:
	extends "res://tests/support/chemistry_counter_harness.gd"
	var fixture_stage := ""


	func _draw() -> void:
		super._draw() # Existing gameplay material, actor visibility and coach card.
		# This small worldbone rectangle is authored only by the test collision
		# fixture, so identify it explicitly; it is not in the campus art/map.
		var camera := _camera_origin(current_position)
		for wall: CollisionWorld.Obstacle in world.collision.obstacle_view():
			if wall.obstacle_id != 990:
				continue
			var rectangle := Rect2(Vector2(wall.minimum_x, wall.minimum_y) / 1000.0 - camera, Vector2(wall.maximum_x - wall.minimum_x, wall.maximum_y - wall.minimum_y) / 1000.0)
			draw_rect(rectangle, Color("373e48"))
			draw_rect(rectangle, Color("c3bba0"), false, 1.0)
		var spent := 0
		for receipt: Dictionary in cast_receipts:
			spent += int(receipt.spent)
		var note := "PAID COUNTER FIXTURE / %s / %d casts, %.0f Flux / target reveal=%d; chemistry-visible=%s" % [fixture_stage.to_upper(), cast_receipts.size(), float(spent) / 1000.0, world.player(2).chemistry_reveal_ticks, target_visible()]
		draw_rect(Rect2(20, 592, 1240, 56), Color("101820ed"))
		draw_string(ThemeDB.fallback_font, Vector2(32, 614), note, HORIZONTAL_ALIGNMENT_LEFT, 1216, 14, Color("e2d8b2"))
		draw_string(ThemeDB.fallback_font, Vector2(32, 635), "Two independent recipes. Target position is staged; the marked worldbone is test-only. Not a human playthrough.", HORIZONTAL_ALIGNMENT_LEFT, 1216, 12, Color("b6a477"))

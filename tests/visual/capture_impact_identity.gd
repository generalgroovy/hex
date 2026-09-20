extends SceneTree


# Actual live impact renderer vs its preserved previous one-stamp path.
# Diagnostic comparison only: not a hit radius, spell preview or played match.
const SIZE := Vector2i(1280, 960)


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/impact-identity-v1/render-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/impact-identity-v1/render-NAME directory")
		quit(1)
		return
	var sheet := ImpactSheet.new()
	if not sheet.pixels.ready() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Could not configure existing impact pixel assets")
		sheet.free()
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(sheet)
	var jobs: Array[Dictionary] = []
	for reduced: bool in [false, true]:
		for zoom: int in [50, 75, 100]:
			jobs.append({"reduced": reduced, "zoom": zoom, "weights": false, "empty_budget": false})
		jobs.append({"reduced": reduced, "zoom": 100, "weights": true, "empty_budget": false})
		jobs.append({"reduced": reduced, "zoom": 100, "weights": false, "empty_budget": true})
	for job: Dictionary in jobs:
		sheet.job = job
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var name := "%s-%d%s%s" % ["reduced" if job.reduced else "normal", job.zoom, "-weights" if job.weights else "", "-zero-budget" if job.empty_budget else ""]
		var path := output.path_join(name + ".png")
		var rendered := viewport.get_texture().get_image()
		if rendered == null or rendered.get_size() != SIZE or rendered.save_png(path) != OK:
			push_error("Actual impact comparison capture failed")
			quit(1)
			return
		print("RENDERED %s | optional=%s" % [path, sheet.pixels.library.decoration_stats()])
	print("PASS: 10 actual 1280x960 before/after sheets; eight element silhouettes, 50/75/100 percent zoom, normal/reduced, three ages, family sizes, zero budget")
	quit(0)


class ImpactSheet:
	extends Node2D
	var pixels := PixelSpellEffects.new()
	var job := {"reduced": false, "zoom": 100, "weights": false, "empty_budget": false}


	func _draw() -> void:
		var reduced: bool = job.reduced
		var zoom := float(job.zoom) / 100.0
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("182528"))
		label(Vector2(24, 30), "FLUX / ELEMENT CONTACT IMPRINT / %s / %d%% WORLD ZOOM" % ["REDUCED" if reduced else "NORMAL", job.zoom], 22)
		label(Vector2(24, 57), "Existing pixels only. BEFORE = previous breakup; AFTER = live contact imprint. " + ("Family weights on dark background." if job.weights else "Dark and campus-light backgrounds."), 15)
		var columns: Array = ["RAPID / 6px / tick 3", "BOLT / 10.8px / tick 3", "HEAVY / 19.2px / tick 3"] if job.weights else ["TICK 0 / CONTACT", "TICK 5 / COLLAPSE", "TICK 16 / ORIGINAL BREAKUP"]
		for index: int in range(3):
			label(Vector2(162 + index * 362, 86), columns[index], 14)
			label(Vector2(199 + index * 362, 108), "BEFORE                  AFTER", 11)
		pixels.library.begin_frame(reduced)
		if job.empty_budget:
			for element: String in pixels.ELEMENTS:
				for unused: int in range(100):
					pixels.library.take_decoration(pixels.asset_id(element, "field_tile", reduced))
		for row: int in range(8):
			var element: String = pixels.ELEMENTS[row]
			var y := 123.0 + float(row) * 91.0
			label(Vector2(20, y + 47), element.to_upper(), 14, pixels.material_color(element, 4))
			for column: int in range(3):
				var x := 148.0 + float(column) * 362.0
				draw_rect(Rect2(x, y, 345, 84), Color("243733"))
				if not job.weights:
					draw_rect(Rect2(x, y + 42, 345, 42), Color("aaa58f"))
				var age: int = 3 if job.weights else [0, 5, 16][column]
				var radius: float = [6.0, 10.8, 19.2][column] if job.weights else 10.8
				for background: int in range(1 if job.weights else 2):
					var centre := Vector2(x + 96.0, y + (42.0 if job.weights else 22.0 + float(background) * 42.0))
					var previous := pixels.impact_profile(element, radius, reduced)
					draw_set_transform(centre, 0.0, Vector2.ONE * zoom)
					pixels.library.draw_stamp(self, previous.asset_id, Vector2.ZERO, age, 0.0, previous.opacity, previous.scale)
					draw_set_transform(centre + Vector2(164, 0), 0.0, Vector2.ONE * zoom)
					pixels.impact(self, element, Vector2.ZERO, age, reduced, radius)
					draw_set_transform(Vector2.ZERO)
		label(Vector2(24, 885), "Imprint ends at 12/120s. Original one-shot is the lifetime gate. Stationary stamp only; no new damage, geometry, range ring or particle stream.", 15)
		label(Vector2(24, 913), "Opening: one guaranteed identity stamp + at most one budgeted breakup. Zero budget retains identity; later breakup stays unchanged.", 15)
		label(Vector2(24, 941), "Explicit renderer comparison, not a match. %sOptional stamp use: %s" % ["OPTIONAL BUDGET EXHAUSTED. " if job.empty_budget else "", pixels.library.decoration_stats()], 13)


	func label(at: Vector2, value: String, size: int, color: Color = Color("e9ddbc")) -> void:
		draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

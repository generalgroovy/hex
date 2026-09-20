extends SceneTree


# Actual campus draw calls at a fixed 120 Hz phase. This diagnostic compares
# startup-only cleanup without actor/UI clocks obscuring the map pixels.
func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/cleanup-20260908/campus-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/cleanup-20260908/campus-NAME")
		quit(1)
		return
	var sheet := CampusSheet.new()
	if not sheet.configure() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Campus capture configuration failed")
		sheet.free()
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = sheet.layout.canvas_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(sheet)
	for reduced: bool in [false, true]:
		sheet.reduced = reduced
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var name := "reduced" if reduced else "normal"
		if rendered == null or rendered.get_size() != sheet.layout.canvas_size or rendered.save_png(output.path_join(name + ".png")) != OK:
			push_error("Campus fixture failed real rendering")
			quit(1)
			return
		rendered.convert(Image.FORMAT_RGBA8)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(rendered.get_data())
		print("CAMPUS_RGBA %s %s" % [name, hash.finish().hex_encode()])
	print("PASS: actual %dx%d campus, normal/reduced, fixed tick 120; map %s" % [sheet.layout.canvas_size.x, sheet.layout.canvas_size.y, sheet.layout.content_hash])
	quit(0)


class CampusSheet:
	extends Node2D
	var renderer := SanctumCampusRenderer.new()
	var language := VisualLanguage.new()
	var layout := SanctumCampusLayout.new()
	var reduced := false


	func configure() -> bool:
		return language.load_from_file() and layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json") and renderer.configure(language) and renderer.configure_campus(layout)


	func _draw() -> void:
		renderer.draw(self, layout, 120, Vector2(layout.spawn), reduced)

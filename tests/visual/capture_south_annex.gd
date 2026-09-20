extends SceneTree


# Real production campus rendering; output must be new and separate from old
# evidence. This proves map presentation, not human traversal or player feel.
func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/south-annex-capture-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/south-annex-capture-NAME")
		quit(1)
		return
	var sheet := AnnexSheet.new()
	if not sheet.configure() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("South annex capture could not configure the real campus")
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
		var name := "overview-reduced" if reduced else "overview-normal"
		if not _save_viewport(viewport, output.path_join(name + ".png"), sheet.layout.canvas_size):
			quit(1)
			return
	viewport.size = Vector2i(1280,720)
	sheet.position = Vector2(0,-1504)
	sheet.reduced = false
	sheet.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if not _save_viewport(viewport, output.path_join("annex-native.png"), Vector2i(1280,720)):
		quit(1)
		return
	print("PASS: actual3072x2304 campus normal/reduced and native southern wall view; map ", sheet.layout.content_hash)
	quit(0)


func _save_viewport(viewport: SubViewport, path: String, expected_size: Vector2i) -> bool:
	var image := viewport.get_texture().get_image()
	if image == null or image.get_size() != expected_size or image.save_png(path) != OK:
		push_error("South annex capture failed real render readback")
		return false
	image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	print("SOUTH_ANNEX_RGBA %s %s" % [path.get_file(), hash.finish().hex_encode()])
	return true


class AnnexSheet:
	extends Node2D
	var renderer := SanctumCampusRenderer.new()
	var language := VisualLanguage.new()
	var layout := SanctumCampusLayout.new()
	var reduced := false

	func configure() -> bool:
		return language.load_from_file() and layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json") and renderer.configure(language) and renderer.configure_campus(layout)

	func _draw() -> void:
		renderer.draw(self, layout, 120, Vector2(560,1856), reduced)

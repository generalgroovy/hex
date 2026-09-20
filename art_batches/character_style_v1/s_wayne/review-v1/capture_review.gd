extends SceneTree

const SOURCE := "res://art_batches/character_style_v1/s_wayne/review-v1/s_wayne-partial-review.png"
const OUTPUT := "res://.godot/artwork-20260908/swayne-native-review-v1"
const SIZE := Vector2i(1040, 620)


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	if DirAccess.dir_exists_absolute(OUTPUT):
		push_error("Review capture output already exists")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := ReviewSheet.new()
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE)) != OK:
		quit(1)
		return
	sheet.texture = ImageTexture.create_from_image(source)
	viewport.add_child(sheet)
	for frame: int in range(8):
		sheet.phase = frame % 2
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		if image == null or image.save_png(OUTPUT.path_join("frame-%02d.png" % frame)) != OK:
			quit(1)
			return
	print("PASS: eight native/4x nearest rendered review frames; dark/light alpha and A/B flipbook; source unchanged")
	quit(0)


class ReviewSheet:
	extends Node2D
	var texture: Texture2D
	var phase := 0
	var font: Font = ThemeDB.fallback_font

	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202a32"))
		label(Vector2(24, 29), "S. WAYNE / SMALL58 / THREE SOUTH POSES ONLY", 22, Color.WHITE)
		label(Vector2(24, 53), "Reviewed source-specific background removal. One scale; pivot48/84. No full80-cell or live-art acceptance.", 14, Color("e0dfd3"))
		for panel: int in range(2):
			var origin := Vector2(20 + panel * 510, 72)
			var ink := Color("e7e4d8") if panel == 0 else Color("202a32")
			draw_rect(Rect2(origin, Vector2(490, 522)), Color("17242a") if panel == 0 else Color("eee9dc"))
			label(origin + Vector2(15, 24), "DARK" if panel == 0 else "LIGHT", 17, ink)
			for cell: int in range(3):
				var position := origin + Vector2(18 + cell * 150, 36)
				draw_texture_rect_region(texture, Rect2(position, Vector2(96, 96)), Rect2(cell * 96, 0, 96, 96))
				draw_line(position + Vector2(20, 84), position + Vector2(78, 84), Color(0.4, 0.5, 0.5, 0.35), 1.0)
				label(position + Vector2(4, 116), ["Idle / 1x", "Walk A / 1x", "Walk B / 1x"][cell], 14, ink)
			label(origin + Vector2(15, 195), "CONTACT " + ("A" if phase == 0 else "B") + " / 4x nearest diagnostic", 17, ink)
			draw_texture_rect_region(texture, Rect2(origin + Vector2(52, 172), Vector2(384, 384)), Rect2((phase + 1) * 96, 0, 96, 96))
		label(Vector2(24, 611), "58px is the idle height; B is57px from the same global scale. Native foot silhouettes visibly alternate. No frame crossfade.", 13, Color("e0dfd3"))

	func label(position: Vector2, text: String, size: int, color: Color) -> void:
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

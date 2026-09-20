extends SceneTree

const SOURCE := "res://art_batches/character_style_v1/s_wayne/review-v4/"
const OUTPUT := "res://.godot/artwork-20260908/swayne-twelve-native-v1.png"
const SIZE := Vector2i(1280, 824)

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite proof")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Sheet.new()
	sheet.manifest = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "manifest.json"))
	var image := Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE + "s_wayne-partial-review.png"))
	sheet.texture = ImageTexture.create_from_image(image)
	viewport.add_child(sheet)
	await process_frame
	await RenderingServer.frame_post_draw
	var captured := viewport.get_texture().get_image()
	if captured == null or captured.save_png(OUTPUT) != OK:
		quit(1)
		return
	print("PASS: twelve native1x/2x source-registered review cells rendered ", OUTPUT)
	quit(0)

class Sheet:
	extends Node2D
	var manifest: Dictionary
	var texture: Texture2D
	var font: Font = ThemeDB.fallback_font

	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202a32"))
		label(Vector2(18, 29), "S. WAYNE / SMALL58 / 12 OF80 REVIEW CELLS / NOT LIVE", 23, Color.WHITE)
		label(Vector2(18, 54), "All8 idle headings + south/east A/B contacts. Each card: native1x dark / 2x nearest light. One global scale, shared48/84 pivot.", 14, Color("deded2"))
		for index: int in range(manifest.frames.size()):
			var frame: Dictionary = manifest.frames[index]
			var origin := Vector2((index % 4) * 320, 72 + floori(index / 4.0) * 244)
			draw_rect(Rect2(origin + Vector2(3, 3), Vector2(105, 238)), Color("142129"))
			draw_rect(Rect2(origin + Vector2(109, 3), Vector2(208, 238)), Color("eeeadf"))
			label(origin + Vector2(8, 23), String(frame.state).to_upper().replace("_B", " B") + " / " + String(frame.direction).replace("south", "S").replace("north", "N").replace("east", "E").replace("west", "W").replace("_", ""), 14, Color("90c9c4"))
			var values: Array = frame.output_region
			var region := Rect2(values[0], values[1], values[2], values[3])
			draw_texture_rect_region(texture, Rect2(origin + Vector2(6, 105), Vector2(96, 96)), region)
			draw_texture_rect_region(texture, Rect2(origin + Vector2(117, 28), Vector2(192, 192)), region)
		label(Vector2(18, 820), "Technical masks retained. Direction/anatomy/contact review remains separate from full80-cell gameplay-art acceptance. Original source pixels are immutable.", 13, Color("deded2"))

	func label(at: Vector2, text: String, size: int, color: Color) -> void:
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

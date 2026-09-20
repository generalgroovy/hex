extends SceneTree
var source := "res://art_batches/character_style_v1/fluup/candidate-v1/"
var output := "res://.godot/artwork-20260908/fluup-complete-native-v1/"
const SIZE := Vector2i(1040, 1100)
func _initialize() -> void:
	root.hide()
	for argument: String in OS.get_cmdline_user_args():
		var value := argument.get_slice("=", 1)
		if not value.is_valid_filename() or value.contains(".."):
			quit(1)
			return
		if argument.begins_with("--candidate="):
			source = "res://art_batches/character_style_v1/fluup/" + value + "/"
		elif argument.begins_with("--tag="):
			output = "res://.godot/artwork-20260908/" + value + "/"
		else:
			quit(1)
			return
	_run.call_deferred()
func _run() -> void:
	if DirAccess.dir_exists_absolute(output):
		push_error("Refusing to overwrite native evidence")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := Sheet.new()
	var image := Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes(source + "fluup.png"))
	sheet.texture = ImageTexture.create_from_image(image)
	viewport.add_child(sheet)
	for index: int in range(10):
		sheet.mode = 0 if index < 2 else 1
		sheet.light = index == 1
		sheet.phase = (index - 2) % 2
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var filename := ("sheet-light.png" if index == 1 else "sheet-dark.png") if index < 2 else "gait-%02d.png" % (index - 2)
		if viewport.get_texture().get_image().save_png(output + filename) != OK:
			push_error("Capture failed")
			quit(1)
			return
	print("PASS: actual Godot RGBA native80-cell sheets and8 contact frames: ", output)
	quit(0)
class Sheet:
	extends Node2D
	var texture: Texture2D
	var mode := 0
	var light := false
	var phase := 0
	var font: Font = ThemeDB.fallback_font
	const STATES := ["grounded", "jump", "cast", "hit", "walk A", "sprint A", "slide", "roll", "walk B", "sprint B"]
	const DIRS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var bg := Color("ede9df") if light else Color("16242c")
		var fg := Color("26343b") if light else Color("deded1")
		draw_rect(Rect2(Vector2.ZERO, SIZE), bg)
		text(Vector2(20, 30), "FLUUP / LARGE76 / 80-CELL REVIEW / GAIT NOT APPROVED", 21, fg)
		text(Vector2(20, 55), "Original pixel source; one global scale; actual occupied feet baseline84. Native1x, no sprite filtering.", 14, fg)
		if mode == 0:
			for column: int in range(8):
				text(Vector2(160 + column * 108, 83), DIRS[column], 17, fg)
			for row: int in range(10):
				text(Vector2(15, 151 + row * 99), STATES[row], 15, fg)
				for column: int in range(8):
					var at := Vector2(125 + column * 108, 90 + row * 99)
					draw_rect(Rect2(at, Vector2(96, 96)), Color("e2e0d7") if light else Color("243943"))
					draw_line(at + Vector2(15, 84), at + Vector2(81, 84), Color(0.4, 0.65, 0.6, 0.32), 1.0)
					draw_texture_rect_region(texture, Rect2(at, Vector2(96, 96)), Rect2(column * 96, row * 96, 96, 96))
		else:
			text(Vector2(20, 86), "WALK / SPRINT A-B comparison. Each card native1x left and nearest2x right. No runtime interpolation.", 15, fg)
			for group: int in range(4):
				var running := group >= 2
				var second_half := group % 2 == 1
				var row: int = (9 if phase == 1 else 5) if running else (8 if phase == 1 else 4)
				for col: int in range(4):
					var direction: int = col + (4 if second_half else 0)
					var at := Vector2(8 + col * 258, 105 + group * 246)
					text(at + Vector2(6, 18), ("SPRINT" if running else "WALK") + " " + DIRS[direction] + (" B" if phase else " A"), 16, fg)
					var source := Rect2(direction * 96, row * 96, 96, 96)
					draw_texture_rect_region(texture, Rect2(at + Vector2(3, 112), Vector2(96, 96)), source)
					draw_texture_rect_region(texture, Rect2(at + Vector2(75, 27), Vector2(192, 192)), source)
	func text(at: Vector2, value: String, size: int, color: Color) -> void:
		draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)



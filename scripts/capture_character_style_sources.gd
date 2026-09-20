extends SceneTree

# Diagnostic view of unchanged source regions; deliberately keeps opaque matte.
const SIZE := Vector2i(1030, 1140)
const OUTPUT := "res://.godot/artwork-20260908/oh-tipi-source-proof-v1.png"
const SPEC := "res://art_batches/character_style_v1/oh_tipi/source-layout-v1.json"


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Refusing to overwrite existing source proof")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := SourceSheet.new()
	sheet.configure()
	viewport.add_child(sheet)
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	if rendered == null or rendered.get_size() != SIZE or rendered.save_png(OUTPUT) != OK:
		push_error("Source proof capture failed")
		quit(1)
		return
	print("PASS: raw-source80-cell review rendered ", OUTPUT, "; matte unchanged; not an accepted runtime atlas")
	quit(0)


class SourceSheet:
	extends Node2D
	const Base := preload("res://reference/art/neutral_body_templates_v1/build_pack.gd")
	var pages: Array[Dictionary] = []
	var font: Font = ThemeDB.fallback_font

	func configure() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
		for page: Dictionary in spec.pages:
			var image := Image.new()
			image.load_png_from_buffer(FileAccess.get_file_as_bytes(page.path))
			pages.append({"texture": ImageTexture.create_from_image(image), "spec": page})

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202932"))
		label(Vector2(24, 30), "OH TIPI / RAW SOURCE REVIEW / NOT RUNTIME ART", 23)
		label(Vector2(24, 56), "80 planned cells. Original matte retained. One display scale after page-width normalization; no per-pose fitting.", 14)
		label(Vector2(24, 78), "FAIL: opaque, nonuniform magenta. PENDING: true opposite-foot contacts, anatomy and precise heading consistency.", 14)
		for direction: int in range(8):
			label(Vector2(151 + direction * 106, 110), ["S", "SE", "E", "NE", "N", "NW", "W", "SW"][direction], 16)
		for state: int in range(10):
			label(Vector2(16, 180 + state * 98), Base.STATES[state], 15)
		for page: Dictionary in pages:
			var normalization := 313.5 / float(page.spec.reference_cell_width)
			for cell: Dictionary in page.spec.cells:
				var values: Array = cell.rect
				var region := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
				var size := region.size * normalization * 0.24
				var column: int = Base.DIRECTIONS.find(cell.direction)
				var row: int = Base.STATES.find(cell.state)
				var origin := Vector2(125 + column * 106, 120 + row * 98)
				draw_rect(Rect2(origin, Vector2(96, 96)), Color("33414b"))
				draw_texture_rect_region(page.texture, Rect2(origin + Vector2((96 - size.x) / 2.0, 94 - size.y), size), region)
		label(Vector2(24, 1124), "Source regions are provisional. This diagnostic does not certify native foot registration, transparency, facing or animation.", 13)

	func label(position: Vector2, text: String, size: int) -> void:
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("e4e4d7"))

extends SceneTree

# Read-only source extraction and nearest enlargement; never paints source pixels.
func _initialize() -> void:
	var source_path := "res://art_batches/character_style_v1/red_baron/candidate-v2/red_baron.png"
	var target_path := "res://art_batches/character_style_v1/red_baron/walk-sn-a-reference-6x.png"
	if FileAccess.file_exists(target_path):
		push_error("Refusing to overwrite the reference.")
		quit(2)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path)) != OK or source.get_size() != Vector2i(768, 960):
		push_error("Expected the unchanged complete96px-cell v2 source.")
		quit(2)
		return
	var pair := Image.create(192, 96, false, Image.FORMAT_RGBA8)
	pair.blit_rect(source, Rect2i(0, 384, 96, 96), Vector2i.ZERO)
	pair.blit_rect(source, Rect2i(384, 384, 96, 96), Vector2i(96, 0))
	pair.resize(1152, 576, Image.INTERPOLATE_NEAREST)
	if pair.save_png(target_path) != OK:
		push_error("Could not save exact technical reference crop.")
		quit(2)
		return
	print("PASS: exact SOUTH/NORTH walk A crops, nearest6x only; source unchanged.")
	quit(0)

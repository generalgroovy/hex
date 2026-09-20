extends SceneTree

func _initialize() -> void:
	var path := "res://art_batches/character_style_v1/biggy_bob/candidate-v1/biggy_bob.png"
	var output := "res://art_batches/character_style_v1/biggy_bob/north-reference-4x.png"
	if FileAccess.file_exists(output):
		quit(2)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		quit(2)
		return
	var reference := Image.create(192, 96, false, Image.FORMAT_RGBA8)
	reference.blit_rect(source, Rect2i(384, 0, 96, 96), Vector2i.ZERO)
	reference.blit_rect(source, Rect2i(384, 480, 96, 96), Vector2i(96, 0))
	reference.resize(768, 384, Image.INTERPOLATE_NEAREST)
	if reference.save_png(output) != OK:
		quit(2)
		return
	print("PASS: exact north grounded / sprintA reference crops, nearest4x only.")
	quit(0)

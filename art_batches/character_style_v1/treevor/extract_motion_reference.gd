extends SceneTree

func _initialize() -> void:
	var source_path := "res://art_batches/character_style_v1/treevor/core-review-v1/treevor_mason-partial-review.png"
	var output := "res://art_batches/character_style_v1/treevor/grounded-eight-reference-4x.png"
	if FileAccess.file_exists(output) or FileAccess.get_sha256(source_path) != "6ec208e94e4b8260ebf8e383bc4b28084128226a42dbb5109eabb6f040d48390":
		quit(2)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path)) != OK:
		quit(2)
		return
	var reference := Image.create(192, 384, false, Image.FORMAT_RGBA8)
	for direction: int in range(8):
		reference.blit_rect(source, Rect2i(direction * 96, 0, 96, 96), Vector2i(direction % 2, floori(float(direction) / 2.0)) * 96)
	reference.resize(768, 1536, Image.INTERPOLATE_NEAREST)
	if reference.save_png(output) != OK:
		quit(2)
		return
	print("PASS: exact eight grounded direction crops, 2x4 arrangement at nearest4x; no source pose changes.")
	quit(0)

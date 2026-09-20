extends SceneTree

func _initialize() -> void:
	var source_path := "res://art_batches/character_style_v1/treevor/core-walk-review-v1/treevor_mason-partial-review.png"
	var output := "res://art_batches/character_style_v1/treevor/eight-reference-corrected-back-4x.png"
	if FileAccess.file_exists(output) or FileAccess.get_sha256(source_path) != "20bbdcdc9475bbb9697d75f3acbc6835e177fa67e46d9ed6b01aea9cbf7f4d49":
		quit(2)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path)) != OK:
		quit(2)
		return
	var reference := Image.create(192, 384, false, Image.FORMAT_RGBA8)
	for direction: int in range(8):
		var row := 4 if direction == 4 else 0
		reference.blit_rect(source, Rect2i(direction * 96, row * 96, 96, 96), Vector2i(direction % 2, floori(float(direction) / 2.0)) * 96)
	reference.resize(768, 1536, Image.INTERPOLATE_NEAREST)
	if reference.save_png(output) != OK:
		quit(2)
		return
	print("PASS: exact eight identity crops with true-back north from walkA, nearest4x; no new pose synthesis.")
	quit(0)

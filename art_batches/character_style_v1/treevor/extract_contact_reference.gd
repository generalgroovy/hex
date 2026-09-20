extends SceneTree

func _initialize() -> void:
	var path := "res://art_batches/character_style_v1/treevor/candidate-v1/treevor_mason.png"
	var output := "res://art_batches/character_style_v1/treevor/contact-reference-three-4x.png"
	if FileAccess.file_exists(output) or FileAccess.get_sha256(path) != "a9c950b3942d2ee60720eee7d5571de5ff1097007a7ed679ac0194c165c5e124":
		quit(2)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		quit(2)
		return
	var result := Image.create(288, 96, false, Image.FORMAT_RGBA8)
	var positions := [Vector2i(0, 4), Vector2i(4, 4), Vector2i(0, 5)]
	for column: int in range(3):
		result.blit_rect(source, Rect2i(positions[column] * 96, Vector2i(96, 96)), Vector2i(column * 96, 0))
	result.resize(1152, 384, Image.INTERPOLATE_NEAREST)
	if result.save_png(output) != OK:
		quit(2)
		return
	print("PASS: exact SouthWalkA, NorthWalkA, SouthSprintA cells; nearest4x only.")
	quit(0)

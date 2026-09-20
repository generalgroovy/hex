extends SceneTree

# Exact candidate crops for the final contact repair; no pose editing or fitting.
func _initialize() -> void:
	var source_path := "res://art_batches/character_style_v1/biggy_bob/candidate-v2-north-repair/biggy_bob.png"
	var output := "res://art_batches/character_style_v1/biggy_bob/final-repair-reference-3x.png"
	if FileAccess.file_exists(output) or FileAccess.get_sha256(source_path) != "bba1f89ded22f654d95d4622640ee92e7ec65063af3de2776f97e3fe27d6eece":
		quit(2)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path)) != OK:
		quit(2)
		return
	var result := Image.create(576, 288, false, Image.FORMAT_RGBA8)
	var directions := [1, 2, 3, 5, 6, 7]
	for column: int in range(6):
		result.blit_rect(source, Rect2i(directions[column] * 96, 4 * 96, 96, 96), Vector2i(column * 96, 0))
		result.blit_rect(source, Rect2i(directions[column] * 96, 5 * 96, 96, 96), Vector2i(column * 96, 96))
	result.blit_rect(source, Rect2i(0, 5 * 96, 96, 96), Vector2i(0, 192))
	result.blit_rect(source, Rect2i(0, 0, 96, 96), Vector2i(96, 192))
	result.resize(1728, 864, Image.INTERPOLATE_NEAREST)
	if result.save_png(output) != OK:
		quit(2)
		return
	print("PASS: 14 exact candidate reference crops in a 6x3 board, nearest3x; remaining4 cells blank.")
	quit(0)

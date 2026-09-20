extends SceneTree

func _initialize() -> void:
	var path := "res://art_batches/character_style_v1/biggy_bob/candidate-v2-north-repair/biggy_bob.png"
	var pixels := Image.new()
	if pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		push_error("Could not read candidate PNG.")
		quit(2)
		return
	var presenter := CartoonChampionPresenter.new()
	if not presenter._validate_override_pixels(pixels, 68, 83):
		push_error(presenter.last_error)
		quit(2)
		return
	print("PASS: real presenter pixel admission accepts80 Middle cells with binaryalpha, gutters and exact83px feet. No registry or runtime promotion.")
	quit(0)

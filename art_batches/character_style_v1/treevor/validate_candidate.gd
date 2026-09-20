extends SceneTree

func _initialize() -> void:
	var base := Image.new()
	var candidate := Image.new()
	if base.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art_batches/character_style_v1/treevor/candidate-v1/treevor_mason.png")) != OK \
		or candidate.load_png_from_buffer(FileAccess.get_file_as_bytes("res://art_batches/character_style_v1/treevor/candidate-v2-contact-repair/treevor_mason.png")) != OK:
		push_error("Cannot read preserved candidate PNGs.")
		quit(2)
		return
	var presenter := CartoonChampionPresenter.new()
	if not presenter._validate_override_pixels(candidate, 76, 83):
		push_error(presenter.last_error)
		quit(2)
		return
	var changed: Array[int] = []
	for index: int in range(80):
		var region := Rect2i(Vector2i(index % 8, floori(float(index) / 8.0)) * 96, Vector2i(96, 96))
		if base.get_region(region).get_data() != candidate.get_region(region).get_data():
			changed.append(index)
	if changed != [64, 68, 72]:
		push_error("Unexpected modified source cells: " + str(changed))
		quit(2)
		return
	print("PASS: real presenter pixel admission, Large76/feet83/binaryalpha/80cells. Only cells64,68,72 changed; other77 decoded regions byte-identical.")
	print("BOUNDARY: format and exact-region integrity only, not anatomical contacts or live art approval.")
	quit(0)

extends SceneTree

func _initialize() -> void:
	var path := "res://art_batches/character_style_v1/biggy_bob/candidate-v1/biggy_bob.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): path = argument.trim_prefix("--source=")
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		quit(2)
		return
	var names := ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
	for row: int in [4, 8, 5, 9]:
		for column: int in range(8):
			var xs: Array[int] = []
			for x: int in range(96):
				if source.get_pixel(column * 96 + x, row * 96 + 83).a > 0: xs.append(x)
			print("row", row, " ", names[column], " bottom_x=", xs)
	quit(0)

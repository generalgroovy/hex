extends SceneTree

# Exact extracted comparisons: walk A on the left, existing sprint B on the right.
func _initialize() -> void:
	var source_path := "res://art_batches/character_style_v1/red_baron/candidate-v2/red_baron.png"
	var output := "res://art_batches/character_style_v1/red_baron/reuse-review-v1"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://art_batches/character_style_v1/red_baron/reuse-review-") or ".." in output:
		push_error("Comparison output must remain in the isolated Red Baron review folder.")
		quit(2)
		return
	if DirAccess.dir_exists_absolute(output):
		push_error("Refusing to overwrite existing gait comparison.")
		quit(2)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path)) != OK or source.get_size() != Vector2i(768, 960):
		push_error("Expected complete v2 source.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create comparison output.")
		quit(2)
		return
	var directions := {1: "south_east", 2: "east", 3: "north_east", 5: "north_west", 6: "west", 7: "south_west"}
	for index: int in directions:
		var pair := Image.create(192, 96, false, Image.FORMAT_RGBA8)
		pair.blit_rect(source, Rect2i(index * 96, 384, 96, 96), Vector2i.ZERO)
		pair.blit_rect(source, Rect2i(index * 96, 864, 96, 96), Vector2i(96, 0))
		pair.resize(768, 384, Image.INTERPOLATE_NEAREST)
		if pair.save_png(output.path_join(String(directions[index]) + "-walkA-sprintB-4x.png")) != OK:
			push_error("Could not save exact comparison.")
			quit(2)
			return
	print("PASS: six exact left=walkA/right=sprintB pairs, nearest4x only; source unchanged.")
	quit(0)

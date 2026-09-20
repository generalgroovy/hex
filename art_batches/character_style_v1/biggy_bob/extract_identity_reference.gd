extends SceneTree

func _initialize() -> void:
	var source := "res://reference/art/cast_sheet_v4/flux-cast-28-size-bands.png"
	var output := "res://art_batches/character_style_v1/biggy_bob/identity-reference.png"
	if FileAccess.file_exists(output) or FileAccess.get_sha256(source) != "d65c50c558b2f8f6189008cfd3175bb8d21a000bbb0090400a08bdfbfa7e2d63":
		push_error("Refusing an overwritten reference or changed source.")
		quit(2)
		return
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(source)) != OK:
		quit(2)
		return
	# Exact inspected Biggy Bob silhouette crop, with no repaint or rescaling.
	var crop := image.get_region(Rect2i(729, 393, 123, 139))
	if crop.save_png(output) != OK:
		quit(2)
		return
	print("PASS: immutable v4 identity crop [729,393,123,139], no rescaling.")
	quit(0)

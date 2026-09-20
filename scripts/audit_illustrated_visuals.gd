extends SceneTree

# Reproducible pixel audit after Godot import; also builds a reference contact
# sheet directly from the gameplay atlas, never a separate concept drawing.
func _initialize() -> void:
	for path: String in [
		"res://assets/environment/wellspring_v3/surfaces.png",
		"res://assets/environment/wellspring_v3/props.png",
		"res://assets/sprites/champions_v3/foundation/runtime_atlas_eight_v14.png",
	]:
		var texture := load(path) as Texture2D
		var pixels := texture.get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(pixels.get_data())
		print(JSON.stringify({"path": path, "imported_rgba_sha256": hash.finish().hex_encode()}))
	var atlas := Image.new()
	assert(atlas.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/sprites/champions_v3/foundation/runtime_atlas_eight_v14.png")) == OK)
	var contact := Image.create(768, 288, false, Image.FORMAT_RGBA8)
	contact.fill(Color("ccbfa0"))
	for index: int in range(3):
		var champion: int = [1, 0, 2][index]
		for column: int in range(8):
			var state: int = [0, 0, 0, 4, 8, 1, 6, 7][column]
			var direction: int = [0, 2, 4, 1, 1, 1, 1, 1][column]
			contact.blend_rect(atlas, Rect2i(direction * 96, (champion * 10 + state) * 96, 96, 96), Vector2i(column * 96, index * 96))
	contact.resize(1536, 576, Image.INTERPOLATE_NEAREST)
	assert(contact.save_png("res://assets/concept/foundation-proportion-reference-small-to-large-v3.png") == OK)
	for champion: int in range(3):
		var heights: Array = []
		for state: int in range(10):
			var poses: Array = []
			for direction: int in range(8):
				poses.append(atlas.get_region(Rect2i(direction * 96, (champion * 10 + state) * 96, 96, 96)).get_used_rect().size.y)
			heights.append(poses)
		print(JSON.stringify({"champion": champion, "heights": heights}))
	quit(0)

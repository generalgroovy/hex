extends SceneTree


func _initialize() -> void:
	var contact := Image.create(768, 480, false, Image.FORMAT_RGBA8)
	contact.fill(Color("ccbfa0"))
	var walk_contacts := Image.create(1536, 480, false, Image.FORMAT_RGBA8)
	walk_contacts.fill(Color("ccbfa0"))
	var names := ["oh_tipi", "s_wayne", "red_baron", "grace_reava", "wa_bidi"]
	for name: String in names:
		var path := "res://assets/sprites/champions_v3/expansion_v1/" + name + ".png"
		var texture := load(path) as Texture2D
		var pixels := texture.get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(pixels.get_data())
		print(JSON.stringify({"id": name, "path": path, "sha256": FileAccess.get_sha256(path), "imported_rgba_sha256": context.finish().hex_encode()}))
		for direction: int in range(8):
			for phase: int in range(2):
				walk_contacts.blend_rect(pixels, Rect2i(direction * 96, (4 if phase == 0 else 8) * 96, 96, 96), Vector2i((direction * 2 + phase) * 96, names.find(name) * 96))
		for column: int in range(8):
			var state: int = [0, 4, 8, 6, 1, 7, 4, 8][column]
			var direction: int = [0, 0, 0, 0, 0, 0, 2, 2][column]
			contact.blend_rect(pixels, Rect2i(direction * 96, state * 96, 96, 96), Vector2i(column * 96, names.find(name) * 96))
	contact.resize(1536, 960, Image.INTERPOLATE_NEAREST)
	assert(contact.save_png("res://assets/concept/five-champion-motion-reference-v1.png") == OK)
	walk_contacts.resize(3072, 960, Image.INTERPOLATE_NEAREST)
	assert(walk_contacts.save_png("res://.godot/walk-contact-audit.png") == OK)
	var foundation_path := "res://assets/sprites/champions_v3/foundation/runtime_atlas_eight_v15.png"
	var foundation := (load(foundation_path) as Texture2D).get_image()
	foundation.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(foundation.get_data())
	print(JSON.stringify({"id": "foundation", "sha256": FileAccess.get_sha256(foundation_path), "imported_rgba_sha256": hash.finish().hex_encode()}))
	quit(0)

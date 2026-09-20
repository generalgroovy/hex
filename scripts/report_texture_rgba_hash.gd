extends SceneTree


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		printerr("usage: godot --headless --path <repo> --script res://scripts/report_texture_rgba_hash.gd -- <res://texture.png>")
		quit(2)
		return
	var resource_path := String(arguments[0])
	var resource := load(resource_path)
	if not resource is Texture2D:
		printerr("not a Texture2D: %s" % resource_path)
		quit(3)
		return
	var image := (resource as Texture2D).get_image()
	if image == null or image.is_empty():
		printerr("texture has no decoded image: %s" % resource_path)
		quit(4)
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	print("%s %s %dx%d RGBA8" % [resource_path, context.finish().hex_encode(), image.get_width(), image.get_height()])
	quit(0)

extends SceneTree

const SOURCE := "res://assets/sprites/champions_v3/style_v1/jan-wicked-v1.png"
const ROOT := "res://art_batches/character_style_v1/jan_wicked/clear-diagonal-v3/"
const SOURCE_SHA := "a5847208c1cbf9ab2183006b0b918470efba0389207e436c0d2a4c4df3e119b2"

func _initialize() -> void:
	if FileAccess.get_sha256(SOURCE) != SOURCE_SHA or FileAccess.file_exists(ROOT + "front-identity-native.png"):
		push_error("Reference source changed or outputs already exist")
		quit(1)
		return
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE)) != OK:
		quit(1)
		return
	var crop := source.get_region(Rect2i(0, 0, 96, 96))
	if crop.save_png(ROOT + "front-identity-native.png") != OK:
		quit(1)
		return
	crop.resize(768, 768, Image.INTERPOLATE_NEAREST)
	if crop.save_png(ROOT + "front-identity-8x.png") != OK or FileAccess.get_sha256(SOURCE) != SOURCE_SHA:
		quit(1)
		return
	print("PASS: unchanged accepted South-grounded identity crop, source rect0,0,96,96; nearest8x reference only")
	quit(0)

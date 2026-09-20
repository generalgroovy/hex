extends SceneTree


const OUTPUT_ROOT := "res://assets/environment/sanctum_g2/runtime_kit_v1"
const TILE_SIZE := 32

const DEEP_WATER := Color("153c4a")
const FOREST_SHADOW := Color("17261b")
const GARDEN_GREEN := Color("304b27")
const MOSS := Color("66834a")
const WARM_PATH := Color("8b7045")
const PALE_STONE := Color("b6a477")
const WORLDBONE := Color("26282a")
const TIMBER := Color("4b3226")
const BRASS := Color("b88438")
const CYAN := Color("55dbe0")
const ROOF := Color("2d473a")


func _initialize() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_ROOT)
	var error := DirAccess.make_dir_recursive_absolute(output_path)
	if error != OK:
		push_error("Cannot create Sanctum runtime-kit directory: %s" % error_string(error))
		quit(1)
		return
	var modules := {
		"warm-stone-ground": _warm_stone_ground(),
		"worldbone-cliff": _worldbone_cliff(),
		"ordinary-stone-path": _ordinary_stone_path(),
		"deep-water": _deep_water(),
		"garden-edge": _garden_edge(),
		"academy-wall": _academy_wall(),
		"blue-green-roof": _blue_green_roof(),
		"attunement-shrine": _attunement_shrine(),
	}
	for module_id: String in modules:
		var path := "%s/%s.png" % [OUTPUT_ROOT, module_id]
		error = (modules[module_id] as Image).save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("Cannot save %s: %s" % [path, error_string(error)])
			quit(1)
			return
		print("generated ", path)
	quit(0)


func _image(color: Color = Color.TRANSPARENT) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


func _warm_stone_ground() -> Image:
	var image := _image(Color("8d805f"))
	for y: int in range(0, TILE_SIZE, 8):
		image.fill_rect(Rect2i(0, y, TILE_SIZE, 1), Color("71664d"))
	for y: int in range(0, TILE_SIZE, 8):
		var offset := 8 if int(y / 8) % 2 == 1 else 0
		for x: int in range(offset, TILE_SIZE, 16):
			image.fill_rect(Rect2i(x, y, 1, 8), Color("71664d"))
	image.fill_rect(Rect2i(3, 3, 5, 2), PALE_STONE.darkened(0.08))
	image.fill_rect(Rect2i(20, 18, 4, 2), PALE_STONE.darkened(0.12))
	return image


func _worldbone_cliff() -> Image:
	var image := _image(WORLDBONE)
	for y: int in range(4, TILE_SIZE, 8):
		var offset := 0 if int(y / 8) % 2 == 1 else 8
		image.fill_rect(Rect2i(offset, y, 12, 2), Color("4f4a3f"))
		image.fill_rect(Rect2i((offset + 18) % TILE_SIZE, y + 2, 8, 1), Color("3a3b3b"))
	image.fill_rect(Rect2i(15, 7, 2, 18), BRASS.darkened(0.35))
	image.fill_rect(Rect2i(12, 12, 8, 2), BRASS.darkened(0.35))
	return image


func _ordinary_stone_path() -> Image:
	var image := _image(WARM_PATH)
	image.fill_rect(Rect2i(0, 0, TILE_SIZE, 2), PALE_STONE.darkened(0.25))
	image.fill_rect(Rect2i(0, 30, TILE_SIZE, 2), PALE_STONE.darkened(0.35))
	for x: int in range(2, TILE_SIZE, 10):
		image.fill_rect(Rect2i(x, 8 + (int(x / 10) % 2) * 9, 6, 2), PALE_STONE.darkened(0.15))
	return image


func _deep_water() -> Image:
	var image := _image(DEEP_WATER)
	for y: int in range(5, TILE_SIZE, 9):
		var offset := 2 if int(y / 9) % 2 == 1 else 10
		image.fill_rect(Rect2i(offset, y, 12, 2), Color("3a7d87"))
		image.fill_rect(Rect2i((offset + 18) % TILE_SIZE, y + 3, 7, 1), CYAN.darkened(0.45))
	return image


func _garden_edge() -> Image:
	var image := _image(GARDEN_GREEN)
	for position: Vector2i in [Vector2i(4, 7), Vector2i(15, 3), Vector2i(25, 10), Vector2i(9, 23), Vector2i(23, 26)]:
		image.fill_rect(Rect2i(position.x, position.y, 3, 7), FOREST_SHADOW)
		image.fill_rect(Rect2i(position.x - 2, position.y, 7, 3), MOSS)
		image.fill_rect(Rect2i(position.x, position.y - 2, 3, 7), Color("50713a"))
	return image


func _academy_wall() -> Image:
	var image := _image(TIMBER)
	for y: int in range(0, TILE_SIZE, 8):
		image.fill_rect(Rect2i(0, y, TILE_SIZE, 2), Color("76503a"))
	for x: int in range(0, TILE_SIZE, 16):
		image.fill_rect(Rect2i(x, 0, 3, TILE_SIZE), Color("38251d"))
	for position: Vector2i in [Vector2i(5, 4), Vector2i(21, 4), Vector2i(5, 20), Vector2i(21, 20)]:
		image.fill_rect(Rect2i(position, Vector2i(2, 2)), BRASS)
	return image


func _blue_green_roof() -> Image:
	var image := _image(ROOF)
	for y: int in range(0, TILE_SIZE, 8):
		for x: int in range(-4, TILE_SIZE, 8):
			var offset := 4 if int(y / 8) % 2 == 1 else 0
			image.fill_rect(Rect2i(x + offset, y, 7, 5), Color("365a4c"))
			image.fill_rect(Rect2i(x + offset, y + 5, 7, 2), Color("1f342b"))
	return image


func _attunement_shrine() -> Image:
	var image := _image()
	image.fill_rect(Rect2i(5, 25, 22, 5), WORLDBONE)
	image.fill_rect(Rect2i(8, 21, 16, 4), PALE_STONE.darkened(0.2))
	image.fill_rect(Rect2i(12, 9, 8, 13), BRASS.darkened(0.2))
	image.fill_rect(Rect2i(14, 3, 4, 17), CYAN)
	image.fill_rect(Rect2i(10, 6, 12, 3), BRASS)
	image.fill_rect(Rect2i(12, 1, 8, 3), Color(CYAN, 0.65))
	return image

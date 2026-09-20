class_name VisualAssetRegistry
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "res://content/visual/visual_asset_registry_v1.json"

var data: Dictionary = {}
var last_error: String = ""
var skeletons: Dictionary = {}
var champions: Dictionary = {}
var environment: Dictionary = {}
var materials: Dictionary = {}
var icons: Dictionary = {}
var spell_animation_skeletons: Dictionary = {}


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("visual asset registry does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("could not open visual asset registry: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("visual asset registry root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	if int(data.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported visual asset registry schema")
	var contract: Dictionary = data.get("character_contract", {})
	if _vector2i(contract.get("cell_size", [])) != Vector2i(32, 32):
		return _fail("visual character cell must remain 32 x 32")
	if _vector2i(contract.get("pivot", [])) != Vector2i(16, 28):
		return _fail("visual character pivot must remain (16, 28)")
	if (contract.get("directions", []) as Array).size() != 8:
		return _fail("visual character contract requires eight directions")

	skeletons = data.get("skeletons", {})
	champions = data.get("champions", {})
	environment = data.get("environment", {})
	materials = data.get("materials", {})
	icons = data.get("icons", {})
	spell_animation_skeletons = data.get("spell_animation_skeletons", {})
	var spell_manifest_path := str(spell_animation_skeletons.get("manifest", ""))
	if spell_manifest_path.is_empty() or not FileAccess.file_exists(spell_manifest_path):
		return _fail("spell animation skeleton manifest is not registered")
	var spell_library := SpellAnimationSkeletonLibrary.new()
	if not spell_library.load_from_file(spell_manifest_path):
		return _fail("registered spell animation skeleton manifest is invalid: %s" % spell_library.last_error)
	if skeletons.size() != 5:
		return _fail("visual registry requires five skeleton sizes")
	for size_id: String in skeletons:
		var entry: Dictionary = skeletons[size_id]
		if not _validate_image(str(entry.get("clean_atlas", "")), Vector2i(960, 1280), "%s clean atlas" % size_id):
			return false
		if not _validate_image(str(entry.get("debug_atlas", "")), Vector2i(960, 1280), "%s debug atlas" % size_id):
			return false

	if not champions.has("nico_lai"):
		return _fail("Nico Lai integrated candidate is missing")
	var nico: Dictionary = champions["nico_lai"]
	if str(nico.get("status", "")) != "integrated_candidate":
		return _fail("Nico Lai must remain explicitly marked as a candidate")
	if not _validate_image(str(nico.get("atlas", "")), Vector2i(960, 1280), "Nico Lai atlas"):
		return false
	if not _validate_image(str(nico.get("debug_atlas", "")), Vector2i(960, 1280), "Nico Lai debug atlas"):
		return false
	if not _validate_image(str(nico.get("direction_preview", "")), Vector2i(1024, 128), "Nico Lai direction preview"):
		return false

	var sanctum_tiles: Dictionary = environment.get("sanctum_tiles", {})
	if _vector2i(sanctum_tiles.get("tile_size", [])) != Vector2i(16, 16):
		return _fail("Sanctum tile size must be 16 x 16")
	if not _validate_image(str(sanctum_tiles.get("path", "")), Vector2i(256, 256), "Sanctum tile atlas"):
		return false
	var world_slice: Dictionary = environment.get("nexus_to_conservatory", {})
	if not _validate_image(str(world_slice.get("preview", "")), Vector2i(1280, 720), "Nexus-to-Conservatory preview"):
		return false
	if not FileAccess.file_exists(str(world_slice.get("layout", ""))):
		return _fail("Nexus-to-Conservatory layout is missing")

	if not _validate_image(str(materials.get("path", "")), Vector2i(176, 16), "foundation material tiles"):
		return false
	if (materials.get("order", []) as Array).size() != 11:
		return _fail("foundation material tile order must contain eleven entries")
	if not _validate_icon_group("elements", Vector2i(128, 16), 8):
		return false
	if not _validate_icon_group("abilities", Vector2i(192, 32), 6):
		return false
	if not _validate_icon_group("ui_states", Vector2i(192, 16), 12):
		return false
	return true


func champion_atlas_path(champion_id: String, debug: bool = false) -> String:
	if not champions.has(champion_id):
		return ""
	var entry: Dictionary = champions[champion_id]
	return str(entry.get("debug_atlas" if debug else "atlas", ""))


func nexus_preview_path() -> String:
	return str((environment.get("nexus_to_conservatory", {}) as Dictionary).get("preview", ""))


func _validate_icon_group(group_id: String, expected_size: Vector2i, expected_count: int) -> bool:
	if not icons.has(group_id):
		return _fail("icon group is missing: %s" % group_id)
	var entry: Dictionary = icons[group_id]
	if (entry.get("order", []) as Array).size() != expected_count:
		return _fail("%s icon order has the wrong entry count" % group_id)
	return _validate_image(str(entry.get("path", "")), expected_size, "%s icon atlas" % group_id)


func _validate_image(path: String, expected_size: Vector2i, label: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return _fail("%s is missing: %s" % [label, path])
	var image := ImageAssetInspector.load_image(path)
	if image == null:
		return _fail("%s could not be decoded" % label)
	if image.get_size() != expected_size:
		return _fail("%s has size %s; expected %s" % [label, image.get_size(), expected_size])
	if image.is_empty():
		return _fail("%s is empty" % label)
	return true


func _vector2i(value: Variant) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int((value as Array)[0]), int((value as Array)[1]))


func _fail(message: String) -> bool:
	last_error = message
	return false

class_name EnvironmentKitManifest
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 1
const REQUIRED_MODULE_COUNT: int = 12
const CONCEPT_PREFIX: String = "res://assets/concept/"

var data: Dictionary = {}
var last_error: String = ""
var modules_by_id: Dictionary[String, Dictionary] = {}


func load_from_file(path: String) -> bool:
	last_error = ""
	data = {}
	if not FileAccess.file_exists(path):
		return _fail("Environment kit manifest does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Environment kit manifest cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("Environment kit manifest root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	modules_by_id = {}
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("Unsupported environment kit manifest schema")
	if String(data.get("id", "")).is_empty():
		return _fail("Environment kit manifest id is required")
	if String(data.get("status", "")) != "candidate" or bool(data.get("runtime_approved", true)):
		return _fail("Generated environment kit must remain an unapproved candidate")
	if String(data.get("authority", "")) != "presentation-only":
		return _fail("Environment kit cannot own gameplay authority")
	var generator: Dictionary = data.get("generator", {})
	for field: String in ["tool", "created_at", "license_review", "prompt"]:
		if String(generator.get(field, "")).is_empty():
			return _fail("Environment kit provenance is missing: %s" % field)
	if String(generator.get("license_review", "")) != "pending":
		return _fail("Candidate license review must remain explicit until approval")

	var image_contract: Dictionary = data.get("image", {})
	var width := int(image_contract.get("width", 0))
	var height := int(image_contract.get("height", 0))
	var columns := int(image_contract.get("columns", 0))
	var rows := int(image_contract.get("rows", 0))
	if width != 1402 or height != 1122 or columns != 4 or rows != 3:
		return _fail("Environment kit candidate dimensions or grid changed")
	var removed_key: Array = image_contract.get("removed_key_rgb", [])
	if removed_key.size() != 3 or int(removed_key[0]) != 250 or int(removed_key[1]) != 2 or int(removed_key[2]) != 251:
		return _fail("Environment kit chroma-key provenance changed")

	var files: Dictionary = data.get("files", {})
	var source: Dictionary = files.get("source", {})
	var alpha_candidate: Dictionary = files.get("alpha_candidate", {})
	if not _validate_file(source, "source") or not _validate_file(alpha_candidate, "alpha candidate"):
		return false
	var source_image := _load_png(String(source.get("path", "")), "source")
	if source_image == null:
		return false
	var alpha_image := _load_png(String(alpha_candidate.get("path", "")), "alpha candidate")
	if alpha_image == null:
		return false
	if source_image.get_width() != width or source_image.get_height() != height or alpha_image.get_width() != width or alpha_image.get_height() != height:
		return _fail("Environment kit file dimensions do not match the manifest")
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(width - 1, 0), Vector2i(0, height - 1), Vector2i(width - 1, height - 1)]:
		if alpha_image.get_pixelv(corner).a > 0.0:
			return _fail("Environment kit alpha candidate corners must be transparent")
	var transparent_pixels: int = 0
	var visible_pixels: int = 0
	for y: int in height:
		for x: int in width:
			var color := alpha_image.get_pixel(x, y)
			if color.a <= 0.0:
				transparent_pixels += 1
			else:
				visible_pixels += 1
				if color.r > 0.96 and color.g < 0.08 and color.b > 0.96:
					return _fail("Environment kit alpha candidate retains chroma-key pixels")
	if transparent_pixels < 100_000 or visible_pixels < 100_000:
		return _fail("Environment kit alpha coverage is implausible")

	var occupied_slots: Dictionary[String, bool] = {}
	var modules: Array = data.get("modules", [])
	if modules.size() != REQUIRED_MODULE_COUNT:
		return _fail("Environment kit requires exactly twelve candidate modules")
	for value: Variant in modules:
		if not value is Dictionary:
			return _fail("Every environment kit module must be an object")
		var module: Dictionary = value
		var module_id := String(module.get("id", ""))
		var kind := String(module.get("kind", ""))
		var column := int(module.get("column", -1))
		var row := int(module.get("row", -1))
		var slot := "%d:%d" % [column, row]
		if module_id.is_empty() or kind.is_empty() or modules_by_id.has(module_id):
			return _fail("Environment kit module ids and kinds must be non-empty and unique")
		if column < 0 or column >= columns or row < 0 or row >= rows or occupied_slots.has(slot):
			return _fail("Environment kit module grid slots must be valid and unique")
		if not _validate_module_output(module_id, module.get("output", {})):
			return false
		modules_by_id[module_id] = module
		occupied_slots[slot] = true
	if occupied_slots.size() != columns * rows:
		return _fail("Environment kit candidate must fill its declared contact-sheet grid")
	return true


func _validate_module_output(module_id: String, value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("Environment kit module output must be an object: %s" % module_id)
	var output: Dictionary = value
	var path := String(output.get("path", ""))
	var expected_path := "%ssanctum_modular_kit_candidate_v2/%s.png" % [CONCEPT_PREFIX, module_id]
	var expected_hash := String(output.get("sha256", ""))
	var width := int(output.get("width", 0))
	var height := int(output.get("height", 0))
	var pivot: Array = output.get("pivot", [])
	if path != expected_path or not FileAccess.file_exists(path):
		return _fail("Environment kit module output path is invalid: %s" % module_id)
	if expected_hash.length() != 64 or FileAccess.get_sha256(path) != expected_hash:
		return _fail("Environment kit module output hash changed: %s" % module_id)
	var image := _load_png(path, "module %s" % module_id)
	if image == null:
		return false
	if width != image.get_width() or height != image.get_height() or width < 16 or height < 16:
		return _fail("Environment kit module output dimensions changed: %s" % module_id)
	if pivot.size() != 2 or int(pivot[0]) != width / 2 or int(pivot[1]) != height - 4:
		return _fail("Environment kit module presentation pivot changed: %s" % module_id)
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(width - 1, 0), Vector2i(0, height - 1), Vector2i(width - 1, height - 1)]:
		if image.get_pixelv(corner).a > 0.0:
			return _fail("Environment kit module crop lacks transparent padding: %s" % module_id)
	return true


func _validate_file(file_contract: Dictionary, label: String) -> bool:
	var path := String(file_contract.get("path", ""))
	var expected_hash := String(file_contract.get("sha256", ""))
	if not path.begins_with(CONCEPT_PREFIX) or ".." in path or not FileAccess.file_exists(path):
		return _fail("Environment kit %s must remain in the excluded concept boundary" % label)
	if expected_hash.length() != 64 or FileAccess.get_sha256(path) != expected_hash:
		return _fail("Environment kit %s hash does not match provenance" % label)
	return true


func _load_png(path: String, label: String) -> Image:
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if error != OK:
		_fail("Environment kit %s is not a valid PNG" % label)
		return null
	return image


func _fail(message: String) -> bool:
	last_error = message
	return false

class_name SanctumRuntimeKit
extends RefCounted


const MANIFEST_PATH := "res://content/assets/sanctum_runtime_kit_v1.json"
const MODULE_PREFIX := "res://assets/environment/sanctum_g2/runtime_kit_v1/"
const REQUIRED_MODULES := [
	"warm-stone-ground",
	"worldbone-cliff",
	"ordinary-stone-path",
	"deep-water",
	"garden-edge",
	"academy-wall",
	"blue-green-roof",
	"attunement-shrine",
]

var data: Dictionary = {}
var last_error: String = ""
var modules_by_id: Dictionary[String, Dictionary] = {}
var textures_by_id: Dictionary[String, Texture2D] = {}


func load_from_file(path: String = MANIFEST_PATH, load_textures: bool = true) -> bool:
	last_error = ""
	data = {}
	modules_by_id = {}
	textures_by_id = {}
	if not FileAccess.file_exists(path):
		return _fail("Sanctum runtime-kit manifest does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Sanctum runtime-kit manifest cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("Sanctum runtime-kit manifest root must be an object")
	data = parsed
	return validate(load_textures)


func validate(load_textures: bool = true) -> bool:
	last_error = ""
	modules_by_id = {}
	textures_by_id = {}
	if int(data.get("schema_version", 0)) != 1:
		return _fail("Unsupported Sanctum runtime-kit schema")
	if String(data.get("id", "")) != "sanctum-runtime-kit-v1":
		return _fail("Sanctum runtime-kit id changed")
	if String(data.get("status", "")) != "runtime-approved" or not bool(data.get("runtime_approved", false)):
		return _fail("Sanctum runtime kit must have explicit runtime approval")
	if bool(data.get("release_approved", true)):
		return _fail("Sanctum runtime kit cannot claim release approval before packaging gates")
	if String(data.get("authority", "")) != "presentation-only":
		return _fail("Sanctum runtime kit cannot own gameplay authority")
	if not _validate_provenance():
		return false
	if not _validate_pixel_contract():
		return false
	return _validate_modules(load_textures)


func texture(module_id: String) -> Texture2D:
	return textures_by_id.get(module_id)


func module(module_id: String) -> Dictionary:
	return modules_by_id.get(module_id, {})


func _validate_provenance() -> bool:
	var provenance: Dictionary = data.get("provenance", {})
	if String(provenance.get("method", "")) != "deterministic-project-authored-gdscript":
		return _fail("Sanctum runtime-kit provenance method changed")
	if bool(provenance.get("third_party_pixel_inputs", true)) or bool(provenance.get("historical_character_sheets_used_as_pixel_inputs", true)):
		return _fail("Sanctum runtime kit must not contain undeclared third-party or historical-sheet pixels")
	if String(provenance.get("distribution_license", "")) != "pending-project-license":
		return _fail("Sanctum runtime-kit release license status must remain explicit")
	if String(provenance.get("review", "")).is_empty():
		return _fail("Sanctum runtime-kit review evidence is required")
	var generator_path := String(provenance.get("generator_path", ""))
	var generator_hash := String(provenance.get("generator_sha256", ""))
	if generator_path != "res://scripts/generate_sanctum_runtime_kit.gd":
		return _fail("Sanctum runtime-kit generator path is invalid")
	if generator_hash.length() != 64:
		return _fail("Sanctum runtime-kit generator hash changed")
	# Exported GDScript is compiled and remapped, so the source text is not a
	# runtime asset. Validate source provenance in editor/source gates while the
	# release validates the authored manifest and the imported pixel modules.
	if OS.has_feature("editor") and (
		not FileAccess.file_exists(generator_path)
		or canonical_text_sha256(generator_path) != generator_hash
	):
		return _fail("Sanctum runtime-kit generator hash changed")
	return true


static func canonical_text_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var source := FileAccess.get_file_as_string(path).replace("\r\n", "\n").replace("\r", "\n")
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK or hashing.update(source.to_utf8_buffer()) != OK:
		return ""
	return hashing.finish().hex_encode()


func _validate_pixel_contract() -> bool:
	var contract: Dictionary = data.get("pixel_contract", {})
	if int(contract.get("tile_width", 0)) != 32 or int(contract.get("tile_height", 0)) != 32:
		return _fail("Sanctum runtime-kit tile dimensions changed")
	if int(contract.get("world_units_per_pixel", 0)) != 1 or int(contract.get("presentation_scale", 0)) != 1:
		return _fail("Sanctum runtime-kit world/pixel scale changed")
	if not bool(contract.get("integer_scale_only", false)) or String(contract.get("texture_filter", "")) != "nearest" or bool(contract.get("mipmaps", true)):
		return _fail("Sanctum runtime-kit sampling contract changed")
	if int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1)) != 0:
		return _fail("Project canvas texture filtering is not nearest-neighbor")
	if bool(ProjectSettings.get_setting("rendering/textures/default_filters/use_nearest_mipmap_filter", true)):
		return _fail("Project unexpectedly enables nearest-mipmap filtering")
	return true


func _validate_modules(load_textures: bool) -> bool:
	var budgets: Dictionary = data.get("budgets", {})
	var modules: Array = data.get("modules", [])
	if modules.size() != REQUIRED_MODULES.size() or int(budgets.get("module_count", 0)) != REQUIRED_MODULES.size():
		return _fail("Sanctum runtime kit requires exactly eight modules")
	var disk_bytes := 0
	var decoded_bytes := 0
	var source_assets_available := OS.has_feature("editor")
	for value: Variant in modules:
		if not value is Dictionary:
			return _fail("Every Sanctum runtime-kit module must be an object")
		var entry: Dictionary = value
		var module_id := String(entry.get("id", ""))
		var role := String(entry.get("role", ""))
		var path := String(entry.get("path", ""))
		var expected_hash := String(entry.get("sha256", ""))
		var pivot: Array = entry.get("pivot", [])
		if module_id not in REQUIRED_MODULES or modules_by_id.has(module_id) or role.is_empty():
			return _fail("Sanctum runtime-kit module identity is invalid")
		if path != "%s%s.png" % [MODULE_PREFIX, module_id] or not ResourceLoader.exists(path, "Texture2D"):
			return _fail("Sanctum runtime-kit module path is invalid: %s" % module_id)
		if expected_hash.length() != 64:
			return _fail("Sanctum runtime-kit module hash changed: %s" % module_id)
		if source_assets_available and FileAccess.get_sha256(path) != expected_hash:
			return _fail("Sanctum runtime-kit module hash changed: %s" % module_id)
		if pivot.size() != 2 or int(pivot[0]) != 16 or int(pivot[1]) < 16 or int(pivot[1]) > 31:
			return _fail("Sanctum runtime-kit pivot is invalid: %s" % module_id)
		if source_assets_available:
			var image := Image.new()
			if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK or image.get_width() != 32 or image.get_height() != 32 or image.get_format() != Image.FORMAT_RGBA8:
				return _fail("Sanctum runtime-kit PNG contract changed: %s" % module_id)
			disk_bytes += FileAccess.get_file_as_bytes(path).size()
		decoded_bytes += 32 * 32 * 4
		modules_by_id[module_id] = entry
		if load_textures:
			var loaded: Resource = ResourceLoader.load(path, "Texture2D")
			if not loaded is Texture2D or (loaded as Texture2D).get_width() != 32 or (loaded as Texture2D).get_height() != 32:
				return _fail("Sanctum runtime-kit texture import failed: %s" % module_id)
			textures_by_id[module_id] = loaded
	for required_id: String in REQUIRED_MODULES:
		if not modules_by_id.has(required_id):
			return _fail("Sanctum runtime-kit module is missing: %s" % required_id)
	if source_assets_available and (disk_bytes != int(budgets.get("png_disk_bytes", -1)) or disk_bytes > int(budgets.get("maximum_png_disk_bytes", 0))):
		return _fail("Sanctum runtime-kit disk budget changed")
	if decoded_bytes != int(budgets.get("decoded_rgba_bytes", -1)) or decoded_bytes > int(budgets.get("maximum_decoded_rgba_bytes", 0)):
		return _fail("Sanctum runtime-kit decoded-memory budget changed")
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false

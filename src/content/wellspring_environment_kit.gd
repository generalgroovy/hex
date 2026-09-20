class_name WellspringEnvironmentKit
extends RefCounted


const MANIFEST_PATH := "res://content/assets/wellspring_environment_runtime_v2.json"
const MODULE_PREFIX := "res://assets/environment/wellspring_v2/runtime_kit_v2/"
const REQUIRED_MODULES := [
	"quiet-cobblestone", "cardinal-bridge", "worldbone-ledge", "water-channel",
	"academy-facade", "academy-roof", "academy-door", "academy-window",
	"brass-lantern", "garden-planter", "source-fountain", "farflow-portal",
	"training-target", "brass-inlay", "broad-canopy-tree", "flowering-bush",
]

var data: Dictionary = {}
var modules_by_id: Dictionary[String, Dictionary] = {}
var textures_by_id: Dictionary[String, Texture2D] = {}
var content_hash := ""
var last_error := ""


func load_from_file(path: String = MANIFEST_PATH, load_textures: bool = true) -> bool:
	data.clear()
	modules_by_id.clear()
	textures_by_id.clear()
	content_hash = ""
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("Wellspring environment runtime manifest does not exist")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Wellspring environment runtime manifest cannot be opened")
	var source := file.get_as_text()
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Wellspring environment runtime manifest must be an object")
	data = parsed
	if not validate(load_textures):
		data.clear()
		return false
	content_hash = source.sha256_text()
	return true


func validate(load_textures: bool = true) -> bool:
	last_error = ""
	modules_by_id.clear()
	textures_by_id.clear()
	if int(data.get("schema_version", 0)) != 1 \
		or String(data.get("id", "")) != "wellspring-environment-runtime-v2" \
		or String(data.get("status", "")) != "runtime-candidate" \
		or String(data.get("authority", "")) != "presentation-only":
		return _fail("Wellspring environment runtime identity is unsupported")
	if not _validate_provenance() or not _validate_sampling():
		return false
	var budgets: Dictionary = data.get("budgets", {})
	var modules: Array = data.get("modules", [])
	if modules.size() != REQUIRED_MODULES.size() or int(budgets.get("module_count", 0)) != REQUIRED_MODULES.size():
		return _fail("Wellspring environment runtime requires exactly sixteen modules")
	var disk_bytes := 0
	var decoded_bytes := 0
	var source_assets_available := OS.has_feature("editor")
	for value: Variant in modules:
		if not value is Dictionary:
			return _fail("Wellspring environment module must be an object")
		var module: Dictionary = value
		var module_id := String(module.get("id", ""))
		var path := String(module.get("path", ""))
		var width := int(module.get("width", 0))
		var height := int(module.get("height", 0))
		var pivot: Array = module.get("pivot", [])
		if module_id not in REQUIRED_MODULES or modules_by_id.has(module_id) or String(module.get("role", "")).is_empty():
			return _fail("Wellspring environment module identity is invalid")
		if path != "%s%s.png" % [MODULE_PREFIX, module_id] or not ResourceLoader.exists(path, "Texture2D"):
			return _fail("Wellspring environment module path is invalid: %s" % module_id)
		if width < 32 or width > 160 or height < 32 or height > 112 \
			or pivot.size() != 2 or int(pivot[0]) < 0 or int(pivot[0]) > width \
			or int(pivot[1]) < height / 2 or int(pivot[1]) > height:
			return _fail("Wellspring environment module geometry is invalid: %s" % module_id)
		if String(module.get("sha256", "")).length() != 64:
			return _fail("Wellspring environment module hash is invalid: %s" % module_id)
		if source_assets_available:
			if FileAccess.get_sha256(path) != String(module.get("sha256", "")):
				return _fail("Wellspring environment module hash changed: %s" % module_id)
			var image := Image.new()
			if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK \
				or image.get_width() != width or image.get_height() != height or image.get_format() != Image.FORMAT_RGBA8:
				return _fail("Wellspring environment module PNG changed: %s" % module_id)
			disk_bytes += FileAccess.get_file_as_bytes(path).size()
		decoded_bytes += width * height * 4
		modules_by_id[module_id] = module
		if load_textures:
			var loaded: Resource = ResourceLoader.load(path, "Texture2D")
			if not loaded is Texture2D or (loaded as Texture2D).get_size() != Vector2(width, height):
				return _fail("Wellspring environment module import failed: %s" % module_id)
			textures_by_id[module_id] = loaded
	if source_assets_available and (disk_bytes != int(budgets.get("png_disk_bytes", -1)) or disk_bytes > int(budgets.get("maximum_png_disk_bytes", 0))):
		return _fail("Wellspring environment disk budget changed")
	if decoded_bytes != int(budgets.get("decoded_rgba_bytes", -1)) or decoded_bytes > int(budgets.get("maximum_decoded_rgba_bytes", 0)):
		return _fail("Wellspring environment decoded-memory budget changed")
	return true


func texture(module_id: String) -> Texture2D:
	return textures_by_id.get(module_id)


func module(module_id: String) -> Dictionary:
	return modules_by_id.get(module_id, {})


func draw_anchored(canvas: CanvasItem, module_id: String, anchor: Vector2, tint: Color = Color.WHITE, scale_value: float = 1.0) -> bool:
	var image := texture(module_id)
	var contract := module(module_id)
	if canvas == null or image == null or contract.is_empty() or scale_value <= 0.0:
		return false
	var pivot_values: Array = contract.get("pivot", [])
	var pivot := Vector2(float(pivot_values[0]), float(pivot_values[1])) * scale_value
	canvas.draw_texture_rect(image, Rect2(anchor - pivot, image.get_size() * scale_value), false, tint)
	return true


func _validate_provenance() -> bool:
	var provenance: Dictionary = data.get("provenance", {})
	if bool(provenance.get("third_party_pixel_inputs", true)) \
		or String(provenance.get("distribution_license", "")) != "pending-project-license" \
		or String(provenance.get("review", "")).is_empty() \
		or String(provenance.get("source_sha256", "")).length() != 64 \
		or String(provenance.get("generator_sha256", "")).length() != 64:
		return _fail("Wellspring environment provenance is incomplete")
	if OS.has_feature("editor"):
		var source_contract := String(provenance.get("source_contract", ""))
		var generator := String(provenance.get("generator", ""))
		if not FileAccess.file_exists(source_contract) or not FileAccess.file_exists(generator):
			return _fail("Wellspring environment provenance files are missing")
		if FileAccess.get_sha256(generator) != String(provenance.get("generator_sha256", "")):
			return _fail("Wellspring environment generator hash changed")
	return true


func _validate_sampling() -> bool:
	var sampling: Dictionary = data.get("sampling", {})
	if int(sampling.get("world_units_per_pixel", 0)) != 1 \
		or String(sampling.get("texture_filter", "")) != "nearest" \
		or bool(sampling.get("mipmaps", true)):
		return _fail("Wellspring environment sampling contract changed")
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false

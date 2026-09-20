class_name MaterialYardDefinition
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 1
const REQUIRED_WIDTH: int = 128
const REQUIRED_HEIGHT: int = 128
const REQUIRED_SEED_MATERIALS: Array[String] = [
	"worldbone", "stone", "brick", "wood", "water", "oil", "fire", "steam", "ice", "rubble",
]

var data: Dictionary = {}
var last_error: String = ""
var content_hash: String = ""
var width: int = 0
var height: int = 0
var chunk_size: int = 0
var ambient_temperature: int = 0
var max_awake_cells_per_second: int = 0
var material_catalog_hash: String = ""


func load_from_file(path: String, registry: MaterialRegistry) -> bool:
	last_error = ""
	data = {}
	if not FileAccess.file_exists(path):
		return _fail("material yard definition does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("material yard definition cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("material yard root must be an object")
	data = parsed
	return validate(registry)


func validate(registry: MaterialRegistry) -> bool:
	last_error = ""
	content_hash = ""
	material_catalog_hash = ""
	width = int(data.get("width", 0))
	height = int(data.get("height", 0))
	chunk_size = int(data.get("chunk_size", 0))
	ambient_temperature = int(data.get("ambient_temperature", 2_000_001))
	max_awake_cells_per_second = int(data.get("max_awake_cells_per_second", 0))
	if registry == null or not registry.last_error.is_empty() or registry.content_hash.length() != 64:
		return _fail("material yard requires a valid material catalog")
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported material yard schema")
	if String(data.get("id", "")).is_empty():
		return _fail("material yard id is required")
	if String(data.get("material_catalog_id", "")) != String(registry.data.get("id", "")):
		return _fail("material yard catalog id does not match loaded catalog")
	if width != REQUIRED_WIDTH or height != REQUIRED_HEIGHT:
		return _fail("material yard must be exactly 128 x 128 cells")
	if chunk_size <= 0 or width % chunk_size != 0 or height % chunk_size != 0:
		return _fail("material yard chunk size must divide both dimensions")
	if String(data.get("reset_group", "")).is_empty():
		return _fail("material yard reset group is required")
	if ambient_temperature < -1_000_000 or ambient_temperature > 1_000_000:
		return _fail("material yard ambient temperature is outside bounds")
	if max_awake_cells_per_second <= 0 or max_awake_cells_per_second > width * height * 120:
		return _fail("material yard awake-work budget is outside bounds")
	if not bool(data.get("worldbone_perimeter_required", false)):
		return _fail("material yard must require a worldbone perimeter")

	var occupied: Dictionary[int, bool] = {}
	var worldbone_cells: Dictionary[int, bool] = {}
	var seeded_materials: Dictionary[String, bool] = {}
	var seed_rects: Array = data.get("seed_rects", [])
	if seed_rects.is_empty():
		return _fail("material yard needs seed rectangles")
	for value: Variant in seed_rects:
		if not value is Dictionary:
			return _fail("every material seed rectangle must be an object")
		var rectangle: Dictionary = value
		var x := int(rectangle.get("x", -1))
		var y := int(rectangle.get("y", -1))
		var rectangle_width := int(rectangle.get("width", 0))
		var rectangle_height := int(rectangle.get("height", 0))
		var material_id := String(rectangle.get("material", ""))
		if x < 0 or y < 0 or rectangle_width <= 0 or rectangle_height <= 0:
			return _fail("material seed rectangle has invalid geometry")
		if x + rectangle_width > width or y + rectangle_height > height:
			return _fail("material seed rectangle exceeds yard bounds: %s" % material_id)
		if not registry.materials_by_id.has(material_id):
			return _fail("material seed rectangle uses unknown material: %s" % material_id)
		var material: Dictionary = registry.material(material_id)
		var amount := int(rectangle.get("amount", material.get("default_amount", 0)))
		var temperature := int(rectangle.get("temperature", material.get("default_temperature", ambient_temperature)))
		var wetness := int(rectangle.get("wetness", 0))
		var charge := int(rectangle.get("charge", 0))
		if amount < 0 or amount > SimConfig.FIXED_SCALE:
			return _fail("material seed amount is outside scale: %s" % material_id)
		if temperature < -1_000_000 or temperature > 1_000_000:
			return _fail("material seed temperature is outside bounds: %s" % material_id)
		if wetness < 0 or wetness > SimConfig.FIXED_SCALE or charge < 0 or charge > SimConfig.FIXED_SCALE:
			return _fail("material seed wetness/charge is outside scale: %s" % material_id)
		for cell_y: int in range(y, y + rectangle_height):
			for cell_x: int in range(x, x + rectangle_width):
				var cell_index := cell_y * width + cell_x
				if occupied.has(cell_index):
					return _fail("material seed rectangles overlap at cell %d" % cell_index)
				occupied[cell_index] = true
				if material_id == "worldbone":
					worldbone_cells[cell_index] = true
		seeded_materials[material_id] = true

	for border_x: int in range(width):
		if not worldbone_cells.has(border_x) or not worldbone_cells.has((height - 1) * width + border_x):
			return _fail("worldbone perimeter is incomplete")
	for border_y: int in range(1, height - 1):
		if not worldbone_cells.has(border_y * width) or not worldbone_cells.has(border_y * width + width - 1):
			return _fail("worldbone perimeter is incomplete")
	var declared_required_materials: Array = data.get("required_seed_materials", [])
	for required_material: String in REQUIRED_SEED_MATERIALS:
		if not declared_required_materials.has(required_material) or not seeded_materials.has(required_material):
			return _fail("material yard is missing required seed material: %s" % required_material)
	material_catalog_hash = registry.content_hash
	content_hash = CanonicalContent.sha256(data)
	return content_hash.length() == 64 or _fail("material yard hash failed")


func _fail(message: String) -> bool:
	last_error = message
	return false

class_name MaterialRegistry
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 1
const PHASES: Array[String] = ["empty", "solid", "loose", "liquid", "gas", "energy"]
const COLLISION_KINDS: Array[String] = ["none", "soft", "solid"]
const REQUIRED_CELL_FIELDS: Array[String] = ["amount", "temperature", "wetness", "charge", "elevation"]
const FOUNDATION_REQUIRED_MATERIAL_IDS: Array[String] = [
	"empty", "worldbone", "stone", "brick", "wood", "water", "oil", "fire", "steam", "ice", "rubble",
]

var data: Dictionary = {}
var last_error: String = ""
var content_hash: String = ""
var materials_by_id: Dictionary = {}
var material_ids_by_wire: Dictionary = {}


func load_from_file(path: String) -> bool:
	last_error = ""
	data = {}
	if not FileAccess.file_exists(path):
		return _fail("material catalog does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("material catalog cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("material catalog root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	content_hash = ""
	materials_by_id = {}
	material_ids_by_wire = {}
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported material catalog schema")
	if String(data.get("id", "")).is_empty():
		return _fail("material catalog id is required")
	if int(data.get("fixed_scale", 0)) != SimConfig.FIXED_SCALE:
		return _fail("material catalog fixed scale must match simulation scale")
	var cell_fields: Array = data.get("cell_fields", [])
	for required_field: String in REQUIRED_CELL_FIELDS:
		if not cell_fields.has(required_field):
			return _fail("material catalog is missing cell field: %s" % required_field)

	for value: Variant in data.get("materials", []):
		if not value is Dictionary:
			return _fail("every material must be an object")
		var material: Dictionary = value
		var material_id := String(material.get("id", ""))
		var wire_id := int(material.get("wire_id", 0))
		var phase := String(material.get("phase", ""))
		var collision := String(material.get("collision", ""))
		var default_amount := int(material.get("default_amount", -1))
		var default_temperature := int(material.get("default_temperature", 2_000_001))
		if material_id.is_empty() or materials_by_id.has(material_id):
			return _fail("material ids must be non-empty and unique: %s" % material_id)
		if wire_id <= 0 or material_ids_by_wire.has(wire_id):
			return _fail("material wire ids must be positive and unique: %d" % wire_id)
		if not PHASES.has(phase):
			return _fail("material has an unknown phase: %s" % material_id)
		if not COLLISION_KINDS.has(collision):
			return _fail("material has an unknown collision kind: %s" % material_id)
		if default_amount < 0 or default_amount > SimConfig.FIXED_SCALE:
			return _fail("material default amount is outside scale: %s" % material_id)
		if default_temperature < -1_000_000 or default_temperature > 1_000_000:
			return _fail("material default temperature is outside bounds: %s" % material_id)
		if phase == "empty" and default_amount != 0:
			return _fail("empty material must have zero amount")
		if phase != "empty" and default_amount <= 0:
			return _fail("non-empty material needs positive amount: %s" % material_id)
		materials_by_id[material_id] = material
		material_ids_by_wire[wire_id] = material_id

	var declared_required_ids: Array = data.get("required_material_ids", [])
	for required_id: String in FOUNDATION_REQUIRED_MATERIAL_IDS:
		if not declared_required_ids.has(required_id) or not materials_by_id.has(required_id):
			return _fail("required material is missing: %s" % required_id)
	if String((materials_by_id.get("empty", {}) as Dictionary).get("phase", "")) != "empty":
		return _fail("empty material id must use the empty phase")
	if not bool((materials_by_id.get("worldbone", {}) as Dictionary).get("immutable", false)):
		return _fail("worldbone must be immutable")
	for material_id: String in materials_by_id:
		if material_id != "worldbone" and bool((materials_by_id[material_id] as Dictionary).get("immutable", false)):
			return _fail("worldbone must be the only immutable material: %s" % material_id)
	content_hash = CanonicalContent.sha256(data)
	return content_hash.length() == 64 or _fail("material catalog hash failed")


func material(material_id: String) -> Dictionary:
	return materials_by_id.get(material_id, {})


func wire_id(material_id: String) -> int:
	return int(material(material_id).get("wire_id", 0))


func material_id(wire_id: int) -> String:
	return String(material_ids_by_wire.get(wire_id, ""))


func _fail(message: String) -> bool:
	last_error = message
	return false

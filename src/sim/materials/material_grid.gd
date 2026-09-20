class_name MaterialGrid
extends RefCounted


var definition: MaterialYardDefinition
var registry: MaterialRegistry
var config: SimConfig
var width: int = 0
var height: int = 0
var material_wire_ids := PackedInt32Array()
var amounts := PackedInt32Array()
var temperatures := PackedInt32Array()
var wetness := PackedInt32Array()
var charges := PackedInt32Array()
var elevations := PackedInt32Array()
var worldbone_mask := PackedByteArray()
var awake_mask := PackedByteArray()
var awake_indices: Array[int] = []
var work_remainder: int = 0
var last_error: String = ""
var seed_state_hash: String = ""
var seed_worldbone_hash: String = ""

var _seed_material_wire_ids := PackedInt32Array()
var _seed_amounts := PackedInt32Array()
var _seed_temperatures := PackedInt32Array()
var _seed_wetness := PackedInt32Array()
var _seed_charges := PackedInt32Array()
var _seed_elevations := PackedInt32Array()


func initialize(
	requested_definition: MaterialYardDefinition,
	requested_registry: MaterialRegistry,
	requested_config: SimConfig,
) -> bool:
	last_error = ""
	if (
		requested_definition == null
		or requested_registry == null
		or requested_config == null
		or not requested_config.is_valid()
		or not requested_definition.last_error.is_empty()
		or not requested_registry.last_error.is_empty()
		or requested_definition.content_hash.length() != 64
		or requested_registry.content_hash.length() != 64
		or requested_definition.material_catalog_hash != requested_registry.content_hash
	):
		return _fail("material grid requires valid definition, registry, and 120 Hz config")
	definition = requested_definition
	registry = requested_registry
	config = requested_config
	width = definition.width
	height = definition.height
	var cell_count := width * height
	material_wire_ids.resize(cell_count)
	amounts.resize(cell_count)
	temperatures.resize(cell_count)
	wetness.resize(cell_count)
	charges.resize(cell_count)
	elevations.resize(cell_count)
	worldbone_mask.resize(cell_count)
	awake_mask.resize(cell_count)
	material_wire_ids.fill(registry.wire_id("empty"))
	amounts.fill(0)
	temperatures.fill(definition.ambient_temperature)
	wetness.fill(0)
	charges.fill(0)
	elevations.fill(0)
	worldbone_mask.fill(0)
	awake_mask.fill(0)
	awake_indices = []
	work_remainder = 0

	for value: Variant in definition.data.get("seed_rects", []):
		var rectangle: Dictionary = value
		var material_id := String(rectangle.get("material", ""))
		var material: Dictionary = registry.material(material_id)
		var material_wire_id := registry.wire_id(material_id)
		var amount := int(rectangle.get("amount", material.get("default_amount", 0)))
		var temperature := int(rectangle.get("temperature", material.get("default_temperature", definition.ambient_temperature)))
		var cell_wetness := int(rectangle.get("wetness", 0))
		var charge := int(rectangle.get("charge", 0))
		var elevation := int(rectangle.get("elevation", 0))
		var start_x := int(rectangle.get("x", 0))
		var start_y := int(rectangle.get("y", 0))
		for cell_y: int in range(start_y, start_y + int(rectangle.get("height", 0))):
			for cell_x: int in range(start_x, start_x + int(rectangle.get("width", 0))):
				var cell_index := cell_y * width + cell_x
				material_wire_ids[cell_index] = material_wire_id
				amounts[cell_index] = amount
				temperatures[cell_index] = temperature
				wetness[cell_index] = cell_wetness
				charges[cell_index] = charge
				elevations[cell_index] = elevation
				if material_id == "worldbone":
					worldbone_mask[cell_index] = 1

	_seed_material_wire_ids = material_wire_ids.duplicate()
	_seed_amounts = amounts.duplicate()
	_seed_temperatures = temperatures.duplicate()
	_seed_wetness = wetness.duplicate()
	_seed_charges = charges.duplicate()
	_seed_elevations = elevations.duplicate()
	seed_worldbone_hash = worldbone_hash()
	seed_state_hash = state_hash()
	return seed_worldbone_hash.length() == 64 and seed_state_hash.length() == 64


func cell(x: int, y: int) -> Dictionary:
	var cell_index := _cell_index(x, y)
	if cell_index < 0:
		return {}
	return {
		"index": cell_index,
		"material": registry.material_id(material_wire_ids[cell_index]),
		"material_wire_id": material_wire_ids[cell_index],
		"amount": amounts[cell_index],
		"temperature": temperatures[cell_index],
		"wetness": wetness[cell_index],
		"charge": charges[cell_index],
		"elevation": elevations[cell_index],
		"worldbone": worldbone_mask[cell_index] != 0,
	}


func write_cell(
	x: int,
	y: int,
	material_id: String,
	amount: int,
	temperature: int,
	cell_wetness: int = 0,
	charge: int = 0,
) -> bool:
	last_error = ""
	var cell_index := _cell_index(x, y)
	if cell_index < 0:
		return _fail("material write is outside yard bounds")
	if worldbone_mask[cell_index] != 0:
		return _fail("worldbone is immutable")
	var material: Dictionary = registry.material(material_id)
	if material.is_empty():
		return _fail("material write uses unknown material: %s" % material_id)
	if bool(material.get("immutable", false)):
		return _fail("immutable material cannot be created by runtime writes: %s" % material_id)
	if amount < 0 or amount > SimConfig.FIXED_SCALE:
		return _fail("material write amount is outside scale")
	if String(material.get("phase", "")) == "empty" and amount != 0:
		return _fail("empty material write must have zero amount")
	if String(material.get("phase", "")) != "empty" and amount <= 0:
		return _fail("non-empty material write needs positive amount")
	if temperature < -1_000_000 or temperature > 1_000_000:
		return _fail("material write temperature is outside bounds")
	if cell_wetness < 0 or cell_wetness > SimConfig.FIXED_SCALE or charge < 0 or charge > SimConfig.FIXED_SCALE:
		return _fail("material write wetness/charge is outside scale")
	material_wire_ids[cell_index] = int(material.get("wire_id", 0))
	amounts[cell_index] = amount
	temperatures[cell_index] = temperature
	wetness[cell_index] = cell_wetness
	charges[cell_index] = charge
	return wake_cell(x, y)


func wake_cell(x: int, y: int) -> bool:
	last_error = ""
	var cell_index := _cell_index(x, y)
	if cell_index < 0:
		return _fail("awake cell is outside yard bounds")
	if worldbone_mask[cell_index] != 0:
		return _fail("worldbone cannot enter the mutable work queue")
	if awake_mask[cell_index] == 0:
		awake_mask[cell_index] = 1
		awake_indices.append(cell_index)
	return true


func process_awake() -> PackedInt32Array:
	var processed := PackedInt32Array()
	work_remainder += definition.max_awake_cells_per_second
	@warning_ignore("integer_division")
	var budget := work_remainder / config.tick_rate
	work_remainder %= config.tick_rate
	awake_indices.sort()
	var process_count := mini(budget, awake_indices.size())
	for queue_index: int in range(process_count):
		var cell_index: int = awake_indices[queue_index]
		processed.append(cell_index)
		awake_mask[cell_index] = 0
	var remaining: Array[int] = []
	for queue_index: int in range(process_count, awake_indices.size()):
		remaining.append(awake_indices[queue_index])
	awake_indices = remaining
	return processed


func reset_to_seed() -> void:
	material_wire_ids = _seed_material_wire_ids.duplicate()
	amounts = _seed_amounts.duplicate()
	temperatures = _seed_temperatures.duplicate()
	wetness = _seed_wetness.duplicate()
	charges = _seed_charges.duplicate()
	elevations = _seed_elevations.duplicate()
	awake_mask.fill(0)
	awake_indices = []
	work_remainder = 0
	last_error = ""


func worldbone_hash() -> String:
	var payload := PackedByteArray()
	CanonicalBytes.append_string(payload, String(definition.data.get("id", "")))
	CanonicalBytes.append_string(payload, registry.content_hash)
	CanonicalBytes.append_i64(payload, width)
	CanonicalBytes.append_i64(payload, height)
	for cell_index: int in range(worldbone_mask.size()):
		if worldbone_mask[cell_index] == 0:
			continue
		for value: int in [
			cell_index,
			material_wire_ids[cell_index],
			amounts[cell_index],
			temperatures[cell_index],
			elevations[cell_index],
		]:
			CanonicalBytes.append_i64(payload, value)
	return CanonicalBytes.sha256_hex(payload)


func state_hash() -> String:
	var payload := PackedByteArray()
	CanonicalBytes.append_string(payload, String(definition.data.get("id", "")))
	CanonicalBytes.append_string(payload, definition.content_hash)
	CanonicalBytes.append_string(payload, registry.content_hash)
	for value: int in [config.tick_rate, width, height, work_remainder, awake_indices.size()]:
		CanonicalBytes.append_i64(payload, value)
	for cell_index: int in range(material_wire_ids.size()):
		for value: int in [
			material_wire_ids[cell_index],
			amounts[cell_index],
			temperatures[cell_index],
			wetness[cell_index],
			charges[cell_index],
			elevations[cell_index],
			worldbone_mask[cell_index],
			awake_mask[cell_index],
		]:
			CanonicalBytes.append_i64(payload, value)
	var ordered_awake: Array[int] = awake_indices.duplicate()
	ordered_awake.sort()
	for cell_index: int in ordered_awake:
		CanonicalBytes.append_i64(payload, cell_index)
	return CanonicalBytes.sha256_hex(payload)


func _cell_index(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return -1
	return y * width + x


func _fail(message: String) -> bool:
	last_error = message
	return false

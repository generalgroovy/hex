class_name MixtureCatalog
extends RefCounted
## Payload identity is independent of delivery. Stable singleton wires remain valid.

const PATH := "res://content/abilities/element_mixtures_v1.json"
const FAMILIES: Array[String] = ["bolt", "heavy", "rapid", "spray", "mantle", "fuse", "split", "rebound"]
const SINGLETON_WIRES := {4: [140,181,182,141], 2: [145,179,180,154], 8: [163,185,186,164], 1: [159,183,184,160], 16: [173,191,192,174], 32: [142,193,194,176]}
static var _rows: Dictionary = {}

static func _load() -> void:
	if not _rows.is_empty(): return
	if not FileAccess.file_exists(PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not valid_document(parsed): return
	var candidate := {}
	for value: Variant in parsed.get("mixtures", []):
		var mask := int(value.get("element_mask", 0))
		candidate[mask] = value
	if candidate.size() == 63: _rows = candidate

static func is_valid() -> bool:
	_load()
	return _rows.size() == 63

static func valid_document(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not _whole(value.get("schema_version"),1,1) or String(value.get("id","")) != "element-mixtures-v1": return false
	if not value.get("mixtures") is Array or value.mixtures.size() != 63: return false
	var seen := {}
	for row: Variant in value.mixtures:
		if not row is Dictionary or not _whole(row.get("element_mask"),1,63): return false
		var mask := int(row.element_mask)
		if seen.has(mask) or String(row.get("id","")) != "mixture_%02d" % mask: return false
		seen[mask] = true
		var expected: Array[String] = []
		for wire: int in ElementRules.WIRE_IDS:
			if mask & int(ElementRules.MASK_BY_WIRE[wire]): expected.append(ElementRules.id_from_wire(wire))
		if not row.get("elements") is Array or row.elements.size() != expected.size(): return false
		for index: int in expected.size():
			if not row.elements[index] is String or row.elements[index] != expected[index]: return false
		if not _whole(row.get("representative_element_wire_id"),1,8) or int(row.representative_element_wire_id) != representative_wire(mask): return false
		if not _whole(row.get("reaction_wire_id"),301,463) or int(row.reaction_wire_id) != HexRecipePolicy.wire_for_mask(mask): return false
		if not _whole(row.get("status_duration_ms"),450,1000): return false
		# JSON numbers are floats. Validate whole values individually rather than
		# relying on equality of float and integer Variant arrays.
		var potencies: Array[int] = [80,1000,120,80,1000,1000]
		if not row.get("status_potencies") is Array or row.status_potencies.size() != potencies.size(): return false
		for index: int in potencies.size():
			if not _whole(row.status_potencies[index],potencies[index],potencies[index]): return false
		for key: String in ["display_name","purpose","counter","reference"]:
			if not row.get(key) is String or String(row[key]).strip_edges().is_empty(): return false
	return seen.size() == 63

static func _whole(value: Variant, low: int, high: int) -> bool:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]: return false
	return is_finite(float(value)) and float(value) == float(int(value)) and int(value) >= low and int(value) <= high

static func definition(mask: int) -> Dictionary:
	_load()
	return (_rows.get(mask, {}) as Dictionary).duplicate(true)

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_valid(): return result
	for mask: int in range(1,64): result.append(definition(mask))
	return result

static func wire_for(mask: int, family: String) -> int:
	var index := FAMILIES.find(family)
	if mask < 1 or mask > 63 or index < 0: return 0
	if index < 4 and SINGLETON_WIRES.has(mask): return int(SINGLETON_WIRES[mask][index])
	return 1000 + 64 * index + mask

static func mask_for_wire(wire: int) -> int:
	for mask: int in SINGLETON_WIRES:
		if wire in SINGLETON_WIRES[mask]: return mask
	var offset := wire-1000
	if offset < 0 or offset >= 512 or offset % 64 == 0: return 0
	var mask := offset % 64
	return mask if wire_for(mask,FAMILIES[offset/64]) == wire else 0

static func family_for_wire(wire: int) -> String:
	for mask: int in SINGLETON_WIRES:
		var index: int = SINGLETON_WIRES[mask].find(wire)
		if index >= 0: return FAMILIES[index]
	if mask_for_wire(wire) == 0: return ""
	return FAMILIES[(wire-1000)/64]

static func representative_wire(mask: int) -> int:
	for wire: int in ElementRules.WIRE_IDS:
		if mask & int(ElementRules.MASK_BY_WIRE[wire]): return wire
	return 0

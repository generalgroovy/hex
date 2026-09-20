class_name MeleeInfusionTuning
extends RefCounted

const DEFAULT_PATH := "res://.agent/candidates/gameplay_s6_infusion/content/combat/melee_infusions_v1.json"
const MAX_BYTES := 8_192
const WATER_ELEMENT_WIRE_ID := 3
const FIRE_ELEMENT_WIRE_ID := 2

static var _shared: MeleeInfusionTuning

var last_error := ""
var content_hash := ""
var supported_element_wire_ids: Array[int] = []
var strength := 0
var matter_budget := 0
var flux_cost := 0
var readiness_ticks := 0


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("melee infusion tuning does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("melee infusion tuning cannot be opened: %s" % path)
	if file.get_length() <= 0 or file.get_length() > MAX_BYTES:
		file.close()
		return _fail("melee infusion tuning size is invalid")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var staged := _validated(parsed)
	if not String(staged.get("error", "")).is_empty():
		return _fail(String(staged.error))
	var staged_hash := CanonicalContent.sha256(parsed)
	if staged_hash.length() != 64:
		return _fail("melee infusion tuning hash failed")
	supported_element_wire_ids = []
	for element_wire_id: Variant in staged.supported_element_wire_ids:
		supported_element_wire_ids.append(int(element_wire_id))
	strength = int(staged.strength)
	matter_budget = int(staged.matter_budget)
	flux_cost = int(staged.flux_cost)
	readiness_ticks = int(staged.readiness_ticks)
	content_hash = staged_hash
	return true


func is_valid() -> bool:
	return (
		content_hash.length() == 64
		and supported_element_wire_ids == [WATER_ELEMENT_WIRE_ID, FIRE_ELEMENT_WIRE_ID]
		and strength == 3
		and matter_budget == 180
		and flux_cost == 4_000
		and readiness_ticks == 36
	)


func profile() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"supported_element_wire_ids": supported_element_wire_ids.duplicate(),
		"strength": strength,
		"matter_budget": matter_budget,
		"flux_cost": flux_cost,
		"readiness_ticks": readiness_ticks,
	}


static func shared() -> MeleeInfusionTuning:
	if _shared == null:
		_shared = MeleeInfusionTuning.new()
		_shared.load_from_file()
	return _shared


static func reset_shared_for_tests() -> void:
	_shared = null


static func _validated(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"error": "melee infusion tuning root must be an object"}
	var expected := ["version", "compatibility_id", "supported_element_wire_ids", "strength", "matter_budget", "flux_cost", "readiness_ticks"]
	if not _has_exact_keys(value, expected):
		return {"error": "melee infusion tuning schema is invalid"}
	if not _whole(value.version) or int(value.version) != 1 or String(value.compatibility_id) != "melee-infusion-s6-v1":
		return {"error": "melee infusion tuning identity is invalid"}
	var raw_elements: Variant = value.supported_element_wire_ids
	if not raw_elements is Array or raw_elements.size() != 2:
		return {"error": "melee infusion requires exactly Water and Fire"}
	var elements: Array[int] = []
	for raw_element: Variant in raw_elements:
		if not _whole(raw_element):
			return {"error": "melee infusion element wire is not an integer"}
		elements.append(int(raw_element))
	if elements != [WATER_ELEMENT_WIRE_ID, FIRE_ELEMENT_WIRE_ID]:
		return {"error": "melee infusion element order must be Water then Fire"}
	for key: String in ["strength", "matter_budget", "flux_cost", "readiness_ticks"]:
		if not _whole(value[key]):
			return {"error": "melee infusion %s is not an integer" % key}
	if int(value.strength) != 3 or int(value.matter_budget) != 180 or int(value.flux_cost) != 4_000 or int(value.readiness_ticks) != 36:
		return {"error": "melee infusion fixed trial profile changed"}
	return {
		"error": "",
		"supported_element_wire_ids": elements,
		"strength": int(value.strength),
		"matter_budget": int(value.matter_budget),
		"flux_cost": int(value.flux_cost),
		"readiness_ticks": int(value.readiness_ticks),
	}


static func _whole(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false

class_name ReactionCatalog
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 2
const FIRST_EIGHT_ELEMENTS: Array[String] = ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
const DEFERRED_ELEMENTS: Array[String] = ["spirit", "chaos", "gravity", "time"]
const CHANNELS: Array[String] = ["structure", "heat", "saturation", "pressure_momentum", "charge", "radiance_vitality", "decay"]
const PRIMITIVES: Array[String] = ["surface", "flow", "cover", "field", "conduction", "visibility", "hazard", "refraction", "fracture"]
const REQUIRED_BOUNDS: Array[String] = [
	"maximum_active_reactions", "maximum_active_cells", "maximum_area_cells_per_reaction",
	"maximum_propagation_depth", "maximum_work_units_per_tick", "maximum_events_per_tick",
	"maximum_owners_per_reaction", "maximum_phase_ms",
]
const REQUIRED_PROFILE_FIELDS: Array[String] = [
	"formation_threshold", "formation_ms", "active_ms", "residue_ms",
	"maximum_area_cells", "maximum_propagation_depth", "work_units_per_tick",
]

var data: Dictionary = {}
var last_error: String = ""
var content_hash: String = ""
var runtime_bounds: Dictionary = {}
var runtime_profiles: Dictionary = {}
var element_channel_vectors: Dictionary = {}
var reactions_by_id: Dictionary = {}
var reaction_ids_by_wire: Dictionary = {}
var reaction_ids_by_pair: Dictionary = {}


func load_from_file(path: String) -> bool:
	last_error = ""
	data = {}
	if not FileAccess.file_exists(path):
		return _fail("reaction catalog does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("reaction catalog cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("reaction catalog root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	content_hash = ""
	runtime_bounds = {}
	runtime_profiles = {}
	element_channel_vectors = {}
	reactions_by_id = {}
	reaction_ids_by_wire = {}
	reaction_ids_by_pair = {}
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported reaction catalog schema")
	if String(data.get("id", "")) != "first-eight-element-reactions-v1":
		return _fail("reaction catalog identity is unsupported")
	if String(data.get("status", "")) != "bounded_level_one" or not bool(data.get("runtime_enabled", false)):
		return _fail("reaction runtime requires the bounded first-grade contract")
	if _string_array(data.get("fundamental_elements", [])) != FIRST_EIGHT_ELEMENTS:
		return _fail("reaction catalog requires the exact ordered first-eight elements")
	if _string_array(data.get("deferred_elements", [])) != DEFERRED_ELEMENTS:
		return _fail("reaction catalog must keep the four deferred elements explicit")
	var policy_value: Variant = data.get("policy", {})
	if not policy_value is Dictionary:
		return _fail("reaction policy must be an object")
	var policy: Dictionary = policy_value
	if not bool(policy.get("pair_order_is_symmetric", false)) \
		or not bool(policy.get("worldbone_immutable", false)) \
		or String(policy.get("worldbone_policy", "")) != "reject" \
		or String(policy.get("mutation_gate", "")) != "bounded_level_one" \
		or String(policy.get("priority", "")) != "map_interaction_before_damage_multiplier":
		return _fail("reaction safety policy is incomplete")
	for required_phase: String in ["formation", "active", "residue_or_decay"]:
		if not (policy.get("required_lifecycle", []) as Array).has(required_phase):
			return _fail("reaction policy is missing lifecycle phase: %s" % required_phase)
	for required_bound: String in ["area", "propagation_depth", "lifetime", "work", "ownership"]:
		if not (policy.get("required_runtime_bounds", []) as Array).has(required_bound):
			return _fail("reaction policy is missing runtime bound: %s" % required_bound)
	if not _validate_channels():
		return false
	if not _validate_bounds():
		return false
	if not _validate_profiles():
		return false
	if not _validate_reactions():
		return false
	content_hash = CanonicalContent.sha256(data)
	return content_hash.length() == 64 or _fail("reaction catalog hash failed")


func reaction(element_a: String, element_b: String) -> Dictionary:
	var reaction_id := String(reaction_ids_by_pair.get(pair_key(element_a, element_b), ""))
	return (reactions_by_id.get(reaction_id, {}) as Dictionary).duplicate(true)


func reaction_from_wire(wire_id: int) -> Dictionary:
	return (reactions_by_id.get(String(reaction_ids_by_wire.get(wire_id, "")), {}) as Dictionary).duplicate(true)


func ordered_wire_ids() -> Array[int]:
	var result: Array[int] = []
	for wire_value: Variant in reaction_ids_by_wire.keys():
		result.append(int(wire_value))
	result.sort()
	return result


static func pair_key(element_a: String, element_b: String) -> String:
	var index_a := FIRST_EIGHT_ELEMENTS.find(element_a)
	var index_b := FIRST_EIGHT_ELEMENTS.find(element_b)
	if index_a < 0 or index_b < 0:
		return ""
	return "%s+%s" % [element_a, element_b] if index_a <= index_b else "%s+%s" % [element_b, element_a]


func _validate_channels() -> bool:
	if _string_array(data.get("channels", [])) != CHANNELS:
		return _fail("reaction channels must use the exact bounded integer model")
	var vectors_value: Variant = data.get("element_channel_vectors", {})
	if not vectors_value is Dictionary or (vectors_value as Dictionary).size() != FIRST_EIGHT_ELEMENTS.size():
		return _fail("every first-eight element requires one channel vector")
	for element_id: String in FIRST_EIGHT_ELEMENTS:
		var vector_value: Variant = (vectors_value as Dictionary).get(element_id, {})
		if not vector_value is Dictionary or (vector_value as Dictionary).size() != CHANNELS.size():
			return _fail("element channel vector is incomplete: %s" % element_id)
		var vector: Dictionary = vector_value
		var has_signal := false
		for channel_id: String in CHANNELS:
			if not _bounded_integer(vector.get(channel_id), -SimConfig.FIXED_SCALE, SimConfig.FIXED_SCALE):
				return _fail("element channel is invalid: %s/%s" % [element_id, channel_id])
			has_signal = has_signal or int(vector[channel_id]) != 0
		if not has_signal:
			return _fail("element channel vector cannot be empty: %s" % element_id)
		element_channel_vectors[element_id] = vector.duplicate(true)
	return true


func _validate_bounds() -> bool:
	var bounds_value: Variant = data.get("runtime_bounds", {})
	if not bounds_value is Dictionary or (bounds_value as Dictionary).size() != REQUIRED_BOUNDS.size():
		return _fail("reaction runtime bounds are incomplete")
	var maxima := {
		"maximum_active_reactions": 256, "maximum_active_cells": 4096,
		"maximum_area_cells_per_reaction": 64, "maximum_propagation_depth": 16,
		"maximum_work_units_per_tick": 2048, "maximum_events_per_tick": 512,
		"maximum_owners_per_reaction": 8, "maximum_phase_ms": 30_000,
	}
	for field: String in REQUIRED_BOUNDS:
		if not _bounded_integer((bounds_value as Dictionary).get(field), 1, int(maxima[field])):
			return _fail("reaction runtime bound is invalid: %s" % field)
	runtime_bounds = (bounds_value as Dictionary).duplicate(true)
	if int(runtime_bounds["maximum_active_cells"]) < int(runtime_bounds["maximum_area_cells_per_reaction"]):
		return _fail("reaction active-cell capacity cannot be smaller than one reaction area")
	return true


func _validate_profiles() -> bool:
	var profiles_value: Variant = data.get("runtime_profiles", {})
	if not profiles_value is Dictionary or (profiles_value as Dictionary).size() != PRIMITIVES.size():
		return _fail("reaction runtime requires exactly one profile per shared primitive")
	var seen_primitives: Dictionary = {}
	for profile_value: Variant in (profiles_value as Dictionary).keys():
		var profile_id := String(profile_value)
		var entry_value: Variant = (profiles_value as Dictionary)[profile_value]
		if profile_id.is_empty() or not entry_value is Dictionary:
			return _fail("reaction runtime profile is invalid: %s" % profile_id)
		var profile: Dictionary = entry_value
		var primitive := String(profile.get("primitive", ""))
		if primitive not in PRIMITIVES or seen_primitives.has(primitive):
			return _fail("reaction primitive profiles must be unique and complete: %s" % primitive)
		for field: String in REQUIRED_PROFILE_FIELDS:
			if not _bounded_integer(profile.get(field), 1, 30_000):
				return _fail("reaction runtime profile field is invalid: %s/%s" % [profile_id, field])
		if int(profile["formation_threshold"]) > SimConfig.FIXED_SCALE * 2 \
			or int(profile["formation_ms"]) > int(runtime_bounds["maximum_phase_ms"]) \
			or int(profile["active_ms"]) > int(runtime_bounds["maximum_phase_ms"]) \
			or int(profile["residue_ms"]) > int(runtime_bounds["maximum_phase_ms"]) \
			or int(profile["maximum_area_cells"]) > int(runtime_bounds["maximum_area_cells_per_reaction"]) \
			or int(profile["maximum_propagation_depth"]) > int(runtime_bounds["maximum_propagation_depth"]) \
			or int(profile["work_units_per_tick"]) > int(runtime_bounds["maximum_work_units_per_tick"]):
			return _fail("reaction runtime profile exceeds global capacity: %s" % profile_id)
		seen_primitives[primitive] = profile_id
		runtime_profiles[profile_id] = profile.duplicate(true)
	for primitive: String in PRIMITIVES:
		if not seen_primitives.has(primitive):
			return _fail("reaction primitive is missing a profile: %s" % primitive)
	return true


func _validate_reactions() -> bool:
	var reaction_values: Variant = data.get("reactions", [])
	if not reaction_values is Array or (reaction_values as Array).size() != 36:
		return _fail("reaction catalog requires exactly 36 first-eight pairs")
	for value: Variant in reaction_values:
		if not value is Dictionary:
			return _fail("every reaction must be an object")
		var entry: Dictionary = value
		var reaction_id := String(entry.get("id", ""))
		var wire_id_value: Variant = entry.get("wire_id")
		var profile_id := String(entry.get("runtime_profile", ""))
		var pair := _string_array(entry.get("input_elements", []))
		if reaction_id.is_empty() or reactions_by_id.has(reaction_id):
			return _fail("reaction ids must be non-empty and unique: %s" % reaction_id)
		if not _bounded_integer(wire_id_value, 301, 4095) or reaction_ids_by_wire.has(int(wire_id_value)):
			return _fail("reaction wire ids must be stable and unique: %s" % reaction_id)
		if pair.size() != 2 or pair[0] not in FIRST_EIGHT_ELEMENTS or pair[1] not in FIRST_EIGHT_ELEMENTS:
			return _fail("reaction pair must use two first-eight elements: %s" % reaction_id)
		var canonical_key := pair_key(pair[0], pair[1])
		if canonical_key != "%s+%s" % [pair[0], pair[1]] or reaction_ids_by_pair.has(canonical_key):
			return _fail("reaction pairs must be canonical and unique: %s" % reaction_id)
		if not runtime_profiles.has(profile_id):
			return _fail("reaction uses an unknown runtime profile: %s" % reaction_id)
		if String(entry.get("name", "")).is_empty() \
			or String(entry.get("residue", "")).is_empty() \
			or String(entry.get("telegraph", "")).is_empty() \
			or (entry.get("map_effects", []) as Array).is_empty() \
			or (entry.get("actor_effects", []) as Array).is_empty() \
			or (entry.get("counters", []) as Array).is_empty():
			return _fail("reaction requires effects, lifecycle cues and counterplay: %s" % reaction_id)
		reactions_by_id[reaction_id] = entry.duplicate(true)
		reaction_ids_by_wire[int(wire_id_value)] = reaction_id
		reaction_ids_by_pair[canonical_key] = reaction_id
	for left_index: int in range(FIRST_EIGHT_ELEMENTS.size()):
		for right_index: int in range(left_index, FIRST_EIGHT_ELEMENTS.size()):
			var expected_key := pair_key(FIRST_EIGHT_ELEMENTS[left_index], FIRST_EIGHT_ELEMENTS[right_index])
			if not reaction_ids_by_pair.has(expected_key):
				return _fail("reaction catalog is missing pair: %s" % expected_key)
	return true


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value:
		if typeof(item) != TYPE_STRING:
			return []
		result.append(String(item))
	return result


static func _bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var integer := int(value)
	return float(value) == float(integer) and integer >= minimum and integer <= maximum


func _fail(message: String) -> bool:
	last_error = message
	return false

class_name CombatDefinitionTable
extends RefCounted


const CATALOG_PATH: String = "res://content/abilities/foundation_abilities_v1.json"
const COMPILER_CONTRACT_VERSION: int = 2
const FIXED_ROTATIONS: Dictionary = {
	-24: Vector2i(914, -407),
	-12: Vector2i(978, -208),
	0: Vector2i(1000, 0),
	12: Vector2i(978, 208),
	24: Vector2i(914, 407),
}

static var _default_instance: CombatDefinitionTable

var last_error: String = ""
var content_hash: String = ""
var _definitions_by_wire: Dictionary = {}
var _runtime_wire_ids: Array[int] = []


static func default_table() -> CombatDefinitionTable:
	if _default_instance == null:
		var catalog := AbilityCatalog.new()
		var compiled := CombatDefinitionTable.new()
		if not catalog.load_from_file(CATALOG_PATH):
			compiled.last_error = catalog.last_error
		elif not compiled.compile(catalog):
			pass
		_default_instance = compiled
	return _default_instance


func compile(catalog: AbilityCatalog) -> bool:
	last_error = ""
	content_hash = ""
	_definitions_by_wire = {}
	_runtime_wire_ids = []
	if catalog == null or catalog.content_hash.length() != 64:
		return _fail("combat definitions require one validated ability catalog")
	for wire_id: int in catalog.runtime_wire_ids:
		var ability: Dictionary = catalog.ability_from_wire(wire_id)
		var definition := _compile_definition(ability, catalog)
		if definition.is_empty():
			return false
		_definitions_by_wire[wire_id] = definition
		_runtime_wire_ids.append(wire_id)
	content_hash = CanonicalContent.sha256({
		"compiler_contract_version": COMPILER_CONTRACT_VERSION,
		"ability_catalog_hash": catalog.content_hash,
		"runtime_wire_ids": _runtime_wire_ids,
	})
	if content_hash.length() != 64:
		return _fail("combat definition hash failed")
	return true


func definition(wire_id: int) -> Dictionary:
	return (_definitions_by_wire.get(wire_id, {}) as Dictionary).duplicate(true)


func projectile_definition(wire_id: int) -> Dictionary:
	var result := definition(wire_id)
	return result if String(result.get("shape", "")) == "projectile" else {}


func is_runtime_wire_id(wire_id: int) -> bool:
	return _definitions_by_wire.has(wire_id)


func runtime_wire_ids() -> Array[int]:
	return _runtime_wire_ids.duplicate()


func _compile_definition(ability: Dictionary, catalog: AbilityCatalog) -> Dictionary:
	var ability_id := String(ability.get("id", ""))
	var element_id := String(ability.get("element", ""))
	var element: Dictionary = catalog.elements_by_id.get(element_id, {})
	if element.is_empty():
		_fail("runtime ability has no compiled element: %s" % ability_id)
		return {}
	var definition := {
		"shape": String(ability.get("shape", "")),
		"element_wire_id": int(element.get("wire_id", 0)),
		"reaction_strength": int(ability.get("reaction_strength", 0)),
		"flux_cost": int(ability.get("flux_cost", 0)) * 1000,
		"cooldown_ms": int(ability.get("cooldown_ms", 0)),
		"startup_ms": int(ability.get("startup_ms", 0)),
		"recovery_ms": int(ability.get("recovery_ms", 0)),
	}
	if bool(ability.get("repeat_while_held", false)):
		definition["repeat_while_held"] = true
	match String(definition["shape"]):
		"projectile":
			definition.merge({
				"speed": int(ability.get("speed", 0)),
				"radius": int(ability.get("radius", 0)),
				"damage": int(ability.get("damage", 0)),
				"lifetime_ms": int(ability.get("lifetime_ms", 0)),
				"hit_control_state": 0,
				"hit_control_duration_ms": 0,
				"hit_control_speed": 0,
				"hit_control_slow_ratio": 1000,
				"remaining_bounces": int(ability.get("remaining_bounces", 0)),
			})
			if ability.has("blast_radius"):
				definition["blast_radius"] = int(ability["blast_radius"])
				definition["blast_damage"] = int(ability["blast_damage"])
			if ability.has("projectile_angles_degrees"):
				var angles: Array[int] = []
				var rotations: Array[Vector2i] = []
				for angle_value: Variant in ability["projectile_angles_degrees"]:
					var angle := int(angle_value)
					if not FIXED_ROTATIONS.has(angle):
						_fail("runtime projectile angle has no deterministic rotation: %s/%d" % [ability_id, angle])
						return {}
					angles.append(angle)
					rotations.append(FIXED_ROTATIONS[angle] as Vector2i)
				definition["projectile_angles_degrees"] = angles
				definition["projectile_rotations"] = rotations
			if ability.has("delivery_kernel"):
				definition["delivery_kernel"] = String(ability["delivery_kernel"])
		"beam", "spray":
			definition.merge({
				"range": int(ability.get("range", 0)),
				"radius": int(ability.get("radius", 0)),
				"damage": int(ability.get("damage", 0)),
				"hit_control_state": int(ability.get("hit_control_state", 0)),
				"hit_control_duration_ms": int(ability.get("hit_control_duration_ms", 0)),
				"hit_control_speed": int(ability.get("hit_control_speed", 0)),
				"hit_control_slow_ratio": int(ability.get("hit_control_slow_ratio", 1000)),
			})
			if String(definition["shape"]) == "spray":
				definition["cone_cosine_squared_per_million"] = int(ability.get("cone_cosine_squared_per_million", 0))
		"field":
			definition.merge({
				"range": int(ability.get("range", 0)),
				"radius": int(ability.get("radius", 0)),
				"lifetime_ms": int(ability.get("lifetime_ms", 0)),
				"hit_control_state": int(ability.get("hit_control_state", 0)),
				"hit_control_duration_ms": int(ability.get("hit_control_duration_ms", 0)),
				"hit_control_speed": int(ability.get("hit_control_speed", 0)),
				"hit_control_slow_ratio": int(ability.get("hit_control_slow_ratio", 1000)),
			})
		_:
			_fail("runtime ability has unsupported compiled shape: %s" % ability_id)
			return {}
	return definition


func _fail(message: String) -> bool:
	last_error = message
	return false

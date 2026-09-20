class_name AbilityCatalog
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 5
const SLOT_KINDS: Array[String] = ["passive", "primary", "active", "mobility", "ultimate"]
const SHAPES: Array[String] = ["passive", "projectile", "beam", "spray", "field", "defense", "movement", "ultimate"]
const DELIVERIES: Array[String] = ["self", "aimed", "placed"]
const IMPACTS: Array[String] = ["empower", "damage", "damage_interrupt", "barrier", "terrain_cover", "reposition", "area_control", "damage_launch", "damage_ricochet", "damage_slow", "control_slow"]
const RESIDUES: Array[String] = ["none", "trail", "field", "construct"]
const MATERIAL_OPERATIONS: Array[String] = ["none", "heat", "cool", "wet", "charge", "discharge", "fracture", "push", "reveal", "decay"]
const RUNTIME_STATUSES: Array[String] = ["playable", "catalog_only"]
const CADENCE_TIER_IDS: Array[String] = ["rapid", "pressure", "tempo", "control"]
const MAX_PROJECTILE_PATTERN_LANES: int = 9
const DISPLAY_ELEMENT_IDS: Array[String] = ["water", "earth", "fire", "wind", "ice", "charge", "light", "dark"]
const DISPLAY_ELEMENT_WIRE_IDS: Array[int] = [3, 1, 2, 4, 5, 6, 7, 8]
const DISPLAY_ELEMENT_WIRES: Dictionary = {
	"water": 3,
	"earth": 1,
	"fire": 2,
	"wind": 4,
	"ice": 5,
	"charge": 6,
	"light": 7,
	"dark": 8,
}
const FIRST_EIGHT_ELEMENTS: Array[String] = DISPLAY_ELEMENT_IDS
const KNOWN_SPELL_FAMILIES: Array[String] = ["bolt", "heavy", "rapid", "burst", "spray", "beam", "field"]
const SPELL_MATRIX_FAMILIES: Array[String] = ["bolt", "heavy", "rapid", "spray"]
const BURST_ANGLES: Array[int] = [-24, -12, 0, 12, 24]

var data: Dictionary = {}
var last_error: String = ""
var content_hash: String = ""
var elements_by_id: Dictionary = {}
var abilities_by_id: Dictionary = {}
var ability_ids_by_wire: Dictionary = {}
var economy: Dictionary = {}
var runtime_wire_ids: Array[int] = []
var spell_matrix_ids: Array[String] = []
var spell_matrix_wire_ids: Array[int] = []


func load_from_file(path: String) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("ability catalog does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("ability catalog cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("ability catalog root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	content_hash = ""
	elements_by_id = {}
	abilities_by_id = {}
	ability_ids_by_wire = {}
	economy = {}
	runtime_wire_ids = []
	spell_matrix_ids = []
	spell_matrix_wire_ids = []
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported ability catalog schema")
	if String(data.get("id", "")).is_empty():
		return _fail("ability catalog id is required")
	if String(data.get("affinity_rule", "")) != "aligned_active_cost_discount_capped_by_affinity_strength":
		return _fail("affinities may only discount aligned active build cost within authored affinity strength")
	var economy_value: Variant = data.get("economy", {})
	if not economy_value is Dictionary:
		return _fail("ability economy must be an object")
	economy = economy_value
	if String(economy.get("resource", "")) != "flux":
		return _fail("runtime spell economy must use Flux")
	if int(economy.get("recovery_delay_ms", 0)) != PlayerTuning.FLUX_RECOVERY_DELAY_MS:
		return _fail("ability economy recovery delay must match compiled Flux recovery")
	var minimum_runtime_spell_cost := int(economy.get("minimum_runtime_spell_cost", 0))
	if minimum_runtime_spell_cost <= 0:
		return _fail("runtime spell economy requires a positive minimum Flux cost")
	var cadence_tiers_value: Variant = economy.get("cadence_tiers_ms", {})
	if not cadence_tiers_value is Dictionary:
		return _fail("ability economy cadence tiers must be an object")
	var cadence_tiers: Dictionary = cadence_tiers_value
	if cadence_tiers.size() != CADENCE_TIER_IDS.size():
		return _fail("ability economy requires the exact cadence tiers")
	for cadence_tier_id: String in CADENCE_TIER_IDS:
		var tier_value: Variant = cadence_tiers.get(cadence_tier_id, {})
		if not tier_value is Dictionary:
			return _fail("ability economy cadence tier is missing: %s" % cadence_tier_id)
		var tier: Dictionary = tier_value
		var minimum_ms := int(tier.get("minimum", 0))
		var maximum_ms := int(tier.get("maximum", 0))
		if minimum_ms <= 0 or maximum_ms < minimum_ms or maximum_ms > 5_000:
			return _fail("ability economy cadence tier is invalid: %s" % cadence_tier_id)

	var element_wires: Dictionary = {}
	var element_ids_in_authored_order: Array[String] = []
	for value: Variant in data.get("elements", []):
		if not value is Dictionary:
			return _fail("every element must be an object")
		var element: Dictionary = value
		var element_id := String(element.get("id", ""))
		var wire_id := int(element.get("wire_id", 0))
		if element_id.is_empty() or elements_by_id.has(element_id):
			return _fail("element ids must be non-empty and unique: %s" % element_id)
		if wire_id <= 0 or element_wires.has(wire_id):
			return _fail("element wire ids must be positive and unique: %d" % wire_id)
		elements_by_id[element_id] = element
		element_wires[wire_id] = element_id
		element_ids_in_authored_order.append(element_id)
	if elements_by_id.size() != 12:
		return _fail("the thematic catalog must declare exactly twelve element families")
	if element_ids_in_authored_order.slice(0, DISPLAY_ELEMENT_IDS.size()) != DISPLAY_ELEMENT_IDS:
		return _fail("the first eight authored elements must use display/development order")
	for display_index: int in range(DISPLAY_ELEMENT_IDS.size()):
		var display_element_id := DISPLAY_ELEMENT_IDS[display_index]
		if not elements_by_id.has(display_element_id) \
			or int((elements_by_id[display_element_id] as Dictionary).get("wire_id", 0)) != DISPLAY_ELEMENT_WIRE_IDS[display_index] \
			or int(DISPLAY_ELEMENT_WIRES.get(display_element_id, 0)) != DISPLAY_ELEMENT_WIRE_IDS[display_index]:
			return _fail("display element mapping must preserve stable internal wire ids: %s" % display_element_id)

	var authored_abilities := _expanded_abilities()
	if authored_abilities.is_empty():
		return false
	for value: Variant in authored_abilities:
		if not value is Dictionary:
			return _fail("every ability must be an object")
		var ability: Dictionary = value
		var ability_id := String(ability.get("id", ""))
		if not ability.get("element", "") is String:
			return _fail("ability must declare one element string: %s" % ability_id)
		for hybrid_key: String in ["elements", "secondary_element", "dual_element", "element_combination", "hybrid_elements"]:
			if ability.has(hybrid_key):
				return _fail("mixed-element attacks are gated until chemistry acceptance: %s" % ability_id)
		var wire_id := int(ability.get("wire_id", 0))
		var slot_kind := String(ability.get("slot_kind", ""))
		var element_id := String(ability.get("element", ""))
		var shape := String(ability.get("shape", ""))
		var delivery := String(ability.get("delivery", ""))
		var impact := String(ability.get("impact", ""))
		var residue := String(ability.get("residue", ""))
		var material_operation := String(ability.get("material_operation", ""))
		var runtime_status := String(ability.get("runtime_status", ""))
		if ability_id.is_empty() or abilities_by_id.has(ability_id):
			return _fail("ability ids must be non-empty and unique: %s" % ability_id)
		if wire_id <= 0 or ability_ids_by_wire.has(wire_id):
			return _fail("ability wire ids must be positive and unique: %d" % wire_id)
		if not SLOT_KINDS.has(slot_kind):
			return _fail("ability has unknown slot kind: %s" % ability_id)
		if not SHAPES.has(shape) or not DELIVERIES.has(delivery) or not IMPACTS.has(impact) or not RESIDUES.has(residue):
			return _fail("ability has invalid shape contract: %s" % ability_id)
		if not MATERIAL_OPERATIONS.has(material_operation):
			return _fail("ability has invalid material operation: %s" % ability_id)
		if not ability.get("material_runtime_enabled", false) is bool:
			return _fail("ability material runtime gate must be boolean: %s" % ability_id)
		if bool(ability.get("material_runtime_enabled", false)) and material_operation == "none":
			return _fail("enabled material operation cannot be none: %s" % ability_id)
		if not RUNTIME_STATUSES.has(runtime_status):
			return _fail("ability has invalid runtime status: %s" % ability_id)
		if slot_kind == "passive" and shape != "passive":
			return _fail("passive ability requires passive shape: %s" % ability_id)
		if slot_kind == "ultimate" and shape != "ultimate":
			return _fail("ultimate ability requires ultimate shape: %s" % ability_id)
		if slot_kind == "mobility" and shape != "movement":
			return _fail("mobility ability requires movement shape: %s" % ability_id)
		if not element_id.is_empty() and not elements_by_id.has(element_id):
			return _fail("ability has unknown element: %s" % ability_id)
		if not element_id.is_empty() and not bool((elements_by_id[element_id] as Dictionary).get("runtime_enabled", false)):
			return _fail("ability uses a gated element family: %s" % ability_id)
		if String(ability.get("authority", "")) != "simulation":
			return _fail("ability must be simulation-authoritative: %s" % ability_id)
		if (ability.get("roles", []) as Array).is_empty():
			return _fail("ability needs at least one role: %s" % ability_id)
		if (ability.get("counterplay", []) as Array).is_empty():
			return _fail("ability needs explicit counterplay: %s" % ability_id)
		var points := int(ability.get("points", -1))
		var flux_cost := int(ability.get("flux_cost", -1))
		var cooldown_ms := int(ability.get("cooldown_ms", -1))
		var startup_ms := int(ability.get("startup_ms", -1))
		var recovery_ms := int(ability.get("recovery_ms", -1))
		if points < 0 or flux_cost < 0 or cooldown_ms < 0 or startup_ms < 0 or recovery_ms < 0:
			return _fail("ability timing and costs must be non-negative: %s" % ability_id)
		if slot_kind == "active" and (points <= 0 or flux_cost <= 0 or cooldown_ms <= 0 or startup_ms <= 0 or recovery_ms <= 0):
			return _fail("catalog actives require positive points, Flux, cooldown, startup, and recovery: %s" % ability_id)
		if runtime_status == "playable":
			if element_id.is_empty():
				return _fail("every playable spell requires exactly one element: %s" % ability_id)
			var cadence_tier_id := String(ability.get("cadence_tier", ""))
			if not CADENCE_TIER_IDS.has(cadence_tier_id):
				return _fail("runtime spell requires a cadence tier: %s" % ability_id)
			var cadence_tier: Dictionary = cadence_tiers[cadence_tier_id]
			if flux_cost < minimum_runtime_spell_cost:
				return _fail("runtime spell requires positive Flux cost: %s" % ability_id)
			if cooldown_ms < int(cadence_tier["minimum"]) or cooldown_ms > int(cadence_tier["maximum"]):
				return _fail("runtime spell cooldown is outside its cadence tier: %s" % ability_id)
			if startup_ms <= 0 or recovery_ms <= 0:
				return _fail("runtime spell requires positive startup and recovery: %s" % ability_id)
			if not _validate_playable_simulation(ability):
				return false
		if shape == "projectile" and not _valid_projectile_angles(ability.get("projectile_angles_degrees", [0])):
			return _fail("projectile angles must be ordered, odd, centered and symmetric: %s" % ability_id)
		if shape != "projectile" and ability.has("projectile_angles_degrees"):
			return _fail("only projectile spells may declare projectile angles: %s" % ability_id)
		abilities_by_id[ability_id] = ability
		ability_ids_by_wire[wire_id] = ability_id
	if abilities_by_id.is_empty():
		return _fail("ability catalog must not be empty")
	if not _validate_spell_matrix():
		return false
	if not _validate_runtime_wire_order():
		return false
	if not _validate_retained_first_eight_bursts():
		return false
	content_hash = CanonicalContent.sha256(data)
	if content_hash.length() != 64:
		return _fail("ability catalog hash failed")
	return true


func _expanded_abilities() -> Array:
	var authored_value: Variant = data.get("abilities", [])
	if not authored_value is Array:
		_fail("ability catalog abilities must be an array")
		return []
	var result: Array = (authored_value as Array).duplicate(true)
	var matrix_value: Variant = data.get("spell_matrix", {})
	if not matrix_value is Dictionary:
		_fail("spell matrix must be an object")
		return []
	var matrix: Dictionary = matrix_value
	var templates_value: Variant = matrix.get("family_templates", {})
	var operations_value: Variant = matrix.get("element_operations", {})
	var extensions_value: Variant = matrix.get("extensions", [])
	if not templates_value is Dictionary or not operations_value is Dictionary or not extensions_value is Array:
		_fail("spell matrix templates, operations and extensions are required")
		return []
	var templates: Dictionary = templates_value
	var operations: Dictionary = operations_value
	for value: Variant in extensions_value:
		if not value is Dictionary:
			_fail("spell matrix extension must be an object")
			return []
		var extension: Dictionary = value
		var family := String(extension.get("family", ""))
		var element_id := String(extension.get("element", ""))
		if family not in KNOWN_SPELL_FAMILIES or not templates.has(family):
			_fail("spell matrix extension has no valid family template")
			return []
		if element_id not in FIRST_EIGHT_ELEMENTS or not operations.has(element_id):
			_fail("spell matrix extension has no valid element operation")
			return []
		var template_value: Variant = templates[family]
		if not template_value is Dictionary:
			_fail("spell matrix family template must be an object: %s" % family)
			return []
		var template: Dictionary = template_value
		if extension.has("reaction_strength") and (
			not _bounded_integer(template.get("reaction_strength"), 1, 15)
			or not _bounded_integer(extension.get("reaction_strength"), 1, 15)
			or int(extension["reaction_strength"]) != int(template["reaction_strength"])
		):
			_fail("spell matrix extension reaction strength contradicts its family template: %s" % String(extension.get("id", "")))
			return []
		var ability: Dictionary = template.duplicate(true)
		for key: Variant in extension:
			ability[key] = extension[key]
		ability["material_operation"] = String(operations[element_id])
		ability["material_runtime_enabled"] = false
		var runtime_status := String(extension.get("runtime_status", ""))
		if runtime_status not in RUNTIME_STATUSES:
			_fail("spell matrix extension requires an explicit runtime status: %s" % String(extension.get("id", "")))
			return []
		ability["runtime_status"] = runtime_status
		ability["slot_kind"] = "active"
		ability["authority"] = "simulation"
		result.append(ability)
	return result


func _validate_spell_matrix() -> bool:
	var matrix_value: Variant = data.get("spell_matrix", {})
	if not matrix_value is Dictionary:
		return _fail("spell matrix must be an object")
	var matrix: Dictionary = matrix_value
	if matrix.get("row_order", []) != FIRST_EIGHT_ELEMENTS:
		return _fail("spell matrix rows must use the canonical first-eight element order")
	if matrix.get("column_order", []) != SPELL_MATRIX_FAMILIES:
		return _fail("spell matrix columns must use the canonical attack-family order")
	var cells_value: Variant = matrix.get("cells", {})
	if not cells_value is Dictionary:
		return _fail("spell matrix cells must be an object")
	var cells: Dictionary = cells_value
	var claimed: Dictionary = {}
	for element_id: String in FIRST_EIGHT_ELEMENTS:
		var row_value: Variant = cells.get(element_id, [])
		if not row_value is Array or (row_value as Array).size() != SPELL_MATRIX_FAMILIES.size():
			return _fail("spell matrix row must contain every attack family: %s" % element_id)
		var row: Array = row_value
		for column: int in range(SPELL_MATRIX_FAMILIES.size()):
			var ability_id := String(row[column])
			if ability_id.is_empty() or claimed.has(ability_id) or not abilities_by_id.has(ability_id):
				return _fail("spell matrix cell must name one unique known spell: %s/%s" % [element_id, SPELL_MATRIX_FAMILIES[column]])
			var ability: Dictionary = abilities_by_id[ability_id]
			if String(ability.get("runtime_status", "")) != "playable" \
				or String(ability.get("element", "")) != element_id \
				or _spell_family(ability) != SPELL_MATRIX_FAMILIES[column]:
				return _fail("spell matrix cell contradicts its row or column: %s" % ability_id)
			claimed[ability_id] = true
			spell_matrix_ids.append(ability_id)
			spell_matrix_wire_ids.append(int(ability.get("wire_id", 0)))
	if claimed.size() != FIRST_EIGHT_ELEMENTS.size() * SPELL_MATRIX_FAMILIES.size():
		return _fail("spell matrix must fill every element/family cell exactly once")
	return true


static func _spell_family(ability: Dictionary) -> String:
	if String(ability.get("delivery_kernel", "")) == "burst":
		return "burst"
	var declared := String(ability.get("family", ""))
	if declared in KNOWN_SPELL_FAMILIES:
		return declared
	return "bolt" if String(ability.get("shape", "")) == "projectile" else String(ability.get("shape", ""))


static func _valid_projectile_angles(value: Variant) -> bool:
	if not value is Array:
		return false
	var angles: Array = value
	if angles.is_empty() or angles.size() > MAX_PROJECTILE_PATTERN_LANES or angles.size() % 2 == 0:
		return false
	var previous := -181
	for index: int in range(angles.size()):
		if typeof(angles[index]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var angle := int(angles[index])
		if float(angles[index]) != float(angle):
			return false
		if angle < -60 or angle > 60 or angle <= previous:
			return false
		if angle != -int(angles[angles.size() - 1 - index]):
			return false
		previous = angle
	return int(angles[angles.size() / 2]) == 0


func _validate_playable_simulation(ability: Dictionary) -> bool:
	var ability_id := String(ability.get("id", ""))
	var shape := String(ability.get("shape", ""))
	if not _bounded_integer(ability.get("reaction_strength"), 1, 15):
		return _fail("runtime spell reaction_strength must be an integer from 1 through 15: %s/reaction_strength" % ability_id)
	var required_positive: Array[String] = ["radius"]
	match shape:
		"projectile":
			required_positive.append_array(["speed", "damage", "lifetime_ms"])
			if not ability.get("repeat_while_held", false) is bool or (bool(ability.get("repeat_while_held", false)) and _spell_family(ability) != "rapid"):
				return _fail("only Rapid may repeat held spell slots: %s" % ability_id)
			if _spell_family(ability) == "heavy":
				if not _bounded_integer(ability.get("blast_radius"), 1000, 120000) or not _bounded_integer(ability.get("blast_damage"), 1, 100000):
					return _fail("Heavy needs a bounded blast: %s" % ability_id)
			elif ability.has("blast_radius") or ability.has("blast_damage"):
				return _fail("only Heavy owns a terminal blast: %s" % ability_id)
			for angle_value: Variant in ability.get("projectile_angles_degrees", [0]):
				if int(angle_value) not in BURST_ANGLES:
					return _fail("runtime projectile angles have no deterministic rotation: %s/%d" % [ability_id, int(angle_value)])
			if ability.has("remaining_bounces") and not _bounded_integer(ability["remaining_bounces"], 0, 8):
				return _fail("runtime projectile bounce count is invalid: %s" % ability_id)
		"beam", "spray":
			required_positive.append_array(["range", "damage"])
			if shape == "spray":
				required_positive.append("cone_cosine_squared_per_million")
			if not _valid_hit_control(ability):
				return _fail("runtime instant spell hit control is invalid: %s" % ability_id)
		"field":
			required_positive.append_array(["range", "lifetime_ms"])
			if not _valid_hit_control(ability):
				return _fail("runtime field hit control is invalid: %s" % ability_id)
		_:
			return _fail("playable spell has no compiled simulation shape: %s" % ability_id)
	for field: String in required_positive:
		if not _bounded_integer(ability.get(field), 1, 10_000_000):
			return _fail("runtime spell simulation field is invalid: %s/%s" % [ability_id, field])
	return true


func _valid_hit_control(ability: Dictionary) -> bool:
	if not _bounded_integer(ability.get("hit_control_state"), 0, 6) \
		or int(ability["hit_control_state"]) not in [0, 1, 6] \
		or not _bounded_integer(ability.get("hit_control_duration_ms"), 0, 5_000) \
		or not _bounded_integer(ability.get("hit_control_speed"), 0, 2_000_000) \
		or not _bounded_integer(ability.get("hit_control_slow_ratio"), 1, 1_000):
		return false
	return int(ability["hit_control_state"]) == 0 or int(ability["hit_control_duration_ms"]) > 0


static func _bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) == TYPE_INT:
		var integer_value: int = value
		return integer_value >= minimum and integer_value <= maximum
	if typeof(value) != TYPE_FLOAT:
		return false
	var float_value: float = value
	if not is_finite(float_value) or float_value < float(minimum) or float_value > float(maximum):
		return false
	return float_value == float(int(float_value))


func _validate_runtime_wire_order() -> bool:
	var order_value: Variant = data.get("runtime_wire_ids", [])
	if not order_value is Array:
		return _fail("runtime wire order must be an array")
	var seen: Dictionary = {}
	for wire_value: Variant in order_value:
		if not _bounded_integer(wire_value, 1, 65_535):
			return _fail("runtime wire order contains an invalid wire")
		var wire_id := int(wire_value)
		if seen.has(wire_id) or not ability_ids_by_wire.has(wire_id):
			return _fail("runtime wire order must contain unique known wires: %d" % wire_id)
		var entry: Dictionary = ability_from_wire(wire_id)
		if String(entry.get("runtime_status", "")) != "playable":
			return _fail("runtime wire order contains a gated ability: %d" % wire_id)
		seen[wire_id] = true
		runtime_wire_ids.append(wire_id)
	if runtime_wire_ids.size() != playable_spell_ids().size():
		return _fail("runtime wire order must contain every playable spell exactly once")
	if runtime_wire_ids != spell_matrix_wire_ids:
		return _fail("runtime wire order must equal the exact row-major four-family spell matrix")
	return true


func _validate_retained_first_eight_bursts() -> bool:
	var bursts_by_element: Dictionary = {}
	for ability_id: String in abilities_by_id:
		var ability: Dictionary = abilities_by_id[ability_id]
		if not ability.has("delivery_kernel"):
			continue
		if String(ability.get("delivery_kernel", "")) != "burst":
			return _fail("ability declares an unsupported delivery kernel: %s" % ability_id)
		var element_id := String(ability.get("element", ""))
		if element_id not in FIRST_EIGHT_ELEMENTS or bursts_by_element.has(element_id):
			return _fail("first-eight Burst elements must be unique and complete: %s" % element_id)
		if String(ability.get("shape", "")) != "projectile" \
			or String(ability.get("delivery", "")) != "aimed" \
			or String(ability.get("impact", "")) != "damage" \
			or String(ability.get("residue", "")) != "none" \
			or String(ability.get("runtime_status", "")) != "catalog_only" \
			or String(ability.get("slot_kind", "")) != "active" \
			or String(ability.get("cadence_tier", "")) != "tempo" \
			or bool(ability.get("material_runtime_enabled", true)):
			return _fail("retained first-eight Burst delivery contract drifted: %s" % ability_id)
		for field: String in ["points", "affinity_discount", "flux_cost", "cooldown_ms", "startup_ms", "recovery_ms"]:
			var expected: int = int({"points": 5, "affinity_discount": 1, "flux_cost": 16, "cooldown_ms": 900, "startup_ms": 150, "recovery_ms": 160}[field])
			if int(ability.get(field, -1)) != expected:
				return _fail("first-eight Burst economy must remain comparable: %s/%s" % [ability_id, field])
		var angles: Array[int] = []
		for angle: Variant in ability.get("projectile_angles_degrees", []):
			angles.append(int(angle))
		if angles != BURST_ANGLES:
			return _fail("first-eight Burst geometry must remain identical: %s" % ability_id)
		bursts_by_element[element_id] = ability_id
	if bursts_by_element.size() != FIRST_EIGHT_ELEMENTS.size():
		return _fail("ability catalog requires exactly one comparable Burst for every first-eight element")
	for element_id: String in FIRST_EIGHT_ELEMENTS:
		if not bursts_by_element.has(element_id):
			return _fail("ability catalog is missing the %s Burst" % element_id)
	return true


static func element_display_name(element_id: String) -> String:
	return "Air" if element_id == "wind" else element_id.capitalize()


func ability(ability_id: String) -> Dictionary:
	return abilities_by_id.get(ability_id, {})


func ability_id_from_wire(wire_id: int) -> String:
	return String(ability_ids_by_wire.get(wire_id, ""))


func ability_from_wire(wire_id: int) -> Dictionary:
	return ability(ability_id_from_wire(wire_id))


func active_element_ids() -> Array[String]:
	var result: Array[String] = []
	for element_id: String in elements_by_id:
		if bool((elements_by_id[element_id] as Dictionary).get("runtime_enabled", false)):
			result.append(element_id)
	result.sort()
	return result


func playable_spell_ids() -> Array[String]:
	var result: Array[String] = []
	for ability_id: String in abilities_by_id:
		var entry: Dictionary = abilities_by_id[ability_id]
		if String(entry.get("runtime_status", "")) == "playable" and String(entry.get("slot_kind", "")) in ["primary", "active", "mobility"]:
			result.append(ability_id)
	result.sort()
	return result


func spell_id_at(element_id: String, family_id: String) -> String:
	var row := FIRST_EIGHT_ELEMENTS.find(element_id)
	var column := SPELL_MATRIX_FAMILIES.find(family_id)
	var index := row * SPELL_MATRIX_FAMILIES.size() + column
	return spell_matrix_ids[index] if row >= 0 and column >= 0 and index < spell_matrix_ids.size() else ""


func _fail(message: String) -> bool:
	last_error = message
	return false

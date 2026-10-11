class_name ElementDepositState
extends RefCounted

# Reserved wire footprints identify the material role without extra fields.
const TRAIL_RADIUS: int = 20_000
const TERMINAL_MIN_RADIUS: int = 30_000
const TERMINAL_MAX_RADIUS: int = 40_000

var entity_id: int = 0
var source_cast_id: int = 0
var source_wire_id: int = 0
var owner_id: int = 0
var team_id: int = 0
var element_wire_id: int = 0
var position_x: int = 0
var position_y: int = 0
var direction_x: int = 1000
var direction_y: int = 0
var radius: int = TERMINAL_MAX_RADIUS
var strength: int = 1000
var created_tick: int = 0
var expiry_tick: int = 0
var reaction_strength: int = 1

func canonical_values() -> PackedInt64Array:
	return PackedInt64Array([entity_id, source_cast_id, source_wire_id, owner_id, team_id, element_wire_id, position_x, position_y, direction_x, direction_y, radius, strength, created_tick, expiry_tick, reaction_strength])

func validate() -> bool:
	return _validate(false)


# Explicit archive tooling only. Live/network admission always calls validate().
func validate_archive() -> bool:
	return _validate(true)


func _validate(archive: bool) -> bool:
	if not archive:
		if not ElementRules.is_active_wire(element_wire_id): return false
		var definition := CombatTuning.cast_definition_view(source_wire_id)
		if definition.is_empty() or int(definition.get("element_wire_id", 0)) != element_wire_id: return false
	var footprint_valid := (radius >= TERMINAL_MIN_RADIUS and radius <= TERMINAL_MAX_RADIUS) or (is_trail() and strength <= 250 and expiry_tick - created_tick <= 180)
	return entity_id > 0 and entity_id < 2_000_000_000 and source_cast_id > 0 and source_cast_id < 2_000_000_000 and source_wire_id >= 100 and source_wire_id <= 999 and owner_id > 0 and owner_id <= 10000 and team_id > 0 and team_id <= 256 and element_wire_id >= 1 and element_wire_id <= 8 and position_x >= 0 and position_y >= 0 and position_x <= 100_000_000 and position_y <= 100_000_000 and absi(direction_x) <= 1000 and absi(direction_y) <= 1000 and direction_x*direction_x+direction_y*direction_y > 0 and footprint_valid and strength > 0 and strength <= 1000 and created_tick >= 0 and expiry_tick > created_tick and expiry_tick-created_tick <= 600 and expiry_tick < 2_000_000_000 and reaction_strength >= 1 and reaction_strength <= 15

func is_trail() -> bool:
	# A reserved footprint identifies the role without adding snapshot fields.
	return radius == TRAIL_RADIUS

static func from_values(values: PackedInt64Array) -> ElementDepositState:
	if values.size() != 15:
		return null
	var result := ElementDepositState.new()
	var fields: Array[String] = ["entity_id","source_cast_id","source_wire_id","owner_id","team_id","element_wire_id","position_x","position_y","direction_x","direction_y","radius","strength","created_tick","expiry_tick","reaction_strength"]
	for index: int in range(fields.size()):
		result.set(fields[index],values[index])
	return result if result.validate() else null

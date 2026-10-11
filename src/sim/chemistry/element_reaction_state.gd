class_name ElementReactionState
extends RefCounted

const RecipePolicy = preload("res://src/sim/hex/hex_recipe_policy.gd")

const MAX_RADIUS: int = 125_000
const MAX_LENGTH: int = 325_000

var entity_id: int = 0
var recipe_wire_id: int = 0
var owner_id: int = 0
var team_id: int = 0
var position_x: int = 0
var position_y: int = 0
var origin_x: int = 0
var origin_y: int = 0
var direction_x: int = 1000
var direction_y: int = 0
var created_tick: int = 0
var active_tick: int = 0
var decay_tick: int = 0
var expiry_tick: int = 0
var radius: int = 0
var length: int = 0
var health: int = 0
var capacity: int = 0
var pulse_index: int = -1
var source_a: int = 0
var source_b: int = 0
var endpoint_x: int = 0
var endpoint_y: int = 0
# Stable linked source IDs and x/y point pairs; at most four linked deposits.
var linked_deposit_ids := PackedInt64Array()
var path_points := PackedInt64Array()
# Triples actor ID, entered tick, previous inside flag. Only actors that touched
# this result are stored; bounded to the supported player/target actor budget.
var contacts := PackedInt64Array()

func canonical_values() -> PackedInt64Array:
	var values := PackedInt64Array([entity_id, recipe_wire_id, owner_id, team_id, position_x, position_y, origin_x, origin_y, direction_x, direction_y, created_tick, active_tick, decay_tick, expiry_tick, radius, length, health, capacity, pulse_index, source_a, source_b, endpoint_x, endpoint_y])
	for extra: PackedInt64Array in [linked_deposit_ids, path_points, contacts]:
		values.append(extra.size())
		values.append_array(extra)
	return values

func active(tick: int) -> bool:
	return tick >= active_tick and tick < decay_tick

func validate() -> bool:
	return _validate(false)


# Explicit archive tooling only. Live/network admission always calls validate().
func validate_archive() -> bool:
	return _validate(true)


func _validate(archive: bool) -> bool:
	# This two-source legacy container cannot represent finite higher-order pools.
	if not archive and (recipe_wire_id > 336 or RecipePolicy.runtime_definition(recipe_wire_id).is_empty()): return false
	if entity_id <= 0 or entity_id >= 2_000_000_000 or recipe_wire_id < 301 or recipe_wire_id > 336 or owner_id <= 0 or owner_id > 10000 or team_id <= 0 or team_id > 256 or source_a <= 0 or source_b <= 0 or source_a >= 2_000_000_000 or source_b >= 2_000_000_000 or source_a == source_b:
		return false
	for coordinate: int in [position_x,position_y,origin_x,origin_y,endpoint_x,endpoint_y]:
		if coordinate < -1_000_000 or coordinate > 100_000_000:
			return false
	if absi(direction_x) > 1000 or absi(direction_y) > 1000 or direction_x*direction_x+direction_y*direction_y == 0 or created_tick < 0 or active_tick <= created_tick or decay_tick < active_tick or expiry_tick <= decay_tick or expiry_tick-created_tick > 600 or expiry_tick >= 2_000_000_000 or radius < 1000 or radius > MAX_RADIUS or length < 0 or length > MAX_LENGTH or health < 0 or health > 60_000 or capacity < 0 or capacity > 36_000 or pulse_index < -1 or pulse_index >= 2_000_000_000:
		return false
	if linked_deposit_ids.size() > 4 or path_points.size() > 10 or path_points.size()%2 != 0 or contacts.size() > 48 or contacts.size()%3 != 0:
		return false
	if not path_points.is_empty() and path_points.size() != (linked_deposit_ids.size()+1)*2:
		return false
	var seen := {}
	for id: int in linked_deposit_ids:
		if id <= 0 or id >= 2_000_000_000 or seen.has(id):
			return false
		seen[id] = true
	for coordinate: int in path_points:
		if coordinate < -1_000_000 or coordinate > 100_000_000:
			return false
	seen.clear()
	for index: int in range(0,contacts.size(),3):
		if contacts[index] <= 0 or contacts[index] > 10000 or seen.has(contacts[index]) or contacts[index+1] < created_tick or contacts[index+1] >= expiry_tick or contacts[index+2] not in [0,1]:
			return false
		seen[contacts[index]] = true
	return true

static func from_values(values: PackedInt64Array) -> ElementReactionState:
	if values.size() < 26 or values.size() > 88:
		return null
	var result := ElementReactionState.new()
	var fields: Array[String] = ["entity_id","recipe_wire_id","owner_id","team_id","position_x","position_y","origin_x","origin_y","direction_x","direction_y","created_tick","active_tick","decay_tick","expiry_tick","radius","length","health","capacity","pulse_index","source_a","source_b","endpoint_x","endpoint_y"]
	for index: int in range(fields.size()):
		result.set(fields[index],values[index])
	var cursor := fields.size()
	for field: String in ["linked_deposit_ids","path_points","contacts"]:
		if cursor >= values.size():
			return null
		var count: int = values[cursor]
		cursor += 1
		if count < 0 or count > 48 or cursor+count > values.size():
			return null
		result.set(field,values.slice(cursor,cursor+count))
		cursor += count
	return result if cursor == values.size() and result.validate() else null

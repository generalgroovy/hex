class_name FieldState
extends RefCounted


var entity_id: int
var owner_id: int
var team_id: int
var source_wire_id: int
var element_wire_id: int
var position_x: int
var position_y: int
var radius: int
var lifetime_ticks: int
var hit_control_state: int
var hit_control_duration_ms: int
var hit_control_slow_ratio: int
var affected_entity_ids := PackedInt64Array()


func _init(
	requested_entity_id: int,
	requested_owner_id: int,
	requested_team_id: int,
	requested_source_wire_id: int,
	requested_element_wire_id: int,
	requested_position: Vector2i,
	requested_radius: int,
	requested_lifetime_ticks: int,
	requested_hit_control_state: int,
	requested_hit_control_duration_ms: int,
	requested_hit_control_slow_ratio: int,
) -> void:
	entity_id = requested_entity_id
	owner_id = requested_owner_id
	team_id = requested_team_id
	source_wire_id = requested_source_wire_id
	element_wire_id = requested_element_wire_id
	position_x = requested_position.x
	position_y = requested_position.y
	radius = requested_radius
	lifetime_ticks = requested_lifetime_ticks
	hit_control_state = requested_hit_control_state
	hit_control_duration_ms = requested_hit_control_duration_ms
	hit_control_slow_ratio = requested_hit_control_slow_ratio


func has_affected(entity_id_to_find: int) -> bool:
	return affected_entity_ids.has(entity_id_to_find)


func record_affected(affected_entity_id: int) -> void:
	if not affected_entity_ids.has(affected_entity_id):
		affected_entity_ids.append(affected_entity_id)
		affected_entity_ids.sort()


func canonical_values() -> PackedInt64Array:
	var values := PackedInt64Array([
		entity_id, owner_id, team_id, source_wire_id, element_wire_id,
		position_x, position_y, radius, lifetime_ticks,
		hit_control_state, hit_control_duration_ms, hit_control_slow_ratio,
		affected_entity_ids.size(),
	])
	for affected_entity_id: int in affected_entity_ids:
		values.append(affected_entity_id)
	return values

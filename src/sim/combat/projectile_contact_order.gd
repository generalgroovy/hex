class_name ProjectileContactOrder
extends RefCounted

@warning_ignore_start("integer_division")

## Pure per-tick planner for pair contacts between linearly moving circles.
## Runtime strength revalidation and contact resolution intentionally remain
## outside this candidate.

const MAX_RECORDS: int = 128
const MAX_ABS_POSITION: int = 100_000_000
const MAX_RADIUS: int = 125_000
const NAT_BASE: int = 1_000_000


static func plan(records: Array) -> Dictionary:
	if records.size() > MAX_RECORDS:
		return _rejected(&"too_many_records")
	var prepared: Array[Dictionary] = []
	var entity_ids: Dictionary = {}
	for index: int in range(records.size()):
		var value: Variant = records[index]
		if typeof(value) != TYPE_DICTIONARY:
			return _rejected(&"invalid_record")
		var prepared_record: Dictionary = _prepare_record(value, index)
		if prepared_record.is_empty():
			return _rejected(&"invalid_record")
		var entity_id: int = prepared_record[&"entity_id"]
		if entity_ids.has(entity_id):
			return _rejected(&"duplicate_entity_id")
		entity_ids[entity_id] = true
		prepared.append(prepared_record)

	var contacts: Array[Dictionary] = []
	var broadphase_pairs: int = 0
	var quadratic_pairs: int = 0
	for first_index: int in range(prepared.size()):
		var first: Dictionary = prepared[first_index]
		for second_index: int in range(first_index + 1, prepared.size()):
			var second: Dictionary = prepared[second_index]
			if first[&"source_id"] == second[&"source_id"]:
				continue
			broadphase_pairs += 1
			if not _swept_aabbs_overlap(first, second):
				continue
			quadratic_pairs += 1
			var fraction: float = _relative_circle_toi(first, second)
			if fraction < 0.0:
				continue
			# Exclusive wall/cover terminals win exact ties. Inclusive range or
			# ordinary tick-end cutoffs retain a contact at the exact endpoint.
			if not _before_terminal(first, fraction) or not _before_terminal(second, fraction):
				continue
			contacts.append(_contact(first, second, fraction))
	contacts.sort_custom(_contact_less)
	return {
		"accepted": true,
		"reason": &"",
		"contacts": contacts,
		"input_count": prepared.size(),
		"broadphase_pairs": broadphase_pairs,
		"quadratic_pairs": quadratic_pairs,
	}


static func _prepare_record(record: Dictionary, input_index: int) -> Dictionary:
	var integer_fields: Array[StringName] = [
		&"entity_id", &"source_id", &"radius", &"remaining_strength",
	]
	for field: StringName in integer_fields:
		if not record.has(field) or typeof(record[field]) != TYPE_INT:
			return {}
	if not record.has(&"start") or typeof(record[&"start"]) != TYPE_VECTOR2I:
		return {}
	if not record.has(&"finish") or typeof(record[&"finish"]) != TYPE_VECTOR2I:
		return {}
	var entity_id: int = record[&"entity_id"]
	var source_id: int = record[&"source_id"]
	var radius: int = record[&"radius"]
	var remaining_strength: int = record[&"remaining_strength"]
	var start: Vector2i = record[&"start"]
	var finish: Vector2i = record[&"finish"]
	if entity_id <= 0 or source_id <= 0 or remaining_strength <= 0:
		return {}
	if radius < 0 or radius > MAX_RADIUS:
		return {}
	if not _point_in_bounds(start) or not _point_in_bounds(finish):
		return {}
	var terminal_value: Variant = record.get(&"terminal_fraction", 1.0)
	if typeof(terminal_value) != TYPE_FLOAT and typeof(terminal_value) != TYPE_INT:
		return {}
	var terminal_fraction: float = float(terminal_value)
	if not is_finite(terminal_fraction) or terminal_fraction < 0.0 or terminal_fraction > 1.0:
		return {}
	var terminal_inclusive_value: Variant = record.get(&"terminal_inclusive", true)
	if typeof(terminal_inclusive_value) != TYPE_BOOL:
		return {}
	var terminal_inclusive: bool = terminal_inclusive_value
	return {
		"entity_id": entity_id,
		"source_id": source_id,
		"start": start,
		"finish": finish,
		"radius": radius,
		"remaining_strength": remaining_strength,
		"terminal_fraction": terminal_fraction,
		"terminal_inclusive": terminal_inclusive,
		"input_index": input_index,
		"minimum_x": mini(start.x, finish.x) - radius,
		"maximum_x": maxi(start.x, finish.x) + radius,
		"minimum_y": mini(start.y, finish.y) - radius,
		"maximum_y": maxi(start.y, finish.y) + radius,
	}


static func _point_in_bounds(point: Vector2i) -> bool:
	return absi(point.x) <= MAX_ABS_POSITION and absi(point.y) <= MAX_ABS_POSITION


static func _swept_aabbs_overlap(first: Dictionary, second: Dictionary) -> bool:
	return not (
		first[&"maximum_x"] < second[&"minimum_x"]
		or second[&"maximum_x"] < first[&"minimum_x"]
		or first[&"maximum_y"] < second[&"minimum_y"]
		or second[&"maximum_y"] < first[&"minimum_y"]
	)


static func _before_terminal(record: Dictionary, fraction: float) -> bool:
	var cutoff: float = record[&"terminal_fraction"]
	return fraction <= cutoff if record[&"terminal_inclusive"] else fraction < cutoff


static func _relative_circle_toi(first: Dictionary, second: Dictionary) -> float:
	var first_start: Vector2i = first[&"start"]
	var first_finish: Vector2i = first[&"finish"]
	var second_start: Vector2i = second[&"start"]
	var second_finish: Vector2i = second[&"finish"]
	var start_x: int = first_start.x - second_start.x
	var start_y: int = first_start.y - second_start.y
	var end_x: int = first_finish.x - second_finish.x
	var end_y: int = first_finish.y - second_finish.y
	var delta_x: int = end_x - start_x
	var delta_y: int = end_y - start_y
	var combined_radius: int = first[&"radius"] + second[&"radius"]

	if not _relative_segment_intersects_circle(
		start_x, start_y, end_x, end_y, delta_x, delta_y, combined_radius
	):
		return -1.0

	var x: float = float(start_x)
	var y: float = float(start_y)
	var dx: float = float(delta_x)
	var dy: float = float(delta_y)
	var radius_float: float = float(combined_radius)
	var c: float = x * x + y * y - radius_float * radius_float
	if c <= 0.0:
		return 0.0
	var a: float = dx * dx + dy * dy
	if a == 0.0:
		return -1.0
	var h: float = x * dx + y * dy
	var root: float = sqrt(maxf(0.0, h * h - a * c))
	# This stable smaller root avoids cancellation while approaching contact.
	var denominator: float = -h + root
	if denominator <= 0.0:
		return -1.0
	var fraction: float = c / denominator
	if fraction < 0.0 or fraction > 1.0:
		return -1.0
	return fraction


static func _relative_segment_intersects_circle(
	start_x: int,
	start_y: int,
	end_x: int,
	end_y: int,
	delta_x: int,
	delta_y: int,
	radius: int,
) -> bool:
	# All scalar squares, dots, and crosses fit int64 under the declared input
	# envelope. Only the final wide-product comparison needs natural-number limbs.
	var radius_squared: int = radius * radius
	var start_squared: int = start_x * start_x + start_y * start_y
	if start_squared <= radius_squared:
		return true
	var length_squared: int = delta_x * delta_x + delta_y * delta_y
	if length_squared == 0:
		return false
	var projection: int = -(start_x * delta_x + start_y * delta_y)
	if projection <= 0:
		return false
	if projection >= length_squared:
		return end_x * end_x + end_y * end_y <= radius_squared
	var cross: int = absi(start_x * delta_y - start_y * delta_x)
	return _nat_compare(
		_square_term(cross, 1),
		_nat_multiply(_square_term(radius, 1), _nat(length_squared)),
	) <= 0


static func _contact(first: Dictionary, second: Dictionary, fraction: float) -> Dictionary:
	var low: Dictionary = first
	var high: Dictionary = second
	if first[&"entity_id"] > second[&"entity_id"]:
		low = second
		high = first
	return {
		"fraction": fraction,
		"entity_a_id": low[&"entity_id"],
		"entity_b_id": high[&"entity_id"],
		"source_a_id": low[&"source_id"],
		"source_b_id": high[&"source_id"],
		"input_a_index": low[&"input_index"],
		"input_b_index": high[&"input_index"],
		"point": _touching_point(low, high, fraction),
	}


static func _touching_point(first: Dictionary, second: Dictionary, fraction: float) -> Vector2i:
	var first_start: Vector2i = first[&"start"]
	var first_finish: Vector2i = first[&"finish"]
	var second_start: Vector2i = second[&"start"]
	var second_finish: Vector2i = second[&"finish"]
	var first_x: float = float(first_start.x) + float(first_finish.x - first_start.x) * fraction
	var first_y: float = float(first_start.y) + float(first_finish.y - first_start.y) * fraction
	var second_x: float = float(second_start.x) + float(second_finish.x - second_start.x) * fraction
	var second_y: float = float(second_start.y) + float(second_finish.y - second_start.y) * fraction
	var first_radius: int = first[&"radius"]
	var second_radius: int = second[&"radius"]
	var combined_radius: int = first_radius + second_radius
	if combined_radius == 0:
		return Vector2i(roundi((first_x + second_x) * 0.5), roundi((first_y + second_y) * 0.5))
	# At first contact this is the common point on both circle surfaces. For an
	# initial overlap it is the deterministic radius-weighted representative.
	var point_x: float = (
		first_x * float(second_radius) + second_x * float(first_radius)
	) / float(combined_radius)
	var point_y: float = (
		first_y * float(second_radius) + second_y * float(first_radius)
	) / float(combined_radius)
	return Vector2i(roundi(point_x), roundi(point_y))


static func _contact_less(first: Dictionary, second: Dictionary) -> bool:
	var first_fraction: float = first[&"fraction"]
	var second_fraction: float = second[&"fraction"]
	if first_fraction != second_fraction:
		return first_fraction < second_fraction
	var first_a: int = first[&"entity_a_id"]
	var second_a: int = second[&"entity_a_id"]
	if first_a != second_a:
		return first_a < second_a
	return first[&"entity_b_id"] < second[&"entity_b_id"]


static func _square_term(coefficient: int, radicand: int) -> Array[int]:
	return _nat_multiply(
		_nat_multiply(_nat(absi(coefficient)), _nat(absi(coefficient))),
		_nat(radicand),
	)


static func _nat(value: int) -> Array[int]:
	var result: Array[int] = []
	var remaining: int = value
	while remaining > 0:
		result.append(remaining % NAT_BASE)
		remaining /= NAT_BASE
	if result.is_empty():
		result.append(0)
	return result


static func _nat_compare(left: Array[int], right: Array[int]) -> int:
	if left.size() != right.size():
		return -1 if left.size() < right.size() else 1
	for index: int in range(left.size() - 1, -1, -1):
		if left[index] != right[index]:
			return -1 if left[index] < right[index] else 1
	return 0


static func _nat_multiply(left: Array[int], right: Array[int]) -> Array[int]:
	var result: Array[int] = []
	result.resize(left.size() + right.size() + 1)
	for left_index: int in range(left.size()):
		for right_index: int in range(right.size()):
			result[left_index + right_index] += left[left_index] * right[right_index]
	for index: int in range(result.size() - 1):
		if result[index] >= NAT_BASE:
			result[index + 1] += result[index] / NAT_BASE
			result[index] %= NAT_BASE
	return _nat_trim(result)


static func _nat_trim(value: Array[int]) -> Array[int]:
	while value.size() > 1 and value[-1] == 0:
		value.pop_back()
	return value


static func _rejected(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"contacts": [],
		"input_count": 0,
		"broadphase_pairs": 0,
		"quadratic_pairs": 0,
	}

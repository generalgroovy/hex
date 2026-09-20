class_name SprayContactGeometry
extends RefCounted

@warning_ignore_start("integer_division")


# Exact continuous contact for the current finite Spray sector against a static
# circle. The cone uses the same fixed-1000 squared-cosine predicate as Spray.
# Inputs outside the proved runtime envelope fail closed.
const DIRECTION_SCALE_SQUARED: int = 1_000_000
const MAX_ABS_POSITION: int = 100_000_000
const MAX_RANGE: int = 1_000_000
const MAX_CIRCLE_RADIUS: int = 100_000
const MAX_COVER_RADIUS: int = 125_000
const NAT_BASE: int = 1_000_000


static func sector_intersects_circle(
	center: Vector2i,
	aim: Vector2i,
	maximum_range: int,
	cone_cosine_squared_per_million: int,
	circle_center: Vector2i,
	circle_radius: int,
) -> bool:
	return bool(sector_circle_contact(
		center, aim, maximum_range, cone_cosine_squared_per_million,
		circle_center, circle_radius,
	).get("overlaps", false))


static func sector_circle_contact(
	center: Vector2i,
	aim: Vector2i,
	maximum_range: int,
	cone_cosine_squared_per_million: int,
	circle_center: Vector2i,
	circle_radius: int,
) -> Dictionary:
	if not _valid_inputs(center, aim, maximum_range, cone_cosine_squared_per_million, circle_center, circle_radius):
		return {"overlaps": false, "kind": "invalid", "point_available": false}

	var offset := circle_center - center
	var distance_squared := offset.x * offset.x + offset.y * offset.y
	var reach := maximum_range + circle_radius
	if distance_squared > reach * reach:
		return {"overlaps": false, "kind": "separated_range", "point_available": false}
	if distance_squared <= circle_radius * circle_radius:
		return {"overlaps": true, "kind": "origin", "point_available": true, "point": center}
	if maximum_range == 0:
		return {"overlaps": false, "kind": "separated_origin", "point_available": false}

	var projection := offset.x * aim.x + offset.y * aim.y
	if projection >= 0 and projection * projection >= distance_squared * cone_cosine_squared_per_million:
		# The center itself is an exact witness when it is inside the radial cap.
		if distance_squared <= maximum_range * maximum_range:
			return {"overlaps": true, "kind": "circle_center", "point_available": true, "point": circle_center}
		# A circle whose center direction is in the cone and whose disk touches the
		# range disk intersects the sector's radial cap. The continuous witness can
		# be irrational, so do not fabricate a Vector2i point.
		return {"overlaps": true, "kind": "radial_cap", "point_available": false}

	var aim_squared := aim.x * aim.x + aim.y * aim.y
	var side_squared := aim_squared - cone_cosine_squared_per_million
	var cross := aim.x * offset.y - aim.y * offset.x
	# The boundary on the same side as the circle center is the nearest of the
	# two cone sides. If even that finite segment misses, the opposite side does.
	var side_component := absi(cross)
	var side_kind := _boundary_segment_contact(
		projection,
		side_component,
		distance_squared,
		aim_squared,
		cone_cosine_squared_per_million,
		side_squared,
		maximum_range,
		circle_radius,
	)
	if not side_kind.is_empty():
		return {"overlaps": true, "kind": side_kind, "point_available": false, "side": -1 if cross < 0 else 1}
	return {"overlaps": false, "kind": "separated_angle", "point_available": false}


static func segment_intersects_circle(start: Vector2i, end: Vector2i, circle_center: Vector2i, circle_radius: int) -> bool:
	# Segment/circle uses wide cross products; 125000 also covers every valid
	# replicated cover radius. Projectile sector queries retain their own bound.
	if not _segment_point_in_bounds(start) or not _segment_point_in_bounds(end) or not _segment_point_in_bounds(circle_center) or circle_radius < 0 or circle_radius > MAX_COVER_RADIUS:
		return false
	if (
		mini(start.x, end.x) > circle_center.x + circle_radius
		or maxi(start.x, end.x) < circle_center.x - circle_radius
		or mini(start.y, end.y) > circle_center.y + circle_radius
		or maxi(start.y, end.y) < circle_center.y - circle_radius
	):
		return false
	var delta := end - start
	var offset := circle_center - start
	var length_squared := delta.x * delta.x + delta.y * delta.y
	var radius_squared := circle_radius * circle_radius
	if length_squared == 0:
		return offset.x * offset.x + offset.y * offset.y <= radius_squared
	var projection := offset.x * delta.x + offset.y * delta.y
	if projection <= 0:
		return offset.x * offset.x + offset.y * offset.y <= radius_squared
	if projection >= length_squared:
		var from_end := circle_center - end
		return from_end.x * from_end.x + from_end.y * from_end.y <= radius_squared
	var cross := absi(offset.x * delta.y - offset.y * delta.x)
	return _nat_compare(_square_term(cross, 1), _nat_multiply(_square_term(circle_radius, 1), _nat(length_squared))) <= 0


static func _segment_point_in_bounds(point: Vector2i) -> bool:
	# Derived cover endpoints extend beyond the replicated center envelope.
	# At +/-101M, squared lengths/dot/cross remain below 8.2e16; products
	# of those operands still use natural limbs. No authority center bound moves.
	return absi(point.x) <= 101_000_000 and absi(point.y) <= 101_000_000


static func segment_intersects_aabb(start: Vector2i, end: Vector2i, minimum: Vector2i, maximum: Vector2i) -> bool:
	if not _position_in_bounds(start) or not _position_in_bounds(end) or not _position_in_bounds(minimum) or not _position_in_bounds(maximum) or minimum.x > maximum.x or minimum.y > maximum.y:
		return false
	if _point_in_aabb(start, minimum, maximum) or _point_in_aabb(end, minimum, maximum):
		return true
	if maxi(start.x, end.x) < minimum.x or mini(start.x, end.x) > maximum.x or maxi(start.y, end.y) < minimum.y or mini(start.y, end.y) > maximum.y:
		return false
	var top_left := minimum
	var top_right := Vector2i(maximum.x, minimum.y)
	var bottom_right := maximum
	var bottom_left := Vector2i(minimum.x, maximum.y)
	return (
		_segments_intersect(start, end, top_left, top_right)
		or _segments_intersect(start, end, top_right, bottom_right)
		or _segments_intersect(start, end, bottom_right, bottom_left)
		or _segments_intersect(start, end, bottom_left, top_left)
	)


static func _point_in_aabb(point: Vector2i, minimum: Vector2i, maximum: Vector2i) -> bool:
	return point.x >= minimum.x and point.x <= maximum.x and point.y >= minimum.y and point.y <= maximum.y


static func _segments_intersect(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> bool:
	var abc := _orientation(a, b, c)
	var abd := _orientation(a, b, d)
	var cda := _orientation(c, d, a)
	var cdb := _orientation(c, d, b)
	if abc == 0 and _point_on_segment(c, a, b):
		return true
	if abd == 0 and _point_on_segment(d, a, b):
		return true
	if cda == 0 and _point_on_segment(a, c, d):
		return true
	if cdb == 0 and _point_on_segment(b, c, d):
		return true
	return (abc < 0) != (abd < 0) and (cda < 0) != (cdb < 0)


static func _orientation(a: Vector2i, b: Vector2i, c: Vector2i) -> int:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


static func _point_on_segment(point: Vector2i, start: Vector2i, end: Vector2i) -> bool:
	return point.x >= mini(start.x, end.x) and point.x <= maxi(start.x, end.x) and point.y >= mini(start.y, end.y) and point.y <= maxi(start.y, end.y)


static func _boundary_segment_contact(
	forward: int,
	side: int,
	distance_squared: int,
	aim_squared: int,
	threshold: int,
	side_squared: int,
	maximum_range: int,
	circle_radius: int,
) -> String:
	# Projection onto the selected unit boundary is
	# (forward*sqrt(threshold) + side*sqrt(side_squared)) / aim_squared.
	var projection_positive := forward >= 0
	if not projection_positive:
		projection_positive = _root_term_compare(side, side_squared, -forward, threshold) > 0
	if not projection_positive:
		return ""

	var radial_numerator := aim_squared * maximum_range
	var projection_within := (
		_sum_roots_le(forward, threshold, side, side_squared, radial_numerator)
		if forward >= 0
		else _difference_roots_le(side, side_squared, -forward, threshold, radial_numerator)
	)
	if projection_within:
		var normal_limit := circle_radius * aim_squared
		var normal_hit := (
			_absolute_root_difference_le(side, threshold, forward, side_squared, normal_limit)
			if forward >= 0
			else _sum_roots_le(side, threshold, -forward, side_squared, normal_limit)
		)
		return "cone_side" if normal_hit else ""

	# The closest point on the finite boundary is its radial endpoint. Compare
	# |q-R*boundary|^2 <= r^2 after multiplying by aim_squared. No irrational
	# point or overflowing triple product is materialized.
	var required := aim_squared * (
		distance_squared + maximum_range * maximum_range - circle_radius * circle_radius
	)
	if required <= 0:
		return "sector_corner"
	var scale := 2 * maximum_range
	var endpoint_hit := (
		_sum_roots_ge(forward * scale, threshold, side * scale, side_squared, required)
		if forward >= 0
		else _difference_roots_ge(side * scale, side_squared, -forward * scale, threshold, required)
	)
	return "sector_corner" if endpoint_hit else ""


static func _valid_inputs(center: Vector2i, aim: Vector2i, maximum_range: int, threshold: int, circle_center: Vector2i, circle_radius: int) -> bool:
	if not _position_in_bounds(center) or not _position_in_bounds(circle_center):
		return false
	if absi(aim.x) > 1000 or absi(aim.y) > 1000:
		return false
	var aim_squared := aim.x * aim.x + aim.y * aim.y
	return (
		aim_squared > 0
		and threshold > 0
		and threshold < aim_squared
		and threshold < DIRECTION_SCALE_SQUARED
		and maximum_range >= 0
		and maximum_range <= MAX_RANGE
		and circle_radius >= 0
		and circle_radius <= MAX_CIRCLE_RADIUS
	)


static func _position_in_bounds(value: Vector2i) -> bool:
	return absi(value.x) <= MAX_ABS_POSITION and absi(value.y) <= MAX_ABS_POSITION


# The helpers below compare nonnegative integer square-root expressions using
# base-10^6 natural-number limbs. Limb products and accumulators remain below
# 10^13, safely inside signed 64-bit integers. This is release-time geometry,
# not a per-tick projectile loop; exactness takes priority over allocation.
static func _sum_roots_le(x: int, m: int, y: int, n: int, z: int) -> bool:
	if x < 0 or y < 0 or z < 0:
		return false
	var left := _square_term(x, m)
	var right := _square_term(y, n)
	var z_squared := _square_term(z, 1)
	var sum := _nat_add(left, right)
	if _nat_compare(sum, z_squared) > 0:
		return false
	var residual := _nat_subtract(z_squared, sum)
	return _nat_compare(_nat_scale(_nat_multiply(left, right), 4), _nat_multiply(residual, residual)) <= 0


static func _sum_roots_ge(x: int, m: int, y: int, n: int, z: int) -> bool:
	if x < 0 or y < 0:
		return false
	if z <= 0:
		return true
	var left := _square_term(x, m)
	var right := _square_term(y, n)
	var z_squared := _square_term(z, 1)
	var sum := _nat_add(left, right)
	if _nat_compare(sum, z_squared) >= 0:
		return true
	var residual := _nat_subtract(z_squared, sum)
	return _nat_compare(_nat_scale(_nat_multiply(left, right), 4), _nat_multiply(residual, residual)) >= 0


static func _difference_roots_le(x: int, m: int, y: int, n: int, z: int) -> bool:
	if x < 0 or y < 0 or z < 0:
		return false
	var left := _square_term(x, m)
	var right := _square_term(y, n)
	if _nat_compare(left, right) <= 0:
		return true
	var z_squared := _square_term(z, 1)
	var sum := _nat_add(left, right)
	if _nat_compare(sum, z_squared) <= 0:
		return true
	var residual := _nat_subtract(sum, z_squared)
	return _nat_compare(_nat_multiply(residual, residual), _nat_scale(_nat_multiply(left, right), 4)) <= 0


static func _difference_roots_ge(x: int, m: int, y: int, n: int, z: int) -> bool:
	if x < 0 or y < 0:
		return false
	if z <= 0:
		return true
	var left := _square_term(x, m)
	var right := _square_term(y, n)
	if _nat_compare(left, right) < 0:
		return false
	var z_squared := _square_term(z, 1)
	var sum := _nat_add(left, right)
	if _nat_compare(sum, z_squared) < 0:
		return false
	var residual := _nat_subtract(sum, z_squared)
	return _nat_compare(_nat_multiply(residual, residual), _nat_scale(_nat_multiply(left, right), 4)) >= 0


static func _absolute_root_difference_le(x: int, m: int, y: int, n: int, z: int) -> bool:
	return (
		_difference_roots_le(x, m, y, n, z)
		if _root_term_compare(x, m, y, n) >= 0
		else _difference_roots_le(y, n, x, m, z)
	)


static func _root_term_compare(x: int, m: int, y: int, n: int) -> int:
	return _nat_compare(_square_term(x, m), _square_term(y, n))


static func _square_term(coefficient: int, radicand: int) -> Array[int]:
	return _nat_multiply(_nat_multiply(_nat(absi(coefficient)), _nat(absi(coefficient))), _nat(radicand))


static func _nat(value: int) -> Array[int]:
	var result: Array[int] = []
	var remaining := value
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


static func _nat_add(left: Array[int], right: Array[int]) -> Array[int]:
	var result: Array[int] = []
	var carry := 0
	for index: int in range(maxi(left.size(), right.size())):
		var value := carry
		if index < left.size():
			value += left[index]
		if index < right.size():
			value += right[index]
		result.append(value % NAT_BASE)
		carry = value / NAT_BASE
	if carry > 0:
		result.append(carry)
	return result


static func _nat_subtract(left: Array[int], right: Array[int]) -> Array[int]:
	# Callers prove left >= right.
	var result: Array[int] = []
	var borrow := 0
	for index: int in range(left.size()):
		var value := left[index] - borrow - (right[index] if index < right.size() else 0)
		if value < 0:
			value += NAT_BASE
			borrow = 1
		else:
			borrow = 0
		result.append(value)
	return _nat_trim(result)


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


static func _nat_scale(value: Array[int], scalar: int) -> Array[int]:
	return _nat_multiply(value, _nat(scalar))


static func _nat_trim(value: Array[int]) -> Array[int]:
	while value.size() > 1 and value[-1] == 0:
		value.pop_back()
	return value

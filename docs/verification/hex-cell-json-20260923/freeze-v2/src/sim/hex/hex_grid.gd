class_name HexGrid
extends RefCounted

@warning_ignore_start("integer_division")


# Pointy-top axial geometry in fixed world units (1000 units per pixel).
# HALF_HEIGHT is the even integer approximation of 24000 / sin(60 deg),
# and ROW_PITCH is exactly 3 * HALF_HEIGHT / 2. These authored integers make
# shared faces coincide exactly. The 48px face-to-face width is 25% smaller
# than the previous 64px grid; actor sizes and world-space spell radii stay fixed.
const HALF_WIDTH: int = 24_000
const HALF_HEIGHT: int = 27_712
const ROW_PITCH: int = HALF_HEIGHT * 3 / 2
const COLUMN_PITCH: int = HALF_WIDTH * 2
const MAX_ABS_QUERY_COORDINATE: int = 8_000_000
const MAX_SWEEP_RADIUS: int = 512_000
const NAT_BASE: int = 1_000_000

const LOCAL_VERTICES: Array[Vector2i] = [
	Vector2i(0, -HALF_HEIGHT),
	Vector2i(HALF_WIDTH, -HALF_HEIGHT / 2),
	Vector2i(HALF_WIDTH, HALF_HEIGHT / 2),
	Vector2i(0, HALF_HEIGHT),
	Vector2i(-HALF_WIDTH, HALF_HEIGHT / 2),
	Vector2i(-HALF_WIDTH, -HALF_HEIGHT / 2),
]

const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(1, -1),
	Vector2i(1, 0),
]


static func center(cell: Vector2i) -> Vector2i:
	return Vector2i(
		COLUMN_PITCH * cell.x + HALF_WIDTH * cell.y,
		ROW_PITCH * cell.y,
	)


static func vertices(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cell_center := center(cell)
	for local_vertex: Vector2i in LOCAL_VERTICES:
		result.append(cell_center + local_vertex)
	return result


static func world_to_cell(point: Vector2i) -> Vector2i:
	# The inverse lattice transform supplies only a local seed. Membership is
	# decided against every nearby closed polygon so face/vertex ownership can
	# select the lexicographically smallest (q,r), including at negative values.
	var seed_r := _floor_div(point.y, ROW_PITCH)
	var q_numerator := 2 * ROW_PITCH * point.x - COLUMN_PITCH * point.y
	var seed_q := _floor_div(q_numerator, 2 * COLUMN_PITCH * ROW_PITCH)
	var owners: Array[Vector2i] = []
	for q: int in range(seed_q - 2, seed_q + 3):
		for r: int in range(seed_r - 2, seed_r + 3):
			var candidate := Vector2i(q, r)
			if _point_in_cell(point, candidate):
				owners.append(candidate)
	owners.sort_custom(_cell_less)
	# The authored polygons tile the plane. This fallback is defensive against
	# malformed future constants and remains deterministic without a world scan.
	return owners[0] if not owners.is_empty() else Vector2i(seed_q, seed_r)


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in AXIAL_DIRECTIONS:
		result.append(cell + direction)
	# AXIAL_DIRECTIONS is already lexicographic, but sort here so the public
	# ordering contract does not depend on the declaration layout.
	result.sort_custom(_cell_less)
	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	var delta := b - a
	return maxi(absi(delta.x), maxi(absi(delta.y), absi(delta.x + delta.y)))


static func disk(center_cell: Vector2i, radius_cells: int) -> Array[Vector2i]:
	if radius_cells < 0:
		return []
	var result: Array[Vector2i] = []
	for delta_q: int in range(-radius_cells, radius_cells + 1):
		var minimum_r := maxi(-radius_cells, -delta_q - radius_cells)
		var maximum_r := mini(radius_cells, -delta_q + radius_cells)
		for delta_r: int in range(minimum_r, maximum_r + 1):
			result.append(center_cell + Vector2i(delta_q, delta_r))
	result.sort_custom(_cell_less)
	return result


static func ring(center_cell: Vector2i, radius_cells: int) -> Array[Vector2i]:
	if radius_cells < 0:
		return []
	if radius_cells == 0:
		return [center_cell]
	var result: Array[Vector2i] = []
	for cell: Vector2i in disk(center_cell, radius_cells):
		if distance(center_cell, cell) == radius_cells:
			result.append(cell)
	return result


static func swept_cells(start: Vector2i, end: Vector2i, radius_world_units: int) -> Array[Vector2i]:
	if (
		radius_world_units < 0
		or radius_world_units > MAX_SWEEP_RADIUS
		or not _query_point_valid(start)
		or not _query_point_valid(end)
	):
		return []
	if radius_world_units == 0:
		var interior_cell := world_to_cell(start)
		if _point_strictly_in_cell(start, interior_cell) and _point_strictly_in_cell(end, interior_cell):
			# A segment between two strictly interior points of one convex hex is
			# wholly strict interior. Closed face/vertex ownership must keep using
			# the general path, so this proof deliberately rejects zero half-planes.
			var interior_result: Array[Vector2i] = [interior_cell]
			return interior_result

	# Axial space is an affine transform of world space. Twice the endpoint
	# cube distance plus a two-cell endpoint allowance gives sub-cell sampling
	# along the segment. A conservative graph halo then covers every hex whose
	# polygon can approach the segment by radius_world_units. Work scales with
	# segment length and requested thickness; it never scans a world rectangle.
	var start_cell := world_to_cell(start)
	var end_cell := world_to_cell(end)
	var step_count := maxi(1, 2 * (distance(start_cell, end_cell) + 2))
	var halo_numerator := radius_world_units + 2 * HALF_HEIGHT
	var halo_radius := _ceil_div(halo_numerator, ROW_PITCH) + 1
	var candidates: Dictionary[Vector2i, bool] = {}
	for step_index: int in range(step_count + 1):
		var sample := Vector2i(
			_interpolate_component(start.x, end.x, step_index, step_count),
			_interpolate_component(start.y, end.y, step_index, step_count),
		)
		for candidate: Vector2i in disk(world_to_cell(sample), halo_radius):
			candidates[candidate] = true

	var result: Array[Vector2i] = []
	for candidate: Vector2i in candidates:
		if _capsule_intersects_cell(start, end, radius_world_units, candidate):
			result.append(candidate)
	result.sort_custom(_cell_less)
	return result


static func _query_point_valid(point: Vector2i) -> bool:
	return absi(point.x) <= MAX_ABS_QUERY_COORDINATE and absi(point.y) <= MAX_ABS_QUERY_COORDINATE


static func _point_in_cell(point: Vector2i, cell: Vector2i) -> bool:
	var polygon := vertices(cell)
	for index: int in range(polygon.size()):
		if _orientation(polygon[index], polygon[(index + 1) % polygon.size()], point) < 0:
			return false
	return true


static func _point_strictly_in_cell(point: Vector2i, cell: Vector2i) -> bool:
	var polygon := vertices(cell)
	for index: int in range(polygon.size()):
		if _orientation(polygon[index], polygon[(index + 1) % polygon.size()], point) <= 0:
			return false
	return true


static func _capsule_intersects_cell(start: Vector2i, end: Vector2i, radius: int, cell: Vector2i) -> bool:
	var polygon := vertices(cell)
	if _point_in_cell(start, cell) or _point_in_cell(end, cell):
		return true
	for index: int in range(polygon.size()):
		var edge_start: Vector2i = polygon[index]
		var edge_end: Vector2i = polygon[(index + 1) % polygon.size()]
		if _segments_intersect(start, end, edge_start, edge_end):
			return true
	if radius == 0:
		return false
	# For two disjoint closed segments, a minimum-distance witness is an
	# endpoint of at least one segment. Test both families for every hex edge.
	for index: int in range(polygon.size()):
		var edge_start: Vector2i = polygon[index]
		var edge_end: Vector2i = polygon[(index + 1) % polygon.size()]
		if (
			_point_segment_within_radius(edge_start, start, end, radius)
			or _point_segment_within_radius(start, edge_start, edge_end, radius)
			or _point_segment_within_radius(end, edge_start, edge_end, radius)
		):
			return true
	return false


static func _point_segment_within_radius(point: Vector2i, start: Vector2i, end: Vector2i, radius: int) -> bool:
	var delta := end - start
	var offset := point - start
	var length_squared := delta.x * delta.x + delta.y * delta.y
	var radius_squared := radius * radius
	if length_squared == 0:
		return offset.x * offset.x + offset.y * offset.y <= radius_squared
	var projection := offset.x * delta.x + offset.y * delta.y
	if projection <= 0:
		return offset.x * offset.x + offset.y * offset.y <= radius_squared
	if projection >= length_squared:
		var from_end := point - end
		return from_end.x * from_end.x + from_end.y * from_end.y <= radius_squared
	var cross := absi(offset.x * delta.y - offset.y * delta.x)
	# Within the explicit 8M/512k query envelope, cross/dot/sign terms fit
	# signed int64. Their squared comparison can exceed int64, so compare exact
	# base-1M natural-number products instead of converting to float.
	var cross_squared := _nat_multiply(_nat(cross), _nat(cross))
	var limit := _nat_multiply(_nat(radius_squared), _nat(length_squared))
	return _nat_compare(cross_squared, limit) <= 0


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
	return (
		point.x >= mini(start.x, end.x)
		and point.x <= maxi(start.x, end.x)
		and point.y >= mini(start.y, end.y)
		and point.y <= maxi(start.y, end.y)
	)


static func _interpolate_component(start: int, end: int, index: int, count: int) -> int:
	var numerator := (end - start) * index
	if numerator >= 0:
		return start + (numerator + count / 2) / count
	return start - (-numerator + count / 2) / count


static func _floor_div(numerator: int, denominator: int) -> int:
	var quotient := numerator / denominator
	if numerator < 0 and numerator % denominator != 0:
		quotient -= 1
	return quotient


static func _ceil_div(numerator: int, denominator: int) -> int:
	return (numerator + denominator - 1) / denominator


static func _cell_less(left: Vector2i, right: Vector2i) -> bool:
	return left.x < right.x or (left.x == right.x and left.y < right.y)


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
	while result.size() > 1 and result[-1] == 0:
		result.pop_back()
	return result

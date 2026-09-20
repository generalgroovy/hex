class_name HexFootprint
extends RefCounted

@warning_ignore_start("integer_division")


const Grid = preload("res://src/sim/hex/hex_grid.gd")
const ContactGeometry = preload("res://src/sim/combat/spray_contact_geometry.gd")

const KIND_DISK := "disk"
const KIND_SECTOR := "sector"
const KIND_INTERSECTION := "intersection"
const MAX_DISK_RADIUS: int = 256_000
const MAX_SECTOR_RANGE: int = 512_000
const MAX_RADIUS: int = MAX_DISK_RADIUS # Compatibility name for radial callers.
const VISUAL_SEGMENTS: int = 128
const VISUAL_INSET: int = 2
const PARAMETER_EPSILON: float = 1.0e-12
const AREA_EPSILON: float = 1.0e-6
const DISTANCE_SQUARED_EPSILON: float = 1.0e-3
const MAX_COMPOSITE_DEPTH: int = 2
const MAX_COMPOSITE_PRIMITIVES: int = 4


static func disk(center: Vector2i, radius: int) -> Dictionary:
	return {"kind": KIND_DISK, "center": center, "radius": radius}


static func sector(start: Vector2i, aim: Vector2i, reach: int, cosine_squared: int) -> Dictionary:
	return {
		"kind": KIND_SECTOR,
		"start": start,
		"aim": aim,
		"range": reach,
		"cosine_squared": cosine_squared,
	}


static func intersection(first: Dictionary, second: Dictionary) -> Dictionary:
	return {"kind": KIND_INTERSECTION, "parts": [first.duplicate(true), second.duplicate(true)]}


static func validate(footprint: Dictionary) -> bool:
	return _validate_at_depth(footprint, 0) and _primitive_count(footprint) <= MAX_COMPOSITE_PRIMITIVES


static func _validate_at_depth(footprint: Dictionary, depth: int) -> bool:
	match String(footprint.get("kind", "")):
		KIND_DISK:
			return (
				footprint.get("center") is Vector2i
				and int(footprint.get("radius", -1)) >= 0
				and int(footprint.get("radius", -1)) <= MAX_DISK_RADIUS
				and _world_point_valid(footprint.center)
			)
		KIND_SECTOR:
			if not (footprint.get("start") is Vector2i and footprint.get("aim") is Vector2i):
				return false
			var aim: Vector2i = footprint.aim
			var aim_squared: int = aim.x * aim.x + aim.y * aim.y
			var threshold := int(footprint.get("cosine_squared", -1))
			return (
				_world_point_valid(footprint.start)
				and absi(aim.x) <= 1_000
				and absi(aim.y) <= 1_000
				and aim_squared > 0
				and threshold > 0
				and threshold < aim_squared
				and int(footprint.get("range", -1)) >= 0
				and int(footprint.get("range", -1)) <= MAX_SECTOR_RANGE
			)
		KIND_INTERSECTION:
			var parts: Array = footprint.get("parts", [])
			return (
				depth < MAX_COMPOSITE_DEPTH
				and parts.size() == 2
				and parts[0] is Dictionary
				and parts[1] is Dictionary
				and _validate_at_depth(parts[0], depth + 1)
				and _validate_at_depth(parts[1], depth + 1)
			)
	return false


static func _primitive_count(footprint: Dictionary) -> int:
	if String(footprint.get("kind", "")) != KIND_INTERSECTION:
		return 1
	var count := 0
	for part: Dictionary in footprint.get("parts", []):
		count += _primitive_count(part)
	return count


static func contains(footprint: Dictionary, point: Vector2i) -> bool:
	if not validate(footprint) or not _world_point_valid(point):
		return false
	match String(footprint.kind):
		KIND_DISK:
			var offset: Vector2i = point - footprint.center
			var radius := int(footprint.radius)
			return offset.x * offset.x + offset.y * offset.y <= radius * radius
		KIND_SECTOR:
			return _sector_contains(footprint, point)
		KIND_INTERSECTION:
			var parts: Array = footprint.parts
			return contains(parts[0], point) and contains(parts[1], point)
	return false


static func segment_intersects(footprint: Dictionary, start: Vector2i, end: Vector2i) -> bool:
	if not validate(footprint) or not _world_point_valid(start) or not _world_point_valid(end):
		return false
	var interval := _segment_interval(footprint, start, end)
	return bool(interval.get("hit", false))


# Continuous entry/exit parameters for authoritative center-path queries.
# Integer predicates decide disk contact, including exact tangency; scalar
# Float64 retains the bounded parameter interval and callers quantize a world
# point once after choosing a contact. This helper never expands the footprint.
static func segment_interval(footprint: Dictionary, start: Vector2i, end: Vector2i) -> Dictionary:
	if not validate(footprint) or not _world_point_valid(start) or not _world_point_valid(end):
		return _empty_interval()
	return _segment_interval(footprint, start, end)


# Earliest center-path interval that lies in both the analytic footprint and
# the closed union of this source's actually stored hex polygons. A boundary
# shared by two stored cells remains eligible; lexicographic cell order makes
# exact ties deterministic without assigning global ownership to one cell.
static func stored_segment_interval(footprint: Dictionary, stored_cells: Dictionary, grid_origin: Vector2i, start: Vector2i, end: Vector2i) -> Dictionary:
	if stored_cells.is_empty():
		return _empty_interval()
	var footprint_interval := segment_interval(footprint, start, end)
	if not bool(footprint_interval.get("hit", false)):
		return footprint_interval
	var touched := {}
	for cell: Vector2i in Grid.swept_cells(start - grid_origin, end - grid_origin, 0):
		touched[cell] = true
	var ordered: Array[Vector2i] = []
	for cell: Vector2i in stored_cells:
		if int(stored_cells[cell]) > 0 and touched.has(cell):
			ordered.append(cell)
	ordered.sort_custom(Grid._cell_less)
	var best := _empty_interval()
	var best_cell := Vector2i.ZERO
	for cell: Vector2i in ordered:
		var cell_interval := _cell_segment_interval(cell, grid_origin, start, end)
		if not bool(cell_interval.get("hit", false)):
			continue
		var low := maxf(float(footprint_interval.low), float(cell_interval.low))
		var high := minf(float(footprint_interval.high), float(cell_interval.high))
		if low > high + PARAMETER_EPSILON:
			continue
		if not bool(best.get("hit", false)) or low < float(best.low) or (low == float(best.low) and Grid._cell_less(cell, best_cell)):
			best = {"hit": true, "low": low, "high": high, "cell": cell}
			best_cell = cell
	if bool(best.get("hit", false)):
		var fraction := float(best.low)
		var continuous := _scalar_point(
			float(start.x) + float(end.x - start.x) * fraction,
			float(start.y) + float(end.y - start.y) * fraction)
		var witness := _quantized_stored_witness(footprint, stored_cells, grid_origin, continuous, best_cell)
		for key: Variant in witness:
			best[key] = witness[key]
	return best


# Deterministic common witness constrained to a source's stored-cell union.
# This is used by instantaneous Spray contacts, which have no traversal time.
static func contact_point_in_cells(first: Dictionary, second: Dictionary, preferred: Vector2i, stored_cells: Dictionary, grid_origin: Vector2i) -> Dictionary:
	if stored_cells.is_empty() or not intersects(first, second):
		return {}
	var shared := intersection(first, second)
	if not validate(shared):
		return {}
	var primitives := _primitive_parts(shared)
	var candidates := _common_point_candidates(primitives)
	# Boundary crossings alone can all lie on the Spray terminal arc even
	# when a disk extends just inside it. Include the closest point on each
	# primitive to the requested origin before selecting a stored witness.
	for primitive: Dictionary in primitives:
		if String(primitive.kind) == KIND_DISK:
			var center: Vector2i = primitive.center
			var dx := float(preferred.x - center.x)
			var dy := float(preferred.y - center.y)
			var distance := sqrt(dx * dx + dy * dy)
			var ratio := minf(1.0, float(primitive.radius) / distance) if distance > 0.0 else 0.0
			candidates.append(_scalar_point(float(center.x) + dx * ratio, float(center.y) + dy * ratio))
		elif String(primitive.kind) == KIND_SECTOR:
			candidates.append(_closest_point_in_sector(primitive, float(preferred.x), float(preferred.y)))
	candidates.append(_scalar_point(float(preferred.x), float(preferred.y)))
	var ordered: Array[Vector2i] = []
	for cell: Vector2i in stored_cells:
		if int(stored_cells[cell]) > 0:
			ordered.append(cell)
	ordered.sort_custom(Grid._cell_less)
	for cell: Vector2i in ordered:
		var polygon: Array[Vector2i] = []
		for local: Vector2i in Grid.vertices(cell):
			var vertex := local + grid_origin
			polygon.append(vertex)
			candidates.append(_scalar_point(float(vertex.x), float(vertex.y)))
		for edge_index: int in range(polygon.size()):
			var edge_start: Vector2i = polygon[edge_index]
			var edge_end: Vector2i = polygon[(edge_index + 1) % polygon.size()]
			var interval := _segment_interval(shared, edge_start, edge_end)
			if not bool(interval.get("hit", false)):
				continue
			for fraction: float in [float(interval.low), float(interval.high)]:
				candidates.append(_scalar_point(
					float(edge_start.x) + float(edge_end.x - edge_start.x) * fraction,
					float(edge_start.y) + float(edge_end.y - edge_start.y) * fraction))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ax := float(a.x) - float(preferred.x)
		var ay := float(a.y) - float(preferred.y)
		var bx := float(b.x) - float(preferred.x)
		var by := float(b.y) - float(preferred.y)
		var ad := ax * ax + ay * ay
		var bd := bx * bx + by * by
		if ad != bd: return ad < bd
		return float(a.x) < float(b.x) if float(a.x) != float(b.x) else float(a.y) < float(b.y))
	for continuous: Dictionary in candidates:
		if not _scalar_in_all(primitives, continuous):
			continue
		for cell: Vector2i in ordered:
			var stored_polygon: Array[Vector2i] = []
			for local: Vector2i in Grid.vertices(cell): stored_polygon.append(local + grid_origin)
			if _float_point_in_polygon(continuous, stored_polygon):
				return _quantized_stored_witness(shared, stored_cells, grid_origin, continuous, cell)
	return {}


# Fixed-grid authority retains the proved continuous collision and quantizes its
# witness by at most one world unit (0.001 px). Prefer the closest floor/ceil
# lattice point that is still inside both the analytic footprint and the closed
# stored-cell union. A true subunit tangency can have no such lattice point; in
# that case retain the nearest rounded witness and mark the bounded exception
# instead of deleting a real analytic collision or moving it farther inward.
static func _quantized_stored_witness(footprint: Dictionary, stored_cells: Dictionary, grid_origin: Vector2i, continuous: Dictionary, fallback_cell: Vector2i) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var seen := {}
	for x: int in [floori(float(continuous.x)), ceili(float(continuous.x))]:
		for y: int in [floori(float(continuous.y)), ceili(float(continuous.y))]:
			var lattice := Vector2i(x, y)
			if seen.has(lattice):
				continue
			seen[lattice] = true
			var dx := float(x) - float(continuous.x)
			var dy := float(y) - float(continuous.y)
			var error_squared := dx * dx + dy * dy
			if error_squared <= 1.0 + PARAMETER_EPSILON:
				candidates.append({"point": lattice, "error_squared": error_squared})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.error_squared) != float(b.error_squared):
			return float(a.error_squared) < float(b.error_squared)
		var first: Vector2i = a.point
		var second: Vector2i = b.point
		return first.x < second.x if first.x != second.x else first.y < second.y)
	for candidate: Dictionary in candidates:
		var point: Vector2i = candidate.point
		if not contains(footprint, point):
			continue
		var owner := _stored_cell_owner(point, stored_cells, grid_origin)
		if owner.is_empty():
			continue
		return {
			"point": point,
			"cell": owner.cell,
			"continuous_x": float(continuous.x),
			"continuous_y": float(continuous.y),
			"quantization_error_squared": float(candidate.error_squared),
			"quantization_outside": false,
		}
	var rounded := Vector2i(roundi(float(continuous.x)), roundi(float(continuous.y)))
	var rounded_dx := float(rounded.x) - float(continuous.x)
	var rounded_dy := float(rounded.y) - float(continuous.y)
	var rounded_error_squared := rounded_dx * rounded_dx + rounded_dy * rounded_dy
	assert(rounded_error_squared <= 1.0 + PARAMETER_EPSILON, "nearest fixed-grid witness stays within one world unit")
	return {
		"point": rounded,
		"cell": fallback_cell,
		"continuous_x": float(continuous.x),
		"continuous_y": float(continuous.y),
		"quantization_error_squared": rounded_error_squared,
		"quantization_outside": true,
	}


static func _stored_cell_owner(point: Vector2i, stored_cells: Dictionary, grid_origin: Vector2i) -> Dictionary:
	var owners: Array[Vector2i] = []
	for cell: Vector2i in stored_cells:
		if int(stored_cells[cell]) > 0 and Grid._point_in_cell(point - grid_origin, cell):
			owners.append(cell)
	owners.sort_custom(Grid._cell_less)
	return {"cell": owners[0]} if not owners.is_empty() else {}


static func intersects(first: Dictionary, second: Dictionary) -> bool:
	if not validate(first) or not validate(second):
		return false
	if String(first.kind) == KIND_INTERSECTION or String(second.kind) == KIND_INTERSECTION:
		var primitives := _primitive_parts(first)
		primitives.append_array(_primitive_parts(second))
		return primitives.size() <= MAX_COMPOSITE_PRIMITIVES and _primitives_have_common_point(primitives)
	if String(first.kind) == KIND_DISK and String(second.kind) == KIND_DISK:
		var offset: Vector2i = second.center - first.center
		var reach := int(first.radius) + int(second.radius)
		return offset.x * offset.x + offset.y * offset.y <= reach * reach
	if String(first.kind) == KIND_DISK and String(second.kind) == KIND_SECTOR:
		return _disk_sector_intersects(first, second)
	if String(first.kind) == KIND_SECTOR and String(second.kind) == KIND_DISK:
		return _disk_sector_intersects(second, first)
	if String(first.kind) == KIND_SECTOR and String(second.kind) == KIND_SECTOR:
		return _sector_sector_intersects(first, second)
	return false


# Instantaneously created overlapping footprints use the nearest common
# analytic witness to their authored impact. This is not a cell-center snap.
static func contact_point(first: Dictionary, second: Dictionary, preferred: Vector2i) -> Dictionary:
	if not intersects(first, second): return {}
	var primitives := _primitive_parts(first)
	primitives.append_array(_primitive_parts(second))
	var candidates := _common_point_candidates(primitives)
	candidates.append(_scalar_point(float(preferred.x), float(preferred.y)))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ax := float(a.x) - float(preferred.x)
		var ay := float(a.y) - float(preferred.y)
		var bx := float(b.x) - float(preferred.x)
		var by := float(b.y) - float(preferred.y)
		var ad := ax * ax + ay * ay
		var bd := bx * bx + by * by
		if ad != bd: return ad < bd
		return float(a.x) < float(b.x) if float(a.x) != float(b.x) else float(a.y) < float(b.y))
	for point: Dictionary in candidates:
		if _scalar_in_all(primitives, point):
			return {"point": Vector2i(roundi(float(point.x)), roundi(float(point.y)))}
	return {}


static func intersected_cells(footprint: Dictionary, grid_origin: Vector2i, allowed_cells: Dictionary = {}) -> Array[Vector2i]:
	if not validate(footprint):
		return []
	var candidates := _candidate_cells(footprint, grid_origin)
	var result: Array[Vector2i] = []
	for cell: Vector2i in candidates:
		if (allowed_cells.is_empty() or allowed_cells.has(cell)) and _intersects_cell(footprint, cell, grid_origin):
			result.append(cell)
	result.sort_custom(Grid._cell_less)
	return result


# Whole-cell authoring selects only cells whose interiors share positive area
# with the analytic shape. Closed edge/vertex tangencies therefore do not grow
# a field. A radius-zero disk is the intentional exception: it selects exactly
# the grid's canonical owner so point-authored effects remain deterministic.
static func selected_cells(shape: Dictionary, grid_origin: Vector2i, allowed_cells: Dictionary = {}) -> Array[Vector2i]:
	if not validate(shape):
		return []
	if String(shape.kind) == KIND_DISK and int(shape.radius) == 0:
		var owner := Grid.world_to_cell(Vector2i(shape.center) - grid_origin)
		if allowed_cells.is_empty() or allowed_cells.has(owner):
			return [owner]
		return []
	var result: Array[Vector2i] = []
	for cell: Vector2i in _candidate_cells(shape, grid_origin):
		if not allowed_cells.is_empty() and not allowed_cells.has(cell):
			continue
		if _positive_area_in_cell(shape, cell, grid_origin):
			result.append(cell)
	result.sort_custom(Grid._cell_less)
	return result


# A whole-cell field owns a point only when it stores the point's canonical
# grid owner. This deliberately differs from the old closed-polygon union,
# where every cell touching a shared face could claim the same point.
static func contains_selected(stored_cells: Dictionary, grid_origin: Vector2i, point: Vector2i) -> bool:
	if stored_cells.is_empty() or not _world_point_valid(point):
		return false
	var owner := Grid.world_to_cell(point - grid_origin)
	return _selected_cell_active(stored_cells, owner)


# Canonical selected cells traversed by one segment, computed with exactly one
# grid sweep. Callers that need only exposure membership can reuse this set
# without repeating a full swept-cell query per stored field cell.
static func traversed_selected_cells(stored_cells: Dictionary, grid_origin: Vector2i, start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	if (
		stored_cells.is_empty()
		or not _world_point_valid(start)
		or not _world_point_valid(end)
	):
		return []
	if start == end:
		if not contains_selected(stored_cells, grid_origin, start):
			return []
		return [Grid.world_to_cell(start - grid_origin)]
	var touched: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in Grid.swept_cells(start - grid_origin, end - grid_origin, 0):
		touched[cell] = true
	var result: Array[Vector2i] = []
	for cell: Vector2i in stored_cells:
		if not _selected_cell_active(stored_cells, cell) or not touched.has(cell):
			continue
		var interval := _cell_segment_interval(cell, grid_origin, start, end)
		if not bool(interval.get("hit", false)):
			continue
		var midpoint := _segment_scalar_point(start, end, (float(interval.low) + float(interval.high)) * 0.5)
		if _scalar_canonical_owner(midpoint, grid_origin) == cell:
			result.append(cell)
	result.sort_custom(Grid._cell_less)
	return result


# Earliest traversal through the interior of an actually selected whole cell.
# A zero-duration face/vertex touch is eligible only for its canonical owner.
# For an open-boundary entry, low remains the continuous infimum while the
# quantized witness moves by at most one fixed unit into the selected owner.
static func selected_segment_interval(stored_cells: Dictionary, grid_origin: Vector2i, start: Vector2i, end: Vector2i) -> Dictionary:
	if (
		stored_cells.is_empty()
		or not _world_point_valid(start)
		or not _world_point_valid(end)
	):
		return _empty_interval()
	if start == end:
		if not contains_selected(stored_cells, grid_origin, start):
			return _empty_interval()
		var stationary_cell := Grid.world_to_cell(start - grid_origin)
		var stationary := {"hit": true, "low": 0.0, "high": 1.0, "cell": stationary_cell}
		var stationary_witness := _quantized_selected_witness({}, stored_cells, grid_origin, _scalar_point(float(start.x), float(start.y)), stationary_cell)
		for key: Variant in stationary_witness:
			stationary[key] = stationary_witness[key]
		return stationary
	var ordered := traversed_selected_cells(stored_cells, grid_origin, start, end)
	var best := _empty_interval()
	var best_cell := Vector2i.ZERO
	for cell: Vector2i in ordered:
		var interval := _cell_segment_interval(cell, grid_origin, start, end)
		if not bool(interval.get("hit", false)):
			continue
		var low := clampf(float(interval.low), 0.0, 1.0)
		var high := clampf(float(interval.high), 0.0, 1.0)
		if (
			not bool(best.get("hit", false))
			or low < float(best.low) - PARAMETER_EPSILON
			or (absf(low - float(best.low)) <= PARAMETER_EPSILON and Grid._cell_less(cell, best_cell))
		):
			best = {"hit": true, "low": low, "high": high, "cell": cell}
			best_cell = cell
	if not bool(best.get("hit", false)):
		return best
	var continuous := _segment_scalar_point(start, end, float(best.low))
	var witness := _quantized_selected_witness({}, stored_cells, grid_origin, continuous, best_cell)
	for key: Variant in witness:
		best[key] = witness[key]
	return best


# Deterministic continuous contact between an analytic shape (notably Spray)
# and the union of selected whole cells. The returned witness always names the
# canonical selected owner; no cell-center or nearest-cell truncation occurs.
static func contact_shape_selected(shape: Dictionary, stored_cells: Dictionary, grid_origin: Vector2i, preferred: Vector2i) -> Dictionary:
	if not validate(shape) or stored_cells.is_empty() or not _world_point_valid(preferred):
		return {}
	var primitives := _primitive_parts(shape)
	var candidates := _common_point_candidates(primitives)
	candidates.append(_scalar_point(float(preferred.x), float(preferred.y)))
	for primitive: Dictionary in primitives:
		candidates.append(_closest_point_in_primitive(primitive, preferred))
	var ordered := _active_selected_cells(stored_cells)
	for cell: Vector2i in ordered:
		var polygon := _world_cell_polygon(cell, grid_origin)
		var center := Grid.center(cell) + grid_origin
		candidates.append(_scalar_point(float(center.x), float(center.y)))
		candidates.append(_closest_point_in_polygon(preferred, polygon))
		for vertex: Vector2i in polygon:
			candidates.append(_scalar_point(float(vertex.x), float(vertex.y)))
		for edge_index: int in range(polygon.size()):
			var edge_start: Vector2i = polygon[edge_index]
			var edge_end: Vector2i = polygon[(edge_index + 1) % polygon.size()]
			var interval := _segment_interval(shape, edge_start, edge_end)
			if not bool(interval.get("hit", false)):
				continue
			candidates.append(_segment_scalar_point(edge_start, edge_end, float(interval.low)))
			candidates.append(_segment_scalar_point(edge_start, edge_end, float(interval.high)))
			candidates.append(_segment_scalar_point(edge_start, edge_end, (float(interval.low) + float(interval.high)) * 0.5))
	_sort_scalar_points_by_preference(candidates, preferred)
	for continuous: Dictionary in candidates:
		if not _scalar_in_all(primitives, continuous):
			continue
		var owner := _scalar_canonical_owner(continuous, grid_origin)
		if _selected_cell_active(stored_cells, owner):
			return _quantized_selected_witness(shape, stored_cells, grid_origin, continuous, owner)
		var fallback := _nearest_polygon_cell(continuous, stored_cells, grid_origin)
		if not fallback.is_empty() and _positive_area_in_cell(shape, Vector2i(fallback.cell), grid_origin):
			return _quantized_selected_witness(shape, stored_cells, grid_origin, continuous, Vector2i(fallback.cell))
	return {}


# Persistent whole-cell chemistry exists only in a cell stored by both fields.
# The preferred witness is retained when possible, otherwise it is projected
# continuously to the nearest common hex and quantized into its canonical owner.
static func shared_selected_contact(first_cells: Dictionary, second_cells: Dictionary, grid_origin: Vector2i, preferred: Vector2i) -> Dictionary:
	if first_cells.is_empty() or second_cells.is_empty() or not _world_point_valid(preferred):
		return {}
	var shared: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in first_cells:
		if _selected_cell_active(first_cells, cell) and _selected_cell_active(second_cells, cell):
			shared[cell] = 1
	if shared.is_empty():
		return {}
	if contains_selected(shared, grid_origin, preferred):
		return _quantized_selected_witness({}, shared, grid_origin, _scalar_point(float(preferred.x), float(preferred.y)), Grid.world_to_cell(preferred - grid_origin))
	var candidates: Array[Dictionary] = []
	for cell: Vector2i in _active_selected_cells(shared):
		var polygon := _world_cell_polygon(cell, grid_origin)
		candidates.append(_closest_point_in_polygon(preferred, polygon))
		var center := Grid.center(cell) + grid_origin
		candidates.append(_scalar_point(float(center.x), float(center.y)))
	_sort_scalar_points_by_preference(candidates, preferred)
	for continuous: Dictionary in candidates:
		var owner := _scalar_canonical_owner(continuous, grid_origin)
		if _selected_cell_active(shared, owner):
			return _quantized_selected_witness({}, shared, grid_origin, continuous, owner)
		# A closest point may lie on a face canonically owned by a non-shared
		# neighbor. Its selected side is open, so use the nearest fixed-unit
		# witness supplied by the quantizer rather than skipping the real overlap.
		var fallback := _nearest_polygon_cell(continuous, shared, grid_origin)
		if not fallback.is_empty():
			return _quantized_selected_witness({}, shared, grid_origin, continuous, Vector2i(fallback.cell))
	return {}


static func visual_polygon(footprint: Dictionary, cell: Vector2i, grid_origin: Vector2i) -> PackedVector2Array:
	# Presentation only. One hundred twenty-eight inscribed sides have < 0.16 px
	# radial deficit even at the 512 px sector limit (including the inward guard).
	# Geometry2D clipping is deliberately excluded from authority predicates.
	if not validate(footprint):
		return PackedVector2Array()
	var polygon := _primitive_visual_polygon(footprint)
	if polygon.size() < 3:
		return PackedVector2Array()
	var cell_polygon := PackedVector2Array()
	for point: Vector2i in Grid.vertices(cell):
		cell_polygon.append(Vector2(point + grid_origin))
	var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(polygon, cell_polygon)
	return clipped[0] if not clipped.is_empty() else PackedVector2Array()


static func _candidate_cells(footprint: Dictionary, grid_origin: Vector2i) -> Array[Vector2i]:
	match String(footprint.kind):
		KIND_DISK:
			var local: Vector2i = footprint.center - grid_origin
			return Grid.swept_cells(local, local, int(footprint.radius))
		KIND_SECTOR:
			var local: Vector2i = footprint.start - grid_origin
			return Grid.swept_cells(local, local, int(footprint.range))
		KIND_INTERSECTION:
			var parts: Array = footprint.parts
			var first := _candidate_cells(parts[0], grid_origin)
			var second_set: Dictionary[Vector2i, bool] = {}
			for cell: Vector2i in _candidate_cells(parts[1], grid_origin):
				second_set[cell] = true
			var shared: Array[Vector2i] = []
			for cell: Vector2i in first:
				if second_set.has(cell):
					shared.append(cell)
			return shared
	return []


static func _intersects_cell(footprint: Dictionary, cell: Vector2i, grid_origin: Vector2i) -> bool:
	var polygon: Array[Vector2i] = []
	for local: Vector2i in Grid.vertices(cell):
		polygon.append(local + grid_origin)
	for vertex: Vector2i in polygon:
		if contains(footprint, vertex):
			return true
	for index: int in range(polygon.size()):
		if segment_intersects(footprint, polygon[index], polygon[(index + 1) % polygon.size()]):
			return true
	for anchor: Vector2i in _anchor_points(footprint):
		if _point_in_polygon(anchor, polygon) and contains(footprint, anchor):
			return true
	for anchor: Dictionary in _continuous_anchor_points(footprint):
		if _float_point_in_polygon(anchor, polygon):
			return true
	return false


static func _positive_area_in_cell(shape: Dictionary, cell: Vector2i, grid_origin: Vector2i) -> bool:
	match String(shape.kind):
		KIND_DISK:
			return _disk_positive_area_in_cell(shape, cell, grid_origin)
		KIND_SECTOR:
			return _sector_positive_area_in_cell(shape, cell, grid_origin)
		KIND_INTERSECTION:
			return _composite_positive_area_in_cell(shape, cell, grid_origin)
	return false


static func _disk_positive_area_in_cell(shape: Dictionary, cell: Vector2i, grid_origin: Vector2i) -> bool:
	var radius := int(shape.radius)
	if radius <= 0:
		return false
	var local_center: Vector2i = Vector2i(shape.center) - grid_origin
	if Grid._point_in_cell(local_center, cell):
		return true
	var polygon := Grid.vertices(cell)
	for edge_index: int in range(polygon.size()):
		if _point_segment_strictly_within_radius(local_center, polygon[edge_index], polygon[(edge_index + 1) % polygon.size()], radius):
			return true
	return false


# Exact strict counterpart to HexGrid._point_segment_within_radius. Natural
# products keep disk/edge tangency exact across the fixed integer envelope.
static func _point_segment_strictly_within_radius(point: Vector2i, start: Vector2i, end: Vector2i, radius: int) -> bool:
	var delta := end - start
	var offset := point - start
	var length_squared := delta.x * delta.x + delta.y * delta.y
	var radius_squared := radius * radius
	if length_squared == 0:
		return offset.x * offset.x + offset.y * offset.y < radius_squared
	var projection := offset.x * delta.x + offset.y * delta.y
	if projection <= 0:
		return offset.x * offset.x + offset.y * offset.y < radius_squared
	if projection >= length_squared:
		var from_end := point - end
		return from_end.x * from_end.x + from_end.y * from_end.y < radius_squared
	var cross := absi(offset.x * delta.y - offset.y * delta.x)
	var cross_squared: Array[int] = Grid._nat_multiply(Grid._nat(cross), Grid._nat(cross))
	var limit: Array[int] = Grid._nat_multiply(Grid._nat(radius_squared), Grid._nat(length_squared))
	return Grid._nat_compare(cross_squared, limit) < 0


# Clip the authored hex by the sector's two cone half-planes, then compare the
# clipped polygon's continuous distance to the terminal disk strictly. This
# retains one-fixed-unit wedges while the explicit Float64 guards reject side
# and terminal-arc tangency after large world translations.
static func _sector_positive_area_in_cell(shape: Dictionary, cell: Vector2i, grid_origin: Vector2i) -> bool:
	var reach := int(shape.range)
	if reach <= 0:
		return false
	var origin: Vector2i = shape.start
	var aim: Vector2i = shape.aim
	var aim_length := sqrt(float(aim.x) * float(aim.x) + float(aim.y) * float(aim.y))
	var cosine := sqrt(float(shape.cosine_squared)) / aim_length
	var sine := sqrt(maxf(0.0, 1.0 - cosine * cosine))
	var unit_x := float(aim.x) / aim_length
	var unit_y := float(aim.y) / aim_length
	var side_x := -unit_y
	var side_y := unit_x
	var polygon: Array[Dictionary] = []
	for point: Vector2i in _world_cell_polygon(cell, grid_origin):
		polygon.append(_scalar_point(float(point.x), float(point.y)))
	polygon = _clip_scalar_polygon_positive(polygon, origin, sine * unit_x + cosine * side_x, sine * unit_y + cosine * side_y)
	polygon = _clip_scalar_polygon_positive(polygon, origin, sine * unit_x - cosine * side_x, sine * unit_y - cosine * side_y)
	if polygon.size() < 3 or _scalar_polygon_area_twice(polygon) <= AREA_EPSILON:
		return false
	var minimum_distance_squared := _scalar_polygon_distance_squared(origin, polygon)
	return minimum_distance_squared < float(reach) * float(reach) - DISTANCE_SQUARED_EPSILON


static func _clip_scalar_polygon_positive(polygon: Array[Dictionary], origin: Vector2i, normal_x: float, normal_y: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if polygon.is_empty():
		return result
	var previous: Dictionary = polygon[-1]
	var previous_value := (float(previous.x) - float(origin.x)) * normal_x + (float(previous.y) - float(origin.y)) * normal_y
	for current: Dictionary in polygon:
		var current_value := (float(current.x) - float(origin.x)) * normal_x + (float(current.y) - float(origin.y)) * normal_y
		var previous_inside := previous_value >= 0.0
		var current_inside := current_value >= 0.0
		if previous_inside != current_inside:
			var denominator := previous_value - current_value
			if denominator != 0.0:
				var amount := previous_value / denominator
				result.append(_scalar_point(
					float(previous.x) + (float(current.x) - float(previous.x)) * amount,
					float(previous.y) + (float(current.y) - float(previous.y)) * amount))
		if current_inside:
			result.append(current)
		previous = current
		previous_value = current_value
	return result


static func _scalar_polygon_area_twice(polygon: Array[Dictionary]) -> float:
	if polygon.size() < 3:
		return 0.0
	var anchor: Dictionary = polygon[0]
	var total := 0.0
	for index: int in range(1, polygon.size() - 1):
		var first: Dictionary = polygon[index]
		var second: Dictionary = polygon[index + 1]
		total += (
			(float(first.x) - float(anchor.x)) * (float(second.y) - float(anchor.y))
			- (float(first.y) - float(anchor.y)) * (float(second.x) - float(anchor.x))
		)
	return absf(total)


static func _scalar_polygon_distance_squared(point: Vector2i, polygon: Array[Dictionary]) -> float:
	var scalar := _scalar_point(float(point.x), float(point.y))
	if _scalar_point_in_scalar_polygon(scalar, polygon):
		return 0.0
	var best := INF
	for index: int in range(polygon.size()):
		var closest := _closest_scalar_on_segment(scalar, polygon[index], polygon[(index + 1) % polygon.size()])
		var dx := float(closest.x) - float(point.x)
		var dy := float(closest.y) - float(point.y)
		best = minf(best, dx * dx + dy * dy)
	return best


static func _scalar_point_in_scalar_polygon(point: Dictionary, polygon: Array[Dictionary]) -> bool:
	for index: int in range(polygon.size()):
		var a: Dictionary = polygon[index]
		var b: Dictionary = polygon[(index + 1) % polygon.size()]
		var cross := (float(b.x) - float(a.x)) * (float(point.y) - float(a.y)) - (float(b.y) - float(a.y)) * (float(point.x) - float(a.x))
		if cross < -PARAMETER_EPSILON:
			return false
	return true


static func _composite_positive_area_in_cell(shape: Dictionary, cell: Vector2i, grid_origin: Vector2i) -> bool:
	var primitives := _primitive_parts(shape)
	var polygon := _world_cell_polygon(cell, grid_origin)
	var candidates := _common_point_candidates(primitives)
	var center := Grid.center(cell) + grid_origin
	candidates.append(_scalar_point(float(center.x), float(center.y)))
	for vertex: Vector2i in polygon:
		candidates.append(_scalar_point(float(vertex.x), float(vertex.y)))
	for edge_index: int in range(polygon.size()):
		var edge_start: Vector2i = polygon[edge_index]
		var edge_end: Vector2i = polygon[(edge_index + 1) % polygon.size()]
		var interval := _segment_interval(shape, edge_start, edge_end)
		if bool(interval.get("hit", false)):
			candidates.append(_segment_scalar_point(edge_start, edge_end, float(interval.low)))
			candidates.append(_segment_scalar_point(edge_start, edge_end, float(interval.high)))
	var feasible: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if _scalar_in_all(primitives, candidate) and _float_point_in_polygon(candidate, polygon):
			feasible.append(candidate)
			if _scalar_strict_in_all(primitives, candidate):
				return true
	for first_index: int in range(feasible.size()):
		for second_index: int in range(first_index + 1, feasible.size()):
			var midpoint := _scalar_point(
				(float(feasible[first_index].x) + float(feasible[second_index].x)) * 0.5,
				(float(feasible[first_index].y) + float(feasible[second_index].y)) * 0.5)
			if _float_point_in_polygon(midpoint, polygon) and _scalar_strict_in_all(primitives, midpoint):
				return true
	return false


static func _scalar_strict_in_all(primitives: Array[Dictionary], point: Dictionary) -> bool:
	for primitive: Dictionary in primitives:
		if not _scalar_strict_in_primitive(primitive, point):
			return false
	return true


static func _scalar_strict_in_primitive(primitive: Dictionary, point: Dictionary) -> bool:
	if String(primitive.kind) == KIND_DISK:
		var center: Vector2i = primitive.center
		var dx := float(point.x) - float(center.x)
		var dy := float(point.y) - float(center.y)
		var radius := float(primitive.radius)
		return radius > 0.0 and dx * dx + dy * dy < radius * radius - DISTANCE_SQUARED_EPSILON
	var origin: Vector2i = primitive.start
	var offset_x := float(point.x) - float(origin.x)
	var offset_y := float(point.y) - float(origin.y)
	var distance_squared := offset_x * offset_x + offset_y * offset_y
	var reach := float(primitive.range)
	if reach <= 0.0 or distance_squared >= reach * reach - DISTANCE_SQUARED_EPSILON:
		return false
	var aim: Vector2i = primitive.aim
	var projection := offset_x * float(aim.x) + offset_y * float(aim.y)
	return projection > PARAMETER_EPSILON and projection * projection > distance_squared * float(primitive.cosine_squared) + DISTANCE_SQUARED_EPSILON


static func _sector_contains(footprint: Dictionary, point: Vector2i) -> bool:
	var offset: Vector2i = point - footprint.start
	var distance_squared := offset.x * offset.x + offset.y * offset.y
	var reach := int(footprint.range)
	if distance_squared > reach * reach:
		return false
	var aim: Vector2i = footprint.aim
	var projection := offset.x * aim.x + offset.y * aim.y
	return projection >= 0 and projection * projection >= distance_squared * int(footprint.cosine_squared)


static func _segment_interval(footprint: Dictionary, start: Vector2i, end: Vector2i) -> Dictionary:
	match String(footprint.kind):
		KIND_DISK:
			return _disk_interval(footprint.center, int(footprint.radius), start, end)
		KIND_SECTOR:
			return _sector_interval(footprint, start, end)
		KIND_INTERSECTION:
			var parts: Array = footprint.parts
			var first := _segment_interval(parts[0], start, end)
			if not bool(first.get("hit", false)):
				return _empty_interval()
			var second := _segment_interval(parts[1], start, end)
			if not bool(second.get("hit", false)):
				return _empty_interval()
			var low := maxf(float(first.low), float(second.low))
			var high := minf(float(first.high), float(second.high))
			return {"hit": low <= high + PARAMETER_EPSILON, "low": low, "high": high}
	return _empty_interval()


static func _cell_segment_interval(cell: Vector2i, grid_origin: Vector2i, start: Vector2i, end: Vector2i) -> Dictionary:
	var local_start := start - grid_origin
	var local_end := end - grid_origin
	# The integer polygon predicate proves closed contact before Float64 retains
	# its entry parameter. This includes face, vertex and tangency contact.
	if not Grid._capsule_intersects_cell(local_start, local_end, 0, cell):
		return _empty_interval()
	var polygon: Array[Vector2i] = []
	for local: Vector2i in Grid.vertices(cell):
		polygon.append(local + grid_origin)
	var interval := {"hit": true, "low": 0.0, "high": 1.0}
	for index: int in range(polygon.size()):
		var edge_start: Vector2i = polygon[index]
		var edge_end: Vector2i = polygon[(index + 1) % polygon.size()]
		var start_value := Grid._orientation(edge_start, edge_end, start)
		var end_value := Grid._orientation(edge_start, edge_end, end)
		interval = _clip_positive(interval, float(start_value), float(end_value - start_value))
		if not bool(interval.hit):
			return interval
	return interval


static func _disk_interval(center: Vector2i, radius: int, start: Vector2i, end: Vector2i) -> Dictionary:
	# The integer helper decides contact, including exact tangency. Float64 is
	# used only to retain the continuous parameter interval for intersections;
	# a negative rounded discriminant is clamped after integer contact is proved.
	# HexGrid owns the proved 8M-coordinate/512k-radius natural-number compare.
	# Reuse it so footprint disks retain exact tangency across their full envelope.
	if not Grid._point_segment_within_radius(center, start, end, radius):
		return _empty_interval()
	var delta_x := float(end.x - start.x)
	var delta_y := float(end.y - start.y)
	var offset_x := float(start.x - center.x)
	var offset_y := float(start.y - center.y)
	var a := delta_x * delta_x + delta_y * delta_y
	if a == 0.0:
		return {"hit": true, "low": 0.0, "high": 1.0}
	var b := 2.0 * (offset_x * delta_x + offset_y * delta_y)
	var c := offset_x * offset_x + offset_y * offset_y - float(radius) * float(radius)
	var discriminant := maxf(0.0, b * b - 4.0 * a * c)
	var root := sqrt(discriminant)
	var low := maxf(0.0, (-b - root) / (2.0 * a))
	var high := minf(1.0, (-b + root) / (2.0 * a))
	return {"hit": low <= high + PARAMETER_EPSILON, "low": low, "high": high}


static func _sector_interval(footprint: Dictionary, start: Vector2i, end: Vector2i) -> Dictionary:
	var radial := _disk_interval(footprint.start, int(footprint.range), start, end)
	if not bool(radial.get("hit", false)):
		return radial
	var aim_value: Vector2i = footprint.aim
	var aim_x := float(aim_value.x)
	var aim_y := float(aim_value.y)
	var aim_length := sqrt(aim_x * aim_x + aim_y * aim_y)
	var cosine := sqrt(float(footprint.cosine_squared)) / aim_length
	var sine := sqrt(maxf(0.0, 1.0 - cosine * cosine))
	var unit_x := aim_x / aim_length
	var unit_y := aim_y / aim_length
	var side_x := -unit_y
	var side_y := unit_x
	var sector_start: Vector2i = footprint.start
	var offset_x := float(start.x - sector_start.x)
	var offset_y := float(start.y - sector_start.y)
	var delta_x := float(end.x - start.x)
	var delta_y := float(end.y - start.y)
	var forward_start := offset_x * unit_x + offset_y * unit_y
	var forward_delta := delta_x * unit_x + delta_y * unit_y
	var side_start := offset_x * side_x + offset_y * side_y
	var side_delta := delta_x * side_x + delta_y * side_y
	var interval := radial
	interval = _clip_positive(interval, sine * forward_start + cosine * side_start, sine * forward_delta + cosine * side_delta)
	if not bool(interval.hit):
		return interval
	return _clip_positive(interval, sine * forward_start - cosine * side_start, sine * forward_delta - cosine * side_delta)


static func _clip_positive(interval: Dictionary, start_value: float, delta_value: float) -> Dictionary:
	if absf(delta_value) <= PARAMETER_EPSILON:
		return interval if start_value >= -PARAMETER_EPSILON else _empty_interval()
	var crossing := -start_value / delta_value
	var low := float(interval.low)
	var high := float(interval.high)
	if delta_value > 0.0:
		low = maxf(low, crossing)
	else:
		high = minf(high, crossing)
	return {"hit": low <= high + PARAMETER_EPSILON, "low": low, "high": high}


static func _disk_sector_intersects(disk_footprint: Dictionary, sector_footprint: Dictionary) -> bool:
	# This is SprayContactGeometry.sector_circle_contact's exact predicate with
	# HexFootprint's smaller coordinate/range envelope and its 256 px disk bound.
	# Reusing the natural-number root comparator avoids the contact helper's
	# intentionally narrower 100 px moving-projectile-circle validation policy.
	var center: Vector2i = sector_footprint.start
	var aim: Vector2i = sector_footprint.aim
	var maximum_range := int(sector_footprint.range)
	var threshold := int(sector_footprint.cosine_squared)
	var circle_center: Vector2i = disk_footprint.center
	var circle_radius := int(disk_footprint.radius)
	var offset := circle_center - center
	var distance_squared := offset.x * offset.x + offset.y * offset.y
	var reach := maximum_range + circle_radius
	if distance_squared > reach * reach:
		return false
	if distance_squared <= circle_radius * circle_radius:
		return true
	if maximum_range == 0:
		return false
	var projection := offset.x * aim.x + offset.y * aim.y
	if projection >= 0 and projection * projection >= distance_squared * threshold:
		return true
	var aim_squared := aim.x * aim.x + aim.y * aim.y
	var side_squared := aim_squared - threshold
	var cross := absi(aim.x * offset.y - aim.y * offset.x)
	return not ContactGeometry._boundary_segment_contact(
		projection,
		cross,
		distance_squared,
		aim_squared,
		threshold,
		side_squared,
		maximum_range,
		circle_radius,
	).is_empty()


static func _sector_sector_intersects(first: Dictionary, second: Dictionary) -> bool:
	# Two convex sectors can first meet only at a boundary endpoint, side/side,
	# side/arc or arc/arc contact. All analytic roots stay scalar Float64; exact
	# integer membership remains the fast path for the two explicit origins.
	for point: Dictionary in _sector_sector_candidate_points(first, second):
		if _scalar_in_sector(first, point) and _scalar_in_sector(second, point):
			return true
	return false


static func _sector_sector_candidate_points(first: Dictionary, second: Dictionary) -> Array[Dictionary]:
	var first_sides := _sector_side_segments(first)
	var second_sides := _sector_side_segments(second)
	var candidates: Array[Dictionary] = [
		_scalar_point(float(first.start.x), float(first.start.y)),
		_scalar_point(float(second.start.x), float(second.start.y)),
	]
	for side: Array in first_sides:
		candidates.append(side[1])
		candidates.append_array(_segment_circle_points(side[0], side[1], second.start, int(second.range)))
	for side: Array in second_sides:
		candidates.append(side[1])
		candidates.append_array(_segment_circle_points(side[0], side[1], first.start, int(first.range)))
	for first_side: Array in first_sides:
		for second_side: Array in second_sides:
			var crossing := _segment_segment_point(first_side[0], first_side[1], second_side[0], second_side[1])
			if not crossing.is_empty():
				candidates.append(crossing)
	candidates.append_array(_circle_circle_points(first.start, int(first.range), second.start, int(second.range)))
	return candidates


static func _sector_side_segments(footprint: Dictionary) -> Array[Array]:
	var origin: Vector2i = footprint.start
	var aim: Vector2i = footprint.aim
	var axis := atan2(float(aim.y), float(aim.x))
	var aim_length := sqrt(float(aim.x) * float(aim.x) + float(aim.y) * float(aim.y))
	var half_angle := acos(sqrt(float(footprint.cosine_squared)) / aim_length)
	var start_point := _scalar_point(float(origin.x), float(origin.y))
	var result: Array[Array] = []
	for angle: float in [axis - half_angle, axis + half_angle]:
		result.append([
			start_point,
			_scalar_point(
				float(origin.x) + cos(angle) * float(footprint.range),
				float(origin.y) + sin(angle) * float(footprint.range),
			),
		])
	return result


static func _segment_segment_point(a: Dictionary, b: Dictionary, c: Dictionary, d: Dictionary) -> Dictionary:
	var rx := float(b.x) - float(a.x)
	var ry := float(b.y) - float(a.y)
	var sx := float(d.x) - float(c.x)
	var sy := float(d.y) - float(c.y)
	var denominator := rx * sy - ry * sx
	if absf(denominator) <= PARAMETER_EPSILON:
		return {}
	var qx := float(c.x) - float(a.x)
	var qy := float(c.y) - float(a.y)
	var t := (qx * sy - qy * sx) / denominator
	var u := (qx * ry - qy * rx) / denominator
	if t < -PARAMETER_EPSILON or t > 1.0 + PARAMETER_EPSILON or u < -PARAMETER_EPSILON or u > 1.0 + PARAMETER_EPSILON:
		return {}
	return _scalar_point(float(a.x) + rx * t, float(a.y) + ry * t)


static func _segment_circle_points(a: Dictionary, b: Dictionary, center: Vector2i, radius: int) -> Array[Dictionary]:
	var dx := float(b.x) - float(a.x)
	var dy := float(b.y) - float(a.y)
	var ox := float(a.x) - float(center.x)
	var oy := float(a.y) - float(center.y)
	var quadratic := dx * dx + dy * dy
	if quadratic == 0.0:
		return []
	var linear := 2.0 * (ox * dx + oy * dy)
	var constant := ox * ox + oy * oy - float(radius) * float(radius)
	var discriminant := linear * linear - 4.0 * quadratic * constant
	if discriminant < -PARAMETER_EPSILON:
		return []
	var root := sqrt(maxf(0.0, discriminant))
	var result: Array[Dictionary] = []
	for parameter: float in [(-linear - root) / (2.0 * quadratic), (-linear + root) / (2.0 * quadratic)]:
		if parameter >= -PARAMETER_EPSILON and parameter <= 1.0 + PARAMETER_EPSILON:
			result.append(_scalar_point(float(a.x) + dx * parameter, float(a.y) + dy * parameter))
	return result


static func _circle_circle_points(first_center: Vector2i, first_radius: int, second_center: Vector2i, second_radius: int) -> Array[Dictionary]:
	var dx := float(second_center.x - first_center.x)
	var dy := float(second_center.y - first_center.y)
	var distance_squared := dx * dx + dy * dy
	if distance_squared == 0.0:
		return []
	var distance := sqrt(distance_squared)
	if distance > float(first_radius + second_radius) + PARAMETER_EPSILON or distance < float(absi(first_radius - second_radius)) - PARAMETER_EPSILON:
		return []
	var along := (float(first_radius) * float(first_radius) - float(second_radius) * float(second_radius) + distance_squared) / (2.0 * distance)
	var height := sqrt(maxf(0.0, float(first_radius) * float(first_radius) - along * along))
	var base_x := float(first_center.x) + dx * along / distance
	var base_y := float(first_center.y) + dy * along / distance
	var side_x := -dy * height / distance
	var side_y := dx * height / distance
	return [_scalar_point(base_x + side_x, base_y + side_y), _scalar_point(base_x - side_x, base_y - side_y)]


static func _scalar_in_sector(footprint: Dictionary, point: Dictionary) -> bool:
	var origin: Vector2i = footprint.start
	var offset_x := float(point.x) - float(origin.x)
	var offset_y := float(point.y) - float(origin.y)
	var distance_squared := offset_x * offset_x + offset_y * offset_y
	var reach := float(footprint.range)
	if distance_squared > reach * reach + PARAMETER_EPSILON:
		return false
	var aim: Vector2i = footprint.aim
	var projection := offset_x * float(aim.x) + offset_y * float(aim.y)
	return projection >= -PARAMETER_EPSILON and projection * projection + PARAMETER_EPSILON >= distance_squared * float(footprint.cosine_squared)


static func _scalar_point(x: float, y: float) -> Dictionary:
	return {"x": x, "y": y}


static func _anchor_points(footprint: Dictionary) -> Array[Vector2i]:
	match String(footprint.kind):
		KIND_DISK:
			return [Vector2i(footprint.center)]
		KIND_SECTOR:
			return [Vector2i(footprint.start), _sector_axis_endpoint(footprint)]
		KIND_INTERSECTION:
			var result: Array[Vector2i] = []
			for part: Dictionary in footprint.parts:
				result.append_array(_anchor_points(part))
			return result
	return []


static func _continuous_anchor_points(footprint: Dictionary) -> Array[Dictionary]:
	if String(footprint.kind) != KIND_INTERSECTION:
		return []
	var primitives := _primitive_parts(footprint)
	var candidates := _common_point_candidates(primitives)
	var result: Array[Dictionary] = []
	for point: Dictionary in candidates:
		if _scalar_in_all(primitives, point):
			result.append(point)
	return result


static func _primitive_parts(footprint: Dictionary) -> Array[Dictionary]:
	if String(footprint.kind) != KIND_INTERSECTION:
		return [footprint]
	var result: Array[Dictionary] = []
	for part: Dictionary in footprint.parts:
		result.append_array(_primitive_parts(part))
	return result


static func _primitives_have_common_point(primitives: Array[Dictionary]) -> bool:
	for point: Dictionary in _common_point_candidates(primitives):
		if _scalar_in_all(primitives, point):
			return true
	return false


static func _common_point_candidates(primitives: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for primitive: Dictionary in primitives:
		result.append_array(_scalar_primitive_anchors(primitive))
	for first_index: int in range(primitives.size()):
		for second_index: int in range(first_index + 1, primitives.size()):
			result.append_array(_primitive_pair_contacts(primitives[first_index], primitives[second_index]))
	return result


static func _scalar_primitive_anchors(primitive: Dictionary) -> Array[Dictionary]:
	if String(primitive.kind) == KIND_DISK:
		return [_scalar_point(float(primitive.center.x), float(primitive.center.y))]
	var sides := _sector_side_segments(primitive)
	return [
		_scalar_point(float(primitive.start.x), float(primitive.start.y)),
		sides[0][1],
		sides[1][1],
	]


static func _primitive_pair_contacts(first: Dictionary, second: Dictionary) -> Array[Dictionary]:
	if String(first.kind) == KIND_DISK and String(second.kind) == KIND_DISK:
		var result := _circle_circle_points(first.center, int(first.radius), second.center, int(second.radius))
		var total_radius := int(first.radius) + int(second.radius)
		if total_radius > 0:
			result.append(_scalar_point(
				(float(first.center.x) * float(second.radius) + float(second.center.x) * float(first.radius)) / float(total_radius),
				(float(first.center.y) * float(second.radius) + float(second.center.y) * float(first.radius)) / float(total_radius),
			))
		return result
	if String(first.kind) == KIND_SECTOR and String(second.kind) == KIND_SECTOR:
		return _sector_sector_candidate_points(first, second)
	var disk_part: Dictionary = first if String(first.kind) == KIND_DISK else second
	var sector_part: Dictionary = second if String(first.kind) == KIND_DISK else first
	var contacts: Array[Dictionary] = [_closest_point_in_sector(sector_part, float(disk_part.center.x), float(disk_part.center.y))]
	var sides := _sector_side_segments(sector_part)
	for side: Array in sides:
		contacts.append(side[1])
		contacts.append_array(_segment_circle_points(side[0], side[1], disk_part.center, int(disk_part.radius)))
	contacts.append_array(_circle_circle_points(sector_part.start, int(sector_part.range), disk_part.center, int(disk_part.radius)))
	return contacts


static func _scalar_in_all(primitives: Array[Dictionary], point: Dictionary) -> bool:
	for primitive: Dictionary in primitives:
		if not _scalar_in_primitive(primitive, point):
			return false
	return true


static func _scalar_in_primitive(primitive: Dictionary, point: Dictionary) -> bool:
	if String(primitive.kind) == KIND_SECTOR:
		return _scalar_in_sector(primitive, point)
	var center: Vector2i = primitive.center
	var dx := float(point.x) - float(center.x)
	var dy := float(point.y) - float(center.y)
	var radius := float(primitive.radius)
	return dx * dx + dy * dy <= radius * radius + maxf(1.0, radius * radius) * PARAMETER_EPSILON


static func _closest_point_in_sector(sector_footprint: Dictionary, point_x: float, point_y: float) -> Dictionary:
	var origin: Vector2i = sector_footprint.start
	var relative_x := point_x - float(origin.x)
	var relative_y := point_y - float(origin.y)
	if relative_x == 0.0 and relative_y == 0.0:
		return _scalar_point(float(origin.x), float(origin.y))
	var aim: Vector2i = sector_footprint.aim
	var axis_angle := atan2(float(aim.y), float(aim.x))
	var aim_length := sqrt(float(aim.x) * float(aim.x) + float(aim.y) * float(aim.y))
	var half_angle := acos(sqrt(float(sector_footprint.cosine_squared)) / aim_length)
	var relative_angle := wrapf(atan2(relative_y, relative_x) - axis_angle, -PI, PI)
	var clamped_angle := clampf(relative_angle, -half_angle, half_angle) + axis_angle
	var direction_x := cos(clamped_angle)
	var direction_y := sin(clamped_angle)
	var distance := clampf(relative_x * direction_x + relative_y * direction_y, 0.0, float(sector_footprint.range))
	return _scalar_point(float(origin.x) + direction_x * distance, float(origin.y) + direction_y * distance)


static func _sector_axis_endpoint(footprint: Dictionary) -> Vector2i:
	var aim: Vector2i = footprint.aim
	var length := sqrt(float(aim.x * aim.x + aim.y * aim.y))
	return Vector2i(footprint.start) + Vector2i(roundi(float(aim.x) * int(footprint.range) / length), roundi(float(aim.y) * int(footprint.range) / length))


static func _primitive_visual_polygon(footprint: Dictionary) -> PackedVector2Array:
	match String(footprint.kind):
		KIND_DISK:
			return _disk_visual_polygon(footprint.center, int(footprint.radius))
		KIND_SECTOR:
			return _sector_visual_polygon(footprint)
		KIND_INTERSECTION:
			var parts: Array = footprint.parts
			var first := _primitive_visual_polygon(parts[0])
			var second := _primitive_visual_polygon(parts[1])
			var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(first, second)
			return clipped[0] if not clipped.is_empty() else PackedVector2Array()
	return PackedVector2Array()


static func _disk_visual_polygon(center: Vector2i, radius: int) -> PackedVector2Array:
	if radius <= 0:
		return PackedVector2Array()
	var result := PackedVector2Array()
	var visual_radius := float(radius) - minf(float(VISUAL_INSET), float(radius) * 0.01)
	for index: int in range(VISUAL_SEGMENTS):
		var angle := TAU * float(index) / float(VISUAL_SEGMENTS)
		result.append(Vector2(center) + Vector2(cos(angle), sin(angle)) * visual_radius)
	return result


static func _sector_visual_polygon(footprint: Dictionary) -> PackedVector2Array:
	var reach := int(footprint.range)
	if reach <= 0:
		return PackedVector2Array()
	var aim := Vector2(footprint.aim)
	var half_angle := acos(sqrt(float(footprint.cosine_squared)) / aim.length())
	var axis_angle := aim.angle()
	var arc_segments := maxi(2, ceili(float(VISUAL_SEGMENTS) * half_angle / PI))
	var result := PackedVector2Array([Vector2(footprint.start)])
	for index: int in range(arc_segments + 1):
		var angle := axis_angle - half_angle + 2.0 * half_angle * float(index) / float(arc_segments)
		var visual_reach := float(reach) - minf(float(VISUAL_INSET), float(reach) * 0.01)
		result.append(Vector2(footprint.start) + Vector2(cos(angle), sin(angle)) * visual_reach)
	return result


static func _selected_cell_active(stored_cells: Dictionary, cell: Vector2i) -> bool:
	return stored_cells.has(cell) and int(stored_cells[cell]) > 0


static func _active_selected_cells(stored_cells: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in stored_cells:
		if _selected_cell_active(stored_cells, cell):
			result.append(cell)
	result.sort_custom(Grid._cell_less)
	return result


static func _world_cell_polygon(cell: Vector2i, grid_origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for local: Vector2i in Grid.vertices(cell):
		result.append(local + grid_origin)
	return result


static func _segment_scalar_point(start: Vector2i, end: Vector2i, amount: float) -> Dictionary:
	return _scalar_point(
		float(start.x) + float(end.x - start.x) * amount,
		float(start.y) + float(end.y - start.y) * amount)


static func _scalar_canonical_owner(point: Dictionary, grid_origin: Vector2i) -> Vector2i:
	var local_rounded := Vector2i(
		roundi(float(point.x) - float(grid_origin.x)),
		roundi(float(point.y) - float(grid_origin.y)))
	var seed := Grid.world_to_cell(local_rounded)
	var owners: Array[Vector2i] = []
	for candidate: Vector2i in Grid.disk(seed, 2):
		if _float_point_in_polygon(point, _world_cell_polygon(candidate, grid_origin)):
			owners.append(candidate)
	owners.sort_custom(Grid._cell_less)
	return owners[0] if not owners.is_empty() else seed


static func _closest_point_in_primitive(primitive: Dictionary, preferred: Vector2i) -> Dictionary:
	if String(primitive.kind) == KIND_SECTOR:
		return _closest_point_in_sector(primitive, float(preferred.x), float(preferred.y))
	var center: Vector2i = primitive.center
	var dx := float(preferred.x - center.x)
	var dy := float(preferred.y - center.y)
	var distance := sqrt(dx * dx + dy * dy)
	var ratio := minf(1.0, float(primitive.radius) / distance) if distance > 0.0 else 0.0
	return _scalar_point(float(center.x) + dx * ratio, float(center.y) + dy * ratio)


static func _closest_point_in_polygon(preferred: Vector2i, polygon: Array[Vector2i]) -> Dictionary:
	var point := _scalar_point(float(preferred.x), float(preferred.y))
	if _float_point_in_polygon(point, polygon):
		return point
	var best := {}
	var best_distance_squared := INF
	for index: int in range(polygon.size()):
		var edge_start := _scalar_point(float(polygon[index].x), float(polygon[index].y))
		var edge_end := _scalar_point(float(polygon[(index + 1) % polygon.size()].x), float(polygon[(index + 1) % polygon.size()].y))
		var candidate := _closest_scalar_on_segment(point, edge_start, edge_end)
		var dx := float(candidate.x) - float(preferred.x)
		var dy := float(candidate.y) - float(preferred.y)
		var distance_squared := dx * dx + dy * dy
		if distance_squared < best_distance_squared:
			best = candidate
			best_distance_squared = distance_squared
	return best


static func _closest_scalar_on_segment(point: Dictionary, start: Dictionary, end: Dictionary) -> Dictionary:
	var delta_x := float(end.x) - float(start.x)
	var delta_y := float(end.y) - float(start.y)
	var length_squared := delta_x * delta_x + delta_y * delta_y
	if length_squared == 0.0:
		return start
	var amount := clampf(
		((float(point.x) - float(start.x)) * delta_x + (float(point.y) - float(start.y)) * delta_y) / length_squared,
		0.0, 1.0)
	return _scalar_point(float(start.x) + delta_x * amount, float(start.y) + delta_y * amount)


static func _sort_scalar_points_by_preference(points: Array[Dictionary], preferred: Vector2i) -> void:
	points.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ax := float(a.x) - float(preferred.x)
		var ay := float(a.y) - float(preferred.y)
		var bx := float(b.x) - float(preferred.x)
		var by := float(b.y) - float(preferred.y)
		var first_distance := ax * ax + ay * ay
		var second_distance := bx * bx + by * by
		if first_distance != second_distance:
			return first_distance < second_distance
		return float(a.x) < float(b.x) if float(a.x) != float(b.x) else float(a.y) < float(b.y))


static func _nearest_polygon_cell(point: Dictionary, stored_cells: Dictionary, grid_origin: Vector2i) -> Dictionary:
	var owners: Array[Vector2i] = []
	for cell: Vector2i in stored_cells:
		if _selected_cell_active(stored_cells, cell) and _float_point_in_polygon(point, _world_cell_polygon(cell, grid_origin)):
			owners.append(cell)
	owners.sort_custom(Grid._cell_less)
	return {"cell": owners[0]} if not owners.is_empty() else {}


static func _quantized_selected_witness(shape: Dictionary, stored_cells: Dictionary, grid_origin: Vector2i, continuous: Dictionary, fallback_cell: Vector2i) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var seen: Dictionary[Vector2i, bool] = {}
	var minimum_x := floori(float(continuous.x)) - 1
	var maximum_x := ceili(float(continuous.x)) + 1
	var minimum_y := floori(float(continuous.y)) - 1
	var maximum_y := ceili(float(continuous.y)) + 1
	for x: int in range(minimum_x, maximum_x + 1):
		for y: int in range(minimum_y, maximum_y + 1):
			var lattice := Vector2i(x, y)
			if seen.has(lattice):
				continue
			seen[lattice] = true
			var dx := float(x) - float(continuous.x)
			var dy := float(y) - float(continuous.y)
			var error_squared := dx * dx + dy * dy
			if error_squared <= 1.0 + PARAMETER_EPSILON:
				candidates.append({"point": lattice, "error_squared": error_squared})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.error_squared) != float(b.error_squared):
			return float(a.error_squared) < float(b.error_squared)
		var first: Vector2i = a.point
		var second: Vector2i = b.point
		return first.x < second.x if first.x != second.x else first.y < second.y)
	for candidate: Dictionary in candidates:
		var lattice: Vector2i = candidate.point
		if not shape.is_empty() and not contains(shape, lattice):
			continue
		if not contains_selected(stored_cells, grid_origin, lattice):
			continue
		return {
			"point": lattice,
			"cell": Grid.world_to_cell(lattice - grid_origin),
			"continuous_x": float(continuous.x),
			"continuous_y": float(continuous.y),
			"quantization_error_squared": float(candidate.error_squared),
			"quantization_outside": false,
		}
	var rounded := Vector2i(roundi(float(continuous.x)), roundi(float(continuous.y)))
	var rounded_dx := float(rounded.x) - float(continuous.x)
	var rounded_dy := float(rounded.y) - float(continuous.y)
	return {
		"point": rounded,
		"cell": fallback_cell,
		"continuous_x": float(continuous.x),
		"continuous_y": float(continuous.y),
		"quantization_error_squared": rounded_dx * rounded_dx + rounded_dy * rounded_dy,
		"quantization_outside": true,
	}


static func _point_in_polygon(point: Vector2i, polygon: Array[Vector2i]) -> bool:
	for index: int in range(polygon.size()):
		if _orientation(polygon[index], polygon[(index + 1) % polygon.size()], point) < 0:
			return false
	return true


static func _float_point_in_polygon(point: Dictionary, polygon: Array[Vector2i]) -> bool:
	for index: int in range(polygon.size()):
		var a: Vector2i = polygon[index]
		var b: Vector2i = polygon[(index + 1) % polygon.size()]
		var cross := float(b.x - a.x) * (float(point.y) - float(a.y)) - float(b.y - a.y) * (float(point.x) - float(a.x))
		if cross < -PARAMETER_EPSILON:
			return false
	return true


static func _orientation(a: Vector2i, b: Vector2i, c: Vector2i) -> int:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


static func _world_point_valid(point: Vector2i) -> bool:
	return absi(point.x) <= Grid.MAX_ABS_QUERY_COORDINATE and absi(point.y) <= Grid.MAX_ABS_QUERY_COORDINATE


static func _empty_interval() -> Dictionary:
	return {"hit": false, "low": 1.0, "high": 0.0}

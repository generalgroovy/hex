extends "res://src/sim/hex/hex_footprint.gd"

# Frozen checkpoint control flow for exact optimization comparisons.

static func contact_shape_selected(shape: Dictionary, stored_cells: Dictionary, grid_origin: Vector2i, preferred: Vector2i) -> Dictionary:
	if not validate(shape) or stored_cells.is_empty() or not _world_point_valid(preferred):
		return {}
	var primitives := _primitive_parts(shape)
	var preferred_point := _scalar_point(float(preferred.x), float(preferred.y))
	# Zero distance is the first possible witness in the existing ordering.
	# Do not enumerate/sort every field edge when the origin already contacts it.
	if _scalar_in_all(primitives, preferred_point):
		var preferred_owner := _scalar_canonical_owner(preferred_point, grid_origin)
		if _selected_cell_active(stored_cells, preferred_owner):
			return _quantized_selected_witness(shape, stored_cells, grid_origin, preferred_point, preferred_owner)
	var candidates := _common_point_candidates(primitives)
	candidates.append(_scalar_point(float(preferred.x), float(preferred.y)))
	for primitive: Dictionary in primitives:
		candidates.append(_closest_point_in_primitive(primitive, preferred))
	var ordered := _active_selected_cells(stored_cells)
	for cell: Vector2i in ordered:
		if not _cell_may_touch_primitives(primitives, cell, grid_origin): continue
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


# Conservative broad phase only: retain a one-fixed-unit guard around analytic
# boundaries (larger than Float64 predicate tolerances). Rejected polygons can
# contribute no accepted candidate. Exact witnesses and tie order stay below.

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

extends FluxTestSuite


func run() -> int:
	_test_authored_geometry_and_closed_ownership()
	_test_topology_and_canonical_order()
	_test_sweep_edges_vertices_and_radius()
	_test_negative_high_speed_and_reversal()
	_test_local_query_matches_exhaustive_oracle()
	_test_random_cross_edge_oracle()
	_test_invalid_bounds_fail_closed()
	return finish("hex-grid")


func _test_authored_geometry_and_closed_ownership() -> void:
	equal(HexGrid.COLUMN_PITCH, 48_000, "48px cells are 25 percent narrower than the previous 64px grid")
	equal(HexGrid.ROW_PITCH * 2, HexGrid.HALF_HEIGHT * 3, "even fixed-point height leaves no shared-face cracks")
	equal(MovementTuning.PLAYER_RADIUS, 18_000, "finer chemistry cells do not shrink common actor wall clearance")
	equal(HexGrid.center(Vector2i(2, -3)), Vector2i(24_000, -124_704), "axial center uses the fixed pointy-top lattice")
	equal(HexGrid.vertices(Vector2i.ZERO), [
		Vector2i(0, -27_712), Vector2i(24_000, -13_856),
		Vector2i(24_000, 13_856), Vector2i(0, 27_712),
		Vector2i(-24_000, 13_856), Vector2i(-24_000, -13_856),
	], "origin vertices retain the authored clockwise geometry")
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(3, -2), Vector2i(-4, 5), Vector2i(-7, -6)]:
		equal(HexGrid.world_to_cell(HexGrid.center(cell)), cell, "cell center round-trips across signed axial coordinates")
	equal(HexGrid.world_to_cell(Vector2i(24_000, 0)), Vector2i.ZERO, "closed shared face belongs to lexicographically smaller cell")
	equal(HexGrid.world_to_cell(Vector2i(24_000, 13_856)), Vector2i.ZERO, "three-cell lower-right vertex chooses the lexicographic owner")
	equal(HexGrid.world_to_cell(Vector2i(0, -27_712)), Vector2i(0, -1), "negative shared vertex chooses the lexicographic owner")


func _test_topology_and_canonical_order() -> void:
	var origin := Vector2i.ZERO
	equal(HexGrid.neighbors(origin), [
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -1),
		Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0),
	], "six neighbors are complete and lexicographically ordered")
	equal(HexGrid.distance(Vector2i(-3, 5), Vector2i(4, -2)), 7, "distance uses exact cube-coordinate maximum")
	for radius: int in range(5):
		var cells := HexGrid.disk(Vector2i(4, -3), radius)
		equal(cells.size(), 1 + 3 * radius * (radius + 1), "disk has the exact axial cell count")
		check(_canonically_sorted(cells), "disk output is canonical")
		for cell: Vector2i in cells:
			check(HexGrid.distance(Vector2i(4, -3), cell) <= radius, "disk contains no cell beyond its radius")
		var edge := HexGrid.ring(Vector2i(4, -3), radius)
		equal(edge.size(), 1 if radius == 0 else 6 * radius, "ring has the exact perimeter count")
		check(_canonically_sorted(edge), "ring output is canonical")
	equal(HexGrid.disk(origin, -1), [], "negative disk radius fails closed")
	equal(HexGrid.ring(origin, -1), [], "negative ring radius fails closed")


func _test_sweep_edges_vertices_and_radius() -> void:
	equal(HexGrid.swept_cells(Vector2i(-23_999, 0), Vector2i(23_999, 0), 0), [Vector2i.ZERO], "one-unit-inside endpoints prove one strict convex-hex segment")
	equal(HexGrid.swept_cells(Vector2i(0, -27_711), Vector2i(0, -27_711), 0), [Vector2i.ZERO], "one-unit-inside corner remains strict interior")
	var face_touch := HexGrid.swept_cells(Vector2i(24_000, -10_000), Vector2i(24_000, 10_000), 0)
	check(face_touch.has(Vector2i.ZERO) and face_touch.has(Vector2i(1, 0)), "zero-radius shared-face sweep includes both closed cells")
	var vertex_touch := HexGrid.swept_cells(Vector2i(24_000, 13_856), Vector2i(24_000, 13_856), 0)
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(0, 1), Vector2i(1, 0)]:
		check(vertex_touch.has(cell), "zero-length vertex sweep includes every closed owner")
	var tangent := HexGrid.swept_cells(Vector2i(34_000, -10_000), Vector2i(34_000, 10_000), 10_000)
	var one_unit_gap := HexGrid.swept_cells(Vector2i(34_001, -10_000), Vector2i(34_001, 10_000), 10_000)
	check(tangent.has(Vector2i.ZERO), "radius includes exact vertical-face tangency")
	check(not one_unit_gap.has(Vector2i.ZERO), "one world unit beyond face tangency misses")
	var diagonal_gap := HexGrid.swept_cells(Vector2i(-23_999, -13_855), Vector2i(168_001, -13_855), 1)
	var diagonal_overlap := HexGrid.swept_cells(Vector2i(-23_999, -13_855), Vector2i(168_001, -13_855), 2)
	check(not diagonal_gap.has(Vector2i(0, -1)), "sqrt(2) endpoint-to-vertex gap exceeds a one-unit radius")
	check(diagonal_overlap.has(Vector2i(0, -1)), "two-unit radius reaches the same diagonal endpoint-to-vertex gap")
	check(HexGrid.swept_cells(Vector2i.ZERO, Vector2i.ZERO, 0).has(Vector2i.ZERO), "stationary point query includes its cell")


func _test_negative_high_speed_and_reversal() -> void:
	var start := Vector2i(-2_000_000, -93_000)
	var end := Vector2i(2_000_000, 141_000)
	var forward := HexGrid.swept_cells(start, end, 17_000)
	var reversed := HexGrid.swept_cells(end, start, 17_000)
	equal(forward, reversed, "reversing a signed high-speed sweep preserves exact canonical cells")
	check(forward.size() > 50, "high-speed traversal discovers intermediate cells instead of querying endpoints only")
	check(_canonically_sorted(forward), "high-speed sweep is deduplicated and canonical")
	check(forward.has(HexGrid.world_to_cell(Vector2i.ZERO)), "high-speed traversal includes a crossed middle cell")


func _test_local_query_matches_exhaustive_oracle() -> void:
	var cases: Array[Array] = [
		[Vector2i(-260_000, -170_000), Vector2i(330_000, 190_000), 0],
		[Vector2i(305_000, -280_000), Vector2i(-250_000, 315_000), 12_000],
		[Vector2i(-415_000, 90_000), Vector2i(440_000, 95_000), 32_000],
		[Vector2i(-23_999, -13_855), Vector2i(168_001, -13_855), 1],
		[Vector2i(-510_000, -405_000), Vector2i(-140_000, 490_000), 67_000],
	]
	for case_index: int in range(cases.size()):
		var start: Vector2i = cases[case_index][0]
		var end: Vector2i = cases[case_index][1]
		var radius: int = cases[case_index][2]
		var actual := HexGrid.swept_cells(start, end, radius)
		var expected := _exhaustive_float_oracle(start, end, radius, -18, 18)
		equal(actual, expected, "local traversal matches independent exhaustive polygon oracle case %d" % case_index)


func _test_random_cross_edge_oracle() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 91_515
	var crossed_cells := 0
	for case_index: int in range(80):
		var start := Vector2i(random.randi_range(-380_000, 380_000), random.randi_range(-300_000, 300_000))
		var end := Vector2i(random.randi_range(-380_000, 380_000), random.randi_range(-300_000, 300_000))
		crossed_cells += int(HexGrid.world_to_cell(start) != HexGrid.world_to_cell(end))
		var actual := HexGrid.swept_cells(start, end, 0)
		var expected := _exhaustive_float_oracle(start, end, 0, -12, 12)
		equal(actual, expected, "radius-zero random traversal matches exhaustive oracle case %d" % case_index)
	check(crossed_cells >= 60, "random differential set exercises cross-cell traversal rather than only the interior fast path")


func _test_invalid_bounds_fail_closed() -> void:
	equal(HexGrid.swept_cells(Vector2i.ZERO, Vector2i.ONE, -1), [], "negative sweep radius fails closed")
	equal(HexGrid.swept_cells(Vector2i.ZERO, Vector2i.ONE, HexGrid.MAX_SWEEP_RADIUS + 1), [], "radius beyond the proved court envelope fails closed")
	equal(HexGrid.swept_cells(Vector2i(HexGrid.MAX_ABS_QUERY_COORDINATE + 1, 0), Vector2i.ZERO, 0), [], "endpoint beyond the proved court envelope fails closed")


# Independent test oracle: enumerate a deliberately larger axial square and use
# floating polygon/segment distances. It shares neither HexGrid candidate
# discovery nor its exact natural-number predicate. Chosen differential cases
# stay away from irrational rounding boundaries; exact boundary regressions live
# in _test_sweep_edges_vertices_and_radius above.
func _exhaustive_float_oracle(start: Vector2i, end: Vector2i, radius: int, minimum: int, maximum: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q: int in range(minimum, maximum + 1):
		for r: int in range(minimum, maximum + 1):
			var cell := Vector2i(q, r)
			if _float_capsule_intersects_hex(start, end, radius, cell):
				result.append(cell)
	result.sort_custom(func(left: Vector2i, right: Vector2i) -> bool: return left.x < right.x or (left.x == right.x and left.y < right.y))
	return result


func _float_capsule_intersects_hex(start: Vector2i, end: Vector2i, radius: int, cell: Vector2i) -> bool:
	var polygon := HexGrid.vertices(cell)
	if _float_point_in_polygon(start, polygon) or _float_point_in_polygon(end, polygon):
		return true
	for index: int in range(polygon.size()):
		var edge_start: Vector2i = polygon[index]
		var edge_end: Vector2i = polygon[(index + 1) % polygon.size()]
		if _float_segments_intersect(start, end, edge_start, edge_end):
			return true
		var radius_squared := float(radius) * float(radius)
		if (
			_float_point_segment_distance_squared(edge_start, start, end) <= radius_squared
			or _float_point_segment_distance_squared(start, edge_start, edge_end) <= radius_squared
			or _float_point_segment_distance_squared(end, edge_start, edge_end) <= radius_squared
		):
			return true
	return false


func _float_point_in_polygon(point: Vector2i, polygon: Array[Vector2i]) -> bool:
	for index: int in range(polygon.size()):
		if _float_orientation(polygon[index], polygon[(index + 1) % polygon.size()], point) < 0.0:
			return false
	return true


func _float_segments_intersect(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> bool:
	var abc := _float_orientation(a, b, c)
	var abd := _float_orientation(a, b, d)
	var cda := _float_orientation(c, d, a)
	var cdb := _float_orientation(c, d, b)
	if abc == 0.0 and _oracle_point_on_segment(c, a, b):
		return true
	if abd == 0.0 and _oracle_point_on_segment(d, a, b):
		return true
	if cda == 0.0 and _oracle_point_on_segment(a, c, d):
		return true
	if cdb == 0.0 and _oracle_point_on_segment(b, c, d):
		return true
	return (abc < 0.0) != (abd < 0.0) and (cda < 0.0) != (cdb < 0.0)


func _float_orientation(a: Vector2i, b: Vector2i, c: Vector2i) -> float:
	# Scalar float values retain double precision in GDScript. Keeping each
	# component scalar avoids Vector2's build-level real_t precision, which can
	# round a sqrt(2) endpoint gap down to a one-unit radius at court scale.
	var ab_x := float(b.x) - float(a.x)
	var ab_y := float(b.y) - float(a.y)
	var ac_x := float(c.x) - float(a.x)
	var ac_y := float(c.y) - float(a.y)
	return ab_x * ac_y - ab_y * ac_x


func _float_point_segment_distance_squared(point: Vector2i, start: Vector2i, end: Vector2i) -> float:
	var delta_x := float(end.x) - float(start.x)
	var delta_y := float(end.y) - float(start.y)
	var offset_x := float(point.x) - float(start.x)
	var offset_y := float(point.y) - float(start.y)
	var length_squared := delta_x * delta_x + delta_y * delta_y
	if length_squared == 0.0:
		return offset_x * offset_x + offset_y * offset_y
	var amount := clampf((offset_x * delta_x + offset_y * delta_y) / length_squared, 0.0, 1.0)
	var separation_x := offset_x - delta_x * amount
	var separation_y := offset_y - delta_y * amount
	return separation_x * separation_x + separation_y * separation_y


func _oracle_point_on_segment(point: Vector2i, start: Vector2i, end: Vector2i) -> bool:
	return (
		point.x >= mini(start.x, end.x)
		and point.x <= maxi(start.x, end.x)
		and point.y >= mini(start.y, end.y)
		and point.y <= maxi(start.y, end.y)
	)


func _canonically_sorted(cells: Array[Vector2i]) -> bool:
	var seen: Dictionary[Vector2i, bool] = {}
	for index: int in range(cells.size()):
		if seen.has(cells[index]):
			return false
		seen[cells[index]] = true
		if index > 0:
			var previous: Vector2i = cells[index - 1]
			var current: Vector2i = cells[index]
			if previous.x > current.x or (previous.x == current.x and previous.y >= current.y):
				return false
	return true

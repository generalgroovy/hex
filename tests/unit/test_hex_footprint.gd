extends FluxTestSuite


func run() -> int:
	_test_disk_predicates_and_cells()
	_test_sector_predicates_and_cells()
	_test_intersection_uses_one_parameter_interval()
	_test_visuals_are_inscribed_and_cell_clipped()
	_test_invalid_inputs_fail_closed()
	return finish("hex-footprint")


func _test_disk_predicates_and_cells() -> void:
	var footprint := HexFootprint.disk(Vector2i(23_000, 0), 2_000)
	check(HexFootprint.validate(footprint), "bounded disk validates")
	check(HexFootprint.contains(footprint, Vector2i(25_000, 0)), "disk includes exact point tangency")
	check(not HexFootprint.contains(footprint, Vector2i(25_001, 0)), "disk excludes a one-unit radial miss")
	check(HexFootprint.segment_intersects(footprint, Vector2i(21_000, 2_000), Vector2i(25_000, 2_000)), "disk includes exact segment tangency")
	check(not HexFootprint.segment_intersects(footprint, Vector2i(21_000, 2_001), Vector2i(25_000, 2_001)), "disk excludes a one-unit segment miss")
	var cells := HexFootprint.intersected_cells(footprint, Vector2i.ZERO)
	equal(cells, [Vector2i.ZERO, Vector2i(1, 0)], "off-center disk clips across the touched shared face without nearest-N expansion")
	var negative := HexFootprint.intersected_cells(HexFootprint.disk(Vector2i(-24_000, -13_856), 0), Vector2i.ZERO)
	check(negative.size() >= 3 and negative.has(Vector2i.ZERO) and negative.has(Vector2i(-1, 0)), "zero-radius negative vertex retains every closed polygon contact")


func _test_sector_predicates_and_cells() -> void:
	var footprint := HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), 80_000, 500_000)
	check(HexFootprint.validate(footprint), "45-degree convex sector validates")
	check(HexFootprint.contains(footprint, Vector2i(30_000, 30_000)), "sector includes its exact rational cone boundary")
	check(not HexFootprint.contains(footprint, Vector2i(30_000, 30_001)), "sector excludes one unit beyond the cone boundary")
	check(HexFootprint.contains(footprint, Vector2i(80_000, 0)), "sector includes the radial endpoint")
	check(not HexFootprint.contains(footprint, Vector2i(80_001, 0)), "sector excludes one unit beyond range")
	check(HexFootprint.segment_intersects(footprint, Vector2i(40_000, -60_000), Vector2i(40_000, 60_000)), "segment crosses the sector interior")
	check(not HexFootprint.segment_intersects(footprint, Vector2i(-20_000, -5_000), Vector2i(-20_000, 5_000)), "segment behind the explicit origin misses")
	var cells := HexFootprint.intersected_cells(footprint, Vector2i.ZERO)
	check(cells.has(Vector2i.ZERO) and cells.has(Vector2i(1, 0)), "sector selects polygons it actually intersects")
	check(not cells.has(Vector2i(-1, 0)), "sector does not authorize the cell behind its origin merely because a range disk touches it")


func _test_intersection_uses_one_parameter_interval() -> void:
	var left := HexFootprint.disk(Vector2i(-10_000, 0), 6_000)
	var right := HexFootprint.disk(Vector2i(10_000, 0), 6_000)
	var empty_overlap := HexFootprint.intersection(left, right)
	var path_start := Vector2i(-20_000, 0)
	var path_end := Vector2i(20_000, 0)
	check(HexFootprint.segment_intersects(left, path_start, path_end), "control segment crosses first primitive")
	check(HexFootprint.segment_intersects(right, path_start, path_end), "control segment crosses second primitive")
	check(not HexFootprint.segment_intersects(empty_overlap, path_start, path_end), "separate primitive intervals cannot fabricate composite contact")
	check(not HexFootprint.intersects(left, right), "separated disks have no product overlap")
	equal(HexFootprint.intersected_cells(empty_overlap, Vector2i.ZERO), [], "disjoint disks inside the same hex cannot fabricate an occupied product cell")
	var overlapping := HexFootprint.intersection(HexFootprint.disk(Vector2i.ZERO, 10_000), HexFootprint.disk(Vector2i(12_000, 0), 10_000))
	check(HexFootprint.segment_intersects(overlapping, path_start, path_end), "shared parameter interval detects a real lens crossing")
	check(HexFootprint.contains(overlapping, Vector2i(6_000, 0)), "composite membership requires both primitives")
	check(HexFootprint.intersects(overlapping.parts[0], overlapping.parts[1]), "tangent-inclusive disk overlap is exact")
	equal(HexFootprint.intersected_cells(overlapping, Vector2i.ZERO), [Vector2i.ZERO], "small disk lens wholly inside one hex still selects its containing cell")
	var modifier := HexFootprint.disk(Vector2i(6_000, 0), 3_000)
	var modified_product := HexFootprint.intersection(overlapping, modifier)
	check(HexFootprint.validate(modified_product), "one primitive modifier may refine a two-parent product")
	check(HexFootprint.intersects(modifier, overlapping), "primitive-versus-product overlap filters a shared analytic witness against all leaves")
	check(HexFootprint.contains(modified_product, Vector2i(6_000, 0)), "three-leaf composite membership is simultaneous")
	equal(HexFootprint.intersected_cells(modified_product, Vector2i.ZERO), [Vector2i.ZERO], "three-leaf region wholly inside a cell retains that cell")
	check(not HexFootprint.intersects(HexFootprint.disk(Vector2i(25_000, 0), 2_000), overlapping), "primitive outside a product lens cannot match either parent independently")


func _test_visuals_are_inscribed_and_cell_clipped() -> void:
	var center := Vector2i(31_000, 0)
	var radius := HexFootprint.MAX_RADIUS
	var footprint := HexFootprint.disk(center, radius)
	var polygon := HexFootprint.visual_polygon(footprint, Vector2i.ZERO, Vector2i.ZERO)
	check(polygon.size() >= 3, "bounded display approximation clips to a visible cell polygon")
	for point: Vector2 in polygon:
		var offset := point - Vector2(center)
		check(offset.length_squared() <= float(radius) * float(radius) + 0.01, "display clipping never paints outside the authoritative disk")
		check(_float_point_in_hex(point, HexGrid.vertices(Vector2i.ZERO)), "display polygon stays inside its selected hex")
	var full := HexFootprint.visual_polygon(HexFootprint.disk(Vector2i.ZERO, 20_000), Vector2i.ZERO, Vector2i.ZERO)
	var minimum_radius := INF
	for point: Vector2 in full:
		minimum_radius = minf(minimum_radius, point.length())
	check(20_000.0 - minimum_radius <= 250.0, "inscribed display error remains at most one quarter pixel")


func _test_invalid_inputs_fail_closed() -> void:
	var too_large := HexFootprint.disk(Vector2i.ZERO, HexFootprint.MAX_RADIUS + 1)
	check(not HexFootprint.validate(too_large), "oversized authoritative disk is rejected")
	check(not HexFootprint.contains(too_large, Vector2i.ZERO), "invalid disk cannot authorize a point")
	equal(HexFootprint.intersected_cells(too_large, Vector2i.ZERO), [], "invalid disk cannot select cells")
	check(not HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i.ZERO, 10_000, 500_000)), "zero-aim sector is rejected")
	check(not HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), -1, 500_000)), "negative-range sector is rejected")
	check(HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), 380_000, 820_000)), "authored 380 px Spray range stays inside the proved sector envelope")
	check(HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), HexFootprint.MAX_SECTOR_RANGE, 820_000)), "sector accepts its 512 px geometry ceiling")
	check(not HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), HexFootprint.MAX_SECTOR_RANGE + 1, 820_000)), "sector rejects one unit beyond its geometry ceiling")
	var primitive := HexFootprint.disk(Vector2i.ZERO, 1_000)
	var three_way := HexFootprint.intersection(HexFootprint.intersection(primitive, primitive), primitive)
	check(HexFootprint.validate(three_way), "one modifier may intersect a two-parent product within the explicit three-leaf bound")
	check(not HexFootprint.validate(HexFootprint.intersection(three_way, primitive)), "a third composite level fails closed")


func _float_point_in_hex(point: Vector2, vertices: Array[Vector2i]) -> bool:
	for index: int in range(vertices.size()):
		var a := Vector2(vertices[index])
		var b := Vector2(vertices[(index + 1) % vertices.size()])
		if (b - a).cross(point - a) < -0.01:
			return false
	return true

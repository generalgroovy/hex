extends FluxTestSuite


func run() -> int:
	_test_exact_closed_hex_predicates()
	_test_exact_hex_intersections_and_witness()
	_test_canonical_cell_and_render_geometry()
	_test_inherited_stored_witness_quantization()
	_test_invalid_hex_fails_closed()
	return finish("hex-footprint-hex")


func _test_exact_closed_hex_predicates() -> void:
	var footprint := HexFootprint.hex(Vector2i.ZERO, Vector2i.ZERO)
	check(HexFootprint.validate(footprint), "bounded canonical hex validates")
	check(HexFootprint.contains(footprint, Vector2i.ZERO), "hex contains its center")
	check(HexFootprint.contains(footprint, Vector2i(32_000, 0)), "hex includes an exact face")
	check(not HexFootprint.contains(footprint, Vector2i(32_001, 0)), "hex excludes one fixed unit beyond a face")
	check(HexFootprint.contains(footprint, Vector2i(0, -36_950)), "hex includes an exact vertex")
	check(not HexFootprint.contains(footprint, Vector2i(0, -36_951)), "hex excludes one fixed unit beyond a vertex")
	var crossing := HexFootprint.segment_interval(footprint, Vector2i(-50_000, 0), Vector2i(50_000, 0))
	check(bool(crossing.hit), "closed convex interval detects an interior crossing")
	check(absf(float(crossing.low) - 0.18) <= 0.0000001, "hex crossing retains the exact left-face entry parameter")
	check(absf(float(crossing.high) - 0.82) <= 0.0000001, "hex crossing retains the exact right-face exit parameter")
	check(HexFootprint.segment_intersects(footprint, Vector2i(-1_000, -36_950), Vector2i(1_000, -36_950)), "segment includes exact vertex tangency")
	check(not HexFootprint.segment_intersects(footprint, Vector2i(-1_000, -36_951), Vector2i(1_000, -36_951)), "segment excludes a one-unit vertex miss")


func _test_exact_hex_intersections_and_witness() -> void:
	var footprint := HexFootprint.hex(Vector2i.ZERO, Vector2i.ZERO)
	var face_tangent := HexFootprint.disk(Vector2i(33_000, 0), 1_000)
	var face_miss := HexFootprint.disk(Vector2i(33_001, 0), 1_000)
	check(HexFootprint.intersects(footprint, face_tangent), "disk-to-hex exact face tangency intersects")
	check(not HexFootprint.intersects(footprint, face_miss), "disk-to-hex one-unit face miss is excluded")
	var outward_tangent_sector := HexFootprint.sector(Vector2i(32_000, 0), Vector2i(1_000, 0), 1_000, 500_000)
	var outward_miss_sector := HexFootprint.sector(Vector2i(32_001, 0), Vector2i(1_000, 0), 1_000, 500_000)
	check(HexFootprint.intersects(footprint, outward_tangent_sector), "sector-to-hex includes its exact face-origin tangency")
	check(not HexFootprint.intersects(footprint, outward_miss_sector), "outward sector one unit beyond the face does not leak back into the hex")
	var neighbor := HexFootprint.hex(Vector2i(1, 0), Vector2i.ZERO)
	var separated := HexFootprint.hex(Vector2i(2, 0), Vector2i.ZERO)
	check(HexFootprint.intersects(footprint, neighbor), "neighbor hexes share their closed face")
	check(not HexFootprint.intersects(footprint, separated), "non-neighbor hexes remain disjoint")
	var witness := HexFootprint.contact_point(footprint, face_tangent, Vector2i(40_000, 0))
	check(not witness.is_empty(), "hex contact returns a bounded analytic witness")
	check(HexFootprint.contains(footprint, witness.point) and HexFootprint.contains(face_tangent, witness.point), "integer face-tangent witness lies in both exact primitives")
	var shared := HexFootprint.intersection(footprint, HexFootprint.disk(Vector2i(30_000, 0), 4_000))
	check(HexFootprint.validate(shared), "hex participates in the existing bounded composite representation")
	check(HexFootprint.contains(shared, Vector2i(30_000, 0)), "composite membership remains simultaneous")
	check(not HexFootprint.contains(shared, Vector2i(33_000, 0)), "composite excludes disk material beyond the exact hex")


func _test_canonical_cell_and_render_geometry() -> void:
	var cell := Vector2i(-2, 3)
	var origin := Vector2i(640_000, 480_000)
	var footprint := HexFootprint.hex(cell, origin)
	equal(HexFootprint.intersected_cells(footprint, origin), [cell], "canonical hex storage selects exactly its authored cell")
	var polygon := HexFootprint.visual_polygon(footprint, cell, origin)
	equal(polygon.size(), 6, "canonical hex renders its exact six authored vertices")
	for point: Vector2 in polygon:
		check(HexFootprint.contains(footprint, Vector2i(roundi(point.x), roundi(point.y))), "every rendered vertex lies on the authoritative closed hex")


func _test_inherited_stored_witness_quantization() -> void:
	var stored := {Vector2i.ZERO: 1}
	var disk := HexFootprint.disk(Vector2i.ZERO, 100_000)
	var diagonal := HexFootprint.stored_segment_interval(
		disk, stored, Vector2i.ZERO,
		Vector2i(23_796, 70_811), Vector2i(-487, -44_962))
	equal(diagonal.get("point", Vector2i.ZERO), Vector2i(14_890, 28_353), "stored entry chooses the nearest representable lattice witness inside the exact hex")
	check(not bool(diagonal.get("quantization_outside", true)) and HexGrid._point_in_cell(diagonal.point, Vector2i.ZERO), "representable entry retains exact stored-cell membership metadata")
	var subunit_tangent := HexFootprint.contact_point_in_cells(
		HexFootprint.disk(Vector2i.ZERO, 1), HexFootprint.disk(Vector2i(3, 4), 4),
		Vector2i.ZERO, stored, Vector2i.ZERO)
	equal(subunit_tangent.get("point", Vector2i.ZERO), Vector2i(1, 1), "non-lattice analytic tangency retains its deterministic nearest fixed-grid witness")
	check(bool(subunit_tangent.get("quantization_outside", false)), "nonrepresentable tangency explicitly carries bounded outside provenance")
	check(float(subunit_tangent.get("quantization_error_squared", 2.0)) <= 1.0, "outside witness remains within one fixed world unit of continuous contact")
	# Compiled Water Spray has a 5px collision radius, so a wall beginning at
	# x=400000 clamps its center to x=395000. A 34px field shifted inward by
	# one fixed unit has a real [394999,395000] lens; primitive boundary
	# crossings alone all lie on the Spray terminal arc.
	var court_origin := Vector2i(640_000, 480_000)
	var spray := HexFootprint.sector(Vector2i(200_000, court_origin.y), Vector2i(1_000, 0), 195_000, 820_000)
	var inward_field := HexFootprint.disk(Vector2i(428_999, court_origin.y), 34_000)
	var field_cells := {}
	for cell: Vector2i in HexFootprint.intersected_cells(inward_field, court_origin):
		field_cells[cell] = 1
	var interior_lens := HexFootprint.contact_point_in_cells(spray, inward_field, Vector2i(200_000, court_origin.y), field_cells, court_origin)
	check(not interior_lens.is_empty(), "one-fixed-unit pre-wall Spray lens keeps a stored common witness")
	if not interior_lens.is_empty():
		check(HexFootprint.contains(spray, interior_lens.point) and HexFootprint.contains(inward_field, interior_lens.point), "pre-wall witness lies in both authoritative primitives")


func _test_invalid_hex_fails_closed() -> void:
	var outside := HexFootprint.hex(Vector2i(1000, 1000), Vector2i(8_000_000, 8_000_000))
	check(not HexFootprint.validate(outside), "hex whose vertices exceed the coordinate envelope fails validation")
	check(not HexFootprint.contains(outside, Vector2i.ZERO), "invalid hex cannot authorize a point")
	equal(HexFootprint.intersected_cells(outside, Vector2i.ZERO), [], "invalid hex cannot select storage")

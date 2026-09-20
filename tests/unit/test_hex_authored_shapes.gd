extends FluxTestSuite


func run() -> int:
	_test_capsule_schema_and_membership()
	_test_capsule_positive_area_boundaries()
	_test_capsule_radius_monotonicity_and_translation()
	_test_annulus_schema_hole_and_thin_band()
	_test_annulus_whole_hex_authority()
	_test_selection_only_contact_and_intersection_refusals()
	return finish("hex-authored-shapes")


func _test_capsule_schema_and_membership() -> void:
	var shape := HexFootprint.capsule(Vector2i(-40_000, 7_000), Vector2i(60_000, 7_000), 12_000)
	check(HexFootprint.validate(shape), "bounded positive-radius capsule validates")
	check(HexFootprint.contains(shape, Vector2i(-52_000, 7_000)), "capsule includes its exact start-cap boundary")
	check(HexFootprint.contains(shape, Vector2i(20_000, 19_000)), "capsule includes its exact side boundary")
	check(not HexFootprint.contains(shape, Vector2i(20_000, 19_001)), "capsule excludes a one-unit side miss")
	check(HexFootprint.contains(shape, Vector2i(72_000, 7_000)), "capsule includes its exact end-cap boundary")

	var point := HexFootprint.capsule(Vector2i(0, -27_712), Vector2i(0, -27_712), 0)
	check(HexFootprint.validate(point), "degenerate radius-zero capsule retains the disk-compatible point contract")
	equal(HexFootprint.selected_cells(point, Vector2i.ZERO), [Vector2i(0, -1)], "radius-zero capsule selects the point's canonical negative-side owner")
	check(not HexFootprint.validate(HexFootprint.capsule(Vector2i.ZERO, Vector2i(1, 0), 0)), "nondegenerate zero-width capsule fails closed")
	check(not HexFootprint.validate(HexFootprint.capsule(Vector2i.ZERO, Vector2i(HexFootprint.MAX_CAPSULE_LENGTH + 1, 0), 1)), "capsule rejects a path one unit beyond its length envelope")
	check(not HexFootprint.validate(HexFootprint.capsule(Vector2i.ZERO, Vector2i.ZERO, HexFootprint.MAX_CAPSULE_RADIUS + 1)), "capsule rejects a radius one unit beyond its envelope")
	check(not HexFootprint.validate({"kind": "capsule", "start": Vector2i.ZERO, "end": Vector2i.ZERO, "radius": "1"}), "capsule rejects a coercible non-integer radius")


func _test_capsule_positive_area_boundaries() -> void:
	var face := Vector2i(24_000, 0)
	var on_face := HexFootprint.capsule(face + Vector2i(0, -10_000), face + Vector2i(0, 10_000), 1)
	var face_cells := HexFootprint.selected_cells(on_face, Vector2i.ZERO)
	check(face_cells.has(Vector2i.ZERO) and face_cells.has(Vector2i(1, 0)), "positive-width capsule centered on a face owns positive area on both sides")

	var side_tangent := HexFootprint.capsule(face + Vector2i(1, -10_000), face + Vector2i(1, 10_000), 1)
	var tangent_cells := HexFootprint.selected_cells(side_tangent, Vector2i.ZERO)
	check(not tangent_cells.has(Vector2i.ZERO), "exact capsule-side tangency does not select the left cell")
	check(tangent_cells.has(Vector2i(1, 0)), "the tangent capsule selects the cell containing its positive-width axis")
	var side_overlap := HexFootprint.capsule(face + Vector2i(1, -10_000), face + Vector2i(1, 10_000), 2)
	check(HexFootprint.selected_cells(side_overlap, Vector2i.ZERO).has(Vector2i.ZERO), "one-unit capsule penetration selects the formerly tangent cell")

	var vertex := Vector2i(24_000, 13_856)
	var vertex_tangent := HexFootprint.capsule(vertex + Vector2i(6_000, 8_000), vertex + Vector2i(6_000, 8_000), 10_000)
	check(not HexFootprint.selected_cells(vertex_tangent, Vector2i.ZERO).has(Vector2i.ZERO), "exact capsule-cap vertex tangency has zero selected area in the center cell")
	var vertex_overlap := HexFootprint.capsule(vertex + Vector2i(5_999, 7_999), vertex + Vector2i(5_999, 7_999), 10_000)
	check(HexFootprint.selected_cells(vertex_overlap, Vector2i.ZERO).has(Vector2i.ZERO), "fixed-unit vertex penetration restores positive selected area")


func _test_capsule_radius_monotonicity_and_translation() -> void:
	var grid_origin := Vector2i(-2_000_000, 1_500_000)
	var start := grid_origin + Vector2i(-70_000, -11_000)
	var finish := grid_origin + Vector2i(85_000, 23_000)
	var small := HexFootprint.selected_cells(HexFootprint.capsule(start, finish, 1), grid_origin)
	var medium := HexFootprint.selected_cells(HexFootprint.capsule(start, finish, 12_000), grid_origin)
	var large := HexFootprint.selected_cells(HexFootprint.capsule(start, finish, 64_000), grid_origin)
	check(not small.is_empty(), "far-translated off-center capsule retains exact continuous path ownership")
	for cell: Vector2i in small:
		check(medium.has(cell), "increasing capsule radius preserves every radius-one selected cell")
	for cell: Vector2i in medium:
		check(large.has(cell), "increasing capsule radius preserves every medium selected cell")
	check(small.has(HexGrid.world_to_cell(start - grid_origin)), "capsule selects the canonical cell containing its exact negative endpoint")
	check(small.has(HexGrid.world_to_cell(finish - grid_origin)), "capsule selects the canonical cell containing its exact positive endpoint")


func _test_annulus_schema_hole_and_thin_band() -> void:
	var ring := HexFootprint.annulus(Vector2i.ZERO, 40_000, 80_000)
	check(HexFootprint.validate(ring), "bounded positive-thickness annulus validates")
	check(not HexFootprint.contains(ring, Vector2i.ZERO), "annulus center remains in the authored hole")
	check(not HexFootprint.contains(ring, Vector2i(39_999, 0)), "annulus excludes a point one unit inside its hole")
	check(HexFootprint.contains(ring, Vector2i(40_000, 0)), "annulus includes its exact inner boundary")
	check(HexFootprint.contains(ring, Vector2i(80_000, 0)), "annulus includes its exact outer boundary")
	check(not HexFootprint.contains(ring, Vector2i(80_001, 0)), "annulus excludes a one-unit outer miss")

	check(HexFootprint.validate(HexFootprint.annulus(Vector2i.ZERO, 23_999, 24_000)), "one-unit annulus band remains a valid positive-area shape")
	check(not HexFootprint.validate(HexFootprint.annulus(Vector2i.ZERO, 24_000, 24_000)), "zero-thickness annulus rejects")
	check(not HexFootprint.validate(HexFootprint.annulus(Vector2i.ZERO, 24_001, 24_000)), "reversed annulus radii reject")
	check(not HexFootprint.validate(HexFootprint.annulus(Vector2i.ZERO, 0, 0)), "zero-radius annulus rejects rather than inventing point ownership")
	check(not HexFootprint.validate({"kind": "annulus", "center": Vector2i.ZERO, "inner_radius": 1.0, "outer_radius": 2}), "annulus rejects a coercible non-integer radius")


func _test_annulus_whole_hex_authority() -> void:
	var wide_hole := HexFootprint.annulus(Vector2i.ZERO, 70_000, 100_000)
	var selected := HexFootprint.selected_cells(wide_hole, Vector2i.ZERO)
	check(not selected.has(Vector2i.ZERO), "hex wholly inside the annulus hole owns no ring quantity")
	check(not selected.is_empty(), "same annulus selects surrounding whole hexes with positive band area")
	if selected.is_empty():
		return

	var thin := HexFootprint.annulus(Vector2i.ZERO, 23_999, 24_000)
	var thin_cells := HexFootprint.selected_cells(thin, Vector2i.ZERO)
	check(thin_cells.has(Vector2i.ZERO), "one-unit band retains positive area in the center hex near its faces")
	check(not thin_cells.has(Vector2i(1, 0)), "exact outer-circle face tangency does not grow the thin band into its neighbor")
	var penetrated := HexFootprint.selected_cells(HexFootprint.annulus(Vector2i.ZERO, 23_999, 24_001), Vector2i.ZERO)
	check(penetrated.has(Vector2i(1, 0)), "one-unit outer penetration selects the neighboring hex")

	var authority := {}
	for cell: Vector2i in selected:
		authority[cell] = 1
	var sample_cell: Vector2i = selected[0]
	var sample_point := HexGrid.center(sample_cell)
	check(HexFootprint.contains_selected(authority, Vector2i.ZERO, sample_point), "annulus formation stores authority in canonical whole-hex membership")
	var face := Vector2i(24_000, 0)
	var owner := HexGrid.world_to_cell(face)
	check(HexFootprint.contains_selected({owner: 1}, Vector2i.ZERO, face), "whole-hex annulus authority uses the existing canonical face owner")


func _test_selection_only_contact_and_intersection_refusals() -> void:
	var capsule := HexFootprint.capsule(Vector2i.ZERO, Vector2i(20_000, 0), 2_000)
	var annulus := HexFootprint.annulus(Vector2i.ZERO, 10_000, 20_000)
	check(not bool(HexFootprint.segment_interval(capsule, Vector2i(-30_000, 0), Vector2i(30_000, 0)).get("hit", false)), "capsule does not claim generic contact-interval support")
	check(not bool(HexFootprint.segment_interval(annulus, Vector2i(-30_000, 0), Vector2i(30_000, 0)).get("hit", false)), "annulus rejects a lossy single interval across two disjoint bands")
	equal(HexFootprint.intersected_cells(capsule, Vector2i.ZERO), [], "capsule closed-contact cell enumeration is explicitly unsupported")
	equal(HexFootprint.intersected_cells(annulus, Vector2i.ZERO), [], "annulus closed-contact cell enumeration is explicitly unsupported")
	check(not HexFootprint.intersects(capsule, HexFootprint.disk(Vector2i.ZERO, 5_000)), "selection-only capsule does not claim generic shape contact")
	check(not HexFootprint.intersects(annulus, HexFootprint.disk(Vector2i(15_000, 0), 1_000)), "selection-only annulus does not claim generic shape contact")
	check(not HexFootprint.validate(HexFootprint.intersection(capsule, HexFootprint.disk(Vector2i.ZERO, 5_000))), "intersection explicitly rejects a capsule child")
	check(not HexFootprint.validate(HexFootprint.intersection(annulus, HexFootprint.disk(Vector2i.ZERO, 5_000))), "intersection explicitly rejects an annulus child")
	var old_intersection := HexFootprint.intersection(HexFootprint.disk(Vector2i.ZERO, 20_000), HexFootprint.disk(Vector2i(10_000, 0), 20_000))
	check(HexFootprint.validate(old_intersection), "existing disk intersection API remains valid")
	check(not HexFootprint.selected_cells(old_intersection, Vector2i.ZERO).is_empty(), "existing intersection selection remains operational")

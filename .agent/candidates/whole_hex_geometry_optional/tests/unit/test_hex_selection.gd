extends FluxTestSuite


func run() -> int:
	_test_positive_area_disk_selection()
	_test_sector_selection_and_allowed_cells()
	_test_canonical_membership_and_sweep()
	_test_whole_cell_contacts()
	return finish("hex-selection")


func _test_positive_area_disk_selection() -> void:
	var center_tiny := HexFootprint.selected_cells(HexFootprint.disk(Vector2i.ZERO, 1), Vector2i.ZERO)
	equal(center_tiny, [Vector2i.ZERO], "one-unit disk selects its containing hex without nearest-cell expansion")
	var face := Vector2i(32_000, 0)
	equal(
		HexFootprint.selected_cells(HexFootprint.disk(face, 1), Vector2i.ZERO),
		[Vector2i.ZERO, Vector2i(1, 0)],
		"positive half-disks on both sides of a face select both whole cells")
	var vertex := Vector2i(32_000, 18_475)
	equal(
		HexFootprint.selected_cells(HexFootprint.disk(vertex, 1), Vector2i.ZERO),
		[Vector2i.ZERO, Vector2i(0, 1), Vector2i(1, 0)],
		"a tiny disk at a vertex selects exactly the three positive-area owners")
	var tangent := HexFootprint.selected_cells(HexFootprint.disk(Vector2i(42_000, 0), 10_000), Vector2i.ZERO)
	check(not tangent.has(Vector2i.ZERO), "exact disk-to-face tangency does not create a whole cell")
	check(tangent.has(Vector2i(1, 0)), "the same disk selects the cell containing positive area")
	var zero_point := Vector2i(0, -36_950)
	equal(
		HexFootprint.selected_cells(HexFootprint.disk(zero_point, 0), Vector2i.ZERO),
		[Vector2i(0, -1)],
		"radius zero selects only the canonical negative-side vertex owner")
	var small := HexFootprint.selected_cells(HexFootprint.disk(Vector2i(-20_000, -20_000), 2_000), Vector2i.ZERO)
	var large := HexFootprint.selected_cells(HexFootprint.disk(Vector2i(-20_000, -20_000), 50_000), Vector2i.ZERO)
	for cell: Vector2i in small:
		check(large.has(cell), "increasing disk radius preserves every previously selected cell")


func _test_sector_selection_and_allowed_cells() -> void:
	var face := Vector2i(32_000, 0)
	var outward := HexFootprint.sector(face, Vector2i(1_000, 0), 10_000, 500_000)
	var selected := HexFootprint.selected_cells(outward, Vector2i.ZERO)
	check(selected.has(Vector2i(1, 0)), "sector with an apex on a face selects the cell containing its positive wedge")
	check(not selected.has(Vector2i.ZERO), "sector apex and side tangency alone do not select the cell behind it")
	equal(
		HexFootprint.selected_cells(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), 0, 500_000), Vector2i.ZERO),
		[],
		"zero-range sector has no positive area")
	var tiny := HexFootprint.selected_cells(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), 1, 820_000), Vector2i.ZERO)
	equal(tiny, [Vector2i.ZERO], "one-unit narrow sector retains its positive area inside the origin cell")
	_test_translated_rotated_sector_boundaries()
	var allowed := {Vector2i(1, 0): 1}
	equal(HexFootprint.selected_cells(HexFootprint.disk(face, 1), Vector2i.ZERO, allowed), [Vector2i(1, 0)], "allowed-cell filtering is applied after geometric selection")


# These expectations come directly from the authored face x = origin.x +
# 32_000. The 3-4-5 aims make one cone side exactly vertical or put the left
# face normal strictly inside the cone; no production selection helper is used
# to derive the expected cells.
func _test_translated_rotated_sector_boundaries() -> void:
	var grid_origin := Vector2i(2_000_000, -1_500_000)
	var left := Vector2i.ZERO
	var right := Vector2i(1, 0)
	var face_start := grid_origin + Vector2i(32_000, 0)
	# aim=(600,800), cos=4/5: upper side is the +Y ray on the shared
	# vertical face and the cone interior is wholly on the right side.
	var side_tangent := HexFootprint.sector(face_start, Vector2i(600, 800), 10_000, 640_000)
	var side_cells := HexFootprint.selected_cells(side_tangent, grid_origin)
	check(not side_cells.has(left), "far-translated rotated cone-side tangency has zero area in the left cell")
	check(side_cells.has(right), "far-translated rotated cone retains positive area on its interior side")
	# Moving the apex one fixed unit into the left cell creates a real triangular
	# wedge there; this guards against a tolerance that erases fixed-grid area.
	var one_unit_wedge := HexFootprint.sector(face_start + Vector2i(-1, 0), Vector2i(600, 800), 10_000, 640_000)
	check(HexFootprint.selected_cells(one_unit_wedge, grid_origin).has(left), "one-unit translated cone wedge has positive area in the left cell")
	# The rotated aim leaves the direct -X radius strictly inside this wider
	# cone. A 10,000 radius from x=42,000 is terminal-arc tangent to the face;
	# adding one unit crosses it with positive area.
	var arc_tangent := HexFootprint.sector(grid_origin + Vector2i(42_000, 0), Vector2i(-800, 600), 10_000, 500_000)
	check(not HexFootprint.selected_cells(arc_tangent, grid_origin).has(left), "far-translated rotated terminal-arc tangency does not select the left cell")
	var arc_overlap := HexFootprint.sector(grid_origin + Vector2i(42_000, 0), Vector2i(-800, 600), 10_001, 500_000)
	check(HexFootprint.selected_cells(arc_overlap, grid_origin).has(left), "one-unit terminal-arc penetration selects the left cell")


func _test_canonical_membership_and_sweep() -> void:
	var left := {Vector2i.ZERO: 1}
	var right := {Vector2i(1, 0): 1}
	var face := Vector2i(32_000, 0)
	check(HexFootprint.contains_selected(left, Vector2i.ZERO, face), "shared face belongs to its canonical selected owner")
	check(not HexFootprint.contains_selected(right, Vector2i.ZERO, face), "noncanonical neighbor cannot claim the shared face")
	check(HexFootprint.contains_selected(right, Vector2i.ZERO, face + Vector2i(1, 0)), "one fixed unit across the face belongs to the right selected cell")
	equal(HexFootprint.traversed_selected_cells(right, Vector2i.ZERO, face, face), [], "stationary noncanonical face returns no traversed selected cell")
	equal(HexFootprint.traversed_selected_cells(left, Vector2i.ZERO, face, face), [Vector2i.ZERO], "stationary canonical face resolves directly to its selected owner")
	equal(HexFootprint.traversed_selected_cells(right, Vector2i.ZERO, Vector2i.ZERO, Vector2i(64_000, 0)), [Vector2i(1, 0)], "one segment sweep reports the crossed selected cell")
	equal(HexFootprint.traversed_selected_cells(right, Vector2i.ZERO, Vector2i(32_000, -10_000), Vector2i(32_000, 10_000)), [], "boundary-only traversal excludes the noncanonical selected neighbor")
	var crossing := HexFootprint.selected_segment_interval(right, Vector2i.ZERO, Vector2i.ZERO, Vector2i(64_000, 0))
	check(bool(crossing.get("hit", false)), "continuous segment finds the first selected whole-cell traversal")
	check(absf(float(crossing.get("low", 0.0)) - 0.5) <= 1.0e-12, "whole-cell traversal retains the exact face entry parameter")
	equal(crossing.get("cell", Vector2i.ZERO), Vector2i(1, 0), "entry reports the traversed selected cell")
	equal(crossing.get("point", Vector2i.ZERO), Vector2i(32_001, 0), "open face entry quantizes one fixed unit into its canonical selected owner")
	var boundary_only := HexFootprint.selected_segment_interval(right, Vector2i.ZERO, Vector2i(32_000, -10_000), Vector2i(32_000, 10_000))
	check(not bool(boundary_only.get("hit", false)), "a segment along a shared face is rejected for the noncanonical neighbor")
	check(not bool(HexFootprint.selected_segment_interval(right, Vector2i.ZERO, face, face).get("hit", false)), "stationary shared-face contact follows canonical ownership")
	check(bool(HexFootprint.selected_segment_interval(left, Vector2i.ZERO, face, face).get("hit", false)), "stationary shared-face contact remains eligible for the canonical owner")


func _test_whole_cell_contacts() -> void:
	var left := {Vector2i.ZERO: 1}
	var right := {Vector2i(1, 0): 1}
	var tangent_shape := HexFootprint.disk(Vector2i(42_000, 0), 10_000)
	var tangent := HexFootprint.contact_shape_selected(tangent_shape, left, Vector2i.ZERO, Vector2i(42_000, 0))
	check(not tangent.is_empty(), "continuous shape contact retains exact tangency with a selected whole cell")
	equal(tangent.get("point", Vector2i.ZERO), Vector2i(32_000, 0), "tangent contact reports the continuous face witness")
	equal(tangent.get("cell", Vector2i(9, 9)), Vector2i.ZERO, "tangent face witness names its canonical selected owner")
	equal(HexFootprint.shared_selected_contact(left, right, Vector2i.ZERO, Vector2i.ZERO), {}, "different whole cells have no persistent same-cell chemistry")
	var shared := HexFootprint.shared_selected_contact(right, {Vector2i(1, 0): 2}, Vector2i.ZERO, Vector2i(32_000, 0))
	check(not shared.is_empty(), "matching selected cells produce a persistent chemistry witness")
	equal(shared.get("cell", Vector2i.ZERO), Vector2i(1, 0), "same-cell chemistry reports the shared cell")
	equal(shared.get("point", Vector2i.ZERO), Vector2i(32_001, 0), "same-cell boundary preference moves by one unit into the canonical shared owner")

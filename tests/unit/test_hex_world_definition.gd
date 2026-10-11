extends FluxTestSuite

func run() -> int:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "trusted production campus loads")
	var definition := HexWorldDefinition.from_campus(layout)
	check(definition != null, "campus has bounded whole-map chemistry topology")
	if definition == null: return finish("hex-world-definition")
	equal(definition.eligible_cells.size(), 59466, "expanded seven-district world has its exact24px topology excluding authored geometry")
	check(definition.eligible_cells.size() <= HexChemistryWorld.MAX_CELLS, "whole-map topology stays within the shared finite cap")
	equal(HexChemistryWorld.MAX_CELLS, 65536, "expanded topology fits the complete unsigned16 cell-index range")
	var playable_top := layout.reserved_ui_top * SimConfig.FIXED_SCALE
	var expected_bounds := Rect2i(Vector2i(0, playable_top), Vector2i(layout.canvas_size.x * SimConfig.FIXED_SCALE, layout.canvas_size.y * SimConfig.FIXED_SCALE - playable_top))
	equal(definition.world_bounds, expected_bounds, "chemistry topology uses the complete playable collision canvas")
	equal(definition.district_bounds, definition.world_bounds, "legacy district bounds property aliases whole-map bounds")
	var duplicate := HexWorldDefinition.from_campus(layout)
	equal(duplicate.definition_hash, definition.definition_hash, "trusted geometry fingerprint is deterministic")
	var authority := definition.create_authority()
	check(authority != null and authority.chemistry_enabled, "definition creates one enabled shared authority")
	if authority == null: return finish("hex-world-definition")
	check(authority.immutable_topology() != null, "large empty world retains immutable trusted topology")
	equal(authority._sparse_cells.size(), 0, "map size alone allocates no active material rows")
	equal(HexChemistryWorld.MAX_CASTS, 64, "larger geography cannot increase paid cast budget")
	equal(HexChemistryWorld.MAX_PRODUCTS, 32, "larger geography cannot increase product budget")
	var topology := {}
	for cell: Vector2i in authority.cells: topology[cell] = 1
	var collision := layout.build_collision_world()
	for cell: Vector2i in definition.eligible_cells:
		for point: Vector2i in HexGrid.vertices(cell):
			check(point.x >= definition.world_bounds.position.x and point.y >= definition.world_bounds.position.y and point.x <= definition.world_bounds.end.x and point.y <= definition.world_bounds.end.y, "whole polygon stays inside playable collision bounds")
		var vertices := HexGrid.vertices(cell)
		var lower := vertices[0]
		var upper := vertices[0]
		for vertex: Vector2i in vertices:
			lower = lower.min(vertex)
			upper = upper.max(vertex)
		var clear := true
		for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
			var expanded := Rect2i(obstacle.minimum_x - 18_000, obstacle.minimum_y - 18_000, obstacle.maximum_x - obstacle.minimum_x + 36_000, obstacle.maximum_y - obstacle.minimum_y + 36_000)
			if upper.x <= expanded.position.x or lower.x >= expanded.end.x or upper.y <= expanded.position.y or lower.y >= expanded.end.y: continue
			if HexWorldDefinition._overlaps_rectangle(vertices, expanded): clear = false; break
		check(clear, "every admitted hex clears all immutable worldbone footprints")
	for destination: Dictionary in layout.travel_destinations():
		var point := Vector2i(int(destination.position[0]), int(destination.position[1])) * SimConfig.FIXED_SCALE
		check(HexFootprint.contains_selected(topology, authority.origin, point), "all travel areas retain actual chemistry: " + String(destination.id))
	var southern := HexGrid.world_to_cell(Vector2i(5_500_000, 5_350_000))
	check(southern.y > 256 and authority.has_cell(southern), "southern rows beyond old axial boundary are admitted")
	check(HexConvexGeometry.box_overlaps(HexGrid.center(southern), 12000, southern, Vector2i.ZERO), "expanded axial rows retain exact convex collision")
	var garden_sample := Vector2i(640_000, 544_000)
	var nexus_sample := layout.spawn * SimConfig.FIXED_SCALE
	var proving_sample := Vector2i(2_864_000, 832_000)
	check(HexFootprint.contains_selected(topology, authority.origin, garden_sample), "Movement Garden supports chemistry away from the old Crucible")
	check(HexFootprint.contains_selected(topology, authority.origin, nexus_sample), "Nexus spawn is no longer a chemistry-safe pocket")
	check(HexFootprint.contains_selected(topology, authority.origin, proving_sample), "Proving ground supports chemistry away from training dummies")
	for point: Vector2i in [Vector2i(256000,2320000), Vector2i(1536000,2320000), Vector2i(2528000,2480000)]:
		check(collision.can_occupy(point, MovementTuning.PLAYER_RADIUS), "southern extension sample is actual open collision space")
		check(HexFootprint.contains_selected(topology, authority.origin, point), "all three new southern training areas support authoritative chemistry")
	for point: Vector2i in [Vector2i(1328000,2428000), Vector2i(1612000,2464000)]:
		check(not HexFootprint.contains_selected(topology, authority.origin, point), "both new real practice walls exclude chemistry through their footprint")
	var bell: Dictionary = layout.stations_by_id["training-reset"]
	var bell_point := Vector2i(int(bell.position[0]), int(bell.position[1])) * SimConfig.FIXED_SCALE
	check(HexFootprint.contains_selected(topology, authority.origin, Vector2i(1888_000,1376_000)), "former Practice Bell pad remains chemically active")
	equal(bell_point, Vector2i(360_000, 1288_000), "Restore now resolves the shared recovery pavilion entrance from canonical layout")
	check(HexFootprint.contains_selected(topology, authority.origin, Vector2i(1808_000, 1312_000)), "retired standalone Restore facade leaves no stale chemistry exclusion")
	for offset: Vector2i in [Vector2i(0, 32000), Vector2i(0, 64000), Vector2i(-32000, 32000), Vector2i(32000, 32000)]:
		var point := bell_point + offset
		check(collision.can_occupy(point, MovementTuning.PLAYER_RADIUS), "grouped Restore front samples remain outside pavilion collision")
		check(HexFootprint.contains_selected(topology, authority.origin, point), "shared Restore front supports chemistry beyond exact solid footprint clearance")
	check(not HexFootprint.selected_cells(HexFootprint.disk(Vector2i(1568_000, 1248_000), 34_000), authority.origin, topology).is_empty(), "existing chemistry effigy can receive whole-hex effects")
	# Independent simple cases guard the rectangle exclusion predicate itself.
	var polygon := HexGrid.vertices(Vector2i.ZERO)
	check(HexWorldDefinition._overlaps_rectangle(polygon, Rect2i(-1, -1, 2, 2)), "inside rectangle overlaps")
	check(not HexWorldDefinition._overlaps_rectangle(polygon, Rect2i(12_000, -100, 100, 200)), "exact face tangency is not positive overlap")
	check(HexWorldDefinition._overlaps_rectangle(polygon, Rect2i(11_999, -100, 100, 200)), "one fixed unit of face overlap is detected")
	check(not HexWorldDefinition._overlaps_rectangle(polygon, Rect2i(22_000, -26_000, 1000, 1000)), "hex corner empty space is not rectangular cover")
	print("CAMPUS_HEX_TOPOLOGY cells=%d hash=%s" % [definition.eligible_cells.size(), definition.definition_hash])
	return finish("hex-world-definition")

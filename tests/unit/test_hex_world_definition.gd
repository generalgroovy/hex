extends FluxTestSuite

func run() -> int:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "trusted production campus loads")
	var definition := HexWorldDefinition.from_campus(layout)
	check(definition != null, "campus has bounded whole-map chemistry topology")
	if definition == null: return finish("hex-world-definition")
	equal(definition.eligible_cells.size(), 2766, "48px campus admits every whole hex outside unchanged expanded worldbone")
	check(definition.eligible_cells.size() <= HexChemistryWorld.MAX_CELLS, "whole-map topology stays within the shared finite cap")
	equal(HexChemistryWorld.MAX_CELLS, 4096, "whole-map topology retains an explicit finite authority cap")
	var playable_top := layout.reserved_ui_top * SimConfig.FIXED_SCALE
	var expected_bounds := Rect2i(Vector2i(0, playable_top), Vector2i(layout.canvas_size.x * SimConfig.FIXED_SCALE, layout.canvas_size.y * SimConfig.FIXED_SCALE - playable_top))
	equal(definition.world_bounds, expected_bounds, "chemistry topology uses the complete playable collision canvas")
	equal(definition.district_bounds, definition.world_bounds, "legacy district bounds property aliases whole-map bounds")
	var duplicate := HexWorldDefinition.from_campus(layout)
	equal(duplicate.definition_hash, definition.definition_hash, "trusted geometry fingerprint is deterministic")
	var authority := definition.create_authority()
	check(authority != null and authority.chemistry_enabled, "definition creates one enabled shared authority")
	if authority == null: return finish("hex-world-definition")
	var topology := {}
	for cell: Vector2i in authority.cells: topology[cell] = 1
	var collision := layout.build_collision_world()
	for cell: Vector2i in definition.eligible_cells:
		for point: Vector2i in HexGrid.vertices(cell):
			check(point.x >= definition.world_bounds.position.x and point.y >= definition.world_bounds.position.y and point.x <= definition.world_bounds.end.x and point.y <= definition.world_bounds.end.y, "whole polygon stays inside playable collision bounds")
		for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
			var expanded := Rect2i(obstacle.minimum_x - 18_000, obstacle.minimum_y - 18_000, obstacle.maximum_x - obstacle.minimum_x + 36_000, obstacle.maximum_y - obstacle.minimum_y + 36_000)
			check(not HexWorldDefinition._overlaps_rectangle(HexGrid.vertices(cell), expanded), "no admitted hex overlaps immutable worldbone clearance")
	var garden_sample := Vector2i(640_000, 544_000)
	var nexus_sample := layout.spawn * SimConfig.FIXED_SCALE
	var proving_sample := Vector2i(2_864_000, 832_000)
	check(HexFootprint.contains_selected(topology, authority.origin, garden_sample), "Movement Garden supports chemistry away from the old Crucible")
	check(HexFootprint.contains_selected(topology, authority.origin, nexus_sample), "Nexus spawn is no longer a chemistry-safe pocket")
	check(HexFootprint.contains_selected(topology, authority.origin, proving_sample), "Proving ground supports chemistry away from training dummies")
	var bell: Dictionary = layout.stations_by_id["training-reset"]
	var bell_point := Vector2i(int(bell.position[0]), int(bell.position[1])) * SimConfig.FIXED_SCALE
	check(HexFootprint.contains_selected(topology, authority.origin, bell_point), "Practice Bell and its former protected approach no longer exclude chemistry")
	check(not HexFootprint.selected_cells(HexFootprint.disk(Vector2i(1568_000, 1248_000), 34_000), authority.origin, topology).is_empty(), "existing chemistry effigy can receive whole-hex effects")
	# Independent simple cases guard the rectangle exclusion predicate itself.
	var polygon := HexGrid.vertices(Vector2i.ZERO)
	check(HexWorldDefinition._overlaps_rectangle(polygon, Rect2i(-1, -1, 2, 2)), "inside rectangle overlaps")
	check(not HexWorldDefinition._overlaps_rectangle(polygon, Rect2i(24_000, -100, 100, 200)), "exact face tangency is not positive overlap")
	check(HexWorldDefinition._overlaps_rectangle(polygon, Rect2i(23_999, -100, 100, 200)), "one fixed unit of face overlap is detected")
	check(not HexWorldDefinition._overlaps_rectangle(polygon, Rect2i(22_000, -26_000, 1000, 1000)), "hex corner empty space is not rectangular cover")
	print("CAMPUS_HEX_TOPOLOGY cells=%d hash=%s" % [definition.eligible_cells.size(), definition.definition_hash])
	return finish("hex-world-definition")

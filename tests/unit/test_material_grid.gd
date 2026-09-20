extends FluxTestSuite


const CATALOG_PATH: String = "res://content/materials/foundation_materials_v1.json"
const YARD_PATH: String = "res://content/maps/sanctum_material_yard_v1.json"


func run() -> int:
	for tick_rate: int in [120]:
		_test_seed_immutability_and_reset(tick_rate)
		_test_bounded_deterministic_work(tick_rate)
	_test_invalid_configuration_fails_closed()
	return finish("material-grid")


func _content() -> Array:
	var registry := MaterialRegistry.new()
	registry.load_from_file(CATALOG_PATH)
	var yard := MaterialYardDefinition.new()
	yard.load_from_file(YARD_PATH, registry)
	return [registry, yard]


func _grid(tick_rate: int) -> MaterialGrid:
	var content: Array = _content()
	var grid := MaterialGrid.new()
	grid.initialize(content[1], content[0], SimConfig.new(tick_rate))
	return grid


func _mutable_indices(count: int, width: int) -> Array[int]:
	var result: Array[int] = []
	for cell_y: int in range(70, 126):
		for cell_x: int in range(1, 127):
			result.append(cell_y * width + cell_x)
			if result.size() == count:
				return result
	return result


func _test_seed_immutability_and_reset(tick_rate: int) -> void:
	var grid := _grid(tick_rate)
	equal(grid.width * grid.height, 16_384, "%d Hz yard allocates exactly 128 x 128 cells" % tick_rate)
	equal(grid.material_wire_ids.size(), 16_384, "%d Hz material column storage is packed" % tick_rate)
	equal(grid.seed_state_hash.length(), 64, "%d Hz seed state hash exists" % tick_rate)
	equal(grid.seed_worldbone_hash.length(), 64, "%d Hz worldbone hash exists" % tick_rate)
	equal(String(grid.cell(0, 0).get("material", "")), "worldbone", "%d Hz perimeter is worldbone" % tick_rate)
	equal(String(grid.cell(40, 18).get("material", "")), "water", "%d Hz flow-basin seed imports" % tick_rate)
	equal(int(grid.cell(40, 18).get("charge", 0)), 700, "%d Hz Charge field coexists with water" % tick_rate)
	var initial_state_hash := grid.state_hash()
	var initial_worldbone_hash := grid.worldbone_hash()
	check(not grid.write_cell(0, 0, "water", 1000, 20_000), "%d Hz runtime write cannot alter worldbone" % tick_rate)
	check(grid.last_error.contains("worldbone"), "%d Hz immutable write failure is diagnosable" % tick_rate)
	equal(grid.worldbone_hash(), initial_worldbone_hash, "%d Hz refused write preserves worldbone hash" % tick_rate)
	check(grid.write_cell(10, 70, "water", 850, 22_000, 400, 300), "%d Hz legal mutable write succeeds" % tick_rate)
	check(grid.state_hash() != initial_state_hash, "%d Hz legal write changes canonical state" % tick_rate)
	equal(grid.worldbone_hash(), initial_worldbone_hash, "%d Hz mutable write cannot change worldbone hash" % tick_rate)
	check(not grid.write_cell(10, 70, "worldbone", 1000, 20_000), "%d Hz runtime cannot create worldbone" % tick_rate)
	grid.reset_to_seed()
	equal(grid.state_hash(), initial_state_hash, "%d Hz reset restores exact seed state" % tick_rate)
	equal(grid.worldbone_hash(), initial_worldbone_hash, "%d Hz reset preserves exact worldbone state" % tick_rate)
	equal(grid.awake_indices.size(), 0, "%d Hz reset clears work queue" % tick_rate)


func _test_bounded_deterministic_work(tick_rate: int) -> void:
	var grid := _grid(tick_rate)
	var mutable_indices := _mutable_indices(600, grid.width)
	var all_wakes_succeeded: bool = true
	for reverse_index: int in range(mutable_indices.size() - 1, -1, -1):
		var cell_index: int = mutable_indices[reverse_index]
		all_wakes_succeeded = grid.wake_cell(
			cell_index % grid.width,
			floori(float(cell_index) / float(grid.width)),
		) and all_wakes_succeeded
	check(all_wakes_succeeded, "%d Hz mutable cells enter the work queue" % tick_rate)
	var first_cell: int = mutable_indices[0]
	check(grid.wake_cell(first_cell % grid.width, floori(float(first_cell) / float(grid.width))), "%d Hz duplicate wake is accepted idempotently" % tick_rate)
	equal(grid.awake_indices.size(), 600, "%d Hz duplicate wake does not duplicate work" % tick_rate)
	var processed: PackedInt32Array = grid.process_awake()
	var expected_budget := 256
	equal(processed.size(), expected_budget, "%d Hz work is capped by per-second budget" % tick_rate)
	equal(processed[0], mutable_indices[0], "%d Hz work begins at lowest canonical cell index" % tick_rate)
	equal(processed[processed.size() - 1], mutable_indices[expected_budget - 1], "%d Hz work is processed in canonical order" % tick_rate)
	equal(grid.awake_indices.size(), 600 - expected_budget, "%d Hz excess work carries over" % tick_rate)
	var hash_after_first_pass := grid.state_hash()
	check(hash_after_first_pass.length() == 64, "%d Hz work queue is included in state hash" % tick_rate)

	var second_grid := _grid(tick_rate)
	for cell_index: int in mutable_indices:
		second_grid.wake_cell(
			cell_index % second_grid.width,
			floori(float(cell_index) / float(second_grid.width)),
		)
	second_grid.process_awake()
	equal(second_grid.state_hash(), hash_after_first_pass, "%d Hz insertion history canonicalizes to the same state" % tick_rate)


func _test_invalid_configuration_fails_closed() -> void:
	var content: Array = _content()
	var grid := MaterialGrid.new()
	check(not grid.initialize(content[1], content[0], SimConfig.new(90)), "unsupported material-grid tick rate fails closed")
	check(grid.last_error.contains("120"), "invalid tick-rate failure is diagnosable")

	var changed_registry := MaterialRegistry.new()
	changed_registry.data = (content[0] as MaterialRegistry).data.duplicate(true)
	for value: Variant in changed_registry.data.get("materials", []):
		var material: Dictionary = value
		if String(material.get("id", "")) == "stone":
			material["default_temperature"] = 21_000
	check(changed_registry.validate(), "changed but valid registry validates independently")
	var mismatched_grid := MaterialGrid.new()
	check(
		not mismatched_grid.initialize(content[1], changed_registry, SimConfig.new(120)),
		"yard/catalog hash mismatch fails closed",
	)

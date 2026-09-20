extends "res://tests/unit/test_hex_chemistry.gd"


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "whole coverage production catalog")
	var wire := _wire(catalog, "fire", "rapid")
	var court := _court()
	var id := _reserve_paid_bound(court, 1, wire, 96001)
	var event := _terminal(wire, 1, 96001, Vector2i.ZERO)
	event.position = court.origin + Vector2i(31_000, 0)
	var preview := court.preview_regions(event, court.casts[id])
	court.deposit_terminal(event, 0)
	var record: Dictionary = court.casts[id]
	equal(preview.size(), record.cells.size(), "preview and paid selected set agree")
	for region: Dictionary in preview:
		check(record.cells.has(region.cell), "preview cell belongs to authority")
		var rendered := court.render_regions(region.cell, "fire", 30.0)
		equal(rendered[0].polygon, region.polygon, "preview and rendered whole hex are identical")
		equal(region.polygon.size(), 6, "whole selected hex has all six corners")
	equal(_sum_values(record.cells), 600, "two whole cells share one paid budget")
	var actor := PlayerState.new(91)
	actor.spawn_protection_ticks = 0
	actor.health_recovery_per_second = 0
	actor.position_x = court.origin.x + 80_000
	actor.position_y = court.origin.y
	var before := actor.health
	var config := SimConfig.new(120)
	court.advance([actor], {}, 30, config, [])
	check(actor.health < before, "selected hex damages far beyond original 12px disk")
	actor.position_x = court.origin.x + 100_000
	before = actor.health
	court.advance([actor], {}, 60, config, [])
	equal(actor.health, before, "unselected neighboring hex is harmless")
	court.advance([actor], {91: court.origin + Vector2i(-100_000, 0)}, 90, config, [])
	check(actor.health < before, "fast full-field traversal cannot skip selected cells")
	actor.position_x = court.origin.x + 80_000
	actor.air_height = 1
	before = actor.health
	court.advance([actor], {}, 120, config, [])
	equal(actor.health, before, "airborne foot remains above ground Fire")
	actor.air_height = 0
	actor.spawn_protection_ticks = 1
	court.advance([actor], {}, 150, config, [])
	equal(actor.health, before, "spawn protection remains authoritative")
	actor.spawn_protection_ticks = 0
	actor.position_x = court.origin.x + 100_000
	court.advance([actor], {91: {"point": court.origin, "height": 1}}, 180, config, [])
	equal(actor.health, before, "landing outside field cannot expose airborne swept segment")
	actor.position_x = court.origin.x + 80_000
	var events: Array[Dictionary] = []
	court.advance([actor], {91: court.origin}, 210, config, events)
	equal(events.size(), 1, "crossing multiple cells yields one pressure pulse")
	check(court.conservation_valid(), "sweeps and rendering conserve paid material")
	court.expire_at(int(record.expires))
	check(record.cells.is_empty(), "expiry removes every whole selected cell")
	check(court.conservation_valid(), "expiry conserves finite payment")
	_test_selected_product_sweep()
	_test_authored_allocation_envelope(catalog)
	return finish("hex-whole-coverage")


func _test_selected_product_sweep() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "product sweep catalog")
	for element: String in ["fire", "water"]:
		var court := _court()
		var wire := _wire(catalog, element, "bolt")
		_deposit(court, 1, wire, 96101, Vector2i.ZERO, 0)
		_deposit(court, 2, wire, 96102, Vector2i.ZERO, 0)
		var product: Dictionary = court.products[court.products.keys()[0]]
		var actor := PlayerState.new(92)
		actor.position_x = court.origin.x + 200_000
		actor.position_y = court.origin.y
		var before := actor.health
		var position := Vector2i(actor.position_x, actor.position_y)
		var events: Array[Dictionary] = []
		court.apply_product_effects([actor], int(product.active_tick), SimConfig.new(120), CollisionWorld.new(1_280_000, 960_000), events, {92: court.origin - Vector2i(200_000, 0)})
		if element == "fire": check(actor.health < before, "Conflagration detects crossing-only pulse")
		else: check(Vector2i(actor.position_x, actor.position_y) != position, "Flood detects crossing-only flow")
		equal(events.size(), 1, "one product applies once across multiple cells")


func _test_authored_allocation_envelope(catalog: AbilityCatalog) -> void:
	var court := _court()
	# Conservative full-strength geometry bounds also cover every smaller
	# weakened terminal. Minimum live stocks: Bolt120, Heavy40, Spray200,
	# Rapid600; medium minimum80. No selected cell needs zero stock/truncation.
	for family_name: String in ["bolt", "heavy", "rapid", "spray"]:
		var wire := _wire(catalog, "fire", family_name)
		var definition := CombatTuning.cast_definition(wire)
		var minimum_stock: int = 600 / int(definition.reaction_strength)
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(32_000, 0), Vector2i(0, 36_950), Vector2i(-31_999, -18_475)]:
			var point := court.origin + offset
			var record := {"wire": wire, "origin": point - Vector2i(int(definition.get("range", 0)), 0)}
			var selected := court.footprint({"position": point, "direction": Vector2i(1000, 0)}, record)
			check(selected.size() <= minimum_stock, "authored %s minimum stock covers all selected cells" % family_name)
			for cell: Vector2i in selected:
				check(court.cells.has(cell), "authored selection stays within eligible map")
	for offset: Vector2i in [Vector2i.ZERO, Vector2i(32_000, 0), Vector2i(0, 36_950)]:
		var selected := HexFootprint.selected_cells(HexFootprint.disk(court.origin + offset, 64_000), court.origin, court.cells)
		check(selected.size() < 80, "smallest paid medium budget covers every selected hex")

extends "res://tests/unit/test_hex_chemistry.gd"

@warning_ignore_start("integer_division")

## Source-pinned Steam occupation regression. The expected exposure and damage
## values below are calculated directly from the approved authored constants;
## the production exposure helper is never used as the test oracle.

const BODY_TYPES: Array[String] = ["small", "middle", "large"]
const EXPECTED_RADII := {"small": 17_000, "middle": 18_000, "large": 19_000}
const OUTSIDE_RADIUS_POINT := Vector2i(80_000, 0)


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "Steam occupation loads the production ability catalog: %s" % catalog.last_error)
	var bodies := BodyTypeProfileCatalog.new()
	check(bodies.load_from_file(), "Steam occupation loads the three authored body profiles: %s" % bodies.last_error)
	var policy := HexRecipePolicy.definition(HexCourt.STEAM_WIRE)
	equal(int(policy.get("exposure_cap", 0)), 240, "Steam keeps the authored 240-tick exposure cap")
	equal(int(policy.get("exposure_exit_decay", 0)), 2, "Steam keeps the authored two-per-tick exit decay")
	equal(int(policy.get("exposure_damage_min", 0)), 2_000, "Steam keeps the authored minimum pulse damage")
	equal(int(policy.get("exposure_damage_max", 0)), 12_000, "Steam keeps the authored maximum pulse damage")
	equal(int(policy.get("pulse_ticks", 0)), 30, "Steam keeps the authored 30-tick pressure pulse")
	if not catalog.last_error.is_empty() or not bodies.last_error.is_empty():
		return finish("hex-steam-occupation")

	var reference: Dictionary = {}
	for body_type: String in BODY_TYPES:
		var radius := bodies.hurt_radius(body_type)
		equal(radius, int(EXPECTED_RADII[body_type]), "%s uses its authored hurt radius" % body_type)
		var result := _test_crossing_and_occupation(catalog, body_type, radius)
		_test_exit_reentry(catalog, body_type, radius)
		_test_same_product_seam(catalog, body_type, radius)
		_test_spawn_protection(catalog, body_type, radius)
		if reference.is_empty():
			reference = result
		else:
			equal(result, reference, "%s Steam foot-path outcomes match the other authored body sizes" % body_type)
	return finish("hex-steam-occupation")


func _steam_fixture(catalog: AbilityCatalog) -> Dictionary:
	var court := _court()
	_deposit(court, 1, _wire(catalog, "water", "bolt"), 81_001, Vector2i.ZERO, 0)
	_deposit(court, 2, _wire(catalog, "fire", "bolt"), 81_002, Vector2i.ZERO, 0)
	equal(court.products.size(), 1, "two distinct paid Bolt sources form exactly one Steam product")
	var product: Dictionary = court.products[_single_product_id(court)]
	equal(int(product.get("recipe_wire_id", 0)), HexCourt.STEAM_WIRE, "paid Water and Fire form Steam310")
	equal(int(product.get("quantity", 0)), 1_200, "Steam owns exactly both finite 600-unit paid budgets")
	equal(int(court.metrics.get("matter_paid", 0)), 1_200, "Steam fixture records exactly two paid source budgets")
	check(court.conservation_valid(), "Steam fixture begins with conserved paid matter")
	var point := court.origin + OUTSIDE_RADIUS_POINT
	var cell := HexGrid.world_to_cell(point - court.origin)
	var selection_radius := int(HexRecipePolicy.definition(HexCourt.STEAM_WIRE).radius)
	check(product.coverage.has(cell), "fixture point belongs to a selected whole Steam cell")
	check((point - Vector2i(product.position)).length_squared() > selection_radius * selection_radius, "fixture point is outside the generating radius")
	check(court.contains_stored(product, point), "stored whole-cell membership includes the outside-radius fixture point")
	return {"court": court, "product": product, "point": point, "cell": cell}


func _actor(id: int, radius: int, point: Vector2i) -> PlayerState:
	var actor := PlayerState.new(id)
	actor.radius = radius
	actor.position_x = point.x
	actor.position_y = point.y
	actor.spawn_protection_ticks = 0
	actor.health_recovery_per_second = 0
	return actor


func _test_crossing_and_occupation(catalog: AbilityCatalog, body_type: String, radius: int) -> Dictionary:
	var short_fixture := _steam_fixture(catalog)
	var short_court: HexChemistryWorld = short_fixture.court
	var short_product: Dictionary = short_fixture.product
	var short_point: Vector2i = short_fixture.point
	var short_actor := _actor(100 + radius / 1_000, radius, short_point)
	var short_expected := _occupy(short_court, short_product, short_actor, short_point, 12)
	equal(int(short_court.exposure[short_actor.entity_id]), 12, "%s short crossing accumulates exactly twelve contact ticks" % body_type)
	equal(short_actor.health_maximum - short_actor.health, int(short_expected.damage), "%s short crossing damage follows the independent authored formula" % body_type)

	var held_fixture := _steam_fixture(catalog)
	var held_court: HexChemistryWorld = held_fixture.court
	var held_product: Dictionary = held_fixture.product
	var held_point: Vector2i = held_fixture.point
	var held_actor := _actor(200 + radius / 1_000, radius, held_point)
	var held_expected := _occupy(held_court, held_product, held_actor, held_point, 60)
	equal(int(held_court.exposure[held_actor.entity_id]), 60, "%s held occupation accumulates once per authoritative contact tick" % body_type)
	equal(held_actor.health_maximum - held_actor.health, int(held_expected.damage), "%s held occupation damage follows the independent authored formula" % body_type)
	check(int(held_expected.damage) >= int(short_expected.damage), "%s sustained occupation is never safer than the matched short crossing" % body_type)
	equal(int(short_product.quantity), 1_200, "%s crossing cannot spend or refresh Steam product quantity" % body_type)
	equal(int(held_product.quantity), 1_200, "%s occupation cannot spend or refresh Steam product quantity" % body_type)
	check(short_court.conservation_valid() and held_court.conservation_valid(), "%s exposure schedules preserve both paid budgets" % body_type)
	return {
		"crossing_exposure": int(short_court.exposure[short_actor.entity_id]),
		"crossing_damage": short_actor.health_maximum - short_actor.health,
		"occupation_exposure": int(held_court.exposure[held_actor.entity_id]),
		"occupation_damage": held_actor.health_maximum - held_actor.health,
	}


func _occupy(court: HexChemistryWorld, product: Dictionary, actor: PlayerState, point: Vector2i, contact_ticks: int) -> Dictionary:
	var expected_exposure := 0
	var expected_damage := 0
	var start_tick := int(product.active_tick)
	var cell := HexGrid.world_to_cell(point - court.origin)
	var density := int(product.cells[cell])
	for offset: int in contact_ticks:
		var tick := start_tick + offset
		court.advance([actor], {actor.entity_id: point}, tick, SimConfig.new(120), [])
		expected_exposure = mini(240, expected_exposure + 1)
		if tick % 30 == 0:
			expected_damage += _expected_damage(product, density, expected_exposure)
	return {"exposure": expected_exposure, "damage": expected_damage}


func _test_exit_reentry(catalog: AbilityCatalog, body_type: String, radius: int) -> void:
	var fixture := _steam_fixture(catalog)
	var court: HexChemistryWorld = fixture.court
	var product: Dictionary = fixture.product
	var inside: Vector2i = fixture.point
	var outside := court.origin + HexGrid.center(Vector2i(5, 0))
	var actor := _actor(300 + radius / 1_000, radius, inside)
	var tick := int(product.active_tick)
	for unused: int in 12:
		court.advance([actor], {actor.entity_id: inside}, tick, SimConfig.new(120), [])
		tick += 1
	equal(int(court.exposure[actor.entity_id]), 12, "%s first visit accumulates twelve exposure" % body_type)
	actor.position_x = outside.x
	actor.position_y = outside.y
	for unused: int in 6:
		court.advance([actor], {actor.entity_id: outside}, tick, SimConfig.new(120), [])
		tick += 1
	equal(int(court.exposure[actor.entity_id]), 0, "%s six outside ticks decay twelve exposure without a reset bonus" % body_type)
	actor.position_x = inside.x
	actor.position_y = inside.y
	for unused: int in 12:
		court.advance([actor], {actor.entity_id: inside}, tick, SimConfig.new(120), [])
		tick += 1
	equal(int(court.exposure[actor.entity_id]), 12, "%s re-entry resumes from the decayed value and does not restore prior exposure" % body_type)
	equal(int(product.quantity), 1_200, "%s re-entry does not mint or consume reaction quantity" % body_type)
	check(court.conservation_valid(), "%s re-entry preserves paid source conservation" % body_type)


func _test_same_product_seam(catalog: AbilityCatalog, body_type: String, radius: int) -> void:
	var fixture := _steam_fixture(catalog)
	var court: HexChemistryWorld = fixture.court
	var product: Dictionary = fixture.product
	var pair := _ordered_neighbor_pair(product)
	check(pair.size() == 2, "%s Steam fixture contains an adjacent selected-cell seam" % body_type)
	if pair.size() != 2:
		return
	var start := court.origin + HexGrid.center(pair[0])
	var finish := court.origin + HexGrid.center(pair[1])
	var crossing := _actor(400 + radius / 1_000, radius, finish)
	var stationary := _actor(500 + radius / 1_000, radius, finish)
	var pulse_tick := (int(product.active_tick) + 29) / 30 * 30
	var events: Array[Dictionary] = []
	court.advance([crossing, stationary], {crossing.entity_id: start, stationary.entity_id: finish}, pulse_tick, SimConfig.new(120), events)
	equal(int(court.exposure[crossing.entity_id]), 1, "%s seam crossing accumulates one exposure, not one per traversed cell" % body_type)
	equal(int(court.exposure[stationary.entity_id]), 1, "%s stationary seam comparator accumulates one exposure" % body_type)
	equal(crossing.health, stationary.health, "%s same-product seam crossing cannot double-apply its pulse" % body_type)
	equal(events.size(), 2, "%s seam fixture emits exactly one pressure event per actor" % body_type)


func _ordered_neighbor_pair(product: Dictionary) -> Array[Vector2i]:
	var cells: Array = product.coverage.keys()
	cells.sort_custom(HexGrid._cell_less)
	for finish: Vector2i in cells:
		for direction: Vector2i in HexGrid.AXIAL_DIRECTIONS:
			var start := finish + direction
			if product.coverage.has(start) and int(product.cells[start]) <= int(product.cells[finish]):
				var pair: Array[Vector2i] = [start, finish]
				return pair
	var empty: Array[Vector2i] = []
	return empty


func _test_spawn_protection(catalog: AbilityCatalog, body_type: String, radius: int) -> void:
	var fixture := _steam_fixture(catalog)
	var court: HexChemistryWorld = fixture.court
	var product: Dictionary = fixture.product
	var point: Vector2i = fixture.point
	var protected := _actor(600 + radius / 1_000, radius, point)
	protected.spawn_protection_ticks = 2
	court.exposure[protected.entity_id] = 10
	var unprotected := _actor(700 + radius / 1_000, radius, point)
	var protected_health := protected.health
	var pulse_tick := (int(product.active_tick) + 29) / 30 * 30
	court.advance([protected, unprotected], {protected.entity_id: point, unprotected.entity_id: point}, pulse_tick, SimConfig.new(120), [])
	equal(protected.health, protected_health, "%s spawn protection blocks Steam damage while ground chemistry remains live" % body_type)
	equal(int(court.exposure[protected.entity_id]), 8, "%s protection decays existing exposure by the authored two-per-tick rule" % body_type)
	equal(int(court.exposure[unprotected.entity_id]), 1, "%s unprotected comparator still accumulates on the same live ground" % body_type)
	check(unprotected.health < unprotected.health_maximum, "%s unprotected comparator receives the live Steam pulse" % body_type)
	protected.spawn_protection_ticks = 0
	court.advance([protected], {protected.entity_id: point}, pulse_tick + 1, SimConfig.new(120), [])
	equal(int(court.exposure[protected.entity_id]), 9, "%s protection expiry resumes accumulation without refreshing Steam" % body_type)
	equal(int(product.quantity), 1_200, "%s protection state cannot change paid product quantity" % body_type)


func _expected_damage(product: Dictionary, density: int, exposure: int) -> int:
	var ramp := 2_000 + 6_000 * exposure / 240
	var density_scaled := mini(8_000, ramp * density / 400)
	return mini(12_000, density_scaled * int(product.intensity) / 1_000)

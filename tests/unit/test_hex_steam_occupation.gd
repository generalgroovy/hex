extends "res://tests/unit/test_hex_chemistry.gd"

@warning_ignore_start("integer_division")

## Source-pinned Steam occupation regression. The expected exposure and damage
## values below are calculated directly from the approved authored constants;
## the production exposure helper is never used as the test oracle.

const BODY_TYPES: Array[String] = ["small", "middle", "large"]
const EXPECTED_RADII := {"small": 17_000, "middle": 18_000, "large": 19_000}
# Outside the compact48px radius but inside the selected east cell (36..60px).
const OUTSIDE_RADIUS_POINT := Vector2i(56_000, 0)
const SteamSnapshot = preload("res://src/net/hex_chemistry_snapshot.gd")


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
	_test_cooling_cannot_increase_realized_pressure(catalog)
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


func _test_cooling_cannot_increase_realized_pressure(catalog: AbilityCatalog) -> void:
	# Use the production family definitions and real paid source ledgers. A
	# lower intensity label is not acceptance: compare actual actor damage at
	# every occupied cell against an independently formed, uncooled control.
	var families: Array[String] = ["rapid", "spray", "bolt", "heavy"]
	var strengths: Array[int] = [1, 3, 5, 15]
	for index: int in families.size():
		equal(int(CombatTuning.cast_definition(_wire(catalog, "water", families[index])).reaction_strength), strengths[index], "cooling matrix uses the current paid Water family strength")
	for parent_family: String in families:
		for cooler_family: String in families:
			for clipped: bool in [false, true]:
				for heated: bool in [false, true]:
					_compare_cooled_pressure(catalog, parent_family, cooler_family, clipped, heated, 600, 600, [0, 59, 239])
	# Canonical partial-expiry ownership fixtures, not a claim that a player
	# can currently split Water or Fire into arbitrary one-unit projectiles.
	# They preserve paid600 provenance and expired stock while exercising the
	# valid low-density/zero-allocation boundary of the chemistry authority.
	var every_exposure: Array[int] = []
	for previous_exposure: int in range(240): every_exposure.append(previous_exposure)
	for clipped: bool in [false, true]:
		for heated: bool in [false, true]:
			for cooler_stock: int in [1, 40, 599]:
				_compare_cooled_pressure(catalog, "heavy", "rapid", clipped, heated, 1, cooler_stock, every_exposure)
	_test_cooled_pressure_eligibility(catalog)
	_test_cooled_snapshot_continuation(catalog)
	_test_zero_intensity_steam_danger(catalog)
	_test_cooling_rounded_pressure_bound()


func _cooling_fixture(catalog: AbilityCatalog, parent_family: String, clipped: bool, heated: bool, parent_stock: int) -> Dictionary:
	var court := _court()
	if clipped:
		var single_cell: Array[Vector2i] = [Vector2i.ZERO]
		check(court.configure_geometry(court.origin, single_cell), "clipped cooling fixture configures one real eligible whole hex")
	var water_id := _reserve_paid_bound(court, 1, _wire(catalog, "water", parent_family), 91_001)
	var fire_id := _reserve_paid_bound(court, 2, _wire(catalog, "fire", parent_family), 91_002)
	_retain_paid_flight_stock(court, water_id, parent_stock)
	_retain_paid_flight_stock(court, fire_id, parent_stock)
	var formed := court.resolve_contact(91_001, 91_002, court.origin, 0)
	check(bool(formed.get("accepted", false)) and court.products.size() == 1, "distinct paid production-family parents form exactly one Steam product")
	var product: Dictionary = court.products[int(formed.product_id)]
	equal(int(product.recipe_wire_id), HexCourt.STEAM_WIRE, "cooling fixture uses active Steam310 authority")
	equal(int(product.quantity), parent_stock * 2, "formation transfers only the parents' remaining paid stock")
	if heated:
		var heater_wire := _wire(catalog, "fire", "bolt")
		var heater_id := _reserve_paid_bound(court, 3, heater_wire, 91_003)
		_retain_paid_flight_stock(court, heater_id, parent_stock)
		court.deposit_terminal(_terminal(heater_wire, 3, 91_003, Vector2i.ZERO), 25)
		check(bool(product.heated), "heated cooling control spends its independent Fire channel")
	check(court.conservation_valid(), "cooling fixture begins with conserved paid and expired stock")
	return {"court": court, "product": product}


func _retain_paid_flight_stock(court: HexCourt, cast_id: int, retained: int) -> void:
	if retained == HexCourt.MATTER_PER_CAST: return
	var record: Dictionary = court.casts[cast_id]
	var expired := CastParts.expire_flight(record, int(record.source), HexCourt.MATTER_PER_CAST - retained)
	equal(expired, HexCourt.MATTER_PER_CAST - retained, "partial-stock fixture expires the exact unused paid amount through source ownership")
	court.metrics.matter_expired += expired
	court._sync_cast_ledger(record)
	check(CastParts.validate(record), "partial-stock fixture retains valid immutable source provenance")
	equal(int(record.ledger.flight_quantity), retained, "partial-stock source owns exactly the requested live remainder")


func _compare_cooled_pressure(catalog: AbilityCatalog, parent_family: String, cooler_family: String, clipped: bool, heated: bool, parent_stock: int, cooler_stock: int, exposures: Array[int]) -> void:
	var control := _cooling_fixture(catalog, parent_family, clipped, heated, parent_stock)
	var cooled := _cooling_fixture(catalog, parent_family, clipped, heated, parent_stock)
	var court: HexCourt = cooled.court
	var product: Dictionary = cooled.product
	var before: Dictionary = product.duplicate(true)
	var label := "%s/%s clipped=%s heated=%s parent_stock=%d coolant_stock=%d" % [parent_family, cooler_family, clipped, heated, parent_stock, cooler_stock]
	var cooler_wire := _wire(catalog, "water", cooler_family)
	var cooler_id := _reserve_paid_bound(court, 4, cooler_wire, 91_004)
	_retain_paid_flight_stock(court, cooler_id, cooler_stock)
	court.deposit_terminal(_coolant_terminal(cooler_wire, 4, 91_004), 29)
	check(bool(product.cooled), "fresh paid Water consumes its one cooling channel: %s" % label)
	equal(int(product.quantity), int(before.quantity) + cooler_stock, "cooling keeps all consumed paid matter: %s" % label)
	equal(int(court.casts[cooler_id].consumed), cooler_stock, "cooling consumes only its live source remainder: %s" % label)
	equal(int(court.casts[cooler_id].ledger.remaining_strength), 0, "accepted coolant cannot be spent twice: %s" % label)
	equal(product.coverage, before.coverage, "cooling cannot enlarge or remove occupied hexes: %s" % label)
	equal(product.footprint, before.footprint, "cooling cannot move the selection origin or shape: %s" % label)
	for phase_key: String in ["created", "active_tick", "decay_tick", "expiry_tick"]:
		equal(int(product[phase_key]), int(before[phase_key]), "cooling does not refresh or shorten a lifecycle boundary: %s/%s" % [label, phase_key])
	var expected_sources: Array = before.source_ids.duplicate()
	expected_sources.append(91_004)
	equal(product.source_ids, expected_sources, "cooling retains original and incoming paid source provenance: %s" % label)
	check(int(product.intensity) < int(before.intensity), "cooling lowers thermal intensity as well as preserving its stock: %s" % label)
	var cells: Array = before.coverage.keys()
	cells.sort_custom(HexGrid._cell_less)
	var increased := ""
	var saw_positive_control := false
	var saw_zero_allocation := false
	for cell: Vector2i in cells:
		var point := court.origin + HexGrid.center(cell)
		var old_density := maxi(1, int(before.cells[cell]))
		saw_zero_allocation = saw_zero_allocation or int(before.cells[cell]) == 0
		for previous_exposure: int in exposures:
			var old_damage := _actual_steam_pulse(control.court, point, previous_exposure)
			var new_damage := _actual_steam_pulse(court, point, previous_exposure)
			equal(old_damage, _expected_damage(before, old_density, mini(240, previous_exposure + 1)), "uncool comparison pulse follows the independent rounded/capped formula: %s" % label)
			if parent_family == "bolt" and cooler_family == "rapid" and clipped and not heated and parent_stock == 600 and previous_exposure == 0:
				equal(old_damage, 3_037, "minimal paid BoltSteam/Rapidcoolant reproduction has the exact3037-unit uncooled pulse")
			saw_positive_control = saw_positive_control or old_damage > 0
			if new_damage > old_damage and increased.is_empty():
				increased = " cell=%s exposure=%d damage=%d->%d" % [cell, previous_exposure + 1, old_damage, new_damage]
	check(saw_positive_control, "cooling comparison contains genuinely damaging Steam: %s" % label)
	check(increased.is_empty(), "Water coolant cannot increase realized Steam harm: %s%s" % [label, increased])
	if parent_stock == 1 and not clipped:
		check(saw_zero_allocation, "finite low-stock fixture exercises selected cells with prior zero allocation")
	var once := product.duplicate(true)
	var unused := _reserve_paid_bound(court, 5, cooler_wire, 91_005)
	court.deposit_terminal(_coolant_terminal(cooler_wire, 5, 91_005), 31)
	equal(product, once, "a second Water source cannot reuse the cooling channel: %s" % label)
	equal(int(court.casts[unused].ground), HexCourt.MATTER_PER_CAST, "refused second coolant remains its own finite ground ingredient: %s" % label)
	check(court.conservation_valid() and (control.court as HexCourt).conservation_valid(), "pressure comparisons and channel refusal conserve all paid stock: %s" % label)


func _coolant_terminal(wire: int, owner: int, source: int) -> Dictionary:
	var terminal := _terminal(wire, owner, source, Vector2i.ZERO)
	# Real Spray terminals carry a nonzero fan endpoint. The generic center
	# fixture would have zero reach, correctly select nothing and expire paid
	# placement stock before the modifier query; that is not failed cooling.
	if String(CombatTuning.cast_definition(wire).family) == "spray":
		terminal.position = HexCourt.ORIGIN + Vector2i(48_000, 0)
	return terminal


func _actual_steam_pulse(court: HexCourt, point: Vector2i, previous_exposure: int, height: int = 0, team: int = 2, protected: bool = false) -> int:
	var actor := _actor(42, 18_000, point)
	actor.team_id = team
	actor.air_height = height
	actor.spawn_protection_ticks = 2 if protected else 0
	court.exposure[actor.entity_id] = previous_exposure
	var before := actor.health
	court.advance([actor], {actor.entity_id: {"point": point, "height": height}}, 30, SimConfig.new(120), [])
	return before - actor.health


func _test_cooled_pressure_eligibility(catalog: AbilityCatalog) -> void:
	var fixture := _cooling_fixture(catalog, "bolt", true, false, 600)
	var court: HexCourt = fixture.court
	_deposit(court, 4, _wire(catalog, "water", "rapid"), 91_004, Vector2i.ZERO, 29)
	var point := court.origin
	var expected := _actual_steam_pulse(court, point, 59)
	check(expected > 0, "cooled pressure eligibility fixture has a damaging positive control")
	for team: int in [1, 2, 3]:
		for height: int in [0, HexCourt.STEAM_HEIGHT]:
			equal(_actual_steam_pulse(court, point, 59, height, team), expected, "cooled Steam keeps shared own/ally/enemy hazard and inclusive48px ceiling")
		equal(_actual_steam_pulse(court, point, 59, HexCourt.STEAM_HEIGHT + 1, team), 0, "above-ceiling actors escape cooled Steam")
		equal(_actual_steam_pulse(court, point, 59, 0, team, true), 0, "spawn protection still blocks cooled Steam")


func _test_cooled_snapshot_continuation(catalog: AbilityCatalog) -> void:
	for partial_stock: bool in [false, true]:
		var fixture := _cooling_fixture(catalog, "heavy", false, true, 1 if partial_stock else 600)
		var original: HexCourt = fixture.court
		_deposit(original, 4, _wire(catalog, "water", "rapid"), 91_004, Vector2i.ZERO, 29)
		_actual_steam_pulse(original, original.origin, 39)
		var snapshot := SteamSnapshot.capture(original)
		check(not snapshot.is_empty(), "cooled finite-stock Steam captures without any added schema field")
		var restored := _court()
		check(SteamSnapshot.restore(snapshot, restored), "cooled finite-stock Steam restores under the unchanged schema")
		equal(restored.state_hash(), original.state_hash(), "cooled intensity, exposure, provenance and one-use channel resume exactly")
		var first := _actor(42, 18_000, original.origin)
		var second := _actor(42, 18_000, restored.origin)
		for tick: int in range(31, 91):
			var original_events: Array[Dictionary] = []
			var restored_events: Array[Dictionary] = []
			original.advance([first], {42: original.origin}, tick, SimConfig.new(120), original_events)
			restored.advance([second], {42: restored.origin}, tick, SimConfig.new(120), restored_events)
			equal(first.health, second.health, "snapshot continuation preserves actual cooled Steam damage")
			equal(original_events, restored_events, "snapshot continuation preserves cooled pressure attribution/events")
			equal(original.state_hash(), restored.state_hash(), "snapshot continuation preserves complete cooled authority state")
		var original_unused := _deposit(original, 5, _wire(catalog, "water", "bolt"), 91_005, Vector2i.ZERO, 91)
		var restored_unused := _deposit(restored, 5, _wire(catalog, "water", "bolt"), 91_005, Vector2i.ZERO, 91)
		equal(int(original.casts[original_unused].ground), 600, "original spent coolant channel rejects a fresh second modifier")
		equal(int(restored.casts[restored_unused].ground), 600, "restored spent coolant channel rejects a fresh second modifier")
		equal(original.state_hash(), restored.state_hash(), "post-restore cooldown refusal retains exact paid source state")


func _test_zero_intensity_steam_danger(catalog: AbilityCatalog) -> void:
	var fixture := _cooling_fixture(catalog, "rapid", true, false, 1)
	var court: HexCourt = fixture.court
	var product: Dictionary = fixture.product
	var before: Array[Dictionary] = court.render_regions(Vector2i.ZERO, "steam", 30)
	check(before.size() == 1 and bool(before[0].danger), "positive-intensity active Steam retains its danger cue")
	_deposit(court, 4, _wire(catalog, "water", "rapid"), 91_004, Vector2i.ZERO, 29)
	equal(int(product.intensity), 0, "finite tiny-stock cooling may conservatively reach zero intensity")
	var after: Array[Dictionary] = court.render_regions(Vector2i.ZERO, "steam", 30)
	check(after.size() == 1 and not bool(after[0].danger), "zero-intensity Steam retains its whole-cell material without claiming harmful pressure")
	equal(String(after[0].phase), "active", "zero intensity does not fake an early decay or expiry")
	equal(_actual_steam_pulse(court, court.origin, 239), 0, "zero-intensity Steam cannot harm even at capped exposure")
	var snapshot := SteamSnapshot.capture(court)
	var restored := _court()
	var single_cell: Array[Vector2i] = [Vector2i.ZERO]
	check(restored.configure_geometry(restored.origin, single_cell), "zero-intensity restore uses the matching trusted one-cell topology")
	check(SteamSnapshot.restore(snapshot, restored), "zero-intensity cooling restores through the unchanged schema")
	equal(restored.state_hash(), court.state_hash(), "zero-intensity stock, exposure and provenance round-trip exactly")
	var restored_regions: Array[Dictionary] = restored.render_regions(Vector2i.ZERO, "steam", 30)
	check(restored_regions.size() == 1 and not bool(restored_regions[0].danger), "restored zero-intensity Steam retains its truthful harmless material cue")
	_deposit(court, 3, _wire(catalog, "fire", "bolt"), 91_003, Vector2i.ZERO, 31)
	var reheated: Array[Dictionary] = court.render_regions(Vector2i.ZERO, "steam", 60)
	check(reheated.size() == 1 and bool(reheated[0].danger), "independent finite heating restores danger when Steam pressure becomes positive")
	check(court.conservation_valid(), "zero-intensity material and independent reheat preserve all finite stock")


func _test_cooling_rounded_pressure_bound() -> void:
	# Direct scalar contract edge supplements the paid source journeys: the
	# naive density ratio gives400, for damage floor(15*400/1000)=6, above the
	# old floor(7*850/1000)=5 at exposure40. The pressure bound must avoid it.
	var old_cells := {Vector2i.ZERO: 1}
	var new_cells := {Vector2i.ZERO: 2}
	var compensated := HexChemistryWorld._cooled_steam_intensity(800, old_cells, new_cells)
	check(compensated < 400, "cooling compensates exact pressure floors, not only the material-density ratio")
	for exposure: int in range(1, 241):
		check(_expected_damage({"intensity": compensated}, 2, exposure) <= _expected_damage({"intensity": 850}, 1, exposure), "rounded low-density cooling cannot add a damage unit at any exposure")

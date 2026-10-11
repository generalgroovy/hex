extends FluxTestSuite


const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CastParts = preload("res://src/sim/hex/hex_cast_parts.gd")


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "hex chemistry loads the production ability catalog: %s" % catalog.last_error)
	if not catalog.last_error.is_empty():
		return finish("hex-chemistry")
	_test_practice_loadout_and_real_paid_deliveries(catalog)
	_test_provenance_reaction_and_conservation(catalog)
	_test_exact_partial_match_fixture(catalog)
	_test_product_modifiers(catalog)
	_test_modifier_order_preserves_cooling(catalog)
	_test_zero_height_and_vertical_transition_rules(catalog)
	_test_real_blocked_and_negated_paid_releases(catalog)
	_test_conservation_rejects_reverse_layer_corruption(catalog)
	_test_capacity_and_failed_payment_cleanup(catalog)
	_test_cancellation_and_consumed_ledger_lifecycle(catalog)
	_test_finite_ground_and_product_expiry(catalog)
	_test_pressure_height_paths_and_invulnerability(catalog)
	_test_hash_and_legacy_isolation(catalog)
	_test_continuous_boundary_exposure(catalog)
	return finish("hex-chemistry")


func _test_continuous_boundary_exposure(catalog: AbilityCatalog) -> void:
	var court := _court()
	var wire := _wire(catalog, "fire", "rapid")
	var id := _reserve_paid_bound(court, 1, wire, 99001)
	var terminal := _terminal(wire, 1, 99001, Vector2i.ZERO)
	terminal.position = court.origin + Vector2i(31_000, 0)
	court.deposit_terminal(terminal, 0)
	check(court.casts[id].cells.has(Vector2i(1, 0)), "off-center radius reaches the adjacent hex")
	var actor := PlayerState.new(40)
	actor.position_x = court.origin.x + 50_000
	actor.position_y = court.origin.y
	var before := actor.health
	court.advance([actor], {40: Vector2i(actor.position_x, actor.position_y)}, 30, SimConfig.new(120), [])
	check(actor.health < before, "selected whole hex authorizes damage beyond selection radius")
	actor.position_x = court.origin.x + 40_000
	court.advance([actor], {40: Vector2i(actor.position_x, actor.position_y)}, 60, SimConfig.new(120), [])
	check(actor.health < before, "same boundary hex damages inside the continuous disk")
	var disjoint := _court()
	for element: String in ["water", "fire"]:
		var owner := 1 if element == "water" else 2
		var cast_wire := _wire(catalog, element, "rapid")
		_reserve_paid_bound(disjoint, owner, cast_wire, 99100 + owner)
		var event := _terminal(cast_wire, owner, 99100 + owner, Vector2i.ZERO)
		event.position = disjoint.origin + Vector2i(-15_000 if owner == 1 else 15_000, 0)
		disjoint.deposit_terminal(event, 0)
	equal(disjoint.products.size(), 1, "disjoint selection disks sharing a whole hex react once")
	check(disjoint.conservation_valid(), "boundary-only storage conserves both independent budgets")
	for point: Vector2i in [Vector2i(31_000, 0), Vector2i(0, 35_950)]:
		var clipped := _court()
		var cast_id := _reserve_paid_bound(clipped, 1, wire, 99200)
		var event := _terminal(wire, 1, 99200, Vector2i.ZERO)
		event.position = clipped.origin + point
		clipped.deposit_terminal(event, 0)
		var visible := 0
		var before_draw := clipped.state_hash()
		for cell: Vector2i in clipped.casts[cast_id].cells:
			for region: Dictionary in clipped.render_regions(cell, "fire", 30.0):
				equal(region.polygon, clipped.whole_cell_polygon(cell), "rendering covers precisely the authoritative whole hex")
				visible += int(region.polygon.size() >= 3)
		check(visible >= 2, "edge/vertex court record produces multiple complete visible hex regions")
		equal(clipped.state_hash(), before_draw, "render-region cache cannot mutate authority")


func _test_practice_loadout_and_real_paid_deliveries(catalog: AbilityCatalog) -> void:
	var expected := [
		_wire(catalog, "water", "bolt"), _wire(catalog, "fire", "bolt"),
		_wire(catalog, "water", "heavy"), _wire(catalog, "fire", "heavy"),
		_wire(catalog, "water", "rapid"), _wire(catalog, "fire", "rapid"),
		_wire(catalog, "water", "spray"), _wire(catalog, "fire", "spray"),
		_wire(catalog, "earth", "bolt"), _wire(catalog, "wind", "bolt"),
		_wire(catalog, "light", "bolt"), _wire(catalog, "dark", "bolt"),
	]
	for slot_index: int in range(expected.size()):
		var fixture := _practice(catalog)
		var world: SimWorld = fixture.world
		var court: HexCourt = fixture.court
		var actor: PlayerState = world.player()
		equal(actor.spell_wire_id(slot_index + 1), expected[slot_index], "practice slot %d keeps all four Water/Fire families followed by the other four live elements" % (slot_index + 1))
		var definition := CombatTuning.cast_definition(expected[slot_index])
		check(int(definition.get("flux_cost", 0)) > 0, "practice delivery %d retains a positive production Flux cost" % slot_index)
		check(int(definition.get("startup_ms", 0)) > 0 and int(definition.get("cooldown_ms", 0)) > 0, "practice delivery %d retains positive production timing" % slot_index)
		var flux_before := actor.flux
		var pressed := int(SimCommand.SPELL_PRESSED_BITS[slot_index])
		var target := Vector2i(640_000, 480_000)
		check(world.step([SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, pressed, 0, -1000, target.x, target.y)]), "practice delivery %d enters the real SimWorld cast path" % slot_index)
		equal(actor.flux, flux_before - int(definition.flux_cost), "practice delivery %d pays its exact production Flux cost" % slot_index)
		var cast_id := _single_cast_id(court)
		check(cast_id > 0 and bool(court.casts[cast_id].paid), "practice delivery %d owns one paid chemistry ledger" % slot_index)
		equal(int(court.metrics.matter_paid), HexCourt.MATTER_PER_CAST, "practice delivery %d mints one finite matter budget only after payment" % slot_index)
		var deposited := false
		for _tick_index: int in range(420):
			check(world.step([SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, 0, 0, -1000)]), "practice delivery %d advances through release and terminal" % slot_index)
			if court.casts.has(cast_id) and int(court.casts[cast_id].ground) == HexCourt.MATTER_PER_CAST:
				deposited = true
				break
		check(deposited, "practice delivery %d resolves its paid terminal into one finite ground budget" % slot_index)
		check(court.conservation_valid(), "practice delivery %d conserves paid matter after terminal" % slot_index)
		equal(world.deposits.size() + world.reactions.size() + world.fields.size(), 0, "practice delivery %d never activates legacy chemistry arrays" % slot_index)


func _test_provenance_reaction_and_conservation(catalog: AbilityCatalog) -> void:
	var water_bolt := _wire(catalog, "water", "bolt")
	var fire_bolt := _wire(catalog, "fire", "bolt")
	var water_rapid := _wire(catalog, "water", "rapid")
	var point := Vector2i.ZERO

	var duplicate := _court()
	var duplicate_id := _deposit(duplicate, 1, water_bolt, 1001, point, 5)
	var duplicate_event := _terminal(water_bolt, 1, 1001, point)
	duplicate.deposit_terminal(duplicate_event, 6)
	equal(int(duplicate.casts[duplicate_id].ground), HexCourt.MATTER_PER_CAST, "a duplicate terminal for one source cannot mint a second ingredient")
	equal(duplicate.products.size(), 0, "one source cannot self-react through duplicate terminal delivery")
	var duplicate_ledger: Dictionary = duplicate.ledger_for_source(1001)
	equal(int(duplicate_ledger.source_id), 1001, "bound ledger keeps immutable runtime source provenance")
	equal(int(duplicate_ledger.initial_strength), 5, "bound ledger keeps immutable catalog strength")
	equal(int(duplicate_ledger.budget), HexCourt.MATTER_PER_CAST, "bound ledger keeps its one paid finite budget")
	check(duplicate.conservation_valid(), "duplicate source suppression preserves conservation")

	var unequal := _court()
	var weak_id := _deposit(unequal, 1, water_rapid, 1101, point, 10)
	var strong_id := _deposit(unequal, 2, fire_bolt, 1102, point, 10)
	equal(unequal.products.size(), 1, "opposite elements with unequal catalog strength make one subtractive contact product")
	var first_unequal: Dictionary = unequal.products[_single_product_id(unequal)]
	equal(int(first_unequal.recipe_wire_id), HexCourt.STEAM_WIRE, "unequal Water and Fire retain Steam310 identity")
	equal(int(first_unequal.quantity), 720, "strength 1 versus 5 transfers finite portions 600 plus 120")
	equal(int(first_unequal.intensity), 100, "medium intensity follows matched strength rather than a full-strength fallback")
	equal(int(unequal.casts[weak_id].ledger.remaining_strength), 0, "weaker unequal source exhausts at its first contact")
	equal(int(unequal.casts[strong_id].ledger.remaining_strength), 4, "stronger unequal source retains unmatched strength")
	_reserve_paid_bound(unequal, 3, water_rapid, 1103)
	var second_unequal: Dictionary = unequal.resolve_contact(1102, 1103, unequal.origin, 11)
	check(bool(second_unequal.accepted), "a later flight contact can spend the retained stronger source")
	equal(unequal.products.size(), 2, "remaining strength can produce a later separately accounted medium")
	equal(int(unequal.casts[strong_id].ledger.remaining_strength), 3, "successive contact subtracts one more strength from the retained source")
	check(unequal.conservation_valid(), "successive unequal products conserve all paid source ledgers")

	var same_element := _court()
	_deposit(same_element, 1, water_bolt, 1201, point, 10)
	_deposit(same_element, 2, water_bolt, 1202, point, 10)
	equal(same_element.products.size(), 1, "two equal-strength Water casts create one explicit mirror product")
	var flood: Dictionary = same_element.products[_single_product_id(same_element)]
	equal(int(flood.recipe_wire_id), HexCourt.FROSTWAY_WIRE, "Water mirror keeps Frostway316 recipe identity")
	equal(String(flood.material), "flood", "Water mirror uses its own product layer instead of fake Steam")
	equal(int(flood.quantity), HexCourt.MATTER_PER_CAST * 2, "full mirror match transfers both finite budgets")
	equal(flood.source_funding, PackedInt64Array([1201, water_bolt, 5, 1202, water_bolt, 5]), "actual paid Water pair retains each five-strength contribution")
	equal(int(flood.funded_strength), 10, "Frostway funding is the exact sum of its two paid Bolts")
	equal(int(flood.damage_budget_remaining), 40_000, "Frostway begins with the linear paid damage ceiling")
	equal(int(flood.active_tick), 88, "Water mirror uses its 78-tick freezing formation after tick10")
	equal(int(flood.decay_tick), 508, "Water mirror then supplies exactly420 active ticks")
	equal(int(flood.expiry_tick), 580, "Water mirror finishes with its72-tick decay")
	var frozen_target := PlayerState.new(77)
	frozen_target.team_id = 2
	frozen_target.position_x = same_element.origin.x
	frozen_target.position_y = same_element.origin.y
	var frozen_health := frozen_target.health
	same_element.apply_product_effects([frozen_target], 88, SimConfig.new(120), CollisionWorld.new(), [])
	same_element.apply_product_effects([frozen_target], 89, SimConfig.new(120), CollisionWorld.new(), [])
	equal(frozen_health - frozen_target.health, 2000, "a real five-strength paid Frostway applies one half-scale first-entry hit")
	equal(int(flood.damage_budget_remaining), 38_000, "only actual realized Frostway Health loss spends its shared pool")
	check(same_element.conservation_valid(), "same-element mirror reaction conserves both paid budgets")
	var fire_mirror := _court()
	_deposit(fire_mirror, 1, fire_bolt, 1251, point, 10)
	_deposit(fire_mirror, 2, fire_bolt, 1252, point, 10)
	var conflagration: Dictionary = fire_mirror.products[_single_product_id(fire_mirror)]
	equal(int(conflagration.recipe_wire_id), HexCourt.CONFLAGRATION_WIRE, "Fire mirror keeps Conflagration309 recipe identity")
	equal(String(conflagration.material), "conflagration", "Fire mirror owns its separate product layer")
	equal(int(conflagration.intensity), 500, "Fire mirror intensity follows the matched strength-five contact")
	check(fire_mirror.conservation_valid(), "Conflagration mirror remains source-ledger conserved")

	var reacted := _court()
	var water_id := _deposit(reacted, 1, water_bolt, 1301, point, 20)
	var fire_id := _deposit(reacted, 2, fire_bolt, 1302, point, 20)
	equal(reacted.products.size(), 1, "one equal-strength opposite contact emits exactly one product")
	var product: Dictionary = reacted.products[_single_product_id(reacted)]
	equal(product.source_ids, [1301, 1302], "product parents are stable runtime source ids in canonical order")
	equal(String(product.material), "steam", "opposite Water and Fire keep Steam310 product identity")
	equal(int(product.footprint.radius), HexCourt.MEDIUM_RADIUS, "contact product uses the explicit compact medium radius")
	equal(int(product.quantity), HexCourt.MATTER_PER_CAST * 2, "fully shared footprints transfer both finite budgets into product quantity")
	check(bool(reacted.casts[water_id].reacted) and bool(reacted.casts[fire_id].reacted), "both parent casts permanently spend their one chemistry payload")
	check(reacted.conservation_valid(), "opposite reaction conserves both paid budgets")
	var retained_parents: Array = product.source_ids.duplicate()
	reacted.sync_flights([], [])
	equal(reacted.casts.size(), 0, "fully consumed parent ledgers retire when no flight remains")
	equal(product.source_ids, retained_parents, "product keeps immutable parent ids after consumed ledgers retire")
	check(reacted.conservation_valid(), "retiring consumed ledgers preserves paid matter accounting")


# Deliberate valid-ledger fixture. It proves that an unequal ground contact uses
# source strength accounting, then proportionally retiles the stronger deposit;
# cell overlap is only a spatial broadphase and cannot define paid quantity.
func _test_exact_partial_match_fixture(catalog: AbilityCatalog) -> void:
	var court := _court()
	var water_id := _reserve_paid_bound(court, 1, _wire(catalog, "water", "heavy"), 2001)
	var fire_id := _reserve_paid_bound(court, 2, _wire(catalog, "fire", "bolt"), 2002)
	var water: Dictionary = court.casts[water_id]
	var fire: Dictionary = court.casts[fire_id]
	_install_ground_fixture(court, water, {Vector2i.ZERO: 500, Vector2i(-1, 0): 100}, 30)
	_install_ground_fixture(court, fire, {Vector2i.ZERO: 200, Vector2i(1, 0): 400}, 30)
	court._try_reaction(fire, 30)
	equal(court.products.size(), 1, "unequal deposited sources with overlapping footprints create one product")
	var product: Dictionary = court.products[_single_product_id(court)]
	equal(int(product.recipe_wire_id), HexCourt.STEAM_WIRE, "unequal deposited Water and Fire still create Steam310")
	equal(int(product.quantity), 800, "strength 15 versus 5 transfers cumulative quantities 200 plus 600")
	equal(int(water.ground), 400, "water unmatched ground persists after its one reaction")
	equal(int(fire.ground), 0, "weaker Fire source exhausts regardless of its per-cell allocation shape")
	equal(water.cells, {Vector2i(-1, 0): 66, Vector2i.ZERO: 334}, "stronger Water ground is retiled proportionally in canonical cell order")
	check(fire.cells.is_empty(), "exhausted ground source clears every cell allocation")
	check(not bool(water.reacted) and bool(fire.reacted), "only the exhausted source receives the terminal reacted marker")
	check(court.conservation_valid(), "partial-strength ground contact conserves product and unmatched ground")


func _test_product_modifiers(catalog: AbilityCatalog) -> void:
	var water_bolt := _wire(catalog, "water", "bolt")
	var fire_bolt := _wire(catalog, "fire", "bolt")
	var heated := _court()
	_deposit(heated, 1, water_bolt, 3001, Vector2i.ZERO, 40)
	_deposit(heated, 2, fire_bolt, 3002, Vector2i.ZERO, 40)
	var product_id := _single_product_id(heated)
	var product: Dictionary = heated.products[product_id]
	var original_expiry := int(product.expires)
	equal(product.source_ids, [3001, 3002], "fresh product begins with its two immutable runtime source ids")
	equal(int(product.intensity), 500, "strength-five parent match creates medium intensity 500")

	var heater := _deposit(heated, 3, fire_bolt, 3003, Vector2i.ZERO, 140)
	equal(heated.products.size(), 1, "compatible Fire modifies the existing product without creating another")
	equal(int(product.intensity), 750, "strength-five Fire adds exactly 250 bounded intensity")
	equal(int(product.expires), 140 + (original_expiry - 140) / 2, "Fire halves only the product's remaining lifetime")
	check(bool(product.heated) and bool(heated.casts[heater].reacted), "Fire and its product record the one-time modifier spend")
	equal(int(heated.casts[heater].consumed), HexCourt.MATTER_PER_CAST, "Fire modifier consumes its fresh finite budget")
	check(3003 in product.source_ids and 3001 in product.source_ids and 3002 in product.source_ids, "modifier provenance retains original and incoming runtime source ids")
	var heated_expiry := int(product.expires)
	var heated_quantity := int(product.quantity)
	var second_heater := _deposit(heated, 4, fire_bolt, 3004, Vector2i.ZERO, 150)
	equal(int(product.intensity), 750, "a second Fire cannot heat the same product twice")
	equal(int(product.expires), heated_expiry, "a refused second heat cannot shorten lifetime again")
	equal(int(product.quantity), heated_quantity, "a refused second heat adds no product matter")
	equal(int(heated.casts[second_heater].ground), HexCourt.MATTER_PER_CAST, "unused second Fire remains ordinary accountable ground")
	check(heated.conservation_valid(), "heated product and unused second Fire remain globally conserved")

	var cooled := _court()
	_deposit(cooled, 5, water_bolt, 3101, Vector2i.ZERO, 40)
	_deposit(cooled, 6, fire_bolt, 3102, Vector2i.ZERO, 40)
	var cooled_product: Dictionary = cooled.products[_single_product_id(cooled)]
	var cool_expiry := int(cooled_product.expires)
	var cool_quantity := int(cooled_product.quantity)
	var cool_cells: int = cooled_product.cells.size()
	var cooler := _deposit(cooled, 7, water_bolt, 3103, Vector2i.ZERO, 160)
	equal(cooled.products.size(), 1, "compatible Water modifies the existing product without creating another")
	equal(cool_cells, 19, "literal cooling regression uses the current centered nineteen-hex footprint")
	equal(int(cooled_product.intensity), 165, "strength-five Water reduces thermal intensity to250 then compensates exact density/cap rounding to165")
	equal(int(cooled_product.expires), cool_expiry, "Water spread never extends product expiry")
	equal(int(cooled_product.quantity), cool_quantity + HexCourt.MATTER_PER_CAST, "Water spread adds exactly its one fresh finite budget")
	equal(cooled_product.cells.size(), cool_cells, "Water cooling retains the selected hex set without forced neighboring-cell expansion")
	equal(_sum_values(cooled_product.cells), int(cooled_product.quantity), "Water retile preserves the entire product quantity")
	check(bool(cooled_product.cooled) and bool(cooled.casts[cooler].reacted) and 3103 in cooled_product.source_ids, "Water and product record one-time runtime-source provenance")
	check(3101 in cooled_product.source_ids and 3102 in cooled_product.source_ids, "Water modifier retains both original runtime parent sources")
	var cooled_cells: Dictionary = cooled_product.cells.duplicate(true)
	var second_cooler := _deposit(cooled, 8, water_bolt, 3104, Vector2i.ZERO, 170)
	equal(cooled_product.cells, cooled_cells, "a second Water cannot spread the same product twice")
	equal(int(cooled.casts[second_cooler].ground), HexCourt.MATTER_PER_CAST, "unused second Water remains ordinary accountable ground")
	check(cooled.conservation_valid(), "cooled product and unused second Water remain globally conserved")


func _test_capacity_and_failed_payment_cleanup(catalog: AbilityCatalog) -> void:
	var fixture := _practice(catalog)
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var actor: PlayerState = world.player()
	var water_bolt := _wire(catalog, "water", "bolt")
	# Thirty-one mirror products plus one live source occupy all thirty-two
	# product reservations; the next paid cast must be refused before spending.
	for index: int in range(HexCourt.MAX_PRODUCTS * 2 - 1):
		_deposit(court, 100 + index, water_bolt, 4000 + index, Vector2i.ZERO, 0)
	equal(court.reserved_products(), HexCourt.MAX_PRODUCTS, "fixture occupies every retained product reservation without eviction")
	var flux_before := actor.flux
	check(world.step([SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, SimCommand.PRESSED_SPELL_1, 1000, 0)]), "capacity-refused real cast leaves the world tick valid")
	equal(actor.flux, flux_before, "hex capacity refusal happens before Flux payment")
	check(not court.pending.has(actor.entity_id), "capacity refusal creates no pending owner reservation")
	check(_has_refusal(world.combat_events, "hex_capacity"), "capacity refusal reports its bounded authority reason")

	var failed := _practice(catalog)
	var failed_world: SimWorld = failed.world
	var failed_court: HexCourt = failed.court
	var failed_actor: PlayerState = failed_world.player()
	failed_actor.flux = 0
	failed_actor.flux_recovery_per_second = 0 # Isolate spend from ordinary per-tick regeneration.
	check(failed_world.step([SimCommand.new(failed_world.tick, failed_actor.entity_id, 0, 0, 0, SimCommand.PRESSED_SPELL_1, 1000, 0)]), "unaffordable real cast leaves the world tick valid")
	equal(failed_actor.flux, 0, "failed payment cannot change Flux")
	check(not failed_court.pending.has(failed_actor.entity_id), "failed payment cancels its provisional owner reservation")
	equal(failed_court.casts.size(), 0, "failed payment leaves no chemistry cast ledger")
	equal(int(failed_court.metrics.matter_paid), 0, "failed payment mints no paid matter")
	check(_has_refusal(failed_world.combat_events, "flux"), "failed payment retains the combat Flux refusal")


func _test_cancellation_and_consumed_ledger_lifecycle(catalog: AbilityCatalog) -> void:
	var wire := _wire(catalog, "water", "bolt")
	var startup := _court()
	startup.current_tick = 10
	check(startup.reserve_cast(1, wire), "startup lifecycle reserves before payment")
	var startup_id := int(startup.pending[1])
	startup.commit_payment(1)
	var actor := PlayerState.new(1)
	actor.pending_cast_wire_id = wire
	actor.pending_cast_ticks = 5
	startup.sync_flights([actor], [])
	check(startup.casts.has(startup_id) and startup.pending.has(actor.entity_id), "living matching startup retains its paid pending ledger")
	actor.health = 0
	startup.sync_flights([actor], [])
	equal(startup.casts.size(), 0, "death retires a paid startup that can no longer release")
	equal(startup.pending.size(), 0, "death clears pending chemistry ownership")
	equal(int(startup.metrics.matter_expired), HexCourt.MATTER_PER_CAST, "dead startup expires its finite paid budget without refund")
	check(startup.conservation_valid(), "dead-startup cancellation remains conserved")

	var negated := _court()
	_reserve_paid_bound(negated, 2, wire, 4501)
	negated.sync_flights([], [])
	equal(negated.casts.size(), 0, "released source with no surviving projectile or terminal retires as negated")
	equal(negated.sources.size(), 0, "negation clears stale release-source lookup")
	equal(int(negated.metrics.matter_expired), HexCourt.MATTER_PER_CAST, "negated release expires its budget exactly once")
	check(negated.conservation_valid(), "negated release remains conserved")


func _test_finite_ground_and_product_expiry(catalog: AbilityCatalog) -> void:
	var water := _court()
	var water_id := _deposit(water, 1, _wire(catalog, "water", "bolt"), 4601, Vector2i.ZERO, 0)
	var expired_record: Dictionary = water.casts[water_id]
	water.advance([], {}, HexCourt.WATER_TICKS, SimConfig.new(120), [])
	equal(int(expired_record.ground), 0, "Water ground retires at its finite expiry tick")
	equal(int(expired_record.expired), HexCourt.MATTER_PER_CAST, "expired Water enters the finite expiry sink before the record retires")
	check(water.casts.has(water_id) and water.reserved_products() == 0, "expired Water releases cast capacity while retaining its empty source record until flight synchronization")
	equal(_sum_values(water.cells[Vector2i.ZERO].get("water",{})), 0, "Water expiry clears cell-layer references")
	water.sync_flights([], [])
	check(not water.casts.has(water_id) and water.casts.is_empty(), "empty expired ground ledger retires and releases cast capacity after flight synchronization")
	check(water.conservation_valid(), "finite ground expiry remains conserved")

	var steam := _court()
	_deposit(steam, 1, _wire(catalog, "water", "bolt"), 4701, Vector2i.ZERO, 0)
	_deposit(steam, 2, _wire(catalog, "fire", "bolt"), 4702, Vector2i.ZERO, 0)
	equal(steam.products.size(), 1, "expiry fixture begins with one Steam product")
	var expiry_tick: int = int(steam.products[_single_product_id(steam)].expiry_tick)
	equal(expiry_tick, HexCourt.MEDIUM_FORMATION_TICKS + HexCourt.MEDIUM_ACTIVE_TICKS + HexCourt.MEDIUM_DECAY_TICKS, "medium publishes exact 24/360/60 lifetime phases")
	steam.advance([], {}, expiry_tick, SimConfig.new(120), [])
	equal(steam.products.size(), 0, "Steam product retires at its explicit medium expiry tick")
	for cell: Vector2i in steam.cells:
		equal((steam.cells[cell].get("steam",{}) as Dictionary).size(), 0, "Steam expiry clears every referenced cell layer")
	steam.sync_flights([], [])
	check(steam.conservation_valid(), "finite product expiry preserves parent matter accounting")


func _test_pressure_height_paths_and_invulnerability(catalog: AbilityCatalog) -> void:
	var fire := _court()
	var fire_id := _deposit(fire, 1, _wire(catalog, "fire", "bolt"), 5001, Vector2i.ZERO, 0)
	var fire_record: Dictionary = fire.casts[fire_id]
	var fire_cell := Vector2i.ZERO
	var fire_point := fire.origin + HexGrid.center(fire_cell)
	var grounded := PlayerState.new(20)
	grounded.position_x = fire_point.x
	grounded.position_y = fire_point.y
	var grounded_health := grounded.health
	fire.advance([grounded], {grounded.entity_id: fire_point}, 30, SimConfig.new(120), [])
	var expected_fire := _fire_pressure_damage(fire_record)
	equal(grounded_health - grounded.health, expected_fire, "active Fire applies density-scaled ground pressure on its 30-tick pulse")

	var airborne := PlayerState.new(21)
	airborne.position_x = fire_point.x
	airborne.position_y = fire_point.y
	airborne.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT
	var airborne_health := airborne.health
	fire.advance([airborne], {airborne.entity_id: fire_point}, 30, SimConfig.new(120), [])
	equal(airborne.health, airborne_health, "authored clearance height avoids ground Fire pressure")

	var crossing := PlayerState.new(22)
	var path_start := fire.origin + HexGrid.center(Vector2i(-2, 0))
	var path_end := fire.origin + HexGrid.center(Vector2i(2, 0))
	crossing.position_x = path_end.x
	crossing.position_y = path_end.y
	var crossing_health := crossing.health
	fire.advance([crossing], {crossing.entity_id: path_start}, 60, SimConfig.new(120), [])
	check(crossing.health < crossing_health, "grounded swept path cannot tunnel through active Fire")

	var steam := _court()
	_deposit(steam, 1, _wire(catalog, "water", "bolt"), 5101, Vector2i.ZERO, 0)
	_deposit(steam, 2, _wire(catalog, "fire", "bolt"), 5102, Vector2i.ZERO, 0)
	var product: Dictionary = steam.products[_single_product_id(steam)]
	var steam_cell := Vector2i.ZERO
	var steam_point := steam.origin + HexGrid.center(steam_cell)
	# Direct overlapping-product view fixture: the duplicate is weaker than the
	# live product, proving one actor pulse takes the maximum rather than summing.
	var duplicate_id := 99
	var duplicate: Dictionary = product.duplicate(true)
	duplicate.id = duplicate_id
	duplicate.source_ids = []
	duplicate.cells = {steam_cell: int(product.cells[steam_cell])}
	duplicate.quantity = int(product.cells[steam_cell])
	duplicate.intensity = 250
	steam.products[duplicate_id] = duplicate
	steam.cells[steam_cell].steam[duplicate_id] = int(product.cells[steam_cell])
	var exposed := PlayerState.new(30)
	exposed.position_x = steam_point.x
	exposed.position_y = steam_point.y
	exposed.air_height = HexCourt.STEAM_HEIGHT
	for tick: int in range(1, 31):
		steam.advance([exposed], {exposed.entity_id: steam_point}, tick, SimConfig.new(120), [])
	equal(int(steam.exposure[exposed.entity_id]), 7, "Steam exposure starts only at the medium active boundary through the inclusive height ceiling")
	var density := int(product.cells[steam_cell])
	var ramp := 2000 + 6000 * 7 / HexCourt.EXPOSURE_CAP
	var expected_steam := mini(12_000, mini(8000, ramp * density / 400) * int(product.intensity) / 1000)
	equal(exposed.health_maximum - exposed.health, expected_steam, "overlapping Steam products apply only the strongest local pulse")

	var too_high := PlayerState.new(31)
	too_high.position_x = steam_point.x
	too_high.position_y = steam_point.y
	too_high.air_height = HexCourt.STEAM_HEIGHT + 1
	steam.exposure[too_high.entity_id] = 10
	var high_health := too_high.health
	steam.advance([too_high], {too_high.entity_id: steam_point}, 30, SimConfig.new(120), [])
	equal(int(steam.exposure[too_high.entity_id]), 8, "Steam exposure decays above its finite air-height ceiling")
	equal(too_high.health, high_health, "Steam cannot damage above its air-height ceiling")

	var intangible := PlayerState.new(32)
	intangible.position_x = steam_point.x
	intangible.position_y = steam_point.y
	intangible.air_dodge_ticks = SimConfig.new(120).milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
	steam.exposure[intangible.entity_id] = 10
	var intangible_health := intangible.health
	steam.advance([intangible], {intangible.entity_id: steam_point}, 30, SimConfig.new(120), [])
	equal(int(steam.exposure[intangible.entity_id]), 8, "existing combat intangibility decays exposure instead of accumulating it")
	equal(intangible.health, intangible_health, "existing combat intangibility gates hex pressure damage")

	var exited := PlayerState.new(33)
	var quiet_point := steam.origin + HexGrid.center(Vector2i(5, 0))
	exited.position_x = quiet_point.x
	exited.position_y = quiet_point.y
	steam.exposure[exited.entity_id] = 10
	steam.advance([exited], {exited.entity_id: quiet_point}, 31, SimConfig.new(120), [])
	equal(int(steam.exposure[exited.entity_id]), 8, "leaving Steam decays exposure by exactly two per tick")


func _test_hash_and_legacy_isolation(catalog: AbilityCatalog) -> void:
	var fixture := _practice(catalog)
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	equal(world.deposits.size() + world.reactions.size() + world.fields.size(), 0, "configured hex court begins with every legacy chemistry array empty")
	check(SessionSnapshot.capture(world, {}).is_empty(), "hex court refuses the incomplete legacy network snapshot")
	var initial_hash := world.state_hash()
	court.set_cell_amount(Vector2i.ZERO,"water",777,9)
	check(world.state_hash() != initial_hash, "whole-world authority hash includes nested hex material layers")
	var layered_hash := world.state_hash()
	court.set_cell_amount(Vector2i.ZERO,"steam",888,11)
	check(world.state_hash() != layered_hash, "whole-world authority hash includes nested product layers independently")


func _practice(catalog: AbilityCatalog) -> Dictionary:
	var world := SimWorld.new(120, 71, CollisionWorld.new(1_280_000, 960_000))
	check(HexCourtPractice.configure(world, catalog, false), "hex practice configures a solo world")
	check(world.hex_court != null and world.hex_court.chemistry_enabled, "hex practice enables its sole chemistry authority")
	equal(Vector2i(world.collision.width, world.collision.height), Vector2i(1_280_000, 960_000), "hex practice uses the authored 1280 by 960 court bounds")
	equal(world.hex_court.origin, Vector2i(640_000, 480_000), "hex practice uses the authored court origin")
	return {"world": world, "court": world.hex_court}


func _court() -> HexCourt:
	var court := HexCourt.new()
	court.chemistry_enabled = true
	return court


func _wire(catalog: AbilityCatalog, element: String, family: String) -> int:
	var ability_id := catalog.spell_id_at(element, family)
	return int(catalog.ability(ability_id).get("wire_id", 0))


func _reserve_paid_bound(court: HexCourt, owner: int, wire: int, source: int, release_origin: Vector2i = HexCourt.ORIGIN) -> int:
	check(court.reserve_cast(owner, wire), "direct fixture reserves one bounded chemistry cast")
	var id := int(court.pending.get(owner, 0))
	check(id > 0, "direct reservation records its cast id")
	court.commit_payment(owner)
	check(bool(court.casts[id].paid), "direct fixture commits payment before release")
	court.bind_release(owner, source, release_origin)
	check(not court.pending.has(owner) and int(court.casts[id].source) == source, "release binding clears pending ownership and records source provenance")
	return id


func _deposit(court: HexCourt, owner: int, wire: int, source: int, cell: Vector2i, tick: int) -> int:
	var id := _reserve_paid_bound(court, owner, wire, source)
	court.deposit_terminal(_terminal(wire, owner, source, cell), tick)
	return id


func _terminal(wire: int, owner: int, source: int, cell: Vector2i) -> Dictionary:
	var definition := CombatTuning.cast_definition(wire)
	return {
		"type": "projectile_terminal",
		"source_cast_id": source,
		"source_wire_id": wire,
		"owner_id": owner,
		"team_id": owner,
		"element_wire_id": int(definition.get("element_wire_id", 0)),
		"position": HexCourt.ORIGIN + HexGrid.center(cell),
		"direction": Vector2i(1000, 0),
		"strength": 1000,
		"reaction_strength": int(definition.get("reaction_strength", 0)),
	}


func _install_ground_fixture(court: HexCourt, record: Dictionary, quantities: Dictionary, tick: int) -> void:
	check(_sum_values(quantities) == HexCourt.MATTER_PER_CAST, "direct ground fixture preserves the source's exact finite budget")
	check(StrengthBudget.validate(record.ledger), "direct ground fixture begins from a valid bound source ledger")
	record.footprint = HexFootprint.disk(court.origin, 128_000)
	var selected: Array[Vector2i] = []
	for cell: Vector2i in quantities:
		selected.append(cell)
	selected.sort_custom(HexGrid._cell_less)
	var part_id := court.next_ground_part_id
	var expiry := tick + HexCourt.ingredient_lifetime(int(record.element))
	equal(CastParts.deposit_flight(record, int(record.source), part_id, selected, record.footprint, tick, expiry), HexCourt.MATTER_PER_CAST, "direct ground fixture moves the explicit flight part without minting matter")
	court.next_ground_part_id += 1
	var part: Dictionary = record.ground_parts[part_id]
	part.cells = quantities.duplicate(true)
	part.coverage = {}
	for cell: Vector2i in selected:
		part.coverage[cell] = 1
	court._sync_cast_ledger(record)
	record.cells = quantities.duplicate(true)
	record.coverage = part.coverage.duplicate(true)
	record.created = tick
	record.expires = expiry
	court._rebuild_cast_layers(record)
	check(CastParts.validate(record), "custom allocation fixture retains current explicit part ownership")


func _single_cast_id(court: HexCourt) -> int:
	var ids: Array = court.casts.keys()
	ids.sort()
	return int(ids[0]) if ids.size() == 1 else 0


func _single_product_id(court: HexCourt) -> int:
	var ids: Array = court.products.keys()
	ids.sort()
	return int(ids[0]) if ids.size() == 1 else 0


func _sum_values(values: Dictionary) -> int:
	var total := 0
	for value: Variant in values.values():
		total += int(value)
	return total


func _fire_pressure_damage(record: Dictionary) -> int:
	var parts: Array = record.ground_parts.values()
	check(parts.size() == 1, "Fire pressure fixture has one explicit finite ground part")
	if parts.is_empty():
		return 0
	var part: Dictionary = parts[0]
	check(not part.coverage.is_empty(), "Fire pressure fixture retains whole-hex coverage")
	if part.coverage.is_empty():
		return 0
	var damage := maxi(1, 4000 * int(part.quantity) / (HexCourt.MATTER_PER_CAST * part.coverage.size()))
	check(damage > 0, "whole-hex Fire pressure remains positive across zero-allocation selected cells")
	return damage


func _greatest_cell(values: Dictionary) -> Vector2i:
	var result := Vector2i.ZERO
	var maximum := -1
	for cell: Vector2i in values:
		if int(values[cell]) > maximum:
			maximum = int(values[cell])
			result = cell
	return result


func _has_refusal(events: Array[Dictionary], reason: String) -> bool:
	for event: Dictionary in events:
		if String(event.get("type", "")) == "cast_refused" and String(event.get("reason", "")) == reason:
			return true
	return false


func _test_modifier_order_preserves_cooling(catalog: AbilityCatalog) -> void:
	var water_bolt := _wire(catalog, "water", "bolt")
	var fire_bolt := _wire(catalog, "fire", "bolt")

	var cool_then_heat := _court()
	_deposit(cool_then_heat, 1, water_bolt, 6001, Vector2i.ZERO, 0)
	_deposit(cool_then_heat, 2, fire_bolt, 6002, Vector2i.ZERO, 0)
	var first: Dictionary = cool_then_heat.products[_single_product_id(cool_then_heat)]
	_deposit(cool_then_heat, 3, water_bolt, 6003, Vector2i.ZERO, 30)
	equal(int(first.intensity), 165, "Water first compensates its reduced thermal intensity for the added finite density")
	var cooled_expiry := int(first.expires)
	_deposit(cool_then_heat, 4, fire_bolt, 6004, Vector2i.ZERO, 60)
	equal(int(first.intensity), 415, "Fire after Water adds the unchanged incoming strength-five potency of250 to cooled165")
	equal(int(first.expires), 60 + (cooled_expiry - 60) / 2, "Fire after Water halves only the remaining lifetime")
	check(bool(first.heated) and bool(first.cooled), "cool-then-heat consumes each modifier permission exactly once")
	equal(int(first.quantity), HexCourt.MATTER_PER_CAST * 4, "cool-then-heat accounts for both parents and both fresh modifiers")
	check(cool_then_heat.conservation_valid(), "cool-then-heat preserves finite matter accounting")

	var heat_then_cool := _court()
	_deposit(heat_then_cool, 1, water_bolt, 6101, Vector2i.ZERO, 0)
	_deposit(heat_then_cool, 2, fire_bolt, 6102, Vector2i.ZERO, 0)
	var second: Dictionary = heat_then_cool.products[_single_product_id(heat_then_cool)]
	_deposit(heat_then_cool, 3, fire_bolt, 6103, Vector2i.ZERO, 30)
	equal(int(second.intensity), 750, "Fire first adds the incoming strength-five potency of 250")
	var heated_expiry := int(second.expires)
	_deposit(heat_then_cool, 4, water_bolt, 6104, Vector2i.ZERO, 60)
	equal(int(second.intensity), 372, "Water after Fire reduces thermal intensity to500 then compensates exact density/cap rounding to372")
	equal(int(second.expires), heated_expiry, "Water after Fire cannot extend the shortened lifetime")
	check(bool(second.heated) and bool(second.cooled), "heat-then-cool consumes each modifier permission exactly once")
	equal(int(second.quantity), HexCourt.MATTER_PER_CAST * 4, "heat-then-cool accounts for both parents and both fresh modifiers")
	check(heat_then_cool.conservation_valid(), "heat-then-cool preserves finite matter accounting")


func _test_zero_height_and_vertical_transition_rules(catalog: AbilityCatalog) -> void:
	var fire := _court()
	var fire_id := _deposit(fire, 1, _wire(catalog, "fire", "bolt"), 6201, Vector2i.ZERO, 0)
	var fire_record: Dictionary = fire.casts[fire_id]
	var fire_cell := Vector2i.ZERO
	var fire_point := fire.origin + HexGrid.center(fire_cell)
	var expected_fire := _fire_pressure_damage(fire_record)

	var rising := PlayerState.new(40)
	rising.position_x = fire_point.x
	rising.position_y = fire_point.y
	rising.air_height = 0
	rising.air_vertical_velocity = MovementTuning.JUMP_VERTICAL_SPEED
	var rising_health := rising.health
	fire.advance([rising], {rising.entity_id: {"point": fire_point, "height": 0}}, 30, SimConfig.new(120), [])
	equal(rising_health - rising.health, expected_fire, "zero air height remains grounded for Fire despite positive vertical velocity")

	var wallskim := PlayerState.new(41)
	wallskim.position_x = fire_point.x
	wallskim.position_y = fire_point.y
	wallskim.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT + 1
	wallskim.wall_skim_ticks = 5
	var wallskim_health := wallskim.health
	fire.advance([wallskim], {wallskim.entity_id: {"point": fire_point, "height": 0}}, 30, SimConfig.new(120), [])
	equal(wallskim_health - wallskim.health, expected_fire, "wallrun remains exposed to Fire above ordinary ground clearance")

	var landing := PlayerState.new(42)
	var airborne_start := fire.origin + HexGrid.center(Vector2i(-3, 0))
	var quiet_landing := fire.origin + HexGrid.center(Vector2i(3, 0))
	landing.position_x = quiet_landing.x
	landing.position_y = quiet_landing.y
	landing.air_height = 0
	var landing_health := landing.health
	fire.advance([landing], {landing.entity_id: {"point": airborne_start, "height": MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT}}, 60, SimConfig.new(120), [])
	equal(landing.health, landing_health, "landing samples only its grounded endpoint and ignores the swept airborne Fire crossing")

	var steam := _court()
	_deposit(steam, 1, _wire(catalog, "water", "bolt"), 6301, Vector2i.ZERO, 0)
	_deposit(steam, 2, _wire(catalog, "fire", "bolt"), 6302, Vector2i.ZERO, 0)
	var descending := PlayerState.new(43)
	var above_start := steam.origin + HexGrid.center(Vector2i(-6, 0))
	var quiet_endpoint := steam.origin + HexGrid.center(Vector2i(6, 0))
	descending.position_x = quiet_endpoint.x
	descending.position_y = quiet_endpoint.y
	descending.air_height = HexCourt.STEAM_HEIGHT
	var descending_health := descending.health
	steam.advance([descending], {descending.entity_id: {"point": above_start, "height": HexCourt.STEAM_HEIGHT + 1}}, 30, SimConfig.new(120), [])
	equal(int(steam.exposure.get(descending.entity_id, 0)), 0, "descending through the Steam ceiling samples only the newly eligible endpoint")
	equal(descending.health, descending_health, "above-ceiling swept travel cannot inherit Steam pressure at a quiet endpoint")


func _test_real_blocked_and_negated_paid_releases(catalog: AbilityCatalog) -> void:
	var blocked_fixture := _practice(catalog)
	var blocked_world: SimWorld = blocked_fixture.world
	var blocked_court: HexCourt = blocked_fixture.court
	var blocked_actor: PlayerState = blocked_world.player()
	blocked_actor.flux_recovery_per_second = 0
	# Actor center is x=640000 with radius 18000. Water Bolt spawns at
	# x=672800; this wall blocks the projectile without overlapping the actor.
	blocked_world.collision.add_obstacle(CollisionWorld.Obstacle.new(9701, 670_000, 680_000, 690_000, 740_000))
	var water_bolt := _wire(catalog, "water", "bolt")
	var blocked_cost := int(CombatTuning.cast_definition(water_bolt).flux_cost)
	var blocked_flux := blocked_actor.flux
	check(blocked_world.step([SimCommand.new(blocked_world.tick, blocked_actor.entity_id, 0, 0, 0, SimCommand.PRESSED_SPELL_1, 1000, 0)]), "blocked release enters a real paid startup")
	for _tick_index: int in range(60):
		if blocked_actor.pending_cast_wire_id == 0:
			break
		check(blocked_world.step([SimCommand.new(blocked_world.tick, blocked_actor.entity_id, 0, 0, 0, 0, 1000, 0)]), "blocked release advances through its finite startup")
	equal(blocked_actor.pending_cast_wire_id, 0, "blocked release leaves startup within its authored bound")
	equal(blocked_flux - blocked_actor.flux, blocked_cost, "blocked release keeps its exact paid Flux cost")
	equal(int(blocked_court.metrics.matter_paid), HexCourt.MATTER_PER_CAST, "blocked release records one paid matter budget")
	equal(int(blocked_court.metrics.matter_expired), HexCourt.MATTER_PER_CAST, "blocked release expires the entire paid budget without refund")
	equal(blocked_court.casts.size() + blocked_court.pending.size() + blocked_court.sources.size(), 0, "blocked release retires every pending and source ledger")
	equal(_court_ground_quantity(blocked_court), 0, "blocked release creates no ground ingredient")
	check(blocked_court.conservation_valid(), "blocked paid release remains conserved")

	var negated_fixture := _practice(catalog)
	var negated_world: SimWorld = negated_fixture.world
	var negated_court: HexCourt = negated_fixture.court
	var negated_actor: PlayerState = negated_world.player()
	negated_actor.flux_recovery_per_second = 0
	var fire_bolt := _wire(catalog, "fire", "bolt")
	var fire_definition := CombatTuning.cast_definition(fire_bolt)
	var stronger := ProjectileState.new(
		9000, 2, 2, fire_bolt, int(fire_definition.element_wire_id),
		Vector2i(640_000, 600_000), Vector2i.ZERO,
		int(fire_definition.radius), int(fire_definition.damage), 120,
	)
	stronger.source_cast_id = 9000
	stronger.reaction_strength = int(fire_definition.reaction_strength)
	stronger.material_strength = 1000
	check(negated_court.reserve_cast(2, fire_bolt), "stationary opponent fixture reserves a real source")
	negated_court.commit_payment(2)
	negated_court.bind_release(2, 9000, Vector2i(640_000, 600_000), Vector2i(0, 1000))
	negated_world.projectiles.append(stronger)
	var water_spray := _wire(catalog, "water", "spray")
	var spray_cost := int(CombatTuning.cast_definition(water_spray).flux_cost)
	var spray_flux := negated_actor.flux
	var spray_source := negated_world.next_projectile_id
	check(negated_world.step([SimCommand.new(negated_world.tick, negated_actor.entity_id, 0, 0, 0, SimCommand.PRESSED_SPELL_7, 0, -1000)]), "negated Spray enters a real paid startup")
	for _tick_index: int in range(60):
		if negated_actor.pending_cast_wire_id == 0:
			break
		check(negated_world.step([SimCommand.new(negated_world.tick, negated_actor.entity_id, 0, 0, 0, 0, 0, -1000)]), "negated Spray advances toward phase-zero interception")
	equal(negated_actor.pending_cast_wire_id, 0, "negated Spray leaves startup within its authored bound")
	equal(spray_flux - negated_actor.flux, spray_cost, "negated Spray keeps its exact paid Flux cost")
	equal(int(negated_court.metrics.matter_paid), 2 * HexCourt.MATTER_PER_CAST, "Spray and opponent each own one paid matter budget")
	equal(int(negated_court.metrics.matter_consumed), 960, "3 versus 5 consumes all Spray plus three fifths of Bolt matter")
	equal(int(negated_court.metrics.matter_expired), 0, "reaction transfers paid material without refund or spurious expiry")
	equal(negated_court.casts.size() + negated_court.pending.size() + negated_court.sources.size(), 2, "only surviving Bolt source and ledger remain live")
	check(not negated_court.sources.has(spray_source), "fully negated Spray retires its paid source without a later ground ingredient")
	var surviving_bolt_ledger: Dictionary = negated_court.ledger_for_source(9000)
	equal(_court_ground_quantity(negated_court), int(surviving_bolt_ledger.deposited_quantity), "any later ground quantity belongs only to the surviving paid Bolt trail")
	equal(negated_court.products.size(), 1, "unequal phase-zero exhaustion creates exactly one Steam product")
	check(negated_world.projectiles.has(stronger), "stronger legally authored Bolt survives the Spray interception")
	equal(stronger.remaining_strength, 2, "surviving Bolt retains only unmatched strength")
	check(_has_interception_outcome(negated_world.combat_events, 2), "phase-zero event records the remaining source outcome")
	check(negated_court.conservation_valid(), "negated paid Spray remains conserved")


func _test_conservation_rejects_reverse_layer_corruption(catalog: AbilityCatalog) -> void:
	for layer: String in ["water", "fire", "steam", "conflagration", "flood"]:
		var orphan := _court()
		orphan.set_cell_amount(Vector2i.ZERO,layer,999,1)
		check(not orphan.conservation_valid(), "conservation rejects an orphan %s cell-layer id" % layer)

	var duplicate := _court()
	var water_id := _deposit(duplicate, 1, _wire(catalog, "water", "bolt"), 6401, Vector2i.ZERO, 0)
	var water: Dictionary = duplicate.casts[water_id]
	var cell: Vector2i = water.cells.keys()[0]
	duplicate.set_cell_amount(cell,"fire",water_id,int(water.cells[cell]))
	check(not duplicate.conservation_valid(), "conservation rejects a cast duplicated into the wrong element layer")


func _court_ground_quantity(court: HexCourt) -> int:
	var total := 0
	for cell: Vector2i in court.cells:
		total += _sum_values(court.cells[cell].get("water",{}))
		total += _sum_values(court.cells[cell].get("fire",{}))
	return total


func _has_interception_outcome(events: Array[Dictionary], outcome: int) -> bool:
	for event: Dictionary in events:
		if String(event.get("type", "")) == "hex_clash" and int(event.get("second_remaining", -1)) == outcome:
			return true
	return false

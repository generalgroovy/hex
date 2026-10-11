extends FluxTestSuite

const CourtCandidate = preload("res://src/sim/hex/hex_court.gd")
const StrengthLedger = preload("res://src/sim/combat/strength_budget.gd")
const CastParts = preload("res://src/sim/hex/hex_cast_parts.gd")

class StationaryCourt:
	extends HexCourt
	var selections := 0
	func select_cells(shape: Dictionary, eligible: Variant = null) -> Array[Vector2i]:
		selections += 1
		return super.select_cells(shape, eligible)



func run() -> int:
	_test_successive_unequal_contacts()
	_test_explicit_mirror_products()
	_test_ground_contact_and_proportional_retile()
	_test_weakened_radial_terminal_radius()
	_test_finite_steam_modifier()
	_test_mirror_effect_profiles()
	_test_render_metadata_phases()
	_test_capacity_reservation()
	_test_edge_effects_and_expiry()
	_test_all_reaction_footprints_remain_stationary()
	return finish("hex-strength")


func _test_successive_unequal_contacts() -> void:
	var court = CourtCandidate.new()
	var water: Dictionary = _add_source(court, 1, 101, CourtCandidate.WATER, 15, false, Vector2i(1000, 0))
	var fire_five: Dictionary = _add_source(court, 2, 102, CourtCandidate.FIRE, 5, false)
	check(court.ledger_for_source(101) == water.ledger and int(water.ledger.source_id) == 101, "source lookup returns the actual immutable nested source ledger")
	check(court.ledger_for_source(999).is_empty(), "unknown source has no fabricated ledger")
	var first: Dictionary = court.resolve_contact(101, 102, court.origin, 10)
	check(first[&"accepted"] and first[&"matched_strength"] == 5, "unequal flight contact consumes the minimum strength once")
	check(water.ledger.remaining_strength == 10 and fire_five.ledger.remaining_strength == 0, "unequal contact keeps only unmatched source strength")
	check(first[&"quantity"] == 800, "15-vs-5 contact transfers cumulative 200 plus 600 quantity")
	var first_product: Dictionary = court.products[first[&"product_id"]]
	check(first[&"reaction_id"] == first[&"product_id"], "contact result exposes stable reaction and product aliases")
	check(first_product.recipe_wire_id == CourtCandidate.STEAM_WIRE and first_product.material == "steam", "Fire plus Water produces explicit Steam310")
	check(first_product.active_tick == 34 and first_product.decay_tick == 394 and first_product.expiry_tick == 454, "medium uses exact 24/360/60 phase boundaries")
	check(first_product.intensity == 500 and first_product.quantity == 800, "medium intensity and quantity derive from this contact")

	_add_source(court, 3, 103, CourtCandidate.FIRE, 3, false)
	var second: Dictionary = court.resolve_contact(101, 103, court.origin + Vector2i(10_000, 0), 20)
	check(second[&"accepted"] and second[&"matched_strength"] == 3, "remaining strong source can resolve a later weaker contact")
	check(water.ledger.remaining_strength == 7 and water.ledger.consumed_quantity == 320, "15->10->7 source keeps cumulative proportional accounting")
	check(second[&"quantity"] == 720, "second medium contains only new 120 plus 600 portions")
	check(court.products.size() == 2 and court.conservation_valid(), "successive products remain finite and globally conserved")


func _test_explicit_mirror_products() -> void:
	var flood_court = CourtCandidate.new()
	_add_source(flood_court, 1, 201, CourtCandidate.WATER, 7, false, Vector2i(1000, 0), 2)
	_add_source(flood_court, 2, 202, CourtCandidate.WATER, 7, false, Vector2i(0, 1000), 3)
	var flood_result: Dictionary = flood_court.resolve_contact(202, 201, flood_court.origin, 5)
	var flood: Dictionary = flood_court.products[flood_result.product_id]
	check(flood.recipe_wire_id == CourtCandidate.FROSTWAY_WIRE and flood.material == "flood", "Water mirror creates Frostway316 without a Steam fallback")
	check(flood.quantity == 1200 and flood.intensity == 700, "Frostway retains both finite portions and matched-strength intensity")
	check(flood.flow_aim == Vector2i(1000, 0), "Frostway corridor follows the oldest source aim")
	check(flood.flow_units_per_second == 0 and flood.common_wall_clearance == 18_000, "Frostway slows travel without an inherited Flood push")
	check(flood.geometry_override == "whole_hex" and flood.footprint.kind == "capsule" and flood.footprint.radius == 22_500, "compact Frostway selects whole hexes from its 22.5-unit capsule")
	equal(flood.footprint.end - flood.footprint.start, Vector2i(150_000, 0), "Frostway uses the authored 150-unit corridor length")
	check(flood_court.cells[_first_cell(flood.cells)].flood.has(int(flood.id)), "Frostway preserves its stable wire316 material-layer identity")

	var fire_court = CourtCandidate.new()
	_add_source(fire_court, 1, 211, CourtCandidate.FIRE, 15, false)
	_add_source(fire_court, 2, 212, CourtCandidate.FIRE, 5, false)
	var flame_result: Dictionary = fire_court.resolve_contact(211, 212, fire_court.origin, 7)
	var flame: Dictionary = fire_court.products[flame_result.product_id]
	check(flame.recipe_wire_id == CourtCandidate.CONFLAGRATION_WIRE and flame.material == "conflagration", "Fire mirror creates Conflagration309 without a Steam fallback")
	check(flame.quantity == 800 and flame.intensity == 500, "Conflagration uses unequal finite source portions")
	check(flame.pulse_ms == 600 and flame.pulse_damage == 8000, "Conflagration publishes the authored 8x1000 per 600ms pulse")
	check(flame.geometry_override == "whole_hex" and flame.footprint.radius == 48_000, "compact Conflagration uses its impact-centered disk only to select authoritative whole hexes")
	check(fire_court.cells[_first_cell(flame.cells)].conflagration.has(int(flame.id)), "Conflagration owns a separate authoritative product layer")


func _test_ground_contact_and_proportional_retile() -> void:
	var court = CourtCandidate.new()
	var water: Dictionary = _add_source(court, 1, 301, CourtCandidate.WATER, 15, true)
	var fire: Dictionary = _add_source(court, 2, 302, CourtCandidate.FIRE, 5, true, Vector2i(0, -1000), 30)
	_set_ground_footprint(court, water, court.origin + Vector2i(-20_000, 0))
	_set_ground_footprint(court, fire, court.origin + Vector2i(20_000, 0))
	var old_water_cells: int = water.cells.size()
	var shared_before: Dictionary = {}
	for cell: Vector2i in water.cells:
		if fire.cells.has(cell): shared_before[cell] = 1
	var preferred: Vector2i = court.origin + Vector2i(50_000, 0) # Inside Fire, outside Water.
	court._try_ground_reactions(fire, preferred, 30)
	check(court.products.size() == 1, "an overlapping deposited pair resolves during ground deposit handling")
	if court.products.is_empty():
		return
	var product: Dictionary = court.products[court.products.keys()[0]]
	check(HexFootprint.contains_selected(shared_before, court.origin, product.footprint.center), "ground medium origin is an actual common selected-cell witness")
	check(product.footprint.center != preferred, "preferred impact outside the other source cannot become a false contact origin")
	check(water.ledger.deposited_quantity == 400 and water.ground == 400, "partial ground source retains only its ledger remainder")
	check(fire.ledger.deposited_quantity == 0 and fire.cells.is_empty(), "exhausted ground source removes every cell allocation")
	check(_sum(water.cells) == 400 and water.cells.size() <= old_water_cells, "remaining ground is retiled proportionally without adding cells")
	check(_layer_sum(court, water, "water") == 400, "cell layer mirrors the exact proportional ground remainder")
	check(court.conservation_valid(), "ground reaction and product remain globally conserved")


func _test_finite_steam_modifier() -> void:
	var court = CourtCandidate.new()
	_add_source(court, 1, 401, CourtCandidate.WATER, 5, false)
	_add_source(court, 2, 402, CourtCandidate.FIRE, 5, false)
	var formed: Dictionary = court.resolve_contact(401, 402, court.origin, 0)
	var steam: Dictionary = court.products[formed.product_id]
	var modifier: Dictionary = _add_source(court, 3, 403, CourtCandidate.FIRE, 5, false)
	var selected: Array[Vector2i] = HexFootprint.intersected_cells(modifier.footprint, court.origin, court.cells)
	check(court._try_modifier(modifier, selected, 30), "fresh Fire consumes against finite Steam interaction strength")
	check(modifier.ledger.remaining_strength == 0 and modifier.ledger.consumed_quantity == 600, "modifier spends only its finite source ledger")
	check(steam.quantity == 1800, "modifier retains existing product matter once and adds only its new 600 portion")
	check(steam.intensity == 750 and steam.heated, "strength-five Fire adds exactly 250 bounded heat after subtractive accounting")
	var second_heater: Dictionary = _add_source(court, 4, 404, CourtCandidate.FIRE, 3, false)
	selected = HexFootprint.intersected_cells(second_heater.footprint, court.origin, court.cells)
	check(not court._try_modifier(second_heater, selected, 31), "one-time heat refuses a second modifier without consuming it")
	check(second_heater.ledger.flight_quantity == 600 and second_heater.ledger.consumed_quantity == 0, "refused heat cannot mutate the new source ledger")
	var cooler: Dictionary = _add_source(court, 5, 405, CourtCandidate.WATER, 5, false)
	selected = HexFootprint.intersected_cells(cooler.footprint, court.origin, court.cells)
	check(court._try_modifier(cooler, selected, 32), "one Water channel remains available after the independent heat channel")
	check(steam.intensity == 372 and steam.cooled, "cool reduces thermal750 to500 then compensates nineteen-cell density and pressure rounding to372")
	check(steam.quantity == 2400 and cooler.ledger.remaining_strength == 0, "cooling adds only its consumed 600 source stock")
	check(court.conservation_valid(), "finite modifier accounting preserves paid-source conservation")

	var low_court = CourtCandidate.new()
	_add_source(low_court, 1, 411, CourtCandidate.WATER, 1, false)
	_add_source(low_court, 2, 412, CourtCandidate.FIRE, 1, false)
	var low_result: Dictionary = low_court.resolve_contact(411, 412, low_court.origin, 0)
	var low_steam: Dictionary = low_court.products[low_result.product_id]
	var low_cooler: Dictionary = _add_source(low_court, 3, 413, CourtCandidate.WATER, 1, false)
	selected = HexFootprint.intersected_cells(low_cooler.footprint, low_court.origin, low_court.cells)
	check(low_steam.intensity == 100 and low_court._try_modifier(low_cooler, selected, 1), "strength-one medium admits one finite cooling channel")
	check(low_steam.intensity == 33, "strength-one cooling reduces thermal100 to50 then compensates added density to33 without a minimum intensity floor")


func _test_weakened_radial_terminal_radius() -> void:
	var court = CourtCandidate.new()
	var heavy: Dictionary = _add_source(court, 1, 451, CourtCandidate.WATER, 15, false)
	heavy.wire = 181 # Production Tide Shell: Heavy, full blast radius 120000.
	equal(int(CombatTuning.cast_definition(heavy.wire).blast_radius), 120_000, "radial strength fixture uses the independently specified live Heavy radius")
	_add_source(court, 2, 452, CourtCandidate.FIRE, 8, false)
	var consumed: Dictionary = court.resolve_contact(451, 452, court.origin, 0)
	check(consumed.accepted and heavy.ledger.remaining_strength == 7, "fixture weakens an actual Heavy source from strength 15 to 7 through the finite ledger")
	var footprint: Dictionary = court.terminal_footprint({"position": court.origin}, heavy)
	var expected_radius: int = roundi(120_000.0 * sqrt(7.0 / 15.0))
	equal(expected_radius, 81_976, "independent seven-fifteenths radius rounds to81976 fixed units")
	check(footprint.kind == "disk" and int(footprint.radius) == expected_radius, "weakened Heavy radius is roundi(120000*sqrt(7/15)) exactly once")
	check(expected_radius < 120_000, "partial strength cannot retain the full Heavy ground extent")


func _test_mirror_effect_profiles() -> void:
	var flood_court = CourtCandidate.new()
	_add_source(flood_court, 1, 501, CourtCandidate.WATER, 10, false, Vector2i(1000, 0))
	_add_source(flood_court, 2, 502, CourtCandidate.WATER, 10, false)
	var flood_result: Dictionary = flood_court.resolve_contact(501, 502, flood_court.origin, 0)
	var actor := PlayerState.new(90)
	actor.team_id = 2
	actor.position_x = flood_court.origin.x
	actor.position_y = flood_court.origin.y
	var events: Array[Dictionary] = []
	var before := actor.health
	for tick: int in [78, 79, 80]:
		flood_court.apply_product_effects([actor], tick, SimConfig.new(120), CollisionWorld.new(), events)
	equal(Vector2i(actor.position_x, actor.position_y), flood_court.origin, "Frostway neither pushes along its corridor nor adds perpendicular motion")
	equal(before - actor.health, 4000, "strength-ten Frostway deals one 4000 first-entry hit across repeated active ticks")
	check(events.size() == 1 and events[0].type == "chemistry_hit", "Frostway reports only its actual one-time damage")
	check(flood_court.products[flood_result.product_id].material == "flood", "Frostway keeps the stable wire316 storage layer")
	var modifiers := HexProductEffects.pre_movement(flood_court, actor, 80, null, SimConfig.new(120))
	equal(modifiers.ground_target_ratio, 750, "ordinary grounded travel uses exactly 75 percent target speed")
	equal(modifiers.acceleration_ratio, 1000, "Frostway does not invent acceleration loss")
	equal(modifiers.braking_ratio, 1000, "Frostway does not invent braking loss")
	actor.slide_ticks = 10
	equal(HexProductEffects.pre_movement(flood_court, actor, 80).ground_target_ratio, 1000, "paid Slide retains its authored motion")
	actor.slide_ticks = 0
	actor.air_height = 20_000
	equal(HexProductEffects.pre_movement(flood_court, actor, 80).ground_target_ratio, 1000, "airborne clearance retains ordinary air motion")
	actor.air_height = 0
	actor.position_x = flood_court.origin.x + 400
	actor.position_y = flood_court.origin.y
	var blocked_world := CollisionWorld.new()
	blocked_world.add_obstacle(CollisionWorld.Obstacle.new(1, flood_court.origin.x + 18_500, flood_court.origin.y - 50_000, flood_court.origin.x + 30_000, flood_court.origin.y + 50_000))
	flood_court.apply_product_effects([actor], 81, SimConfig.new(120), blocked_world, events)
	equal(actor.position_x, flood_court.origin.x + 400, "Frostway cannot translate an actor into an adjacent wall")
	var projectile_world := SimWorld.new(120, 1, CollisionWorld.new(1_280_000, 960_000))
	projectile_world.hex_court = flood_court
	projectile_world.tick = 80
	var shot := ProjectileState.new(900, 2, 2, 140, CourtCandidate.WATER, flood_court.origin, Vector2i(120_000, 0), 8000, 1000, 120)
	var plan := HexProjectileCombat._plan(shot, projectile_world)
	equal(plan.finish - plan.start, Vector2i(650, 0), "actual projectile planner applies 65 percent displacement at 120Hz")
	equal(shot.velocity_x, 120_000, "field planning retains immutable base projectile velocity")
	shot.position_x = flood_court.origin.x + 250_000
	shot.position_y = flood_court.origin.y + 200_000
	plan = HexProjectileCombat._plan(shot, projectile_world)
	equal(plan.finish - plan.start, Vector2i(1000, 0), "leaving Frostway immediately restores full projectile displacement")

	var flame_court = CourtCandidate.new()
	_add_source(flame_court, 1, 511, CourtCandidate.FIRE, 10, false)
	_add_source(flame_court, 2, 512, CourtCandidate.FIRE, 10, false)
	var flame_result: Dictionary = flame_court.resolve_contact(511, 512, flame_court.origin, 0)
	var target := PlayerState.new(91)
	target.position_x = flame_court.origin.x
	target.position_y = flame_court.origin.y
	target.spawn_protection_ticks = 0
	var flame_before: int = target.health
	events.clear()
	flame_court.apply_product_effects([target], 24, SimConfig.new(120), CollisionWorld.new(), events)
	check(target.health == flame_before - 8000, "strength-ten Conflagration applies one authored 8000 active pulse")
	check(events.size() == 1 and events[0].type == "hex_conflagration", "Conflagration pulse reports its own recipe event")
	check(flame_court.products[flame_result.product_id].material == "conflagration", "damage execution keeps Conflagration identity")


func _test_edge_effects_and_expiry() -> void:
	for element: int in [CourtCandidate.WATER, CourtCandidate.FIRE]:
		var court: HexCourt = CourtCandidate.new()
		court.chemistry_enabled = true
		_add_source(court, 1, 901, element, 5, false)
		_add_source(court, 2, 902, element, 5, false)
		var point := court.origin + Vector2i(300_000, 0) # Twelve24px columns plus one12px half-width.
		var outcome: Dictionary = court.resolve_contact(901, 902, point, 0)
		check(outcome.accepted, "edge medium retains its intersecting stored cell")
		var product: Dictionary = court.products[outcome.product_id]
		var actor := PlayerState.new(80)
		actor.position_x = point.x + 20_000
		actor.position_y = point.y
		check(HexFootprint.contains(product.footprint, Vector2i(actor.position_x, actor.position_y)), "outside court fixture is inside the unclipped analytic disk")
		check(not court.contains_stored(product, Vector2i(actor.position_x, actor.position_y)), "outside-grid disk portion is not stored coverage")
		check(court.contains_stored(product, point), "closed outer edge remains part of the stored polygon union")
		var events: Array[Dictionary] = []
		var before := actor.canonical_values()
		court.apply_product_effects([actor], 78 if element == CourtCandidate.WATER else 24, SimConfig.new(), CollisionWorld.new(), events)
		check(actor.canonical_values() == before and events.is_empty(), "unrendered off-grid mirror region cannot move or damage")
		equal(int(product.expiry_tick), 570 if element == CourtCandidate.WATER else 444, "each mirror retains its independently authored exact phase deadline")
		court.expire_at(570 if element == CourtCandidate.WATER else 444)
		check(court.products.is_empty(), "medium product capacity returns on its exact expiry tick before admission")
		check(court.conservation_valid(), "exact expiry preserves the global matter ledger")


func _test_capacity_reservation() -> void:
	var court = CourtCandidate.new()
	for index: int in range(4):
		_add_source(court, index + 1, 601 + index, CourtCandidate.WATER, 5, false)
	check(court.reserved_products() == 4, "each live unspent cast reserves one potential product")
	court.resolve_contact(601, 602, court.origin, 0)
	check(court.reserved_products() == 3, "one product plus two remaining casts preserves capacity after both parents exhaust")
	check(court.reserved_products() <= CourtCandidate.MAX_PRODUCTS, "bounded reservation never exceeds the product cap in the fixture")


func _test_render_metadata_phases() -> void:
	var water_court = CourtCandidate.new()
	var water: Dictionary = _add_source(water_court, 1, 701, CourtCandidate.WATER, 5, true, Vector2i(0, -1000), 10)
	var water_cell: Vector2i = _first_cell(water.cells)
	var forming_water: Dictionary = water_court.render_regions(water_cell, "water", 10)[0]
	var active_water: Dictionary = water_court.render_regions(water_cell, "water", 34)[0]
	var decaying_water: Dictionary = water_court.render_regions(water_cell, "water", int(water.expires) - CourtCandidate.COOLING_TICKS)[0]
	check(forming_water.phase == "forming" and active_water.phase == "active" and decaying_water.phase == "decaying", "Water presentation retains created and expiry transition phases")
	check(not forming_water.danger and not active_water.danger and not decaying_water.danger, "Water presentation metadata never claims an active damage policy")

	var flood_court = CourtCandidate.new()
	_add_source(flood_court, 1, 711, CourtCandidate.WATER, 5, false, Vector2i(1000, 0))
	_add_source(flood_court, 2, 712, CourtCandidate.WATER, 5, false)
	var flood_result: Dictionary = flood_court.resolve_contact(711, 712, flood_court.origin, 20)
	var flood: Dictionary = flood_court.products[flood_result.product_id]
	var flood_cell: Vector2i = _first_cell(flood.cells)
	var forming_flood: Dictionary = flood_court.render_regions(flood_cell, "flood", 20)[0]
	var active_flood: Dictionary = flood_court.render_regions(flood_cell, "flood", flood.active_tick)[0]
	var decaying_flood: Dictionary = flood_court.render_regions(flood_cell, "flood", flood.decay_tick)[0]
	check(not forming_flood.danger and active_flood.danger and not decaying_flood.danger, "product danger matches Frostway's active-only first-entry damage")
	check(active_flood.direction == Vector2i(1000, 0), "Frostway rendering publishes its authoritative corridor direction")

	var steam_court = CourtCandidate.new()
	_add_source(steam_court, 1, 721, CourtCandidate.WATER, 5, false)
	_add_source(steam_court, 2, 722, CourtCandidate.FIRE, 5, false)
	var steam_result: Dictionary = steam_court.resolve_contact(721, 722, steam_court.origin, 30)
	var steam: Dictionary = steam_court.products[steam_result.product_id]
	var steam_cell: Vector2i = _first_cell(steam.cells)
	check(not steam_court.render_regions(steam_cell, "steam", 30)[0].danger, "forming Steam is not marked harmful before exposure begins")
	check(steam_court.render_regions(steam_cell, "steam", steam.active_tick)[0].danger, "active Steam danger matches exposure")
	check(not steam_court.render_regions(steam_cell, "steam", steam.decay_tick)[0].danger, "decaying Steam is not marked harmful after exposure ends")


func _test_all_reaction_footprints_remain_stationary() -> void:
	var physics := CollisionWorld.new(1_280_000, 960_000)
	var aims := [Vector2i(1000, 0), Vector2i(707, 707), Vector2i(0, 1000), Vector2i(-707, 707), Vector2i(-1000, 0), Vector2i(-707, -707), Vector2i(0, -1000), Vector2i(707, -707)]
	var pair_count := 0
	for wire: int in HexRecipePolicy.ACTIVE_RECIPE_WIRES:
		if wire > 400: continue # Higher-order formation has its own exhaustive 63-reaction suite.
		pair_count += 1
		var policy := HexRecipePolicy.definition(wire)
		for aim: Vector2i in aims:
			var court := StationaryCourt.new()
			_add_source(court, 1, 901, int(policy.elements[0]), 5, false, aim)
			_add_source(court, 2, 902, int(policy.elements[1]), 5, false, aim)
			var contact := court.origin + Vector2i(137, 251)
			var outcome := court.resolve_contact(901, 902, contact, 10)
			check(bool(outcome.accepted), "stationary pair %d admits finite paid contact" % wire)
			if not bool(outcome.accepted): continue
			var product: Dictionary = court.products[outcome.product_id]
			var before := product.duplicate(true)
			var revision := court.value_revision
			var selections := court.selections
			var ticks := [10, int(product.active_tick) - 1, int(product.active_tick), int(product.active_tick) + 1, int(product.active_tick) + 54, int(product.decay_tick) - 1, int(product.decay_tick), int(product.expiry_tick) - 1, int(product.expiry_tick)]
			for tick: int in ticks:
				court.move_products(tick, physics)
				court.move_products(tick, null) # prediction and repeated calls also remain inert.
				equal(product, before, "wire %d preserves origin, cells, geometry, quantity and lifecycle at tick %d" % [wire, tick])
				equal(court.value_revision, revision, "stationary ticks do not dirty field values")
				equal(court.selections, selections, "stationary ticks perform zero selection/occlusion work")
				check(court.conservation_valid(), "stationary tick conserves both paid source budgets")
			for cell: Vector2i in product.coverage:
				var regions := court.render_regions(cell, String(product.material), int(product.active_tick))
				check(not regions.is_empty(), "every selected compact cell is visible to the presenter")
				if not regions.is_empty(): equal(regions[0].polygon, court.whole_cell_polygon(cell), "compact gameplay and rendered hex agree")
			court.expire_at(int(product.expiry_tick))
			check(court.products.is_empty() and court.conservation_valid(), "stationary reactions still expire and conserve matter")
	equal(pair_count, 21, "stationarity visits every live unordered pair and self-combination exactly once")


func _add_source(
	court,
	cast_id: int,
	source_id: int,
	element: int,
	strength: int,
	deposited: bool,
	aim: Vector2i = Vector2i(0, -1000),
	created: int = 0,
) -> Dictionary:
	var ledger: Dictionary = StrengthLedger.make_partitioned(source_id, strength, CourtCandidate.MATTER_PER_CAST)
	var footprint := HexFootprint.disk(court.origin, 34_000)
	# Pure accounting probes deliberately exercise intermediate strengths 1..15.
	# A real matching Heavy wire bounds their provenance; these synthetic ledgers
	# do not claim a network-admissible full cast or replace paid-route fixtures.
	var wire := int({1: 183, 2: 179, 3: 181, 4: 185, 7: 191, 8: 193}.get(element, 0))
	var definition := CombatTuning.cast_definition(wire)
	check(int(definition.get("element_wire_id", 0)) == element and int(definition.get("reaction_strength", 0)) >= strength, "synthetic source has a real matching wire whose paid strength bounds the probe")
	var record := {
		"id": cast_id, "owner": cast_id, "team": cast_id, "wire": wire, "element": element,
		"strength": strength, "budget": CourtCandidate.MATTER_PER_CAST,
		"unallocated": CourtCandidate.MATTER_PER_CAST, "ground": 0,
		"consumed": 0, "expired": 0, "paid": true, "source": source_id,
		"reacted": false, "ledger": ledger, "cells": {}, "coverage": {},
		"flight_parts": {}, "ground_parts": {}, "trail_spent": 0, "created": created,
		"expires": 10_000, "origin": court.origin, "aim": aim,
		"footprint": footprint,
	}
	check(CastParts.initialize(record, source_id), "direct strength fixture initializes one explicit paid flight part")
	court.casts[cast_id] = record
	court.sources[source_id] = cast_id
	court.next_cast_id = maxi(court.next_cast_id, cast_id + 1)
	court.metrics.matter_paid += CourtCandidate.MATTER_PER_CAST
	if deposited:
		var selected: Array[Vector2i] = HexFootprint.intersected_cells(footprint, court.origin, court.cells)
		var moved := CastParts.deposit_flight(record, source_id, court.next_ground_part_id, selected, footprint, created, 10_000)
		check(moved == CourtCandidate.MATTER_PER_CAST, "direct strength fixture deposits its explicit paid flight part")
		court.next_ground_part_id += 1
		court._sync_cast_ledger(record)
		court._rebuild_cast_layers(record)
	return record


func _first_cell(values: Dictionary) -> Vector2i:
	var keys: Array = values.keys()
	return keys[0]


func _set_ground_footprint(court, record: Dictionary, center: Vector2i) -> void:
	record.footprint = HexFootprint.disk(center, 34_000)
	var selected: Array[Vector2i] = HexFootprint.intersected_cells(record.footprint, court.origin, court.cells)
	var part_id: int = record.ground_parts.keys()[0]
	var part: Dictionary = record.ground_parts[part_id]
	part.footprint = record.footprint.duplicate(true)
	part.cells = court._equal_allocations(selected, int(part.quantity))
	part.coverage = {}
	for cell: Vector2i in selected:
		part.coverage[cell] = 1
	record.cells = part.cells.duplicate(true)
	record.coverage = part.coverage.duplicate(true)
	court._rebuild_cast_layers(record)
	check(CastParts.validate(record), "moved ground fixture retains explicit part ownership")


func _sum(values: Dictionary) -> int:
	var result := 0
	for value: int in values.values():
		result += value
	return result


func _layer_sum(court, record: Dictionary, layer: String) -> int:
	var result := 0
	for cell: Vector2i in record.cells:
		result += int(court.cells[cell][layer].get(int(record.id), 0))
	return result

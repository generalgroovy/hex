extends RefCounted

const CourtCandidate = preload("hex_court.gd")
const StrengthLedger = preload("strength_budget.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run() -> Dictionary:
	_test_successive_unequal_contacts()
	_test_explicit_mirror_products()
	_test_ground_contact_and_proportional_retile()
	_test_weakened_radial_terminal_radius()
	_test_finite_steam_modifier()
	_test_mirror_effect_profiles()
	_test_render_metadata_phases()
	_test_capacity_reservation()
	return {
		"passed": _failures.is_empty(),
		"assertions": _assertions,
		"failures": _failures.duplicate(),
	}


func _test_successive_unequal_contacts() -> void:
	var court = CourtCandidate.new()
	var water: Dictionary = _add_source(court, 1, 101, CourtCandidate.WATER, 15, false, Vector2i(1000, 0))
	var fire_five: Dictionary = _add_source(court, 2, 102, CourtCandidate.FIRE, 5, false)
	_check(court.ledger_for_source(101) == water.ledger and int(water.ledger.source_id) == 101, "source lookup returns the actual immutable nested source ledger")
	_check(court.ledger_for_source(999).is_empty(), "unknown source has no fabricated ledger")
	var first: Dictionary = court.resolve_contact(101, 102, court.origin, 10)
	_check(first[&"accepted"] and first[&"matched_strength"] == 5, "unequal flight contact consumes the minimum strength once")
	_check(water.ledger.remaining_strength == 10 and fire_five.ledger.remaining_strength == 0, "unequal contact keeps only unmatched source strength")
	_check(first[&"quantity"] == 800, "15-vs-5 contact transfers cumulative 200 plus 600 quantity")
	var first_product: Dictionary = court.products[first[&"product_id"]]
	_check(first[&"reaction_id"] == first[&"product_id"], "contact result exposes stable reaction and product aliases")
	_check(first_product.recipe_wire_id == CourtCandidate.STEAM_WIRE and first_product.material == "steam", "Fire plus Water produces explicit Steam310")
	_check(first_product.active_tick == 34 and first_product.decay_tick == 394 and first_product.expiry_tick == 454, "medium uses exact 24/360/60 phase boundaries")
	_check(first_product.intensity == 500 and first_product.quantity == 800, "medium intensity and quantity derive from this contact")

	_add_source(court, 3, 103, CourtCandidate.FIRE, 3, false)
	var second: Dictionary = court.resolve_contact(101, 103, court.origin + Vector2i(10_000, 0), 20)
	_check(second[&"accepted"] and second[&"matched_strength"] == 3, "remaining strong source can resolve a later weaker contact")
	_check(water.ledger.remaining_strength == 7 and water.ledger.consumed_quantity == 320, "15->10->7 source keeps cumulative proportional accounting")
	_check(second[&"quantity"] == 720, "second medium contains only new 120 plus 600 portions")
	_check(court.products.size() == 2 and court.conservation_valid(), "successive products remain finite and globally conserved")


func _test_explicit_mirror_products() -> void:
	var flood_court = CourtCandidate.new()
	_add_source(flood_court, 1, 201, CourtCandidate.WATER, 7, false, Vector2i(1000, 0), 2)
	_add_source(flood_court, 2, 202, CourtCandidate.WATER, 7, false, Vector2i(0, 1000), 3)
	var flood_result: Dictionary = flood_court.resolve_contact(202, 201, flood_court.origin, 5)
	var flood: Dictionary = flood_court.products[flood_result.product_id]
	_check(flood.recipe_wire_id == CourtCandidate.FLOOD_WIRE and flood.material == "flood", "Water mirror creates Flood316 without a Steam fallback")
	_check(flood.quantity == 1200 and flood.intensity == 700, "Flood retains both finite portions and matched-strength intensity")
	_check(flood.flow_aim == Vector2i(1000, 0), "Flood flow follows the oldest source aim")
	_check(flood.flow_units_per_second == 40_000 and flood.common_wall_clearance == 18_000, "Flood publishes bounded flow and wall-clearance numerics")
	_check(flood.geometry_override == "medium_disk_64000" and flood.footprint.radius == 64_000, "Flood explicitly overrides old flow geometry with the medium disk")
	_check(flood_court.cells[_first_cell(flood.cells)].flood.has(int(flood.id)), "Flood owns a separate authoritative product layer")

	var fire_court = CourtCandidate.new()
	_add_source(fire_court, 1, 211, CourtCandidate.FIRE, 15, false)
	_add_source(fire_court, 2, 212, CourtCandidate.FIRE, 5, false)
	var flame_result: Dictionary = fire_court.resolve_contact(211, 212, fire_court.origin, 7)
	var flame: Dictionary = fire_court.products[flame_result.product_id]
	_check(flame.recipe_wire_id == CourtCandidate.CONFLAGRATION_WIRE and flame.material == "conflagration", "Fire mirror creates Conflagration309 without a Steam fallback")
	_check(flame.quantity == 800 and flame.intensity == 500, "Conflagration uses unequal finite source portions")
	_check(flame.pulse_ms == 600 and flame.pulse_damage == 8000, "Conflagration publishes the authored 8x1000 per 600ms pulse")
	_check(flame.geometry_override == "medium_disk_64000" and flame.footprint.radius == 64_000, "Conflagration documents the new medium-disk override")
	_check(fire_court.cells[_first_cell(flame.cells)].conflagration.has(int(flame.id)), "Conflagration owns a separate authoritative product layer")


func _test_ground_contact_and_proportional_retile() -> void:
	var court = CourtCandidate.new()
	var water: Dictionary = _add_source(court, 1, 301, CourtCandidate.WATER, 15, true)
	var fire: Dictionary = _add_source(court, 2, 302, CourtCandidate.FIRE, 5, true)
	_set_ground_footprint(court, water, court.origin + Vector2i(-20_000, 0))
	_set_ground_footprint(court, fire, court.origin + Vector2i(20_000, 0))
	var old_water_cells: int = water.cells.size()
	var preferred := court.origin + Vector2i(50_000, 0) # Inside Fire, outside Water.
	court._try_ground_reactions(fire, preferred, 30)
	_check(court.products.size() == 1, "an overlapping deposited pair resolves during ground deposit handling")
	var product: Dictionary = court.products[court.products.keys()[0]]
	_check(HexFootprint.contains(water.footprint, product.footprint.center) and HexFootprint.contains(fire.footprint, product.footprint.center), "ground medium origin is an actual common-footprint witness")
	_check(product.footprint.center != preferred, "preferred impact outside the other source cannot become a false contact origin")
	_check(water.ledger.deposited_quantity == 400 and water.ground == 400, "partial ground source retains only its ledger remainder")
	_check(fire.ledger.deposited_quantity == 0 and fire.cells.is_empty(), "exhausted ground source removes every cell allocation")
	_check(_sum(water.cells) == 400 and water.cells.size() <= old_water_cells, "remaining ground is retiled proportionally without adding cells")
	_check(_layer_sum(court, water, "water") == 400, "cell layer mirrors the exact proportional ground remainder")
	_check(court.conservation_valid(), "ground reaction and product remain globally conserved")


func _test_finite_steam_modifier() -> void:
	var court = CourtCandidate.new()
	_add_source(court, 1, 401, CourtCandidate.WATER, 5, false)
	_add_source(court, 2, 402, CourtCandidate.FIRE, 5, false)
	var formed: Dictionary = court.resolve_contact(401, 402, court.origin, 0)
	var steam: Dictionary = court.products[formed.product_id]
	var modifier: Dictionary = _add_source(court, 3, 403, CourtCandidate.FIRE, 5, false)
	var selected: Array[Vector2i] = HexFootprint.intersected_cells(modifier.footprint, court.origin, court.cells)
	_check(court._try_modifier(modifier, selected, 30), "fresh Fire consumes against finite Steam interaction strength")
	_check(modifier.ledger.remaining_strength == 0 and modifier.ledger.consumed_quantity == 600, "modifier spends only its finite source ledger")
	_check(steam.quantity == 1800, "modifier retains existing product matter once and adds only its new 600 portion")
	_check(steam.intensity == 750 and steam.heated, "strength-five Fire adds exactly 250 bounded heat after subtractive accounting")
	var second_heater: Dictionary = _add_source(court, 4, 404, CourtCandidate.FIRE, 3, false)
	selected = HexFootprint.intersected_cells(second_heater.footprint, court.origin, court.cells)
	_check(not court._try_modifier(second_heater, selected, 31), "one-time heat refuses a second modifier without consuming it")
	_check(second_heater.ledger.flight_quantity == 600 and second_heater.ledger.consumed_quantity == 0, "refused heat cannot mutate the new source ledger")
	var cooler: Dictionary = _add_source(court, 5, 405, CourtCandidate.WATER, 5, false)
	selected = HexFootprint.intersected_cells(cooler.footprint, court.origin, court.cells)
	_check(court._try_modifier(cooler, selected, 32), "one Water channel remains available after the independent heat channel")
	_check(steam.intensity == 500 and steam.cooled, "cool subtracts min(750/2,5*50)=250 without raising intensity")
	_check(steam.quantity == 2400 and cooler.ledger.remaining_strength == 0, "cooling adds only its consumed 600 source stock")
	_check(court.conservation_valid(), "finite modifier accounting preserves paid-source conservation")

	var low_court = CourtCandidate.new()
	_add_source(low_court, 1, 411, CourtCandidate.WATER, 1, false)
	_add_source(low_court, 2, 412, CourtCandidate.FIRE, 1, false)
	var low_result: Dictionary = low_court.resolve_contact(411, 412, low_court.origin, 0)
	var low_steam: Dictionary = low_court.products[low_result.product_id]
	var low_cooler: Dictionary = _add_source(low_court, 3, 413, CourtCandidate.WATER, 1, false)
	selected = HexFootprint.intersected_cells(low_cooler.footprint, low_court.origin, low_court.cells)
	_check(low_steam.intensity == 100 and low_court._try_modifier(low_cooler, selected, 1), "strength-one medium admits one finite cooling channel")
	_check(low_steam.intensity == 50, "literal cooling subtraction lowers 100 by min(50,50) without a 250 floor")


func _test_weakened_radial_terminal_radius() -> void:
	var court = CourtCandidate.new()
	var heavy: Dictionary = _add_source(court, 1, 451, CourtCandidate.WATER, 15, false)
	heavy.wire = 181 # Production Tide Shell: Heavy, full blast radius 84000.
	var opposing: Dictionary = StrengthLedger.make(452, 8, CourtCandidate.MATTER_PER_CAST)
	var consumed: Dictionary = StrengthLedger.consume_pair(heavy.ledger, opposing)
	_check(consumed.accepted and heavy.ledger.remaining_strength == 7, "fixture weakens an actual Heavy source from strength 15 to 7 through the finite ledger")
	var footprint: Dictionary = court.terminal_footprint({"position": court.origin}, heavy)
	var expected_radius: int = roundi(84_000.0 * sqrt(7.0 / 15.0))
	_check(footprint.kind == "disk" and int(footprint.radius) == expected_radius, "weakened Heavy radius is roundi(84000*sqrt(7/15)) exactly once")
	_check(expected_radius < 84_000, "partial strength cannot retain the full Heavy ground extent")


func _test_mirror_effect_profiles() -> void:
	var flood_court = CourtCandidate.new()
	_add_source(flood_court, 1, 501, CourtCandidate.WATER, 10, false, Vector2i(1000, 0))
	_add_source(flood_court, 2, 502, CourtCandidate.WATER, 10, false)
	var flood_result: Dictionary = flood_court.resolve_contact(501, 502, flood_court.origin, 0)
	var actor := PlayerState.new(90)
	actor.position_x = flood_court.origin.x
	actor.position_y = flood_court.origin.y
	var events: Array[Dictionary] = []
	for tick: int in [24, 25, 26]:
		flood_court.apply_product_effects([actor], tick, SimConfig.new(120), CollisionWorld.new(), events)
	_check(actor.position_x == flood_court.origin.x + 1000, "Flood carry produces exactly 40000 fixed units per second over three 120Hz ticks")
	_check(actor.position_y == flood_court.origin.y, "east Flood aim adds no perpendicular movement")
	_check(not events.is_empty() and events[0].type == "hex_flood_flow", "Flood reports its actual collision-resolved displacement")
	_check(flood_court.products[flood_result.product_id].material == "flood", "flow execution keeps Flood identity")
	actor.position_x = flood_court.origin.x + 400
	actor.position_y = flood_court.origin.y
	var blocked_world := CollisionWorld.new()
	blocked_world.add_obstacle(CollisionWorld.Obstacle.new(1, flood_court.origin.x + 18_500, flood_court.origin.y - 50_000, flood_court.origin.x + 30_000, flood_court.origin.y + 50_000))
	flood_court.apply_product_effects([actor], 27, SimConfig.new(120), blocked_world, events)
	_check(actor.position_x == flood_court.origin.x + 500, "Flood uses the common 18000 wall clearance when resolving flow")

	var flame_court = CourtCandidate.new()
	_add_source(flame_court, 1, 511, CourtCandidate.FIRE, 10, false)
	_add_source(flame_court, 2, 512, CourtCandidate.FIRE, 10, false)
	var flame_result: Dictionary = flame_court.resolve_contact(511, 512, flame_court.origin, 0)
	var target := PlayerState.new(91)
	target.position_x = flame_court.origin.x
	target.position_y = flame_court.origin.y
	target.spawn_protection_ticks = 0
	var before: int = target.health
	events.clear()
	flame_court.apply_product_effects([target], 24, SimConfig.new(120), CollisionWorld.new(), events)
	_check(target.health == before - 8000, "strength-ten Conflagration applies one authored 8000 active pulse")
	_check(events.size() == 1 and events[0].type == "hex_conflagration", "Conflagration pulse reports its own recipe event")
	_check(flame_court.products[flame_result.product_id].material == "conflagration", "damage execution keeps Conflagration identity")


func _test_capacity_reservation() -> void:
	var court = CourtCandidate.new()
	for index: int in range(4):
		_add_source(court, index + 1, 601 + index, CourtCandidate.WATER, 5, false)
	_check(court.reserved_products() == 4, "each live unspent cast reserves one potential product")
	court.resolve_contact(601, 602, court.origin, 0)
	_check(court.reserved_products() == 3, "one product plus two remaining casts preserves capacity after both parents exhaust")
	_check(court.reserved_products() <= CourtCandidate.MAX_PRODUCTS, "bounded reservation never exceeds the product cap in the fixture")


func _test_render_metadata_phases() -> void:
	var water_court = CourtCandidate.new()
	var water: Dictionary = _add_source(water_court, 1, 701, CourtCandidate.WATER, 5, true, Vector2i(0, -1000), 10)
	var water_cell: Vector2i = _first_cell(water.cells)
	var forming_water: Dictionary = water_court.render_regions(water_cell, "water", 10)[0]
	var active_water: Dictionary = water_court.render_regions(water_cell, "water", 34)[0]
	var decaying_water: Dictionary = water_court.render_regions(water_cell, "water", int(water.expires) - CourtCandidate.COOLING_TICKS)[0]
	_check(forming_water.phase == "forming" and active_water.phase == "active" and decaying_water.phase == "decaying", "Water presentation retains created and expiry transition phases")
	_check(not forming_water.danger and not active_water.danger and not decaying_water.danger, "Water presentation metadata never claims an active damage policy")

	var flood_court = CourtCandidate.new()
	_add_source(flood_court, 1, 711, CourtCandidate.WATER, 5, false, Vector2i(1000, 0))
	_add_source(flood_court, 2, 712, CourtCandidate.WATER, 5, false)
	var flood_result: Dictionary = flood_court.resolve_contact(711, 712, flood_court.origin, 20)
	var flood: Dictionary = flood_court.products[flood_result.product_id]
	var flood_cell: Vector2i = _first_cell(flood.cells)
	var forming_flood: Dictionary = flood_court.render_regions(flood_cell, "flood", 20)[0]
	var active_flood: Dictionary = flood_court.render_regions(flood_cell, "flood", flood.active_tick)[0]
	var decaying_flood: Dictionary = flood_court.render_regions(flood_cell, "flood", flood.decay_tick)[0]
	_check(not forming_flood.danger and active_flood.danger and not decaying_flood.danger, "product danger matches the active-only Flood movement policy")
	_check(active_flood.direction == Vector2i(1000, 0), "Flood rendering publishes the authoritative oldest-source flow direction")

	var steam_court = CourtCandidate.new()
	_add_source(steam_court, 1, 721, CourtCandidate.WATER, 5, false)
	_add_source(steam_court, 2, 722, CourtCandidate.FIRE, 5, false)
	var steam_result: Dictionary = steam_court.resolve_contact(721, 722, steam_court.origin, 30)
	var steam: Dictionary = steam_court.products[steam_result.product_id]
	var steam_cell: Vector2i = _first_cell(steam.cells)
	_check(not steam_court.render_regions(steam_cell, "steam", 30)[0].danger, "forming Steam is not marked harmful before exposure begins")
	_check(steam_court.render_regions(steam_cell, "steam", steam.active_tick)[0].danger, "active Steam danger matches exposure")
	_check(not steam_court.render_regions(steam_cell, "steam", steam.decay_tick)[0].danger, "decaying Steam is not marked harmful after exposure ends")


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
	var ledger: Dictionary = StrengthLedger.make(source_id, strength, CourtCandidate.MATTER_PER_CAST)
	var footprint := HexFootprint.disk(court.origin, 34_000)
	var record := {
		"id": cast_id, "owner": cast_id, "wire": 0, "element": element,
		"strength": strength, "budget": CourtCandidate.MATTER_PER_CAST,
		"unallocated": CourtCandidate.MATTER_PER_CAST, "ground": 0,
		"consumed": 0, "expired": 0, "paid": true, "source": source_id,
		"reacted": false, "ledger": ledger, "cells": {}, "created": created,
		"expires": 10_000, "origin": court.origin, "aim": aim,
		"footprint": footprint,
	}
	court.casts[cast_id] = record
	court.sources[source_id] = cast_id
	court.next_cast_id = maxi(court.next_cast_id, cast_id + 1)
	court.metrics.matter_paid += CourtCandidate.MATTER_PER_CAST
	if deposited:
		StrengthLedger.deposit(ledger)
		court._sync_cast_ledger(record)
		var selected: Array[Vector2i] = HexFootprint.intersected_cells(footprint, court.origin, court.cells)
		var allocations: Dictionary = court._equal_allocations(selected, CourtCandidate.MATTER_PER_CAST)
		record.cells = allocations
		var layer := "water" if element == CourtCandidate.WATER else "fire"
		for cell: Vector2i in allocations:
			court.cells[cell][layer][cast_id] = int(allocations[cell])
	return record


func _first_cell(values: Dictionary) -> Vector2i:
	var keys: Array = values.keys()
	return keys[0]


func _set_ground_footprint(court, record: Dictionary, center: Vector2i) -> void:
	var layer := "water" if int(record.element) == CourtCandidate.WATER else "fire"
	for cell: Vector2i in record.cells:
		court.cells[cell][layer].erase(int(record.id))
	record.footprint = HexFootprint.disk(center, 34_000)
	var selected: Array[Vector2i] = HexFootprint.intersected_cells(record.footprint, court.origin, court.cells)
	record.cells = court._equal_allocations(selected, int(record.ledger.deposited_quantity))
	for cell: Vector2i in record.cells:
		court.cells[cell][layer][int(record.id)] = int(record.cells[cell])


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


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)

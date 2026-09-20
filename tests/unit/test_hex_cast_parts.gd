extends FluxTestSuite


const Parts = preload("res://src/sim/hex/hex_cast_parts.gd")
const Budget = preload("res://src/sim/combat/strength_budget.gd")


func run() -> int:
	_test_initialize_and_odd_split()
	_test_partial_trail_deposit_preserves_zero_allocation_coverage()
	_test_independent_ground_lifetimes_and_expiry()
	_test_contact_retile_uses_stable_location_prefixes()
	_test_flight_expiry_and_atomic_refusals()
	_test_strict_validation_rejects_forged_ownership()
	return finish("hex-cast-parts")


func _record(source_id: int, strength: int, budget: int) -> Dictionary:
	return {
		"source": source_id,
		"strength": strength,
		"budget": budget,
		"ledger": Budget.make_partitioned(source_id, strength, budget),
		"cells": {},
	}


func _footprint(center: Vector2i = Vector2i.ZERO, radius: int = 64_000) -> Dictionary:
	return HexFootprint.disk(center, radius)


func _test_initialize_and_odd_split() -> void:
	var record := _record(100, 9, 9)
	check(Parts.initialize(record, 1000), "fresh partitioned cast initializes one flight owner")
	equal(record.flight_parts, {1000: 9}, "initial entity owns the complete flight ledger")
	check(record.ground_parts.is_empty() and record.cells.is_empty() and record.coverage.is_empty(), "fresh flight has no invented ground ownership")
	check(Parts.validate(record), "initialized source validates")
	check(Parts.split_flight(record, 1000, 1001), "odd flight branch splits atomically")
	equal(record.flight_parts, {1000: 5, 1001: 4}, "child receives floor half and odd unit remains with parent")
	check(Parts.validate(record), "odd split preserves ownership sum")
	var before := record.duplicate(true)
	check(not Parts.split_flight(record, 1001, 1000), "split rejects a child ID already owned elsewhere")
	check(record == before, "rejected duplicate-ID split is atomic")
	var independent_namespaces := _record(102, 4, 4)
	Parts.initialize(independent_namespaces, 2000)
	equal(Parts.deposit_flight(independent_namespaces, 2000, 2000, [Vector2i.ZERO], _footprint(), 1, 10, true, 1), 1, "ground part IDs use a namespace independent from flight entity IDs")
	check(independent_namespaces.flight_parts.has(2000) and independent_namespaces.ground_parts.has(2000), "equal numeric IDs may coexist across independent ownership maps")
	check(Parts.validate(independent_namespaces), "equal numeric IDs across independent ownership maps remain canonical")
	var strict_record := {"source": 101, "strength": 3, "budget": 3, "ledger": Budget.make(101, 3, 3), "cells": {}}
	var strict_before := strict_record.duplicate(true)
	check(not Parts.initialize(strict_record, 2000), "cast-parts helper rejects a strict ledger")
	check(strict_record == strict_before, "failed initialization does not add ownership fields")


func _test_partial_trail_deposit_preserves_zero_allocation_coverage() -> void:
	var record := _record(110, 5, 5)
	Parts.initialize(record, 1100)
	var selected: Array[Vector2i] = [Vector2i(1, 0), Vector2i.ZERO, Vector2i(0, 1)]
	equal(Parts.deposit_flight(record, 1100, 2100, selected, _footprint(), 10, 50, true, 1), 1, "trail may deposit a proper partial branch quantity")
	equal(int(record.flight_parts[1100]), 4, "partial trail deposit leaves its remainder with the flight entity")
	var part: Dictionary = record.ground_parts[2100]
	equal(int(part.quantity), 1, "ground part owns the exact moved quantity")
	equal((part.coverage as Dictionary).size(), 3, "ground part preserves every selected whole-cell membership")
	equal((part.cells as Dictionary).size(), 3, "allocation map retains zero-valued selected cells")
	equal(_sum(part.cells), 1, "per-branch cell allocations sum to its quantity")
	var zero_allocations := 0
	for cell: Vector2i in part.coverage:
		equal(int(part.coverage[cell]), 1, "coverage uses explicit one-valued membership")
		check(part.cells.has(cell), "coverage and allocation maps have exactly matching keys")
		if int(part.cells[cell]) == 0:
			zero_allocations += 1
	equal(zero_allocations, 2, "one unit over three cells preserves two zero-allocation memberships")
	equal(record.cells, part.cells, "record allocation aggregate retains all zero-valued coverage keys")
	equal(record.coverage, part.coverage, "record coverage is the live ground-part union")
	check(Parts.validate(record), "tiny partial trail with zero allocations validates")


func _test_independent_ground_lifetimes_and_expiry() -> void:
	var record := _record(120, 12, 12)
	Parts.initialize(record, 1200)
	Parts.split_flight(record, 1200, 1201)
	var first_cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	var second_cells: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	equal(Parts.deposit_flight(record, 1200, 2200, first_cells, _footprint(), 20, 100), 6, "first branch deposits independently")
	equal(Parts.deposit_flight(record, 1201, 2201, second_cells, _footprint(Vector2i(64_000, 0)), 25, 200, true), 6, "second branch retains its own lifetime and footprint")
	equal(int(record.ground_parts[2200].expiry_tick), 100, "first ground expiry is retained")
	equal(int(record.ground_parts[2201].expiry_tick), 200, "second ground expiry is retained")
	equal((record.coverage as Dictionary).size(), 3, "overlapping part coverage forms one three-cell union")
	check(Parts.validate(record), "two independently timed ground branches validate")

	equal(Parts.expire_ground(record, 2200), 6, "one ground branch expires without touching its sibling")
	check(not record.ground_parts.has(2200) and record.ground_parts.has(2201), "expired ground ID is removed and sibling survives")
	check(record.coverage.has(Vector2i(1, 0)), "overlap remains covered by the surviving ground branch")
	check(not record.coverage.has(Vector2i.ZERO), "cell unique to expired branch leaves aggregate coverage")
	equal(int(record.ground_parts[2201].expiry_tick), 200, "sibling lifetime remains unchanged")
	check(Parts.validate(record), "independent ground expiry preserves exact ledger ownership")

	equal(Parts.expire_ground(record, 2201, 1), 1, "ground part supports an exact partial expiry")
	equal(int(record.ground_parts[2201].quantity), 5, "partial ground expiry reduces only selected part quantity")
	equal(_sum(record.ground_parts[2201].cells), 5, "partial ground expiry retiles its own allocation exactly")
	equal((record.ground_parts[2201].coverage as Dictionary).size(), 2, "partial expiry preserves complete part coverage")
	check(Parts.validate(record), "partially expired ground branch validates")


func _test_contact_retile_uses_stable_location_prefixes() -> void:
	var record := _record(130, 10, 20)
	Parts.initialize(record, 1300)
	Parts.split_flight(record, 1300, 1301)
	Parts.split_flight(record, 1301, 1302)
	Parts.deposit_flight(record, 1301, 2301, [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)], _footprint(), 30, 130)
	Parts.deposit_flight(record, 1302, 2302, [Vector2i(0, 1), Vector2i(-1, 1)], _footprint(Vector2i(0, 64_000)), 31, 231)
	Parts.split_flight(record, 1300, 1303)
	equal(record.flight_parts, {1300: 5, 1303: 5}, "fixture owns two equal flight branches")
	equal(Vector2i(int(record.ledger.flight_quantity), int(record.ledger.deposited_quantity)), Vector2i(10, 10), "fixture owns equal flight and ground totals")
	check(Parts.validate(record), "mixed retile fixture begins valid")

	var old_flight := int(record.ledger.flight_quantity)
	var old_ground := int(record.ledger.deposited_quantity)
	var first_partner := Budget.make_partitioned(131, 3, 6)
	var first_contact := Budget.consume_pair(record.ledger, first_partner)
	check(bool(first_contact.accepted), "first contact reduces aggregate ledger")
	equal(Vector2i(int(record.ledger.flight_quantity), int(record.ledger.deposited_quantity)), Vector2i(4, 10), "ledger consumes six-unit flight prefix before ground")
	check(Parts.retile_after_contact(record, old_flight, old_ground), "ownership retiles after first aggregate contact")
	equal(record.flight_parts, {1300: 2, 1303: 2}, "stable cumulative flight retile gives each equal branch two")
	equal(Vector2i(int(record.ground_parts[2301].quantity), int(record.ground_parts[2302].quantity)), Vector2i(5, 5), "ground ownership stays unchanged while flight covers the delta")
	check(Parts.validate(record), "first post-contact ownership validates")

	old_flight = int(record.ledger.flight_quantity)
	old_ground = int(record.ledger.deposited_quantity)
	var second_partner := Budget.make_partitioned(132, 3, 6)
	Budget.consume_pair(record.ledger, second_partner)
	equal(Vector2i(int(record.ledger.flight_quantity), int(record.ledger.deposited_quantity)), Vector2i(0, 8), "second delta exhausts flight then consumes two ground units")
	check(Parts.retile_after_contact(record, old_flight, old_ground), "ownership retiles across the flight-to-ground boundary")
	check(record.flight_parts.is_empty(), "zero flight branches are removed")
	equal(Vector2i(int(record.ground_parts[2301].quantity), int(record.ground_parts[2302].quantity)), Vector2i(4, 4), "ground parts receive stable proportional four-unit allocations")
	check(record.ground_parts[2301].cells.has(Vector2i.ZERO) and record.ground_parts[2301].coverage.has(Vector2i.ZERO), "retile preserves selected-cell membership even where allocation may round down")
	check(Parts.validate(record), "cross-location post-contact ownership validates")

	old_flight = int(record.ledger.flight_quantity)
	old_ground = int(record.ledger.deposited_quantity)
	var final_partner := Budget.make_partitioned(133, 4, 8)
	Budget.consume_pair(record.ledger, final_partner)
	check(Parts.retile_after_contact(record, old_flight, old_ground), "terminal contact removes exhausted part ownership")
	check(record.flight_parts.is_empty() and record.ground_parts.is_empty(), "terminal retile removes every zero ownership part")
	check(record.cells.is_empty() and record.coverage.is_empty(), "terminal retile clears derived ground maps")
	check(Parts.validate(record), "terminal cast ownership validates")


func _test_flight_expiry_and_atomic_refusals() -> void:
	var record := _record(140, 8, 16)
	Parts.initialize(record, 1400)
	Parts.split_flight(record, 1400, 1401)
	equal(Parts.expire_flight(record, 1400, 3), 3, "one flight branch supports exact partial expiry")
	equal(int(record.flight_parts[1400]), 5, "partial flight expiry reduces only its named branch")
	check(Parts.validate(record), "partially expired flight ownership validates")
	var before := record.duplicate(true)
	equal(Parts.expire_flight(record, 9999), -1, "unknown flight entity rejects")
	check(record == before, "unknown flight expiry rejection is atomic")

	var duplicate_cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
	before = record.duplicate(true)
	equal(Parts.deposit_flight(record, 1401, 2400, duplicate_cells, _footprint(), 10, 20), -1, "duplicate selected cell rejects")
	check(record == before, "duplicate selection rejection is atomic")
	before = record.duplicate(true)
	equal(Parts.deposit_flight(record, 1401, 2400, [Vector2i.ZERO], {}, 10, 20), -1, "invalid footprint rejects")
	check(record == before, "invalid footprint rejection is atomic")
	before = record.duplicate(true)
	equal(Parts.deposit_flight(record, 1401, 2400, [Vector2i.ZERO], _footprint(), 10, 20, false, 1), -1, "non-trail branch cannot deposit a proper partial quantity")
	check(record == before, "non-trail partial-deposit rejection is atomic")


func _test_strict_validation_rejects_forged_ownership() -> void:
	var record := _record(150, 6, 12)
	Parts.initialize(record, 1500)
	Parts.split_flight(record, 1500, 1501)
	Parts.deposit_flight(record, 1501, 2500, [Vector2i.ZERO, Vector2i(1, 0)], _footprint(), 15, 90)
	check(Parts.validate(record), "forgery fixture begins valid")
	var forged := record.duplicate(true)
	forged.source = 151
	check(not Parts.validate(forged), "canonical source must equal ledger provenance")
	forged = record.duplicate(true)
	forged.flight_parts[1500] = int(forged.flight_parts[1500]) + 1
	check(not Parts.validate(forged), "flight ownership sum must equal ledger flight quantity")
	forged = record.duplicate(true)
	forged.ground_parts[2500].cells.erase(Vector2i.ZERO)
	check(not Parts.validate(forged), "ground allocation and coverage keys must match exactly")
	forged = record.duplicate(true)
	forged.coverage.erase(Vector2i.ZERO)
	check(not Parts.validate(forged), "record coverage must be the exact union of live ground parts")
	forged = record.duplicate(true)
	forged.ground_parts[2500].footprint = {}
	check(not Parts.validate(forged), "every ground part requires a valid authored footprint")
	forged = record.duplicate(true)
	forged.ground_parts[2500].invented = 1
	check(not Parts.validate(forged), "ground-part rows reject unvalidated extra fields")

	var old_flight := int(record.ledger.flight_quantity)
	var old_ground := int(record.ledger.deposited_quantity)
	var partner := Budget.make_partitioned(151, 2, 4)
	Budget.consume_pair(record.ledger, partner)
	var stale_before := record.duplicate(true)
	check(not Parts.retile_after_contact(record, old_flight + 1, old_ground), "retile rejects old totals that do not match stale ownership")
	check(record == stale_before, "rejected retile leaves ledger and stale ownership untouched")
	forged = record.duplicate(true)
	forged.coverage.erase(Vector2i.ZERO)
	var forged_before := forged.duplicate(true)
	check(not Parts.retile_after_contact(forged, old_flight, old_ground), "retile rejects forged pre-contact aggregate coverage")
	check(forged == forged_before, "retile does not silently repair a forged aggregate map")


func _sum(values: Dictionary) -> int:
	var result := 0
	for value: Variant in values.values():
		result += int(value)
	return result

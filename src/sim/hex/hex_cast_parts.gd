class_name HexCastParts
extends RefCounted


## Pure branch ownership for one partitioned cast ledger. This helper owns only
## record-local maps; callers separately mirror aggregate cells into world layers.
## Flight entity IDs and ground part IDs are independent namespaces.
const StrengthBudget = preload("res://src/sim/combat/strength_budget.gd")
const HexFootprint = preload("res://src/sim/hex/hex_footprint.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const MAX_SELECTED_CELLS: int = 511 # Fourfold density; world-space effect radii unchanged.


static func initialize(record: Dictionary, entity_id: int) -> bool:
	if entity_id <= 0 or not _canonical_source_valid(record):
		return false
	var ledger: Dictionary = record.ledger
	if (
		int(ledger.remaining_strength) != int(ledger.initial_strength)
		or int(ledger.flight_quantity) != int(ledger.budget)
		or int(ledger.deposited_quantity) != 0
		or int(ledger.consumed_quantity) != 0
		or int(ledger.expired_quantity) != 0
	):
		return false
	for key: String in ["flight_parts", "ground_parts", "coverage"]:
		if record.has(key) and (not record[key] is Dictionary or not (record[key] as Dictionary).is_empty()):
			return false
	if record.has("cells") and (not record.cells is Dictionary or not (record.cells as Dictionary).is_empty()):
		return false
	var candidate := record.duplicate(true)
	candidate.flight_parts = {entity_id: int(ledger.flight_quantity)}
	candidate.ground_parts = {}
	candidate.cells = {}
	candidate.coverage = {}
	if not validate(candidate):
		return false
	_commit_owned(record, candidate)
	return true


static func validate(record: Dictionary) -> bool:
	if not _canonical_source_valid(record):
		return false
	for key: String in ["flight_parts", "ground_parts", "cells", "coverage"]:
		if not record.has(key) or not record[key] is Dictionary:
			return false
	var ledger: Dictionary = record.ledger
	return _ownership_valid(record, int(ledger.flight_quantity), int(ledger.deposited_quantity))


## The child receives floor(parent/2); the odd unit remains with the parent.
static func split_flight(record: Dictionary, parent_id: int, child_id: int) -> bool:
	if not validate(record) or parent_id <= 0 or child_id <= 0 or parent_id == child_id:
		return false
	if not record.flight_parts.has(parent_id) or record.flight_parts.has(child_id):
		return false
	var parent_quantity: int = record.flight_parts[parent_id]
	if parent_quantity < 2:
		return false
	var child_quantity: int = parent_quantity >> 1
	var candidate := record.duplicate(true)
	candidate.flight_parts[parent_id] = parent_quantity - child_quantity
	candidate.flight_parts[child_id] = child_quantity
	if not validate(candidate):
		return false
	_commit_owned(record, candidate)
	return true


## Deposits all of one branch by default. Only a trail part may deposit a proper
## partial amount, leaving the rest owned by the same flight entity.
static func deposit_flight(
	record: Dictionary,
	entity_id: int,
	part_id: int,
	selected_value: Variant,
	footprint: Dictionary,
	tick: int,
	expiry_tick: int,
	trail: bool = false,
	amount: int = -1
) -> int:
	if not validate(record) or entity_id <= 0 or part_id <= 0 or record.ground_parts.has(part_id):
		return -1
	if not record.flight_parts.has(entity_id) or not HexFootprint.validate(footprint) or tick < 0 or expiry_tick <= tick:
		return -1
	var selected := _canonical_selected(selected_value)
	if selected.is_empty():
		return -1
	var branch_quantity: int = record.flight_parts[entity_id]
	var moved: int = branch_quantity if amount == -1 else amount
	if moved <= 0 or moved > branch_quantity or (moved < branch_quantity and not trail):
		return -1
	var candidate := record.duplicate(true)
	var ledger_result: int = StrengthBudget.deposit_quantity(candidate.ledger, moved)
	if ledger_result != moved:
		return -1
	if moved == branch_quantity:
		candidate.flight_parts.erase(entity_id)
	else:
		candidate.flight_parts[entity_id] = branch_quantity - moved
	var allocations := _equal_allocations(selected, moved)
	var coverage := {}
	for cell: Vector2i in selected:
		coverage[cell] = 1
	candidate.ground_parts[part_id] = {
		"quantity": moved,
		"cells": allocations,
		"coverage": coverage,
		"footprint": footprint.duplicate(true),
		"created": tick,
		"expiry_tick": expiry_tick,
		"trail": trail,
	}
	_rebuild_ground_aggregates(candidate)
	if not validate(candidate):
		return -1
	_commit_owned(record, candidate)
	return moved


static func expire_flight(record: Dictionary, entity_id: int, amount: int = -1) -> int:
	if not validate(record) or entity_id <= 0 or not record.flight_parts.has(entity_id):
		return -1
	var branch_quantity: int = record.flight_parts[entity_id]
	var moved: int = branch_quantity if amount == -1 else amount
	if moved <= 0 or moved > branch_quantity:
		return -1
	var candidate := record.duplicate(true)
	if StrengthBudget.expire_quantity(candidate.ledger, moved, true) != moved:
		return -1
	if moved == branch_quantity:
		candidate.flight_parts.erase(entity_id)
	else:
		candidate.flight_parts[entity_id] = branch_quantity - moved
	if not validate(candidate):
		return -1
	_commit_owned(record, candidate)
	return moved


static func expire_ground(record: Dictionary, part_id: int, amount: int = -1) -> int:
	if not validate(record) or part_id <= 0 or not record.ground_parts.has(part_id):
		return -1
	var source_part: Dictionary = record.ground_parts[part_id]
	var part_quantity: int = source_part.quantity
	var moved: int = part_quantity if amount == -1 else amount
	if moved <= 0 or moved > part_quantity:
		return -1
	var candidate := record.duplicate(true)
	if StrengthBudget.expire_quantity(candidate.ledger, moved, false) != moved:
		return -1
	if moved == part_quantity:
		candidate.ground_parts.erase(part_id)
	else:
		var remaining_part: Dictionary = candidate.ground_parts[part_id]
		remaining_part.quantity = part_quantity - moved
		remaining_part.cells = _ground_allocations(source_part.cells, source_part.coverage, part_quantity - moved)
	_rebuild_ground_aggregates(candidate)
	if not validate(candidate):
		return -1
	_commit_owned(record, candidate)
	return moved


## Called after StrengthBudget.consume_pair/consume_remaining has already reduced
## ledger totals. The supplied old totals prove that the still-stale part maps
## describe the exact pre-contact ownership state.
static func retile_after_contact(record: Dictionary, old_flight_quantity: int, old_ground_quantity: int) -> bool:
	if old_flight_quantity < 0 or old_ground_quantity < 0 or not _canonical_source_valid(record):
		return false
	if not _ownership_valid(record, old_flight_quantity, old_ground_quantity):
		return false
	var ledger: Dictionary = record.ledger
	var new_flight_quantity: int = ledger.flight_quantity
	var new_ground_quantity: int = ledger.deposited_quantity
	if new_flight_quantity < 0 or new_ground_quantity < 0:
		return false
	var consumed_delta: int = old_flight_quantity + old_ground_quantity - new_flight_quantity - new_ground_quantity
	if consumed_delta < 0:
		return false
	var expected_flight: int = maxi(0, old_flight_quantity - consumed_delta)
	var expected_ground: int = old_ground_quantity - maxi(0, consumed_delta - old_flight_quantity)
	if new_flight_quantity != expected_flight or new_ground_quantity != expected_ground:
		return false

	var candidate := record.duplicate(true)
	candidate.flight_parts = _proportional_map(candidate.flight_parts, new_flight_quantity)
	var ground_quantities := {}
	for part_id: int in _sorted_int_keys(candidate.ground_parts):
		ground_quantities[part_id] = int(candidate.ground_parts[part_id].quantity)
	var new_ground_quantities := _proportional_map(ground_quantities, new_ground_quantity)
	for part_id: int in _sorted_int_keys(candidate.ground_parts):
		if not new_ground_quantities.has(part_id):
			candidate.ground_parts.erase(part_id)
			continue
		var ground_part: Dictionary = candidate.ground_parts[part_id]
		var new_part_quantity: int = new_ground_quantities[part_id]
		ground_part.quantity = new_part_quantity
		ground_part.cells = _ground_allocations(ground_part.cells, ground_part.coverage, new_part_quantity)
	_rebuild_ground_aggregates(candidate)
	if not validate(candidate):
		return false
	_commit_owned(record, candidate)
	return true


static func _canonical_source_valid(record: Dictionary) -> bool:
	for name: String in ["source", "strength", "budget"]:
		if not record.has(name) or typeof(record[name]) != TYPE_INT:
			return false
	if not record.has("ledger") or not record.ledger is Dictionary:
		return false
	var ledger: Dictionary = record.ledger
	return (
		StrengthBudget.validate(ledger)
		and bool(ledger.get("partitioned", false))
		and int(record.source) == int(ledger.source_id)
		and int(record.strength) == int(ledger.initial_strength)
		and int(record.budget) == int(ledger.budget)
	)


static func _ownership_valid(record: Dictionary, expected_flight: int, expected_ground: int) -> bool:
	for key: String in ["flight_parts", "ground_parts", "cells", "coverage"]:
		if not record.has(key) or not record[key] is Dictionary:
			return false
	var ledger: Dictionary = record.ledger
	var budget: int = ledger.budget
	if expected_flight < 0 or expected_ground < 0 or expected_flight > budget or expected_ground > budget - expected_flight:
		return false
	var flight_total := 0
	for entity_value: Variant in record.flight_parts:
		if typeof(entity_value) != TYPE_INT:
			return false
		var entity_id: int = entity_value
		var quantity_value: Variant = record.flight_parts[entity_id]
		if entity_id <= 0 or typeof(quantity_value) != TYPE_INT or int(quantity_value) <= 0 or int(quantity_value) > expected_flight - flight_total:
			return false
		flight_total += int(quantity_value)
	if flight_total != expected_flight:
		return false

	var ground_total := 0
	for part_value: Variant in record.ground_parts:
		if typeof(part_value) != TYPE_INT:
			return false
		var part_id: int = part_value
		if part_id <= 0:
			return false
		var raw_part: Variant = record.ground_parts[part_id]
		if not raw_part is Dictionary:
			return false
		var part: Dictionary = raw_part
		if not _ground_part_valid(part):
			return false
		if int(part.quantity) > expected_ground - ground_total:
			return false
		ground_total += int(part.quantity)
	if ground_total != expected_ground:
		return false
	var expected_record := {"ground_parts": record.ground_parts, "cells": {}, "coverage": {}}
	_rebuild_ground_aggregates(expected_record)
	return record.cells == expected_record.cells and record.coverage == expected_record.coverage


static func _ground_part_valid(part: Dictionary) -> bool:
	if part.size() != 7:
		return false
	for name: String in ["quantity", "created", "expiry_tick"]:
		if not part.has(name) or typeof(part[name]) != TYPE_INT:
			return false
	if int(part.quantity) <= 0 or int(part.quantity) > StrengthBudget.MAX_PARTITIONED_BUDGET or int(part.created) < 0 or int(part.expiry_tick) <= int(part.created):
		return false
	if not part.has("trail") or typeof(part.trail) != TYPE_BOOL:
		return false
	if not part.has("footprint") or not part.footprint is Dictionary or not HexFootprint.validate(part.footprint):
		return false
	if not part.has("cells") or not part.cells is Dictionary or not part.has("coverage") or not part.coverage is Dictionary:
		return false
	if (
		(part.cells as Dictionary).is_empty()
		or (part.cells as Dictionary).size() > MAX_SELECTED_CELLS
		or (part.cells as Dictionary).size() != (part.coverage as Dictionary).size()
	):
		return false
	var unallocated: int = part.quantity
	for cell_value: Variant in part.coverage:
		if not cell_value is Vector2i or typeof(part.coverage[cell_value]) != TYPE_INT or int(part.coverage[cell_value]) != 1:
			return false
		if not part.cells.has(cell_value) or typeof(part.cells[cell_value]) != TYPE_INT or int(part.cells[cell_value]) < 0:
			return false
		var allocation: int = part.cells[cell_value]
		if allocation > unallocated:
			return false
		unallocated -= allocation
	for cell_value: Variant in part.cells:
		if not cell_value is Vector2i or not part.coverage.has(cell_value):
			return false
	return unallocated == 0


static func _canonical_selected(selected_value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not selected_value is Array or (selected_value as Array).is_empty() or (selected_value as Array).size() > MAX_SELECTED_CELLS:
		return result
	var seen := {}
	for cell_value: Variant in selected_value:
		if not cell_value is Vector2i or seen.has(cell_value):
			return []
		seen[cell_value] = true
		result.append(cell_value)
	result.sort_custom(Grid._cell_less)
	return result


static func _equal_allocations(selected: Array[Vector2i], total: int) -> Dictionary:
	var weights := {}
	for cell: Vector2i in selected:
		weights[cell] = 1
	return _ground_allocations(weights, weights, total)


static func _ground_allocations(old_values: Dictionary, coverage: Dictionary, new_total: int) -> Dictionary:
	var positive := _proportional_map(old_values, new_total)
	var result := {}
	for cell: Vector2i in _sorted_cell_keys(coverage):
		result[cell] = int(positive.get(cell, 0))
	return result


## Stable cumulative proportional allocation. Keys whose rounded allocation is
## zero are omitted for entity/part ownership maps; ground coverage is stored in
## a separate map and the ground allocator re-adds zero cell allocations.
static func _proportional_map(old_values: Dictionary, new_total: int) -> Dictionary:
	var result := {}
	if new_total <= 0 or old_values.is_empty():
		return result
	var old_total := 0
	for value: Variant in old_values.values():
		if typeof(value) != TYPE_INT or int(value) < 0:
			return {}
		old_total += int(value)
	if old_total <= 0:
		return {}
	var keys: Array = old_values.keys()
	keys.sort_custom(_variant_key_less)
	var cumulative_old := 0
	var cumulative_new := 0
	for key: Variant in keys:
		cumulative_old += int(old_values[key])
		@warning_ignore("integer_division")
		var next_cumulative: int = new_total * cumulative_old / old_total
		var amount: int = next_cumulative - cumulative_new
		cumulative_new = next_cumulative
		if amount > 0:
			result[key] = amount
	return result


static func _rebuild_ground_aggregates(record: Dictionary) -> void:
	var cells := {}
	var coverage := {}
	for part_id: int in _sorted_int_keys(record.ground_parts):
		var part: Dictionary = record.ground_parts[part_id]
		for cell: Vector2i in _sorted_cell_keys(part.coverage):
			coverage[cell] = 1
			cells[cell] = int(cells.get(cell, 0)) + int(part.cells.get(cell, 0))
	record.cells = cells
	record.coverage = coverage


static func _sorted_int_keys(values: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for key: Variant in values:
		if typeof(key) == TYPE_INT:
			result.append(key)
	result.sort()
	return result


static func _sorted_cell_keys(values: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key: Variant in values:
		if key is Vector2i:
			result.append(key)
	result.sort_custom(Grid._cell_less)
	return result


static func _variant_key_less(first: Variant, second: Variant) -> bool:
	if first is Vector2i and second is Vector2i:
		return Grid._cell_less(first, second)
	return int(first) < int(second)


static func _commit_owned(record: Dictionary, candidate: Dictionary) -> void:
	record.ledger = candidate.ledger
	record.flight_parts = candidate.flight_parts
	record.ground_parts = candidate.ground_parts
	record.cells = candidate.cells
	record.coverage = candidate.coverage

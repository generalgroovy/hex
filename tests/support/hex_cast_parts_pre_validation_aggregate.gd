extends RefCounted

# Frozen pre-validation-aggregation validator. These function bodies are copied
# verbatim from the preceding HexCastParts, including sorted temporary rebuild.
# No function calls the production Parts validator or aggregation implementation.
const StrengthBudget = preload("res://src/sim/combat/strength_budget.gd")
const HexFootprint = preload("res://src/sim/hex/hex_footprint.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const MAX_SELECTED_CELLS: int = 511

static func validate(record: Dictionary) -> bool:
	if not _canonical_source_valid(record):
		return false
	for key: String in ["flight_parts", "ground_parts", "cells", "coverage"]:
		if not record.has(key) or not record[key] is Dictionary:
			return false
	var ledger: Dictionary = record.ledger
	return _ownership_valid(record, int(ledger.flight_quantity), int(ledger.deposited_quantity))


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

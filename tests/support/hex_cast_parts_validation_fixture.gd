extends RefCounted
@warning_ignore_start("integer_division")

const Budget = preload("res://src/sim/combat/strength_budget.gd")
const Footprint = preload("res://src/sim/hex/hex_footprint.gd")
const Before = preload("res://tests/support/hex_cast_parts_pre_validation_aggregate.gd")


# Synthetic, legal ledger fixtures, not paid gameplay or capacity evidence.
# Setup uses the frozen aggregate builder, never the optimized validator.
static func record(part_count: int, cells_per_part: int, overlap: bool, reverse_order: bool = false) -> Dictionary:
	var ground := mini(600, part_count * 8)
	var ledger := Budget.make_partitioned(7001, 15, 600)
	if ground > 0: Budget.deposit_quantity(ledger, ground)
	var result := {"source": 7001, "strength": 15, "budget": 600, "ledger": ledger,
		"flight_parts": {7101: 600 - ground} if ground < 600 else {},
		"ground_parts": {}, "cells": {}, "coverage": {}}
	for position: int in part_count:
		var index := part_count - 1 - position if reverse_order else position
		var quantity := (index + 1) * ground / part_count - index * ground / part_count
		var cells := {}
		var coverage := {}
		for cell_position: int in cells_per_part:
			var cell_index := cells_per_part - 1 - cell_position if reverse_order else cell_position
			var cell := Vector2i(cell_index - 256, 0 if overlap else index)
			cells[cell] = (cell_index + 1) * quantity / cells_per_part - cell_index * quantity / cells_per_part
			coverage[cell] = 1
		result.ground_parts[8001 + index] = {"quantity": quantity, "cells": cells, "coverage": coverage,
			"footprint": Footprint.disk(Vector2i.ZERO, 64_000), "created": 12, "expiry_tick": 144, "trail": true}
	Before._rebuild_ground_aggregates(result)
	return result

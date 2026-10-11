extends RefCounted

# Frozen byte-for-byte control-flow copy of HexChemistrySnapshot._trusted_cells
# before the 2026-09-23 empty-record candidate. Keep this implementation
# independent: performance/equivalence probes compare the runtime candidate to
# this old function rather than recreating the candidate's branch.
const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const MAX_TOPOLOGY_CELLS := 4096


static func trusted_cells(world: HexChemistryWorld) -> Array[Vector2i]:
	if world.cells.is_empty() or world.cells.size() > MAX_TOPOLOGY_CELLS or not _world_point_valid(world.origin):
		return []
	var result: Array[Vector2i] = []
	var material_layers: Array[String] = World.material_layers()
	for key: Variant in world.cells:
		if not key is Vector2i:
			return []
		var cell: Vector2i = key
		var record_value: Variant = world.cells[cell]
		if not record_value is Dictionary:
			return []
		var record: Dictionary = record_value
		for property_name: String in ["terrain", "elevation", "structure"]:
			if not record.has(property_name) or typeof(record[property_name]) != TYPE_INT:
				return []
		for layer: String in material_layers:
			if not record.has(layer) or not record[layer] is Dictionary:
				return []
		result.append(cell)
	result.sort_custom(Grid._cell_less)
	return result


static func _world_point_valid(point: Vector2i) -> bool:
	return absi(point.x) <= Grid.MAX_ABS_QUERY_COORDINATE and absi(point.y) <= Grid.MAX_ABS_QUERY_COORDINATE

extends RefCounted

# Frozen whole_cell_polygon implementation before the October 11 geometry cache.
# Only the pure geometry method is copied; no gameplay or optimized cache helper.
const Grid = preload("res://src/sim/hex/hex_grid.gd")
var origin := Vector2i.ZERO


func whole_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var result := PackedVector2Array()
	for vertex: Vector2i in Grid.vertices(cell): result.append(Vector2(vertex + origin))
	return result

extends RefCounted

# Test-only checked specialization for the canonical HexGrid order already
# produced by HexChemistrySnapshot._trusted_cells(). Non-canonical input and
# derived worlds retain the actual public configure_geometry() path.
const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")


static func construct(requested_origin: Vector2i, eligible_cells: Array[Vector2i]) -> HexChemistryWorld:
	var world: HexChemistryWorld = World.new()
	return world if configure_geometry(world, requested_origin, eligible_cells) else null


static func configure_geometry(world: HexChemistryWorld, requested_origin: Vector2i, eligible_cells: Array[Vector2i]) -> bool:
	if world == null:
		return false
	if world.get_script() != World or not _strictly_ordered(eligible_cells):
		return world.configure_geometry(requested_origin, eligible_cells)
	if not Grid._query_point_valid(requested_origin) or eligible_cells.is_empty() or eligible_cells.size() > World.MAX_CELLS \
		or not world.casts.is_empty() or not world.products.is_empty() or not world.pending.is_empty() \
		or not world.sources.is_empty() or int(world.metrics.matter_paid) != 0:
		return false

	var prepared := {}
	var empty_cell: Dictionary = World._new_empty_cell()
	for cell: Vector2i in eligible_cells:
		if absi(cell.x) > 256 or absi(cell.y) > 256 or not Grid._query_point_valid(Grid.center(cell) + requested_origin):
			return false
		prepared[cell] = empty_cell.duplicate(true)
	world.origin = requested_origin
	world.cells = prepared
	world._render_polygon_revision = -1
	world._render_polygons.clear()
	return true


static func _strictly_ordered(cells: Array[Vector2i]) -> bool:
	for index: int in range(1, cells.size()):
		if not Grid._cell_less(cells[index - 1], cells[index]):
			return false
	return true

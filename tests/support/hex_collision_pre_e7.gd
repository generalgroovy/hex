extends RefCounted

# Frozen immediately before E7; original hex_collision_world.gd SHA-256:
# 4a347f9e3ca650f4cc5ce31673c6177e6da23ce4df9292f95bbf8668e3084a07
# These two configuration methods retain the predecessor's complete algorithm.
# Only destination-field qualification and the internal oracle call differ.
# They never invoke the candidate's configuration or topology-admission helper.
# Geometry/query methods are unchanged dependencies on the destination class.

static func configure_hex_sets(destination: HexCollisionWorld, origin: Vector2i, topology: Array[Vector2i], movement_solid: Array[Vector2i], cover_cells: Array[Vector2i]) -> bool:
	if topology.is_empty() or topology.size() > HexChemistryWorld.MAX_CELLS: return false
	if absi(origin.x) > HexGrid.MAX_ABS_QUERY_COORDINATE or absi(origin.y) > HexGrid.MAX_ABS_QUERY_COORDINATE: return false
	var ordered := topology
	if topology != destination._topology:
		ordered = topology.duplicate()
		ordered.sort_custom(HexGrid._cell_less)
	if not destination._topology.is_empty() and (ordered != destination._topology or origin != destination.grid_origin): return false
	var indices := {} if destination._indices.is_empty() else destination._indices
	for index: int in (ordered.size() if destination._indices.is_empty() else 0):
		if indices.has(ordered[index]): return false
		if absi(ordered[index].x) > 256 or absi(ordered[index].y) > 256: return false
		var center := origin + HexGrid.center(ordered[index])
		if absi(center.x) > HexGrid.MAX_ABS_QUERY_COORDINATE or absi(center.y) > HexGrid.MAX_ABS_QUERY_COORDINATE: return false
		indices[ordered[index]] = index
	var solid := {}
	for cell: Vector2i in movement_solid:
		if not indices.has(cell) or solid.has(cell): return false
		solid[cell] = int(indices[cell])
	var cover := {}
	for cell: Vector2i in cover_cells:
		if not indices.has(cell) or cover.has(cell): return false
		cover[cell] = int(indices[cell])
	for cell: Vector2i in solid:
		if not cover.has(cell): return false
	if ordered == destination._topology and origin == destination.grid_origin and solid == destination._solid and cover == destination._cover: return true
	destination._indices = indices
	destination.grid_origin = origin
	destination._topology = ordered
	destination._solid = solid
	destination._cover = cover
	destination._solid_ordered = solid.keys()
	destination._solid_ordered.sort_custom(HexGrid._cell_less)
	destination._cover_ordered = cover.keys()
	destination._cover_ordered.sort_custom(HexGrid._cell_less)
	destination._faces.clear()
	destination._components.clear()
	destination._actor_ignored.clear()
	for cell: Vector2i in ordered:
		if not solid.has(cell): continue
		for face: int in 6:
			# A later-four cover neighbor is transparent to actors, so the shared
			# Rampart face remains a real movement and attachment boundary.
			if solid.has(cell + HexConvexGeometry.NEIGHBORS[face]): continue
			destination._faces[HexCollisionWorld.FACE_ID_BASE + int(indices[cell]) * 8 + face] = {"cell": cell, "face": face}
		if destination._components.has(cell): continue
		var component: Array[Vector2i] = [cell]
		destination._components[cell] = cell
		var cursor := 0
		while cursor < component.size():
			for neighbor: Vector2i in HexGrid.neighbors(component[cursor]):
				if solid.has(neighbor) and not destination._components.has(neighbor):
					destination._components[neighbor] = cell
					component.append(neighbor)
			cursor += 1
	return true


static func set_hex_surfaces(destination: HexCollisionWorld, authority: HexChemistryWorld, tick: int) -> bool:
	var cover := {}
	var movement_solid := {}
	for product: Dictionary in authority.products.values():
		if int(product.recipe_wire_id) not in [301, 305, 306, 307, 329] or tick < int(product.active_tick) or tick >= int(product.decay_tick) or int(product.get("health", 0)) <= 0: continue
		for cell: Vector2i in HexChemistryWorld.coverage(product):
			cover[cell] = true
			if int(product.recipe_wire_id) == 301: movement_solid[cell] = true
	var topology: Array[Vector2i] = []
	var solid_cells: Array[Vector2i] = []
	var cover_cells: Array[Vector2i] = []
	var concrete: bool = authority.get_script().resource_path == "res://src/sim/hex/hex_chemistry_world.gd"
	var sealed: HexCellTopology = authority.immutable_topology() if concrete else null
	if sealed != null and sealed == destination._sealed_topology and not destination._topology.is_empty():
		topology = destination._topology
	else:
		var keys: Array = authority.cell_keys() if concrete else authority.cells.keys()
		for cell: Vector2i in keys: topology.append(cell)
	for cell: Vector2i in movement_solid: solid_cells.append(cell)
	for cell: Vector2i in cover: cover_cells.append(cell)
	if not configure_hex_sets(destination, authority.origin, topology, solid_cells, cover_cells): return false
	destination._chemistry = authority
	destination._sealed_topology = sealed
	return true


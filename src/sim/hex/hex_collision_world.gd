class_name HexCollisionWorld
extends ReactionMovementWorld

const ChemistryWorld = preload("res://src/sim/hex/hex_chemistry_world.gd")
const CellTopology = preload("res://src/sim/hex/hex_cell_topology.gd")
const FACE_ID_BASE := 200_000_000
var grid_origin := Vector2i.ZERO
# Actor movement and attachment retain the legacy Rampart-only contract.
var _solid: Dictionary = {}
# Projectiles and sight use every authored physical cover recipe.
var _cover: Dictionary = {}
var _faces: Dictionary = {}
var _components: Dictionary = {}
var _actor_ignored: Dictionary = {}
var _topology: Array[Vector2i] = []
var _chemistry: HexChemistryWorld = null
var _sealed_topology: HexCellTopology = null
var _indices: Dictionary = {}
var _solid_ordered: Array = []
var _cover_ordered: Array = []

func _init(source: CollisionWorld = null) -> void:
	super(source)

func configure_hexes(origin: Vector2i, topology: Array[Vector2i], occupied: Array[Vector2i]) -> bool:
	return _configure_hex_sets(origin, topology, occupied, occupied)

func _configure_hex_sets(origin: Vector2i, topology: Array[Vector2i], movement_solid: Array[Vector2i], cover_cells: Array[Vector2i], authority: HexChemistryWorld = null) -> bool:
	if topology.is_empty() or topology.size() > HexChemistryWorld.MAX_CELLS: return false
	if absi(origin.x) > HexGrid.MAX_ABS_QUERY_COORDINATE or absi(origin.y) > HexGrid.MAX_ABS_QUERY_COORDINATE: return false
	var ordered := topology
	var sealed := _owned_topology(authority)
	var indices: Dictionary
	if sealed != null and origin == authority.origin and topology == sealed.numeric_cells():
		# This actual concrete authority owns geometry admitted at construction.
		# A fresh collision can borrow immutable full-map order/indices without
		# sorting/revalidating every blank cell. No caller-supplied trust flag or
		# context is accepted; mismatching ordinary inputs retain full validation.
		ordered = sealed.numeric_cells()
		indices = sealed.cell_indices()
	else:
		if topology != _topology:
			ordered = topology.duplicate()
			ordered.sort_custom(HexGrid._cell_less)
		indices = {} if _indices.is_empty() else _indices
		for index: int in (ordered.size() if _indices.is_empty() else 0):
			if indices.has(ordered[index]): return false
			if absi(ordered[index].x) > HexGrid.MAX_ABS_CELL_COORDINATE or absi(ordered[index].y) > HexGrid.MAX_ABS_CELL_COORDINATE: return false
			var center := origin + HexGrid.center(ordered[index])
			if absi(center.x) > HexGrid.MAX_ABS_QUERY_COORDINATE or absi(center.y) > HexGrid.MAX_ABS_QUERY_COORDINATE: return false
			indices[ordered[index]] = index
	if not _topology.is_empty() and (ordered != _topology or origin != grid_origin): return false
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
	if ordered == _topology and origin == grid_origin and solid == _solid and cover == _cover: return true
	_indices = indices
	grid_origin = origin
	_topology = ordered
	_solid = solid
	_cover = cover
	_solid_ordered = solid.keys()
	_solid_ordered.sort_custom(HexGrid._cell_less)
	_cover_ordered = cover.keys()
	_cover_ordered.sort_custom(HexGrid._cell_less)
	_faces.clear()
	_components.clear()
	_actor_ignored.clear()
	# Same numeric subset/order as the preceding full-topology loop. Stable
	# face IDs still use full topology indices, never sparse positions.
	for cell: Vector2i in _solid_ordered:
		for face: int in 6:
			# A later-four cover neighbor is transparent to actors, so the shared
			# Rampart face remains a real movement and attachment boundary.
			if solid.has(cell + HexConvexGeometry.NEIGHBORS[face]): continue
			_faces[FACE_ID_BASE + int(indices[cell]) * 8 + face] = {"cell": cell, "face": face}
		if _components.has(cell): continue
		var component: Array[Vector2i] = [cell]
		_components[cell] = cell
		var cursor := 0
		while cursor < component.size():
			for neighbor: Vector2i in HexGrid.neighbors(component[cursor]):
				if solid.has(neighbor) and not _components.has(neighbor):
					_components[neighbor] = cell
					component.append(neighbor)
			cursor += 1
	return true

func set_hex_surfaces(authority: HexChemistryWorld, tick: int) -> bool:
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
	var concrete: bool = authority.get_script() == ChemistryWorld
	var sealed := _owned_topology(authority)
	if sealed != null:
		topology = sealed.numeric_cells()
	else:
		var keys: Array = authority.cell_keys() if concrete else authority.cells.keys()
		for cell: Vector2i in keys: topology.append(cell)
	for cell: Vector2i in movement_solid: solid_cells.append(cell)
	for cell: Vector2i in cover: cover_cells.append(cell)
	if not _configure_hex_sets(authority.origin, topology, solid_cells, cover_cells, authority): return false
	_chemistry = authority
	_sealed_topology = sealed
	return true

func _owned_topology(authority: HexChemistryWorld) -> HexCellTopology:
	# Read helpers are virtual; an extension cannot claim a different world's
	# valid handle while concealing mutable, malformed coordinate membership.
	if authority == null or authority.get_script() != ChemistryWorld: return null
	var sealed := authority.immutable_topology()
	return sealed if sealed != null and sealed.get_script() == CellTopology else null

func refresh_surfaces(tick: int) -> bool:
	return true if _chemistry == null else set_hex_surfaces(_chemistry, tick)

func begin_actor(position: Vector2i, radius: int) -> void:
	_actor_ignored.clear()
	var inside_components := {}
	for cell: Vector2i in _solid:
		if not _cell_in_query_bounds(cell, position, position, radius): continue
		if HexConvexGeometry.box_overlaps(position, radius, cell, grid_origin): inside_components[_components[cell]] = true
	# A structure formed beneath an actor allows exit through its connected
	# component. Exemption ends on the first wholly clear tick; no teleport,
	# timer refresh, expanded body, or permanently passable pillar is introduced.
	for cell: Vector2i in _solid:
		if inside_components.has(_components[cell]): _actor_ignored[cell] = true

func obstacle_view() -> Array[Obstacle]:
	return base_world.obstacle_view()

func _candidate_obstacles(minimum: Vector2i, maximum: Vector2i) -> Array[Obstacle]:
	return base_world._candidate_obstacles(minimum, maximum)

func can_occupy(position: Vector2i, radius: int, ignored_obstacle_id: int = -1) -> bool:
	if not base_world.can_occupy(position, radius, ignored_obstacle_id): return false
	for cell: Vector2i in _solid:
		if not _cell_in_query_bounds(cell, position, position, radius): continue
		if HexConvexGeometry.box_overlaps(position, radius, cell, grid_origin): return false
	return true

func move_box(position: Vector2i, delta: Vector2i, radius: int) -> MoveResult:
	if _solid.is_empty(): return base_world.move_box(position, delta, radius)
	var point := position
	var remaining := delta
	var normal := Vector2i.ZERO
	var surface := 0
	var constraints: Array[Vector2i] = []
	for iteration: int in 3:
		if remaining == Vector2i.ZERO: break
		# Preserve worldbone's established axis resolver, strict tangency and
		# overlapping-start escape. A distant pillar cannot change those rules.
		var base_result := base_world.move_box(point, remaining, radius)
		var hit := _sweep(point, base_result.position, radius, true)
		if hit.is_empty():
			if constraints.is_empty(): return base_result
			point = base_result.position
			for axis: int in 2:
				if base_result.wall_normal[axis] != 0:
					var axis_normal := Vector2i.ZERO
					axis_normal[axis] = base_result.wall_normal[axis]
					if axis_normal not in constraints: constraints.append(axis_normal)
			break
		var next_point: Vector2i = hit.center
		if hit.has("cell") and HexConvexGeometry.box_overlaps(next_point, radius, hit.cell, grid_origin):
			# A nearest-grid rounded TOI may be less than one fixed unit inside.
			# Separate only that rounding error before the bounded tangent step.
			next_point += Vector2i(signi(hit.normal.x), signi(hit.normal.y))
		var residue := base_result.position - next_point
		if hit.normal not in constraints: constraints.append(hit.normal)
		if surface <= 0 or (int(hit.id) > 0 and int(hit.id) < surface):
			normal = hit.normal
			surface = int(hit.id)
		point = next_point
		if hit.normal == Vector2i.ZERO: break
		var projected := HexConvexGeometry.clip_motion(residue, constraints)
		if projected == remaining: break
		remaining = projected
	var result := MoveResult.new(point, normal, surface)
	result.blocking_normals = constraints
	return result

func hex_wall_contact(start: Vector2i, finish: Vector2i, radius: int) -> Dictionary:
	return _sweep(start, finish, radius, false)

func hex_segment_clear(start: Vector2i, finish: Vector2i) -> bool:
	if not ContinuousContact.wall_contact(start, finish, 0, base_world).is_empty(): return false
	return hex_pillar_segment_clear(start, finish)


# Presentation LOS deliberately calls this narrower query. The immutable campus
# collision also contains low_never_occludes walls, so the combined gameplay
# query above cannot represent the authored POV policy by itself.
func hex_pillar_segment_clear(start: Vector2i, finish: Vector2i) -> bool:
	for cell: Vector2i in _cover:
		if not _cell_in_query_bounds(cell, start, finish, 0): continue
		if bool(HexFootprint._cell_segment_interval(cell, grid_origin, start, finish).get("hit", false)): return false
	return true

func nearby_hex_face(position: Vector2i, radius: int, tolerance: int, surface_id: int = 0) -> Dictionary:
	var best := {}
	for id: int in _faces:
		if surface_id > 0 and id != surface_id: continue
		var face: Dictionary = _faces[id]
		if _actor_ignored.has(face.cell): continue
		if not _cell_in_query_bounds(face.cell, position, position, maxi(0, radius) + maxi(0, tolerance)): continue
		var contact := HexConvexGeometry.nearby_face(position, radius, tolerance, face.cell, grid_origin, int(face.face))
		if contact.is_empty(): continue
		if best.is_empty() or float(contact.gap) < float(best.gap) or (float(contact.gap) == float(best.gap) and id < int(best.id)):
			contact.id = id
			best = contact
	return best

func has_live_surface(surface_id: int) -> bool:
	return _faces.has(surface_id) and not _actor_ignored.has(_faces[surface_id].cell)

func hex_occluders() -> Array[Array]:
	var result: Array[Array] = []
	for cell: Vector2i in _cover_ordered:
		result.append(HexConvexGeometry.polygon(cell, grid_origin))
	return result

func _sweep(start: Vector2i, finish: Vector2i, radius: int, box: bool) -> Dictionary:
	var best: Dictionary = {} if box else ContinuousContact.wall_contact(start, finish, radius, base_world)
	var occupied: Dictionary = _solid if box else _cover
	for cell: Vector2i in (_solid_ordered if box else _cover_ordered):
		if box and _actor_ignored.has(cell): continue
		if not _cell_in_query_bounds(cell, start, finish, radius): continue
		var hit := HexConvexGeometry.sweep_box(start, finish, radius, cell, grid_origin) if box else HexConvexGeometry.sweep_circle(start, finish, radius, cell, grid_origin)
		if hit.is_empty(): continue
		hit.cell = cell
		var face := int(hit.face)
		var id := FACE_ID_BASE + int(occupied[cell]) * 8 + maxi(0, face)
		# Internal faces never become attachment targets. They still participate
		# in convex occupancy when a sweep begins inside an unexpected solid.
		if not _faces.has(id) or face < 0: hit.runnable = false
		if not best.is_empty() and (float(hit.fraction) > float(best.fraction) or (float(hit.fraction) == float(best.fraction) and id >= int(best.get("sort_id", best.id)))): continue
		hit.sort_id = id
		hit.id = id if bool(hit.runnable) else 0
		best = hit
	return best


## Conservative closed AABB rejection only. Keep one fixed unit of slack for
## Float64 boundary tolerances; every surviving candidate uses the original
## exact narrow phase and stable tie-break. No cache or quantized movement.
func _cell_in_query_bounds(cell: Vector2i, start: Vector2i, finish: Vector2i, padding: int) -> bool:
	if padding < 0: return true # Preserve defensive behavior for invalid callers.
	var center := HexGrid.center(cell) + grid_origin
	var x_margin := HexGrid.HALF_WIDTH + padding + 1
	var y_margin := HexGrid.HALF_HEIGHT + padding + 1
	return center.x + x_margin >= mini(start.x, finish.x) \
		and center.x - x_margin <= maxi(start.x, finish.x) \
		and center.y + y_margin >= mini(start.y, finish.y) \
		and center.y - y_margin <= maxi(start.y, finish.y)

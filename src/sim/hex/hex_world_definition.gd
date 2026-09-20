class_name HexWorldDefinition
extends RefCounted

# Trusted local topology. Snapshots reference its hash; they never supply a map.
const SCHEMA := 2
const CLEARANCE := 18_000
const MAX_CELLS := HexChemistryWorld.MAX_CELLS
var origin := Vector2i.ZERO
var eligible_cells: Array[Vector2i] = []
var map_hash := ""
var definition_hash := ""
# district_bounds remains a compatibility alias for callers from the original
# Crucible-only topology. Both rectangles now describe the collision world.
var world_bounds := Rect2i()
var district_bounds := Rect2i()

static func from_campus(layout: SanctumCampusLayout) -> HexWorldDefinition:
	if layout == null or layout.content_hash.is_empty(): return null
	var result := HexWorldDefinition.new()
	result.map_hash = layout.content_hash
	var collision := layout.build_collision_world()
	var playable_top := layout.reserved_ui_top * SimConfig.FIXED_SCALE
	result.world_bounds = Rect2i(Vector2i(0, playable_top), Vector2i(collision.width, collision.height - playable_top))
	result.district_bounds = result.world_bounds
	if result.world_bounds.size.x <= 0 or result.world_bounds.size.y <= 0: return null
	var bounds := result.world_bounds
	var minimum := HexGrid.world_to_cell(bounds.position)
	var maximum := minimum
	for point: Vector2i in [bounds.position, bounds.end, Vector2i(bounds.end.x, bounds.position.y), Vector2i(bounds.position.x, bounds.end.y)]:
		var cell := HexGrid.world_to_cell(point)
		minimum = minimum.min(cell)
		maximum = maximum.max(cell)
	var expanded_obstacles: Array[Rect2i] = []
	for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
		expanded_obstacles.append(Rect2i(
			obstacle.minimum_x - CLEARANCE,
			obstacle.minimum_y - CLEARANCE,
			obstacle.maximum_x - obstacle.minimum_x + 2 * CLEARANCE,
			obstacle.maximum_y - obstacle.minimum_y + 2 * CLEARANCE,
		))
	for q: int in range(minimum.x - 2, maximum.x + 3):
		for r: int in range(minimum.y - 2, maximum.y + 3):
			var cell := Vector2i(q, r)
			var polygon := HexGrid.vertices(cell)
			var allowed := true
			for point: Vector2i in polygon:
				if point.x < bounds.position.x or point.y < bounds.position.y or point.x > bounds.end.x or point.y > bounds.end.y:
					allowed = false
			if not allowed: continue
			for rectangle: Rect2i in expanded_obstacles:
				if _overlaps_rectangle(polygon, rectangle):
					allowed = false
					break
			if not allowed: continue
			result.eligible_cells.append(cell)
	if result.eligible_cells.is_empty() or result.eligible_cells.size() > MAX_CELLS: return null
	result.eligible_cells.sort_custom(HexGrid._cell_less)
	var rows: Array = [SCHEMA, result.map_hash, "whole_map", result.world_bounds.position, result.world_bounds.size, HexGrid.LOCAL_VERTICES, result.origin, result.eligible_cells]
	result.definition_hash = CanonicalBytes.sha256_hex(JSON.stringify(HexChemistryWorld._stable(rows)).to_utf8_buffer())
	return result

func create_authority() -> HexChemistryWorld:
	var world := HexChemistryWorld.new()
	if not world.configure_geometry(origin, eligible_cells): return null
	world.chemistry_enabled = true
	return world

func bind_world(world: SimWorld) -> bool:
	if world == null or not world.is_valid() or world.map_hash != map_hash or world.hex_court != null or not world.projectiles.is_empty() or not world.fields.is_empty() or not world.deposits.is_empty() or not world.reactions.is_empty(): return false
	var authority := create_authority()
	if authority == null: return false
	var physics := HexCollisionWorld.new(world.collision)
	if not physics.set_hex_surfaces(authority, world.tick): return false
	authority.collision = physics.base_world
	world.hex_court = authority
	world.collision = physics
	world.reaction_movement = physics
	return true

static func _overlaps_rectangle(polygon: Array[Vector2i], rectangle: Rect2i) -> bool:
	var corners: Array[Vector2i] = [rectangle.position, Vector2i(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2i(rectangle.position.x, rectangle.end.y)]
	var axes: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	for index: int in polygon.size():
		var edge := polygon[(index + 1) % polygon.size()] - polygon[index]
		axes.append(Vector2i(-edge.y, edge.x))
	for axis: Vector2i in axes:
		var low_a: int = 0x7fffffffffffffff
		var high_a: int = -0x7fffffffffffffff
		var low_b: int = low_a
		var high_b: int = high_a
		for point: Vector2i in polygon:
			var projection: int = point.x * axis.x + point.y * axis.y
			low_a = mini(low_a, projection)
			high_a = maxi(high_a, projection)
		for point: Vector2i in corners:
			var projection: int = point.x * axis.x + point.y * axis.y
			low_b = mini(low_b, projection)
			high_b = maxi(high_b, projection)
		if high_a <= low_b or high_b <= low_a: return false
	return true

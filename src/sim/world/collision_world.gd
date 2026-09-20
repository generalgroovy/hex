class_name CollisionWorld
extends RefCounted


class Obstacle:
	extends RefCounted
	signal geometry_changed
	var obstacle_id: int
	var minimum_x: int:
		set(value):
			minimum_x = value
			geometry_changed.emit()
	var minimum_y: int:
		set(value):
			minimum_y = value
			geometry_changed.emit()
	var maximum_x: int:
		set(value):
			maximum_x = value
			geometry_changed.emit()
	var maximum_y: int:
		set(value):
			maximum_y = value
			geometry_changed.emit()
	var vaultable: bool # Reserved legacy geometry metadata; no traversal activation.
	var wall_runnable: bool

	func _init(
		requested_id: int,
		requested_minimum_x: int,
		requested_minimum_y: int,
		requested_maximum_x: int,
		requested_maximum_y: int,
		requested_vaultable: bool = false,
		requested_wall_runnable: bool = true,
	) -> void:
		obstacle_id = requested_id
		minimum_x = requested_minimum_x
		minimum_y = requested_minimum_y
		maximum_x = requested_maximum_x
		maximum_y = requested_maximum_y
		vaultable = requested_vaultable
		wall_runnable = requested_wall_runnable

	func projected_depth(direction: Vector2i) -> int:
		@warning_ignore("integer_division")
		return (
			absi(direction.x) * (maximum_x - minimum_x)
			+ absi(direction.y) * (maximum_y - minimum_y)
		) / SimConfig.FIXED_SCALE


class MoveResult:
	extends RefCounted
	var position: Vector2i
	var wall_normal: Vector2i
	var wall_id: int
	var blocking_normals: Array[Vector2i] = [] # Convex composite constraints; empty preserves axis movement.

	func _init(
		requested_position: Vector2i,
		requested_normal: Vector2i = Vector2i.ZERO,
		requested_wall_id: int = 0,
	) -> void:
		position = requested_position
		wall_normal = requested_normal
		wall_id = requested_wall_id


const OBSTACLE_CELL_SIZE: int = 256_000
const OBSTACLE_INDEX_MINIMUM: int = 16
const MAX_INDEX_ENTRIES: int = 8_192
const MAX_QUERY_CELLS: int = 64

var width: int
var height: int
# Legacy callers may retain and mutate this array. Once exposed, use the
# original linear path permanently: no cache may silently miss such edits.
# Ordinary add_obstacle/move_box/can_occupy usage keeps the fast path private.
var obstacles: Array[Obstacle]:
	get:
		_obstacle_array_exposed = true
		return _obstacles
	set(value):
		_obstacle_array_exposed = true
		_obstacles = value
		_invalidate_obstacle_index()
var _obstacles: Array[Obstacle] = []
var _obstacle_array_exposed: bool = false
var _obstacle_index_dirty: bool = true
var _obstacle_index_failed: bool = false
var _obstacle_cells: Dictionary = {}
var _obstacle_view_cache: Array[Obstacle] = []
var _obstacle_view_dirty: bool = true


func _init(requested_width: int = 1_280_000, requested_height: int = 720_000) -> void:
	width = requested_width
	height = requested_height


func add_obstacle(obstacle: Obstacle) -> void:
	_obstacles.append(obstacle)
	_obstacles.sort_custom(func(left: Obstacle, right: Obstacle) -> bool: return left.obstacle_id < right.obstacle_id)
	if not obstacle.geometry_changed.is_connected(_invalidate_obstacle_index):
		obstacle.geometry_changed.connect(_invalidate_obstacle_index)
	_invalidate_obstacle_index()


func obstacle_view() -> Array[Obstacle]:
	# Structure is read-only; obstacle properties remain signal-observed so
	# geometry edits still invalidate collision queries immediately.
	if _obstacle_view_dirty or _obstacle_array_exposed:
		_obstacle_view_cache = _obstacles.duplicate()
		_obstacle_view_cache.make_read_only()
		_obstacle_view_dirty = false
	return _obstacle_view_cache


func move_box(position: Vector2i, delta: Vector2i, radius: int) -> MoveResult:
	var resolved := position
	var normal := Vector2i.ZERO
	var wall_id: int = 0
	var next_x: int = clampi(position.x + delta.x, radius, width - radius)
	var next_y: int = clampi(position.y + delta.y, radius, height - radius)
	var candidates := _candidate_obstacles(
		Vector2i(mini(position.x, next_x) - radius, mini(position.y, next_y) - radius),
		Vector2i(maxi(position.x, next_x) + radius, maxi(position.y, next_y) + radius),
	) if radius >= 0 else _obstacles
	if next_x != position.x + delta.x:
		normal.x = -signi(delta.x) * 1000
		wall_id = -1
	for obstacle: Obstacle in candidates:
		if not _ranges_overlap(position.y - radius, position.y + radius, obstacle.minimum_y, obstacle.maximum_y):
			continue
		if delta.x > 0 and position.x + radius <= obstacle.minimum_x and next_x + radius > obstacle.minimum_x:
			next_x = mini(next_x, obstacle.minimum_x - radius)
			normal.x = -1000
			wall_id = obstacle.obstacle_id
		elif delta.x < 0 and position.x - radius >= obstacle.maximum_x and next_x - radius < obstacle.maximum_x:
			next_x = maxi(next_x, obstacle.maximum_x + radius)
			normal.x = 1000
			wall_id = obstacle.obstacle_id
	resolved.x = next_x

	if next_y != position.y + delta.y:
		normal.y = -signi(delta.y) * 1000
		wall_id = -2
	for obstacle: Obstacle in candidates:
		if not _ranges_overlap(resolved.x - radius, resolved.x + radius, obstacle.minimum_x, obstacle.maximum_x):
			continue
		if delta.y > 0 and position.y + radius <= obstacle.minimum_y and next_y + radius > obstacle.minimum_y:
			next_y = mini(next_y, obstacle.minimum_y - radius)
			normal.y = -1000
			wall_id = obstacle.obstacle_id
		elif delta.y < 0 and position.y - radius >= obstacle.maximum_y and next_y - radius < obstacle.maximum_y:
			next_y = maxi(next_y, obstacle.maximum_y + radius)
			normal.y = 1000
			wall_id = obstacle.obstacle_id
	resolved.y = next_y
	return MoveResult.new(resolved, normal, wall_id)


func find_vault_candidate(position: Vector2i, direction: Vector2i, radius: int) -> Obstacle:
	var best: Obstacle = null
	var best_distance_squared: int = 0x7fffffffffffffff
	var maximum_distance: int = radius + MovementTuning.VAULT_APPROACH
	for obstacle: Obstacle in _obstacles:
		if not obstacle.vaultable or obstacle.projected_depth(direction) > MovementTuning.VAULT_MAXIMUM_DEPTH:
			continue
		var nearest := Vector2i(
			clampi(position.x, obstacle.minimum_x, obstacle.maximum_x),
			clampi(position.y, obstacle.minimum_y, obstacle.maximum_y),
		)
		var offset: Vector2i = nearest - position
		var distance_squared: int = offset.length_squared()
		if distance_squared > maximum_distance * maximum_distance or distance_squared >= best_distance_squared:
			continue
		var approach_dot: int = offset.x * direction.x + offset.y * direction.y
		if approach_dot <= 0 or approach_dot * approach_dot < distance_squared * 518_400:
			continue
		best = obstacle
		best_distance_squared = distance_squared
	return best


func vault_destination(
	position: Vector2i,
	direction: Vector2i,
	radius: int,
	obstacle: Obstacle,
) -> Vector2i:
	var destination := position
	if absi(direction.x) >= absi(direction.y):
		destination.x = (
			obstacle.maximum_x + radius + MovementTuning.VAULT_LANDING
			if direction.x > 0
			else obstacle.minimum_x - radius - MovementTuning.VAULT_LANDING
		)
		@warning_ignore("integer_division")
		destination.y += direction.y * obstacle.projected_depth(direction) / 1000
	else:
		destination.y = (
			obstacle.maximum_y + radius + MovementTuning.VAULT_LANDING
			if direction.y > 0
			else obstacle.minimum_y - radius - MovementTuning.VAULT_LANDING
		)
		@warning_ignore("integer_division")
		destination.x += direction.x * obstacle.projected_depth(direction) / 1000
	destination.x = clampi(destination.x, radius, width - radius)
	destination.y = clampi(destination.y, radius, height - radius)
	return destination if can_occupy(destination, radius) else position


func can_occupy(position: Vector2i, radius: int, ignored_obstacle_id: int = -1) -> bool:
	if position.x < radius or position.x > width - radius or position.y < radius or position.y > height - radius:
		return false
	var candidates := _candidate_obstacles(position - Vector2i(radius, radius), position + Vector2i(radius, radius)) if radius >= 0 else _obstacles
	for obstacle: Obstacle in candidates:
		if obstacle.obstacle_id == ignored_obstacle_id:
			continue
		if _ranges_overlap(position.x - radius, position.x + radius, obstacle.minimum_x, obstacle.maximum_x) and _ranges_overlap(position.y - radius, position.y + radius, obstacle.minimum_y, obstacle.maximum_y):
			return false
	return true


func _invalidate_obstacle_index() -> void:
	_obstacle_index_dirty = true
	_obstacle_index_failed = false
	_obstacle_view_dirty = true


func _candidate_obstacles(minimum: Vector2i, maximum: Vector2i) -> Array[Obstacle]:
	if _obstacle_array_exposed or _obstacles.size() < OBSTACLE_INDEX_MINIMUM:
		return _obstacles
	if _obstacle_index_dirty:
		_rebuild_obstacle_index()
	if _obstacle_index_failed:
		return _obstacles
	var first_cell := _obstacle_cell(minimum)
	var last_cell := _obstacle_cell(maximum)
	var query_cells := (last_cell.x - first_cell.x + 1) * (last_cell.y - first_cell.y + 1)
	if query_cells < 1 or query_cells > MAX_QUERY_CELLS:
		return _obstacles
	var found: Dictionary[int, bool] = {}
	for cell_x: int in range(first_cell.x, last_cell.x + 1):
		for cell_y: int in range(first_cell.y, last_cell.y + 1):
			for index: int in _obstacle_cells.get(Vector2i(cell_x, cell_y), []):
				found[index] = true
	var indices: Array[int] = found.keys()
	indices.sort()
	var result: Array[Obstacle] = []
	for index: int in indices:
		result.append(_obstacles[index])
	return result


func _rebuild_obstacle_index() -> void:
	_obstacle_cells.clear()
	_obstacle_index_dirty = false
	var entries := 0
	for index: int in range(_obstacles.size()):
		var obstacle := _obstacles[index]
		# Degenerate or extraordinarily large geometry retains legacy semantics
		# through the bounded linear fallback instead of building a huge grid.
		if obstacle.minimum_x >= obstacle.maximum_x or obstacle.minimum_y >= obstacle.maximum_y:
			_obstacle_index_failed = true
			_obstacle_cells.clear()
			return
		var first_cell := _obstacle_cell(Vector2i(obstacle.minimum_x, obstacle.minimum_y))
		var last_cell := _obstacle_cell(Vector2i(obstacle.maximum_x, obstacle.maximum_y))
		entries += (last_cell.x - first_cell.x + 1) * (last_cell.y - first_cell.y + 1)
		if entries > MAX_INDEX_ENTRIES:
			_obstacle_index_failed = true
			_obstacle_cells.clear()
			return
		for cell_x: int in range(first_cell.x, last_cell.x + 1):
			for cell_y: int in range(first_cell.y, last_cell.y + 1):
				var key := Vector2i(cell_x, cell_y)
				if not _obstacle_cells.has(key):
					_obstacle_cells[key] = []
				(_obstacle_cells[key] as Array).append(index)


static func _obstacle_cell(position: Vector2i) -> Vector2i:
	return Vector2i(floori(float(position.x) / OBSTACLE_CELL_SIZE), floori(float(position.y) / OBSTACLE_CELL_SIZE))


static func _ranges_overlap(minimum_a: int, maximum_a: int, minimum_b: int, maximum_b: int) -> bool:
	return maximum_a > minimum_b and minimum_a < maximum_b

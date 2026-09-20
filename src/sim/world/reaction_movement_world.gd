class_name ReactionMovementWorld
extends CollisionWorld

## Read-only map plus finite, authority-derived movement surfaces. Neither
## collision queries nor escape handling mutate reaction state or map geometry.
const SURFACE_ID_BASE: int = 100_000_000
const ROW_WIDTH: int = 7
const MAX_SURFACES: int = 32
var base_world: CollisionWorld
var _surfaces: Array[Obstacle] = []
var _actor_surfaces: Array[Obstacle] = []
var _view: Array[Obstacle] = []
var _view_dirty: bool = false

func _init(source: CollisionWorld = null) -> void:
	base_world = source
	if source != null:
		width = source.width
		height = source.height

static func capture_surfaces(reactions: Array, tick: int) -> PackedInt32Array:
	var ordered: Array = []
	for reaction: ElementReactionState in reactions:
		if reaction.recipe_wire_id == 301 and reaction.health > 0 and tick < reaction.decay_tick:
			ordered.append(reaction)
	ordered.sort_custom(func(a: ElementReactionState, b: ElementReactionState) -> bool: return a.entity_id < b.entity_id)
	var rows := PackedInt32Array()
	for reaction: ElementReactionState in ordered.slice(0, MAX_SURFACES):
		var bounds := ElementChemistrySystem.rampart_bounds(reaction)
		rows.append_array(PackedInt32Array([SURFACE_ID_BASE + reaction.entity_id, bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y, reaction.active_tick, reaction.decay_tick]))
	return rows

static func validate_surfaces(rows: PackedInt32Array, tick: int) -> bool:
	if rows.size() % ROW_WIDTH != 0 or rows.size() > MAX_SURFACES * ROW_WIDTH:
		return false
	var previous_id := SURFACE_ID_BASE
	for index: int in range(0, rows.size(), ROW_WIDTH):
		var id := rows[index]
		if id <= previous_id or id >= 2_100_000_000:
			return false
		previous_id = id
		for axis: int in range(1, 5):
			if rows[index + axis] < -1_100_000 or rows[index + axis] > 100_100_000:
				return false
		var extent := Vector2i(rows[index + 3] - rows[index + 1], rows[index + 4] - rows[index + 2])
		var policy := ElementChemistrySystem.movement_surface_policy()
		var expected := Vector2i(int(policy.thickness), int(policy.length))
		if extent not in [expected, Vector2i(expected.y, expected.x)]:
			return false
		if rows[index + 5] < 0 or rows[index + 6] <= maxi(tick, rows[index + 5]) or rows[index + 6] - tick > 600 or rows[index + 6] - rows[index + 5] > 600:
			return false
	return true

func set_surfaces(rows: PackedInt32Array, tick: int) -> void:
	_surfaces.clear()
	for index: int in range(0, rows.size(), ROW_WIDTH):
		if tick < rows[index + 5] or tick >= rows[index + 6]:
			continue
		# A custom map cannot alias a dynamic ID. Fail closed for that surface;
		# never attach to the wrong wall. Authored maps use IDs below the base.
		var id := rows[index]
		var collision_id := false
		for obstacle: Obstacle in base_world.obstacle_view():
			if obstacle.obstacle_id == id:
				collision_id = true
				break
		if not collision_id:
			_surfaces.append(Obstacle.new(id, rows[index + 1], rows[index + 2], rows[index + 3], rows[index + 4]))

func begin_actor(position: Vector2i, radius: int) -> void:
	_actor_surfaces.clear()
	if _surfaces.is_empty():
		_view = base_world.obstacle_view()
		_view_dirty = false
		return
	# An actor already overlapping at admission can leave without ejection.
	# This exemption lasts for the whole movement step, not individual axes.
	# Once clear, the next step includes the surface and prevents re-entry.
	for obstacle: Obstacle in _surfaces:
		if _ranges_overlap(position.x - radius, position.x + radius, obstacle.minimum_x, obstacle.maximum_x) and _ranges_overlap(position.y - radius, position.y + radius, obstacle.minimum_y, obstacle.maximum_y):
			continue
		_actor_surfaces.append(obstacle)
	_view_dirty = true

func obstacle_view() -> Array[Obstacle]:
	if _view_dirty:
		_view = base_world.obstacle_view().duplicate()
		_view.append_array(_actor_surfaces)
		_view.sort_custom(func(a: Obstacle, b: Obstacle) -> bool: return a.obstacle_id < b.obstacle_id)
		_view.make_read_only()
		_view_dirty = false
	return _view

func _candidate_obstacles(minimum: Vector2i, maximum: Vector2i) -> Array[Obstacle]:
	if _actor_surfaces.is_empty():
		return base_world._candidate_obstacles(minimum, maximum)
	var result := base_world._candidate_obstacles(minimum, maximum).duplicate()
	result.append_array(_actor_surfaces)
	result.sort_custom(func(a: Obstacle, b: Obstacle) -> bool: return a.obstacle_id < b.obstacle_id)
	return result

func has_live_surface(surface_id: int) -> bool:
	for obstacle: Obstacle in _actor_surfaces:
		if obstacle.obstacle_id == surface_id:
			return true
	return false

static func clear_stale_contact(state: PlayerState, world: ReactionMovementWorld) -> void:
	if state.wall_contact_id >= SURFACE_ID_BASE:
		for obstacle: Obstacle in world.base_world.obstacle_view():
			if obstacle.obstacle_id == state.wall_contact_id:
				return # A custom static map ID is never dynamic contact memory.
	if state.wall_contact_id >= SURFACE_ID_BASE and not world.has_live_surface(state.wall_contact_id):
		state.wall_contact_id = 0
		state.wall_memory_ticks = 0
		state.wall_x = 0
		state.wall_y = 0
	# Running attachment ends through the ordinary finite-air exit path in
	# MovementSystem. Never refresh protection, stamina or any air budget here.

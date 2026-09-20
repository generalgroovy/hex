class_name CapacitorFieldPolicy
extends RefCounted
@warning_ignore_start("integer_division")

## Exact-tick, read-only material context shared by authority and prediction.
## Rows describe the stationary capsule plus its owning team. Ordinary ground
## targets accelerate once; the last active tick may displace one valid enemy.
const RECIPE_WIRE: int = 331
const ROW_WIDTH: int = 10
const MAX_FIELDS: int = 32
const WALK_RATIO: int = 1250
const DISCHARGE_DISTANCE: int = 14_000
const FINAL_WARNING_TICKS: int = 60
const MAX_DURATION_TICKS: int = 240
const MAX_FORMATION_TICKS: int = 78

static func policy() -> Dictionary:
	return {"version": 1, "recipe": RECIPE_WIRE, "name": "Capacitor", "shape": "stationary_capsule", "radius": ElementChemistrySystem.extent(24000), "length": ElementChemistrySystem.extent(160000), "warning_ms": 650, "active_ms": 2000, "final_warning_ms": 500, "decay_ms": 450, "walk_sprint_target_ratio": WALK_RATIO, "slide_ratio": 1000, "air_and_forced_control_ratio": 1000, "maximum_speed": MovementTuning.MAX_AUTHORED_SPEED, "query": "center_at_tick_start", "teams": "all", "stacking": "nonstacking", "overlap_precedence": "frostway_750_else_capacitor_1250", "discharge_tick": "decay_tick_minus_one", "discharge_distance": DISCHARGE_DISTANCE, "discharge_direction": "cast", "discharge_targets": "grounded_enemy_unprotected", "simultaneous_discharge_cap": DISCHARGE_DISTANCE, "simultaneous_discharge_scope": "per_actor_per_tick_lowest_id", "prediction": "required_exact_tick_lanes_v1", "solid": false, "ray_blocking": false, "base_velocity_damage_lifetime_cost_protection_unchanged": true}

static func capture(reactions: Array, tick: int) -> PackedInt32Array:
	var ordered: Array = []
	for reaction: ElementReactionState in reactions:
		if reaction.recipe_wire_id == RECIPE_WIRE and tick < reaction.decay_tick:
			ordered.append(reaction)
	ordered.sort_custom(func(a: ElementReactionState, b: ElementReactionState) -> bool: return a.entity_id < b.entity_id)
	var rows := PackedInt32Array()
	for reaction: ElementReactionState in ordered.slice(0, MAX_FIELDS):
		rows.append_array(PackedInt32Array([reaction.entity_id, reaction.position_x, reaction.position_y, reaction.endpoint_x, reaction.endpoint_y, reaction.radius, reaction.length, reaction.active_tick, reaction.decay_tick, reaction.team_id]))
	return rows

static func validate(rows: PackedInt32Array, tick: int) -> bool:
	if rows.size() % ROW_WIDTH != 0 or rows.size() > MAX_FIELDS * ROW_WIDTH:
		return false
	var previous_id := 0
	for index: int in range(0, rows.size(), ROW_WIDTH):
		if rows[index] <= previous_id or rows[index] >= 2_000_000_000:
			return false
		previous_id = rows[index]
		for axis: int in range(1, 5):
			if rows[index + axis] < -1_000_000 or rows[index + axis] > 100_000_000:
				return false
		if rows[index + 5] != ElementChemistrySystem.extent(24000) or rows[index + 6] != ElementChemistrySystem.extent(160000):
			return false
		var delta := Vector2i(rows[index + 3] - rows[index + 1], rows[index + 4] - rows[index + 2])
		var distance := SimCommand._integer_square_root(delta.x * delta.x + delta.y * delta.y)
		if absi(distance - rows[index + 6]) > 400:
			return false
		var active := rows[index + 7]
		var decay := rows[index + 8]
		if active < 0 or active > tick + MAX_FORMATION_TICKS or decay <= maxi(active, tick) or decay - active > MAX_DURATION_TICKS or decay >= 2_000_000_000:
			return false
		if rows[index + 9] < 1 or rows[index + 9] > 256:
			return false
	return true

static func contains(rows: PackedInt32Array, point: Vector2i, tick: int) -> bool:
	for index: int in range(0, rows.size(), ROW_WIDTH):
		if _row_contains(rows, index, point, tick):
			return true
	return false

static func movement_ratio(rows: PackedInt32Array, point: Vector2i, tick: int) -> int:
	return WALK_RATIO if contains(rows, point, tick) else 1000

static func discharge_due(rows: PackedInt32Array, tick: int) -> bool:
	if rows.size() % ROW_WIDTH != 0:
		return false
	for index: int in range(0, rows.size(), ROW_WIDTH):
		if tick >= rows[index + 7] and tick == rows[index + 8] - 1:
			return true
	return false

static func apply_discharge(rows: PackedInt32Array, state: PlayerState, tick: int, collision: CollisionWorld) -> bool:
	if rows.size() % ROW_WIDTH != 0 or state == null or state.health <= 0 or state.spawn_protection_ticks > 0 or state.air_height > 0 or state.is_airborne():
		return false
	var point := Vector2i(state.position_x, state.position_y)
	for index: int in range(0, rows.size(), ROW_WIDTH):
		if tick != rows[index + 8] - 1 or state.team_id == rows[index + 9] or not _row_contains(rows, index, point, tick):
			continue
		var start := Vector2i(rows[index + 1], rows[index + 2])
		var reaction_world := collision as ReactionMovementWorld
		var sight_world: CollisionWorld = reaction_world.base_world if reaction_world != null else collision
		if sight_world != null and not ElementChemistrySystem.clear_line(start, point, sight_world):
			continue
		var end := Vector2i(rows[index + 3], rows[index + 4])
		var direction := SimCommand._normalized_direction(end.x - start.x, end.y - start.y)
		if direction == Vector2i.ZERO:
			continue
		var delta := ElementChemistrySystem.scaled(direction, DISCHARGE_DISTANCE)
		var moved := collision.move_box(point, delta, MovementTuning.PLAYER_RADIUS).position if collision != null else point + delta
		state.position_x = moved.x
		state.position_y = moved.y
		return true
	return false

static func _row_contains(rows: PackedInt32Array, index: int, point: Vector2i, tick: int) -> bool:
	if index < 0 or index + ROW_WIDTH > rows.size() or tick < rows[index + 7] or tick >= rows[index + 8]:
		return false
	var start := Vector2i(rows[index + 1], rows[index + 2])
	var end := Vector2i(rows[index + 3], rows[index + 4])
	var radius := rows[index + 5]
	if point.x < mini(start.x, end.x) - radius or point.x > maxi(start.x, end.x) + radius or point.y < mini(start.y, end.y) - radius or point.y > maxi(start.y, end.y) + radius:
		return false
	return ElementChemistrySystem.segment_near(point, start, end, radius)

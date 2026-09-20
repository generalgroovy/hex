class_name FrostwayFieldPolicy
extends RefCounted
@warning_ignore_start("integer_division")

## Exact-tick, read-only material context. Rows describe the same capsule used
## by chemistry and presentation; no player status or projectile velocity is
## rewritten. Multiple lanes never compound their ratios.
const RECIPE_WIRE: int = 327
const ROW_WIDTH: int = 9
const MAX_FIELDS: int = 32
const WALK_RATIO: int = 750
const PROJECTILE_RATIO: int = 650
const MAX_DURATION_TICKS: int = 420
const MAX_FORMATION_TICKS: int = 78

static func policy() -> Dictionary:
	return {"version": 1, "recipe": RECIPE_WIRE, "name": "Frostway", "shape": "stationary_capsule", "radius": ElementChemistrySystem.extent(24000), "length": ElementChemistrySystem.extent(160000), "walk_sprint_target_ratio": WALK_RATIO, "slide_ratio": 1000, "air_and_forced_control_ratio": 1000, "projectile_displacement_ratio": PROJECTILE_RATIO, "query": "center_at_tick_start", "teams": "all", "stacking": "nonstacking", "prediction": "required_exact_tick_lanes_v1", "solid": false, "ray_blocking": false, "base_velocity_damage_lifetime_unchanged": true}

static func capture(reactions: Array, tick: int) -> PackedInt32Array:
	var ordered: Array = []
	for reaction: ElementReactionState in reactions:
		if reaction.recipe_wire_id == RECIPE_WIRE and tick < reaction.decay_tick:
			ordered.append(reaction)
	ordered.sort_custom(func(a: ElementReactionState, b: ElementReactionState) -> bool: return a.entity_id < b.entity_id)
	var rows := PackedInt32Array()
	for reaction: ElementReactionState in ordered.slice(0, MAX_FIELDS):
		rows.append_array(PackedInt32Array([reaction.entity_id, reaction.position_x, reaction.position_y, reaction.endpoint_x, reaction.endpoint_y, reaction.radius, reaction.length, reaction.active_tick, reaction.decay_tick]))
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
		# Aim vectors use normalized fixed integers, with truncation below one
		# direction unit. Reject distorted or zero-length imported corridors.
		if absi(distance - rows[index + 6]) > 400:
			return false
		var active := rows[index + 7]
		var decay := rows[index + 8]
		if active < 0 or active > tick + MAX_FORMATION_TICKS or decay <= maxi(active, tick) or decay - active > MAX_DURATION_TICKS or decay >= 2_000_000_000:
			return false
	return true

static func contains(rows: PackedInt32Array, point: Vector2i, tick: int) -> bool:
	for index: int in range(0, rows.size(), ROW_WIDTH):
		if tick < rows[index + 7] or tick >= rows[index + 8]:
			continue
		var start := Vector2i(rows[index + 1], rows[index + 2])
		var end := Vector2i(rows[index + 3], rows[index + 4])
		var radius := rows[index + 5]
		if point.x < mini(start.x, end.x) - radius or point.x > maxi(start.x, end.x) + radius or point.y < mini(start.y, end.y) - radius or point.y > maxi(start.y, end.y) + radius:
			continue
		if ElementChemistrySystem.segment_near(point, start, end, radius):
			return true
	return false

static func movement_ratio(rows: PackedInt32Array, point: Vector2i, tick: int) -> int:
	return WALK_RATIO if contains(rows, point, tick) else 1000

static func projectile_ratio(rows: PackedInt32Array, point: Vector2i, tick: int) -> int:
	return PROJECTILE_RATIO if contains(rows, point, tick) else 1000

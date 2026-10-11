extends "res://src/sim/world/collision_world.gd"
@warning_ignore_start("integer_division")

# Exact pre-optimization method bodies; do not update to mirror optimized guards.
# Original source SHA-256: 28425207bf7aa1eb35518c5a17131417909514f99eceefe6fd80e26f8d7c86e7

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

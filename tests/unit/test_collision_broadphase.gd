extends FluxTestSuite


# Frozen pre-index axis resolver: this reference deliberately does not call the
# optimized candidate query or copy its partitioning logic.
class LinearReference:
	extends RefCounted
	var width: int = 12_000_000
	var height: int = 6_000_000
	var obstacles: Array[CollisionWorld.Obstacle] = []

	func move_box(position: Vector2i, delta: Vector2i, radius: int) -> CollisionWorld.MoveResult:
		var resolved := position
		var normal := Vector2i.ZERO
		var wall_id := 0
		var next_x: int = clampi(position.x + delta.x, radius, width - radius)
		if next_x != position.x + delta.x:
			normal.x = -signi(delta.x) * 1000
			wall_id = -1
		for obstacle: CollisionWorld.Obstacle in obstacles:
			if not _overlap(position.y - radius, position.y + radius, obstacle.minimum_y, obstacle.maximum_y):
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
		var next_y: int = clampi(position.y + delta.y, radius, height - radius)
		if next_y != position.y + delta.y:
			normal.y = -signi(delta.y) * 1000
			wall_id = -2
		for obstacle: CollisionWorld.Obstacle in obstacles:
			if not _overlap(resolved.x - radius, resolved.x + radius, obstacle.minimum_x, obstacle.maximum_x):
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
		return CollisionWorld.MoveResult.new(resolved, normal, wall_id)

	func can_occupy(position: Vector2i, radius: int, ignored_id: int = -1) -> bool:
		if position.x < radius or position.x > width - radius or position.y < radius or position.y > height - radius:
			return false
		for obstacle: CollisionWorld.Obstacle in obstacles:
			if obstacle.obstacle_id == ignored_id:
				continue
			if _overlap(position.x - radius, position.x + radius, obstacle.minimum_x, obstacle.maximum_x) and _overlap(position.y - radius, position.y + radius, obstacle.minimum_y, obstacle.maximum_y):
				return false
		return true

	static func _overlap(minimum_a: int, maximum_a: int, minimum_b: int, maximum_b: int) -> bool:
		return maximum_a > minimum_b and minimum_a < maximum_b


func run() -> int:
	_test_differential_moves_and_occupancy()
	_test_geometry_and_legacy_mutation()
	_test_bounded_fallbacks()
	return finish("collision-broadphase")


func _fixture(count: int = 64) -> Dictionary:
	var world := CollisionWorld.new(12_000_000, 6_000_000)
	var reference := LinearReference.new()
	for index: int in range(count - 1, -1, -1):
		var x := 300_000 + (index % 8) * 400_000
		@warning_ignore("integer_division")
		var y := 300_000 + (index / 8) * 300_000
		var obstacle := CollisionWorld.Obstacle.new(index + 1, x, y, x + 160_000, y + 160_000)
		world.add_obstacle(obstacle)
		reference.obstacles.append(obstacle)
	reference.obstacles.sort_custom(func(left: CollisionWorld.Obstacle, right: CollisionWorld.Obstacle) -> bool: return left.obstacle_id < right.obstacle_id)
	return {"world": world, "reference": reference}


func _test_differential_moves_and_occupancy() -> void:
	var fixture := _fixture()
	var world: CollisionWorld = fixture["world"]
	var reference: LinearReference = fixture["reference"]
	var view := world.obstacle_view()
	check(view.is_read_only(), "public obstacle view cannot mutate array structure")
	equal(view.size(), 64, "public read-only view contains the full ordered worldbone")
	check(not world._obstacle_array_exposed, "read-only view does not opt out of acceleration")
	equal(world._candidate_obstacles(Vector2i(7_000_000, 4_000_000), Vector2i(7_030_000, 4_030_000)).size(), 0, "empty-region query excludes all sixty-four distant obstacles")
	_random_differential(world, reference, 4_000, 80_401)
	for position: Vector2i in [Vector2i(280_000, 380_000), Vector2i(480_000, 380_000), Vector2i(380_000, 280_000), Vector2i(380_000, 480_000), Vector2i(20_000, 20_000)]:
		for delta: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(900_000, 900_000), Vector2i(-900_000, -900_000)]:
			_compare(world, reference, position, delta, 20_000, -1, "exact face/tangent/axis edge")
	# The resolver historically permits an overlapping start to move out; do
	# not convert the candidate grid into a different penetration solver.
	_compare(world, reference, Vector2i(380_000, 380_000), Vector2i(400_000, 300_000), 35_000, 1, "overlapping-start and ignored occupancy")
	check(not world._obstacle_array_exposed, "production-style view reads leave index enabled after the full sweep")


func _test_geometry_and_legacy_mutation() -> void:
	var fixture := _fixture()
	var world: CollisionWorld = fixture["world"]
	var reference: LinearReference = fixture["reference"]
	world.move_box(Vector2i(200_000, 300_000), Vector2i(300_000, 0), 20_000)
	var moved := world.obstacle_view()[0]
	moved.minimum_x = 7_000_000
	moved.maximum_x = 7_200_000
	moved.minimum_y = 4_000_000
	moved.maximum_y = 4_200_000
	check(world._obstacle_index_dirty, "direct geometry edits invalidate cached cells immediately")
	_compare(world, reference, Vector2i(6_900_000, 4_100_000), Vector2i(400_000, 0), 20_000, -1, "moved obstacle crosses grid cells")
	check(not world._obstacle_index_dirty, "next query rebuilds mutated geometry")
	var added := CollisionWorld.Obstacle.new(500, 7_600_000, 3_900_000, 7_800_000, 4_200_000)
	world.add_obstacle(added)
	reference.obstacles.append(added)
	equal(world.obstacle_view().size(), 65, "cached view refreshes after ordered insertion")
	_compare(world, reference, Vector2i(7_500_000, 4_100_000), Vector2i(400_000, 0), 20_000, -1, "new obstacle enters an already-built index")
	_random_differential(world, reference, 500, 81_502)
	var escaped := world.obstacles
	check(world._obstacle_array_exposed, "legacy mutable array explicitly selects safe linear fallback")
	escaped.reverse()
	escaped[0] = CollisionWorld.Obstacle.new(900, 100_000, 100_000, 900_000, 900_000)
	escaped.remove_at(1)
	reference.obstacles = escaped.duplicate()
	_random_differential(world, reference, 500, 81_503)
	equal(world.obstacle_view().size(), escaped.size(), "read-only view refreshes after retained legacy-array mutation")
	escaped.clear()
	reference.obstacles.clear()
	_compare(world, reference, Vector2i(500_000, 500_000), Vector2i(400_000, -400_000), 20_000, -1, "retained array clear cannot leave stale collision")
	equal(world.obstacle_view().size(), 0, "retained array clear cannot leave stale presentation")


func _test_bounded_fallbacks() -> void:
	for count: int in [0, 1, 15, 16]:
		var fixture := _fixture(count)
		_random_differential(fixture["world"], fixture["reference"], 100, count + 99)
	var fixture := _fixture()
	var world: CollisionWorld = fixture["world"]
	var reference: LinearReference = fixture["reference"]
	_compare(world, reference, Vector2i(100_000, 100_000), Vector2i(11_000_000, 5_000_000), 20_000, -1, "large sweep uses bounded linear fallback")
	var huge := CollisionWorld.Obstacle.new(700, -2_000_000_000, -2_000_000_000, 2_000_000_000, 2_000_000_000)
	world.add_obstacle(huge)
	reference.obstacles.append(huge)
	_compare(world, reference, Vector2i(600_000, 600_000), Vector2i(90_000, 0), 20_000, -1, "huge obstacle fails back without huge cell allocation")
	check(world._obstacle_index_failed, "oversized index records bounded fallback")
	var second := _fixture()
	var degenerate: CollisionWorld = second["world"]
	var flat := CollisionWorld.Obstacle.new(701, 100_000, 100_000, 100_000, 200_000)
	degenerate.add_obstacle(flat)
	(second["reference"] as LinearReference).obstacles.append(flat)
	_compare(degenerate, second["reference"], Vector2i(50_000, 150_000), Vector2i(100_000, 0), 10_000, -1, "degenerate geometry preserves original resolver")
	check(degenerate._obstacle_index_failed, "degenerate geometry selects safe fallback")


func _random_differential(world: CollisionWorld, reference: LinearReference, count: int, seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for index: int in range(count):
		var position := Vector2i(random.randi_range(-80_000, 12_080_000), random.randi_range(-80_000, 6_080_000))
		var delta := Vector2i(random.randi_range(-900_000, 900_000), random.randi_range(-900_000, 900_000))
		var radius: int = [0, 20_000, 24_000, 34_000, 38_000][index % 5]
		world.obstacle_view()
		_compare(world, reference, position, delta, radius, index % 70, "seed %d case %d" % [seed_value, index])


func _compare(world: CollisionWorld, reference: LinearReference, position: Vector2i, delta: Vector2i, radius: int, ignored_id: int, label: String) -> void:
	var actual := world.move_box(position, delta, radius)
	var expected := reference.move_box(position, delta, radius)
	equal(actual.position, expected.position, "%s exact resolved position" % label)
	equal(actual.wall_normal, expected.wall_normal, "%s exact two-axis normal" % label)
	equal(actual.wall_id, expected.wall_id, "%s original wall/order ownership" % label)
	equal(world.can_occupy(position, radius, ignored_id), reference.can_occupy(position, radius, ignored_id), "%s exact occupancy/ignore behavior" % label)

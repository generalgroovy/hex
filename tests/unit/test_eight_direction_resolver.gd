extends FluxTestSuite


func run() -> int:
	_test_direction_contract()
	_test_exact_boundaries()
	_test_stateful_hysteresis()
	_test_relative_movement()
	return finish("eight-direction-resolver")


func _test_direction_contract() -> void:
	equal(EightDirectionResolver.DIRECTION_ORDER, ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"], "direction order matches every character manifest")
	for index: int in range(EightDirectionResolver.DIRECTION_ORDER.size()):
		var direction_id: String = EightDirectionResolver.DIRECTION_ORDER[index]
		var vector: Vector2i = EightDirectionResolver.FIXED_VECTORS[index]
		equal(EightDirectionResolver.classify_index(vector.x, vector.y), index, "%s fixed vector resolves exactly" % direction_id)
		equal(EightDirectionResolver.direction_id_from_vector(vector.x, vector.y), direction_id, "%s exposes its stable semantic ID" % direction_id)
		equal(EightDirectionResolver.fixed_vector(direction_id), vector, "%s round-trips to a normalized capture vector" % direction_id)
		check(EightDirectionResolver.is_fixed_vector(vector), "%s is accepted by deterministic capture input" % direction_id)
	equal(EightDirectionResolver.classify_index(0, 0), EightDirectionResolver.SOUTH, "zero vector fails safe to south")
	equal(EightDirectionResolver.direction_id_from_vector(0, 0, "north_west"), "north_west", "zero vector preserves an explicit valid fallback")
	equal(EightDirectionResolver.direction_id_from_vector(0, 0, "missing"), "south", "unknown fallback fails closed to south")
	equal(EightDirectionResolver.nearest_cardinal_id(900, 500), "east", "four-direction runtime fallback retains the nearest horizontal cardinal")
	equal(EightDirectionResolver.nearest_cardinal_id(-500, -900), "north", "four-direction runtime fallback retains the nearest vertical cardinal")


func _test_exact_boundaries() -> void:
	equal(EightDirectionResolver.direction_id_from_vector(414_214, 1_000_000), "south", "exact south-sector boundary remains cardinal")
	equal(EightDirectionResolver.direction_id_from_vector(414_215, 1_000_000), "south_east", "one fixed unit beyond south boundary becomes diagonal")
	equal(EightDirectionResolver.direction_id_from_vector(1_000_000, 414_214), "east", "exact east-sector boundary remains cardinal")
	equal(EightDirectionResolver.direction_id_from_vector(1_000_000, 414_215), "south_east", "one fixed unit beyond east boundary becomes diagonal")
	equal(EightDirectionResolver.direction_id_from_vector(-414_215, -1_000_000), "north_west", "signed north-west boundary is symmetric")
	equal(EightDirectionResolver.direction_id_from_vector(-1_000_000, 414_215), "south_west", "signed south-west boundary is symmetric")


func _test_stateful_hysteresis() -> void:
	var resolver := EightDirectionResolver.new()
	resolver.reset("east")
	equal(resolver.resolve_id(1000, 420), "east", "small sector crossing stays east inside the hold cone")
	equal(resolver.resolve_id(1000, 650), "south_east", "deliberate turn leaves the east hold cone")
	equal(resolver.resolve_id(1000, 400), "south_east", "return jitter stays diagonal inside its hold cone")
	equal(resolver.resolve_id(1000, 200), "east", "deliberate return leaves the diagonal hold cone")
	equal(resolver.resolve_id(0, 0), "east", "zero input preserves the last stable facing")
	resolver.clear()
	check(not resolver.has_direction, "clear removes prior direction ownership")
	equal(resolver.resolve_id(0, 0, "north"), "north", "first zero sample adopts its explicit fallback")
	var at_60 := EightDirectionResolver.new()
	var at_120 := EightDirectionResolver.new()
	var samples := [Vector2i(1000, 0), Vector2i(1000, 420), Vector2i(1000, 650), Vector2i(0, 0), Vector2i(300, 1000)]
	for sample: Vector2i in samples:
		equal(at_60.resolve_id(sample.x, sample.y), at_120.resolve_id(sample.x, sample.y), "direction resolution is simulation-rate independent for %s" % sample)


func _test_relative_movement() -> void:
	equal(EightDirectionResolver.relative_gait(EightDirectionResolver.SOUTH, EightDirectionResolver.SOUTH), "forward", "matching travel and facing move forward")
	equal(EightDirectionResolver.relative_gait(EightDirectionResolver.SOUTH, EightDirectionResolver.SOUTH_EAST), "forward", "near-forward diagonal stays in the forward gait family")
	equal(EightDirectionResolver.relative_gait(EightDirectionResolver.SOUTH, EightDirectionResolver.EAST), "strafe_left", "right-screen travel while facing south is character-left strafe")
	equal(EightDirectionResolver.relative_gait(EightDirectionResolver.SOUTH, EightDirectionResolver.WEST), "strafe_right", "left-screen travel while facing south is character-right strafe")
	equal(EightDirectionResolver.relative_gait(EightDirectionResolver.SOUTH, EightDirectionResolver.NORTH_EAST), "backward", "rear diagonal uses backward gait")
	equal(EightDirectionResolver.relative_gait(EightDirectionResolver.SOUTH, EightDirectionResolver.NORTH), "backward", "opposite travel uses backward gait")
	equal(EightDirectionResolver.relative_gait_from_vectors(Vector2i.DOWN, Vector2i.ZERO), "idle", "zero travel remains idle independently of facing")
	equal(EightDirectionResolver.relative_gait(-1, 0), "idle", "invalid direction indices fail closed")

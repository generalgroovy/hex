extends SceneTree
@warning_ignore_start("integer_division")

# Standalone test-only differential oracle. The production pre-payment query
# remains unchanged; compare the new post-cast batch to that original query.
const SEED: int = 609_121
const COUNTS: Array[int] = [0,1,15,16,17,31,32,127,128,129,256]
const PENDING: Array[int] = [0,145,146,144,143,141,179,180,999]
var assertions := 0
var failures := 0
var benchmark_worlds: Array[SimWorld] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for index: int in range(384):
		var world := _fixture(index,rng)
		_compare(world,"original case %d" % index)
		# Same state with different traversal and dictionary insertion order.
		world.players.reverse()
		world.projectiles.reverse()
		world.deposits.reverse()
		world.fields.reverse()
		_compare(world,"reversed case %d" % index)
		if index%13 == 0:
			benchmark_worlds.append(world)
	# Whole five-lane reservation at the exact global and per-owner boundary.
	var edge := SimWorld.new(120,SEED,CollisionWorld.new())
	edge.players.append(PlayerState.new(2))
	edge.players[0].pending_cast_wire_id = CombatTuning.CINDERFAN_WIRE_ID
	_compare(edge,"whole five-lane pending pattern")
	_check(edge._owner_material_slots()[1] == 11,"five pending lanes reserve five, not one")
	edge.players[0].health = 0
	_compare(edge,"defeated pending pattern is ignored")
	_check(edge._owner_material_slots()[1] == 16,"dead pending cast consumes no owner slots")
	edge.players[0].health = edge.players[0].health_maximum
	for index: int in range(123):
		edge.projectiles.append(ProjectileState.new(1000+index,999,1,145,2,Vector2i(100000,100000),Vector2i(1000,0),10800,9000,120))
	_compare(edge,"orphan projectiles plus whole pending pattern fill global capacity")
	_check(edge._owner_material_slots()[1] == 0,"123 orphan projectiles plus five pending lanes leave zero slots")
	edge.projectiles.pop_back()
	_compare(edge,"one global slot remains after full pending reservation")
	_check(edge._owner_material_slots()[1] == 1,"122 orphan projectiles plus five pending lanes leave exactly one slot")
	_benchmark()
	print("%s: owner-material-capacity-equivalence; %d assertions; %d failures; seed=%d; generated_worlds=384" % ["PASS" if failures == 0 else "FAIL",assertions,failures,SEED])
	quit(0 if failures == 0 else 1)

func _fixture(index: int,rng: RandomNumberGenerator) -> SimWorld:
	var world := SimWorld.new(120,SEED,CollisionWorld.new())
	world.players.clear()
	var actor_count: int = [0,1,2,8,8,8][index%6]
	for actor_index: int in range(actor_count):
		var actor := PlayerState.new(actor_index+1)
		actor.pending_cast_wire_id = PENDING[(index+actor_index)%PENDING.size()]
		actor.health = 0 if (index+actor_index)%7 == 0 else actor.health
		world.players.append(actor)
	# These query-only robustness cases are not claims of network-valid worlds.
	# Preserve the old helper's duplicate-entry and missing-owner behavior too.
	if actor_count > 0 and index%7 == 0:
		world.players.append(world.players[0])
	if actor_count > 0 and index%11 == 0:
		var duplicate := PlayerState.new(1)
		duplicate.pending_cast_wire_id = CombatTuning.CINDERFAN_WIRE_ID
		world.players.append(duplicate)
	var projectile_count := COUNTS[index%COUNTS.size()] if index < 121 else rng.randi_range(0,150)
	var deposit_count := COUNTS[(index/COUNTS.size())%COUNTS.size()] if index < 121 else rng.randi_range(0,150)
	for item: int in range(projectile_count):
		var owner := rng.randi_range(0,maxi(1,actor_count+2))
		world.projectiles.append(ProjectileState.new(1000+item,owner,1,145,2,Vector2i(100000,100000),Vector2i(1000,0),10800,9000,120))
	for item: int in range(deposit_count):
		var deposit := ElementDepositState.new()
		deposit.entity_id = 3000+item
		deposit.owner_id = rng.randi_range(0,maxi(1,actor_count+2))
		world.deposits.append(deposit)
	for item: int in range(index%35):
		world.fields.append(FieldState.new(2000+item,rng.randi_range(0,maxi(1,actor_count+2)),1,144,5,Vector2i(100000,100000),86400,120,6,700,650))
	return world

func _compare(world: SimWorld,label: String) -> void:
	var before := _values(world)
	var expected := _legacy_owner_slots(world)
	var actual := world._owner_material_slots()
	_check(actual == expected,label+": all requested owners exactly match the unchanged pre-payment query")
	_check(actual.keys() == expected.keys(),label+": key insertion order and duplicate-owner overwrites remain identical")
	for owner: int in expected:
		_check(int(actual[owner]) == int(expected[owner]),label+": owner %d" % owner)
	_check(_values(world) == before,label+": neither query mutates authoritative arrays or state")

static func _legacy_owner_slots(world: SimWorld) -> Dictionary:
	var result := {}
	for state: PlayerState in world.players:
		result[state.entity_id] = world.available_cast_capacity(state.entity_id).x
	return result

static func _values(world: SimWorld) -> Array:
	var result: Array = []
	for collection: Array in [world.players,world.projectiles,world.deposits,world.fields]:
		var values: Array = []
		for state: RefCounted in collection:
			values.append(state.canonical_values())
		result.append(values)
	return result

func _benchmark() -> void:
	for candidate_first: bool in [false,true]:
		for candidate: bool in [candidate_first,not candidate_first]:
			var checksum := 0
			var began := Time.get_ticks_usec()
			for _repeat: int in range(16):
				for world: SimWorld in benchmark_worlds:
					var result: Dictionary = world._owner_material_slots() if candidate else _legacy_owner_slots(world)
					for value: int in result.values():
						checksum += value
			print("OWNER_CAPACITY_TIMING ",JSON.stringify({"path":"candidate" if candidate else "legacy","calls":benchmark_worlds.size()*16,"elapsed_us":Time.get_ticks_usec()-began,"checksum":checksum,"order":int(candidate_first)}))

func _check(condition: bool,label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		if failures < 20:
			push_error(label)

extends "res://tests/scenarios/runtime_stress_probe.gd"
@warning_ignore_start("integer_division")

# Standalone, bounded diagnostic. Reuses the paid mixed workload unchanged.
# The frozen oracle below is the pre-guard production helper verbatim.
# Post-step survivor samples are representative queries, NOT exact hot-call
# counts: terminated projectiles are deliberately not reconstructed here.
const QUERY_SEED: int = 609_122
var query_count := 0
var broad_misses := 0
var real_queries: Array[Array] = []
var edge_queries: Array[Array] = []

func _run() -> void:
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities), "champions load")
	_edges()
	var edge_misses := broad_misses
	var world := _make_world(8,0,true)
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	var event_counts := {}
	for _warmup: int in range(WARMUP_TICKS):
		_check(world.step(_commands(world,false,false)), "warmup step")
		_trace_tick(world,trace,event_counts)
	var candidate_counts: Array[int] = []
	for sample_index: int in range(LEGAL_TICKS):
		_check(world.step(_commands(world,true,false,true)), "paid mixed step")
		_trace_tick(world,trace,event_counts)
		var count := 0
		for projectile: ProjectileState in world.projectiles:
			for target: PlayerState in world.players:
				if target.entity_id == projectile.owner_id or target.team_id == projectile.team_id or target.health <= 0 or target.spawn_protection_ticks > 0:
					continue
				count += 1
				if sample_index%12 == 0:
					var query := _query(Vector2i(projectile.previous_x,projectile.previous_y),Vector2i(projectile.position_x,projectile.position_y),Vector2i(target.position_x,target.position_y),target.radius+projectile.radius)
					_compare(query)
					real_queries.append(query)
		candidate_counts.append(count)
	var cleanup_ticks := 0
	while cleanup_ticks < CLEANUP_LIMIT and (not world.projectiles.is_empty() or not world.fields.is_empty() or _has_pending_cast(world) or not world.deposits.is_empty() or not world.reactions.is_empty()):
		_check(world.step(_commands(world,false,false)),"natural cleanup step")
		_trace_tick(world,trace,event_counts)
		cleanup_ticks += 1
	_check(world.projectiles.is_empty() and world.fields.is_empty() and world.deposits.is_empty() and world.reactions.is_empty() and not _has_pending_cast(world),"all material naturally expires")
	_check(world.step([]),"final idle step")
	_trace_tick(world,trace,event_counts)
	print("CIRCLE_QUERY_META ",JSON.stringify({"seed":QUERY_SEED,"world_seed":SEED,"source_combat_sha256":FileAccess.get_sha256("res://src/sim/combat/combat_system.gd"),"runtime_probe_sha256":FileAccess.get_sha256("res://tests/scenarios/runtime_stress_probe.gd"),"sample_stride_ticks":12,"real_survivor_queries":real_queries.size(),"real_broad_misses":broad_misses-edge_misses,"all_queries":query_count,"broad_misses":broad_misses,"survivor_eligible_pairs_per_tick":_percentiles(PackedInt64Array(candidate_counts)),"final_hash":world.state_hash(),"all_tick_state_and_event_trace_sha256":trace.finish().hex_encode(),"event_counts":event_counts,"cleanup_ticks":cleanup_ticks,"scope":"post-step survivor queries; excludes terminated projectiles; not exact production invocation counts; trace covers every warmup/measured/cleanup/idle state and ordered event batch"}))
	_benchmark(real_queries,"paid-mixed-survivors")
	_benchmark(edge_queries,"boundary-and-near-hit")
	_benchmark(_cluster_queries(),"synthetic-eight-target-close-cluster",32)
	if OS.get_cmdline_user_args().has("--with-suites"):
		for script: Script in [preload("res://tests/unit/test_combat.gd"),preload("res://tests/unit/test_projectile_chemistry_integration.gd")]:
			var suite = script.new()
			failures += suite.run()
			assertions += suite.assertions
	print("%s: projectile-circle-equivalence; %d assertions; %d failures; queries=%d" % ["PASS" if failures == 0 else "FAIL",assertions,failures,query_count])
	quit(0 if failures == 0 else 1)

func _trace_tick(world: SimWorld,trace: HashingContext,event_counts: Dictionary) -> void:
	trace.update(world.state_hash().to_utf8_buffer())
	trace.update(var_to_bytes(world.combat_events))
	for event: Dictionary in world.combat_events:
		var kind := String(event.get("type",""))
		event_counts[kind] = int(event_counts.get(kind,0))+1

func _edges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = QUERY_SEED
	# Signed coordinates, zero/reversed motion, truncation, tangency, broad-box
	# corners, negative-radius legacy fallback, and extremes without int overflow.
	for index: int in range(1024):
		var start := Vector2i(rng.randi_range(-100000000,100000000),rng.randi_range(-100000000,100000000))
		var delta := Vector2i(rng.randi_range(-120001,120001),rng.randi_range(-120001,120001))
		if index%8 == 0: delta = Vector2i.ZERO
		if index%8 == 1: delta.y = 0
		if index%8 == 2: delta.x = 0
		if index%8 == 3: delta = Vector2i(-1,3)
		var finish := start+delta
		var radius: int = [0,1,2,10800,28777,80000,-1,-28777][index%8]
		var extent := absi(radius)
		var middle := Vector2i(start.x+delta.x/2,start.y+delta.y/2)
		var points: Array[Vector2i] = [start,finish,middle,start+Vector2i(extent,0),start+Vector2i(extent+1,0),start-Vector2i(0,extent),start-Vector2i(0,extent+1),middle+Vector2i(extent,extent),start+Vector2i(rng.randi_range(-500001,500001),rng.randi_range(-500001,500001))]
		for point: Vector2i in points:
			for reversed: bool in [false,true]:
				var query := _query(finish if reversed else start,start if reversed else finish,point,radius)
				_compare(query)
				if index%16 == 0 or index%16 == 1:
					edge_queries.append(query)
	# One mutable instance; no stale endpoint/target/radius state is admissible.
	var mutable := _query(Vector2i(-3,-2),Vector2i(4,1),Vector2i(0,0),1)
	for index: int in range(64):
		(mutable[0] as ProjectileState).position_x = index-32
		(mutable[1] as PlayerState).position_y = 32-index
		mutable[2] = index%4-1
		_compare(mutable)

func _query(start: Vector2i,finish: Vector2i,point: Vector2i,radius: int) -> Array:
	var projectile := ProjectileState.new(100,1,1,179,2,finish,Vector2i.ZERO,1000,9000,120)
	projectile.previous_x = start.x
	projectile.previous_y = start.y
	var target := PlayerState.new(2)
	target.position_x = point.x
	target.position_y = point.y
	return [projectile,target,radius]

func _compare(query: Array) -> void:
	query_count += 1
	var projectile: ProjectileState = query[0]
	var target: PlayerState = query[1]
	var radius: int = query[2]
	var before_projectile := projectile.canonical_values()
	var before_target := target.canonical_values()
	var expected := _legacy_segment_circle_hit(projectile,target,radius)
	_check(_candidate_segment_circle_hit(projectile,target,radius) == expected,"candidate matches frozen integer oracle query %d" % query_count)
	_check(CombatSystem._segment_circle_hit(projectile,target,radius) == expected,"production matches frozen integer oracle query %d" % query_count)
	_check(projectile.canonical_values() == before_projectile and target.canonical_values() == before_target,"query is pure")
	if radius >= 0 and (target.position_x < mini(projectile.previous_x,projectile.position_x)-radius or target.position_x > maxi(projectile.previous_x,projectile.position_x)+radius or target.position_y < mini(projectile.previous_y,projectile.position_y)-radius or target.position_y > maxi(projectile.previous_y,projectile.position_y)+radius):
		broad_misses += 1

func _cluster_queries() -> Array[Array]:
	# Query-only density counterexample, not injected or free casts in a game.
	# Nearby targets expose the broadphase's extra cost when bounds overlap.
	var queries: Array[Array] = []
	for index: int in range(128):
		var start := Vector2i(1000000+(index%16)*5000,1000000+(index/16)*5000)
		for actor: int in range(8):
			var query := _query(start,start+Vector2i(4001,-3001),Vector2i(1010000+(actor%4)*12000,1010000+(actor/4)*12000),32000)
			_compare(query)
			queries.append(query)
	return queries

func _benchmark(queries: Array[Array],label: String,repeats: int = 4) -> void:
	for candidate_first: bool in [false,true]:
		for candidate: bool in [candidate_first,not candidate_first]:
			var checksum := 0
			var began := Time.get_ticks_usec()
			for _repeat: int in range(repeats):
				for query: Array in queries:
					checksum += int(_candidate_segment_circle_hit(query[0],query[1],query[2]) if candidate else _legacy_segment_circle_hit(query[0],query[1],query[2]))
			print("CIRCLE_QUERY_BENCH ",JSON.stringify({"workload":label,"candidate_first":candidate_first,"candidate":candidate,"calls":queries.size()*repeats,"elapsed_us":Time.get_ticks_usec()-began,"checksum":checksum}))

static func _candidate_segment_circle_hit(projectile: ProjectileState,target: PlayerState,radius: int) -> bool:
	if radius >= 0 and (target.position_x < mini(projectile.previous_x,projectile.position_x)-radius or target.position_x > maxi(projectile.previous_x,projectile.position_x)+radius or target.position_y < mini(projectile.previous_y,projectile.position_y)-radius or target.position_y > maxi(projectile.previous_y,projectile.position_y)+radius):
		return false
	var delta_x: int = projectile.position_x - projectile.previous_x
	var delta_y: int = projectile.position_y - projectile.previous_y
	var offset_x: int = target.position_x - projectile.previous_x
	var offset_y: int = target.position_y - projectile.previous_y
	var length_squared: int = delta_x * delta_x + delta_y * delta_y
	if length_squared == 0:
		return offset_x * offset_x + offset_y * offset_y <= radius * radius
	var projection: int = clampi(offset_x * delta_x + offset_y * delta_y, 0, length_squared)
	var closest_x: int = projectile.previous_x + delta_x * projection / length_squared
	var closest_y: int = projectile.previous_y + delta_y * projection / length_squared
	var distance_x: int = target.position_x - closest_x
	var distance_y: int = target.position_y - closest_y
	return distance_x * distance_x + distance_y * distance_y <= radius * radius

static func _legacy_segment_circle_hit(projectile: ProjectileState, target: PlayerState, radius: int) -> bool:
	var delta_x: int = projectile.position_x - projectile.previous_x
	var delta_y: int = projectile.position_y - projectile.previous_y
	var offset_x: int = target.position_x - projectile.previous_x
	var offset_y: int = target.position_y - projectile.previous_y
	var length_squared: int = delta_x * delta_x + delta_y * delta_y
	if length_squared == 0:
		return offset_x * offset_x + offset_y * offset_y <= radius * radius
	var projection: int = clampi(offset_x * delta_x + offset_y * delta_y, 0, length_squared)
	@warning_ignore("integer_division")
	var closest_x: int = projectile.previous_x + delta_x * projection / length_squared
	@warning_ignore("integer_division")
	var closest_y: int = projectile.previous_y + delta_y * projection / length_squared
	var distance_x: int = target.position_x - closest_x
	var distance_y: int = target.position_y - closest_y
	return distance_x * distance_x + distance_y * distance_y <= radius * radius

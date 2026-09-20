extends SceneTree
@warning_ignore_start("integer_division")

# Standalone, bounded differential probe. The oracle below is the exact sampled
# entry algorithm before the broadphase guard; do not rewrite it with bounds.
# Run with --headless --path . --script res://tests/scenarios/chemistry_broadphase_equivalence.gd
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const SEED: int = 609_120
const SEGMENT_BENCH_REPEATS: int = 16
var failures := 0
var assertions := 0
var queries: Array = []
var rejected := 0
var query_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := SimConfig.new(120)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var directions: Array[Vector2i] = []
	directions.assign(EightDirectionResolver.FIXED_VECTORS)
	directions.append_array([Vector2i(999,1),Vector2i(-731,317),Vector2i(1,-999)])
	var wires: Array[int] = [-1,0,300,337]
	for wire: int in range(301,337):
		wires.append(wire)
	for wire: int in wires:
		for direction: Vector2i in directions:
			var state := _state(wire,direction)
			for variant: int in range(3):
				# Reuse and mutate the SAME instance, including endpoint values
				# deliberately unrelated to the current center/length/direction.
				var origin := [Vector2i(500000,500000),Vector2i(-700001,-800003),Vector2i(99500000,99500000)][variant] as Vector2i
				state.position_x = origin.x
				state.position_y = origin.y
				state.length = int(Chemistry.recipe(wire).get("length",24000)) + (3 if variant == 1 else 0)
				if variant == 2:
					state.length = 0
				state.radius = int(Chemistry.recipe(wire).get("radius",18000)) + variant
				var endpoint := origin+Chemistry.scaled(direction,state.length)+Vector2i(17003,-29001)
				state.endpoint_x = endpoint.x
				state.endpoint_y = endpoint.y
				state.path_points = PackedInt64Array() if variant == 0 else PackedInt64Array([origin.x,origin.y,endpoint.x,endpoint.y,origin.x+245001,origin.y-130003])
				var tick: int = [state.active_tick-1,state.active_tick+26,state.decay_tick][variant]
				var side := Chemistry.scaled(Vector2i(-direction.y,direction.x),state.length/2)
				var points: Array[Vector2i] = [origin,endpoint,origin+side,origin-side,
					origin+Vector2i(state.radius,0),origin+Vector2i(state.radius+1,0),
					origin-Vector2i(state.radius,0),origin-Vector2i(state.radius+1,0),
					origin+side+Vector2i(state.radius,0),origin-side-Vector2i(0,state.radius)]
				for point: Vector2i in points:
					_compare(state,point,point,tick,config)
				# Tangent, crossing, reversed, short signed truncation and the
				# 512-sample cap, without 32-bit vector or 64-bit product overflow.
				_compare(state,origin+Vector2i(-220001,state.radius),origin+Vector2i(220003,state.radius),tick,config)
				_compare(state,origin+Vector2i(220003,17),origin+Vector2i(-220001,-19),tick,config)
				_compare(state,origin+Vector2i(-1,2001),origin+Vector2i(1,-1999),tick,config)
				_compare(state,origin+Vector2i(-600001,230001),origin+Vector2i(600003,230001),tick,config)
				for _sample: int in range(4):
					var start := origin+Vector2i(rng.randi_range(-300001,300001),rng.randi_range(-300001,300001))
					var end := start+Vector2i(rng.randi_range(-120001,120001),rng.randi_range(-120001,120001))
					_compare(state,start,end,tick,config)
	# Public integration checks cover mutated health/capacity, damage budgets,
	# beam approach/continuation, worldbone clipping and interaction masks.
	for script: Script in [preload("res://tests/unit/test_element_chemistry.gd"),preload("res://tests/unit/test_projectile_chemistry_integration.gd"),preload("res://tests/unit/test_combat.gd")]:
		var suite = script.new()
		failures += suite.run()
		assertions += suite.assertions
	_benchmark(config)
	_segment_benchmark(config)
	print("%s: chemistry-broadphase-equivalence; %d assertions; %d failures; seed=%d; queries=%d; rejected=%d" % ["PASS" if failures == 0 else "FAIL",assertions,failures,SEED,query_count,rejected])
	quit(0 if failures == 0 else 1)

func _state(wire: int,direction: Vector2i) -> ElementReactionState:
	var state := ElementReactionState.new()
	state.entity_id = 4000
	state.recipe_wire_id = wire
	state.owner_id = 1
	state.team_id = 1
	state.source_a = 1
	state.source_b = 2
	state.active_tick = 30
	state.decay_tick = 200
	state.expiry_tick = 250
	state.direction_x = direction.x
	state.direction_y = direction.y
	return state

func _compare(state: ElementReactionState,start: Vector2i,end: Vector2i,tick: int,config: SimConfig) -> void:
	query_count += 1
	var before := state.canonical_values()
	var expected := _legacy_entry_point(state,start,end,tick,config)
	var actual := Chemistry._entry_point(state,start,end,tick,config)
	var segment_hit := Chemistry._segment_enters(state,start,end,tick,config)
	assertions += 3
	if actual != expected:
		failures += 1
		if failures < 20:
			push_error("entry changed wire=%d start=%s end=%s tick=%d expected=%s actual=%s" % [state.recipe_wire_id,start,end,tick,expected,actual])
	if segment_hit != bool(actual["hit"]):
		failures += 1
		if failures < 20:
			push_error("segment hit changed wire=%d start=%s end=%s tick=%d expected=%s actual=%s" % [state.recipe_wire_id,start,end,tick,bool(actual["hit"]),segment_hit])
	if state.canonical_values() != before:
		failures += 1
		push_error("entry query mutated authoritative reaction state")
	if not Chemistry._entry_bounds_overlap(state,start,end):
		rejected += 1
	# Keep only a small frozen sample for the separate diagnostic timing pass.
	if queries.size() < 512 and assertions%100 == 0:
		var frozen := _state(state.recipe_wire_id,Vector2i(state.direction_x,state.direction_y))
		for field: String in ["position_x","position_y","radius","length","endpoint_x","endpoint_y"]:
			frozen.set(field,state.get(field))
		frozen.path_points = state.path_points.duplicate()
		queries.append([frozen,start,end,tick])

func _benchmark(config: SimConfig) -> void:
	# Same frozen input order and repeat count; timings are diagnostic only.
	# No hardware-independent speed threshold belongs in a correctness test.
	for candidate_first: bool in [false,true]:
		for candidate: bool in [candidate_first,not candidate_first]:
			var checksum := 0
			var began := Time.get_ticks_usec()
			for _repeat: int in range(3):
				for query: Array in queries:
					var result: Dictionary = Chemistry._entry_point(query[0],query[1],query[2],query[3],config) if candidate else _legacy_entry_point(query[0],query[1],query[2],query[3],config)
					checksum += int(result["hit"])
			var elapsed := Time.get_ticks_usec()-began
			print("CHEMISTRY_ENTRY_TIMING ",JSON.stringify({"path":"candidate" if candidate else "legacy","calls":queries.size()*3,"elapsed_us":elapsed,"checksum":checksum,"order":int(candidate_first)}))

func _segment_benchmark(config: SimConfig) -> void:
	# Compare only the changed boolean path against the unchanged Dictionary
	# result. Warm both, alternate measurement order, and gate equal checksums;
	# elapsed time remains diagnostic and has no hardware-independent threshold.
	var warm_oracle := 0
	var warm_candidate := 0
	for query: Array in queries:
		warm_oracle += int(bool(Chemistry._entry_point(query[0],query[1],query[2],query[3],config)["hit"]))
		warm_candidate += int(Chemistry._segment_enters(query[0],query[1],query[2],query[3],config))
	assertions += 1
	if warm_candidate != warm_oracle:
		failures += 1
		push_error("warmed segment checksum differs from unchanged entry oracle")
	for candidate_first: bool in [false,true]:
		var checksums := {}
		for candidate: bool in [candidate_first,not candidate_first]:
			var checksum := 0
			var began := Time.get_ticks_usec()
			for _repeat: int in range(SEGMENT_BENCH_REPEATS):
				for query: Array in queries:
					var hit := Chemistry._segment_enters(query[0],query[1],query[2],query[3],config) if candidate else bool(Chemistry._entry_point(query[0],query[1],query[2],query[3],config)["hit"])
					checksum += int(hit)
			var elapsed := Time.get_ticks_usec()-began
			checksums["candidate" if candidate else "oracle"] = checksum
			print("CHEMISTRY_SEGMENT_TIMING ",JSON.stringify({"path":"candidate" if candidate else "oracle_entry_dictionary","calls":queries.size()*SEGMENT_BENCH_REPEATS,"elapsed_us":elapsed,"checksum":checksum,"order":int(candidate_first)}))
		assertions += 1
		if int(checksums.get("candidate",-1)) != int(checksums.get("oracle",-2)):
			failures += 1
			push_error("measured segment checksum differs from unchanged entry oracle")

static func _legacy_entry_point(result: ElementReactionState,start: Vector2i,end: Vector2i,tick: int,config: SimConfig) -> Dictionary:
	var delta := end-start
	var count := mini(512,maxi(1,(SimCommand._integer_square_root(delta.length_squared())+1999)/2000))
	for index: int in range(count+1):
		var point := start+Chemistry.scaled(delta,index*1000/count)
		if Chemistry.contains(result,point,tick,config):
			return {"hit":true,"point":point}
	return {"hit":false,"point":end}

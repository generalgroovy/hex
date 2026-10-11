extends FluxTestSuite
const Workset = preload("res://src/sim/hex/hex_contact_workset.gd")
const Snapshot = preload("res://src/net/hex_chemistry_snapshot.gd")

func run() -> int:
	_test_queue()
	_test_spatial()
	_test_stationary_membership()
	_test_topology_bytes()
	return finish("hex-contact-workset")

func _test_queue() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 57381
	var queue := Workset.OrderedQueue.new(HexProjectileCombat._ordered)
	var reference: Array[Dictionary] = []
	for index: int in 800:
		var event := {"fraction":float(random.randi_range(0,15))/16.0,"priority":random.randi_range(0,3),"first":random.randi_range(1,20),"second":random.randi_range(1,20),"serial":index}
		queue.append(event)
		reference.append(event)
	reference.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if HexProjectileCombat._ordered(a,b): return true
		if HexProjectileCombat._ordered(b,a): return false
		return int(a.serial)<int(b.serial))
	for expected: Dictionary in reference: equal(queue.pop_front(),expected,"heap preserves total contact order and stable ties")
	check(queue.is_empty(),"queue drains")
	queue.append({"fraction":0.5,"priority":0,"first":1,"second":2})
	var moved := queue.pop_front()
	moved.fraction = 0.75
	queue.append(moved)
	equal(queue.pop_front().fraction,0.75,"revalidation reinserts changed TOI")

func _test_spatial() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 2357
	var plans: Array[Dictionary] = []
	for index: int in 120:
		var start := Vector2i(random.randi_range(-600000,600000),random.randi_range(-600000,600000))
		plans.append({"entity_id":index+1,"start":start,"finish":start+Vector2i(random.randi_range(-40000,40000),random.randi_range(-40000,40000)),"radius":random.randi_range(0,30000)})
	var spatial := Workset.SpatialPlans.new(plans)
	for iteration: int in 2:
		for plan: Dictionary in plans:
			var expected: Array[Dictionary] = []
			for other: Dictionary in plans:
				var a := Workset.SpatialPlans.bounds(plan)
				var b := Workset.SpatialPlans.bounds(other)
				if not (a.end.x < b.position.x or b.end.x < a.position.x or a.end.y < b.position.y or b.end.y < a.position.y): expected.append(other)
			equal(spatial.query(plan),expected,"spatial candidates equal exhaustive swept bounds in original order")
		plans[0].start = Vector2i(-128000,-128000)
		plans[0].finish = Vector2i(256000,256000)
		spatial.update(plans[0])
	var touching: Array[Dictionary] = [{"entity_id":1,"start":Vector2i.ZERO,"finish":Vector2i(128000,0),"radius":0},{"entity_id":2,"start":Vector2i(128000,0),"finish":Vector2i(256000,0),"radius":0}]
	var boundary := Workset.SpatialPlans.new(touching)
	equal(boundary.query(touching[0]).size(),2,"zero-radius boundary touch is never culled")

func _test_stationary_membership() -> void:
	var court := HexChemistryWorld.new()
	court.casts[1] = {"coverage":{Vector2i.ZERO:1}}
	var first := court.occupied_cells()
	first.clear()
	equal(court.occupied_cells(),{Vector2i.ZERO:1},"caller cannot corrupt membership cache")
	court.casts[1].coverage[Vector2i(1,0)] = 1
	equal(court.occupied_cells().size(),2,"direct coverage mutation invalidates cache without revision")
	court.casts.clear()
	check(court.occupied_cells().is_empty(),"expiry/removal invalidates membership")

func _test_topology_bytes() -> void:
	var court := HexChemistryWorld.new()
	var cells: Array[Vector2i] = [Vector2i(2,-5),Vector2i(-3,2),Vector2i.ZERO]
	check(court.configure_geometry(Vector2i(-13000,41000),cells),"topology fixture")
	court.cells[Vector2i.ZERO].terrain = -4
	var ordered := Snapshot._trusted_cells(court)
	var old := cells.duplicate()
	old.sort_custom(HexGrid._cell_less)
	equal(ordered,old,"native sort keeps canonical order")
	var bytes := PackedByteArray()
	for value: int in [court.origin.x,court.origin.y,ordered.size()]: CanonicalBytes.append_i64(bytes,value)
	for cell: Vector2i in ordered:
		for value: int in [cell.x,cell.y,court.cells[cell].terrain,court.cells[cell].elevation,court.cells[cell].structure]: CanonicalBytes.append_i64(bytes,value)
	equal(Snapshot._topology_hash(court,ordered),CanonicalBytes.sha256_hex(bytes),"preallocated topology bytes preserve exact published hash")

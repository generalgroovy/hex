extends FluxTestSuite


func run() -> int:
	var origin := Vector2i(100_000, 200_000)
	var end := Vector2i(500_000, 200_000)
	var center := Vector2i(300_000, 200_000)
	equal(ContinuousContact.circle_toi(origin, end, center, 20_000), 0.45, "circle uses first swept contact, not tick endpoint")
	equal(ContinuousContact.point_at(origin, end, 0.45), Vector2i(280_000, 200_000), "continuous point quantizes once to fixed world coordinates")
	equal(ContinuousContact.circle_toi(origin, end, Vector2i(300_000, 220_000), 20_000), 0.5, "closed tangent is a contact")
	equal(ContinuousContact.circle_toi(origin, end, Vector2i(300_000, 220_001), 20_000), -1.0, "one-unit tangent miss remains outside")
	equal(ContinuousContact.circle_toi(center, center, center, 1), 0.0, "stationary overlap starts at zero")
	equal(ContinuousContact.circle_toi(-end, -origin, -center, 20_000), 0.45, "negative coordinates preserve first contact")
	var world := CollisionWorld.new(1_280_000, 960_000)
	world.add_obstacle(CollisionWorld.Obstacle.new(7, 300_000, 180_000, 320_000, 220_000))
	var wall := ContinuousContact.wall_contact(origin, end, 10_000, world)
	equal(wall.center, Vector2i(290_000, 200_000), "wall center respects existing projectile clearance")
	equal(wall.point, Vector2i(300_000, 200_000), "effect originates on wall surface rather than displaced projectile center")
	_test_actor_order()
	_test_wall_and_range()
	_test_diagonal_contacts_and_range()
	_test_indexed_wall_queries()
	return finish("continuous-contact")


func _test_indexed_wall_queries() -> void:
	var indexed := CollisionWorld.new(4000000,3000000)
	var exhaustive := CollisionWorld.new(4000000,3000000)
	var random := RandomNumberGenerator.new()
	random.seed=915821
	for index: int in 120:
		var x := random.randi_range(100000,3700000)
		var y := random.randi_range(100000,2700000)
		indexed.add_obstacle(CollisionWorld.Obstacle.new(index+1,x,y,x+90000,y+60000))
		exhaustive.add_obstacle(CollisionWorld.Obstacle.new(index+1,x,y,x+90000,y+60000))
	# Public obstacle exposure deliberately disables the index and exercises the
	# original full scan; both paths retain the same narrow phase and tie rules.
	var exposed := exhaustive.obstacles
	equal(exposed.size(),120,"oracle full scan configured")
	for index: int in 700:
		var start := Vector2i(random.randi_range(0,4000000),random.randi_range(0,3000000))
		var end := start+Vector2i(random.randi_range(-150000,150000),random.randi_range(-150000,150000))
		if index%7==0: end=Vector2i(random.randi_range(0,4000000),random.randi_range(0,3000000))
		if index%11==0: end=start
		var radius: int = [0,1000,18000,32000][index%4]
		equal(ContinuousContact.wall_contact(start,end,radius,indexed),ContinuousContact.wall_contact(start,end,radius,exhaustive),"indexed swept wall contact matches original scan including boundaries")
	indexed.add_obstacle(CollisionWorld.Obstacle.new(999,200000,200000,220000,220000))
	exhaustive.add_obstacle(CollisionWorld.Obstacle.new(999,200000,200000,220000,220000))
	equal(ContinuousContact.wall_contact(Vector2i(150000,210000),Vector2i(250000,210000),0,indexed),ContinuousContact.wall_contact(Vector2i(150000,210000),Vector2i(250000,210000),0,exhaustive),"new walls invalidate index without stale visibility")


func _shot() -> ProjectileState:
	var shot := ProjectileState.new(10, 1, 1, 140, 3, Vector2i(100_000, 200_000), Vector2i(48_000_000, 0), 10_000, 9000, 100)
	shot.reaction_strength = 5
	return shot


func _test_actor_order() -> void:
	var far := PlayerState.new(2)
	far.team_id = 2
	far.position_x = 420_000
	far.position_y = 200_000
	var near := PlayerState.new(9)
	near.team_id = 2
	near.position_x = 260_000
	near.position_y = 200_000
	var shot := _shot()
	var events: Array[Dictionary] = []
	var survivors := CombatSystem.advance_projectiles([shot], [far, near], SimConfig.new(120), CollisionWorld.new(), events)
	equal(survivors.size(), 0, "first actor consumes the projectile")
	equal(far.health, far.health_maximum, "lower entity id cannot steal a later contact")
	equal(near.health, near.health_maximum - 9000, "nearest swept eligible actor is hit")
	var terminal := _terminal(events)
	equal(terminal.position, Vector2i(near.position_x - near.radius, 200_000), "actor terminal is physical contact surface")


func _test_wall_and_range() -> void:
	var world := CollisionWorld.new()
	world.add_obstacle(CollisionWorld.Obstacle.new(7, 300_000, 180_000, 320_000, 220_000))
	var events: Array[Dictionary] = []
	CombatSystem.advance_projectiles([_shot()], [], SimConfig.new(120), world, events)
	equal(_terminal(events).position, Vector2i(300_000, 200_000), "production obstacle terminal uses actual swept wall contact")
	var shot := _shot()
	shot.remaining_distance = 25_000
	events.clear()
	CombatSystem.advance_projectiles([shot], [], SimConfig.new(120), CollisionWorld.new(), events)
	equal(_terminal(events).position, Vector2i(125_000, 200_000), "range terminal uses clamped actual endpoint")


func _terminal(events: Array[Dictionary]) -> Dictionary:
	for event: Dictionary in events:
		if event.get("type", "") == "projectile_terminal": return event
	return {}


func _test_diagonal_contacts_and_range() -> void:
	var start := Vector2i(671_203, 798_930)
	var finish_point := Vector2i(901_787, 798_750)
	var target := Vector2i(694_505, 771_255)
	var fraction := ContinuousContact.circle_toi(start, finish_point, target, 30_000)
	equal(ContinuousContact.circle_contact(start, finish_point, fraction, target, 18_000), Vector2i(687_544, 787_855), "diagonal actor surface is quantized once from continuous contact")
	var actor := PlayerState.new(2)
	actor.team_id = 2
	actor.position_x = target.x
	actor.position_y = target.y
	var diagonal_shot := ProjectileState.new(10, 1, 1, 140, 3, start, (finish_point - start) * 120, 12_000, 9000, 100)
	diagonal_shot.reaction_strength = 5
	var diagonal_events: Array[Dictionary] = []
	CombatSystem.advance_projectiles([diagonal_shot], [actor], SimConfig.new(120), CollisionWorld.new(1_280_000, 960_000), diagonal_events)
	equal(_terminal(diagonal_events).position, Vector2i(687_544, 787_855), "production actor terminal preserves single-quantized diagonal contact")
	var world := CollisionWorld.new()
	world.add_obstacle(CollisionWorld.Obstacle.new(7, 300_000, 180_000, 320_000, 220_000))
	var corner := ContinuousContact.wall_contact(Vector2i(280_000, 160_000), Vector2i(320_000, 200_000), 10_000, world)
	equal(corner.point, Vector2i(300_000, 180_000), "diagonal square-clearance entry produces the physical obstacle corner")
	check(ContinuousContact.wall_contact(Vector2i(290_000, 200_000), Vector2i(280_000, 200_000), 10_000, world).is_empty(), "a tangent projectile may separate from the obstacle face")
	var shot := _shot()
	shot.velocity_x = 1001 * 120
	shot.velocity_y = 500 * 120
	shot.remaining_distance = 1118
	var events: Array[Dictionary] = []
	CombatSystem.advance_projectiles([shot], [], SimConfig.new(120), CollisionWorld.new(), events)
	equal(_terminal(events).position, Vector2i(101_000, 200_500), "floor-equality diagonal range clamps to actual continuous endpoint")
	shot = _shot()
	shot.velocity_x = 1001 * 120
	shot.velocity_y = 500 * 120
	shot.remaining_distance = 200_000
	var shots: Array[ProjectileState] = [shot]
	for _tick: int in range(100):
		shots = CombatSystem.advance_projectiles(shots, [], SimConfig.new(120), CollisionWorld.new(), [])
	var step_subunits := roundi(sqrt(1_252_001.0) * ProjectileState.RANGE_SUBUNITS)
	equal(shot.remaining_distance * ProjectileState.RANGE_SUBUNITS - shot.range_subunit, 200_000 * ProjectileState.RANGE_SUBUNITS - 100 * step_subunits, "fractional diagonal distance carries across ticks without floor drift")

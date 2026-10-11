extends FluxTestSuite
@warning_ignore_start("integer_division")

const BeforeCollision = preload("res://tests/support/collision_before_empty_work.gd")
const BeforeChemistry = preload("res://tests/support/chemistry_before_empty_work.gd")
const ORIGIN := Vector2i(600_000, 500_000)
const BOLTS := {1:159, 2:145, 3:140, 4:163, 7:173, 8:142}


class QuerySpy:
	extends CollisionWorld
	var queries := 0
	func _candidate_obstacles(minimum: Vector2i, maximum: Vector2i) -> Array[Obstacle]:
		queries += 1
		return super._candidate_obstacles(minimum, maximum)


func run() -> int:
	_test_collision_equivalence()
	_test_no_stationary_obstacle_work()
	_test_product_effects_equivalence()
	_test_flight_retirement_equivalence()
	_test_complete_fixed_step_equivalence()
	return finish("sim-empty-work")


func _populate(world: CollisionWorld, count: int) -> void:
	for index: int in count:
		var at := Vector2i(100_000 + (index % 7) * 120_000, 80_000 + (index / 7) * 90_000)
		world.add_obstacle(CollisionWorld.Obstacle.new(index + 1, at.x, at.y, at.x + 50_000, at.y + 40_000))


func _test_collision_equivalence() -> void:
	# Includes indexed/linear worlds, overlapping starts, tangent contacts, exact
	# borders, outside positions, negative radii and radii larger than the map.
	var positions: Array[Vector2i] = [Vector2i.ZERO, Vector2i(-1,-1), Vector2i(1_280_001,720_001), Vector2i(1_280_001,200_000), Vector2i(200_000,-1), Vector2i(125_000,100_000), Vector2i(82_000,100_000), Vector2i(600_000,500_000)]
	var deltas: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1,0), Vector2i(0,-1), Vector2i(180_000,90_000), Vector2i(-180_000,-90_000)]
	for count: int in [0, 5, 49]:
		var current := CollisionWorld.new()
		var before := BeforeCollision.new()
		_populate(current, count)
		_populate(before, count)
		for exposed: bool in [false, true]:
			if exposed:
				current.obstacles.append(CollisionWorld.Obstacle.new(100,510_000,400_000,550_000,600_000))
				before.obstacles.append(CollisionWorld.Obstacle.new(100,510_000,400_000,550_000,600_000))
			for radius: int in [-1, 0, 18_000, 32_000, 800_000]:
				for point: Vector2i in positions:
					for delta: Vector2i in deltas:
						var actual := current.move_box(point, delta, radius)
						var expected := before.move_box(point, delta, radius)
						var label := "collision count%d exposed%s radius%d at%s delta%s" % [count,exposed,radius,point,delta]
						equal(actual.position, expected.position, label + " position")
						equal(actual.wall_normal, expected.wall_normal, label + " normal")
						equal(actual.wall_id, expected.wall_id, label + " wall ID")
						equal(actual.blocking_normals, expected.blocking_normals, label + " constraints")


func _test_no_stationary_obstacle_work() -> void:
	var spy := QuerySpy.new()
	_populate(spy, 49)
	for point: Vector2i in [Vector2i(600_000,500_000),Vector2i(-1,-1),Vector2i(1_300_000,800_000)]:
		spy.move_box(point, Vector2i.ZERO, 18_000)
	equal(spy.queries, 0, "stationary collision performs no obstacle candidate lookup")
	check(spy._obstacle_index_dirty, "stationary collision does not build an unused spatial index")
	spy.move_box(Vector2i(600_000,500_000), Vector2i(1,0), 18_000)
	equal(spy.queries, 1, "even one fixed unit of motion retains real indexed collision")
	check(not spy._obstacle_index_dirty, "actual movement builds the normal spatial index")
	var outside := spy.move_box(Vector2i(-1,-1), Vector2i.ZERO, 18_000)
	equal(outside.position, Vector2i(18_000,18_000), "zero movement preserves both bounds corrections")
	equal(outside.wall_id, -2, "Y bounds retain precedence over X for a stationary outside actor")
	equal(outside.wall_normal, Vector2i.ZERO, "bounds correction invents no signed impact normal")


func _court(before: bool = false) -> HexChemistryWorld:
	var court: HexChemistryWorld = BeforeChemistry.new() if before else HexChemistryWorld.new()
	check(court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 8)), "small exact chemistry topology configures")
	court.chemistry_enabled = true
	return court


func _actors() -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	for index: int in 30:
		var actor := PlayerState.new(index + 1)
		actor.position_x = ORIGIN.x + (index % 3) * 50_000
		actor.position_y = ORIGIN.y + (index / 3) * 10_000
		actor.spawn_protection_ticks = 0
		actor.health_recovery_per_second = 0
		actor.health = 100_000
		actor.health_maximum = 100_000
		if index > 0: actor.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
		result.append(actor)
	return result


func _actor_values(actor: PlayerState) -> Dictionary:
	# Compare every script field, including timers/status/remainders not used by
	# this optimization. No reduced rendering or prediction view stands in for it.
	var result := {}
	for property: Dictionary in actor.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
		var value: Variant = actor.get(property.name)
		result[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func _form(court: HexChemistryWorld, wire: int) -> bool:
	var elements: Array = HexRecipePolicy.definition(wire).get("elements", [])
	if elements.size() != 2: return false
	for part: int in 2:
		if not court.reserve_cast(1, int(BOLTS[int(elements[part])])): return false
		court.commit_payment(1)
		court.bind_release(1, 100 + part, ORIGIN, Vector2i(1000,0), 1)
	return bool(court.resolve_contact(100,101,ORIGIN,0).get("accepted",false))


func _test_product_effects_equivalence() -> void:
	var config := SimConfig.new(120)
	for wire: int in [0,301,309,310,311,316,317]:
		var current := _court()
		var before := _court(true)
		var actors := _actors()
		var reference_actors := _actors()
		if wire > 0:
			check(_form(current,wire) and _form(before,wire), "nonempty guard control uses funded real recipe%d" % wire)
			if current.products.is_empty() or before.products.is_empty(): continue
		var paths := {}
		for actor: PlayerState in actors:
			paths[actor.entity_id] = {"point":Vector2i(actor.position_x-80_000,actor.position_y),"height":0}
		var original_paths := paths.duplicate(true)
		var ticks: Array[int] = [0,1,120]
		if wire > 0:
			var product: Dictionary = current.products.values()[0]
			ticks = [int(product.active_tick)-1,int(product.active_tick),int(product.active_tick)+1,int(product.decay_tick),int(product.expiry_tick)]
		var collisions := [CollisionWorld.new(),CollisionWorld.new()]
		var events: Array[Dictionary] = []
		var reference_events: Array[Dictionary] = []
		for tick: int in ticks:
			current.apply_product_effects(actors,tick,config,collisions[0],events,paths)
			before.apply_product_effects(reference_actors,tick,config,collisions[1],reference_events,paths)
			equal(current.state_hash(),before.state_hash(),"product guard preserves complete authority recipe%d tick%d" % [wire,tick])
			equal(events,reference_events,"product guard preserves exact event order and damage receipts")
			equal(paths,original_paths,"product effects retain caller paths unchanged")
			for index: int in actors.size():
				equal(_actor_values(actors[index]),_actor_values(reference_actors[index]),"all actor fields match prior product algorithm")
		if wire == 0:
			equal(events,[],"empty product guard creates no combat events")
			for index: int in actors.size():
				equal(actors[index].health,100_000,"empty authority remains harmless")


func _test_flight_retirement_equivalence() -> void:
	for mode: String in ["empty","pending","flight"]:
		var current := _court()
		var before := _court(true)
		var actors := _actors()
		var shots: Array[ProjectileState] = []
		if mode != "empty":
			for court: HexChemistryWorld in [current,before]:
				check(court.reserve_cast(1,145), "sync control reserves live Fire Bolt")
				court.commit_payment(1)
				if mode == "flight": court.bind_release(1,100,ORIGIN)
			if mode == "pending": actors[0].pending_cast_wire_id = 145
			else: shots.append(ProjectileState.new(100,1,1,145,2,ORIGIN,Vector2i.ZERO,10_000,10_000,120))
		current.sync_flights(actors,shots)
		before.sync_flights(actors,shots)
		equal(current.state_hash(),before.state_hash(),"live/pending/empty sync matches previous algorithm: "+mode)
		if mode != "empty": equal(current.casts.size(),1,"matching live or pending cast is retained")
		actors[0].pending_cast_wire_id = 0
		shots.clear()
		current.sync_flights(actors,shots)
		before.sync_flights(actors,shots)
		equal(current.state_hash(),before.state_hash(),"missing pending/flight expires with identical ledger and metrics")
		equal(current.casts.size(),0,"abandoned paid cast actually retires")
		check(current.conservation_valid(),"empty and retired casts retain paid-matter conservation")
		current.sync_flights(actors,shots)
		before.sync_flights(actors,shots)
		equal(current.state_hash(),before.state_hash(),"subsequent empty sync remains exactly inert")


func _test_complete_fixed_step_equivalence() -> void:
	var current := SimWorld.new(120,77,CollisionWorld.new())
	var before := SimWorld.new(120,77,BeforeCollision.new())
	_populate(current.collision,49)
	_populate(before.collision,49)
	current.hex_court = _court()
	before.hex_court = _court(true)
	for world: SimWorld in [current,before]:
		world.players = _actors()
		for actor: PlayerState in world.players:
			actor.health_recovery_delay_ticks = 7
			actor.flux_recovery_delay_ticks = 9
			actor.stamina_recovery_delay_ticks = 11
			actor.jump_buffer_ticks = 3
			actor.landing_ticks = 5
			actor.landing_intensity = 250
			actor.set_spell_cooldown(145,13)
			if actor.actor_kind == PlayerState.ActorKind.TRAINING_TARGET:
				actor.movement_speed_ratio = 0
				actor.stamina_recovery_per_second = 0
				actor.flux_recovery_per_second = 0
			actor.place_proven_spell(0,145)
		var traveller := world.player()
		traveller.position_x = 700_000
		traveller.position_y = 650_000
		traveller.flux = traveller.flux_maximum
		# A displaced target must continue through real movement and collision;
		# the optimization never sleeps actor state or omits any fixed tick.
		world.players[1].velocity_x = 90_000
		world.players[2].air_height = 40_000
		world.players[2].air_vertical_velocity = -120_000
	for tick: int in 160:
		var movement := 1000 if tick >= 25 and tick < 45 else 0
		var pressed := SimCommand.PRESSED_SPELL_1 if tick == 60 else 0
		var command := SimCommand.new(tick,1,movement,0,0,pressed,0,-1000,700_000,500_000)
		check(current.step([command]),"optimized fixed tick remains admissible")
		check(before.step([command.copy()]),"pre-optimization fixed tick remains admissible")
		equal(current.state_hash(),before.state_hash(),"complete fixed-step state, timers, resources, statuses and paid casts remain equal at%d" % tick)
		for index: int in current.players.size():
			equal(_actor_values(current.players[index]),_actor_values(before.players[index]),"all actor script fields remain equal across fixed tick%d" % tick)

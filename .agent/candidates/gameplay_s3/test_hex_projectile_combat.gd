extends FluxTestSuite

# Isolated resolver fixture: paid-ledger behavior is tested independently in
# HexCourt integration; this fixture controls exact collision order and time.
class LedgerCourt:
	extends RefCounted
	var ledgers := {}
	var products: Array[Dictionary] = []
	func ledger_for_source(source: int) -> Dictionary:
		return ledgers.get(source, {})
	func resolve_contact(a: int, b: int, point: Vector2i, _tick: int) -> Dictionary:
		var result := StrengthBudget.consume_pair(ledger_for_source(a), ledger_for_source(b))
		if bool(result.accepted):
			products.append({"point": point, "quantity": int(result.first.consumed_quantity) + int(result.second.consumed_quantity)})
			result.recipe_wire_id = 310
			result.reaction_id = products.size()
		return result


func run() -> int:
	_test_successive_order_and_no_terminal_duplication()
	_test_actor_before_clash_and_revalidation()
	_test_wall_tie_and_range_endpoint()
	_test_spray_zero_and_survivor()
	_test_released_dead_owner_and_splash_defeat()
	_test_height_lifetime_and_projection_bounds()
	return finish("hex-projectile-combat")


func _world() -> SimWorld:
	var world := SimWorld.new(120, 1, CollisionWorld.new(2_000_000, 2_000_000))
	world.players.clear()
	world.hex_court = LedgerCourt.new()
	return world


func _shot(world: SimWorld, id: int, strength: int, x: int, speed: int = 0, owner: int = 1, wire: int = 140) -> ProjectileState:
	var shot := ProjectileState.new(id, owner, owner, wire, 3, Vector2i(x, 400_000), Vector2i(speed, 0), 1000, 6000, 120)
	shot.source_cast_id = id
	shot.reaction_strength = strength
	(world.hex_court as LedgerCourt).ledgers[id] = StrengthBudget.make(id, strength, 600)
	world.projectiles.append(shot)
	return shot


func _events(world: SimWorld, kind: String, source: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if event.get("type", "") == kind and (source < 0 or int(event.get("source_cast_id", event.get("projectile_id", -1))) == source): result.append(event)
	return result


func _target(world: SimWorld, x: int, id: int = 20) -> PlayerState:
	var actor := PlayerState.new(id)
	actor.team_id = 2
	actor.position_x = x
	actor.position_y = 400_000
	actor.radius = 18_000
	actor.health = 100_000
	actor.spawn_protection_ticks = 0
	world.players.append(actor)
	return actor


func _test_successive_order_and_no_terminal_duplication() -> void:
	var world := _world()
	var heavy := _shot(world, 1000, 15, 200_000, 12_000_000)
	_shot(world, 1002, 3, 280_000, 0, 2)
	_shot(world, 1003, 5, 250_000, 0, 2)
	HexProjectileCombat.advance(world)
	equal(world.projectiles.size(), 1, "only finite stronger survivor remains after two swept clashes")
	equal(heavy.remaining_strength, 7, "TOI orders strength15 to10 to7 despite reversed entity IDs")
	equal(heavy.initial_strength, 15, "initial provenance remains fifteen")
	var clashes := _events(world, "hex_clash")
	equal(clashes.size(), 2, "each exhausted partner creates exactly one clash result")
	equal(int(clashes[0].first_remaining), 10, "first event consumes nearby five")
	equal(int(clashes[1].first_remaining), 7, "second event consumes later three")
	equal(_events(world, "projectile_terminal").size(), 0, "exhausted collision inputs do not also emit terminal deposits")
	var ledger: Dictionary = world.hex_court.ledger_for_source(1000)
	equal(int(ledger.flight_quantity), 280, "survivor retains only its remaining paid material")
	equal(int(ledger.consumed_quantity), 320, "successive products consume200 then120 from Heavy")
	check(StrengthBudget.validate(ledger), "ordered resolver leaves conserved ledger")
	world.combat_events.clear()
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 0, "destroyed projectiles cannot react on the next tick")


func _test_actor_before_clash_and_revalidation() -> void:
	var world := _world()
	_shot(world, 1000, 5, 200_000, 12_000_000)
	_shot(world, 1001, 5, 250_000, 0, 2)
	var target := _target(world, 240_000)
	HexProjectileCombat.advance(world)
	equal(target.health, 94000, "earlier actor contact receives one direct hit")
	equal((world.hex_court as LedgerCourt).products.size(), 0, "later queued clash is invalid after actor termination")
	equal(_events(world, "projectile_terminal", 1000).size(), 1, "actor contact has exactly one terminal")
	world = _world()
	_shot(world, 1000, 15, 200_000, 12_000_000)
	_shot(world, 1001, 5, 240_000, 0, 2)
	target = _target(world, 280_000)
	HexProjectileCombat.advance(world)
	equal(target.health, 96000, "later actor hit uses remaining10/15 damage after prior clash")
	equal(_events(world, "projectile_terminal", 1001).size(), 0, "exhausted partner cannot deposit while survivor hits")
	# The first shot kills the closest actor; the second must skip that now-dead
	# queued contact and continue to the next enemy instead of disappearing.
	world = _world()
	_shot(world, 1000, 5, 205_000, 12_000_000)
	_shot(world, 1001, 5, 200_000, 12_000_000)
	target = _target(world, 240_000)
	target.health = 6000
	var farther := _target(world, 290_000, 21)
	HexProjectileCombat.advance(world)
	equal(target.health, 0, "earliest projectile kills the first enemy")
	equal(farther.health, 94000, "later projectile revalidates dead target then reaches farther enemy")


func _test_wall_tie_and_range_endpoint() -> void:
	var world := _world()
	_shot(world, 1000, 5, 200_000, 12_000_000)
	_shot(world, 1001, 5, 242_000, 0, 2)
	world.collision.add_obstacle(CollisionWorld.Obstacle.new(7, 241_000, 390_000, 260_000, 410_000, false))
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 0, "wall wins an exact pair contact tie")
	var terminal := _events(world, "projectile_terminal", 1000)
	equal(terminal.size(), 1, "wall terminated source deposits once")
	if not terminal.is_empty(): equal(terminal[0].position, Vector2i(241_000, 400_000), "wall deposit uses physical wall surface")
	world = _world()
	var shot := _shot(world, 1000, 5, 200_000, 12_000_000)
	shot.remaining_distance = 40_000
	_shot(world, 1001, 5, 242_000, 0, 2)
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 1, "clash at exact range endpoint precedes ordinary expiry")
	equal(_events(world, "projectile_terminal").size(), 0, "range tie does not duplicate exhausted payload")
	world = _world()
	shot = _shot(world, 1000, 5, 200_000, 12_000_000)
	shot.remaining_distance = 10_000
	_shot(world, 1001, 5, 250_000, 0, 2)
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 0, "pair beyond earlier range endpoint is ineligible")
	terminal = _events(world, "projectile_terminal", 1000)
	if not terminal.is_empty(): equal(terminal[0].position, Vector2i(210_000, 400_000), "range terminal uses exact consumed travel")


func _test_spray_zero_and_survivor() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production catalogue loads for pulse fixture")
	var wire := int(catalog.ability(catalog.spell_id_at("fire", "spray")).wire_id)
	for strength: int in [3, 15]:
		var world := _world()
		var owner := PlayerState.new(2)
		owner.team_id = 2
		world.players.append(owner)
		var shot := _shot(world, 1000, strength, 250_000, 0)
		(world.hex_court as LedgerCourt).ledgers[1001] = StrengthBudget.make(1001, 3, 600)
		world.combat_events.append({"type": "spray_requested", "source_cast_id": 1001, "owner_id": 2,
			"source_wire_id": wire, "origin_x": 200_000, "origin_y": 400_000, "aim_x": 1000, "aim_y": 0, "target_x": 300_000, "target_y": 400_000})
		HexProjectileCombat.resolve_sprays(world)
		equal(_events(world, "hex_clash").size(), 1, "instant pulse clash emits one result for equal or unequal strength")
		equal(_events(world, "projectile_terminal", 1001).size(), 0, "exhausted pulse never deposits or damages after interception")
		equal(_events(world, "spray_fired").size(), 0, "exhausted pulse cannot resolve actor damage")
		if strength == 15:
			equal(shot.remaining_strength, 12, "stronger flight loses exact pulse strength")
		else:
			equal(world.projectiles.size(), 0, "equal pulse exhausts both participants")


func _test_released_dead_owner_and_splash_defeat() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "catalogue loads for paid-release regression")
	var world := _world()
	var owner := PlayerState.new(2)
	owner.health = 0 # Captured release already paid before this phase's damage.
	owner.team_id = 2
	world.players.append(owner)
	var target := _target(world, 250_000)
	target.team_id = 3
	var wire := int(catalog.ability(catalog.spell_id_at("fire", "spray")).wire_id)
	(world.hex_court as LedgerCourt).ledgers[1001] = StrengthBudget.make(1001, 3, 600)
	world.combat_events.append({"type": "spray_requested", "source_cast_id": 1001, "owner_id": 2,
		"source_wire_id": wire, "origin_x": 200_000, "origin_y": 400_000, "aim_x": 1000, "aim_y": 0, "target_x": 300_000, "target_y": 400_000})
	HexProjectileCombat.resolve_sprays(world)
	check(target.health < 100000, "already released paid pulse is not suppressed by owner death in its phase")
	equal(_events(world, "projectile_terminal", 1001).size(), 1, "released paid pulse retains exactly one terminal")
	world = _world()
	wire = int(catalog.ability(catalog.spell_id_at("water", "heavy")).wire_id)
	var heavy := _shot(world, 1000, 15, 200_000, 0, 1, wire)
	var direct := _target(world, 200_000)
	var splash := _target(world, 240_000, 21)
	splash.health = 1000
	check(HexProjectileCombat.sync_strength(world), "Heavy obtains its paid projection")
	HexProjectileCombat._terminal(world, heavy, Vector2i(200_000, 400_000), "actor", direct.entity_id)
	equal(direct.health, 100000, "direct victim remains excluded from secondary blast")
	equal(splash.health, 0, "secondary blast can defeat a nearby champion")
	var defeats := _events(world, "champion_defeated")
	equal(defeats.size(), 1, "secondary blast emits the authoritative defeat event")
	if not defeats.is_empty(): equal(int(defeats[0].target_id), splash.entity_id, "defeat event identifies splash victim")


func _test_height_lifetime_and_projection_bounds() -> void:
	for height: int in [MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT - 1, MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT]:
		var world := _world()
		_shot(world, 1000, 5, 200_000, 12_000_000)
		var target := _target(world, 240_000)
		target.air_height = height
		HexProjectileCombat.advance(world)
		equal(target.health < 100000, height < MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT, "ground flight uses exact authoritative height boundary")
	var world := _world()
	var shot := _shot(world, 1000, 5, 200_000, 12_000_000)
	shot.lifetime_ticks = 1
	_shot(world, 1001, 5, 302_000, 0, 2)
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 1, "exact lifetime endpoint clash precedes terminal expiry")
	equal(_events(world, "projectile_terminal").size(), 0, "lifetime tie cannot duplicate the exhausted ingredients")
	world = _world()
	shot = _shot(world, 1000, 5, 200_000)
	var canonical := shot.canonical_values()
	shot.initial_strength = 5
	shot.remaining_strength = 2
	equal(shot.canonical_values(), canonical, "derived hex projections do not alter legacy canonical state")
	var sibling := _shot(world, 1001, 5, 250_000)
	sibling.source_cast_id = 1000
	check(not HexProjectileCombat.sync_strength(world), "court refuses unpartitioned multiflight source")
	check(world.last_error.contains("one live flight"), "unsupported multiflight boundary is explicit")

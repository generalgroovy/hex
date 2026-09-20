extends SceneTree
@warning_ignore_start("integer_division")

# Query/batch-only seeded edge fixtures, not free casts or network-capacity proof.
# Refreshed observation batch preserves the baseline dictionary-entry oracle.
const LegacyBatch = preload("res://tests/scenarios/runtime_drill_combat.gd")
const LegacyCounters = preload("res://tests/scenarios/runtime_drill_chemistry.gd")
const SEED: int = 609_123
var assertions := 0
var failures := 0
var observed_wires := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for index: int in range(144):
		for reversed: bool in [false,true]:
			var actual := _fixture(index,reversed)
			var expected := _fixture(index,reversed)
			for step: int in range(3):
				var slots := {1:2,2:2,3:2,4:2,5:2,6:2,7:2,8:2}
				var old_slots := slots.duplicate()
				actual.combat_events = []
				expected.combat_events = []
				LegacyCounters.reset()
				LegacyBatch.reset()
				actual.projectiles = CombatSystem.advance_projectiles(actual.projectiles,actual.players,actual.config,actual.collision,actual.combat_events,actual.reactions,actual.tick,8,slots)
				expected.projectiles = LegacyBatch.measured_advance_projectiles(expected.projectiles,expected.players,expected.config,expected.collision,expected.combat_events,expected.reactions,expected.tick,8,old_slots)
				_check(slots == old_slots,"split slot bookkeeping agrees")
				_check(_events(actual.combat_events) == _events(expected.combat_events),"ordered pre-consumption events and split children agree")
				actual._consume_projectile_terminals()
				expected._consume_projectile_terminals()
				_check(actual.state_hash() == expected.state_hash(),"every actor/projectile/reaction/deposit/id is equal")
				_check(actual.combat_events == expected.combat_events,"ordered public events agree")
				_check(actual.last_error == expected.last_error,"terminal admission outcome agrees")
				if index == 0 and step == 0:
					_check(actual.reactions[0].health == 0 and actual.reactions[0].decay_tick == 10,"first shot really destroys cover inside the batch")
					_check(actual.projectiles.size() == 7,"later seven shots really pass newly decayed cover")
				if index == 6 and step == 2:
					_check(actual.projectiles.size() == 8 and actual.projectiles[0].velocity_x < 0,"prism really reflects the seeded batch")
				if index == 28 and step == 0:
					_check(actual.projectiles.size() == 12,"Light lens really consumes both owner split reservations")
				actual.tick += 1
				expected.tick += 1
	_check(observed_wires.size() == 36,"all36 recipe identities exercised")
	var suite := preload("res://tests/unit/test_combat.gd").new()
	failures += suite.run()
	assertions += suite.assertions
	print("%s: projectile-reaction-batch-equivalence; %d assertions; %d failures; seed=%d; fixtures=288; batch_steps=864; recipe_wires=%d" % ["PASS" if failures == 0 else "FAIL",assertions,failures,SEED,observed_wires.size()])
	quit(0 if failures == 0 else 1)

func _fixture(index: int,reversed: bool) -> SimWorld:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+index
	var world := SimWorld.new(120,SEED,CollisionWorld.new(4000000,4000000))
	world.tick = 10
	world.players.clear()
	world.next_projectile_id = 5000
	for actor: int in range(8):
		var player := PlayerState.new(actor+1)
		player.position_x = 1200000+actor*100000
		player.position_y = 1200000
		player.team_id = actor+1
		world.players.append(player)
	var amount := 1 if index < 36 else 16
	for item: int in range(amount):
		var wire := 301+(index+item*7)%36
		observed_wires[wire] = true
		var reaction := ElementReactionState.new()
		reaction.entity_id = 1000+item
		reaction.recipe_wire_id = wire
		reaction.owner_id = 8
		reaction.team_id = 8
		reaction.position_x = 500000+(item%4)*10000
		reaction.position_y = 500000+(item/4)*10000
		reaction.origin_x = reaction.position_x
		reaction.origin_y = reaction.position_y
		reaction.source_a = item*2+1
		reaction.source_b = item*2+2
		reaction.created_tick = 0
		reaction.active_tick = 10 if index < 36 else [9,10,11][(index+item)%3]
		reaction.decay_tick = 100 if index < 36 else [10,11,100][(index+item)%3]
		reaction.expiry_tick = 130
		reaction.radius = int(ElementChemistrySystem.recipe(wire).get("radius",24000))
		reaction.length = int(ElementChemistrySystem.recipe(wire).get("length",64000))
		reaction.endpoint_x = reaction.position_x+reaction.length
		reaction.endpoint_y = reaction.position_y
		reaction.health = [1,0,20000][index%3]
		reaction.capacity = [0,5000,36000][index%3]
		world.reactions.append(reaction)
	if index >= 36 and index%4 == 0:
		# Aliases must remain aliases and duplicates keep their original order.
		world.reactions.append(world.reactions[0])
	for item: int in range(8):
		var position := Vector2i(480000,500000) if index < 36 else Vector2i(480000+rng.randi_range(-10000,60000),500000+rng.randi_range(-10000,60000))
		var projectile := ProjectileState.new(item+100,1+item%2,1+item%2,193 if index%4 == 0 else 194,6 if index%36 == 5 else 7,position,Vector2i(600000,0),10000,10000,120)
		projectile.source_cast_id = item+1
		projectile.chemistry_interaction_mask = 0 if index < 36 or item%2 == 0 else (1 << ((index+item)%36))
		world.projectiles.append(projectile)
	if index%7 == 0:
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(1,510000,450000,520000,600000))
	if reversed:
		world.projectiles.reverse()
		world.reactions.reverse()
		world.players.reverse()
	return world

func _events(events: Array[Dictionary]) -> Array:
	var normalized: Array = []
	for event: Dictionary in events:
		var value := event.duplicate()
		if value.get("projectile") is ProjectileState:
			value.projectile = (value.projectile as ProjectileState).canonical_values()
		normalized.append(value)
	return normalized

func _check(condition: bool,label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		if failures < 10: push_error(label)

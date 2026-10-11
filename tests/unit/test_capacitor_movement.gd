extends FluxTestSuite
@warning_ignore_start("integer_division")
const Fixture = preload("res://tests/support/live_field_fixture.gd")
const ORIGIN := Fixture.ORIGIN
var config := SimConfig.new(120)

# Keep historical suite identity while testing the derived electrical pair.
# Charge331's125percent ground speed is retired, not silently moved to Arcstorm.
func run() -> int:
	_test_live_policy_and_retired_inputs()
	_test_no_hidden_ground_bonus()
	_test_burst_boundaries_and_protection()
	return finish("capacitor-movement")

func _world(direction: Vector2i = Vector2i(1000, 0)) -> SimWorld:
	var world := Fixture.make(311, direction)
	check(world != null, "actual paid Fire and Air Bolts form Arcstorm")
	return world

func _test_live_policy_and_retired_inputs() -> void:
	check(HexRecipePolicy.definition(331).is_empty(), "retired Charge mirror cannot produce live Capacitor metadata")
	equal(HexRecipePolicy.recipe_wire(6, 6), 0, "retired Charge input cannot reserve a live reaction identity")
	var policy := HexRecipePolicy.definition(311)
	equal(policy.elements, [2, 4], "electrical line derives from Fire and Air")
	equal(policy.name, "Arcstorm", "derived line uses current gameplay identity")
	equal([int(policy.formation_ticks), int(policy.active_ticks), int(policy.decay_ticks)], [54, 15, 42], "450ms warning,125ms burst and350ms harmless tail are independently bounded")
	equal([int(policy.radius), int(policy.length)], [9375, 168750], "compact electrical line retains independent physical dimensions")
	equal(int(policy.pulse_damage), 9000, "authored electrical burst has a9k full-strength quote")
	equal(int(policy.health), 0, "electrical line does not become invisible physical cover")
	for wire: int in [101, 167, 187, 188]:
		var world := _world()
		var before: String = world.hex_court.state_hash()
		check(not world.hex_court.reserve_cast(1, wire), "retired Charge spell cannot acquire a new paid source")
		equal(world.hex_court.state_hash(), before, "retired refusal preserves finite current state")

func _test_no_hidden_ground_bonus() -> void:
	var arena := CollisionWorld.new(2_000_000, 1_500_000)
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var world := _world(direction)
		for radius: int in [17_000, 18_000, 19_000]:
			for held: int in [0, SimCommand.HELD_SPRINT]:
				var actor := PlayerState.new(2)
				actor.position_x = ORIGIN.x
				actor.position_y = ORIGIN.y
				actor.radius = radius
				var control := ClientPrediction.restore_state(ClientPrediction.capture_packet(actor, 0, -1).values)
				for tick: int in range(53, 71):
					var point := Vector2i(actor.position_x, actor.position_y)
					var modifiers := HexProductEffects.pre_movement(world.hex_court, actor, tick, point, config)
					equal(modifiers, {"ground_target_ratio":1000,"acceleration_ratio":1000,"braking_ratio":1000}, "Arcstorm never grants the removed125percent lane boost")
					var command := SimCommand.new(tick, 2, direction.x, direction.y, held)
					MovementSystem.step(actor, command, config, arena, int(modifiers.ground_target_ratio), int(modifiers.acceleration_ratio), int(modifiers.braking_ratio))
					MovementSystem.step(control, command, config, arena)
					for field: StringName in ClientPrediction.STATE_FIELDS:
						equal(actor.get(field), control.get(field), "line cannot alter movement, payment or protection field " + String(field))

func _test_burst_boundaries_and_protection() -> void:
	for scenario: String in ["enemy", "ally", "spawn", "air_dodge", "dead", "outside"]:
		for tick: int in [53, 54, 68, 69]:
			var world := _world()
			var actor := world.player(2)
			if scenario == "ally": actor.team_id = 1
			elif scenario == "spawn": actor.spawn_protection_ticks = 1
			elif scenario == "air_dodge": actor.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
			elif scenario == "dead": actor.health = 0
			elif scenario == "outside": actor.position_y += 200_000
			var before := actor.canonical_values()
			var health := actor.health
			var product: Dictionary = world.hex_court.products.values()[0]
			check(Fixture.set_tick(world, tick), "exact electrical phase prepares")
			var events: Array[Dictionary] = []
			world.hex_court.apply_product_effects(world.players, tick, config, world.collision, events)
			var hit := scenario == "enemy" and tick >= 54 and tick < 69
			equal(actor.health, health - 4500 if hit else health, "only an eligible hostile in the active interval receives a funded electrical burst")
			equal(Vector2i(actor.position_x, actor.position_y), Vector2i(before[4], before[5]), "Arcstorm never inherits a removed Capacitor impulse")
			equal(int(product.damage_budget_remaining), 35500 if hit else 40000, "actual realized damage alone spends the finite two-Bolt pool")
			var after := actor.canonical_values()
			world.hex_court.apply_product_effects(world.players, tick, config, world.collision, events)
			equal(actor.canonical_values(), after, "same-tick electrical query cannot duplicate the hit or a movement impulse")

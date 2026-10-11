extends FluxTestSuite
@warning_ignore_start("integer_division")
const Fixture = preload("res://tests/support/live_field_fixture.gd")
const ORIGIN := Fixture.ORIGIN
var config := SimConfig.new(120)

# Suite identity is stable; live acceptance now uses paid Water+Water316 and
# complete Hex prediction. The exact old327/legacy-row suite remains in baseline.
func run() -> int:
	_test_geometry_phases_and_validation()
	_test_ground_targets_and_actions()
	_test_projectiles_and_cover()
	_test_prediction_and_replay()
	_test_maximum_network_delivery()
	return finish("frostway-movement")

func _world(direction: Vector2i = Vector2i(1000, 0), copies: int = 1) -> SimWorld:
	var world := Fixture.make(316, direction, copies)
	check(world != null, "two actual paid Water Bolts form each live Frostway")
	return world

func _state(radius: int = 18_000, direction: Vector2i = Vector2i(1000, 0)) -> PlayerState:
	var state := PlayerState.new(2)
	state.team_id = 2
	var center := ORIGIN + ElementChemistrySystem.scaled(direction, 75_000)
	state.position_x = center.x
	state.position_y = center.y
	state.radius = radius
	return state

func _copy(state: PlayerState) -> PlayerState:
	return ClientPrediction.restore_state(ClientPrediction.capture_packet(state, 0, -1).values)

func _test_geometry_phases_and_validation() -> void:
	var definition := HexRecipePolicy.definition(316)
	equal(definition.elements, [3, 3], "Water self-combination owns derived Ice")
	equal(definition.name, "Frostway", "live field has its current display identity")
	equal(definition.radius, 22_500, "compact capsule radius is independently22.5px")
	equal(definition.length, 150_000, "compact capsule centerline is independently150px")
	equal(definition.health, 0, "Frostway never becomes physical cover")
	check(HexRecipePolicy.definition(327).is_empty(), "retired Ice self-wire has no live policy")
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var world := _world(direction)
		var product: Dictionary = world.hex_court.products.values()[0]
		equal([int(product.active_tick), int(product.decay_tick), int(product.expiry_tick)], [78, 498, 570], "warning, active end and expiry have exact independent ticks")
		equal(int(product.funded_strength), 10, "two Bolts fund exactly5+5 strength")
		equal(int(product.damage_budget_remaining), 40_000, "the paid damage pool is finite before entry")
		var shape: Dictionary = product.footprint.duplicate(true)
		var actor := _state(18_000, direction)
		var inside := Vector2i(actor.position_x, actor.position_y)
		check(world.hex_court.contains_stored(product, inside), "mid-lane foot is inside actual selected coverage")
		for tick: int in [0, 77, 78, 497, 498, 570]:
			var active := tick >= 78 and tick < 498
			equal(Fixture.ratio(world, actor, tick, inside), 750 if active else 1000, "ground target obeys exact live phase boundaries")
			equal(Fixture.ratio(world, actor, tick, ORIGIN + ElementChemistrySystem.scaled(direction, 250_000)), 1000, "outside selected lane has no hidden slow")
		check(Fixture.set_tick(world, 78), "active Frostway prepares trusted collision")
		check(world.collision.can_occupy(inside, actor.radius), "Frostway is traversable in every direction")
		check(SprayInterception.clear_ray(ORIGIN - direction * 100, ORIGIN + direction * 250, world.collision, [], 78), "live Ice cannot create invisible shot or splash cover")
		equal(product.footprint, shape, "queries never retile or rotate the stored field")
		var snapshot := HexWorldSnapshot.capture(world)
		check(not snapshot.is_empty(), "paid source funding and compact geometry form a valid complete snapshot")
		if not snapshot.is_empty(): equal([int(snapshot.header[1]), int(snapshot.header[7])], [78, 77], "snapshot publishes next world tick and last completed chemistry tick independently")
		var restored := HexWorldSnapshot.prepare(snapshot, world)
		check(restored != null, "complete field snapshot restores against matching topology")
		if restored != null: equal(restored.state_hash(), world.state_hash(), "every field and source value roundtrips exactly")

func _test_ground_targets_and_actions() -> void:
	var world := CollisionWorld.new(2_000_000, 1_500_000)
	for radius: int in [17_000, 18_000, 19_000]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var lane_world := _world(direction)
			for held: int in [0, SimCommand.HELD_SPRINT]:
				var slow := _state(radius, direction)
				var normal := _copy(slow)
				for tick: int in range(78, 138):
					# A fixed central probe allows both targets to settle without
					# measuring a different exit time as a supposed speed change.
					var center := ORIGIN + ElementChemistrySystem.scaled(direction, 100_000)
					slow.position_x = center.x
					slow.position_y = center.y
					var command := SimCommand.new(tick, 2, direction.x, direction.y, held)
					MovementSystem.step(slow, command, config, world, Fixture.ratio(lane_world, slow, tick, center))
					MovementSystem.step(normal, command, config, world)
				var expected := Vector2i(normal.velocity_x * 750 / 1000, normal.velocity_y * 750 / 1000)
				check(absi(slow.velocity_x - expected.x) <= 2 and absi(slow.velocity_y - expected.y) <= 2, "all sizes/directions walk and sprint settle at75percent target")
				equal(slow.control_state, PlayerState.ControlState.FREE, "lane never writes a control status")
				equal(slow.slow_ratio, 1000, "lane never contaminates authored hostile slow ratio")
				equal(slow.stamina, normal.stamina, "Frostway does not alter sprint cost/recovery budget")
				for tick: int in range(138, 163):
					var command := SimCommand.new(tick, 2, direction.x, direction.y, held)
					MovementSystem.step(slow, command, config, world, 1000)
					MovementSystem.step(normal, command, config, world)
				equal(Vector2i(slow.velocity_x, slow.velocity_y), Vector2i(normal.velocity_x, normal.velocity_y), "exit restores ordinary target without sticky or exponential slow")
			for action: String in ["jump", "slide", "roll", "flight", "double_jump", "air_dodge", "wave_dash", "launched", "grappled", "charging", "stunned", "rooted"]:
				var state := _state(radius, direction)
				state.velocity_x = direction.x * 350
				state.velocity_y = direction.y * 350
				var pressed := 0
				var held := 0
				match action:
					"jump":
						# Prepare identical grounded anticipation, then compare the
						# release/launch tick rather than ordinary jumpsquat travel.
						MovementSystem.step(state, SimCommand.new(77, 2, direction.x, direction.y, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP), config, world)
						check(state.jumpsquat_active, "jump bypass fixture begins from held anticipation")
					"slide":
						pressed = SimCommand.PRESSED_SLIDE
						held = SimCommand.HELD_SLIDE
					"roll": pressed = SimCommand.PRESSED_EVADE
					"flight", "double_jump", "air_dodge":
						state.air_height = 18_000
						state.flight_capable = action == "flight"
						state.hop_ticks = 30
						state.hop_stage = 1
						state.air_velocity_x = state.velocity_x
						state.air_velocity_y = state.velocity_y
						pressed = SimCommand.PRESSED_EVADE if action == "air_dodge" else SimCommand.PRESSED_JUMP
						held = SimCommand.HELD_JUMP if action == "flight" else 0
					"wave_dash":
						state.wave_dash_ticks = 20
						state.wave_dash_x = direction.x
						state.wave_dash_y = direction.y
						state.movement_action_speed = 350_000
					_:
						var control := {"launched": PlayerState.ControlState.LAUNCHED, "grappled": PlayerState.ControlState.GRAPPLED, "charging": PlayerState.ControlState.CHARGING, "stunned": PlayerState.ControlState.STUNNED, "rooted": PlayerState.ControlState.ROOTED}
						MovementSystem.apply_control_state(state, int(control[action]), 500, direction, 350_000, config)
				var normal := _copy(state)
				var command := SimCommand.new(78, 2, direction.x, direction.y, held, pressed)
				MovementSystem.step(state, command, config, world, 750)
				MovementSystem.step(normal, command, config, world, 1000)
				if action == "jump":
					check(state.is_airborne() and not state.jumpsquat_active, "lane comparison tests actual released jump")
				elif action == "flight":
					check(state.air_floating, "lane comparison admits capability-gated held flight")
				elif action == "double_jump":
					check(state.double_jump_used and not state.air_floating, "lane comparison admits non-flyer double jump")
				for field: StringName in ClientPrediction.STATE_FIELDS:
					equal(state.get(field), normal.get(field), "lane bypasses%s size%d dir%s field%s including resources/air budgets" % [action, radius, direction, field])
	var hostile := _state()
	MovementSystem.apply_control_state(hostile, PlayerState.ControlState.SLOWED, 500, Vector2i.ZERO, 0, config, 600)
	MovementSystem.step(hostile, SimCommand.new(78, 2, 1000, 0), config, world, 750)
	equal(hostile.control_state, PlayerState.ControlState.SLOWED, "independent hostile slow state preserved")
	equal(hostile.slow_ratio, 600, "independent hostile slow strength preserved")
	equal(world.obstacle_view().size(), 0, "all lane movement keeps immutable map geometry untouched")

func _test_projectiles_and_cover() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "physical field probes use24 live spells")
	for element: String in ElementRules.IDS:
		for family: String in ["bolt", "rapid", "heavy"]:
			var world := _world(Vector2i(1000, 0), 2)
			world.player(2).position_y += 300_000
			var court: HexChemistryWorld = world.hex_court
			var wire := int(catalog.ability(catalog.spell_id_at(element, family)).wire_id)
			var definition := CombatTuning.cast_definition(wire)
			check(court.reserve_cast(1, wire), "physical probe reserves an actual paid source")
			court.commit_payment(1)
			court.bind_release(1, 2000, ORIGIN + Vector2i(20_000, 0), Vector2i(1000, 0), 1)
			var shot := ProjectileState.new(2000, 1, 1, wire, int(definition.element_wire_id), ORIGIN + Vector2i(20_000, 0), Vector2i(120_000, 0), int(definition.radius), int(definition.damage), 200)
			shot.source_cast_id = 2000
			shot.reaction_strength = int(definition.reaction_strength)
			shot.remaining_distance = 180_000
			world.projectiles.append(shot)
			world.next_projectile_id = 2001
			for tick: int in range(78, 90):
				check(Fixture.set_tick(world, tick), "projectile probe prepares current field phase")
				var before_x := shot.position_x
				var before_range := shot.remaining_distance
				HexProjectileCombat.advance(world)
				equal(shot.position_x - before_x, 650, "overlapping real Frostways apply one65percent displacement")
				equal(shot.remaining_distance, before_range - 650, "range pays actual movement only")
				equal(shot.velocity_x, 120_000, "base velocity is never rewritten or compounded")
				equal(shot.damage, int(definition.damage), "slowing never buffs the damage payload")
				equal(shot.lifetime_ticks, 200 - (tick - 77), "slow flight retains its independent finite lifetime")
				check(court.conservation_valid(), "field query cannot mint source stock")
			shot.position_x = ORIGIN.x + 250_000
			var before_x := shot.position_x
			HexProjectileCombat.advance(world)
			equal(shot.position_x - before_x, 1000, "first sample outside restores normal travel")
			shot.position_x = ORIGIN.x + 20_000
			check(Fixture.set_tick(world, 498), "exact harmless decay prepares")
			before_x = shot.position_x
			HexProjectileCombat.advance(world)
			equal(shot.position_x - before_x, 1000, "decay removes the slow exactly")

func _test_prediction_and_replay() -> void:
	for radius: int in [17_000, 18_000, 19_000]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var world := _world(direction)
			var actor := _state(radius, direction)
			world.players[1] = actor
			check(Fixture.set_tick(world, 77), "prediction begins one tick before live field activation")
			var prediction := ClientPrediction.new()
			check(prediction.configure(config, world.collision, 2) and prediction.bind_hex_world(world), "prediction binds detached complete Hex geometry")
			check(prediction.reconcile(ClientPrediction.capture_packet(actor, 77, -1)), "actor and finite fields share one authoritative tick")
			for tick: int in range(77, 117):
				var command := SimCommand.new(tick, 2, direction.x, direction.y, SimCommand.HELD_SPRINT)
				check(world.step([command]) and prediction.queue_input(tick - 76, command), "actual world and prediction advance across activation and exit")
				for field: StringName in ClientPrediction.STATE_FIELDS:
					equal(prediction.predicted_state.get(field), actor.get(field), "all actor fields agree through field phase and movement: " + String(field))
	var world := _world()
	check(Fixture.set_tick(world, 497), "expiry replay starts on the final active tick")
	var restored := HexWorldSnapshot.prepare(HexWorldSnapshot.capture(world), world)
	check(restored != null, "complete live source snapshot prepares expiry replay")
	if restored == null: return
	for tick: int in range(497, 572):
		var command := SimCommand.new(tick, 2, 1000, 0)
		check(world.step([command]) and restored.step([command.copy()]), "source and restored world advance through harmless decay and expiry")
		equal(world.state_hash(), restored.state_hash(), "complete paid source and actor state replay exactly")
	check(world.hex_court.products.is_empty(), "Frostway retires at its original finite expiry")
	check(world.collision.obstacle_view().is_empty(), "expiry leaves no material worldbone")

func _test_maximum_network_delivery() -> void:
	# The paid reservation cap admits31 products plus one possible next source,
	# rather than manufacturing32 already-formed fields outside admission.
	var world := _world(Vector2i(1000, 0), 31)
	check(Fixture.set_tick(world, 78), "all real paid fields are active for packet coverage")
	equal(world.hex_court.products.size(), 31, "maximum independently paid field fixture contains31 products")
	var snapshot := HexWorldSnapshot.capture(world)
	check(not snapshot.is_empty(), "full field/source/funding authority fits the complete codec")
	if snapshot.is_empty(): return
	check(var_to_bytes(snapshot).size() <= HexWorldSnapshot.MAX_RAW_BYTES, "maximum paid field authority remains inside32KiB envelope")
	var restored := HexWorldSnapshot.prepare(snapshot, world)
	check(restored != null, "maximum live field authority restores")
	if restored != null: equal(restored.state_hash(), world.state_hash(), "all31 complete fields survive exact snapshot reconstruction")
	var hearth := SessionHearth.new()
	hearth.bind_host()
	check(hearth.connect_entity(2), "field guest enters the complete session metadata")
	var round_state := SessionRound.new()
	round_state.bind_hearth()
	var session := WorldSnapshotEnvelope.make_hex_session([[1,"Field Host","spawn"],[2,"Field Guest","spawn"]],[],hearth.capture(world.tick,SessionSnapshot.MAX_PLAYERS),round_state.capture(world),PackedInt32Array([0,0,0,0]))
	var envelope := WorldSnapshotEnvelope.wrap_hex(snapshot,session,0)
	check(WorldSnapshotEnvelope.validate(envelope), "complete finite fields have a validated multiplayer envelope")
	var packets := SessionTransport._snapshot_wire_packets(envelope)
	check(not packets.is_empty(), "all complete fields reach the actual datagram codec")
	for packet: Dictionary in packets: check(var_to_bytes(packet).size() <= SessionTransport.ENET_MTU_BYTES, "every finite-field datagram fits actual ENet MTU")

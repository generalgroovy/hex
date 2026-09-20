extends FluxTestSuite
@warning_ignore_start("integer_division")

const ORIGIN := Vector2i(600_000, 500_000)
var config := SimConfig.new()

func run() -> int:
	_test_geometry_phases_and_validation()
	_test_ground_targets_and_actions()
	_test_projectiles_and_rays()
	_test_prediction_and_replay()
	_test_maximum_network_delivery()
	return finish("frostway-movement")

func _reaction(direction: Vector2i = Vector2i(1000, 0), id: int = 4000) -> ElementReactionState:
	var result := ElementReactionState.new()
	result.entity_id = id
	result.recipe_wire_id = 327
	result.owner_id = 1
	result.team_id = 1
	result.position_x = ORIGIN.x
	result.position_y = ORIGIN.y
	result.origin_x = ORIGIN.x
	result.origin_y = ORIGIN.y
	result.direction_x = direction.x
	result.direction_y = direction.y
	result.created_tick = 0
	result.active_tick = 78
	result.decay_tick = 498
	result.expiry_tick = 570
	result.radius = 30_000
	result.length = 200_000
	result.source_a = 3000
	result.source_b = 3001
	var end := ORIGIN + ElementChemistrySystem.scaled(direction, result.length)
	result.endpoint_x = end.x
	result.endpoint_y = end.y
	return result

func _state(radius: int = 18_000, direction: Vector2i = Vector2i(1000, 0)) -> PlayerState:
	var state := PlayerState.new(2)
	var center := ORIGIN + ElementChemistrySystem.scaled(direction, 100_000)
	state.position_x = center.x
	state.position_y = center.y
	state.radius = radius
	return state

func _copy(state: PlayerState) -> PlayerState:
	return ClientPrediction.restore_state(ClientPrediction.capture_packet(state, 0, -1)["values"])

func _test_geometry_phases_and_validation() -> void:
	var definition := ElementChemistrySystem.recipe(327)
	equal(definition.id, "glacier", "stable internal reaction identity retained")
	equal(definition.name, "Frostway", "player-facing name reflects lane playstyle")
	equal(definition.shape, "corridor", "Ice mirror is a capsule lane, not obsolete cover")
	equal(definition.health, 0, "Frostway never intercepts attacks as hidden cover")
	for near_axis: Vector2i in [Vector2i(1000, 1), Vector2i(999, 45), Vector2i(-1, -1000)]:
		check(FrostwayFieldPolicy.validate(FrostwayFieldPolicy.capture([_reaction(near_axis)], 78), 78), "normalized near-axis fixed-point aim survives compact endpoint validation")
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var reaction := _reaction(direction)
		check(reaction.validate(), "Frostway state validates all eight orientations")
		var rows := FrostwayFieldPolicy.capture([reaction], 77)
		check(FrostwayFieldPolicy.validate(rows, 77), "captured exact-tick future lane validates")
		for along: int in [-40_000, -30_000, 0, 100_000, 200_000, 230_000, 240_000]:
			for across: int in [-31_000, -30_000, 0, 30_000, 31_000]:
				var point := ORIGIN + ElementChemistrySystem.scaled(direction, along) + ElementChemistrySystem.scaled(Vector2i(-direction.y, direction.x), across)
				equal(FrostwayFieldPolicy.contains(rows, point, 78), ElementChemistrySystem.contains(reaction, point, 78, config), "lane query exactly matches active chemistry capsule")
		var center := ORIGIN + ElementChemistrySystem.scaled(direction, 100_000)
		for tick: int in [0, 77, 78, 497, 498, 570]:
			var active := tick >= 78 and tick < 498
			equal(FrostwayFieldPolicy.movement_ratio(rows, center, tick), 750 if active else 1000, "walk ratio obeys exact formation/decay boundary")
			equal(FrostwayFieldPolicy.projectile_ratio(rows, center, tick), 650 if active else 1000, "projectile ratio obeys exact formation/decay boundary")
			equal(ReactionMovementWorld.capture_surfaces([reaction], tick).size(), 0, "lane never becomes body-blocking worldbone")
	var rows := FrostwayFieldPolicy.capture([_reaction()], 78)
	for fixture: Array in [[0, 0], [0, 2_000_000_000], [1, -1_000_001], [4, 100_000_001], [5, 30001], [6, 200001], [3, ORIGIN.x], [7, -1], [7, 157], [8, 78], [8, 499]]:
		var malformed := rows.duplicate()
		malformed[int(fixture[0])] = int(fixture[1])
		check(not FrostwayFieldPolicy.validate(malformed, 78), "malformed lane coordinate/dimension/timer/id fails closed")
	check(not FrostwayFieldPolicy.validate(rows, 498), "stale authority lane cannot be admitted at decay tick")
	var duplicate := rows.duplicate()
	duplicate.append_array(rows)
	check(not FrostwayFieldPolicy.validate(duplicate, 78), "duplicate lane identities rejected")
	rows.append(0)
	check(not FrostwayFieldPolicy.validate(rows, 78), "truncated row rejected")
	var a := _reaction(Vector2i(1000, 0), 4010)
	var b := _reaction(Vector2i(0, 1000), 4001)
	var sorted := FrostwayFieldPolicy.capture([a, b], 78)
	equal(sorted[0], 4001, "lane order stable by reaction identity, not input array order")
	equal(sorted, FrostwayFieldPolicy.capture([b, a], 78), "reordered authority source yields identical derived context")

func _test_ground_targets_and_actions() -> void:
	var world := CollisionWorld.new(2_000_000, 1_500_000)
	for radius: int in [17_000, 18_000, 19_000]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var rows := FrostwayFieldPolicy.capture([_reaction(direction)], 78)
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
					MovementSystem.step(slow, command, config, world, FrostwayFieldPolicy.movement_ratio(rows, center, tick))
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
			for action: String in ["jump", "slide", "roll", "float", "air_dodge", "wave_dash", "launched", "grappled", "charging", "stunned", "rooted"]:
				var state := _state(radius, direction)
				state.velocity_x = direction.x * 350
				state.velocity_y = direction.y * 350
				var pressed := 0
				var held := 0
				match action:
					"jump":
						pressed = SimCommand.PRESSED_JUMP
						held = SimCommand.HELD_JUMP
					"slide":
						pressed = SimCommand.PRESSED_SLIDE
						held = SimCommand.HELD_SLIDE
					"roll": pressed = SimCommand.PRESSED_EVADE
					"float", "air_dodge":
						state.air_height = 18_000
						state.hop_ticks = 30
						state.hop_stage = 1
						state.air_velocity_x = state.velocity_x
						state.air_velocity_y = state.velocity_y
						pressed = SimCommand.PRESSED_JUMP if action == "float" else SimCommand.PRESSED_EVADE
						held = SimCommand.HELD_JUMP if action == "float" else 0
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
				for field: StringName in ClientPrediction.STATE_FIELDS:
					equal(state.get(field), normal.get(field), "lane bypasses%s size%d dir%s field%s including resources/air budgets" % [action, radius, direction, field])
	var hostile := _state()
	MovementSystem.apply_control_state(hostile, PlayerState.ControlState.SLOWED, 500, Vector2i.ZERO, 0, config, 600)
	MovementSystem.step(hostile, SimCommand.new(78, 2, 1000, 0), config, world, 750)
	equal(hostile.control_state, PlayerState.ControlState.SLOWED, "independent hostile slow state preserved")
	equal(hostile.slow_ratio, 600, "independent hostile slow strength preserved")
	equal(world.obstacle_view().size(), 0, "all lane movement keeps immutable map geometry untouched")

func _projectile(element: int = 2, wire: int = 145) -> ProjectileState:
	var projectile := ProjectileState.new(1000, 3, 2, wire, element, ORIGIN + Vector2i(20_000, 0), Vector2i(120_000, 0), 4000, 9000, 200)
	projectile.remaining_distance = 180_000
	return projectile

func _test_projectiles_and_rays() -> void:
	var reaction := _reaction()
	var world := CollisionWorld.new(2_000_000, 1_500_000)
	var rows := FrostwayFieldPolicy.capture([reaction], 78)
	for element: int in range(1, 9):
		for wire: int in CombatTuning.runtime_wire_ids():
			var definition := CombatTuning.cast_definition(wire)
			if String(definition.get("shape", "")) != "projectile" or int(definition.get("element_wire_id", 0)) != element:
				continue
			var projectile := _projectile(element, wire)
			var events: Array[Dictionary] = []
			for tick: int in range(78, 90):
				var old_x := projectile.position_x
				var before_range := projectile.remaining_distance
				var survivors := CombatSystem.advance_projectiles([projectile], [], config, world, events, [reaction, reaction], tick)
				equal(survivors.size(), 1, "every physical projectile family/element passes overlapping lanes")
				equal(projectile.position_x - old_x, 650, "projectile travels65percent each tick, noncompounding and nonstacking")
				equal(projectile.remaining_distance, before_range - 650, "range tracks actual travel, never burns hidden extra distance")
				equal(projectile.velocity_x, 120_000, "base projectile velocity unchanged")
				equal(projectile.damage, 9000, "material never silently buffs or weakens damage")
				equal(projectile.lifetime_ticks, 200 - (tick - 77), "lifetime advances normally, no free extended expiry")
			projectile.position_x = ORIGIN.x + 250_000
			var old_x := projectile.position_x
			CombatSystem.advance_projectiles([projectile], [], config, world, events, [reaction], 90)
			equal(projectile.position_x - old_x, 1000, "exit restores base projectile travel next sampled tick")
			projectile.position_x = ORIGIN.x + 20_000
			old_x = projectile.position_x
			CombatSystem.advance_projectiles([projectile], [], config, world, events, [reaction], 498)
			equal(projectile.position_x - old_x, 1000, "decay restores base projectile travel at exact tick")
		var ray := ElementChemistrySystem.ray_interaction(ORIGIN - Vector2i(100_000, 0), ORIGIN + Vector2i(300_000, 0), element, 9000, [reaction], 78)
		check(not ray.blocked and not ray.transformed, "instant Beam/Spray rays never slowed, blocked or transformed by Frostway")
		check(CombatSystem.blast_clear_line(ORIGIN - Vector2i(100_000, 0), ORIGIN + Vector2i(300_000, 0), world, [reaction], 78, config), "Frostway never creates invisible splash cover")
	var fast := _projectile()
	fast.position_x = ORIGIN.x - 31_000
	fast.velocity_x = 1_200_000
	var events: Array[Dictionary] = []
	CombatSystem.advance_projectiles([fast], [], config, world, events, [reaction], 78)
	equal(fast.position_x, ORIGIN.x - 21_000, "boundary entry samples tick-start center, bounded to one120Hz step")
	CombatSystem.advance_projectiles([fast], [], config, world, events, [reaction], 79)
	equal(fast.position_x, ORIGIN.x - 14_500, "following tick immediately applies lane travel once")
	var spent := _projectile()
	spent.lifetime_ticks = 1
	equal(CombatSystem.advance_projectiles([spent], [], config, world, events, [reaction], 78).size(), 0, "slow projectile still expires on its original lifetime")
	equal(FrostwayFieldPolicy.projectile_ratio(rows, ORIGIN + Vector2i(100_000, 30_001), 78), 1000, "outside capsule has no oversized hidden influence")

func _test_prediction_and_replay() -> void:
	var base := CollisionWorld.new(2_000_000, 1_500_000)
	for radius: int in [17_000, 18_000, 19_000]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var reaction := _reaction(direction)
			var state := _state(radius, direction)
			var prediction := ClientPrediction.new()
			check(prediction.configure(config, base, 2), "Frostway prediction configures")
			var packet := ClientPrediction.capture_packet(state, 77, -1, [reaction])
			check(prediction.reconcile(packet), "exact authority lane accepted before activation")
			var missing := packet.duplicate(true)
			missing.erase("lanes")
			check(not ClientPrediction.validate_packet(missing), "old reconciliation lacking required lanes fails closed")
			for tick: int in range(77, 117):
				var command := SimCommand.new(tick, 2, direction.x, direction.y, SimCommand.HELD_SPRINT)
				var rows := FrostwayFieldPolicy.capture([reaction], tick)
				MovementSystem.step(state, command, config, base, FrostwayFieldPolicy.movement_ratio(rows, Vector2i(state.position_x, state.position_y), tick))
				check(prediction.queue_input(tick - 76, command), "pending input captured through formation and edge exit")
				for field: StringName in ClientPrediction.STATE_FIELDS:
					equal(prediction.predicted_state.get(field), state.get(field), "host/prediction agree all fields across sampled lane boundary")
			check(prediction.reconcile(ClientPrediction.capture_packet(state, 117, 40, [reaction])), "authority confirmation retires pending history")
			check(not prediction.reconcile(packet), "stale lane packet cannot resurrect previous material")
			state = _state(radius, direction)
			prediction = ClientPrediction.new()
			prediction.configure(config, base, 2)
			check(prediction.reconcile(ClientPrediction.capture_packet(state, 497, -1, [reaction])), "expiry probe starts on final active tick")
			var old_rows := FrostwayFieldPolicy.capture([reaction], 497)
			for tick: int in range(497, 505):
				var command := SimCommand.new(tick, 2, direction.x, direction.y)
				MovementSystem.step(state, command, config, base, FrostwayFieldPolicy.movement_ratio(old_rows, Vector2i(state.position_x, state.position_y), tick))
				prediction.queue_input(tick - 496, command)
				equal(Vector2i(prediction.predicted_state.velocity_x, prediction.predicted_state.velocity_y), Vector2i(state.velocity_x, state.velocity_y), "expiry releases prediction exactly without waiting for another packet")
	var first := SimWorld.new(120, 817, CollisionWorld.new(2_000_000, 1_500_000))
	var second := SimWorld.new(120, 817, CollisionWorld.new(2_000_000, 1_500_000))
	for world: SimWorld in [first, second]:
		world.players = [_state()]
		world.reactions = [_reaction()]
		world.tick = 77
	for tick: int in range(77, 575):
		var pressed := SimCommand.PRESSED_JUMP if tick == 100 else SimCommand.PRESSED_SLIDE if tick == 180 else 0
		var commands: Array[SimCommand] = [SimCommand.new(tick, 2, 1000 if tick < 200 else -1000, 0, 0, pressed)]
		check(first.step(commands) and second.step(commands), "whole authoritative worlds advance finite material and movement")
		equal(first.state_hash(), second.state_hash(), "snapshot-canonical world hashes deterministic through material expiry")
	equal(first.reactions.size(), 0, "expired Frostway removed from live world inventory")
	equal(first.collision.obstacle_view().size(), 0, "worldstep never installs a persistent material obstacle")

func _test_maximum_network_delivery() -> void:
	var reactions: Array = []
	for index: int in range(32):
		var reaction := _reaction(EightDirectionResolver.FIXED_VECTORS[index % 8], 4000 + index)
		var offset := Vector2i(index * 173_291, index * 121_357)
		reaction.position_x += offset.x
		reaction.position_y += offset.y
		reaction.endpoint_x += offset.x
		reaction.endpoint_y += offset.y
		reactions.append(reaction)
	var packet := ClientPrediction.capture_packet(_state(), 78, -1, reactions)
	check(not packet.is_empty() and packet.lanes.size() == 32 * FrostwayFieldPolicy.ROW_WIDTH, "all32 bounded lane rows fit required reconciliation contract")
	var mixed := reactions.slice(0, 16)
	for index: int in range(16):
		var rampart := _reaction(Vector2i(1000, 0), 5000 + index)
		rampart.recipe_wire_id = 301
		rampart.radius = 22_500
		rampart.length = 80_000
		rampart.health = 32_000
		mixed.append(rampart)
	var mixed_packet := ClientPrediction.capture_packet(_state(), 78, -1, mixed)
	check(not mixed_packet.is_empty() and mixed_packet.surfaces.size() == 16 * ReactionMovementWorld.ROW_WIDTH and mixed_packet.lanes.size() == 16 * FrostwayFieldPolicy.ROW_WIDTH, "mixed32 surface/lane authority validates one shared reaction budget")
	for wire: Dictionary in SessionTransport._snapshot_wire_packets(mixed_packet, true):
		check(var_to_bytes(wire).size() <= SessionTransport.ENET_MTU_BYTES, "mixed solid/material datagram stays within MTU")
	var oversized := packet.duplicate(true)
	oversized.surfaces = mixed_packet.surfaces
	check(not ClientPrediction.validate_packet(oversized), "separate row fields cannot exceed shared32-reaction authority cap")
	var aliased := mixed_packet.duplicate(true)
	aliased.surfaces[0] = ReactionMovementWorld.SURFACE_ID_BASE + aliased.lanes[0]
	check(not ClientPrediction.validate_packet(aliased), "one reaction cannot masquerade as both solid wall and lane")
	var too_many: PackedInt32Array = packet.lanes.duplicate()
	too_many.append_array(too_many.slice(0, FrostwayFieldPolicy.ROW_WIDTH))
	check(not FrostwayFieldPolicy.validate(too_many, 78), "more than32 lanes rejected")
	var encoded := var_to_bytes({"kind": SessionTransport.PACKET_RECONCILIATION, "reconciliation": packet}).size()
	check(encoded <= SessionTransport.MAX_PACKET_BYTES, "maximum exact-tick lane context fits existing raw message budget")
	var wire_packets := SessionTransport._snapshot_wire_packets(packet, true)
	check(not wire_packets.is_empty(), "maximum lane packet compresses/fragments through established codec")
	for wire: Dictionary in wire_packets:
		check(var_to_bytes(wire).size() <= SessionTransport.ENET_MTU_BYTES, "every production lane datagram fits actual ENet MTU")
	var host := SessionTransport.new()
	var guest := SessionTransport.new()
	var signature := SessionTransport.compatibility_signature(SimConfig.PROTOCOL_VERSION, 120, "frostway-m2a-test", "a".repeat(64), "b".repeat(64), SessionCharter.catalog_hash(), CanonicalContent.sha256(FrostwayFieldPolicy.policy()))
	check(host.start_host(0, signature, "Frostway Host"), "Frostway host uses ephemeral loopback test port")
	check(guest.start_join("127.0.0.1", host.bound_port, signature, "Frostway Guest"), "Frostway guest enters compatibility handshake")
	check(_poll_until(host, guest, func() -> bool: return guest.is_connected_client()), "Frostway field policy accepted through HELLO")
	if guest.is_connected_client():
		# Production clients learn this from their first complete world envelope.
		# This transport-focused fixture has no session world, so establish the
		# accepted host epoch explicitly before any reconciliation is admitted.
		check(guest.configure_world_epoch(host.world_epoch), "Frostway guest establishes the initial host world epoch")
		equal(guest.world_epoch, 0, "Frostway reconciliation runs in initial epoch zero")
		check(host.send_reconciliation(guest.local_peer_id, packet), "production network sends all32 exact-tick fields")
		check(_poll_until(host, guest, func() -> bool: return not guest.incoming_reconciliations.is_empty()), "actual ENet receives bounded lane reconciliation")
		var incoming := guest.take_reconciliations()
		check(not incoming.is_empty() and incoming.back() == packet, "all lane coordinates/times survive network exactly")
		var expired := ClientPrediction.capture_packet(_state(), 498, -1, reactions)
		check(host.send_reconciliation(guest.local_peer_id, expired), "finite lane removal sent by normal authority packet")
		check(_poll_until(host, guest, func() -> bool: return not guest.incoming_reconciliations.is_empty()), "guest receives lane expiry")
		var cleared := guest.take_reconciliations()
		check(not cleared.is_empty() and cleared.back().lanes.is_empty(), "no stale lane inventory after expiry")
	guest.stop()
	host.stop()
	check(not guest.is_online() and not host.is_online(), "Frostway test peers release sockets")

func _poll_until(host: SessionTransport, guest: SessionTransport, predicate: Callable) -> bool:
	for _index: int in range(2000):
		host.poll()
		guest.poll()
		if predicate.call():
			return true
		OS.delay_msec(1)
	return false

extends FluxTestSuite

const ORIGIN := Vector2i(600000, 500000)
var config := SimConfig.new(120)

func run() -> int:
	_test_prediction_discharge_and_replay()
	_test_overlap_cover_and_packets()
	_test_predicted_eligibility()
	_test_teaching()
	return finish("capacitor-integration")

func _reaction(id: int = 4000, direction: Vector2i = Vector2i(1000, 0), wire: int = 331) -> ElementReactionState:
	var result := ElementReactionState.new()
	result.entity_id = id
	result.recipe_wire_id = wire
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
	result.decay_tick = 318
	result.expiry_tick = 372
	result.radius = 30000
	result.length = 200000
	result.source_a = 3000
	result.source_b = 3001
	var endpoint := ORIGIN + ElementChemistrySystem.scaled(direction, result.length)
	result.endpoint_x = endpoint.x
	result.endpoint_y = endpoint.y
	return result

func _actor(direction: Vector2i = Vector2i(1000, 0), radius: int = 18000) -> PlayerState:
	var actor := PlayerState.new(2)
	actor.team_id = 2
	actor.radius = radius
	var center := ORIGIN + ElementChemistrySystem.scaled(direction, 100000)
	actor.position_x = center.x
	actor.position_y = center.y
	return actor

func _world(actor: PlayerState, reactions: Array, tick: int) -> SimWorld:
	var world := SimWorld.new(120, 817, CollisionWorld.new(2000000, 1500000))
	world.players = [actor]
	world.reactions.assign(reactions)
	world.tick = tick
	return world

func _test_prediction_discharge_and_replay() -> void:
	for radius: int in [17000, 18000, 19000]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for shortened: bool in [false, true]:
				var reaction := _reaction(4000, direction)
				if shortened:
					reaction.decay_tick = 222 # 60 percent trail-assisted sustain.
					reaction.expiry_tick = 276
				var start := reaction.decay_tick - 2
				var actor := _actor(direction, radius)
				var world := _world(actor, [reaction], start)
				var prediction := ClientPrediction.new()
				check(prediction.configure(config, world.collision, 2), "Capacitor prediction configures")
				check(prediction.reconcile(ClientPrediction.capture_packet(actor, start, -1, world.reactions)), "final discharge context accepted")
				var before := Vector2i(actor.position_x, actor.position_y)
				for tick: int in range(start, start + 5):
					var command := SimCommand.new(tick, 2, 0, 0)
					check(world.step([command]), "production world advances discharge and decay")
					check(prediction.queue_input(tick - start, command), "guest predicts same tick")
					for field: StringName in [&"position_x", &"position_y", &"velocity_x", &"velocity_y", &"control_state", &"air_height", &"stamina", &"flux"]:
						equal(prediction.predicted_state.get(field), actor.get(field), "host/prediction agree through final discharge %s" % field)
					if tick == start:
						equal(Vector2i(actor.position_x, actor.position_y), before, "no early activation discharge")
				check((Vector2i(actor.position_x, actor.position_y) - before).length() > 13900, "single finite discharge actually moved the actor")
				check((Vector2i(actor.position_x, actor.position_y) - before).length() <= 14001, "all sizes/directions receive at most14px across expiry")
				check(prediction.reconcile(ClientPrediction.capture_packet(actor, world.tick, 4, world.reactions)), "authoritative confirmation retires predicted discharge")
	var first := _world(_actor(), [_reaction()], 77)
	var second := _world(_actor(), [_reaction()], 77)
	for tick: int in range(77, 375):
		var command := SimCommand.new(tick, 2, 1000 if tick < 100 else 0, 0)
		check(first.step([command]) and second.step([command]), "repeat worlds advance")
		equal(first.state_hash(), second.state_hash(), "canonical snapshot hash/replay remains deterministic through expiry")
	equal(first.reactions.size(), 0, "Capacitor naturally expires without daughters")

func _test_overlap_cover_and_packets() -> void:
	var charge := _reaction()
	var ice := _reaction(4001, Vector2i(1000, 0), 327)
	var actor := _actor()
	var world := _world(actor, [charge, ice], 78)
	var expected := _actor()
	var command := SimCommand.new(78, 2, 1000, 0)
	MovementSystem.step(expected, command, config, world.collision, 750)
	check(world.step([command]), "overlap world advances")
	equal(actor.velocity_x, expected.velocity_x, "Frostway takes priority over Capacitor rather than multiplication")
	var wall := _reaction(4002, Vector2i(1000, 0), 301)
	wall.position_x = 741000
	wall.position_y = 500000
	wall.origin_x = wall.position_x
	wall.origin_y = wall.position_y
	wall.radius = 22500
	wall.length = 80000
	wall.health = 32000
	actor = _actor()
	world = _world(actor, [charge, wall], 317)
	check(world.step([SimCommand.new(317, 2, 0, 0)]), "discharge into active Rampart advances")
	check(actor.position_x >= 700000 and actor.position_x <= 700500, "discharge respects18px clearance against temporary cover (x=%d)" % actor.position_x)
	check(world.collision.obstacle_view().is_empty(), "temporary cover never mutates static world")
	var reactions: Array = []
	for index: int in range(32):
		reactions.append(_reaction(5000 + index, EightDirectionResolver.FIXED_VECTORS[index % 8]))
	var packet := ClientPrediction.capture_packet(_actor(), 78, -1, reactions)
	check(not packet.is_empty(), "32Charge rows fit canonical reconciliation")
	if packet.is_empty():
		return
	equal(packet.capacitors.size(), 32 * CapacitorFieldPolicy.ROW_WIDTH, "all bounded Charge context retained")
	for wire: Dictionary in SessionTransport._snapshot_wire_packets(packet, true):
		check(var_to_bytes(wire).size() <= SessionTransport.ENET_MTU_BYTES, "production compressed/fragmented packet respects MTU")
	var host := SessionTransport.new()
	var guest := SessionTransport.new()
	var signature := SessionTransport.compatibility_signature(SimConfig.PROTOCOL_VERSION, 120, "capacitor-m2b", "a".repeat(64), "b".repeat(64), SessionCharter.catalog_hash(), CanonicalContent.sha256(CapacitorFieldPolicy.policy()))
	check(host.start_host(0, signature, "Capacitor Host"), "ephemeral localhost host starts")
	check(guest.start_join("127.0.0.1", host.bound_port, signature, "Capacitor Guest"), "same-policy guest starts")
	check(_poll_until(host, guest, func() -> bool: return guest.is_connected_client()), "same-build compatibility handshake passes")
	if guest.is_connected_client():
		# This transport-only fixture establishes the epoch normally accepted
		# from a complete world envelope before field reconciliation.
		check(guest.configure_world_epoch(host.world_epoch), "Charge fixture establishes the accepted host epoch")
		equal(guest.world_epoch, 0, "Charge reconciliation uses the initial world epoch")
		check(host.send_reconciliation(guest.local_peer_id, packet), "32Charge rows sent through production ENet codec")
		check(_poll_until(host, guest, func() -> bool: return not guest.incoming_reconciliations.is_empty()), "guest receives exact field context")
		var incoming := guest.take_reconciliations()
		check(not incoming.is_empty() and incoming.back() == packet, "all geometry/timers/teams survive real localhost delivery")
	guest.stop()
	host.stop()
	var missing := packet.duplicate(true)
	missing.erase("capacitors")
	check(not ClientPrediction.validate_packet(missing), "old packet missing required Charge context rejected")
	var extra := ClientPrediction.capture_packet(_actor(), 78, -1, [ice])
	packet.lanes = extra.lanes
	check(not ClientPrediction.validate_packet(packet), "combined reaction budget cannot exceed32")
	packet = ClientPrediction.capture_packet(_actor(), 78, -1, [charge, ice])
	packet.lanes[0] = packet.capacitors[0]
	check(not ClientPrediction.validate_packet(packet), "one ID cannot masquerade as Ice and Charge")
	var policy := CapacitorFieldPolicy.policy()
	var original := CanonicalContent.sha256(policy)
	policy.walk_sprint_target_ratio = 1251
	check(CanonicalContent.sha256(policy) != original, "numeric lane rules participate in compatibility identity")

func _test_teaching() -> void:
	var text := " ".join(ChemistryGuideModel.pair_lines(5, 5))
	check(text.contains("125%") and text.contains("200 px") and text.contains("60 px"), "Charge teaching agrees with live footprint and speed")
	check(text.contains("14 px") and text.contains("0.50 s") and text.contains("without damage"), "teaching gives final warning/displacement and honest consequence")
	equal(ChemistryGuideModel.matrix_cell(5, 5).name, "Capacitor", "matrix uses current display name")

func _test_predicted_eligibility() -> void:
	for team: int in [1, 2]:
		for health: int in [0, 100000]:
			for protection: int in [0, 1, 2]:
				var actor := _actor()
				actor.team_id = team
				actor.health = health
				actor.spawn_protection_ticks = protection
				if health == 0:
					actor.velocity_x = 350000
					actor.sprinting = true
					actor.movement_mode = PlayerState.MovementMode.SPRINT
				var world := _world(actor, [_reaction()], 317)
				var prediction := ClientPrediction.new()
				prediction.configure(config, world.collision, 2)
				check(prediction.reconcile(ClientPrediction.capture_packet(actor, 317, -1, world.reactions)), "eligibility captured for team/life/protection")
				var command := SimCommand.new(317, 2, 0, 0)
				check(world.step([command]) and prediction.queue_input(0, command), "eligibility boundary advances")
				equal(prediction.predicted_state.position_x, actor.position_x, "protected/dead/allied enemy eligibility agrees with host")
				equal(actor.position_x, 714000 if team == 2 and health > 0 and protection <= 1 else 700000, "protection expires before discharge; allied/dead guests never displaced")
				for field: StringName in [&"velocity_x", &"velocity_y", &"sprinting", &"movement_mode"]:
					equal(prediction.predicted_state.get(field), actor.get(field), "defeat clears stale predicted movement like authority")

func _poll_until(host: SessionTransport, guest: SessionTransport, predicate: Callable) -> bool:
	for unused: int in range(2000):
		host.poll()
		guest.poll()
		if predicate.call():
			return true
		OS.delay_msec(1)
	return false

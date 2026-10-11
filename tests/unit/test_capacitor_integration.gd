extends FluxTestSuite

const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const ORIGIN := Vector2i(600000, 500000)
var config := SimConfig.new(120)

# Historical suite name retained for the runner. Charge/Capacitor331 is retired;
# current electrical integration uses Arcstorm311 and Caldera407's one impulse.
func run() -> int:
	_test_prediction_discharge_and_replay()
	_test_cover_overlap_and_eligibility()
	_test_complete_network_delivery()
	_test_teaching()
	return finish("capacitor-integration")


func _world(direction: Vector2i = Vector2i(1000, 0), radius: int = 18000, composite: bool = true) -> SimWorld:
	var world := SimWorld.new(120, 817, CollisionWorld.new(2000000, 1500000))
	world.hex_court = HexChemistryWorld.new()
	check(world.hex_court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 12)), "electrical integration configures a trusted finite topology")
	world.hex_court.chemistry_enabled = true
	var owner := world.player()
	owner.champion_wire_id = 0; owner.team_id = 1
	owner.position_x = 200000; owner.position_y = 200000
	owner.spawn_protection_ticks = 0
	var actor := PlayerState.new(2)
	actor.champion_wire_id = 0; actor.team_id = 2
	actor.position_x = ORIGIN.x; actor.position_y = ORIGIN.y; actor.radius = radius
	actor.health = 100000; actor.health_maximum = 100000
	actor.health_recovery_per_second = 0; actor.spawn_protection_ticks = 0
	world.players.append(actor)
	_add_product(world, direction, composite)
	world.collision = HexCollisionWorld.new(world.collision)
	world.reaction_movement = world.collision
	world.hex_court.collision = world.collision.base_world
	return world


func _add_product(world: SimWorld, direction: Vector2i, composite: bool = true) -> Dictionary:
	var court: HexChemistryWorld = world.hex_court
	var first_source := court.next_cast_id + 1000
	var wires: Array[int] = [145, 163]
	if composite: wires.assign([159, 140, 145])
	for index: int in wires.size():
		var source := first_source + index
		check(court.reserve_cast(1, wires[index]), "electrical recipe reserves an actual live Bolt source")
		court.commit_payment(1)
		court.bind_release(1, source, ORIGIN, direction, 1)
		if index == 1:
			check(bool(court.resolve_contact(first_source, source, ORIGIN, 0).accepted), "two real source ledgers form the starter pair")
		elif index == 2:
			court.deposit_terminal({"source_cast_id": source, "source_wire_id": wires[index], "reaction_strength": 5, "position": ORIGIN, "direction": direction}, 1)
	var product: Dictionary = court.products.values()[-1]
	equal(int(product.recipe_wire_id), 407 if composite else 311, "fresh Fire extends Earth/Water into real Caldera or Fire/Air remains Arcstorm")
	equal(int(product.funded_strength), 15 if composite else 10, "electrical effect retains exact paid source funding")
	court.sync_flights(world.players, world.projectiles)
	world.next_projectile_id = maxi(world.next_projectile_id, first_source + wires.size())
	return product


func _set_tick(world: SimWorld, tick: int) -> void:
	world.tick = tick
	# SimWorld stores the next input tick; the court stores the last executed
	# authority tick. Complete snapshots validate that exact relationship.
	world.hex_court.current_tick = maxi(0, tick - 1)
	check(world.collision.set_hex_surfaces(world.hex_court, tick), "current product phase prepares exact dynamic collision")


func _prediction(world: SimWorld) -> ClientPrediction:
	var result := ClientPrediction.new()
	check(result.configure(config, world.collision, 2), "electrical prediction configures")
	check(result.bind_hex_world(world), "prediction owns detached finite product state")
	check(result.reconcile(ClientPrediction.capture_packet(world.player(2), world.tick, -1)), "same-tick actor reconciles with complete Hex context")
	return result


func _assert_prediction(prediction: ClientPrediction, actor: PlayerState) -> void:
	for field: StringName in ClientPrediction.STATE_FIELDS:
		equal(prediction.predicted_state.get(field), actor.get(field), "electrical authority/prediction field " + String(field))


func _test_prediction_discharge_and_replay() -> void:
	for radius: int in [17000, 18000, 19000]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var world := _world(direction, radius)
			var actor := world.player(2)
			var product: Dictionary = world.hex_court.products.values()[0]
			_set_tick(world, int(product.active_tick) - 1)
			var prediction := _prediction(world)
			var before := Vector2i(actor.position_x, actor.position_y)
			var discharge_count := 0
			for index: int in range(5):
				var command := SimCommand.new(world.tick, 2)
				check(world.step([command]) and prediction.queue_input(index, command), "host and detached prediction advance actual electrical formation/activation")
				_assert_prediction(prediction, actor)
				for event: Dictionary in world.combat_events:
					if String(event.type) == "hex_capacitor_discharge": discharge_count += 1
				if index == 0:
					equal(Vector2i(actor.position_x, actor.position_y), before, "full formation warning has no early impulse")
					equal(actor.health, 100000, "full formation warning is harmless")
			equal(discharge_count, 1, "electrical descendant discharges once, not once per active tick")
			var displacement := Vector2i(actor.position_x, actor.position_y) - before
			check(displacement.length() > 13900 and displacement.length() <= 14001, "each radius and direction receives at most the exact14px impulse")
			equal(actor.health, 95500, "five-strength Caldera spends one exact4500Health attack")
			equal(int(product.damage_budget_remaining), 55500, "actual damage debits the15-strength60000 shared pool exactly")
			check(bool(product.contacts[2].effect_used), "one-use contact remains spent after the hit")
	var world := _world()
	var product: Dictionary = world.hex_court.products.values()[0]
	_set_tick(world, int(product.active_tick) - 1)
	var restored := HexWorldSnapshot.prepare(HexWorldSnapshot.capture(world), world)
	check(restored != null, "complete electrical source/funding snapshot prepares")
	if restored != null:
		for unused: int in range(int(product.expiry_tick) - world.tick + 1):
			var command := SimCommand.new(world.tick, 2)
			check(world.step([command]) and restored.step([command.copy()]), "source and restored authority advance to ordinary expiry")
			equal(world.state_hash(), restored.state_hash(), "electrical replay remains exact through formation, attack, harmless decay and expiry")
		check(world.hex_court.products.is_empty(), "electrical descendant expires without daughters")


func _test_cover_overlap_and_eligibility() -> void:
	var wall_world := _world()
	var wall_product: Dictionary = wall_world.hex_court.products.values()[0]
	wall_world.collision.base_world.add_obstacle(CollisionWorld.Obstacle.new(91, ORIGIN.x + 25000, ORIGIN.y - 60000, ORIGIN.x + 45000, ORIGIN.y + 60000))
	_set_tick(wall_world, int(wall_product.active_tick))
	check(wall_world.step([SimCommand.new(wall_world.tick, 2)]), "electrical impulse against worldbone advances")
	equal(wall_world.player(2).position_x, ORIGIN.x + 7000, "solid wall clips14px impulse at exact common18px clearance")
	equal(wall_world.player(2).health, 95500, "wall-clipped displacement does not erase the real hostile damage")
	var overlap := _world()
	_add_product(overlap, Vector2i(1000, 0))
	equal(overlap.hex_court.products.size(), 2, "same-subset products remain two independently paid fields")
	var product: Dictionary = overlap.hex_court.products.values()[0]
	_set_tick(overlap, int(product.active_tick))
	check(overlap.step([SimCommand.new(overlap.tick, 2)]), "overlapping electrical products execute")
	equal(overlap.player(2).position_x, ORIGIN.x + 14000, "two products cannot stack displacement beyond14px in one tick")
	equal(overlap.player(2).health, 91000, "two distinct paid pools retain their two independently funded4500 attacks")
	for scenario: String in ["ally", "protected", "air", "dead"]:
		var world := _world()
		var actor := world.player(2)
		product = world.hex_court.products.values()[0]
		if scenario == "ally": actor.team_id = 1
		elif scenario == "protected": actor.spawn_protection_ticks = 2
		elif scenario == "air":
			actor.air_height = 30000; actor.hop_stage = 1; actor.hop_ticks = MovementSystem._remaining_air_ticks(actor, config)
		else: actor.health = 0
		_set_tick(world, int(product.active_tick))
		var prediction := _prediction(world)
		var health := actor.health
		var command := SimCommand.new(world.tick, 2)
		check(world.step([command]) and prediction.queue_input(0, command), "protected/airborne/allied/defeated counter advances")
		_assert_prediction(prediction, actor)
		equal(actor.position_x, ORIGIN.x, "ineligible actor avoids electrical impulse")
		equal(actor.health, health, "ineligible actor avoids the grounded electrical attack")
	var core := _world(Vector2i(1000, 0), 18000, false)
	product = core.hex_court.products.values()[0]
	_set_tick(core, int(product.active_tick))
	check(core.step([SimCommand.new(core.tick, 2)]), "derived pair Arcstorm executes")
	equal(core.player(2).health, 95500, "Arcstorm pair supplies its actual one4500Health activation")
	equal(core.player(2).position_x, ORIGIN.x, "Arcstorm does not inherit removed Capacitor movement")
	equal(int(HexProductEffects.pre_movement(core.hex_court, core.player(2), core.tick, null, config).ground_target_ratio), 1000, "pair has no invented125percent ground-speed bonus")


func _test_complete_network_delivery() -> void:
	var world := _world()
	var product: Dictionary = world.hex_court.products.values()[0]
	_set_tick(world, int(product.active_tick) - 1)
	var authority := HexWorldSnapshot.capture(world)
	check(not authority.is_empty(), "electrical packet contains full source funding and contact authority")
	if authority.is_empty(): return
	var hearth := SessionHearth.new(); hearth.bind_host(); check(hearth.connect_entity(2), "second named champion enters session metadata")
	var round_state := SessionRound.new(); round_state.bind_hearth()
	# Transport names have a15-character bound. Keep the real wire boundary
	# visible here: an overlong guest label must fail before packet delivery.
	equal("Electrical Peer".length(), 15, "electrical peer name exercises the exact admitted name boundary")
	var invalid_names := WorldSnapshotEnvelope.make_hex_session([[1, "Electrical Host", "spawn"], [2, "Electrical Guest", "spawn"]], [], hearth.capture(world.tick, SessionSnapshot.MAX_PLAYERS), round_state.capture(world), PackedInt32Array([0, 0, 0, 0]))
	check(invalid_names.is_empty(), "sixteen-character metadata name refuses instead of silently changing network identity")
	var session := WorldSnapshotEnvelope.make_hex_session([[1, "Electrical Host", "spawn"], [2, "Electrical Peer", "spawn"]], [], hearth.capture(world.tick, SessionSnapshot.MAX_PLAYERS), round_state.capture(world), PackedInt32Array([0, 0, 0, 0]))
	check(not session.is_empty(), "bounded electrical identities form complete session metadata")
	var envelope := WorldSnapshotEnvelope.wrap_hex(authority, session, 0)
	check(WorldSnapshotEnvelope.validate(envelope), "complete electrical Hex envelope validates")
	if not WorldSnapshotEnvelope.validate(envelope): return
	var packets := SessionTransport._snapshot_wire_packets(envelope)
	check(not packets.is_empty(), "complete electrical authority reaches the production datagram codec")
	for packet: Dictionary in packets:
		check(var_to_bytes(packet).size() <= SessionTransport.ENET_MTU_BYTES, "every electrical datagram fits the actual ENet MTU")
	var host := SessionTransport.new(); var guest := SessionTransport.new()
	var signature := SessionTransport.compatibility_signature(SimConfig.PROTOCOL_VERSION, 120, "derived-electrical", "a".repeat(64), "b".repeat(64), SessionCharter.catalog_hash(), CanonicalContent.sha256(Policy.definition(407)))
	check(host.start_host(0, signature, "Electrical Host"), "ephemeral localhost host starts")
	check(guest.start_join("127.0.0.1", host.bound_port, signature, "Electrical Peer"), "matching guest joins")
	check(_poll_until(host, guest, func() -> bool: return guest.is_connected_client()), "same-content localhost handshake passes")
	if guest.is_connected_client():
		check(host.configure_world_epoch(0), "host publishes initial epoch")
		check(host.broadcast_envelope(envelope), "host sends complete electrical authority")
		check(_poll_until(host, guest, func() -> bool: return not guest.incoming_envelopes.is_empty()), "guest receives complete electrical envelope")
		var incoming := guest.poll_envelopes()
		check(not incoming.is_empty(), "electrical receipt exists")
		if not incoming.is_empty():
			equal(incoming.back(), envelope, "geometry, funding, contacts and actor state survive real localhost delivery exactly")
			var replica := HexWorldSnapshot.prepare(WorldSnapshotEnvelope.authority(incoming.back()), world)
			check(replica != null, "received electrical authority prepares against caller-trusted topology")
			if replica != null: equal(replica.state_hash(), world.state_hash(), "network receipt reconstructs the exact authority")
	guest.stop(); host.stop()


func _test_teaching() -> void:
	check(6 not in ChemistryGuideModel.DISPLAY_WIRES, "archived Charge lane does not return as a live ingredient choice")
	var cell := ChemistryGuideModel.matrix_cell(1,2)
	equal(cell.wire_id,311,"Fire and Air teach the live electrical reaction")
	var definition := ChemistryGuideModel.Policy.definition(311)
	var text := " ".join(ChemistryGuideModel.pair_lines(1,2))
	check(text.contains(String(definition.purpose)) and text.contains(String(definition.counter)),"electrical derived effect uses its actual live offense and response")


func _poll_until(host: SessionTransport, guest: SessionTransport, predicate: Callable) -> bool:
	for unused: int in range(2000):
		host.poll(); guest.poll()
		if predicate.call(): return true
		OS.delay_msec(1)
	return false

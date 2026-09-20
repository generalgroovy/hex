extends FluxTestSuite


const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"
const CAMPUS_PATH := "res://content/maps/sanctum_campus_g2_v1.json"
const REACTION_PATH := "res://content/reactions/first_eight_element_reactions_v1.json"
const TEST_RUNTIME_SOURCE_HASH := "abababababababababababababababababababababababababababababababab"
const HOST_NAME := "Unified Host"
const TARGET := Vector2i(1_504_000, 1_344_000)
const LOCAL_BENCH_OFFSET := Vector2i(0, 96_000)

var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var layout := SanctumCampusLayout.new()
var reactions := ReactionCatalog.new()
var reaction_definitions := ReactionDefinitionTable.new()
var definition: HexWorldDefinition


func run() -> int:
	var loaded := abilities.load_from_file(ABILITY_PATH) \
		and champions.load_from_file(CHAMPION_PATH, abilities) \
		and layout.load_from_file(CAMPUS_PATH) \
		and reactions.load_from_file(REACTION_PATH) \
		and reaction_definitions.compile(reactions, abilities)
	check(loaded, "unified ENet fixture loads the production ability, champion, campus and reaction catalogues")
	if not loaded:
		return finish("unified-enet")
	definition = HexWorldDefinition.from_campus(layout)
	check(definition != null, "normal campus supplies one trusted whole-Hex definition")
	if definition == null:
		return finish("unified-enet")
	_test_eight_player_epoch_transport()
	return finish("unified-enet")


func _test_eight_player_epoch_transport() -> void:
	var signature := _signature()
	check(signature.length() == 64, "production content produces a complete transport compatibility signature")
	var host := _transport()
	var clients: Array[SessionTransport] = []
	if not host.start_host(0, signature, HOST_NAME):
		check(false, "unified ENet host binds an automatic localhost port: %s" % host.last_error)
		return
	check(host.bound_port >= 1024, "unified ENet host exposes an unprivileged ephemeral port")

	var world := _new_hex_world(91_001, true)
	if world == null:
		check(false, "host creates the normal campus whole-Hex authority")
		host.stop()
		return
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, layout.spawn, HOST_NAME), "authoritative session binds the production Hex world")
	if session.world == null:
		host.stop()
		return

	# Six ordinary guests establish the initial session. The seventh guest joins
	# only after paid chemistry exists, so its first frame is a real late join.
	var initial_started := true
	for index: int in range(6):
		var client := _transport()
		clients.append(client)
		var started := client.start_join("127.0.0.1", host.bound_port, signature, "Unified Guest %d" % (index + 1))
		check(started, "initial guest %d opens a localhost ENet connection: %s" % [index + 1, client.last_error])
		initial_started = started and initial_started
	if not initial_started:
		_stop_all(host, clients)
		return
	check(_poll_many_until(host, clients, func() -> bool: return _all_connected(clients)), "six initial guests complete the production handshake")
	if not _all_connected(clients):
		_stop_all(host, clients)
		return
	var joined := host.take_joined_peers()
	equal(session.register_peers(joined), 6, "authoritative session creates every accepted initial champion")
	equal(host.player_count(), 7, "initial localhost company contains the host and six guests")
	_assert_catalogue_actors(session.world, 7, "initial")
	for client: SessionTransport in clients:
		equal(client.world_epoch, -1, "accepted guest still lacks world authority before its first complete envelope")
		check(not client.send_input(1, SimCommand.new(0, client.local_entity_id)), "accepted guest cannot send input before receiving epoch zero")

	var initial_envelope := session.capture_envelope()
	check(WorldSnapshotEnvelope.validate(initial_envelope), "initial seven-player Hex authority captures as one exact envelope")
	check(host.configure_world_epoch(session.world_epoch), "host configures initial epoch zero")
	var initial_received := _broadcast_and_take(host, clients, initial_envelope, "initial epoch")
	_assert_replicas(initial_received, session.world, 7, "initial epoch")
	check(clients[0].send_input(1, SimCommand.new(session.world.tick, clients[0].local_entity_id, 1000, 0)), "complete initial envelope enables client input")
	check(_poll_many_until(host, clients, func() -> bool: return not host.incoming_inputs.is_empty()), "epoch-zero input crosses the real localhost socket")
	var first_inputs := host.take_inputs()
	equal(first_inputs.size(), 1, "host receives exactly the newly authorized epoch-zero input")
	if not first_inputs.is_empty():
		equal(int(first_inputs[0].get("entity_id", 0)), clients[0].local_entity_id, "host stamps the authenticated initial input identity")

	# Steam runs through the production guided demo. Flood and Fortify use fresh
	# actors and the same 96px clear approach used by that demo. The short local
	# paths avoid optional trail debits, and distinct empty Hexes prevent an older
	# ingredient or product from intercepting the intended pair.
	if not _drive_paid_demo(session.world, "water", "fire", 310):
		_stop_all(host, clients)
		return
	var flood_site := _separate_pair_site(session.world)
	check(not flood_site.is_empty(), "normal campus supplies a clear local Flood cast site outside live Steam")
	if flood_site.is_empty() or not _drive_paid_pair(session.world, clients[0].local_entity_id, "water", "water", 316, flood_site):
		_stop_all(host, clients)
		return
	var fortify_site := _separate_pair_site(session.world)
	check(not fortify_site.is_empty(), "normal campus supplies a distinct clear local Fortify cast site outside Steam and Flood")
	if fortify_site.is_empty() or not _drive_paid_pair(session.world, clients[1].local_entity_id, "earth", "earth", 301, fortify_site):
		_stop_all(host, clients)
		return
	var fortify := _product(session.world, 301)
	while session.world.tick <= int(fortify.active_tick):
		check(session.world.step([]), "paid Fortify advances to its physical active phase")
	_assert_rich_paid_state(session.world, "pre-late-join")

	var late := _transport()
	clients.append(late)
	var late_started := late.start_join("127.0.0.1", host.bound_port, signature, "Unified Guest 7")
	check(late_started, "seventh guest begins a true late join after paid products exist")
	if not late_started:
		_stop_all(host, clients)
		return
	var late_connected := _poll_many_until(host, clients, func() -> bool: return _all_connected(clients))
	check(late_connected, "late guest completes the production handshake")
	if not late_connected:
		_stop_all(host, clients)
		return
	var late_joined := host.take_joined_peers()
	equal(late_joined.size(), 1, "host exposes exactly one late-join presence event")
	equal(session.register_peers(late_joined), 1, "late guest receives one catalogue-backed champion")
	equal(host.player_count(), SessionTransport.MAX_PLAYERS, "localhost session reaches the supported eight-player capacity")
	_assert_catalogue_actors(session.world, SessionTransport.MAX_PLAYERS, "late-join")
	equal(late.world_epoch, -1, "late guest cannot infer the current epoch from handshake metadata")
	check(not late.send_input(1, SimCommand.new(session.world.tick, late.local_entity_id)), "late guest cannot send before receiving its first world")

	var rich_envelope := session.capture_envelope()
	check(WorldSnapshotEnvelope.validate(rich_envelope), "eight-player paid Hex state fits the exact envelope")
	var rich_bytes := WorldSnapshotEnvelope.byte_size(rich_envelope)
	check(rich_bytes > 0 and rich_bytes <= WorldSnapshotEnvelope.MAX_RAW_BYTES, "eight-player paid Hex envelope respects the unchanged raw32768 limit")
	var rich_packets := SessionTransport._envelope_wire_packets(rich_envelope)
	check(not rich_packets.is_empty(), "eight-player paid envelope has a bounded production packet sequence")
	for packet: Dictionary in rich_packets:
		check(var_to_bytes(packet).size() <= SessionTransport.ENET_MTU_BYTES, "every paid-state fragment respects the unchanged ENet MTU")
	print("UNIFIED ENET HEX: raw=%d packets=%d players=%d products=%d" % [rich_bytes, rich_packets.size(), session.world.players.size(), session.world.hex_court.products.size()])
	var rich_received := _broadcast_and_take(host, clients, rich_envelope, "late-join paid state")
	_assert_replicas(rich_received, session.world, SessionTransport.MAX_PLAYERS, "late-join paid state")
	for received: Dictionary in rich_received:
		equal(received, rich_envelope, "every client receives the same decoded canonical envelope and typed lanes")

	# Stop and return one established peer. The AuthoritativeSession retains its
	# actor and chemistry while the transport rotates the reconnect capability.
	var returning: SessionTransport = clients[2]
	var returning_entity := returning.local_entity_id
	var paid_quantities := _product_quantities(session.world)
	var old_occluder_count := _hex_occluder_count(session.world)
	returning.stop()
	check(_poll_many_until(host, clients, func() -> bool: return host.reserved_count() == 1), "host reserves the disconnected rich-state identity")
	var disconnected := host.take_disconnected_peers()
	check(not disconnected.is_empty() and bool(disconnected[0].get("reserved", false)), "disconnect is represented as a resumable presence transition")
	equal(session.suspend_peers(disconnected), 1, "authoritative actor is suspended instead of deleted during return window")
	var return_started := returning.start_join("127.0.0.1", host.bound_port, signature, "Unified Guest 3")
	check(return_started, "same client begins endpoint-scoped reconnection")
	if not return_started:
		_stop_all(host, clients)
		return
	var return_connected := _poll_many_until(host, clients, func() -> bool: return _all_connected(clients))
	check(return_connected, "returning guest reclaims its localhost session")
	if not return_connected:
		_stop_all(host, clients)
		return
	equal(returning.local_entity_id, returning_entity, "reconnection preserves the exact actor identity")
	var resumed := host.take_joined_peers()
	check(resumed.size() == 1 and bool(resumed[0].get("resumed", false)), "host labels the accepted connection as an exact resume")
	equal(session.register_peers(resumed), 1, "authoritative session reconnects the existing catalogue actor")
	equal(returning.world_epoch, -1, "reconnected guest again waits for a complete world envelope")
	check(not returning.send_input(1, SimCommand.new(session.world.tick, returning.local_entity_id)), "reconnected guest cannot act from stale local world state")
	check(session.world.step([]), "authority advances once so the resumed roster has a newer canonical frame")
	equal(_product_quantities(session.world), paid_quantities, "reconnect preserves every paid recipe and finite quantity")
	equal(_hex_occluder_count(session.world), old_occluder_count, "reconnect preserves the active six-face collision surface")
	var resumed_envelope := session.capture_envelope()
	var resumed_received := _broadcast_and_take(host, clients, resumed_envelope, "reconnected paid state")
	_assert_replicas(resumed_received, session.world, SessionTransport.MAX_PLAYERS, "reconnected paid state")

	# Preserve real old wire packets, then reset to a fresh trusted world at a
	# higher epoch and lower tick. Delayed delivery occurs through the same ENet
	# sockets after the new epoch has already been accepted.
	var delayed_old_packets := SessionTransport._envelope_wire_packets(resumed_envelope)
	check(not delayed_old_packets.is_empty(), "old rich state has a bounded production wire representation")
	var reset_world := _new_hex_world(91_002, true)
	check(reset_world != null and session.replace_world(reset_world, layout.spawn), "authoritative reset replaces the rich world atomically")
	if reset_world == null or session.world != reset_world:
		_stop_all(host, clients)
		return
	equal(session.world_epoch, 1, "world reset advances the outer transport epoch exactly once")
	equal(session.world.tick, 0, "fresh epoch legitimately restarts at lower tick zero")
	check(session.world.hex_court.products.is_empty() and session.world.hex_court.casts.is_empty() and session.world.hex_court.sources.is_empty() and session.world.hex_court.pending.is_empty(), "new epoch contains no old paid product, source ledger or reservation")
	equal(_hex_occluder_count(session.world), 0, "new epoch contains no old dynamic pillar collision")
	check(host.configure_world_epoch(session.world_epoch), "host changes transport authority to reset epoch one")
	var reset_envelope := session.capture_envelope()
	var reset_received := _broadcast_and_take(host, clients, reset_envelope, "reset epoch")
	_assert_replicas(reset_received, session.world, SessionTransport.MAX_PLAYERS, "reset epoch")
	for client: SessionTransport in clients:
		equal(client.world_epoch, 1, "higher epoch is accepted despite its lower tick zero")

	var delayed_sent := true
	for packet: Dictionary in delayed_old_packets:
		delayed_sent = host._send_to(returning.local_peer_id, packet, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, SessionTransport.SNAPSHOT_CHANNEL) and delayed_sent
	check(delayed_sent, "host socket delivers the delayed old-epoch frame to the rejection boundary")
	var delayed_input := {
		"kind": SessionTransport.PACKET_INPUT,
		"world_epoch": 0,
		"sequence": 999,
		"move_x": 1000,
		"move_y": 0,
		"held": 0,
		"pressed": SimCommand.PRESSED_SPELL_1,
		"aim_x": 1000,
		"aim_y": 0,
		"aim_target_x": TARGET.x,
		"aim_target_y": TARGET.y,
	}
	check(returning._send_to(SessionTransport.SERVER_PEER_ID, delayed_input), "client socket delivers delayed epoch-zero input to the host rejection boundary")
	_poll_fixed(host, clients, 60)
	check(returning.poll_envelopes().is_empty(), "delayed old frame cannot re-enter the accepted epoch-one queue")
	check(host.take_inputs().is_empty(), "delayed old input cannot enter epoch-one authority")
	equal(returning.world_epoch, 1, "delayed old traffic cannot roll back the accepted epoch")
	check(returning.send_input(1, SimCommand.new(0, returning.local_entity_id, 0, -1000)), "fresh epoch-one input remains usable after stale traffic")
	check(_poll_many_until(host, clients, func() -> bool: return not host.incoming_inputs.is_empty()), "fresh epoch-one input crosses the same socket")
	var fresh_inputs := host.take_inputs()
	equal(fresh_inputs.size(), 1, "rejected stale input does not poison the fresh sequence watermark")
	if not fresh_inputs.is_empty():
		equal(int(fresh_inputs[0].get("world_epoch", -1)), 1, "host accepts only input stamped with current epoch one")

	_stop_all(host, clients)


func _drive_paid_demo(world: SimWorld, first: String, second: String, expected_wire: int) -> bool:
	var paid_before := int(world.hex_court.metrics.matter_paid)
	var demo := HexPlaygroundDemo.new()
	var began := demo.begin(world, 1, first, second, abilities)
	check(began, "%s plus %s begins through the production paid-demo path" % [first, second])
	if not began:
		return false
	for _unused: int in range(1_000):
		if not demo.is_active():
			break
		var command: SimCommand = demo.command(world)
		if command == null:
			continue
		check(world.step([command]), "%s plus %s advances through ordinary SimCommands" % [first, second])
	check(not demo.is_active() and demo.status().contains("complete"), "%s plus %s paid demo completes" % [first, second])
	equal(int(world.hex_court.metrics.matter_paid), paid_before + 1_200, "%s plus %s pays exactly two finite sources" % [first, second])
	var product := _product(world, expected_wire)
	check(not product.is_empty(), "%s plus %s creates production recipe %d" % [first, second, expected_wire])
	if not product.is_empty():
		equal(int(product.quantity), 1_200, "recipe %d retains both paid source budgets" % expected_wire)
	return not demo.is_active() and demo.status().contains("complete") and not product.is_empty() and int(product.quantity) == 1_200


func _drive_paid_pair(world: SimWorld, actor_id: int, first: String, second: String, expected_wire: int, site: Dictionary) -> bool:
	var actor := world.player(actor_id)
	check(actor != null, "%s plus %s has a dedicated production actor" % [first, second])
	if actor == null:
		return false
	var target: Vector2i = site.get("target", Vector2i.ZERO)
	var bench: Vector2i = site.get("bench", Vector2i.ZERO)
	var approach := bench - target
	check(target != Vector2i.ZERO and bench != Vector2i.ZERO and approach in [LOCAL_BENCH_OFFSET, -LOCAL_BENCH_OFFSET, Vector2i(LOCAL_BENCH_OFFSET.y, 0), Vector2i(-LOCAL_BENCH_OFFSET.y, 0)], "%s plus %s uses one exact local demo-length approach" % [first, second])
	check(not _site_touches_chemistry(world, target, bench), "%s plus %s begins with no product or ingredient along its local flight" % [first, second])
	actor.position_x = bench.x
	actor.position_y = bench.y
	actor.position_remainder_x = 0
	actor.position_remainder_y = 0
	var first_ability := abilities.ability(abilities.spell_id_at(first, "bolt"))
	var second_ability := abilities.ability(abilities.spell_id_at(second, "bolt"))
	var first_wire := int(first_ability.get("wire_id", 0))
	var second_wire := int(second_ability.get("wire_id", 0))
	check(first_wire > 0 and second_wire > 0, "%s plus %s resolves production Bolt wires" % [first, second])
	check(actor.place_proven_spell(0, first_wire), "%s Bolt equips through the ordinary legal weave API" % first)
	if first_wire != second_wire:
		check(actor.place_proven_spell(1, second_wire), "%s Bolt equips through the ordinary legal weave API" % second)
	var paid_before := int(world.hex_court.metrics.matter_paid)
	var first_command := _paid_command(world, actor, 0, target)
	check(world.step([first_command]), "%s first paid Bolt advances through SimWorld" % first)
	equal(int(world.hex_court.metrics.matter_paid), paid_before + 600, "%s first Bolt reserves one finite source" % first)
	for _unused: int in range(360):
		if actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(second_wire) == 0 and not _owner_has_flight(world, actor.entity_id):
			break
		check(world.step([]), "%s first paid Bolt reaches terminal authority" % first)
	var second_slot := 0 if first_wire == second_wire else 1
	var second_command := _paid_command(world, actor, second_slot, target)
	check(world.step([second_command]), "%s second paid Bolt advances through SimWorld" % second)
	equal(int(world.hex_court.metrics.matter_paid), paid_before + 1_200, "%s plus %s pays exactly two finite sources" % [first, second])
	for _unused: int in range(360):
		if not _product(world, expected_wire).is_empty():
			break
		check(world.step([]), "%s plus %s resolves through real startup, flight and contact" % [first, second])
	var product := _product(world, expected_wire)
	check(not product.is_empty(), "%s plus %s creates production recipe %d" % [first, second, expected_wire])
	if not product.is_empty():
		equal(int(product.quantity), 1_200, "recipe %d retains both paid source budgets" % expected_wire)
	check(world.hex_court.conservation_valid(), "%s plus %s preserves paid matter conservation" % [first, second])
	return not product.is_empty() and int(product.quantity) == 1_200 and world.hex_court.conservation_valid()


func _paid_command(world: SimWorld, actor: PlayerState, slot: int, target: Vector2i) -> SimCommand:
	var delta := target - Vector2i(actor.position_x, actor.position_y)
	return SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[slot]), delta.x, delta.y, target.x, target.y)


func _separate_pair_site(world: SimWorld) -> Dictionary:
	var offsets: Array[Vector2i] = [LOCAL_BENCH_OFFSET, -LOCAL_BENCH_OFFSET, Vector2i(LOCAL_BENCH_OFFSET.y, 0), Vector2i(-LOCAL_BENCH_OFFSET.y, 0)]
	for cell: Vector2i in definition.eligible_cells:
		var candidate := definition.origin + HexGrid.center(cell)
		if candidate.distance_squared_to(TARGET) <= 180_000 * 180_000 or not _has_chemistry_clearance(world, candidate):
			continue
		for offset: Vector2i in offsets:
			var bench := candidate + offset
			if not world.collision.can_occupy(bench, MovementTuning.PLAYER_RADIUS):
				continue
			if not (world.collision as HexCollisionWorld).hex_wall_contact(bench, candidate, 11_000).is_empty():
				continue
			if _site_touches_chemistry(world, candidate, bench):
				continue
			return {"target": candidate, "bench": bench}
	return {}


func _has_chemistry_clearance(world: SimWorld, point: Vector2i) -> bool:
	const CLEARANCE_SQUARED := 220_000 * 220_000
	for record: Dictionary in world.hex_court.casts.values():
		var origin: Vector2i = record.get("origin", point)
		if point.distance_squared_to(origin) <= CLEARANCE_SQUARED:
			return false
	for product: Dictionary in world.hex_court.products.values():
		var position: Vector2i = product.get("position", point)
		if point.distance_squared_to(position) <= CLEARANCE_SQUARED:
			return false
	return true


func _site_touches_chemistry(world: SimWorld, target: Vector2i, bench: Vector2i) -> bool:
	var swept := {}
	for cell: Vector2i in world.hex_court.select_cells(HexFootprint.capsule(bench, target, 12_000)):
		swept[cell] = 1
	if swept.is_empty():
		return true
	for record: Dictionary in world.hex_court.casts.values():
		for cell: Vector2i in HexChemistryWorld.coverage(record):
			if swept.has(cell):
				return true
	for product: Dictionary in world.hex_court.products.values():
		for cell: Vector2i in HexChemistryWorld.coverage(product):
			if swept.has(cell):
				return true
	return false


func _owner_has_flight(world: SimWorld, actor_id: int) -> bool:
	for projectile: ProjectileState in world.projectiles:
		if projectile.owner_id == actor_id:
			return true
	for record: Dictionary in world.hex_court.casts.values():
		if int(record.get("owner", 0)) == actor_id and not (record.get("flight_parts", {}) as Dictionary).is_empty():
			return true
	return false


func _assert_rich_paid_state(world: SimWorld, label: String) -> void:
	equal(int(world.hex_court.metrics.matter_paid), 3_600, "%s records exactly six paid 600-matter admissions" % label)
	for wire: int in [310, 316, 301]:
		var product := _product(world, wire)
		check(not product.is_empty(), "%s retains paid recipe %d" % [label, wire])
		if not product.is_empty():
			equal(int(product.quantity), 1_200, "%s recipe %d retains exact finite quantity" % [label, wire])
	check(world.hex_court.conservation_valid(), "%s paid chemistry conserves all source matter" % label)
	check(_hex_occluder_count(world) > 0, "%s includes a real active Fortify collision polygon" % label)


func _assert_catalogue_actors(world: SimWorld, expected: int, label: String) -> void:
	var champion_count := 0
	for state: PlayerState in world.players:
		if state.actor_kind != PlayerState.ActorKind.CHAMPION:
			continue
		champion_count += 1
		check(not champions.champion_id_from_wire(state.champion_wire_id).is_empty(), "%s actor %d owns an actual catalogue champion" % [label, state.entity_id])
		check(state.has_valid_spell_slots(), "%s actor %d owns an actual valid twelve-spell weave" % [label, state.entity_id])
	equal(champion_count, expected, "%s authority contains the exact connected champion count" % label)


func _assert_replicas(envelopes: Array[Dictionary], authority: SimWorld, expected_actors: int, label: String) -> void:
	equal(envelopes.size(), expected_actors - 1, "%s reaches every connected remote client" % label)
	for index: int in range(envelopes.size()):
		var envelope := envelopes[index]
		check(WorldSnapshotEnvelope.validate(envelope), "%s client %d receives one validated whole envelope" % [label, index + 1])
		var trusted := _new_hex_world(92_000 + index, true)
		var replica: SimWorld = null
		if trusted != null:
			replica = HexWorldSnapshot.prepare(WorldSnapshotEnvelope.authority(envelope), trusted)
		check(replica != null, "%s client %d prepares against independent trusted campus geometry" % [label, index + 1])
		if replica == null:
			continue
		equal(replica.state_hash(), authority.state_hash(), "%s client %d receives the identical canonical Hex world" % [label, index + 1])
		equal(replica.players.size(), expected_actors, "%s client %d receives all canonical actors" % [label, index + 1])
		equal(_product_quantities(replica), _product_quantities(authority), "%s client %d receives every paid product quantity" % [label, index + 1])
		equal(_hex_occluder_count(replica), _hex_occluder_count(authority), "%s client %d rebuilds the same trusted dynamic collision" % [label, index + 1])


func _broadcast_and_take(host: SessionTransport, clients: Array[SessionTransport], envelope: Dictionary, label: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sent := host.broadcast_envelope(envelope)
	check(sent, "%s broadcasts through production SessionTransport" % label)
	if not sent:
		return result
	# Snapshot fragments intentionally use ENet's unreliable lane. Production
	# publishes repeatedly, so exercise that contract without advancing authority:
	# retransmit the identical epoch/tick until every peer has one complete frame.
	# Completed peers reject the same tuple in _accept_envelope, while an incomplete
	# peer can fill its existing assembly from any identical retransmission.
	var arrived := false
	var retransmits_sent := true
	for poll_index: int in range(3_000):
		host.poll()
		for client: SessionTransport in clients:
			client.poll()
		var every_client_has_exactly_one := true
		for client: SessionTransport in clients:
			if client.incoming_envelopes.size() != 1:
				every_client_has_exactly_one = false
				break
		if every_client_has_exactly_one:
			arrived = true
			break
		if poll_index > 0 and poll_index % 80 == 0:
			retransmits_sent = host.broadcast_envelope(envelope) and retransmits_sent
		OS.delay_msec(1)
	check(retransmits_sent, "%s identical unreliable retransmissions remain wire-valid" % label)
	check(arrived, "%s fully reassembles on every localhost client" % label)
	if not arrived:
		return result
	for client: SessionTransport in clients:
		var received := client.poll_envelopes()
		equal(received.size(), 1, "%s is queued exactly once per client" % label)
		if not received.is_empty():
			result.append(received.back())
	return result


func _new_hex_world(seed: int, apply_host_champion: bool) -> SimWorld:
	var world := SimWorld.new(120, seed, layout.build_collision_world(), String(layout.data.get("id", "")), layout.content_hash)
	if apply_host_champion and not champions.apply_to_player(world.player(), champions.default_champion_id):
		return null
	world.player().reset_for_spawn(layout.spawn * SimConfig.FIXED_SCALE)
	world.player().spawn_protection_ticks = 0
	return world if definition.bind_world(world) else null


func _product(world: SimWorld, wire: int) -> Dictionary:
	for product: Dictionary in world.hex_court.products.values():
		if int(product.recipe_wire_id) == wire:
			return product
	return {}


func _product_quantities(world: SimWorld) -> Dictionary:
	var result := {}
	if world == null or world.hex_court == null:
		return result
	for product: Dictionary in world.hex_court.products.values():
		result[int(product.recipe_wire_id)] = int(product.quantity)
	return result


func _hex_occluder_count(world: SimWorld) -> int:
	return (world.collision as HexCollisionWorld).hex_occluders().size() if world != null and world.collision is HexCollisionWorld else -1


func _signature() -> String:
	return SessionTransport.compatibility_signature(
		SimConfig.PROTOCOL_VERSION,
		120,
		layout.content_hash,
		abilities.content_hash,
		champions.content_hash,
		SessionCharter.catalog_hash(),
		reaction_definitions.content_hash,
		TEST_RUNTIME_SOURCE_HASH,
	)


func _transport() -> SessionTransport:
	var transport := SessionTransport.new()
	check(transport.configure_runtime_identity(_identity_manifest()), "transport accepts the bounded test runtime identity")
	return transport


func _identity_manifest() -> Dictionary:
	return {
		"schema_version": RuntimeBuildIdentity.SCHEMA_VERSION,
		"status": RuntimeBuildIdentity.STATUS,
		"scope_id": RuntimeBuildIdentity.SCOPE_ID,
		"canonical_encoding": RuntimeBuildIdentity.CANONICAL_ENCODING,
		"protocol_version": SimConfig.PROTOCOL_VERSION,
		"snapshot_schema": SessionSnapshot.SCHEMA_VERSION,
		"engine_identity": RuntimeBuildIdentity.PINNED_ENGINE_IDENTITY,
		"record_count": 1,
		"runtime_source_sha256": TEST_RUNTIME_SOURCE_HASH,
		"build_id": "p%d-%s" % [SimConfig.PROTOCOL_VERSION, TEST_RUNTIME_SOURCE_HASH.left(RuntimeBuildIdentity.SHORT_HASH_LENGTH)],
		"authority": RuntimeBuildIdentity.AUTHORITY,
	}


func _poll_many_until(host: SessionTransport, clients: Array[SessionTransport], predicate: Callable) -> bool:
	for _index: int in range(3_000):
		host.poll()
		for client: SessionTransport in clients:
			client.poll()
		if predicate.call():
			return true
		OS.delay_msec(1)
	return false


func _poll_fixed(host: SessionTransport, clients: Array[SessionTransport], count: int) -> void:
	for _index: int in count:
		host.poll()
		for client: SessionTransport in clients:
			client.poll()
		OS.delay_msec(1)


func _all_connected(clients: Array[SessionTransport]) -> bool:
	for client: SessionTransport in clients:
		if not client.is_connected_client():
			return false
	return true


func _stop_all(host: SessionTransport, clients: Array[SessionTransport]) -> void:
	for client: SessionTransport in clients:
		client.stop()
	host.stop()

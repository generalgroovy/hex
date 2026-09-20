extends FluxTestSuite

const CENTER := Vector2i(600_000, 500_000)

func run() -> int:
	_test_lifecycle_and_geometry()
	_test_escape_and_reentry()
	_test_wall_actions_and_expiry()
	_test_prediction_and_validation()
	_test_world_and_attack_integration()
	_test_maximum_enet_delivery()
	return finish("rampart-movement")

func _reaction() -> ElementReactionState:
	var reaction := ElementReactionState.new()
	reaction.entity_id = 4000
	reaction.recipe_wire_id = 301
	reaction.owner_id = 1
	reaction.team_id = 1
	reaction.position_x = CENTER.x
	reaction.position_y = CENTER.y
	reaction.origin_x = CENTER.x
	reaction.origin_y = CENTER.y
	reaction.created_tick = 0
	reaction.active_tick = 22
	reaction.decay_tick = 397
	reaction.expiry_tick = 445
	reaction.radius = 22_500
	reaction.length = 80_000
	reaction.health = 32_000
	reaction.source_a = 3000
	reaction.source_b = 3001
	return reaction

func _state(radius: int = 18_000) -> PlayerState:
	var state := PlayerState.new(2)
	state.position_x = CENTER.x - 90_000
	state.position_y = CENTER.y
	state.radius = radius
	return state

func _layer(reaction: ElementReactionState, tick: int, state: PlayerState = null) -> ReactionMovementWorld:
	var layer := ReactionMovementWorld.new(CollisionWorld.new(2_000_000, 1_500_000))
	layer.set_surfaces(ReactionMovementWorld.capture_surfaces([reaction], tick), tick)
	var position := Vector2i(state.position_x, state.position_y) if state != null else CENTER - Vector2i(100_000, 0)
	layer.begin_actor(position, MovementTuning.PLAYER_RADIUS)
	return layer

func _test_lifecycle_and_geometry() -> void:
	var reaction := _reaction()
	check(reaction.validate(), "Rampart fixture is valid authoritative reaction state")
	var point := CENTER - Vector2i(100_000, 0)
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		reaction.direction_x = direction.x
		reaction.direction_y = direction.y
		var bounds := ElementChemistrySystem.rampart_bounds(reaction)
		check(bounds.size in [Vector2i(45_000, 80_000), Vector2i(80_000, 45_000)], "all eight cast directions choose exact enlarged tileable rectangle")
		check(ElementChemistrySystem.contains(reaction, bounds.position, 22, SimConfig.new()), "attack footprint contains exact rectangle corner")
		check(not ElementChemistrySystem.contains(reaction, bounds.position - Vector2i(1, 1), 22, SimConfig.new()), "attack footprint excludes outside rectangle corner")
		for hurtbox: int in [17_000, 18_000, 19_000]:
			var state := _state(hurtbox)
			for tick: int in [0, 21, 22, 396, 397, 445]:
				var layer := _layer(reaction, tick, state)
				var moved := layer.move_box(point, Vector2i(200_000, 0), MovementTuning.PLAYER_RADIUS)
				var active := tick >= 22 and tick < 397
				equal(moved.wall_id > 0, active, "solid exactly during active life for each hurtbox")
				if active:
					equal(moved.position.x, bounds.position.x - MovementTuning.PLAYER_RADIUS, "all sizes use common 18px wall clearance")
				equal(layer.base_world.obstacle_view().size(), 0, "derived surface never mutates worldbone")
	reaction.health = 0
	equal(_layer(reaction, 23).obstacle_view().size(), 0, "destroyed cover has no movement surface immediately")

func _test_escape_and_reentry() -> void:
	for hurtbox: int in [17_000, 18_000, 19_000]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var reaction := _reaction()
			var layer := _layer(reaction, 22)
			var inside := CENTER + Vector2i(30_000, 0) # Clearance overlaps, center already outside.
			layer.begin_actor(inside, MovementTuning.PLAYER_RADIUS)
			var step := ElementChemistrySystem.scaled(direction, 140_000)
			var escaped := layer.move_box(inside, step, MovementTuning.PLAYER_RADIUS)
			check(escaped.position == inside + step, "size%d direction%s escapes newly overlapping Rampart without ejection" % [hurtbox, direction])
			layer.begin_actor(escaped.position, MovementTuning.PLAYER_RADIUS)
			var returned := layer.move_box(escaped.position, -step, MovementTuning.PLAYER_RADIUS)
			check(returned.position != inside, "size%d direction%s cannot re-enter once clear" % [hurtbox, direction])
	var first := _reaction()
	var second := _reaction()
	second.entity_id += 1
	second.position_x += 20_000
	var base := CollisionWorld.new(2_000_000, 1_500_000)
	base.add_obstacle(CollisionWorld.Obstacle.new(7, CENTER.x - 45_000, CENTER.y - 100_000, CENTER.x - 35_000, CENTER.y + 100_000))
	var layer := ReactionMovementWorld.new(base)
	layer.set_surfaces(ReactionMovementWorld.capture_surfaces([first, second], 22), 22)
	layer.begin_actor(CENTER, MovementTuning.PLAYER_RADIUS)
	var escape := layer.move_box(CENTER, Vector2i(160_000, 0), MovementTuning.PLAYER_RADIUS)
	equal(escape.position, CENTER + Vector2i(160_000, 0), "two overlapping Ramparts permit escape beside static wall")
	var wall := layer.move_box(CENTER, Vector2i(-160_000, 0), MovementTuning.PLAYER_RADIUS)
	equal(wall.wall_id, 7, "formation escape never disables static wall collision")

func _test_wall_actions_and_expiry() -> void:
	var reaction := _reaction()
	var state := _state()
	state.position_x = CENTER.x - 40_500
	state.position_y = CENTER.y - 10_000
	# Exercise an airborne wall kick, not a ground-height run followed by a
	# normal first jump (which intentionally retains hop stage one).
	state.air_height = 12_000
	state.hop_ticks = 40
	state.hop_stage = 1
	var config := SimConfig.new()
	var layer := _layer(reaction, 22, state)
	MovementSystem.step(state, SimCommand.new(22, 2, 0, 1000, 0, SimCommand.PRESSED_TECHNIQUE), config, layer)
	check(state.wall_skim_ticks > 0, "active Rampart accepts existing paid wallrun grammar")
	equal(state.wall_skim_surface_id, ReactionMovementWorld.SURFACE_ID_BASE + reaction.entity_id, "wallrun identity tracks finite reaction entity")
	var stamina_after_run := state.stamina
	state.movement_commitment_ticks = 0
	layer.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
	MovementSystem.step(state, SimCommand.new(23, 2, -1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP), config, layer)
	check(state.stamina < stamina_after_run, "wall jump from Rampart pays normal stamina cost")
	equal(state.hop_stage, 2, "Rampart wall jump consumes existing air wall-kick budget")
	state.wall_contact_id = ReactionMovementWorld.SURFACE_ID_BASE + reaction.entity_id
	state.wall_memory_ticks = 30
	state.wall_x = -1000
	state.air_dodge_used = true
	state.float_used = true
	state.air_redirects_remaining = 0
	state.jump_protection_ticks = 0
	var stamina := state.stamina
	layer.set_surfaces(ReactionMovementWorld.capture_surfaces([reaction], 397), 397)
	layer.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
	ReactionMovementWorld.clear_stale_contact(state, layer)
	equal(state.wall_contact_id, 0, "expired Rampart clears wall contact before buffered action")
	equal(state.wall_memory_ticks, 0, "expired Rampart cannot buy ghost wall kick with coyote memory")
	equal(state.stamina, stamina, "surface cleanup never refunds stamina")
	check(state.air_dodge_used and state.float_used and state.air_redirects_remaining == 0 and state.jump_protection_ticks == 0, "surface cleanup never renews air or protection budgets")

func _test_prediction_and_validation() -> void:
	var reaction := _reaction()
	var state := _state()
	var base := CollisionWorld.new(2_000_000, 1_500_000)
	var prediction := ClientPrediction.new()
	check(prediction.configure(SimConfig.new(), base, 2), "surface prediction configures")
	var packet := ClientPrediction.capture_packet(state, 21, -1, [reaction])
	check(ClientPrediction.validate_packet(packet), "future active surface rows validate")
	var missing := packet.duplicate(true)
	missing.erase("surfaces")
	check(not ClientPrediction.validate_packet(missing), "old reconciliation without surface contract fails closed")
	var bad := packet.duplicate(true)
	bad["surfaces"][3] += 1
	check(not ClientPrediction.validate_packet(bad), "untrusted movement rectangle dimensions rejected")
	check(prediction.reconcile(packet), "exact authority tick initializes future surface")
	var layer := ReactionMovementWorld.new(base)
	for tick: int in range(21, 61):
		var command := SimCommand.new(tick, 2, 1000, 0)
		layer.set_surfaces(ReactionMovementWorld.capture_surfaces([reaction], tick), tick)
		layer.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
		MovementSystem.step(state, command, SimConfig.new(), layer)
		check(prediction.queue_input(tick - 20, command), "prediction queues input through formation boundary")
		equal(Vector2i(prediction.predicted_state.position_x, prediction.predicted_state.position_y), Vector2i(state.position_x, state.position_y), "host/prediction agree across formation and wall contact")
	check(prediction.reconcile(ClientPrediction.capture_packet(state, 61, 40, [reaction])), "authority reconciles finite surface with no separate snapshot dependency")
	equal(prediction.last_correction_pixels, 0.0, "same live surface needs no prediction correction")
	# A new acknowledgement carries destruction without waiting for map channel.
	reaction.health = 0
	check(prediction.reconcile(ClientPrediction.capture_packet(state, 62, 40, [reaction])), "destruction replaces compact surface set")
	equal(prediction.reaction_surfaces.size(), 0, "destroyed surface vanishes from prediction immediately")
	var expiring := _reaction()
	var expiry_state := _state()
	expiry_state.position_x = CENTER.x - 40_500
	var expiry_prediction := ClientPrediction.new()
	check(expiry_prediction.configure(SimConfig.new(), base, 2), "expiry replay configures")
	check(expiry_prediction.reconcile(ClientPrediction.capture_packet(expiry_state, 396, -1, [expiring])), "last-active-tick packet initializes expiry replay")
	for tick: int in [396, 397, 398]:
		var command := SimCommand.new(tick, 2, 1000, 0)
		layer.set_surfaces(ReactionMovementWorld.capture_surfaces([expiring], tick), tick)
		layer.begin_actor(Vector2i(expiry_state.position_x, expiry_state.position_y), MovementTuning.PLAYER_RADIUS)
		ReactionMovementWorld.clear_stale_contact(expiry_state, layer)
		MovementSystem.step(expiry_state, command, SimConfig.new(), layer)
		check(expiry_prediction.queue_input(tick - 395, command), "pending input advances past surface expiry")
		equal(expiry_prediction.predicted_state.position_x, expiry_state.position_x, "prediction releases expired wall at exact tick without new snapshot")
	check(expiry_state.position_x > CENTER.x - 40_500, "expiry replay permits movement through former footprint")
	var maximum: Array = []
	for index: int in range(32):
		var item := _reaction()
		item.entity_id += index
		maximum.append(item)
	var max_packet := ClientPrediction.capture_packet(state, 22, 40, maximum)
	check(var_to_bytes({"kind": SessionTransport.PACKET_RECONCILIATION, "reconciliation": max_packet}).size() <= SessionTransport.MAX_PACKET_BYTES, "all32 compact surfaces fit existing transport packet limit")
	var excessive: PackedInt32Array = max_packet["surfaces"].duplicate()
	excessive.append_array(excessive.slice(0, 7))
	check(not ReactionMovementWorld.validate_surfaces(excessive, 22), "more than32 surfaces rejected")

func _test_world_and_attack_integration() -> void:
	var reaction := _reaction()
	var world := SimWorld.new(120, 1, CollisionWorld.new(2_000_000, 1_500_000))
	world.tick = 22
	world.reactions.append(reaction)
	var player := world.player()
	player.position_x = CENTER.x - 40_500
	player.position_y = CENTER.y
	for index: int in range(12):
		check(world.step([SimCommand.new(world.tick, 1, 1000, 0)]), "production world advances with Rampart")
	equal(player.position_x, CENTER.x - 40_500, "production host uses derived blocking surface")
	var hit := ElementChemistrySystem.ray_interaction(CENTER - Vector2i(100_000, 0), CENTER + Vector2i(100_000, 0), 2, 32_000, [reaction], world.tick)
	check(hit.blocked, "existing ray damage breaks active Rampart")
	equal(reaction.health, 0, "breakable cover keeps finite health budget")
	check(world.step([SimCommand.new(world.tick, 1, 1000, 0)]), "host advances after destruction")
	check(player.position_x > CENTER.x - 40_500, "next authoritative tick releases destroyed wall clearance")

func _test_maximum_enet_delivery() -> void:
	var host := SessionTransport.new()
	var guest := SessionTransport.new()
	var signature := SessionTransport.compatibility_signature(SimConfig.PROTOCOL_VERSION, 120, "rampart-mtu-test", "a".repeat(64), "b".repeat(64), SessionCharter.catalog_hash(), CanonicalContent.sha256(ElementChemistrySystem.movement_surface_policy()))
	check(host.start_host(0, signature, "Rampart Host"), "maximum surface ENet host binds ephemeral port")
	check(guest.start_join("127.0.0.1", host.bound_port, signature, "Rampart Guest"), "maximum surface ENet guest begins guarded join")
	check(_poll_until(host, guest, func() -> bool: return guest.is_connected_client()), "maximum surface ENet HELLO accepted")
	if not guest.is_connected_client():
		guest.stop()
		host.stop()
		return
	# Production clients cannot accept reconciliation until one complete world
	# envelope establishes the host epoch. This transport-focused fixture has no
	# session world, so establish that already-accepted epoch explicitly.
	check(guest.configure_world_epoch(host.world_epoch), "maximum surface guest establishes the initial host world epoch")
	equal(guest.world_epoch, 0, "maximum surface reconciliation runs in initial epoch zero")
	var state := _state()
	var reactions: Array = []
	for index: int in range(32):
		var item := _reaction()
		item.entity_id += index
		# First wall is in the traveller's path; remaining walls vary position
		# and direction to avoid measuring an unrealistically repetitive packet.
		if index > 0:
			item.position_x += index * 173_291
			item.position_y += index * 121_357
			item.direction_x = 0 if index % 2 == 0 else 1000
			item.direction_y = 1000 if index % 2 == 0 else 0
		reactions.append(item)
	var packet := ClientPrediction.capture_packet(state, 22, -1, reactions)
	var encoded_bytes := var_to_bytes({"kind": SessionTransport.PACKET_RECONCILIATION, "reconciliation": packet}).size()
	print("RAMPART ENET: surfaces=32 encoded_bytes=%d mtu=%d message_bound=%d" % [encoded_bytes, SessionTransport.ENET_MTU_BYTES, SessionTransport.MAX_PACKET_BYTES])
	check(encoded_bytes > SessionTransport.ENET_MTU_BYTES and encoded_bytes <= SessionTransport.MAX_PACKET_BYTES, "worst-case authority is bounded but intentionally crosses single-MTU threshold")
	var wire_packets := SessionTransport._snapshot_wire_packets(packet, true)
	check(not wire_packets.is_empty(), "maximum surface authority gets bounded compressed wire packets")
	for wire_packet: Dictionary in wire_packets:
		var wire_bytes := var_to_bytes(wire_packet).size()
		print("RAMPART ENET WIRE: datagram_bytes=%d" % wire_bytes)
		check(wire_bytes <= SessionTransport.ENET_MTU_BYTES, "every actual reconciliation datagram fits MTU")
	check(host.send_reconciliation(guest.local_peer_id, packet), "host sends actual32-surface reconciliation using production channel")
	check(_poll_until(host, guest, func() -> bool: return not guest.incoming_reconciliations.is_empty()), "actual ENet reassembles maximum reconciliation")
	var received := guest.take_reconciliations()
	equal(received.size(), 1, "maximum reconciliation arrives as one complete message")
	if not received.is_empty():
		equal(received[0], packet, "every state value and all32 surface rows survive actual ENet")
		var base := CollisionWorld.new(10_000_000, 10_000_000)
		var prediction := ClientPrediction.new()
		check(prediction.configure(SimConfig.new(), base, 2), "network surface replay configures")
		check(prediction.reconcile(received[0]), "client accepts actual received maximum authority")
		var layer := ReactionMovementWorld.new(base)
		for tick: int in range(22, 46):
			var command := SimCommand.new(tick, 2, 1000, 0)
			layer.set_surfaces(ReactionMovementWorld.capture_surfaces(reactions, tick), tick)
			layer.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
			MovementSystem.step(state, command, SimConfig.new(), layer)
			check(prediction.queue_input(tick - 21, command), "received surface packet replays pending movement")
			equal(prediction.predicted_state.position_x, state.position_x, "network32-surface prediction matches authoritative movement")
		for item: ElementReactionState in reactions:
			item.health = 0
		var cleared := ClientPrediction.capture_packet(state, 46, 24, reactions)
		check(host.send_reconciliation(guest.local_peer_id, cleared), "host sends destruction after large reconciliation")
		check(_poll_until(host, guest, func() -> bool: return not guest.incoming_reconciliations.is_empty()), "newer small authority follows fragmented message")
		var removed := guest.take_reconciliations()
		check(not removed.is_empty() and prediction.reconcile(removed.back()), "received destruction reconciles without stale large message")
		equal(prediction.reaction_surfaces.size(), 0, "received destruction releases all movement surfaces")
		# Exercise the bounded codec fallback, independently from how well the
		# current state happens to compress. Padding is test-only, ignored by
		# movement validation, deterministic and below the existing raw bound.
		var fragmented := cleared.duplicate(true)
		fragmented["tick"] = 47
		var random := RandomNumberGenerator.new()
		random.seed = 91731
		var entropy := PackedByteArray()
		for _index: int in range(4096):
			entropy.append(random.randi() & 255)
		fragmented["_transport_probe_entropy"] = entropy
		var fragments := SessionTransport._snapshot_wire_packets(fragmented, true)
		check(fragments.size() > 1, "synthetic incompressible authority forces bounded fragment fallback")
		for fragment: Dictionary in fragments:
			check(var_to_bytes(fragment).size() <= SessionTransport.ENET_MTU_BYTES, "fallback fragment fits oneMTU")
		check(host.send_reconciliation(guest.local_peer_id, fragmented), "production channel sends forced multiMTU fallback")
		check(_poll_until(host, guest, func() -> bool: return not guest.incoming_reconciliations.is_empty()), "actual ENet receives forced fallback without warning or reliable HOL")
		var fallback_received := guest.take_reconciliations()
		check(not fallback_received.is_empty() and fallback_received.back() == fragmented, "fallback reassembles exactly once and atomically")
		var assembly := SessionTransport.new()
		assembly.local_entity_id = 2
		for index: int in range(fragments.size() - 1, 0, -1):
			check(assembly._snapshot_from_fragment(fragments[index], true).is_empty(), "reordered incomplete fragments never publish partial movement")
		var complete := assembly._snapshot_from_fragment(fragments[0], true)
		equal(complete, fragmented, "out-of-order fallback resolves exact packet after missing first fragment")
		assembly._accept_reconciliation(complete)
		check(assembly._snapshot_from_fragment(fragments[0], true).is_empty(), "late duplicate fragment cannot resurrect accepted authority")
		var newer := cleared.duplicate(true)
		newer["tick"] = 48
		assembly._accept_reconciliation(newer)
		equal(assembly.incoming_reconciliations.back()["tick"], 48, "newer complete authority is never blocked by an incomplete older frame")
		var oversized := fragments[0].duplicate(true)
		oversized["raw_size"] = SessionTransport.MAX_PACKET_BYTES + 1
		check(assembly._snapshot_from_fragment(oversized, true).is_empty(), "oversized decompression request fails closed")
	guest.stop()
	host.stop()
	check(not host.is_online() and not guest.is_online(), "maximum surface ENet peers close cleanly")

func _poll_until(host: SessionTransport, guest: SessionTransport, predicate: Callable) -> bool:
	for _index: int in range(2000):
		host.poll()
		guest.poll()
		if predicate.call():
			return true
		OS.delay_msec(1)
	return false

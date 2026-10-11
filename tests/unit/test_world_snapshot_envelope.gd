extends FluxTestSuite


const Envelope = preload("res://src/net/world_snapshot_envelope.gd")
const Transport = preload("res://src/net/session_transport.gd")
const HexSnapshot = preload("res://src/net/hex_world_snapshot.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"


func run() -> int:
	_test_legacy_envelope_and_adapter()
	_test_hex_envelope_and_exact_session()
	_test_fragment_epoch_ordering_and_reset()
	_test_input_request_and_reconciliation_epochs()
	return finish("world-snapshot-envelope")


func _test_legacy_envelope_and_adapter() -> void:
	var snapshot: Dictionary = _legacy_snapshot(7, 1)
	var envelope: Dictionary = Envelope.wrap_legacy(snapshot, 0)
	check(Envelope.validate(envelope), "legacy authority wraps in one exact schema-one envelope")
	equal(int(envelope.tick), 7, "legacy authority tick is copied into the outer ordering tuple")
	check((envelope.session as Dictionary).is_empty(), "legacy authority does not duplicate its embedded session lanes")
	equal(Envelope.authority(envelope), snapshot, "legacy authority accessor returns the exact validated payload")
	equal(Envelope.names(envelope), [[1, "Envelope Host", "spawn"]], "common names accessor derives legacy identity and last-event rows")
	equal(Envelope.events(envelope), snapshot.events, "common events accessor derives the legacy encoded lane")
	equal(Envelope.hearth(envelope), snapshot.hearth, "common Hearth accessor derives the legacy encoded lane")
	equal(Envelope.round_state(envelope), snapshot.round, "common round accessor derives the legacy encoded lane")
	equal(Envelope.overflow(envelope), snapshot.overflow, "common overflow accessor derives the legacy encoded lane")
	check(Envelope.byte_size(envelope) > 0 and Envelope.byte_size(envelope) <= Transport.MAX_SNAPSHOT_UNCOMPRESSED_BYTES, "whole legacy envelope fits the unchanged raw bound")

	for mutation: Callable in [
		func(value: Dictionary) -> void: value.tick = 8,
		func(value: Dictionary) -> void: value.world_epoch = -1,
		func(value: Dictionary) -> void: value.session = {"names": []},
		func(value: Dictionary) -> void: value.extra = 1,
	]:
		var malformed: Dictionary = envelope.duplicate(true)
		mutation.call(malformed)
		check(not Envelope.validate(malformed), "legacy envelope rejects mismatched, negative, nonempty-session, and extra fields")
	var oversized_authority: Dictionary = snapshot.duplicate(true)
	var padding := PackedByteArray()
	padding.resize(Envelope.MAX_RAW_BYTES)
	oversized_authority._envelope_probe = padding
	check(SessionSnapshot.validate(oversized_authority), "outer-bound fixture remains valid under the existing legacy authority validator")
	check(Envelope.wrap_legacy(oversized_authority, 0).is_empty(), "whole-envelope guard rejects authority whose wrapper exceeds32768 bytes")

	var packets: Array[Dictionary] = Transport._snapshot_wire_packets(snapshot)
	check(not packets.is_empty(), "legacy direct snapshot API remains an automatic epoch-zero adapter")
	var receiver := Transport.new()
	receiver.mode = Transport.Mode.CLIENT
	for packet: Dictionary in packets:
		check(typeof(packet.get("world_epoch")) == TYPE_INT and int(packet.world_epoch) == 0, "every legacy wire packet carries explicit epoch zero")
		receiver._handle_packet(Transport.SERVER_PEER_ID, var_to_bytes(packet))
	var received: Array[Dictionary] = receiver.take_snapshots()
	check(received.size() == 1 and received[0] == snapshot, "legacy take_snapshots compatibility unwraps one exact authority payload")
	var received_envelopes: Array[Dictionary] = receiver.poll_envelopes()
	check(received_envelopes.size() == 1 and received_envelopes[0] == envelope, "new envelope polling sees the same complete legacy authority")


func _test_hex_envelope_and_exact_session() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "hex envelope fixture loads the production ability catalog")
	if not catalog.last_error.is_empty():
		return
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, catalog, false), "hex envelope fixture configures trusted court authority")
	var authority_value: Dictionary = HexSnapshot.capture(world)
	check(not authority_value.is_empty(), "hex world snapshot captures complete resumable authority")
	if authority_value.is_empty():
		return
	var session: Dictionary = _hex_session(world)
	var envelope: Dictionary = Envelope.wrap_hex(authority_value, session, 6)
	check(Envelope.validate(envelope), "hex authority and exact five-lane session wrap together")
	equal(int(envelope.tick), int((authority_value.header as PackedInt64Array)[1]), "hex outer tick equals the authoritative header tick")
	equal(Envelope.names(envelope), session.names, "validated names and last-event rows round-trip")
	equal(Envelope.events(envelope), session.events, "encoded event lane round-trips without reinterpretation")
	equal(Envelope.hearth(envelope), session.hearth, "Hearth lane round-trips without reinterpretation")
	equal(Envelope.round_state(envelope), session.round, "round lane round-trips without reinterpretation")
	equal(Envelope.overflow(envelope), session.overflow, "overflow lane round-trips without reinterpretation")

	var malformed: Dictionary = envelope.duplicate(true)
	malformed.tick = int(envelope.tick) + 1
	check(not Envelope.validate(malformed), "hex outer tick cannot disagree with authority header")
	malformed = envelope.duplicate(true)
	malformed.session.names[0][0] = 2
	check(not Envelope.validate(malformed), "hex name identity must match the ordered champion authority")
	malformed = envelope.duplicate(true)
	malformed.session.extra = PackedInt32Array()
	check(not Envelope.validate(malformed), "hex session dictionary rejects undeclared lanes")
	malformed = envelope.duplicate(true)
	malformed.authority.epoch = 1
	check(not Envelope.validate(malformed), "inner hex epoch remains reserved while the outer envelope owns reset epochs")


func _test_fragment_epoch_ordering_and_reset() -> void:
	equal(Transport.SNAPSHOT_FRAGMENT_PAYLOAD_BYTES, 1152, "epoch headers retain the established fragment payload cap")
	equal(Transport.MAX_SNAPSHOT_FRAGMENTS, 64, "expanded snapshots retain an explicit64-fragment admission cap")
	equal(Transport.ENET_MTU_BYTES, 1392, "expanded state does not enlarge the actual datagram MTU")
	equal(Transport.MAX_SNAPSHOT_UNCOMPRESSED_BYTES, 65536, "expanded state retains the original raw snapshot allocation bound")
	equal(Transport.MAX_PENDING_SNAPSHOT_ASSEMBLIES, 3, "epoch transport retains the established assembly cap")
	equal(Transport.MAX_QUEUED_SNAPSHOTS, 2, "epoch transport retains the established complete-snapshot queue cap")
	var current_snapshot: Dictionary = _legacy_snapshot(10, 80)
	var current_envelope: Dictionary = Envelope.wrap_legacy(current_snapshot, 3)
	var current_packets: Array[Dictionary] = Transport._snapshot_wire_packets(current_envelope)
	check(current_packets.size() > 1 and current_packets.size() <= Transport.MAX_SNAPSHOT_FRAGMENTS, "dense envelope uses the existing bounded fragment path")
	if current_packets.size() < 2:
		return
	var receiver := Transport.new()
	receiver.mode = Transport.Mode.CLIENT
	check(receiver.configure_world_epoch(3), "receiver installs the trusted initial epoch")
	current_packets.reverse()
	for packet: Dictionary in current_packets:
		receiver._handle_packet(Transport.SERVER_PEER_ID, var_to_bytes(packet))
	var accepted: Array[Dictionary] = receiver.poll_envelopes()
	check(accepted.size() == 1 and accepted[0] == current_envelope, "reordered fragments reconstruct one exact epoch/tick tuple")

	var future_snapshot: Dictionary = _legacy_snapshot(5, 80)
	var future_envelope: Dictionary = Envelope.wrap_legacy(future_snapshot, 4)
	var future_packets: Array[Dictionary] = Transport._snapshot_wire_packets(future_envelope)
	receiver._handle_packet(Transport.SERVER_PEER_ID, var_to_bytes(future_packets[0]))
	equal(receiver.world_epoch, 3, "one future fragment cannot advance the accepted world epoch")
	equal(receiver.poll_envelopes().size(), 0, "one future fragment exposes no partial authority")
	check(receiver._snapshot_assemblies.size() == 1, "future partial authority occupies one bounded assembly")
	check(receiver.configure_world_epoch(3), "reconfiguring the identical epoch is a no-op")
	equal(receiver._snapshot_assemblies.size(), 1, "same-epoch configuration does not discard useful fragment progress")

	var next_current: Dictionary = Envelope.wrap_legacy(_legacy_snapshot(11, 80), 3)
	for packet: Dictionary in Transport._snapshot_wire_packets(next_current):
		receiver._handle_packet(Transport.SERVER_PEER_ID, var_to_bytes(packet))
	equal(receiver.world_epoch, 3, "newer current-epoch authority remains acceptable while a future frame is incomplete")
	for index: int in range(1, future_packets.size()):
		receiver._handle_packet(Transport.SERVER_PEER_ID, var_to_bytes(future_packets[index]))
	equal(receiver.world_epoch, 4, "only the complete future envelope advances world epoch")
	accepted = receiver.poll_envelopes()
	check(accepted.size() == 1 and accepted[0] == future_envelope, "higher complete tuple purges older queued authority")
	equal(receiver._snapshot_assemblies.size(), 0, "higher complete tuple purges superseded assemblies")

	var lost_epoch_five: Array[Dictionary] = Transport._snapshot_wire_packets(Envelope.wrap_legacy(_legacy_snapshot(1, 80), 5))
	receiver._handle_packet(Transport.SERVER_PEER_ID, var_to_bytes(lost_epoch_five[0]))
	check(receiver._snapshot_assemblies.size() == 1 and receiver.world_epoch == 4, "lost future fragment remains partial and does not reset authority")
	check(receiver.configure_world_epoch(5), "explicit trusted reset installs a newer epoch")
	equal(receiver._snapshot_assemblies.size(), 0, "changed epoch configuration clears stale partial assemblies")
	equal(receiver._last_snapshot_tick, -1, "changed epoch resets the monotonic tick cursor")


func _test_input_request_and_reconciliation_epochs() -> void:
	var host := Transport.new()
	host.mode = Transport.Mode.HOSTING
	host.accepted_peer_ids = PackedInt32Array([2])
	host.entity_by_peer[2] = 2
	host.configure_world_epoch(9)
	var input := {
		"kind": Transport.PACKET_INPUT, "world_epoch": 8, "sequence": 0,
		"move_x": 0, "move_y": 0, "held": 0, "pressed": 0,
		"aim_x": 0, "aim_y": -1000,
	}
	host._handle_packet(2, var_to_bytes(input))
	equal(host.take_inputs().size(), 0, "host drops an otherwise valid input from the wrong epoch")
	input.erase("world_epoch")
	host._handle_packet(2, var_to_bytes(input))
	equal(host.take_inputs().size(), 0, "actual wire input requires an explicit epoch")
	input.world_epoch = 9
	host._handle_packet(2, var_to_bytes(input))
	var accepted_inputs: Array[Dictionary] = host.take_inputs()
	check(accepted_inputs.size() == 1 and int(accepted_inputs[0].world_epoch) == 9, "matching input retains trusted epoch stamping")
	var request := {"kind": Transport.PACKET_REQUEST, "world_epoch": 8, "sequence": 0, "action": Transport.REQUEST_EMOTE, "value": 0}
	host._handle_packet(2, var_to_bytes(request))
	equal(host.take_requests().size(), 0, "host drops an otherwise valid request from the wrong epoch")
	request.world_epoch = 9
	host._handle_packet(2, var_to_bytes(request))
	var accepted_requests: Array[Dictionary] = host.take_requests()
	check(accepted_requests.size() == 1 and int(accepted_requests[0].world_epoch) == 9, "matching request retains trusted epoch stamping")

	var receiver := Transport.new()
	receiver.mode = Transport.Mode.CLIENT
	receiver.local_entity_id = 2
	receiver.configure_world_epoch(9)
	var state := PlayerState.new(2)
	var reconciliation: Dictionary = ClientPrediction.capture_packet(state, 4, 0)
	var packets: Array[Dictionary] = Transport._snapshot_wire_packets(reconciliation, true, 9)
	check(not packets.is_empty(), "valid reconciliation packs through the shared codec path")
	for packet: Dictionary in packets:
		equal(int(packet.world_epoch), 9, "every reconciliation packet carries the host current epoch")
		receiver._handle_packet(Transport.SERVER_PEER_ID, var_to_bytes(packet))
	equal(receiver.take_reconciliations().size(), 1, "accepted-epoch reconciliation is delivered")
	for packet: Dictionary in Transport._snapshot_wire_packets(ClientPrediction.capture_packet(state, 5, 1), true, 10):
		receiver._handle_packet(Transport.SERVER_PEER_ID, var_to_bytes(packet))
	equal(receiver.take_reconciliations().size(), 0, "future reconciliation cannot precede accepted future world authority")
	equal(receiver._reconciliation_assemblies.size(), 0, "wrong-epoch reconciliation allocates no fragment state")


func _legacy_snapshot(tick: int, projectile_count: int) -> Dictionary:
	var world := SimWorld.new(120, 71, CollisionWorld.new(20_000_000, 20_000_000))
	world.player().champion_wire_id = 1
	world.tick = tick
	for index: int in projectile_count:
		world.projectiles.append(ProjectileState.new(
			1000 + index, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 3,
			Vector2i(500_000 + index * 7919, 500_000 + index * 6151),
			Vector2i(480_000 - index * 187, index * 157), 12_000, 9_000, 90 + index,
		))
	return SessionSnapshot.capture(world, {1: "Envelope Host"})


func _hex_session(world: SimWorld) -> Dictionary:
	var hearth_state := SessionHearth.new()
	hearth_state.bind_host()
	var round_state := SessionRound.new()
	round_state.bind_hearth()
	return Envelope.make_hex_session(
		[[1, "Envelope Host", "spawn"]],
		[],
		hearth_state.capture(world.tick, SessionSnapshot.MAX_PLAYERS),
		round_state.capture(world),
		PackedInt32Array([0, 0, 0, 0]),
	)

extends "res://tests/unit/test_hex_world_snapshot.gd"
## Exact outbound bytes/call-count tests. Native ENet delivery is covered by the
## existing session-transport, unified-enet and admin-close-delivery suites.

const Transport = preload("res://src/net/session_transport.gd")
const Envelope = preload("res://src/net/world_snapshot_envelope.gd")


class RecordingTransport:
	extends SessionTransport
	var encode_calls: int = 0
	var sent: Array[Dictionary] = []
	var fail_calls: Array[int] = []
	var mutate_sink_argument: bool = false

	func _encode_outgoing_packet(packet: Dictionary) -> PackedByteArray:
		encode_calls += 1
		return super._encode_outgoing_packet(packet)

	# Replace only physical delivery for fanout tests. Real lifecycle/size guards
	# are exercised separately on the production transport below.
	func _send_encoded_to(target_peer_id: int, encoded: PackedByteArray, transfer_mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE, transfer_channel: int = 0) -> bool:
		return _record_packet(target_peer_id, encoded, transfer_mode, transfer_channel)

	func _record_packet(target_peer_id: int, encoded: PackedByteArray, transfer_mode: int, transfer_channel: int) -> bool:
		if encoded.is_empty() or encoded.size() > MAX_PACKET_BYTES:
			return false
		var call_index: int = sent.size()
		sent.append({"peer": target_peer_id, "bytes": encoded.duplicate(), "mode": transfer_mode, "channel": transfer_channel})
		if mutate_sink_argument:
			encoded[0] = encoded[0] ^ 0xff
		return not fail_calls.has(call_index)


class PreBroadcastTransport:
	extends RecordingTransport
	# Frozen predecessor broadcast. _wire_packets and envelope validation are
	# shared unchanged dependencies; this oracle targets fanout serialization.
	func broadcast_envelope(envelope: Dictionary) -> bool:
		if not is_host() or not WorldSnapshotEnvelope.validate(envelope) or int(envelope.world_epoch) != world_epoch:
			return false
		var packets: Array[Dictionary] = _wire_packets(envelope, false, int(envelope.world_epoch), int(envelope.tick))
		if packets.is_empty():
			return false
		var all_sent: bool = true
		for peer_id: int in accepted_peer_ids:
			for packet: Dictionary in packets:
				all_sent = _send_to(peer_id, packet, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, SNAPSHOT_CHANNEL) and all_sent
		return all_sent

	# Frozen predecessor _send_to through its byte bound; the final four native
	# ENet statements are replaced by the same byte sink used by the candidate.
	func _send_to(target_peer_id: int, packet: Dictionary, transfer_mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE, transfer_channel: int = 0) -> bool:
		if peer == null:
			return false
		if mode in [Mode.CONNECTING, Mode.CLIENT] and _server_disconnect_pending:
			return false
		if mode == Mode.CLIENT and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return false
		var encoded: PackedByteArray = var_to_bytes(packet)
		encode_calls += 1
		if encoded.is_empty() or encoded.size() > MAX_PACKET_BYTES:
			return false
		return _record_packet(target_peer_id, encoded, transfer_mode, transfer_channel)


class BoundaryEncoder:
	extends SessionTransport
	var encode_calls: int = 0
	var action: String = ""

	func _encode_outgoing_packet(packet: Dictionary) -> PackedByteArray:
		encode_calls += 1
		var result: PackedByteArray = super._encode_outgoing_packet(packet)
		match action:
			"clear-peer": peer = null
			"pending-close": _server_disconnect_pending = true
			"empty": return PackedByteArray()
			"oversize": result.resize(MAX_PACKET_BYTES + 1)
		return result


class SendOverrideTransport:
	extends RecordingTransport
	var send_override_calls: int = 0

	func _send_to(target_peer_id: int, packet: Dictionary, transfer_mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE, transfer_channel: int = 0) -> bool:
		send_override_calls += 1
		return super._send_to(target_peer_id, packet, transfer_mode, transfer_channel)


func run() -> int:
	_test_legacy_fanout()
	_test_fragmented_hex_fanout()
	_test_rejected_broadcasts()
	_test_subclass_send_override_preserved()
	_test_real_send_boundary()
	return finish("session-broadcast-bytes")


func _host(transport: SessionTransport, peers: PackedInt32Array = PackedInt32Array([2, 3, 4, 5, 6, 7, 8])) -> void:
	transport.mode = Transport.Mode.HOSTING
	# Unbound native peer only satisfies the predecessor null check. The byte
	# sink never invokes put_packet, opens a socket or starts a handshake.
	transport.peer = ENetMultiplayerPeer.new()
	transport.accepted_peer_ids = peers
	check(transport.configure_world_epoch(7), "fanout fixture installs its trusted epoch")


func _legacy_envelope(projectile_count: int = 0) -> Dictionary:
	var world := SimWorld.new(120, 71, CollisionWorld.new(20_000_000, 20_000_000))
	world.player().champion_wire_id = 1
	world.tick = 100
	for index: int in projectile_count:
		world.projectiles.append(ProjectileState.new(
			1000 + index, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 3,
			Vector2i(500_000 + index * 7919, 500_000 + index * 6151),
			Vector2i(480_000 - index * 187, index * 157), 12_000, 9_000, 90 + index,
		))
	return Envelope.wrap_legacy(SessionSnapshot.capture(world, {1: "Fanout Host"}), 7)


func _assert_fanout(envelope: Dictionary, peers: PackedInt32Array, label: String, failures: Array[int] = []) -> void:
	var packets: Array[Dictionary] = Transport._envelope_wire_packets(envelope)
	check(not packets.is_empty(), label + " supplies complete valid wire packets")
	if packets.is_empty(): return
	var before: PackedByteArray = var_to_bytes(envelope)
	var candidate := RecordingTransport.new()
	var predecessor := PreBroadcastTransport.new()
	_host(candidate, peers)
	_host(predecessor, peers)
	candidate.fail_calls = failures.duplicate()
	predecessor.fail_calls = failures.duplicate()
	var expected: bool = predecessor.broadcast_envelope(envelope)
	# Explicit diagnostic invocation, not a spoofed concrete transport. The
	# public production method only chooses this path for its exact own script.
	var actual: bool = candidate._broadcast_encoded_packets(packets)
	equal(actual, expected, label + " retains predecessor aggregate success/refusal")
	equal(actual, failures.is_empty(), label + " reports every injected send failure")
	equal(candidate.sent, predecessor.sent, label + " preserves exact bytes, recipient order, mode and channel")
	equal(candidate.encode_calls, 0 if peers.is_empty() else packets.size(), label + " encodes each packet once before fanout")
	equal(predecessor.encode_calls, peers.size() * packets.size(), label + " frozen predecessor encodes once per recipient and packet")
	equal(candidate.sent.size(), peers.size() * packets.size(), label + " attempts every recipient packet even after failure")
	equal(var_to_bytes(envelope), before, label + " cannot mutate caller authority")
	var index: int = 0
	for peer_id: int in peers:
		for packet: Dictionary in packets:
			var row: Dictionary = candidate.sent[index]
			equal(int(row.peer), peer_id, label + " preserves accepted-peer iteration order")
			equal(row.bytes, var_to_bytes(packet), label + " uses the original exact Variant encoding")
			equal(int(row.mode), MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, label + " retains unreliable snapshot delivery")
			equal(int(row.channel), Transport.SNAPSHOT_CHANNEL, label + " retains the snapshot channel")
			check((row.bytes as PackedByteArray).size() <= Transport.ENET_MTU_BYTES, label + " preserves the existing per-packet MTU")
			index += 1
	# Actual receiving transport must reconstruct exactly the original envelope.
	if not peers.is_empty():
		var receiver := Transport.new()
		receiver.mode = Transport.Mode.CLIENT
		receiver.configure_world_epoch(7)
		for packet_index: int in packets.size():
			receiver._handle_packet(Transport.SERVER_PEER_ID, candidate.sent[packet_index].bytes)
		var received: Array[Dictionary] = receiver.poll_envelopes()
		check(received.size() == 1, label + " reconstructs one complete frame on the unchanged receiver")
		if received.size() == 1:
			equal(var_to_bytes(received[0]), before, label + " receiver reconstructs exact envelope bytes")


func _test_legacy_fanout() -> void:
	var small: Dictionary = _legacy_envelope()
	var dense: Dictionary = _legacy_envelope(80)
	equal(Transport._envelope_wire_packets(small).size(), 1, "small legacy control uses one packet")
	check(Transport._envelope_wire_packets(dense).size() > 1, "dense legacy control exercises fragmentation")
	for peers: PackedInt32Array in [PackedInt32Array(), PackedInt32Array([2]), PackedInt32Array([8, 2, 7, 3, 6, 4, 5])]:
		_assert_fanout(small, peers, "single legacy / %d peers" % peers.size())
		_assert_fanout(dense, peers, "fragmented legacy / %d peers" % peers.size())
	_assert_fanout(dense, PackedInt32Array([2, 5, 8]), "partial failure continues fanout", [0, 2])


func _test_fragmented_hex_fanout() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "Hex fanout loads the production ability catalog")
	if not catalog.last_error.is_empty(): return
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, catalog, false), "Hex fanout configures the production paid practice fixture")
	var rich: Dictionary = _advance_to_rich_capture(world)
	check(not rich.is_empty(), "Hex fanout reaches real pending/flight/product authority using paid commands")
	if rich.is_empty(): return
	var names: Array = [[1, "Fanout Host", "spawn"]]
	var hearth := SessionHearth.new()
	hearth.bind_host()
	for entity_id: int in range(2, Transport.MAX_PLAYERS + 1):
		var actor := PlayerState.new(entity_id)
		actor.team_id = entity_id
		actor.position_x = 100_000 + entity_id * 20_003
		actor.position_y = 200_000 + entity_id * 17_009
		world.players.append(actor)
		names.append([entity_id, "Fanout Guest %d" % entity_id, "spawn"])
		hearth.connect_entity(entity_id)
	var authority: Dictionary = Snapshot.capture(world)
	check(not authority.is_empty(), "all eight complete actors retain the paid Hex authority")
	if authority.is_empty(): return
	var round_state := SessionRound.new()
	round_state.bind_hearth()
	var session: Dictionary = Envelope.make_hex_session(names, [], hearth.capture(world.tick, Transport.MAX_PLAYERS), round_state.capture(world), PackedInt32Array([0, 0, 0, 0]))
	var envelope: Dictionary = Envelope.wrap_hex(authority, session, 7)
	var packets: Array[Dictionary] = Transport._envelope_wire_packets(envelope)
	check(packets.size() > 1, "complete paid eight-actor Hex fixture requires multiple wire fragments")
	if packets.size() < 2: return
	_assert_fanout(envelope, PackedInt32Array([2, 3, 4, 5, 6, 7, 8]), "fragmented paid Hex seven-recipient fanout")
	_assert_fanout(envelope, PackedInt32Array([2, 5, 8]), "fragmented paid Hex partial failure", [0, packets.size()])


func _test_rejected_broadcasts() -> void:
	var valid: Dictionary = _legacy_envelope()
	for kind: String in ["not-host", "wrong-epoch", "invalid-envelope"]:
		var candidate := RecordingTransport.new()
		var predecessor := PreBroadcastTransport.new()
		_host(candidate)
		_host(predecessor)
		var envelope: Dictionary = valid.duplicate(true)
		match kind:
			"not-host":
				candidate.mode = Transport.Mode.OFFLINE
				predecessor.mode = Transport.Mode.OFFLINE
			"wrong-epoch": envelope.world_epoch = 8
			"invalid-envelope": envelope.schema = -1
		equal(candidate.broadcast_envelope(envelope), predecessor.broadcast_envelope(envelope), kind + " matches predecessor refusal")
		equal(candidate.encode_calls, 0, kind + " cannot encode fanout bytes")
		check(candidate.sent.is_empty(), kind + " cannot reach the byte sink")


func _test_real_send_boundary() -> void:
	var packet := {"kind": Transport.PACKET_INPUT, "sequence": 1}
	var encoded: PackedByteArray = var_to_bytes(packet)
	var transport := BoundaryEncoder.new()
	transport.mode = Transport.Mode.HOSTING
	check(not transport._send_to(2, packet), "public dictionary send still refuses a null peer")
	check(not transport._send_encoded_to(2, encoded), "reused-byte send independently refuses a null peer")
	equal(transport.encode_calls, 0, "public dictionary send retains its pre-encoding null guard")
	transport.peer = ENetMultiplayerPeer.new()
	for mode: int in [Transport.Mode.CONNECTING, Transport.Mode.CLIENT]:
		transport.mode = mode
		transport._server_disconnect_pending = true
		check(not transport._send_to(2, packet), "public send refuses a pending disconnect")
		check(not transport._send_encoded_to(2, encoded), "reused bytes do not bypass a pending disconnect")
	transport._server_disconnect_pending = false
	transport.mode = Transport.Mode.CLIENT
	check(not transport._send_to(2, packet), "public send refuses a disconnected client peer")
	check(not transport._send_encoded_to(2, encoded), "reused bytes refuse a disconnected client peer")
	equal(transport.encode_calls, 0, "all original connection guards precede dictionary encoding")
	transport.mode = Transport.Mode.HOSTING
	var oversized := PackedByteArray()
	oversized.resize(Transport.MAX_PACKET_BYTES + 1)
	check(not transport._send_encoded_to(2, PackedByteArray()), "raw-byte send rejects an empty packet before native delivery")
	check(not transport._send_encoded_to(2, oversized), "raw-byte send retains the 8192-byte maximum")
	for action: String in ["empty", "oversize", "clear-peer", "pending-close"]:
		var callback := BoundaryEncoder.new()
		callback.peer = ENetMultiplayerPeer.new()
		callback.mode = Transport.Mode.CONNECTING if action == "pending-close" else Transport.Mode.HOSTING
		callback.action = action
		check(not callback._send_to(2, packet), action + " after encoding still fails closed at the actual send boundary")
		equal(callback.encode_calls, 1, action + " fixture reaches exactly one dictionary encoding")


func _test_subclass_send_override_preserved() -> void:
	var envelope: Dictionary = _legacy_envelope(80)
	var packets: Array[Dictionary] = Transport._envelope_wire_packets(envelope)
	var extension := SendOverrideTransport.new()
	var predecessor := PreBroadcastTransport.new()
	_host(extension, PackedInt32Array([8, 2, 5]))
	_host(predecessor, PackedInt32Array([8, 2, 5]))
	# PackedByteArray arguments are reference-passed. A mutating extension must
	# keep the predecessor's fresh bytes per _send_to call via public fallback;
	# it is not eligible for the concrete native byte-reuse path.
	extension.mutate_sink_argument = true
	predecessor.mutate_sink_argument = true
	extension.fail_calls = [0]
	predecessor.fail_calls = [0]
	check(not extension.broadcast_envelope(envelope), "extension send override failure remains authoritative")
	check(not predecessor.broadcast_envelope(envelope), "frozen predecessor retains the injected extension failure")
	equal(extension.send_override_calls, 3 * packets.size(), "extension broadcast preserves every _send_to override invocation")
	equal(extension.encode_calls, 3 * packets.size(), "extension retains its original per-send encoding lifecycle")
	equal(extension.sent, predecessor.sent, "mutating extension fallback exactly matches predecessor bytes and fanout order")
	var index: int = 0
	for _peer_id: int in extension.accepted_peer_ids:
		for packet: Dictionary in packets:
			equal(extension.sent[index].bytes, var_to_bytes(packet), "mutating extension cannot affect bytes encoded for a later recipient")
			index += 1

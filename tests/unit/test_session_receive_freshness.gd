extends FluxTestSuite
## Admission-only comparison; no sockets, engine timing or production counters.

const Transport = preload("res://src/net/session_transport.gd")
const Envelope = preload("res://src/net/world_snapshot_envelope.gd")


class DecodeSpy:
	extends SessionTransport
	var snapshot_decodes: int = 0
	var reconciliation_decodes: int = 0

	func _decode_received_single_packet(packet: Dictionary, reconciliation: bool) -> Dictionary:
		if reconciliation:
			reconciliation_decodes += 1
		else:
			snapshot_decodes += 1
		return super._decode_received_single_packet(packet, reconciliation)


class PreFreshnessTransport:
	extends SessionTransport
	# Frozen predecessor client payload dispatch and both acceptance methods.
	# The public stateless decoders and fragment path are deliberately unchanged
	# production dependencies; this oracle covers admission/queues, not codecs.
	func _handle_packet(sender_id: int, packet_bytes: PackedByteArray) -> void:
		if packet_bytes.is_empty() or packet_bytes.size() > MAX_PACKET_BYTES:
			return
		var decoded: Variant = bytes_to_var(packet_bytes)
		if not decoded is Dictionary:
			return
		var packet: Dictionary = decoded
		if typeof(packet.get("kind")) != TYPE_INT:
			return
		if sender_id != SERVER_PEER_ID or mode != Mode.CLIENT:
			return
		var kind: int = int(packet.kind)
		if kind == PACKET_SNAPSHOT:
			_accept_envelope(_envelope_from_wire_packet(packet))
		elif kind == PACKET_SNAPSHOT_FRAGMENT:
			_accept_envelope(_envelope_from_fragment(packet))
		elif kind == PACKET_RECONCILIATION:
			_accept_reconciliation(_snapshot_from_wire_packet(packet, true), int(packet.get("world_epoch", -1)))
		elif kind == PACKET_RECONCILIATION_FRAGMENT:
			_accept_reconciliation(_snapshot_from_fragment(packet, true), int(packet.get("world_epoch", -1)))

	func _accept_envelope(envelope: Dictionary) -> void:
		if not WorldSnapshotEnvelope.validate(envelope):
			return
		var accepted_epoch: int = int(envelope.world_epoch)
		var accepted_tick: int = int(envelope.tick)
		if not _pair_after(accepted_epoch, accepted_tick, _last_snapshot_epoch, _last_snapshot_tick):
			return
		if world_epoch >= 0 and accepted_epoch < world_epoch:
			return
		var epoch_changed: bool = accepted_epoch > _last_snapshot_epoch
		if accepted_epoch > world_epoch:
			world_epoch = accepted_epoch
			incoming_reconciliations = []
			_reconciliation_assemblies = {}
			_last_reconciliation_epoch = accepted_epoch
			_last_reconciliation_tick = -1
		_last_snapshot_epoch = accepted_epoch
		_last_snapshot_tick = accepted_tick
		_purge_snapshot_state_through(accepted_epoch, accepted_tick, epoch_changed)
		incoming_envelopes.append(envelope)
		while incoming_envelopes.size() > MAX_QUEUED_SNAPSHOTS:
			incoming_envelopes.pop_front()
		if int(envelope.world_kind) == WorldSnapshotEnvelope.WORLD_LEGACY:
			incoming_snapshots.append((envelope.authority as Dictionary).duplicate(true))
		while incoming_snapshots.size() > MAX_QUEUED_SNAPSHOTS:
			incoming_snapshots.pop_front()

	func _accept_reconciliation(reconciliation: Dictionary, reconciliation_epoch: int = 0) -> void:
		var embedded_epoch_valid: bool = (
			typeof(reconciliation.get("world_epoch")) == TYPE_INT
			and int(reconciliation.world_epoch) == reconciliation_epoch
		)
		var legacy_epoch_zero: bool = not reconciliation.has("world_epoch") and reconciliation_epoch == 0 and world_epoch == 0
		if (
			reconciliation.is_empty()
			or reconciliation_epoch != world_epoch
			or world_epoch < 0
			or (not embedded_epoch_valid and not legacy_epoch_zero)
		):
			return
		if not _pair_after(reconciliation_epoch, int(reconciliation.tick), _last_reconciliation_epoch, _last_reconciliation_tick):
			return
		var values: PackedInt64Array = reconciliation["values"]
		if values[0] != local_entity_id:
			return
		_last_reconciliation_epoch = reconciliation_epoch
		_last_reconciliation_tick = int(reconciliation["tick"])
		for pending_key: int in _reconciliation_assemblies.keys():
			if pending_key <= _pair_key(reconciliation_epoch, _last_reconciliation_tick):
				_reconciliation_assemblies.erase(pending_key)
		incoming_reconciliations.append(reconciliation)
		while incoming_reconciliations.size() > MAX_QUEUED_RECONCILIATIONS:
			incoming_reconciliations.pop_front()


func run() -> int:
	_test_header_types_and_ranges()
	_test_stale_and_wrong_epoch_avoid_decode()
	_test_fresh_refusal_does_not_poison_pair()
	_test_sender_mode_and_outer_bounds()
	_test_frozen_admission_and_queue_equivalence()
	_test_fragment_admission_unchanged()
	_test_static_decoders_and_epoch_zero()
	return finish("session-receive-freshness")


func _receiver(epoch: int = 7) -> DecodeSpy:
	var result := DecodeSpy.new()
	_configure(result, epoch)
	return result


func _configure(receiver: SessionTransport, epoch: int) -> void:
	receiver.mode = Transport.Mode.CLIENT
	receiver.local_entity_id = 2
	check(receiver.configure_world_epoch(epoch), "receive fixture installs a valid epoch")


func _envelope(tick: int, epoch: int, projectile_count: int = 0) -> Dictionary:
	var world := SimWorld.new(120, 71, CollisionWorld.new(20_000_000, 20_000_000))
	world.player().champion_wire_id = 1
	world.tick = tick
	for index: int in projectile_count:
		world.projectiles.append(ProjectileState.new(
			1000 + index, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 3,
			Vector2i(500_000 + index * 7919, 500_000 + index * 6151),
			Vector2i(480_000 - index * 187, index * 157), 12_000, 9_000, 90 + index,
		))
	var result: Dictionary = Envelope.wrap_legacy(SessionSnapshot.capture(world, {1: "Receive Host"}), epoch)
	check(not result.is_empty(), "receive fixture produces complete valid authority")
	return result


func _reconciliation(tick: int, epoch: int, entity_id: int = 2) -> Dictionary:
	var result: Dictionary = ClientPrediction.capture_packet(PlayerState.new(entity_id), tick, 1)
	result.world_epoch = epoch
	return result


func _wire(value: Variant, reconciliation: bool, epoch: int, tick: int) -> Dictionary:
	var raw: PackedByteArray = var_to_bytes(value)
	return {
		"kind": Transport.PACKET_RECONCILIATION if reconciliation else Transport.PACKET_SNAPSHOT,
		"world_epoch": epoch, "tick": tick, "raw_size": raw.size(),
		"payload": raw.compress(FileAccess.COMPRESSION_FASTLZ),
	}


func _packet(tick: int, epoch: int, reconciliation: bool = false) -> Dictionary:
	var value: Dictionary = _reconciliation(tick, epoch) if reconciliation else _envelope(tick, epoch)
	var result: Dictionary = _wire(value, reconciliation, epoch, tick)
	check(var_to_bytes(result).size() <= Transport.ENET_MTU_BYTES, "small admission fixture exercises the real single-packet route")
	return result


func _deliver(receiver: SessionTransport, packet: Dictionary, sender: int = Transport.SERVER_PEER_ID) -> void:
	receiver._handle_packet(sender, var_to_bytes(packet))


func _state(receiver: SessionTransport) -> Dictionary:
	return {
		"world_epoch": receiver.world_epoch,
		"snapshot_epoch": receiver._last_snapshot_epoch, "snapshot_tick": receiver._last_snapshot_tick,
		"reconciliation_epoch": receiver._last_reconciliation_epoch, "reconciliation_tick": receiver._last_reconciliation_tick,
		"envelopes": receiver.incoming_envelopes.duplicate(true),
		"snapshots": receiver.incoming_snapshots.duplicate(true),
		"reconciliations": receiver.incoming_reconciliations.duplicate(true),
	}


func _decode_count(receiver: DecodeSpy) -> int:
	return receiver.snapshot_decodes + receiver.reconciliation_decodes


func _assert_early_refusal(receiver: DecodeSpy, packet: Dictionary, label: String) -> void:
	var before: Dictionary = _state(receiver)
	var decode_count: int = _decode_count(receiver)
	_deliver(receiver, packet)
	equal(_decode_count(receiver), decode_count, label + " avoids complete decoding")
	equal(_state(receiver), before, label + " preserves every accepted cursor and queue")


func _test_header_types_and_ranges() -> void:
	for reconciliation: bool in [false, true]:
		var receiver := _receiver()
		var valid: Dictionary = _packet(100, 7, reconciliation)
		for key: String in ["kind", "world_epoch", "tick"]:
			for value: Variant in [null, true, 7.0, "7", [], PackedInt32Array([7])]:
				var malformed: Dictionary = valid.duplicate(true)
				malformed[key] = value
				check(not receiver._single_packet_is_fresh(malformed, reconciliation), "freshness never coerces " + key)
				_assert_early_refusal(receiver, malformed, "non-integer " + key)
			var missing: Dictionary = valid.duplicate(true)
			missing.erase(key)
			check(not receiver._single_packet_is_fresh(missing, reconciliation), "freshness requires explicit " + key)
			_assert_early_refusal(receiver, missing, "absent " + key)
		for key: String in ["world_epoch", "tick"]:
			for value: int in [-1, Envelope.MAX_TICK + 1]:
				var malformed: Dictionary = valid.duplicate(true)
				malformed[key] = value
				_assert_early_refusal(receiver, malformed, "out-of-range " + key)
		var other_kind: Dictionary = valid.duplicate(true)
		other_kind.kind = Transport.PACKET_SNAPSHOT if reconciliation else Transport.PACKET_RECONCILIATION
		check(not receiver._single_packet_is_fresh(other_kind, reconciliation), "freshness requires the exact expected payload kind")
		for unsupported_kind: int in [-1, 0, Transport.PACKET_HELLO, 99]:
			other_kind.kind = unsupported_kind
			_assert_early_refusal(receiver, other_kind, "unsupported payload kind")
	var zero := _receiver(0)
	check(zero._single_packet_is_fresh(_packet(0, 0), false), "zero epoch and zero tick remain eligible")
	var maximum := _receiver(Envelope.MAX_EPOCH)
	for reconciliation: bool in [false, true]:
		check(maximum._single_packet_is_fresh(_packet(Envelope.MAX_TICK, Envelope.MAX_EPOCH, reconciliation), reconciliation), "inclusive maximum epoch/tick remain eligible")


func _test_stale_and_wrong_epoch_avoid_decode() -> void:
	var receiver := _receiver()
	_deliver(receiver, _packet(100, 7))
	_deliver(receiver, _packet(100, 7, true))
	equal(_decode_count(receiver), 2, "fresh world and reconciliation both run their complete decoder")
	for reconciliation: bool in [false, true]:
		for tick: int in [99, 100]:
			_assert_early_refusal(receiver, _packet(tick, 7, reconciliation), "older or duplicate accepted tuple")
		_assert_early_refusal(receiver, _packet(101, 6, reconciliation), "older epoch despite a newer tick")
	_assert_early_refusal(receiver, _packet(101, 8, true), "future reconciliation before its complete world")
	_deliver(receiver, _packet(0, 8))
	equal(receiver.world_epoch, 8, "complete future world still advances authority epoch")
	equal(receiver._last_snapshot_tick, 0, "a higher epoch permits a lower tick")
	equal(receiver.incoming_reconciliations.size(), 0, "future complete world still clears prior reconciliation queue")
	_assert_early_refusal(receiver, _packet(101, 7, true), "reconciliation from superseded epoch")
	_deliver(receiver, _packet(0, 8, true))
	equal(receiver._last_reconciliation_tick, 0, "new epoch resets and admits reconciliation tick zero")
	var unready := _receiver()
	unready.world_epoch = -1
	_assert_early_refusal(unready, _packet(101, 7, true), "uninitialized authority cannot admit reconciliation")


func _test_fresh_refusal_does_not_poison_pair() -> void:
	for reconciliation: bool in [false, true]:
		var epoch: int = 7 if reconciliation else 8
		var valid: Dictionary = _packet(100, epoch, reconciliation)
		var payload: Dictionary = _reconciliation(100, epoch) if reconciliation else _envelope(100, epoch)
		var malformed_packets: Array[Dictionary] = []
		for key: String in ["world_epoch", "tick"]:
			var mismatch: Dictionary = payload.duplicate(true)
			mismatch[key] = int(payload[key]) + 1
			malformed_packets.append(_wire(mismatch, reconciliation, epoch, 100))
		var semantic: Dictionary = payload.duplicate(true)
		if reconciliation:
			semantic.sequence = -2
		else:
			semantic.schema = -1
		malformed_packets.append(_wire(semantic, reconciliation, epoch, 100))
		malformed_packets.append(_wire([payload, payload], reconciliation, epoch, 100))
		for raw_size: Variant in [null, true, 1.0, "1", 0, -1, Transport.MAX_SNAPSHOT_UNCOMPRESSED_BYTES + 1]:
			var malformed: Dictionary = valid.duplicate(true)
			malformed.raw_size = raw_size
			malformed_packets.append(malformed)
		var missing: Dictionary = valid.duplicate(true)
		missing.erase("raw_size")
		malformed_packets.append(missing)
		for bad_payload: Variant in [null, [], "packed bytes only", PackedByteArray()]:
			var malformed: Dictionary = valid.duplicate(true)
			malformed.payload = bad_payload
			malformed_packets.append(malformed)
		missing = valid.duplicate(true)
		missing.erase("payload")
		malformed_packets.append(missing)
		for malformed: Dictionary in malformed_packets:
			var receiver := _receiver()
			var before: Dictionary = _state(receiver)
			_deliver(receiver, malformed)
			equal(_decode_count(receiver), 1, "fresh tuple still reaches complete strict decoding")
			equal(_state(receiver), before, "malformed fresh payload changes no authority cursor or queue")
			check(Transport._decode_wire_packet(malformed, reconciliation).is_empty(), "stateless decoder independently refuses malformed fresh payload")
			_deliver(receiver, valid)
			equal(_decode_count(receiver), 2, "valid replacement at the identical refused pair still decodes")
			equal(receiver._last_reconciliation_tick if reconciliation else receiver._last_snapshot_tick, 100, "valid same-pair replacement is accepted")
	var receiver := _receiver()
	var before: Dictionary = _state(receiver)
	_deliver(receiver, _wire(_reconciliation(100, 7, 3), true, 7, 100))
	equal(receiver.reconciliation_decodes, 1, "wrong-entity fresh reconciliation still performs full validation")
	equal(_state(receiver), before, "wrong entity cannot consume a valid reconciliation pair")
	_deliver(receiver, _packet(100, 7, true))
	equal(receiver._last_reconciliation_tick, 100, "correct entity recovers at the same pair")


func _test_sender_mode_and_outer_bounds() -> void:
	for reconciliation: bool in [false, true]:
		var packet: Dictionary = _packet(100, 7, reconciliation)
		for sender: int in [0, 2, 999]:
			var receiver := _receiver()
			var before: Dictionary = _state(receiver)
			_deliver(receiver, packet, sender)
			equal(_decode_count(receiver), 0, "unauthorized sender cannot invoke complete snapshot decoding")
			equal(_state(receiver), before, "unauthorized sender cannot change accepted authority")
		for mode: int in [Transport.Mode.OFFLINE, Transport.Mode.CONNECTING, Transport.Mode.HOSTING]:
			var receiver := _receiver()
			receiver.mode = mode
			var before: Dictionary = _state(receiver)
			_deliver(receiver, packet)
			equal(_decode_count(receiver), 0, "non-client mode cannot invoke complete snapshot decoding")
			equal(_state(receiver), before, "non-client mode cannot admit payload authority")
	var receiver := _receiver()
	var oversized := PackedByteArray()
	oversized.resize(Transport.MAX_PACKET_BYTES + 1)
	for encoded: PackedByteArray in [PackedByteArray(), oversized, var_to_bytes([1, 2, 3])]:
		receiver._handle_packet(Transport.SERVER_PEER_ID, encoded)
	equal(_decode_count(receiver), 0, "outer empty/size/type refusal precedes complete decoding")


func _compare_admission(candidate: DecodeSpy, predecessor: PreFreshnessTransport, packet: Dictionary, label: String) -> void:
	_deliver(predecessor, packet)
	_deliver(candidate, packet)
	equal(_state(candidate), _state(predecessor), label + " exactly matches frozen accepted data and cursors")
	equal(var_to_bytes(_state(candidate)), var_to_bytes(_state(predecessor)), label + " preserves byte order as well as values")
	check(candidate.incoming_envelopes.size() <= Transport.MAX_QUEUED_SNAPSHOTS, label + " keeps complete world queue bounded")
	check(candidate.incoming_snapshots.size() <= Transport.MAX_QUEUED_SNAPSHOTS, label + " keeps legacy adapter queue bounded")
	check(candidate.incoming_reconciliations.size() <= Transport.MAX_QUEUED_RECONCILIATIONS, label + " keeps reconciliation queue bounded")


func _test_frozen_admission_and_queue_equivalence() -> void:
	var receiver := _receiver()
	var predecessor := PreFreshnessTransport.new()
	_configure(predecessor, 7)
	for tick: int in [100, 102, 101, 102, 103, 105]:
		_compare_admission(receiver, predecessor, _packet(tick, 7), "world burst")
		_compare_admission(receiver, predecessor, _packet(tick, 7, true), "reconciliation burst")
	equal(receiver.incoming_envelopes.size(), Transport.MAX_QUEUED_SNAPSHOTS, "complete overflow retains exactly the existing finite capacity")
	equal(receiver.incoming_reconciliations.size(), Transport.MAX_QUEUED_RECONCILIATIONS, "reconciliation overflow retains exactly the existing finite capacity")
	equal(receiver.snapshot_decodes, 4, "world burst decodes four fresh tuples but neither old nor duplicate tuples")
	equal(receiver.reconciliation_decodes, 4, "reconciliation burst decodes four fresh tuples but neither old nor duplicate tuples")
	_compare_admission(receiver, predecessor, _packet(106, 6), "stale epoch world")
	_compare_admission(receiver, predecessor, _packet(0, 8, true), "future reconciliation before world")
	_compare_admission(receiver, predecessor, _wire(_reconciliation(106, 7, 3), true, 7, 106), "fresh wrong entity")
	var rejected: Dictionary = _envelope(0, 8)
	rejected.schema = -1
	_compare_admission(receiver, predecessor, _wire(rejected, false, 8, 0), "malformed future complete authority")
	_compare_admission(receiver, predecessor, _packet(0, 8), "valid same future tuple")
	_compare_admission(receiver, predecessor, _packet(0, 8, true), "matching future reconciliation")
	for tick: int in [1, 2, 2, 1, 3]:
		_compare_admission(receiver, predecessor, _packet(tick, 8), "new epoch bounded world burst")
		_compare_admission(receiver, predecessor, _packet(tick, 8, true), "new epoch bounded reconciliation burst")
	equal(receiver.poll_envelopes(), predecessor.poll_envelopes(), "poll drains identical complete worlds")
	equal(receiver.take_snapshots(), predecessor.take_snapshots(), "legacy poll drains identical authority")
	equal(receiver.take_reconciliations(), predecessor.take_reconciliations(), "reconciliation poll drains identical movement authority")
	_compare_admission(receiver, predecessor, _packet(3, 8), "draining cannot reopen accepted snapshot tuples")
	_compare_admission(receiver, predecessor, _packet(3, 8, true), "draining cannot reopen accepted reconciliation tuples")
	check(receiver.configure_world_epoch(9) and predecessor.configure_world_epoch(9), "trusted explicit epoch reset remains available")
	_compare_admission(receiver, predecessor, _packet(0, 9), "reset admits tick zero")
	_compare_admission(receiver, predecessor, _packet(0, 9, true), "reset admits tick zero movement")


func _test_fragment_admission_unchanged() -> void:
	var receiver := _receiver()
	var predecessor := PreFreshnessTransport.new()
	_configure(predecessor, 7)
	var current: Array[Dictionary] = Transport._envelope_wire_packets(_envelope(100, 7, 80))
	var future: Array[Dictionary] = Transport._envelope_wire_packets(_envelope(0, 8, 80))
	check(current.size() > 1 and future.size() > 1, "dense control fixtures exercise actual fragmented transport")
	if current.size() < 2 or future.size() < 2:
		return
	_compare_admission(receiver, predecessor, future[0], "partial future fragment")
	equal(receiver.world_epoch, 7, "partial future fragments cannot advance epoch")
	current.reverse()
	for fragment: Dictionary in current:
		_compare_admission(receiver, predecessor, fragment, "reordered complete current fragments")
	equal(receiver._snapshot_assemblies.size(), 1, "future partial frame survives newer current authority")
	for index: int in range(future.size() - 1, 0, -1):
		_compare_admission(receiver, predecessor, future[index], "reordered future completion")
	equal(receiver.world_epoch, 8, "complete future fragments retain previous epoch advancement")
	equal(receiver._snapshot_assemblies.size(), 0, "completed future fragments purge superseded partial state")
	for fragment: Dictionary in current:
		_compare_admission(receiver, predecessor, fragment, "stale fragments after complete future epoch")
	equal(_decode_count(receiver), 0, "single-packet optimization never intercepts fragment decoding")


func _test_static_decoders_and_epoch_zero() -> void:
	var receiver := _receiver(0)
	var world_packet: Dictionary = _packet(0, 0)
	var movement_packet: Dictionary = _packet(0, 0, true)
	_deliver(receiver, world_packet)
	_deliver(receiver, movement_packet)
	check(not Transport._envelope_from_wire_packet(world_packet).is_empty(), "public static decoder remains stateless even for an accepted duplicate")
	var movement: Dictionary = Transport._snapshot_from_wire_packet(movement_packet, true)
	check(not movement.is_empty() and not movement.has("world_epoch"), "static epoch-zero reconciliation retains its legacy adapter shape")
	equal(receiver.incoming_reconciliations, [movement], "instance fresh route preserves epoch-zero adapter bytes")
	_assert_early_refusal(receiver, world_packet, "epoch-zero duplicate world")
	_assert_early_refusal(receiver, movement_packet, "epoch-zero duplicate movement")
	var mismatch: Dictionary = world_packet.duplicate(true)
	mismatch.tick = 1
	check(Transport._envelope_from_wire_packet(mismatch).is_empty(), "public stateless decoder still checks inner/outer tick consistency")

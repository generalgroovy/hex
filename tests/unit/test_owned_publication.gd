extends "res://tests/unit/test_hex_world_snapshot.gd"
## Same-source public composition is the strict oracle. No sockets or timing
## assertions: the paired performance probe measures this complete operation.

const Transport = preload("res://src/net/session_transport.gd")
const Envelope = preload("res://src/net/world_snapshot_envelope.gd")


class TracingSession:
	extends AuthoritativeSession
	var trace: Array[String] = []
	var captures := 0
	func capture_envelope() -> Dictionary:
		captures += 1
		trace.append("capture")
		return super.capture_envelope()

class TracingTransport:
	extends SessionTransport
	var trace: Array[String] = []
	var sent: Array[Dictionary] = []
	var failure_indices: Array[int] = []
	func broadcast_envelope(envelope: Dictionary) -> bool:
		trace.append("broadcast")
		return super.broadcast_envelope(envelope)
	func _send_to(peer_id: int, packet: Dictionary, transfer_mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE, transfer_channel: int = 0) -> bool:
		var index := sent.size()
		sent.append({"peer": peer_id, "bytes": var_to_bytes(packet), "mode": transfer_mode, "channel": transfer_channel})
		return not failure_indices.has(index)

class MutatingHearth:
	extends SessionHearth
	var source: AuthoritativeSession
	var calls := 0
	func capture(world_tick: int, maximum_players: int) -> PackedInt32Array:
		calls += 1
		source.world.player().health -= 1
		source.world_epoch += 1
		return super.capture(world_tick, maximum_players)

class TracingRound:
	extends SessionRound
	var calls := 0
	func capture(world: SimWorld) -> PackedInt32Array:
		calls += 1
		return super.capture(world)

class TracingWorld:
	extends SimWorld
	var hash_calls := 0
	func state_hash() -> String:
		hash_calls += 1
		return super.state_hash()

class OpaqueEventValue:
	extends RefCounted
	var calls := 0
	func _to_string() -> String:
		calls += 1
		return "opaque"

class MutatingChemistryKey:
	extends RefCounted
	var court: HexChemistryWorld
	var calls := 0
	var armed := true
	func _to_string() -> String:
		calls += 1
		if armed:
			armed = false
			court.metrics.requested += 1
			court.metrics.refused += 1
		return "mutating-chemistry-key"

class SuppliedEnvelopeSession:
	extends AuthoritativeSession
	var supplied: Dictionary = {}
	var captures := 0
	func capture_envelope() -> Dictionary:
		captures += 1
		snapshot_capture_pending_ack = true
		return supplied

class ModeChangingName:
	extends RefCounted
	var target: SessionTransport
	var calls := 0
	func _to_string() -> String:
		calls += 1
		target.mode = SessionTransport.Mode.HOSTING
		return "Callback"

class LateInstalledTransport:
	extends SessionTransport
	var observed: Dictionary = {}
	var calls := 0
	func broadcast_envelope(envelope: Dictionary) -> bool:
		calls += 1
		observed = envelope.duplicate(true)
		return true # Deliberately observable extension-owned decision, even for {}.

class ScriptChangingChemistryKey:
	extends RefCounted
	var target: SessionTransport
	var calls := 0
	var swaps := 0
	func _to_string() -> String:
		calls += 1
		if swaps == 0:
			swaps += 1
			target.set_script(LateInstalledTransport)
		return "script-changing-chemistry-key"

class ScriptChangingSession:
	extends AuthoritativeSession
	var target: SessionTransport
	var captures := 0
	func capture_envelope() -> Dictionary:
		captures += 1
		var result := super.capture_envelope()
		target.set_script(LateInstalledTransport)
		return result


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "owned publication loads the production spell catalogue")
	if not catalog.last_error.is_empty(): return finish("owned-publication")
	_test_empty_and_paid_bytes(catalog)
	_test_refusals_and_pending_ack(catalog)
	_test_completed_outputs_are_not_trust(catalog)
	_test_extension_and_callback_fallbacks(catalog)
	_test_chemistry_capture_owns_deep_admission(catalog)
	_test_late_transport_extension_dispatch(catalog)
	_test_delivery_contract(catalog)
	_test_offline_fallback_validation_order()
	_test_raw_packing_bounds()
	return finish("owned-publication")


func _session(catalog: AbilityCatalog, rich := false, count := 1, requested_session: AuthoritativeSession = null, requested_world: SimWorld = null) -> AuthoritativeSession:
	var source := AuthoritativeSession.new() if requested_session == null else requested_session
	var world := SimWorld.new() if requested_world == null else requested_world
	check(HexCourtPractice.configure(world, catalog, false), "owned fixture uses the ordinary practice loadout")
	# Practice's HexCourt subclass intentionally uses the fallback. Admit the
	# same initially empty geometry into the production concrete storage type.
	var cells: Array[Vector2i] = []
	for cell: Vector2i in world.hex_court.cell_keys(): cells.append(cell)
	var court := HexChemistryWorld.new()
	check(court.configure_geometry(world.hex_court.origin, cells), "owned fixture admits concrete immutable geometry")
	court.chemistry_enabled = true
	var base: CollisionWorld = world.collision
	var collision := HexCollisionWorld.new(base)
	check(collision.set_hex_surfaces(court, world.tick), "owned fixture installs concrete dynamic collision")
	court.collision = base
	world.hex_court = court
	world.collision = collision
	world.reaction_movement = collision
	if rich:
		check(not _advance_to_rich_capture(world).is_empty(), "owned fixture reaches real paid pending, flight and product authority")
	source.world = world
	source.world_epoch = 7
	source.names_by_entity = {1: "Owned Host"}
	source.hearth.bind_host()
	source.session_round.bind_hearth()
	for entity_id: int in range(2, count + 1):
		var actor := PlayerState.new(entity_id)
		actor.team_id = entity_id
		actor.position_x = 100_000 + entity_id * 20_003
		actor.position_y = 200_000 + entity_id * 17_009
		world.players.append(actor)
		source.names_by_entity[entity_id] = "Owned Guest %d" % entity_id
		check(source.hearth.connect_entity(entity_id), "owned fixture registers champion Hearth presence")
	return source


func _public_publication(source: AuthoritativeSession) -> Dictionary:
	# Deliberately the unchanged old public composition, not the optimized
	# factory or its additional-header-only predicate.
	var envelope := source.capture_envelope()
	var packets: Array[Dictionary] = []
	if not envelope.is_empty():
		packets = Transport._envelope_wire_packets(envelope)
	return {"envelope": envelope, "packets": packets} if not packets.is_empty() else {}


func _equal_publications(actual: Dictionary, expected: Dictionary, label: String) -> void:
	check(not actual.is_empty() and not expected.is_empty(), label + " requires actual admission in both positive comparison arms")
	equal(actual.is_empty(), expected.is_empty(), label + " retains strict public acceptance")
	if actual.is_empty() or expected.is_empty(): return
	equal(actual.keys(), ["envelope", "packets"], label + " exposes only completed diagnostic output")
	equal(var_to_bytes(actual.envelope), var_to_bytes(expected.envelope), label + " preserves exact complete envelope bytes")
	equal(var_to_bytes(actual.packets), var_to_bytes(expected.packets), label + " preserves exact packet order, fields, compression and fragments")
	check(Envelope.validate(actual.envelope), label + " still passes independent public envelope validation")
	var packets: Array[Dictionary] = actual.packets
	check(not packets.is_empty(), label + " produces at least one packet")
	for packet: Dictionary in packets:
		check(var_to_bytes(packet).size() <= Transport.ENET_MTU_BYTES, label + " keeps every complete encoded datagram within MTU")


func _assert_pair(source: AuthoritativeSession, label: String) -> Dictionary:
	var before := source.world.state_hash()
	var queue_before := var_to_bytes(source.pending_combat_events)
	var expected := _public_publication(source)
	var expected_ack := source.snapshot_capture_pending_ack
	source.snapshot_capture_pending_ack = false
	var actual := Transport._capture_session_packets(source)
	_equal_publications(actual, expected, label)
	equal(source.snapshot_capture_pending_ack, expected_ack, label + " retains pending acknowledgement")
	equal(source.world.state_hash(), before, label + " leaves live authority unchanged")
	equal(var_to_bytes(source.pending_combat_events), queue_before, label + " does not retire or alter event redundancy")
	return actual


func _test_empty_and_paid_bytes(catalog: AbilityCatalog) -> void:
	var empty := _session(catalog)
	check(Transport._owned_publication_eligible(empty), "concrete object-free session enters owned publication")
	var initial := _assert_pair(empty, "empty concrete Hex")
	check(not initial.is_empty(), "empty concrete authority actually publishes")
	var paid := _session(catalog, true, 8)
	check(Transport._owned_publication_eligible(paid), "paid eight-champion session enters owned publication")
	equal(paid.record_combat_events([{"type": "ready_changed", "entity_id": 1, "ready": true}]), 1, "paid fixture retains a real encodable session event")
	var rich := _assert_pair(paid, "paid eight-champion Hex")
	check(not rich.is_empty(), "paid concrete authority actually publishes")
	if rich.is_empty(): return
	check((rich.packets as Array).size() > 1, "paid eight-champion case exercises real fragmentation")
	var receiver := Transport.new()
	receiver.mode = Transport.Mode.CLIENT
	check(receiver.configure_world_epoch(7), "receiver installs the exact publication epoch")
	for packet: Dictionary in rich.packets: receiver._handle_packet(Transport.SERVER_PEER_ID, var_to_bytes(packet))
	var received := receiver.poll_envelopes()
	equal(received.size(), 1, "unchanged receiver admits one complete owned publication")
	if received.size() == 1: equal(var_to_bytes(received[0]), var_to_bytes(rich.envelope), "unchanged receiver reconstructs exact authority and metadata")
	for acknowledgement: int in AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS:
		check(not Transport._capture_session_packets(paid).is_empty(), "redundant event publication remains valid")
		paid.acknowledge_snapshot()
		equal(paid.pending_combat_events.size(), 0 if acknowledgement == AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS - 1 else 1, "only explicit acknowledgement retires the existing redundancy lane")


func _test_refusals_and_pending_ack(catalog: AbilityCatalog) -> void:
	for kind: String in ["epoch-negative", "epoch-large", "tick-negative", "tick-large", "actor", "hearth", "round", "event", "overflow", "outer-byte-limit"]:
		var source := _session(catalog)
		match kind:
			"epoch-negative": source.world_epoch = -1
			"epoch-large": source.world_epoch = Envelope.MAX_EPOCH + 1
			"tick-negative": source.world.tick = -1
			"tick-large": source.world.tick = Envelope.MAX_TICK + 1
			"actor": source.world.player().health = -1
			"hearth": source.hearth.connect_entity(2)
			"round":
				source.session_round.phase = SessionRound.Phase.ACTIVE
				source.session_round.scores_by_entity = {1: 0, 2: 0}
			"event": source.pending_combat_events = [{"type": "hex_clash", "source_wire_id": "not-an-int"}]
			"overflow": source.pending_combat_event_overflow_count = -1
			"outer-byte-limit":
				var authority := Snapshot.capture(source.world)
				check(not authority.is_empty(), "outer-only size fixture starts from valid authority")
				var retained_length := source.world.map_hash.to_utf8_buffer().size()
				var extra := Snapshot.MAX_RAW_BYTES - Snapshot.byte_size(authority) - 64
				source.world.map_hash = "x".repeat(retained_length + extra)
				check(not Snapshot.capture(source.world).is_empty(), "outer-only size fixture remains within authority byte limit")
		for previous_ack: bool in [false, true]:
			source.snapshot_capture_pending_ack = previous_ack
			var expected := _public_publication(source)
			var expected_ack := source.snapshot_capture_pending_ack
			source.snapshot_capture_pending_ack = previous_ack
			var actual := Transport._capture_session_packets(source)
			check(expected.is_empty() and actual.is_empty(), kind + " refuses through strict and owned paths")
			equal(source.snapshot_capture_pending_ack, expected_ack, kind + " refusal preserves previous pending-ack state")


func _test_completed_outputs_are_not_trust(catalog: AbilityCatalog) -> void:
	var source := _session(catalog)
	var publication := Transport._capture_session_packets(source)
	check(not publication.is_empty(), "alias fixture completes publication")
	if publication.is_empty(): return
	var pristine_bytes := var_to_bytes(publication.envelope)
	var packet_bytes := var_to_bytes(publication.packets)
	var before := source.world.state_hash()
	var exposed: Dictionary = publication.envelope
	var exposed_players: PackedInt32Array = exposed.authority.players
	exposed_players[35] = -1
	exposed.authority.players = exposed_players
	(exposed.session.names as Array)[0][1] = "Changed"
	equal(var_to_bytes(publication.packets), packet_bytes, "returned mutable envelope cannot rewrite serialized packet payloads")
	check(not Envelope.validate(exposed), "public envelope validator rejects caller mutation of completed output")
	check(Envelope.wrap_hex(exposed.authority, exposed.session, source.world_epoch).is_empty(), "public wrapper never accepts caller alleged captured authority")
	check(Transport._envelope_wire_packets(exposed).is_empty(), "public wire entry still fully checks mutable caller data")
	var host := Transport.new()
	host.mode = Transport.Mode.HOSTING
	host.world_epoch = source.world_epoch
	check(not host.broadcast_envelope(exposed), "public broadcast still refuses corrupted caller output with no peers")
	var fresh := Transport._capture_session_packets(source)
	check(not fresh.is_empty(), "caller mutation cannot poison the next fresh capture")
	if not fresh.is_empty(): equal(var_to_bytes(fresh.envelope), pristine_bytes, "fresh capture preserves pristine exact bytes")
	var packet: Dictionary = (publication.packets as Array)[0]
	var payload: PackedByteArray = packet.payload
	payload[0] = payload[0] ^ 0xff
	equal(source.world.state_hash(), before, "exposed envelope and packed-byte mutations cannot reach live authority")
	var after_packet_mutation := Transport._capture_session_packets(source)
	if not after_packet_mutation.is_empty(): equal(var_to_bytes(after_packet_mutation.packets), packet_bytes, "future packets own buffers independent of escaped prior payload")
	for kind: String in ["schema", "inner-size", "header", "session-relation"]:
		var altered: Dictionary = (fresh.envelope as Dictionary).duplicate(true)
		match kind:
			"schema": altered.authority.schema = -1
			"inner-size": altered.authority.hex["size"] = int(altered.authority.hex["size"]) + 1
			"header":
				var header: PackedInt64Array = altered.authority.header
				header[7] += 1
				altered.authority.header = header
			"session-relation": (altered.session.names as Array)[0][0] = 2
		check(not Envelope.validate(altered), kind + " remains refused by unchanged public validation")
		check(Transport._envelope_wire_packets(altered).is_empty(), kind + " cannot bypass public packet packing")


func _test_extension_and_callback_fallbacks(catalog: AbilityCatalog) -> void:
	var extended := _session(catalog, false, 1, TracingSession.new()) as TracingSession
	check(not Transport._owned_publication_eligible(extended), "session subclass cannot claim owned producer admission")
	_equal_publications(Transport._capture_session_packets(extended), _public_publication(extended), "session subclass fallback")
	equal(extended.captures, 2, "both fallback arms invoke the existing virtual capture exactly once")
	var source := _session(catalog)
	var hearth := MutatingHearth.new()
	hearth.bind_host()
	hearth.source = source
	source.hearth = hearth
	check(not Transport._owned_publication_eligible(source), "Hearth callback is excluded before capture reuse")
	var original_health := source.world.player().health
	var expected := _public_publication(source)
	equal(hearth.calls, 1, "public callback fixture really re-enters after authority capture")
	equal(source.world.player().health, original_health - 1, "Hearth callback really changes live authority")
	source.world.player().health = original_health
	source.world_epoch = 7
	source.snapshot_capture_pending_ack = false
	var actual := Transport._capture_session_packets(source)
	_equal_publications(actual, expected, "mutating Hearth fallback preserves prior capture order")
	equal(hearth.calls, 2, "owned source factory invokes fallback callback exactly once")
	equal(source.world_epoch, 8, "fallback preserves callback-selected envelope epoch")
	hearth.source = null # Break the intentional RefCounted observer cycle.
	var round_source := _session(catalog)
	var round_state := TracingRound.new()
	round_source.session_round = round_state
	check(not Transport._owned_publication_eligible(round_source), "round subclass cannot bypass virtual capture")
	_equal_publications(Transport._capture_session_packets(round_source), _public_publication(round_source), "round subclass fallback")
	equal(round_state.calls, 2, "round fallback preserves one callback per capture")
	var world := TracingWorld.new()
	var world_source := _session(catalog, false, 1, null, world)
	check(not Transport._owned_publication_eligible(world_source), "world subclass keeps final-source hash fallback")
	_equal_publications(Transport._capture_session_packets(world_source), _public_publication(world_source), "world subclass fallback")
	check(world.hash_calls >= 4, "both world fallback arms preserve virtual hash calls")
	var opaque_source := _session(catalog)
	var opaque := OpaqueEventValue.new()
	opaque_source.pending_combat_events = [{"type": "ready_changed", "entity_id": 1, "ready": true, "ignored": opaque}]
	check(not Transport._owned_publication_eligible(opaque_source), "opaque event values decline reuse even in otherwise ignored fields")
	equal(opaque.calls, 0, "admission does not stringify arbitrary event objects")
	_equal_publications(Transport._capture_session_packets(opaque_source), _public_publication(opaque_source), "opaque event fallback")
	equal(opaque.calls, 0, "ignored opaque data is not serialized into session authority")
	var legacy := AuthoritativeSession.new()
	legacy.world = SimWorld.new()
	legacy.world.player().champion_wire_id = 1
	legacy.names_by_entity = {1: "Legacy Host"}
	legacy.hearth.bind_host()
	check(not Transport._owned_publication_eligible(legacy), "legacy source retains unchanged public path")
	_equal_publications(Transport._capture_session_packets(legacy), _public_publication(legacy), "legacy fallback")
	var refused := SuppliedEnvelopeSession.new()
	check(Transport._capture_session_packets(refused).is_empty(), "empty extension capture returns a typed empty fallback without packing")
	equal(refused.captures, 1, "empty extension capture is invoked exactly once")
	check(refused.snapshot_capture_pending_ack, "empty extension fallback preserves its existing capture side effects")


func _test_delivery_contract(catalog: AbilityCatalog) -> void:
	var source := _session(catalog)
	source.record_combat_events([{"type": "ready_changed", "entity_id": 1, "ready": true}])
	for kind: String in ["no-peers", "not-host", "wrong-epoch", "missing-peer"]:
		var host := Transport.new()
		host.mode = Transport.Mode.HOSTING
		host.world_epoch = source.world_epoch
		match kind:
			"not-host": host.mode = Transport.Mode.OFFLINE
			"wrong-epoch": host.world_epoch += 1
			"missing-peer": host.accepted_peer_ids = PackedInt32Array([2, 3])
		source.snapshot_capture_pending_ack = false
		var expected := host.broadcast_envelope(source.capture_envelope())
		var expected_ack := source.snapshot_capture_pending_ack
		source.snapshot_capture_pending_ack = false
		var actual := host.broadcast_session(source)
		equal(actual, expected, kind + " retains old composed send result")
		equal(actual, kind == "no-peers", kind + " keeps historical no-peer success and failure guards")
		equal(source.snapshot_capture_pending_ack, expected_ack, kind + " still captures before delivery guards")
		check(source.snapshot_capture_pending_ack, kind + " never clears completed capture acknowledgement on send failure")
		equal(source.pending_combat_events.size(), 1, kind + " never acknowledges internally")
	var extended := _session(catalog, true, 8, TracingSession.new()) as TracingSession
	var packets := _public_publication(extended)
	check(not packets.is_empty(), "extension fanout fixture publishes")
	if packets.is_empty(): return
	var transport := TracingTransport.new()
	transport.mode = Transport.Mode.HOSTING
	transport.world_epoch = extended.world_epoch
	transport.accepted_peer_ids = PackedInt32Array([8, 2, 5])
	transport.failure_indices = [0, 2]
	transport.trace = extended.trace
	extended.trace.clear()
	check(not transport.broadcast_session(extended), "partial extension send failure remains authoritative")
	equal(extended.trace, ["capture", "broadcast"], "transport/session overrides preserve original expression evaluation order")
	var packet_count: int = (packets.packets as Array).size()
	equal(transport.sent.size(), 3 * packet_count, "partial send failure still attempts every peer and fragment")
	for peer_index: int in 3:
		for packet_index: int in packet_count:
			var sent: Dictionary = transport.sent[peer_index * packet_count + packet_index]
			equal(sent.peer, transport.accepted_peer_ids[peer_index], "extension fanout remains peer-major")
			equal(sent.bytes, var_to_bytes((packets.packets as Array)[packet_index]), "extension fanout preserves exact fragment bytes")
			equal(sent.mode, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, "extension snapshot transfer mode remains unchanged")
			equal(sent.channel, Transport.SNAPSHOT_CHANNEL, "extension snapshot channel remains unchanged")
	check(extended.snapshot_capture_pending_ack, "partial delivery does not erase captured acknowledgement state")
	check(not transport.broadcast_session(null), "missing source refuses without extension callbacks")


func _test_chemistry_capture_owns_deep_admission(catalog: AbilityCatalog) -> void:
	var source := _session(catalog)
	check(not Transport._capture_session_packets(source).is_empty(), "chemistry adversary starts after a successful owned publication")
	var court: HexChemistryWorld = source.world.hex_court
	var key := MutatingChemistryKey.new()
	key.court = court
	court.metrics[key] = 0
	check(Transport._owned_publication_eligible(source), "publication's cheap gate deliberately admits opaque live chemistry to strict capture")
	check(not Snapshot._producer_reuse_eligible(source.world), "capture still independently rejects opaque chemistry from its deep producer optimization")
	equal(key.calls, 0, "neither admission check formats opaque chemistry keys")
	var original_requested: int = court.metrics.requested
	var original_refused: int = court.metrics.refused
	source.snapshot_capture_pending_ack = false
	var expected := _public_publication(source)
	var expected_calls := key.calls
	check(expected.is_empty(), "public capture refuses opaque chemistry which cannot reconstruct exact authority")
	check(expected_calls > 0 and not key.armed, "strict capture really executes the mutating chemistry callback")
	equal(int(court.metrics.requested), original_requested + 1, "chemistry callback really changes valid live counters")
	court.metrics.requested = original_requested
	court.metrics.refused = original_refused
	key.calls = 0
	key.armed = true
	source.snapshot_capture_pending_ack = false
	var actual := Transport._capture_session_packets(source)
	check(actual.is_empty(), "owned publication cannot bypass strict capture refusal after a previously valid capture")
	equal(key.calls, expected_calls, "owned path retains the original capture callback count")
	check(not key.armed, "owned path reaches capture's real callback rather than declining at publication admission")
	equal(int(court.metrics.requested), original_requested + 1, "owned capture performs the same callback mutation")
	check(not source.snapshot_capture_pending_ack, "failed deep capture cannot mark a completed envelope")
	court.metrics.erase(key)
	key.court = null # Break the intentional authority -> observer -> authority cycle.
	check(Transport._owned_publication_eligible(source), "removing opaque state leaves cheap admission stateless")
	var recovery := _assert_pair(source, "post-opaque-callback recovery")
	check(not recovery.is_empty(), "no failed or prior successful publication leaves cached trust or poisoned authority")


func _test_raw_packing_bounds() -> void:
	check(Transport._capture_session_packets(null).is_empty(), "source-only factory rejects a null source")
	check(Transport._wire_packets_from_raw(PackedByteArray(), false, 0, 0).is_empty(), "raw packer retains empty-byte refusal")
	var too_large := PackedByteArray()
	too_large.resize(Transport.MAX_SNAPSHOT_UNCOMPRESSED_BYTES + 1)
	check(Transport._wire_packets_from_raw(too_large, false, 0, 0).is_empty(), "raw snapshot packer keeps exact uncompressed cap")
	too_large.resize(Transport.MAX_PACKET_BYTES + 1)
	check(Transport._wire_packets_from_raw(too_large, true, 0, 0).is_empty(), "raw reconciliation packer keeps its smaller existing cap")
	var raw := var_to_bytes({"test": 1})
	for pair: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
		check(Transport._wire_packets_from_raw(raw, false, pair.x, pair.y).is_empty(), "raw packer rejects negative epoch/tick")
	check(Transport._wire_packets_from_raw(raw, false, Envelope.MAX_EPOCH + 1, 0).is_empty(), "raw packer rejects oversized epoch")
	check(Transport._wire_packets_from_raw(raw, false, 0, Envelope.MAX_TICK + 1).is_empty(), "raw packer rejects oversized tick")


func _test_late_transport_extension_dispatch(catalog: AbilityCatalog) -> void:
	var rejected_results: Array[Dictionary] = []
	var accepted_results: Array[Dictionary] = []
	for owned: bool in [false, true]:
		var source := _session(catalog)
		var host := Transport.new()
		host.mode = Transport.Mode.HOSTING
		host.world_epoch = source.world_epoch
		var key := ScriptChangingChemistryKey.new()
		key.target = host
		source.world.hex_court.metrics[key] = 0
		check(Transport._owned_publication_eligible(source), "late script adversary reaches owned capture through cheap admission")
		var result: bool
		if owned:
			result = host.broadcast_session(source)
		else:
			result = host.broadcast_envelope(source.capture_envelope())
		check(key.calls > 0 and key.swaps == 1, "opaque chemistry really installs a different transport script during capture")
		check(host.get_script() == LateInstalledTransport, "transport script replacement is an actual runtime change")
		check(result, "late extension retains its own broadcast return value even for rejected capture")
		var installed := host as LateInstalledTransport
		check(installed != null, "late script is the expected transport extension")
		if installed != null:
			equal(installed.calls, 1, "late extension receives exactly one post-capture broadcast")
			check(installed.observed.is_empty(), "strict capture refusal is delivered unchanged as an empty envelope")
			rejected_results.append({"calls": key.calls, "envelope": installed.observed, "result": result})
		check(not source.snapshot_capture_pending_ack, "rejected late-callback capture cannot mark acknowledgement")
		source.world.hex_court.metrics.erase(key)
		key.target = null
		var successful := _session(catalog, false, 1, ScriptChangingSession.new()) as ScriptChangingSession
		var successful_host := Transport.new()
		successful.target = successful_host
		check(not Transport._owned_publication_eligible(successful), "successful capture override keeps literal public fallback")
		var success: bool
		if owned:
			success = successful_host.broadcast_session(successful)
		else:
			success = successful_host.broadcast_envelope(successful.capture_envelope())
		var successful_extension := successful_host as LateInstalledTransport
		check(success and successful_extension != null, "successful capture callback also dispatches to its newly installed extension")
		equal(successful.captures, 1, "late extension delivery never recaptures successful source")
		if successful_extension != null:
			equal(successful_extension.calls, 1, "successful late extension receives one envelope")
			check(Envelope.validate(successful_extension.observed), "successful late extension receives the full valid captured envelope")
			accepted_results.append(successful_extension.observed)
		check(successful.snapshot_capture_pending_ack, "successful late capture preserves pending acknowledgement")
		successful.target = null
	equal(rejected_results.size(), 2, "both real rejected-capture script-change arms completed")
	if rejected_results.size() == 2: equal(rejected_results[1], rejected_results[0], "owned rejected callback count and late dispatch match original expression")
	equal(accepted_results.size(), 2, "both real successful-capture script-change arms completed")
	if accepted_results.size() == 2: equal(var_to_bytes(accepted_results[1]), var_to_bytes(accepted_results[0]), "successful callback fallback preserves exact captured bytes")


func _test_offline_fallback_validation_order() -> void:
	var legacy := AuthoritativeSession.new()
	legacy.world = SimWorld.new()
	legacy.world.player().champion_wire_id = 1
	legacy.names_by_entity = {1: "Legacy Host"}
	legacy.hearth.bind_host()
	var supplied := legacy.capture_envelope()
	check(not supplied.is_empty(), "offline callback fixture starts with valid legacy authority")
	if supplied.is_empty(): return
	var host := Transport.new()
	host.world_epoch = legacy.world_epoch
	host.mode = Transport.Mode.OFFLINE
	var name := ModeChangingName.new()
	name.target = host
	(supplied.authority.players as Array)[0][1] = name
	var source := SuppliedEnvelopeSession.new()
	source.supplied = supplied
	check(not host.broadcast_envelope(source.capture_envelope()), "predecessor composition rejects offline before inspecting caller names")
	equal(name.calls, 0, "predecessor host guard does not stringify an opaque caller name")
	source.snapshot_capture_pending_ack = false
	check(not host.broadcast_session(source), "owned API preserves offline rejection for extension-supplied envelopes")
	equal(name.calls, 0, "fallback cannot re-enter validation and switch OFFLINE to HOSTING before host guard")
	equal(host.mode, Transport.Mode.OFFLINE, "no-host callback refusal retains exact transport mode")
	equal(source.captures, 2, "both old and new expressions capture exactly once before refusing")
	check(source.snapshot_capture_pending_ack, "offline fallback preserves capture's pending acknowledgement")
	# Prove the adversary is active without feeding its opaque input to a wire
	# encoder. The host guard above must prevent this otherwise valid callback.
	equal(str(name), "Callback", "opaque name's real formatting callback is armed")
	equal(host.mode, Transport.Mode.HOSTING, "adversary would change the guarded transport mode")
	name.target = null

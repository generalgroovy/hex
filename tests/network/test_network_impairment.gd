extends "res://tests/unit/test_session_transport.gd"
## Real loopback ENet, with deterministic impairment BEFORE its send boundary.
## Tick delays are injected model values, not measured Internet RTT or FPS.
const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")

# Test-only failure witness. It never retries publication or changes admission.
# Bounded history changes polling cost; this is diagnosis, not a timing replay.
const DiagnosticChemistry = preload("res://src/net/hex_chemistry_snapshot.gd")
const DiagnosticEnvelope = preload("res://src/net/world_snapshot_envelope.gd")
var diagnostic_first_failure := false
var diagnostic_case: Dictionary = {}
var diagnostic_phase := "initial"
var diagnostic_loop_tick := -1
var diagnostic_transcript: Array[Dictionary] = []
var diagnostic_initial_envelope: Dictionary = {}

class ImpairedTransport:
	extends SessionTransport
	var enabled := false
	var clock_tick := 0
	var delay_ticks := 0
	var jitter_ticks := 0
	var loss_every := 0
	var outage := false
	var serial := 0
	var last_reliable_due := -1
	var queued: Array[Dictionary] = []
	var dropped := 0
	var peak_queue := 0
	var sent_bytes := 0
	var send_failures := 0
	const MAX_DELAYED := 2048
	func _send_encoded_to(target: int, bytes: PackedByteArray, mode_value: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE, channel: int = 0) -> bool:
		var decoded: Variant = bytes_to_var(bytes)
		var input_packet := decoded is Dictionary and int(decoded.get("kind", -1)) == PACKET_INPUT
		if not enabled or (mode_value == MultiplayerPeer.TRANSFER_MODE_RELIABLE and not input_packet):
			return super._send_encoded_to(target, bytes, mode_value, channel)
		serial += 1
		var in_outage := outage and clock_tick >= 60 and clock_tick < 150
		if not input_packet and (in_outage or (loss_every > 0 and serial % loss_every == 0)):
			dropped += 1
			return true # Loss is external to successful socket admission.
		if queued.size() >= MAX_DELAYED: return false
		var jitter := posmod(serial * 17, jitter_ticks * 2 + 1) - jitter_ticks
		var due := clock_tick + maxi(0, delay_ticks + jitter)
		if input_packet:
			if in_outage: due = maxi(due, 150 + delay_ticks)
			due = maxi(due, last_reliable_due)
			last_reliable_due = due # ENet's reliable input ordering is preserved.
		queued.append({"due": due, "target": target, "bytes": bytes.duplicate(), "mode": mode_value, "channel": channel})
		peak_queue = maxi(peak_queue, queued.size())
		return true
	func advance(tick: int) -> void:
		clock_tick = tick
		var pending: Array[Dictionary] = []
		for packet: Dictionary in queued:
			if int(packet.due) > tick: pending.append(packet); continue
			if super._send_encoded_to(packet.target, packet.bytes, packet.mode, packet.channel): sent_bytes += packet.bytes.size()
			else: send_failures += 1
		queued = pending


func run() -> int:
	for count: int in [2, 8]:
		for profile: Dictionary in [
			{"id": "delay", "delay": 6, "jitter": 0, "loss": 0, "outage": false},
			{"id": "jitter", "delay": 12, "jitter": 5, "loss": 0, "outage": false},
			{"id": "loss", "delay": 6, "jitter": 3, "loss": 7, "outage": false},
			{"id": "outage_return", "delay": 6, "jitter": 3, "loss": 0, "outage": true},
		]: _exercise(count, profile)
	return finish("network-impairment")


func _impaired(profile: Dictionary) -> ImpairedTransport:
	var transport := ImpairedTransport.new()
	check(transport.configure_runtime_identity(_identity_manifest()), "impairment transport admits explicit test source identity")
	transport.delay_ticks = int(profile.delay)
	transport.jitter_ticks = int(profile.jitter)
	transport.loss_every = int(profile.loss)
	transport.outage = bool(profile.outage)
	return transport


func _exercise(count: int, profile: Dictionary) -> void:
	diagnostic_case = {"players": count, "profile": profile.duplicate(true)}
	diagnostic_phase = "initial"
	diagnostic_loop_tick = -1
	diagnostic_transcript.clear()
	diagnostic_initial_envelope.clear()
	var host := _impaired(profile)
	var clients: Array[SessionTransport] = []
	check(host.start_host(0, _signature(), "Impairment Host"), "owned unprivileged loopback host starts")
	for index: int in count - 1:
		var client := _impaired(profile)
		clients.append(client)
		check(client.start_join("127.0.0.1", host.bound_port, _signature(), "Probe %d" % index), "actual ENet client joins")
	if not _poll_many_until(host, clients, func() -> bool: return _all_clients_connected(clients)):
		check(false, "all clients complete real handshake")
		for client: SessionTransport in clients: client.stop()
		host.stop()
		return
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "impairment uses paid current catalog")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "impairment uses actual roster")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "impairment loads the actual campus")
	var world := SimWorld.new(120, 8675309, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	check(HexWorldDefinition.from_campus(layout).bind_world(world), "impairment runs the current full-map Hex authority")
	check(champions.apply_to_player(world.player(), "oh_tipi"), "host has ordinary champion stats")
	world.player().reset_for_spawn(layout.spawn * SimConfig.FIXED_SCALE)
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, layout.spawn, "Impairment Host", host.take_joined_peers()), "all real peers bind authority")
	check(SessionTransport._owned_publication_eligible(session), "harness measures concrete current publication, not extension fallback")
	for actor: PlayerState in world.players:
		check(actor.place_proven_spell(0, Mixtures.wire_for(2, "rapid")), "ordinary paid Rapid equipped")
	check(_publish(host, session), "actual initial Hex snapshot sent")
	check(_poll_many_until(host, clients, func() -> bool:
		for client: SessionTransport in clients:
			if client.world_epoch != host.world_epoch: return false
		return true), "all clients receive complete initial epoch")
	var predictions: Array[ClientPrediction] = []
	var buffers: Array[ReconciliationOrderBuffer] = []
	var replicas: Array[SimWorld] = []
	var overflow_seen: Array[bool] = []
	for client: SessionTransport in clients:
		var predictor := ClientPrediction.new()
		check(predictor.configure(world.config, world.collision, client.local_entity_id), "prediction configures actual actor")
		check(predictor.bind_hex_world(world), "prediction uses admitted Hex geometry")
		check(predictor.reconcile(ClientPrediction.capture_packet(world.player(client.local_entity_id), world.tick, -1)), "prediction initializes from authority")
		predictions.append(predictor)
		var buffer := ReconciliationOrderBuffer.new()
		buffer.configure_epoch(host.world_epoch)
		buffers.append(buffer)
		replicas.append(null)
		overflow_seen.append(false)
		client.poll_envelopes()
		client.take_snapshots()
		client.enabled = true
	host.enabled = true
	var paid := {}
	var captures := PackedInt64Array()
	for tick: int in 240:
		diagnostic_phase = "impaired"
		diagnostic_loop_tick = tick
		var sent_rows: Array = []
		host.advance(tick)
		for index: int in clients.size():
			var client := clients[index] as ImpairedTransport
			client.advance(tick)
			var command := SimCommand.new(world.tick, client.local_entity_id, 1000 if tick % 80 < 40 else -1000, 0, SimCommand.SPELL_HELD_BITS[0], SimCommand.PRESSED_JUMP if tick % 70 == 0 else 0, 0, -1000)
			sent_rows.append({"peer_id": client.local_peer_id, "sequence": tick, "command": command.canonical_bytes()})
			check(client.send_input(tick, command), "real input sends under the selected impairment")
			check(predictions[index].queue_input(tick, command), "prediction retains ordinary movement intent")
			overflow_seen[index] = overflow_seen[index] or predictions[index].history_overflowed
		host.poll()
		var received_inputs := host.take_inputs()
		session.ingest_inputs(received_inputs)
		var commands := session.commands_for_tick(SimCommand.new(world.tick, 1, 0, 0, SimCommand.SPELL_HELD_BITS[0], 0, 0, -1000))
		_diagnostic_record(world.tick, received_inputs, commands, sent_rows)
		check(world.step(commands), "authority steps paid pressure despite delayed peers")
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "cast_started": paid[int(event.entity_id)] = true
		if tick % 2 == 0:
			var started := Time.get_ticks_usec()
			check(_publish(host, session), "every-other-tick publication satisfies the packet contract")
			captures.append(Time.get_ticks_usec() - started)
			for client: SessionTransport in clients: check(host.send_reconciliation(client.local_peer_id, session.capture_reconciliation(client.local_entity_id)), "movement correction uses matching authority")
		for index: int in clients.size():
			_consume(clients[index], predictions[index], buffers[index], replicas, index, world)
			check(predictions[index].pending_inputs.size() <= ClientPrediction.MAX_PENDING_INPUTS, "prediction history stays within48commands")
		OS.delay_msec(1)
	# Restore a healthy path, drain delayed sends, then publish one final exact pair.
	host.enabled = false
	host.advance(1000)
	for client: SessionTransport in clients: client.enabled = false; client.advance(1000)
	for unused: int in 12:
		host.poll()
		for client: SessionTransport in clients: client.poll()
		OS.delay_msec(1)
	diagnostic_phase = "healthy_final"
	diagnostic_loop_tick = 240
	var drained_inputs := host.take_inputs()
	session.ingest_inputs(drained_inputs)
	var final_commands := session.commands_for_tick(SimCommand.new(world.tick, 1))
	_diagnostic_record(world.tick, drained_inputs, final_commands, [])
	check(world.step(final_commands), "final authority consumes drained input")
	check(_publish(host, session), "healthy complete snapshot follows impairment")
	for client: SessionTransport in clients: check(host.send_reconciliation(client.local_peer_id, session.capture_reconciliation(client.local_entity_id)), "healthy correction follows impairment")
	for unused: int in 200:
		host.poll()
		for index: int in clients.size(): _consume(clients[index], predictions[index], buffers[index], replicas, index, world)
		if predictions.all(func(value: ClientPrediction) -> bool: return value.last_authoritative_tick == world.tick): break
		OS.delay_msec(1)
	for index: int in clients.size():
		equal(predictions[index].last_authoritative_tick, world.tick, "client catches up to exact final authority after recovery")
		equal(predictions[index].last_acknowledged_sequence, 239, "all reliable intents acknowledged after recovery")
		check(predictions[index].pending_inputs.is_empty(), "fully acknowledged prediction retains no stale commands")
		if replicas[index] != null: equal(replicas[index].state_hash(), world.state_hash(), "recovered full replica is byte-canonical host authority")
		equal(ClientPrediction.capture_packet(predictions[index].predicted_state, world.tick, 239).values, ClientPrediction.capture_packet(world.player(clients[index].local_entity_id), world.tick, 239).values, "recovered predicted actor equals actual host scalars")
		check(paid.has(clients[index].local_entity_id), "each remote actor actually paid for a cast")
		if bool(profile.outage): check(overflow_seen[index], "outage exercises the real48-command overflow boundary")
		equal((clients[index] as ImpairedTransport).send_failures, 0, "actual client socket sends did not fail behind injected delay")
	if int(profile.loss) > 0 or bool(profile.outage): check(host.dropped > 0, "impairment actually drops snapshot/correction packets")
	check(host.peak_queue <= ImpairedTransport.MAX_DELAYED, "injected packet queue remains bounded")
	equal(host.send_failures, 0, "actual host socket sends did not fail behind injected loss")
	captures.sort()
	print("IMPAIRMENT: players=%d profile=%s capture_send_p95_us=%d sent_bytes=%d dropped=%d queue_peak=%d; injected tick delay, not Internet RTT" % [count, profile.id, captures[int(captures.size() * 0.95)], host.sent_bytes, host.dropped, host.peak_queue])
	if bool(profile.outage):
		var returning := clients[0]
		var entity := returning.local_entity_id
		returning.stop()
		check(_poll_many_until(host, clients, func() -> bool: return host.reserved_count() == 1), "real disconnect reserves identity after impairment")
		check(returning.start_join("127.0.0.1", host.bound_port, _signature(), "Probe 0"), "returning client uses its existing token")
		check(_poll_many_until(host, clients, func() -> bool: return returning.is_connected_client()), "real ENet reconnect completes")
		equal(returning.local_entity_id, entity, "reconnect retains exact actor identity")
	for client: SessionTransport in clients: client.stop()
	host.stop()


func _publish(host: SessionTransport, session: AuthoritativeSession) -> bool:
	# The test transport subclass only intercepts the final send. Capture uses
	# the real callback-free production factory, not subclass dispatch fallback.
	var publication := SessionTransport._capture_session_packets(session)
	if diagnostic_phase == "initial" and not publication.is_empty():
		diagnostic_initial_envelope = (publication.envelope as Dictionary).duplicate(true)
	var published: bool = not publication.is_empty() and host._broadcast_encoded_packets(publication.packets)
	if not published and not diagnostic_first_failure:
		diagnostic_first_failure = true
		_diagnostic_publication_failure(host as ImpairedTransport, session, publication)
	return published


func _consume(client: SessionTransport, prediction: ClientPrediction, buffer: ReconciliationOrderBuffer, replicas: Array[SimWorld], index: int, trusted: SimWorld) -> void:
	client.poll()
	buffer.offer_many(client.take_reconciliations())
	for envelope: Dictionary in client.poll_envelopes():
		var prepared := Snapshot.prepare(envelope.authority, trusted)
		check(prepared != null, "received complete snapshot admits against trusted Hex world")
		if prepared != null: replicas[index] = prepared
	client.take_snapshots()
	if replicas[index] == null: return
	var packet := buffer.take_exact(client.world_epoch, replicas[index].tick)
	if not packet.is_empty():
		check(prediction.bind_hex_world(replicas[index]), "correction binds exact matching Hex geometry")
		check(prediction.reconcile(packet), "correction replays only against matching complete world")


func _diagnostic_record(tick: int, inputs: Array[Dictionary], commands: Array[SimCommand], sent: Array) -> void:
	# Exactly 240 impaired batches and one final drain. No transport tokens.
	if diagnostic_transcript.size() >= 241: return
	var rows: Array = []
	for command: SimCommand in commands: rows.append(command.canonical_bytes())
	diagnostic_transcript.append({"tick": tick, "loop_tick": diagnostic_loop_tick,
		"phase": diagnostic_phase, "inputs": inputs.duplicate(true),
		"commands": rows, "sent_inputs": sent.duplicate(true)})


func _diagnostic_publication_failure(host: ImpairedTransport, session: AuthoritativeSession, publication: Dictionary) -> void:
	var world: SimWorld = session.world
	var court: HexChemistryWorld = world.hex_court as HexChemistryWorld
	var context := {"schema": "hex.network-capture-failure.v1", "case": diagnostic_case,
		"phase": diagnostic_phase, "loop_tick": diagnostic_loop_tick, "world_tick": world.tick,
		"last_error": world.last_error, "publication_empty": publication.is_empty(),
		"queue_count": host.queued.size(), "queue_peak": host.peak_queue,
		"send_failures": host.send_failures, "trace_rows": diagnostic_transcript.size()}
	# Persist the small context before touching any deeper codec/relation validator.
	print("IMPAIRMENT_CAPTURE_FAILURE_CONTEXT " + JSON.stringify(context))
	var actors: Array = []
	for actor: PlayerState in world.players:
		actors.append({"values": actor.canonical_values(), "last_event": actor.last_event})
	var shots: Array = []
	for shot: ProjectileState in world.projectiles:
		shots.append({"values": shot.canonical_values(), "initial_strength": shot.initial_strength,
			"remaining_strength": shot.remaining_strength})
	var raw := {"context": context, "seed": world.seed, "map_id": world.map_id, "map_hash": world.map_hash,
		"next_ids": [world.next_projectile_id, world.next_field_id, world.next_deposit_id, world.next_reaction_id],
		"actors": actors, "projectiles": shots, "combat_events": world.combat_events.duplicate(true),
		"peer_entity": host.entity_by_peer.duplicate(true), "trace": diagnostic_transcript.duplicate(true),
		"initial_envelope": diagnostic_initial_envelope.duplicate(true),
		"latest_inputs": session.latest_input_by_entity.duplicate(true),
		"processed_sequences": session.last_processed_input_sequence_by_entity.duplicate(true)}
	if court != null:
		# Never read court.cells: that getter materializes sealed topology.
		raw["court"] = {"origin": court.origin, "tick": court.current_tick,
			"chemistry_enabled": court.chemistry_enabled, "casts": court.casts.duplicate(true),
			"products": court.products.duplicate(true), "pending": court.pending.duplicate(true),
			"sources": court.sources.duplicate(true), "exposure": court.exposure.duplicate(true),
			"flow_carry": court.flow_carry.duplicate(true), "sparse_cells": court._sparse_cells.duplicate(true),
			"legacy_cells": court._legacy_cells.duplicate(true), "metrics": court.metrics.duplicate(true),
			"next_ids": [court.next_cast_id, court.next_product_id, court.next_ground_part_id]}
	_diagnostic_emit_bytes(raw)
	# Each marker survives if a malformed relation record makes the next call fail.
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC trusted_world " + str(Snapshot._trusted_world_valid(world)))
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC producer_reuse " + str(Snapshot._producer_reuse_eligible(world)))
	for actor: PlayerState in world.players:
		print("IMPAIRMENT_CAPTURE_DIAGNOSTIC actor %d valid=%s" % [actor.entity_id, str(Snapshot._valid_player_values(actor.canonical_values()))])
	if court == null: return
	for shot: ProjectileState in world.projectiles:
		var ledger: Dictionary = court.ledger_for_source(shot.source_cast_id).duplicate(true)
		var ledger_valid: bool = not ledger.is_empty() and StrengthBudget.validate(ledger)
		var row := PackedInt32Array()
		if ledger_valid: row = Snapshot._capture_projectile(shot, ledger)
		print("IMPAIRMENT_CAPTURE_DIAGNOSTIC projectile %d ledger=%s row=%s" % [shot.entity_id, str(ledger_valid), str(not row.is_empty())])
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC begin_world_relations")
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC world_relations " + str(Snapshot._validate_relations(world)))
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC begin_chemistry_relations")
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC chemistry_relations " + str(DiagnosticChemistry._validate_relations(court)))
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC conservation " + str(court.conservation_valid()))
	var metadata: Dictionary = AuthoritativeSession._capture_hex_session_metadata(session)
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC session_shape " + str(not metadata.is_empty() and DiagnosticEnvelope._hex_session_shape_valid(metadata)))
	# Encoding only, not a second full-world capture or retry of the failed result.
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC begin_chemistry_encoding")
	var chemistry: Dictionary = DiagnosticChemistry._capture_for_outer_roundtrip(court)
	print("IMPAIRMENT_CAPTURE_DIAGNOSTIC chemistry_bytes=%d shape=%s" % [DiagnosticChemistry.encoded_size(chemistry), str(DiagnosticChemistry._snapshot_shape_valid(chemistry))])


func _diagnostic_emit_bytes(raw: Dictionary) -> void:
	var bytes: PackedByteArray = var_to_bytes(raw)
	const MAX_WITNESS_BYTES := 4 * 1024 * 1024
	if bytes.size() > MAX_WITNESS_BYTES:
		print("IMPAIRMENT_CAPTURE_WITNESS_OVERFLOW bytes=%d limit=%d" % [bytes.size(), MAX_WITNESS_BYTES])
		return
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(bytes)
	var digest: String = hasher.finish().hex_encode()
	var hex: String = bytes.hex_encode()
	var chunks: int = ceili(float(hex.length()) / 16384.0)
	print("IMPAIRMENT_CAPTURE_WITNESS_BEGIN bytes=%d chunks=%d sha256=%s" % [bytes.size(), chunks, digest])
	for index: int in chunks:
		print("IMPAIRMENT_CAPTURE_WITNESS_CHUNK %d/%d %s" % [index, chunks, hex.substr(index * 16384, 16384)])
	print("IMPAIRMENT_CAPTURE_WITNESS_END " + digest)

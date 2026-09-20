extends FluxTestSuite


const TEST_RUNTIME_SOURCE_HASH := "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
const OTHER_RUNTIME_SOURCE_HASH := "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
const SAME_DISPLAY_RUNTIME_SOURCE_HASH := "ddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"


func run() -> int:
	_test_validation_fails_closed()
	_test_runtime_identity_handshake_contract()
	_test_seven_client_hitch_input_fairness()
	_test_enet_loopback_handshake_and_input()
	_test_host_administration()
	_test_charter_assignment_and_capacity()
	_test_reconnect_identity_and_host_loss()
	return finish("session-transport")


func _signature(
	tick_rate: int = 120,
	protocol_version: int = SimConfig.PROTOCOL_VERSION,
	runtime_source_hash: String = TEST_RUNTIME_SOURCE_HASH,
) -> String:
	return SessionTransport.compatibility_signature(
		protocol_version,
		tick_rate,
		"a".repeat(64),
		"b".repeat(64),
		"c".repeat(64),
		"",
		"",
		runtime_source_hash,
	)


func _identity_manifest(
	runtime_source_hash: String = TEST_RUNTIME_SOURCE_HASH,
	protocol_version: int = SimConfig.PROTOCOL_VERSION,
) -> Dictionary:
	return {
		"schema_version": RuntimeBuildIdentity.SCHEMA_VERSION,
		"status": RuntimeBuildIdentity.STATUS,
		"scope_id": RuntimeBuildIdentity.SCOPE_ID,
		"canonical_encoding": RuntimeBuildIdentity.CANONICAL_ENCODING,
		"protocol_version": protocol_version,
		"snapshot_schema": SessionSnapshot.SCHEMA_VERSION,
		"engine_identity": RuntimeBuildIdentity.PINNED_ENGINE_IDENTITY,
		"record_count": 1,
		"runtime_source_sha256": runtime_source_hash,
		"build_id": "p%d-%s" % [protocol_version, runtime_source_hash.left(RuntimeBuildIdentity.SHORT_HASH_LENGTH)],
		"authority": RuntimeBuildIdentity.AUTHORITY,
	}


func _transport(runtime_source_hash: String = TEST_RUNTIME_SOURCE_HASH) -> SessionTransport:
	var transport := SessionTransport.new()
	transport.configure_runtime_identity(_identity_manifest(runtime_source_hash))
	return transport


func _test_validation_fails_closed() -> void:
	var transport := _transport()
	equal(SessionTransport.MAX_PLAYERS, 8, "public session cap is eight players")
	check(SessionCharter.catalog_hash().length() == 64, "session charter catalog contributes a bounded compatibility identity")
	equal(_signature().length(), 64, "compatibility identity is a SHA-256 digest")
	equal(_signature(), CanonicalContent.sha256({
		"protocol_version":SimConfig.PROTOCOL_VERSION, "snapshot_schema":SessionSnapshot.SCHEMA_VERSION, "tick_rate":120,
		"movement_hash":MovementTuning.compatibility_hash(), "transition_hash":ActionTransitionPolicy.repository_hash(),
		"map_hash":"a".repeat(64), "ability_hash":"b".repeat(64), "champion_hash":"c".repeat(64),
		"charter_catalog_hash":"", "reaction_hash":"", "runtime_source_sha256":TEST_RUNTIME_SOURCE_HASH,
		"snapshot_boundary_wall_ids":SessionSnapshot.WORLD_BOUNDARY_WALL_IDS,
		"world_snapshot_envelope_schema":WorldSnapshotEnvelope.SCHEMA_VERSION,
		"hex_world_snapshot_schema":HexWorldSnapshot.SCHEMA_VERSION,
	}), "compatibility digest explicitly binds snapshot schema and full runtime source")
	var old_boundary_signature := CanonicalContent.sha256({
		"protocol_version":SimConfig.PROTOCOL_VERSION, "tick_rate":120,
		"snapshot_schema":SessionSnapshot.SCHEMA_VERSION,
		"movement_hash":MovementTuning.compatibility_hash(), "transition_hash":ActionTransitionPolicy.repository_hash(),
		"map_hash":"a".repeat(64), "ability_hash":"b".repeat(64), "champion_hash":"c".repeat(64),
		"charter_catalog_hash":"", "reaction_hash":"",
		"runtime_source_sha256":TEST_RUNTIME_SOURCE_HASH,
	})
	check(_signature() != old_boundary_signature, "peers that reject legitimate boundary impacts cannot join this fixed build")
	var consolidation_q_signature := CanonicalContent.sha256({
		"protocol_version":SimConfig.PROTOCOL_VERSION, "tick_rate":120,
		"snapshot_schema":SessionSnapshot.SCHEMA_VERSION,
		"movement_hash":"0dc088623b40bc95be6d968423190a88a01624a4a855535b96a5aaa6c2bbef52",
		"transition_hash":ActionTransitionPolicy.repository_hash(),
		"map_hash":"a".repeat(64), "ability_hash":"b".repeat(64), "champion_hash":"c".repeat(64),
		"charter_catalog_hash":"", "reaction_hash":"",
		"runtime_source_sha256":TEST_RUNTIME_SOURCE_HASH,
		"snapshot_boundary_wall_ids":SessionSnapshot.WORLD_BOUNDARY_WALL_IDS,
	})
	check(_signature() != consolidation_q_signature, "otherwise matching consolidation peers cannot join with old neutral-airborne-Q semantics")
	check(_signature(120, SimConfig.PROTOCOL_VERSION - 1) != _signature(), "the retained protocol48 portable cannot share protocol49 compatibility")
	check(SessionTransport.compatibility_signature(SimConfig.PROTOCOL_VERSION, 120, "a".repeat(64), "b".repeat(64), "c".repeat(64), "d".repeat(64), "e".repeat(64), TEST_RUNTIME_SOURCE_HASH) != _signature(), "reaction definitions contribute to Farflow compatibility")
	check(not transport.start_host(80, _signature()), "privileged production host port is rejected")
	check(transport.last_error.contains("1024"), "invalid host port has an actionable error")
	check(not transport.start_join("bad address", SessionTransport.DEFAULT_PORT, _signature()), "address whitespace is rejected")
	check(not transport.start_join("127.0.0.1", 70000, _signature()), "out-of-range join port is rejected")
	check(not transport.start_host(0, "not-a-signature"), "malformed compatibility identity is rejected")
	check(not transport.start_host(0, _signature(), ""), "empty player name is rejected")
	check(not transport.start_host(0, _signature(), "Host", "forged"), "unknown host charter is rejected")
	check(not transport.start_join("127.0.0.1", SessionTransport.DEFAULT_PORT, _signature(), "Guest", "bad-hash"), "malformed join charter identity is rejected")
	check(not SessionTransport._valid_input_packet({"sequence": "0", "move_x": 0, "move_y": 0, "held": 0, "pressed": 0, "aim_x": 1000, "aim_y": 0}), "string-coerced input fields fail closed")
	var target_input := {"sequence": 0, "move_x": 0, "move_y": 0, "held": 0, "pressed": 0, "aim_x": 1000, "aim_y": 0, "aim_target_x": 100_000_000, "aim_target_y": 0}
	check(SessionTransport._valid_input_packet(target_input), "bounded world target endpoint validates")
	for target_value: Variant in [-2, 100_000_001, "12", 1.5]:
		var malformed := target_input.duplicate()
		malformed["aim_target_x"] = target_value
		check(not SessionTransport._valid_input_packet(malformed), "out-of-range or coerced target endpoint fails closed")
	for missing_key: String in ["aim_target_x", "aim_target_y"]:
		var malformed := target_input.duplicate()
		malformed.erase(missing_key)
		check(not SessionTransport._valid_input_packet(malformed), "half-present target pair fails closed")
	target_input["aim_target_x"] = -1
	check(not SessionTransport._valid_input_packet(target_input), "mixed unset and set target coordinates fail closed")
	target_input["aim_target_y"] = -1
	check(SessionTransport._valid_input_packet(target_input), "explicit untargeted direction input remains valid")
	check(SessionTransport._valid_request_packet({"sequence": 0, "action": SessionTransport.REQUEST_EMOTE, "value": 0}), "known typed interaction request validates")
	check(SessionTransport._valid_request_packet({"sequence": 1, "action": SessionTransport.REQUEST_READY_TOGGLE, "value": 0}), "typed Hearth readiness request validates")
	check(SessionTransport._valid_request_packet({"sequence": 2, "action": SessionTransport.REQUEST_PRACTICE_START, "value": 0}), "typed Hearth start request validates")
	check(SessionTransport._valid_request_packet({"sequence": 3, "action": SessionTransport.REQUEST_SPELL_EQUIP, "value": 768}), "typed final Spell Loom request validates")
	check(SessionTransport._valid_request_packet({"sequence": 4, "action": SessionTransport.REQUEST_IMPACT_PRACTICE, "value": 0}), "typed Momentum Chime request validates")
	equal(SessionTransport.REQUEST_CHAMPION_SELECT, 8, "exact champion selection has a stable distinct wire action")
	for value: int in [1, 5, 27, 4096]:
		check(SessionTransport._valid_request_packet({"sequence": 5, "action": SessionTransport.REQUEST_CHAMPION_SELECT, "value": value}), "bounded exact champion wire validates: %d" % value)
	for value: Variant in [0, -1, 4097, "2", 2.0, true, null]:
		check(not SessionTransport._valid_request_packet({"sequence": 5, "action": SessionTransport.REQUEST_CHAMPION_SELECT, "value": value}), "invalid/coerced champion wire fails closed: %s" % str(value))
	check(not SessionTransport._valid_request_packet({"sequence": 0, "action": 99, "value": 0}), "unknown interaction request fails closed")
	check(not SessionTransport._valid_request_packet({"sequence": "0", "action": SessionTransport.REQUEST_EMOTE, "value": 0}), "coerced interaction sequence fails closed")
	check(not SessionTransport._valid_request_packet({"sequence": 4, "action": SessionTransport.REQUEST_EMOTE, "value": 1}), "unrelated request cannot smuggle a value")
	var prediction_state := PlayerState.new(2)
	var reconciliation := ClientPrediction.capture_packet(prediction_state, 4, -1)
	check(ClientPrediction.validate_packet(reconciliation), "typed reconciliation packet validates")
	var malformed_reconciliation := reconciliation.duplicate(true)
	malformed_reconciliation["sequence"] = "0"
	check(not ClientPrediction.validate_packet(malformed_reconciliation), "coerced reconciliation acknowledgement fails closed")
	equal(SessionTransport.MAX_PACKETS_PER_POLL, 64, "transport processing has a per-poll work budget")
	equal(SessionTransport.MAX_QUEUED_INPUTS_PER_PEER, 4, "each remote has a bounded independent input lane")
	equal(SessionTransport.MAX_QUEUED_INPUTS, 28, "accepted input memory is bounded for seven remote peers")
	var return_token := SessionTransport._new_reconnect_token()
	check(SessionTransport._valid_reconnect_token(return_token), "host creates a typed 256-bit return token")
	check(not SessionTransport._valid_reconnect_token(return_token.to_upper()), "return token encoding fails closed on alternate case")
	check(not SessionTransport._valid_reconnect_token("a".repeat(62)), "short return token fails closed")
	equal(SessionTransport._validated_administration_reason("  Company closed  "), "Company closed", "administration reason is bounded and trimmed")
	equal(SessionTransport._validated_administration_reason(""), "", "empty administration reason fails closed")
	equal(SessionTransport._validated_administration_reason("x".repeat(SessionTransport.MAX_ADMIN_REASON_LENGTH + 1)), "", "oversized administration reason fails closed")
	equal(SessionTransport._validated_administration_reason("bad\nreason"), "", "control characters fail closed in administration reasons")


func _test_runtime_identity_handshake_contract() -> void:
	equal(SimConfig.PROTOCOL_VERSION, 54, "remote hex-clash semantics own the explicit protocol54 boundary")
	var local := _transport()
	equal(local.runtime_source_sha256, TEST_RUNTIME_SOURCE_HASH, "configured transport exposes the full validated local source identity")
	equal(local.build_id, "p%d-%s" % [SimConfig.PROTOCOL_VERSION, TEST_RUNTIME_SOURCE_HASH.left(12)], "configured transport exposes only the derived short display identity")
	local.stop()
	equal(local.runtime_source_sha256, TEST_RUNTIME_SOURCE_HASH, "stop preserves the validated full local source identity")
	equal(local.build_id, "p%d-%s" % [SimConfig.PROTOCOL_VERSION, TEST_RUNTIME_SOURCE_HASH.left(12)], "stop preserves the local display identity for retry and diagnostics")

	var malformed_manifest := _identity_manifest()
	malformed_manifest["runtime_source_sha256"] = TEST_RUNTIME_SOURCE_HASH.to_upper()
	check(not local.configure_runtime_identity(malformed_manifest), "malformed configured identity fails closed")
	check(local.runtime_source_sha256.is_empty() and local.build_id.is_empty(), "failed identity configuration exposes no stale authority identity")

	var source_signature := _signature()
	var same_display_signature := _signature(120, SimConfig.PROTOCOL_VERSION, SAME_DISPLAY_RUNTIME_SOURCE_HASH)
	check(source_signature != same_display_signature, "the full source hash contributes to the semantic compatibility signature")
	equal(
		_identity_manifest()["build_id"],
		_identity_manifest(SAME_DISPLAY_RUNTIME_SOURCE_HASH)["build_id"],
		"synthetic full hashes can share a short display ID so that ID cannot be authority",
	)
	check(SessionTransport._valid_build_identity(SimConfig.PROTOCOL_VERSION, TEST_RUNTIME_SOURCE_HASH, String(_identity_manifest()["build_id"])), "derived local identity validates")
	check(not SessionTransport._valid_build_identity(SimConfig.PROTOCOL_VERSION, TEST_RUNTIME_SOURCE_HASH, "p49-ffffffffffff"), "friendly display text cannot replace full identity derivation")

	var mismatch_message := SessionTransport.reject_message(
		SessionTransport.REJECT_BUILD_MISMATCH,
		String(_identity_manifest(OTHER_RUNTIME_SOURCE_HASH)["build_id"]),
		String(_identity_manifest()["build_id"]),
	)
	check(mismatch_message.contains(String(_identity_manifest(OTHER_RUNTIME_SOURCE_HASH)["build_id"])), "local mismatch copy names the bounded host display ID")
	check(mismatch_message.contains(String(_identity_manifest()["build_id"])), "local mismatch copy names the bounded player display ID")
	check(mismatch_message.contains("same complete portable ZIP") and mismatch_message.contains("new folder") and mismatch_message.contains("older installed shortcut"), "local mismatch copy gives same-ZIP recovery and the stale-shortcut warning")
	check(mismatch_message.length() <= SessionTransport.MAX_REJECT_MESSAGE_LENGTH, "localized mismatch copy has a hard display bound")
	var hostile_message := SessionTransport.reject_message(SessionTransport.REJECT_BUILD_MISMATCH, "<remote prose>", "also unsafe")
	check(not hostile_message.contains("remote prose") and hostile_message.contains("host unknown") and hostile_message.contains("yours unknown"), "rejection copy never reflects arbitrary remote prose")

	var hello := {
		"kind": SessionTransport.PACKET_HELLO,
		"protocol_version": SimConfig.PROTOCOL_VERSION,
		"signature": _signature(),
		"runtime_source_sha256": TEST_RUNTIME_SOURCE_HASH,
		"build_id": String(_identity_manifest()["build_id"]),
		"name": "Typed Guest",
		"reconnect_token": "",
		"charter_catalog_hash": SessionCharter.catalog_hash(),
	}
	check(SessionTransport._valid_hello_packet(hello), "strict fully typed HELLO validates")
	for field: String in SessionTransport.HELLO_FIELDS:
		var missing := hello.duplicate()
		missing.erase(field)
		check(not SessionTransport._valid_hello_packet(missing), "HELLO fails closed when %s is missing" % field)
	var extra_hello := hello.duplicate()
	extra_hello["friendly_build"] = "same-ish"
	check(not SessionTransport._valid_hello_packet(extra_hello), "HELLO rejects undeclared compatibility fields")
	for coerced_protocol: Variant in [str(SimConfig.PROTOCOL_VERSION), float(SimConfig.PROTOCOL_VERSION), true]:
		var coerced := hello.duplicate()
		coerced["protocol_version"] = coerced_protocol
		check(not SessionTransport._valid_hello_packet(coerced), "HELLO rejects a coerced protocol field")

	# ACCEPT identity is checked before any roster, charter, entity or reconnect
	# mutation. These two full hashes intentionally share one display ID.
	var forged_accept_client := _transport()
	forged_accept_client.mode = SessionTransport.Mode.CONNECTING
	forged_accept_client.local_peer_id = 22
	forged_accept_client.session_signature = _signature()
	var forged_accept := _accept_packet(22, SAME_DISPLAY_RUNTIME_SOURCE_HASH, _signature(120, SimConfig.PROTOCOL_VERSION, SAME_DISPLAY_RUNTIME_SOURCE_HASH))
	forged_accept_client._handle_packet(SessionTransport.SERVER_PEER_ID, var_to_bytes(forged_accept))
	check(not forged_accept_client.accepted and forged_accept_client.local_entity_id == 0, "same display ID with a different full source hash cannot mutate client admission")
	check(forged_accept_client.last_error.contains("same complete portable ZIP"), "forged full identity receives only trusted local recovery copy")
	var signature_accept_client := _transport()
	signature_accept_client.mode = SessionTransport.Mode.CONNECTING
	signature_accept_client.local_peer_id = 23
	signature_accept_client.session_signature = _signature()
	signature_accept_client._handle_packet(SessionTransport.SERVER_PEER_ID, var_to_bytes(_accept_packet(23, TEST_RUNTIME_SOURCE_HASH, _signature(60))))
	check(not signature_accept_client.accepted and signature_accept_client.local_entity_id == 0, "ACCEPT semantic-signature mismatch fails before client admission mutation")

	var protocol_accept_client := _transport()
	protocol_accept_client.mode = SessionTransport.Mode.CONNECTING
	protocol_accept_client.local_peer_id = 24
	protocol_accept_client.session_signature = _signature()
	var protocol_accept := _accept_packet(24, TEST_RUNTIME_SOURCE_HASH, _signature())
	protocol_accept["protocol_version"] = SimConfig.PROTOCOL_VERSION - 1
	protocol_accept["build_id"] = String(_identity_manifest(TEST_RUNTIME_SOURCE_HASH, SimConfig.PROTOCOL_VERSION - 1)["build_id"])
	protocol_accept_client._handle_packet(SessionTransport.SERVER_PEER_ID, var_to_bytes(protocol_accept))
	check(not protocol_accept_client.accepted and protocol_accept_client.local_entity_id == 0, "ACCEPT protocol mismatch fails before client admission mutation")
	check(protocol_accept_client.last_error.contains("same complete portable ZIP"), "ACCEPT protocol mismatch uses the same bounded recovery guidance")

	var coerced_accept_client := _transport()
	coerced_accept_client.mode = SessionTransport.Mode.CONNECTING
	coerced_accept_client.local_peer_id = 25
	coerced_accept_client.session_signature = _signature()
	var coerced_accept := _accept_packet(25, TEST_RUNTIME_SOURCE_HASH, _signature())
	coerced_accept["protocol_version"] = str(SimConfig.PROTOCOL_VERSION)
	coerced_accept_client._handle_packet(SessionTransport.SERVER_PEER_ID, var_to_bytes(coerced_accept))
	check(not coerced_accept_client.accepted and coerced_accept_client.local_entity_id == 0, "coerced ACCEPT identity fails before client admission mutation")
	check(coerced_accept_client.last_error.contains("malformed") and not coerced_accept_client.last_error.contains(str(coerced_accept)), "malformed ACCEPT exposes only fixed local text")

	var untrusted_reject_client := _transport()
	untrusted_reject_client.mode = SessionTransport.Mode.CONNECTING
	untrusted_reject_client._handle_packet(SessionTransport.SERVER_PEER_ID, var_to_bytes({"kind": SessionTransport.PACKET_REJECT, "reason": "REMOTE PROSE"}))
	check(untrusted_reject_client.mode == SessionTransport.Mode.OFFLINE, "narrowly typed protocol47 rejection ends the new client's connection without a timeout")
	check(untrusted_reject_client.last_error.contains("same complete portable ZIP") and untrusted_reject_client.last_error.contains("host unknown"), "legacy rejection receives fixed local recovery without inventing a host build ID")
	check(not untrusted_reject_client.last_error.contains("REMOTE PROSE"), "legacy rejection never reflects the old host's arbitrary reason text")
	var oversized_legacy_reject := {"kind": SessionTransport.PACKET_REJECT, "reason": "x".repeat(SessionTransport.MAX_ADMIN_REASON_LENGTH + 1)}
	check(not SessionTransport._valid_legacy_reject_packet(oversized_legacy_reject), "legacy rejection recognition remains narrowly bounded")


func _accept_packet(peer_id: int, runtime_source_hash: String, signature: String) -> Dictionary:
	return {
		"kind": SessionTransport.PACKET_ACCEPT,
		"protocol_version": SimConfig.PROTOCOL_VERSION,
		"signature": signature,
		"runtime_source_sha256": runtime_source_hash,
		"build_id": String(_identity_manifest(runtime_source_hash)["build_id"]),
		"peer_id": peer_id,
		"entity_id": 2,
		"player_count": 2,
		"reconnect_token": "a".repeat(SessionTransport.RECONNECT_TOKEN_BYTES * 2),
		"resumed": false,
		"charter_id": SessionCharter.DEFAULT_ID,
		"charter_hash": SessionCharter.profile_hash(SessionCharter.DEFAULT_ID),
		"maximum_players": SessionCharter.maximum_players(SessionCharter.DEFAULT_ID),
	}


func _test_seven_client_hitch_input_fairness() -> void:
	var host := _transport()
	var clients: Array[SessionTransport] = []
	check(host.start_host(0, _signature(), "Hitch Host"), "seven-client hitch host binds: %s" % host.last_error)
	for client_index: int in range(SessionTransport.MAX_REMOTE_CLIENTS):
		var client := _transport()
		clients.append(client)
		check(
			client.start_join("127.0.0.1", host.bound_port, _signature(), "Burst %d" % (client_index + 1)),
			"burst client %d seeks the hitch host: %s" % [client_index + 1, client.last_error],
		)
	check(
		_poll_many_until(host, clients, func() -> bool: return _all_clients_connected(clients)),
		"all seven remote entry paths complete before the hitch burst",
	)
	_establish_world_epoch(host, clients)
	equal(host.player_count(), SessionTransport.MAX_PLAYERS, "hitch fixture reaches the supported eight-player session")
	host.take_joined_peers()

	var expected_pressed := SimCommand.PRESSED_JUMP | SimCommand.PRESSED_EVADE | SimCommand.PRESSED_SPELL_1
	var expected_held := SimCommand.HELD_SPRINT | SimCommand.HELD_PRIMARY
	for client_index: int in range(clients.size()):
		var client := clients[client_index]
		var commands: Array[SimCommand] = [
			SimCommand.new(0, client.local_entity_id, 100, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, 1000, 0),
			SimCommand.new(0, client.local_entity_id, 200, 0, SimCommand.HELD_SPRINT, SimCommand.PRESSED_EVADE, 1000, 0),
			SimCommand.new(0, client.local_entity_id, 300, 0, SimCommand.HELD_PRIMARY, 0, 1000, 0),
			SimCommand.new(0, client.local_entity_id, 400, 0, SimCommand.HELD_PRIMARY, SimCommand.PRESSED_SPELL_1, 1000, 0),
			SimCommand.new(0, client.local_entity_id, 500 + client_index, -500 - client_index, expected_held, 0, 0, -1000),
		]
		for command_index: int in range(commands.size()):
			var command := commands[command_index]
			command.aim_target_x = 1_000_000 + client_index
			command.aim_target_y = 700_000 - client_index
			check(client.send_input(command_index + 1, command), "client %d sends hitch input %d" % [client_index + 1, command_index + 1])

	# All five reliable packets per client queue before host polling resumes. The
	# drain still feeds only the next real authority tick; no backlog adds sim time.
	for _poll_index: int in range(100):
		host.poll()
		for client: SessionTransport in clients:
			client.poll()
		OS.delay_msec(1)
	var retained := host.take_inputs()
	check(retained.size() <= SessionTransport.MAX_QUEUED_INPUTS, "seven-client burst stays inside the total input memory bound")
	var lanes_by_entity: Dictionary[int, Dictionary] = {}
	for packet: Dictionary in retained:
		var entity_id := int(packet.get("entity_id", 0))
		var lane: Dictionary = lanes_by_entity.get(entity_id, {"count": 0, "pressed": 0, "latest": {}})
		lane["count"] = int(lane["count"]) + 1
		lane["pressed"] = int(lane["pressed"]) | int(packet.get("pressed", 0))
		var latest: Dictionary = lane["latest"]
		if latest.is_empty() or int(packet.get("sequence", -1)) > int(latest.get("sequence", -1)):
			lane["latest"] = packet
		lanes_by_entity[entity_id] = lane
	for client_index: int in range(clients.size()):
		var entity_id := clients[client_index].local_entity_id
		var lane: Dictionary = lanes_by_entity.get(entity_id, {})
		check(not lane.is_empty(), "client %d retains a fair command lane" % (client_index + 1))
		if lane.is_empty():
			continue
		check(int(lane.get("count", 0)) <= SessionTransport.MAX_QUEUED_INPUTS_PER_PEER, "client %d cannot consume another peer's bounded lane" % (client_index + 1))
		check((int(lane.get("pressed", 0)) & expected_pressed) == expected_pressed, "client %d retains jump, evade and cast edges" % (client_index + 1))
		var latest: Dictionary = lane.get("latest", {})
		equal(int(latest.get("sequence", -1)), 5, "client %d retains its newest hitch sequence" % (client_index + 1))
		equal(int(latest.get("held", 0)), expected_held, "client %d resolves held actions to its newest input" % (client_index + 1))
		equal(Vector2i(int(latest.get("move_x", 0)), int(latest.get("move_y", 0))), Vector2i(500 + client_index, -500 - client_index), "client %d resolves movement to its newest input" % (client_index + 1))
		equal(Vector2i(int(latest.get("aim_x", 0)), int(latest.get("aim_y", 0))), Vector2i(0, -1000), "client %d resolves aim to its newest input" % (client_index + 1))
		equal(Vector2i(int(latest.get("aim_target_x", -1)), int(latest.get("aim_target_y", -1))), Vector2i(1_000_000 + client_index, 700_000 - client_index), "client %d retains its newest world aim target" % (client_index + 1))

	# One abusive sender queues more than a whole poll budget before six ordinary
	# peers send. Per-peer admission must keep the quiet lanes live and eventually
	# reach every newest sequence over subsequent bounded polls.
	var noisy_final_sequence := SessionTransport.MAX_PACKETS_PER_POLL + 20
	var all_asymmetric_inputs_sent := true
	for sequence: int in range(6, noisy_final_sequence + 1):
		var pressed := SimCommand.PRESSED_JUMP if sequence == 6 else (SimCommand.PRESSED_EVADE if sequence == 7 else (SimCommand.PRESSED_SPELL_1 if sequence == 8 else 0))
		var command := SimCommand.new(0, clients[0].local_entity_id, sequence, -sequence, expected_held, pressed, 0, -1000)
		command.aim_target_x = 2_000_000 + sequence
		command.aim_target_y = 600_000 - sequence
		all_asymmetric_inputs_sent = clients[0].send_input(sequence, command) and all_asymmetric_inputs_sent
	for client_index: int in range(1, clients.size()):
		for sequence: int in range(6, 11):
			var pressed := SimCommand.PRESSED_JUMP if sequence == 6 else (SimCommand.PRESSED_EVADE if sequence == 7 else (SimCommand.PRESSED_SPELL_1 if sequence == 8 else 0))
			var command := SimCommand.new(0, clients[client_index].local_entity_id, 700 + client_index, -700 - client_index, expected_held, pressed, 0, -1000)
			command.aim_target_x = 2_100_000 + client_index
			command.aim_target_y = 500_000 - client_index
			all_asymmetric_inputs_sent = clients[client_index].send_input(sequence, command) and all_asymmetric_inputs_sent
	check(all_asymmetric_inputs_sent, "asymmetric hitch queues more input than one host poll budget")
	check(noisy_final_sequence > SessionTransport.MAX_PACKETS_PER_POLL, "noisy fixture crosses the explicit per-poll work cap")
	for _poll_index: int in range(160):
		host.poll()
		for client: SessionTransport in clients:
			client.poll()
		OS.delay_msec(1)
	var asymmetric_retained := host.take_inputs()
	check(asymmetric_retained.size() <= SessionTransport.MAX_QUEUED_INPUTS, "asymmetric burst remains inside the total input memory bound")
	var asymmetric_lanes: Dictionary[int, Dictionary] = {}
	for packet: Dictionary in asymmetric_retained:
		var entity_id := int(packet.get("entity_id", 0))
		var lane: Dictionary = asymmetric_lanes.get(entity_id, {"count": 0, "pressed": 0, "latest": {}})
		lane["count"] = int(lane["count"]) + 1
		lane["pressed"] = int(lane["pressed"]) | int(packet.get("pressed", 0))
		var latest: Dictionary = lane["latest"]
		if latest.is_empty() or int(packet.get("sequence", -1)) > int(latest.get("sequence", -1)):
			lane["latest"] = packet
		asymmetric_lanes[entity_id] = lane
	for client_index: int in range(clients.size()):
		var entity_id := clients[client_index].local_entity_id
		var lane: Dictionary = asymmetric_lanes.get(entity_id, {})
		check(not lane.is_empty(), "asymmetric burst preserves client %d's lane" % (client_index + 1))
		if lane.is_empty():
			continue
		check(int(lane.get("count", 0)) <= SessionTransport.MAX_QUEUED_INPUTS_PER_PEER, "asymmetric client %d stays inside its lane cap" % (client_index + 1))
		check((int(lane.get("pressed", 0)) & expected_pressed) == expected_pressed, "asymmetric client %d retains jump, evade and cast edges" % (client_index + 1))
		var latest: Dictionary = lane.get("latest", {})
		var expected_sequence := noisy_final_sequence if client_index == 0 else 10
		equal(int(latest.get("sequence", -1)), expected_sequence, "asymmetric client %d eventually reaches its newest sequence" % (client_index + 1))
		if client_index == 0:
			equal(Vector2i(int(latest.get("move_x", 0)), int(latest.get("move_y", 0))), Vector2i(noisy_final_sequence, -noisy_final_sequence), "noisy lane still resolves continuous state to its newest packet")
		else:
			equal(Vector2i(int(latest.get("move_x", 0)), int(latest.get("move_y", 0))), Vector2i(700 + client_index, -700 - client_index), "quiet client %d retains newest continuous state despite noisy-first admission" % (client_index + 1))

	var all_replays_sent := true
	for client_index: int in range(clients.size()):
		var latest_sequence := noisy_final_sequence if client_index == 0 else 10
		var replay_sequence := latest_sequence if client_index % 2 == 0 else latest_sequence - 1
		var replay := SimCommand.new(0, clients[client_index].local_entity_id, -999, 999, 0, SimCommand.PRESSED_ACTIVE_1, -1000, 0)
		all_replays_sent = clients[client_index].send_input(replay_sequence, replay) and all_replays_sent
	check(all_replays_sent, "clients can send replayed and stale sequences to the host rejection boundary")
	for _poll_index: int in range(40):
		host.poll()
		for client: SessionTransport in clients:
			client.poll()
		OS.delay_msec(1)
	check(host.take_inputs().is_empty(), "stale and replayed sequences cannot re-enter any peer lane")

	# A disconnected sender cannot leave an action edge queued for an entity that
	# later returns on a new ENet peer id. The returned lane starts bounded and clean.
	var returning_client: SessionTransport = clients.back()
	var returning_entity_id := returning_client.local_entity_id
	var pending_before_disconnect := SimCommand.new(0, returning_entity_id, 901, -901, SimCommand.HELD_JUMP, SimCommand.PRESSED_SPELL_1, 1000, 0)
	check(returning_client.send_input(11, pending_before_disconnect), "returning client queues an input before disconnect")
	var pending_lane_received := func() -> bool:
		for packet: Dictionary in host.incoming_inputs:
			if int(packet.get("entity_id", 0)) == returning_entity_id:
				return true
		return false
	check(
		_poll_many_until(host, clients, pending_lane_received),
		"host holds the returning client's pending lane before disconnect",
	)
	returning_client.stop()
	check(
		_poll_many_until(host, clients, func() -> bool: return host.player_count() == SessionTransport.MAX_PLAYERS - 1 and host.reserved_count() == 1),
		"host observes the disconnect and reserves the exact returning entity",
	)
	check(host.take_inputs().is_empty(), "disconnect purges the old peer's pending lane and cast edge")
	check(returning_client.start_join("127.0.0.1", host.bound_port, _signature(), "Burst 7"), "reserved client begins a bounded return")
	check(
		_poll_many_until(host, clients, func() -> bool: return _all_clients_connected(clients)),
		"reserved client returns on a replacement ENet peer",
	)
	_establish_world_epoch(host, clients)
	equal(returning_client.local_entity_id, returning_entity_id, "return keeps the authoritative entity without keeping its stale input lane")
	var resumed_events := host.take_joined_peers()
	check(not resumed_events.is_empty() and bool(resumed_events.back().get("resumed", false)), "host identifies the replacement peer as an exact return")
	var fresh_after_return := SimCommand.new(0, returning_entity_id, 902, -902, SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP, 0, -1000)
	check(returning_client.send_input(1, fresh_after_return), "returned peer starts a fresh monotonic input lane")
	check(
		_poll_many_until(host, clients, func() -> bool: return not host.incoming_inputs.is_empty()),
		"returned peer's fresh input reaches the host",
	)
	var returned_inputs := host.take_inputs()
	equal(returned_inputs.size(), 1, "returned peer owns one clean bounded input record")
	if not returned_inputs.is_empty():
		equal(int(returned_inputs[0].get("entity_id", 0)), returning_entity_id, "fresh return input retains the reclaimed entity")
		equal(int(returned_inputs[0].get("sequence", -1)), 1, "replacement peer sequence state starts fresh")
		equal(int(returned_inputs[0].get("pressed", 0)), SimCommand.PRESSED_JUMP, "old queued cast edge cannot leak into the returned peer's first command")
	check(returned_inputs.size() <= SessionTransport.MAX_QUEUED_INPUTS, "return lane remains inside the global resource bound")
	for client: SessionTransport in clients:
		client.stop()
	host.stop()


func _test_enet_loopback_handshake_and_input() -> void:
	var host := _transport()
	var client := _transport()
	check(host.start_host(0, _signature(), "Lantern Host"), "loopback host binds an automatic UDP port: %s" % host.last_error)
	check(host.bound_port >= 1024, "automatic host exposes its actual unprivileged port")
	check(client.start_join("127.0.0.1", host.bound_port, _signature(), "River Guest"), "loopback client begins joining: %s" % client.last_error)
	check(_poll_until(host, client, func() -> bool: return client.is_connected_client()), "compatible loopback client completes handshake")
	check(not client.send_input(1, SimCommand.new(0, client.local_entity_id)), "handshake alone cannot authorize input before a complete world epoch")
	_establish_world_epoch(host, [client])
	equal(client.runtime_source_sha256, host.runtime_source_sha256, "accepted peers retain the same full runtime source identity")
	equal(client.remote_build_id, host.build_id, "accepted client stores the host-reported protected display ID")
	check(host.is_host(), "host remains authoritative after client handshake")
	equal(host.session_charter_id, SessionCharter.DEFAULT_ID, "host opens with the safe social charter")
	equal(client.session_charter_id, SessionCharter.DEFAULT_ID, "client receives the host charter during acceptance")
	equal(client.player_capacity(), 8, "client receives the charter capacity from host authority")
	equal(host.player_count(), 2, "host counts itself plus accepted client")
	check(client.local_peer_id > SessionTransport.SERVER_PEER_ID, "client receives a positive non-host peer id")
	equal(client.local_entity_id, 2, "first guest receives stable session entity two")
	var joined := host.take_joined_peers()
	equal(joined.size(), 1, "host exposes one accepted presence event")
	if not joined.is_empty():
		equal(int(joined[0].get("entity_id", 0)), 2, "presence event owns the stable entity mapping")
		equal(String(joined[0].get("name", "")), "River Guest", "presence event carries the validated display name")

	var invalid_high_sequence := {
		"kind": SessionTransport.PACKET_INPUT,
		"sequence": 0x80000000,
		"move_x": 0,
		"move_y": 0,
		"held": 0,
		"pressed": SimCommand.PRESSED_ACTIVE_1,
		"aim_x": 1000,
		"aim_y": 0,
	}
	host._handle_packet(client.local_peer_id, var_to_bytes(invalid_high_sequence))
	check(host.incoming_inputs.is_empty(), "invalid high sequence fails closed at the host packet handler")
	equal(int(host.last_input_sequence_by_peer.get(client.local_peer_id, -1)), -1, "invalid high sequence cannot poison the peer watermark")
	var command := SimCommand.new(0, 1, 700, -300, SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP, 1000, 0)
	command.aim_target_x = 876_543
	command.aim_target_y = 456_789
	check(client.send_input(17, command), "accepted client sends a bounded input packet")
	check(_poll_until(host, client, func() -> bool: return not host.incoming_inputs.is_empty()), "host receives client input through ENet")
	var inputs: Array[Dictionary] = host.take_inputs()
	equal(inputs.size(), 1, "host drains one validated input")
	if not inputs.is_empty():
		equal(int(inputs[0].get("sequence", -1)), 17, "input sequence survives transport")
		equal(int(inputs[0].get("move_x", 0)), 700, "input movement survives transport")
		equal(Vector2i(int(inputs[0].get("aim_target_x", -1)), int(inputs[0].get("aim_target_y", -1))), Vector2i(876_543, 456_789), "locked world target survives real ENet input transport exactly")
		equal(int(inputs[0].get("peer_id", 0)), client.local_peer_id, "host stamps trusted sender identity")
		equal(int(inputs[0].get("entity_id", 0)), client.local_entity_id, "host stamps the trusted simulation entity")
	check(host.take_inputs().is_empty(), "host input drain is single-consumer")
	var direction_inputs: Array[Dictionary] = []
	for direction_index: int in range(EightDirectionResolver.DIRECTION_ORDER.size()):
		var fixed := EightDirectionResolver.FIXED_VECTORS[direction_index]
		var direction_command := SimCommand.new(0, 1, fixed.x, fixed.y, 0, 0, fixed.x, fixed.y)
		check(client.send_input(18 + direction_index, direction_command), "%s input enters Farflow" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
		if (direction_index + 1) % SessionTransport.MAX_QUEUED_INPUTS_PER_PEER == 0:
			check(
				_poll_until(host, client, func() -> bool: return host.incoming_inputs.size() == SessionTransport.MAX_QUEUED_INPUTS_PER_PEER),
				"host receives bounded direction batch %d" % int((direction_index + 1) / SessionTransport.MAX_QUEUED_INPUTS_PER_PEER),
			)
			direction_inputs.append_array(host.take_inputs())
	equal(direction_inputs.size(), EightDirectionResolver.DIRECTION_ORDER.size(), "Farflow drains exactly eight directional inputs")
	var direction_by_sequence := {}
	for packet: Dictionary in direction_inputs:
		direction_by_sequence[int(packet.get("sequence", -1))] = packet
	for direction_index: int in range(EightDirectionResolver.DIRECTION_ORDER.size()):
		var sequence := 18 + direction_index
		var fixed := EightDirectionResolver.FIXED_VECTORS[direction_index]
		var packet: Dictionary = direction_by_sequence.get(sequence, {})
		equal(Vector2i(int(packet.get("move_x", 0)), int(packet.get("move_y", 0))), fixed, "%s movement survives Farflow exactly" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
		equal(Vector2i(int(packet.get("aim_x", 0)), int(packet.get("aim_y", 0))), fixed, "%s aim survives Farflow exactly" % EightDirectionResolver.DIRECTION_ORDER[direction_index])
	check(client.send_input(17, command), "client can retransmit but cannot authorize a repeated sequence")
	for _index: int in range(20):
		host.poll()
		client.poll()
		OS.delay_msec(1)
	check(host.take_inputs().is_empty(), "host drops replayed input sequences")
	check(client.send_request(4, SessionTransport.REQUEST_EMOTE), "client sends a bounded reliable interaction intent")
	check(_poll_until(host, client, func() -> bool: return not host.incoming_requests.is_empty()), "host receives interaction intent through ENet")
	var requests := host.take_requests()
	equal(requests.size(), 1, "host drains one validated interaction intent")
	if not requests.is_empty():
		equal(int(requests[0].get("entity_id", 0)), client.local_entity_id, "host stamps trusted request entity")
		equal(int(requests[0].get("action", 0)), SessionTransport.REQUEST_EMOTE, "request action survives transport")
	check(client.send_request(4, SessionTransport.REQUEST_EMOTE), "client retransmit reaches replay boundary")
	for _index: int in range(20):
		host.poll()
		client.poll()
		OS.delay_msec(1)
	check(host.take_requests().is_empty(), "host drops replayed interaction sequence")
	check(client.send_request(5, SessionTransport.REQUEST_READY_TOGGLE), "client sends a monotonic Hearth request")
	check(_poll_until(host, client, func() -> bool: return not host.incoming_requests.is_empty()), "host receives Hearth request through reliable ENet")
	var hearth_requests := host.take_requests()
	equal(int(hearth_requests[0].get("action", 0)) if not hearth_requests.is_empty() else 0, SessionTransport.REQUEST_READY_TOGGLE, "Hearth action survives trusted request stamping")
	check(client.send_request(6, SessionTransport.REQUEST_SPELL_EQUIP, 768), "client sends a bounded Spell Loom weave")
	check(_poll_until(host, client, func() -> bool: return not host.incoming_requests.is_empty()), "host receives Spell Loom weave through reliable ENet")
	var spell_requests := host.take_requests()
	equal(int(spell_requests[0].get("value", 0)) if not spell_requests.is_empty() else 0, 768, "host receives the bounded slot/library value")
	check(client.send_request(7, SessionTransport.REQUEST_IMPACT_PRACTICE), "client sends a bounded Momentum Chime intent")
	check(_poll_until(host, client, func() -> bool: return not host.incoming_requests.is_empty()), "host receives Momentum Chime intent through reliable ENet")
	var impact_requests := host.take_requests()
	equal(int(impact_requests[0].get("action", 0)) if not impact_requests.is_empty() else 0, SessionTransport.REQUEST_IMPACT_PRACTICE, "Momentum Chime action survives trusted request stamping")
	check(not client.send_request(8, SessionTransport.REQUEST_SPELL_EQUIP, 769), "out-of-range Spell Loom value fails before transport")
	check(client.send_request(8, SessionTransport.REQUEST_CHAMPION_SELECT, 27), "client sends exact champion identity, not a cycle offset")
	check(_poll_until(host, client, func() -> bool: return not host.incoming_requests.is_empty()), "host receives exact champion selection through reliable ENet")
	var champion_requests := host.take_requests()
	equal(champion_requests.size(), 1, "exact champion request arrives once")
	if not champion_requests.is_empty():
		equal(int(champion_requests[0].get("action", 0)), SessionTransport.REQUEST_CHAMPION_SELECT, "exact action survives transport")
		equal(int(champion_requests[0].get("value", 0)), 27, "exact requested champion survives transport")
		equal(int(champion_requests[0].get("entity_id", 0)), client.local_entity_id, "host stamps trusted champion selection owner")
	check(client.send_request(8, SessionTransport.REQUEST_CHAMPION_SELECT, 1), "replayed sequence cannot choose a different champion")
	for _index: int in range(20):
		host.poll()
		client.poll()
		OS.delay_msec(1)
	check(host.take_requests().is_empty(), "exact selection replay is discarded before application")

	var incompatible := _transport()
	check(incompatible.start_join("127.0.0.1", host.bound_port, _signature(60), "Old Build"), "incompatible client reaches handshake boundary")
	check(_poll_until(host, incompatible, func() -> bool: return incompatible.mode == SessionTransport.Mode.OFFLINE and not incompatible.last_error.is_empty()), "incompatible session is rejected deterministically")
	check(incompatible.last_error.contains("same complete portable ZIP"), "semantic-signature mismatch gives trusted same-ZIP recovery")
	equal(host.player_count(), 2, "rejected client never enters authoritative roster")

	var different_source := _transport(OTHER_RUNTIME_SOURCE_HASH)
	check(different_source.start_join("127.0.0.1", host.bound_port, _signature(120, SimConfig.PROTOCOL_VERSION, OTHER_RUNTIME_SOURCE_HASH), "Diff Source"), "different full-source client reaches the identity boundary")
	check(_poll_until(host, different_source, func() -> bool: return different_source.mode == SessionTransport.Mode.OFFLINE and not different_source.last_error.is_empty()), "different full source is rejected over real ENet")
	check(different_source.last_error.contains(host.build_id) and different_source.last_error.contains(different_source.build_id), "source refusal names both bounded display IDs")
	check(different_source.last_error.contains("new folder") and different_source.last_error.contains("older installed shortcut"), "source refusal gives useful portable recovery")
	equal(host.player_count(), 2, "different full source is rejected before authoritative allocation")

	var same_display_source := _transport(SAME_DISPLAY_RUNTIME_SOURCE_HASH)
	equal(same_display_source.build_id, host.build_id, "full-source collision fixture deliberately shares the short display ID")
	check(same_display_source.start_join("127.0.0.1", host.bound_port, _signature(120, SimConfig.PROTOCOL_VERSION, SAME_DISPLAY_RUNTIME_SOURCE_HASH), "Same Short ID"), "same-display different-source client reaches the full identity boundary")
	check(_poll_until(host, same_display_source, func() -> bool: return same_display_source.mode == SessionTransport.Mode.OFFLINE and not same_display_source.last_error.is_empty()), "same short ID cannot authorize a changed full source")
	equal(host.player_count(), 2, "short-ID collision cannot consume a player slot")

	var old_chemistry := _transport()
	check(old_chemistry.start_join("127.0.0.1", host.bound_port, _signature(), "Protocol 47"), "protocol47 fixture opens a real ENet connection")
	old_chemistry._hello_sent = true
	var old_protocol_connected := _poll_until(host, old_chemistry, func() -> bool: return old_chemistry.peer != null and old_chemistry.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	check(old_protocol_connected, "protocol47 fixture reaches the guarded HELLO boundary without automatic admission")
	var old_protocol := 47
	check(old_protocol < SimConfig.PROTOCOL_VERSION, "the legacy HELLO fixture retains its real protocol47 identity")
	var old_build_id := String(_identity_manifest(TEST_RUNTIME_SOURCE_HASH, old_protocol)["build_id"])
	old_chemistry.build_id = old_build_id
	var old_protocol_hello := {
		"kind": SessionTransport.PACKET_HELLO,
		"signature": _signature(120, old_protocol),
		"name": "Protocol 47",
		"reconnect_token": "",
		"charter_catalog_hash": SessionCharter.catalog_hash(),
	}
	check(SessionTransport._valid_legacy_hello_packet(old_protocol_hello), "retained protocol47 HELLO shape is recognized only for structured recovery")
	if old_protocol_connected and old_chemistry.peer != null:
		old_chemistry.local_peer_id = old_chemistry.peer.get_unique_id()
		check(old_chemistry._send_to(SessionTransport.SERVER_PEER_ID, old_protocol_hello), "legacy protocol47 HELLO reaches the host")
		check(_poll_until(host, old_chemistry, func() -> bool: return old_chemistry.mode == SessionTransport.Mode.OFFLINE and not old_chemistry.last_error.is_empty()), "protocol47 is refused over real ENet")
		check(old_chemistry.last_error.contains(host.build_id) and old_chemistry.last_error.contains(old_build_id), "protocol refusal names host protocol49 and local protocol47 builds using trusted local copy")
		equal(host.player_count(), 2, "protocol mismatch cannot consume a player slot")

	# Protocol48 already used the full-identity HELLO. Preserve the legacy47
	# fixture above and independently reject the selected fallback's wire shape.
	var old_identity := _transport()
	check(old_identity.start_join("127.0.0.1", host.bound_port, _signature(), "Protocol 48"), "protocol48 fixture opens a real ENet connection")
	old_identity._hello_sent = true
	var p48_connected := _poll_until(host, old_identity, func() -> bool: return old_identity.peer != null and old_identity.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	check(p48_connected, "protocol48 fixture reaches HELLO without automatic admission")
	var p48_build_id := String(_identity_manifest(TEST_RUNTIME_SOURCE_HASH, 48)["build_id"])
	old_identity.build_id = p48_build_id
	var p48_hello := {
		"kind": SessionTransport.PACKET_HELLO, "protocol_version": 48,
		"signature": _signature(120, 48), "runtime_source_sha256": TEST_RUNTIME_SOURCE_HASH,
		"build_id": p48_build_id, "name": "Protocol 48", "reconnect_token": "",
		"charter_catalog_hash": SessionCharter.catalog_hash(),
	}
	check(SessionTransport._valid_hello_packet(p48_hello), "protocol48 HELLO is structurally valid before current-protocol admission")
	if p48_connected and old_identity.peer != null:
		old_identity.local_peer_id = old_identity.peer.get_unique_id()
		check(old_identity._send_to(SessionTransport.SERVER_PEER_ID, p48_hello), "full-identity protocol48 HELLO reaches the real host")
		check(_poll_until(host, old_identity, func() -> bool: return old_identity.mode == SessionTransport.Mode.OFFLINE and not old_identity.last_error.is_empty()), "protocol48 is refused over real ENet")
		check(old_identity.last_error.contains(host.build_id) and old_identity.last_error.contains(p48_build_id), "protocol49 refusal identifies the retained protocol48 client")
		equal(host.player_count(), 2, "protocol48 refusal never consumes an admitted slot")
	old_identity.stop()

	var coerced_hello_client := _transport()
	check(coerced_hello_client.start_join("127.0.0.1", host.bound_port, _signature(), "Coerced Proto"), "coerced-field fixture opens a real ENet connection")
	coerced_hello_client._hello_sent = true
	var coerced_connected := _poll_until(host, coerced_hello_client, func() -> bool: return coerced_hello_client.peer != null and coerced_hello_client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)
	check(coerced_connected, "coerced-field fixture reaches HELLO without automatic admission")
	var coerced_hello := {
		"kind": SessionTransport.PACKET_HELLO,
		"protocol_version": str(SimConfig.PROTOCOL_VERSION),
		"signature": _signature(),
		"runtime_source_sha256": TEST_RUNTIME_SOURCE_HASH,
		"build_id": host.build_id,
		"name": "Coerced Proto",
		"reconnect_token": "",
		"charter_catalog_hash": SessionCharter.catalog_hash(),
	}
	if coerced_connected and coerced_hello_client.peer != null:
		coerced_hello_client.local_peer_id = coerced_hello_client.peer.get_unique_id()
		check(coerced_hello_client._send_to(SessionTransport.SERVER_PEER_ID, coerced_hello), "string-coerced protocol HELLO reaches the host guard")
		check(_poll_until(host, coerced_hello_client, func() -> bool: return coerced_hello_client.mode == SessionTransport.Mode.OFFLINE and not coerced_hello_client.last_error.is_empty()), "coerced protocol is refused through the structured malformed code")
		check(coerced_hello_client.last_error.contains("malformed") and not coerced_hello_client.last_error.contains("Coerced Proto"), "malformed refusal is fixed local text without reflected packet prose")
		equal(host.player_count(), 2, "malformed identity fields cannot reach allocation")

	var source := SimWorld.new(120, 1, CollisionWorld.new())
	source.tick = 1
	source.player().champion_wire_id = 1
	var guest := PlayerState.new(2)
	guest.champion_wire_id = 2
	source.players.append(guest)
	var target := PlayerState.new(900)
	target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	target.position_x = 700_000
	target.position_y = 500_000
	target.radius = 18_000
	target.health_maximum = 80_000
	target.health = 80_000
	source.players.append(target)
	source.projectiles.append(ProjectileState.new(
		1000, 2, 2, CombatTuning.ECLIPSE_DISC_WIRE_ID, 8,
		Vector2i(500_000, 500_000), Vector2i(400_000, 0),
		14_000, 10_000, 90,
	))
	var snapshot := SessionSnapshot.capture(
		source,
		{1: "Lantern Host", 2: "River Guest"},
		[{"type": "projectile_spawned", "projectile_id": 1000, "owner_id": 2, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID}],
	)
	var snapshot_packet := SessionTransport._snapshot_wire_packet(snapshot)
	check(not snapshot_packet.is_empty(), "normal snapshot packs into its bounded wire envelope")
	check(var_to_bytes(snapshot_packet).size() <= SessionTransport.ENET_MTU_BYTES, "normal two-player combat snapshot stays within one ENet MTU")
	var unpacked_snapshot := SessionTransport._snapshot_from_wire_packet(snapshot_packet)
	equal(int(unpacked_snapshot.get("tick", -1)), source.tick, "compressed snapshot wire envelope round-trips exactly")
	check(SessionTransport._snapshot_from_wire_packet({"raw_size": SessionTransport.MAX_SNAPSHOT_UNCOMPRESSED_BYTES + 1, "payload": PackedByteArray([1])}).is_empty(), "oversized snapshot expansion fails closed")
	var reconciliation := ClientPrediction.capture_packet(guest, source.tick, 17)
	check(var_to_bytes({"kind": SessionTransport.PACKET_RECONCILIATION, "reconciliation": reconciliation}).size() <= SessionTransport.ENET_MTU_BYTES, "movement reconciliation stays within its own ENet MTU")
	check(host.send_reconciliation(client.local_peer_id, reconciliation), "host sends scoped movement authority on a separate ordered channel")
	check(_poll_until(host, client, func() -> bool: return not client.incoming_reconciliations.is_empty()), "client receives movement reconciliation through ENet")
	var reconciliations := client.take_reconciliations()
	equal(reconciliations.size(), 1, "client drains one newest reconciliation")
	if not reconciliations.is_empty():
		equal(int(reconciliations[0].get("sequence", -1)), 17, "input acknowledgement survives reconciliation transport")
	var wrong_state := PlayerState.new(3)
	check(not host.send_reconciliation(client.local_peer_id, ClientPrediction.capture_packet(wrong_state, source.tick, 17)), "host refuses reconciliation for another entity")
	check(host.broadcast_snapshot(snapshot), "host broadcasts a validated authoritative snapshot")
	check(_poll_until(host, client, func() -> bool: return not client.incoming_snapshots.is_empty()), "client receives the snapshot through unreliable-ordered ENet")
	var snapshots := client.take_snapshots()
	equal(snapshots.size(), 1, "client drains one validated snapshot")
	if not snapshots.is_empty():
		equal(int(snapshots[0].get("tick", -1)), source.tick, "snapshot tick survives transport")
		equal((snapshots[0].get("projectiles", PackedInt32Array()) as PackedInt32Array).size() / SessionSnapshot.PROJECTILE_VALUE_COUNT, 1, "projectile lane survives unreliable-ordered transport")
		equal((snapshots[0].get("events", []) as Array).size(), 1, "semantic combat event survives unreliable-ordered transport")

	# Real ENet delivery, not just a codec test: varied simultaneous threats need
	# several MTUs and must arrive as one complete authoritative frame.
	source.tick += 1
	for index: int in range(1, 80):
		source.projectiles.append(ProjectileState.new(
			1000 + index, 2, 2, CombatTuning.RILLSHOT_WIRE_ID, 2,
			Vector2i(300_000 + index * 7919, 200_000 + index * 6151),
			Vector2i(480_000 - index * 187, index * 157), 12_000, 9_000, 90 + index,
		))
	var dense_snapshot := SessionSnapshot.capture(source, {1: "Lantern Host", 2: "River Guest"})
	check(SessionTransport._snapshot_wire_packets(dense_snapshot).size() > 1, "real network fixture spans several MTUs")
	check(host.broadcast_snapshot(dense_snapshot), "host sends complete fragmented threat snapshot")
	check(_poll_until(host, client, func() -> bool: return not client.incoming_snapshots.is_empty()), "real ENet receives every fragment")
	var dense_received := client.take_snapshots()
	equal(dense_received.size(), 1, "fragmented ENet frame is delivered once and atomically")
	if not dense_received.is_empty():
		check(dense_received[0] == dense_snapshot, "all eighty threats and player values survive real transport")

	client.stop()
	check(_poll_until(host, client, func() -> bool: return host.player_count() == 1), "host removes a disconnected accepted peer")
	var disconnected := host.take_disconnected_peers()
	equal(disconnected.size(), 1, "host exposes one accepted disconnect event")
	if not disconnected.is_empty():
		equal(int(disconnected[0].get("entity_id", 0)), 2, "disconnect event preserves the released entity mapping")
	host.stop()
	check(not host.is_online() and not client.is_online(), "loopback peers close cleanly")


func _test_host_administration() -> void:
	var host := _transport()
	var client := _transport()
	var reason := "The host released you from the Farflow company."
	check(host.start_host(0, _signature(), "Steward Host"), "steward host binds")
	check(client.start_join("127.0.0.1", host.bound_port, _signature(), "River Guest"), "steward guest seeks host")
	check(_poll_until(host, client, func() -> bool: return client.is_connected_client()), "steward guest completes guarded acceptance")
	host.take_joined_peers()
	check(not client.host_remove_entity(2, reason), "client cannot call the host-only removal boundary")
	check(client._send_to(SessionTransport.SERVER_PEER_ID, {"kind": SessionTransport.PACKET_ADMIN_CLOSE, "reason": reason}), "forged administration packet reaches host packet boundary")
	for _index: int in range(20):
		host.poll()
		client.poll()
		OS.delay_msec(1)
	equal(host.player_count(), 2, "host ignores client-forged administration packet")
	check(host.take_disconnected_peers().is_empty(), "forged moderation emits no authoritative removal")
	check(not host.host_remove_entity(1, reason), "host cannot target its own entity through guest removal")
	check(not host.host_remove_entity(2, ""), "host cannot remove a guest without a readable reason")
	check(host.host_remove_entity(2, reason), "host begins graceful reason-bearing guest removal")
	check(_poll_until(host, client, func() -> bool: return host.player_count() == 1 and client.mode == SessionTransport.Mode.OFFLINE), "administrative removal reaches both peers")
	equal(client.last_error, reason, "removed guest receives the exact bounded reason")
	check(not client.can_reconnect(), "administratively removed guest loses the return capability")
	equal(host.reserved_count(), 0, "administrative removal creates no return reservation")
	var disconnected := host.take_disconnected_peers()
	equal(disconnected.size(), 1, "host exposes one administrative departure")
	if not disconnected.is_empty():
		check(bool(disconnected[0].get("administrative", false)), "departure is explicitly administrative")
		check(not bool(disconnected[0].get("reserved", true)), "administrative departure is final")
		equal(String(disconnected[0].get("reason", "")), reason, "authoritative departure retains the public reason")
	check(not host.host_remove_entity(2, reason), "removed entity cannot be targeted again")
	var stubborn := _transport()
	var close_reason := "The host closed the Farflow company."
	check(stubborn.start_join("127.0.0.1", host.bound_port, _signature(), "Stubborn Guest"), "unresponsive-client fixture seeks host")
	check(_poll_until(host, stubborn, func() -> bool: return stubborn.is_connected_client()), "unresponsive-client fixture is accepted")
	host.take_joined_peers()
	check(host.host_remove_entity(2, close_reason), "host schedules bounded company-close notice")
	equal(host._force_due_administrative_disconnects(Time.get_ticks_msec() + SessionTransport.ADMIN_DISCONNECT_GRACE_MS + 1), 1, "ignored administration notice reaches forced deadline")
	var forced_removed := false
	for _index: int in range(2_000):
		host.poll()
		if host.player_count() == 1:
			forced_removed = true
			break
		OS.delay_msec(1)
	check(forced_removed, "modified client cannot outwait final host removal")
	equal(host.reserved_count(), 0, "forced administrative close also creates no reservation")
	var forced_events := host.take_disconnected_peers()
	check(not forced_events.is_empty() and bool(forced_events[0].get("administrative", false)) and String(forced_events[0].get("reason", "")) == close_reason, "forced departure preserves the company-close reason")
	stubborn.stop()
	host.stop()


func _test_reconnect_identity_and_host_loss() -> void:
	var host := _transport()
	var client := _transport()
	check(host.start_host(0, _signature(), "Lantern Host"), "reconnect host binds")
	check(client.start_join("127.0.0.1", host.bound_port, _signature(), "River Guest"), "reconnect client begins first join")
	check(_poll_until(host, client, func() -> bool: return client.is_connected_client()), "reconnect client receives first identity")
	equal(client.local_entity_id, 2, "first reconnect identity is entity two")
	var first_token := client.reconnect_token
	check(SessionTransport._valid_reconnect_token(first_token), "accepted client retains an in-memory return capability")
	check(not str(host.host_roster()).contains(first_token), "return capability is absent from public roster serialization")
	check(not host.status_detail.contains(first_token), "return capability is absent from host diagnostics")
	host.take_joined_peers()
	client.stop()
	check(_poll_until(host, client, func() -> bool: return host.reserved_count() == 1), "host reserves disconnected identity")
	equal(host.player_count(), 1, "return reservation is not reported as a connected player")
	equal(host.host_session_roster().size(), 1, "return reservation remains in session actor roster")
	var first_disconnect := host.take_disconnected_peers()
	check(not first_disconnect.is_empty() and bool(first_disconnect[0].get("reserved", false)), "disconnect event distinguishes a reserved return")
	var attacker := _transport()
	attacker.reconnect_token = first_token
	attacker.reconnect_address = "127.0.0.1"
	attacker.reconnect_port = host.bound_port
	attacker.reconnect_signature = _signature()
	attacker.reconnect_runtime_source_sha256 = TEST_RUNTIME_SOURCE_HASH
	attacker.reconnect_build_id = attacker.build_id
	check(attacker.start_join("127.0.0.1", host.bound_port, _signature(), "False Guest"), "name-mismatch attacker reaches handshake")
	check(_poll_until(host, attacker, func() -> bool: return attacker.mode == SessionTransport.Mode.OFFLINE and not attacker.last_error.is_empty()), "name-mismatch return is rejected")
	check(attacker.last_error.contains("name"), "return name mismatch is explicit")
	equal(host.reserved_count(), 1, "failed token use does not consume reservation")
	check(client.start_join("127.0.0.1", host.bound_port, _signature(), "River Guest"), "original client begins return")
	check(_poll_until(host, client, func() -> bool: return client.is_connected_client()), "original client reclaims reserved identity")
	equal(client.local_entity_id, 2, "return reclaims exact entity two")
	check(client.reconnect_token != first_token and SessionTransport._valid_reconnect_token(client.reconnect_token), "successful return rotates the capability")
	var resumed := host.take_joined_peers()
	check(not resumed.is_empty() and bool(resumed[0].get("resumed", false)), "host presence event distinguishes resumed identity")
	client.stop()
	check(_poll_until(host, client, func() -> bool: return host.reserved_count() == 1), "second disconnect reserves rotated capability")
	host.take_disconnected_peers()
	var expiry_ms := Time.get_ticks_msec() + SessionTransport.RECONNECT_WINDOW_MS + 1
	equal(host._expire_reconnect_reservations(expiry_ms), 1, "bounded return window expires deterministically")
	equal(host.reserved_count(), 0, "expired reservation releases capacity")
	var expired := host.take_disconnected_peers()
	check(not expired.is_empty() and bool(expired[0].get("expired", false)) and not bool(expired[0].get("reserved", true)), "expiry event authorizes actor removal")
	var observer := _transport()
	check(observer.start_join("127.0.0.1", host.bound_port, _signature(), "Observer"), "host-loss observer joins")
	check(_poll_until(host, observer, func() -> bool: return observer.is_connected_client()), "host-loss observer is accepted")
	host.stop()
	check(_poll_until(host, observer, func() -> bool: return observer.mode == SessionTransport.Mode.OFFLINE), "forced host loss closes observer")
	check(observer.last_error.contains("Host"), "forced host loss is explicit")
	check(observer.can_reconnect(), "host-loss client retains its endpoint-scoped return capability in memory")
	observer.stop()
	check(observer.configure_runtime_identity(_identity_manifest(OTHER_RUNTIME_SOURCE_HASH)), "offline client can load a newly validated source identity")
	check(not observer.can_reconnect(), "return capability cannot cross a full runtime-source identity boundary")


func _test_charter_assignment_and_capacity() -> void:
	var host := _transport()
	var first := _transport()
	var excess := _transport()
	var incompatible := _transport()
	var charter_id := "duel_knot"
	check(host.start_host(0, _signature(), "Duel Host", charter_id, SessionCharter.profile_hash(charter_id)), "Duel Knot host binds")
	equal(host.player_capacity(), 2, "Duel Knot host enforces two places")
	check(first.start_join("127.0.0.1", host.bound_port, _signature(), "First Guest"), "first Duel guest seeks host")
	check(_poll_until(host, first, func() -> bool: return first.is_connected_client()), "first Duel guest is accepted")
	equal(first.session_charter_id, charter_id, "accepted guest learns the Duel Knot charter")
	equal(first.player_capacity(), 2, "accepted guest learns the authoritative capacity")
	check(excess.start_join("127.0.0.1", host.bound_port, _signature(), "Excess Guest"), "excess Duel guest reaches guarded hello")
	check(_poll_until(host, excess, func() -> bool: return excess.mode == SessionTransport.Mode.OFFLINE and not excess.last_error.is_empty()), "excess Duel guest receives an explicit refusal")
	check(excess.last_error.contains("full"), "charter capacity refusal is readable")
	check(incompatible.start_join("127.0.0.1", host.bound_port, _signature(), "Old Charter", "f".repeat(64)), "old charter catalog reaches guarded hello")
	check(_poll_until(host, incompatible, func() -> bool: return incompatible.mode == SessionTransport.Mode.OFFLINE and not incompatible.last_error.is_empty()), "old charter catalog is refused")
	check(incompatible.last_error.contains("charter"), "charter incompatibility refusal is explicit")
	equal(host.player_count(), 2, "refused travellers never enter Duel roster")
	first.stop()
	host.stop()


func _poll_until(host: SessionTransport, client: SessionTransport, predicate: Callable) -> bool:
	for _index: int in range(2_000):
		host.poll()
		client.poll()
		if predicate.call():
			return true
		OS.delay_msec(1)
	return false


func _poll_many_until(host: SessionTransport, clients: Array[SessionTransport], predicate: Callable) -> bool:
	for _index: int in range(2_000):
		host.poll()
		for client: SessionTransport in clients:
			client.poll()
		if predicate.call():
			return true
		OS.delay_msec(1)
	return false


func _all_clients_connected(clients: Array[SessionTransport]) -> bool:
	for client: SessionTransport in clients:
		if not client.is_connected_client():
			return false
	return true


func _establish_world_epoch(host: SessionTransport, clients: Array[SessionTransport]) -> void:
	var initial_world := SimWorld.new(120, 1, CollisionWorld.new())
	initial_world.player().champion_wire_id = 1
	var names := {1: "Epoch Host"}
	for client: SessionTransport in clients:
		if client.local_entity_id <= 1: continue
		var actor := PlayerState.new(client.local_entity_id)
		actor.champion_wire_id = 1
		initial_world.players.append(actor)
		names[actor.entity_id] = "Epoch Guest"
	var initial_snapshot := SessionSnapshot.capture(initial_world, names)
	check(host.broadcast_snapshot(initial_snapshot), "host publishes a complete initial world before accepting epoch-scoped input")
	check(_poll_many_until(host, clients, func() -> bool:
		for client: SessionTransport in clients:
			if client.world_epoch != host.world_epoch: return false
		return true), "every client establishes the host epoch from a complete snapshot")
	for client: SessionTransport in clients:
		client.take_snapshots()
		client.poll_envelopes()

extends FluxTestSuite


const TEST_RUNTIME_SOURCE_HASH := "acacacacacacacacacacacacacacacacacacacacacacacacacacacacacacacac"


func run() -> int:
	_test_delayed_poll_preserves_reliable_administration_reason()
	return finish("session-transport-admin-close-delivery")


func _test_delayed_poll_preserves_reliable_administration_reason() -> void:
	var host := _transport()
	var client := _transport()
	var signature := "b".repeat(64)
	var reason := "The host released you from the Farflow company."
	check(host.start_host(0, signature, "Steward Host"), "administration host binds an automatic localhost port")
	check(client.start_join("127.0.0.1", host.bound_port, signature, "Delayed Guest"), "delayed-poll guest begins a guarded join")
	check(_poll_until_connected(host, client), "delayed-poll guest receives an accepted identity")
	if not client.is_connected_client():
		client.stop()
		host.stop()
		return
	host.take_joined_peers()
	check(client.can_reconnect(), "accepted guest begins with an endpoint-scoped return capability")
	check(client.configure_world_epoch(0), "fixture establishes an input-capable world epoch")
	var weave := PackedInt32Array()
	for wire_id: int in CombatTuning.runtime_wire_ids():
		weave.append(wire_id)
		if weave.size() == PlayerState.SPELL_SLOT_COUNT:
			break
	equal(weave.size(), PlayerState.SPELL_SLOT_COUNT, "fixture builds a valid complete weave request")
	check(client.send_input(1, SimCommand.new()), "connected client can send gameplay input before removal")
	check(client.send_request(2, SessionTransport.REQUEST_EMOTE), "connected client can send an ordinary request before removal")
	check(client.send_weave_request(3, 1, weave, weave), "connected client can send a valid weave request before removal")
	check(_poll_host_until(host, func() -> bool:
		return not host.incoming_inputs.is_empty() and host.incoming_requests.size() == 2
	), "host receives positive-control traffic while peer is authorized")
	equal(host.take_inputs().size(), 1, "authorized host accepts the positive-control input")
	equal(host.take_requests().size(), 2, "authorized host accepts ordinary and weave positive-control requests")

	# Put exactly one full poll budget ahead of the administration close. Raw ENet
	# service fills the receive queue without letting SessionTransport consume it.
	# This deterministically exercises the bounded multi-poll close path.
	var filler_sent: bool = true
	for sequence: int in range(SessionTransport.MAX_PACKETS_PER_POLL):
		filler_sent = host._send_to(client.local_peer_id, {"kind": 999, "sequence": sequence}) and filler_sent
	check(filler_sent, "host queues one complete receive budget before administration")
	var removal_started_ms: int = Time.get_ticks_msec()
	check(host.host_remove_entity(client.local_entity_id, reason), "host sends a reliable reason and starts the unchanged removal grace")
	# Service only the host through the real 250 ms authority grace. The client
	# intentionally stops all service, matching a busy production frame.
	var removal_watchdog_ms: int = removal_started_ms + SessionTransport.ADMIN_DISCONNECT_GRACE_MS + 1_000
	while host.player_count() > 1 and Time.get_ticks_msec() < removal_watchdog_ms:
		host.poll()
		OS.delay_msec(1)
	check(client.is_connected_client(), "fixture withholds client polling through close delivery")
	check(
		Time.get_ticks_msec() - removal_started_ms >= SessionTransport.ADMIN_DISCONNECT_GRACE_MS,
		"host retains the full administration grace before authority revocation",
	)
	equal(host.player_count(), 1, "host revokes traveller authority at 250 ms without waiting for client cooperation")
	equal(host.reserved_count(), 0, "administrative removal does not create a return reservation")
	equal(host.administrative_delivery_deadline_by_peer.size(), 1, "removed peer retains one bounded physical delivery tombstone")

	# Service raw ENet only after authority is gone. No physical disconnect has
	# begun, so the reliable close and its full-budget prefix remain available.
	var queued_watchdog_ms: int = Time.get_ticks_msec() + 500
	while (
		client.peer.get_available_packet_count() <= SessionTransport.MAX_PACKETS_PER_POLL
		and Time.get_ticks_msec() < queued_watchdog_ms
	):
		client.peer.poll()
		OS.delay_msec(1)
	check(
		client.peer.get_available_packet_count() > SessionTransport.MAX_PACKETS_PER_POLL,
		"raw ENet queue contains the capped filler plus the final administration packet",
	)

	# The first transport poll honors the unchanged cap. The client has not yet
	# consumed its reason and may transmit, but the revoked host must reject it.
	client.poll()
	equal(client.mode, SessionTransport.Mode.CLIENT, "first delayed poll preserves the packet processing cap")
	check(client.is_connected_client(), "capped delivery drain cannot make Bootstrap step local authority")
	check(client.send_input(4, SimCommand.new()), "unaware delayed client can physically transmit after authority revocation")
	check(client.send_request(5, SessionTransport.REQUEST_EMOTE), "unaware delayed client can physically request after authority revocation")
	check(client.send_weave_request(6, 1, weave, weave), "unaware delayed client can physically send a weave after authority revocation")
	var fresh_hello := {
		"kind": SessionTransport.PACKET_HELLO,
		"protocol_version": SimConfig.PROTOCOL_VERSION,
		"signature": signature,
		"runtime_source_sha256": client.runtime_source_sha256,
		"build_id": client.build_id,
		"name": "Fresh Rejoin",
		"reconnect_token": "",
		"charter_catalog_hash": SessionCharter.catalog_hash(),
	}
	check(SessionTransport._valid_hello_packet(fresh_hello), "forged rejoin HELLO is otherwise a fully valid fresh handshake")
	check(client._send_to(SessionTransport.SERVER_PEER_ID, fresh_hello), "tombstone fixture physically sends the valid fresh rejoin HELLO")
	for _index: int in range(8):
		host.poll()
		OS.delay_msec(1)
	check(host.take_inputs().is_empty(), "tombstoned peer cannot submit input after the 250 ms authority deadline")
	check(host.take_requests().is_empty(), "tombstoned peer cannot submit requests after the 250 ms authority deadline")
	check(host.take_joined_peers().is_empty(), "tombstoned peer cannot re-enter authority through HELLO")
	check(not host.accepted_peer_ids.has(client.local_peer_id), "tombstoned peer remains outside the accepted set")
	client.poll()
	equal(client.mode, SessionTransport.Mode.OFFLINE, "next delayed poll consumes the final reason and closes")
	equal(client.last_error, reason, "queued administration reason wins over generic host-loss ordering")
	check(not client.can_reconnect(), "reason-bearing administrative close revokes the saved return capability")
	check(not client.send_input(1, SimCommand.new()), "administratively removed client cannot send gameplay input")

	var departures := host.take_disconnected_peers()
	equal(departures.size(), 1, "host emits one final administrative departure")
	if not departures.is_empty():
		check(bool(departures[0].get("administrative", false)), "departure remains explicitly administrative")
		equal(String(departures[0].get("reason", "")), reason, "host authority retains the same public reason")
		check(not bool(departures[0].get("reserved", true)), "departure remains final after delayed receipt")
	check(_poll_host_until(host, func() -> bool: return host.administrative_delivery_deadline_by_peer.is_empty()), "cooperative close clears its physical tombstone")
	check(host.take_disconnected_peers().is_empty(), "later physical disconnect creates no duplicate departure or reservation")

	var stubborn := _transport()
	check(stubborn.start_join("127.0.0.1", host.bound_port, signature, "Quiet Guest"), "nonpolling cleanup fixture begins a guarded join")
	check(_poll_until_connected(host, stubborn), "nonpolling cleanup fixture receives an accepted identity")
	host.take_joined_peers()
	var stubborn_peer_id: int = stubborn.local_peer_id
	check(host.host_remove_entity(stubborn.local_entity_id, reason), "host schedules reason delivery for nonpolling peer")
	var synthetic_authority_ms: int = Time.get_ticks_msec() + SessionTransport.ADMIN_DISCONNECT_GRACE_MS + 1
	equal(host._force_due_administrative_disconnects(synthetic_authority_ms), 1, "synthetic deadline revokes nonpolling peer authority")
	check(not host.accepted_peer_ids.has(stubborn_peer_id), "nonpolling tombstone is absent from accepted host authority")
	check(host.administrative_delivery_deadline_by_peer.has(stubborn_peer_id), "nonpolling socket retains one bounded delivery tombstone")
	equal(
		host._force_due_administrative_delivery_closes(synthetic_authority_ms + SessionTransport.ADMIN_DELIVERY_GRACE_MS - 1),
		0,
		"physical cleanup does not shorten the five-second delivery grace",
	)
	equal(
		host._force_due_administrative_delivery_closes(synthetic_authority_ms + SessionTransport.ADMIN_DELIVERY_GRACE_MS),
		1,
		"nonpolling physical socket is forcibly reclaimed at the bounded deadline",
	)
	check(not host.administrative_delivery_deadline_by_peer.has(stubborn_peer_id), "hard cleanup removes the delivery tombstone")
	equal(host.take_disconnected_peers().size(), 1, "nonpolling cleanup emits only its earlier authoritative departure")
	stubborn.stop()
	client.stop()
	host.stop()


func _poll_until_connected(host: SessionTransport, client: SessionTransport) -> bool:
	for _index: int in range(2_000):
		host.poll()
		client.poll()
		if client.is_connected_client():
			return true
		OS.delay_msec(1)
	return false


func _poll_host_until(host: SessionTransport, predicate: Callable) -> bool:
	for _index: int in range(2_000):
		host.poll()
		if predicate.call():
			return true
		OS.delay_msec(1)
	return false


func _transport() -> SessionTransport:
	var transport := SessionTransport.new()
	check(transport.configure_runtime_identity(_identity_manifest()), "transport accepts the bounded runtime identity")
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

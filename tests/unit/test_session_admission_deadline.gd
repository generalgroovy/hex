extends FluxTestSuite

func run() -> int:
	var host := SessionTransport.new()
	check(host.start_host(0, "a".repeat(64)), "admission fixture hosts actual ENet")
	if host.peer == null: return finish("session-admission-deadline")
	var silent: Array[ENetMultiplayerPeer] = []
	for unused: int in SessionTransport.MAX_REMOTE_CLIENTS:
		var client := ENetMultiplayerPeer.new()
		check(client.create_client("127.0.0.1", host.bound_port) == OK, "silent socket starts")
		silent.append(client)
	var until := Time.get_ticks_msec() + 2000
	while host._hello_deadline_by_peer.size() < SessionTransport.MAX_REMOTE_CLIENTS and Time.get_ticks_msec() < until:
		host.poll()
		for client: ENetMultiplayerPeer in silent: client.poll()
		OS.delay_msec(2)
	equal(host._hello_deadline_by_peer.size(), 7, "all physical slots are occupied before HELLO")
	equal(host.player_count(), 1, "unadmitted sockets own no player")
	var earliest := Time.get_ticks_msec() + SessionTransport.HELLO_TIMEOUT_MS
	var latest := 0
	for peer_id: int in host._hello_deadline_by_peer:
		var deadline: int = host._hello_deadline_by_peer[peer_id]
		earliest = mini(earliest, deadline)
		latest = maxi(latest, deadline)
		host._on_host_peer_connected(peer_id)
		equal(host._hello_deadline_by_peer[peer_id], deadline, "repeated connection event cannot renew admission")
	equal(host._expire_pending_hellos(earliest - 1), 0, "no early deadline eviction")
	var refused_id := silent[0].get_unique_id()
	var refusal_time := Time.get_ticks_msec()
	host._hello_deadline_by_peer[refused_id] = refusal_time
	host._handle_hello(refused_id, {"kind": SessionTransport.PACKET_HELLO})
	var refusal_deadline: int = host._hello_deadline_by_peer[refused_id]
	check(refusal_deadline >= refusal_time + SessionTransport.ADMIN_DELIVERY_GRACE_MS, "endpoint rejection receives bounded delivery grace")
	host._handle_hello(refused_id, {"kind": SessionTransport.PACKET_HELLO})
	equal(host._hello_deadline_by_peer[refused_id], refusal_deadline, "repeated malformed HELLO cannot renew rejection grace")
	equal(host._expire_pending_hellos(refusal_time), 0, "queued endpoint refusal is not discarded by immediate close")
	until = Time.get_ticks_msec() + 1000
	while silent[0].get_available_packet_count() == 0 and Time.get_ticks_msec() < until:
		host.poll()
		silent[0].poll()
		OS.delay_msec(2)
	check(silent[0].get_available_packet_count() > 0, "real ENet delivers endpoint refusal")
	if silent[0].get_available_packet_count() > 0:
		var packet: Variant = bytes_to_var(silent[0].get_packet())
		check(packet is Dictionary and packet.get("code", "") == SessionTransport.REJECT_MALFORMED_REQUEST, "actual refusal retains its actionable reason")
	latest = maxi(latest, refusal_deadline)
	equal(host._expire_pending_hellos(latest), 7, "deadline reclaims every silent physical slot")
	check(host._hello_deadline_by_peer.is_empty(), "pending memory reclaimed")
	check(host._hello_rejection_grace_by_peer.is_empty(), "refusal grace memory reclaimed")
	check(host.reconnect_reservations.is_empty() and host.disconnected_peers.is_empty(), "unadmitted sockets produce no return identities or departure events")
	for client: ENetMultiplayerPeer in silent: client.close()
	var guest := SessionTransport.new()
	check(guest.start_join("127.0.0.1", host.bound_port, "a".repeat(64), "Guest"), "ordinary guest can request reclaimed capacity")
	until = Time.get_ticks_msec() + 2000
	while not guest.accepted and Time.get_ticks_msec() < until:
		host.poll()
		guest.poll()
		OS.delay_msec(2)
	check(guest.accepted, "real handshake succeeds after seven silent sockets")
	equal(host.player_count(), 2, "admitted guest owns exactly one slot")
	check(host._hello_deadline_by_peer.is_empty(), "successful HELLO removes pending lease")
	equal(host._expire_pending_hellos(Time.get_ticks_msec() + 10000), 0, "admitted player survives admission timeout")
	guest.stop()
	until = Time.get_ticks_msec() + 1000
	while host.accepted_peer_ids.size() > 0 and Time.get_ticks_msec() < until:
		host.poll()
		OS.delay_msec(2)
	equal(host.reconnect_reservations.size(), 1, "admitted disconnect retains existing return grace")
	host.stop()
	check(host._hello_deadline_by_peer.is_empty(), "stop clears admission state")
	return finish("session-admission-deadline")

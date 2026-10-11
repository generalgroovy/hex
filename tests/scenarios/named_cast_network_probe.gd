extends SceneTree

# Standalone real-UDP integration, not a render/FPS or internet load benchmark.
# Uses inherited production request handling; skips only boot/UI side effects.
class HostHarness:
	extends "res://src/app/bootstrap.gd"
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _draw() -> void: pass

var assertions := 0
var failures := 0
var completed := false
var host := SessionTransport.new()
var client := SessionTransport.new()
var node: HostHarness
var replica := SimWorld.new(120, 1, CollisionWorld.new(6_000_000, 6_000_000))
var input_sequence := 0
var request_sequence := 0
var snapshots_received := 0
var maximum_snapshot_bytes := 0
var selection_receipts: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	node = HostHarness.new()
	node.ability_catalog = AbilityCatalog.new()
	node.champion_catalog = ChampionCatalog.new()
	node.campus_layout = SanctumCampusLayout.new()
	node.authoritative_session = AuthoritativeSession.new()
	_exercise()
	_check(completed, "entire bounded network scenario reaches its final checkpoint")
	client.stop()
	host.stop()
	node.free()
	print(JSON.stringify({"probe": "named-cast-network", "protocol": SimConfig.PROTOCOL_VERSION,
		"snapshot_schema": SessionSnapshot.SCHEMA_VERSION, "selections": selection_receipts,
		"direction_cases": input_sequence, "snapshots_received": snapshots_received,
		"maximum_snapshot_bytes": maximum_snapshot_bytes, "assertions": assertions,
		"failures": failures, "scope": "local ENet loopback; production request handler and authoritative simulation; not internet/performance acceptance"}))
	print("PASS: named roster network probe" if failures == 0 else "FAIL: named roster network probe")
	quit(0 if failures == 0 else 1)


func _exercise() -> void:
	if not _check(node.ability_catalog.load_from_file(node.ABILITY_CATALOG_PATH), "live abilities load"): return
	if not _check(node.champion_catalog.load_from_file(node.CHAMPION_CATALOG_PATH, node.ability_catalog), "live champions load"): return
	if not _check(node.campus_layout.load_from_file(node.CAMPUS_LAYOUT_PATH), "actual Gallery layout loads"): return
	if not _check(node.champion_catalog.ordered_champion_ids().size() == 30, "probe uses current promoted roster"): return
	node.world = SimWorld.new(120, 1, CollisionWorld.new(6_000_000, 6_000_000))
	node.session_transport = host
	if not _check(node.champion_catalog.apply_to_player(node.world.player(), "oh_tipi"), "host profile initialized"): return
	var signature := SessionTransport.compatibility_signature(SimConfig.PROTOCOL_VERSION, 120,
		FileAccess.get_sha256(node.CAMPUS_LAYOUT_PATH), node.ability_catalog.content_hash,
		node.champion_catalog.content_hash, SessionCharter.catalog_hash(),
		FileAccess.get_sha256(ReactionCatalog.DEFAULT_PATH))
	if not _check(host.start_host(0, signature, "Roster Host"), "host binds unique automatic UDP port: " + host.last_error): return
	if not _check(client.start_join("127.0.0.1", host.bound_port, signature, "Roster Guest"), "guest starts real ENet join: " + client.last_error): return
	if not _check(_poll(func() -> bool: return client.is_connected_client()), "current compatibility handshake completes"): return
	if not _check(node.authoritative_session.bind(node.world, node.champion_catalog, Vector2i(1568, 640), "Roster Host", host.take_joined_peers()), "real joined peer registers in authoritative world"): return
	var state := node.world.player(client.local_entity_id)
	if not _check(state != null and state.entity_id == 2, "trusted guest owns entity2"): return
	var gallery := SanctumCampusLayout._parse_point(node.campus_layout.stations_by_id["champion-loom"]["position"]) * SimConfig.FIXED_SCALE
	for wire: int in [27, 24, 26, 28, 29, 30]:
		state.position_x = gallery.x
		state.position_y = gallery.y
		state.velocity_x = 0
		state.velocity_y = 0
		var champion_id := node.champion_catalog.champion_id_from_wire(wire)
		if not _select(wire): return
		_check(state.champion_wire_id == wire, "actual host request handler applies exact wire%d" % wire)
		for stat: String in node.champion_catalog.champion(champion_id)["stats"]:
			_check(int(state.get(stat)) == int(node.champion_catalog.champion(champion_id)["stats"][stat]), "host applies exact baseline stat " + stat)
		# A second valid wire request must not call the profile reset path.
		state.flux_recovery_delay_ticks = 19
		state.stamina_remainder = 29
		state.spell_cooldown_ticks[0] = 31
		var before := state.canonical_values()
		if not _select(wire): return
		_check(state.canonical_values() == before, "same-ID network request is canonical no-op")
		if not _step_and_replicate(): return
		var remote := replica.player(state.entity_id)
		_check(remote != null and remote.champion_wire_id == wire, "client observes exact host-confirmed identity")
		for stat: String in ["health_maximum", "flux_maximum", "stamina_maximum", "stamina_recovery_per_second", "flux_recovery_per_second", "float_max_duration_ms"]:
			_check(int(remote.get(stat)) == int(state.get(stat)), "replicated baseline resource/body value matches host: " + stat)
		selection_receipts.append({"id": champion_id, "wire": wire, "body": node.champion_catalog.champion(champion_id)["body_type"], "health_maximum": remote.health_maximum, "flux_maximum": remote.flux_maximum, "stamina_maximum": remote.stamina_maximum})
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var command := SimCommand.new(node.world.tick, state.entity_id, direction.x, direction.y, 0, 0, direction.x, direction.y)
			if not _check(client.send_input(input_sequence, command), "client sends screen-cardinal movement"): return
			input_sequence += 1
			if not _check(_poll(func() -> bool: return not host.incoming_inputs.is_empty()), "movement reaches host over UDP"): return
			if not _check(node.authoritative_session.ingest_inputs(host.take_inputs()) == 1, "host ingests exactly one trusted input"): return
			var commands := node.authoritative_session.commands_for_tick(SimCommand.new(node.world.tick, 1))
			var remote_command: SimCommand = commands[1]
			_check(remote_command.entity_id == state.entity_id and Vector2i(remote_command.move_x, remote_command.move_y) == direction, "exact eight-way input reaches authoritative command lane")
			if not _check(node.world.step(commands), "shared world accepts direction input"): return
			if not _replicate(): return
			remote = replica.player(state.entity_id)
			_check(Vector2i(remote.position_x, remote.position_y) == Vector2i(state.position_x, state.position_y), "client observes exact resulting host position")
			_check(Vector2i(remote.aim_x, remote.aim_y) == direction, "client sees the same screen-cardinal aim")
	# A real request outside the Gallery is refused by the inherited host policy.
	state.position_x = 400_000
	state.position_y = 400_000
	var before_refusal := state.canonical_values()
	if not _select(27): return
	_check(state.canonical_values() == before_refusal, "remote out-of-range selection cannot mutate actor")
	if not _step_and_replicate(): return
	var refused := false
	for event: Dictionary in replica.combat_events:
		if event.get("type") == "request_refused" and int(event.get("action", 0)) == SessionTransport.REQUEST_CHAMPION_SELECT:
			refused = int(event.get("reason", 0)) == SessionRequestPolicy.REFUSED_DISTANCE
	_check(refused, "client receives exact selection distance refusal over snapshot transport")
	completed = true


func _select(wire: int) -> bool:
	if not _check(client.send_request(request_sequence, SessionTransport.REQUEST_CHAMPION_SELECT, wire), "exact champion request enters reliable ENet"): return false
	request_sequence += 1
	if not _check(_poll(func() -> bool: return not host.incoming_requests.is_empty()), "exact champion request reaches host"): return false
	var requests := host.take_requests()
	if not _check(requests.size() == 1 and int(requests[0].get("entity_id", 0)) == client.local_entity_id, "transport stamps the authenticated guest"): return false
	node._handle_session_requests(requests)
	return true


func _step_and_replicate() -> bool:
	return _check(node.world.step(node.authoritative_session.commands_for_tick(SimCommand.new(node.world.tick, 1))), "world advances after selection") and _replicate()


func _replicate() -> bool:
	var snapshot := node.authoritative_session.capture_snapshot()
	maximum_snapshot_bytes = maxi(maximum_snapshot_bytes, var_to_bytes(snapshot).size())
	if not _check(host.broadcast_snapshot(snapshot), "host sends actual authoritative snapshot"): return false
	var state := node.world.player(client.local_entity_id)
	var reconciliation := ClientPrediction.capture_packet(state, node.world.tick, input_sequence - 1)
	if not _check(host.send_reconciliation(client.local_peer_id, reconciliation), "host sends movement baseline on reconciliation channel"): return false
	if not _check(_poll(func() -> bool: return not client.incoming_snapshots.is_empty() and not client.incoming_reconciliations.is_empty()), "snapshot and movement authority reach guest"): return false
	var snapshots := client.take_snapshots()
	var reconciliations := client.take_reconciliations()
	if not _check(SessionSnapshot.apply_to_world(snapshots[-1], replica), "received snapshot applies to client world"): return false
	var restored := ClientPrediction.restore_state(reconciliations[-1]["values"])
	if not _check(restored != null, "received prediction authority validates"): return false
	_check(restored.movement_speed_ratio == state.movement_speed_ratio, "body movement speed is honest in client reconciliation")
	_check(restored.stamina_maximum == state.stamina_maximum and restored.float_max_duration_ms == state.float_max_duration_ms, "movement economy/body allowance matches selected host profile")
	snapshots_received += 1
	node.authoritative_session.acknowledge_snapshot()
	return true


func _poll(predicate: Callable) -> bool:
	for _index: int in range(2000):
		host.poll()
		client.poll()
		if predicate.call(): return true
		OS.delay_msec(1)
	return false


func _check(condition: bool, label: String) -> bool:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
	return condition

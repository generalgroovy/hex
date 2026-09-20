class_name SessionTransport
extends RefCounted


const WorldSnapshotEnvelope = preload("res://src/net/world_snapshot_envelope.gd")
const HexWorldSnapshotCodec = preload("res://src/net/hex_world_snapshot.gd")

enum Mode {
	OFFLINE,
	HOSTING,
	CONNECTING,
	CLIENT,
}

const DEFAULT_PORT: int = 24_872
const MAX_PLAYERS: int = 8
const MAX_REMOTE_CLIENTS: int = MAX_PLAYERS - 1
const MAX_PACKET_BYTES: int = 8_192
const ENET_MTU_BYTES: int = 1_392
const MAX_SNAPSHOT_UNCOMPRESSED_BYTES: int = 32_768
const SNAPSHOT_FRAGMENT_PAYLOAD_BYTES: int = 1_152
const MAX_SNAPSHOT_FRAGMENTS: int = 32
const MAX_PENDING_SNAPSHOT_ASSEMBLIES: int = 3
const SNAPSHOT_ASSEMBLY_TIMEOUT_MS: int = 350
const MAX_PACKETS_PER_POLL: int = 64
const MAX_QUEUED_INPUTS_PER_PEER: int = 4
const MAX_QUEUED_INPUTS: int = MAX_REMOTE_CLIENTS * MAX_QUEUED_INPUTS_PER_PEER
# Display names travel in every bounded snapshot; sixteen Unicode codepoints keep
# the eight-player one-MTU envelope while remaining generous in the compact HUD.
const MAX_PLAYER_NAME_LENGTH: int = 15
const CONNECT_TIMEOUT_MS: int = 5_000
const RECONNECT_WINDOW_MS: int = 15_000
const ADMIN_DISCONNECT_GRACE_MS: int = 250
# Host authority ends after ADMIN_DISCONNECT_GRACE_MS. The physical ENet peer
# remains only this much longer so a delayed client can consume its reliable
# reason before a non-cooperative socket is forcibly reclaimed.
const ADMIN_DELIVERY_GRACE_MS: int = 5_000
const RECONNECT_TOKEN_BYTES: int = 32
const SERVER_PEER_ID: int = 1
const MAX_REJECT_MESSAGE_LENGTH: int = 256
const MAX_BUILD_ID_LENGTH: int = 32

const REJECT_MALFORMED_REQUEST := "malformed_request"
const REJECT_PROTOCOL_MISMATCH := "protocol_mismatch"
const REJECT_BUILD_MISMATCH := "build_mismatch"
const REJECT_CHARTER_MISMATCH := "charter_mismatch"
const REJECT_INVALID_NAME := "invalid_name"
const REJECT_INVALID_RETURN := "invalid_return"
const REJECT_RETURN_NAME_MISMATCH := "return_name_mismatch"
const REJECT_SESSION_FULL := "session_full"
const REJECT_HOST_ERROR := "host_error"
const REJECT_CODES: Array[String] = [
	REJECT_MALFORMED_REQUEST,
	REJECT_PROTOCOL_MISMATCH,
	REJECT_BUILD_MISMATCH,
	REJECT_CHARTER_MISMATCH,
	REJECT_INVALID_NAME,
	REJECT_INVALID_RETURN,
	REJECT_RETURN_NAME_MISMATCH,
	REJECT_SESSION_FULL,
	REJECT_HOST_ERROR,
]
const HELLO_FIELDS: Array[String] = [
	"kind",
	"protocol_version",
	"signature",
	"runtime_source_sha256",
	"build_id",
	"name",
	"reconnect_token",
	"charter_catalog_hash",
]
const LEGACY_HELLO_FIELDS: Array[String] = [
	"kind",
	"signature",
	"name",
	"reconnect_token",
	"charter_catalog_hash",
]
const ACCEPT_FIELDS: Array[String] = [
	"kind",
	"protocol_version",
	"signature",
	"runtime_source_sha256",
	"build_id",
	"peer_id",
	"entity_id",
	"player_count",
	"reconnect_token",
	"resumed",
	"charter_id",
	"charter_hash",
	"maximum_players",
]
const REJECT_FIELDS: Array[String] = ["kind", "code", "host_build_id"]
const LEGACY_REJECT_FIELDS: Array[String] = ["kind", "reason"]

const PACKET_HELLO: int = 1
const PACKET_ACCEPT: int = 2
const PACKET_REJECT: int = 3
const PACKET_INPUT: int = 4
const PACKET_SNAPSHOT: int = 5
const PACKET_REQUEST: int = 6
const PACKET_RECONCILIATION: int = 7
const PACKET_ADMIN_CLOSE: int = 8
const PACKET_SNAPSHOT_FRAGMENT: int = 9
const PACKET_RECONCILIATION_FRAGMENT: int = 10
const MAX_ADMIN_REASON_LENGTH: int = 80
const MAX_QUEUED_SNAPSHOTS: int = 2
const MAX_QUEUED_REQUESTS: int = MAX_REMOTE_CLIENTS * 4
const MAX_QUEUED_RECONCILIATIONS: int = 2
const SNAPSHOT_CHANNEL: int = 0
const RECONCILIATION_CHANNEL: int = 1
const REQUEST_EMOTE: int = 1
const REQUEST_TRAINING_RESET: int = 2
const REQUEST_CHAMPION_NEXT: int = 3
const REQUEST_READY_TOGGLE: int = 4
const REQUEST_PRACTICE_START: int = 5
const REQUEST_SPELL_EQUIP: int = 6
const REQUEST_IMPACT_PRACTICE: int = 7
const REQUEST_CHAMPION_SELECT: int = 8
const REQUEST_WEAVE_APPLY: int = 9
# Twelve weave positions x a bounded catalog lane. The request carries only a
# library index; the host resolves it against the canonical runtime wire order.
const MAX_SPELL_LIBRARY_SIZE: int = 64
const MAX_SPELL_EQUIP_VALUE: int = PlayerState.SPELL_SLOT_COUNT * MAX_SPELL_LIBRARY_SIZE

var peer: ENetMultiplayerPeer
var mode: int = Mode.OFFLINE
var bound_port: int = 0
var join_address: String = ""
var session_signature: String = ""
var session_charter_id: String = ""
var session_charter_hash: String = ""
var maximum_players: int = MAX_PLAYERS
var player_name: String = "Traveller"
var last_error: String = ""
var status_detail: String = "Offline"
var accepted: bool = false
var local_peer_id: int = 0
var local_entity_id: int = 0
var accepted_peer_ids := PackedInt32Array()
var incoming_inputs: Array[Dictionary] = []
var incoming_snapshots: Array[Dictionary] = []
var incoming_envelopes: Array[Dictionary] = []
var incoming_requests: Array[Dictionary] = []
var incoming_reconciliations: Array[Dictionary] = []
var joined_peers: Array[Dictionary] = []
var disconnected_peers: Array[Dictionary] = []
var last_input_sequence_by_peer: Dictionary[int, int] = {}
var last_request_sequence_by_peer: Dictionary[int, int] = {}
var entity_by_peer: Dictionary[int, int] = {}
var name_by_peer: Dictionary[int, String] = {}
var reconnect_token_by_peer: Dictionary[int, String] = {}
var reconnect_reservations: Dictionary[String, Dictionary] = {}
var administrative_disconnect_reason_by_peer: Dictionary[int, String] = {}
var administrative_disconnect_deadline_by_peer: Dictionary[int, int] = {}
var administrative_delivery_deadline_by_peer: Dictionary[int, int] = {}
var reconnect_token: String = ""
var reconnect_address: String = ""
var reconnect_port: int = 0
var reconnect_signature: String = ""
var reconnect_runtime_source_sha256: String = ""
var reconnect_build_id: String = ""
var runtime_source_sha256: String = ""
var build_id: String = ""
var remote_build_id: String = ""
var _runtime_identity_configured: bool = false
var _hello_sent: bool = false
var _connect_started_ms: int = 0
var _server_disconnect_pending: bool = false
var _snapshot_assemblies: Dictionary[int, Dictionary] = {}
var world_epoch: int = 0
var _last_snapshot_epoch: int = -1
var _last_snapshot_tick: int = -1
var _reconciliation_assemblies: Dictionary[int, Dictionary] = {}
var _last_reconciliation_epoch: int = -1
var _last_reconciliation_tick: int = -1


static func compatibility_signature(
	protocol_version: int,
	tick_rate: int,
	map_hash: String,
	ability_hash: String,
	champion_hash: String,
	charter_catalog_hash: String = "",
	reaction_hash: String = "",
	runtime_source_hash: String = "",
) -> String:
	return CanonicalContent.sha256({
		"protocol_version": protocol_version,
		"snapshot_schema": SessionSnapshot.SCHEMA_VERSION,
		"world_snapshot_envelope_schema": WorldSnapshotEnvelope.SCHEMA_VERSION,
		"hex_world_snapshot_schema": HexWorldSnapshotCodec.SCHEMA_VERSION,
		"tick_rate": tick_rate,
		"movement_hash": MovementTuning.compatibility_hash(),
		"transition_hash": ActionTransitionPolicy.repository_hash(),
		"map_hash": map_hash,
		"ability_hash": ability_hash,
		"champion_hash": champion_hash,
		"charter_catalog_hash": charter_catalog_hash,
		"reaction_hash": reaction_hash,
		"runtime_source_sha256": runtime_source_hash,
		"snapshot_boundary_wall_ids": SessionSnapshot.WORLD_BOUNDARY_WALL_IDS,
	})


func configure_runtime_identity(manifest: Dictionary) -> bool:
	if mode != Mode.OFFLINE:
		return _fail("Runtime build identity can only be configured while offline")
	var previous_hash := runtime_source_sha256
	var previous_build_id := build_id
	_runtime_identity_configured = false
	runtime_source_sha256 = ""
	build_id = ""
	remote_build_id = ""
	var result := RuntimeBuildIdentity.validate_manifest(
		manifest,
		SimConfig.PROTOCOL_VERSION,
		SessionSnapshot.SCHEMA_VERSION,
	)
	if not bool(result.get("ok", false)):
		_clear_return_path()
		return _fail(String(result.get("error", "Runtime build identity is invalid.")))
	runtime_source_sha256 = String(result["runtime_source_sha256"])
	build_id = String(result["build_id"])
	_runtime_identity_configured = true
	if (not previous_hash.is_empty() or not previous_build_id.is_empty()) and (previous_hash != runtime_source_sha256 or previous_build_id != build_id):
		_clear_return_path()
	last_error = ""
	status_detail = "Offline"
	return true


func _ensure_runtime_identity() -> bool:
	if _runtime_identity_configured and _valid_build_identity(SimConfig.PROTOCOL_VERSION, runtime_source_sha256, build_id):
		return true
	var result := RuntimeBuildIdentity.load_current(
		SimConfig.PROTOCOL_VERSION,
		SessionSnapshot.SCHEMA_VERSION,
	)
	if not bool(result.get("ok", false)):
		_runtime_identity_configured = false
		runtime_source_sha256 = ""
		build_id = ""
		remote_build_id = ""
		return _fail(String(result.get("error", "Runtime build identity is unavailable.")))
	runtime_source_sha256 = String(result["runtime_source_sha256"])
	build_id = String(result["build_id"])
	_runtime_identity_configured = true
	return true


func start_host(
	port: int,
	signature: String,
	requested_player_name: String = "Host",
	requested_charter_id: String = SessionCharter.DEFAULT_ID,
	requested_charter_hash: String = "",
) -> bool:
	last_error = ""
	if not _ensure_runtime_identity():
		return false
	if not _valid_port(port, true):
		return _fail("Host port must be 0 for automatic testing or 1024-65535")
	if not _valid_signature(signature):
		return _fail("Session compatibility signature must be 64 lowercase hexadecimal characters")
	var safe_name := _validated_player_name(requested_player_name)
	if safe_name.is_empty():
		return _fail("Player name must contain 1-24 safe characters")
	var charter_hash := requested_charter_hash if not requested_charter_hash.is_empty() else SessionCharter.profile_hash(requested_charter_id)
	if not SessionCharter.validate_assignment(requested_charter_id, charter_hash):
		return _fail("Host session charter is invalid")
	var charter_capacity := SessionCharter.maximum_players(requested_charter_id)
	if charter_capacity < 2 or charter_capacity > MAX_PLAYERS:
		return _fail("Host session charter capacity is invalid")
	stop()
	var candidate := ENetMultiplayerPeer.new()
	# Keep the physical transport ceiling at eight so a charter-full client can
	# complete the guarded hello and receive an explicit refusal.
	var error: Error = candidate.create_server(port, MAX_REMOTE_CLIENTS)
	if error != OK:
		return _fail("Could not host UDP port %d (error %d)" % [port, error])
	peer = candidate
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.peer_disconnected.connect(_on_peer_disconnected)
	mode = Mode.HOSTING
	session_signature = signature
	session_charter_id = requested_charter_id
	session_charter_hash = charter_hash
	maximum_players = charter_capacity
	player_name = safe_name
	bound_port = peer.host.get_local_port()
	local_peer_id = SERVER_PEER_ID
	local_entity_id = SERVER_PEER_ID
	accepted = true
	accepted_peer_ids = PackedInt32Array()
	status_detail = _host_status()
	return true


func start_join(
	address: String,
	port: int,
	signature: String,
	requested_player_name: String = "Traveller",
	requested_charter_catalog_hash: String = "",
) -> bool:
	last_error = ""
	if not _ensure_runtime_identity():
		return false
	var safe_address := address.strip_edges()
	if not _valid_address(safe_address):
		return _fail("Join address must be a valid IPv4, IPv6 or host name")
	if not _valid_port(port, false):
		return _fail("Join port must be 1024-65535")
	if not _valid_signature(signature):
		return _fail("Session compatibility signature must be 64 lowercase hexadecimal characters")
	var safe_name := _validated_player_name(requested_player_name)
	if safe_name.is_empty():
		return _fail("Player name must contain 1-24 safe characters")
	var charter_catalog_hash := requested_charter_catalog_hash if not requested_charter_catalog_hash.is_empty() else SessionCharter.catalog_hash()
	if charter_catalog_hash.length() != 64:
		return _fail("Join session charter catalog identity is invalid")
	stop()
	var candidate := ENetMultiplayerPeer.new()
	var error: Error = candidate.create_client(safe_address, port)
	if error != OK:
		return _fail("Could not begin joining %s:%d (error %d)" % [safe_address, port, error])
	peer = candidate
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.peer_disconnected.connect(_on_peer_disconnected)
	mode = Mode.CONNECTING
	world_epoch = -1
	_reset_world_epoch_queues()
	session_signature = signature
	session_charter_id = ""
	session_charter_hash = charter_catalog_hash
	maximum_players = MAX_PLAYERS
	player_name = safe_name
	join_address = safe_address
	bound_port = port
	accepted = false
	local_peer_id = 0
	local_entity_id = 0
	_hello_sent = false
	_connect_started_ms = Time.get_ticks_msec()
	status_detail = "%s %s:%d" % ["Returning to" if not _reconnect_token_for_current_endpoint().is_empty() else "Seeking", join_address, bound_port]
	return true


func poll() -> void:
	if peer == null:
		return
	if is_host():
		_expire_reconnect_reservations(Time.get_ticks_msec())
	peer.poll()
	if is_host():
		var host_now_ms: int = Time.get_ticks_msec()
		_force_due_administrative_disconnects(host_now_ms)
		_force_due_administrative_delivery_closes(host_now_ms)
	# A reliable final packet and ENet's disconnect event can become observable
	# during the same service call. Consume packets first so an administration
	# reason (and its return revocation) wins over the generic host-loss status.
	var packets_processed: int = 0
	while peer != null and peer.get_available_packet_count() > 0 and packets_processed < MAX_PACKETS_PER_POLL:
		var sender_id: int = peer.get_packet_peer()
		var packet_bytes: PackedByteArray = peer.get_packet()
		_handle_packet(sender_id, packet_bytes)
		packets_processed += 1
		if peer == null:
			break
	if peer == null:
		return
	var queued_packets_remain: bool = (
		packets_processed == MAX_PACKETS_PER_POLL
		and peer.get_available_packet_count() > 0
	)
	if mode == Mode.CLIENT and (
		_server_disconnect_pending
		or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
	):
		if queued_packets_remain:
			# Keep the existing per-poll cap. The disconnected queue is finite, and
			# the centralized send gate prevents input while later polls look for a
			# final reason. Keep replica classification until the peer actually closes.
			_server_disconnect_pending = true
			status_detail = "Closing session"
			return
		_disconnect_with_error("Host left the session")
		return
	if mode == Mode.CONNECTING:
		var connection_status: int = peer.get_connection_status()
		if (
			_server_disconnect_pending
			or connection_status == MultiplayerPeer.CONNECTION_DISCONNECTED
		) and queued_packets_remain:
			status_detail = "Closing session"
			return
		elif _server_disconnect_pending or connection_status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_disconnect_with_error("Host could not be reached")
			return
		elif connection_status == MultiplayerPeer.CONNECTION_CONNECTED and not _hello_sent:
			local_peer_id = peer.get_unique_id()
			_send_to(SERVER_PEER_ID, {
				"kind": PACKET_HELLO,
				"protocol_version": SimConfig.PROTOCOL_VERSION,
				"signature": session_signature,
				"runtime_source_sha256": runtime_source_sha256,
				"build_id": build_id,
				"name": player_name,
				"reconnect_token": _reconnect_token_for_current_endpoint(),
				"charter_catalog_hash": session_charter_hash,
			})
			_hello_sent = true
			status_detail = "Verifying session"
		elif Time.get_ticks_msec() - _connect_started_ms > CONNECT_TIMEOUT_MS:
			_disconnect_with_error("Join timed out")
			return


func stop() -> void:
	_close_peer()
	remote_build_id = ""
	last_error = ""
	status_detail = "Offline"


func is_host() -> bool:
	return mode == Mode.HOSTING


func is_connected_client() -> bool:
	return mode == Mode.CLIENT and accepted


func is_online() -> bool:
	return is_host() or is_connected_client()


func configure_world_epoch(requested_epoch: int) -> bool:
	if requested_epoch < 0 or requested_epoch > WorldSnapshotEnvelope.MAX_EPOCH:
		return false
	if requested_epoch == world_epoch:
		return true
	world_epoch = requested_epoch
	_reset_world_epoch_queues()
	return true


func player_count() -> int:
	if is_host():
		return 1 + accepted_peer_ids.size()
	if is_connected_client():
		return 2
	return 1


func player_capacity() -> int:
	return maximum_players


func reserved_count() -> int:
	return reconnect_reservations.size() if is_host() else 0


func can_reconnect() -> bool:
	return (
		_valid_reconnect_token(reconnect_token)
		and not reconnect_address.is_empty()
		and reconnect_port > 0
		and _valid_signature(reconnect_signature)
		and reconnect_runtime_source_sha256 == runtime_source_sha256
		and reconnect_build_id == build_id
		and _valid_build_identity(SimConfig.PROTOCOL_VERSION, reconnect_runtime_source_sha256, reconnect_build_id)
	)


func send_input(sequence: int, command: SimCommand) -> bool:
	if not is_connected_client() or world_epoch < 0:
		return false
	var payload := {
		"kind": PACKET_INPUT,
		"world_epoch": world_epoch,
		"sequence": sequence,
		"move_x": command.move_x,
		"move_y": command.move_y,
		"held": command.held_actions,
		"pressed": command.pressed_actions,
		"aim_x": command.aim_x,
		"aim_y": command.aim_y,
		"aim_target_x": command.aim_target_x,
		"aim_target_y": command.aim_target_y,
	}
	if not _valid_input_packet(payload):
		return false
	return _send_to(SERVER_PEER_ID, payload)


func send_request(sequence: int, action: int, value: int = 0) -> bool:
	if not is_connected_client() or world_epoch < 0:
		return false
	var payload := {"kind": PACKET_REQUEST, "world_epoch": world_epoch, "sequence": sequence, "action": action, "value": value}
	if not _valid_request_packet(payload):
		return false
	return _send_to(SERVER_PEER_ID, payload)


func send_weave_request(sequence: int, champion_wire: int, expected: PackedInt32Array, requested: PackedInt32Array) -> bool:
	if not is_connected_client() or world_epoch < 0: return false
	var payload := {"kind": PACKET_REQUEST, "world_epoch": world_epoch, "sequence": sequence, "action": REQUEST_WEAVE_APPLY, "value": champion_wire,
		"expected": Array(expected), "wires": Array(requested)}
	return _send_to(SERVER_PEER_ID, payload) if _valid_request_packet(payload) else false


func take_inputs() -> Array[Dictionary]:
	var result: Array[Dictionary] = incoming_inputs
	incoming_inputs = []
	return result


func _queue_input(sender_id: int, accepted_input: Dictionary) -> void:
	var sender_count: int = 0
	var newest_sender_index: int = -1
	for index: int in range(incoming_inputs.size()):
		if int(incoming_inputs[index].get("peer_id", 0)) == sender_id:
			sender_count += 1
			newest_sender_index = index
	if sender_count < MAX_QUEUED_INPUTS_PER_PEER:
		incoming_inputs.append(accepted_input)
		return
	# Continuous input is sampled state, so the newest packet wins. Edge bits are
	# carried forward into that newest packet until authority consumes the lane.
	# Repeated presses of one bit before a simulation tick intentionally collapse
	# to one press, matching SimCommand's one-bit-per-tick action contract.
	var displaced: Dictionary = incoming_inputs[newest_sender_index]
	accepted_input["pressed"] = int(accepted_input.get("pressed", 0)) | int(displaced.get("pressed", 0))
	incoming_inputs[newest_sender_index] = accepted_input


func take_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = incoming_requests
	incoming_requests = []
	return result


func send_reconciliation(peer_id: int, reconciliation: Dictionary) -> bool:
	if not is_host() or world_epoch < 0 or not accepted_peer_ids.has(peer_id) or not ClientPrediction.validate_packet(reconciliation):
		return false
	var values: PackedInt64Array = reconciliation["values"]
	if values[0] != int(entity_by_peer.get(peer_id, 0)):
		return false
	var packets := _snapshot_wire_packets(reconciliation, true, world_epoch)
	if packets.is_empty():
		return false
	var sent := true
	for packet: Dictionary in packets:
		# As with snapshots, order whole authority ticks after bounded assembly;
		# a missing fragment must never hold back a newer movement correction.
		sent = _send_to(peer_id, packet, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, RECONCILIATION_CHANNEL) and sent
	return sent


func take_reconciliations() -> Array[Dictionary]:
	var result: Array[Dictionary] = incoming_reconciliations
	incoming_reconciliations = []
	return result


func take_joined_peers() -> Array[Dictionary]:
	var result: Array[Dictionary] = joined_peers
	joined_peers = []
	return result


func take_disconnected_peers() -> Array[Dictionary]:
	var result: Array[Dictionary] = disconnected_peers
	disconnected_peers = []
	return result


func host_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_host():
		return result
	for peer_id: int in accepted_peer_ids:
		result.append({
			"peer_id": peer_id,
			"entity_id": int(entity_by_peer.get(peer_id, 0)),
			"name": String(name_by_peer.get(peer_id, "Traveller")),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["entity_id"]) < int(right["entity_id"]))
	return result


func host_session_roster() -> Array[Dictionary]:
	var result := host_roster()
	if not is_host():
		return result
	for reservation: Dictionary in reconnect_reservations.values():
		result.append({
			"peer_id": 0,
			"entity_id": int(reservation.get("entity_id", 0)),
			"name": String(reservation.get("name", "Traveller")),
			"reserved": true,
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["entity_id"]) < int(right["entity_id"]))
	return result


func host_remove_entity(entity_id: int, requested_reason: String) -> bool:
	if not is_host() or entity_id < 2 or entity_id > MAX_PLAYERS:
		return false
	var reason := _validated_administration_reason(requested_reason)
	if reason.is_empty():
		return false
	var target_peer_id: int = 0
	for peer_id: int in accepted_peer_ids:
		if int(entity_by_peer.get(peer_id, 0)) == entity_id:
			target_peer_id = peer_id
			break
	if target_peer_id <= SERVER_PEER_ID:
		return false
	administrative_disconnect_reason_by_peer[target_peer_id] = reason
	administrative_disconnect_deadline_by_peer[target_peer_id] = Time.get_ticks_msec() + ADMIN_DISCONNECT_GRACE_MS
	if not _send_to(target_peer_id, {"kind": PACKET_ADMIN_CLOSE, "reason": reason}):
		administrative_disconnect_reason_by_peer.erase(target_peer_id)
		administrative_disconnect_deadline_by_peer.erase(target_peer_id)
		return false
	# Cooperative clients close on receipt. Poll enforces the same removal after
	# a short bounded grace if a modified client ignores the reliable notice.
	return true


func broadcast_snapshot(snapshot: Dictionary) -> bool:
	if not is_host() or not SessionSnapshot.validate(snapshot):
		return false
	var envelope: Dictionary = WorldSnapshotEnvelope.wrap_legacy(snapshot, world_epoch)
	return broadcast_envelope(envelope)


func broadcast_envelope(envelope: Dictionary) -> bool:
	if not is_host() or not WorldSnapshotEnvelope.validate(envelope) or int(envelope.world_epoch) != world_epoch:
		return false
	var packets: Array[Dictionary] = _wire_packets(envelope, false, int(envelope.world_epoch), int(envelope.tick))
	if packets.is_empty():
		return false
	var all_sent: bool = true
	for peer_id: int in accepted_peer_ids:
		for packet: Dictionary in packets:
			# Ordering belongs to complete snapshot ticks, not individual fragments.
			# Losing one fragment never blocks delivery of a newer complete frame.
			all_sent = _send_to(peer_id, packet, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, SNAPSHOT_CHANNEL) and all_sent
	return all_sent


func take_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = incoming_snapshots
	incoming_snapshots = []
	return result


func poll_envelopes() -> Array[Dictionary]:
	var result: Array[Dictionary] = incoming_envelopes
	incoming_envelopes = []
	return result


func _handle_packet(sender_id: int, packet_bytes: PackedByteArray) -> void:
	if is_host() and administrative_delivery_deadline_by_peer.has(sender_id):
		return
	if packet_bytes.is_empty() or packet_bytes.size() > MAX_PACKET_BYTES:
		return
	var decoded: Variant = bytes_to_var(packet_bytes)
	if not decoded is Dictionary:
		return
	var packet: Dictionary = decoded
	if typeof(packet.get("kind")) != TYPE_INT:
		return
	var kind: int = int(packet["kind"])
	if is_host():
		match kind:
			PACKET_HELLO:
				_handle_hello(sender_id, packet)
			PACKET_INPUT:
				var sequence: int = int(packet.get("sequence", -1))
				var previous_sequence: int = last_input_sequence_by_peer.get(sender_id, -1)
				if (
					accepted_peer_ids.has(sender_id)
					and _packet_epoch_matches(packet)
					and _valid_input_packet(packet)
					and sequence > previous_sequence
				):
					var accepted_input: Dictionary = packet.duplicate(true)
					accepted_input["peer_id"] = sender_id
					accepted_input["entity_id"] = int(entity_by_peer.get(sender_id, 0))
					_queue_input(sender_id, accepted_input)
					last_input_sequence_by_peer[sender_id] = sequence
			PACKET_REQUEST:
				var sequence: int = int(packet.get("sequence", -1))
				var previous_sequence: int = last_request_sequence_by_peer.get(sender_id, -1)
				if (
					accepted_peer_ids.has(sender_id)
					and _packet_epoch_matches(packet)
					and _valid_request_packet(packet)
					and sequence > previous_sequence
					and incoming_requests.size() < MAX_QUEUED_REQUESTS
				):
					var accepted_request := {
						"peer_id": sender_id,
						"entity_id": int(entity_by_peer.get(sender_id, 0)),
						"world_epoch": world_epoch,
						"sequence": sequence,
						"action": int(packet["action"]),
						"value": int(packet["value"]),
					}
					if int(packet.action) == REQUEST_WEAVE_APPLY:
						accepted_request.expected = PackedInt32Array(packet.expected)
						accepted_request.wires = PackedInt32Array(packet.wires)
					incoming_requests.append(accepted_request)
					last_request_sequence_by_peer[sender_id] = sequence
		return
	if sender_id != SERVER_PEER_ID:
		return
	if mode == Mode.CONNECTING:
		match kind:
			PACKET_ACCEPT:
				_handle_accept(packet)
			PACKET_REJECT:
				_handle_reject(packet)
		return
	if mode == Mode.CLIENT:
		if kind == PACKET_ADMIN_CLOSE:
			var administration_reason := _validated_administration_reason(String(packet.get("reason", "")))
			if administration_reason.is_empty():
				return
			_clear_return_path()
			_disconnect_with_error(administration_reason)
			return
		if kind == PACKET_SNAPSHOT:
			_accept_envelope(_envelope_from_wire_packet(packet))
		elif kind == PACKET_SNAPSHOT_FRAGMENT:
			_accept_envelope(_envelope_from_fragment(packet))
		elif kind == PACKET_RECONCILIATION:
			_accept_reconciliation(_snapshot_from_wire_packet(packet, true), int(packet.get("world_epoch", -1)))
		elif kind == PACKET_RECONCILIATION_FRAGMENT:
			_accept_reconciliation(_snapshot_from_fragment(packet, true), int(packet.get("world_epoch", -1)))


func _handle_hello(sender_id: int, packet: Dictionary) -> void:
	if sender_id <= SERVER_PEER_ID or accepted_peer_ids.has(sender_id):
		return
	if not _valid_hello_packet(packet):
		_send_reject(sender_id, REJECT_PROTOCOL_MISMATCH if _valid_legacy_hello_packet(packet) else REJECT_MALFORMED_REQUEST)
		return
	if int(packet["protocol_version"]) != SimConfig.PROTOCOL_VERSION:
		_send_reject(sender_id, REJECT_PROTOCOL_MISMATCH)
		return
	if (
		String(packet["runtime_source_sha256"]) != runtime_source_sha256
		or String(packet["build_id"]) != build_id
		or String(packet["signature"]) != session_signature
	):
		_send_reject(sender_id, REJECT_BUILD_MISMATCH)
		return
	if String(packet["charter_catalog_hash"]) != SessionCharter.catalog_hash():
		_send_reject(sender_id, REJECT_CHARTER_MISMATCH)
		return
	var safe_name := _validated_player_name(String(packet["name"]))
	if safe_name.is_empty():
		_send_reject(sender_id, REJECT_INVALID_NAME)
		return
	var requested_reconnect_token := String(packet["reconnect_token"])
	var resumed: bool = false
	var entity_id: int = 0
	var consumed_reconnect_token: String = ""
	if not requested_reconnect_token.is_empty():
		if not _valid_reconnect_token(requested_reconnect_token) or not reconnect_reservations.has(requested_reconnect_token):
			_send_reject(sender_id, REJECT_INVALID_RETURN)
			return
		var reservation: Dictionary = reconnect_reservations[requested_reconnect_token]
		if String(reservation.get("name", "")) != safe_name:
			_send_reject(sender_id, REJECT_RETURN_NAME_MISMATCH)
			return
		entity_id = int(reservation.get("entity_id", 0))
		consumed_reconnect_token = requested_reconnect_token
		resumed = true
	else:
		if accepted_peer_ids.size() + reconnect_reservations.size() >= maximum_players - 1:
			_send_reject(sender_id, REJECT_SESSION_FULL)
			return
		entity_id = _allocate_entity_id()
	if entity_id == 0:
		_send_reject(sender_id, REJECT_SESSION_FULL)
		return
	var rotated_reconnect_token := _new_reconnect_token()
	if rotated_reconnect_token.is_empty():
		_send_reject(sender_id, REJECT_HOST_ERROR)
		return
	if resumed:
		reconnect_reservations.erase(consumed_reconnect_token)
	accepted_peer_ids.append(sender_id)
	accepted_peer_ids.sort()
	entity_by_peer[sender_id] = entity_id
	name_by_peer[sender_id] = safe_name
	reconnect_token_by_peer[sender_id] = rotated_reconnect_token
	last_input_sequence_by_peer[sender_id] = -1
	last_request_sequence_by_peer[sender_id] = -1
	joined_peers.append({"peer_id": sender_id, "entity_id": entity_id, "name": safe_name, "resumed": resumed})
	_send_to(sender_id, {
		"kind": PACKET_ACCEPT,
		"protocol_version": SimConfig.PROTOCOL_VERSION,
		"signature": session_signature,
		"runtime_source_sha256": runtime_source_sha256,
		"build_id": build_id,
		"peer_id": sender_id,
		"entity_id": entity_id,
		"player_count": player_count(),
		"reconnect_token": rotated_reconnect_token,
		"resumed": resumed,
		"charter_id": session_charter_id,
		"charter_hash": session_charter_hash,
		"maximum_players": maximum_players,
	})
	status_detail = _host_status()


func _handle_accept(packet: Dictionary) -> void:
	if not _valid_accept_shape(packet):
		_disconnect_with_error("Host sent a malformed session acceptance")
		return
	var host_build_id := String(packet["build_id"])
	if int(packet["protocol_version"]) != SimConfig.PROTOCOL_VERSION:
		if _valid_display_build_id(host_build_id):
			remote_build_id = host_build_id
		_disconnect_with_error(reject_message(REJECT_PROTOCOL_MISMATCH, host_build_id, build_id))
		return
	if not _valid_build_identity(int(packet["protocol_version"]), String(packet["runtime_source_sha256"]), host_build_id):
		_disconnect_with_error("Host sent a malformed session acceptance")
		return
	if (
		String(packet["runtime_source_sha256"]) != runtime_source_sha256
		or host_build_id != build_id
		or String(packet["signature"]) != session_signature
	):
		remote_build_id = host_build_id
		_disconnect_with_error(reject_message(REJECT_BUILD_MISMATCH, host_build_id, build_id))
		return
	var assigned_entity_id := int(packet["entity_id"])
	var assigned_peer_id := int(packet["peer_id"])
	var assigned_player_count := int(packet["player_count"])
	var assigned_charter_id := String(packet["charter_id"])
	var assigned_charter_hash := String(packet["charter_hash"])
	var assigned_maximum_players := int(packet["maximum_players"])
	var assigned_reconnect_token := String(packet["reconnect_token"])
	if (
		assigned_peer_id != local_peer_id
		or assigned_entity_id < 2 or assigned_entity_id > MAX_PLAYERS
		or assigned_player_count < 2 or assigned_player_count > assigned_maximum_players
	):
		_disconnect_with_error("Host assigned an invalid traveller identity")
		return
	if (
		not SessionCharter.validate_assignment(assigned_charter_id, assigned_charter_hash)
		or assigned_maximum_players != SessionCharter.maximum_players(assigned_charter_id)
	):
		_disconnect_with_error("Host assigned an invalid session charter")
		return
	if not _valid_reconnect_token(assigned_reconnect_token):
		_disconnect_with_error("Host assigned an invalid return token")
		return
	remote_build_id = host_build_id
	session_charter_id = assigned_charter_id
	session_charter_hash = assigned_charter_hash
	maximum_players = assigned_maximum_players
	local_entity_id = assigned_entity_id
	reconnect_token = assigned_reconnect_token
	reconnect_address = join_address
	reconnect_port = bound_port
	reconnect_signature = session_signature
	reconnect_runtime_source_sha256 = runtime_source_sha256
	reconnect_build_id = build_id
	accepted = true
	mode = Mode.CLIENT
	status_detail = "Joined %s · %s · %d places" % [join_address, SessionCharter.display_name(session_charter_id), maximum_players]


func _handle_reject(packet: Dictionary) -> void:
	if not _exact_fields(packet, REJECT_FIELDS):
		if _valid_legacy_reject_packet(packet):
			# Protocol 47 hosts return free-form `reason` text. Its presence only
			# classifies this as a legacy refusal; remote prose is never displayed.
			remote_build_id = ""
			_disconnect_with_error(reject_message(REJECT_BUILD_MISMATCH, "", build_id))
		return
	if typeof(packet["code"]) != TYPE_STRING or typeof(packet["host_build_id"]) != TYPE_STRING:
		return
	var code := String(packet["code"])
	var host_build_id := String(packet["host_build_id"])
	if not REJECT_CODES.has(code) or not _valid_display_build_id(host_build_id):
		return
	remote_build_id = host_build_id
	_disconnect_with_error(reject_message(code, host_build_id, build_id))


func _send_reject(target_peer_id: int, code: String) -> bool:
	if not REJECT_CODES.has(code):
		return false
	return _send_to(target_peer_id, {"kind": PACKET_REJECT, "code": code, "host_build_id": build_id})


func _send_to(
	target_peer_id: int,
	packet: Dictionary,
	transfer_mode: int = MultiplayerPeer.TRANSFER_MODE_RELIABLE,
	transfer_channel: int = 0,
) -> bool:
	if peer == null:
		return false
	if mode in [Mode.CONNECTING, Mode.CLIENT] and _server_disconnect_pending:
		return false
	if mode == Mode.CLIENT and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	var encoded: PackedByteArray = var_to_bytes(packet)
	if encoded.is_empty() or encoded.size() > MAX_PACKET_BYTES:
		return false
	peer.set_target_peer(target_peer_id)
	peer.transfer_mode = transfer_mode
	peer.transfer_channel = transfer_channel
	return peer.put_packet(encoded) == OK


static func _snapshot_wire_packet(snapshot: Dictionary) -> Dictionary:
	var envelope: Dictionary = WorldSnapshotEnvelope.wrap_legacy(snapshot, 0)
	return _envelope_wire_packet(envelope)


static func _envelope_wire_packet(envelope: Dictionary) -> Dictionary:
	var packets: Array[Dictionary] = _envelope_wire_packets(envelope)
	return packets[0] if packets.size() == 1 else {}


static func _snapshot_wire_packets(snapshot: Dictionary, reconciliation: bool = false, packet_epoch: int = 0) -> Array[Dictionary]:
	if reconciliation:
		if not ClientPrediction.validate_packet(snapshot) or packet_epoch < 0 or packet_epoch > WorldSnapshotEnvelope.MAX_EPOCH:
			return []
		if snapshot.has("world_epoch") and (typeof(snapshot.world_epoch) != TYPE_INT or int(snapshot.world_epoch) != packet_epoch):
			return []
		var stamped_reconciliation: Dictionary = snapshot.duplicate(true)
		stamped_reconciliation.world_epoch = packet_epoch
		return _wire_packets(stamped_reconciliation, true, packet_epoch, int(snapshot.tick))
	var envelope: Dictionary
	if WorldSnapshotEnvelope.validate(snapshot):
		envelope = snapshot
	else:
		envelope = WorldSnapshotEnvelope.wrap_legacy(snapshot, packet_epoch)
	return _wire_packets(envelope, false, int(envelope.get("world_epoch", -1)), int(envelope.get("tick", -1))) if not envelope.is_empty() else []


static func _envelope_wire_packets(envelope: Dictionary) -> Array[Dictionary]:
	if not WorldSnapshotEnvelope.validate(envelope):
		return []
	return _wire_packets(envelope, false, int(envelope.world_epoch), int(envelope.tick))


static func _wire_packets(payload_value: Dictionary, reconciliation: bool, packet_epoch: int, payload_tick: int) -> Array[Dictionary]:
	if packet_epoch < 0 or packet_epoch > WorldSnapshotEnvelope.MAX_EPOCH or payload_tick < 0 or payload_tick > WorldSnapshotEnvelope.MAX_TICK:
		return []
	var raw: PackedByteArray = var_to_bytes(payload_value)
	if raw.is_empty() or raw.size() > (MAX_PACKET_BYTES if reconciliation else MAX_SNAPSHOT_UNCOMPRESSED_BYTES):
		return []
	var compressed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_FASTLZ)
	if compressed.is_empty():
		return []
	var single := {
		"kind": PACKET_RECONCILIATION if reconciliation else PACKET_SNAPSHOT,
		"world_epoch": packet_epoch,
		"tick": payload_tick,
		"raw_size": raw.size(),
		"payload": compressed,
	}
	if var_to_bytes(single).size() <= ENET_MTU_BYTES:
		return [single]
	@warning_ignore("integer_division")
	var count: int = (compressed.size() + SNAPSHOT_FRAGMENT_PAYLOAD_BYTES - 1) / SNAPSHOT_FRAGMENT_PAYLOAD_BYTES
	if count > MAX_SNAPSHOT_FRAGMENTS:
		return []
	var packets: Array[Dictionary] = []
	for index: int in range(count):
		var packet := {
			"kind": PACKET_RECONCILIATION_FRAGMENT if reconciliation else PACKET_SNAPSHOT_FRAGMENT,
			"world_epoch": packet_epoch,
			"tick": payload_tick,
			"raw_size": raw.size(), "count": count, "index": index,
			"payload": compressed.slice(index * SNAPSHOT_FRAGMENT_PAYLOAD_BYTES, (index + 1) * SNAPSHOT_FRAGMENT_PAYLOAD_BYTES),
		}
		if var_to_bytes(packet).size() > ENET_MTU_BYTES:
			return []
		packets.append(packet)
	return packets


func _accept_snapshot(snapshot: Dictionary) -> void:
	var epoch: int = maxi(0, world_epoch)
	var envelope: Dictionary = WorldSnapshotEnvelope.wrap_legacy(snapshot, epoch)
	_accept_envelope(envelope)


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


func _snapshot_from_fragment(packet: Dictionary, reconciliation: bool = false) -> Dictionary:
	var decoded: Dictionary = _payload_from_fragment(packet, reconciliation)
	if decoded.is_empty():
		return decoded
	if reconciliation:
		return _legacy_reconciliation_view(decoded, int(packet.get("world_epoch", -1)))
	return (decoded.authority as Dictionary).duplicate(true) if int(decoded.world_kind) == WorldSnapshotEnvelope.WORLD_LEGACY else {}


func _envelope_from_fragment(packet: Dictionary) -> Dictionary:
	return _payload_from_fragment(packet, false)


func _payload_from_fragment(packet: Dictionary, reconciliation: bool) -> Dictionary:
	for key: String in ["kind", "world_epoch", "tick", "raw_size", "count", "index"]:
		if typeof(packet.get(key)) != TYPE_INT:
			return {}
	var packet_epoch: int = int(packet.world_epoch)
	var snapshot_tick: int = int(packet.tick)
	var count: int = int(packet["count"])
	var index: int = int(packet["index"])
	var raw_size: int = int(packet["raw_size"])
	var assemblies: Dictionary[int, Dictionary] = _reconciliation_assemblies if reconciliation else _snapshot_assemblies
	var last_epoch: int = _last_reconciliation_epoch if reconciliation else _last_snapshot_epoch
	var last_tick: int = _last_reconciliation_tick if reconciliation else _last_snapshot_tick
	if (
		int(packet["kind"]) != (PACKET_RECONCILIATION_FRAGMENT if reconciliation else PACKET_SNAPSHOT_FRAGMENT)
		or packet_epoch < 0 or packet_epoch > WorldSnapshotEnvelope.MAX_EPOCH
		or snapshot_tick < 0 or snapshot_tick > WorldSnapshotEnvelope.MAX_TICK
		or not _pair_after(packet_epoch, snapshot_tick, last_epoch, last_tick)
		or (reconciliation and packet_epoch != world_epoch)
		or (not reconciliation and world_epoch >= 0 and packet_epoch < world_epoch)
		or count < 2 or count > MAX_SNAPSHOT_FRAGMENTS or index < 0 or index >= count
		or raw_size < 1 or raw_size > (MAX_PACKET_BYTES if reconciliation else MAX_SNAPSHOT_UNCOMPRESSED_BYTES)
		or typeof(packet.get("payload")) != TYPE_PACKED_BYTE_ARRAY
	):
		return {}
	var payload: PackedByteArray = packet["payload"]
	if payload.is_empty() or payload.size() > SNAPSHOT_FRAGMENT_PAYLOAD_BYTES:
		return {}
	if index < count - 1 and payload.size() != SNAPSHOT_FRAGMENT_PAYLOAD_BYTES:
		return {}
	var now: int = Time.get_ticks_msec()
	for pending_key: int in assemblies.keys():
		if now - int(assemblies[pending_key]["created_ms"]) > SNAPSHOT_ASSEMBLY_TIMEOUT_MS:
			assemblies.erase(pending_key)
	var assembly_key: int = _pair_key(packet_epoch, snapshot_tick)
	if not assemblies.has(assembly_key):
		if assemblies.size() >= MAX_PENDING_SNAPSHOT_ASSEMBLIES:
			var oldest_key: int = assemblies.keys().min()
			if assembly_key < oldest_key:
				return {}
			assemblies.erase(oldest_key)
		assemblies[assembly_key] = {"world_epoch": packet_epoch, "tick": snapshot_tick, "count": count, "raw_size": raw_size, "created_ms": now, "parts": {}}
	var assembly: Dictionary = assemblies[assembly_key]
	if int(assembly["count"]) != count or int(assembly["raw_size"]) != raw_size:
		assemblies.erase(assembly_key)
		return {}
	var parts: Dictionary = assembly["parts"]
	if parts.has(index) and parts[index] != payload:
		assemblies.erase(assembly_key)
		return {}
	parts[index] = payload
	if parts.size() != count:
		return {}
	var compressed := PackedByteArray()
	for part_index: int in range(count):
		compressed.append_array(parts[part_index])
	assemblies.erase(assembly_key)
	return _decode_wire_packet({
		"kind": PACKET_RECONCILIATION if reconciliation else PACKET_SNAPSHOT,
		"world_epoch": packet_epoch,
		"tick": snapshot_tick,
		"raw_size": raw_size,
		"payload": compressed,
	}, reconciliation)


static func _snapshot_from_wire_packet(packet: Dictionary, reconciliation: bool = false) -> Dictionary:
	var decoded: Dictionary = _decode_wire_packet(packet, reconciliation)
	if decoded.is_empty():
		return decoded
	if reconciliation:
		return _legacy_reconciliation_view(decoded, int(packet.get("world_epoch", -1)))
	return (decoded.authority as Dictionary).duplicate(true) if int(decoded.world_kind) == WorldSnapshotEnvelope.WORLD_LEGACY else {}


static func _envelope_from_wire_packet(packet: Dictionary) -> Dictionary:
	return _decode_wire_packet(packet, false)


static func _legacy_reconciliation_view(reconciliation: Dictionary, packet_epoch: int) -> Dictionary:
	if packet_epoch != 0:
		return reconciliation
	var result: Dictionary = reconciliation.duplicate(true)
	result.erase("world_epoch")
	return result


static func _decode_wire_packet(packet: Dictionary, reconciliation: bool) -> Dictionary:
	for key: String in ["kind", "world_epoch", "tick", "raw_size"]:
		if typeof(packet.get(key)) != TYPE_INT:
			return {}
	if int(packet.kind) != (PACKET_RECONCILIATION if reconciliation else PACKET_SNAPSHOT):
		return {}
	var packet_epoch: int = int(packet.world_epoch)
	var packet_tick: int = int(packet.tick)
	var raw_size: int = int(packet.raw_size)
	var payload_value: Variant = packet.get("payload")
	if (
		packet_epoch < 0 or packet_epoch > WorldSnapshotEnvelope.MAX_EPOCH
		or packet_tick < 0 or packet_tick > WorldSnapshotEnvelope.MAX_TICK
		or raw_size < 1
		or raw_size > (MAX_PACKET_BYTES if reconciliation else MAX_SNAPSHOT_UNCOMPRESSED_BYTES)
		or typeof(payload_value) != TYPE_PACKED_BYTE_ARRAY
	):
		return {}
	var payload: PackedByteArray = payload_value
	if payload.is_empty() or payload.size() > MAX_SNAPSHOT_FRAGMENTS * SNAPSHOT_FRAGMENT_PAYLOAD_BYTES:
		return {}
	var raw: PackedByteArray = payload.decompress(raw_size, FileAccess.COMPRESSION_FASTLZ)
	if raw.size() != raw_size:
		return {}
	var decoded: Variant = bytes_to_var(raw)
	if not decoded is Dictionary:
		return {}
	var result: Dictionary = decoded
	if reconciliation:
		return result if ClientPrediction.validate_packet(result) and typeof(result.get("world_epoch")) == TYPE_INT and int(result.world_epoch) == packet_epoch and int(result.tick) == packet_tick else {}
	return result if WorldSnapshotEnvelope.validate(result) and int(result.world_epoch) == packet_epoch and int(result.tick) == packet_tick else {}


func _packet_epoch_matches(packet: Dictionary) -> bool:
	return world_epoch >= 0 and typeof(packet.get("world_epoch")) == TYPE_INT and int(packet.world_epoch) == world_epoch


func _reset_world_epoch_queues() -> void:
	incoming_inputs = []
	incoming_requests = []
	incoming_snapshots = []
	incoming_envelopes = []
	incoming_reconciliations = []
	_snapshot_assemblies = {}
	_reconciliation_assemblies = {}
	_last_snapshot_epoch = world_epoch
	_last_snapshot_tick = -1
	_last_reconciliation_epoch = world_epoch
	_last_reconciliation_tick = -1


func _purge_snapshot_state_through(accepted_epoch: int, accepted_tick: int, epoch_changed: bool) -> void:
	var accepted_key: int = _pair_key(accepted_epoch, accepted_tick)
	for pending_key: int in _snapshot_assemblies.keys():
		if pending_key <= accepted_key:
			_snapshot_assemblies.erase(pending_key)
	for index: int in range(incoming_envelopes.size() - 1, -1, -1):
		var queued: Dictionary = incoming_envelopes[index]
		if int(queued.world_epoch) < accepted_epoch:
			incoming_envelopes.remove_at(index)
	# Legacy snapshots have no embedded epoch, so their adapter queue cannot
	# safely survive acceptance of a complete newer epoch.
	if epoch_changed:
		incoming_snapshots = []


static func _pair_after(epoch: int, tick: int, previous_epoch: int, previous_tick: int) -> bool:
	return epoch > previous_epoch or (epoch == previous_epoch and tick > previous_tick)


static func _pair_key(epoch: int, tick: int) -> int:
	return (epoch << 32) | tick


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host():
		administrative_delivery_deadline_by_peer.erase(peer_id)
		var entity_id: int = entity_by_peer.get(peer_id, 0)
		var disconnected_name: String = name_by_peer.get(peer_id, "Traveller")
		var return_token: String = reconnect_token_by_peer.get(peer_id, "")
		var administration_reason: String = administrative_disconnect_reason_by_peer.get(peer_id, "")
		var index: int = accepted_peer_ids.find(peer_id)
		if index >= 0:
			accepted_peer_ids.remove_at(index)
		if entity_id > 0 and not administration_reason.is_empty():
			disconnected_peers.append({
				"peer_id": peer_id,
				"entity_id": entity_id,
				"name": disconnected_name,
				"reserved": false,
				"administrative": true,
				"reason": administration_reason,
			})
		elif entity_id > 0 and _valid_reconnect_token(return_token):
			reconnect_reservations[return_token] = {
				"entity_id": entity_id,
				"name": disconnected_name,
				"expires_ms": Time.get_ticks_msec() + RECONNECT_WINDOW_MS,
			}
			disconnected_peers.append({"peer_id": peer_id, "entity_id": entity_id, "name": disconnected_name, "reserved": true})
		elif entity_id > 0:
			disconnected_peers.append({"peer_id": peer_id, "entity_id": entity_id, "name": disconnected_name, "reserved": false})
		for input_index: int in range(incoming_inputs.size() - 1, -1, -1):
			if int(incoming_inputs[input_index].get("peer_id", 0)) == peer_id:
				incoming_inputs.remove_at(input_index)
		last_input_sequence_by_peer.erase(peer_id)
		last_request_sequence_by_peer.erase(peer_id)
		entity_by_peer.erase(peer_id)
		name_by_peer.erase(peer_id)
		reconnect_token_by_peer.erase(peer_id)
		administrative_disconnect_reason_by_peer.erase(peer_id)
		administrative_disconnect_deadline_by_peer.erase(peer_id)
		status_detail = _host_status()
	elif peer_id == SERVER_PEER_ID:
		# ENet can signal this from inside peer.poll() while a final reliable
		# administration packet is already queued. Defer closing the peer until poll
		# has drained that queue; the central send gate blocks all further output.
		_server_disconnect_pending = true


func _disconnect_with_error(message: String) -> void:
	_close_peer()
	last_error = message
	status_detail = message


func _close_peer() -> void:
	if peer != null:
		peer.close()
	peer = null
	mode = Mode.OFFLINE
	bound_port = 0
	join_address = ""
	session_signature = ""
	session_charter_id = ""
	session_charter_hash = ""
	maximum_players = MAX_PLAYERS
	accepted = false
	local_peer_id = 0
	local_entity_id = 0
	accepted_peer_ids = PackedInt32Array()
	incoming_inputs = []
	incoming_snapshots = []
	incoming_envelopes = []
	_snapshot_assemblies = {}
	_reconciliation_assemblies = {}
	_last_snapshot_epoch = -1
	_last_reconciliation_epoch = -1
	_last_reconciliation_tick = -1
	_last_snapshot_tick = -1
	incoming_requests = []
	incoming_reconciliations = []
	joined_peers = []
	disconnected_peers = []
	last_input_sequence_by_peer = {}
	last_request_sequence_by_peer = {}
	entity_by_peer = {}
	name_by_peer = {}
	reconnect_token_by_peer = {}
	reconnect_reservations = {}
	administrative_disconnect_reason_by_peer = {}
	administrative_disconnect_deadline_by_peer = {}
	administrative_delivery_deadline_by_peer = {}
	_hello_sent = false
	_connect_started_ms = 0
	_server_disconnect_pending = false
	world_epoch = 0


func _fail(message: String) -> bool:
	last_error = message
	status_detail = message
	return false


func _allocate_entity_id() -> int:
	var used: Dictionary[int, bool] = {SERVER_PEER_ID: true}
	for entity_id: int in entity_by_peer.values():
		used[entity_id] = true
	for reservation: Dictionary in reconnect_reservations.values():
		used[int(reservation.get("entity_id", 0))] = true
	for candidate: int in range(2, MAX_PLAYERS + 1):
		if not used.has(candidate):
			return candidate
	return 0


func _expire_reconnect_reservations(now_ms: int) -> int:
	if not is_host():
		return 0
	var expired_tokens: Array[String] = []
	for return_token: String in reconnect_reservations:
		var reservation: Dictionary = reconnect_reservations[return_token]
		if now_ms >= int(reservation.get("expires_ms", 0)):
			expired_tokens.append(return_token)
	for return_token: String in expired_tokens:
		var reservation: Dictionary = reconnect_reservations[return_token]
		disconnected_peers.append({
			"peer_id": 0,
			"entity_id": int(reservation.get("entity_id", 0)),
			"name": String(reservation.get("name", "Traveller")),
			"reserved": false,
			"expired": true,
		})
		reconnect_reservations.erase(return_token)
	if not expired_tokens.is_empty():
		status_detail = _host_status()
	return expired_tokens.size()


func _force_due_administrative_disconnects(now_ms: int) -> int:
	if not is_host() or peer == null:
		return 0
	var due_peer_ids: Array[int] = []
	for peer_id: int in administrative_disconnect_deadline_by_peer:
		if now_ms >= int(administrative_disconnect_deadline_by_peer[peer_id]):
			due_peer_ids.append(peer_id)
	due_peer_ids.sort()
	for peer_id: int in due_peer_ids:
		administrative_disconnect_deadline_by_peer.erase(peer_id)
		if accepted_peer_ids.has(peer_id):
			# Revoke authority at the original 250 ms deadline. Do not call
			# disconnect_peer here: Godot's ENet implementation resets pending
			# reliable output before its ordinary disconnect, losing the reason.
			_on_peer_disconnected(peer_id)
			administrative_delivery_deadline_by_peer[peer_id] = now_ms + ADMIN_DELIVERY_GRACE_MS
	return due_peer_ids.size()


func _force_due_administrative_delivery_closes(now_ms: int) -> int:
	if not is_host() or peer == null:
		return 0
	var due_peer_ids: Array[int] = []
	for peer_id: int in administrative_delivery_deadline_by_peer:
		if now_ms >= int(administrative_delivery_deadline_by_peer[peer_id]):
			due_peer_ids.append(peer_id)
	due_peer_ids.sort()
	for peer_id: int in due_peer_ids:
		administrative_delivery_deadline_by_peer.erase(peer_id)
		# A cooperative client closes itself after displaying the reliable reason.
		# Only a still-present, non-cooperative socket reaches this bounded cleanup.
		peer.disconnect_peer(peer_id, true)
	return due_peer_ids.size()


func _reconnect_token_for_current_endpoint() -> String:
	if (
		_valid_reconnect_token(reconnect_token)
		and reconnect_address == join_address
		and reconnect_port == bound_port
		and reconnect_signature == session_signature
		and reconnect_runtime_source_sha256 == runtime_source_sha256
		and reconnect_build_id == build_id
	):
		return reconnect_token
	return ""


func _host_status() -> String:
	var returns := reconnect_reservations.size()
	return "Hosting %d/%d on UDP %d" % [player_count(), maximum_players, bound_port] if returns == 0 else "Hosting %d/%d + %d returning on UDP %d" % [player_count(), maximum_players, returns, bound_port]


static func _valid_reconnect_token(token: String) -> bool:
	if token.length() != RECONNECT_TOKEN_BYTES * 2:
		return false
	for character: String in token:
		if character not in "0123456789abcdef":
			return false
	return true


static func _new_reconnect_token() -> String:
	var bytes := Crypto.new().generate_random_bytes(RECONNECT_TOKEN_BYTES)
	var token := bytes.hex_encode()
	return token if _valid_reconnect_token(token) else ""


func _clear_return_path() -> void:
	reconnect_token = ""
	reconnect_address = ""
	reconnect_port = 0
	reconnect_signature = ""
	reconnect_runtime_source_sha256 = ""
	reconnect_build_id = ""


static func reject_message(code: String, host_build_id: String, local_build_id: String) -> String:
	var safe_host_id := host_build_id if _valid_display_build_id(host_build_id) else "unknown"
	var safe_local_id := local_build_id if _valid_display_build_id(local_build_id) else "unknown"
	var message := "Host refused the join request."
	match code:
		REJECT_MALFORMED_REQUEST:
			message = "Host refused a malformed join request."
		REJECT_PROTOCOL_MISMATCH, REJECT_BUILD_MISMATCH:
			message = "Different build: host %s, yours %s. Both players must extract the same complete portable ZIP into a new folder and launch it directly; an older installed shortcut opens an older build." % [safe_host_id, safe_local_id]
		REJECT_CHARTER_MISMATCH:
			message = "Incompatible session charter catalog."
		REJECT_INVALID_NAME:
			message = "Invalid traveller name."
		REJECT_INVALID_RETURN:
			message = "Return token expired or is invalid."
		REJECT_RETURN_NAME_MISMATCH:
			message = "Return token does not match traveller name."
		REJECT_SESSION_FULL:
			message = "Session is full."
		REJECT_HOST_ERROR:
			message = "Host could not reserve a secure return path."
	return message.left(MAX_REJECT_MESSAGE_LENGTH)


static func _validated_administration_reason(requested_reason: String) -> String:
	var reason := requested_reason.strip_edges()
	if reason.is_empty() or reason.length() > MAX_ADMIN_REASON_LENGTH:
		return ""
	for character: String in reason:
		if character.unicode_at(0) < 32:
			return ""
	return reason


static func _valid_port(port: int, allow_automatic: bool) -> bool:
	return (allow_automatic and port == 0) or (port >= 1024 and port <= 65_535)


static func _valid_signature(signature: String) -> bool:
	if signature.length() != 64:
		return false
	for character: String in signature:
		if character not in "0123456789abcdef":
			return false
	return true


static func _valid_build_identity(protocol_version: int, source_hash: String, display_id: String) -> bool:
	return (
		protocol_version >= 1
		and protocol_version <= RuntimeBuildIdentity.MAX_EXACT_INTEGER
		and _valid_signature(source_hash)
		and display_id == "p%d-%s" % [protocol_version, source_hash.left(RuntimeBuildIdentity.SHORT_HASH_LENGTH)]
	)


static func _valid_display_build_id(display_id: String) -> bool:
	if display_id.is_empty() or display_id.length() > MAX_BUILD_ID_LENGTH or not display_id.begins_with("p"):
		return false
	var separator := display_id.find("-")
	if separator < 2 or separator != display_id.rfind("-"):
		return false
	var protocol_text := display_id.substr(1, separator - 1)
	if protocol_text.begins_with("0"):
		return false
	for character: String in protocol_text:
		if character not in "0123456789":
			return false
	if protocol_text.to_int() < 1 or protocol_text.to_int() > RuntimeBuildIdentity.MAX_EXACT_INTEGER:
		return false
	var short_hash := display_id.substr(separator + 1)
	if short_hash.length() != RuntimeBuildIdentity.SHORT_HASH_LENGTH:
		return false
	for character: String in short_hash:
		if character not in "0123456789abcdef":
			return false
	return true


static func _exact_fields(packet: Dictionary, fields: Array[String]) -> bool:
	if packet.size() != fields.size():
		return false
	for key: Variant in packet.keys():
		if typeof(key) != TYPE_STRING or not fields.has(String(key)):
			return false
	for field: String in fields:
		if not packet.has(field):
			return false
	return true


static func _valid_hello_packet(packet: Dictionary) -> bool:
	if not _exact_fields(packet, HELLO_FIELDS):
		return false
	if typeof(packet["kind"]) != TYPE_INT or int(packet["kind"]) != PACKET_HELLO:
		return false
	if typeof(packet["protocol_version"]) != TYPE_INT:
		return false
	for field: String in ["signature", "runtime_source_sha256", "build_id", "name", "reconnect_token", "charter_catalog_hash"]:
		if typeof(packet[field]) != TYPE_STRING:
			return false
	var protocol_version := int(packet["protocol_version"])
	var signature := String(packet["signature"])
	var source_hash := String(packet["runtime_source_sha256"])
	var display_id := String(packet["build_id"])
	var reconnect_value := String(packet["reconnect_token"])
	return (
		_valid_signature(signature)
		and _valid_build_identity(protocol_version, source_hash, display_id)
		and _valid_signature(String(packet["charter_catalog_hash"]))
		and (reconnect_value.is_empty() or _valid_reconnect_token(reconnect_value))
	)


static func _valid_legacy_hello_packet(packet: Dictionary) -> bool:
	if not _exact_fields(packet, LEGACY_HELLO_FIELDS):
		return false
	if typeof(packet["kind"]) != TYPE_INT or int(packet["kind"]) != PACKET_HELLO:
		return false
	for field: String in ["signature", "name", "reconnect_token", "charter_catalog_hash"]:
		if typeof(packet[field]) != TYPE_STRING:
			return false
	var reconnect_value := String(packet["reconnect_token"])
	return (
		_valid_signature(String(packet["signature"]))
		and _valid_signature(String(packet["charter_catalog_hash"]))
		and (reconnect_value.is_empty() or _valid_reconnect_token(reconnect_value))
	)


static func _valid_legacy_reject_packet(packet: Dictionary) -> bool:
	return (
		_exact_fields(packet, LEGACY_REJECT_FIELDS)
		and typeof(packet["kind"]) == TYPE_INT
		and int(packet["kind"]) == PACKET_REJECT
		and typeof(packet["reason"]) == TYPE_STRING
		and not String(packet["reason"]).is_empty()
		and String(packet["reason"]).length() <= MAX_ADMIN_REASON_LENGTH
	)


static func _valid_accept_shape(packet: Dictionary) -> bool:
	if not _exact_fields(packet, ACCEPT_FIELDS):
		return false
	for field: String in ["kind", "protocol_version", "peer_id", "entity_id", "player_count", "maximum_players"]:
		if typeof(packet[field]) != TYPE_INT:
			return false
	for field: String in ["signature", "runtime_source_sha256", "build_id", "reconnect_token", "charter_id", "charter_hash"]:
		if typeof(packet[field]) != TYPE_STRING:
			return false
	return (
		int(packet["kind"]) == PACKET_ACCEPT
		and typeof(packet["resumed"]) == TYPE_BOOL
		and _valid_signature(String(packet["signature"]))
		and _valid_signature(String(packet["runtime_source_sha256"]))
	)


static func _valid_address(address: String) -> bool:
	if address.is_empty() or address.length() > 255:
		return false
	for character: String in address:
		if character.unicode_at(0) <= 32 or character in "/\\":
			return false
	return true


static func _validated_player_name(requested_name: String) -> String:
	var safe_name := requested_name.strip_edges()
	if safe_name.is_empty() or safe_name.length() > MAX_PLAYER_NAME_LENGTH:
		return ""
	for character: String in safe_name:
		var codepoint: int = character.unicode_at(0)
		if codepoint < 32 or codepoint == 127:
			return ""
	return safe_name


static func _valid_input_packet(packet: Dictionary) -> bool:
	if packet.has("world_epoch") and (typeof(packet.world_epoch) != TYPE_INT or int(packet.world_epoch) < 0 or int(packet.world_epoch) > WorldSnapshotEnvelope.MAX_EPOCH):
		return false
	if packet.has("aim_target_x") != packet.has("aim_target_y"):
		return false
	if packet.has("aim_target_x"):
		for key: String in ["aim_target_x", "aim_target_y"]:
			if typeof(packet[key]) != TYPE_INT or int(packet[key]) < -1 or int(packet[key]) > 100_000_000:
				return false
		if (int(packet["aim_target_x"]) == -1) != (int(packet["aim_target_y"]) == -1):
			return false
	for key: String in ["sequence", "move_x", "move_y", "aim_x", "aim_y", "held", "pressed"]:
		if not packet.has(key) or typeof(packet[key]) != TYPE_INT:
			return false
	if int(packet["sequence"]) < 0 or int(packet["sequence"]) > 0x7fffffff:
		return false
	for key: String in ["move_x", "move_y", "aim_x", "aim_y"]:
		var value: int = int(packet[key])
		if value < -1000 or value > 1000:
			return false
	var held: int = int(packet["held"])
	var pressed: int = int(packet["pressed"])
	return held >= 0 and held <= 0xffff and pressed >= 0 and pressed <= 0x1ffff


static func _valid_request_packet(packet: Dictionary) -> bool:
	if packet.has("world_epoch") and (typeof(packet.world_epoch) != TYPE_INT or int(packet.world_epoch) < 0 or int(packet.world_epoch) > WorldSnapshotEnvelope.MAX_EPOCH):
		return false
	if typeof(packet.get("sequence")) != TYPE_INT or typeof(packet.get("action")) != TYPE_INT or typeof(packet.get("value")) != TYPE_INT:
		return false
	var sequence := int(packet["sequence"])
	var action := int(packet["action"])
	var value := int(packet["value"])
	if sequence < 0 or sequence > 0x7fffffff:
		return false
	if action == REQUEST_WEAVE_APPLY:
		return value >= 1 and value <= 4096 and _valid_weave_wires(packet.get("expected"), true) and _valid_weave_wires(packet.get("wires"))
	if packet.has("expected") or packet.has("wires"): return false
	if action == REQUEST_SPELL_EQUIP:
		return value >= 1 and value <= MAX_SPELL_EQUIP_VALUE
	if action == REQUEST_CHAMPION_SELECT:
		return value >= 1 and value <= 4096
	return value == 0 and action in [REQUEST_EMOTE, REQUEST_TRAINING_RESET, REQUEST_CHAMPION_NEXT, REQUEST_READY_TOGGLE, REQUEST_PRACTICE_START, REQUEST_IMPACT_PRACTICE]


static func _valid_weave_wires(value: Variant, allow_empty: bool = false) -> bool:
	if not (value is Array or value is PackedInt32Array): return false
	if value.size() != PlayerState.SPELL_SLOT_COUNT: return false
	var seen := {}
	for wire: Variant in value:
		if typeof(wire) != TYPE_INT: return false
		if allow_empty and int(wire) == 0: continue
		if not CombatTuning.is_runtime_wire_id(int(wire)) or seen.has(int(wire)): return false
		seen[int(wire)] = true
	return true

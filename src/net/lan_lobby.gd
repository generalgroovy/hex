class_name LanLobby
extends CanvasLayer


const DISCOVERY_PORT: int = 24_873
const DISCOVERY_MAGIC: String = "FLUX2_LAN_V1"
const DISCOVERY_KIND_QUERY: String = "discover"
const DISCOVERY_KIND_ADVERTISEMENT: String = "advertise"
const BROADCAST_ADDRESS: String = "255.255.255.255"
const DISCOVERY_INTERVAL_MS: int = 750
const HOST_STALE_MS: int = 3_500
const LISTENER_RETRY_MS: int = 3_000
const MAX_DISCOVERY_PACKET_BYTES: int = 2_048
const MAX_DISCOVERED_HOSTS: int = 24
const MAX_PACKETS_PER_POLL: int = 32
const LEGACY_PROTOCOL: int = 47
const LEGACY_BUILD_ID: String = "p47-legacy"

var bootstrap: Node
var listener := PacketPeerUDP.new()
var broadcaster := PacketPeerUDP.new()
var listener_ready: bool = false
var broadcaster_ready: bool = false
var discovery_error: String = ""
var discovered_hosts: Dictionary = {}
var last_broadcast_ms: int = 0
var last_probe_ms: int = 0
var last_listener_retry_ms: int = 0
var browser_open: bool = false
var host_rows_fingerprint: String = ""
var visual_capture_run: bool = false

var panel: PanelContainer
var host_button: Button
var join_button: Button
var status_label: Label
var browser_box: VBoxContainer
var browser_status_label: Label
var host_rows: VBoxContainer


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	call_deferred("_initialize")


func _initialize() -> void:
	bootstrap = get_parent()
	visual_capture_run = _is_visual_capture_run()
	_build_ui()
	if not discovery_enabled(OS.get_cmdline_user_args()):
		discovery_error = "LAN discovery disabled for this diagnostic run."
		return
	_open_discovery_listener()
	_prepare_broadcaster()
	set_process(true)


func _exit_tree() -> void:
	listener.close()
	broadcaster.close()


static func discovery_enabled(arguments: PackedStringArray) -> bool:
	return not arguments.has("--no-lan-discovery")


func _process(_delta: float) -> void:
	if bootstrap == null:
		return
	var transport := _transport()
	if transport == null:
		return
	var focused_station_id := String(bootstrap.get("focused_station_id"))
	var context_visible := context_panel_visible(focused_station_id, visual_capture_run)
	panel.visible = context_visible
	if not context_visible and browser_open:
		browser_open = false
		browser_box.visible = false

	var now := Time.get_ticks_msec()
	if not listener_ready and now - last_listener_retry_ms >= LISTENER_RETRY_MS:
		_open_discovery_listener()
	_poll_discovery_packets()
	_expire_stale_hosts(now)

	if transport.is_host():
		_maybe_broadcast_host(now)
	elif browser_open and transport.mode == SessionTransport.Mode.OFFLINE:
		_maybe_probe_for_hosts(now)

	_update_ui()


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "LanMultiplayerPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -372.0
	panel.offset_right = -16.0
	# Reserve the combat session header and its independent feedback line at
	# the maximum supported HUD scale (1.5), including a small clear gap.
	panel.offset_top = 128.0
	panel.custom_minimum_size = Vector2(356.0, 0.0)
	panel.visible = false
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "FARFLOW · LAN MULTIPLAYER"
	title.add_theme_font_size_override("font_size", 15)
	outer.add_child(title)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	outer.add_child(actions)

	host_button = Button.new()
	host_button.text = "HOST"
	host_button.custom_minimum_size = Vector2(150.0, 42.0)
	host_button.pressed.connect(_on_host_pressed)
	actions.add_child(host_button)

	join_button = Button.new()
	join_button.text = "JOIN"
	join_button.custom_minimum_size = Vector2(150.0, 42.0)
	join_button.pressed.connect(_on_join_pressed)
	actions.add_child(join_button)

	status_label = Label.new()
	status_label.text = "Offline"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(status_label)

	browser_box = VBoxContainer.new()
	browser_box.visible = false
	browser_box.add_theme_constant_override("separation", 6)
	outer.add_child(browser_box)

	var separator := HSeparator.new()
	browser_box.add_child(separator)

	var browser_title := Label.new()
	browser_title.text = "FOUND HOSTS"
	browser_title.add_theme_font_size_override("font_size", 13)
	browser_box.add_child(browser_title)

	browser_status_label = Label.new()
	browser_status_label.text = "Searching local network…"
	browser_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	browser_box.add_child(browser_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 150.0)
	browser_box.add_child(scroll)

	host_rows = VBoxContainer.new()
	host_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_rows.add_theme_constant_override("separation", 5)
	scroll.add_child(host_rows)



static func context_panel_visible(focused_station_id: String, capture_run: bool) -> bool:
	return not capture_run and focused_station_id in ["farflow-host", "farflow-join", "farflow-charter"]


func _transport() -> SessionTransport:
	if bootstrap == null:
		return null
	return bootstrap.get("session_transport") as SessionTransport


func _on_host_pressed() -> void:
	var transport := _transport()
	if transport == null:
		return
	browser_open = false
	browser_box.visible = false
	bootstrap.call("_toggle_host_session")
	last_broadcast_ms = 0
	_update_ui()


func _on_join_pressed() -> void:
	var transport := _transport()
	if transport == null:
		return
	if transport.is_host():
		return
	if transport.mode != SessionTransport.Mode.OFFLINE:
		bootstrap.call("_return_to_offline", "You left the Farflow company.")
		browser_open = false
		browser_box.visible = false
		_update_ui()
		return
	if not browser_open and not bool(bootstrap.call("_ensure_runtime_identity")):
		_update_ui()
		return
	browser_open = not browser_open
	browser_box.visible = browser_open
	if browser_open:
		_open_discovery_listener()
		last_probe_ms = 0
		host_rows_fingerprint = ""
		_refresh_host_rows()
	_update_ui()


func _join_discovered_host(endpoint_key: String) -> void:
	if not discovered_hosts.has(endpoint_key):
		return
	var host: Dictionary = discovered_hosts[endpoint_key]
	if not bool(host.get("compatible", false)):
		return
	var transport := _transport()
	if transport == null:
		return
	if transport.mode != SessionTransport.Mode.OFFLINE:
		bootstrap.call("_return_to_offline", "Switching Farflow company.")
	bootstrap.set("join_address", String(host.get("address", "")))
	bootstrap.set("session_port", int(host.get("port", SessionTransport.DEFAULT_PORT)))
	browser_open = false
	browser_box.visible = false
	bootstrap.call("_start_join_session_now")
	_update_ui()


func _open_discovery_listener() -> void:
	if listener_ready:
		return
	last_listener_retry_ms = Time.get_ticks_msec()
	listener.close()
	listener = PacketPeerUDP.new()
	listener.set_broadcast_enabled(true)
	var error := listener.bind(DISCOVERY_PORT, "0.0.0.0")
	if error == OK:
		listener_ready = true
		discovery_error = ""
	else:
		listener_ready = false
		discovery_error = "LAN discovery unavailable (UDP %d, error %d)." % [DISCOVERY_PORT, error]


func _prepare_broadcaster() -> void:
	broadcaster.close()
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	var error := broadcaster.set_dest_address(BROADCAST_ADDRESS, DISCOVERY_PORT)
	broadcaster_ready = error == OK
	if not broadcaster_ready:
		discovery_error = "LAN advertising unavailable (error %d)." % error


func _maybe_probe_for_hosts(now: int) -> void:
	if not listener_ready or now - last_probe_ms < DISCOVERY_INTERVAL_MS:
		return
	last_probe_ms = now
	var query := JSON.stringify({
		"magic": DISCOVERY_MAGIC,
		"kind": DISCOVERY_KIND_QUERY,
	}).to_utf8_buffer()
	if listener.set_dest_address(BROADCAST_ADDRESS, DISCOVERY_PORT) == OK:
		listener.put_packet(query)


func _maybe_broadcast_host(now: int) -> void:
	if not broadcaster_ready:
		_prepare_broadcaster()
	if not broadcaster_ready or now - last_broadcast_ms < DISCOVERY_INTERVAL_MS:
		return
	last_broadcast_ms = now
	var bytes := _host_advertisement_bytes()
	if not bytes.is_empty():
		broadcaster.put_packet(bytes)


func _reply_to_discovery_query(address: String, port: int) -> void:
	if not listener_ready or address.is_empty() or port < 1_024 or port > 65_535:
		return
	var bytes := _host_advertisement_bytes()
	if bytes.is_empty():
		return
	if listener.set_dest_address(address, port) == OK:
		listener.put_packet(bytes)


func _host_advertisement_bytes() -> PackedByteArray:
	var transport := _transport()
	if transport == null or not transport.is_host() or not bool(bootstrap.call("_ensure_runtime_identity")):
		return PackedByteArray()
	var signature := String(bootstrap.call("_session_compatibility_signature"))
	if not _valid_signature(signature) or not _valid_build_identity(SimConfig.PROTOCOL_VERSION, transport.runtime_source_sha256, transport.build_id):
		return PackedByteArray()
	var name := String(bootstrap.get("local_player_name")).strip_edges().left(SessionTransport.MAX_PLAYER_NAME_LENGTH)
	var packet := {
		"magic": DISCOVERY_MAGIC,
		"kind": DISCOVERY_KIND_ADVERTISEMENT,
		"port": transport.bound_port,
		"name": name,
		"players": transport.player_count(),
		"capacity": transport.player_capacity(),
		"signature": signature,
		"protocol": SimConfig.PROTOCOL_VERSION,
		"runtime_source_sha256": transport.runtime_source_sha256,
		"build_id": transport.build_id,
	}
	var bytes := JSON.stringify(packet).to_utf8_buffer()
	return bytes if bytes.size() <= MAX_DISCOVERY_PACKET_BYTES else PackedByteArray()


func _poll_discovery_packets() -> void:
	if not listener_ready:
		return
	var processed := 0
	while listener.get_available_packet_count() > 0 and processed < MAX_PACKETS_PER_POLL:
		var bytes := listener.get_packet()
		var source_ip := listener.get_packet_ip()
		var source_port := listener.get_packet_port()
		processed += 1
		if bytes.is_empty() or bytes.size() > MAX_DISCOVERY_PACKET_BYTES:
			continue
		var decoded: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if typeof(decoded) != TYPE_DICTIONARY:
			continue
		var packet := decoded as Dictionary
		if String(packet.get("magic", "")) != DISCOVERY_MAGIC:
			continue
		var kind := String(packet.get("kind", ""))
		if kind == DISCOVERY_KIND_QUERY:
			var transport := _transport()
			if transport != null and transport.is_host():
				_reply_to_discovery_query(source_ip, source_port)
			continue
		if kind != DISCOVERY_KIND_ADVERTISEMENT:
			continue
		_accept_discovery_packet(packet, source_ip)


func _accept_discovery_packet(packet: Dictionary, source_ip: String) -> void:
	if bootstrap == null or not bool(bootstrap.call("_ensure_runtime_identity")):
		return
	var transport := _transport()
	if transport == null:
		return
	var local_signature := String(bootstrap.call("_session_compatibility_signature"))
	var host := normalized_host(packet, source_ip, local_signature, Time.get_ticks_msec(), transport.runtime_source_sha256)
	if host.is_empty():
		return
	var endpoint_key := "%s:%d" % [host["address"], host["port"]]
	discovered_hosts[endpoint_key] = host
	if discovered_hosts.size() > MAX_DISCOVERED_HOSTS:
		_remove_oldest_host()


static func normalized_host(packet: Dictionary, source_ip: String, local_signature: String, now_ms: int, local_source_hash: String = "") -> Dictionary:
	if String(packet.get("magic", "")) != DISCOVERY_MAGIC:
		return {}
	if String(packet.get("kind", "")) != DISCOVERY_KIND_ADVERTISEMENT:
		return {}
	if source_ip.is_empty():
		return {}
	var port := int(packet.get("port", 0))
	if port < 1_024 or port > 65_535:
		return {}
	var signature := String(packet.get("signature", ""))
	if not _valid_signature(signature) or not _valid_signature(local_signature):
		return {}
	if not _exact_protocol_number(packet.get("protocol", null)):
		return {}
	var protocol := int(packet["protocol"])
	var has_source_hash := packet.has("runtime_source_sha256")
	var has_build_id := packet.has("build_id")
	var source_hash := ""
	var host_build_id := ""
	if protocol == LEGACY_PROTOCOL and not has_source_hash and not has_build_id:
		host_build_id = LEGACY_BUILD_ID
	else:
		if not has_source_hash or not has_build_id:
			return {}
		if typeof(packet["runtime_source_sha256"]) != TYPE_STRING or typeof(packet["build_id"]) != TYPE_STRING:
			return {}
		source_hash = String(packet["runtime_source_sha256"])
		host_build_id = String(packet["build_id"])
		if not _valid_build_identity(protocol, source_hash, host_build_id):
			return {}
	var players := clampi(int(packet.get("players", 0)), 1, SessionTransport.MAX_PLAYERS)
	var capacity := clampi(int(packet.get("capacity", 0)), 2, SessionTransport.MAX_PLAYERS)
	if players > capacity:
		return {}
	var name := String(packet.get("name", "Host")).strip_edges().left(SessionTransport.MAX_PLAYER_NAME_LENGTH)
	if name.is_empty():
		name = "Host"
	var local_identity_valid := _valid_signature(local_source_hash)
	var local_build_id := "p%d-%s" % [SimConfig.PROTOCOL_VERSION, local_source_hash.left(RuntimeBuildIdentity.SHORT_HASH_LENGTH)] if local_identity_valid else "unknown"
	var protocol_matches := protocol == SimConfig.PROTOCOL_VERSION
	var compatible := protocol_matches and local_identity_valid and source_hash == local_source_hash and signature == local_signature
	return {
		"address": source_ip,
		"port": port,
		"name": name,
		"players": players,
		"capacity": capacity,
		"signature": signature,
		"runtime_source_sha256": source_hash,
		"build_id": host_build_id,
		"local_build_id": local_build_id,
		"compatible": compatible,
		"mismatch_code": "" if compatible else (SessionTransport.REJECT_PROTOCOL_MISMATCH if not protocol_matches else SessionTransport.REJECT_BUILD_MISMATCH),
		"protocol": protocol,
		"last_seen_ms": maxi(0, now_ms),
	}


static func _valid_signature(signature: String) -> bool:
	if signature.length() != 64:
		return false
	for index: int in range(signature.length()):
		var code := signature.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _exact_protocol_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= 1 and int(value) <= RuntimeBuildIdentity.MAX_EXACT_INTEGER
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric := float(value)
	return is_finite(numeric) and numeric >= 1.0 and numeric <= float(RuntimeBuildIdentity.MAX_EXACT_INTEGER) and floor(numeric) == numeric


static func _valid_build_identity(protocol: int, source_hash: String, display_id: String) -> bool:
	return (
		protocol >= 1
		and protocol <= RuntimeBuildIdentity.MAX_EXACT_INTEGER
		and _valid_signature(source_hash)
		and display_id == "p%d-%s" % [protocol, source_hash.left(RuntimeBuildIdentity.SHORT_HASH_LENGTH)]
	)


func _expire_stale_hosts(now: int) -> void:
	for key: Variant in discovered_hosts.keys():
		var host: Dictionary = discovered_hosts[key]
		if now - int(host.get("last_seen_ms", 0)) > HOST_STALE_MS:
			discovered_hosts.erase(key)


func _remove_oldest_host() -> void:
	var oldest_key: Variant = null
	var oldest_seen := Time.get_ticks_msec()
	for key: Variant in discovered_hosts.keys():
		var seen := int((discovered_hosts[key] as Dictionary).get("last_seen_ms", 0))
		if oldest_key == null or seen < oldest_seen:
			oldest_key = key
			oldest_seen = seen
	if oldest_key != null:
		discovered_hosts.erase(oldest_key)


func _update_ui() -> void:
	var transport := _transport()
	if transport == null or host_button == null:
		return
	if transport.is_host():
		host_button.text = "HOSTING %d/%d" % [transport.player_count(), transport.player_capacity()]
		host_button.disabled = false
		host_button.tooltip_text = "Click twice within the confirmation window to close the host."
		join_button.disabled = true
		join_button.text = "JOIN"
		status_label.text = "Hosting %s on this LAN · %s" % [transport.build_id, transport.status_detail]
	elif transport.is_connected_client():
		host_button.text = "HOST"
		host_button.disabled = true
		join_button.disabled = false
		join_button.text = "LEAVE"
		var joined_build_id := transport.remote_build_id if not transport.remote_build_id.is_empty() else transport.build_id
		status_label.text = "Joined %s · %s" % [joined_build_id, transport.status_detail]
	elif transport.mode == SessionTransport.Mode.CONNECTING:
		host_button.text = "HOST"
		host_button.disabled = true
		join_button.disabled = false
		join_button.text = "CANCEL"
		status_label.text = "Seeking with %s · %s" % [transport.build_id, transport.status_detail]
	else:
		host_button.text = "HOST"
		host_button.disabled = false
		host_button.tooltip_text = "Start a game visible to other FLUX players on this LAN."
		join_button.disabled = false
		join_button.text = "JOIN"
		status_label.text = transport.last_error if not transport.last_error.is_empty() else "Offline · Host or find a game on this Wi-Fi/LAN"

	browser_box.visible = browser_open and not transport.is_host()
	if browser_box.visible:
		_refresh_host_rows()


func _refresh_host_rows() -> void:
	if host_rows == null:
		return
	var keys: Array = discovered_hosts.keys()
	keys.sort_custom(
		func(left: Variant, right: Variant) -> bool:
			var a: Dictionary = discovered_hosts[left]
			var b: Dictionary = discovered_hosts[right]
			if bool(a.get("compatible", false)) != bool(b.get("compatible", false)):
				return bool(a.get("compatible", false))
			if int(a.get("players", 0)) != int(b.get("players", 0)):
				return int(a.get("players", 0)) > int(b.get("players", 0))
			return String(a.get("name", "")) < String(b.get("name", ""))
	)
	# Cache every displayed value, including the empty/error state. JSON preserves
	# field boundaries even when a host name contains punctuation. Freshness-only
	# advertisements need not recreate buttons or disturb keyboard/controller focus.
	var parts: Array = [discovery_error]
	for key: Variant in keys:
		var host: Dictionary = discovered_hosts[key]
		parts.append([
			key,
			host.get("name", "Host"),
			host.get("players", 0),
			host.get("capacity", 0),
			host.get("compatible", false),
			host.get("protocol", 0),
			host.get("signature", ""),
			host.get("runtime_source_sha256", ""),
			host.get("build_id", ""),
			host.get("local_build_id", ""),
			host.get("mismatch_code", ""),
		])
	var fingerprint := JSON.stringify(parts)
	if fingerprint == host_rows_fingerprint:
		return
	host_rows_fingerprint = fingerprint

	for child: Node in host_rows.get_children():
		host_rows.remove_child(child)
		child.queue_free()

	if keys.is_empty():
		browser_status_label.text = discovery_error if not discovery_error.is_empty() else "Searching local network… hosts appear automatically."
		return

	var compatible_count := 0
	for key: Variant in keys:
		var host: Dictionary = discovered_hosts[key]
		var compatible := bool(host.get("compatible", false))
		if compatible:
			compatible_count += 1
		var button := Button.new()
		var host_build_id := String(host.get("build_id", "unknown"))
		var local_build_id := String(host.get("local_build_id", "unknown"))
		button.text = (
			"%s · %d/%d\nBUILD %s" % [String(host.get("name", "Host")), int(host.get("players", 1)), int(host.get("capacity", 2)), host_build_id]
			if compatible
			else "%s · %d/%d · DIFFERENT BUILD\nHOST %s · YOU %s" % [String(host.get("name", "Host")), int(host.get("players", 1)), int(host.get("capacity", 2)), host_build_id, local_build_id]
		)
		button.disabled = not compatible
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0.0, 52.0 if compatible else 64.0)
		var endpoint_key := String(key)
		button.pressed.connect(func() -> void: _join_discovered_host(endpoint_key))
		host_rows.add_child(button)

	if compatible_count > 0:
		var local_build_id := String((discovered_hosts[keys[0]] as Dictionary).get("local_build_id", "unknown"))
		browser_status_label.text = "%d compatible host%s found · YOUR BUILD %s" % [compatible_count, "" if compatible_count == 1 else "s", local_build_id]
	else:
		browser_status_label.text = _mismatch_recovery_message(discovered_hosts[keys[0]] as Dictionary)


static func _mismatch_recovery_message(host: Dictionary) -> String:
	var host_build_id := String(host.get("build_id", "unknown"))
	var local_build_id := String(host.get("local_build_id", "unknown"))
	if host_build_id == LEGACY_BUILD_ID:
		return ("Different build: host %s, yours %s. Both players must extract the same complete portable ZIP into a new folder and launch it directly; an older installed shortcut opens an older build." % [host_build_id, local_build_id]).left(SessionTransport.MAX_REJECT_MESSAGE_LENGTH)
	var code := String(host.get("mismatch_code", SessionTransport.REJECT_BUILD_MISMATCH))
	return SessionTransport.reject_message(code, host_build_id, local_build_id)


func _is_visual_capture_run() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-") or argument == "--visual-specimen":
			return true
	return false

extends FluxTestSuite


const LOCAL_SOURCE_HASH := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const OTHER_SOURCE_HASH := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const COLLIDING_SOURCE_HASH := "aaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const LOCAL_BUILD_ID := "p%d-aaaaaaaaaaaa" % SimConfig.PROTOCOL_VERSION


class DiscoveryBootstrap:
	extends Node
	var session_transport := SessionTransport.new()
	var local_player_name := "Lantern Host"
	var join_address := ""
	var session_port := SessionTransport.DEFAULT_PORT
	var identity_ready := true
	var join_calls := 0
	var host_calls := 0
	var focused_station_id := "farflow-join"
	var gameplay_blocked := false
	var visible_result := false
	var active_cast := false
	var result_view_builds := 0
	var signature := "a".repeat(64)

	func _init() -> void:
		session_transport.runtime_source_sha256 = "a".repeat(64)
		session_transport.build_id = LOCAL_BUILD_ID

	func _ensure_runtime_identity() -> bool:
		if identity_ready:
			return true
		session_transport.last_error = "Build identity unavailable."
		return false

	func _session_compatibility_signature() -> String:
		return signature

	func _start_join_session_now() -> void:
		join_calls += 1

	func _return_to_offline(_reason: String) -> void:
		session_transport.mode = SessionTransport.Mode.OFFLINE

	func _toggle_host_session() -> void:
		host_calls += 1

	func _gameplay_input_blocked() -> bool:
		return gameplay_blocked

	func _has_visible_demo_result() -> bool:
		return visible_result

	func _demo_result_view() -> Dictionary:
		result_view_builds += 1
		return {"visible": visible_result}


class RetryLobby:
	extends LanLobby
	var listener_attempts: int = 0
	var listener_should_succeed: bool = false

	func _open_discovery_listener() -> void:
		listener_attempts += 1
		listener_ready = listener_should_succeed
		discovery_error = "" if listener_ready else "LAN discovery unavailable (test listener)."


class LegacyContextBootstrap:
	extends Node
	var session_transport := SessionTransport.new()
	var focused_station_id := "farflow-join"


class ContextLobby:
	extends LanLobby
	var discovery_polls := 0
	var host_broadcasts := 0
	var browser_probes := 0

	func _poll_discovery_packets() -> void:
		discovery_polls += 1

	func _maybe_broadcast_host(_now: int) -> void:
		host_broadcasts += 1

	func _maybe_probe_for_hosts(_now: int) -> void:
		browser_probes += 1


func run() -> int:
	check(LanLobby.discovery_enabled(PackedStringArray()), "normal play retains LAN discovery")
	check(not LanLobby.discovery_enabled(PackedStringArray(["--no-lan-discovery"])), "isolated smoke explicitly avoids the shared LAN port")
	check(LanLobby.discovery_enabled(PackedStringArray(["--headless"])), "headless network tests do not silently lose discovery")
	_test_host_advertisement_identity()
	_test_discovery_packet_validation()
	_test_discovery_compatibility_and_source_identity()
	_test_legacy_protocol_visibility()
	_test_identity_rows_and_refresh()
	_test_status_identity_and_rejection_persistence()
	_test_wellspring_context_boundary()
	_test_overlay_context_and_discovery()
	_test_explicit_capture_context()
	_test_discovery_expiry_empty_error_and_retry()
	return finish("lan-lobby")


func _test_host_advertisement_identity() -> void:
	var boot := DiscoveryBootstrap.new()
	boot.session_transport.mode = SessionTransport.Mode.HOSTING
	boot.session_transport.bound_port = SessionTransport.DEFAULT_PORT
	var lobby := LanLobby.new()
	lobby.bootstrap = boot
	var bytes := lobby._host_advertisement_bytes()
	check(not bytes.is_empty(), "host emits a bounded identity advertisement")
	if bytes.is_empty():
		lobby.free()
		boot.free()
		return
	var packet: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	equal(int(packet.get("protocol", 0)), SimConfig.PROTOCOL_VERSION, "advertisement names the exact current protocol")
	equal(packet.get("runtime_source_sha256", ""), LOCAL_SOURCE_HASH, "advertisement carries the full source identity")
	equal(packet.get("build_id", ""), LOCAL_BUILD_ID, "advertisement carries the derived diagnostic ID")
	equal(packet.get("signature", ""), boot.signature, "advertisement carries the complete semantic/source signature")
	boot.identity_ready = false
	check(lobby._host_advertisement_bytes().is_empty(), "host suppresses advertising when identity cannot be ensured")
	lobby.free()
	boot.free()


func _test_discovery_packet_validation() -> void:
	var signature := "a".repeat(64)
	check(LanLobby._valid_signature(signature), "lowercase SHA-256-shaped discovery identity validates")
	check(not LanLobby._valid_signature(signature.to_upper()), "uppercase discovery identity fails closed")
	check(not LanLobby._valid_signature("a".repeat(63)), "short discovery identity fails closed")

	var from_json: Dictionary = JSON.parse_string(JSON.stringify(_advertisement(signature)))
	var host := LanLobby.normalized_host(from_json, "192.168.1.44", signature, 1234, LOCAL_SOURCE_HASH)
	check(not host.is_empty(), "bounded JSON advertisement normalizes")
	equal(String(host.get("address", "")), "192.168.1.44", "sender IP, not packet data, owns the discovered endpoint")
	equal(int(host.get("port", 0)), SessionTransport.DEFAULT_PORT, "advertised game port survives normalization")
	equal(int(host.get("players", 0)), 2, "player count survives normalization")
	equal(int(host.get("capacity", 0)), 8, "capacity survives normalization")
	equal(int(host.get("last_seen_ms", 0)), 1234, "discovery stores bounded freshness time")

	var wrong_magic := _advertisement(signature)
	wrong_magic["magic"] = "OTHER_GAME"
	check(LanLobby.normalized_host(wrong_magic, "192.168.1.44", signature, 1, LOCAL_SOURCE_HASH).is_empty(), "foreign discovery traffic is ignored")
	var query := _advertisement(signature)
	query["kind"] = LanLobby.DISCOVERY_KIND_QUERY
	check(LanLobby.normalized_host(query, "192.168.1.44", signature, 1, LOCAL_SOURCE_HASH).is_empty(), "discovery queries cannot masquerade as hosts")
	var bad_port := _advertisement(signature)
	bad_port["port"] = 80
	check(LanLobby.normalized_host(bad_port, "192.168.1.44", signature, 1, LOCAL_SOURCE_HASH).is_empty(), "privileged advertised ports fail closed")
	var impossible_roster := _advertisement(signature)
	impossible_roster["players"] = 8
	impossible_roster["capacity"] = 2
	check(LanLobby.normalized_host(impossible_roster, "192.168.1.44", signature, 1, LOCAL_SOURCE_HASH).is_empty(), "impossible host rosters fail closed")

	for invalid_protocol: Variant in [true, "48", 48.5, 0, -1, 3_000_000_000]:
		var malformed := _advertisement(signature)
		malformed["protocol"] = invalid_protocol
		check(LanLobby.normalized_host(malformed, "192.168.1.44", signature, 1, LOCAL_SOURCE_HASH).is_empty(), "protocol rejects coerced or non-exact value %s" % invalid_protocol)
	var integral_json_number := _advertisement(signature)
	integral_json_number["protocol"] = float(SimConfig.PROTOCOL_VERSION)
	check(not LanLobby.normalized_host(integral_json_number, "192.168.1.44", signature, 1, LOCAL_SOURCE_HASH).is_empty(), "integral JSON protocol number is accepted")

	for field: String in ["runtime_source_sha256", "build_id"]:
		var wrong_type := _advertisement(signature)
		wrong_type[field] = StringName(String(wrong_type[field]))
		check(LanLobby.normalized_host(wrong_type, "192.168.1.44", signature, 1, LOCAL_SOURCE_HASH).is_empty(), "%s rejects a coerced non-JSON string" % field)
	for invalid_hash: String in [LOCAL_SOURCE_HASH.to_upper(), "a".repeat(63), "g".repeat(64)]:
		var malformed_hash := _advertisement(signature)
		malformed_hash["runtime_source_sha256"] = invalid_hash
		check(LanLobby.normalized_host(malformed_hash, "192.168.1.44", signature, 1, LOCAL_SOURCE_HASH).is_empty(), "malformed full source identity fails closed")
	for invalid_id: String in ["overnight-best", "p48-000000000000", "p47-aaaaaaaaaaaa"]:
		var malformed_id := _advertisement(signature)
		malformed_id["build_id"] = invalid_id
		check(LanLobby.normalized_host(malformed_id, "192.168.1.44", signature, 1, LOCAL_SOURCE_HASH).is_empty(), "underived build ID fails closed")


func _test_discovery_compatibility_and_source_identity() -> void:
	var local_signature := "a".repeat(64)
	var matching := LanLobby.normalized_host(_advertisement(local_signature), "10.0.0.7", local_signature, 10, LOCAL_SOURCE_HASH)
	check(bool(matching.get("compatible", false)), "protocol, full source identity and semantic signature all match")

	var signature_mismatch := LanLobby.normalized_host(_advertisement("b".repeat(64)), "10.0.0.8", local_signature, 20, LOCAL_SOURCE_HASH)
	check(not signature_mismatch.is_empty(), "semantic mismatch remains visible for explanation")
	check(not bool(signature_mismatch.get("compatible", true)), "semantic mismatch is not selectable")

	var changed_source := _advertisement(local_signature, OTHER_SOURCE_HASH)
	var source_mismatch := LanLobby.normalized_host(changed_source, "10.0.0.9", local_signature, 30, LOCAL_SOURCE_HASH)
	check(not source_mismatch.is_empty(), "full source mismatch remains visible for explanation")
	check(not bool(source_mismatch.get("compatible", true)), "full source mismatch is not selectable")

	var short_collision := _advertisement(local_signature, COLLIDING_SOURCE_HASH)
	equal(short_collision["build_id"], LOCAL_BUILD_ID, "fixture has the same short diagnostic ID")
	var collision_host := LanLobby.normalized_host(short_collision, "10.0.0.10", local_signature, 40, LOCAL_SOURCE_HASH)
	check(not bool(collision_host.get("compatible", true)), "matching short ID cannot override a different full source hash")

	var no_local_hash := LanLobby.normalized_host(_advertisement(local_signature), "10.0.0.11", local_signature, 50)
	check(not no_local_hash.is_empty() and not bool(no_local_hash.get("compatible", true)), "optional legacy call remains safe and cannot admit without a local full hash")

	var oversized_name := _advertisement(local_signature)
	oversized_name["name"] = "X".repeat(SessionTransport.MAX_PLAYER_NAME_LENGTH + 20)
	var bounded := LanLobby.normalized_host(oversized_name, "10.0.0.12", local_signature, 60, LOCAL_SOURCE_HASH)
	equal(String(bounded.get("name", "")).length(), SessionTransport.MAX_PLAYER_NAME_LENGTH, "discovered host names are bounded")


func _test_legacy_protocol_visibility() -> void:
	var legacy := _advertisement("a".repeat(64))
	legacy["protocol"] = LanLobby.LEGACY_PROTOCOL
	legacy.erase("runtime_source_sha256")
	legacy.erase("build_id")
	var host := LanLobby.normalized_host(legacy, "10.0.0.47", "a".repeat(64), 47, LOCAL_SOURCE_HASH)
	check(not host.is_empty(), "legacy protocol 47 advertisement remains visible")
	check(not bool(host.get("compatible", true)), "legacy protocol 47 advertisement is never selectable")
	equal(host.get("build_id", ""), LanLobby.LEGACY_BUILD_ID, "legacy advertisement has an explicit diagnostic ID")
	equal(host.get("mismatch_code", ""), SessionTransport.REJECT_PROTOCOL_MISMATCH, "legacy advertisement is classified as a protocol mismatch")
	var future := _advertisement("a".repeat(64), OTHER_SOURCE_HASH, SimConfig.PROTOCOL_VERSION + 1)
	var future_host := LanLobby.normalized_host(future, "10.0.0.49", "a".repeat(64), 49, LOCAL_SOURCE_HASH)
	check(not future_host.is_empty() and not bool(future_host.get("compatible", true)), "well-formed different protocol remains visible but incompatible")
	equal(future_host.get("mismatch_code", ""), SessionTransport.REJECT_PROTOCOL_MISMATCH, "different protocol uses protocol mismatch recovery")
	var partial := legacy.duplicate(true)
	partial["runtime_source_sha256"] = LOCAL_SOURCE_HASH
	check(LanLobby.normalized_host(partial, "10.0.0.47", "a".repeat(64), 47, LOCAL_SOURCE_HASH).is_empty(), "partial legacy identity fields fail closed")


func _test_identity_rows_and_refresh() -> void:
	var boot := DiscoveryBootstrap.new()
	var lobby := LanLobby.new()
	lobby.bootstrap = boot
	lobby._build_ui()
	var endpoint := "10.0.0.7:%d" % SessionTransport.DEFAULT_PORT
	var compatible := LanLobby.normalized_host(_advertisement(boot.signature), "10.0.0.7", boot.signature, 10, LOCAL_SOURCE_HASH)
	lobby.discovered_hosts[endpoint] = compatible
	lobby._refresh_host_rows()
	equal(lobby.host_rows.get_child_count(), 1, "identity host creates one actual UI row")
	var first_row := lobby.host_rows.get_child(0) as Button
	var original_id := first_row.get_instance_id()
	check(not first_row.disabled and first_row.text.contains(LOCAL_BUILD_ID), "matching row is selectable and displays its build")
	check(first_row.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "host row wraps within the fixed LAN panel")
	check(lobby.browser_status_label.text.contains(LOCAL_BUILD_ID), "compatible browser status displays the local build")

	var freshness_only := compatible.duplicate(true)
	freshness_only["last_seen_ms"] = 20
	lobby.discovered_hosts[endpoint] = freshness_only
	lobby._refresh_host_rows()
	equal(lobby.host_rows.get_child(0).get_instance_id(), original_id, "freshness-only update retains the focusable row")

	var changed := LanLobby.normalized_host(_advertisement(boot.signature, OTHER_SOURCE_HASH), "10.0.0.7", boot.signature, 30, LOCAL_SOURCE_HASH)
	lobby.discovered_hosts[endpoint] = changed
	lobby._refresh_host_rows()
	var changed_row := lobby.host_rows.get_child(0) as Button
	var changed_row_id := changed_row.get_instance_id()
	check(changed_row.get_instance_id() != original_id, "source identity change refreshes the actual row")
	check(changed_row.disabled, "source identity change disables joining")
	check(changed_row.text.contains(String(changed["build_id"])) and changed_row.text.contains(LOCAL_BUILD_ID), "mismatch row displays both host and local IDs")
	check(lobby.browser_status_label.text.contains("same complete portable ZIP"), "mismatch-only browser gives complete-ZIP recovery")
	check(lobby.browser_status_label.text.contains(String(changed["build_id"])) and lobby.browser_status_label.text.contains(LOCAL_BUILD_ID), "mismatch recovery contains both IDs")
	lobby._join_discovered_host(endpoint)
	equal(boot.join_calls, 0, "disabled mismatch cannot reach the join action")

	var legacy := _advertisement(boot.signature)
	legacy["protocol"] = LanLobby.LEGACY_PROTOCOL
	legacy.erase("runtime_source_sha256")
	legacy.erase("build_id")
	lobby.discovered_hosts[endpoint] = LanLobby.normalized_host(legacy, "10.0.0.7", boot.signature, 40, LOCAL_SOURCE_HASH)
	lobby._refresh_host_rows()
	check(lobby.host_rows.get_child(0).get_instance_id() != changed_row_id, "protocol identity change refreshes the actual row")
	check((lobby.host_rows.get_child(0) as Button).text.contains(LanLobby.LEGACY_BUILD_ID), "legacy row names p47-legacy")
	check(lobby.browser_status_label.text.contains(LanLobby.LEGACY_BUILD_ID) and lobby.browser_status_label.text.contains(LOCAL_BUILD_ID), "legacy recovery preserves both diagnostic IDs")
	lobby.free()
	boot.free()


func _test_status_identity_and_rejection_persistence() -> void:
	var boot := DiscoveryBootstrap.new()
	var lobby := LanLobby.new()
	lobby.bootstrap = boot
	lobby._build_ui()
	boot.session_transport.status_detail = "Ready"
	boot.session_transport.mode = SessionTransport.Mode.HOSTING
	lobby._update_ui()
	check(lobby.status_label.text.contains(LOCAL_BUILD_ID), "hosting status displays the local build")
	boot.session_transport.mode = SessionTransport.Mode.CONNECTING
	boot.session_transport.status_detail = "Contacting host"
	lobby._update_ui()
	check(lobby.status_label.text.contains(LOCAL_BUILD_ID), "seeking status displays the local build")
	boot.session_transport.mode = SessionTransport.Mode.CLIENT
	boot.session_transport.accepted = true
	boot.session_transport.remote_build_id = "p49-bbbbbbbbbbbb"
	boot.session_transport.status_detail = "Connected"
	lobby._update_ui()
	check(lobby.status_label.text.contains("p49-bbbbbbbbbbbb"), "joined status displays the accepted host build")
	boot.session_transport.mode = SessionTransport.Mode.OFFLINE
	boot.session_transport.last_error = "Different build: host p49-bbbbbbbbbbbb, yours p49-aaaaaaaaaaaa."
	lobby._update_ui()
	equal(lobby.status_label.text, boot.session_transport.last_error, "offline pre-accept rejection remains visible")
	lobby.free()
	boot.free()


func _test_discovery_expiry_empty_error_and_retry() -> void:
	var boot := DiscoveryBootstrap.new()
	var lobby := RetryLobby.new()
	lobby.bootstrap = boot
	lobby._build_ui()
	lobby.join_button.pressed.emit()
	equal(lobby.listener_attempts, 1, "Join attempts discovery through its actual button handler")
	equal(lobby.browser_status_label.text, lobby.discovery_error, "empty discovery shows the listener error immediately")
	lobby._accept_discovery_packet(_advertisement(boot.signature), "10.0.0.7")
	lobby._refresh_host_rows()
	equal(lobby.host_rows.get_child_count(), 1, "received advertisement creates a selectable host row")
	var original_row_id := lobby.host_rows.get_child(0).get_instance_id()
	lobby._accept_discovery_packet(_advertisement(boot.signature), "10.0.0.7")
	lobby._refresh_host_rows()
	equal(lobby.host_rows.get_child(0).get_instance_id(), original_row_id, "freshness-only advertisement retains the same focusable row")
	var renamed := _advertisement(boot.signature)
	renamed["name"] = "New | Lantern; Host"
	lobby._accept_discovery_packet(renamed, "10.0.0.7")
	lobby._refresh_host_rows()
	equal(lobby.host_rows.get_child_count(), 1, "renamed host replaces rather than duplicates its row")
	check((lobby.host_rows.get_child(0) as Button).text.begins_with("New | Lantern; Host".left(SessionTransport.MAX_PLAYER_NAME_LENGTH)), "changed bounded host name is reflected without a roster change")
	var host: Dictionary = lobby.discovered_hosts.values()[0]
	lobby._expire_stale_hosts(int(host["last_seen_ms"]) + LanLobby.HOST_STALE_MS + 1)
	lobby._refresh_host_rows()
	equal(lobby.host_rows.get_child_count(), 0, "last host expiry immediately removes the stale button")
	equal(lobby.browser_status_label.text, lobby.discovery_error, "last host expiry returns to discovery error state")
	lobby.join_button.pressed.emit()
	lobby.listener_should_succeed = true
	lobby.join_button.pressed.emit()
	equal(lobby.listener_attempts, 2, "close and reopen Join retries the listener")
	check(lobby.browser_status_label.text.begins_with("Searching local network"), "successful empty retry replaces the stale error")
	lobby.discovery_error = "LAN discovery unavailable again."
	lobby._refresh_host_rows()
	equal(lobby.browser_status_label.text, lobby.discovery_error, "a later discovery error refreshes without any host packet")
	lobby.free()
	boot.free()


func _advertisement(signature: String, source_hash: String = LOCAL_SOURCE_HASH, protocol: int = SimConfig.PROTOCOL_VERSION) -> Dictionary:
	return {
		"magic": LanLobby.DISCOVERY_MAGIC,
		"kind": LanLobby.DISCOVERY_KIND_ADVERTISEMENT,
		"port": SessionTransport.DEFAULT_PORT,
		"name": "Lantern Host",
		"players": 2,
		"capacity": 8,
		"signature": signature,
		"protocol": protocol,
		"runtime_source_sha256": source_hash,
		"build_id": "p%d-%s" % [protocol, source_hash.left(RuntimeBuildIdentity.SHORT_HASH_LENGTH)],
	}


func _test_wellspring_context_boundary() -> void:
	check(LanLobby.context_panel_visible("farflow-host", false), "LAN controls appear at the physical Host Farflow station")
	check(LanLobby.context_panel_visible("farflow-join", false), "LAN controls appear at the physical Join Farflow station")
	check(LanLobby.context_panel_visible("farflow-charter", false), "LAN controls remain available beside the Farflow charter")
	check(not LanLobby.context_panel_visible("spell-loom", false), "LAN controls do not become a detached always-on menu")
	check(not LanLobby.context_panel_visible("farflow-join", true), "visual acceptance runs remain free of diagnostic LAN UI")
	for station: String in ["farflow-host", "farflow-join", "farflow-charter"]:
		check(not LanLobby.context_panel_visible(station, false, true), "normal production LAN panel yields to a modal or visible result")
		check(LanLobby.context_panel_visible(station, false, false), "optional overlay argument preserves the existing station visibility contract")


func _test_overlay_context_and_discovery() -> void:
	var boot := DiscoveryBootstrap.new()
	var lobby := ContextLobby.new()
	lobby.bootstrap = boot
	lobby._build_ui()
	lobby.listener_ready = true # No socket is opened by this UI/discovery fixture.
	lobby.visual_capture_run = false # Exercise the production guard, not diagnostic hiding.
	boot.session_transport.mode = SessionTransport.Mode.HOSTING
	lobby._process(0.0)
	check(lobby.panel.visible, "unblocked physical Farflow context displays the real panel")
	equal(lobby.discovery_polls, 1, "normal process polls discovery")
	equal(lobby.host_broadcasts, 1, "normal host process advertises")
	lobby.browser_open = true
	lobby.browser_box.visible = true
	boot.gameplay_blocked = true
	lobby._process(0.0)
	check(not lobby.panel.visible, "actual process hides CanvasLayer panel behind a gameplay-blocking modal")
	check(not lobby.browser_open and not lobby.browser_box.visible, "modal context loss closes the host browser")
	equal(lobby.discovery_polls, 2, "hidden LAN UI still polls discovery")
	equal(lobby.host_broadcasts, 2, "hidden LAN UI does not stop host advertisements")
	lobby._on_host_pressed()
	lobby._on_join_pressed()
	equal(boot.host_calls, 0, "stale host-button signal cannot mutate a session behind a modal")
	var endpoint := "10.0.0.7:%d" % SessionTransport.DEFAULT_PORT
	lobby.discovered_hosts[endpoint] = LanLobby.normalized_host(_advertisement(boot.signature), "10.0.0.7", boot.signature, Time.get_ticks_msec(), LOCAL_SOURCE_HASH)
	lobby._join_discovered_host(endpoint)
	equal(boot.join_calls, 0, "stale discovered-host signal cannot join behind a modal")
	boot.gameplay_blocked = false
	boot.visible_result = true
	lobby._process(0.0)
	check(not lobby.panel.visible, "nonmodal retained result also owns its visible UI region")
	equal(lobby.discovery_polls, 3, "visible result does not pause discovery")
	equal(lobby.host_broadcasts, 3, "visible result does not pause hosting")
	equal(boot.result_view_builds, 0, "visibility polling never builds or reformats the result card")
	boot.visible_result = false
	boot.active_cast = true
	lobby._process(0.0)
	check(lobby.panel.visible, "ordinary casting is not mistaken for a modal or retained result")
	check(not lobby.browser_open, "dismissed overlay does not silently reopen the prior host browser")
	boot.session_transport.mode = SessionTransport.Mode.OFFLINE
	lobby.browser_open = true
	lobby._process(0.0)
	equal(lobby.browser_probes, 1, "an explicitly open browser still probes in valid offline context")
	boot.focused_station_id = "spell-loom"
	lobby._process(0.0)
	check(not lobby.panel.visible and not lobby.browser_open, "leaving Farflow closes both panel and browser")
	equal(lobby.browser_probes, 1, "context loss stops browser-only probes without stopping discovery polls")
	equal(lobby.discovery_polls, 6, "all six context updates continued the discovery polling path")
	boot.focused_station_id = "farflow-join"
	lobby.browser_open = true
	lobby.bootstrap = null
	lobby._process(0.0)
	check(not lobby.panel.visible and not lobby.browser_open, "losing the bootstrap context cannot retain detached visible controls")
	lobby.free()
	boot.free()
	var legacy_boot := LegacyContextBootstrap.new()
	var legacy_lobby := LanLobby.new()
	legacy_lobby.bootstrap = legacy_boot
	legacy_lobby._build_ui()
	check(legacy_lobby._refresh_context_visibility(), "older callers without optional overlay hooks retain normal LAN visibility")
	legacy_lobby.free()
	legacy_boot.free()


func _test_explicit_capture_context() -> void:
	for argument: String in ["--capture-expanded-station=farflow-charter", "--visual-specimen", "--native-capture"]:
		check(LanLobby.is_visual_capture_run(PackedStringArray([argument])), "explicit capture mode is recognized: " + argument)
	check(not LanLobby.is_visual_capture_run(PackedStringArray()), "normal launches do not hide LAN controls as captures")
	check(not LanLobby.is_visual_capture_run(PackedStringArray(["--output=res://.godot/team-checkpoint-native-test", "--fullbody-art", "--pixel-cast"])), "generic native harness output is not misclassified to mask production UI overlap")
	check(not LanLobby.is_visual_capture_run(PackedStringArray(["--native-capture=false"])), "alternate capture flag syntax cannot silently hide production UI")


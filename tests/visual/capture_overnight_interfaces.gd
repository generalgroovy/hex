extends SceneTree


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const CASES: Array[String] = [
	"route-source-court", "route-movement-garden", "route-crucible", "route-duel-court",
	"lan-match", "lan-mismatch", "lan-legacy", "lan-empty-error", "lan-host",
	"controls-actions", "controls-spells", "controls-reserved", "feedback-busy",
]
var output := ""
var viewport: SubViewport
var node: Node2D
var lobby: LanLobby
var frames: Array[Dictionary] = []


class CaptureLobby:
	extends LanLobby
	# Render production controls without opening discovery sockets or polling.
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/overnight-interfaces-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh overnight-interfaces output directory")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot configure the inherited actual-game draw fixture")
		return
	node.reaction_catalog = ReactionCatalog.new()
	node.reaction_definitions = ReactionDefinitionTable.new()
	if not node.reaction_catalog.load_from_file(node.REACTION_CATALOG_PATH) or not node.reaction_definitions.compile(node.reaction_catalog, node.ability_catalog):
		fail("Cannot bind current reaction identity")
		return
	if not node._ensure_runtime_identity():
		fail(node.session_transport.last_error)
		return
	node.interaction_presenter = WellspringInteractionPresenter.new()
	if not node.interaction_presenter.configure(node.visual_language, node.campus_layout):
		fail("Cannot configure the production interaction presenter")
		return
	node.session_steward = SessionSteward.new()
	node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	node.visual_accessibility_filter = VisualAccessibilityFilter.new()
	node.add_child(node.visual_accessibility_filter)
	lobby = CaptureLobby.new()
	node.add_child(lobby)
	lobby.bootstrap = node
	lobby._build_ui()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = size
		for case_name: String in CASES:
			if not apply_case(case_name):
				return
			for reduced: bool in [false, true]:
				if not await capture(case_name, size, reduced):
					return
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Cannot retain interface capture evidence")
		return
	var source_hashes := {}
	for path: String in ["res://src/app/bootstrap.gd", "res://src/net/lan_lobby.gd", "res://src/net/session_transport.gd", "res://content/presentation/wellspring_floor_guides_v1.json", RuntimeBuildIdentity.MANIFEST_PATH, "res://tests/visual/capture_overnight_interfaces.gd", "res://tests/support/chemistry_coach_harness.gd"]:
		source_hashes[path] = FileAccess.get_sha256(path)
	receipt.store_string(JSON.stringify({
		"schema_version": 1, "frames": frames, "source_hashes": source_hashes,
		"runtime_build_id": node.session_transport.build_id, "runtime_source_sha256": node.session_transport.runtime_source_sha256,
		"campus_hash": node.campus_layout.content_hash,
		"method": "Inherited production game draw and LAN controls; controlled actor placement and synthetic session/UI states, no sockets or input playthrough",
		"network": "not_started", "preferences": "transient_fixture_only", "human_acceptance": "not_run",
		"authority_unchanged_by_every_draw": true,
	}, "  "))
	receipt.close()
	print("PASS: %d actual-game interface and route frames;720/1080 normal/reduced; every draw preserves authority" % frames.size())
	quit(0)


func apply_case(case_name: String) -> bool:
	node.session_transport.stop()
	node.controls_editor.close_editor()
	node.network_event_overflow_notice_seconds = 0.0
	node.focused_station_id = ""
	node.expanded_station_id = ""
	node.station_notice = ""
	node.station_notice_seconds = 0.0
	lobby.panel.visible = false
	lobby.browser_open = false
	lobby.browser_box.visible = false
	lobby.discovered_hosts.clear()
	lobby.host_rows_fingerprint = ""
	lobby.discovery_error = ""
	var position := Vector2i(1472, 832)
	if case_name.begins_with("route-"):
		var activity := case_name.trim_prefix("route-")
		for stage: Dictionary in node.campus_renderer.floor_guide_data["stages"]:
			if String(stage["activity"]) == activity:
				position = Vector2i(int(stage["anchor"][0]), int(stage["anchor"][1]))
	elif case_name.begins_with("controls-"):
		node.controls_editor.open_editor()
		node.controls_editor.selected_device = ControlBindingEditor.DEVICE_CONTROLLER
		node.controls_editor.selected_action_index = 0
		node.controls_editor.first_visible_row = 0
		if case_name == "controls-spells":
			node.controls_editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"spell_1")
			node.controls_editor.first_visible_row = maxi(0, ControlBindingEditor.ACTIONS.size() - ControlBindingEditor.VISIBLE_ROWS)
		elif case_name == "controls-reserved":
			node.controls_editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
			node.controls_editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"jump")
			node.controls_editor.begin_capture()
			var key := InputEventKey.new()
			key.physical_keycode = KEY_F4
			key.pressed = true
			node.controls_editor.capture_event(key, node.player_preferences)
	elif case_name == "feedback-busy":
		node.session_transport.mode = SessionTransport.Mode.HOSTING
		node.authoritative_session.pending_combat_event_overflow_count = 7
		node._update_network_feedback_notice(0.0)
	else:
		node.focused_station_id = "farflow-join"
		var station: Dictionary = node.campus_layout.stations_by_id["farflow-join"]
		position = Vector2i(int(station["position"][0]), int(station["position"][1]) + 56)
		lobby.panel.visible = true
		lobby.browser_open = case_name != "lan-host"
		if case_name == "lan-host":
			node.session_transport.mode = SessionTransport.Mode.HOSTING
			node.session_transport.bound_port = SessionTransport.DEFAULT_PORT
			node.session_transport.session_charter_id = SessionCharter.DEFAULT_ID
			node.session_transport.status_detail = node.session_transport._host_status()
		elif case_name == "lan-empty-error":
			lobby.discovery_error = "LAN discovery unavailable (UDP 24873). Reopen Join to retry, or enter the host address."
		else:
			var local_hash: String = node.session_transport.runtime_source_sha256
			var remote_hash := local_hash if case_name == "lan-match" else "b".repeat(64)
			var packet := {
				"magic": LanLobby.DISCOVERY_MAGIC, "kind": LanLobby.DISCOVERY_KIND_ADVERTISEMENT,
				"protocol": SimConfig.PROTOCOL_VERSION, "name": "Lantern Host", "port": SessionTransport.DEFAULT_PORT,
				"players": 2, "capacity": 8, "signature": node._session_compatibility_signature(),
				"runtime_source_sha256": remote_hash, "build_id": "p%d-%s" % [SimConfig.PROTOCOL_VERSION, remote_hash.left(12)],
			}
			if case_name == "lan-legacy":
				packet["protocol"] = 47
				packet.erase("runtime_source_sha256")
				packet.erase("build_id")
			lobby._accept_discovery_packet(packet, "192.0.2.10")
			if lobby.discovered_hosts.size() != 1:
				fail("Controlled advertisement did not reach the actual LAN UI")
				return false
		lobby._update_ui()
	var actor: PlayerState = node.world.player()
	actor.position_x = position.x * SimConfig.FIXED_SCALE
	actor.position_y = position.y * SimConfig.FIXED_SCALE
	node.previous_position = Vector2(position)
	node.current_position = Vector2(position)
	node.actor_motion_history.clear()
	return true


func capture(case_name: String, size: Vector2i, reduced: bool) -> bool:
	node.requested_capture_reduced_effects = reduced
	node.player_preferences.reduced_motion = reduced
	var before: String = node.world.state_hash()
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	var filename := "%s-%dx%d-%s.png" % [case_name, size.x, size.y, "reduced" if reduced else "normal"]
	if pixels == null or pixels.get_size() != size or pixels.save_png(output.path_join(filename)) != OK or node.world.state_hash() != before:
		fail("Interface readback failed or drawing mutated authority: " + filename)
		return false
	frames.append({"file": filename, "case": case_name, "size": [size.x, size.y], "reduced_effects": reduced, "world_hash": before, "world_hash_unchanged": true})
	print("RENDERED ", output.path_join(filename))
	return true


func fail(message: String) -> void:
	push_error(message)
	quit(1)

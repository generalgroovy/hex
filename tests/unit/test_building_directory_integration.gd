extends FluxTestSuite

const Bootstrap = preload("res://src/app/bootstrap.gd")
const Grid = preload("res://src/presentation/character_selection_grid.gd")
const Compendium = preload("res://src/presentation/player_compendium.gd")


# Exercise production focus, directory input, authorization, child panels and
# command quarantine. Only network/mutating endpoints are spies: no sockets,
# saves, rendering, imports, lobby acceptance or simulation mutation are claimed.
class DirectoryHarness:
	extends "res://src/app/bootstrap.gd"
	var forced_round_phase: int = SessionRound.Phase.HEARTH
	var dispatched_ids: Array[String] = []
	var endpoint_calls: Array[String] = []
	var submitted_requests: Array[Vector2i] = []
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _draw() -> void:
		pass
	func _current_round_state() -> Dictionary:
		return {"phase": forced_round_phase}
	func _session_label() -> String:
		return "Offline integration fixture"
	func _activate_focused_station() -> void:
		dispatched_ids.append(focused_station_id)
		super._activate_focused_station()
	func _toggle_host_session() -> void:
		endpoint_calls.append("host")
	func _toggle_join_session() -> void:
		endpoint_calls.append("join")
		join_address_editor_open = true
	func _cycle_session_charter() -> void:
		endpoint_calls.append("rules")
	func _activate_session_hearth() -> void:
		endpoint_calls.append("ready")
	func _activate_session_ledger() -> void:
		endpoint_calls.append("company")
	func _activate_session_parting() -> void:
		endpoint_calls.append("parting")
	func _submit_session_request(action: int, value: int = 0) -> void:
		submitted_requests.append(Vector2i(action, value))


func run() -> int:
	var saved_mouse_mode := Input.mouse_mode
	var node := _fixture()
	_test_open_and_academy_children(node)
	_test_training_children_and_modal_input(node)
	_test_dispatch_boundaries(node)
	_test_session_selection_and_front_approach(node)
	_test_phase_transition(node)
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	node.free()
	Input.mouse_mode = saved_mouse_mode
	return finish("building-directory-integration")


func _fixture() -> DirectoryHarness:
	var node := DirectoryHarness.new()
	node.ability_catalog = AbilityCatalog.new()
	check(node.ability_catalog.load_from_file(Bootstrap.ABILITY_CATALOG_PATH), "directory integration loads live ability data")
	node.champion_catalog = ChampionCatalog.new()
	check(node.champion_catalog.load_from_file(Bootstrap.CHAMPION_CATALOG_PATH, node.ability_catalog), "directory integration loads live champion data")
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "directory integration loads identity registry")
	node.campus_layout = SanctumCampusLayout.new()
	check(node.campus_layout.load_from_file(Bootstrap.CAMPUS_LAYOUT_PATH), "directory integration loads grouped campus doors")
	node.character_selection_grid = Grid.new()
	check(node.character_selection_grid.configure(node.champion_catalog, roster), "directory integration uses production Gallery")
	node.player_compendium = Compendium.new()
	check(node.player_compendium.configure(node.champion_catalog, roster), "directory integration uses production Compendium")
	node.controls_editor = ControlBindingEditor.new()
	node.spell_loom_editor = SpellLoomEditor.new()
	node.player_preferences = PlayerPreferences.new()
	node.preference_overrides_are_transient = true
	node.session_transport = SessionTransport.new() # Never starts a peer.
	# The overridden _ready skips production setup, but live Farflow details use
	# the real confirmation state even when action endpoints remain spies.
	node.session_steward = SessionSteward.new()
	node.world = SimWorld.new(120, 1, node.campus_layout.build_collision_world(), String(node.campus_layout.data.id), node.campus_layout.content_hash)
	check(node.champion_catalog.apply_to_player(node.world.player(), "oh_tipi"), "directory actor uses valid champion state")
	node.selected_champion_id = "oh_tipi"
	node.input_router = InputRouter.new(1)
	InputRouter.ensure_input_map()
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	return node


func _place(node: DirectoryHarness, station_id: String, offset: Vector2i = Vector2i(0, 12)) -> void:
	var position: Array = node.campus_layout.stations_by_id[station_id]["position"]
	var state: PlayerState = node.world.player()
	state.position_x = (int(position[0]) + offset.x) * SimConfig.FIXED_SCALE
	state.position_y = (int(position[1]) + offset.y) * SimConfig.FIXED_SCALE
	node._update_station_focus()


func _choose(node: DirectoryHarness, station_id: String) -> void:
	for index: int in range(node.service_directory.entries.size()):
		if String(node.service_directory.entries[index]["id"]) == station_id:
			node.service_directory.selected_index = index
			return
	check(false, "fixture requested a real card: %s" % station_id)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _return_to_parent(node: DirectoryHarness, expected_id: String) -> void:
	node._update_station_focus()
	node._update_service_directory(0.016)
	check(node.service_directory.is_open, "closing child restores the building directory")
	equal(node.service_directory.selected_station_id(), expected_id, "parent retains exact child despite co-located alphabetical focus")
	if node.service_directory.group_id != "farflow":
		node.station_notice_seconds = 0.0
		node._update_service_directory(0.0)
		equal(node.service_directory.status_text, "", "non-session buildings retain their own purpose subtitle")
	check(node.directory_return_group.is_empty(), "successful return consumes its return marker")


func _test_open_and_academy_children(node: DirectoryHarness) -> void:
	_place(node, "champion-loom")
	var state_before := node.world.player().canonical_values()
	var stations_before := CanonicalContent.sha256(node.campus_layout.data["stations"])
	node._open_focused_service_directory()
	check(node.service_directory.is_open, "actual front door opens its directory")
	equal(node.service_directory.group_id, "academy", "Academy offers only its grouped services")
	equal(node.dispatched_ids.size(), 0, "opening cannot activate any child service")
	equal(node.world.player().canonical_values(), state_before, "opening preserves authoritative actor state")
	equal(CanonicalContent.sha256(node.campus_layout.data["stations"]), stations_before, "opening preserves canonical station metadata")
	node._handle_service_directory_input(_key(KEY_RIGHT))
	equal(node.service_directory.selected_station_id(), "spell-loom", "keyboard chooses Spell Loom beside Gallery")
	node._handle_service_directory_input(_key(KEY_ENTER))
	check(node.spell_loom_editor.is_open and not node.character_selection_grid.is_open, "explicit sibling selection opens actual Spell Loom, not nearest Gallery")
	check(not node.service_directory.is_open, "child panel replaces directory rather than overlapping it")
	equal(node.dispatched_ids.back(), "spell-loom", "dispatcher receives exact chosen child ID")
	node.spell_loom_editor.close_editor()
	_return_to_parent(node, "spell-loom")
	_choose(node, "champion-loom")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	node._handle_service_directory_input(button)
	check(node.character_selection_grid.is_open and not node.spell_loom_editor.is_open, "controller accept opens actual Gallery at the same door")
	equal(node.submitted_requests.size(), 0, "opening real child panels submits no equip or champion request")
	node.character_selection_grid.close_panel()
	_return_to_parent(node, "champion-loom")
	node.service_directory.close()


func _test_training_children_and_modal_input(node: DirectoryHarness) -> void:
	_place(node, "controls-lectern")
	node._open_focused_service_directory()
	_choose(node, "controls-lectern")
	var viewport := node.get_viewport_rect().size / node._ui_scale()
	var card: Rect2 = node.service_directory.layout_for(viewport)["cards"][node.service_directory.selected_index]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = card.get_center() * node._ui_scale()
	node._handle_service_directory_input(click)
	check(node.controls_editor.is_open, "actual scaled pointer click opens Controls")
	node.controls_editor.close_editor()
	_return_to_parent(node, "controls-lectern")
	_choose(node, "movement-guide")
	var interact := InputEventAction.new()
	interact.action = InputRouter.INTERACT_ACTION
	interact.pressed = true
	node._handle_service_directory_input(interact)
	check(node.player_compendium.is_open, "mapped Interact opens actual movement Compendium")
	equal(node.player_compendium.tab, Compendium.MOVEMENT, "movement directory card selects movement page")
	node.player_compendium.close_panel()
	_return_to_parent(node, "movement-guide")
	node.controls_input_guard_frames = 0
	check(node._gameplay_input_blocked(), "directory itself blocks input independently of opening guard")
	for action: StringName in [&"move_right", &"primary", &"spell_1"]:
		Input.action_press(action)
	var command := node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2(400, 200), node._gameplay_input_blocked())
	for action: StringName in [&"move_right", &"primary", &"spell_1"]:
		Input.action_release(action)
	equal(command.move_x, 0, "directory neutralizes held movement")
	equal(command.move_y, 0, "directory neutralizes both movement axes")
	equal(command.held_actions, 0, "directory neutralizes physical attacks and held spells")
	equal(command.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "directory emits only safe movement cancellation")
	equal(command.aim_target_x, -1, "directory carries no stale spell endpoint")
	var calls_before := node.dispatched_ids.size()
	node._handle_service_directory_input(_key(KEY_ESCAPE))
	check(not node.service_directory.is_open, "actual Back closes directory")
	equal(node.dispatched_ids.size(), calls_before, "Back dispatches nothing")
	equal(node.controls_input_guard_frames, 2, "Back preserves normal post-modal input quarantine")


func _test_dispatch_boundaries(node: DirectoryHarness) -> void:
	_place(node, "controls-lectern")
	node._open_focused_service_directory()
	var calls_before := node.dispatched_ids.size()
	node._dispatch_directory_station("farflow-host")
	node._dispatch_directory_station("not-a-station")
	equal(node.dispatched_ids.size(), calls_before, "wrong group and nonexistent child never reach dispatcher")
	_place(node, "farflow-host") # Stale open Training directory cannot grant nearby foreign services.
	node._dispatch_directory_station("farflow-host")
	equal(node.dispatched_ids.size(), calls_before, "in-range foreign group still fails closed")
	node.world.player().position_x = 10 * SimConfig.FIXED_SCALE
	node.world.player().position_y = 10 * SimConfig.FIXED_SCALE
	node._dispatch_directory_station("controls-lectern")
	equal(node.dispatched_ids.size(), calls_before, "stale focus cannot dispatch after actor leaves the door")
	node._update_station_focus()
	node._update_service_directory(0.016)
	check(not node.service_directory.is_open, "out-of-range directory closes safely")


func _test_session_selection_and_front_approach(node: DirectoryHarness) -> void:
	_place(node, "farflow-host")
	node._open_focused_service_directory()
	var calls_before := node.dispatched_ids.size()
	for id: String in ["company-ledger", "parting-bell", "session-hearth"]:
		_choose(node, id)
		check(not node.service_directory.selected_available(), "offline availability disables %s" % id)
		node._handle_service_directory_input(_key(KEY_ENTER))
	equal(node.dispatched_ids.size(), calls_before, "disabled host/online actions never reach adapters")
	_choose(node, "farflow-host")
	node._handle_service_directory_input(_key(KEY_ENTER))
	check(node.service_directory.is_open, "direct service leaves directory open")
	equal(node.endpoint_calls.back(), "host", "chosen Host reaches only the host adapter spy")
	node._update_station_focus()
	node._update_service_directory(0.016)
	equal(node.focused_station_id, "farflow-host", "direct selection wins over alphabetical co-located focus")
	node._handle_service_directory_input(_key(KEY_ENTER))
	equal(node.endpoint_calls.slice(-2), ["host", "host"], "repeat confirmation remains on the same direct service")
	node.session_transport.mode = SessionTransport.Mode.HOSTING # Role-only fixture; never opens sockets.
	var stations_before := CanonicalContent.sha256(node.campus_layout.data["stations"])
	var endpoints_before := node.endpoint_calls.size()
	node._refresh_directory_availability()
	check("\n".join(node.service_directory.selected_detail_lines()).contains("arms a three-second close"), "live Host details replace offline open instructions after role changes")
	equal(node.session_steward.request_close(node.world.tick, node.world.config.milliseconds_to_ticks(Bootstrap.STEWARD_CONFIRMATION_MS)), SessionSteward.Decision.ARMED, "fixture arms the real two-step confirmation state")
	node._refresh_directory_availability()
	var armed_lines := node.service_directory.selected_detail_lines()
	check("\n".join(armed_lines).contains("CONFIRMS CLOSING THE COMPANY"), "refreshed Host details expose the pending close confirmation")
	check(not "\n".join(armed_lines).contains("arms a three-second close"), "refreshed details do not retain the previous action instruction")
	check(node.session_steward.is_armed(SessionSteward.Action.CLOSE_COMPANY, 0, node.world.tick), "reading live details cannot confirm or cancel an armed close")
	equal(node.endpoint_calls.size(), endpoints_before, "refreshing detail state dispatches no service action")
	node.session_steward.reset()
	node._refresh_directory_availability()
	check("\n".join(node.service_directory.selected_detail_lines()).contains("arms a three-second close"), "clearing confirmation restores the live first-step instruction")
	_choose(node, "parting-bell")
	check(node.service_directory.selected_available(), "host role can reach existing Parting confirmation adapter")
	equal(node.service_directory.selected_detail_lines(), ["NO TRAVELLER NAMED", "Use the Company Ledger first", "One press can never dismiss a guest"], "live Parting details require a named connected guest before release")
	equal(CanonicalContent.sha256(node.campus_layout.data["stations"]), stations_before, "live confirmation details preserve canonical station metadata")
	_place(node, "parting-bell", Vector2i(0, 80))
	node._refresh_directory_availability()
	check(not node.service_directory.selected_available(), "shared door preserves smaller per-action Parting radius")
	node._dispatch_directory_station("parting-bell")
	check(not node.endpoint_calls.has("parting"), "out-of-action-range Parting cannot inherit Host radius")
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	node.service_directory.close()
	_place(node, "farflow-host", Vector2i(0, -17))
	equal(node.focused_station_id, "", "door cannot be accessed through rear building approach")
	node._open_focused_service_directory()
	check(not node.service_directory.is_open, "rear approach never opens directory")


func _test_phase_transition(node: DirectoryHarness) -> void:
	_place(node, "farflow-host")
	node._open_focused_service_directory()
	equal(node.service_directory.selected_station_id(), "farflow-host", "fresh Farflow opens the first enabled action instead of alphabetical disabled Company")
	_choose(node, "farflow-host")
	var calls_before := node.dispatched_ids.size()
	node.forced_round_phase = SessionRound.Phase.ACTIVE
	# A confirmation can arrive before the next frame closes a stale modal.
	node._handle_service_directory_input(_key(KEY_ENTER))
	equal(node.dispatched_ids.size(), calls_before, "phase transition is revalidated at confirmation boundary, not only next frame")
	node._update_service_directory(0.016)
	check(not node.service_directory.is_open, "active round releases stale service directory")
	node._open_focused_service_directory()
	check(not node.service_directory.is_open, "active round cannot reopen campus directory")
	node.forced_round_phase = SessionRound.Phase.HEARTH

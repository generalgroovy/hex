extends FluxTestSuite


const Bootstrap = preload("res://src/app/bootstrap.gd")
const Grid = preload("res://src/presentation/character_selection_grid.gd")
const Compendium = preload("res://src/presentation/player_compendium.gd")


# Keep tests offline and avoid all boot/import/preferences/render side effects.
# Request handling, feedback, open/close and modal command code remain inherited.
class GalleryHarness:
	extends "res://src/app/bootstrap.gd"
	var forced_round_phase: int = -1
	var submitted_requests: Array[Vector2i] = []
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _draw() -> void:
		pass
	func _current_round_state() -> Dictionary:
		return {"phase": forced_round_phase} if forced_round_phase >= 0 else super._current_round_state()
	func _submit_session_request(action: int, value: int = 0) -> void:
		submitted_requests.append(Vector2i(action, value))
		super._submit_session_request(action, value)


class ActivePagesRecorder:
	extends CartoonChampionPresenter
	var preparations := 0
	var received_ids: Array[String] = []
	func prepare_override_pages(ids: Array[String]) -> bool:
		preparations += 1
		received_ids = ids.duplicate()
		return true


func run() -> int:
	_test_missing_presenter_procedural_fallback_contract()
	var command := SimCommand.new(77, 2, 1000, -1000, SimCommand.HELD_JUMP, SimCommand.PRESSED_ACTIVE_1, 700, -700, 50000, 60000)
	var neutral := Bootstrap.gallery_modal_command(command, true)
	equal(neutral.tick, command.tick, "Gallery neutralization preserves authority tick")
	equal(neutral.entity_id, 2, "Gallery neutralization preserves authenticated actor")
	equal(neutral.move_x, 0, "Gallery removes horizontal movement including capture overrides")
	equal(neutral.move_y, 0, "Gallery removes vertical movement including capture overrides")
	equal(neutral.held_actions, 0, "Gallery removes held movement/spells")
	equal(neutral.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "Gallery sends only safe movement cancellation, never a paid action edge or intentional jump release")
	equal(neutral.aim_x, command.aim_x, "Gallery keeps harmless facing")
	equal(neutral.aim_target_x, -1, "Gallery does not retain a cursor spell endpoint")
	check(Bootstrap.gallery_modal_command(command, false) == command, "closed Gallery leaves ordinary commands untouched")
	var node := GalleryHarness.new()
	node.ability_catalog = AbilityCatalog.new()
	check(node.ability_catalog.load_from_file(Bootstrap.ABILITY_CATALOG_PATH), "Gallery integration ability catalog loads")
	node.champion_catalog = ChampionCatalog.new()
	check(node.champion_catalog.load_from_file(Bootstrap.CHAMPION_CATALOG_PATH, node.ability_catalog), "Gallery integration champion catalog loads")
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "Gallery integration identity registry loads")
	node.campus_layout = SanctumCampusLayout.new()
	check(node.campus_layout.load_from_file(Bootstrap.CAMPUS_LAYOUT_PATH), "Gallery integration station layout loads")
	node.character_selection_grid = Grid.new()
	check(node.character_selection_grid.configure(node.champion_catalog, roster), "Gallery integration uses actual selector")
	node.player_compendium = Compendium.new()
	check(node.player_compendium.configure(node.champion_catalog, roster), "Gallery integration uses actual Compendium")
	node.controls_editor = ControlBindingEditor.new()
	node.spell_loom_editor = SpellLoomEditor.new()
	node.session_transport = SessionTransport.new()
	node.authoritative_session = AuthoritativeSession.new()
	node.world = SimWorld.new(120, 1, CollisionWorld.new(3_072_000, 1_728_000))
	var state: PlayerState = node.world.player()
	check(node.champion_catalog.apply_to_player(state, "oh_tipi"), "Gallery host begins as Oh Tipi")
	var gallery_position: Array = node.campus_layout.stations_by_id["champion-loom"].position
	var gallery_approach := Vector2i(int(gallery_position[0]), int(gallery_position[1]) + 48)
	check(node.authoritative_session.bind(node.world, node.champion_catalog, gallery_approach, "Test Host"), "Gallery host session binds without sockets")
	state.position_x = gallery_approach.x * SimConfig.FIXED_SCALE
	state.position_y = gallery_approach.y * SimConfig.FIXED_SCALE
	node.selected_champion_id = "oh_tipi"
	node.input_router = InputRouter.new(1)
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	node.focused_station_id = "champion-loom"
	node._activate_focused_station()
	check(node.character_selection_grid.is_open, "ordinary Gallery station interaction opens selector instead of cycling")
	equal(state.champion_wire_id, 1, "opening leaves champion authority unchanged")
	equal(node.controls_input_guard_frames, 2, "opening arms the shared two-frame input guard")
	equal(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "Gallery opening exposes native pointer")
	node._open_player_compendium(Compendium.MOVEMENT)
	check(not node.player_compendium.is_open, "Gallery cannot overlap the read-only Compendium")
	_test_whole_roster_inspection(node, state)
	_select_champion(node, "s_wayne")
	var before_early_feedback := state.canonical_values()
	var before_early_notice := node.station_notice
	node._ingest_session_feedback([{"type": "champion_attuned", "entity_id": 1, "champion_wire_id": 2}])
	equal(state.canonical_values(), before_early_feedback, "early attunement feedback cannot mutate actual offline authority")
	equal(node.character_selection_grid.model.equipped_id, "oh_tipi", "unconfirmed feedback cannot optimistically equip the selected Gallery card")
	equal(node.station_notice, before_early_notice, "unconfirmed local feedback cannot announce an attunement")
	var requests_before := node.submitted_requests.size()
	node._handle_character_gallery_input(_key(KEY_ENTER))
	equal(node.submitted_requests.size(), requests_before + 1, "eligible Enter confirmation sends exactly one actual Gallery request")
	equal(state.champion_wire_id, 2, "eligible input path uses ordinary host request handling for exact selection")
	equal(node.selected_champion_id, "s_wayne", "host selection source updates only after accepted attunement")
	equal(node.character_selection_grid.model.equipped_id, "s_wayne", "actual champion_attuned feedback confirms the local UI")
	equal(node.character_selection_grid.model.pending_wire, 0, "actual acceptance clears pending selection")
	state.flux_recovery_delay_ticks = 19
	var before := state.canonical_values()
	node._submit_session_request(SessionTransport.REQUEST_CHAMPION_SELECT, 2)
	equal(state.canonical_values(), before, "same champion request is byte-stable through actual host handler")
	_test_selection_availability(node, state)
	state.position_x = 500_000
	node.character_selection_grid.model.pending_wire = 1
	node._submit_session_request(SessionTransport.REQUEST_CHAMPION_SELECT, 1)
	equal(state.champion_wire_id, 2, "host refuses exact swap outside Gallery range")
	equal(node.character_selection_grid.model.pending_wire, 0, "actual refusal feedback unlocks UI")
	check(node.character_selection_grid.model.status_message.contains("beside the Gallery"), "distance refusal names the correct station")
	var tick_before := node.world.tick
	check(node.world.step([Bootstrap.gallery_modal_command(SimCommand.new(tick_before, 1, 1000, 0), true)]), "shared simulation still steps while Gallery is open")
	equal(node.world.tick, tick_before + 1, "opening Gallery never pauses authoritative time")
	var close := InputEventKey.new()
	close.keycode = KEY_ESCAPE
	close.pressed = true
	node._handle_character_gallery_input(close)
	check(not node.character_selection_grid.is_open, "actual modal event handler closes on Escape")
	equal(node.controls_input_guard_frames, 2, "closing retains two frames of gameplay input quarantine")
	check(not node.safe_quit_pending, "closing Gallery never starts application quit")
	equal(node.get("application_input_active"), true, "headless and capture harnesses begin with active gameplay input")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	node.input_router.observe_input_event(wheel)
	check(not node.input_router.pending_wheel_pulses.is_empty(), "focus fixture queues a real accepted wheel event")
	node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	equal(node.get("application_input_active"), false, "actual focus-out notification suspends local gameplay input")
	check(node.input_router.pending_wheel_pulses.is_empty(), "focus loss discards accepted wheel input before it can become a paid jump")
	Input.action_press(&"move_right")
	Input.action_press(&"primary")
	Input.action_press(&"spell_1")
	var focus_tick_before := node.world.tick
	for unused: int in range(3):
		var inactive := node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, false)
		equal(inactive.move_x, 0, "focus latch neutralizes movement even if a caller omits its modal flag")
		equal(inactive.held_actions, 0, "unfocused held primary and Rapid cannot fire")
		equal(inactive.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "unfocused input sends exactly movement cancellation and cannot spend resources")
		equal(inactive.aim_target_x, -1, "unfocused command carries no live cursor endpoint")
		check(node.world.step([inactive]), "authoritative world still advances with neutral unfocused commands")
	equal(node.world.tick, focus_tick_before + 3, "focus loss never pauses shared simulation time")
	node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	equal(node.get("application_input_active"), true, "actual focus-in notification restores the explicit input latch")
	for unused: int in range(2):
		var guarded := node._gameplay_input_blocked()
		node.controls_input_guard_frames -= 1
		equal(node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, guarded).move_x, 0, "focus return retains the two-frame neutral guard")
	var resumed := node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, node._gameplay_input_blocked())
	equal(resumed.move_x, 1000, "direction may resume after focus returns")
	equal(resumed.held_actions, 0, "held paid actions remain quarantined beyond the focus guard")
	equal(resumed.pressed_actions, 0, "focus return cannot manufacture paid action edges")
	Input.action_release(&"primary")
	Input.action_release(&"spell_1")
	node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, false)
	Input.action_press(&"primary")
	Input.action_press(&"spell_1")
	var fresh := node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, false)
	check(fresh.has_held(SimCommand.HELD_PRIMARY) and fresh.has_pressed(SimCommand.PRESSED_SPELL_1), "release and a fresh gameplay press restore primary and spells")
	for action: StringName in [&"primary", &"spell_1", &"move_right"]:
		Input.action_release(action)
	# Exercise the real modal event routing, not only the command helper.
	node._open_character_gallery()
	var jump := InputEventKey.new()
	jump.keycode = KEY_SPACE
	jump.physical_keycode = KEY_SPACE
	jump.pressed = true
	Input.parse_input_event(jump)
	Input.flush_buffered_events()
	node._unhandled_input(jump)
	node._handle_character_gallery_input(close)
	for unused: int in range(2):
		var guarded := node._gameplay_input_blocked()
		node.controls_input_guard_frames -= 1
		node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, guarded)
	var closed := node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, false)
	check(not closed.has_pressed(SimCommand.PRESSED_JUMP) and not closed.has_held(SimCommand.HELD_JUMP), "Space held inside actual Gallery cannot jump when Escape closes it")
	var jump_release := jump.duplicate() as InputEventKey
	jump_release.pressed = false
	Input.parse_input_event(jump_release)
	Input.flush_buffered_events()
	node.input_router.observe_input_event(jump_release)
	_test_station_guide_device(node)
	_test_active_page_preparation(node)
	node.free()
	_test_prediction_gait_metadata()
	return finish("character-gallery-integration")


func _test_whole_roster_inspection(node: GalleryHarness, state: PlayerState) -> void:
	var grid := node.character_selection_grid
	var before := state.canonical_values()
	var requests_before := node.submitted_requests.size()
	var seen: Dictionary = {}
	grid.model.select_display_index(0)
	# Follow the visible grid using actual Bootstrap event routing, not model
	# selection setters. Alternating direction covers every row with no pages.
	for row: int in range(5):
		for column: int in range(6):
			var champion_id := String(grid.model.selected_entry().id)
			check(not seen.has(champion_id), "real modal navigation visits each flat-grid identity once")
			seen[champion_id] = true
			equal(grid.model.display_cells().size(), 30, "real Gallery routing retains every card on screen")
			equal(grid.model.equipped_id, "oh_tipi", "whole-roster inspection never relabels authoritative attunement")
			equal(grid.model.pending_wire, 0, "whole-roster inspection creates no pending authority work")
			equal(state.canonical_values(), before, "whole-roster inspection preserves character, resources and exact equipped weave")
			if column < 5:
				node._handle_character_gallery_input(_key(KEY_RIGHT if row % 2 == 0 else KEY_LEFT))
		if row < 4:
			node._handle_character_gallery_input(_key(KEY_DOWN))
	equal(seen.size(), 30, "all thirty characters are reachable by direct grid navigation")
	equal(node.submitted_requests.size(), requests_before, "browsing all thirty characters sends no host requests")
	check(grid.is_open, "whole-roster browsing keeps the Gallery modal open")


func _test_selection_availability(node: GalleryHarness, state: PlayerState) -> void:
	_select_champion(node, "oh_tipi")
	var retained_status: String = "Previous attunement confirmation remains visible."
	node.character_selection_grid.model.status_message = retained_status
	var station: Array = node.campus_layout.stations_by_id["champion-loom"].position
	state.position_x = int(station[0]) * 1000
	state.position_y = (int(station[1]) + 48) * 1000
	var availability: Dictionary = node._gallery_selection_availability(state)
	check(bool(availability.get("enabled", false)), "free grounded actor beside Gallery keeps the positive selection path")
	state.position_x = 400_000
	state.position_y = 400_000
	availability = node._gallery_selection_availability(state)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("beside the Gallery"), "remote Gallery inspection reports the exact station requirement")
	var requests_before := node.submitted_requests.size()
	node._handle_character_gallery_input(_key(KEY_ENTER))
	equal(node.submitted_requests.size(), requests_before, "remote Enter confirmation sends no refused request")
	equal(node.character_selection_grid.model.pending_wire, 0, "remote Enter confirmation creates no pending request")
	equal(node.character_selection_grid.model.status_message, retained_status, "remote availability does not overwrite retained feedback")
	state.position_x = int(station[0]) * 1000
	state.position_y = (int(station[1]) + 48) * 1000
	node.forced_round_phase = SessionRound.Phase.ACTIVE
	availability = node._gallery_selection_availability(state)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("Wellspring free practice"), "arranged active phase exposes the policy reason without claiming a lifecycle journey")
	node._handle_character_gallery_input(_key(KEY_ENTER))
	equal(node.submitted_requests.size(), requests_before, "active-round Enter confirmation sends no refused request")
	equal(node.character_selection_grid.model.pending_wire, 0, "active-round confirmation creates no pending request")
	node.forced_round_phase = SessionRound.Phase.HEARTH
	state.cast_recovery_ticks = 2
	availability = node._gallery_selection_availability(state)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("active action"), "active actor sees a specific attunement reason")
	node._handle_character_gallery_input(_key(KEY_ENTER))
	equal(node.submitted_requests.size(), requests_before, "active-action confirmation sends no refused request")
	equal(node.character_selection_grid.model.pending_wire, 0, "active-action confirmation creates no pending request")
	state.cast_recovery_ticks = 0
	state.health = 0
	availability = node._gallery_selection_availability(state)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("alive"), "dead actor sees a specific attunement reason")
	node._handle_character_gallery_input(_key(KEY_ENTER))
	equal(node.submitted_requests.size(), requests_before, "dead-actor confirmation sends no refused request")
	equal(node.character_selection_grid.model.pending_wire, 0, "dead-actor confirmation creates no pending request")
	state.health = state.health_maximum
	availability = node._gallery_selection_availability(null)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("unavailable"), "missing actor context fails closed with a visible reason")
	node.client_request_sequence = 0x7fffffff
	availability = node._gallery_selection_availability(state)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("Restart the session"), "exhausted request sequence is unavailable before pending state")
	node._handle_character_gallery_input(_key(KEY_ENTER))
	equal(node.submitted_requests.size(), requests_before, "exhausted sequence confirmation sends no request")
	equal(node.character_selection_grid.model.pending_wire, 0, "exhausted sequence confirmation creates no pending request")
	node.client_request_sequence = 0
	var original_map_id: String = node.world.map_id
	node.world.map_id = "hex-court-v1"
	state.position_x = 400_000
	state.position_y = 400_000
	availability = node._gallery_selection_availability(state)
	check(bool(availability.get("enabled", false)), "isolated offline Hex Court retains station-free Gallery admission")
	node.world.map_id = original_map_id
	node.forced_round_phase = -1
	state.position_x = int(station[0]) * 1000
	state.position_y = (int(station[1]) + 48) * 1000
	check(bool(node._gallery_selection_availability(state).get("enabled", false)), "restored ordinary Gallery context remains available")
	node.character_selection_grid.model.pending_wire = int(node.character_selection_grid.model.selected_entry().get("wire_id", 0))
	check(bool(node._gallery_selection_availability(state).get("enabled", false)), "contextual policy stays enabled while the grid owns pending confirmation")
	node._handle_character_gallery_input(_key(KEY_ENTER))
	equal(node.submitted_requests.size(), requests_before, "pending confirmation retains its existing no-duplicate request behavior")
	check(node.character_selection_grid.model.pending_wire != 0 and node.character_selection_grid.model.status_message.contains("Waiting for the host"), "pending selection retains the existing waiting state")
	node.character_selection_grid.model.pending_wire = 0
	node.character_selection_grid.model.status_message = retained_status
	equal(node.character_selection_grid.model.status_message, retained_status, "availability queries and blocked controls preserve status feedback")


func _select_champion(node: GalleryHarness, champion_id: String) -> void:
	for race: int in range(node.character_selection_grid.model.races().size()):
		for character: int in range(node.character_selection_grid.model.characters(race).size()):
			var entry: Dictionary = node.character_selection_grid.model.characters(race)[character]
			if String(entry.get("id", "")) == champion_id:
				node.character_selection_grid.model.select_cell(race, character)
				return


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _test_missing_presenter_procedural_fallback_contract() -> void:
	var source := FileAccess.get_file_as_string("res://src/app/bootstrap.gd").replace("\r\n", "\n")
	check(source.contains("if not sprite_drawn:\n\t\t\tdraw_circle(body_position, player_radius"), "missing visible local body presentation retains the bounded procedural circle")
	check(source.contains("if not sprite_drawn:\n\t\t\tvar body_color"), "missing remote body presentation retains the bounded procedural circle")


func _test_station_guide_device(node: GalleryHarness) -> void:
	var original_preferences := node.player_preferences
	var actor: PlayerState = node._local_player_state()
	var original_position := Vector2i(actor.position_x, actor.position_y)
	var original_focus := node.focused_station_id
	if node.player_preferences == null:
		node.player_preferences = PlayerPreferences.new()
	var original_events := InputMap.action_get_events(InputRouter.INTERACT_ACTION)
	var original_key: int = node.player_preferences.keyboard_bindings[&"jump"]
	var original_pad: Dictionary = node.player_preferences.controller_bindings[&"jump"].duplicate()
	var original_sprint_pad: Dictionary = node.player_preferences.controller_bindings[&"sprint"].duplicate()
	var original_interact_key: int = node.player_preferences.keyboard_bindings[&"interact"]
	var original_interact_mouse: int = node.player_preferences.mouse_bindings[&"interact"]
	var original_interact_pad: Dictionary = node.player_preferences.controller_bindings[&"interact"].duplicate()
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_G
	keyboard.keycode = KEY_G
	keyboard.pressed = true
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_XBUTTON1
	mouse.pressed = true
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_STICK
	pad.pressed = true
	InputMap.action_erase_events(InputRouter.INTERACT_ACTION)
	for event: InputEvent in [keyboard, mouse, pad]:
		InputMap.action_add_event(InputRouter.INTERACT_ACTION, event)
	node.player_preferences.keyboard_bindings[&"jump"] = KEY_J
	node.player_preferences.controller_bindings[&"jump"] = {"kind": "button", "index": JOY_BUTTON_LEFT_STICK, "direction": 0}
	node.player_preferences.controller_bindings[&"sprint"] = {"kind": "none", "index": -1, "direction": 0}
	node.player_preferences.keyboard_bindings[&"interact"] = KEY_G
	node.player_preferences.mouse_bindings[&"interact"] = MOUSE_BUTTON_XBUTTON1
	node.player_preferences.controller_bindings[&"interact"] = {"kind": "button", "index": JOY_BUTTON_RIGHT_STICK, "direction": 0}
	node.focused_station_id = ""
	for station_id: String in node.campus_layout.stations_by_id:
		if String(node.campus_layout.stations_by_id[station_id].get("command", "")) == "movement_guide":
			node.focused_station_id = station_id
			var position: Array = node.campus_layout.stations_by_id[station_id].position
			actor.position_x = int(position[0]) * SimConfig.FIXED_SCALE
			# Lodge has a practice wall south of its door: +12 remains clear
			# for the common wall radius, unlike the Academy's +48 approach.
			actor.position_y = (int(position[1]) + 12) * SimConfig.FIXED_SCALE
			break
	check(not node.focused_station_id.is_empty(), "device fixture finds the actual movement-guide station")
	var editor := ControlBindingEditor.new()
	for event: InputEvent in [pad, keyboard, pad, mouse]:
		node.player_compendium.close_panel()
		node.controls_input_guard_frames = 0
		node.application_input_active = true
		node._unhandled_input(event)
		node._activate_focused_station()
		var expected_activation := ControlBindingEditor.DEVICE_CONTROLLER if event is InputEventJoypadButton else (ControlBindingEditor.DEVICE_MOUSE if event is InputEventMouseButton else ControlBindingEditor.DEVICE_KEYBOARD)
		var expected_guide := ControlBindingEditor.DEVICE_CONTROLLER if expected_activation == ControlBindingEditor.DEVICE_CONTROLLER else ControlBindingEditor.DEVICE_KEYBOARD
		check(node.player_compendium.is_open, "mapped station activation opens the actual Compendium")
		equal(node.station_activation_device, expected_activation, "station remembers the exact device that performed mapped Interact")
		equal(node._station_interact_label(), editor.binding_label(&"interact", expected_activation, node.player_preferences), "station badge follows the exact rebound Interact input")
		equal(node.player_compendium.device, expected_guide, "movement guide keeps its controller or keyboard/mouse teaching family")
		var jump_row: Dictionary = node.player_compendium.movement_rows[2]
		equal(jump_row.binding, editor.binding_label(&"jump", expected_guide, node.player_preferences), "station shows the current rebound jump control for the activating setup")
		equal(node.controls_input_guard_frames, 2, "station opening retains modal input quarantine")
	node.player_compendium.close_panel()
	node.controls_input_guard_frames = 0
	node._observe_station_activation_device(pad)
	var unrelated := InputEventKey.new()
	unrelated.keycode = KEY_Z
	unrelated.physical_keycode = KEY_Z
	unrelated.pressed = true
	node._observe_station_activation_device(unrelated)
	equal(node.station_activation_device, ControlBindingEditor.DEVICE_CONTROLLER, "unrelated keyboard input cannot relabel a controller Interact press")
	var release := keyboard.duplicate() as InputEventKey
	release.pressed = false
	node._observe_station_activation_device(release)
	equal(node.station_activation_device, ControlBindingEditor.DEVICE_CONTROLLER, "release edges cannot replace accepted activation device")
	node.station_activation_device = ControlBindingEditor.DEVICE_MOUSE
	node.player_preferences.mouse_bindings[&"interact"] = 0
	equal(node._station_interact_label(), "UNBOUND", "explicitly unbound Interact never falls back to a false F prompt")
	equal(node._station_interact_instruction("confirms the action"), "Bind Interact in the Lodge controls.", "unbound station instructions explain how to bind instead of claiming an available action")
	InputMap.action_erase_events(InputRouter.INTERACT_ACTION)
	for event: InputEvent in original_events:
		InputMap.action_add_event(InputRouter.INTERACT_ACTION, event)
	node.player_preferences.keyboard_bindings[&"jump"] = original_key
	node.player_preferences.controller_bindings[&"jump"] = original_pad
	node.player_preferences.controller_bindings[&"sprint"] = original_sprint_pad
	node.player_preferences.keyboard_bindings[&"interact"] = original_interact_key
	node.player_preferences.mouse_bindings[&"interact"] = original_interact_mouse
	node.player_preferences.controller_bindings[&"interact"] = original_interact_pad
	node.player_preferences = original_preferences
	actor.position_x = original_position.x
	actor.position_y = original_position.y
	node.focused_station_id = original_focus


func _test_prediction_gait_metadata() -> void:
	var node := GalleryHarness.new()
	node.ability_catalog = AbilityCatalog.new()
	check(node.ability_catalog.load_from_file(Bootstrap.ABILITY_CATALOG_PATH), "predicted gait loads real ability catalog")
	node.champion_catalog = ChampionCatalog.new()
	check(node.champion_catalog.load_from_file(Bootstrap.CHAMPION_CATALOG_PATH, node.ability_catalog), "predicted gait loads actual character sizes")
	var language := VisualLanguage.new()
	check(language.load_from_file(), "predicted gait visual language loads")
	node.cartoon_champion_presenter = CartoonChampionPresenter.new()
	check(node.cartoon_champion_presenter.configure(language), "predicted gait uses real character height recipes")
	node.world = SimWorld.new(120, 1, CollisionWorld.new(3_072_000, 1_728_000))
	node.session_transport = SessionTransport.new()
	node.session_transport.mode = SessionTransport.Mode.CLIENT
	node.session_transport.accepted = true
	node.session_transport.local_entity_id = 2
	node.accumulator_seconds = 1.0 / 120.0
	var authority := PlayerState.new(2)
	node.world.players.append(authority)
	for champion_id: String in ["s_wayne", "red_baron"]:
		check(node.champion_catalog.apply_to_player(authority, champion_id), "client gait equips actual Small/Large champion")
		authority.health = authority.health_maximum
		authority.spawn_protection_ticks = 0
		authority.position_x = 512_000
		authority.position_y = 512_000
		authority.movement_mode = PlayerState.MovementMode.WALK
		authority.velocity_x = 240_000
		node.client_prediction = ClientPrediction.new()
		check(node.client_prediction.configure(node.world.config, node.world.collision, 2), "real local client prediction configures")
		check(node.client_prediction.reconcile(ClientPrediction.capture_packet(authority, 10, -1)), "actual movement-only reconciliation packet restores prediction")
		var predicted := node.client_prediction.predicted_state
		equal(predicted.champion_wire_id, authority.champion_wire_id, "prediction restores the authoritative identity required by situational movement perks")
		# Simulate local movement leading the last received authority snapshot.
		authority.movement_mode = PlayerState.MovementMode.IDLE
		authority.velocity_x = 0
		node.previous_position = Vector2(512, 512)
		node.current_position = node.previous_position
		node.previous_prediction_position = node.client_prediction.raw_position_pixels()
		node.actor_motion_history.clear()
		node._update_character_gaits(1.0 / 120.0)
		var before_authority := authority.canonical_values()
		node.current_position.x += 2.0
		predicted.position_x += 2_000
		var before_prediction := predicted.canonical_values()
		node._update_character_gaits(1.0 / 120.0)
		var height := float(node.cartoon_champion_presenter.champions[champion_id]["height"])
		var predicted_sprinting := predicted.sprinting or predicted.movement_mode == PlayerState.MovementMode.SPRINT
		var cadence_limit := ActorMotionHistory.MAX_GAIT_CYCLES_PER_SECOND if predicted_sprinting else ActorMotionHistory.MAX_WALK_GAIT_CYCLES_PER_SECOND
		var expected := minf(2.0 / MinimalChampionMotion.locomotion_stride_pixels(height), cadence_limit / 120.0)
		check(absf(node.actor_motion_history.gait_phase(2) - expected) < 0.00001, "local predicted travel uses actual Small/Large stride and predicted-mode cadence, not Middle fallback or idle authority")
		equal(node.actor_motion_history.gait_tracks[2].champion_wire_id, authority.champion_wire_id, "gait lifecycle retains authority identity separately from predicted motion")
		equal(authority.canonical_values(), before_authority, "bootstrap gait never mutates authority metadata")
		equal(predicted.canonical_values(), before_prediction, "bootstrap gait never patches omitted fields into prediction")
		var visual_id := node._champion_visual_id(authority)
		equal(visual_id, champion_id, "world sprite and HUD resolve actual client identity instead of predicted zero")
		check(node.cartoon_champion_presenter.can_present(visual_id), "actual local client identity has world sprite art")
		check(not node.cartoon_champion_presenter.portrait_frame(visual_id).is_empty(), "same actual local client identity resolves HUD portrait art")
		check(not node.cartoon_champion_presenter.movement_frame(visual_id, predicted, 20.0, node.world.config, false, expected).is_empty(), "predicted movement can render actual Small/Large world sprites")
		authority.spawn_protection_ticks = 30
		node._update_character_gaits(1.0 / 120.0)
		equal(node.actor_motion_history.gait_phase(2), 0.0, "same-alive client respawn resets despite absent predicted spawn field")
		authority.spawn_protection_ticks -= 1
		node.current_position.x += 2.0
		predicted.position_x += 2_000
		node._update_character_gaits(1.0 / 120.0)
		check(node.actor_motion_history.gait_phase(2) > 0.0, "ordinary authoritative protection countdown permits predicted walking")
		authority.health = 0
		node._update_character_gaits(1.0 / 120.0)
		node.current_position.x += 2.0
		predicted.position_x += 2_000
		node._update_character_gaits(1.0 / 120.0)
		equal(node.actor_motion_history.gait_phase(2), 0.0, "dead authority cannot walk because prediction still has default positive health")
		check(not node.actor_motion_history.gait_tracks[2].alive, "client gait life state follows the current world snapshot")
		authority.health = authority.health_maximum
		authority.spawn_protection_ticks = 30
		node._update_character_gaits(1.0 / 120.0)
		equal(node.actor_motion_history.gait_phase(2), 0.0, "revived client begins at a stable plant")
		node.current_position.x += 2.0
		predicted.position_x += 2_000
		node._update_character_gaits(1.0 / 120.0)
		check(node.actor_motion_history.gait_phase(2) > 0.0, "revived client resumes predicted travel normally")
		_test_prediction_correction_tail(node, authority, champion_id)
		check(node.champion_catalog.apply_to_player(authority, "oh_tipi"), "client switches actual identity without changing movement packet layout")
		check(predicted.champion_wire_id != authority.champion_wire_id, "the previous prediction identity intentionally trails the new authoritative attunement")
		node._update_character_gaits(1.0 / 120.0)
		equal(node.actor_motion_history.gait_phase(2), 0.0, "client identity switch resets even while predicted identity still belongs to the previous character")
	node.free()


func _test_prediction_correction_tail(node: GalleryHarness, authority: PlayerState, champion_id: String) -> void:
	var height := float(node.cartoon_champion_presenter.champions[champion_id]["height"])
	var stride := MinimalChampionMotion.locomotion_stride_pixels(height)
	for correction: int in [-24_000, 24_000]:
		authority.position_x = 512_000
		authority.position_y = 512_000
		authority.movement_mode = PlayerState.MovementMode.WALK
		authority.velocity_x = 240_000
		authority.spawn_protection_ticks = 0
		node.client_prediction = ClientPrediction.new()
		check(node.client_prediction.configure(node.world.config, node.world.collision, 2), "correction-tail client configures")
		check(node.client_prediction.reconcile(ClientPrediction.capture_packet(authority, 10, -1)), "correction-tail client initializes from actual packet")
		authority.position_x += correction
		check(node.client_prediction.reconcile(ClientPrediction.capture_packet(authority, 11, -1)), "actual positive/negative soft reconciliation starts its visual tail")
		check(absf(node.client_prediction.visual_offset.x) > 20.0, "fixture retains a real nonzero presentation correction offset")
		node.previous_prediction_position = node.client_prediction.raw_position_pixels()
		node.previous_position = node.client_prediction.presented_position_pixels()
		node.current_position = node.previous_position
		node.actor_motion_history.clear()
		node._update_character_gaits(1.0 / 120.0)
		var predicted := node.client_prediction.predicted_state
		var predicted_sprinting := predicted.sprinting or predicted.movement_mode == PlayerState.MovementMode.SPRINT
		var cadence_limit := ActorMotionHistory.MAX_GAIT_CYCLES_PER_SECOND if predicted_sprinting else ActorMotionHistory.MAX_WALK_GAIT_CYCLES_PER_SECOND
		var expected_step := minf(2.0 / stride, cadence_limit / 120.0)
		for frame: int in range(8):
			node.previous_prediction_position = node.client_prediction.raw_position_pixels()
			node.previous_position = node.client_prediction.presented_position_pixels()
			node.client_prediction.advance_visual(1.0 / 120.0)
			node.client_prediction.predicted_state.position_x += 2_000
			node.current_position = node.client_prediction.presented_position_pixels()
			node._update_character_gaits(1.0 / 120.0)
			var expected := fposmod(float(frame + 1) * expected_step, 1.0)
			check(absf(node.actor_motion_history.gait_phase(2) - expected) < 0.00001, "decaying positive/negative correction tail cannot alter the cadence-limited phase from real 2px foot travel")
		check(node.client_prediction.visual_offset.is_zero_approx(), "real soft correction tail finishes within the fixture")


func _test_active_page_preparation(node: GalleryHarness) -> void:
	var recorder := ActivePagesRecorder.new()
	node.cartoon_champion_presenter = recorder
	node.world.players.clear()
	var ids := node.champion_catalog.ordered_champion_ids()
	for index: int in range(8):
		var actor := PlayerState.new(index + 1)
		check(node.champion_catalog.apply_to_player(actor, ids[index]), "active-page fixture uses genuine champion identity")
		node.world.players.append(actor)
	var target := PlayerState.new(900)
	target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	node.world.players.append(target)
	var before := node.world.state_hash()
	check(node._prepare_active_character_pages(), "real bootstrap prepares all eight active actors before rendering")
	equal(recorder.received_ids.size(), 8, "training targets consume no full character-page residency")
	check(recorder.received_ids.has(ids[0]), "local actor is included, not only network guests")
	equal(node.world.state_hash(), before, "art preparation cannot mutate authoritative actors")
	for frame: int in range(30):
		check(node._prepare_active_character_pages(), "stable active identities stay prepared")
	equal(recorder.preparations, 1, "ordinary frames do not call page loading or decode again")
	node.world.players.reverse()
	check(node._prepare_active_character_pages(), "network actor ordering does not change resident identity set")
	equal(recorder.preparations, 1, "roster order alone triggers no page preparation")
	check(node.champion_catalog.apply_to_player(node.world.player(2), ids[8]), "actual selected identity changes its registered wire")
	check(node._prepare_active_character_pages(), "changed host/remote identity prepares before next draw")
	equal(recorder.preparations, 2, "one identity change causes exactly one preparation")
	check(recorder.received_ids.has(ids[8]) and not recorder.received_ids.has(ids[1]), "departed identity is replaced without a ninth page")
	recorder.configuration_generation += 1
	check(node._prepare_active_character_pages(), "same-ID validated manifest reload refreshes its resources")
	equal(recorder.preparations, 3, "explicit presenter reload causes one re-preparation")

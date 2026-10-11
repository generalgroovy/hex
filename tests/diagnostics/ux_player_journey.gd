extends "res://tests/diagnostics/loom_availability_journey.gd"
## Native lead-run regression; positions/focus are fixtures, admission is real.


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or not OS.get_user_data_dir().replace("\\", "/").contains("/hex-probe-"):
		push_error("Native backend, fresh output and isolated profile required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	facts = {"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string("res://content/runtime/runtime_build_identity_v1.json")), "fixture": "station positions, inspected selection and application focus are arranged; synthetic UI events, assignment, attunement and paid cast use production paths; unrelated desktop events are excluded without moving the OS cursor or focusing the window", "not_run": ["physical input and OS focus behavior", "remote networking", "human usability", "rendered FPS"], "user_data": OS.get_user_data_dir(), "focus_restorations": [], "service_routes": []}
	game = Bootstrap.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	# Only this diagnostic supplies UI events. Direct _unhandled_input calls below
	# still exercise production routing; desktop motion during captures cannot.
	game.set_process_unhandled_input(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for unused: int in range(4): game._process(1.0 / 120.0)
	if not _open_service("spell-loom"):
		await _finish()
		return
	_check(game.spell_loom_editor.is_open, "actual Academy directory opens Spell Loom")
	var actor: PlayerState = game._local_player_state()
	var original := actor.spell_wire_ids.duplicate()
	var editor: SpellLoomEditor = game.spell_loom_editor
	editor.selected_spell_index = 0
	_key(KEY_DOWN)
	_check(editor.selected_spell_index == 4, "native Down follows element rows")
	var wheel_slot := editor.selected_slot_index
	var wheel_state := actor.canonical_values()
	_wheel_at(editor.spell_rect(4).get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	_check(editor.selected_spell_index == 5 and editor.selected_slot_index == wheel_slot, "native library wheel browses spells without moving destination")
	_wheel_at(editor.spell_rect(5).get_center(), MOUSE_BUTTON_WHEEL_UP)
	_check(editor.selected_spell_index == 4 and actor.canonical_values() == wheel_state, "native wheel reverses selection without assigning or mutating gameplay")
	_key(KEY_PAGEDOWN)
	_check(editor.selected_element_filter == "water", "native PageDown filters library")
	_key(KEY_TAB)
	_key(KEY_RIGHT)
	_check(editor.focus_area == "slots" and editor.selected_slot_index == 1, "native Tab/Right selects adjacent target slot")
	_key(KEY_PAGEUP)
	_check(editor.selected_element_filter.is_empty(), "native PageUp restores all elements")
	editor.selected_slot_index = 0
	editor.selected_spell_index = editor.available_wire_ids.find(actor.spell_wire_ids[2])
	var proposed := editor.requested_wire_ids(actor)
	await _capture_ui("loom-swap")
	_key(KEY_ENTER)
	_check(actor.spell_wire_ids == proposed and game.pending_weave_request.is_empty(), "native confirm applies exact previewed swap")
	var sequence: int = game.client_request_sequence
	var saved_hash := FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH)
	_key(KEY_ENTER)
	_check(sequence == game.client_request_sequence and saved_hash == FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH), "same-slot confirmation sends/saves nothing")
	await _capture_ui("loom-no-op")
	# Mixed-input confirmation ends the old pointer gesture, even for a no-op.
	for controller: bool in [false, true]:
		var drag_source := editor.spell_rect(editor.available_wire_ids.find(actor.spell_wire_ids[0])).get_center()
		var drag_target := SpellLoomEditor.slot_rect(1).get_center()
		var before_drag := actor.canonical_values()
		_pointer_button(drag_source, true)
		var drag_motion := InputEventMouseMotion.new()
		drag_motion.position = drag_target * game._ui_scale()
		game._unhandled_input(drag_motion)
		_check(editor.dragging, "ordinary pointer motion creates a drag before explicit confirmation")
		if controller:
			var confirm := InputEventJoypadButton.new()
			confirm.button_index = JOY_BUTTON_A
			confirm.pressed = true
			game._unhandled_input(confirm)
		else:
			_key(KEY_ENTER)
		_check(not editor.dragging and editor.drag_spell_index == -1, "explicit keyboard/controller confirm ends the pointer gesture")
		_pointer_button(drag_target, false)
		_check(actor.canonical_values() == before_drag and game.client_request_sequence == sequence and FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH) == saved_hash, "later release on a different slot cannot submit a stale drag")
	await _capture_ui("loom-mixed-input-confirm")
	var heavy: int = game.ability_catalog.ability(game.ability_catalog.spell_id_at("water", "heavy")).wire_id
	# Heavy may already exist: the visible action still honestly previews swap/replacement.
	_click(editor.spell_rect(editor.available_wire_ids.find(heavy)).get_center())
	await _capture_ui("loom-heavy")
	_key(KEY_ENTER)
	_check(actor.spell_wire_ids[0] == heavy, "paid-test Heavy is deliberately equipped")
	_key(KEY_ESCAPE)
	game._process(1.0 / 120.0)
	_check(game.service_directory.is_open, "closing Loom returns to Academy")
	_key(KEY_ESCAPE)
	for unused: int in range(4): game._process(1.0 / 120.0)
	var flux := actor.flux
	_press_action(&"spell_1")
	game._process(1.0 / 120.0)
	Input.action_release(&"spell_1")
	_check(actor.flux < flux and actor.pending_cast_wire_id == heavy, "configured slot still starts real paid Heavy cast")
	var startup_steps := maxi(1, floori(float(actor.pending_cast_ticks) / 2.0))
	for unused: int in startup_steps: game._process(1.0 / 120.0)
	var startup := CompactCombatHud.spell_readiness(actor, game.ability_catalog.ability_from_wire(heavy))
	_check(startup.kind == "startup" and float(startup.progress) > 0.0 and float(startup.progress) < 1.0, "actual paid Heavy advances the hotbar startup track without claiming early release")
	facts.paid_startup = {"wire":heavy,"remaining_ticks":actor.pending_cast_ticks,"progress":startup.progress,"kind":startup.kind}
	await _capture_ui("hud-paid-startup")
	await _capture_resource_hover("hud-resource-recovery", actor)
	var flight_fixture := PlayerState.new()
	flight_fixture.flight_capable = true
	flight_fixture.air_floating = true
	flight_fixture.air_height = 42000
	flight_fixture.float_ticks = 144
	flight_fixture.stamina = 125000
	flight_fixture.stamina_maximum = 500000
	flight_fixture.flux = 89000
	flight_fixture.flux_maximum = 100000
	flight_fixture.flux_recovery_delay_ticks = 72
	facts.flight_resource_fixture = "HUD-only arranged flight/wait values; not a simulated flight or a character capability claim"
	await _capture_resource_hover("hud-resource-flight-fixture", flight_fixture)
	var original_notice: String = game.station_notice
	var original_notice_seconds: float = game.station_notice_seconds
	game.station_notice = "Water Spray | Earth Spray | Fire Bolt | Fire Rapid in your first four positions."
	game.station_notice_seconds = 4.0
	facts.notice_fixture = "Real production notice copy, arranged display without invoking practice reset"
	await _capture_ui("notice-complete")
	root.size = Vector2i(960, 540)
	await process_frame
	await _capture_ui("notice-narrow")
	root.size = Vector2i(1280, 720)
	await process_frame
	game.station_notice = original_notice
	game.station_notice_seconds = original_notice_seconds
	_press_action(&"spell_layer_ctrl")
	game._process(1.0 / 120.0)
	var hidden := CompactCombatHud.hidden_cast_status(actor,game.ability_catalog,1,game.player_preferences)
	_check(int(hidden.get("wire_id",0))==heavy and float(hidden.get("progress",0.0))>0.0, "changing visible layer does not hide paid startup")
	facts.hidden_paid_startup=hidden.duplicate(true)
	await _capture_ui("hud-hidden-paid-startup")
	Input.action_release(&"spell_layer_ctrl")
	game._process(1.0 / 120.0)
	_check(CompactCombatHud.hidden_cast_status(actor,game.ability_catalog,0,game.player_preferences).is_empty(), "returning to casting slot removes duplicate cue")
	for unused: int in range(120): game._process(1.0 / 120.0)
	if not _open_service("spell-loom"):
		await _finish()
		return
	editor.selected_slot_index = 0
	var bolt: int = game.ability_catalog.ability(game.ability_catalog.spell_id_at("fire", "bolt")).wire_id
	editor.selected_spell_index = editor.available_wire_ids.find(bolt)
	_key(KEY_ENTER)
	_check(actor.spell_wire_ids[0] == bolt, "ordinary Loom confirmation equips held Bolt")
	await _capture_ui("loom-bolt")
	_key(KEY_ESCAPE)
	game._process(1.0 / 120.0)
	_key(KEY_ESCAPE)
	# Closing a menu deliberately suppresses held inputs during its short guard.
	# Observe neutral frames before issuing a fresh gameplay press, as above.
	for unused: int in range(4): game._process(1.0 / 120.0)
	_check(not game._gameplay_input_blocked(), "menu-close guard settles before a fresh Bolt press")
	var bolt_flux := actor.flux
	var bolt_starts := 0
	_press_action(&"spell_1")
	for unused: int in range(65):
		game._process(1.0 / 120.0)
		for event: Dictionary in game.world.combat_events:
			if event.get("type", "") == "cast_started" and int(event.get("wire_id", 0)) == bolt: bolt_starts += 1
	Input.action_release(&"spell_1")
	facts.held_bolt = {"admissions": bolt_starts, "flux_before": bolt_flux, "flux_after": actor.flux, "binding": "spell_1", "ticks": 65}
	_check(bolt_starts >= 2 and actor.flux <= bolt_flux - 12_000, "native held input admits multiple paid Bolts without mashing")
	var released_flux := actor.flux
	for unused: int in range(45): game._process(1.0 / 120.0)
	_check(actor.flux >= released_flux, "releasing Bolt prevents further payment while accepted startup may finish")
	game.player_preferences.keyboard_bindings[&"spell_1"] = KEY_T
	game.player_preferences.keyboard_bindings[&"spell_layer_ctrl"] = KEY_SHIFT
	await _capture_ui("hud-rebound")
	if not _open_service("spell-loom"):
		await _finish()
		return
	_check(SpellLoomPresenter.slot_keycap(4, game.player_preferences).label == "Shift+T", "Loom keycap uses saved modifier and key")
	await _capture_ui("loom-rebound")
	game.player_preferences.keyboard_bindings[&"spell_1"] = 0
	var saved_spell_pad: Dictionary = game.player_preferences.controller_bindings[&"spell_1"].duplicate(true)
	var saved_spell_mouse: int = game.player_preferences.mouse_bindings[&"spell_1"]
	_check(SpellLoomPresenter.slot_keycap(0, game.player_preferences).label == "PAD UP", "Loom retains actual saved pad input when only keyboard is unbound")
	game.player_preferences.controller_bindings[&"spell_1"] = PlayerPreferences.unbound_controller_binding()
	game.player_preferences.mouse_bindings[&"spell_1"] = MOUSE_BUTTON_MIDDLE
	_check(SpellLoomPresenter.slot_keycap(0, game.player_preferences).label == "MOUSE M" and CompactCombatHud.button_binding_label(0, game.player_preferences) == "MOUSE M", "native journey presents the same saved mouse-only input in Loom and HUD")
	game.player_preferences.mouse_bindings[&"spell_1"] = 0
	_check(SpellLoomPresenter.slot_keycap(0, game.player_preferences).label == "Not bound", "Loom card makes missing input explicit")
	await _capture_ui("loom-unbound")
	game.player_preferences.keyboard_bindings[&"spell_1"] = KEY_T
	game.player_preferences.mouse_bindings[&"spell_1"] = saved_spell_mouse
	game.player_preferences.controller_bindings[&"spell_1"] = saved_spell_pad
	_key(KEY_ESCAPE)
	game._process(1.0 / 120.0)
	_key(KEY_ESCAPE)
	if not _open_service("champion-loom"):
		await _finish()
		return
	var grid: CharacterSelectionGrid = game.character_selection_grid
	_check(grid.is_open, "Gallery opens through normal game route")
	var before_character := actor.champion_wire_id
	var cell := Vector2i(-1, -1)
	for race: int in range(grid.model.races().size()):
		for row: int in range(grid.model.characters(race).size()):
			var entry: Dictionary = grid.model.characters(race)[row]
			if bool(entry.selectable) and int(entry.wire_id) != before_character:
				cell = Vector2i(race, row)
				break
		if cell.x >= 0: break
	_check(cell.x >= 0, "Gallery fixture finds another selectable identity")
	if cell.x < 0:
		await _finish()
		return
	grid.model.select_cell(cell.x, cell.y)
	_click(grid.card_rect(cell.x, cell.y).get_center())
	_check(actor.champion_wire_id == before_character and grid.model.pending_wire == 0, "native card click cannot change identity or reset weave")
	await _capture_ui("gallery-overview")
	_key(KEY_END)
	await _capture_ui("gallery-details")
	_key(KEY_TAB)
	var selected_wire := int(grid.model.selected_entry().wire_id)
	_click(CharacterSelectionGrid.SELECT_RECT.get_center())
	_check(actor.champion_wire_id == selected_wire, "explicit native Attune commits selected character")
	_key(KEY_ESCAPE)
	game._process(1.0 / 120.0)
	_key(KEY_ESCAPE)
	# The real offline Ready gate: click, then process another ordinary UI frame.
	if not _open_service("session-hearth"):
		await _finish()
		return
	_check(game.service_directory.is_open and not game.service_directory.selected_available(), "offline Ready stays in its directory without an illegal action")
	var refused_cards: Array[Rect2] = game.service_directory.layout_for(Vector2(root.size) / game._ui_scale()).cards
	var refused_index: int = game.service_directory.selected_index
	_check(refused_index >= 0 and refused_index < refused_cards.size(), "offline Ready has a rendered card before its pointer check")
	if refused_index < 0 or refused_index >= refused_cards.size():
		await _finish()
		return
	var refused_rect: Rect2 = refused_cards[refused_index]
	# Synthetic click events do not physically move the OS cursor; update that
	# same logical pointer explicitly rather than allowing unrelated desktop input.
	game.service_directory.update(1.0 / 120.0, refused_rect.get_center(), Vector2(root.size) / game._ui_scale())
	game._refresh_directory_availability()
	_check(game.service_directory.details_visible and not game.service_directory.selected_disabled_reason().is_empty(), "disabled reason survives a fresh availability and pointer update")
	await _capture_ui("service-refusal")
	game.service_directory.close()
	root.size = Vector2i(1600, 900)
	game.spell_loom_editor.open_editor(actor, game.ability_catalog)
	await _capture_ui("loom-1600x900")
	_check(original.size() == 12, "original weave remains a complete twelve-slot fixture")
	await _finish()


func _open_service(station: String) -> bool:
	_restore_fixture_focus("open-service:" + station)
	_place(station)
	for unused: int in range(4): game._process(1.0 / 120.0)
	if not game.service_directory.is_open:
		_press_action(&"interact")
		game._process(1.0 / 120.0)
		Input.action_release(&"interact")
	facts.service_routes.append({"station": station, "stage": "parent", "ui": _ui_state(station)})
	_check(game.service_directory.is_open, "Interact opens parent directory for " + station)
	if not game.service_directory.is_open:
		return false
	var geometry: Dictionary = game.service_directory.layout_for(Vector2(root.size) / game._ui_scale())
	for index: int in range(game.service_directory.entries.size()):
		if String(game.service_directory.entries[index].id) == station:
			_check(index < geometry.cards.size(), "service has a rendered card: " + station)
			if index >= geometry.cards.size():
				return false
			_click((geometry.cards[index] as Rect2).get_center())
			var routed: bool = game.service_directory.is_open and game.service_directory.selected_station_id() == station
			if station == "spell-loom": routed = game.spell_loom_editor.is_open and not game.service_directory.is_open
			if station == "champion-loom": routed = game.character_selection_grid.is_open and not game.service_directory.is_open
			facts.service_routes.append({"station": station, "stage": "clicked", "ui": _ui_state(station)})
			_check(routed, "ordinary service click reaches expected view: " + station)
			return routed
	_check(false, "service exists in parent directory: " + station)
	return false


func _pointer_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point * game._ui_scale()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	game._unhandled_input(event)


func _capture_resource_hover(label: String, state: PlayerState) -> void:
	# Replace only the HUD draw for one frame, injecting a logical pointer into
	# its public draw call. Never move the OS cursor or alter authority.
	var hud: CompactCombatHud = game.compact_hud
	var overlay := Node2D.new()
	var id: String = game._champion_visual_id(game._local_player_state())
	var name_text: String = game.champion_catalog.champion(id).display_name
	game.compact_hud = null
	game.add_child(overlay)
	overlay.draw.connect(func() -> void:
		var ui_scale: float = game._ui_scale()
		var viewport := Vector2(root.size) / ui_scale
		overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
		hud.draw(overlay, viewport, state, game.ability_catalog, id, name_text, "THE WELLSPRING", game._session_label(), 0, 120, false, Vector2i(-1,-1), "", Vector2(100,viewport.y-70), "", game.player_preferences)
	)
	overlay.queue_redraw()
	await _capture_ui(label)
	game.compact_hud = hud
	overlay.queue_free()
	await process_frame


func _capture_ui(label: String) -> void:
	var authority: String = game.world.state_hash()
	if not facts.has("practice_copy"): facts.practice_copy = []
	var alpha: float = clampf(game.accumulator_seconds * float(game.tick_rate), 0.0, 1.0)
	var focus: Vector2 = game._camera_focus_position(game.previous_position.lerp(game.current_position, alpha))
	for group: Dictionary in game.campus_layout.practice_groups_by_id.values():
		var anchor := Vector2(SanctumCampusLayout._parse_point(group["label_anchor"]))
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(group["bounds"]))
		facts.practice_copy.append({"frame": label, "group": group.id, "focus": [focus.x, focus.y], "opacity": SanctumCampusRenderer.practice_instruction_opacity(anchor, focus, bounds)})
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	_check(picture.save_png(output.path_join(label + ".png")) == OK, label + " saves native frame")
	_check(game.world.state_hash() == authority, label + " rendering leaves authority unchanged")
	frames.append({"label": label, "image": label + ".png", "size": [picture.get_width(), picture.get_height()], "authority_hash": authority, "ui": _ui_state()})
	# Awaiting native frames can deliver a genuine focus-out notification. This
	# is a synthetic-input fixture, not an OS-focus test; restore via the normal
	# notification without changing the runtime's focus safety or its input guard.
	_restore_fixture_focus("after-capture:" + label)


func _wheel_at(point: Vector2, button: MouseButton) -> void:
	_restore_fixture_focus("wheel")
	var event := InputEventMouseButton.new()
	event.position = point * game._ui_scale()
	event.button_index = button
	event.pressed = true
	game._unhandled_input(event)


func _key(code: Key) -> void:
	_restore_fixture_focus("key:" + str(code))
	super._key(code)


func _click(point: Vector2) -> void:
	_restore_fixture_focus("click")
	super._click(point)


func _press_action(action: StringName) -> void:
	_restore_fixture_focus("action:" + String(action))
	Input.action_press(action)


func _restore_fixture_focus(context: String) -> void:
	if game.application_input_active:
		return
	facts.focus_restorations.append({"context": context, "ui": _ui_state()})
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)


func _ui_state(station: String = "") -> Dictionary:
	var actor: PlayerState = game._local_player_state()
	var geometry: Dictionary = game.service_directory.layout_for(Vector2(root.size) / game._ui_scale())
	return {
		"application_input_active": game.application_input_active,
		"window_has_focus": game.get_window().has_focus(),
		"input_guard_frames": game.controls_input_guard_frames,
		"gameplay_input_blocked": game._gameplay_input_blocked(),
		"focused_station": game.focused_station_id,
		"directory_open": game.service_directory.is_open,
		"directory_group": game.service_directory.group_id,
		"directory_entries": game.service_directory.entries.size(),
		"directory_cards": geometry.cards.size(),
		"selected_station": game.service_directory.selected_station_id(),
		"return_station": game.directory_return_station,
		"loom_open": game.spell_loom_editor.is_open,
		"gallery_open": game.character_selection_grid.is_open,
		"position": [actor.position_x, actor.position_y] if actor != null else [],
		"station_in_reach": actor != null and not station.is_empty() and SanctumStationModel.station_in_reach(game.campus_layout.stations_by_id, station, Vector2i(actor.position_x, actor.position_y)),
	}


func _check(condition: bool, message: String) -> void:
	super._check(condition, message)
	if not condition:
		if not facts.has("failure_states"): facts.failure_states = []
		facts.failure_states.append({"message": message, "ui": _ui_state()})
		print("UX_CHECK_FAILED: ", message, " ", JSON.stringify(_ui_state()))


func _finish() -> void:
	facts.final_ui_state = _ui_state()
	await super._finish()

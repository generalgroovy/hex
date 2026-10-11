extends SceneTree

# Real Bootstrap, station Interact, Loom input handlers and Gallery requests.
# Only actor station positions are arranged. No final wire/character injection.
const Bootstrap = preload("res://src/app/bootstrap.gd")
var game: Node
var output := ""
var facts := {"passed": true, "checks": [], "starting_station_positions_arranged": true}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	game = Bootstrap.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var actor: PlayerState = game._local_player_state()
	var original_champion: int = actor.champion_wire_id
	facts.original_champion = original_champion
	facts.initial_wires = Array(actor.spell_wire_ids)
	_arrange_station("spell-loom")
	_settle()
	await _interact()
	_check(game.spell_loom_editor.is_open, "ordinary station Interact opens Loom")
	if not game.spell_loom_editor.is_open:
		await _finish()
		return
	# Filter through its actual mouse hit target, then drag the visible spell
	# into Alt+4. Every requested wire is derived from the presented catalogue.
	_mouse_button(SpellLoomEditor.element_filter_rect(1).get_center(), true)
	_mouse_button(SpellLoomEditor.element_filter_rect(1).get_center(), false)
	_check(game.spell_loom_editor.selected_element_filter == "water", "Water filter uses ordinary pointer events")
	var visible: PackedInt32Array = game.spell_loom_editor.visible_spell_indices()
	_check(not visible.is_empty(), "filtered picker contains a presented Water spell")
	if visible.is_empty():
		await _finish()
		return
	var index: int = visible[0]
	var expected_wire: int = game.spell_loom_editor.available_wire_ids[index]
	var source: Vector2 = game.spell_loom_editor.spell_rect(index).get_center()
	var target := SpellLoomEditor.slot_rect(11).get_center()
	_mouse_button(source, true)
	var motion := InputEventMouseMotion.new()
	motion.position = target * game._ui_scale()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	game._unhandled_input(motion)
	_mouse_button(target, false)
	_check(actor.spell_wire_id(12) == expected_wire and game.pending_weave_request.is_empty(), "filtered drag applies and confirms Alt+4 through authority")
	# Controller events wrap Alt+4 to slot1, select the next visible Water spell
	# and submit through the same player input/request path.
	_joy(JOY_BUTTON_DPAD_DOWN)
	_joy(JOY_BUTTON_DPAD_RIGHT)
	var controller_wire: int = game.spell_loom_editor.selected_wire_id()
	_joy(JOY_BUTTON_A)
	_check(actor.spell_wire_id(1) == controller_wire and game.pending_weave_request.is_empty(), "controller selection and Assign confirm slot1")
	var custom := actor.spell_wire_ids.duplicate()
	facts.custom_wires = Array(custom)
	_check(custom != PackedInt32Array(facts.initial_wires), "journey creates an actual changed custom weave")
	_check(FileAccess.file_exists(CharacterWeaveLibrary.DEFAULT_PATH), "confirmed UI assignment creates the isolated saved library")
	_joy(JOY_BUTTON_B)
	_check(not game.spell_loom_editor.is_open, "controller Back closes Loom")
	for unused: int in range(4): game._process(1.0 / 120.0)
	await process_frame
	var flux_before: int = actor.flux
	Input.action_press(&"spell_1")
	game._process(1.0 / 120.0)
	Input.action_release(&"spell_1")
	_check(actor.pending_cast_wire_id == custom[0] and actor.flux < flux_before, "custom slot1 starts an ordinary paid cast after Loom close")
	await process_frame
	_settle()
	_arrange_station("champion-loom")
	await _interact()
	_check(game.character_selection_grid.is_open, "ordinary Gallery station Interact opens selection")
	if not game.character_selection_grid.is_open:
		await _finish()
		return
	_key(KEY_RIGHT)
	_key(KEY_ENTER)
	actor = game._local_player_state()
	facts.other_champion = actor.champion_wire_id
	_check(actor.champion_wire_id != original_champion, "Gallery keyboard selection equips another character through authority")
	_settle()
	_key(KEY_LEFT)
	_key(KEY_ENTER)
	actor = game._local_player_state()
	_check(actor.champion_wire_id == original_champion, "Gallery keyboard return equips original character")
	_check(actor.spell_wire_ids == custom, "original character restores its saved custom weave")
	_key(KEY_ESCAPE)
	_check(not game.character_selection_grid.is_open, "Escape closes Gallery after switching")
	var disk := CharacterWeaveLibrary.new()
	_check(disk.load_from_file(CharacterWeaveLibrary.DEFAULT_PATH, game.champion_catalog, game.ability_catalog), "saved library reloads independently after character switching")
	var champion_id: String = game.champion_catalog.champion_id_from_wire(original_champion)
	_check(disk.saved_weave(champion_id).get("wire_ids", PackedInt32Array()) == custom, "disk retains original character custom weave after both switches")
	facts.final_wires = Array(actor.spell_wire_ids)
	facts.final_champion = actor.champion_wire_id
	facts.pending_at_end = not game.pending_weave_request.is_empty()
	facts.feedback = game.station_notice
	await _finish()


func _settle() -> void:
	var frames := 0
	while frames < 960:
		var actor: PlayerState = game._local_player_state()
		var cooling := false
		for ticks: int in actor.spell_cooldown_ticks:
			cooling = cooling or ticks > 0
		if frames >= 4 and not cooling and ChampionAttunement.is_available(actor): break
		game._process(1.0 / 120.0)
		frames += 1
	_check(frames < 960, "neutral real process clears active action and cooldown within bounded authored time")


func _arrange_station(id: String) -> void:
	var position: Array = game.campus_layout.stations_by_id[id].position
	var actor: PlayerState = game._local_player_state()
	actor.position_x = int(position[0]) * 1000
	actor.position_y = (int(position[1]) + 48) * 1000
	game._update_station_focus()


func _interact() -> void:
	Input.action_press(&"interact")
	game._process(1.0 / 120.0)
	Input.action_release(&"interact")
	await process_frame


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)


func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	game._unhandled_input(event)


func _mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position * game._ui_scale()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	game._unhandled_input(event)


func _check(condition: bool, message: String) -> void:
	facts.checks.append({"passed": condition, "message": message})
	facts.passed = bool(facts.passed) and condition


func _finish() -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		game.queue_free()
		quit(1)
		return
	file.store_string(JSON.stringify(facts, "\t") + "\n")
	file.close()
	print("LOOM_CHARACTER_JOURNEY ", JSON.stringify(facts))
	game.queue_free()
	await process_frame
	quit(0 if bool(facts.passed) else 1)

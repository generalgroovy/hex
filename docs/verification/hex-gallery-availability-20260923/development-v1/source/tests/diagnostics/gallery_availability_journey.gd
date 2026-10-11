extends SceneTree

# Root-owned native diagnostic. Positions, phase, locks and pending are explicit
# fixtures. Opening, inspecting, requesting and closing use production UI input.
const Bootstrap = preload("res://src/app/bootstrap.gd")
const Grid = preload("res://src/presentation/character_selection_grid.gd")
var game: Node
var output := ""
var baseline := false
var checks: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var failures: Array[String] = []
var facts: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--baseline": baseline = true
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or not OS.get_user_data_dir().replace("\\", "/").contains("/hex-probe-"):
		push_error("Native backend, fresh absolute output and wrapper-isolated profile required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	facts = {"baseline": baseline, "runtime_identity": JSON.parse_string(FileAccess.get_file_as_string("res://content/runtime/runtime_build_identity_v1.json")),
		"fixture": "arranged station positions, valid phase packet, action/death/pending states; actual UI opening, navigation, attunement and closing",
		"not_run": ["physical input", "live network round transition", "all identities", "human visual approval"], "user_data": OS.get_user_data_dir()}
	game = Bootstrap.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for unused: int in range(4): game._process(1.0 / 120.0)
	var actor: PlayerState = game._local_player_state()
	var original_wire: int = actor.champion_wire_id
	_place_gallery()
	Input.action_press(&"interact")
	game._process(1.0 / 120.0)
	Input.action_release(&"interact")
	_check(game.character_selection_grid.is_open, "ordinary Gallery Interact opens inspection")
	_key(KEY_RIGHT)
	_check(int(game.character_selection_grid.model.selected_entry().get("wire_id", 0)) != original_wire, "navigation selects another playable identity")
	await _capture("hearth-available", true)
	var original_round: PackedInt32Array = game.session_round_values.duplicate()
	var active_round := SessionRound.new()
	active_round.phase = SessionRound.Phase.ACTIVE
	active_round.scores_by_entity = {1: 0, 2: 0}
	game.session_round_values = active_round.capture(game.world)
	_check(SessionRound.validate_packet(game.session_round_values) and int(game._current_round_state().get("phase", -1)) == SessionRound.Phase.ACTIVE, "arranged two-participant packet is actually ACTIVE")
	await _capture("active-round", false)
	for route: String in ["enter", "controller", "button", "card"]:
		_attempt_refused(actor, route, "ACTIVE " + route)
	var direction: int = game.character_selection_grid.preview_direction
	_key(KEY_BRACKETRIGHT)
	_check(game.character_selection_grid.preview_direction == posmod(direction + 1, 8), "blocked attunement still permits facing inspection")
	_key(KEY_END)
	_check(game.character_selection_grid.detail_page > 0, "blocked attunement still permits detail pages")
	_key(KEY_PAGEDOWN)
	_check(game.character_selection_grid.model.race_page() > 0, "blocked attunement still permits race pages")
	_key(KEY_PAGEUP)
	_key(KEY_LEFT)
	_key(KEY_RIGHT)
	await _capture("active-browse", false)
	game.session_round_values = original_round
	actor.position_x = 400000
	actor.position_y = 400000
	game._update_station_focus()
	await _capture("away-gallery", false)
	_attempt_refused(actor, "enter", "away from Gallery")
	_place_gallery()
	actor.cast_recovery_ticks = 6
	await _capture("active-action", false)
	_attempt_refused(actor, "button", "active action")
	actor.cast_recovery_ticks = 0
	var health: int = actor.health
	actor.health = 0
	await _capture("dead-actor", false)
	_attempt_refused(actor, "controller", "dead actor")
	actor.health = health
	if not baseline:
		var sequence: int = game.client_request_sequence
		game.client_request_sequence = 2147483647
		await _capture("sequence-exhausted", false)
		_attempt_refused(actor, "enter", "sequence exhausted")
		game.client_request_sequence = sequence
	game.character_selection_grid.model.pending_wire = 2
	await _capture("pending", true)
	var pending_before: int = game.character_selection_grid.model.pending_wire
	var before_sequence: int = game.client_request_sequence
	_key(KEY_ENTER)
	_check(game.character_selection_grid.model.pending_wire == pending_before and game.client_request_sequence == before_sequence, "pending confirmation cannot be replaced or resent")
	_key(KEY_ESCAPE)
	_check(not game.character_selection_grid.is_open and game.character_selection_grid.model.pending_wire == pending_before, "Escape closes inspection without revoking pending attunement")
	# End the arranged pending fixture; reopen through actual station Interact.
	game.character_selection_grid.model.pending_wire = 0
	for unused: int in range(4): game._process(1.0 / 120.0)
	Input.action_press(&"interact")
	game._process(1.0 / 120.0)
	Input.action_release(&"interact")
	_check(game.character_selection_grid.is_open, "ordinary station Interact reopens after blocked paths")
	_key(KEY_RIGHT)
	var requested: int = game.character_selection_grid.model.selected_entry().get("wire_id", 0)
	_check(requested > 0 and requested != original_wire, "positive route requests a different valid champion")
	_key(KEY_ENTER)
	actor = game._local_player_state()
	_check(actor.champion_wire_id == requested and game.character_selection_grid.model.pending_wire == 0, "eligible UI attunement confirms through authority")
	await _capture("confirmed", true)
	_key(KEY_ESCAPE)
	for unused: int in range(4): game._process(1.0 / 120.0)
	var before_position: int = actor.position_x
	Input.action_press(&"move_right")
	for unused: int in range(24): game._process(1.0 / 120.0)
	Input.action_release(&"move_right")
	_check(actor.position_x != before_position and not game.character_selection_grid.is_open, "movement resumes after Gallery closes")
	facts.original_wire = original_wire
	facts.confirmed_wire = actor.champion_wire_id
	await _finish()


func _capture(label: String, enabled: bool) -> void:
	var authority: String = game.world.state_hash()
	var availability := {"enabled": true, "reason": "Legacy grid paints final attunement without contextual admission."}
	var samples := PackedInt64Array()
	if not baseline:
		availability = game._gallery_selection_availability(game._local_player_state())
		_check(bool(availability.enabled) == enabled, label + " availability matches existing authority rules")
		if not enabled: _check(not String(availability.reason).is_empty(), label + " supplies a visible reason")
		for unused: int in range(128):
			var start := Time.get_ticks_usec()
			game._gallery_selection_availability(game._local_player_state())
			samples.append(Time.get_ticks_usec() - start)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, label + " saves native frame")
	_check(game.world.state_hash() == authority, label + " advisory query and draw preserve world authority")
	frames.append({"label":label,"expected_context_enabled":enabled,"availability":availability,"pending_wire":game.character_selection_grid.model.pending_wire,"image":label + ".png", "modal_query_us":Array(samples)})


func _attempt_refused(actor: PlayerState, route: String, label: String) -> void:
	var before := actor.canonical_values()
	var sequence: int = game.client_request_sequence
	var events: Array[Dictionary] = game.authoritative_session.pending_combat_events.duplicate(true)
	var saved_before := FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH) if FileAccess.file_exists(CharacterWeaveLibrary.DEFAULT_PATH) else ""
	match route:
		"enter": _key(KEY_ENTER)
		"controller":
			var event := InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_A
			event.pressed = true
			game._unhandled_input(event)
		"button": _click(Grid.SELECT_RECT.get_center())
		"card": _click(game.character_selection_grid.card_rect(game.character_selection_grid.model.race_index, game.character_selection_grid.model.character_index).get_center())
	_check(actor.canonical_values() == before and game.character_selection_grid.model.pending_wire == 0, label + " preserves actor and leaves no pending attunement")
	_check(game.client_request_sequence == sequence, label + " offline path leaves client sequence unchanged")
	if baseline:
		var last: Dictionary = game.authoritative_session.pending_combat_events.back()
		_check(game.authoritative_session.pending_combat_events != events and String(last.get("type", "")) == "request_refused" and int(last.get("action", 0)) == SessionTransport.REQUEST_CHAMPION_SELECT and int(last.get("entity_id", 0)) == actor.entity_id, label + " reproduces matching authority refusal")
	else:
		_check(game.authoritative_session.pending_combat_events == events, label + " emits no authority event")
	var saved_after := FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH) if FileAccess.file_exists(CharacterWeaveLibrary.DEFAULT_PATH) else ""
	_check(saved_before == saved_after, label + " leaves saved weave bytes unchanged")


func _place_gallery() -> void:
	var point: Array = game.campus_layout.stations_by_id["champion-loom"].position
	var actor: PlayerState = game._local_player_state()
	actor.position_x = int(point[0]) * 1000
	actor.position_y = (int(point[1]) + 48) * 1000
	game._update_station_focus()


func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point * game._ui_scale()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		game._unhandled_input(event)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)


func _check(condition: bool, message: String) -> void:
	checks.append({"passed":condition,"message":message})
	if not condition: failures.append(message)


func _finish() -> void:
	facts.merge({"passed":failures.is_empty(),"checks":checks,"failures":failures,"frames":frames},true)
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(facts,"\t") + "\n")
	file.close()
	print("GALLERY_AVAILABILITY ",checks.size()," checks / ",failures.size()," failures / ",frames.size()," native frames")
	for failure: String in failures: print("FAILED: ",failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

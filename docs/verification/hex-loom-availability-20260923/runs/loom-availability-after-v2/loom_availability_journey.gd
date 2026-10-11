extends SceneTree

# Lead-run native UI diagnostic. Positions, locks and round/pending conditions
# are arranged fixtures; assignment and the final paid cast use real UI routes.
const Bootstrap = preload("res://src/app/bootstrap.gd")
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
		"fixture": "initial positions, action lock, round phase and pending request are arranged; actual UI events, assignment, persistence, movement and paid casting are production paths",
		"not_run": ["physical input", "network transport/lifecycle", "human feel", "all 32 spells by 12 slots"], "user_data": OS.get_user_data_dir()}
	game = Bootstrap.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for unused: int in range(4): game._process(1.0 / 120.0)
	var actor: PlayerState = game._local_player_state()
	actor.position_x = 400000
	actor.position_y = 400000
	game._update_station_focus()
	_check(game.focused_station_id not in ["spell-loom", "champion-loom"], "away fixture is outside both accepted stations")
	_click(Bootstrap.HEX_START_RECT.get_center())
	_check(game.hex_playground_open, "ordinary Chemistry Matrix button opens its panel")
	var layout: Dictionary = HexPlaygroundPanel.layout(Bootstrap.HEX_PLAYGROUND_RECT, game._reduced_effects_enabled())
	_click((layout.buttons.open_loom as Rect2).get_center())
	_check(game.spell_loom_editor.is_open and not game.hex_playground_open, "ordinary chemistry panel opens browseable Loom away from station")
	await _capture("away-assign", false)
	_attempt_refused(actor, "away assignment")
	_key(KEY_HOME)
	_check(game.spell_loom_editor.starter_preview_active(), "starter preview remains available while assignment is blocked")
	await _capture("away-starter", false)
	_attempt_refused(actor, "away starter apply")
	_key(KEY_ESCAPE)
	_check(game.spell_loom_editor.is_open and not game.spell_loom_editor.starter_preview_active(), "Escape cancels preview without closing inspection")
	_key(KEY_ESCAPE)
	_check(not game.spell_loom_editor.is_open, "Escape closes unavailable Loom")
	_place("spell-loom")
	for unused: int in range(4): game._process(1.0 / 120.0)
	Input.action_press(&"interact")
	game._process(1.0 / 120.0)
	Input.action_release(&"interact")
	_check(game.spell_loom_editor.is_open, "ordinary Interact opens Loom at actual station")
	await _capture("station-assign", true)
	actor.cast_recovery_ticks = 6
	await _capture("active-action", false)
	_attempt_refused(actor, "active action")
	actor.cast_recovery_ticks = 0
	var original_round: PackedInt32Array = game.session_round_values.duplicate()
	var active_round := SessionRound.new()
	active_round.phase = SessionRound.Phase.ACTIVE
	active_round.scores_by_entity = {1: 0, 2: 0}
	game.session_round_values = active_round.capture(game.world)
	_check(SessionRound.validate_packet(game.session_round_values) and int(game._current_round_state().get("phase", -1)) == SessionRound.Phase.ACTIVE, "two-participant round fixture reaches actual ACTIVE admission")
	await _capture("active-round", false)
	_attempt_refused(actor, "active round")
	game.session_round_values = original_round
	if not baseline:
		_key(KEY_HOME)
		var original_weave := actor.spell_wire_ids.duplicate()
		var changed_weave := original_weave.duplicate()
		changed_weave.reverse()
		_check(CharacterWeavePolicy.apply(actor, changed_weave), "stale-preview fixture changes authority after preview opened")
		await _capture("stale-preview", false)
		_attempt_refused(actor, "stale starter preview")
		_check(CharacterWeavePolicy.apply(actor, original_weave), "stale-preview fixture restores original authority")
		_key(KEY_ESCAPE)
	var cooling_slot := -1
	for slot: int in range(actor.spell_wire_ids.size()):
		if actor.spell_wire_ids[slot] not in actor.kit_spell_wire_ids():
			cooling_slot = slot
			break
	var replacement := 0
	for wire: int in CombatTuning.runtime_wire_ids():
		if wire not in actor.spell_wire_ids:
			replacement = wire
			break
	_check(cooling_slot >= 0 and replacement > 0, "cooldown fixture has a nonlegacy spell and outside replacement")
	_click(SpellLoomEditor.slot_rect(cooling_slot).get_center())
	_click(game.spell_loom_editor.spell_rect(game.spell_loom_editor.available_wire_ids.find(replacement)).get_center())
	var cooling_wire: int = actor.spell_wire_ids[cooling_slot]
	actor.set_spell_cooldown(cooling_wire, 7)
	await _capture("cooldown-removal", false)
	_attempt_refused(actor, "cooldown removal")
	actor.set_spell_cooldown(cooling_wire, 0)
	await _capture("cooldown-expired", true)
	# Pending is a fixture, not proof of a live remote host acknowledgement.
	game.pending_weave_request = {"sequence": 700, "actor": actor.entity_id, "champion": actor.champion_wire_id,
		"context": game._weave_session_context(), "wires": actor.spell_wire_ids.duplicate(),
		"deadline_ms": Time.get_ticks_msec() + 5000, "acknowledged": false, "save": false, "mode": CharacterWeaveLibrary.MODE_CUSTOM}
	await _capture("pending", false)
	var pending_before: Dictionary = game.pending_weave_request.duplicate(true)
	_key(KEY_ENTER)
	_check(game.pending_weave_request == pending_before, "pending assignment cannot be replaced")
	_key(KEY_ESCAPE)
	_check(not game.spell_loom_editor.is_open and game.pending_weave_request == pending_before, "pending Escape closes view without revoking request")
	game.pending_weave_request.clear()
	game.spell_loom_editor.open_editor(actor, game.ability_catalog)
	var heavy: int = game.ability_catalog.ability(game.ability_catalog.spell_id_at("water", "heavy")).wire_id
	_click(SpellLoomEditor.slot_rect(0).get_center())
	_click(game.spell_loom_editor.spell_rect(game.spell_loom_editor.available_wire_ids.find(heavy)).get_center())
	var before_flux := actor.flux
	_key(KEY_ENTER)
	_check(game.pending_weave_request.is_empty() and actor.spell_wire_ids[0] == heavy, "eligible selection receives authority confirmation in exact chosen slot")
	_check(actor.flux == before_flux and FileAccess.file_exists(CharacterWeaveLibrary.DEFAULT_PATH), "assignment preserves Flux and saves confirmed weave")
	await _capture("confirmed", true)
	_key(KEY_ESCAPE)
	for unused: int in range(4): game._process(1.0 / 120.0)
	var before_position := actor.position_x
	Input.action_press(&"move_right")
	for unused: int in range(30): game._process(1.0 / 120.0)
	Input.action_release(&"move_right")
	_check(actor.position_x != before_position, "movement resumes after closing Loom")
	before_flux = actor.flux
	Input.action_press(&"spell_1")
	game._process(1.0 / 120.0)
	Input.action_release(&"spell_1")
	_check(actor.pending_cast_wire_id == heavy and actor.flux < before_flux, "newly assigned Water Heavy begins real paid cast through slot input")
	facts.paid_wire = actor.pending_cast_wire_id
	facts.flux_spent = before_flux - actor.flux
	await _finish()


func _capture(label: String, enabled: bool) -> void:
	var actor: PlayerState = game._local_player_state()
	var authority: String = game.world.state_hash()
	var availability := {"enabled": true, "reason": "Legacy UI always paints active assignment controls."}
	var query_samples := PackedInt64Array()
	if not baseline:
		var requested := _requested(actor)
		availability = game._loom_assignment_availability(actor, requested, game.spell_loom_editor.starter_preview_active())
		_check(bool(availability.enabled) == enabled, label + " availability matches existing admission")
		if not enabled: _check(not String(availability.reason).is_empty(), label + " supplies a reason")
		# Modal-policy cost only. This excludes rendering, request transport and
		# gameplay simulation, and cannot establish a frame-rate improvement.
		for unused: int in range(128):
			var start := Time.get_ticks_usec()
			game._loom_assignment_availability(actor, requested, game.spell_loom_editor.starter_preview_active())
			query_samples.append(Time.get_ticks_usec() - start)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	_check(picture.save_png(output.path_join(label + ".png")) == OK, label + " saves native frame")
	_check(game.world.state_hash() == authority, label + " query and rendering preserve world authority")
	frames.append({"label":label, "expected_enabled":enabled, "availability":availability,
		"status":game.spell_loom_editor.status_message, "authority_hash":authority, "image":label + ".png",
		"modal_query_us": Array(query_samples)})


func _requested(actor: PlayerState) -> PackedInt32Array:
	if game.spell_loom_editor.starter_preview_active():
		return game.spell_loom_editor.request_starter_apply().get("wire_ids", PackedInt32Array())
	var result := actor.spell_wire_ids.duplicate()
	var wire: int = game.spell_loom_editor.selected_wire_id()
	var slot: int = game.spell_loom_editor.selected_slot_index
	var existing := result.find(wire)
	if existing >= 0: result[existing] = result[slot]
	result[slot] = wire
	return result


func _attempt_refused(actor: PlayerState, label: String) -> void:
	var before := actor.canonical_values()
	var sequence: int = game.client_request_sequence
	var events: Array[Dictionary] = game.authoritative_session.pending_combat_events.duplicate(true)
	var saved_before := FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH) if FileAccess.file_exists(CharacterWeaveLibrary.DEFAULT_PATH) else ""
	_key(KEY_ENTER)
	_check(actor.canonical_values() == before and game.pending_weave_request.is_empty(), label + " leaves authority and pending unchanged")
	_check(game.client_request_sequence == sequence + (1 if baseline else 0), label + (" reproduces legacy rejected request" if baseline else " sends no unavailable request"))
	if baseline:
		var last: Dictionary = game.authoritative_session.pending_combat_events.back()
		_check(String(last.get("type", "")) == "request_refused" and int(last.get("sequence", 0)) == sequence + 1, label + " observes the matching authority refusal event")
	else:
		_check(game.authoritative_session.pending_combat_events == events, label + " emits no authority event")
	var saved_after := FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH) if FileAccess.file_exists(CharacterWeaveLibrary.DEFAULT_PATH) else ""
	_check(saved_before == saved_after, label + " does not create or rewrite the saved weave")


func _place(station: String) -> void:
	var point: Array = game.campus_layout.stations_by_id[station].position
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
	checks.append({"passed":condition, "message":message})
	if not condition: failures.append(message)


func _finish() -> void:
	facts.merge({"passed":failures.is_empty(), "checks":checks, "failures":failures, "frames":frames}, true)
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(facts, "\t") + "\n")
	file.close()
	print("LOOM_AVAILABILITY ", checks.size(), " checks / ", failures.size(), " failures / ", frames.size(), " native frames")
	for failure: String in failures: print("FAILED: ", failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

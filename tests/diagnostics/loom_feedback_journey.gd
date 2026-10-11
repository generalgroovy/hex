extends "res://tests/diagnostics/loom_availability_journey.gd"
## Native owner-run feedback regression. Never use the player's real profile.


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or not OS.get_user_data_dir().replace("\\", "/").contains("/hex-probe-"):
		push_error("Native backend, fresh absolute output and wrapper-isolated profile required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	facts = {"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string("res://content/runtime/runtime_build_identity_v1.json")),
		"fixture": "Actual offline assignments and production save-failure reporting; local coordinator configured=false injects rejection without disk damage. Starter pending envelope and refusal are arranged, then production acknowledgement/timeout paths run. After timeout an authoritative weave change is arranged through the pure policy before actual Escape closes the comparison. Unsent outcome is a presentation fixture, not a network transport test. Station position and window sizes are arranged; UI events are synthetic.",
		"not_run": ["physical input", "network transport/lifecycle", "real disk failure", "human feel"], "user_data": OS.get_user_data_dir()}
	game = Bootstrap.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for unused: int in range(4): game._process(1.0 / 120.0)
	_place("spell-loom")
	var actor: PlayerState = game._local_player_state()
	var editor: SpellLoomEditor = game.spell_loom_editor
	editor.open_editor(actor, game.ability_catalog)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		editor.cancel_starter_preview(false)
		editor.selected_slot_index = 0
		editor.selected_spell_index = editor.available_wire_ids.find(actor.spell_wire_ids[1])
		var requested := editor.requested_wire_ids(actor)
		_key(KEY_ENTER)
		_check(actor.spell_wire_ids == requested and game.pending_weave_request.is_empty(), "ordinary assignment reaches authority " + suffix)
		await _capture_feedback("confirmed-" + suffix, false, "Twelve spell positions applied.")
		var stored_before := FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH)
		var configured: bool = game.character_weaves.configured
		game.character_weaves.configured = false
		editor.selected_spell_index = editor.available_wire_ids.find(actor.spell_wire_ids[1])
		requested = editor.requested_wire_ids(actor)
		_key(KEY_ENTER)
		game.character_weaves.configured = configured
		_check(actor.spell_wire_ids == requested, "local save rejection retains accepted assignment " + suffix)
		_check(FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH) == stored_before, "failed local save preserves existing file " + suffix)
		await _capture_feedback("save-failed-" + suffix, false, "saved file could not be updated")
		for outcome: String in ["refused", "timeout", "unsent"]:
			editor.cancel_starter_preview(false)
			_check(editor.prepare_starter_preview(actor, game.champion_catalog, game.ability_catalog), "starter comparison opens " + outcome)
			editor.starter_preview.notice = "Apply sent. Waiting for authority; this request can no longer be cancelled."
			var authority := actor.canonical_values()
			if outcome == "unsent":
				editor.complete_starter_apply(false)
				editor.status_message = "Request could not be sent. Your current weave is unchanged."
			else:
				game.pending_weave_request = {"sequence": 700, "actor": actor.entity_id, "champion": actor.champion_wire_id, "context": game._weave_session_context(), "wires": editor.request_starter_apply().wire_ids, "deadline_ms": 0, "acknowledged": false, "save": false, "mode": CharacterWeaveLibrary.MODE_STARTER}
				if outcome == "timeout": game._complete_pending_weave()
				else:
					var refusal_feedback: Array[Dictionary] = [{"type": "request_refused", "entity_id": actor.entity_id, "action": SessionTransport.REQUEST_WEAVE_APPLY, "sequence": 700, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE}]
					game._ingest_session_feedback(refusal_feedback)
			_check(actor.canonical_values() == authority and game.pending_weave_request.is_empty(), outcome + " presentation preserves authority and clears pending")
			_check(not String(editor.starter_preview.notice).contains("Waiting for authority") and not String(editor.starter_preview.notice).contains("no longer be cancelled"), outcome + " has no stale pending notice")
			await _capture_feedback("starter-" + outcome + "-" + suffix, true, "timed out" if outcome == "timeout" else ("could not be sent" if outcome == "unsent" else "previous weave remains usable"))
			if outcome == "timeout":
				var late_wires := actor.spell_wire_ids.duplicate()
				var first_wire := late_wires[0]
				late_wires[0] = late_wires[1]
				late_wires[1] = first_wire
				_check(CharacterWeavePolicy.apply(actor, late_wires), "arranged late authority changes weave before timeout cancellation " + suffix)
			var before_close := actor.canonical_values()
			var sequence_before: int = game.client_request_sequence
			var saved_before_close := FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH)
			_key(KEY_ESCAPE)
			_check(not editor.starter_preview_active() and editor.is_open, outcome + " cancel closes comparison only " + suffix)
			_check(editor.status_message == "Starter preview closed. No new request was sent.", outcome + " cancel makes only a local action claim " + suffix)
			_check(actor.canonical_values() == before_close and game.pending_weave_request.is_empty(), outcome + " cancel neither rolls back authority nor creates pending work " + suffix)
			_check(game.client_request_sequence == sequence_before and FileAccess.get_sha256(CharacterWeaveLibrary.DEFAULT_PATH) == saved_before_close, outcome + " cancel sends no new request and preserves the saved file " + suffix)
			if outcome == "timeout":
				await _capture_feedback("starter-timeout-closed-" + suffix, true, "No new request was sent.")
	await _finish()


func _capture_feedback(label: String, enabled: bool, expected: String) -> void:
	var actor: PlayerState = game._local_player_state()
	var availability: Dictionary = game._loom_assignment_availability(actor, game._loom_presented_request(actor), game.spell_loom_editor.starter_preview_active())
	var lines := SpellLoomPresenter.feedback_lines(game.spell_loom_editor, availability, game.spell_loom_editor.starter_preview_active())
	_check(not lines.is_empty() and String(lines[0].text).contains(expected), label + " actual renderer projection exposes expected outcome")
	await _capture(label, enabled)
	frames.back()["visible_feedback"] = lines

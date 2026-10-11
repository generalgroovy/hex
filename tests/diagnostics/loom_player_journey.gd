extends SceneTree

# Runs the actual Bootstrap from source or a mounted preserved PCK. Only the
# starting location is arranged; all assignment goes through ordinary UI events.
const Bootstrap = preload("res://src/app/bootstrap.gd")
var game: Node
var output: String
var facts: Dictionary = {}
var resume: String = ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--resume="): resume = argument.trim_prefix("--resume=")
	game = Bootstrap.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var actor: PlayerState = game._local_player_state()
	if not resume.is_empty():
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resume))
		facts = {"restored_wires": Array(actor.spell_wire_ids), "expected_wires": previous.applied_wires,
			"passed": actor.spell_wire_ids == PackedInt32Array(previous.applied_wires), "separate_process_restart": true}
		await _finish()
		return
	var position: Array = game.campus_layout.stations_by_id["spell-loom"].position
	actor.position_x = int(position[0]) * 1000
	actor.position_y = (int(position[1]) + 48) * 1000
	game._update_station_focus()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for frame: int in 3: game._process(1.0 / 120.0)
	facts = {"transport_id": game.session_transport.local_entity_id, "actor_id": actor.entity_id,
		"initial_wires": Array(actor.spell_wire_ids), "starting_position_arranged": true,
		"focused_station": game.focused_station_id, "blocked_before": game._gameplay_input_blocked()}
	Input.action_press(&"interact")
	game._process(1.0 / 120.0)
	Input.action_release(&"interact")
	await process_frame
	facts.opened_by_interact = game.spell_loom_editor.is_open
	_key(KEY_RIGHT)
	_key(KEY_ENTER)
	facts.applied_wires = Array(actor.spell_wire_ids)
	facts.pending_after_apply = not game.pending_weave_request.is_empty()
	facts.feedback = game.spell_loom_editor.status_message
	_key(KEY_ESCAPE)
	facts.closed_by_escape = not game.spell_loom_editor.is_open
	game.queue_redraw()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + ".png")
	facts.passed = facts.opened_by_interact and not facts.pending_after_apply and facts.closed_by_escape
	if facts.passed:
		for frame: int in 4: game._process(1.0 / 120.0)
		var before_x := actor.position_x
		Input.action_press(&"move_right")
		for frame: int in 30: game._process(1.0 / 120.0)
		Input.action_release(&"move_right")
		facts.moved_after_close = actor.position_x != before_x
		var flux_before := actor.flux
		Input.action_press(&"spell_1")
		game._process(1.0 / 120.0)
		Input.action_release(&"spell_1")
		facts.cast_wire = actor.pending_cast_wire_id
		facts.flux_spent = flux_before - actor.flux
		facts.paid_cast_after_close = facts.flux_spent > 0 and actor.pending_cast_wire_id == actor.spell_wire_ids[0]
		facts.saved_file = FileAccess.file_exists(CharacterWeaveLibrary.DEFAULT_PATH)
		facts.passed = facts.passed and facts.moved_after_close and facts.paid_cast_after_close and facts.saved_file
	await _finish()

func _finish() -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(facts, "  "))
	file.close()
	print("LOOM_JOURNEY " + JSON.stringify(facts))
	game.queue_free()
	await process_frame
	quit(0 if facts.passed else 1)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)

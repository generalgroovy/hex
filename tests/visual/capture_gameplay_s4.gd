extends SceneTree


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const CAPTURE_SIZE := Vector2i(1280, 720)
const CASES: Array[String] = [
	"loom-before",
	"loom-preview",
	"loom-preview-quarantined",
	"loom-applied",
	"controls-defaults",
	"controls-migration-notice",
]

var output := ""
var viewport: SubViewport
var node: Node2D
var frames: Array[Dictionary] = []
var original_custom_weave := PackedInt32Array()
var proposed_starter_weave := PackedInt32Array()
var preview_world_hash := ""
var migration_messages: Array[String] = []


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/gameplay-s4-ui-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh gameplay-s4-ui output directory")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot configure the inherited actual-game draw fixture")
		return
	viewport = SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	node.visual_accessibility_filter = VisualAccessibilityFilter.new()
	node.add_child(node.visual_accessibility_filter)
	node.preference_overrides_are_transient = true
	node.preferences_persistence_allowed = false
	node.session_transport.local_entity_id = SessionTransport.SERVER_PEER_ID
	node.character_weaves.champions = node.champion_catalog
	node.character_weaves.abilities = node.ability_catalog
	node.character_weaves.configured = true
	node.character_weaves.persistence_allowed = false
	if not _prepare_custom_weave():
		return
	for case_name: String in CASES:
		if not await _prepare_and_capture(case_name):
			return
	if not _write_receipt():
		return
	print("PASS: %d actual-game S4 UI frames; Loom authority, migration notice and modal quarantine asserted" % frames.size())
	quit(0)


func _prepare_custom_weave() -> bool:
	var actor: PlayerState = node.world.player()
	var station: Dictionary = node.campus_layout.stations_by_id.get("spell-loom", {})
	var authored_position: Array = station.get("position", [])
	if actor == null or authored_position.size() != 2:
		fail("Spell Loom fixture actor or station is unavailable")
		return false
	actor.position_x = int(authored_position[0]) * SimConfig.FIXED_SCALE
	actor.position_y = int(authored_position[1]) * SimConfig.FIXED_SCALE
	node.previous_position = Vector2(actor.position_x, actor.position_y) / float(SimConfig.FIXED_SCALE)
	node.current_position = node.previous_position
	node.actor_motion_history.clear()
	var custom := actor.spell_wire_ids.duplicate()
	custom.reverse()
	if custom == actor.spell_wire_ids or not CharacterWeavePolicy.apply(actor, custom):
		fail("Cannot prepare a valid custom weave through the authoritative weave policy")
		return false
	original_custom_weave = actor.spell_wire_ids.duplicate()
	if original_custom_weave.size() != PlayerState.SPELL_SLOT_COUNT or not actor.has_valid_spell_slots():
		fail("Prepared custom weave does not preserve twelve valid slots")
		return false
	return true


func _prepare_and_capture(case_name: String) -> bool:
	match case_name:
		"loom-before":
			if not _open_loom_before(): return false
		"loom-preview":
			if not _open_starter_preview(): return false
		"loom-preview-quarantined":
			if not _prove_preview_quarantine(): return false
		"loom-applied":
			if not _apply_starter_through_input(): return false
		"controls-defaults":
			if not _show_control_defaults(): return false
		"controls-migration-notice":
			if not _show_control_migration_notice(): return false
		_:
			fail("Unknown S4 capture case: " + case_name)
			return false
	return await capture(case_name)


func _open_loom_before() -> bool:
	node.controls_editor.close_editor()
	node.spell_loom_editor.open_editor(node.world.player(), node.ability_catalog)
	node.controls_input_guard_frames = 2
	if not node.spell_loom_editor.is_open or node.spell_loom_editor.starter_preview_active():
		fail("Loom did not open at the first-stage editor")
		return false
	if node.world.player().spell_wire_ids != original_custom_weave:
		fail("Opening the Loom changed the custom weave")
		return false
	return true


func _open_starter_preview() -> bool:
	var before_hash: String = node.world.state_hash()
	var before_wires: PackedInt32Array = node.world.player().spell_wire_ids.duplicate()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = SpellLoomEditor.STARTER_BUTTON_RECT.get_center()
	node._handle_spell_loom_input(click)
	if not node.spell_loom_editor.starter_preview_active():
		fail("Starter button did not open the production preview")
		return false
	var rows_value: Variant = node.spell_loom_editor.starter_preview.get("rows", [])
	var after_value: Variant = node.spell_loom_editor.starter_preview.get("after_wire_ids", PackedInt32Array())
	if not rows_value is Array or not after_value is PackedInt32Array:
		fail("Starter preview does not expose typed comparison rows and wires")
		return false
	var rows: Array = rows_value
	proposed_starter_weave = (after_value as PackedInt32Array).duplicate()
	if rows.size() != PlayerState.SPELL_SLOT_COUNT or proposed_starter_weave.size() != PlayerState.SPELL_SLOT_COUNT:
		fail("Starter preview does not expose all twelve slots")
		return false
	var supported_rows := 0
	var pending_rows := 0
	for slot: int in range(rows.size()):
		if not rows[slot] is Dictionary:
			fail("Starter preview contains a malformed row")
			return false
		var row: Dictionary = rows[slot]
		if int(row.get("slot_index", -1)) != slot or String(row.get("slot_label", "")) != PlayerState.spell_slot_label(slot):
			fail("Starter preview row lost its slot identity")
			return false
		var element := String(row.get("after_element", ""))
		var supported := element in ["water", "fire"]
		if bool(row.get("court_supported", false)) != supported:
			fail("Starter preview court-support tag is inaccurate")
			return false
		if supported:
			supported_rows += 1
		else:
			pending_rows += 1
	if supported_rows <= 0 or pending_rows <= 0:
		fail("Starter preview must visibly distinguish supported and pending Hex effects")
		return false
	if node.world.state_hash() != before_hash or node.world.player().spell_wire_ids != before_wires:
		fail("Preview mutated authority before Apply")
		return false
	preview_world_hash = before_hash
	return true


func _prove_preview_quarantine() -> bool:
	var editor: SpellLoomEditor = node.spell_loom_editor
	var before_hash: String = node.world.state_hash()
	var before_wires: PackedInt32Array = node.world.player().spell_wire_ids.duplicate()
	var before_preview := editor.starter_preview.duplicate(true)
	var before_slot := editor.selected_slot_index
	var before_spell := editor.selected_spell_index
	var ordinary_navigation := InputEventKey.new()
	ordinary_navigation.keycode = KEY_RIGHT
	ordinary_navigation.physical_keycode = KEY_RIGHT
	ordinary_navigation.pressed = true
	node._handle_spell_loom_input(ordinary_navigation)
	if node.controls_input_guard_frames != 2 or not node._gameplay_input_blocked():
		fail("Preview input did not arm the production modal guard")
		return false
	var neutral: SimCommand = node._sample_gameplay_command(
		node.world.tick,
		Vector2(node.world.player().position_x, node.world.player().position_y) / float(SimConfig.FIXED_SCALE),
		Vector2.RIGHT,
		node._gameplay_input_blocked(),
	)
	if neutral.move_x != 0 or neutral.move_y != 0 or neutral.held_actions != 0 or neutral.pressed_actions != 0:
		fail("Modal preview allowed a gameplay command")
		return false
	if editor.selected_slot_index != before_slot or editor.selected_spell_index != before_spell \
			or editor.starter_preview != before_preview or node.world.player().spell_wire_ids != before_wires \
			or node.world.state_hash() != before_hash:
		fail("Quarantined preview input changed UI selection or authority")
		return false
	for action: StringName in [InputRouter.PUNCH_ACTION, InputRouter.KICK_ACTION]:
		Input.action_release(action)
		Input.action_press(action)
		node.input_router.discard_transient_movement_input()
		if not node.input_router.quarantined_actions.has(action):
			Input.action_release(action)
			fail("Held melee input was not quarantined: %s" % action)
			return false
		var command: SimCommand = node.input_router.sample(node.world.tick, Vector2.ZERO, Vector2.RIGHT)
		if command.held_actions != 0 or command.pressed_actions != 0:
			Input.action_release(action)
			fail("S4 melee intent leaked an unowned wire bit while quarantined: %s" % action)
			return false
		Input.action_release(action)
		node.input_router.observe_input_event(_mouse_release_for(action))
		node.input_router.sample(node.world.tick, Vector2.ZERO, Vector2.RIGHT)
		if node.input_router.quarantined_actions.has(action):
			fail("Melee quarantine did not clear after release: %s" % action)
			return false
	return true


func _mouse_release_for(action: StringName) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT if action == InputRouter.PUNCH_ACTION else MOUSE_BUTTON_RIGHT
	event.pressed = false
	return event


func _apply_starter_through_input() -> bool:
	if not node.spell_loom_editor.starter_preview_active() or proposed_starter_weave.is_empty():
		fail("Apply requires the retained preview")
		return false
	var apply := InputEventKey.new()
	apply.keycode = KEY_ENTER
	apply.physical_keycode = KEY_ENTER
	apply.pressed = true
	node._handle_spell_loom_input(apply)
	if not node.pending_weave_request.is_empty() or node.spell_loom_editor.starter_preview_active():
		fail("Offline authority did not acknowledge and close the applied preview")
		return false
	if node.world.player().spell_wire_ids != proposed_starter_weave or node.world.player().spell_wire_ids == original_custom_weave:
		fail("Apply did not atomically replace all twelve authoritative slots")
		return false
	if not node.world.player().has_valid_spell_slots() or not node.spell_loom_editor.status_message.contains("applied"):
		fail("Applied starter weave or confirmation status is invalid")
		return false
	return true


func _show_control_defaults() -> bool:
	node.spell_loom_editor.close_editor()
	var preferences := PlayerPreferences.new()
	if int(preferences.keyboard_bindings.get(&"evade", 0)) != KEY_B \
			or int(preferences.keyboard_bindings.get(&"punch", -1)) != 0 \
			or int(preferences.keyboard_bindings.get(&"kick", -1)) != 0 \
			or int(preferences.mouse_bindings.get(&"punch", 0)) != MOUSE_BUTTON_LEFT \
			or int(preferences.mouse_bindings.get(&"kick", 0)) != MOUSE_BUTTON_RIGHT \
			or int(preferences.mouse_bindings.get(&"primary", -1)) != 0 \
			or int(preferences.mouse_bindings.get(&"active_1", -1)) != 0:
		fail("Fresh S4 control defaults do not match the dedicated melee layout")
		return false
	node.player_preferences = preferences
	node.controls_editor = ControlBindingEditor.new()
	node.controls_editor.set_migration_notices(preferences.migration_notices)
	node.controls_editor.open_editor()
	node.controls_editor.selected_device = ControlBindingEditor.DEVICE_MOUSE
	node.controls_editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"punch")
	node.controls_editor.first_visible_row = maxi(0, node.controls_editor.selected_action_index - 5)
	if node.controls_editor.binding_label(&"punch", ControlBindingEditor.DEVICE_MOUSE, preferences) != "LEFT BUTTON" \
			or node.controls_editor.binding_label(&"kick", ControlBindingEditor.DEVICE_MOUSE, preferences) != "RIGHT BUTTON":
		fail("Controls Lectern labels disagree with the fresh mouse defaults")
		return false
	return true


func _show_control_migration_notice() -> bool:
	var migrated := PlayerPreferences.new()
	var legacy := migrated.to_dictionary()
	var custom_keyboard := PlayerPreferences.S4_PREVIOUS_DEFAULT_KEYBOARD_BINDINGS.duplicate()
	custom_keyboard[&"emote"] = KEY_B
	var custom_mouse := PlayerPreferences.S4_PREVIOUS_DEFAULT_MOUSE_BINDINGS.duplicate()
	custom_mouse[&"jump"] = MOUSE_BUTTON_MIDDLE
	legacy["keyboard_defaults_revision"] = 1
	legacy["mouse_defaults_revision"] = 0
	legacy["keyboard_bindings"] = custom_keyboard
	legacy["mouse_bindings"] = custom_mouse
	if not migrated.apply_dictionary(legacy):
		fail("Customized pre-S4 controls could not migrate: " + migrated.last_error)
		return false
	migration_messages.clear()
	var notice_codes: Dictionary[String, bool] = {}
	var selected_conflict_message := ""
	for notice: Dictionary in migrated.migration_notices:
		migration_messages.append(String(notice.get("message", "")))
		var code := String(notice.get("code", ""))
		notice_codes[code] = true
		if code == "mouse_binding_conflict_preserved" and notice.get("action") == &"punch":
			selected_conflict_message = String(notice.get("message", ""))
	for expected_code: String in ["custom_keyboard_preserved", "evade_b_conflict_preserved", "custom_mouse_preserved", "mouse_binding_conflict_preserved"]:
		if not notice_codes.has(expected_code):
			fail("Customized migration omitted notice: " + expected_code)
			return false
	if selected_conflict_message.is_empty():
		fail("Customized migration omitted the Punch mouse-conflict notice")
		return false
	if int(migrated.keyboard_bindings.get(&"evade", 0)) != KEY_Q \
			or int(migrated.keyboard_bindings.get(&"emote", 0)) != KEY_B \
			or int(migrated.keyboard_bindings.get(&"punch", -1)) != 0 \
			or int(migrated.mouse_bindings.get(&"punch", -1)) != 0 \
			or int(migrated.mouse_bindings.get(&"kick", -1)) != 0 \
			or int(migrated.mouse_bindings.get(&"primary", 0)) != MOUSE_BUTTON_LEFT \
			or int(migrated.mouse_bindings.get(&"active_1", 0)) != MOUSE_BUTTON_RIGHT:
		fail("Customized migration changed a preserved owner or assigned melee over it")
		return false
	node.player_preferences = migrated
	node.controls_editor = ControlBindingEditor.new()
	node.controls_editor.selected_device = ControlBindingEditor.DEVICE_MOUSE
	node.controls_editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"punch")
	node.controls_editor.first_visible_row = maxi(0, node.controls_editor.selected_action_index - 5)
	node.controls_editor.set_migration_notices(migrated.migration_notices)
	node.controls_editor.open_editor()
	if node.controls_editor.selected_migration_notice() != "Migration: " + selected_conflict_message:
		fail("Controls Lectern did not select the affected Punch conflict notice")
		return false
	return true


func capture(case_name: String) -> bool:
	var before_hash: String = node.world.state_hash()
	var before_wires: PackedInt32Array = node.world.player().spell_wire_ids.duplicate()
	node.requested_capture_reduced_effects = false
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	var filename := case_name + "-1280x720.png"
	if pixels == null or pixels.get_size() != CAPTURE_SIZE or pixels.save_png(output.path_join(filename)) != OK:
		fail("S4 UI readback failed: " + filename)
		return false
	if node.world.state_hash() != before_hash or node.world.player().spell_wire_ids != before_wires:
		fail("Drawing mutated authority: " + filename)
		return false
	frames.append({
		"file": filename,
		"case": case_name,
		"size": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"world_hash": before_hash,
		"world_hash_unchanged": true,
		"weave": Array(before_wires),
		"preview_active": node.spell_loom_editor.starter_preview_active(),
		"controls_open": node.controls_editor.is_open,
		"status": node.controls_editor.status_message if node.controls_editor.is_open else node.spell_loom_editor.status_message,
	})
	print("RENDERED ", output.path_join(filename))
	return true


func _write_receipt() -> bool:
	var source_paths: Array[String] = [
		"res://src/app/bootstrap.gd",
		"res://src/app/player_preferences.gd",
		"res://src/app/control_binding_editor.gd",
		"res://src/app/input_router.gd",
		"res://src/app/spell_loom_editor.gd",
		"res://src/content/character_starter_kit.gd",
		"res://src/presentation/spell_loom_presenter.gd",
		"res://tests/support/chemistry_coach_harness.gd",
		"res://tests/visual/capture_gameplay_s4.gd",
	]
	var hashes := {}
	for path: String in source_paths:
		hashes[path] = FileAccess.get_sha256(path)
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Cannot retain S4 UI capture evidence")
		return false
	receipt.store_string(JSON.stringify({
		"schema_version": 1,
		"frames": frames,
		"source_hashes": hashes,
		"loom": {
			"custom_before": Array(original_custom_weave),
			"preview_proposal": Array(proposed_starter_weave),
			"authority_hash_before_preview": preview_world_hash,
			"preview_and_quarantined_input_preserved_authority": true,
			"apply_used_production_input_and_authority_paths": true,
		},
		"controls": {
			"fresh_evade_key": KEY_B,
			"fresh_punch_mouse": MOUSE_BUTTON_LEFT,
			"fresh_kick_mouse": MOUSE_BUTTON_RIGHT,
			"migration_messages": migration_messages,
			"punch_and_kick_modal_quarantine_checked": true,
			"s4_assigns_no_melee_command_bits": true,
		},
		"method": "Inherited production game draw; actual Spell Loom input and offline authority; transient exact-default migration; no sockets or persistent preferences",
		"network": "not_started",
		"preferences": "transient_fixture_only",
		"human_acceptance": "not_run",
		"authority_unchanged_by_every_draw": true,
	}, "  "))
	receipt.close()
	return true


func fail(message: String) -> void:
	for action: StringName in [InputRouter.PUNCH_ACTION, InputRouter.KICK_ACTION]:
		Input.action_release(action)
	push_error(message)
	quit(1)

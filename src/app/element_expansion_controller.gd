extends RefCounted
## Local teaching and practice orchestration; simulation remains authoritative.

const Progression = preload("res://src/app/signature_progression.gd")
const Challenge = preload("res://src/app/signature_challenge_session.gd")
const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const RangeSession = preload("res://src/app/spell_training_range.gd")
const Developer = preload("res://src/app/developer_testing_session.gd")
const TestingPanelScript = preload("res://src/presentation/spell_testing_panel.gd")
const Introduction = preload("res://src/app/optional_introduction.gd")
const ENTRIES := [
	["expansion-introduction", "INTRODUCTION", "Learn by doing; skip at any time", KEY_F5, false],
	["expansion-range", "SPELL RANGE", "Try every element and delivery", KEY_F6, false],
	["expansion-challenges", "SIGNATURE CHALLENGES", "Defeat a rival; learn their spell", KEY_F6, true],
	["expansion-developer", "DEVELOPER TOOLS", "Offline testing; session-only overrides", KEY_F5, true],
]
var game
var progression := Progression.new()
var challenge := Challenge.new()
var training := RangeSession.new()
var developer := Developer.new()
var panel := TestingPanelScript.new()
var developer_weave := RangeSession.new()
var configured := false
var challenge_active := false
var guide := Introduction.new()
var notice := ""
var _last_reward := ""


func configure(owner: Node) -> bool:
	game = owner
	configured = progression.configure(game.champion_catalog, game.ability_catalog, Progression.DEFAULT_PATH, game.preferences_persistence_allowed and not game.preference_overrides_are_transient)
	# Existing valid saved weaves retain access; practice never enters this import.
	for saved: Dictionary in game.character_weaves.library.weaves_by_champion.values():
		progression.preserve_existing(PackedInt32Array(saved.get("wire_ids", [])))
	if not configured: notice = progression.last_error
	return configured


func offline() -> bool:
	return game != null and game.session_transport != null and game.session_transport.mode == SessionTransport.Mode.OFFLINE


func temporary_session() -> bool:
	return training.active or developer.active or challenge_active


func blocks_gameplay() -> bool:
	return panel.is_open or (challenge_active and challenge.trial.blocks_gameplay())


func can_equip(wire: int) -> bool:
	return progression.can_equip(wire, offline() and (training.active or developer.all_spells_enabled()))


func allows_weave(wires: PackedInt32Array) -> bool:
	for wire: int in wires:
		if not can_equip(wire): return false
	return true


func refresh_loom() -> void:
	if game == null or game.world == null: return
	if game.spell_loom_editor == null: return
	game.spell_loom_editor.blocked_reason_by_wire.clear()
	for row: Dictionary in Challenges.rows(game.champion_catalog, game.ability_catalog):
		if not can_equip(int(row.signature_wire)):
			game.spell_loom_editor.blocked_reason_by_wire[int(row.signature_wire)] = "Defeat %s in Signature Challenges to learn this spell. Try it freely in the Range." % String(row.name)


func before_transition() -> void:
	# Called before any old actor can be copied into a normal saved/session weave.
	if game != null and game.world != null:
		var actor: PlayerState = game._local_player_state()
		if training.active: training.restore(actor, game.world.tick)
		if developer_weave.active: developer_weave.restore(actor, game.world.tick)
	training.close()
	developer_weave.close()
	developer.leave()
	challenge.reset()
	challenge_active = false
	panel.close()
	if guide != null: guide.stop()


func before_step() -> void:
	if game == null or game.world == null: return
	if developer.active: developer.apply_continuous(game.world, offline(), true)


func prepare_character_change() -> bool:
	if game == null or game.world == null: return false
	var resume_range := training.active
	var actor: PlayerState = game._local_player_state()
	if training.active: training.restore(actor, game.world.tick)
	if developer_weave.active: developer_weave.restore(actor, game.world.tick)
	developer.leave()
	return resume_range


func finish_character_change(resume_range: bool) -> void:
	if game == null or game.world == null: return
	if resume_range: training.begin(game._local_player_state(), offline(), game.world.tick)
	refresh_loom()


func after_step() -> void:
	if game == null or game.world == null: return
	if challenge_active:
		challenge.observe(game.world, progression, offline(), developer.active)
		if not challenge.reward.is_empty():
			var text := String(challenge.reward.get("notice", ""))
			if text != _last_reward:
				_last_reward = text
				show_notice(text)
	if guide != null: guide.observe(game.world, game.world.combat_events, {"range": training.active, "panel_open": panel.is_open, "developer": developer.active})


func rival_command() -> SimCommand:
	if game == null or game.world == null: return null
	if not challenge_active or developer.freezes_rival(): return null
	return challenge.command(game.world)


func activate(id: String) -> bool:
	if not offline():
		show_notice("Leave the online session to open local practice tools.")
		return false
	_close_other_panels()
	match id:
		"expansion-range":
			var continue_lesson := bool(guide.view().get("active", false)) and guide.step >= 4
			if not training.active:
				if not game._start_hex_court(): return false
				if not training.begin(game._local_player_state(), true, game.world.tick): return false
				if continue_lesson: guide.rebind(game.world)
			panel.open_range(game.ability_catalog, training.selected_mask, training.selected_family)
		"expansion-challenges":
			panel.open_challenges(game.champion_catalog, game.ability_catalog, progression)
		"expansion-developer":
			# Modal actions can happen between ticks; taint immediately, so entering,
			# applying a one-shot tool and leaving before the next step cannot earn.
			if challenge_active: challenge.tainted = true
			if not developer.active:
				if not developer.enter(true, true): return false
				if not training.active: developer_weave.begin(game._local_player_state(), true, game.world.tick)
			panel.open_developer(developer.view())
		"expansion-introduction":
			start_introduction()
		_:
			return false
	_handoff()
	return true


func start_introduction() -> void:
	# The optional guide is configured by Bootstrap once its content is loaded.
	if guide == null: return
	if training.active or challenge_active or developer.active:
		game._start_match(game.tick_rate)
	var bindings := ControlBindingEditor.new()
	var preferences: PlayerPreferences = game.player_preferences
	var moves: Array[String] = []
	for direction: String in ["move_up", "move_left", "move_down", "move_right"]:
		moves.append(bindings.binding_label(StringName(direction), ControlBindingEditor.DEVICE_KEYBOARD, preferences))
	guide.configure_bindings({"move": "/".join(moves), "jump": bindings.binding_label(&"jump", ControlBindingEditor.DEVICE_KEYBOARD, preferences), "cast": SpellLoomPresenter.slot_binding_label(0, preferences)})
	guide.start(game.world)
	show_notice("Introduction started. F5 or the Skip button ends it at any time.")


func handle_input(event: InputEvent) -> bool:
	# Bootstrap can receive lifecycle/input callbacks before its world exists.
	# Local tools must not consume input or mutate a session before that handoff.
	if game == null or game.world == null: return false
	if panel.is_open:
		var transformed := event
		if event is InputEventMouse:
			transformed = event.duplicate()
			transformed.position = event.position / game._ui_scale()
		var action := panel.handle_input(transformed, game.get_viewport_rect().size / game._ui_scale())
		_apply_panel_action(action)
		_handoff()
		return true
	if game.controls_editor != null and game.controls_editor.is_open: return false
	if game._directory_child_open() or game.service_directory.is_open or game.solo_trial_menu_open: return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		for entry: Array in ENTRIES:
			# A pre-existing custom gameplay binding keeps priority over convenience keys.
			if key == int(entry[3]) and event.shift_pressed == bool(entry[4]) and not game.player_preferences.keyboard_bindings.values().has(key):
				if String(entry[0]) == "expansion-introduction" and guide != null and bool(guide.view().get("active", false)): guide.stop()
				else: activate(String(entry[0]))
				return true
		if challenge_active and key == KEY_ESCAPE:
			game._start_match(game.tick_rate)
			return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK and challenge_active:
		game._start_match(game.tick_rate)
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var viewport: Vector2 = game.get_viewport_rect().size / game._ui_scale()
		var point: Vector2 = event.position / game._ui_scale()
		if guide.active and guide.skip_rect(viewport, ThemeDB.fallback_font).has_point(point):
			guide.stop()
			return true
		if entry_buttons_visible():
			for index: int in ENTRIES.size():
				if entry_rect(index, viewport).has_point(point):
					activate(String(ENTRIES[index][0]))
					return true
	return false


func _apply_panel_action(action: Dictionary) -> void:
	if action.is_empty(): return
	match String(action.get("action", "")):
		"close": panel.close()
		"introduction":
			panel.close()
			start_introduction()
		"skip_introduction": guide.stop()
		"loaner":
			var request := training.preview(int(action.mask), String(action.family), game.ability_catalog)
			if request.is_empty(): show_notice(training.last_error)
			else:
				var availability: Dictionary = game._loom_assignment_availability(game._local_player_state(), request.wire_ids)
				if not bool(availability.get("enabled", false)):
					show_notice(String(availability.get("reason", "This loaner is unavailable right now.")))
					return
				game._submit_whole_weave(game._local_player_state(), request.expected_wire_ids, request.wire_ids, CharacterWeaveLibrary.MODE_CUSTOM, false)
				if game._local_player_state().spell_wire_ids == request.wire_ids:
					panel.close()
					show_notice(String(request.notice) + " " + String(request.warning))
		"challenge":
			start_challenge(String(action.challenge_id))
		"toggle":
			developer.set_toggle(String(action.id), bool(action.enabled))
			panel.update_developer(developer.view())
			refresh_loom()
		"leave_developer":
			if developer_weave.active: developer_weave.restore(game._local_player_state(), game.world.tick)
			developer.leave()
			panel.close()
			refresh_loom()
		"refill", "reset_cooldowns", "reset_targets", "clear_shots":
			if challenge_active: challenge.tainted = true
			if training.active: Developer.apply_practice_action(String(action.action), game.world, offline(), true)
			elif developer.active: developer.apply(String(action.action), game.world, offline(), true)
			show_notice("Practice tool applied: " + String(action.action).replace("_", " "))


func start_challenge(id: String) -> bool:
	if not offline(): return false
	var definition := Challenges.definition(id, game.champion_catalog, game.ability_catalog)
	if definition.is_empty(): return false
	var candidate: SimWorld = game._new_wellspring_world(game.tick_rate)
	if candidate == null: return false
	var setup := InterceptionShowcase.configure(candidate, game.champion_catalog, game.ability_catalog, game.campus_layout)
	var anchors := InterceptionPractice.spawn_contract(game.campus_layout)
	if setup.is_empty() or anchors.is_empty(): return false
	var actor := candidate.player(1)
	var opponent := candidate.player(2)
	if not game.champion_catalog.apply_to_player(actor, game.selected_champion_id): return false
	game.character_weaves.restore_actor(actor, true)
	if not game.champion_catalog.apply_to_player(opponent, id): return false
	if not opponent.place_proven_spell(0, int(definition.signature_wire)): return false
	var prepared := Challenge.new()
	var developer_attempt := developer.active
	if not prepared.begin(candidate, anchors.bounds, definition, true, developer_attempt): return false
	if not game._start_match_world(game.tick_rate, candidate): return false
	challenge = prepared
	challenge_active = true
	_last_reward = ""
	game.interception_practice_setup = setup
	game.interception_practice_active = true
	game.solo_trial = challenge.trial
	game.authoritative_session.hearth.connect_entity(2)
	game.session_names_by_entity[2] = String(definition.name)
	if game.pov_terrain_backdrop != null: game.pov_terrain_backdrop.set_court_context(SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT)
	show_notice("Defeat %s to learn %s. %s" % [String(definition.name), String(definition.spell_name), String(definition.counter)])
	_handoff()
	return true


func show_notice(text: String) -> void:
	notice = text
	if panel.is_open: panel.set_message(text)
	if game == null: return
	game.station_notice = text
	game.station_notice_seconds = 6.0


func _close_other_panels() -> void:
	game.service_directory.close()
	game.controls_editor.close_editor()
	# Escape cancels a starter preview before closing the Loom; switching tools
	# must deliberately close both layers so two modals cannot remain active.
	game.spell_loom_editor.cancel_starter_preview(false)
	game.spell_loom_editor.close_editor()
	game.player_compendium.close_panel()
	game.character_selection_grid.close_panel()
	game.solo_trial_menu_open = false
	game.hex_playground_open = false


func _handoff() -> void:
	game.controls_input_guard_frames = 2
	if game.input_router != null: game.input_router.discard_transient_movement_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_redraw()


static func entry_rect(index: int, viewport: Vector2) -> Rect2:
	return Rect2(Vector2(viewport.x - 218, 286 + index * 31), Vector2(202, 27))


func entry_buttons_visible() -> bool:
	# The compact Menu owns discovery. Keep this compatibility hit-test hook
	# false so old invisible buttons cannot consume a spell aimed at the world.
	return false


static func challenge_banner_rect(viewport: Vector2) -> Rect2:
	# Reserve the full three-line notice above this card even after it expires,
	# so instructions never overlap it or jump around during the fight.
	var top := 138.0 if viewport.x < 1092.0 else 94.0
	return Rect2(264, top, viewport.x - 528, 82)


func draw(canvas: CanvasItem, font: Font, viewport: Vector2) -> void:
	if not offline(): return
	if panel.is_open:
		panel.draw(canvas, font, viewport)
		return
	if game._directory_child_open() or game.service_directory.is_open or game.solo_trial_menu_open: return
	if entry_buttons_visible():
		for index: int in ENTRIES.size():
			var rect := entry_rect(index, viewport)
			canvas.draw_rect(rect, Color("12242bea"))
			canvas.draw_string(font, rect.position + Vector2(8, 18), String(ENTRIES[index][1]), HORIZONTAL_ALIGNMENT_LEFT, 186, 12, Color("eadfc3"))
	if developer.active and not challenge_active:
		canvas.draw_rect(Rect2(viewport.x - 296, 422, 280, 44), Color("4b2344ee"))
		canvas.draw_string(font, Vector2(viewport.x - 286, 440), "DEV SESSION | no earned progress", HORIZONTAL_ALIGNMENT_LEFT, 264, 13, Color("ffc5e4"))
		canvas.draw_string(font, Vector2(viewport.x - 286, 457), "Shift+F5 opens overrides and Leave Developer", HORIZONTAL_ALIGNMENT_LEFT, 264, 11, Color("eadfc3"))
	elif training.active:
		canvas.draw_string(font, Vector2(viewport.x - 296, 444), "RANGE | F6 change spell · return restores weave", HORIZONTAL_ALIGNMENT_LEFT, 282, 11, Color("77dddc"))
	if challenge_active:
		var status := challenge.status(game.world.tick)
		var text := String(challenge.reward.get("notice", "")) if challenge.trial.is_finished() else String(status.get("cue", ""))
		var box := challenge_banner_rect(viewport)
		var width := box.size.x - 28
		canvas.draw_rect(box, Color("12242bea"))
		canvas.draw_string(font, box.position + Vector2(14, 23), String(challenge.definition.spell_name), HORIZONTAL_ALIGNMENT_LEFT, width, 16, Color("eadfc3"))
		var y := box.position.y + 43
		for line: String in TestingPanelScript._wrap(text, font, 12, width):
			if y > box.position.y + 67: break
			canvas.draw_string(font, Vector2(box.position.x + 14, y), line, HORIZONTAL_ALIGNMENT_LEFT, width, 12, Color("77dddc"))
			y += 16
		var footer := "DEV PRACTICE · Esc: return · Shift+F5: tools" if developer.active else "Esc / Back: return · Shift+F6: rivals · Shift+F5: tools"
		canvas.draw_string(font, box.position + Vector2(14, 76), footer, HORIZONTAL_ALIGNMENT_LEFT, width, 11, Color("b8c1bf"))
	guide.draw(canvas, font, viewport)

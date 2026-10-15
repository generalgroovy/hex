extends RefCounted
## Local teaching and practice orchestration; simulation remains authoritative.

const Progression = preload("res://src/app/signature_progression.gd")
const Challenge = preload("res://src/app/signature_challenge_session.gd")
const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const Arenas = preload("res://src/content/signature_arena_catalog.gd")
const RangeSession = preload("res://src/app/spell_training_range.gd")
const Developer = preload("res://src/app/developer_testing_session.gd")
const TestingPanelScript = preload("res://src/presentation/spell_testing_panel.gd")
const Introduction = preload("res://src/app/optional_introduction.gd")
const DiagnosticReplay = preload("res://src/app/diagnostic_replay_session.gd")
const RangeTarget = preload("res://src/app/range_target_scenario.gd")
const Circuit = preload("res://src/app/signature_circuit.gd")
const CircuitPanel = preload("res://src/presentation/signature_circuit_panel.gd")
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
var diagnostic_replay := DiagnosticReplay.new()
var range_target := RangeTarget.new()
var circuit := Circuit.new()
var circuit_panel := CircuitPanel.new()
var _circuit_transition := false
var _circuit_spell_wire := 0


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


func blocks_gameplay(allow_finished_result: bool = false) -> bool:
	return panel.is_open or (challenge_active and challenge.trial.blocks_gameplay() and not (allow_finished_result and challenge.trial.is_finished()))


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
	diagnostic_replay.stop()
	if not _circuit_transition:
		circuit.reset()
		_circuit_spell_wire = 0
	# Called before any old actor can be copied into a normal saved/session weave.
	if game != null and game.world != null:
		var actor: PlayerState = game._local_player_state()
		if training.active: training.restore(actor, game.world.tick)
		if developer_weave.active: developer_weave.restore(actor, game.world.tick)
	training.close()
	range_target.close()
	developer_weave.close()
	developer.leave()
	challenge.reset()
	challenge_active = false
	panel.close()
	if guide != null: guide.stop()


func before_step() -> void:
	if game == null or game.world == null: return
	if developer.active: developer.apply_continuous(game.world, offline(), true)
	var was_recording: bool = diagnostic_replay.recording
	diagnostic_replay.before_tick(game.world)
	if was_recording and not diagnostic_replay.recording: show_notice(diagnostic_replay.notice)


func after_paid_step(commands: Array[SimCommand]) -> void:
	if game == null: return
	var was_recording: bool = diagnostic_replay.recording
	diagnostic_replay.after_tick(commands, game.world)
	if was_recording and not diagnostic_replay.recording: show_notice(diagnostic_replay.notice)


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
	if training.active: range_target.observe()
	game.district_practice.observe(game.world,game.campus_layout,offline() and not temporary_session())
	# Observe eligibility before a legitimate victory adds its own input block.
	var audio_allowed: bool = game.element_audio != null and not game._gameplay_input_blocked() and not game._is_spectating()
	if game.element_audio != null: game.element_audio.observe_movement(game._local_player_state(),game.world.tick,audio_allowed)
	if challenge_active:
		challenge.observe(game.world, progression, offline(), developer.active)
		if challenge.trial.is_finished(): circuit.observe_result(challenge.view())
		if not challenge.reward.is_empty():
			var text := String(challenge.reward.get("notice", ""))
			if text != _last_reward:
				_last_reward = text
				show_notice(text)
				if bool(challenge.reward.get("ok",false)) and game.element_audio != null: game.element_audio.consequence("confirmed",game.world.tick,audio_allowed)
	if guide != null: guide.observe(game.world, game.world.combat_events, {"range": training.active, "panel_open": panel.is_open, "developer": developer.active,"challenge":challenge_active,"earned":bool(challenge.reward.get("ok",false)),"saved":bool(challenge.reward.get("saved",false))})


func rival_command() -> SimCommand:
	if game == null or game.world == null: return null
	if not challenge_active or developer.freezes_rival(): return null
	return challenge.command(game.world)


func range_target_command() -> SimCommand:
	return range_target.command() if offline() and training.active and not challenge_active else null


func garden_range_preset() -> Dictionary:
	if not offline() or game.world==null or training.active: return {}
	var actor: PlayerState = game._local_player_state()
	if actor==null: return {}
	var info: Dictionary = game.element_garden.nearest_info(Vector2(actor.position_x,actor.position_y)/1000.0)
	return RangeSession.garden_preset(info,training.selected_family)


func open_range_preset(mask: int, family: String) -> bool:
	if not offline() or MixtureCatalog.wire_for(mask,family)<=0: return false
	var continue_lesson := bool(guide.view().get("active",false)) and (guide.tactical or guide.step>=4)
	_close_other_panels()
	if not training.active:
		if not game._start_hex_court(): return false
		if not training.begin(game._local_player_state(),true,game.world.tick): return false
		if not range_target.begin(game.world,game.champion_catalog,true): return false
		if continue_lesson: guide.rebind(game.world)
	training.selected_mask = mask
	training.selected_family = family
	if not panel.open_range(game.ability_catalog,mask,family): return false
	panel.set_range_scenario(range_target.view())
	_handoff()
	return true


func activate(id: String) -> bool:
	if not offline():
		show_notice("Leave the online session to open local practice tools.")
		return false
	_close_other_panels()
	match id:
		"expansion-circuit":
			return start_circuit()
		"expansion-range":
			var preset := garden_range_preset()
			return open_range_preset(int(preset.get("mask",training.selected_mask)),String(preset.get("family",training.selected_family)))
		"expansion-garden-range":
			var preset := garden_range_preset()
			return not preset.is_empty() and open_range_preset(int(preset.mask),String(preset.family))
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
		"expansion-tactics":
			start_introduction()
			guide.start_tactical(game.world)
			show_notice("Tactical lessons started. Menu > Skip introduction ends the guide.")
		"expansion-retry-save", "expansion-recover-save":
			progress_action(id)
		"expansion-guide-details": guide.detail_page = not guide.detail_page
		_:
			return false
	_handoff()
	return true


func progress_action(id: String) -> Dictionary:
	var result: Dictionary = progression.recover_backup() if id == "expansion-recover-save" else progression.retry_save()
	show_notice(String(result.get("notice","")))
	if bool(result.get("saved",false)) and bool(challenge.reward.get("ok",false)):
		challenge.reward.saved = true
		challenge.reward.notice = String(result.notice)
		circuit.refresh_reward(challenge.reward)
		# A finished challenge stops simulation ticks; a real retry receipt can
		# finish the final observer gate without inventing a combat event.
		if guide.active and guide.tactical and guide.step == 3:
			guide.complete = true
			guide.active = false
			guide.step = 4
	refresh_loom()
	return result


func start_introduction() -> void:
	# The optional guide is configured by Bootstrap once its content is loaded.
	if guide == null: return
	if training.active or challenge_active or developer.active:
		game._start_match(game.tick_rate)
	refresh_guide_bindings()
	guide.start(game.world)
	show_notice("Introduction started. F5 or the Skip button ends it at any time." if shortcut_available(KEY_F5) else "Introduction started. Menu > Skip introduction or the Skip button ends it.")


func shortcut_available(key: int) -> bool:
	# The existing input priority is also the source for displayed convenience hints.
	return game != null and game.player_preferences != null and not game.player_preferences.keyboard_bindings.values().has(key)


func refresh_guide_bindings() -> void:
	if game == null or game.player_preferences == null or guide == null: return
	var bindings := preload("res://src/presentation/spell_binding_labels.gd")
	var preferences: PlayerPreferences = game.player_preferences
	var moves: Array[String] = []
	for direction: String in ["move_up", "move_left", "move_down", "move_right"]:
		var label: String = bindings.action_label(StringName(direction), preferences)
		moves.append(label if not label.is_empty() else "Unbound")
	var jump: String = bindings.action_label(&"jump", preferences)
	guide.configure_bindings({"move": "/".join(moves), "jump": jump if not jump.is_empty() else "Jump (unbound)", "cast": SpellLoomPresenter.slot_binding_label(0, preferences), "range": "Menu > Spell Range" if preferences.prompt_device == ControlBindingEditor.DEVICE_CONTROLLER or not shortcut_available(KEY_F6) else "F6 / Spell Range", "skip": "Menu > Skip introduction" if preferences.prompt_device == ControlBindingEditor.DEVICE_CONTROLLER or not shortcut_available(KEY_F5) else "F5 / Skip guide"})


func handle_input(event: InputEvent) -> bool:
	# Bootstrap can receive lifecycle/input callbacks before its world exists.
	# Local tools must not consume input or mutate a session before that handoff.
	if game == null or game.world == null: return false
	panel.readable = game._readable_ui()
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
	if challenge_active and challenge.trial.is_finished() and bool(circuit.view().get("active",false)):
		var transformed := event
		if event is InputEventMouse:
			transformed = event.duplicate()
			transformed.position = event.position / game._ui_scale()
		var action: String = circuit_panel.handle_input(transformed, game.get_viewport_rect().size / game._ui_scale(), circuit_view())
		if not action.is_empty():
			apply_circuit_action(action)
			_handoff()
		return true
	if challenge_active and challenge.trial.is_finished() and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X:
		var progress := progression.view()
		if bool(progress.get("can_recover_backup",false)): progress_action("expansion-recover-save"); return true
		if bool(progress.get("can_retry_save",false)): progress_action("expansion-retry-save"); return true
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		for entry: Array in ENTRIES:
			# A pre-existing custom gameplay binding keeps priority over convenience keys.
			if key == int(entry[3]) and event.shift_pressed == bool(entry[4]) and shortcut_available(key):
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
			_handoff()
			return true
		if guide.active and viewport.x < 900 and (guide.geometry(viewport,ThemeDB.fallback_font).details as Rect2).has_point(point):
			guide.detail_page = not guide.detail_page
			_handoff()
			return true
		if challenge_active and challenge.trial.is_finished() and progress_action_rect(viewport).has_point(point):
			var progress := progression.view()
			if bool(progress.get("can_recover_backup",false)): progress_action("expansion-recover-save"); return true
			if bool(progress.get("can_retry_save",false)): progress_action("expansion-retry-save"); return true
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
		"range_target_motion", "range_target_fire", "range_target_size", "range_reset_statistics":
			if not offline() or not training.active or challenge_active: return
			match String(action.action):
				"range_target_motion": range_target.set_moving(not range_target.moving)
				"range_target_fire": range_target.set_firing(not range_target.firing)
				"range_target_size": range_target.cycle_size()
				"range_reset_statistics": range_target.reset_statistics()
			panel.set_range_scenario(range_target.view())
		"record_replay":
			var overrides := false
			for id: String in ["immortality", "infinite_flux", "infinite_stamina", "no_cooldown"]:
				overrides = overrides or (developer.active and bool(developer.toggles[id]))
			if diagnostic_replay.start(game.world, offline(), overrides): panel.close()
			show_notice(diagnostic_replay.notice)
		"export_replay":
			var exported := diagnostic_replay.export_recording()
			show_notice(String(exported.notice))
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


func start_challenge(id: String, circuit_wire: int = 0) -> bool:
	if not offline(): return false
	if circuit_wire != 0 and (not _circuit_transition or not progression.can_equip(circuit_wire)): return false
	var definition := Challenges.definition(id, game.champion_catalog, game.ability_catalog)
	if definition.is_empty(): return false
	var candidate: SimWorld = game._new_wellspring_world(game.tick_rate)
	if candidate == null: return false
	var setup := InterceptionShowcase.configure(candidate, game.champion_catalog, game.ability_catalog, game.campus_layout)
	var anchors := Arenas.contract(id, game.campus_layout, candidate.collision)
	if setup.is_empty() or anchors.is_empty(): return false
	var actor := candidate.player(1)
	var opponent := candidate.player(2)
	if not game.champion_catalog.apply_to_player(actor, game.selected_champion_id): return false
	game.character_weaves.restore_actor(actor, true)
	# Explicit circuit choice applies only to this fresh encounter. The existing
	# temporary-session transition guard keeps it out of the saved normal weave.
	if circuit_wire != 0 and not actor.place_proven_spell(0, circuit_wire): return false
	if not game.champion_catalog.apply_to_player(opponent, id): return false
	if not opponent.place_proven_spell(0, int(definition.signature_wire)): return false
	# This is a fresh candidate before session admission, never a mid-fight warp.
	if not candidate.collision.can_occupy(anchors.player_spawn_fixed,actor.radius) or not candidate.collision.can_occupy(anchors.opponent_spawn_fixed,opponent.radius): return false
	actor.reset_for_spawn(anchors.player_spawn_fixed)
	opponent.reset_for_spawn(anchors.opponent_spawn_fixed)
	definition["arena_id"] = String(anchors.arena_id)
	definition["district_label"] = String(anchors.district_label)
	var prepared := Challenge.new()
	var developer_attempt := developer.active
	if not prepared.begin(candidate, anchors.bounds, definition, true, developer_attempt): return false
	var continue_lesson := guide.active and guide.tactical
	if not game._start_match_world(game.tick_rate, candidate): return false
	if continue_lesson: guide.rebind(game.world)
	challenge = prepared
	challenge_active = true
	_last_reward = ""
	game.interception_practice_setup = setup
	game.interception_practice_active = true
	game.solo_trial = challenge.trial
	game.authoritative_session.hearth.connect_entity(2)
	game.session_names_by_entity[2] = String(definition.name)
	if game.pov_terrain_backdrop != null: game.pov_terrain_backdrop.set_court_context(SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT)
	show_notice("%s · Defeat %s to learn %s. %s" % [String(anchors.district_label), String(definition.name), String(definition.spell_name), String(anchors.purpose)])
	_handoff()
	return true


func start_circuit() -> bool:
	if game == null or game.tick_rate != 120:
		show_notice("Rival Circuit requires the standard 120 Hz session.")
		return false
	if not offline() or developer.active:
		show_notice("Leave developer practice before starting a Rival Circuit.")
		return false
	var prepared := Circuit.new()
	prepared.begin()
	var id: String = prepared.current_id()
	_circuit_transition = true
	var started := start_challenge(id)
	_circuit_transition = false
	if not started: return false
	circuit = prepared
	circuit_panel.reset_selection()
	_circuit_spell_wire = 0
	return circuit.admit_current(id)


func circuit_view() -> Dictionary:
	var result: Dictionary = circuit.view()
	result["progress"] = progression.view()
	result["reward"] = challenge.reward.duplicate(true)
	result["challenge"] = challenge.definition.duplicate(true)
	return result


func apply_circuit_action(action: String) -> bool:
	if not offline() or not challenge_active or not challenge.trial.is_finished() or not bool(circuit.view().get("active",false)): return false
	match action:
		"circuit-leave":
			return game._start_match(game.tick_rate)
		"circuit-replay":
			return start_circuit()
		"circuit-save":
			var progress := progression.view()
			if bool(progress.get("can_recover_backup",false)): progress_action("expansion-recover-save")
			elif bool(progress.get("can_retry_save",false)): progress_action("expansion-retry-save")
			else: return false
			return true
		"circuit-try":
			if not bool(circuit.view().get("complete",false)) or not bool(challenge.reward.get("ok",false)): return false
			return open_range_preset(int(challenge.definition.mask), String(challenge.definition.family))
		"circuit-next", "circuit-next-learned", "circuit-retry":
			var retry := action == "circuit-retry"
			var id: String = circuit.retry_id() if retry else circuit.next_id()
			if id.is_empty(): return false
			var wire := _circuit_spell_wire
			if action == "circuit-next-learned":
				if not bool(challenge.reward.get("ok",false)): return false
				wire = int(challenge.definition.signature_wire)
				if not progression.can_equip(wire): return false
			_circuit_transition = true
			var started := start_challenge(id, wire)
			_circuit_transition = false
			if not started: return false
			_circuit_spell_wire = wire
			return circuit.admit_retry(id) if retry else circuit.admit_next(id)
	return false


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
	return Rect2(16,86,viewport.x-32,98) if viewport.x < 900 else Rect2(264, top, viewport.x - 528, 82)


static func progress_action_rect(viewport: Vector2) -> Rect2:
	var banner := challenge_banner_rect(viewport)
	return Rect2(banner.position+Vector2(0,banner.size.y+4),Vector2(banner.size.x,30))


func draw(canvas: CanvasItem, font: Font, viewport: Vector2) -> void:
	if not offline(): return
	panel.readable = game._readable_ui()
	if panel.is_open:
		panel.set_inspection_context(game._local_player_state(), training.original_wire())
		if training.active: panel.set_range_scenario(range_target.view())
		panel.draw(canvas, font, viewport)
		return
	if game._directory_child_open() or game.service_directory.is_open or game.solo_trial_menu_open: return
	if challenge_active and challenge.trial.is_finished() and bool(circuit.view().get("active",false)):
		circuit_panel.draw(canvas, font, viewport, circuit_view())
		return
	if entry_buttons_visible():
		for index: int in ENTRIES.size():
			var rect := entry_rect(index, viewport)
			canvas.draw_rect(rect, Color("12242bea"))
			canvas.draw_string(font, rect.position + Vector2(8, 18), String(ENTRIES[index][1]), HORIZONTAL_ALIGNMENT_LEFT, 186, 12, Color("eadfc3"))
	if developer.active and not challenge_active:
		canvas.draw_rect(Rect2(viewport.x - 296, 422, 280, 44), Color("4b2344ee"))
		canvas.draw_string(font, Vector2(viewport.x - 286, 440), "DEV SESSION | no earned progress", HORIZONTAL_ALIGNMENT_LEFT, 264, 13, Color("ffc5e4"))
		canvas.draw_string(font, Vector2(viewport.x - 286, 457), ("Shift+F5 opens overrides and Leave Developer" if shortcut_available(KEY_F5) else "Menu > Developer tools"), HORIZONTAL_ALIGNMENT_LEFT, 264, 11, Color("eadfc3"))
	elif training.active:
		canvas.draw_string(font, Vector2(viewport.x - 296, 444), ("RANGE | F6 change spell · return restores weave" if shortcut_available(KEY_F6) else "RANGE | Menu: spell · return restores weave"), HORIZONTAL_ALIGNMENT_LEFT, 282, 11, Color("77dddc"))
	if challenge_active:
		var status := challenge.status(game.world.tick)
		var text := String(challenge.reward.get("notice", "")) if challenge.trial.is_finished() else String(status.get("cue", ""))
		var box := challenge_banner_rect(viewport)
		var width := box.size.x - 28
		canvas.draw_rect(box, Color("12242bea"))
		var heading := String(challenge.definition.spell_name)
		var route: Dictionary = circuit.view()
		if bool(route.active): heading = "%d / %d · %s" % [int(route.stage)+1,int(route.total),heading]
		canvas.draw_string(font, box.position + Vector2(14, 23), heading, HORIZONTAL_ALIGNMENT_LEFT, width, 16, Color("eadfc3"))
		var y := box.position.y + 43
		for line: String in TestingPanelScript._wrap(text, font, 12, width):
			if y > box.end.y - 20: break
			canvas.draw_string(font, Vector2(box.position.x + 14, y), line, HORIZONTAL_ALIGNMENT_LEFT, width, 12, Color("77dddc"))
			y += 16
		var footer := "Esc / Back: return · then Menu for rivals, tools and saves" if viewport.x < 900 or game.player_preferences.prompt_device == ControlBindingEditor.DEVICE_CONTROLLER or not shortcut_available(KEY_F5) or (not developer.active and not shortcut_available(KEY_F6)) else "DEV PRACTICE · Esc: return · Shift+F5: tools" if developer.active else "Esc / Back: return · Shift+F6: rivals · Shift+F5: tools"
		canvas.draw_string(font, box.position + Vector2(14, box.size.y-6), footer, HORIZONTAL_ALIGNMENT_LEFT, width, 11, Color("b8c1bf"))
		if challenge.trial.is_finished():
			var progress := progression.view()
			if bool(progress.get("can_retry_save",false)) or bool(progress.get("can_recover_backup",false)):
				var action := progress_action_rect(viewport)
				canvas.draw_rect(action,Color("4c4230"))
				canvas.draw_string(font,action.position+Vector2(10,21),"Recover backup · X / click (keeps damaged copy)" if bool(progress.get("can_recover_backup",false)) else "Not saved · Retry progress save [X / click]",HORIZONTAL_ALIGNMENT_LEFT,action.size.x-20,13,Color("ffe6a7"))
	guide.draw(canvas, font, viewport)

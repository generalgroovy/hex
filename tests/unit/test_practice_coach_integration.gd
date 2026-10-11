extends FluxTestSuite

const Harness = preload("res://tests/support/chemistry_coach_harness.gd")

class PreferencesSpy extends PlayerPreferences:
	var save_attempts := 0
	func save_to_file(_path: String = DEFAULT_PATH) -> bool:
		save_attempts += 1
		return true

class InputHarness extends Harness:
	# Keep actual _unhandled_input and device selection. Only unrelated station
	# action-map observation and rendering are isolated; no InputRouter is built.
	func _observe_station_activation_device(_event: InputEvent) -> void:
		pass
	func _draw() -> void:
		pass


func run() -> int:
	_test_actual_area_and_shared_gates()
	_test_device_observation_and_inherited_input()
	_test_current_hex_guidance()
	return finish("practice-coach-integration")


func _test_current_hex_guidance() -> void:
	var node := Harness.new()
	check(node.configure_fixture(false), "hex coach uses the inherited free-practice gates")
	node.world = node._new_wellspring_world(120)
	check(node.world != null and node.world.hex_court != null, "integration uses the actual campus Hex authority")
	if node.world == null or node.world.hex_court == null:
		node.free()
		return
	node.authoritative_session.world = node.world
	node.session_round_values = node.authoritative_session.session_round.capture(node.world)
	var actor: PlayerState = node.world.player()
	check(node.champion_catalog.apply_to_player(actor, "oh_tipi"), "paid coach example owns a real current character")
	_move(node, node.fixture_anchor)
	actor.flux_recovery_per_second = 0
	actor.health_recovery_per_second = 0
	actor.spawn_protection_ticks = 0
	actor.aim_x = 0
	actor.aim_y = -1000
	for index: int in 2:
		var element := "fire" if index == 0 else "water"
		var wire := int(node.ability_catalog.ability(node.ability_catalog.spell_id_at(element, "bolt")).wire_id)
		check(actor.place_proven_spell(index, wire), "paid example equips a live canonical Bolt")
	equal(node.world.hex_court.products.size(), 0, "fresh world has no reaction to describe")
	var idle := _read_current_hex_view(node)
	equal(idle.get("kind"), "invitation", "empty current court invites paid input instead of inventing a Steam field")
	var idle_words := " ".join(PackedStringArray(idle.get("lines", [])))
	check(idle_words.contains("separate paid casts") and idle_words.contains("distinct elements"), "idle invitation teaches funded formation and larger combinations")
	check(idle_words.contains("Help:") and idle_words.contains("counters"), "idle invitation retains the current discoverable recipe next step")
	check(not idle_words.contains("Steam scalds"), "empty court cannot claim a particular active effect")

	var flux_before := actor.flux
	check(node.paid_cast(1), "Fire enters through real command admission and Flux payment")
	check(node.advance_until("matter"), "real Fire projectile reaches current paid ground matter")
	var matter := _read_current_hex_view(node)
	equal(matter.get("kind"), "matter", "the first paid terminal is matter, not an invented reaction")
	check(node.paid_cast(2), "Water enters through a second real paid command")
	check(node.advance_until("reaction"), "paid overlapping terminals form the actual local reaction")
	equal(node.paid_casts, 2, "the teaching fixture uses exactly two paid admissions")
	check(actor.flux < flux_before, "real formation spends the actor's Flux")
	equal(int(node.world.hex_court.metrics.matter_paid), 1200, "two paid casts issue exactly two finite source stocks")
	equal(node.world.hex_court.products.size(), 1, "two source terminals leave one actual product")
	if node.world.hex_court.products.size() != 1:
		node.free()
		return
	var product: Dictionary = node.world.hex_court.products.values()[0]
	equal(int(product.recipe_wire_id), 310, "real Fire and Water route creates Steam")
	equal(int(product.owner), actor.entity_id, "current card is tied to the local paid product owner")
	check(node.world.hex_court.conservation_valid(), "actual paid matter accounting remains conserved")
	var definition := HexRecipePolicy.definition(310)
	var forming := _read_current_hex_view(node)
	equal(forming.get("kind"), "reaction", "current authority teaches the product actually formed")
	equal(int(forming.get("recipe_wire_id", 0)), 310, "coach resolves the exact live Steam identity")
	check(String(forming.get("phase", "")).begins_with("FORMING"), "the forming field does not advertise early damage")
	equal(forming.get("purpose"), definition.purpose, "full effect teaching comes from the current recipe")
	equal(forming.get("counter"), definition.counter, "whole-field escape counter comes from current Steam policy")
	equal(int(forming.get("remaining_ticks", -1)), int(product.active_tick) - node.world.tick, "forming countdown uses the actual product deadline")
	check(node.advance_to(int(product.active_tick)), "actual simulation reaches the accepted active boundary")
	var active := _read_current_hex_view(node)
	check(String(active.get("phase", "")).begins_with("ACTIVE"), "active field changes its phase at the real boundary")
	equal(int(active.get("remaining_ticks", -1)), int(product.decay_tick) - node.world.tick, "active countdown reads the actual instance")
	equal(int(active.get("damage_budget_remaining", -1)), int(product.damage_budget_remaining), "coach reports the current shared damage pool without replenishing it")
	var full_lines := PackedStringArray(active.get("full_lines", []))
	check(" ".join(full_lines).contains(String(definition.counter)), "unabridged counter is retained behind the compact card")
	check(not " ".join(full_lines).contains("Jump or leave to escape"), "the blanket jump-escape promise cannot return")
	actor.air_height = 20_000
	check(actor.air_height < int(definition.maximum_height), "ordinary ground clearance remains below Steam's effect ceiling")
	var airborne := _read_current_hex_view(node)
	equal(airborne.get("lines"), active.get("lines"), "low jump never replaces real Steam instructions with an immunity promise")
	equal(airborne.get("counter"), definition.counter, "the exact current Steam escape counter survives low jump")
	check(node.input_router == null and node.element_audio == null, "paid integration creates no global InputMap writer or playback")
	node.free()


func _read_current_hex_view(node: Node) -> Dictionary:
	var before: String = node.world.state_hash()
	var saved: Dictionary = node.player_preferences.to_dictionary().duplicate(true)
	var view: Dictionary = node._chemistry_practice_view()
	check(not view.is_empty(), "current campus practice returns a bounded contextual view")
	var lines := PackedStringArray(view.get("lines", []))
	equal(lines.size(), 3, "current context retains all three ingredient/effect/counter lines")
	var compact := PracticeCoachCard.model(view, Vector2(1280,720), Vector2.ZERO)
	var expanded := PracticeCoachCard.model(view, Vector2(1280,720), Vector2(850,100))
	check(not compact.is_empty() and not expanded.is_empty(), "actual compact and hover card models both admit the current view")
	if not expanded.is_empty():
		var panel: Rect2 = expanded.panel
		var text_width := panel.size.x - 28.0
		equal(text_width, 412.0, "native card keeps its established horizontal content width")
		# Bootstrap._draw_practice_coach draws these lines at12px with14px
		# horizontal padding. Measure that real font contract, not the old13px hint.
		for line: String in lines:
			check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= text_width, "every current hint fits the actual native card font and width")
		equal(expanded.lines, lines, "hover exposes all three existing contextual lines")
	if not compact.is_empty() and not lines.is_empty():
		var effect_index := 1 if String(view.get("kind", "")) == "reaction" else 0
		equal(compact.lines, PackedStringArray([lines[effect_index]]), "compact card prioritizes the actual current effect")
	equal(node.world.state_hash(), before, "every contextual help sample leaves complete authority unchanged")
	equal(node.player_preferences.to_dictionary(), saved, "contextual help and hover models cannot change settings")
	return view


func _bounds(node: Node) -> Rect2i:
	for area: Dictionary in node.campus_layout.data.activity_areas:
		if String(area.id) == "south-movement-loop":
			return SanctumCampusLayout._parse_bounds(area.bounds)
	return Rect2i()


func _move(node: Node, point_fixed: Vector2i, actor_id: int = 1) -> void:
	var actor: PlayerState = node.world.player(actor_id)
	actor.position_x = point_fixed.x
	actor.position_y = point_fixed.y
	node.current_position = Vector2(point_fixed) / SimConfig.FIXED_SCALE


func _view(node: Node, expected_visible: bool, message: String) -> Dictionary:
	var before: String = node.world.state_hash()
	var preferences: Dictionary = node.player_preferences.to_dictionary().duplicate(true)
	var view: Dictionary = node._movement_practice_view()
	equal(not view.is_empty(), expected_visible, message)
	equal(node.world.state_hash(), before, message + " leaves simulation untouched")
	equal(node.player_preferences.to_dictionary(), preferences, message + " leaves preferences untouched")
	return view


func _test_actual_area_and_shared_gates() -> void:
	var node := Harness.new()
	check(node.configure_fixture(false), "integration uses the real inherited campus and silent gameplay fixture")
	equal(node._chemistry_practice_view().kind, "invitation", "original Crucible fixture still reaches the shared chemistry gate")
	_view(node, false, "Crucible never borrows southern movement coaching")
	var area := _bounds(node)
	check(area.has_area(), "movement area is read from current authored annex")
	var inside := area.position * SimConfig.FIXED_SCALE + Vector2i(100_000, 100_000)
	check(node.world.collision.can_occupy(inside, MovementTuning.PLAYER_RADIUS), "ordinary example is actually walkable at shared wall clearance")
	_move(node, inside)
	equal(_view(node, true, "entering actual southern area enables offline coaching").kind, "grounded", "initial southern lesson is ordinary walking")
	check(node._chemistry_practice_view().is_empty(), "southern area never borrows the Crucible invitation")
	for panel: RefCounted in [node.controls_editor, node.spell_loom_editor, node.player_compendium, node.character_selection_grid]:
		panel.set("is_open", true)
		_view(node, false, "each inherited Controls/Loom/Compendium/Gallery modal hides movement coaching")
		panel.set("is_open", false)
	for property: String in ["join_address_editor_open", "show_visual_specimen"]:
		node.set(property, true)
		_view(node, false, "address editor and specimen presentation suppress personal practice")
		node.set(property, false)
	node.application_input_active = false
	_view(node, false, "application focus loss suppresses the inherited view")
	node.application_input_active = true
	node.controls_input_guard_frames = 1
	_view(node, false, "last rearm frame remains quiet")
	node.controls_input_guard_frames = 0
	node.world.player().health = 0
	_view(node, false, "dead local actor cannot receive a movement lesson")
	node.world.player().health = node.world.player().health_maximum
	for phase: int in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
		node.session_round_values = PackedInt32Array([SessionRound.SCHEMA_VERSION, phase, 1, 120, 0, 3, 2, 0, 0, 0, 0, SessionRound.ResultReason.TIMEOUT if phase == SessionRound.Phase.RESULT else 0, 1, 0, 0, 1, 1, 2, 0, 0, 2, 1])
		check(SessionRound.validate_packet(node.session_round_values), "round gate uses an existing valid phase packet")
		_view(node, false, "live and result round phases are not free practice")
	node.session_round_values = node.authoritative_session.session_round.capture(node.world)
	_view(node, true, "HEARTH restores the same local lesson")
	var guest := PlayerState.new(2)
	check(node.champion_catalog.apply_to_player(guest, "oh_tipi"), "guest owns a valid independent playable actor")
	node.world.players.append(guest)
	_move(node, inside, 2)
	node.session_transport.mode = SessionTransport.Mode.HOSTING
	_view(node, true, "host uses its actual authoritative HEARTH")
	var round_state: SessionRound = node.authoritative_session.session_round
	round_state.scores_by_entity = {1: 0, 2: 0}
	round_state.serial = 1
	round_state.round_end_tick = 120
	round_state.result_end_tick = 120
	for phase: int in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
		round_state.phase = phase
		# Schema v2 requires a terminal reason exactly when phase is RESULT.
		# Keep a tied timeout fixture; the replica deliberately remains HEARTH.
		round_state.result_reason = SessionRound.ResultReason.TIMEOUT if phase == SessionRound.Phase.RESULT else SessionRound.ResultReason.NONE
		check(SessionRound.validate_packet(round_state.capture(node.world)), "host phase is a valid authoritative two-actor round")
		equal(int(SessionRound.decoded(node.session_round_values).get("phase", -1)), SessionRound.Phase.HEARTH, "replica remains a valid stale HEARTH while host authority advances")
		equal(int(node._current_round_state().get("phase", -1)), phase, "inherited round selection reads the valid host phase instead of the stale replica")
		_view(node, false, "host authoritative phase wins over stale replica HEARTH values")
	round_state.bind_hearth()
	node.session_transport.mode = SessionTransport.Mode.CLIENT
	node.session_transport.accepted = true
	node.session_transport.local_entity_id = 2
	equal(node._free_practice_actor().entity_id, 2, "shared admission returns the actual connected guest")
	_view(node, true, "correct guest receives its own southern lesson")
	_move(node, node.fixture_anchor, 1)
	_view(node, true, "host standing elsewhere cannot relocate the guest's lesson")
	_move(node, node.fixture_anchor, 2)
	_move(node, inside, 1)
	_view(node, false, "guest outside cannot borrow an in-area host lesson")
	_move(node, inside, 2)
	node.spectator_focus.active = true
	node.spectator_focus.focus_entity_id = 1
	check(node._is_spectating(), "spectator fixture reaches the real inherited spectator state")
	_view(node, false, "spectator camera is not personal movement practice")
	node.spectator_focus.reset()
	for missing_id: int in [0, 999]:
		node.session_transport.local_entity_id = missing_id
		equal(node._local_player_state().entity_id, 1, "missing guest reaches the known general HUD host fallback")
		_view(node, false, "personal practice explicitly rejects missing guest identity")
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	for point: Vector2i in [area.position * SimConfig.FIXED_SCALE - Vector2i.ONE, area.end * SimConfig.FIXED_SCALE]:
		_move(node, point)
		_view(node, false, "leaving the exact authored area clears the card immediately")
	_move(node, inside)
	_view(node, true, "reentry has no invented completion or cooldown state")
	var original_areas: Array = node.campus_layout.data.activity_areas
	node.campus_layout.data.activity_areas = []
	_view(node, false, "missing authored area cannot create an implicit practice zone")
	node.campus_layout.data.activity_areas = original_areas
	_move(node, node.fixture_anchor)
	equal(node._chemistry_practice_view().kind, "invitation", "return to Crucible preserves the existing shared-gate lesson")
	check(node.input_router == null and node.element_audio == null, "admission fixture creates no InputMap writer or playback")
	node.free()


func _key(pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_J
	event.pressed = pressed
	event.echo = echo
	return event


func _axis(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event


func _input_map_snapshot() -> Dictionary:
	var result := {}
	for action: StringName in InputMap.get_actions():
		var labels := PackedStringArray()
		for event: InputEvent in InputMap.action_get_events(action):
			labels.append(event.as_text())
		result[action] = [InputMap.action_get_deadzone(action), labels]
	return result


func _test_device_observation_and_inherited_input() -> void:
	var map_before := _input_map_snapshot()
	var node := InputHarness.new()
	check(node.preference_overrides_are_transient, "fixture construction disables persistence even before setup")
	check(node.configure_fixture(false), "input fixture retains inherited bootstrap dispatcher without initializing InputRouter")
	check(node.preference_overrides_are_transient, "fixture setup retains the teardown safety guard")
	var preference_spy := PreferencesSpy.new()
	node.player_preferences = preference_spy
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	viewport.add_child(node)
	_move(node, _bounds(node).position * SimConfig.FIXED_SCALE + Vector2i(100_000, 100_000))
	var actor: PlayerState = node.world.player()
	actor.air_height = 20_000
	node.player_preferences.keyboard_bindings[&"jump"] = KEY_K
	node.player_preferences.controller_bindings[&"jump"] = {"kind": "button", "index": JOY_BUTTON_A, "direction": 0}
	var saved: Dictionary = node.player_preferences.to_dictionary().duplicate(true)
	var before: String = node.world.state_hash()
	node.station_activation_device = ControlBindingEditor.DEVICE_MOUSE
	node._unhandled_input(_axis(InputRouter.AIM_DEADZONE))
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_CONTROLLER, "exact meaningful stick threshold selects controller through inherited input")
	check(" ".join(node._movement_practice_view().lines).contains("SOUTH / A"), "live inherited view reflects the current remapped controller profile")
	for ignored: InputEvent in [_key(false), _key(true, true), InputEventMouseMotion.new()]:
		node._unhandled_input(ignored)
		equal(node.movement_practice_device, ControlBindingEditor.DEVICE_CONTROLLER, "release, key echo and mouse motion cannot steal controller labels")
	node._unhandled_input(_key())
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_KEYBOARD, "fresh keyboard press selects keyboard/mouse setup")
	check(" ".join(node._movement_practice_view().lines).contains("Fresh K: one paid double jump"), "keyboard remapping immediately reaches the real non-flying character card")
	for noise: float in [0.0, InputRouter.AIM_DEADZONE - 0.001, -InputRouter.AIM_DEADZONE + 0.001]:
		node._unhandled_input(_axis(noise))
		equal(node.movement_practice_device, ControlBindingEditor.DEVICE_KEYBOARD, "idle and sub-threshold stick noise do not steal keyboard labels")
	node._unhandled_input(_axis(-InputRouter.AIM_DEADZONE))
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_CONTROLLER, "negative threshold is equally deliberate controller activity")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_X
	button.pressed = false
	node.movement_practice_device = ControlBindingEditor.DEVICE_KEYBOARD
	node._unhandled_input(button)
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_KEYBOARD, "controller release cannot switch labels")
	button.pressed = true
	node._unhandled_input(button)
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_CONTROLLER, "fresh controller button selects its profile")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = false
	node._unhandled_input(mouse)
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_CONTROLLER, "mouse release cannot select keyboard/mouse setup")
	mouse.pressed = true
	node._unhandled_input(mouse)
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_KEYBOARD, "fresh mouse press selects the shared keyboard/mouse setup")
	node.application_input_active = false
	node._unhandled_input(button)
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_KEYBOARD, "focus-blocked inherited input cannot change coach device")
	node.application_input_active = true
	node.controls_input_guard_frames = 2
	node._unhandled_input(button)
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_KEYBOARD, "rearm guard also blocks device selection")
	node.controls_input_guard_frames = 0
	node.controls_editor.open_editor()
	node._unhandled_input(_axis(1.0))
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_KEYBOARD, "menu-blocked inherited input does not change the gameplay device")
	node.controls_editor.selected_device = ControlBindingEditor.DEVICE_MOUSE
	node.controls_editor.begin_capture()
	node._unhandled_input(_key())
	check(node.controls_editor.capturing, "keyboard event leaves unrelated mouse binding capture armed")
	equal(node.movement_practice_device, ControlBindingEditor.DEVICE_KEYBOARD, "capture context keeps gameplay label selection isolated")
	equal(node.station_activation_device, ControlBindingEditor.DEVICE_MOUSE, "movement label tracking never rewrites station activation device")
	equal(node.player_preferences.to_dictionary(), saved, "device observation changes no saved bindings or preferences")
	equal(node.world.state_hash(), before, "device and modal input observation spends no resources or movement")
	check(node.input_router == null and node.element_audio == null, "input fixture remains without global map configuration or sound")
	viewport.free()
	equal(preference_spy.save_attempts, 0, "inherited tree teardown never attempts to save fixture preferences")
	equal(_input_map_snapshot(), map_before, "entire inherited input test preserves the global InputMap exactly")

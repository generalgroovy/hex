extends FluxTestSuite

const Playground = preload("res://src/presentation/hex_playground_panel.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Navigation = preload("res://src/app/local_navigation_controller.gd")
const PANEL_RECT := Rect2(330, 150, 900, 530)
const MODAL_HELD_ACTIONS: Array[StringName] = [&"move_right", &"primary", &"evade", &"spell_1"]


class PlaygroundInputHarness:
	extends "res://src/app/bootstrap.gd"
	# Keep production event dispatch, modal close and command quarantine. Never
	# initialize the full game, render, advance simulation or open a peer.
	func _ready() -> void:
		set_process(false)
		set_process_unhandled_input(true)
	func _draw() -> void:
		pass


class PlaygroundPreferencesSpy:
	extends PlayerPreferences
	var save_attempts := 0
	func save_to_file(_path: String = DEFAULT_PATH) -> bool:
		save_attempts += 1
		return true


func run() -> int:
	_test_symmetric_first_four_matrix()
	_test_exact_policy_projection()
	_test_layout_and_intents()
	_test_readable_wrapped_copy()
	_test_modal_close_input()
	return finish("hex-playground-panel")


func _test_symmetric_first_four_matrix() -> void:
	var unique_wires := {}
	for row: int in range(6):
		for column: int in range(6):
			var cell := Playground.matrix_cell(row, column)
			check(not cell.is_empty(), "every playground matrix coordinate resolves")
			var reverse := Playground.matrix_cell(column, row)
			equal(int(cell.recipe_wire_id), int(reverse.recipe_wire_id), "playground pair matrix is symmetric")
			equal(int(cell.first_wire), Playground.ELEMENT_WIRES[row], "row keeps its exact ingredient wire")
			equal(int(cell.second_wire), Playground.ELEMENT_WIRES[column], "column keeps its exact ingredient wire")
			equal(int(cell.recipe_wire_id), Policy.recipe_wire(int(cell.first_wire), int(cell.second_wire)), "cell uses canonical recipe lookup")
			unique_wires[int(cell.recipe_wire_id)] = true
	equal(unique_wires.size(), 21, "six ingredients expose21 unordered pair/self recipes")
	var ordered: Array = unique_wires.keys()
	ordered.sort()
	equal(ordered, [301,302,303,304,307,308,309,310,311,314,315,316,317,320,321,322,325,326,334,335,336], "playground contains the approved21 pair/self contracts exactly")
	equal(Playground.matrix_cell(2, 0).first_id, "wind", "Air retains canonical internal wind identity")
	equal(Playground.matrix_cell(2, 0).first_name, "Air", "players see Air rather than internal wind")
	equal(Playground.matrix_cell(-1, 0), {}, "invalid row fails closed")
	equal(Playground.matrix_cell(0, 6), {}, "invalid column fails closed")


func _test_exact_policy_projection() -> void:
	var steam := Playground.selection_model(Vector2i(3, 2))
	equal(int(steam.recipe_wire_id), 310, "Water plus Fire selects Steam")
	equal(String(steam.name), "Steam", "selection uses policy display name")
	equal([steam.formation_ticks, steam.active_ticks, steam.decay_ticks], [24, 360, 60], "Steam uses current unified phase ticks")
	equal(int(steam.radius), 48_000, "Steam guide uses the compact unified whole-hex selection radius")
	equal(int(steam.pulse_ticks), 30, "Steam uses current scald cadence")
	equal(int(steam.pulse_damage), 12_000, "Steam exposes the current capped pressure ceiling")
	check(bool(steam.transparent) and not bool(steam.conceals), "Steam is explicitly transparent and non-concealing")
	var behavior := String(steam.behavior).to_lower()
	check(behavior == String(Policy.definition(310).purpose).to_lower() + ".", "Steam copy teaches visible pressure and finite exit decay")
	for row: int in range(6):
		for column: int in range(6):
			var cell := Playground.matrix_cell(row, column)
			var model := Playground.selection_model(Vector2i(int(cell.first_wire), int(cell.second_wire)))
			var definition := Policy.definition(int(cell.recipe_wire_id))
			for field: String in ["formation_ticks", "active_ticks", "decay_ticks", "selection_kind", "quantity_policy", "radius", "length", "pulse_ticks", "pulse_damage", "flow_speed", "flow_kind", "slow_ratio", "ground_only", "purpose", "counter"]:
				equal(model[field], definition[field], "playground field %s is projected from policy" % field)
			equal(int(model.selection_radius), int(definition.get("selection_radius", definition.radius)), "playground uses the policy's effective selection radius")
	var rampart := Playground.selection_model(Vector2i(1, 1))
	equal([rampart.selection_kind, rampart.selection_radius, rampart.radius], ["disk", 25_500, 16_875], "compact Rampart distinguishes whole-hex selection reach from product extent")
	equal(Playground.canonical_pair(Vector2i(5, 5)), Playground.DEFAULT_PAIR, "pair outside the six-element playground falls back safely")


func _test_layout_and_intents() -> void:
	check(Playground.DEMO_GUIDANCE.contains("offline") and Playground.DEMO_GUIDANCE.contains("host during Hearth free practice"), "playground states the demo and reset authority boundary")
	equal(Playground.RESET_LABEL, "RESET WELLSPRING", "reset label names the shared world scope")
	check(Playground.RESET_GUIDANCE.contains("restarts shared practice") and Playground.RESET_GUIDANCE.contains("weaves stay") and Playground.RESET_GUIDANCE.contains("paid fields and targets clear"), "playground states what reset preserves and clears")
	var geometry := Playground.layout(PANEL_RECT)
	check(not geometry.is_empty(), "panel fits its intended native 1280x720 practice region")
	check(PANEL_RECT.encloses(geometry.grid) and PANEL_RECT.encloses(geometry.detail), "matrix and detail remain inside the panel")
	var buttons: Dictionary = geometry.buttons
	var button_names: Array = buttons.keys()
	button_names.sort()
	for name: String in button_names:
		var rectangle: Rect2 = buttons[name]
		check(PANEL_RECT.encloses(rectangle), "%s action remains inside the panel" % name)
		for earlier_name: String in button_names:
			if earlier_name == name:
				break
			check(not rectangle.intersects(buttons[earlier_name]), "action hit regions do not overlap")
	for row: int in range(6):
		for column: int in range(6):
			var rectangle := Playground.cell_rect(PANEL_RECT, row, column)
			check((geometry.grid as Rect2).encloses(rectangle), "matrix cell stays inside the grid")
			var intent := Playground.intent_at(rectangle.get_center(), PANEL_RECT, Vector2i(3, 2))
			equal(String(intent.action), "select_hex_pair", "matrix click emits selection intent only")
			equal(intent.selected_pair, Vector2i(Playground.ELEMENT_WIRES[row], Playground.ELEMENT_WIRES[column]), "selection intent carries exact ingredient wires")
	var launch := Playground.intent_at((buttons.launch_paid_demo as Rect2).get_center(), PANEL_RECT, Vector2i(3, 2))
	equal(String(launch.action), "launch_paid_hex_demo", "demo button emits root integration intent")
	check(bool(launch.requires_paid_casts) and not bool(launch.direct_effect_injection), "demo intent requires production paid casts and forbids direct effect injection")
	equal(int(launch.recipe_wire_id), 310, "demo intent carries selected canonical recipe")
	equal(String(Playground.intent_at((buttons.reset_area as Rect2).get_center(), PANEL_RECT, Playground.DEFAULT_PAIR).action), "reset_hex_playground_area", "reset has a separate bounded authority intent")
	equal(String(Playground.intent_at((buttons.open_loom as Rect2).get_center(), PANEL_RECT, Playground.DEFAULT_PAIR).action), "open_spell_loom", "Loom button reuses the existing editor flow")
	equal(String(Playground.intent_at((buttons.open_help as Rect2).get_center(), PANEL_RECT, Playground.DEFAULT_PAIR).action), "open_chemistry_help", "Help button reuses the existing Compendium flow")
	equal(String(Playground.intent_at((geometry.close as Rect2).get_center(), PANEL_RECT, Playground.DEFAULT_PAIR).action), "close_hex_playground", "panel has an explicit close intent")
	equal(Playground.intent_at(Vector2.ZERO, PANEL_RECT, Playground.DEFAULT_PAIR), {}, "outside click emits no gameplay or navigation intent")
	var phases := Playground.phase_segments(Rect2(0, 0, 600, 20), Vector2i(3, 2))
	equal(phases.size(), 3, "selected recipe exposes forming, active and decay segments")
	equal([phases[0].ticks, phases[1].ticks, phases[2].ticks], [24, 360, 60], "phase strip retains exact policy ticks")
	check(absf((phases[2].rectangle as Rect2).end.x - 600.0) < 0.001, "phase strip fills its complete width")
	var reduced := Playground.layout(PANEL_RECT, true)
	check(not reduced.is_empty() and reduced.buttons.keys() == geometry.buttons.keys(), "reduced presentation retains identical actions and coverage")
	equal(Playground.layout(Rect2(0, 0, 500, 300)), {}, "undersized panel fails closed instead of overlapping controls")


func _test_readable_wrapped_copy() -> void:
	var geometry := Playground.layout(PANEL_RECT)
	var detail: Rect2 = geometry.detail
	var regions := Playground.detail_regions(PANEL_RECT)
	for region_name: String in ["behavior", "counter", "phase_bar", "phase_legend", "facts"]:
		check(detail.encloses(regions[region_name]), "%s remains inside the details column" % region_name)
	check(not (regions.behavior as Rect2).intersects(regions.counter), "wrapped behavior and counter have independent rows")
	check(not (regions.counter as Rect2).intersects(regions.phase_bar), "phase timing does not cover counter copy")
	check(not (regions.phase_bar as Rect2).intersects(regions.phase_legend), "phase labels sit beneath rather than inside the proportional bar")

	var font := ThemeDB.fallback_font
	var steam := Playground.selection_model(Vector2i(3, 2))
	var behavior_lines: Array[String] = Playground.wrapped_lines(String(steam.behavior), font, (regions.behavior as Rect2).size.x, 13)
	check(not behavior_lines.is_empty(), "Steam current policy purpose remains visible")
	check(behavior_lines.size() * 18.0 <= (regions.behavior as Rect2).size.y, "wrapped Steam sentence fits its authored detail region")
	_assert_full_wrapped_copy(String(steam.behavior), behavior_lines, font, (regions.behavior as Rect2).size.x, 13, "Steam behavior")
	var counter_copy := "Counter: " + String(steam.counter)
	var counter_lines: Array[String] = Playground.wrapped_lines(counter_copy, font, (regions.counter as Rect2).size.x, 12)
	check(counter_lines.size() * 17.0 <= (regions.counter as Rect2).size.y, "wrapped counter fits its authored detail region")
	_assert_full_wrapped_copy(counter_copy, counter_lines, font, (regions.counter as Rect2).size.x, 12, "counter")

	var legend := Playground.phase_legend_items(regions.phase_legend, Vector2i(3, 2))
	equal(legend.size(), 3, "phase legend has one readable entry per phase")
	equal([legend[0].text, legend[1].text, legend[2].text], ["FORMING 0.20s", "ACTIVE 3.00s", "DECAY 0.50s"], "phase legend keeps full labels and exact policy time")
	for item: Dictionary in legend:
		check((regions.phase_legend as Rect2).encloses(item.rectangle), "phase legend entry remains below the bar")
		check(font.get_string_size(String(item.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= (item.rectangle as Rect2).size.x, "phase legend entry has enough width for its complete label")

	var cell_width := (Playground.cell_rect(PANEL_RECT, 0, 0).grow(-2)).size.x - 12.0
	var checked_wires := {}
	for row: int in range(6):
		for column: int in range(6):
			var cell := Playground.matrix_cell(row, column)
			var wire := int(cell.recipe_wire_id)
			if checked_wires.has(wire):
				continue
			checked_wires[wire] = true
			var full_name := String(cell.name).to_upper()
			var name_lines: Array[String] = Playground.wrapped_lines(full_name, font, cell_width, 11)
			check(name_lines.size() <= 3, "%s fits the six-element matrix in at most three complete lines" % full_name)
			_assert_full_wrapped_copy(full_name, name_lines, font, cell_width, 11, "%s matrix name" % full_name)
	var conflagration_lines: Array[String] = Playground.wrapped_lines("CONFLAGRATION", font, cell_width, 11)
	equal(conflagration_lines.size(), 3, "Conflagration uses three complete lines in the narrower six-element cell")


func _assert_full_wrapped_copy(expected: String, lines: Array[String], font: Font, width: float, size: int, label: String) -> void:
	var rebuilt := ""
	for line: String in lines:
		rebuilt += line
		check(not line.contains("..."), "%s does not use ellipsis" % label)
		check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width, "%s line fits its assigned width" % label)
	equal(rebuilt.replace(" ", ""), expected.replace(" ", ""), "%s preserves every non-space character" % label)


func _test_modal_close_input() -> void:
	var previous_mouse_mode := Input.mouse_mode
	var cases: Array[Dictionary] = [
		{"label": "controller B press", "kind": "joy", "code": JOY_BUTTON_B, "pressed": true, "closes": true},
		{"label": "controller Back press", "kind": "joy", "code": JOY_BUTTON_BACK, "pressed": true, "closes": true},
		{"label": "controller B release", "kind": "joy", "code": JOY_BUTTON_B, "pressed": false, "closes": false},
		{"label": "controller Back release", "kind": "joy", "code": JOY_BUTTON_BACK, "pressed": false, "closes": false},
		{"label": "unrelated controller A", "kind": "joy", "code": JOY_BUTTON_A, "pressed": true, "closes": false},
		{"label": "Escape press", "kind": "key", "code": KEY_ESCAPE, "pressed": true, "closes": true},
		{"label": "Escape release", "kind": "key", "code": KEY_ESCAPE, "pressed": false, "closes": false},
		{"label": "Escape echo", "kind": "key", "code": KEY_ESCAPE, "pressed": true, "echo": true, "closes": false},
		{"label": "close-button click", "kind": "mouse", "pressed": true, "closes": true},
		{"label": "close-button release", "kind": "mouse", "pressed": false, "closes": false},
	]
	for case: Dictionary in cases:
		_test_modal_close_case(case)
	Input.mouse_mode = previous_mouse_mode


func _test_modal_close_case(case: Dictionary) -> void:
	var label := String(case.label)
	var node := PlaygroundInputHarness.new()
	node.preference_overrides_are_transient = true
	node.preferences_persistence_allowed = false
	var preferences := PlaygroundPreferencesSpy.new()
	node.player_preferences = preferences
	node.world = SimWorld.new(120, 20261004, CollisionWorld.new(3_072_000, 1_728_000))
	node.input_router = InputRouter.new(1)
	node.session_transport = SessionTransport.new()
	node.controls_editor = ControlBindingEditor.new()
	node.spell_loom_editor = SpellLoomEditor.new()
	node.player_compendium = node.PlayerCompendiumScript.new()
	# Bind only the existing local routing owners; this input-only harness must
	# not initialize progression, catalogs, persistence or full game startup.
	node.element_expansion.game = node
	node.local_navigation.configure(node)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.handle_input_locally = true
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	viewport.add_child(node)
	viewport.notify_mouse_entered()
	node.application_input_active = true
	node.controls_input_guard_frames = 0
	var actor_before := node.world.player().canonical_values()
	var preferences_before := preferences.to_dictionary().duplicate(true)
	# Follow the actual compact Menu -> Chemistry demos route through the
	# Viewport boundary. No direct modal assignment or private handler call.
	var open_click := InputEventMouseButton.new()
	open_click.button_index = MOUSE_BUTTON_LEFT
	open_click.pressed = true
	open_click.position = Navigation.MENU_ENTRY.get_center() * node._ui_scale()
	viewport.push_input(open_click, true)
	check(node.local_navigation.menu_open, "%s fixture opens the actual compact Menu" % label)
	check(viewport.is_input_handled(), "%s Menu opening consumes its pointer event" % label)
	var menu_rows: Array[Dictionary] = node.local_navigation.entries()
	var chemistry_index := -1
	for index: int in menu_rows.size():
		if String(menu_rows[index].id) == "chemistry": chemistry_index = index
	check(chemistry_index >= 0, "%s actual Menu exposes Chemistry demos" % label)
	if chemistry_index >= 0:
		var chemistry_click := InputEventMouseButton.new()
		chemistry_click.button_index = MOUSE_BUTTON_LEFT
		chemistry_click.pressed = true
		chemistry_click.position = Navigation.row_rect(Vector2(viewport.size) / node._ui_scale(), menu_rows.size(), chemistry_index).get_center() * node._ui_scale()
		viewport.push_input(chemistry_click, true)
	check(node.hex_playground_open, "%s fixture opens Chemistry demos through the actual Menu row" % label)
	check(viewport.is_input_handled(), "%s opening consumes its pointer event" % label)
	check(not node.local_navigation.blocks_gameplay(), "%s Menu releases ownership to the chemistry panel" % label)
	node.controls_input_guard_frames = 0
	check(node._gameplay_input_blocked(), "%s open panel blocks gameplay independently of its guard" % label)
	for action: StringName in MODAL_HELD_ACTIONS:
		Input.action_press(action)
	node.input_router.pending_wheel_pulses[&"jump"] = Time.get_ticks_msec()
	var event := _modal_test_event(case, node)
	viewport.push_input(event, true)
	equal(node.hex_playground_open, not bool(case.closes), "%s has the expected close behavior" % label)
	check(viewport.is_input_handled(), "%s consumes the event at the real viewport boundary" % label)
	check(not node.player_compendium.is_open, "%s cannot fall through to the global Back shortcut" % label)
	check(not node.local_navigation.blocks_gameplay(), "%s cannot fall through to the current global Menu shortcut" % label)
	equal(node.controls_input_guard_frames, 2, "%s retains the two-frame input guard" % label)
	check(node.input_router.pending_wheel_pulses.is_empty(), "%s discards preexisting wheel movement pulses" % label)
	for guard_frame: int in range(2):
		var blocking := node._gameplay_input_blocked()
		check(blocking, "%s guard frame %d remains modal" % [label, guard_frame])
		node.controls_input_guard_frames -= 1
		var guarded := node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2(400, 200), blocking)
		equal(Vector2i(guarded.move_x, guarded.move_y), Vector2i.ZERO, "%s guard cannot leak held movement" % label)
		equal(guarded.held_actions, 0, "%s guard cannot leak held spells or attacks" % label)
		equal(guarded.pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "%s guard sends only movement cancellation, no paid action" % label)
		equal(Vector2i(guarded.aim_target_x, guarded.aim_target_y), Vector2i(-1, -1), "%s guard cannot retain a spell endpoint" % label)
	if bool(case.closes):
		check(not node._gameplay_input_blocked(), "%s releases modal ownership after the existing guard" % label)
		var resumed := node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, false)
		check(resumed.move_x > 0, "%s allows ordinary held direction after the guard" % label)
		equal(resumed.held_actions, 0, "%s keeps modal-origin paid holds quarantined after closing" % label)
		equal(resumed.pressed_actions, 0, "%s cannot replay a paid edge or cancellation after closing" % label)
	else:
		check(node._gameplay_input_blocked(), "%s does not accidentally release modal ownership" % label)
	for action: StringName in MODAL_HELD_ACTIONS:
		Input.action_release(action)
	equal(node.world.player().canonical_values(), actor_before, "%s input-only close never mutates actor state" % label)
	equal(preferences.to_dictionary(), preferences_before, "%s preserves player preferences" % label)
	viewport.free()
	equal(preferences.save_attempts, 0, "%s fixture cannot write preferences even during teardown" % label)


func _modal_test_event(case: Dictionary, node: PlaygroundInputHarness) -> InputEvent:
	if String(case.kind) == "joy":
		var joy := InputEventJoypadButton.new()
		joy.button_index = int(case.code)
		joy.pressed = bool(case.pressed)
		return joy
	if String(case.kind) == "key":
		var key := InputEventKey.new()
		key.keycode = int(case.code)
		key.physical_keycode = int(case.code)
		key.pressed = bool(case.pressed)
		key.echo = bool(case.get("echo", false))
		return key
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = bool(case.pressed)
	var geometry := Playground.layout(node.HEX_PLAYGROUND_RECT, node._reduced_effects_enabled())
	click.position = (geometry.close as Rect2).get_center() * node._ui_scale()
	return click

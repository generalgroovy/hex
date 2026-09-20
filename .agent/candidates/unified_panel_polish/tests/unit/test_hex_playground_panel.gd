extends FluxTestSuite

const Playground = preload("res://src/presentation/hex_playground_panel.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const PANEL_RECT := Rect2(330, 150, 900, 530)


func run() -> int:
	_test_symmetric_first_four_matrix()
	_test_exact_policy_projection()
	_test_layout_and_intents()
	_test_readable_wrapped_copy()
	return finish("hex-playground-panel")


func _test_symmetric_first_four_matrix() -> void:
	var unique_wires := {}
	for row: int in range(4):
		for column: int in range(4):
			var cell := Playground.matrix_cell(row, column)
			check(not cell.is_empty(), "every playground matrix coordinate resolves")
			var reverse := Playground.matrix_cell(column, row)
			equal(int(cell.recipe_wire_id), int(reverse.recipe_wire_id), "playground pair matrix is symmetric")
			equal(int(cell.first_wire), Playground.ELEMENT_WIRES[row], "row keeps its exact ingredient wire")
			equal(int(cell.second_wire), Playground.ELEMENT_WIRES[column], "column keeps its exact ingredient wire")
			equal(int(cell.recipe_wire_id), Policy.recipe_wire(int(cell.first_wire), int(cell.second_wire)), "cell uses canonical recipe lookup")
			unique_wires[int(cell.recipe_wire_id)] = true
	equal(unique_wires.size(), 10, "four ingredients expose ten unique unordered recipes")
	var ordered: Array = unique_wires.keys()
	ordered.sort()
	equal(ordered, [301, 302, 303, 304, 309, 310, 311, 316, 317, 322], "playground contains the approved first-ten contracts exactly")
	equal(Playground.matrix_cell(3, 0).first_id, "wind", "Air retains canonical internal wind identity")
	equal(Playground.matrix_cell(3, 0).first_name, "Air", "players see Air rather than internal wind")
	equal(Playground.matrix_cell(-1, 0), {}, "invalid row fails closed")
	equal(Playground.matrix_cell(0, 4), {}, "invalid column fails closed")


func _test_exact_policy_projection() -> void:
	var steam := Playground.selection_model(Vector2i(3, 2))
	equal(int(steam.recipe_wire_id), 310, "Water plus Fire selects Steam")
	equal(String(steam.name), "Steam", "selection uses policy display name")
	equal([steam.formation_ticks, steam.active_ticks, steam.decay_ticks], [24, 360, 60], "Steam uses current unified phase ticks")
	equal(int(steam.radius), 64_000, "Steam uses current unified whole-hex selection radius")
	equal(int(steam.pulse_ticks), 30, "Steam uses current scald cadence")
	equal(int(steam.pulse_damage), 12_000, "Steam exposes the current capped pressure ceiling")
	check(bool(steam.transparent) and not bool(steam.conceals), "Steam is explicitly transparent and non-concealing")
	var behavior := String(steam.behavior).to_lower()
	check(behavior.contains("scald") and behavior.contains("exit tick") and behavior.contains("does not conceal"), "Steam copy teaches visible pressure and finite exit decay")
	for row: int in range(4):
		for column: int in range(4):
			var cell := Playground.matrix_cell(row, column)
			var model := Playground.selection_model(Vector2i(int(cell.first_wire), int(cell.second_wire)))
			var definition := Policy.definition(int(cell.recipe_wire_id))
			for field: String in ["formation_ticks", "active_ticks", "decay_ticks", "selection_kind", "quantity_policy", "radius", "length", "pulse_ticks", "pulse_damage", "flow_speed", "flow_kind", "slow_ratio", "ground_only", "purpose", "counter"]:
				equal(model[field], definition[field], "playground field %s is projected from policy" % field)
			equal(int(model.selection_radius), int(definition.get("selection_radius", definition.radius)), "playground uses the policy's effective selection radius")
	var rampart := Playground.selection_model(Vector2i(1, 1))
	equal([rampart.selection_kind, rampart.selection_radius, rampart.radius], ["disk", 34_000, 22_500], "Rampart distinguishes whole-hex selection reach from product extent")
	equal(Playground.canonical_pair(Vector2i(8, 8)), Playground.DEFAULT_PAIR, "pair outside the four-element playground falls back safely")


func _test_layout_and_intents() -> void:
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
	for row: int in range(4):
		for column: int in range(4):
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
	check(behavior_lines.size() >= 2, "Steam safety and decay sentence wraps instead of truncating after its first clause")
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
	for row: int in range(4):
		for column: int in range(4):
			var cell := Playground.matrix_cell(row, column)
			var wire := int(cell.recipe_wire_id)
			if checked_wires.has(wire):
				continue
			checked_wires[wire] = true
			var full_name := String(cell.name).to_upper()
			var name_lines: Array[String] = Playground.wrapped_lines(full_name, font, cell_width, 11)
			check(name_lines.size() <= 2, "%s fits the matrix in at most two complete lines" % full_name)
			_assert_full_wrapped_copy(full_name, name_lines, font, cell_width, 11, "%s matrix name" % full_name)
	var conflagration_lines: Array[String] = Playground.wrapped_lines("CONFLAGRATION", font, cell_width, 11)
	equal(conflagration_lines.size(), 2, "Conflagration uses two complete lines rather than an ellipsis")


func _assert_full_wrapped_copy(expected: String, lines: Array[String], font: Font, width: float, size: int, label: String) -> void:
	var rebuilt := ""
	for line: String in lines:
		rebuilt += line
		check(not line.contains("..."), "%s does not use ellipsis" % label)
		check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width, "%s line fits its assigned width" % label)
	equal(rebuilt.replace(" ", ""), expected.replace(" ", ""), "%s preserves every non-space character" % label)

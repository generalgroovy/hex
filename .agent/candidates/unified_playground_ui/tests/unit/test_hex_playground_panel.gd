extends FluxTestSuite

const Panel = preload("res://src/presentation/hex_playground_panel.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const PANEL_RECT := Rect2(330, 150, 900, 530)


func run() -> int:
	_test_symmetric_first_four_matrix()
	_test_exact_policy_projection()
	_test_layout_and_intents()
	return finish("hex-playground-panel")


func _test_symmetric_first_four_matrix() -> void:
	var unique_wires := {}
	for row: int in range(4):
		for column: int in range(4):
			var cell := Panel.matrix_cell(row, column)
			check(not cell.is_empty(), "every playground matrix coordinate resolves")
			var reverse := Panel.matrix_cell(column, row)
			equal(int(cell.recipe_wire_id), int(reverse.recipe_wire_id), "playground pair matrix is symmetric")
			equal(int(cell.first_wire), Panel.ELEMENT_WIRES[row], "row keeps its exact ingredient wire")
			equal(int(cell.second_wire), Panel.ELEMENT_WIRES[column], "column keeps its exact ingredient wire")
			equal(int(cell.recipe_wire_id), Policy.recipe_wire(int(cell.first_wire), int(cell.second_wire)), "cell uses canonical recipe lookup")
			unique_wires[int(cell.recipe_wire_id)] = true
	equal(unique_wires.size(), 10, "four ingredients expose ten unique unordered recipes")
	var ordered: Array = unique_wires.keys()
	ordered.sort()
	equal(ordered, [301, 302, 303, 304, 309, 310, 311, 316, 317, 322], "playground contains the approved first-ten contracts exactly")
	equal(Panel.matrix_cell(3, 0).first_id, "wind", "Air retains canonical internal wind identity")
	equal(Panel.matrix_cell(3, 0).first_name, "Air", "players see Air rather than internal wind")
	equal(Panel.matrix_cell(-1, 0), {}, "invalid row fails closed")
	equal(Panel.matrix_cell(0, 4), {}, "invalid column fails closed")


func _test_exact_policy_projection() -> void:
	var steam := Panel.selection_model(Vector2i(3, 2))
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
			var cell := Panel.matrix_cell(row, column)
			var model := Panel.selection_model(Vector2i(int(cell.first_wire), int(cell.second_wire)))
			var definition := Policy.definition(int(cell.recipe_wire_id))
			for field: String in ["formation_ticks", "active_ticks", "decay_ticks", "selection_kind", "quantity_policy", "radius", "length", "pulse_ticks", "pulse_damage", "flow_speed", "flow_kind", "slow_ratio", "ground_only", "purpose", "counter"]:
				equal(model[field], definition[field], "playground field %s is projected from policy" % field)
			equal(int(model.selection_radius), int(definition.get("selection_radius", definition.radius)), "playground uses the policy's effective selection radius")
	var rampart := Panel.selection_model(Vector2i(1, 1))
	equal([rampart.selection_kind, rampart.selection_radius, rampart.radius], ["disk", 34_000, 22_500], "Rampart distinguishes whole-hex selection reach from product extent")
	equal(Panel.canonical_pair(Vector2i(8, 8)), Panel.DEFAULT_PAIR, "pair outside the four-element playground falls back safely")


func _test_layout_and_intents() -> void:
	var geometry := Panel.layout(PANEL_RECT)
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
			var rectangle := Panel.cell_rect(PANEL_RECT, row, column)
			check((geometry.grid as Rect2).encloses(rectangle), "matrix cell stays inside the grid")
			var intent := Panel.intent_at(rectangle.get_center(), PANEL_RECT, Vector2i(3, 2))
			equal(String(intent.action), "select_hex_pair", "matrix click emits selection intent only")
			equal(intent.selected_pair, Vector2i(Panel.ELEMENT_WIRES[row], Panel.ELEMENT_WIRES[column]), "selection intent carries exact ingredient wires")
	var launch := Panel.intent_at((buttons.launch_paid_demo as Rect2).get_center(), PANEL_RECT, Vector2i(3, 2))
	equal(String(launch.action), "launch_paid_hex_demo", "demo button emits root integration intent")
	check(bool(launch.requires_paid_casts) and not bool(launch.direct_effect_injection), "demo intent requires production paid casts and forbids direct effect injection")
	equal(int(launch.recipe_wire_id), 310, "demo intent carries selected canonical recipe")
	equal(String(Panel.intent_at((buttons.reset_area as Rect2).get_center(), PANEL_RECT, Panel.DEFAULT_PAIR).action), "reset_hex_playground_area", "reset has a separate bounded authority intent")
	equal(String(Panel.intent_at((buttons.open_loom as Rect2).get_center(), PANEL_RECT, Panel.DEFAULT_PAIR).action), "open_spell_loom", "Loom button reuses the existing editor flow")
	equal(String(Panel.intent_at((buttons.open_help as Rect2).get_center(), PANEL_RECT, Panel.DEFAULT_PAIR).action), "open_chemistry_help", "Help button reuses the existing Compendium flow")
	equal(String(Panel.intent_at((geometry.close as Rect2).get_center(), PANEL_RECT, Panel.DEFAULT_PAIR).action), "close_hex_playground", "panel has an explicit close intent")
	equal(Panel.intent_at(Vector2.ZERO, PANEL_RECT, Panel.DEFAULT_PAIR), {}, "outside click emits no gameplay or navigation intent")
	var phases := Panel.phase_segments(Rect2(0, 0, 600, 20), Vector2i(3, 2))
	equal(phases.size(), 3, "selected recipe exposes forming, active and decay segments")
	equal([phases[0].ticks, phases[1].ticks, phases[2].ticks], [24, 360, 60], "phase strip retains exact policy ticks")
	check(absf((phases[2].rectangle as Rect2).end.x - 600.0) < 0.001, "phase strip fills its complete width")
	var reduced := Panel.layout(PANEL_RECT, true)
	check(not reduced.is_empty() and reduced.buttons.keys() == geometry.buttons.keys(), "reduced presentation retains identical actions and coverage")
	equal(Panel.layout(Rect2(0, 0, 500, 300)), {}, "undersized panel fails closed instead of overlapping controls")

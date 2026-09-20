class_name HexPlaygroundPanel
extends RefCounted

## Compact, read-only chemistry selector for a practice interaction. This class
## emits UI intents only. Bootstrap remains responsible for turning a demo
## request into ordinary paid casts in the selected district.

const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const ELEMENT_WIRES: Array[int] = [3, 1, 2, 4]
const ELEMENT_IDS: Array[String] = ["water", "earth", "fire", "wind"]
const MINIMUM_SIZE := Vector2(620, 360)
const DEFAULT_PAIR := Vector2i(3, 2)
const TICK_RATE := 120
const INK := Color("111916f5")
const PANEL := Color("e8dab5fa")
const MUTED := Color("788078")
const BRASS := Color("a78449")
const ACTIVE := Color("315e4f")


static func matrix_cell(row: int, column: int) -> Dictionary:
	if row < 0 or row >= ELEMENT_WIRES.size() or column < 0 or column >= ELEMENT_WIRES.size():
		return {}
	var first := ELEMENT_WIRES[row]
	var second := ELEMENT_WIRES[column]
	var wire := Policy.recipe_wire(first, second)
	var definition := Policy.definition(wire)
	if definition.is_empty():
		return {}
	return {
		"row": row,
		"column": column,
		"first_wire": first,
		"second_wire": second,
		"first_id": ELEMENT_IDS[row],
		"second_id": ELEMENT_IDS[column],
		"first_name": AbilityCatalog.element_display_name(ELEMENT_IDS[row]),
		"second_name": AbilityCatalog.element_display_name(ELEMENT_IDS[column]),
		"recipe_wire_id": wire,
		"name": String(definition.name),
	}


static func selection_model(selected_pair: Vector2i) -> Dictionary:
	var pair := canonical_pair(selected_pair)
	var wire := Policy.recipe_wire(pair.x, pair.y)
	var definition := Policy.definition(wire)
	if definition.is_empty():
		return {}
	var first_id := Policy.ingredient_layer(pair.x)
	var second_id := Policy.ingredient_layer(pair.y)
	return {
		"selected_pair": pair,
		"first_wire": pair.x,
		"second_wire": pair.y,
		"first_id": first_id,
		"second_id": second_id,
		"first_name": AbilityCatalog.element_display_name(first_id),
		"second_name": AbilityCatalog.element_display_name(second_id),
		"recipe_wire_id": wire,
		"name": String(definition.name),
		"purpose": String(definition.purpose),
		"counter": String(definition.counter),
		"formation_ticks": int(definition.formation_ticks),
		"active_ticks": int(definition.active_ticks),
		"decay_ticks": int(definition.decay_ticks),
		"selection_kind": String(definition.selection_kind),
		"selection_radius": int(definition.get("selection_radius", definition.radius)),
		"quantity_policy": String(definition.quantity_policy),
		"radius": int(definition.radius),
		"length": int(definition.length),
		"pulse_ticks": int(definition.pulse_ticks),
		"pulse_damage": int(definition.pulse_damage),
		"flow_speed": int(definition.flow_speed),
		"flow_kind": String(definition.flow_kind),
		"slow_ratio": int(definition.slow_ratio),
		"ground_only": bool(definition.ground_only),
		"transparent": bool(definition.get("transparent", false)),
		"conceals": bool(definition.get("conceals", false)),
		"behavior": _behavior_summary(wire, definition),
	}


static func canonical_pair(selected_pair: Vector2i) -> Vector2i:
	if selected_pair.x not in ELEMENT_WIRES or selected_pair.y not in ELEMENT_WIRES:
		return DEFAULT_PAIR
	return selected_pair


static func layout(rectangle: Rect2, reduced: bool = false) -> Dictionary:
	if rectangle.size.x < MINIMUM_SIZE.x or rectangle.size.y < MINIMUM_SIZE.y:
		return {}
	var padding := 14.0 if reduced else 18.0
	var header_height := 48.0 if reduced else 56.0
	var footer_height := 48.0 if reduced else 56.0
	var label_space := 50.0 if reduced else 58.0
	var available_height := rectangle.size.y - header_height - footer_height - padding * 2.0
	var available_width := rectangle.size.x * 0.46 - padding
	var cell_size := floor(minf((available_height - label_space) / 4.0, (available_width - label_space) / 4.0))
	if cell_size < 44.0:
		return {}
	var grid := Rect2(rectangle.position + Vector2(padding + label_space, padding + header_height + label_space), Vector2(cell_size * 4.0, cell_size * 4.0))
	var detail_left := grid.end.x + padding
	var detail := Rect2(Vector2(detail_left, rectangle.position.y + padding + header_height), Vector2(rectangle.end.x - padding - detail_left, available_height))
	if detail.size.x < 210.0:
		return {}
	var button_gap := 8.0
	var button_width := (rectangle.size.x - padding * 2.0 - button_gap * 3.0) / 4.0
	var button_y := rectangle.end.y - padding - 34.0
	var buttons := {
		"launch_paid_demo": Rect2(rectangle.position.x + padding, button_y, button_width, 34),
		"reset_area": Rect2(rectangle.position.x + padding + (button_width + button_gap), button_y, button_width, 34),
		"open_loom": Rect2(rectangle.position.x + padding + (button_width + button_gap) * 2.0, button_y, button_width, 34),
		"open_help": Rect2(rectangle.position.x + padding + (button_width + button_gap) * 3.0, button_y, button_width, 34),
	}
	return {
		"panel": rectangle,
		"grid": grid,
		"cell_size": cell_size,
		"detail": detail,
		"buttons": buttons,
		"close": Rect2(rectangle.end - Vector2(padding + 30.0, rectangle.size.y - padding), Vector2(30, 26)),
	}


static func cell_rect(rectangle: Rect2, row: int, column: int, reduced: bool = false) -> Rect2:
	var geometry := layout(rectangle, reduced)
	if geometry.is_empty() or row < 0 or row >= 4 or column < 0 or column >= 4:
		return Rect2()
	var grid: Rect2 = geometry.grid
	var size := float(geometry.cell_size)
	return Rect2(grid.position + Vector2(column * size, row * size), Vector2(size, size))


static func phase_segments(rectangle: Rect2, selected_pair: Vector2i) -> Array[Dictionary]:
	var model := selection_model(selected_pair)
	if model.is_empty() or rectangle.size.x <= 0.0 or rectangle.size.y <= 0.0:
		return []
	var durations: Array[int] = [int(model.formation_ticks), int(model.active_ticks), int(model.decay_ticks)]
	var labels: Array[String] = ["FORMING", "ACTIVE", "DECAY"]
	var total := durations[0] + durations[1] + durations[2]
	var elapsed := 0
	var result: Array[Dictionary] = []
	for index: int in range(3):
		var left := rectangle.position.x + rectangle.size.x * float(elapsed) / maxf(1.0, float(total))
		elapsed += durations[index]
		var right := rectangle.position.x + rectangle.size.x * float(elapsed) / maxf(1.0, float(total))
		result.append({"label": labels[index], "ticks": durations[index], "rectangle": Rect2(left, rectangle.position.y, right - left, rectangle.size.y)})
	return result


static func intent_at(pointer: Vector2, rectangle: Rect2, selected_pair: Vector2i, reduced: bool = false) -> Dictionary:
	var geometry := layout(rectangle, reduced)
	if geometry.is_empty() or not rectangle.has_point(pointer):
		return {}
	if (geometry.close as Rect2).has_point(pointer):
		return {"action": "close_hex_playground"}
	for row: int in range(4):
		for column: int in range(4):
			if cell_rect(rectangle, row, column, reduced).has_point(pointer):
				var cell := matrix_cell(row, column)
				return {"action": "select_hex_pair", "selected_pair": Vector2i(int(cell.first_wire), int(cell.second_wire)), "recipe_wire_id": int(cell.recipe_wire_id)}
	var buttons: Dictionary = geometry.buttons
	if (buttons.launch_paid_demo as Rect2).has_point(pointer):
		var model := selection_model(selected_pair)
		return {"action": "launch_paid_hex_demo", "selected_pair": model.selected_pair, "recipe_wire_id": int(model.recipe_wire_id), "requires_paid_casts": true, "direct_effect_injection": false}
	if (buttons.reset_area as Rect2).has_point(pointer):
		return {"action": "reset_hex_playground_area"}
	if (buttons.open_loom as Rect2).has_point(pointer):
		return {"action": "open_spell_loom"}
	if (buttons.open_help as Rect2).has_point(pointer):
		return {"action": "open_chemistry_help"}
	return {}


static func draw(canvas: CanvasItem, rectangle: Rect2, selected_pair: Vector2i, reduced: bool = false) -> void:
	if canvas == null:
		return
	var geometry := layout(rectangle, reduced)
	if geometry.is_empty():
		return
	var model := selection_model(selected_pair)
	var font := ThemeDB.fallback_font
	var alpha := 0.82 if reduced else 1.0
	canvas.draw_rect(rectangle, Color(PANEL, alpha))
	canvas.draw_rect(rectangle, BRASS, false, 2.0)
	_text(canvas, font, rectangle.position + Vector2(18, 29), "HEX PLAYGROUND", 19 if reduced else 22, INK)
	_text(canvas, font, rectangle.position + Vector2(18, 49), "Choose a pair; Run Demo requests two ordinary paid casts.", 11 if reduced else 12, MUTED)
	var close: Rect2 = geometry.close
	canvas.draw_rect(close, Color(INK, 0.08))
	canvas.draw_rect(close, BRASS, false, 1.0)
	_text(canvas, font, close.position + Vector2(10, 19), "X", 13, INK)
	var grid: Rect2 = geometry.grid
	var cell_size := float(geometry.cell_size)
	for index: int in range(4):
		var label := AbilityCatalog.element_display_name(ELEMENT_IDS[index])
		_text(canvas, font, Vector2(grid.position.x + index * cell_size + 5, grid.position.y - 10), label.to_upper(), 11, INK)
		_text(canvas, font, Vector2(grid.position.x - 51, grid.position.y + index * cell_size + 23), label.to_upper(), 11, INK)
	for row: int in range(4):
		for column: int in range(4):
			var cell := matrix_cell(row, column)
			var cell_box := cell_rect(rectangle, row, column, reduced).grow(-2)
			var chosen := int(cell.recipe_wire_id) == int(model.recipe_wire_id)
			canvas.draw_rect(cell_box, Color(ACTIVE, 0.28 if chosen else 0.08))
			canvas.draw_rect(cell_box, ACTIVE if chosen else Color(MUTED, 0.45), false, 2.0 if chosen else 1.0)
			_text(canvas, font, cell_box.position + Vector2(6, cell_box.size.y * 0.5 + 4), _fit(String(cell.name), font, cell_box.size.x - 12.0, 11), 11, INK)
	var detail: Rect2 = geometry.detail
	_text(canvas, font, detail.position + Vector2(0, 24), "%s + %s" % [model.first_name, model.second_name], 14, MUTED)
	_text(canvas, font, detail.position + Vector2(0, 50), String(model.name).to_upper(), 20 if reduced else 23, INK)
	_text(canvas, font, detail.position + Vector2(0, 76), _fit(String(model.behavior), font, detail.size.x, 13), 13, INK)
	_text(canvas, font, detail.position + Vector2(0, 99), _fit("Counter: " + String(model.counter), font, detail.size.x, 12), 12, MUTED)
	var phase_rect := Rect2(detail.position + Vector2(0, 116), Vector2(detail.size.x, 22))
	var phase_colors: Array[Color] = [Color("c49c55"), Color("3d8068"), Color("7c7467")]
	var segments := phase_segments(phase_rect, model.selected_pair)
	for index: int in range(segments.size()):
		var segment: Dictionary = segments[index]
		canvas.draw_rect(segment.rectangle, Color(phase_colors[index], alpha))
		_text(canvas, font, (segment.rectangle as Rect2).position + Vector2(4, 16), "%s %.2fs" % [segment.label, float(segment.ticks) / TICK_RATE], 10, PANEL)
	var facts := _selection_fact(model)
	if int(model.pulse_damage) > 0:
		facts += "  Pulse %.0f" % (float(model.pulse_damage) / 1000.0)
	if int(model.flow_speed) > 0:
		facts += "  Flow %.0fpx/s" % (float(model.flow_speed) / 1000.0)
	if int(model.slow_ratio) != 1000:
		facts += "  Move %.0f%%" % (float(model.slow_ratio) / 10.0)
	_text(canvas, font, detail.position + Vector2(0, 161), _fit(facts, font, detail.size.x, 12), 12, INK)
	var buttons: Dictionary = geometry.buttons
	_draw_button(canvas, font, buttons.launch_paid_demo, "RUN PAID DEMO")
	_draw_button(canvas, font, buttons.reset_area, "RESET AREA")
	_draw_button(canvas, font, buttons.open_loom, "SPELL LOOM")
	_draw_button(canvas, font, buttons.open_help, "HELP")


static func _behavior_summary(wire: int, definition: Dictionary) -> String:
	if wire == 310:
		return "Transparent capped scald pressure; exposure falls by 2 per exit tick. Steam does not conceal."
	return String(definition.purpose).capitalize() + "."


static func _selection_fact(model: Dictionary) -> String:
	match String(model.selection_kind):
		"disk":
			var disk := "Disk %.0fpx" % (float(model.selection_radius) / 1000.0)
			if int(model.radius) != int(model.selection_radius):
				disk += "  Effect %.0fpx" % (float(model.radius) / 1000.0)
			return disk
		"sector":
			return "Sector reach %.0fpx" % (float(model.length) / 1000.0)
		"capsule":
			return "Capsule %.0fpx x %.0fpx" % [float(model.radius) / 1000.0, float(model.length) / 1000.0]
		"annulus":
			return "Annulus %.0f-%.0fpx" % [float(model.length) / 1000.0, float(model.radius) / 1000.0]
	return String(model.selection_kind).capitalize()


static func _fit(value: String, font: Font, width: float, size: int) -> String:
	if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return value
	var result := value
	while not result.is_empty() and font.get_string_size(result + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		result = result.left(result.length() - 1)
	return result + "..."


static func _text(canvas: CanvasItem, font: Font, point: Vector2, value: String, size: int, color: Color) -> void:
	canvas.draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func _draw_button(canvas: CanvasItem, font: Font, rectangle: Rect2, label: String) -> void:
	canvas.draw_rect(rectangle, Color(ACTIVE, 0.14))
	canvas.draw_rect(rectangle, ACTIVE, false, 1.0)
	_text(canvas, font, rectangle.position + Vector2(9, 22), label, 11, INK)

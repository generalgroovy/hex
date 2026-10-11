class_name WellspringServiceBuildings
extends RefCounted
## Directory metadata and compact cards for existing campus buildings.
## This does not generate architecture, collision or execute any command.

const DETAIL_DELAY_SECONDS := 0.28
const INK := Color("25222b")
const STONE := Color("8a816d")
const STONE_LIGHT := Color("c0b28d")
const PARCHMENT := Color("eadcba")
const GROUPS := {
	"training": {"title": "ROUTEKEEPER LODGE", "purpose": "MOVEMENT + CONTROLS", "building_id": 101, "hint": "Movement and controls", "commands": ["movement_guide", "configure_controls"]},
	"academy": {"title": "WELLSPRING ACADEMY", "purpose": "CHAMPIONS + SPELLS", "building_id": 104, "hint": "Champions and spellcraft", "commands": ["champion_switch", "configure_spells"]},
	"farflow": {"title": "FARFLOW HALL", "purpose": "FRIENDS + MATCHES", "building_id": 109, "hint": "Friends, rules and rounds", "commands": ["host_session", "join_session", "session_charter", "session_hearth", "session_ledger", "session_parting"]},
	"practice": {"title": "VERDANT REST PAVILION", "purpose": "RECOVER + PRACTICE", "building_id": 103, "hint": "Practice and recovery", "commands": ["impact_practice", "training_reset"]},
}
const DEFINITIONS := {
	"movement_guide": {"title": "MOVEMENT", "group": "training", "glyph": "route", "hint": "Moves, timing and routes", "color": "83bda0"},
	"configure_controls": {"title": "CONTROLS", "group": "training", "glyph": "keys", "hint": "Keyboard, mouse and pad", "color": "83bda0"},
	"champion_switch": {"title": "CHAMPIONS", "group": "academy", "glyph": "mask", "hint": "Choose your traveller", "color": "b598cf"},
	"configure_spells": {"title": "SPELL LOOM", "group": "academy", "glyph": "weave", "hint": "Equip 12 spell slots", "color": "b598cf"},
	"host_session": {"title": "HOST", "group": "farflow", "glyph": "gate", "hint": "Open or close your lobby", "color": "88bfc9"},
	"join_session": {"title": "JOIN", "group": "farflow", "glyph": "gate", "hint": "Connect to a friend's lobby", "color": "88bfc9"},
	"session_charter": {"title": "RULES", "group": "farflow", "glyph": "scroll", "hint": "Social, sparring or duel", "color": "d2ac64"},
	"session_hearth": {"title": "READY", "group": "farflow", "glyph": "hearth", "hint": "Gather and ready for a round", "color": "d2ac64"},
	"session_ledger": {"title": "COMPANY", "group": "farflow", "glyph": "mask", "hint": "Select a connected traveller", "color": "d2ac64"},
	"session_parting": {"title": "PARTING", "group": "farflow", "glyph": "gate", "hint": "Host only; confirm dismissal", "color": "c78d7f"},
	"training_reset": {"title": "RESTORE", "group": "practice", "glyph": "hearth", "hint": "Reset resources and practice", "color": "83bda0"},
	"impact_practice": {"title": "IMPACT", "group": "practice", "glyph": "route", "hint": "Practice impact recovery", "color": "83bda0"},
}

var focused_id := ""
var focus_seconds := 0.0


static func definition_for(station: Dictionary) -> Dictionary:
	return (DEFINITIONS.get(String(station.get("command", "")), {}) as Dictionary).duplicate()


static func group_for_station(station: Dictionary) -> String:
	var definition := definition_for(station)
	if definition.is_empty():
		return ""
	var group := String(station.get("service_group", definition["group"]))
	return group if GROUPS.has(group) else ""


static func group_definition(group: String) -> Dictionary:
	return (GROUPS.get(group, {}) as Dictionary).duplicate(true)


static func position_of(station: Dictionary) -> Vector2:
	var value: Array = station.get("position", [0, 0])
	return Vector2(float(value[0]), float(value[1]))


static func door_threshold(station: Dictionary) -> Rect2:
	# Canonical entries sit 24px beyond the facade; the existing door foot is
	# 20px above the entry. Flat paving connects them without implying a step.
	return Rect2(position_of(station) + Vector2(-18, -20), Vector2(36, 27))


static func service_label_rect(station: Dictionary) -> Rect2:
	var group := group_definition(group_for_station(station))
	if group.is_empty():
		return Rect2()
	var purpose_width := ThemeDB.fallback_font.get_string_size(String(group["purpose"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var name_width := ThemeDB.fallback_font.get_string_size(String(group["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var width := ceilf(maxf(purpose_width, name_width)) + 16.0
	return Rect2(position_of(station) + Vector2(-width * 0.5, 8), Vector2(width, 31))


static func door_outline(station: Dictionary) -> PackedVector2Array:
	var threshold := door_threshold(station)
	return PackedVector2Array([
		threshold.position, threshold.position + Vector2(threshold.size.x, 0),
		threshold.end - Vector2(0, 5), threshold.end - Vector2(5, 0),
		threshold.position + Vector2(5, threshold.size.y),
		threshold.position + Vector2(0, threshold.size.y - 5),
	])


static func hex_outline(rectangle: Rect2) -> PackedVector2Array:
	var center := rectangle.get_center()
	var half := rectangle.size * 0.5
	return PackedVector2Array([
		center + Vector2(-half.x, 0), center + Vector2(-half.x * 0.5, -half.y),
		center + Vector2(half.x * 0.5, -half.y), center + Vector2(half.x, 0),
		center + Vector2(half.x * 0.5, half.y), center + Vector2(-half.x * 0.5, half.y),
	])


static func commands_for_group(group: String, stations: Array) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not GROUPS.has(group):
		return output
	for command: String in GROUPS[group]["commands"]:
		for value: Variant in stations:
			if not value is Dictionary:
				continue
			var station: Dictionary = value
			if String(station.get("command", "")) != command or group_for_station(station) != group:
				continue
			# Preserve canonical authority, position, id and confirmation behavior.
			var entry := station.duplicate(true)
			var definition := definition_for(station)
			entry["compact_title"] = definition["title"]
			entry["compact_hint"] = definition["hint"]
			output.append(entry)
	return output


func update_focus(item_id: String, delta: float, immediate: bool = false) -> bool:
	if item_id.is_empty():
		clear_focus()
		return false
	if item_id != focused_id:
		focused_id = item_id
		focus_seconds = 0.0
	if immediate:
		focus_seconds = DETAIL_DELAY_SECONDS
	elif is_finite(delta) and delta > 0.0:
		focus_seconds = minf(DETAIL_DELAY_SECONDS, focus_seconds + delta)
	return focus_seconds >= DETAIL_DELAY_SECONDS


func clear_focus() -> void:
	focused_id = ""
	focus_seconds = 0.0


static func card_rectangles(area: Rect2, count: int) -> Array[Rect2]:
	var output: Array[Rect2] = []
	if count <= 0 or area.size.x < 80.0 or area.size.y < 36.0:
		return output
	var gap := 8.0
	var columns := card_columns(area.size.x, count)
	var rows := ceili(float(count) / float(columns))
	var width := floorf((area.size.x - gap * float(columns - 1)) / float(columns))
	var height := minf(68.0, floorf((area.size.y - gap * float(rows - 1)) / float(rows)))
	if height < 36.0:
		return output # Caller must page instead of clipping unreadable cards.
	for index: int in range(count):
		var column := index % columns
		var row := floori(float(index) / float(columns))
		output.append(Rect2(area.position + Vector2(column * (width + gap), row * (height + gap)), Vector2(width, height)))
	return output


static func card_columns(width: float, count: int) -> int:
	var columns := mini(3, mini(count, maxi(1, int((width + 8.0) / 176.0))))
	return 2 if count == 4 and columns >= 2 else maxi(1, columns)


static func hit_card(point: Vector2, rectangles: Array[Rect2]) -> int:
	for index: int in range(rectangles.size()):
		if rectangles[index].has_point(point):
			return index
	return -1


static func draw_service(canvas: CanvasItem, station: Dictionary, active: bool = false, show_title: bool = true, title_alpha: float = 1.0) -> void:
	# Only the four existing service groups receive a flat front-door approach.
	# The existing campus building owns all actual structure and collision.
	var group := group_definition(group_for_station(station))
	if canvas == null or group.is_empty():
		return
	var color := Color("c5b487")
	var threshold := door_outline(station)
	canvas.draw_colored_polygon(threshold, Color(color, 0.76 if active else 0.40))
	canvas.draw_polyline(_closed(threshold), INK, 1.0, false)
	if show_title and title_alpha > 0.01:
		var label := service_label_rect(station)
		canvas.draw_rect(label, Color(INK, 0.86 * title_alpha))
		canvas.draw_string(ThemeDB.fallback_font, label.position + Vector2(8, 13), String(group["purpose"]), HORIZONTAL_ALIGNMENT_CENTER, label.size.x - 16.0, 12, Color(PARCHMENT, title_alpha))
		canvas.draw_string(ThemeDB.fallback_font, label.position + Vector2(8, 27), String(group["title"]), HORIZONTAL_ALIGNMENT_CENTER, label.size.x - 16.0, 10, Color(STONE_LIGHT, title_alpha))


static func draw_card(canvas: CanvasItem, rectangle: Rect2, station: Dictionary, focused: bool = false, key_label: String = "", title_override: String = "", hint_override: String = "") -> void:
	var definition := definition_for(station)
	if canvas == null or definition.is_empty() or rectangle.size.y < 36.0:
		return
	var color := Color(String(definition["color"]))
	canvas.draw_rect(rectangle, INK.lightened(0.08 if focused else 0.0))
	canvas.draw_rect(rectangle, color if focused else STONE, false, 2.0)
	_draw_emblem(canvas, rectangle.position + Vector2(18, 20), String(definition["glyph"]), color)
	var title_width := rectangle.size.x - 42.0
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(34, 24), String(definition["title"]) if title_override.is_empty() else title_override, HORIZONTAL_ALIGNMENT_LEFT, title_width, 12, PARCHMENT)
	if rectangle.size.y >= 56.0:
		canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(10, 47), String(definition["hint"]) if hint_override.is_empty() else hint_override, HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 20.0, 10, STONE_LIGHT)
	if not key_label.is_empty() and rectangle.size.y >= 68.0:
		canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(10, 61), key_label, HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 20.0, 9, color)


static func _draw_emblem(canvas: CanvasItem, center: Vector2, glyph: String, color: Color) -> void:
	match glyph:
		"route":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-6, 5), center + Vector2(-2, -4), center + Vector2(2, 3), center + Vector2(6, -5)]), color, 2.0, false)
		"keys":
			for offset: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 4), Vector2(4, 4)]:
				canvas.draw_rect(Rect2(center + offset - Vector2(2, 2), Vector2(4, 4)), color)
		"mask":
			canvas.draw_colored_polygon(hex_outline(Rect2(center - Vector2(7, 6), Vector2(14, 12))), color)
			canvas.draw_rect(Rect2(center + Vector2(-4, -2), Vector2(2, 2)), INK)
			canvas.draw_rect(Rect2(center + Vector2(2, -2), Vector2(2, 2)), INK)
		"weave":
			canvas.draw_polyline(_closed(hex_outline(Rect2(center - Vector2(7, 6), Vector2(14, 12)))), color, 1.0, false)
			canvas.draw_line(center + Vector2(-5, -4), center + Vector2(5, 4), color, 2.0)
			canvas.draw_line(center + Vector2(5, -4), center + Vector2(-5, 4), color, 2.0)
		"scroll":
			canvas.draw_rect(Rect2(center - Vector2(5, 7), Vector2(10, 14)), color, false, 2.0)
			canvas.draw_line(center + Vector2(-2, -2), center + Vector2(3, -2), color)
			canvas.draw_line(center + Vector2(-2, 2), center + Vector2(3, 2), color)
		"hearth":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(6, 4), center + Vector2(0, 7), center + Vector2(-6, 4)]), color)
		_:
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-6, 7), center + Vector2(-6, -6), center + Vector2(6, -6), center + Vector2(6, 7)]), color, 2.0, false)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var output := points.duplicate()
	if not output.is_empty():
		output.append(output[0])
	return output

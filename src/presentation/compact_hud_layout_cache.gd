extends RefCounted


const BindingLabels = preload("res://src/presentation/spell_binding_labels.gd")
const BINDING_ACTIONS := [&"spell_1", &"spell_2", &"spell_3", &"spell_4", &"spell_layer_ctrl", &"spell_layer_alt"]
const MAX_TEXT_METRICS := 32
const MAX_TEXT_LENGTH := 128

var binding_builds := 0
var text_measurements := 0
var layout_builds := 0
var _bindings: Dictionary = {}
var _text_metrics: Dictionary = {}
var _font: Font
var _font_revision := 0
var _layout_key: Array = []
var _layout: Dictionary = {}


func clear() -> void:
	_bindings.clear()
	_text_metrics.clear()
	_layout_key.clear()
	_layout = {}
	if _font != null and _font.changed.is_connected(_font_changed):
		_font.changed.disconnect(_font_changed)
	_font = null
	_font_revision += 1


func font_revision(font: Font) -> int:
	if font != _font:
		if _font != null and _font.changed.is_connected(_font_changed):
			_font.changed.disconnect(_font_changed)
		_font = font
		if _font != null: _font.changed.connect(_font_changed)
		_font_changed()
	return _font_revision


func _font_changed() -> void:
	# Font identity alone does not catch in-place fallback, size or spacing edits.
	_text_metrics.clear()
	_font_revision += 1


func text_width(role: StringName, label: String, size: int, font: Font = null) -> float:
	if font == null: font = ThemeDB.fallback_font
	font_revision(font)
	var row: Dictionary = _text_metrics.get(role, {})
	if not row.is_empty() and row.text == label and row.font_size == size:
		return float(row.width)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_measurements += 1
	# One current value per role, with finite fallback for arbitrary callers.
	if label.length() <= MAX_TEXT_LENGTH and (_text_metrics.has(role) or _text_metrics.size() < MAX_TEXT_METRICS):
		_text_metrics[role] = {"text": label, "font_size": size, "width": width}
	return width


func binding_label(action: StringName, preferences: PlayerPreferences) -> String:
	if preferences == null: return ""
	if action not in BINDING_ACTIONS: return BindingLabels.action_label(action, preferences)
	var controller: Variant = preferences.controller_bindings.get(action)
	var kind: Variant = controller.get("kind") if controller is Dictionary else null
	var index: Variant = controller.get("index") if controller is Dictionary else null
	var direction: Variant = controller.get("direction") if controller is Dictionary else null
	# Types matter: malformed floating-point pad indices must stay unbound.
	var key := [preferences.prompt_device, int(preferences.keyboard_bindings.get(action, 0)), int(preferences.mouse_bindings.get(action, 0)),
		typeof(controller), kind, typeof(kind), index, typeof(index), direction, typeof(direction)]
	var row: Dictionary = _bindings.get(action, {})
	if not row.is_empty() and row.key == key: return String(row.label)
	var label := BindingLabels.action_label(action, preferences)
	_bindings[action] = {"key": key, "label": label}
	binding_builds += 1
	return label


func frame_layout(viewport: Vector2, authored: Dictionary, session_lines: int, layer_width: float) -> Dictionary:
	var margin := float(authored.get("margin", 16))
	var header_height := float(authored.get("header_height", 34))
	var header_width := float(authored.get("header_width", 312))
	var session_width := float(authored.get("session_width", 248))
	var resource_width := float(authored.get("resource_width", 270))
	var resource_height := float(authored.get("resource_height", 118))
	var cell_width := float(authored.get("spell_cell_width", 142))
	var cell_height := float(authored.get("spell_cell_height", 70))
	var gap := float(authored.get("spell_cell_gap", 6))
	var line_count := clampi(session_lines, 1, 6)
	var key := [viewport, margin, header_height, header_width, session_width, resource_width, resource_height, cell_width, cell_height, gap, line_count, layer_width]
	if _layout_key == key: return _layout
	var spell_width := cell_width * PlayerState.SPELL_BUTTON_COUNT + gap * (PlayerState.SPELL_BUTTON_COUNT - 1)
	var columns := 2 if spell_width + resource_width + margin * 3 > viewport.x else 4
	spell_width = cell_width * columns + gap * (columns - 1)
	var rows := ceili(float(PlayerState.SPELL_BUTTON_COUNT) / columns)
	var start := Vector2(viewport.x - margin - spell_width, viewport.y - margin - cell_height * rows - gap * (rows - 1))
	var spells: Array[Rect2] = []
	for button: int in PlayerState.SPELL_BUTTON_COUNT:
		spells.append(Rect2(start + Vector2(float(button % columns) * (cell_width + gap), floorf(float(button) / columns) * (cell_height + gap)), Vector2(cell_width, cell_height)))
	spells.make_read_only()
	var session := Rect2(viewport.x - margin - session_width, margin, session_width, header_height + (line_count - 1) * 14)
	var tab := Rect2(start + Vector2(0, -24), Vector2(layer_width, 20))
	_layout = {"header": Rect2(margin, margin, header_width, header_height), "session": session,
		"feedback": Rect2(session.position + Vector2(0, session.size.y + 4), Vector2(session_width, 24)),
		"resources": Rect2(margin, viewport.y - margin - resource_height, resource_width, resource_height),
		"layer_tab": tab, "cast_cue": Rect2(tab.position + Vector2(layer_width + gap, 0), Vector2(spell_width - layer_width - gap, 20)),
		"spell_rectangles": spells, "spell_columns": columns}
	_layout.make_read_only()
	_layout_key = key
	layout_builds += 1
	return _layout

extends Control

const Model = preload("res://viewer_model.gd")
const INK := Color("111a20")
const PANEL := Color("1f2b30")
const TEXT := Color("efe2bd")
const MUTED := Color("a9b7b1")
const BRASS := Color("b79759")
var model: RefCounted
var action := "idle"
var direction := 0
var frame := 0
var zoom := 2
var show_directions := false
var contact_sheet := false


func refresh() -> void:
	if contact_sheet:
		custom_minimum_size = Vector2(2520, 1190)
	elif show_directions:
		custom_minimum_size = Vector2(118 + 8 * (96 * zoom + 18), 48 + 3 * (96 * zoom + 46))
	else:
		custom_minimum_size = Vector2(3 * (96 * zoom + 60) + 48, 96 * zoom + 155)
	queue_redraw()


func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	draw_rect(Rect2(Vector2.ZERO, size.max(custom_minimum_size)), INK)
	if model == null:
		return
	if contact_sheet:
		_draw_contact_sheet()
	elif show_directions:
		_draw_direction_grid()
	else:
		_draw_comparison()


func _label(position: Vector2, text: String, color: Color = TEXT, font_size: int = 16) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _sprite(size_name: String, row: String, column: int, feet: Vector2, scale_value: int) -> void:
	var destination := Rect2(feet - Model.PIVOT * scale_value, Vector2(Model.CELL) * scale_value)
	draw_rect(destination, PANEL)
	for y: int in range(0, 96, 16):
		for x: int in range(0, 96, 16):
			if (x + y) % 32 == 0:
				draw_rect(Rect2(destination.position + Vector2(x, y) * scale_value, Vector2(16, 16) * scale_value), Color("243338"))
	draw_line(Vector2(destination.position.x, feet.y), Vector2(destination.end.x, feet.y), BRASS, 1)
	if model.textures.has(size_name):
		draw_texture_rect_region(model.textures[size_name], destination, Model.source_region(row, column))
	else:
		_label(destination.position + Vector2(8, 30), "No sheet", MUTED, 14)
	draw_line(feet + Vector2(-4, 0), feet + Vector2(4, 0), BRASS, 1)


func _draw_comparison() -> void:
	var rows: Array = Model.sequence(action)
	var row := String(rows[posmod(frame, rows.size())])
	var width := float(96 * zoom + 60)
	var ground := float(82 + 84 * zoom)
	_label(Vector2(24, 25), "SAME GROUND BASELINE / %dx / %s" % [zoom, Model.DIRECTION_LABELS[direction]], BRASS, 16)
	for index: int in range(3):
		var origin := Vector2(24 + width * index, 53)
		_label(origin, String(Model.SIZES[index]).to_upper(), TEXT, 20)
		var feet := Vector2(origin.x + 48 * zoom, ground)
		_sprite(Model.SIZES[index], row, direction, feet, zoom)
		_label(Vector2(origin.x, ground + 32), "96px cell / pivot (48, 84)", MUTED, 14)


func _draw_direction_grid() -> void:
	var rows: Array = Model.sequence(action)
	var row := String(rows[posmod(frame, rows.size())])
	var width := 96 * zoom + 18
	var height := 96 * zoom + 46
	for column: int in range(8):
		_label(Vector2(118 + column * width, 25), Model.DIRECTION_LABELS[column], BRASS)
	for index: int in range(3):
		var ground := 48 + index * height + 84 * zoom
		_label(Vector2(12, ground - 20), String(Model.SIZES[index]).capitalize(), TEXT, 18)
		for column: int in range(8):
			_sprite(Model.SIZES[index], row, column, Vector2(118 + column * width + 48 * zoom, ground), zoom)


func _draw_contact_sheet() -> void:
	_label(Vector2(18, 26), "FLUX / NEUTRAL BODY SOURCE CONTACT SHEET / native 1x pixels", TEXT, 22)
	_label(Vector2(18, 49), "All 10 source rows, all 8 directions, unchanged 96px cells and shared pivot. Aliases are not extra animations.", MUTED, 16)
	for size_index: int in range(3):
		var start_x := 118 + size_index * 800
		_label(Vector2(start_x, 79), String(Model.SIZES[size_index]).to_upper(), BRASS, 20)
		for column: int in range(8):
			_label(Vector2(start_x + column * 96, 99), Model.DIRECTION_LABELS[column], MUTED, 13)
		for row_index: int in range(10):
			var ground := 110 + row_index * 107 + 84
			if size_index == 0:
				_label(Vector2(12, ground - 25), Model.ROWS[row_index], TEXT, 15)
			for column: int in range(8):
				_sprite(Model.SIZES[size_index], Model.ROWS[row_index], column, Vector2(start_x + column * 96 + 48, ground), 1)

class_name WellspringMapPanel
extends RefCounted
## One compact overview; destination labels live in the list, not twice on the map.

const Model = preload("res://src/app/wellspring_map_model.gd")
const DistrictStyle = preload("res://src/presentation/wellspring_district_style.gd")
const PAGE_SIZE := 8
const ROW_HEIGHT := 35.0
const INK := Color("10201ff5")
const PAPER := Color("eee0b8")
const MUTED := Color("b8c1af")
const ACCENT := Color("83d8cf")
var model := Model.new()
var is_open: bool:
	get: return model.is_open
var _stick_latched := false
var detail_page := 0
var _detail_selection := -1


func open(layout: SanctumCampusLayout, position_fixed: Vector2i, availability: Dictionary = {}) -> bool:
	_stick_latched = false
	return model.configure(layout) and model.open(position_fixed, availability)


func close() -> void:
	model.close()
	_stick_latched = false


func update_position(position_fixed: Vector2i) -> void:
	model.update_position(position_fixed)


func set_location_visible(value: bool) -> void:
	model.location_visible = value


func set_availability(value: Dictionary) -> void:
	model.set_availability(value)


func set_message(text: String) -> void:
	model.message = text.replace("\n", " ").strip_edges()


static func geometry(viewport: Vector2) -> Dictionary:
	var size := Vector2(minf(1120, viewport.x - 48), minf(640, viewport.y - 48))
	var panel := Rect2((viewport - size) * 0.5, size)
	var split := minf(floorf(size.x * 0.62),size.x-256)
	var page_size := clampi(floori((size.y-210)/ROW_HEIGHT),1,PAGE_SIZE)
	var map := Rect2(panel.position + Vector2(18, 76), Vector2(split - 34, size.y - 180))
	var list := Rect2(panel.position + Vector2(split, 76), Vector2(size.x - split - 18, page_size * ROW_HEIGHT))
	return {"panel": panel, "map": map, "list": list,"page_size":page_size,
		"close": Rect2(Vector2(panel.end.x - 92, panel.position.y + 14), Vector2(74, 32)),
		"previous": Rect2(list.position + Vector2(0, list.size.y + 6), Vector2(72, 28)),
		"next": Rect2(Vector2(list.end.x - 72, list.end.y + 6), Vector2(72, 28)),
		"detail": Rect2(Vector2(panel.position.x + 18, panel.end.y - 80), Vector2(size.x - 200, 45)),
		"travel": Rect2(Vector2(panel.end.x - 166, panel.end.y - 78), Vector2(148, 42))}


static func row_rect(index: int, geo: Dictionary) -> Rect2:
	var list: Rect2 = geo.list
	return Rect2(list.position + Vector2(0, index * ROW_HEIGHT), Vector2(list.size.x, ROW_HEIGHT - 3)) if index >= 0 and index < PAGE_SIZE else Rect2()


func visible_indices(page_size: int = PAGE_SIZE) -> Array[int]:
	var result: Array[int] = []
	var first := model.selected_index / page_size * page_size
	for index: int in range(first, mini(first + page_size, model.destinations.size())): result.append(index)
	return result


func map_rect(geo: Dictionary) -> Rect2:
	var available: Rect2 = geo.map
	if model.world_bounds.size.x <= 0 or model.world_bounds.size.y <= 0: return Rect2()
	var scale := minf(available.size.x / model.world_bounds.size.x, available.size.y / model.world_bounds.size.y)
	var size := model.world_bounds.size * scale
	return Rect2(available.position + (available.size - size) * 0.5, size)


func project(point: Vector2, geo: Dictionary) -> Vector2:
	var rect := map_rect(geo)
	return rect.position + (point - model.world_bounds.position) / model.world_bounds.size * rect.size


func handle_input(event: InputEvent, viewport: Vector2) -> Dictionary:
	if not is_open or event == null: return {}
	var move := 0
	var activate := false
	var page_size := int(geometry(viewport).page_size)
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match key:
			KEY_C: detail_page+=1; return {}
			KEY_ESCAPE, KEY_M: return {"action": "close"}
			KEY_UP, KEY_W: move = -1
			KEY_DOWN, KEY_S: move = 1
			KEY_TAB: move = -1 if event.shift_pressed else 1
			KEY_LEFT, KEY_PAGEUP: move = -page_size
			KEY_RIGHT, KEY_PAGEDOWN: move = page_size
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: activate = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_Y: detail_page+=1; return {}
			JOY_BUTTON_B, JOY_BUTTON_BACK: return {"action": "close"}
			JOY_BUTTON_DPAD_UP: move = -1
			JOY_BUTTON_DPAD_DOWN: move = 1
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER: move = -page_size
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER: move = page_size
			JOY_BUTTON_A: activate = true
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		if absf(event.axis_value) < 0.35: _stick_latched = false
		elif absf(event.axis_value) > 0.65 and not _stick_latched:
			_stick_latched = true
			move = 1 if event.axis_value > 0 else -1
	elif event is InputEventMouseButton and event.pressed:
		var geo := geometry(viewport)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: move = -1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: move = 1
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if (geo.detail as Rect2).has_point(event.position): detail_page+=1; return {}
			if (geo.close as Rect2).has_point(event.position): return {"action": "close"}
			if (geo.travel as Rect2).has_point(event.position): activate = true
			elif (geo.previous as Rect2).has_point(event.position): move = -page_size
			elif (geo.next as Rect2).has_point(event.position): move = page_size
			else:
				var indices := visible_indices(page_size)
				for offset: int in indices.size():
					if row_rect(offset, geo).has_point(event.position):
						model.select(indices[offset])
						return {}
				var nearest := 14.0 * 14.0
				var chosen := -1
				for index: int in model.destinations.size():
					if map_rect(geo).size.x<250 and index!=model.selected_index: continue
					var distance := project(model.destination_position(index), geo).distance_squared_to(event.position)
					if distance < nearest:
						nearest = distance
						chosen = index
				if chosen >= 0: model.select(chosen)
	if move != 0: model.move(move)
	return model.request_travel() if activate else {}


func draw(canvas: CanvasItem, font: Font, viewport: Vector2) -> void:
	if not is_open or canvas == null or font == null: return
	var geo := geometry(viewport)
	var panel: Rect2 = geo.panel
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport), Color("07110e88"))
	canvas.draw_rect(panel, INK)
	canvas.draw_rect(panel, Color("567d71"), false, 1)
	_text(canvas, font, panel.position + Vector2(18, 32), "WELLSPRING", 22, PAPER)
	_text(canvas, font, panel.position + Vector2(18, 56), "You are at " + model.current_location(), 14, MUTED)
	_button(canvas, font, geo.close, "Close", false)
	_draw_map(canvas, font, geo)
	var page_size := int(geo.page_size)
	var indices := visible_indices(page_size)
	for offset: int in indices.size():
		var index := indices[offset]
		var rect := row_rect(offset, geo)
		var selected := index == model.selected_index
		canvas.draw_rect(rect, Color("2c4a40") if selected else Color("192e29"))
		_text(canvas, font, rect.position + Vector2(10, 22), "%02d  %s" % [index + 1, String(model.destinations[index].label)], 14, PAPER if selected else MUTED)
	if model.destinations.size() > page_size:
		_button(canvas, font, geo.previous, "<", false)
		_button(canvas, font, geo.next, ">", false)
		var list: Rect2 = geo.list
		_text(canvas, font, Vector2(list.position.x + 92, list.end.y + 26), "%d / %d" % [model.selected_index / page_size + 1, ceili(float(model.destinations.size()) / page_size)], 13, MUTED)
	var detail: Rect2 = geo.detail
	var details := detail_projection(font,detail)
	for index: int in details.lines.size(): _text(canvas,font,detail.position+Vector2(0,16+index*20),details.lines[index],14,ACCENT if not model.message.is_empty() else PAPER)
	_button(canvas, font, geo.travel, "Travel  [Enter / A]", bool(model.availability.enabled))
	_text(canvas,font,Vector2(panel.position.x+18,panel.end.y-13),"Details %d/%d: C / Y or click text · Enter / A travel" % [int(details.page)+1,int(details.pages)],12,MUTED)


func detail_projection(font: Font,rect: Rect2) -> Dictionary:
	if _detail_selection!=model.selected_index:
		_detail_selection=model.selected_index
		detail_page=0
	var lines: Array[String]=[]
	for paragraph: String in model.selected_context(): lines.append_array(wrap_text(paragraph,font,14,rect.size.x))
	var count := maxi(1,floori(rect.size.y/20))
	var pages := maxi(1,ceili(float(lines.size())/count))
	var page := posmod(detail_page,pages)
	return {"lines":lines.slice(page*count,mini(lines.size(),(page+1)*count)),"page":page,"pages":pages,"all_lines":lines}



func _draw_map(canvas: CanvasItem, font: Font, geo: Dictionary) -> void:
	var map := map_rect(geo)
	canvas.draw_rect(map, Color("152a26"))
	for district: Dictionary in model.districts:
		var style := DistrictStyle.style_for(DistrictStyle.environment_for(district))
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(district.get("bounds", [])))
		var rect := Rect2(project(bounds.position, geo), project(bounds.end, geo) - project(bounds.position, geo))
		canvas.draw_rect(rect, style.ground)
		canvas.draw_rect(rect, style.edge, false, 1)
	var route := model.selected_route()
	var selected_connections: Array=route.get("connection_ids",[])
	for connection: Dictionary in model.connections:
		var points := PackedVector2Array()
		for point: Array in connection.get("points", []): points.append(project(Vector2(float(point[0]), float(point[1])), geo))
		if points.size() >= 2:
			var selected := selected_connections.has(String(connection.id))
			canvas.draw_polyline(points,INK,6 if selected else 3)
			canvas.draw_polyline(points,ACCENT if selected else Color("9ca788"),3 if selected else 1)
			if selected:
				# End caps distinguish selected links without relying on color.
				canvas.draw_circle(points[0],3,PAPER)
				canvas.draw_circle(points[-1],3,PAPER)
	for building: Dictionary in model.buildings:
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(building.get("bounds", [])))
		if bounds.has_area(): canvas.draw_rect(Rect2(project(bounds.position, geo), project(bounds.end, geo) - project(bounds.position, geo)), Color("738579"))
	for index: int in model.destinations.size():
		if map.size.x<250 and index!=model.selected_index: continue
		var point := project(model.destination_position(index), geo)
		var selected := index == model.selected_index
		canvas.draw_circle(point, 11, ACCENT if selected else Color("536b52"))
		canvas.draw_arc(point, 11, 0, TAU, 24, PAPER if selected else MUTED, 1)
		var label := str(index + 1)
		_text(canvas, font, point + Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5, 4), label, 12, INK if selected else PAPER)
	if model.location_visible and model.world_bounds.has_point(model.player_position):
		var point := project(model.player_position, geo)
		# A diamond remains distinct from every destination, without color alone.
		canvas.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -6), point + Vector2(6, 0), point + Vector2(0, 6), point + Vector2(-6, 0)]), Color.WHITE)
		canvas.draw_polyline(PackedVector2Array([point + Vector2(0, -6), point + Vector2(6, 0), point + Vector2(0, 6), point + Vector2(-6, 0), point + Vector2(0, -6)]), INK, 1)


static func wrap_text(text: String, font: Font, size: int, width: float) -> Array[String]:
	var result: Array[String] = []
	var line := ""
	for word: String in text.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if not line.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			result.append(line)
			line = word
		else: line = candidate
	if not line.is_empty(): result.append(line)
	return result


static func _text(canvas: CanvasItem, font: Font, point: Vector2, text: String, size: int, color: Color) -> void:
	canvas.draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func _button(canvas: CanvasItem, font: Font, rect: Rect2, label: String, selected: bool) -> void:
	canvas.draw_rect(rect, Color("355d4b") if selected else Color("253932"))
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_text(canvas, font, rect.position + Vector2((rect.size.x - width) * 0.5, (rect.size.y + 10) * 0.5), label, 13, PAPER)

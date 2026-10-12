extends FluxTestSuite

const MapModel = preload("res://src/app/wellspring_map_model.gd")
const MapPanel = preload("res://src/presentation/wellspring_map_panel.gd")
const Compendium = preload("res://src/presentation/player_compendium.gd")
const LAYOUT_PATH := "res://content/maps/sanctum_campus_g2_v1.json"


func run() -> int:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(LAYOUT_PATH), "map uses the validated expanded campus")
	if layout.content_hash.is_empty(): return finish("wellspring-map")
	_test_projection(layout)
	_test_input(layout)
	_test_layout(layout)
	_test_compendium_request()
	_test_selected_route(layout)
	return finish("wellspring-map")


func _test_selected_route(layout: SanctumCampusLayout) -> void:
	var panel := MapPanel.new()
	check(panel.open(layout,layout.spawn*SimConfig.FIXED_SCALE),"route cues use validated authored world")
	var source := JSON.stringify(layout.data)
	var connection_ids := {}
	for row: Dictionary in layout.data.connections: connection_ids[String(row.id)]=true
	for selected: int in panel.model.destinations.size():
		panel.model.select(selected)
		var route := panel.model.selected_route()
		check(not route.is_empty(),"every actual destination resolves a district connection route")
		for id: String in route.get("connection_ids",[]): check(connection_ids.has(id),"cue highlights only an authored connection")
		var snapshot := route.duplicate(true)
		route.connection_ids.clear()
		equal(panel.model.selected_route(),snapshot,"retained route result is detached")
		for viewport: Vector2 in [Vector2(480,270),Vector2(960,540)]:
			var detail: Rect2=MapPanel.geometry(viewport).detail
			var info := panel.detail_projection(ThemeDB.fallback_font,detail)
			var rendered: Array=[]
			for page: int in int(info.pages):
				var current := panel.detail_projection(ThemeDB.fallback_font,detail)
				rendered.append_array(current.lines)
				for line: String in current.lines: check(ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=detail.size.x,"route advice stays within its real reading width")
				panel.handle_input(_pad(JOY_BUTTON_Y),viewport)
			check(rendered.size()>=info.all_lines.size(),"controller can expose every purpose and route paragraph")
			panel.detail_page=0
	panel.set_location_visible(false)
	check(panel.model.selected_route().is_empty(),"practice scene cannot invent a campus route from local coordinates")
	equal(JSON.stringify(layout.data),source,"route and page interactions cannot edit geometry or travel authority")


func _test_projection(layout: SanctumCampusLayout) -> void:
	var source_before := JSON.stringify(layout.data)
	var model := MapModel.new()
	check(not model.configure(null) and not model.open(Vector2i.ZERO), "missing layout cannot expose a stale map")
	check(model.configure(layout), "map projects validated authored destinations")
	equal(model.destinations, layout.travel_destinations(), "all destination IDs, labels, details and positions come from content")
	check(model.open(layout.spawn * SimConfig.FIXED_SCALE), "map opens at actual fixed-point player location")
	equal(model.player_position, Vector2(layout.spawn), "player marker converts fixed units exactly once")
	equal(model.world_bounds, Rect2(Vector2.ZERO, Vector2(layout.canvas_size)), "overview uses actual canvas rather than the former small campus")
	for index: int in model.destinations.size():
		model.select(index)
		var selected := model.selected_destination()
		var row: Dictionary = layout.travel_destinations()[index]
		equal(selected, row, "every destination is selectable without semantic reconstruction")
		var point := Vector2i(int(row.position[0]), int(row.position[1]))
		model.update_position(point * SimConfig.FIXED_SCALE)
		var area_label := ""
		for area: Dictionary in layout.data.activity_areas:
			if String(area.id) == String(row.area_id): area_label = String(area.label)
		equal(model.current_location(), area_label, "actual arrival point reports its authored activity rather than nearest destination")
		var request := model.request_travel()
		equal(request, {"action": "travel", "destination_id": String(row.id)}, "travel requests only a stable destination ID; root must revalidate")
		selected.label = "modified copy"
		equal(String(model.selected_destination().label), String(row.label), "caller cannot edit the model through a selected-row result")
	model.move(999)
	equal(model.selected_index, model.destinations.size() - 1, "forward navigation cannot overshoot")
	model.move(-999)
	equal(model.selected_index, 0, "backward navigation cannot underflow")
	model.update_position(Vector2i(-1000, -1000))
	equal(model.current_location(), "Outside Wellspring", "other scenes are never labeled as a nearby campus area")
	model.set_availability({"enabled": false, "reason": "Finish the active action before travelling."})
	check(model.request_travel().is_empty(), "blocked travel never returns a dispatchable request")
	equal(model.view().message, "Finish the active action before travelling.", "a refused action remains legible in the map")
	model.set_availability({"enabled": true})
	check(not model.request_travel().is_empty() and model.message.is_empty(), "fresh authority availability clears a stale refusal")
	equal(JSON.stringify(layout.data), source_before, "inspection never edits shared authored world content")
	check(not model.configure(null) and model.destinations.is_empty() and not model.is_open, "failed reconfiguration clears prior destination authority")


func _test_input(layout: SanctumCampusLayout) -> void:
	var panel := MapPanel.new()
	var viewport := Vector2(960, 540)
	check(panel.open(layout, layout.spawn * SimConfig.FIXED_SCALE), "input uses the real campus")
	panel.model.select(0)
	for index: int in panel.model.destinations.size():
		equal(panel.model.selected_index, index, "keyboard reaches every named destination")
		var result := panel.handle_input(_key(KEY_ENTER), viewport)
		equal(String(result.destination_id), String(panel.model.destinations[index].id), "Enter requests only the visibly selected place")
		panel.handle_input(_key(KEY_DOWN), viewport)
	panel.model.select(0)
	for index: int in panel.model.destinations.size():
		equal(panel.model.selected_index, index, "D-pad reaches every named destination")
		equal(String(panel.handle_input(_pad(JOY_BUTTON_A), viewport).destination_id), String(panel.model.destinations[index].id), "A confirms the same selected place")
		panel.handle_input(_pad(JOY_BUTTON_DPAD_DOWN), viewport)
	for size: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
		var geo := MapPanel.geometry(size)
		for index: int in panel.model.destinations.size():
			panel.model.select(index)
			var click := _click(MapPanel.row_rect(index % MapPanel.PAGE_SIZE, geo).get_center())
			check(panel.handle_input(click, size).is_empty(), "selecting a named row never immediately teleports")
			equal(panel.model.selected_index, index, "shared row painting/hit geometry resolves every page")
			panel.model.select((index + 1) % panel.model.destinations.size())
			check(panel.handle_input(_click(panel.project(panel.model.destination_position(index), geo)), size).is_empty(), "a map-pin click only selects")
			equal(panel.model.selected_index, index, "every real projected pin can be selected, including another page")
			equal(String(panel.handle_input(_click((geo.travel as Rect2).get_center()), size).destination_id), String(panel.model.destinations[index].id), "Travel confirms the pointer-selected destination")
		var closed := panel.handle_input(_click((geo.close as Rect2).get_center()), size)
		equal(closed, {"action": "close"}, "visible Close routes one explicit close request")
	panel.model.select(0)
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_Y
	axis.axis_value = 0.9
	panel.handle_input(axis, viewport)
	equal(panel.model.selected_index, 1, "deliberate stick tilt selects once")
	panel.handle_input(axis, viewport)
	equal(panel.model.selected_index, 1, "held stick does not run through destinations")
	axis.axis_value = 0.1
	panel.handle_input(axis, viewport)
	axis.axis_value = 0.9
	panel.handle_input(axis, viewport)
	equal(panel.model.selected_index, 2, "neutral release rearms the stick")
	panel.set_availability({"enabled": false, "reason": "Travel is available in offline Wellspring."})
	check(panel.handle_input(_key(KEY_ENTER), viewport).is_empty() and panel.handle_input(_pad(JOY_BUTTON_A), viewport).is_empty(), "both confirm paths obey current availability")
	panel.set_availability({"enabled": true})
	panel.set_message("The arrival point is occupied.")
	panel.set_availability({"enabled": true})
	equal(panel.model.message, "The arrival point is occupied.", "ordinary draw/input eligibility refresh does not erase destination-specific feedback")
	panel.model.move(-1)
	equal(panel.model.message, "", "selecting another place clears the prior target-specific refusal")
	var released := _key(KEY_ENTER)
	released.pressed = false
	check(panel.handle_input(released, viewport).is_empty(), "key release cannot confirm")
	var echo := _key(KEY_ENTER)
	echo.echo = true
	check(panel.handle_input(echo, viewport).is_empty(), "keyboard repeat cannot confirm")
	panel.close()
	check(panel.handle_input(_key(KEY_ENTER), viewport).is_empty(), "closed map cannot dispatch travel")
	check(panel.open(layout, layout.spawn * SimConfig.FIXED_SCALE), "overview remains inspectable from an isolated practice scene")
	panel.set_location_visible(false)
	equal(panel.model.current_location(), "Away from Wellspring", "Range-local coordinates cannot impersonate a campus location")
	panel.update_position(layout.spawn * SimConfig.FIXED_SCALE)
	equal(panel.model.current_location(), "Away from Wellspring", "routine marker updates do not undo the scene boundary")
	panel.set_location_visible(true)
	check(panel.model.current_location() != "Away from Wellspring", "return to the campus restores actual area naming")


func _test_layout(layout: SanctumCampusLayout) -> void:
	var panel := MapPanel.new()
	check(panel.open(layout, layout.spawn * SimConfig.FIXED_SCALE), "layout uses all actual destination copy")
	var font := ThemeDB.fallback_font
	for viewport: Vector2 in [Vector2(960, 540), Vector2(1024, 768), Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080)]:
		var geo := MapPanel.geometry(viewport)
		var bounds: Rect2 = geo.panel
		check(Rect2(Vector2.ZERO, viewport).encloses(bounds), "map modal fits supported viewport")
		for key: String in ["map", "list", "close", "previous", "next", "detail", "travel"]:
			check(bounds.encloses(geo[key]), "all map sections and actual targets remain inside modal")
		check(not (geo.detail as Rect2).intersects(geo.travel), "context and travel remain separate")
		check(not (geo.next as Rect2).intersects(geo.detail), "pagination clears destination context")
		var projected := panel.map_rect(geo)
		check((geo.map as Rect2).encloses(projected), "overview preserves canvas aspect ratio inside its column")
		check(absf(projected.size.x / projected.size.y - float(layout.canvas_size.x) / layout.canvas_size.y) < 0.0001, "world geometry is uniformly projected, never stretched")
		for index: int in panel.model.destinations.size():
			var row: Dictionary = panel.model.destinations[index]
			var rectangle := MapPanel.row_rect(index % MapPanel.PAGE_SIZE, geo)
			var text := "%02d  %s" % [index + 1, String(row.label)]
			var glyphs := Rect2(rectangle.position + Vector2(10, 22 - font.get_ascent(14)), font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14))
			check(rectangle.encloses(glyphs), "all twelve complete numbered names fit real14px font; no abbreviations")
			var detail: Rect2 = geo.detail
			var lines := MapPanel.wrap_text(String(row.detail), font, 14, detail.size.x)
			equal(" ".join(lines), String(row.detail), "selected context retains every authored word")
			for line: int in lines.size():
				var detail_glyphs := Rect2(detail.position + Vector2(0, 16 + line * 20 - font.get_ascent(14)), font.get_string_size(lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, 14))
				check(detail.encloses(detail_glyphs), "each complete contextual detail clears footer and controls at actual font metrics")
			var pin := panel.project(panel.model.destination_position(index), geo)
			check(projected.encloses(Rect2(pin - Vector2.ONE * 11, Vector2.ONE * 22)), "pin contour stays within the authored map frame")
			for previous: int in index:
				check(pin.distance_to(panel.project(panel.model.destination_position(previous), geo)) >= 22, "numbered pins do not obscure each other at the smallest viewport")
		var travel: Rect2 = geo.travel
		check(font.get_string_size("Travel  [Enter / A]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x <= travel.size.x - 12, "travel action retains full keyboard/controller label")


func _test_compendium_request() -> void:
	var compendium := Compendium.new()
	var prefs := PlayerPreferences.new()
	var state := PlayerState.new(1)
	var before := state.canonical_values()
	var font := ThemeDB.fallback_font
	var request_events: Array[InputEvent] = [_key(KEY_M), _pad(JOY_BUTTON_LEFT_STICK), _click(Compendium.MAP_RECT.get_center())]
	for event: InputEvent in request_events:
		compendium.open_panel(Compendium.MOVEMENT, prefs, state)
		compendium.handle_event(event, font, Compendium.MAP_RECT.get_center())
		check(compendium.is_open and compendium.consume_map_request(), "Compendium requests navigation without executing or replacing its pure reader")
		check(not compendium.consume_map_request(), "map routing request is consumed exactly once")
		equal(state.canonical_values(), before, "map affordance never moves, equips or spends")
	check(not Compendium.MAP_RECT.intersects(Compendium.CLOSE_RECT), "map header action clears existing Close")
	check(font.get_string_size("Map  [M / L3]", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= Compendium.MAP_RECT.size.x - 24, "map entry fits the real Compendium button font")
	compendium.handle_event(_key(KEY_M), font)
	compendium.close_panel()
	check(not compendium.consume_map_request(), "closing a guide cannot leave a stale routing request")


func _key(code: int) -> InputEventKey:
	var result := InputEventKey.new()
	result.physical_keycode = code
	result.pressed = true
	return result


func _pad(button: int) -> InputEventJoypadButton:
	var result := InputEventJoypadButton.new()
	result.button_index = button
	result.pressed = true
	return result


func _click(point: Vector2) -> InputEventMouseButton:
	var result := InputEventMouseButton.new()
	result.position = point
	result.button_index = MOUSE_BUTTON_LEFT
	result.pressed = true
	return result

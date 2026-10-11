class_name CharacterSelectionGrid
extends RefCounted


const Model = preload("res://src/app/character_selection_model.gd")
const Text = preload("res://src/presentation/player_compendium.gd")
const PANEL := Rect2(48, 44, 1184, 632)
const CLOSE_RECT := Rect2(1116, 64, 92, 32)
const PREVIOUS_PAGE := Rect2(72, 112, 112, 32)
const NEXT_PAGE := Rect2(696, 112, 124, 32)
const PREVIOUS_DETAIL := Rect2(852, 582, 104, 32)
const NEXT_DETAIL := Rect2(1104, 582, 104, 32)
const SELECT_RECT := Rect2(852, 620, 356, 32)
const PREVIOUS_FACING := Rect2(864, 144, 44, 32)
const NEXT_FACING := Rect2(1152, 144, 44, 32)
const FACING_LABELS := ["S 0 / 360", "SE 45", "E 90", "NE 135", "N 180", "NW 225", "W 270", "SW 315"]
const GRID_ORIGIN := Vector2(72, 182)
const CARD_SIZE := Vector2(100, 130)
const COLUMN_STRIDE := 108.0
const ROW_STRIDE := 134.0
const DETAIL_WIDTH := 356.0
const DETAIL_LINES := 12
const FONT_SIZE := 16
const LINE_HEIGHT := 22
const INK := Color("141a17f5")
const PAPER := Color("eee0b8")
const MUTED := Color("b7b69e")
const BRASS := Color("b79351")

var model := Model.new()
var is_open := false
var detail_page := 0
var last_error := ""
var _presenter: Object
var _preview_state := PlayerState.new(0)
var _detail_key := ""
var _detail_lines: Array[String] = []
var _portrait_cache: Dictionary = {}
var _portrait_generation: int = -1
var preview_direction := 0


func configure(champions: ChampionCatalog, roster: ChampionRosterPlan, presenter: Object = null) -> bool:
	# Drop the previous modal and all borrowed visual state before validation.
	# A failed reload must be closed, not an old panel over invalid catalogs.
	close_panel()
	_presenter = null
	_portrait_cache.clear()
	_portrait_generation = -1
	_reset_detail()
	_detail_lines.clear()
	_preview_state.facing_x = 0
	_preview_state.facing_y = 1000
	if not model.configure(champions, roster):
		last_error = model.last_error
		return false
	_presenter = presenter
	last_error = ""
	return true


func open_panel(current_champion_id: String) -> void:
	model.open_for(current_champion_id)
	is_open = model.last_error.is_empty() and not model.races().is_empty()
	_reset_detail()


func close_panel() -> void:
	is_open = false


func confirm_equipped(champion_id: String) -> void:
	model.confirm_equipped(champion_id)


func refuse(reason: String) -> void:
	model.refuse(reason)


func card_rect(race: int, character: int) -> Rect2:
	var offset := model.visible_character_indices(race).find(character)
	if race not in model.visible_race_indices() or offset < 0:
		return Rect2()
	return Rect2(GRID_ORIGIN + Vector2((race % Model.COLUMNS_PER_PAGE) * COLUMN_STRIDE, offset * ROW_STRIDE), CARD_SIZE)


func cell_at(pointer: Vector2) -> Vector2i:
	for race: int in model.visible_race_indices():
		for character: int in model.visible_character_indices(race):
			if card_rect(race, character).has_point(pointer):
				return Vector2i(race, character)
	return Vector2i(-1, -1)


# Return one exact wire intent, never an authority mutation. Caller consumes all
# events while is_open (including releases), sends neutral gameplay commands,
# and maintains its existing close guard. Pointer uses logical 1280x720 space.
func handle_event(event: InputEvent, font: Font, pointer: Vector2 = Vector2(-1, -1)) -> int:
	if not is_open:
		return 0
	var before := Vector2i(model.race_index, model.character_index)
	var choose := false
	if event is InputEventMouseMotion:
		var cell := cell_at(pointer)
		if cell.x >= 0:
			model.select_cell(cell.x, cell.y)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				close_panel()
			KEY_LEFT:
				model.move_selection(0, -1)
			KEY_RIGHT:
				model.move_selection(0, 1)
			KEY_UP:
				model.move_selection(-1, 0)
			KEY_DOWN:
				model.move_selection(1, 0)
			KEY_PAGEUP:
				model.change_race_page(-1)
			KEY_PAGEDOWN:
				model.change_race_page(1)
			KEY_HOME:
				change_detail_page(-1, font)
			KEY_END:
				change_detail_page(1, font)
			KEY_BRACKETLEFT:
				change_preview_direction(-1)
			KEY_BRACKETRIGHT:
				change_preview_direction(1)
			KEY_ENTER, KEY_KP_ENTER:
				choose = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				close_panel()
			JOY_BUTTON_DPAD_LEFT:
				model.move_selection(0, -1)
			JOY_BUTTON_DPAD_RIGHT:
				model.move_selection(0, 1)
			JOY_BUTTON_DPAD_UP:
				model.move_selection(-1, 0)
			JOY_BUTTON_DPAD_DOWN:
				model.move_selection(1, 0)
			JOY_BUTTON_LEFT_SHOULDER:
				model.change_race_page(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				model.change_race_page(1)
			JOY_BUTTON_X:
				change_detail_page(-1, font)
			JOY_BUTTON_Y:
				change_detail_page(1, font)
			JOY_BUTTON_LEFT_STICK:
				change_preview_direction(-1)
			JOY_BUTTON_RIGHT_STICK:
				change_preview_direction(1)
			JOY_BUTTON_A:
				choose = true
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var delta := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			if pointer.x >= 844:
				change_detail_page(delta, font)
			else:
				model.move_selection(delta, 0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if CLOSE_RECT.has_point(pointer):
				close_panel()
			elif PREVIOUS_PAGE.has_point(pointer):
				model.change_race_page(-1)
			elif NEXT_PAGE.has_point(pointer):
				model.change_race_page(1)
			elif PREVIOUS_DETAIL.has_point(pointer):
				change_detail_page(-1, font)
			elif NEXT_DETAIL.has_point(pointer):
				change_detail_page(1, font)
			elif PREVIOUS_FACING.has_point(pointer):
				change_preview_direction(-1)
			elif NEXT_FACING.has_point(pointer):
				change_preview_direction(1)
			elif SELECT_RECT.has_point(pointer):
				choose = true
			else:
				var cell := cell_at(pointer)
				if cell.x >= 0:
					model.select_cell(cell.x, cell.y)
					choose = true
	if before != Vector2i(model.race_index, model.character_index):
		_reset_detail()
	return model.request_selection() if choose else 0


func detail_pages(font: Font) -> int:
	_ensure_detail(font)
	return maxi(1, ceili(float(_detail_lines.size()) / DETAIL_LINES))


func change_detail_page(delta: int, font: Font) -> void:
	detail_page = clampi(detail_page + delta, 0, detail_pages(font) - 1)


func visible_detail_lines(font: Font) -> Array[String]:
	_ensure_detail(font)
	detail_page = clampi(detail_page, 0, detail_pages(font) - 1)
	return _detail_lines.slice(detail_page * DETAIL_LINES, (detail_page + 1) * DETAIL_LINES)


func _sync_portrait_generation() -> void:
	# Detail readers also call this before their early cache return. A validated
	# presenter reload must not require a portrait draw to refresh its art status.
	if is_instance_valid(_presenter) and _presenter.has_method("portrait_revision"):
		var generation := int(_presenter.call("portrait_revision"))
		if generation != _portrait_generation:
			_portrait_cache.clear()
			_portrait_generation = generation
			_detail_key = ""


func portrait_source(champion_id: String) -> Dictionary:
	_sync_portrait_generation()
	if _portrait_cache.has(champion_id):
		return _portrait_cache[champion_id]
	var result: Dictionary = {}
	if is_instance_valid(_presenter) and _presenter.has_method("can_present") and bool(_presenter.call("can_present", champion_id)):
		if _presenter.has_method("portrait_frame"):
			result = _presenter.call("portrait_frame", champion_id)
			_portrait_cache[champion_id] = result
			return result
		var texture: Texture2D = _presenter.call("texture_for_champion", champion_id)
		var region: Rect2 = _presenter.call("source_region_for_animation_state", champion_id, _preview_state, "grounded")
		if texture != null and region.has_area():
			result = {"texture": texture, "region": region}
			if _presenter.has_method("recipe"):
				var recipe: Dictionary = _presenter.call("recipe", champion_id)
				result["temporary_body_template"] = bool(recipe.get("temporary_body_template", false))
				result["template_source_id"] = String(recipe.get("template_source_id", ""))
	_portrait_cache[champion_id] = result
	return result


func uses_temporary_body(champion_id: String) -> bool:
	return bool(portrait_source(champion_id).get("temporary_body_template", false))


func uses_wireframe_body(champion_id: String) -> bool:
	return String(portrait_source(champion_id).get("visual_mode", "")) == "wireframe_body"


func change_preview_direction(delta: int) -> void:
	preview_direction = posmod(preview_direction + delta, 8)


func facing_preview(champion_id: String) -> Dictionary:
	# Only the selected body borrows a page; cards keep their compact front portraits.
	# Inspect actual atlas cells, never rotate/mirror/blend a frontal cutout.
	if not is_instance_valid(_presenter) or not _presenter.has_method("can_present") \
		or not bool(_presenter.call("can_present", champion_id)) \
		or not _presenter.has_method("texture_for_champion") \
		or not _presenter.has_method("source_region_for_animation_state"):
		return {}
	var direction_id: String = EightDirectionResolver.DIRECTION_ORDER[preview_direction]
	if _presenter.has_method("inspection_frame"):
		var frame: Dictionary = _presenter.call("inspection_frame", champion_id, direction_id)
		if not frame.is_empty():
			frame["direction"] = direction_id
			frame["degrees"] = preview_direction * 45
		return frame
	var direction: Vector2i = EightDirectionResolver.FIXED_VECTORS[preview_direction]
	_preview_state.facing_x = direction.x
	_preview_state.facing_y = direction.y
	_preview_state.aim_x = direction.x
	_preview_state.aim_y = direction.y
	# Acquire first: the presenter then knows whether this is an override page.
	var texture: Texture2D = _presenter.call("texture_for_champion", champion_id)
	var region: Rect2 = _presenter.call("source_region_for_animation_state", champion_id, _preview_state, "grounded")
	if texture == null or not region.has_area():
		return {}
	return {"texture": texture, "region": region, "direction": EightDirectionResolver.DIRECTION_ORDER[preview_direction], "degrees": preview_direction * 45}


func draw(canvas: CanvasItem, font: Font) -> void:
	if not is_open:
		return
	canvas.draw_rect(Rect2(0, 0, 1280, 720), Color("07110e88"))
	canvas.draw_rect(PANEL, INK)
	canvas.draw_rect(PANEL, BRASS, false, 2)
	_text(canvas, font, Vector2(72, 88), "CHAMPION GALLERY", 26, PAPER)
	_button(canvas, font, CLOSE_RECT, "Close")
	_button(canvas, font, PREVIOUS_PAGE, "< Races")
	_button(canvas, font, NEXT_PAGE, "Races >")
	_text(canvas, font, Vector2(208, 134), "Races %d / %d  |  Alphabetical columns" % [model.race_page() + 1, model.race_page_count()], 16, MUTED)
	for race: int in model.visible_race_indices():
		var x := GRID_ORIGIN.x + (race % Model.COLUMNS_PER_PAGE) * COLUMN_STRIDE
		_text(canvas, font, Vector2(x + 2, 170), String(model.races()[race]["race"]), 15, BRASS)
		if model.characters(race).is_empty():
			_text(canvas, font, Vector2(x + 3, 210), "No champion", 12, MUTED)
			_text(canvas, font, Vector2(x + 3, 228), "yet", 12, MUTED)
		for index: int in model.visible_character_indices(race):
			var rectangle := card_rect(race, index)
			var entry: Dictionary = model.characters(race)[index]
			var focused := race == model.race_index and index == model.character_index
			canvas.draw_rect(rectangle, Color("4c482bee") if focused else Color("202a23"))
			canvas.draw_rect(rectangle, BRASS if focused else Color(BRASS, 0.35), false, 2 if focused else 1)
			_draw_portrait(canvas, font, String(entry["id"]), Rect2(rectangle.position + Vector2(18, 3), Vector2(64, 64)))
			var names := Text.wrap_text(String(entry["display_name"]), font, 94, 13)
			for line: int in range(mini(2, names.size())):
				_text(canvas, font, rectangle.position + Vector2(3, 81 + line * 16), names[line], 13, PAPER)
			var badge := "EQUIPPED" if String(entry["id"]) == model.equipped_id else String(entry["body_type"]).to_upper()
			if not bool(entry["selectable"]):
				badge = String(entry["status"]).to_upper()
			elif uses_wireframe_body(String(entry["id"])):
				badge = "SKEL/EQUIPPED" if String(entry["id"]) == model.equipped_id else "SKEL/" + String(entry["body_type"]).to_upper()
			elif uses_temporary_body(String(entry["id"])):
				badge = "TEMP/EQUIPPED" if String(entry["id"]) == model.equipped_id else "TEMP/" + String(entry["body_type"]).to_upper()
			_text(canvas, font, rectangle.position + Vector2(4, 120), badge, 11, BRASS if focused else MUTED)
	var selected := model.selected_entry()
	canvas.draw_line(Vector2(836, 154), Vector2(836, 652), Color(BRASS, 0.5))
	var title := "Race awaiting a champion" if selected.is_empty() else String(selected["display_name"])
	if not selected.is_empty():
		var preview := facing_preview(String(selected["id"]))
		if not preview.is_empty():
			canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			canvas.draw_texture_rect_region(preview.texture, Rect2(982, 98, 96, 96), preview.region)
		_button(canvas, font, PREVIOUS_FACING, "<")
		_button(canvas, font, NEXT_FACING, ">")
		_text(canvas, font, Vector2(970, 198), FACING_LABELS[preview_direction], 13, MUTED)
		if uses_wireframe_body(String(selected["id"])):
			_text(canvas, font, Vector2(852, 208), String(selected["body_type"]).to_upper() + " SIZE SKELETON / shared animation base", 12, BRASS)
		elif uses_temporary_body(String(selected["id"])):
			_text(canvas, font, Vector2(852, 208), "TEMPORARY BODY TEMPLATE / unique art pending", 12, BRASS)
	var titles := Text.wrap_text(title, font, DETAIL_WIDTH, 20)
	for index: int in range(mini(titles.size(), 2)):
		_text(canvas, font, Vector2(852, 230 + index * 24), titles[index], 20, PAPER)
	var lines := visible_detail_lines(font)
	for index: int in range(lines.size()):
		_text(canvas, font, Vector2(852, 284 + index * LINE_HEIGHT), lines[index], FONT_SIZE, PAPER)
	_button(canvas, font, PREVIOUS_DETAIL, "< Details")
	_button(canvas, font, NEXT_DETAIL, "Details >")
	_text(canvas, font, Vector2(971, 604), "%d / %d" % [detail_page + 1, detail_pages(font)], 15, MUTED)
	var choice := "Inspect only"
	if model.pending_wire != 0:
		choice = "Waiting for host"
	elif not selected.is_empty() and bool(selected["selectable"]):
		choice = "Already equipped" if String(selected["id"]) == model.equipped_id else "Attune / Enter / A"
	_button(canvas, font, SELECT_RECT, choice)
	var status := Text.wrap_text(model.status_message, font, 748, 14)
	for index: int in range(mini(2, status.size())):
		_text(canvas, font, Vector2(72, 604 + index * 18), status[index], 14, PAPER)
	_text(canvas, font, Vector2(72, 646), "Arrows/D-pad: cards  PgUp/PgDn/LB/RB: races  [ ]/L3/R3: facing", 14, MUTED)
	_text(canvas, font, Vector2(72, 668), "Home/End/X/Y: details  Esc/B: close  |  The shared world does not pause.", 13, BRASS)


func _draw_portrait(canvas: CanvasItem, font: Font, champion_id: String, rectangle: Rect2) -> void:
	var source := portrait_source(champion_id)
	if not source.is_empty():
		canvas.draw_texture_rect_region(source["texture"], rectangle, source["region"])
	else:
		_text(canvas, font, rectangle.position + Vector2(1, rectangle.size.y * 0.5), "Art pending", 11, MUTED)


func _reset_detail() -> void:
	detail_page = 0
	preview_direction = 0
	_detail_key = ""


func _ensure_detail(font: Font) -> void:
	_sync_portrait_generation()
	var key := "%d/%d/%d" % [model.race_index, model.character_index, font.get_instance_id()]
	if key == _detail_key:
		return
	_detail_key = key
	_detail_lines.clear()
	for paragraph: String in model.detail_paragraphs():
		_detail_lines.append_array(Text.wrap_text(paragraph, font, DETAIL_WIDTH, FONT_SIZE))
	var selected := model.selected_entry()
	if not selected.is_empty() and uses_wireframe_body(String(selected["id"])):
		_detail_lines.append_array(Text.wrap_text("Shared adventurer body: identity and race stay yours. Only Small / Middle / Large determines hurtbox size; aiming and travel animate independently.", font, DETAIL_WIDTH, FONT_SIZE))
	elif not selected.is_empty() and uses_temporary_body(String(selected["id"])):
		_detail_lines.append_array(Text.wrap_text("Temporary visual: this identity currently reuses a tested body template. Its individual character artwork and animation acceptance are pending.", font, DETAIL_WIDTH, FONT_SIZE))


static func _text(canvas: CanvasItem, font: Font, position: Vector2, value: String, size: int, color: Color) -> void:
	canvas.draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func _button(canvas: CanvasItem, font: Font, rectangle: Rect2, label: String) -> void:
	canvas.draw_rect(rectangle, Color("202a23"))
	canvas.draw_rect(rectangle, Color(BRASS, 0.6), false, 1)
	_text(canvas, font, rectangle.position + Vector2(10, 22), label, 15, PAPER)

class_name CharacterSelectionGrid
extends RefCounted


const Model = preload("res://src/app/character_selection_model.gd")
const Text = preload("res://src/presentation/player_compendium.gd")
const Portraits = preload("res://src/presentation/champion_portrait_library.gd")
const PANEL := Rect2(48, 44, 1184, 632)
const CLOSE_RECT := Rect2(1116, 50, 92, 32)
const PREVIOUS_DETAIL := Rect2(852, 582, 104, 32)
const NEXT_DETAIL := Rect2(1104, 582, 104, 32)
const OVERVIEW_RECT := Rect2(970, 582, 120, 32)
const SELECT_RECT := Rect2(852, 620, 356, 32)
const PREVIOUS_FACING := Rect2(984, 144, 44, 32)
const NEXT_FACING := Rect2(1164, 144, 44, 32)
const HERO_PORTRAIT := Rect2(852, 84, 128, 128)
const FACING_PREVIEW := Rect2(1032, 84, 128, 128)
const FACING_PIVOT := Vector2(64, 104)
const LEGACY_FACING_PIVOT := Vector2(48, 84)
const LARGE_PORTRAIT := Rect2(232, 174, 400, 400)
const PORTRAIT_BACK := Rect2(664, 112, 156, 32)
const FACING_LABELS := ["S 0 / 360", "SE 45", "E 90", "NE 135", "N 180", "NW 225", "W 270", "SW 315"]
const GRID_ORIGIN := Vector2(72, 136)
const CARD_SIZE := Vector2(118, 84)
const CARD_PORTRAIT_SIZE := Vector2(32, 32)
const COLUMN_STRIDE := 126.0
const ROW_STRIDE := 90.0
const CARD_FONT_SIZE := 16
const CARD_NAME_WIDTH := 110.0
const CARD_NAME_LINE_HEIGHT := 18
const DETAIL_WIDTH := 356.0
const DETAIL_LINES := 12
const FONT_SIZE := 16
const LINE_HEIGHT := 22
const OVERVIEW_NOTE_SIZE := 13
const OVERVIEW_NOTE_HEIGHT := 16
const OVERVIEW_NOTE_TOP := 444
const OVERVIEW_NOTE_MAX_LINES := 8
const INK := Color("141a17f5")
const PAPER := Color("eee0b8")
const MUTED := Color("b7b69e")
const BRASS := Color("b79351")

var model := Model.new()
var is_open := false
var detail_page := 0
var overview_visible := true
var last_error := ""
var _presenter: Object
var _preview_state := PlayerState.new(0)
var _detail_key := ""
var _detail_lines: Array[String] = []
var _portrait_cache: Dictionary = {}
var _portrait_generation: int = -1
var preview_direction := 0
var portrait_library := Portraits.new()
var portrait_expanded := false


func configure(champions: ChampionCatalog, roster: ChampionRosterPlan, presenter: Object = null) -> bool:
	# Drop the previous modal and all borrowed visual state before validation.
	# A failed reload must be closed, not an old panel over invalid catalogs.
	close_panel()
	_presenter = null
	portrait_library.clear()
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
	# Optional illustrated art must never revoke a valid sprite-only Gallery.
	portrait_library.configure(champions.ordered_champion_ids())
	last_error = ""
	return true


func open_panel(current_champion_id: String) -> void:
	model.open_for(current_champion_id)
	is_open = model.last_error.is_empty() and not model.races().is_empty()
	_reset_detail()


func close_panel() -> void:
	is_open = false
	portrait_expanded = false
	portrait_library.release_textures()


func confirm_equipped(champion_id: String) -> void:
	model.confirm_equipped(champion_id)


func refuse(reason: String) -> void:
	model.refuse(reason)


func bind_pending_attunement(context: Array, now_ms: int) -> bool:
	return model.bind_pending_attunement(context, now_ms)


func reconcile_attunement(context: Array, authoritative_champion_id: String, now_ms: int, authority_ready: bool = true) -> String:
	return model.reconcile_attunement(context, authoritative_champion_id, now_ms, authority_ready)


func confirm_attunement_feedback(champion_id: String, context: Array) -> bool:
	return model.confirm_attunement_feedback(champion_id, context)


func card_rect(race: int, character: int) -> Rect2:
	var index := model.display_index(race, character)
	if index < 0:
		return Rect2()
	return Rect2(GRID_ORIGIN + Vector2((index % Model.GRID_COLUMNS) * COLUMN_STRIDE, (index / Model.GRID_COLUMNS) * ROW_STRIDE), CARD_SIZE)


func cell_at(pointer: Vector2) -> Vector2i:
	if portrait_expanded:
		return Vector2i(-1, -1)
	for cell: Vector2i in model.display_cells():
		if card_rect(cell.x, cell.y).has_point(pointer):
			return cell
	return Vector2i(-1, -1)


# Return one exact wire intent, never an authority mutation. Caller consumes all
# events while is_open (including releases), sends neutral gameplay commands,
# and maintains its existing close guard. Pointer uses logical 1280x720 space.
func handle_event(
	event: InputEvent,
	font: Font,
	pointer: Vector2 = Vector2(-1, -1),
	selection_availability: Dictionary = {},
) -> int:
	if not is_open:
		return 0
	var before := Vector2i(model.race_index, model.character_index)
	var choose := false
	if event is InputEventMouseMotion:
		var cell := cell_at(pointer)
		if cell.x >= 0:
			model.select_cell(cell.x, cell.y)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode if event.physical_keycode != 0 else event.keycode:
			KEY_ESCAPE:
				_close_portrait_or_panel()
			KEY_LEFT, KEY_A:
				model.move_selection(0, -1)
			KEY_RIGHT, KEY_D:
				model.move_selection(0, 1)
			KEY_UP, KEY_W:
				model.move_selection(-1, 0)
			KEY_DOWN, KEY_S:
				model.move_selection(1, 0)
			KEY_PAGEUP:
				model.change_size_group(-1)
			KEY_PAGEDOWN:
				model.change_size_group(1)
			KEY_HOME:
				change_detail_page(-1, font)
			KEY_END:
				change_detail_page(1, font)
			KEY_TAB:
				overview_visible = not overview_visible
			KEY_P:
				toggle_portrait()
			KEY_BRACKETLEFT:
				change_preview_direction(-1)
			KEY_BRACKETRIGHT:
				change_preview_direction(1)
			KEY_ENTER, KEY_KP_ENTER:
				choose = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				_close_portrait_or_panel()
			JOY_BUTTON_START:
				toggle_portrait()
			JOY_BUTTON_DPAD_LEFT:
				model.move_selection(0, -1)
			JOY_BUTTON_DPAD_RIGHT:
				model.move_selection(0, 1)
			JOY_BUTTON_DPAD_UP:
				model.move_selection(-1, 0)
			JOY_BUTTON_DPAD_DOWN:
				model.move_selection(1, 0)
			JOY_BUTTON_LEFT_SHOULDER:
				model.change_size_group(-1)
			JOY_BUTTON_RIGHT_SHOULDER:
				model.change_size_group(1)
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
			elif not portrait_expanded:
				model.move_selection(delta, 0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if CLOSE_RECT.has_point(pointer):
				close_panel()
			elif HERO_PORTRAIT.has_point(pointer) or (portrait_expanded and PORTRAIT_BACK.has_point(pointer)):
				toggle_portrait()
			elif portrait_expanded and pointer.x < 836:
				pass # Covered roster cards are not click targets.
			elif PREVIOUS_DETAIL.has_point(pointer):
				change_detail_page(-1, font)
			elif NEXT_DETAIL.has_point(pointer):
				change_detail_page(1, font)
			elif OVERVIEW_RECT.has_point(pointer):
				overview_visible = true
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
	if before != Vector2i(model.race_index, model.character_index):
		_reset_detail()
	if not choose:
		return 0
	# Contextual admission belongs to Bootstrap because it depends on the live
	# round, authority actor and station. Browsing remains available while that
	# final request is disabled, including a direct click that focused a card.
	if not bool(selection_availability.get("enabled", true)):
		return 0
	return model.request_selection()


func detail_pages(font: Font) -> int:
	_ensure_detail(font)
	return maxi(1, ceili(float(_detail_lines.size()) / DETAIL_LINES))


func change_detail_page(delta: int, font: Font) -> void:
	if overview_visible:
		overview_visible = false
		detail_page = 0
		return
	if delta < 0 and detail_page == 0:
		overview_visible = true
		return
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


func hero_portrait_source(champion_id: String) -> Dictionary:
	# Cards and the combat HUD keep the presenter's front-sprite crop. Only this
	# selected hero/detail seam is allowed to request a detailed illustration.
	var detailed := portrait_library.portrait_frame(champion_id)
	return detailed if not detailed.is_empty() else portrait_source(champion_id)


func toggle_portrait() -> void:
	var selected := model.selected_entry()
	if not is_open or selected.is_empty():
		return
	if portrait_expanded:
		portrait_expanded = false
	elif not hero_portrait_source(String(selected.id)).is_empty():
		portrait_expanded = true


func _close_portrait_or_panel() -> void:
	if portrait_expanded:
		portrait_expanded = false
	else:
		close_panel()


func inspection_label() -> String:
	var selected := model.selected_entry()
	return "ATTUNED" if not selected.is_empty() and String(selected.id) == model.equipped_id else "INSPECTING"


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


static func facing_preview_draw_rect(preview: Dictionary) -> Rect2:
	# The full pixel cell is already registered at native 128px. Do not shrink it
	# to the legacy 96px slot or infer body size from individual pose ink bounds.
	if bool(preview.get("fullbody_art", false)) or bool(preview.get("pixel_body_pilot", false)):
		return FACING_PREVIEW
	# The separate 96px legacy path keeps its own pixels and shares the floor.
	return Rect2(FACING_PREVIEW.position + FACING_PIVOT - LEGACY_FACING_PIVOT, Vector2(96, 96))


static func card_portrait_rect(card: Rect2) -> Rect2:
	# Center the prepared native 32px crop in its original 40px allocation.
	return Rect2(card.position + Vector2(8, 8), CARD_PORTRAIT_SIZE)


func draw(canvas: CanvasItem, font: Font, selection_availability: Dictionary = {}) -> void:
	if not is_open:
		return
	canvas.draw_rect(Rect2(0, 0, 1280, 720), Color("07110e88"))
	canvas.draw_rect(PANEL, INK)
	canvas.draw_rect(PANEL, BRASS, false, 2)
	_text(canvas, font, Vector2(72, 88), "CHAMPION GALLERY", 26, PAPER)
	_button(canvas, font, CLOSE_RECT, "Close")
	_text(canvas, font, Vector2(72, 121), "%d characters  |  Small / Middle / Large  |  A-Z within each size" % model.display_cells().size(), 16, MUTED)
	for cell: Vector2i in model.display_cells():
		var rectangle := card_rect(cell.x, cell.y)
		var entry: Dictionary = model.characters(cell.x)[cell.y]
		var champion_id := String(entry["id"])
		var focused := cell == Vector2i(model.race_index, model.character_index)
		var size_color := Color("97c6b5") if String(entry["body_type"]) == "small" else (Color("c7b782") if String(entry["body_type"]) == "middle" else Color("bfa0c2"))
		canvas.draw_rect(rectangle, Color("4c482bee") if focused else Color("202a23"))
		canvas.draw_rect(rectangle, PAPER if focused else Color(size_color, 0.55), false, 2 if focused else 1)
		canvas.draw_rect(Rect2(rectangle.position, Vector2(rectangle.size.x, 2)), size_color)
		_draw_portrait(canvas, font, champion_id, card_portrait_rect(rectangle))
		_text(canvas, font, rectangle.position + Vector2(49, 20), String(entry["body_type"]).capitalize(), 13, size_color)
		var badge := "ATTUNED" if champion_id == model.equipped_id else ""
		if not bool(entry["selectable"]):
			badge = String(entry["status"]).to_upper()
		elif badge.is_empty() and uses_wireframe_body(champion_id):
			badge = "SHARED"
		elif badge.is_empty() and uses_temporary_body(champion_id):
			badge = "TEMP"
		_text(canvas, font, rectangle.position + Vector2(49, 37), badge, 11, BRASS if champion_id == model.equipped_id else MUTED)
		var names := Text.wrap_text(String(entry["display_name"]), font, CARD_NAME_WIDTH, CARD_FONT_SIZE)
		for line: int in range(mini(2, names.size())):
			_text(canvas, font, rectangle.position + Vector2(4, 60 + line * CARD_NAME_LINE_HEIGHT), names[line], CARD_FONT_SIZE, PAPER)
	var selected := model.selected_entry()
	if portrait_expanded and not selected.is_empty():
		_draw_expanded_portrait(canvas, font, selected)
	canvas.draw_line(Vector2(836, 154), Vector2(836, 652), Color(BRASS, 0.5))
	var title := "Race awaiting a champion" if selected.is_empty() else String(selected["display_name"])
	if not selected.is_empty():
		var hero := hero_portrait_source(String(selected.id))
		canvas.draw_rect(HERO_PORTRAIT.grow(2), BRASS)
		canvas.draw_rect(HERO_PORTRAIT, Color("111814"))
		if not hero.is_empty():
			canvas.draw_texture_rect_region(hero.texture, HERO_PORTRAIT, hero.region)
			canvas.draw_rect(Rect2(HERO_PORTRAIT.position + Vector2(0, 109), Vector2(128, 19)), Color("0c1311dd"))
			_text(canvas, font, HERO_PORTRAIT.position + Vector2(5, 123), "P / Start: portrait", 11, PAPER)
		_text(canvas, font, Vector2(1000, 92), inspection_label(), 12, BRASS)
		var preview := facing_preview(String(selected["id"]))
		if not preview.is_empty():
			canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			canvas.draw_texture_rect_region(preview.texture, facing_preview_draw_rect(preview), preview.region)
		_button(canvas, font, PREVIOUS_FACING, "<")
		_button(canvas, font, NEXT_FACING, ">")
		var facing_label: String = FACING_LABELS[preview_direction]
		if uses_wireframe_body(String(selected["id"])):
			facing_label += " / SHARED BODY"
		elif uses_temporary_body(String(selected["id"])):
			facing_label += " / TEMP BODY"
		_text(canvas, font, Vector2(1000, 211), facing_label, 12, MUTED)
	var titles := Text.wrap_text(title, font, DETAIL_WIDTH, 20)
	for index: int in range(mini(titles.size(), 2)):
		_text(canvas, font, Vector2(852, 238 + index * 24), titles[index], 20, PAPER)
	if overview_visible and not selected.is_empty():
		_draw_overview(canvas, font, selected)
	else:
		var lines := visible_detail_lines(font)
		for index: int in range(lines.size()):
			_text(canvas, font, Vector2(852, 284 + index * LINE_HEIGHT), lines[index], FONT_SIZE, PAPER)
	_button(canvas, font, PREVIOUS_DETAIL, "< Details")
	_button(canvas, font, NEXT_DETAIL, "Details >")
	_button(canvas, font, OVERVIEW_RECT, "Overview")
	if not overview_visible:
		_text(canvas, font, Vector2(852, 567), "Detail %d / %d" % [detail_page + 1, detail_pages(font)], 12, MUTED)
	var choice := "Inspect only"
	var selection_enabled: bool = bool(selection_availability.get("enabled", true))
	if model.pending_wire != 0:
		choice = "Waiting for host"
	elif not selected.is_empty() and bool(selected["selectable"]):
		if String(selected["id"]) == model.equipped_id:
			choice = "Already equipped"
		elif selection_enabled:
			choice = "Attune / Enter / A"
		else:
			choice = "Attunement unavailable"
	_button(canvas, font, SELECT_RECT, choice, choice == "Attune / Enter / A")
	var unavailable_reason: String = String(selection_availability.get("reason", ""))
	var status_y := 604.0
	if not selection_enabled and model.pending_wire == 0 and not unavailable_reason.is_empty():
		var availability_lines: Array[String] = Text.wrap_text(unavailable_reason, font, 748, 11)
		if not availability_lines.is_empty():
			_text(canvas, font, Vector2(72, 594), availability_lines[0], 11, BRASS)
			status_y = 612.0
	var status := Text.wrap_text(model.status_message, font, 748, 14)
	for index: int in range(mini(2, status.size())):
		_text(canvas, font, Vector2(72, status_y + index * 18), status[index], 14, PAPER)
	_text(canvas, font, Vector2(72, 646), "Arrows/WASD/D-pad: inspect  Enter/A: attune  PgUp/PgDn/LB/RB: size", 13, MUTED)
	_text(canvas, font, Vector2(72, 668), "Home/End/X/Y: details  [ ]/L3/R3: facing  Esc/B: close  |  World continues.", 12, BRASS)


static func summary_rows(entry: Dictionary) -> Array[Dictionary]:
	if not bool(entry.get("stats_available", false)):
		return []
	var stats: Dictionary = entry.get("stats", {})
	var rows: Array[Dictionary] = []
	for resource: String in ["health", "flux", "stamina"]:
		rows.append({"label": resource.capitalize(), "value": String.num(float(stats.get(resource + "_maximum", 0)) / 1000.0, 2), "recovery": String.num(float(stats.get(resource + "_recovery_per_second", 0)) / 1000.0, 2) + "/s"})
	rows.append({"label": "Walk speed", "value": String.num(float(stats.get("movement_speed_ratio", 1000)) / 10.0, 1) + "%", "recovery": "of base"})
	rows.append({"label": "Hurt radius", "value": String.num(float(entry.get("hurt_radius", 0)) / 1000.0, 1) + " px", "recovery": "wall: 18 px"})
	return rows


static func overview_notes(entry: Dictionary) -> Array[String]:
	if not bool(entry.get("stats_available", false)):
		return [Model.air_action_summary(entry), "Details: identity and availability notes."]
	var result: Array[String] = [Model.air_action_summary(entry)]
	result.append_array(CharacterOverviewModel.perk_summaries(entry))
	result.append("Attune: saved weave; starter if uncustomized.")
	return result


static func overview_note_lines(entry: Dictionary, font: Font) -> Array[String]:
	var result: Array[String] = []
	for note: String in overview_notes(entry):
		result.append_array(Text.wrap_text(note, font, DETAIL_WIDTH, OVERVIEW_NOTE_SIZE))
	return result


func _draw_overview(canvas: CanvasItem, font: Font, entry: Dictionary) -> void:
	_text(canvas, font, Vector2(852, 281), "%s / %s" % [entry.get("race", ""), String(entry.get("body_type", "")).capitalize()], 15, BRASS)
	var affinity_labels := PackedStringArray()
	for element: String in entry.get("affinities", []):
		affinity_labels.append("%s %d" % [AbilityCatalog.element_display_name(element), int(entry.get("affinity_points", {}).get(element, 0))])
	_text(canvas, font, Vector2(852, 304), " / ".join(affinity_labels), 13, PAPER)
	_text(canvas, font, Vector2(852, 325), "BASE STAT", 11, MUTED)
	_text(canvas, font, Vector2(993, 325), "VALUE", 11, MUTED)
	_text(canvas, font, Vector2(1096, 325), "BASE REGEN", 11, MUTED)
	var rows := summary_rows(entry)
	for index: int in range(rows.size()):
		var y := 346 + index * 19
		canvas.draw_rect(Rect2(848, y - 15, 360, 18), Color(BRASS, 0.055 if index % 2 == 0 else 0.0))
		_text(canvas, font, Vector2(852, y), rows[index].label, 14, PAPER)
		_text(canvas, font, Vector2(993, y), rows[index].value, 14, PAPER)
		_text(canvas, font, Vector2(1096, y), rows[index].recovery, 12, MUTED)
	var notes := overview_note_lines(entry, font)
	for index: int in range(notes.size()):
		_text(canvas, font, Vector2(852, OVERVIEW_NOTE_TOP + index * OVERVIEW_NOTE_HEIGHT), notes[index], OVERVIEW_NOTE_SIZE, BRASS if index == 0 else PAPER)


func _draw_portrait(canvas: CanvasItem, font: Font, champion_id: String, rectangle: Rect2) -> void:
	var source := portrait_source(champion_id)
	if not source.is_empty():
		canvas.draw_texture_rect_region(source["texture"], rectangle, source["region"])
	else:
		_text(canvas, font, rectangle.position + Vector2(1, rectangle.size.y * 0.5), "No art", 11, MUTED)


func _draw_expanded_portrait(canvas: CanvasItem, font: Font, entry: Dictionary) -> void:
	# A read-only layer over the roster, not a second modal. The right-hand
	# heading preview, actual stats/details and explicit Attune remain visible.
	canvas.draw_rect(Rect2(64, 106, 764, 476), Color("141a17"))
	_text(canvas, font, Vector2(80, 136), "PORTRAIT / READ-ONLY", 17, BRASS)
	_button(canvas, font, PORTRAIT_BACK, "< Roster / Esc")
	var source := hero_portrait_source(String(entry.id))
	canvas.draw_rect(LARGE_PORTRAIT.grow(2), BRASS)
	canvas.draw_rect(LARGE_PORTRAIT, Color("111814"))
	if not source.is_empty():
		canvas.draw_texture_rect_region(source.texture, LARGE_PORTRAIT, source.region)
		var caption := "Illustration" if bool(source.get("detailed_portrait", false)) else "Sprite portrait / detailed art unavailable"
		_text(canvas, font, Vector2(232, 162), caption, 12, MUTED)


func _reset_detail() -> void:
	overview_visible = true
	portrait_expanded = false
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


static func _button(canvas: CanvasItem, font: Font, rectangle: Rect2, label: String, enabled: bool = true) -> void:
	canvas.draw_rect(rectangle, Color("202a23") if enabled else Color("171d19"))
	canvas.draw_rect(rectangle, Color(BRASS, 0.6 if enabled else 0.28), false, 1)
	_text(canvas, font, rectangle.position + Vector2(10, 22), label, 15, PAPER if enabled else MUTED)

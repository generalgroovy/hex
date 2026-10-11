extends FluxTestSuite


const Grid = preload("res://src/presentation/character_selection_grid.gd")
const Compendium = preload("res://src/presentation/player_compendium.gd")


class SharedPortrait:
	extends RefCounted
	var queries := 0
	var texture := GradientTexture2D.new()
	func can_present(champion_id: String) -> bool:
		return champion_id == "oh_tipi"
	func texture_for_champion(_champion_id: String) -> Texture2D:
		queries += 1
		return texture
	func source_region_for_animation_state(_champion_id: String, state: PlayerState, action: String) -> Rect2:
		return Rect2(EightDirectionResolver.classify_index(state.facing_x, state.facing_y) * 96, 0, 96, 96) if action == "grounded" else Rect2()
	func recipe(_champion_id: String) -> Dictionary:
		return {"temporary_body_template": true, "template_source_id": "reference-body"}


class CompactPortraits:
	extends RefCounted
	var queries := 0
	var full_page_queries := 0
	var generation := 0
	var temporary := false
	var visual_mode := ""
	var textures: Dictionary = {}
	func can_present(_champion_id: String) -> bool:
		return true
	func portrait_revision() -> int:
		return generation
	func texture_for_champion(_champion_id: String) -> Texture2D:
		full_page_queries += 1
		return null
	func portrait_frame(champion_id: String) -> Dictionary:
		queries += 1
		if not textures.has(champion_id):
			var texture := GradientTexture2D.new()
			texture.width = 32
			texture.height = 32
			textures[champion_id] = texture
		return {"texture": textures[champion_id], "region": Rect2(0, 0, 32, 32), "temporary_body_template": temporary, "template_source_id": "reference-body" if temporary else "", "complete_page_override": not temporary, "visual_mode": visual_mode}


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "grid abilities load")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "grid champions load")
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "grid roster loads")
	var grid := Grid.new()
	var shared := SharedPortrait.new()
	check(grid.configure(champions, roster, shared), "grid uses existing validated data and shared presenter")
	grid.open_panel(champions.default_champion_id)
	check(grid.is_open, "configured grid opens")
	var font := ThemeDB.fallback_font
	var equipped := grid.model.equipped_id
	var source := grid.portrait_source("oh_tipi")
	check(source["texture"] == shared.texture, "portrait reuses existing texture reference without page loading")
	equal(source["region"], Rect2(0, 0, 96, 96), "portrait uses grounded source cell, not a new body composition")
	check(grid.uses_temporary_body("oh_tipi"), "temporary body metadata is exposed for prominent selected and card labels")
	equal(source["template_source_id"], "reference-body", "temporary portrait retains its honest source reference")
	grid.portrait_source("oh_tipi")
	equal(shared.queries, 1, "portrait metadata is cached rather than rebuilt every draw")
	check(grid.portrait_source("not-accepted-art").is_empty(), "missing art is honestly unavailable")
	_test_facing_preview(champions, roster, font)
	var playable_cell := Vector2i(-1, -1)
	for race: int in range(grid.model.races().size()):
		var race_label := String(grid.model.races()[race]["race"])
		check(font.get_string_size(race_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= Grid.CARD_SIZE.x, "current race header fits its column")
		for character: int in range(grid.model.characters(race).size()):
			grid.model.select_cell(race, character)
			var entry: Dictionary = grid.model.selected_entry()
			var rectangle := grid.card_rect(race, character)
			check(Grid.PANEL.encloses(rectangle), "every visible card stays inside720p panel")
			equal(grid.cell_at(rectangle.get_center()), Vector2i(race, character), "mouse hit testing resolves exact displayed identity")
			var names := Compendium.wrap_text(String(entry["display_name"]), font, 94, 13)
			check(names.size() <= 2, "current character name remains complete in two card lines")
			var paragraphs: Array[String] = grid.model.detail_paragraphs()
			var expected: Array[String] = []
			for paragraph: String in paragraphs:
				expected.append_array(Compendium.wrap_text(paragraph, font, Grid.DETAIL_WIDTH, Grid.FONT_SIZE))
			if grid.uses_temporary_body(String(entry["id"])):
				expected.append_array(Compendium.wrap_text("Temporary visual: this identity currently reuses a tested body template. Its individual character artwork and animation acceptance are pending.", font, Grid.DETAIL_WIDTH, Grid.FONT_SIZE))
			var actual: Array[String] = []
			for page: int in range(grid.detail_pages(font)):
				grid.detail_page = page
				var lines := grid.visible_detail_lines(font)
				check(lines.size() <= Grid.DETAIL_LINES, "detail page has finite vertical height")
				for line: String in lines:
					check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Grid.FONT_SIZE).x <= Grid.DETAIL_WIDTH + 0.01, "actual-font detail wrapping cannot clip")
				actual.append_array(lines)
			equal(actual, expected, "all current stats and help survive detail pagination")
			if bool(entry["selectable"]) and String(entry["id"]) != equipped:
				playable_cell = Vector2i(race, character)
			elif not bool(entry["selectable"]):
				equal(grid.handle_event(_key(KEY_ENTER), font), 0, "planned or placeholder card cannot send a selection")
	check(playable_cell.x >= 0, "at least one alternate playable identity exists")
	grid.model.select_cell(playable_cell.x, 0)
	var point := grid.card_rect(playable_cell.x, playable_cell.y).get_center()
	var motion := InputEventMouseMotion.new()
	equal(grid.handle_event(motion, font, point), 0, "hover returns no authority intent")
	equal(grid.model.character_index, playable_cell.y, "hover focuses hovered card")
	equal(grid.model.equipped_id, equipped, "hover does not attune")
	var expected_wire := int(grid.model.selected_entry()["wire_id"])
	equal(grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, point), expected_wire, "click sends selected stable wire")
	equal(grid.handle_event(_joy(JOY_BUTTON_A), font), 0, "controller confirmation cannot duplicate a pending request")
	grid.refuse("Stay near the Gallery.")
	equal(grid.handle_event(_joy(JOY_BUTTON_A), font), expected_wire, "refused request can be deliberately retried")
	grid.confirm_equipped(String(grid.model.selected_entry()["id"]))
	equal(grid.handle_event(_key(KEY_ENTER), font), 0, "repeated confirmation of current character cannot reset its kit")
	var page_before := grid.model.race_page()
	grid.handle_event(_joy(JOY_BUTTON_LEFT_SHOULDER), font)
	equal(grid.model.race_page(), maxi(0, page_before - 1), "controller shoulder pages races")
	equal(grid.handle_event(_mouse(MOUSE_BUTTON_WHEEL_DOWN), font, Vector2(400, 400)), 0, "mouse wheel navigates without selecting")
	var release := _key(KEY_ENTER)
	release.pressed = false
	equal(grid.handle_event(release, font), 0, "key release emits no intent")
	var echo := _key(KEY_ENTER)
	echo.echo = true
	equal(grid.handle_event(echo, font), 0, "key repeat emits no intent")
	grid.handle_event(_key(KEY_ESCAPE), font)
	check(not grid.is_open, "Escape closes before underlying quit")
	equal(grid.handle_event(_joy(JOY_BUTTON_A), font), 0, "closed grid cannot select")
	grid.open_panel(equipped)
	grid.handle_event(_joy(JOY_BUTTON_B), font)
	check(not grid.is_open, "controller B closes")
	grid.open_panel("oh_tipi")
	grid.detail_page = 2
	check(not grid.configure(null, null, shared), "invalid Gallery reload is refused")
	check(not grid.is_open, "invalid reload closes old modal instead of trapping input")
	equal(grid.detail_page, 0, "invalid reload resets detail pagination")
	check(grid.portrait_source("oh_tipi").is_empty(), "invalid reload releases old portrait presenter and cached texture")
	check(grid.configure(champions, roster, shared), "Gallery recovers with valid catalogs")
	check(not grid.is_open, "recovered Gallery requires a deliberate reopen")
	grid.open_panel("oh_tipi")
	check(grid.is_open, "recovered Gallery opens normally")
	check(not grid.portrait_source("oh_tipi").is_empty(), "recovered Gallery can prepare current portrait")
	check(grid.configure(champions, roster, shared), "valid replacement can reconfigure open Gallery")
	check(not grid.is_open, "valid replacement also closes stale panel state")
	_test_compact_portrait_path(champions, roster)
	return finish("character-selection-grid")


func _test_compact_portrait_path(champions: ChampionCatalog, roster: ChampionRosterPlan) -> void:
	var grid := Grid.new()
	var compact := CompactPortraits.new()
	check(grid.configure(champions, roster, compact), "Gallery supports prepared compact override portraits")
	var ids := champions.ordered_champion_ids().slice(0, 21)
	for champion_id: String in ids:
		var frame := grid.portrait_source(champion_id)
		equal((frame["texture"] as Texture2D).get_size(), Vector2(32, 32), "a full visible Gallery page borrows only compact portraits")
		check(not grid.uses_temporary_body(champion_id), "accepted portrait uses effective override art status, not fallback provenance")
	equal(compact.queries, 21, "at most one portrait lookup per visible card")
	equal(compact.full_page_queries, 0, "21 visible Gallery cards never request or retain full-page textures")
	for champion_id: String in ids:
		grid.portrait_source(champion_id)
	equal(compact.queries, 21, "repeated Gallery draws reuse compact results")
	compact.generation += 1
	grid.portrait_source(ids[0])
	equal(compact.queries, 22, "a validated art reload invalidates stale portrait metadata")
	equal(compact.full_page_queries, 0, "portrait refresh does not evict or reload any active actor page")
	_test_direct_detail_reload(champions, roster)


func _test_facing_preview(champions: ChampionCatalog, roster: ChampionRosterPlan, font: Font) -> void:
	var grid := Grid.new()
	check(grid.configure(champions, roster, SharedPortrait.new()), "eight-way body preview configures")
	grid.open_panel("oh_tipi")
	var before := grid.model.equipped_id
	for index: int in range(8):
		var preview := grid.facing_preview("oh_tipi")
		equal(preview.direction, EightDirectionResolver.DIRECTION_ORDER[index], "preview samples exact semantic facing")
		equal(preview.degrees, index * 45, "preview headings are exact45degree multiples with south0")
		equal(preview.region, Rect2(index * 96, 0, 96, 96), "preview uses separate atlas cells instead of rotating or blending body art")
		equal(grid.handle_event(_key(KEY_BRACKETRIGHT), font), 0, "turntable cannot request champion selection")
	equal(grid.preview_direction, 0, "360degrees wraps to the exact same south0pose")
	equal(grid.model.equipped_id, before, "preview cannot mutate equipped identity")
	equal(grid.handle_event(_joy(JOY_BUTTON_LEFT_STICK), font), 0, "controller turntable does not emit authority intents")
	equal(grid.preview_direction, 7, "controller turns backwards to315degrees")
	equal(grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, Grid.NEXT_FACING.get_center()), 0, "mouse facing button is not an attune button")
	equal(grid.preview_direction, 0, "mouse advances to0degrees")
	grid.change_preview_direction(3)
	grid.close_panel()
	grid.open_panel("oh_tipi")
	equal(grid.preview_direction, 0, "reopening returns to stable front pose")
	check(grid.facing_preview("missing").is_empty(), "unknown art cannot create a facing preview")
	check(Grid.PANEL.encloses(Grid.PREVIOUS_FACING) and Grid.PANEL.encloses(Grid.NEXT_FACING), "turntable targets stay inside the panel")
	check(not Grid.PREVIOUS_FACING.intersects(Grid.PREVIOUS_DETAIL) and not Grid.NEXT_FACING.intersects(Grid.SELECT_RECT), "turning and equipping have distinct targets")


func _test_direct_detail_reload(champions: ChampionCatalog, roster: ChampionRosterPlan) -> void:
	var grid := Grid.new()
	var compact := CompactPortraits.new()
	compact.temporary = true
	check(grid.configure(champions, roster, compact), "direct detail reload fixture configures")
	grid.open_panel("steezo")
	var font := ThemeDB.fallback_font
	check("Temporary visual:" in _all_detail_text(grid, font), "initial direct detail query identifies temporary body art")
	var selected := String(grid.model.selected_entry()["id"])
	var initial_queries := compact.queries
	compact.temporary = false
	compact.generation += 1
	check("Temporary visual:" not in _all_detail_text(grid, font), "direct detail query drops stale temporary-art prose after presenter reload without a draw")
	equal(compact.queries, initial_queries + 1, "direct detail reload refreshes selected compact portrait once")
	equal(String(grid.model.selected_entry()["id"]), selected, "art reload does not change selected identity")
	compact.temporary = true
	compact.generation += 1
	check("Temporary visual:" in _all_detail_text(grid, font), "direct detail query restores honest fallback prose after override removal without a draw")
	var settled_queries := compact.queries
	_all_detail_text(grid, font)
	equal(compact.queries, settled_queries, "unchanged detail reads retain the compact portrait cache")
	equal(compact.full_page_queries, 0, "detail generation changes never request active full-page resources")
	compact.visual_mode = "wireframe_body"
	compact.generation += 1
	check(grid.uses_wireframe_body(selected), "shared skeleton mode is explicit in Gallery metadata")
	var skeleton_text := _all_detail_text(grid, font)
	check("Shared adventurer body:" in skeleton_text, "Gallery identifies the new active shared body instead of a historical skin")
	check("Temporary visual:" not in skeleton_text, "new skeleton mode does not append stale named-art fallback prose")
	check("hurtbox" in skeleton_text, "size-only hurtbox rule is available with the selected skeleton")
	equal(String(grid.model.selected_entry()["id"]), selected, "skeleton presentation never changes identity or selection")


func _all_detail_text(grid: Grid, font: Font) -> String:
	var lines: Array[String] = []
	for page: int in range(grid.detail_pages(font)):
		grid.detail_page = page
		lines.append_array(grid.visible_detail_lines(font))
	return "\n".join(lines)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event

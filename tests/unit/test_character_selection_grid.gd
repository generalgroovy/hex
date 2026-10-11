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
	_test_flat_grid(grid, font)
	_test_native_inspection_geometry(grid)
	_test_spatial_bindings(grid, font)
	grid.open_panel(champions.default_champion_id)
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
		for character: int in range(grid.model.characters(race).size()):
			grid.model.select_cell(race, character)
			var entry: Dictionary = grid.model.selected_entry()
			var summary := Grid.summary_rows(entry)
			var overview_notes := Grid.overview_notes(entry)
			if bool(entry.get("stats_available", false)):
				equal(summary.size(), 5, "all playable identities have the same five-row comparison layout")
				equal(summary[0].value, String.num(float(entry.stats.health_maximum) / 1000.0, 2), "overview health follows character authority")
				for stat: Dictionary in summary:
					check(font.get_string_size(String(stat.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 98, "overview values fit numeric column")
					check(font.get_string_size(String(stat.recovery), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 112, "overview recovery and size notes fit third column")
				equal(overview_notes.size(), 4, "first-screen notes expose air action, both perks and restoration")
				equal(overview_notes[0], grid.model.air_action_summary(entry), "prominent air action is shared with the source-derived model")
				check(overview_notes[3].contains("saved weave") and overview_notes[3].contains("starter if uncustomized"), "first-screen Attune guidance no longer promises to erase customized spells")
				for scope: String in ["race", "character"]:
					var perk: Dictionary = entry.identity_perks[scope]
					check(" ".join(overview_notes).contains(String(perk.name)) and " ".join(overview_notes).contains(String(perk.summary)), "first screen identifies each real perk and benefit for " + String(entry.id))
				var note_lines := Grid.overview_note_lines(entry, font)
				check(note_lines.size() <= Grid.OVERVIEW_NOTE_MAX_LINES, "both perks and air/restoration guidance fit the actual vertical overview budget for " + String(entry.id))
				check(Grid.OVERVIEW_NOTE_TOP + (note_lines.size() - 1) * Grid.OVERVIEW_NOTE_HEIGHT < Grid.PREVIOUS_DETAIL.position.y, "perk notes cannot cover Details controls")
				for note: String in note_lines:
					check(font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, Grid.OVERVIEW_NOTE_SIZE).x <= Grid.DETAIL_WIDTH + 0.01, "all thirty capability, perk and restore notes fit actual-font overview width")
			else:
				check(summary.is_empty(), "unimplemented characters never fabricate live stats")
			var rectangle := grid.card_rect(race, character)
			check(Grid.PANEL.encloses(rectangle), "every visible card stays inside720p panel")
			equal(grid.cell_at(rectangle.get_center()), Vector2i(race, character), "mouse hit testing resolves exact displayed identity")
			var names := Compendium.wrap_text(String(entry["display_name"]), font, Grid.CARD_NAME_WIDTH, Grid.CARD_FONT_SIZE)
			check(names.size() <= 2, "current character name remains complete in two card lines")
			for line: String in names:
				check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Grid.CARD_FONT_SIZE).x <= Grid.CARD_NAME_WIDTH, "readable sixteen-pixel card names fit without clipping")
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
	var unavailable: Dictionary = {"enabled": false, "reason": "Return to Wellspring free practice before attuning."}
	grid.open_panel(equipped)
	# Every card is already visible; the click alone focuses its exact identity.
	grid.model.select_cell(playable_cell.x, 0)
	var retained_status: String = "Previous host confirmation remains visible."
	grid.model.status_message = retained_status
	equal(grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, point, unavailable), 0, "unavailable card click browses without emitting an authority intent")
	equal(int(grid.model.selected_entry()["wire_id"]), expected_wire, "unavailable card click still focuses the inspected champion")
	equal(grid.model.pending_wire, 0, "unavailable card click creates no synthetic pending request")
	equal(grid.model.status_message, retained_status, "advisory card availability does not overwrite retained host feedback")
	equal(grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, Grid.SELECT_RECT.get_center(), unavailable), 0, "unavailable Attune button emits no request")
	equal(grid.handle_event(_key(KEY_ENTER), font, Vector2(-1, -1), unavailable), 0, "unavailable Enter confirmation emits no request")
	equal(grid.handle_event(_joy(JOY_BUTTON_A), font, Vector2(-1, -1), unavailable), 0, "unavailable controller A confirmation emits no request")
	equal(grid.model.pending_wire, 0, "all unavailable confirmation controls leave pending state empty")
	equal(grid.model.status_message, retained_status, "unavailable keyboard, controller and button controls preserve status feedback")
	var direction_before: int = grid.preview_direction
	equal(grid.handle_event(_key(KEY_BRACKETRIGHT), font, Vector2(-1, -1), unavailable), 0, "unavailable context keeps facing inspection request-free")
	equal(grid.preview_direction, posmod(direction_before + 1, 8), "unavailable context keeps facing inspection available")
	equal(grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, point), 0, "card click is safe inspection, not an attunement request")
	equal(grid.model.pending_wire, 0, "inspection never resets a weave or creates pending authority work")
	check(grid.overview_visible, "newly inspected identity starts at the concise overview")
	grid.handle_event(_key(KEY_END), font)
	check(not grid.overview_visible, "Details preserves full paged information behind summary")
	grid.handle_event(_key(KEY_TAB), font)
	check(grid.overview_visible, "Tab returns to summary without attunement")
	equal(grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, Grid.SELECT_RECT.get_center()), expected_wire, "explicit Attune sends selected stable wire")
	equal(grid.handle_event(_joy(JOY_BUTTON_A), font), 0, "controller confirmation cannot duplicate a pending request")
	grid.refuse("Stay near the Gallery.")
	equal(grid.handle_event(_joy(JOY_BUTTON_A), font), expected_wire, "refused request can be deliberately retried")
	grid.confirm_equipped(String(grid.model.selected_entry()["id"]))
	equal(grid.handle_event(_key(KEY_ENTER), font), 0, "repeated confirmation of current character cannot reset its kit")
	grid.model.select_display_index(20)
	grid.handle_event(_joy(JOY_BUTTON_LEFT_SHOULDER), font)
	equal(String(grid.model.selected_entry().id), "biggy_bob", "controller left shoulder jumps to Middle without paging")
	grid.handle_event(_joy(JOY_BUTTON_RIGHT_SHOULDER), font)
	equal(String(grid.model.selected_entry().id), "ba_djoh", "controller right shoulder jumps to Large without paging")
	equal(grid.model.display_cells().size(), 30, "controller size shortcuts keep the complete roster visible")
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
	var unknown_notes := Grid.overview_notes({})
	equal(unknown_notes.size(), 2, "missing entry has a compact non-playable fallback")
	check(not " ".join(unknown_notes).contains("Attune:") and not " ".join(unknown_notes).contains("paid flight"), "unknown entries cannot advertise attunement or flight")
	return finish("character-selection-grid")


func _test_flat_grid(grid: Grid, font: Font) -> void:
	var cells := grid.model.display_cells()
	equal(cells.size(), 30, "all thirty current characters are present immediately on opening")
	var rectangles: Array[Rect2] = []
	for index: int in range(cells.size()):
		var cell := cells[index]
		var rectangle := grid.card_rect(cell.x, cell.y)
		var expected_position := Grid.GRID_ORIGIN + Vector2((index % 6) * Grid.COLUMN_STRIDE, (index / 6) * Grid.ROW_STRIDE)
		equal(rectangle, Rect2(expected_position, Grid.CARD_SIZE), "sorted projection draws in exactly six columns and five rows")
		equal(grid.cell_at(rectangle.get_center()), cell, "every card can be hit without first selecting or paging its ancestry")
		check(rectangle.end.x <= 820 and rectangle.end.y <= 580, "all cards fit left of details and above persistent status without scrolling")
		for size: Vector2 in [Vector2(1280, 720), Vector2(960, 540)]:
			var scale := size.x / 1280.0
			check(Rect2(Vector2.ZERO, size).encloses(Rect2(rectangle.position * scale, rectangle.size * scale)), "the existing logical-canvas scaling retains every card at supported window sizes")
		for other: Rect2 in rectangles:
			check(not rectangle.intersects(other), "no sorted roster card obscures another character")
		for control: Rect2 in [Grid.HERO_PORTRAIT, Grid.SELECT_RECT, Grid.OVERVIEW_RECT, Grid.PREVIOUS_DETAIL, Grid.NEXT_DETAIL]:
			check(not rectangle.intersects(control), "inspection cards cannot overlap detail or Attune targets")
		rectangles.append(rectangle)
	for size_label: String in ["Small", "Middle", "Large"]:
		check(font.get_string_size(size_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x <= 65, "explicit size labels fit beside the compact portraits")
	check(Grid.CARD_FONT_SIZE * 0.75 >= 12, "minimum supported window preserves twelve-pixel character-name text")
	equal(grid.cell_at(Grid.GRID_ORIGIN + Vector2(Grid.CARD_SIZE.x + 2, 2)), Vector2i(-1, -1), "card gutters are not accidental selection targets")
	equal(grid.card_rect(-1, -1), Rect2(), "invalid backing references cannot create an active card")
	var before := grid.model.selected_entry().duplicate(true)
	grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, Vector2(128, 121))
	equal(grid.model.selected_entry(), before, "retired race-page location is only a read-only heading")
	for index: int in range(cells.size()):
		grid.model.select_display_index(index)
		for visible: int in range(cells.size()):
			equal(grid.card_rect(cells[visible].x, cells[visible].y), rectangles[visible], "navigation never hides or moves any of the thirty cards")


func _test_spatial_bindings(grid: Grid, font: Font) -> void:
	var keyboard := {KEY_LEFT: 13, KEY_A: 13, KEY_RIGHT: 15, KEY_D: 15, KEY_UP: 8, KEY_W: 8, KEY_DOWN: 20, KEY_S: 20}
	for code: Key in keyboard:
		grid.model.select_display_index(14)
		equal(grid.handle_event(_key(code), font), 0, "keyboard inspection never emits a character request")
		equal(grid.model.display_index(grid.model.race_index, grid.model.character_index), keyboard[code], "arrow and WASD bindings track the displayed flat-grid direction")
	var joypad := {JOY_BUTTON_DPAD_LEFT: 13, JOY_BUTTON_DPAD_RIGHT: 15, JOY_BUTTON_DPAD_UP: 8, JOY_BUTTON_DPAD_DOWN: 20}
	for button: JoyButton in joypad:
		grid.model.select_display_index(14)
		equal(grid.handle_event(_joy(button), font), 0, "controller inspection never emits a character request")
		equal(grid.model.display_index(grid.model.race_index, grid.model.character_index), joypad[button], "D-pad direction tracks the displayed flat-grid direction")
	grid.model.select_display_index(14)
	grid.handle_event(_key(KEY_PAGEUP), font)
	equal(String(grid.model.selected_entry().id), "grace_reava", "Page Up focuses the preceding size group")
	grid.handle_event(_key(KEY_PAGEDOWN), font)
	equal(String(grid.model.selected_entry().id), "biggy_bob", "Page Down focuses the following size group")


func _test_native_inspection_geometry(grid: Grid) -> void:
	equal(Grid.FACING_PREVIEW.size, Vector2(128, 128), "full pixel body inspection retains its native 128px cell")
	var floor_anchor := Grid.FACING_PREVIEW.position + Grid.FACING_PIVOT
	for heading: int in 8:
		for body: String in ["small", "middle", "large"]:
			var preview := {"region": Rect2(heading * 128, 0, 128, 128), "fullbody_art": true,
				"pixel_body_pilot": true, "body_type": body}
			var target := Grid.facing_preview_draw_rect(preview)
			equal(target.size, preview.region.size, "every size and heading draws source texels at exactly 1x")
			equal(target.position + Vector2(64, 104), floor_anchor, "all full-pixel body tiers retain a shared visible foot anchor")
			check(Grid.PANEL.encloses(target), "native full-body cell stays inside the Gallery panel")
			for control: Rect2 in [Grid.HERO_PORTRAIT, Grid.PREVIOUS_FACING, Grid.NEXT_FACING, Grid.CLOSE_RECT]:
				check(not target.intersects(control), "native body preview cannot cover portrait or facing/close targets")
	var legacy := Grid.facing_preview_draw_rect({"region": Rect2(0, 0, 96, 96)})
	equal(legacy.size, Vector2(96, 96), "legacy cells are not enlarged when the pixel-body allocation grows")
	equal(legacy.position + Vector2(48, 84), floor_anchor, "separate legacy mode shares the fixed floor without changing its geometry")
	for cell: Vector2i in grid.model.display_cells():
		var card := grid.card_rect(cell.x, cell.y)
		var portrait := Grid.card_portrait_rect(card)
		equal(portrait.size, Vector2(32, 32), "all thirty card icons retain prepared native 32px dimensions")
		equal(portrait.get_center(), card.position + Vector2(24, 24), "smaller native icon is centered in its preserved allocation")
		check(card.encloses(portrait), "native portrait remains within its unchanged roster card")
		check(portrait.end.x < card.position.x + 49 and portrait.end.y < card.position.y + 46, "native icons cannot cover size badges or readable champion names")
		for scale: float in [1.0, 0.75]:
			equal(portrait.size * scale, Vector2(32, 32) * scale, "logical canvas adds no second card-icon resampling factor")
			equal(Grid.FACING_PREVIEW.size * scale, Vector2(128, 128) * scale, "logical canvas adds no second body-preview resampling factor")


func _test_compact_portrait_path(champions: ChampionCatalog, roster: ChampionRosterPlan) -> void:
	var grid := Grid.new()
	var compact := CompactPortraits.new()
	check(grid.configure(champions, roster, compact), "Gallery supports prepared compact override portraits")
	var ids := champions.ordered_champion_ids()
	equal(ids.size(), 30, "compact portrait fixture covers the complete live roster")
	for champion_id: String in ids:
		var frame := grid.portrait_source(champion_id)
		equal((frame["texture"] as Texture2D).get_size(), Vector2(32, 32), "the complete visible Gallery borrows only compact portraits")
		equal(Grid.CARD_PORTRAIT_SIZE, frame.region.size, "prepared compact sprites are drawn without 1.25x enlargement")
		check(not grid.uses_temporary_body(champion_id), "accepted portrait uses effective override art status, not fallback provenance")
	equal(compact.queries, 30, "at most one portrait lookup per visible card")
	equal(compact.full_page_queries, 0, "thirty visible Gallery cards never request or retain full-page textures")
	for champion_id: String in ids:
		grid.portrait_source(champion_id)
	equal(compact.queries, 30, "repeated Gallery draws reuse compact results")
	compact.generation += 1
	grid.portrait_source(ids[0])
	equal(compact.queries, 31, "a validated art reload invalidates stale portrait metadata")
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

extends FluxTestSuite

const Portraits = preload("res://src/presentation/champion_portrait_library.gd")
const Grid = preload("res://src/presentation/character_selection_grid.gd")
const IDS := ["oh_tipi", "s_wayne", "red_baron"]


class FakePortraits:
	extends "res://src/presentation/champion_portrait_library.gd"
	var loads: Array[String] = []
	var missing: Array[String] = []
	var wrong_size := false
	func _load_texture(path: String) -> Texture2D:
		loads.append(path)
		if path.get_file().get_basename() in missing:
			return null
		var texture := GradientTexture2D.new()
		texture.width = 1024 if wrong_size else 512
		texture.height = texture.width
		return texture


class SpritePortraits:
	extends RefCounted
	var texture := GradientTexture2D.new()
	func can_present(_id: String) -> bool:
		return true
	func portrait_frame(_id: String) -> Dictionary:
		return {"texture": texture, "region": Rect2(0, 0, 32, 32), "visual_mode": "pixel_cast"}
	func texture_for_champion(_id: String) -> Texture2D:
		return texture
	func source_region_for_animation_state(_id: String, state: PlayerState, _action: String) -> Rect2:
		return Rect2(EightDirectionResolver.classify_index(state.facing_x, state.facing_y) * 96, 0, 96, 96)


func run() -> int:
	_test_manifest()
	_test_cache()
	_test_gallery()
	return finish("champion-portrait-library")


func _manifest(ids: Array = IDS) -> Dictionary:
	var entries: Array[Dictionary] = []
	for id: String in ids:
		entries.append({"id": id, "file": id + ".png", "width": 512, "height": 512, "sha256": "a".repeat(64)})
	return {"id": Portraits.MANIFEST_ID, "schema_version": 1, "characters": entries}


func _test_manifest() -> void:
	var valid := _manifest()
	equal(Portraits.manifest_error(valid, IDS), "", "canonical bounded portrait registry is accepted")
	equal(Portraits.manifest_error(JSON.parse_string(JSON.stringify(valid)), IDS), "", "JSON integer-float dimensions remain valid")
	for invalid: Variant in [null, true, 4, "bad", [], {}]:
		check(not Portraits.manifest_error(invalid, IDS).is_empty(), "malformed portrait registry is refused")
	for key: String in ["id", "schema_version", "characters"]:
		var changed := valid.duplicate(true)
		changed.erase(key)
		check(not Portraits.manifest_error(changed, IDS).is_empty(), "required portrait header field: " + key)
	for version: Variant in [true, "1", 1.5, null]:
		var changed := valid.duplicate(true)
		changed.schema_version = version
		check(not Portraits.manifest_error(changed, IDS).is_empty(), "schema version cannot be coerced from unrelated JSON types")
	for field: String in ["id", "file", "width", "height", "sha256"]:
		var changed := valid.duplicate(true)
		changed.characters[0].erase(field)
		check(not Portraits.manifest_error(changed, IDS).is_empty(), "required portrait entry field: " + field)
	for file: Variant in ["../oh_tipi.png", "res://secret.png", "nested/oh_tipi.png", "s_wayne.png", "OH_TIPI.png", null]:
		var changed := valid.duplicate(true)
		changed.characters[0].file = file
		check(not Portraits.manifest_error(changed, IDS).is_empty(), "portrait filename cannot traverse or remap identity")
	for edge: Variant in [0, 255, 513, 1024, 512.5, "512", true, NAN, INF, null]:
		var changed := valid.duplicate(true)
		changed.characters[0].width = edge
		check(not Portraits.manifest_error(changed, IDS).is_empty(), "unbounded or malformed texture width is refused")
	for digest: Variant in ["", "g".repeat(64), "a".repeat(63), null, 0]:
		var changed := valid.duplicate(true)
		changed.characters[0].sha256 = digest
		check(not Portraits.manifest_error(changed, IDS).is_empty(), "build digest must be a complete hexadecimal SHA256")
	var duplicate := valid.duplicate(true)
	duplicate.characters.append(duplicate.characters[0].duplicate(true))
	check(not Portraits.manifest_error(duplicate, IDS).is_empty(), "duplicate portrait identity is refused atomically")
	check(not Portraits.manifest_error(valid, ["oh_tipi"]).is_empty(), "unknown catalog identity cannot obtain portrait artwork")
	check(not Portraits.manifest_error(_manifest(["../secret"]), ["../secret"]).is_empty(), "even a malformed catalog cannot authorize path traversal")
	check(not Portraits.manifest_error(_manifest([]), IDS).is_empty(), "empty registry takes the sprite-only fallback")
	var too_many := valid.duplicate(true)
	too_many.characters.resize(Portraits.MAX_ENTRIES + 1)
	check(not Portraits.manifest_error(too_many, IDS).is_empty(), "registry admission is bounded before resource loading")
	var square := valid.duplicate(true)
	square.characters[0].height = 256
	check(not Portraits.manifest_error(square, IDS).is_empty(), "non-square portrait cannot be stretched silently")


func _test_cache() -> void:
	var library := FakePortraits.new()
	check(library.admit_manifest(_manifest(), IDS), "fake portrait assets admit through the production metadata path")
	equal(library.loads.size(), 0, "admission never loads an entire portrait roster")
	equal(library.cached_ids().size(), 0, "no texture retained before inspection")
	var first := library.portrait_frame("oh_tipi")
	check(bool(first.get("detailed_portrait", false)), "selected illustration has explicit Gallery-only metadata")
	equal(first.champion_id, "oh_tipi", "frame retains exact canonical identity")
	equal(library.loads, [Portraits.ROOT + "oh_tipi.png"], "only the selected allowlisted file is loaded")
	library.portrait_frame("oh_tipi")
	equal(library.loads.size(), 1, "repeated redraw reuses selected texture")
	library.portrait_frame("s_wayne")
	library.portrait_frame("oh_tipi")
	library.portrait_frame("red_baron")
	equal(library.cached_ids(), ["oh_tipi", "red_baron"], "third inspection evicts least-recently-used illustration")
	library.portrait_frame("s_wayne")
	equal(library.loads.size(), 4, "evicted illustration is loaded only on a later explicit request")
	equal(library.cached_ids().size(), Portraits.CACHE_LIMIT, "texture retention remains bounded to two")
	var external := library.cached_ids()
	external.clear()
	equal(library.cached_ids().size(), 2, "cache inventory cannot be mutated by caller")
	check(library.portrait_frame("../secret").is_empty(), "unknown identity never reaches loader")
	equal(library.loads.size(), 4, "unknown identity cannot load even a constructed resource path")
	library.release_textures()
	equal(library.cached_ids().size(), 0, "closing Gallery releases its retained illustration textures")
	library.missing.assign(["red_baron"])
	check(library.portrait_frame("red_baron").is_empty(), "unloadable illustration safely requests sprite fallback")
	var failed_loads := library.loads.size()
	for redraw: int in range(10):
		library.portrait_frame("red_baron")
	library.release_textures()
	library.portrait_frame("red_baron")
	equal(library.loads.size(), failed_loads, "negative cache survives redraw and panel close without repeated failed IO")
	check(library.admit_manifest(_manifest(), IDS), "fresh admission is an explicit resource-repair boundary")
	library.missing.clear()
	check(not library.portrait_frame("red_baron").is_empty(), "reconfiguration makes repaired artwork available")
	library.wrong_size = true
	check(library.portrait_frame("oh_tipi").is_empty(), "oversized imported texture is refused instead of retained")
	equal(library.cached_ids(), ["red_baron"], "invalid resource does not evict healthy retained art")
	check(not library.admit_manifest({}, IDS), "invalid reload is rejected")
	equal(library.cached_ids().size(), 0, "invalid reload cannot leave stale illustration ownership")
	check(library.portrait_frame("red_baron").is_empty(), "invalid reload cannot serve earlier metadata")


func _test_gallery() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "portrait fixture ability data loads")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "portrait fixture real character catalog loads")
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "portrait fixture canonical roster loads")
	var grid := Grid.new()
	var sprites := SpritePortraits.new()
	check(grid.configure(champions, roster, sprites), "optional portrait integration preserves Gallery configuration")
	var library := FakePortraits.new()
	check(library.admit_manifest(_manifest(), champions.ordered_champion_ids()), "test illustrations use actual admitted champion IDs")
	grid.portrait_library = library
	grid.open_panel("oh_tipi")
	equal(grid.inspection_label(), "ATTUNED", "initial preview labels the actual equipped identity")
	equal(library.loads.size(), 0, "opening Gallery alone never eagerly loads selected or roster art")
	var compact := grid.portrait_source("oh_tipi")
	equal(compact.texture, sprites.texture, "card portrait remains the presenter's sprite crop")
	equal(compact.region, Rect2(0, 0, 32, 32), "illustration does not alter sprite crop geometry")
	equal(library.loads.size(), 0, "card reads never request detailed art")
	check(grid.hero_portrait_source("oh_tipi").texture != sprites.texture, "only selected hero seam uses detailed art")
	library.missing.assign(["red_baron"])
	equal(grid.hero_portrait_source("red_baron").texture, sprites.texture, "missing selected illustration retains the existing sprite portrait")
	var font := ThemeDB.fallback_font
	var before := [grid.model.equipped_id, grid.model.pending_wire, grid.model.race_index, grid.model.character_index]
	equal(grid.handle_event(_key(KEY_P), font), 0, "portrait enlargement cannot emit attunement")
	check(grid.portrait_expanded, "P opens the read-only large portrait")
	var card := grid.card_rect(grid.model.race_index, grid.model.character_index)
	equal(grid.cell_at(card.get_center()), Vector2i(-1, -1), "covered roster has no invisible hover targets")
	# The roster heading and every card are covered by the read-only portrait.
	# Its explicit Back target is the only action in this left-hand area.
	grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, Vector2(128, 121))
	grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, card.get_center())
	grid.handle_event(_mouse(MOUSE_BUTTON_WHEEL_DOWN), font, card.get_center())
	check(grid.portrait_expanded, "covered roster targets cannot dismiss the read-only portrait")
	equal([grid.model.equipped_id, grid.model.pending_wire, grid.model.race_index, grid.model.character_index], before, "covered roster and former page area cannot change the selection")
	for direction: int in range(8):
		equal(grid.facing_preview("oh_tipi").degrees, direction * 45, "large portrait preserves the exact eight-heading body preview")
		grid.handle_event(_key(KEY_BRACKETRIGHT), font)
	check(grid.portrait_expanded, "facing inspection does not close portrait")
	grid.handle_event(_key(KEY_ESCAPE), font)
	check(not grid.portrait_expanded and grid.is_open, "first Escape returns to roster without closing Gallery")
	equal([grid.model.equipped_id, grid.model.pending_wire, grid.model.race_index, grid.model.character_index], before, "closing portrait preserves identity and selection")
	grid.handle_event(_joy(JOY_BUTTON_START), font)
	check(grid.portrait_expanded, "controller Start opens the same read-only portrait")
	grid.handle_event(_joy(JOY_BUTTON_B), font)
	check(not grid.portrait_expanded and grid.is_open, "controller B returns to roster before closing Gallery")
	grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, Grid.HERO_PORTRAIT.get_center())
	check(grid.portrait_expanded, "thumbnail click opens portrait")
	grid.handle_event(_mouse(MOUSE_BUTTON_LEFT), font, Grid.PORTRAIT_BACK.get_center())
	check(not grid.portrait_expanded and grid.is_open, "visible Back button restores roster")
	grid.handle_event(_key(KEY_P), font)
	grid.handle_event(_key(KEY_RIGHT), font)
	check(not grid.portrait_expanded, "changing character deliberately returns to the roster")
	equal(grid.inspection_label(), "INSPECTING", "browsed identity is not described as already attuned")
	equal(grid.model.equipped_id, "oh_tipi", "inspection label does not change attuned identity")
	equal(grid.model.pending_wire, 0, "portrait and navigation never submit an authority request")
	for rectangle: Rect2 in [Grid.HERO_PORTRAIT, Grid.LARGE_PORTRAIT, Grid.FACING_PREVIEW, Grid.PORTRAIT_BACK, Grid.PREVIOUS_FACING, Grid.NEXT_FACING]:
		check(Grid.PANEL.encloses(rectangle), "portrait and facing targets stay inside logical Gallery bounds")
	check(not Grid.HERO_PORTRAIT.intersects(Grid.FACING_PREVIEW), "illustration never hides the actual body preview")
	check(not Grid.LARGE_PORTRAIT.intersects(Grid.SELECT_RECT), "enlargement cannot cover Attune confirmation")
	check(font.get_string_size("NW 225 / SHARED BODY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 208, "longest facing/fallback label fits its dedicated header width")
	grid.close_panel()
	equal(library.cached_ids().size(), 0, "closing Gallery releases optional detailed textures")
	check(not grid.configure(null, null, sprites), "invalid Gallery reload still refuses stale catalogs")
	check(grid.hero_portrait_source("oh_tipi").is_empty(), "invalid Gallery reload releases sprite and illustration fallbacks")


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

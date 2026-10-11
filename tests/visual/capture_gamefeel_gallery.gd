extends "res://tests/visual/capture_glow_flow.gd"


# Reuse the existing minimized-root/SubViewport readback and image receipt
# plumbing. This harness only inspects the real Gallery model; it does not
# attune, change a weave, inject movement, or simulate physical input.
const INSPECT_IDS := ["s_wayne", "oh_tipi", "red_baron", "grace_reava"]
const EXPECTED_SELECTIONS := {
	"s_wayne": {"body_type": "small", "air_action": "double_jump"},
	"oh_tipi": {"body_type": "middle", "air_action": "double_jump"},
	"red_baron": {"body_type": "large", "air_action": "double_jump"},
	"grace_reava": {"body_type": "small", "air_action": "flight"},
}
const STARTER_COMPOSITION_PHRASES := [
	"twelve-slot starter", "eight element Bolts", "one Heavy", "strongest affinity",
	"first listed on a tie", "three Rapid/Spray",
]
const GALLERY_SOURCES := [
	"res://src/app/bootstrap.gd",
	"res://src/app/character_overview_model.gd",
	"res://src/app/character_selection_model.gd",
	"res://src/presentation/character_selection_grid.gd",
	"res://src/content/character_starter_kit.gd",
	"res://src/content/champion_catalog.gd",
	"res://content/champions/foundation_champions_v1.json",
	"res://content/champions/champion_roster_plan_v1.json",
	"res://content/runtime/runtime_build_identity_v1.json",
	"res://tests/visual/capture_glow_flow.gd",
	"res://tests/visual/capture_gamefeel_gallery.gd",
]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/gamefeel-gallery-native-") \
			or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Provide native rendering and fresh --output=res://.godot/gamefeel-gallery-native-NAME")
		return
	if "--pixel-cast" not in OS.get_cmdline_user_args():
		_fail("Gallery capture requires the production --pixel-cast route")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Could not create fresh Gallery evidence directory")
		return
	for path: String in GALLERY_SOURCES:
		source_hashes[path] = FileAccess.get_sha256(path)
	root.visible = true
	root.mode = Window.MODE_MINIMIZED
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = BootstrapScene.instantiate()
	game.set_process(false)
	viewport.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null:
		game.element_audio.silence()
		game.element_audio.set_process(false)
		game.element_audio.volume_percent = 0
	await process_frame
	if game.world == null or game.character_selection_grid == null \
			or game.cartoon_champion_presenter == null or game.cartoon_champion_presenter.fullbody_art == null:
		_fail("Production Gallery and pixel-cast scene did not initialize")
		return
	var authority_hash: String = game.world.state_hash()
	var equipped_id: String = game._champion_visual_id(game._local_player_state())
	for champion_id: String in INSPECT_IDS:
		if not _inspect(champion_id, equipped_id):
			return
		if not await _capture_gallery(champion_id + "-overview", "overview", champion_id, authority_hash, equipped_id):
			return
	# Inspect the current generated starter description, not obsolete foundation
	# aliases. It remains an ordinary paged production Details view.
	if not _inspect("oh_tipi", equipped_id):
		return
	var grid: CharacterSelectionGrid = game.character_selection_grid
	grid.overview_visible = false
	var best_page := -1
	var best_score := 0
	var all_detail_lines: Array[String] = []
	for page: int in range(grid.detail_pages(ThemeDB.fallback_font)):
		grid.detail_page = page
		var page_lines := grid.visible_detail_lines(ThemeDB.fallback_font)
		all_detail_lines.append_array(page_lines)
		var coverage := _starter_coverage(page_lines)
		var score: int = coverage.visible_phrases.size()
		if score > best_score:
			best_score = score
			best_page = page
	if best_page < 0:
		_fail("No production Details page exposes the twelve-slot starter rules")
		return
	if not bool(_starter_coverage(all_detail_lines).complete):
		_fail("Production Details no longer contains every required starter-composition phrase")
		return
	grid.detail_page = best_page
	var starter_complete := best_score == STARTER_COMPOSITION_PHRASES.size()
	var starter_label := "oh_tipi-starter-details" if starter_complete else "oh_tipi-starter-details-fragment"
	if not await _capture_gallery(starter_label, "starter-details", "oh_tipi", authority_hash, equipped_id):
		return
	if frames.size() != 5 or cases.size() != 5 or not root.visible:
		_fail("Gallery capture must retain five screens and a visible-flag minimized root")
		return
	for path: String in GALLERY_SOURCES:
		if String(source_hashes[path]).length() != 64 or FileAccess.get_sha256(path) != source_hashes[path]:
			_fail("Gallery source changed during native inspection: " + path)
			return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Could not save Gallery receipt")
		return
	receipt.store_string(JSON.stringify({
		"status": "passed", "frames": frames, "inspections": cases, "sources": source_hashes,
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"display": {"server": DisplayServer.get_name(), "root_visible": root.visible,
			"minimized_root": root.mode == Window.MODE_MINIMIZED, "unfocusable": root.unfocusable,
			"subviewport": [1280, 720], "update_always": true, "resized": false},
		"authority_hash_before_and_after": authority_hash,
		"expected_selections": EXPECTED_SELECTIONS,
		"starter_composition_complete_on_captured_page": starter_complete,
		"starter_details_claim": "All six composition phrases are visible on the captured production Details page." if starter_complete else "PARTIAL PAGE ONLY: composition is split by production pagination. Only the receipt's visible_phrases are evidenced by this screenshot; missing_phrases are not visually accepted.",
		"method": "Actual Bootstrap scene, CharacterSelectionGrid and production _draw. Programmatic menu opening/card inspection only. Four asserted overview screens cover Small, Middle, Large and flying Grace Riva; one normal paged Details screen records exact starter-composition phrase coverage, without claiming any off-page text is visible. Five unscaled full native screenshots; per-file SHA256 recorded.",
		"limitations": "Scripted local native inspection, not physical keyboard/controller interaction, confirmed attunement, saved-weave restoration, movement/flight execution, all-roster visual acceptance, low-resolution readability, multiplayer, performance or human acceptance. The world is intentionally frozen; no simulation state, resource, loadout or capability is injected. Root window remains minimized, not hidden.",
	}, "\t") + "\n")
	receipt.close()
	print("PASS gamefeel Gallery native:4 asserted overviews +1 Details page;5 images; authority unchanged; complete starter composition=" + str(starter_complete))
	quit(0)


func _inspect(champion_id: String, equipped_id: String) -> bool:
	var grid: CharacterSelectionGrid = game.character_selection_grid
	grid.open_panel(equipped_id)
	for race: int in range(grid.model.races().size()):
		var entries: Array = grid.model.characters(race)
		for character: int in range(entries.size()):
			if String(entries[character].id) == champion_id:
				grid.model.select_cell(race, character)
				return true
	_fail("Requested canonical identity is absent from production Gallery: " + champion_id)
	return false


func _capture_gallery(label: String, kind: String, expected_id: String, authority_hash: String, equipped_id: String) -> bool:
	var grid: CharacterSelectionGrid = game.character_selection_grid
	var entry: Dictionary = grid.model.selected_entry()
	if not grid.is_open or entry.is_empty() or not bool(entry.get("stats_available", false)):
		_fail("Gallery must expose a real playable selection")
		return false
	if not await _redraw():
		return false
	entry = grid.model.selected_entry()
	if not EXPECTED_SELECTIONS.has(expected_id) or kind not in ["overview", "starter-details"]:
		_fail("Gallery capture has an unknown expected identity or screen kind")
		return false
	var expected: Dictionary = EXPECTED_SELECTIONS[expected_id]
	if not grid.is_open or String(entry.get("id", "")) != expected_id \
			or not bool(entry.get("stats_available", false)) \
			or grid.overview_visible != (kind == "overview") \
			or String(entry.get("body_type", "")) != String(expected.body_type) \
			or String(entry.get("air_action", "")) != String(expected.air_action):
		_fail("Production Gallery selection, kind, body size or air action differs from the expected capture: " + expected_id)
		return false
	var flight_duration := int(entry.get("flight_duration_ms", 0))
	if (String(expected.air_action) == "flight" and flight_duration <= 0) \
			or (String(expected.air_action) == "double_jump" and flight_duration != 0):
		_fail("Production Gallery flight duration disagrees with the expected air action: " + expected_id)
		return false
	var visible_lines: Array[String] = []
	if not grid.overview_visible:
		visible_lines.assign(grid.visible_detail_lines(ThemeDB.fallback_font))
	var starter_coverage := _starter_coverage(visible_lines)
	var expected_label := expected_id + "-overview"
	if kind == "starter-details":
		if expected_id != "oh_tipi" or starter_coverage.visible_phrases.is_empty():
			_fail("Starter Details capture must show Oh Tipi and actual composition text")
			return false
		expected_label = "oh_tipi-starter-details" if bool(starter_coverage.complete) else "oh_tipi-starter-details-fragment"
	if label != expected_label:
		_fail("Gallery filename must match its asserted identity, kind and visible coverage")
		return false
	if game.world.state_hash() != authority_hash or grid.model.equipped_id != equipped_id or grid.model.pending_wire != 0:
		_fail("Read-only Gallery inspection changed authority, equipped identity or request state")
		return false
	if not _store(viewport.get_texture().get_image(), label, "production-gallery-" + kind):
		return false
	cases.append({
		"file": frames.back().file, "selected_champion": String(entry.id), "equipped_champion": equipped_id,
		"expected_champion": expected_id, "kind": kind, "expected_overview": kind == "overview",
		"expected_body_size": String(expected.body_type), "expected_air_action": String(expected.air_action),
		"race": String(entry.race_id), "body_size": String(entry.body_type), "air_action": String(entry.air_action),
		"flight_duration_ms": int(entry.flight_duration_ms), "overview": grid.overview_visible,
		"overview_notes": CharacterSelectionGrid.overview_notes(entry),
		"detail_page": grid.detail_page, "detail_page_count": grid.detail_pages(ThemeDB.fallback_font),
		"visible_detail_lines": visible_lines,
		"starter_composition": starter_coverage if kind == "starter-details" else {},
		"status_message": grid.model.status_message, "pending_wire": grid.model.pending_wire,
		"world_hash": authority_hash,
	})
	return true


func _starter_coverage(lines: Array[String]) -> Dictionary:
	var visible_text := " ".join(lines)
	var visible_phrases: Array[String] = []
	var missing_phrases: Array[String] = []
	for phrase: String in STARTER_COMPOSITION_PHRASES:
		if visible_text.contains(phrase):
			visible_phrases.append(phrase)
		else:
			missing_phrases.append(phrase)
	return {"complete": missing_phrases.is_empty(), "required_phrases": STARTER_COMPOSITION_PHRASES,
		"visible_phrases": visible_phrases, "missing_phrases": missing_phrases}

extends "res://tests/visual/capture_gamefeel_gallery.gd"
## Production Gallery inspection only; root owns native engine and APPDATA.

const PERK_SOURCES := [
	"res://src/app/bootstrap.gd",
	"res://src/app/character_overview_model.gd",
	"res://src/app/character_selection_model.gd",
	"res://src/presentation/character_selection_grid.gd",
	"res://src/presentation/player_compendium.gd",
	"res://src/sim/entities/identity_perk_policy.gd",
	"res://src/content/race_perk_catalog.gd",
	"res://src/content/character_perk_catalog.gd",
	"res://content/runtime/runtime_build_identity_v1.json",
	"res://tests/visual/capture_identity_perks.gd",
]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/identity-perks-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Provide native rendering and fresh --output=res://.godot/identity-perks-native-NAME")
		return
	if "--pixel-cast" not in OS.get_cmdline_user_args():
		_fail("Perk capture requires the production --pixel-cast route")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create fresh perk capture directory")
		return
	# Include the inherited production catalogs and readback helpers as well as
	# the new policy/UI seam; hashing an output identity alone misses file drift.
	for path: String in GALLERY_SOURCES + PERK_SOURCES:
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
	if game.world == null or game.character_selection_grid == null:
		_fail("Production Gallery did not initialize")
		return
	var grid: CharacterSelectionGrid = game.character_selection_grid
	var equipped: String = game._champion_visual_id(game._local_player_state())
	var authority: String = game.world.state_hash()
	var records: Array[Dictionary] = []
	for id: String in game.champion_catalog.ordered_champion_ids():
		if not _inspect(id, equipped): return
		var entry := grid.model.selected_entry()
		var lines := CharacterSelectionGrid.overview_note_lines(entry, ThemeDB.fallback_font)
		if lines.size() > CharacterSelectionGrid.OVERVIEW_NOTE_MAX_LINES or entry.identity_perks.size() != 2:
			_fail("Perk overview exceeds its visible budget: " + id)
			return
		for line: String in lines:
			if ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, CharacterSelectionGrid.OVERVIEW_NOTE_SIZE).x > CharacterSelectionGrid.DETAIL_WIDTH + 0.01:
				_fail("Perk overview overflows horizontally: " + id)
				return
		records.append({"id": id, "line_count": lines.size(), "overview_lines": lines, "perks": entry.identity_perks})
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.line_count) > int(b.line_count) if a.line_count != b.line_count else String(a.id) < String(b.id))
	var inspect_ids: Array[String] = ["oh_tipi", "grace_reava"]
	for record: Dictionary in records:
		if not String(record.id) in inspect_ids:
			inspect_ids.append(String(record.id))
		if inspect_ids.size() == 4: break
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		viewport.size = resolution
		for id: String in inspect_ids:
			if not _inspect(id, equipped): return
			if not await _capture_perk_view(id, authority, equipped): return
		# The most text-heavy identity also exercises two pages of full rules.
		if not _inspect(String(records[0].id), equipped): return
		grid.overview_visible = false
		for page: int in range(mini(2, grid.detail_pages(ThemeDB.fallback_font))):
			grid.detail_page = page
			if not await _capture_perk_view(String(records[0].id), authority, equipped): return
	grid.close_panel()
	for path: String in source_hashes:
		if String(source_hashes[path]).length() != 64 or FileAccess.get_sha256(path) != source_hashes[path]:
			_fail("Perk capture source changed during verification: " + path)
			return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Cannot save perk capture receipt")
		return
	receipt.store_string(JSON.stringify({"status": "passed", "frames": frames, "all_identity_checks": records, "source_hashes": source_hashes,
		"authority_hash_before_and_after": authority, "equipped_before_and_after": equipped,
		"scope": "All thirty policy projections and overview bounds; four production overviews including the longest notes and two detail pages at both native viewport sizes.",
		"limitations": "Scripted read-only rendering does not establish runtime perk triggers, balance, physical controls, animation, networking or human readability/fun. Inspect every saved frame.",
	}, "\t") + "\n")
	receipt.close()
	print("PASS identity perks native: ", records.size(), " identities; ", frames.size(), " native frames; authority unchanged")
	quit(0)


func _capture_perk_view(id: String, authority: String, equipped: String) -> bool:
	var grid: CharacterSelectionGrid = game.character_selection_grid
	if not await _redraw(): return false
	if String(grid.model.selected_entry().id) != id or grid.model.equipped_id != equipped or grid.model.pending_wire != 0 or game.world.state_hash() != authority:
		_fail("Perk inspection changed selection or authority")
		return false
	var size: Vector2i = viewport.size
	var kind := "overview" if grid.overview_visible else "details-%d" % grid.detail_page
	var path := output.path_join("%s-%s-%dx%d.png" % [id, kind, size.x, size.y])
	var pixels := viewport.get_texture().get_image()
	if pixels == null or pixels.get_size() != size or pixels.save_png(path) != OK:
		_fail("Native perk readback/save failed")
		return false
	frames.append({"file": path.get_file(), "sha256": FileAccess.get_sha256(path), "width": size.x, "height": size.y,
		"selected": id, "equipped": equipped, "kind": kind, "detail_page": grid.detail_page,
		"visible_lines": CharacterSelectionGrid.overview_note_lines(grid.model.selected_entry(), ThemeDB.fallback_font) if grid.overview_visible else grid.visible_detail_lines(ThemeDB.fallback_font)})
	return true

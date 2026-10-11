extends "res://tests/visual/capture_unified_wellspring.gd"

# Production UI with isolated, deliberately selected presentation states.
# These images prove drawing/authority nonmutation, not human play acceptance.
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/aspect-refinement-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh native aspect-refinement output required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create capture output")
		return
	root.size = Vector2i(WIDTH, HEIGHT)
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null: game.element_audio.silence()
	if game.world == null:
		_fail("production world did not boot")
		return
	var actor: PlayerState = game.world.player()
	_sync()
	var grid: CharacterSelectionGrid = game.character_selection_grid
	for champion: String in ["oh_tipi", "grace_reava"]:
		grid.open_panel(game.champion_catalog.champion_id_from_wire(actor.champion_wire_id))
		for race: int in range(grid.model.races().size()):
			var entries: Array = grid.model.characters(race)
			for index: int in range(entries.size()):
				if String(entries[index].id) == champion:
					grid.model.select_cell(race, index)
		if String(grid.model.selected_entry().id) != champion:
			_fail("Gallery inspection did not select the requested identity")
			return
		grid.overview_visible = false
		var air_page := -1
		for page: int in range(grid.detail_pages(ThemeDB.fallback_font)):
			grid.detail_page = page
			if " ".join(grid.visible_detail_lines(ThemeDB.fallback_font)).contains("airtime"):
				air_page = page
				break
		if air_page < 0:
			_fail("air capability detail not reachable: " + champion)
			return
		if not await _both(champion + "-air-capability", "production-gallery-selected-detail"): return
		grid.close_panel()
	game.player_compendium.open_panel(PlayerCompendium.CHEMISTRY, game.player_preferences, actor)
	game.player_compendium.selected_row = 4
	game.player_compendium.selected_element_column = 3
	game.player_compendium.show_details = true
	if not await _both("vortex-counter", "production-pair-guide"): return
	game.player_compendium.close_panel()
	game.spell_loom_editor.open_editor(actor, game.ability_catalog)
	game.spell_loom_editor.set_element_filter("water")
	var source := -1
	for slot: int in range(PlayerState.SPELL_SLOT_COUNT):
		if String(game.ability_catalog.ability_from_wire(actor.spell_wire_id(slot + 1)).element) != "water":
			source = slot
			break
	if source < 0:
		_fail("fixture needs an equipped off-filter spell")
		return
	var before := actor.canonical_values()
	game.spell_loom_editor.pointer_down(SpellLoomEditor.slot_rect(source).get_center(), actor)
	if not game.spell_loom_editor.pointer_up(SpellLoomEditor.slot_rect((source + 1) % 12).get_center()) or game.spell_loom_editor.selected_element_filter != "" or actor.canonical_values() != before:
		_fail("filtered drag did not reveal its exact uncommitted selection")
		return
	if not await _both("loom-revealed-drop", "production-pointer-drop-preview-no-equipment-mutation"): return
	game.spell_loom_editor.close_editor()
	actor.health = 1
	actor.flux = 1
	actor.stamina = 1
	actor.spawn_protection_ticks = 0
	_sync()
	if not await _both("fractional-resources", "presentation-fixture-positive-one-milliunit"): return
	actor.health = actor.health_maximum
	actor.flux = actor.flux_maximum
	actor.stamina = actor.stamina_maximum
	for sample: Dictionary in [{"name":"coastal-water", "point":Vector2(72, 706.656)}, {"name":"garden-contact", "point":Vector2(300, 720)}]:
		var point: Vector2 = sample.point
		actor.position_x = roundi(point.x * 1000.0)
		actor.position_y = roundi(point.y * 1000.0)
		_sync()
		game.player_camera.clear()
		for tick: int in range(240):
			game.player_camera.advance(point, Vector2.ZERO, Vector2.UP, 1.0 / 120.0, Vector2(WIDTH, HEIGHT), Rect2(Vector2.ZERO, Vector2(game.campus_layout.canvas_size)))
		if not await _both(String(sample.name), "production-receiving-shadow-position-fixture"): return
	var file := FileAccess.open(output + "/receipt.json", FileAccess.WRITE)
	if file == null:
		_fail("cannot save aspect capture receipt")
		return
	file.store_string(JSON.stringify({"status":"passed", "frames":frames, "runtime_identity":JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)), "scope":"native production gallery, pair guide, real editor pointer drop and deliberate fractional HUD fixture; every draw preserves authority; isolated preferences; no human, network, performance or physical input acceptance"}, "\t") + "\n")
	file.close()
	print("PASS aspect-refinement native frames=", frames.size())
	quit(0)


func _both(label: String, kind: String) -> bool:
	for reduced: bool in [false, true]:
		game.requested_capture_reduced_effects = reduced
		if (await _capture_frame(label + ("-reduced" if reduced else "-normal"), kind, reduced)).is_empty() or failed: return false
	return true

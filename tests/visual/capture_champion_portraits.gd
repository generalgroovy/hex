extends "res://tests/visual/capture_gamefeel_gallery.gd"
## Production Gallery rendering, never attunement or gameplay simulation.
## Root owns the engine lease and isolated APPDATA for this native fixture.

const PortraitLibrary = preload("res://src/presentation/champion_portrait_library.gd")
const PORTRAIT_SOURCES := [
	"res://src/app/bootstrap.gd",
	"res://src/presentation/character_selection_grid.gd",
	"res://src/presentation/champion_portrait_library.gd",
	"res://content/runtime/runtime_build_identity_v1.json",
	"res://assets/portraits/champions_v1/manifest.json",
	"res://tests/visual/capture_champion_portraits.gd",
]
const CAPTURE_IDS := ["s_wayne", "oh_tipi", "red_baron", "grace_reava"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/champion-portraits-native-") \
			or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Provide native rendering and fresh --output=res://.godot/champion-portraits-native-NAME")
		return
	if "--pixel-cast" not in OS.get_cmdline_user_args():
		_fail("Portrait capture requires the production --pixel-cast route")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create fresh portrait capture directory")
		return
	for path: String in PORTRAIT_SOURCES:
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
		_fail("Production pixel-cast Gallery did not initialize")
		return
	var grid: CharacterSelectionGrid = game.character_selection_grid
	var equipped: String = game._champion_visual_id(game._local_player_state())
	var authority: String = game.world.state_hash()
	var all_ids: Array = game.champion_catalog.ordered_champion_ids()
	if grid.portrait_library.entries.size() != all_ids.size() or not grid.portrait_library.cached_ids().is_empty():
		_fail("Complete portrait roster must be admitted without startup texture loading")
		return
	# All-live-ID asset seam/cache checks are not all-roster visual acceptance.
	for id: String in all_ids:
		if not _inspect(id, equipped):
			return
		var sprite_before := grid.portrait_source(id)
		var hero := grid.hero_portrait_source(id)
		if not bool(hero.get("detailed_portrait", false)) or hero.get("champion_id") != id \
				or grid.portrait_library.cached_ids().size() > PortraitLibrary.CACHE_LIMIT \
				or grid.portrait_source(id) != sprite_before:
			_fail("Portrait identity, lazy bound or sprite preservation failed: " + id)
			return
		for direction: int in range(8):
			grid.preview_direction = direction
			var body := grid.facing_preview(id)
			if body.is_empty() or int(body.get("degrees", -1)) != direction * 45:
				_fail("Portrait integration lost the actual eight-heading body: " + id)
				return
		var entry: Dictionary = grid.portrait_library.entries[id]
		var source_path := PortraitLibrary.ROOT + String(entry.file)
		source_hashes[source_path] = FileAccess.get_sha256(source_path)
		if source_hashes[source_path] != entry.sha256:
			_fail("Portrait PNG does not match its build manifest: " + id)
			return
		cases.append({"champion": id, "texture_size": [hero.texture.get_width(), hero.texture.get_height()],
			"cached_ids": grid.portrait_library.cached_ids(), "eight_headings": true, "sprite_crop_unchanged": true})
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		viewport.size = resolution
		for id: String in CAPTURE_IDS:
			if not _inspect(id, equipped):
				return
			if not await _capture_portrait(id, false, false, equipped, authority):
				return
			grid.toggle_portrait()
			if not grid.portrait_expanded:
				_fail("Read-only portrait toggle did not open: " + id)
				return
			if not await _capture_portrait(id, true, false, equipped, authority):
				return
		# Synthetic absence is explicit and local to this Gallery instance.
		# It proves the normal sprite fallback, not physical file-corruption QA.
		var installed := grid.portrait_library
		grid.portrait_library = PortraitLibrary.new()
		if not _inspect("oh_tipi", equipped):
			return
		grid.toggle_portrait()
		if not await _capture_portrait("oh_tipi", true, true, equipped, authority):
			return
		grid.portrait_library = installed
	grid.close_panel()
	if not grid.portrait_library.cached_ids().is_empty() or game.world.state_hash() != authority:
		_fail("Gallery close did not release art or inspection altered authority")
		return
	for path: String in source_hashes:
		if String(source_hashes[path]).length() != 64 or FileAccess.get_sha256(path) != source_hashes[path]:
			_fail("Portrait capture source changed during verification: " + path)
			return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Cannot save portrait receipt")
		return
	receipt.store_string(JSON.stringify({"status": "passed", "frames": frames, "asset_checks": cases,
		"source_hashes": source_hashes, "runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"authority_hash_before_and_after": authority, "equipped_before_and_after": equipped,
		"display": {"server": DisplayServer.get_name(), "root_visible": root.visible, "minimized_root": root.mode == Window.MODE_MINIMIZED,
			"unfocusable": root.unfocusable, "native_subviewport_sizes": [[1280, 720], [960, 540]], "image_resizing": false},
		"scope": "All live identity portrait resources and eight-facing body seams checked; four representative production Gallery overview/large-portrait views at two native viewport sizes, plus explicitly synthetic missing-library fallbacks. No attunement or simulation mutation. Source PNG hashes freeze capture inputs, not artwork quality.",
		"limitations": "Scripted local rendering is not physical input, confirmed attunement, all-roster visual acceptance, animation-cycle, network, performance, human readability/fun acceptance or real corrupted-import handling. Engine loader diagnostics are not suppressed. Reviewer must inspect every saved image for actual layout/readability.",
	}, "\t") + "\n")
	receipt.close()
	print("PASS champion portraits native: ", cases.size(), " live resources; ", frames.size(), " native frames; authority unchanged")
	quit(0)


func _capture_portrait(id: String, expanded: bool, fallback: bool, equipped: String, authority: String) -> bool:
	var grid: CharacterSelectionGrid = game.character_selection_grid
	if not await _redraw():
		return false
	var hero := grid.hero_portrait_source(id)
	if grid.model.selected_entry().get("id") != id or grid.portrait_expanded != expanded \
			or hero.is_empty() or bool(hero.get("detailed_portrait", false)) == fallback \
			or grid.model.equipped_id != equipped or grid.model.pending_wire != 0 or game.world.state_hash() != authority:
		_fail("Portrait capture selection, art seam or read-only state differs: " + id)
		return false
	var size: Vector2i = viewport.size
	var label := id + ("-large" if expanded else "-overview") + ("-sprite-fallback" if fallback else "")
	var path := output.path_join("%s-%dx%d.png" % [label, size.x, size.y])
	var pixels := viewport.get_texture().get_image()
	if pixels == null or pixels.get_size() != size or pixels.save_png(path) != OK:
		_fail("Native portrait readback/save failed")
		return false
	frames.append({"file": path.get_file(), "sha256": FileAccess.get_sha256(path), "width": size.x, "height": size.y,
		"selected": id, "equipped": equipped, "inspection_label": grid.inspection_label(), "large": expanded,
		"synthetic_missing_library": fallback, "facing": grid.preview_direction, "cached_ids": grid.portrait_library.cached_ids()})
	return true

extends "res://tests/visual/capture_overnight_interfaces.gd"


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/four-delivery-interfaces-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh four-delivery-interfaces output directory")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot configure actual game draw fixture")
		return
	node.reaction_catalog = ReactionCatalog.new()
	node.reaction_definitions = ReactionDefinitionTable.new()
	var roster := ChampionRosterPlan.new()
	if not node.reaction_catalog.load_from_file(node.REACTION_CATALOG_PATH) or not node.reaction_definitions.compile(node.reaction_catalog, node.ability_catalog) or not roster.load_from_files() or not node.player_compendium.configure(node.champion_catalog, roster) or not node._ensure_runtime_identity():
		fail("Cannot bind current source-derived interface content")
		return
	node.runtime_content_summary = RuntimeContentSummary.build(node.ability_catalog, node.champion_catalog, node.reaction_catalog)
	node.runtime_content_lines = RuntimeContentSummary.spell_loom_lines(node.runtime_content_summary)
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	node.visual_accessibility_filter = VisualAccessibilityFilter.new()
	node.add_child(node.visual_accessibility_filter)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = size
		for case_name: String in ["loom-water", "loom-dark", "chemistry-order", "chemistry-water-air", "character-affinities"]:
			node.spell_loom_editor.close_editor()
			node.player_compendium.close_panel()
			if case_name.begins_with("loom-"):
				node.spell_loom_editor.open_editor(node.world.player(), node.ability_catalog)
				node.spell_loom_editor.selected_spell_index = 0 if case_name == "loom-water" else 31
			elif case_name == "character-affinities":
				node._open_player_compendium(PlayerCompendium.CHARACTERS)
			else:
				node._open_player_compendium(PlayerCompendium.CHEMISTRY)
				if case_name == "chemistry-water-air":
					node.player_compendium.selected_row = 1
					node.player_compendium.selected_element_column = 3
					node.player_compendium.show_details = true
			for reduced: bool in [false, true]:
				if not await capture(case_name, size, reduced):
					return
	var source_hashes := {}
	for path: String in ["res://src/app/bootstrap.gd", "res://src/app/spell_loom_editor.gd", "res://src/presentation/spell_loom_presenter.gd", "res://src/presentation/player_compendium.gd", "res://src/presentation/chemistry_guide_model.gd", "res://content/abilities/foundation_abilities_v1.json", RuntimeBuildIdentity.MANIFEST_PATH, "res://tests/visual/capture_four_delivery_interfaces.gd", "res://tests/support/chemistry_coach_harness.gd"]:
		source_hashes[path] = FileAccess.get_sha256(path)
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Cannot retain four-delivery interface evidence")
		return
	receipt.store_string(JSON.stringify({
		"schema_version": 1, "frames": frames, "source_hashes": source_hashes,
		"runtime_build_id": node.session_transport.build_id, "runtime_source_sha256": node.session_transport.runtime_source_sha256,
		"method": "Inherited production draw with source-derived menus; controlled UI state, no input playthrough",
		"preferences": "transient fixture under isolated APPDATA", "network": "not_started", "human_acceptance": "not_run",
		"authority_unchanged_by_every_draw": true,
	}, "  "))
	receipt.close()
	print("PASS: %d four-delivery interface frames; 720/1080 normal/reduced; every draw preserves authority" % frames.size())
	quit(0)

extends SceneTree
## Actual Bootstrap drawing with arranged UI controls; no save or play claims.
const Scene = preload("res://scenes/bootstrap/bootstrap.tscn")
const Compendium = preload("res://src/presentation/player_compendium.gd")
const Elements = preload("res://src/content/element_rules.gd")
const Weaves = preload("res://src/app/character_weave_library.gd")
const CASES := [["water","spray"],["fire","rapid"],["wind","bolt"],["earth","heavy"],["light","bolt"],["dark","spray"]]
const MASKS := [14,15,31,63]
const SOURCES := ["res://src/app/bootstrap.gd","res://src/app/spell_loom_editor.gd","res://src/presentation/spell_loom_presenter.gd","res://src/presentation/player_compendium.gd","res://src/presentation/chemistry_guide_model.gd","res://src/content/element_rules.gd","res://src/sim/hex/hex_recipe_policy.gd","res://src/sim/hex/hex_composite_policy.gd","res://content/abilities/foundation_abilities_v1.json","res://content/reactions/six_element_reactions_v2.json","res://content/runtime/runtime_build_identity_v1.json","res://tests/visual/capture_balance_loom.gd"]
var output := ""
var game: Node
var viewport: SubViewport
var authority := ""
var saved_files := {}
var startup_saved_files := {}
var frames: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not output.begins_with("res://.godot/balance-loom-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Fresh native res://.godot/balance-loom-native-* output required"); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: _fail("Cannot create capture directory"); return
	var hashes := {}
	for path: String in SOURCES:
		hashes[path]=FileAccess.get_sha256(path)
		if String(hashes[path]).length()!=64: _fail("Missing source: "+path); return
	for path: String in [PlayerPreferences.DEFAULT_PATH,Weaves.DEFAULT_PATH,Weaves.DEFAULT_PATH+Weaves.BACKUP_SUFFIX]:
		saved_files[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	startup_saved_files=saved_files.duplicate()
	root.visible=true
	root.mode=Window.MODE_MINIMIZED
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game=Scene.instantiate()
	game.preference_overrides_are_transient=true
	game.preferences_persistence_allowed=false
	game.set_process(false)
	viewport.add_child(game)
	# Ordinary _ready may create defaults before applying transient overrides.
	# UI capture begins only after that isolated initialization completes.
	game.preference_overrides_are_transient=true
	game.preferences_persistence_allowed=false
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.application_input_active=true
	if game.element_audio!=null:
		game.element_audio.silence()
		game.element_audio.set_process(false)
	await process_frame
	if game.world==null or game.player_compendium==null: _fail("Production Bootstrap failed"); return
	for path: String in saved_files:
		var initialized := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
		if initialized!=saved_files[path]:
			if path!=PlayerPreferences.DEFAULT_PATH or saved_files[path]!="ABSENT" or initialized=="ABSENT":
				_fail("Initialization changed pre-existing preferences or weave bytes: "+path); return
		saved_files[path]=initialized
	authority=game.world.state_hash()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		viewport.size=size
		game.player_compendium.close_panel()
		game.spell_loom_editor.open_editor(game._local_player_state(),game.ability_catalog)
		for choice: Array in CASES:
			var ability: Dictionary=game.ability_catalog.ability(game.ability_catalog.spell_id_at(choice[0],choice[1]))
			if ability.is_empty() or not game.spell_loom_editor.set_element_filter(choice[0]): _fail("Missing canonical Loom choice"); return
			game.spell_loom_editor.selected_spell_index=game.spell_loom_editor.available_wire_ids.find(int(ability.wire_id))
			if game.spell_loom_editor.selected_spell_index<0: _fail("Live Loom card unavailable"); return
			var leaf := "%s-%s-%dx%d.png" % [choice[0],choice[1],size.x,size.y]
			if not await _capture(leaf,{"kind":"loom","wire_id":int(ability.wire_id),"metrics":SpellLoomPresenter.spell_metrics(ability),"detail":SpellLoomPresenter.family_detail(ability)}): return
		if not game.spell_loom_editor.set_element_filter("") or game.spell_loom_editor.visible_spell_indices().size()!=24:
			_fail("Complete canonical Loom grid unavailable"); return
		game.spell_loom_editor.selected_spell_index=game.spell_loom_editor.available_wire_ids.size()-1
		var visible_wires: Array[int]=[]
		for index: int in game.spell_loom_editor.visible_spell_indices():
			visible_wires.append(int(game.spell_loom_editor.available_wire_ids[index]))
		if not await _capture("all-spells-%dx%d.png" % [size.x,size.y],{"kind":"loom_all","visible_wire_ids":visible_wires,"selected_wire_id":game.spell_loom_editor.selected_wire_id()}): return
		game.spell_loom_editor.close_editor()
		game._open_player_compendium(Compendium.CHEMISTRY)
		var panel: RefCounted=game.player_compendium
		panel.move_row(1)
		if not await _capture("pair-matrix-%dx%d.png" % [size.x,size.y],{"kind":"pair_matrix","elements":Elements.IDS}): return
		panel.toggle_combination_mode()
		for mask: int in MASKS:
			for index: int in Elements.WIRE_IDS.size():
				var bit: int=Elements.MASK_BY_WIRE[Elements.WIRE_IDS[index]]
				if (int(panel.combination_mask)&bit)!=(mask&bit): panel.toggle_combination_element(index)
			var definition: Dictionary=Compendium.combination_definition(mask)
			var pages: int=panel.detail_pages(ThemeDB.fallback_font)
			if definition.is_empty() or pages<1 or pages>8: _fail("Combination details unavailable or unbounded"); return
			for page: int in pages:
				panel.detail_page=page
				var lines: Array[String]=panel.visible_detail_lines(ThemeDB.fallback_font)
				if lines.size()>12: _fail("Combination page exceeds visible line budget"); return
				var leaf := "combination-%d-page-%d-%dx%d.png" % [definition.elements.size(),page+1,size.x,size.y]
				if not await _capture(leaf,{"kind":"combination","mask":mask,"wire_id":definition.wire_id,"name":definition.name,"purpose":definition.purpose,"counter":definition.counter,"page":page+1,"pages":pages,"visible_lines":lines}): return
	for path: String in hashes:
		if FileAccess.get_sha256(path)!=hashes[path]: _fail("Source changed during capture: "+path); return
	var receipt := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	if receipt==null: _fail("Cannot save capture receipt"); return
	receipt.store_string(JSON.stringify({"status":"captured","frames":frames,"source_hashes":hashes,"authority_hash_before_and_after":authority,"saved_file_hashes_before_and_after":saved_files,"startup_saved_file_hashes":startup_saved_files,"initialization_scope":"Only first-run creation of absent default player preferences is permitted before UI capture. Existing preference bytes and weave/backup files cannot change during setup. All captured UI actions preserve the post-initialization bytes exactly.","scope":"Actual Bootstrap Loom all24grid plus six individual element filters/allfourfamilies and Compendium pair matrix plus3/4/5/6element inspector at1280x720/960x540; every detail page captured.","limitations":"Arranged UI state and API selections, not physical input, submitted migration, gameplay balance, frame performance, networking or human readability acceptance."},"\t")+"\n")
	receipt.close()
	print("PASS native six-element Loom/Compendium: ",frames.size()," images; save bytes and authority unchanged; visual review required")
	quit(0)

func _capture(leaf: String, metadata: Dictionary) -> bool:
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	if game.world.state_hash()!=authority: _fail("Read-only UI changed authority"); return false
	for path: String in saved_files:
		var current := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
		if current!=saved_files[path]: _fail("Read-only UI changed persisted bytes: "+path); return false
	var pixels := viewport.get_texture().get_image()
	if pixels==null or pixels.get_size()!=viewport.size or pixels.save_png(output.path_join(leaf))!=OK: _fail("Native image failed: "+leaf); return false
	metadata["image"]=leaf
	metadata["pixels"]=[pixels.get_width(),pixels.get_height()]
	metadata["sha256"]=FileAccess.get_sha256(output.path_join(leaf))
	metadata["saved_and_authority_unchanged"]=true
	frames.append(metadata)
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

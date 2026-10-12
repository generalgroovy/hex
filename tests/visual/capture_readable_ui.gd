extends SceneTree
## Native render + pointer-route fixture. No boot, save, socket, audio or time step.
const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const Loom = preload("res://src/presentation/readable_spell_loom.gd")
const Controls = preload("res://src/presentation/readable_controls.gd")
const Testing = preload("res://src/presentation/readable_testing_panel.gd")
const Demo = preload("res://src/presentation/readable_chemistry_demo.gd")
const Reading = preload("res://src/presentation/ui_reading_policy.gd")
const Reference = preload("res://src/presentation/readable_reference_panel.gd")
const Setup = preload("res://src/presentation/range_scenario_panel.gd")
const PAGES := ["menu","display","controls","loom","loom_compare","range","range_compare","range_setup","challenges","gallery","compendium_movement","compendium_characters","compendium_chemistry","map","demo","services"]
var output := ""
var records: Array[Dictionary] = []

class Board extends Harness:
	var page := "menu"
	func _draw() -> void:
		var scale := _ui_scale()
		var viewport := get_viewport_rect().size/scale
		draw_rect(get_viewport_rect(),Color("25353d"))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale)
		match page:
			"menu","display","map": local_navigation.draw(self,ThemeDB.fallback_font,viewport)
			"controls": _draw_controls_editor()
			"demo": _draw_hex_playground_panel()
			"services": service_directory.draw(self,viewport)
			"range","range_compare","range_setup","challenges": element_expansion.panel.draw(self,ThemeDB.fallback_font,viewport)
			"gallery":
				if _readable_ui(): character_selection_grid.draw_readable(self,viewport,{"enabled":false,"reason":"Read-only capture: no attunement."})
				else:
					draw_set_transform(Vector2.ZERO,0,Vector2.ONE*_compendium_scale())
					character_selection_grid.draw(self,ThemeDB.fallback_font,{"enabled":false,"reason":"Read-only capture."})
			"compendium_movement","compendium_characters","compendium_chemistry":
				if _readable_ui(): player_compendium.draw_readable(self,viewport)
				else:
					draw_set_transform(Vector2.ZERO,0,Vector2.ONE*_compendium_scale())
					player_compendium.draw(self,ThemeDB.fallback_font)
			"loom","loom_compare":
				if _readable_ui(): readable_loom.draw(self,viewport,spell_loom_editor,world.player(),ability_catalog,player_preferences,{"enabled":true},readable_loom.page)
				else: SpellLoomPresenter.draw_panel(self,spell_loom_editor,world.player(),ability_catalog,visual_language,player_preferences,{"enabled":true})
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if not output.begins_with("res://.godot/readable-ui-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Use a fresh --output=res://.godot/readable-ui-* directory"); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail("Cannot create capture directory"); return
	var board := Board.new()
	if not board.configure_fixture(false): _fail("UI fixture content failed"); return
	board.visual_language = VisualLanguage.new()
	if not board.visual_language.load_from_file(): _fail("UI visual language failed"); return
	board.visual_accessibility_filter = VisualAccessibilityFilter.new()
	if not board.visual_accessibility_filter.configure(): _fail("Fixture accessibility profile failed"); return
	board.add_child(board.visual_accessibility_filter)
	var roster := ChampionRosterPlan.new()
	if not roster.load_from_files() or not board.player_compendium.configure(board.champion_catalog,roster) or not board.character_selection_grid.configure(board.champion_catalog,roster): _fail("Reading roster failed"); return
	var progression := SignatureProgression.new()
	if not progression.configure(board.champion_catalog,board.ability_catalog,output.path_join("nonexistent-profile.json"),false): _fail("Isolated progression failed"); return
	board.input_router = InputRouter.new(1)
	board.local_navigation.configure(board)
	board.element_expansion.game = board
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(board)
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(960,540)
	root.show()
	create_timer(180).timeout.connect(func() -> void: _fail("Native UI capture exceeded its 180-second watchdog"))
	var authority := board.world.state_hash()
	for size: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		viewport.size=size
		for percent: int in [100,150,200]:
			board.player_preferences.ui_text_percent=percent
			for device: int in [ControlBindingEditor.DEVICE_KEYBOARD,ControlBindingEditor.DEVICE_CONTROLLER]:
				board.player_preferences.prompt_device=device
				board.input_router.prompt_device=device
				for page: String in PAGES:
					board.local_navigation.close()
					board.service_directory.close()
					board.hex_playground_open=false
					board.controls_editor.close_editor()
					board.spell_loom_editor.close_editor()
					board.element_expansion.panel.close()
					board.player_compendium.close_panel()
					board.character_selection_grid.close_panel()
					board.page=page
					var reflow := Reading.needs_reflow(Vector2(size),percent)
					var logical := Vector2(size)/board._ui_scale()
					var pointer_ok := true
					var interaction: Dictionary={}
					match page:
						"menu":
							board.local_navigation.open_menu()
							var rows: Array = board.local_navigation.entries()
							if rows.size()>board.local_navigation.menu_page_size(logical):
								var point: Vector2 = board.local_navigation.page_rect(logical,rows.size(),1).get_center()*board._ui_scale()
								board.local_navigation.handle_input(_click(point))
								pointer_ok=board.local_navigation.selected>0
						"display":
							board.local_navigation.performance_panel.open()
							var panel=board.local_navigation.performance_panel
							var change: Dictionary = panel.handle_input(_click(panel.row_rect(logical,2).get_center()+Vector2(50,0)),logical,board.player_preferences)
							pointer_ok=change.has("ui_text_percent")
						"controls":
							board.controls_editor.open_editor()
							board.controls_editor.selected_device=device
							if reflow:
								Controls.pointer_action(Controls.geometry(logical,0).next.get_center(),logical,board.controls_editor)
								pointer_ok=board.controls_editor.selected_action_index>0
						"loom","loom_compare":
							board.spell_loom_editor.open_editor(board.world.player(),board.ability_catalog)
							board.spell_loom_editor.set_element_mask(63)
							board.spell_loom_editor.basic_forms_only=false
							board.spell_loom_editor.compare_equipped=false
							board.spell_loom_editor.reading_options_open=false
							if page=="loom_compare":
								board._handle_spell_loom_input(_key(KEY_C))
								interaction={"action":"compare","enabled":board.spell_loom_editor.compare_equipped}
								pointer_ok=board.spell_loom_editor.compare_equipped
							if reflow:
								var previous := board.spell_loom_editor.selected_spell_index
								board._handle_spell_loom_input(_click(Loom.geometry(logical).buttons.next.get_center()*board._loom_scale()))
								pointer_ok=board.spell_loom_editor.selected_spell_index!=previous
						"range","range_compare","range_setup":
							board.element_expansion.panel.open_range(board.ability_catalog,63,"fuse")
							board.element_expansion.panel.readable=reflow
							board.element_expansion.panel.set_inspection_context(board.world.player(),board.world.player().spell_wire_id(1))
							board.element_expansion.panel.compare_equipped=false
							if page=="range_compare":
								board.element_expansion.panel.handle_input(_key(KEY_C),logical)
								interaction={"action":"compare","enabled":board.element_expansion.panel.compare_equipped}
								pointer_ok=board.element_expansion.panel.compare_equipped
							if page=="range_setup":
								board.element_expansion.panel.set_range_scenario({"active":true,"moving":false,"firing":false,"size":"Medium","statistics":{},"elapsed_ticks":0,"scope":"Capture fixture has no measured combat statistics."})
								board.element_expansion.panel.handle_input(_key(KEY_T),logical)
								pointer_ok=_setup_page(board.element_expansion.panel,logical,0)
								interaction=board.element_expansion.panel.handle_input(_click(Setup.geometry(logical).controls[0].get_center()),logical)
								pointer_ok=pointer_ok and interaction.get("action")=="range_target_motion" and not board.element_expansion.panel._range_scenario.moving
							if reflow and page!="range_setup":
								if bool(Testing.geometry(logical).tight):
									var panel=board.element_expansion.panel
									panel.handle_input(_click(Testing.geometry(logical).setup.get_center()),logical)
									pointer_ok=pointer_ok and _setup_page(panel,logical,2)
									panel.handle_input(_click(Setup.geometry(logical).controls[3].get_center()),logical)
									panel.handle_input(_click(Setup.geometry(logical).back.get_center()),logical)
								else: board.element_expansion.panel.handle_input(_click(Testing.geometry(logical).family_next.get_center()),logical)
								pointer_ok=pointer_ok and board.element_expansion.panel.family_index!=MixtureCatalog.FAMILIES.find("fuse")
								interaction["delivery_after"]=String(MixtureCatalog.FAMILIES[board.element_expansion.panel.family_index])
						"challenges":
							var panel=board.element_expansion.panel
							pointer_ok=panel.open_challenges(board.champion_catalog,board.ability_catalog,progression)
							panel.readable=reflow
							panel.detail_page=0
							var geo := Testing.geometry(logical) if reflow else SpellTestingPanel.geometry(logical)
							panel.handle_input(_click(geo.details_next.get_center()),logical)
							pointer_ok=pointer_ok and panel.detail_page==1
							interaction={"action":"detail_next","page":panel.detail_page,"paragraphs":panel.challenge_paragraphs()}
						"gallery":
							var gallery=board.character_selection_grid
							gallery.open_panel("oh_tipi")
							gallery.readable_reader.options_open=false
							var before := String(gallery.model.selected_entry().id)
							if reflow:
								var geo := Reference.geometry(logical)
								gallery.handle_readable_event(_click(geo.buttons.next.get_center()),geo.buttons.next.get_center(),logical,{"enabled":false})
							else: gallery.handle_event(_key(KEY_RIGHT),ThemeDB.fallback_font,Vector2(-1,-1),{"enabled":false})
							interaction={"action":"next_character","before":before,"after":String(gallery.model.selected_entry().id)}
							pointer_ok=interaction.before!=interaction.after
						"compendium_movement","compendium_characters","compendium_chemistry":
							var compendium=board.player_compendium
							var tab := 0 if page.ends_with("movement") else 1 if page.ends_with("characters") else 2
							compendium.open_panel(tab,board.player_preferences,board.world.player(),device)
							if reflow:
								compendium.readable_reader.options_open=false
								var geo := Reference.geometry(logical)
								compendium.handle_readable_event(_click(geo.buttons.next.get_center()),geo.buttons.next.get_center(),logical)
								if tab==2:
									if bool(geo.tight): compendium.handle_readable_event(_click(geo.buttons.options.get_center()),geo.buttons.options.get_center(),logical)
									geo=Reference.geometry(logical,false,true)
									compendium.handle_readable_event(_click(geo.buttons.mode.get_center()),geo.buttons.mode.get_center(),logical)
									for index: int in 6:
										var bit: int=ElementRules.MASK_BY_WIRE[ElementRules.WIRE_IDS[index]]
										if (compendium.combination_mask&bit)==0: compendium.handle_readable_event(_click(geo.buttons["element%d" % index].get_center()),geo.buttons["element%d" % index].get_center(),logical)
									pointer_ok=compendium.combination_mode and compendium.combination_mask==63
									if bool(geo.tight): compendium.handle_readable_event(_click(geo.buttons.options.get_center()),geo.buttons.options.get_center(),logical)
							interaction={"action":"read_entry","tab":compendium.tab,"row":compendium.selected_row,"character":compendium.selected_character,"combination_mask":compendium.combination_mask}
						"map": pointer_ok=board.local_navigation.open_map()
						"demo":
							board.hex_playground_open=true
							board.hex_playground_pair=HexPlaygroundPanel.DEFAULT_PAIR
							var before_pair: Vector2i = board.hex_playground_pair
							if reflow:
								board._handle_hex_playground_input(_click(Demo.geometry(logical).next_first.get_center()*board._ui_scale()))
							else:
								board._handle_hex_playground_input(_click(HexPlaygroundPanel.cell_rect(board.HEX_PLAYGROUND_RECT,0,0).get_center()*board._ui_scale()))
							pointer_ok=board.hex_playground_pair!=before_pair
						"services":
							pointer_ok=board.service_directory.open_group("farflow",board.campus_layout.data.stations)
							var directory=board.service_directory
							var geo: Dictionary = directory.layout_for(logical)
							if bool(geo.get("compact",false)):
								directory.handle_event(_click(geo.next.get_center()),geo.next.get_center(),logical)
								pointer_ok=pointer_ok and directory.selected_index==1 and directory.handle_event(_click(geo.open.get_center()),geo.open.get_center(),logical)==directory.selected_station_id()
							else:
								var center: Vector2 = (geo.cards[1] as Rect2).get_center()
								pointer_ok=pointer_ok and directory.handle_event(_click(center),center,logical)==String(directory.entries[1].id)
					if not pointer_ok: _fail("Pointer route failed: "+page); return
					board.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					var frame := viewport.get_texture().get_image()
					var name := "%dx%d-%d-%s-%s" % [size.x,size.y,percent,"pad" if device==2 else "keys",page]
					if frame == null or frame.is_empty() or frame.get_size()!=size or frame.save_png(output.path_join(name+".png")) != OK: _fail("Native image failed: "+name); return
					if board.world.state_hash()!=authority: _fail("UI mutated world: "+name); return
					records.append({"name":name,"actual_size":[size.x,size.y],"text_percent":percent,"device":device,"reflow":reflow,"pointer_route":pointer_ok,"interaction":interaction})
					if bool(Reference.geometry(logical).tight) and page in ["gallery","compendium_chemistry"]:
						var back := InputEventJoypadButton.new()
						back.pressed=true;back.button_index=JOY_BUTTON_BACK
						var reader = board.character_selection_grid.readable_reader if page=="gallery" else board.player_compendium.readable_reader
						if page=="gallery": board.character_selection_grid.handle_readable_event(back,Vector2(-1,-1),logical,{"enabled":false})
						else: board.player_compendium.handle_readable_event(back,Vector2(-1,-1),logical)
						if not reader.options_open: _fail("Controller Back did not expose compact controls: "+name); return
						board.queue_redraw()
						await process_frame
						await RenderingServer.frame_post_draw
						var options_image := viewport.get_texture().get_image()
						if options_image==null or options_image.save_png(output.path_join(name+"-options.png"))!=OK or board.world.state_hash()!=authority: _fail("Native Options capture failed: "+name); return
						records.append({"name":name+"-options","actual_size":[size.x,size.y],"text_percent":percent,"device":device,"reflow":reflow,"pointer_route":true,"interaction":{"action":"controller_back_options","open":true,"ingredient_cursor":board.player_compendium.combination_cursor if page=="compendium_chemistry" else -1}})
						if page=="gallery": board.character_selection_grid.handle_readable_event(back,Vector2(-1,-1),logical,{"enabled":false})
						else: board.player_compendium.handle_readable_event(back,Vector2(-1,-1),logical)
						if reader.options_open: _fail("Controller Back did not restore compact reading: "+name); return

	var receipt := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	if receipt == null: _fail("Cannot write capture receipt"); return
	receipt.store_string(JSON.stringify({"scope":"native UI rendering and pointer navigation; no human readability or gameplay performance claim","frames":records,"authority_unchanged":true,"profiles":"not read or written"},"  "))
	receipt.close()
	board.queue_free()
	viewport.queue_free()
	await process_frame
	print("PASS readable-ui capture: %d native frames" % records.size())
	quit()

func _setup_page(panel, logical: Vector2, wanted: int) -> bool:
	# Focus intentionally survives reopening the real panel. Follow its visible
	# page through actual clicks rather than assuming every case starts at zero.
	for unused: int in 4:
		if int(panel.range_setup_index/4)==wanted: return true
		panel.handle_input(_click(Setup.geometry(logical).more.get_center()),logical)
	return int(panel.range_setup_index/4)==wanted

func _click(point: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed=true
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=point
	return event

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	return event

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)

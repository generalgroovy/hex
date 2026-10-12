extends FluxTestSuite

const Quality = preload("res://src/presentation/render_quality.gd")
const PerformancePanel = preload("res://src/presentation/performance_panel.gd")
const Batch = preload("res://src/presentation/pov_terrain_batch.gd")

func run() -> int:
	_test_preferences()
	_test_panel()
	_test_mask_geometry()
	_test_frame_visibility_bounds()
	_test_readable_layouts()
	_test_readable_loom_identity()
	_test_readable_references()
	return finish("performance-presentation")

func _test_readable_layouts() -> void:
	var policy := preload("res://src/presentation/ui_reading_policy.gd")
	var controls := preload("res://src/presentation/readable_controls.gd")
	var loom := preload("res://src/presentation/readable_spell_loom.gd")
	var testing := preload("res://src/presentation/readable_testing_panel.gd")
	var navigation := preload("res://src/app/local_navigation_controller.gd")
	check(policy.needs_reflow(Vector2(960,540),100),"small default window reflows instead of shrinking body text")
	check(not policy.needs_reflow(Vector2(1280,720),100),"full-size overview retains its established layout")
	check(policy.needs_reflow(Vector2(1280,720),150),"large text selects the same input and painting layout")
	var preferences := PlayerPreferences.new()
	for percent: int in [100,125,150,200]:
		preferences.ui_text_percent=percent
		var other := PlayerPreferences.new()
		check(other.apply_dictionary(preferences.to_dictionary()),"readable preference round trips")
		equal(other.ui_text_percent,percent,"text size remains independent of world zoom")
	for viewport: Vector2 in [Vector2(480,270),Vector2(640,360),Vector2(853.333,480),Vector2(960,540),Vector2(1280,720)]:
		var screen := Rect2(Vector2.ZERO,viewport)
		for model: Dictionary in [controls.geometry(viewport,22),loom.geometry(viewport),testing.geometry(viewport)]:
			check(screen.encloses(model.panel),"readable panel stays in logical viewport")
			for key: String in ["body","notice","previous","next"]:
				if model.has(key): check((model.panel as Rect2).encloses(model[key]),"readable content/navigation fits without clipping")
			for collection: String in ["rows","tabs","settings","filters","buttons"]:
				if not model.has(collection): continue
				var values: Array = model[collection].values() if model[collection] is Dictionary else model[collection]
				for rect: Rect2 in values: check((model.panel as Rect2).encloses(rect),"every readable pointer target remains within the panel")
		var map := WellspringMapPanel.geometry(viewport)
		var spell_reading := testing.geometry(viewport)
		check(not (spell_reading.body as Rect2).intersects(spell_reading.details_previous),"last Range text line cannot share the detail-page controls")
		check(screen.encloses(map.panel) and (map.panel as Rect2).encloses(map.list),"map list page adapts to text-size height")
		for direction: int in [-1,1]: check(navigation.menu_rect(viewport,15).encloses(navigation.page_rect(viewport,15,direction)),"visible menu paging keeps later settings reachable by pointer")
		var editor := ControlBindingEditor.new()
		for index: int in ControlBindingEditor.ACTIONS.size(): controls.pointer_action(controls.geometry(viewport,editor.selected_action_index).next.get_center(),viewport,editor)
		equal(editor.selected_action_index,0,"pointer alone can visit every controls row and wrap")
		var control_geometry := controls.geometry(viewport,editor.selected_action_index)
		var settings := controls.setting_labels(preferences)
		for setting: int in settings.size():
			check(ThemeDB.fallback_font.get_string_size(settings[setting],HORIZONTAL_ALIGNMENT_LEFT,-1,13).x<=control_geometry.settings[setting].size.x-12,"each painted control setting label fits its actual button at supported reading sizes")
		equal(controls.pointer_action(control_geometry.settings[5].get_center(),viewport,editor),"aim","short Aim cue label preserves its existing pointer action")
	check(loom.geometry(Vector2(480,270)).body.size.y>=76,"200percent Loom leaves four lines for meaning rather than a heading-only page")
	check(testing.geometry(Vector2(480,270)).body.size.y>=76,"200percent Range leaves four lines after identity and cost")
	equal(testing.geometry(Vector2(480,270)).setup,testing.geometry(Vector2(480,270)).buttons[3],"compact Setup pointer target is the single painted footer action")
	var old := preferences.to_dictionary()
	var invalid := old.duplicate(true)
	invalid.ui_text_percent=175
	check(not preferences.apply_dictionary(invalid),"unsupported text size is rejected atomically")
	equal(preferences.to_dictionary(),old,"invalid text size preserves all bindings and preferences")

func _test_readable_loom_identity() -> void:
	var loom := preload("res://src/presentation/readable_spell_loom.gd")
	var wrap := preload("res://src/presentation/spell_testing_panel.gd")
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"readable identity fixture loads actual compiled names")
	var editor := SpellLoomEditor.new()
	editor.configure_for_catalog(catalog)
	editor.compare_equipped=true
	var state := PlayerState.new(1)
	var preferences := PlayerPreferences.new()
	var authority := state.canonical_values()
	for viewport: Vector2 in [Vector2(480,270),Vector2(640,360),Vector2(853.333,480),Vector2(960,540),Vector2(1280,720)]:
		var geo := loom.geometry(viewport)
		if not geo.tight:
			check((geo.panel as Rect2).encloses(geo.title),"persistent selected identity stays within the readable panel")
			check(not (geo.title as Rect2).intersects(geo.buttons.compare),"selected identity never overlaps Compare")
			for filter: Rect2 in geo.filters: check(not (geo.title as Rect2).intersects(filter),"selected identity stays above all element filters")
		for index: int in editor.available_wire_ids.size():
			editor.selected_spell_index=index
			var chosen := catalog.ability_from_wire(editor.selected_wire_id())
			if not geo.tight:
				var title := loom.selection_title_lines(editor,catalog,geo.title.size.x)
				check(title.size()<=2 and title.size()>0,"every real mixture name fits the two-line persistent title")
				equal(" ".join(title),"Selected: "+String(chosen.display_name),"persistent title retains the complete selected identity")
				for line: String in title: check(ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=geo.title.size.x,"selected name wraps without horizontal clipping")
			var identity := loom.comparison_identity(editor,state,catalog)
			var current := catalog.ability_from_wire(state.spell_wire_id(editor.selected_slot_index+1))
			equal(identity,"Equipped %s -> selected %s" % [String(current.get("display_name","Empty")),String(chosen.display_name)],"named comparison fixes the direction of the numeric deltas")
			var first := wrap._wrap(identity,ThemeDB.fallback_font,14,geo.body.size.x)
			check(first.size()<=maxi(1,floori(geo.body.size.y/19)),"both named comparison identities fit before the first detail page ends")
			var lines := loom.detail_lines(editor,state,catalog,preferences,geo.body.size.x)
			equal(lines.slice(0,first.size()),first,"complete equipped and selected identities precede comparison values")
	equal(state.canonical_values(),authority,"identity reads cannot change spells, resources or authority")

func _test_frame_visibility_bounds() -> void:
	var game := preload("res://src/app/bootstrap.gd").new()
	game.campus_layout = SanctumCampusLayout.new()
	game.campus_layout.data = {"buildings": [
		{"bounds": [10, 20, 30, 40], "occlusion_policy": "los_cutaway"},
		{"bounds": [70, 80, 90, 100], "occlusion_policy": "none"},
	]}
	var expected: Array[Rect2] = [Rect2(10, 20, 30, 40)]
	equal(game._pov_opaque_bounds(), expected, "fresh sight bounds preserve only actual opaque buildings")
	game._begin_visibility_frame()
	var before: int = game._visibility_bounds_builds
	for query: int in 40:
		equal(game._pov_opaque_bounds(), expected, "every same-frame sight query receives the exact layout")
	equal(game._visibility_bounds_builds, before + 1, "one draw parses opaque building bounds only once")
	game._end_visibility_frame()
	game.campus_layout.data.buildings[0].bounds = [11, 22, 33, 44]
	equal(game._pov_opaque_bounds(), [Rect2(11, 22, 33, 44)], "outside-draw query immediately sees a layout replacement")
	game._begin_visibility_frame()
	equal(game._pov_opaque_bounds(), [Rect2(11, 22, 33, 44)], "the next frame never retains prior layout geometry")
	game._end_visibility_frame()
	check(not game._visibility_frame_active and game._visibility_frame_bounds.is_empty(), "frame end releases the private borrowed cache")
	game.free()

func _test_preferences() -> void:
	var prefs := PlayerPreferences.new()
	equal([prefs.render_quality, prefs.frame_limit], ["low", 60], "new profiles use the economical 60 FPS presentation")
	var legacy := prefs.to_dictionary()
	legacy.erase("render_quality")
	legacy.erase("frame_limit")
	check(prefs.apply_dictionary(legacy), "existing saved controls accept additive performance defaults")
	prefs.reduced_motion = true
	prefs.keyboard_bindings[&"emote"] = KEY_U
	for quality: String in ["low", "standard"]:
		for limit: int in [0, 60, 120]:
			prefs.render_quality = quality
			prefs.frame_limit = limit
			var other := PlayerPreferences.new()
			check(other.apply_dictionary(prefs.to_dictionary()), "every valid quality and cap round-trips")
			equal(other.to_dictionary(), prefs.to_dictionary(), "performance persistence preserves accessibility and customized controls")
	var before := prefs.to_dictionary()
	for bad: Dictionary in [{"render_quality": "ultra"}, {"render_quality": 1}, {"frame_limit": -1}, {"frame_limit": 60.5}, {"frame_limit": "60"}]:
		var invalid := before.duplicate(true)
		invalid.merge(bad, true)
		check(not prefs.apply_dictionary(invalid), "invalid performance preference rejected before mutation")
		equal(prefs.to_dictionary(), before, "rejected quality keeps the entire profile")
	var defaults := PlayerPreferences.new()
	var old_controls := defaults.to_dictionary()
	for action: String in ["aim_left","aim_right","aim_up","aim_down"]:
		old_controls.keyboard_bindings.erase(action)
		old_controls.controller_bindings.erase(action)
	old_controls.keyboard_bindings["emote"]=KEY_I
	old_controls.controller_bindings["emote"]={"kind":"axis","index":JOY_AXIS_RIGHT_Y,"direction":-1}
	check(defaults.apply_dictionary(old_controls),"additive aim mappings preserve older customized layouts")
	equal(defaults.keyboard_bindings[&"aim_up"],0,"new optional keyboard aim cannot steal an old custom I binding")
	equal(defaults.controller_bindings[&"aim_up"].kind,"none","new explicit aim cannot conflict with an old custom axis")
	for invalid_value: Variant in [0,51,12.5,"20"]:
		var invalid := defaults.to_dictionary()
		invalid.aim_deadzone_percent=invalid_value
		var saved := defaults.to_dictionary()
		check(not defaults.apply_dictionary(invalid),"invalid analog adaptation is rejected")
		equal(defaults.to_dictionary(),saved,"rejected adaptation cannot erase customized inputs")
	var previous: String = Quality.profile
	check(Quality.set_profile("low"), "Low selects cosmetic budgets")
	equal(Quality.surface_glow_limit(12), 0, "Low avoids optional surface glow")
	equal(Quality.garden_sample_limit(), 1, "Low uses one native material sample per exhibit")
	check(not Quality.set_profile("unexpected"), "unknown profiles cannot alter shared renderer")
	equal(Quality.profile, "low", "invalid quality cannot promote extra work")
	check(Quality.set_profile("standard"), "Standard restores decoration")
	equal(Quality.surface_glow_limit(12), 12, "Standard retains original surface budget")
	Quality.set_profile(previous)

func _test_panel() -> void:
	var prefs := PlayerPreferences.new()
	var PerformancePanel := PerformancePanel.new()
	var viewport := Vector2(960, 540)
	var rect: Rect2 = PerformancePanel.panel_rect(viewport)
	check(Rect2(Vector2.ZERO, viewport).encloses(rect), "performance PerformancePanel fits smallest supported window")
	for index: int in 2: check(rect.encloses(PerformancePanel.row_rect(viewport, index)), "controls remain inside compact PerformancePanel")
	PerformancePanel.open()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	equal(PerformancePanel.handle_input(key, viewport, prefs), {"render_quality": "standard"}, "keyboard changes selected cosmetic setting")
	key.keycode = KEY_DOWN
	PerformancePanel.handle_input(key, viewport, prefs)
	key.keycode = KEY_LEFT
	equal(PerformancePanel.handle_input(key, viewport, prefs), {"frame_limit": 0}, "left wraps cap to unlimited")
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	pad.button_index = JOY_BUTTON_A
	equal(PerformancePanel.handle_input(pad, viewport, prefs), {"frame_limit": 120}, "controller confirms next cap")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = PerformancePanel.row_rect(viewport, 0).get_center() + Vector2(70, 0)
	equal(PerformancePanel.handle_input(click, viewport, prefs), {"render_quality": "standard"}, "pointer reaches quality control")
	key.keycode = KEY_ESCAPE
	equal(PerformancePanel.handle_input(key, viewport, prefs), {"close": true}, "Escape dismisses without changing settings")
	PerformancePanel.close()
	equal(PerformancePanel.handle_input(pad, viewport, prefs), {}, "closed performance PerformancePanel cannot consume or change gameplay")

func _test_mask_geometry() -> void:
	var batch := Batch.new()
	var texture := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var backdrop := Rect2(192, 128, 512, 512)
	var translation := Vector2(-240, -192)
	var zoom := 0.75
	batch.begin(null, texture, backdrop, translation, zoom)
	var points := PackedVector2Array([Vector2(0, 0), Vector2(80, 0), Vector2(80, 60), Vector2(0, 60)])
	var shade := Color(0.66, 0.66, 0.66, 1)
	var edge := Color(0.4, 0.4, 0.4, 1)
	batch.append_polygon(points, shade, edge, true)
	var mesh := batch.geometry()
	equal(mesh.points.size(), 4, "terrain replacement retains full visibility polygon")
	equal(mesh.indices.size(), 6, "opaque quad becomes exactly two triangles")
	for index: int in points.size():
		var world_point: Vector2 = (points[index] - translation) / zoom
		var expected_uv: Vector2 = (world_point - backdrop.position) / backdrop.size
		check(mesh.uvs[index].is_equal_approx(expected_uv), "batched terrain UV matches world backdrop despite camera offset")
		equal(mesh.colors[index].a, 1.0, "mask stays opaque and cannot expose hidden actors")
	equal(mesh.colors, PackedColorArray([shade, edge, edge, shade]), "range feather shades the same two far vertices")
	var first_vertices: PackedVector2Array = mesh.points.duplicate()
	batch.append_polygon(PackedVector2Array([Vector2(80, 0), Vector2(100, 0), Vector2(100, 60)]), shade, shade)
	mesh.points[0] = Vector2(999, 999)
	var combined := batch.geometry()
	equal(combined.points[0], first_vertices[0], "diagnostic buffers cannot mutate retained mask")
	for index: int in combined.indices: check(index >= 0 and index < combined.points.size(), "all batched polygons index their own vertices")
	batch.finish()
	check(not batch.active and batch.geometry().points.is_empty(), "painter-order flush cannot leave previous-frame geometry")


func _test_readable_references() -> void:
	var reader := preload("res://src/presentation/readable_reference_panel.gd").new()
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	var roster := ChampionRosterPlan.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"readable references load spells")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities),"readable references load characters")
	check(roster.load_from_files(),"readable references load authored roster")
	var compendium := PlayerCompendium.new()
	var gallery := CharacterSelectionGrid.new()
	check(compendium.configure(champions,roster) and gallery.configure(champions,roster),"same authoritative catalog powers both layouts")
	compendium.open_panel(0,PlayerPreferences.new())
	gallery.open_panel(String(champions.champion_ids_by_wire[1]))
	var viewport := Vector2(480,270)
	var geo := reader.geometry(viewport)
	check(Rect2(Vector2.ZERO,viewport).encloses(geo.panel),"200% reference panel stays on screen")
	check((geo.panel as Rect2).encloses(geo.body) and not (geo.body as Rect2).intersects(geo.buttons.page_previous),"200% detail lines do not overlap paging controls")
	for rect: Rect2 in geo.buttons.values(): check((geo.panel as Rect2).encloses(rect),"every 200% reference pointer target stays reachable")
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	reader.handle_compendium(click,geo.buttons.options.get_center(),viewport,compendium)
	check(reader.options_open,"pointer exposes compact category controls without shrinking text")
	geo=reader.geometry(viewport,false,true)
	for tab: int in 3:
		reader.handle_compendium(click,geo.buttons["tab%d" % tab].get_center(),viewport,compendium)
		equal(compendium.tab,tab,"pointer reaches every readable reference category")
		for row: int in compendium.row_count():
			compendium.selected_row=row
			var paragraphs := compendium.detail_paragraphs()
			var lines := reader.wrapped(paragraphs,geo.body.size.x)
			for line: String in lines: check(ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=geo.body.size.x,"complete reference text fits 200% wrapped pages")
		var pinned: String=reader.selection_title(compendium)
		reader.page=3
		equal(reader.selection_title(compendium),pinned,"selected reference identity is independent of detail pagination")
	reader.handle_compendium(click,geo.buttons.mode.get_center(),viewport,compendium)
	check(compendium.combination_mode,"pointer reaches the six-element reference picker")
	compendium.combination_mask=0
	for index: int in 6: reader.handle_compendium(click,geo.buttons["element%d" % index].get_center(),viewport,compendium)
	equal(compendium.combination_mask,63,"all six independently labeled ingredients remain pointer reachable")
	reader.handle_compendium(click,geo.buttons.options.get_center(),viewport,compendium)
	check(not reader.options_open,"pointer returns to four-line selected-entry reading")
	geo=reader.geometry(viewport)
	check(geo.body.size.y>=76,"200percent default reference reading exposes at least four lines")
	var visited: Dictionary={}
	for unused: int in gallery.model.display_cells().size():
		visited[String(gallery.model.selected_entry().id)]=true
		equal(reader.handle_gallery(click,geo.buttons.next.get_center(),viewport,gallery,{"enabled":false}),0,"readable browsing never returns a selection request")
	equal(visited.size(),gallery.model.display_cells().size(),"pointer alone reaches every Gallery character")
	equal(reader.handle_gallery(click,geo.buttons.primary.get_center(),viewport,gallery,{"enabled":false}),0,"readable attunement retains live refusal")
	equal(gallery.model.pending_wire,0,"readable inspection cannot bypass pending-selection admission")
	var page_event := InputEventJoypadButton.new()
	page_event.pressed=true
	page_event.button_index=JOY_BUTTON_Y
	reader.page=0
	reader.handle_gallery(page_event,Vector2(-1,-1),viewport,gallery,{})
	equal(reader.page,1,"controller pages actual reflowed Gallery text")
	var stick := InputEventJoypadButton.new()
	stick.pressed=true;stick.button_index=JOY_BUTTON_LEFT_STICK
	reader.handle_compendium(stick,Vector2(-1,-1),viewport,compendium)
	check(compendium.map_requested and not reader.options_open,"reference options preserve the existing controller map shortcut")
	var world := SimWorld.new()
	compendium.refresh_status(world.player())
	var authority := world.state_hash()
	var back := InputEventJoypadButton.new()
	back.pressed=true;back.button_index=JOY_BUTTON_BACK
	reader.handle_compendium(back,Vector2(-1,-1),viewport,compendium)
	check(reader.options_open and compendium.is_open,"compact controller Back opens visible composition controls without closing reference")
	compendium.combination_cursor=0
	var right := InputEventJoypadButton.new()
	right.pressed=true;right.button_index=JOY_BUTTON_DPAD_RIGHT
	reader.handle_compendium(right,Vector2(-1,-1),viewport,compendium)
	equal(compendium.combination_cursor,1,"controller navigates the highlighted ingredient cursor")
	var accept := InputEventJoypadButton.new()
	accept.pressed=true;accept.button_index=JOY_BUTTON_A
	reader.handle_compendium(accept,Vector2(-1,-1),viewport,compendium)
	equal(compendium.combination_mask,63 ^ int(ElementRules.MASK_BY_WIRE[ElementRules.WIRE_IDS[1]]),"controller toggles exactly the visibly focused ingredient")
	reader.handle_compendium(back,Vector2(-1,-1),viewport,compendium)
	check(not reader.options_open and compendium.is_open,"Back returns to compact reading instead of closing")
	reader.handle_gallery(back,Vector2(-1,-1),viewport,gallery,{"enabled":false})
	check(reader.options_open and gallery.is_open,"Gallery Back opens optional portrait/facing controls")
	reader.handle_gallery(back,Vector2(-1,-1),viewport,gallery,{"enabled":false})
	check(not reader.options_open and gallery.is_open,"Gallery Back returns to selected character reading")
	equal(gallery.model.pending_wire,0,"Options navigation cannot request attunement")
	equal(world.state_hash(),authority,"reference navigation cannot mutate world authority")
	var close := InputEventJoypadButton.new()
	close.pressed=true;close.button_index=JOY_BUTTON_B
	reader.handle_compendium(close,Vector2(-1,-1),viewport,compendium)
	check(not compendium.is_open,"controller B still closes the compact reference")
	gallery.close_panel()

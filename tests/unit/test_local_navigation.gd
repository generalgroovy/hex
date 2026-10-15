extends FluxTestSuite

const Navigation = preload("res://src/app/local_navigation_controller.gd")
const Quality = preload("res://src/presentation/render_quality.gd")
const Garden = preload("res://src/app/element_garden_exhibition.gd")
const MapPanel = preload("res://src/presentation/wellspring_map_panel.gd")
const GardenPresenter = preload("res://src/presentation/element_garden_presenter.gd")

class CountedGardenPresenter extends GardenPresenter:
	var preparation_calls := 0
	var refuse_next := false
	func _prepare_arrival_entry(entry: Dictionary, reduced: bool) -> bool:
		preparation_calls += 1
		if refuse_next: return _arrival_fail("Injected visual preparation failure.")
		return super._prepare_arrival_entry(entry, reduced)

class Harness extends "res://src/app/bootstrap.gd":
	var hold_terrain := false
	func _ready() -> void:
		set_process(false)
		set_process_unhandled_input(true)
	func _draw() -> void:
		pass
	func _prepare_terrain_frame() -> void:
		super._prepare_terrain_frame()
		# Controlled GPU-readiness input, not an asset-loading performance claim.
		if hold_terrain: terrain_loading = true

class RefusingGarden extends Garden:
	var refuse_next := false
	func _new_entry(mask: int) -> Dictionary:
		if refuse_next:
			last_error = "Injected exhibit preparation failure."
			return {}
		return super._new_entry(mask)

func run() -> int:
	InputRouter.ensure_input_map()
	var unowned := Navigation.new()
	check(not unowned.open_map(), "unconfigured map refuses without owner access")
	check(not unowned.handle_input(InputEventKey.new()), "unconfigured navigation ignores input")
	check(not unowned.travel("unknown"), "unconfigured travel refuses without mutation")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	var game := Harness.new()
	viewport.add_child(game)
	if not _configure(game):
		check(false, "navigation fixture loads the real expanded world")
		viewport.free()
		return finish("local-navigation")
	var nav: RefCounted = game.local_navigation
	var actor: PlayerState = game.world.player()
	actor.health -= 1234
	actor.flux -= 4567
	actor.stamina -= 3456
	actor.spell_cooldown_ticks[0] = 77
	var resources := [actor.health, actor.flux, actor.stamina, actor.spell_cooldown_ticks.duplicate(), actor.spell_wire_ids.duplicate()]
	var cells_paid := int(game.world.hex_court.metrics.matter_paid)
	for destination: Dictionary in game.campus_layout.travel_destinations():
		check(nav.open_map(), "real map opens for " + String(destination.id))
		check(game._gameplay_input_blocked(), "map owns command input")
		check(nav.travel(String(destination.id)), "actual travel reaches " + String(destination.id))
		var expected := Vector2i(int(destination.position[0]), int(destination.position[1])) * SimConfig.FIXED_SCALE
		equal(Vector2i(actor.position_x, actor.position_y), expected, "arrival uses trusted authored coordinates")
		check(game.world.collision.can_occupy(expected, actor.radius), "arrival clears actual actor collision")
		equal([actor.health, actor.flux, actor.stamina, actor.spell_cooldown_ticks, actor.spell_wire_ids], resources, "travel preserves resources, cooldowns and loadout")
		equal(game.previous_position, game.current_position, "teleport cannot smear actor interpolation across the world")
		check(not game.player_camera.initialized, "camera snaps after travel")
		check(not nav.blocks_gameplay(), "arrival closes both navigation surfaces")
		_finish_arrival(game)
	equal(int(game.world.hex_court.metrics.matter_paid), cells_paid, "travel never creates paid matter")
	var before := actor.canonical_values()
	check(not nav.travel("not-an-authored-destination"), "unknown travel id fails closed")
	equal(actor.canonical_values(), before, "unknown destination cannot reset actor state")
	var target: String = String(game.campus_layout.travel_destinations()[0].id)
	actor.pending_cast_ticks = 1
	_rejected(nav, actor, target, "spell startup")
	actor.pending_cast_ticks = 0
	actor.air_height = 1000
	_rejected(nav, actor, target, "airborne action")
	actor.air_height = 0
	actor.health_recovery_delay_ticks = 1
	_rejected(nav, actor, target, "recent damage")
	actor.health_recovery_delay_ticks = 0
	actor.spell_status_values[0] = 1
	_rejected(nav, actor, target, "active status")
	actor.spell_status_values[0] = 0
	game.interception_practice_active = true
	_rejected(nav, actor, target, "isolated duel")
	game.interception_practice_active = false
	game.element_expansion.challenge_active = true
	_rejected(nav, actor, target, "signature challenge")
	game.element_expansion.challenge_active = false
	var shot := ProjectileState.new(999, actor.entity_id, actor.team_id, 140, 1, Vector2i(actor.position_x, actor.position_y), Vector2i.RIGHT, 1000, 1000, 60)
	game.world.projectiles.append(shot)
	_rejected(nav, actor, target, "live owned projectile")
	game.world.projectiles.clear()
	game.session_transport.mode = SessionTransport.Mode.HOSTING
	_rejected(nav, actor, target, "online host")
	game.session_transport.mode = SessionTransport.Mode.OFFLINE
	var destination: Dictionary = game.campus_layout.travel_destination(target)
	var other := PlayerState.new()
	other.entity_id = 2
	other.position_x = int(destination.position[0]) * SimConfig.FIXED_SCALE
	other.position_y = int(destination.position[1]) * SimConfig.FIXED_SCALE
	game.world.players.append(other)
	_rejected(nav, actor, target, "occupied destination")
	game.world.players.erase(other)
	var original_collision: HexCollisionWorld = game.world.collision
	var occupied_collision := HexCollisionWorld.new(original_collision.base_world)
	var occupied_cell := HexGrid.world_to_cell(Vector2i(int(destination.position[0]), int(destination.position[1])) * SimConfig.FIXED_SCALE)
	check(occupied_collision.configure_hexes(Vector2i.ZERO, game.world.hex_court.immutable_topology().numeric_cells(), [occupied_cell]), "live Rampart collision fixture installs at authored arrival")
	game.world.collision = occupied_collision
	_rejected(nav, actor, target, "active Rampart at destination")
	game.world.collision = original_collision
	_test_input(game)
	var font := ThemeDB.fallback_font
	for size: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
		var rows: Array[Dictionary] = nav.entries()
		var panel: Rect2 = Navigation.menu_rect(size, rows.size())
		check(Rect2(Vector2.ZERO, size).encloses(panel), "compact menu fits supported size")
		for index: int in rows.size():
			check(panel.encloses(Navigation.row_rect(size, rows.size(), index)), "every menu action remains in panel")
			check(font.get_string_size(String(rows[index].label), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= 220, "actual menu action label fits its budget")
	game.world = null # Teardown cannot accidentally save a production weave.
	viewport.free()
	_test_garden_travel_arrival()
	_test_garden_arrival_cancellation()
	_test_ready_garden_waits_for_terrain()
	_test_garden_preparation_failure()
	_test_garden_visual_preparation_failure()
	_test_walking_does_not_stage()
	return finish("local-navigation")

func _configure(game: Node) -> bool:
	game.preferences_persistence_allowed = false
	game.preference_overrides_are_transient = true
	game.ability_catalog = AbilityCatalog.new()
	game.campus_layout = SanctumCampusLayout.new()
	if not game.ability_catalog.load_from_file(game.ABILITY_CATALOG_PATH) or not game.campus_layout.load_from_file(game.CAMPUS_LAYOUT_PATH): return false
	if not game.element_garden.configure(game.campus_layout.element_garden_plots()): return false
	game.visual_language = VisualLanguage.new()
	game.element_garden_presenter = CountedGardenPresenter.new()
	if not game.visual_language.load_from_file(game.VISUAL_LANGUAGE_PATH) or not game.element_garden_presenter.configure(game.visual_language): return false
	game.world = game._new_wellspring_world(120)
	if game.world == null: return false
	game.session_transport = SessionTransport.new()
	game.authoritative_session = AuthoritativeSession.new()
	game.authoritative_session.world = game.world
	game.session_round_values = game.authoritative_session.session_round.capture(game.world)
	game.player_preferences = PlayerPreferences.new()
	game.controls_editor = ControlBindingEditor.new()
	game.spell_loom_editor = SpellLoomEditor.new()
	game.player_compendium = game.PlayerCompendiumScript.new()
	game.character_selection_grid = game.CharacterSelectionGridScript.new()
	game.input_router = InputRouter.new(1)
	game.element_expansion.game = game
	game.local_navigation.configure(game)
	game.application_input_active = true
	game.world.player().reset_for_spawn(game.campus_layout.spawn * SimConfig.FIXED_SCALE)
	game.current_position = Vector2(game.campus_layout.spawn)
	game.previous_position = game.current_position
	return true


func _finish_arrival(game: Node) -> void:
	var world_hash: String = game.world.state_hash()
	var tick: int = game.world.tick
	for unused: int in 65:
		if not game.element_garden_arrival_pending: break
		var visual_calls: int = game.element_garden_presenter.preparation_calls
		game._process(0.0)
		check(game.element_garden_presenter.preparation_calls - visual_calls <= 1, "actual Bootstrap pump performs at most one surface/plaque preparation per process frame")
		equal(game.world.state_hash(), world_hash, "zero-step loading preparation cannot alter live player or battlefield authority")
		equal(game.world.tick, tick, "staging frames never advance live simulation time")
		check(int(game.element_garden.arrival_status().total_courts) <= 63, "arrival remains inside the combined63-court bound")
		check(int(game.element_garden_presenter._surface.diagnostics().resident) <= 63, "derived presentation remains inside the same bounded mask universe")
	check(not game.element_garden_arrival_pending, "every bounded destination finishes preparation in at most63 frames")
	check(not game._area_loading(), "ready headless terrain plus complete exhibits releases the existing loading surface")
	for entry: Dictionary in game.element_garden.render_entries():
		check(game.element_garden_presenter._surface._cache.has(int(entry.mask)), "atomic publication includes a prepared surface for every first-visible plot")
		check(game.element_garden_presenter._plaques.has(String(entry.name)), "atomic publication includes the actual current plaque for every first-visible plot")


func _arrival_fixture(size: Vector2i = Vector2i(1280,720)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.handle_input_locally = true
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	var game := Harness.new()
	viewport.add_child(game)
	if not _configure(game):
		check(false, "arrival fixture configures real navigation, map, Garden and paid world")
		viewport.free()
		return {}
	game.champion_catalog = ChampionCatalog.new()
	if not game.champion_catalog.load_from_file(game.CHAMPION_CATALOG_PATH,game.ability_catalog) or not game.champion_catalog.apply_to_player(game.world.player(),"oh_tipi"):
		check(false,"arrival fixture applies an actual champion profile before simulation")
		game.world = null
		viewport.free()
		return {}
	var actor: PlayerState = game.world.player()
	actor.health_recovery_per_second = 0
	actor.flux_recovery_per_second = 0
	actor.stamina_recovery_per_second = 0
	# Use the supported stable-framing preference so the stationary comparison
	# measures arrival semantics without an unrelated pointer-led camera pan.
	game.player_preferences.reduced_motion = true
	game.player_preferences.camera_look_ahead = false
	viewport.notify_mouse_entered()
	return {"game":game,"viewport":viewport}


func _test_garden_travel_arrival() -> void:
	InputRouter.ensure_input_map()
	var old_mouse_mode := Input.mouse_mode
	var saved := {}
	for action: StringName in PlayerPreferences.DEFAULT_MOUSE_BINDINGS:
		saved[action] = InputMap.action_get_events(action).duplicate()
	var fixture := _arrival_fixture()
	if fixture.is_empty(): return
	var game: Node = fixture.game
	var viewport: SubViewport = fixture.viewport
	var actor: PlayerState = game.world.player()
	actor.health -= 1234; actor.flux -= 4567; actor.stamina -= 3456
	var resources := [actor.health,actor.flux,actor.stamina,actor.spell_wire_ids.duplicate(),actor.spell_cooldown_ticks.duplicate()]
	game.player_preferences.mouse_bindings[&"punch"] = 0
	game.player_preferences.mouse_bindings[&"spell_1"] = MOUSE_BUTTON_LEFT
	check(game.input_router.configure_mouse_bindings(game.player_preferences.mouse_bindings), "arrival handoff uses a valid supported spell remap")
	check(game.local_navigation.open_map(), "actual map opens before the travel confirmation")
	for index: int in game.local_navigation.map_panel.model.destinations.size():
		if String(game.local_navigation.map_panel.model.destinations[index].id) == "element-garden": game.local_navigation.map_panel.model.selected_index = index
	var geo: Dictionary = MapPanel.geometry(Vector2(viewport.size)/game._ui_scale())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (geo.travel as Rect2).get_center()*game._ui_scale()
	Input.parse_input_event(click); Input.flush_buffered_events(); viewport.push_input(click,true)
	check(viewport.is_input_handled() and actor.last_event == "map_travel", "actual held pointer commits the authored Garden travel")
	check(game.element_garden_arrival_pending and game._area_loading(), "only successful explicit travel arms the Garden arrival episode")
	check(not game.local_navigation.blocks_gameplay(), "travel closes its old map instead of hiding it under loading")
	equal([actor.health,actor.flux,actor.stamina,actor.spell_wire_ids,actor.spell_cooldown_ticks],resources,"actual pointer travel preserves finite player resources and weave")
	var after_travel: String = game.world.state_hash()
	var paid_before := int(game.world.hex_court.metrics.matter_paid)
	game.accumulator_seconds = 0.05
	game._process(0.1)
	check(game.element_garden_arrival_pending, "real Garden demand cannot complete in its first one-entry frame")
	equal(game.accumulator_seconds,0.0,"existing loading path drops catch-up debt rather than aging the world on release")
	equal(game.world.state_hash(),after_travel,"first loading frame preserves the complete live world")
	for keycode: int in [KEY_ESCAPE,KEY_F6]:
		var key := InputEventKey.new()
		key.keycode = keycode; key.physical_keycode = keycode; key.pressed = true
		viewport.push_input(key,true)
		check(viewport.is_input_handled(),"arrival consumes modal-opening keys during unpublished preparation")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK; pad.pressed = true
	viewport.push_input(pad,true)
	check(viewport.is_input_handled(),"arrival consumes controller Back while preparation owns input")
	check(not game.local_navigation.blocks_gameplay() and not game.element_expansion.panel.is_open and not game.player_compendium.is_open,"loading cannot conceal a newly opened menu, Range or guide")
	_finish_arrival(game)
	var view := Rect2(game._camera_origin(game.current_position),Vector2(viewport.size)/game._camera_zoom_scale())
	var expected := Garden.new()
	check(expected.configure(game.campus_layout.element_garden_plots()) and expected.step(view,game.current_position),"ordinary synchronous arrival supplies the exact visible-state control")
	_assert_arrival_same(game.element_garden,expected)
	for unused: int in 4: game._process(0.0)
	_assert_arrival_same(game.element_garden,expected)
	for tick: int in range(1,5):
		game._process(1.0/120.0)
		equal(game.world.tick,tick,"release advances only new ordinary fixed ticks, with no loading catch-up burst")
		equal(actor.flux,int(resources[1]),"held travel confirmation stays quarantined beyond the two-frame guard")
		equal(int(game.world.hex_court.metrics.matter_paid),paid_before,"held travel input creates no live paid source during or after loading")
		if tick>1: check(expected.step(view,game.current_position),"baseline advances exactly after its original tick0 admission")
		_assert_arrival_same(game.element_garden,expected)
	click = click.duplicate(); click.pressed = false
	Input.parse_input_event(click); Input.flush_buffered_events(); viewport.push_input(click,true)
	game._process(1.0/120.0)
	check(not game.input_router.quarantined_actions.has(&"spell_1"),"actual release rearms the pointer after arrival")
	click = click.duplicate(); click.pressed = true; click.position = Vector2(viewport.size.x-8,8)
	Input.parse_input_event(click); Input.flush_buffered_events(); viewport.push_input(click,true)
	game._process(1.0/120.0)
	equal(int(resources[1])-actor.flux,int(CombatTuning.cast_definition_view(actor.spell_wire_id(1)).flux_cost),"fresh intentional post-arrival spell pays its normal Flux exactly once")
	equal(actor.pending_cast_wire_id,actor.spell_wire_id(1),"fresh press enters ordinary equipped startup")
	click = click.duplicate(); click.pressed = false
	Input.parse_input_event(click); Input.flush_buffered_events(); viewport.push_input(click,true)
	game.world = null
	viewport.free()
	for action: StringName in saved:
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for event: InputEvent in saved[action]: InputMap.action_add_event(action,event)
	Input.mouse_mode = old_mouse_mode


func _assert_arrival_same(actual: RefCounted,expected: RefCounted) -> void:
	equal(actual._resident.keys(),expected._resident.keys(),"first-visible arrival contains every exact camera-visible plot in original order")
	for mask: int in expected._resident:
		if not actual._resident.has(mask): continue
		var a: Dictionary = actual._resident[mask]
		var b: Dictionary = expected._resident[mask]
		for key: String in ["tick","cycle","started","active","decay","expiry","mode","material"]:
			equal(a[key],b[key],"staged arrival retains concrete admission and finite phase metadata")
		equal((a.court as HexChemistryWorld).state_hash(),(b.court as HexChemistryWorld).state_hash(),"arrival has exact ordinary funded chemistry, source IDs and ownership")
		check((a.court as HexChemistryWorld).conservation_valid(),"arrival never manufactures exhibition matter")


func _test_garden_arrival_cancellation() -> void:
	for reason: String in ["resize","world","mode","online","challenge","directory","failed_travel","replacement"]:
		var fixture := _arrival_fixture()
		if fixture.is_empty(): return
		var game: Node = fixture.game
		var viewport: SubViewport = fixture.viewport
		check(game.local_navigation.travel("element-garden"),"cancellation fixture commits real Garden travel")
		game._process(0.0)
		check(game.element_garden_arrival_pending and int(game.element_garden.arrival_status().prepared)==1,"cancellation starts with one genuinely funded unpublished entry")
		var authority: String = game.world.state_hash()
		match reason:
			"resize":
				viewport.size = Vector2i(960,540)
				_finish_arrival(game)
				var view := Rect2(game._camera_origin(game.current_position),Vector2(viewport.size)/game._camera_zoom_scale())
				var expected := Garden.new()
				check(expected.configure(game.campus_layout.element_garden_plots()) and expected.step(view,game.current_position),"resized exact camera rectangle has an ordinary control")
				_assert_arrival_same(game.element_garden,expected)
			"world":
				game.world = game._new_wellspring_world(120)
				var replacement: String = game.world.state_hash()
				game._prepare_element_garden_arrival_frame()
				equal(game.world.state_hash(),replacement,"world replacement cancellation cannot publish or mutate old authority into the new world")
			"mode":
				game.interception_practice_active = true
				game._prepare_element_garden_arrival_frame()
				equal(game.world.state_hash(),authority,"mode cancellation keeps all live actor and paid-world fields unchanged")
			"online":
				game.session_transport.mode = SessionTransport.Mode.HOSTING
				game._prepare_element_garden_arrival_frame()
				equal(game.world.state_hash(),authority,"joining an online mode cannot publish offline exhibition authority")
				game.session_transport.mode = SessionTransport.Mode.OFFLINE
			"challenge":
				game.element_expansion.challenge_active = true
				game._prepare_element_garden_arrival_frame()
				equal(game.world.state_hash(),authority,"signature context cancels unpublished free-exploration exhibits")
			"directory":
				check(game.element_garden.configure(game.campus_layout.element_garden_plots()),"directory replacement advances the Garden content generation")
				game._prepare_element_garden_arrival_frame()
			"failed_travel":
				check(not game.local_navigation.travel("unknown-arrival"),"a rejected superseding destination does not retain stale pending authority")
				equal(game.world.state_hash(),authority,"failed travel keeps the current player and live paid world exact")
			"replacement":
				var target: String = String(game.campus_layout.travel_destinations()[0].id)
				check(target!="element-garden" and game.local_navigation.travel(target),"another valid authored destination supersedes partial Garden staging")
				_finish_arrival(game)
				var view := Rect2(game._camera_origin(game.current_position),Vector2(viewport.size)/game._camera_zoom_scale())
				var expected := Garden.new()
				check(expected.configure(game.campus_layout.element_garden_plots()) and expected.step(view,game.current_position),"replacement target has its own concrete first-view control")
				_assert_arrival_same(game.element_garden,expected)
		check(not game.element_garden_arrival_pending,"completed or canceled generation releases the arrival latch")
		if reason not in ["resize","replacement"]:
			equal(int(game.element_garden.arrival_status().total_courts),0,"canceled unpublished courts are fully released")
			check(game.element_garden.render_entries().is_empty(),"canceled generation cannot expose stale field pixels")
			equal(int(game.element_garden_presenter.arrival_status().prepared),0,"canceled generation releases derived presentation readiness")
			equal(int(game.element_garden_presenter._surface.diagnostics().resident),0,"canceled unpublished fields cannot retain stale surface geometry")
			equal(game.element_garden_presenter._plaques.size(),0,"canceled unpublished fields cannot retain stale plaque layouts")
		game.world = null
		viewport.free()


func _test_walking_does_not_stage() -> void:
	InputRouter.ensure_input_map()
	var old_mouse_mode := Input.mouse_mode
	var fixture := _arrival_fixture()
	if fixture.is_empty(): return
	var game: Node = fixture.game
	var viewport: SubViewport = fixture.viewport
	check(game.local_navigation.travel("element-garden"),"walking control first arrives through normal authored travel")
	_finish_arrival(game)
	for unused: int in 3: game._process(0.0)
	var actor: PlayerState = game.world.player()
	var initial_position := Vector2i(actor.position_x,actor.position_y)
	var initial_masks: Array = game.element_garden._resident.keys()
	var new_plot_seen := false
	var start_tick: int = game.world.tick
	var visual_calls: int = game.element_garden_presenter.preparation_calls
	Input.action_press(&"move_down")
	for frame: int in 180:
		game._process(1.0/60.0)
		check(not game.element_garden_arrival_pending and not game._area_loading(),"ordinary held walking never acquires a new Garden loading pause")
		equal(game.world.tick,start_tick+(frame+1)*2,"ready-terrain walking advances every ordinary120Hz command without a staging stall")
		for mask: int in game.element_garden._resident:
			if mask not in initial_masks: new_plot_seen = true
	Input.action_release(&"move_down")
	check(Vector2i(actor.position_x,actor.position_y).distance_to(initial_position)>160000.0,"ordinary movement actually traverses a meaningful Garden distance")
	check(new_plot_seen,"walking fixture positively witnesses a newly visible plot using synchronous admission")
	equal(game.element_garden_presenter.preparation_calls, visual_calls, "ordinary walking never invokes the explicit arrival preparation gate")
	equal(int(game.world.hex_court.metrics.matter_paid),0,"harmless walking exhibits never fund a player spell")
	game.world = null
	viewport.free()
	Input.mouse_mode = old_mouse_mode


func _test_ready_garden_waits_for_terrain() -> void:
	var fixture := _arrival_fixture()
	if fixture.is_empty(): return
	var game: Node = fixture.game
	var viewport: SubViewport = fixture.viewport
	game.hold_terrain = true
	check(game.local_navigation.travel("element-garden"),"terrain-wait fixture begins with an actual successful travel")
	var live_hash: String = game.world.state_hash()
	for unused: int in 65:
		game._process(0.0)
		if bool(game.element_garden.arrival_status().ready): break
	check(bool(game.element_garden.arrival_status().ready),"Garden can finish while the separate terrain prerequisite is pending")
	check(game.element_garden_arrival_pending and game._area_loading(),"ready exhibits cannot release unfinished terrain arrival")
	check(game.element_garden.render_entries().is_empty(),"all prepared fields remain detached behind the unfinished terrain prerequisite")
	check(bool(game.element_garden_presenter.arrival_status().ready),"ready chemistry also has complete current surface and plaque preparation")
	equal(game.world.state_hash(),live_hash,"terrain and Garden preparation preserve complete live authority")
	viewport.size = Vector2i(960,540)
	game._process(0.0)
	equal(int(game.element_garden.arrival_status().prepared),1,"resize after Garden readiness rekeys the exact still-unpublished view")
	equal(int(game.element_garden_presenter.arrival_status().prepared),1,"resize cannot reuse old unpublished court presentation readiness")
	for unused: int in 65:
		if bool(game.element_garden.arrival_status().ready): break
		game._process(0.0)
	check(bool(game.element_garden.arrival_status().ready) and game.element_garden.render_entries().is_empty(),"resized ready fields remain unpublished until terrain completion")
	game.hold_terrain = false
	game._process(0.0)
	check(not game._area_loading() and not game.element_garden_arrival_pending,"both complete prerequisites release together on a zero-step frame")
	var view := Rect2(game._camera_origin(game.current_position),Vector2(viewport.size)/game._camera_zoom_scale())
	var expected := Garden.new()
	check(expected.configure(game.campus_layout.element_garden_plots()) and expected.step(view,game.current_position),"final resized arrival has an independent ordinary admission control")
	_assert_arrival_same(game.element_garden,expected)
	equal(game.world.state_hash(),live_hash,"atomic zero-step publication changes no live actor or player-funded source")
	game.world = null
	viewport.free()


func _test_garden_visual_preparation_failure() -> void:
	var fixture := _arrival_fixture()
	if fixture.is_empty(): return
	var game: Node = fixture.game
	var viewport: SubViewport = fixture.viewport
	check(game.local_navigation.travel("element-garden"), "visual refusal begins with successful authored travel")
	game._process(0.0)
	equal(game.element_garden_presenter.preparation_calls, 1, "visual refusal follows one actual surface/plaque preparation")
	var authority: String = game.world.state_hash()
	game.element_garden_presenter.refuse_next = true
	game._process(0.0)
	check(not game.element_garden_arrival_pending and not game._area_loading(), "visual refusal cannot leave an endless loading gate")
	check(game.element_garden.render_entries().is_empty(), "visual refusal cannot publish a partially prepared destination")
	equal(int(game.element_garden.arrival_status().total_courts), 0, "visual refusal releases unpublished funded courts")
	equal(int(game.element_garden_presenter._surface.diagnostics().resident), 0, "visual refusal releases unpublished derived geometry")
	equal(game.element_garden_presenter._plaques.size(), 0, "visual refusal releases unpublished derived text")
	equal(game.world.state_hash(), authority, "visual failure handling leaves every live actor and paid source unchanged")
	equal(game.element_garden_arrival_error, "Injected visual preparation failure.", "visual refusal remains visible after local preparation cancellation")
	game.element_garden_presenter.refuse_next = false
	game._process(1.0/120.0)
	check(not game.element_garden.render_entries().is_empty(), "normal synchronous admission remains available after a transient visual refusal")
	equal(game.element_garden_arrival_error, "Injected visual preparation failure.", "ordinary fallback does not misreport failed visual staging as success")
	equal(int(game.world.hex_court.metrics.matter_paid), 0, "presentation fallback never grants or spends player spell matter")
	game._cancel_element_garden_arrival()
	equal(game.element_garden_arrival_error, "", "explicit cancellation can acknowledge the retained visual diagnostic")
	game.world = null
	viewport.free()


func _test_garden_preparation_failure() -> void:
	var fixture := _arrival_fixture()
	if fixture.is_empty(): return
	var game: Node = fixture.game
	var viewport: SubViewport = fixture.viewport
	var refusing := RefusingGarden.new()
	check(refusing.configure(game.campus_layout.element_garden_plots()), "preparation failure uses the ordinary configured Garden except one refused constructor")
	game.element_garden = refusing
	check(game.local_navigation.travel("element-garden"), "failure case begins through successful authored travel")
	game._process(0.0)
	equal(int(refusing.arrival_status().prepared), 1, "failure occurs only after one genuine funded entry exists")
	var authority: String = game.world.state_hash()
	refusing.refuse_next = true
	game._process(0.0)
	check(not game.element_garden_arrival_pending and not game._area_loading(), "failed preparation cannot strand the player in an endless arrival wait")
	equal(int(refusing.arrival_status().total_courts), 0, "failed generation releases its already funded unpublished entry")
	check(refusing.render_entries().is_empty(), "failed preparation cannot publish a partial success")
	equal(game.world.state_hash(), authority, "failure handling changes no player or live paid authority")
	equal(game.element_garden_arrival_error, "Injected exhibit preparation failure.", "Bootstrap preserves the concrete preparation failure after canceling staged state")
	refusing.refuse_next = false
	game._process(1.0/120.0)
	check(not refusing.render_entries().is_empty(), "ordinary synchronous admission remains available after a transient preparation failure")
	equal(game.element_garden_arrival_error, "Injected exhibit preparation failure.", "ordinary fallback does not erase or misreport failed staging as success")
	equal(int(game.world.hex_court.metrics.matter_paid), 0, "failure and fallback never fund a player spell")
	game._cancel_element_garden_arrival()
	equal(game.element_garden_arrival_error, "", "explicit cancellation may acknowledge and clear the retained diagnostic")
	game.world = null
	viewport.free()

func _rejected(nav: RefCounted, actor: PlayerState, destination: String, label: String) -> void:
	var before := actor.canonical_values()
	check(not nav.travel(destination), label + " refuses travel")
	equal(actor.canonical_values(), before, label + " preserves every actor field")

func _test_input(game: Node) -> void:
	var nav: RefCounted = game.local_navigation
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	game.controls_input_guard_frames = 0
	game._unhandled_input(key)
	check(nav.map_panel.is_open, "actual Bootstrap M opens map")
	var release := InputEventKey.new()
	release.keycode = KEY_SPACE
	release.pressed = false
	check(nav.handle_input(release), "map consumes releases to prevent buffered jump leaks")
	key.keycode = KEY_ESCAPE
	game._unhandled_input(key)
	check(not nav.map_panel.is_open, "Escape closes map")
	game.controls_input_guard_frames = 0
	game._unhandled_input(key)
	check(nav.menu_open, "Escape opens compact menu in freeplay")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	game._unhandled_input(joy)
	check(nav.map_panel.is_open, "controller confirms World map from menu")
	joy.button_index = JOY_BUTTON_B
	game._unhandled_input(joy)
	check(not nav.blocks_gameplay(), "controller B closes map")
	game.controls_input_guard_frames = 0
	joy.button_index = JOY_BUTTON_BACK
	game._unhandled_input(joy)
	check(nav.menu_open and not game.player_compendium.is_open, "controller Back opens the consolidated Menu directly")
	nav.close()
	game.controls_input_guard_frames = 0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Navigation.MENU_ENTRY.get_center() * game._ui_scale()
	game._unhandled_input(click)
	check(nav.menu_open, "single visible Menu button opens through pointer")
	nav.close()
	var previous_quality: String = Quality.profile
	var previous_cap := Engine.max_fps
	var tick_before: int = game.world.tick
	nav.activate("performance")
	check(nav.performance_panel.is_open and game._gameplay_input_blocked(), "Performance owns input through actual navigation")
	key.keycode = KEY_RIGHT
	game._unhandled_input(key)
	equal(game.player_preferences.render_quality, "standard", "actual keyboard event applies visual detail")
	equal(game.world.tick, tick_before, "local performance changes cannot advance or replace authority")
	key.keycode = KEY_DOWN
	game._unhandled_input(key)
	key.keycode = KEY_RIGHT
	game._unhandled_input(key)
	equal(Engine.max_fps, 120, "actual cap event reaches engine presentation setting")
	key.keycode = KEY_ESCAPE
	game._unhandled_input(key)
	check(not nav.blocks_gameplay() and game.controls_input_guard_frames > 0, "closing Performance quarantines confirm input")
	Quality.set_profile(previous_quality)
	Engine.max_fps = previous_cap
	game.controls_input_guard_frames = 0
	game.controls_editor.open_editor()
	key.keycode = KEY_M
	check(not nav.handle_input(key), "Controls M retains reduced effects priority")
	game.controls_editor.close_editor()
	game.player_preferences.keyboard_bindings[&"emote"] = KEY_M
	check(not nav.handle_input(key), "custom gameplay M binding retains priority")

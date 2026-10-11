extends SceneTree
## Root executes this native Bootstrap journey; authored input is not device acceptance.

const Scene = preload("res://scenes/bootstrap/bootstrap.tscn")
const Navigation = preload("res://src/app/local_navigation_controller.gd")
const MapPanel = preload("res://src/presentation/wellspring_map_panel.gd")
const Weaves = preload("res://src/app/character_weave_library.gd")
const Progression = preload("res://src/app/signature_progression.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const GardenPresenter = preload("res://src/presentation/element_garden_presenter.gd")
const SIZES := [Vector2i(1280,720), Vector2i(960,540)]
const SOURCES := [
	"res://scenes/bootstrap/bootstrap.tscn", "res://src/app/bootstrap.gd",
	"res://src/app/local_navigation_controller.gd", "res://src/app/wellspring_map_model.gd",
	"res://src/presentation/wellspring_map_panel.gd", "res://src/presentation/wellspring_district_style.gd",
	"res://src/content/sanctum_campus_layout.gd", "res://content/maps/sanctum_campus_g2_v1.json",
	"res://src/presentation/sanctum_campus_renderer.gd", "res://src/presentation/wellspring_illustrated_kit.gd",
	"res://src/presentation/hex_environment_layout.gd", "res://src/presentation/pov_terrain_backdrop.gd",
	"res://src/presentation/player_camera_rig.gd", "res://src/sim/hex/hex_world_definition.gd",
	"res://tests/visual/capture_wellspring_expansion.gd",
	"res://src/app/element_garden_exhibition.gd", "res://src/presentation/element_garden_presenter.gd",
]
var output := ""
var game: Node
var viewport: SubViewport
var source_hashes := {}
var startup_files := {}
var saved_files := {}
var checkpoints: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var steps := 0
var failed := false
var output_created := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/wellspring-expansion-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("A fresh native res://.godot/wellspring-expansion-native-* output is required."); return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create native journey output."); return
	output_created = true
	for path: String in SOURCES:
		source_hashes[path] = FileAccess.get_sha256(path)
		if String(source_hashes[path]).length() != 64:
			_fail("Missing captured source: " + path); return
	for path: String in [PlayerPreferences.DEFAULT_PATH, Weaves.DEFAULT_PATH, Weaves.DEFAULT_PATH + Weaves.BACKUP_SUFFIX, Progression.DEFAULT_PATH, Progression.DEFAULT_PATH + Progression.BACKUP_SUFFIX]:
		startup_files[path] = _file_hash(path)
	root.visible = true
	root.mode = Window.MODE_MINIMIZED
	viewport = SubViewport.new()
	viewport.size = SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = Scene.instantiate()
	game.preferences_persistence_allowed = false
	game.preference_overrides_are_transient = true
	game.set_process(false)
	viewport.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.preferences_persistence_allowed = false
	game.preference_overrides_are_transient = true
	game.application_input_active = true
	game.player_preferences.reduced_motion = false # Transient capture mode; persistence remains disabled.
	game.character_weaves.persistence_allowed = false
	game.element_expansion.progression.persistence_allowed = false
	if game.element_audio != null:
		game.element_audio.silence()
		game.element_audio.set_process(false)
	await process_frame
	if not _check(game.world != null and game.world.hex_court != null and game.campus_layout.canvas_size == Vector2i(6144,5376), "production_expanded_campus_loaded"): return
	for path: String in startup_files:
		var initialized := _file_hash(path)
		if initialized != startup_files[path] and not (path == PlayerPreferences.DEFAULT_PATH and startup_files[path] == "ABSENT" and initialized != "ABSENT"):
			_fail("Initialization changed persisted bytes: " + path); return
		saved_files[path] = initialized
	var destinations: Array[Dictionary] = game.campus_layout.travel_destinations()
	if not _check(destinations.size() == 13, "all_thirteen_authored_destinations_admitted"): return
	for size: Vector2i in SIZES:
		viewport.size = size
		for index: int in destinations.size():
			if not await _open_map(index == 0): return
			var model: RefCounted = game.local_navigation.map_panel.model
			# Keyboard focus is driven through production input, never assigned.
			for unused: int in destinations.size():
				if model.selected_index == index: break
				_key(KEY_DOWN if model.selected_index < index else KEY_UP)
			if not _check(String(model.selected_destination().id) == String(destinations[index].id), "map_focus_matches_named_destination", {"id": destinations[index].id, "size": [size.x,size.y]}): return
			if not _check_map_geometry(): return
			if index in [0,8]:
				if not await _capture("map-page-%d" % (index / 8 + 1), {"destination": destinations[index].id}): return
			var actor: PlayerState = game._local_player_state()
			var economy := _economy(actor)
			var before_tick: int = game.world.tick
			var paid_before := int(game.world.hex_court.metrics.matter_paid)
			if index % 3 == 0:
				_key(KEY_ENTER)
			elif index % 3 == 1:
				var joy := InputEventJoypadButton.new()
				joy.button_index = JOY_BUTTON_A
				joy.pressed = true
				game._unhandled_input(joy)
			else:
				_click((MapPanel.geometry(_logical_viewport()).travel as Rect2).get_center())
			var point := Vector2i(int(destinations[index].position[0]),int(destinations[index].position[1])) * SimConfig.FIXED_SCALE
			if not _check(not game.local_navigation.blocks_gameplay() and Vector2i(actor.position_x,actor.position_y) == point, "actual_input_confirms_authoritative_arrival", {"id": destinations[index].id, "pixels": destinations[index].position, "size": [size.x,size.y], "input": ["keyboard","controller","pointer"][index % 3]}): return
			if not _check(_economy(actor) == economy and game.world.tick == before_tick and int(game.world.hex_court.metrics.matter_paid) == paid_before, "travel_preserves_resources_weave_cooldowns_and_paid_matter"): return
			if not _check(game.world.collision.can_occupy(point, actor.radius) and game.previous_position == game.current_position and not game.player_camera.initialized, "arrival_has_live_clearance_and_no_interpolation_or_camera_smear"): return
			if index >= 8:
				for reduced: bool in [false,true]:
					game.requested_capture_reduced_effects = reduced
					if not await _capture(String(destinations[index].id) + ("-reduced" if reduced else "-normal"), {"destination": destinations[index].id,"reduced":reduced}): return
				game.requested_capture_reduced_effects = false
			if not _drain_handoff(): return
			if not _step(): return
			var start := Vector2i(actor.position_x,actor.position_y)
			for unused: int in 8:
				if not _step(Vector2i(1000,0)): return
			if not _check(actor.position_x > start.x and actor.position_y == start.y, "ordinary_walk_still_works_after_arrival", {"id":destinations[index].id}): return
			for unused: int in 60:
				if not _step(): return
			if not _check(actor.velocity_x == 0 and actor.velocity_y == 0 and game.local_navigation.travel_availability().enabled, "ordinary_braking_returns_to_free_exploration"): return
	if not await _garden_journey(): return
	if not _saved_unchanged(): return
	for path: String in source_hashes:
		if not _check(FileAccess.get_sha256(path) == source_hashes[path], "source_stable", {"path":path}): return
	_write_receipt("passed", "")
	print("PASS Wellspring expansion journey: %d checks, %d simulation steps, %d native images; visual review required" % [checkpoints.size(),steps,frames.size()])
	game.queue_free()
	await process_frame
	quit(0)

func _garden_journey() -> bool:
	var actor: PlayerState = game._local_player_state()
	var model: RefCounted = game.element_garden
	var plots: Array[Dictionary] = game.campus_layout.element_garden_plots()
	if not _check(plots.size() == 63, "all_sixty_three_physical_garden_plots_exist"): return false
	for size: Vector2i in SIZES:
		viewport.size = size
		for sample: Dictionary in [{"mask":4,"mode":"single"},{"mask":4,"mode":"self"},{"mask":6,"mode":"mixed"},{"mask":7,"mode":"mixed"},{"mask":15,"mode":"mixed"},{"mask":31,"mode":"mixed"},{"mask":63,"mode":"mixed"}]:
			var center := Vector2.ZERO
			for plot: Dictionary in plots:
				if int(plot.mask) == int(sample.mask): center = plot.center
			# Explicit visual fixture placement; map travel was exercised above.
			# The showcase itself receives no actor or campus authority reference.
			var point := Vector2i(center + Vector2(0, 80)) * SimConfig.FIXED_SCALE
			if not _check(game.world.collision.can_occupy(point,actor.radius), "garden_walkway_fixture_has_real_clearance",sample): return false
			actor.position_x = point.x
			actor.position_y = point.y
			game.player_camera.clear()
			_sync()
			model.clear()
			var before: String = game.world.state_hash()
			var found := false
			for unused: int in 1600:
				game._update_element_garden()
				var info: Dictionary = model.nearest_info(center)
				if int(info.get("mask",0)) != int(sample.mask): continue
				var entries: Array[Dictionary] = model.render_entries()
				for entry: Dictionary in entries:
					if int(entry.mask) != int(sample.mask): continue
					var product_present: bool = not entry.court.products.is_empty()
					if String(sample.mode) == "single": found = not product_present and int(entry.court.metrics.deposited) > 0
					else: found = product_present and String(entry.phase) == "active"
				if found: break
			if not _check(found, "actual_ground_phase_available",sample): return false
			if not _check(game.world.state_hash() == before, "exhibition_cycle_does_not_change_live_world",sample): return false
			if not await _capture("garden-%02d-%s" % [int(sample.mask),String(sample.mode)],sample): return false
			if int(sample.mask) == 63:
				if not _paid_plot_overlap(): return false
				game.requested_capture_reduced_effects = true
				if not await _capture("garden-63-reduced", {"mask":63,"mode":"mixed","live_paid_fire_overlap":true}): return false
				game.requested_capture_reduced_effects = false
	return true

func _paid_plot_overlap() -> bool:
	var actor: PlayerState = game._local_player_state()
	var original_wire := int(actor.spell_wire_ids[0])
	var original_slots := actor.spell_wire_ids.duplicate()
	var flux_before := actor.flux
	var paid_before := int(game.world.hex_court.metrics.matter_paid)
	# Explicit in-memory visual fixture loadout, followed by genuine ordinary
	# paid input. This never calls the saved-weave coordinator or invents a field.
	if not _check(actor.place_proven_spell(0,Mixtures.wire_for(2,"mantle")), "garden_overlap_fixture_equips_live_fire_mantle"): return false
	if not _step(Vector2i.ZERO,SimCommand.SPELL_PRESSED_BITS[0]): return false
	for unused: int in 18:
		if not _step(Vector2i(0,-1000)): return false
	for unused: int in 40:
		if not _step(): return false
	var fire_cells := 0
	for cell: Vector2i in game.world.hex_court.occupied_cells():
		if not game.world.hex_court.render_regions(cell,"fire",float(game.world.tick)).is_empty(): fire_cells += 1
	if not _check(actor.flux < flux_before and int(game.world.hex_court.metrics.matter_paid) > paid_before and fire_cells > 0, "ordinary_paid_fire_is_visible_over_exhibit", {"cells":fire_cells}): return false
	if not _check(actor.place_proven_spell(0,original_wire) and actor.spell_wire_ids == original_slots, "garden_overlap_fixture_restores_original_weave"): return false
	return _saved_unchanged()

func _open_map(capture_menu: bool) -> bool:
	if not _drain_handoff(): return false
	_click(Navigation.MENU_ENTRY.get_center())
	if not _check(game.local_navigation.menu_open, "visible_compact_menu_entry_opens"): return false
	if capture_menu:
		if not await _capture("compact-menu", {}): return false
	var rows: Array[Dictionary] = game.local_navigation.entries()
	for index: int in rows.size():
		if String(rows[index].id) == "map":
			_click(Navigation.row_rect(_logical_viewport(),rows.size(),index).get_center())
			return _check(game.local_navigation.map_panel.is_open and game._gameplay_input_blocked(), "compact_menu_world_map_opens_and_owns_input")
	return _check(false, "compact_menu_contains_world_map")

func _drain_handoff() -> bool:
	# The native root is deliberately minimized. Reproduce focus-in through the
	# production lifecycle rather than letting desktop focus hide this fixture UI.
	if not game.application_input_active: game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var tick_before: int = game.world.tick
	var hash_before: String = game.world.state_hash()
	game.accumulator_seconds = 0.0
	for unused: int in 4:
		if game.controls_input_guard_frames <= 0: break
		game._process(0.0)
	return _check(game.controls_input_guard_frames == 0 and game.world.tick == tick_before and game.world.state_hash() == hash_before, "ordinary_zero_delta_handoff_preserves_simulation")

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func _click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point * float(game._ui_scale())
	game._unhandled_input(event)

func _logical_viewport() -> Vector2:
	return Vector2(viewport.size) / float(game._ui_scale())

func _economy(actor: PlayerState) -> Array:
	return [actor.health,actor.flux,actor.stamina,actor.spell_wire_ids.duplicate(),actor.spell_cooldown_ticks.duplicate(),actor.spell_status_values.duplicate(),actor.champion_wire_id]

func _step(direction: Vector2i = Vector2i.ZERO, pressed: int = 0) -> bool:
	if not game.application_input_active or game.controls_input_guard_frames > 0:
		if not _drain_handoff(): return false
	if not _check(not game._gameplay_input_blocked(), "no_authority_steps_behind_modal"): return false
	game.element_expansion.before_step()
	var commands: Array[SimCommand] = [SimCommand.new(game.world.tick,game._local_player_state().entity_id,direction.x,direction.y,0,pressed)]
	if not game.world.step(commands):
		_fail("Ordinary movement command failed: " + game.world.last_error); return false
	game.element_expansion.after_step()
	game._update_element_garden()
	steps += 1
	_sync()
	return _check(game.world.hex_court.conservation_valid(), "navigation_does_not_change_material_conservation")

func _sync() -> void:
	game.accumulator_seconds = 0.0
	game.current_position = game._player_position()
	game.previous_position = game.current_position
	game.previous_air_height = game._local_player_state().air_height
	game._reset_motion_history()

func _check_map_geometry() -> bool:
	var panel: RefCounted = game.local_navigation.map_panel
	var geo := MapPanel.geometry(_logical_viewport())
	if not _check(not (geo.map as Rect2).intersects(geo.list) and (geo.panel as Rect2).encloses(geo.travel), "map_and_directory_have_distinct_bounded_regions"): return false
	for i: int in panel.model.destinations.size():
		var a: Vector2 = panel.project(panel.model.destination_position(i),geo)
		if not _check((geo.map as Rect2).has_point(a), "every_waypoint_pin_is_on_map"): return false
		for j: int in range(i + 1,panel.model.destinations.size()):
			var b: Vector2 = panel.project(panel.model.destination_position(j),geo)
			if not _check(a.distance_to(b) >= 18.0, "waypoint_number_labels_do_not_overlap", {"a":i,"b":j,"distance":a.distance_to(b)}): return false
	return true

func _capture(stem: String, details: Dictionary) -> bool:
	_sync()
	game._update_element_garden()
	var before: String = game.world.state_hash()
	var origin: Vector2 = game._camera_origin(game._camera_focus_position(game.current_position))
	var visible := Rect2(origin,Vector2(viewport.size) / float(game._camera_zoom_scale()))
	if not _check(Rect2(Vector2.ZERO,Vector2(game.campus_layout.canvas_size)).encloses(visible), "camera_remains_inside_expanded_world", {"origin":[origin.x,origin.y],"visible":[visible.size.x,visible.size.y]}): return false
	# Several explicitly redrawn native frames allow the bounded POV backdrop
	# revision to finish after a distant arrival, without advancing authority.
	var render_started := Time.get_ticks_msec()
	for unused: int in 4:
		if details.has("mask"):
			# These are arranged views, not an OS focus test. Reproduce the
			# production focus-in handoff explicitly while the root is minimized.
			game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			if not _drain_handoff(): return false
		game.queue_redraw()
		await process_frame
	RenderingServer.force_draw(false)
	var settled_render_ms := Time.get_ticks_msec() - render_started
	if not _check(game.pov_terrain_backdrop.ready_for(visible), "native_backdrop_revision_matches_current_camera"): return false
	if not _check(game.world.state_hash() == before, "native_render_does_not_mutate_authority") or not _saved_unchanged(): return false
	if details.has("mask"):
		var garden_info: Dictionary = game.element_garden.nearest_info(game.current_position)
		if not _check(not game._gameplay_input_blocked() and not game.element_expansion.guide.active and int(garden_info.get("mask",0)) == int(details.mask), "nearby_garden_card_is_visible_for_selected_plot", details): return false
		var ui_scale: float = game._ui_scale()
		var plot_screen: Vector2 = (Vector2(garden_info.center) - origin) * float(game._camera_zoom_scale()) / ui_scale
		var plot_radius: float = 118.0 * float(game._camera_zoom_scale()) / ui_scale
		var card := GardenPresenter.card_geometry(garden_info,_logical_viewport(),ThemeDB.fallback_font,plot_screen,plot_radius)
		if not _check(not (card.box as Rect2).intersects(Rect2(plot_screen - Vector2.ONE * plot_radius,Vector2.ONE * plot_radius * 2.0)), "explanation_does_not_cover_the_inspected_ground_field", details): return false
	var image := viewport.get_texture().get_image()
	var leaf := "%s-%dx%d.png" % [stem,viewport.size.x,viewport.size.y]
	if image == null or image.get_size() != viewport.size or image.save_png(output.path_join(leaf)) != OK:
		_fail("Native capture failed: " + leaf); return false
	var frame := details.duplicate(true)
	frame.merge({"image":leaf,"sha256":FileAccess.get_sha256(output.path_join(leaf)),"size":[viewport.size.x,viewport.size.y],"world_hash":before,"tick":game.world.tick,"camera_origin":[origin.x,origin.y],"settled_render_ms":settled_render_ms})
	frames.append(frame)
	return true

func _saved_unchanged() -> bool:
	for path: String in saved_files:
		if _file_hash(path) != saved_files[path]:
			_fail("Journey changed persisted bytes: " + path); return false
	return true

func _file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"

func _check(condition: bool, id: String, details: Dictionary = {}) -> bool:
	checkpoints.append({"id":id,"passed":condition,"details":details})
	if not condition: _fail("Checkpoint failed: " + id)
	return condition

func _write_receipt(status: String,error: String) -> void:
	if not output_created: return
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"schema":1,"status":status,"error":error,"scope":"Actual Bootstrap Menu to World map; all thirteen destinations at two native sizes; keyboard/controller/pointer confirmation; real arrival clearance, unchanged resources/weave/cooldowns, camera and ordinary walking. Additional explicitly placed garden visual fixtures inspect raw, self-pair and two-through-six-element actual ground phases without modifying campus authority.","limitations":"Authored input events, visual fixture placements and SimCommands are not physical device acceptance or human wayfinding/playfeel validation. Images need individual native review. No performance claim follows from these finite geometry and cache checks.","display_server":DisplayServer.get_name(),"source_hashes":source_hashes,"startup_files":startup_files,"saved_files_before_and_after":saved_files,"simulation_steps":steps,"checkpoints":checkpoints,"frames":frames},"\t") + "\n")
	file.close()

func _fail(message: String) -> void:
	if failed: return
	failed = true
	_write_receipt("failed",message)
	push_error(message)
	quit(1)

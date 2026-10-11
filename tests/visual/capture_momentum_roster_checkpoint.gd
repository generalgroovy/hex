extends "res://tests/visual/capture_gamefeel_gallery.gd"
## Bounded native inspection. Root owns the engine lease and isolated APPDATA.
## Production map/Gallery + controlled direction boards + real paid simulation.

const Art = preload("res://src/presentation/fullbody_cast_presenter.gd")
const History = preload("res://src/presentation/actor_motion_history.gd")
const BODY_IDS := ["s_wayne", "oh_tipi", "red_baron"]
const TRANSITIONS := ["jump", "slide", "roll", "air_dodge", "walk"]
const CAPTURE_SOURCES := [
	"res://tests/visual/capture_gamefeel_gallery.gd",
	"res://tests/visual/capture_glow_flow.gd",
	"res://src/app/bootstrap.gd", "res://src/app/character_selection_model.gd",
	"res://src/presentation/character_selection_grid.gd",
	"res://src/presentation/pixel_flipbook_presenter.gd",
	"res://src/presentation/fullbody_cast_presenter.gd",
	"res://src/presentation/actor_motion_history.gd",
	"res://src/sim/movement/movement_system.gd",
	"res://src/sim/movement/movement_tuning.gd",
	"res://src/presentation/wellspring_service_buildings.gd",
	"res://src/presentation/sanctum_campus_renderer.gd",
	"res://content/maps/sanctum_campus_g2_v1.json",
	"res://content/runtime/runtime_build_identity_v1.json",
	"res://assets/portraits/champions_v1/manifest.json",
	"res://assets/portraits/champions_v1/joh_haynes.png",
	"res://assets/portraits/champions_v1/grimm_bow.png",
	"res://tests/visual/capture_momentum_roster_checkpoint.gd",
]
const MAP_VIEWS := [
	{"id": "academy-farflow-services", "point": Vector2i(1536, 392),
		"scope": "CHAMPIONS + SPELLS / WELLSPRING ACADEMY and FRIENDS + MATCHES / FARFLOW HALL"},
	{"id": "crucible-open-south-passage", "point": Vector2i(1568, 1552),
		"scope": "Crucible 106 narrowed facade, 128px east passage and FREE EXPERIMENT COURT floor route"},
]
var presentation_board: CheckpointBoard
var capture_bytes := 0
var simulation_records: Array[Dictionary] = []
var roster_records: Array[Dictionary] = []


class CheckpointBoard:
	extends Node2D
	var samples: Array[Dictionary] = []
	var title := ""
	var subtitle := ""
	var integer_zoom := 1
	var timeline := false
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * integer_zoom)
		draw_rect(Rect2(0, 0, 1280, 720), Color("26382f"))
		draw_string(ThemeDB.fallback_font, Vector2(18, 28), title, HORIZONTAL_ALIGNMENT_LEFT, 1240, 18, Color("f3dfac"))
		draw_string(ThemeDB.fallback_font, Vector2(18, 50), subtitle, HORIZONTAL_ALIGNMENT_LEFT, 1240, 12, Color("c7d5c5"))
		for sample: Dictionary in samples:
			var anchor: Vector2 = sample.anchor
			var lift := float(sample.get("lift", 0.0))
			draw_line(anchor + Vector2(-37, 0), anchor + Vector2(37, 0), Color("718775"), 1.0)
			Art.draw_frame(self, sample.frame, anchor - Vector2(0, lift))
			draw_string(ThemeDB.fallback_font, anchor + Vector2(-58, 20), String(sample.label), HORIZONTAL_ALIGNMENT_LEFT, 148, 11, Color("f3dfac"))
			if timeline:
				draw_string(ThemeDB.fallback_font, anchor + Vector2(-58, 36), String(sample.detail), HORIZONTAL_ALIGNMENT_LEFT, 148, 10, Color("c7d5c5"))
				if not String(sample.get("row_label", "")).is_empty():
					draw_string(ThemeDB.fallback_font, Vector2(18, anchor.y - 140), String(sample.row_label), HORIZONTAL_ALIGNMENT_LEFT, 200, 15, Color("f3dfac"))
			elif int(sample.column) == 0:
				draw_string(ThemeDB.fallback_font, Vector2(12, anchor.y - 30), String(sample.action), HORIZONTAL_ALIGNMENT_LEFT, 108, 13, Color("f3dfac"))
		draw_string(ThemeDB.fallback_font, Vector2(18, 703), "Fixed authored/reused pixels; no mesh. Still-frame evidence is not continuous animation or human feel acceptance.", HORIZONTAL_ALIGNMENT_LEFT, 1240, 12, Color("c7d5c5"))
		draw_set_transform(Vector2.ZERO)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var repo := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	var roaming := OS.get_environment("APPDATA").replace("\\", "/")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/momentum-roster-native-") \
			or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Use native rendering and fresh --output=res://.godot/momentum-roster-native-NAME")
		return
	if OS.get_name() == "Windows" and not roaming.to_lower().begins_with(repo.to_lower() + "/.godot/"):
		_fail("Root must isolate APPDATA inside this checkout's .godot before native capture")
		return
	if "--pixel-cast" not in OS.get_cmdline_user_args():
		_fail("This fixture requires the actual --pixel-cast route")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create fresh native checkpoint output")
		return
	for path: String in CAPTURE_SOURCES: source_hashes[path] = FileAccess.get_sha256(path)
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
	game.application_input_active = true
	game.controls_input_guard_frames = 0
	if game.element_audio != null:
		game.element_audio.silence()
		game.element_audio.set_process(false)
		game.element_audio.volume_percent = 0
	await process_frame
	if game.world == null or game.campus_layout == null or game.cartoon_champion_presenter.fullbody_art == null \
			or game.cartoon_champion_presenter.fullbody_art.pixel_pilot == null:
		_fail("Production pixel-cast Wellspring did not initialize")
		return
	if not await _capture_roster(): return
	viewport.size = SIZE
	for id: String in ["joh_haynes", "grimm_bow"]:
		var equipped: String = game._champion_visual_id(game._local_player_state())
		var authority: String = game.world.state_hash()
		if not _inspect(id, equipped): return
		game.character_selection_grid.toggle_portrait()
		if not game.character_selection_grid.portrait_expanded or not await _redraw(): return
		if game.world.state_hash() != authority:
			_fail("Portrait inspection changed authoritative state")
			return
		if not _save_checkpoint(id + "-refined-portrait", "production-portrait", {"selected": id, "equipped": equipped, "read_only": true}): return
	game.character_selection_grid.close_panel()
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		viewport.size = resolution
		for view: Dictionary in MAP_VIEWS:
			if not await _capture_map(view): return
	# The Lodge label abuts a real wall; retain one minimum-resolution check.
	if not await _capture_map({"id": "lodge-wall-clearance", "point": Vector2i(328, 328),
		"scope": "MOVEMENT + CONTROLS / ROUTEKEEPER LODGE label immediately above NorthPracticeWall"}): return
	game.hide()
	presentation_board = CheckpointBoard.new()
	presentation_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(presentation_board)
	if not await _capture_transition_sheets(): return
	if not await _capture_actual_momentum(): return
	for path: String in source_hashes:
		if String(source_hashes[path]).length() != 64 or FileAccess.get_sha256(path) != source_hashes[path]:
			_fail("Capture source changed while native verification was running: " + path)
			return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Cannot save native checkpoint receipt")
		return
	receipt.store_string(JSON.stringify({"status": "passed", "frames": frames, "sources": source_hashes,
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"roster": roster_records, "cases": cases, "simulation_ticks": simulation_records,
		"png_count": frames.size(), "png_bytes": capture_bytes, "physical_input": false,
		"display": {"server": DisplayServer.get_name(), "minimized_root": root.mode == Window.MODE_MINIMIZED,
			"unfocusable": root.unfocusable, "scene_sizes": [[1280, 720], [960, 540]],
			"integer_zoom_sheet_size": [2560, 1440], "image_resizing": false},
		"method": "Real Bootstrap Gallery/map rendering. Gallery is read-only; map placement resets the isolated actor to disclosed collision-valid landmarks. Direction sheets are controlled states. Separate 120Hz SimWorld journeys earn sprint, enter paid slide, gather held jump and release through ordinary commands without injected velocity or action timers. Their still timeline uses production pixel descriptors and actual air lift.",
		"limitations": "No physical input, continuous-video, human readability/feel, multiplayer, performance or casting acceptance. Reused advanced-action poses are not authored cycles. Eight-direction sheets are controlled presenter fixtures, not actual movement execution. Actual-simulation timeline is a clear isolated arena, not a map-route traversal. No saved profile or attunement changes. Root must review every PNG.",
	}, "\t") + "\n")
	receipt.close()
	print("PASS momentum-roster native: ", frames.size(), " PNGs / ", capture_bytes, " bytes; 30-card roster, map landmarks, 120 direction poses and three paid journeys")
	quit(0)


func _capture_roster() -> bool:
	var grid: CharacterSelectionGrid = game.character_selection_grid
	var equipped: String = game._champion_visual_id(game._local_player_state())
	var authority: String = game.world.state_hash()
	if not _inspect("oh_tipi", equipped): return false
	var cells: Array[Vector2i] = grid.model.display_cells()
	if cells.size() != 30 or cells.size() != game.champion_catalog.ordered_champion_ids().size():
		_fail("Native roster expects every current identity on the same 30-card grid")
		return false
	for cell: Vector2i in cells:
		var entry: Dictionary = grid.model.characters(cell.x)[cell.y]
		var rectangle := grid.card_rect(cell.x, cell.y)
		if not CharacterSelectionGrid.PANEL.encloses(rectangle) or grid.cell_at(rectangle.get_center()) != cell:
			_fail("A real roster card is clipped or loses its production hit target")
			return false
		roster_records.append({"id": entry.id, "name": entry.display_name, "size": entry.body_type,
			"display_index": grid.model.display_index(cell.x, cell.y),
			"logical_rect": [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y]})
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		viewport.size = resolution
		if not await _redraw(): return false
		if game.world.state_hash() != authority or grid.model.equipped_id != equipped or grid.model.pending_wire != 0:
			_fail("Native roster inspection changed authority or attunement")
			return false
		if not _save_checkpoint("all-30-roster", "production-gallery", {"selected": "oh_tipi", "equipped": equipped,
			"world_hash_before_and_after": authority, "logical_grid": [6, 5], "menu_scale": game._compendium_scale()}): return false
	return true


func _capture_map(view: Dictionary) -> bool:
	var actor: PlayerState = game.world.player()
	var point: Vector2i = view.point
	if not game.world.collision.can_occupy(point * SimConfig.FIXED_SCALE, MovementTuning.PLAYER_RADIUS):
		_fail("Requested map inspection anchor is not collision-legal: " + String(view.id))
		return false
	actor.reset_for_spawn(point * SimConfig.FIXED_SCALE)
	actor.spawn_protection_ticks = 0
	game.current_position = Vector2(point)
	game.previous_position = Vector2(point)
	game.accumulator_seconds = 0.0
	game._reset_motion_history()
	game.player_camera.clear()
	game.player_camera.advance(Vector2(point), Vector2.ZERO, Vector2.ZERO, DELTA, Vector2(viewport.size),
		Rect2(Vector2.ZERO, Vector2(game.campus_layout.canvas_size)), float(game.campus_layout.reserved_ui_top), true)
	var authority: String = game.world.state_hash()
	if not await _redraw(): return false
	return _save_checkpoint(String(view.id), "production-map", {"setup_actor_point": [point.x, point.y],
		"scope": view.scope, "world_hash_before_and_after": authority, "route_traversal": false})


func _capture_transition_sheets() -> bool:
	var art: RefCounted = game.cartoon_champion_presenter.fullbody_art
	for id: String in BODY_IDS:
		presentation_board.samples.clear()
		presentation_board.timeline = false
		presentation_board.title = id + " / jump > slide > roll > air dodge > walk / eight travel headings A"
		presentation_board.subtitle = "Aim B is three headings clockwise from A. Native 1x body registration; low/air fallbacks honestly reuse held keys."
		var records: Array[Dictionary] = []
		for row: int in TRANSITIONS.size():
			for travel: int in 8:
				var aim := (travel + 3) % 8
				var state := _controlled_state(TRANSITIONS[row], aim, travel)
				var authority := state.canonical_values()
				var frame: Dictionary = art.frame(id, state, 60.0, game.world.config, 0.375)
				if frame.is_empty() or frame.has("mesh") or frame.has("render_mesh") or frame.get("action") != TRANSITIONS[row] \
						or state.canonical_values() != authority:
					_fail("Controlled native transition lost fixed pixels, action or authority")
					return false
				presentation_board.samples.append({"anchor": Vector2(185 + travel * 140, 160 + row * 115),
					"frame": frame, "column": travel, "action": TRANSITIONS[row],
					"label": "A %s / B %s" % [Art.DIRS[travel], Art.DIRS[aim]]})
				records.append(_frame_record(frame, state, id))
		for zoom: int in [1, 2]:
			presentation_board.integer_zoom = zoom
			viewport.size = SIZE * zoom
			if not await _redraw_board(): return false
			if not _save_checkpoint(id + "-transitions-" + str(zoom) + "x", "controlled-direction-sheet",
				{"champion": id, "integer_render_zoom": zoom, "world_lift_applied": false, "poses": records}): return false
	return true


func _capture_actual_momentum() -> bool:
	var art: RefCounted = game.cartoon_champion_presenter.fullbody_art
	presentation_board.samples.clear()
	presentation_board.timeline = true
	presentation_board.integer_zoom = 1
	presentation_board.title = "Actual 120Hz paid simulation / sprint > slide > held gather > released slide jump"
	presentation_board.subtitle = "Three real size profiles. A east / B north. Six sampled instants from 100 steps; no injected velocity, action timers or capability."
	var sample_steps := [44, 50, 51, 62, 63, 78]
	for row: int in BODY_IDS.size():
		var id: String = BODY_IDS[row]
		var sim := SimWorld.new(120, 1, CollisionWorld.new(10_000_000, 10_000_000), "capture-clear-arena", "capture-only")
		var state := sim.player()
		if not sim.is_valid() or not game.champion_catalog.apply_to_player(state, id):
			_fail("Actual simulation fixture could not admit champion: " + id)
			return false
		state.reset_for_spawn(Vector2i(5_000_000, 5_000_000))
		var history := History.new()
		var heights := {1: float(art.pixel_pilot.entries[id].display_height)}
		history.capture_gaits(sim.players, {1: Vector2(state.position_x, state.position_y) / SimConfig.FIXED_SCALE}, heights, DELTA)
		var gathered := false
		var released := false
		var saw_slide := false
		var sprint_paid := 0
		var slide_paid := 0
		var release_paid := 0
		for step: int in 100:
			var held := SimCommand.HELD_SPRINT if step < 45 else (SimCommand.HELD_SLIDE if step < 51 else (SimCommand.HELD_JUMP | SimCommand.HELD_SLIDE if step < 63 else 0))
			var pressed := SimCommand.PRESSED_SLIDE if step == 45 else (SimCommand.PRESSED_JUMP if step == 51 else 0)
			var movement := 1000 if step < 51 else 0
			var stamina := state.stamina
			var command := SimCommand.new(sim.tick, state.entity_id, movement, 0, held, pressed, 0, -1000)
			if not sim.step([command]):
				_fail("Ordinary paid simulation command failed: " + sim.last_error)
				return false
			if step < 45: sprint_paid += maxi(0, stamina - state.stamina)
			if step == 45: slide_paid = stamina - state.stamina
			if step == 63: release_paid = stamina - state.stamina
			saw_slide = saw_slide or state.movement_mode == PlayerState.MovementMode.SLIDE
			gathered = gathered or state.jumpsquat_active
			released = released or (state.is_airborne() and state.hop_mode == PlayerState.MovementMode.SLIDE_JUMP)
			history.capture_gaits(sim.players, {1: Vector2(state.position_x, state.position_y) / SimConfig.FIXED_SCALE}, heights, DELTA)
			var before := state.canonical_values()
			var frame: Dictionary = art.frame(id, state, float(sim.tick) * 0.5, sim.config, history.gait_phase(1))
			if frame.has("mesh") or frame.is_empty() or state.canonical_values() != before:
				_fail("Actual simulation presentation lost fixed pixels or mutated authority")
				return false
			var record := _frame_record(frame, state, id)
			record.merge({"step": step, "tick": sim.tick, "move": [movement, 0], "held": held, "pressed": pressed,
				"stamina_before": stamina, "stamina_after": state.stamina, "world_hash": sim.state_hash()}, true)
			simulation_records.append(record)
			if sample_steps.has(step):
				var column := sample_steps.find(step)
				var jump := JumpPresentation.sample(state, sim.config)
				presentation_board.samples.append({"anchor": Vector2(125 + column * 205, 230 + row * 200), "frame": frame,
					"lift": jump.body_lift_pixels, "label": "t%d / %s" % [sim.tick, frame.action], "row_label": id if column == 0 else "",
					"detail": "v %.1f px/s / h %.1f" % [Vector2(state.velocity_x, state.velocity_y).length() / 1000.0, state.air_height / 1000.0]})
		if not saw_slide or not gathered or not released or sprint_paid <= 0 or slide_paid < MovementTuning.SLIDE_COST or release_paid <= 0:
			_fail("Actual sprint/slide/gather/release positive controls failed: " + id)
			return false
		cases.append({"champion": id, "kind": "actual-paid-simulation", "ticks": 100,
			"sprint_paid": sprint_paid, "slide_entry_paid": slide_paid, "release_paid": release_paid,
			"saw_slide": saw_slide, "saw_gather": gathered, "saw_slide_jump": released})
	viewport.size = SIZE
	if not await _redraw_board(): return false
	return _save_checkpoint("paid-slide-gather-jump-timeline", "actual-simulation-still-timeline",
		{"simulation_hz": 120, "sample_steps": sample_steps, "world_lift_applied": true, "continuous_video": false})


func _controlled_state(action: String, aim: int, travel: int) -> PlayerState:
	var state := PlayerState.new(9600)
	var look: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
	var move: Vector2i = EightDirectionResolver.FIXED_VECTORS[travel]
	state.aim_x = look.x; state.aim_y = look.y
	state.facing_x = look.x; state.facing_y = look.y
	state.velocity_x = move.x * 200; state.velocity_y = move.y * 200
	state.movement_mode = PlayerState.MovementMode.WALK
	match action:
		"slide":
			state.movement_mode = PlayerState.MovementMode.SLIDE
			state.slide_ticks = 12; state.slide_x = move.x; state.slide_y = move.y
		"roll":
			state.movement_mode = PlayerState.MovementMode.ROLL
			state.hop_mode = PlayerState.MovementMode.ROLL; state.air_dodge_ticks = 12
		"jump", "air_dodge":
			state.movement_mode = PlayerState.MovementMode.HOP
			state.hop_mode = PlayerState.MovementMode.HOP; state.hop_ticks = 12
			state.air_height = 24000; state.air_vertical_velocity = 30000
			if action == "air_dodge":
				state.air_dodge_ticks = 12; state.movement_mode = PlayerState.MovementMode.AIR_DODGE
	return state


func _frame_record(frame: Dictionary, state: PlayerState, id: String) -> Dictionary:
	return {"champion": id, "action": frame.get("action"), "frame_id": frame.get("frame_id", ""),
		"aim": frame.get("aim_index"), "travel": frame.get("travel_index"), "pose_facing": frame.get("pose_facing_index", frame.get("aim_index")),
		"phase": frame.get("motion_phase"), "reused_pose": frame.get("rigid_pose_fallback", false), "source_pose": frame.get("source_pose", ""),
		"authored_action_key": frame.get("pixel_action_key", false), "independent_cast_pose": frame.get("independent_cast_pose", false),
		"position": [state.position_x, state.position_y], "velocity": [state.velocity_x, state.velocity_y],
		"air_height": state.air_height, "vertical_velocity": state.air_vertical_velocity, "jumpsquat_ticks": state.jumpsquat_ticks,
		"jumpsquat_active": state.jumpsquat_active, "last_event": state.last_event}


func _redraw_board() -> bool:
	presentation_board.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	return true


func _save_checkpoint(label: String, kind: String, details: Dictionary) -> bool:
	var size := viewport.size
	var leaf := "%s-%dx%d.png" % [label, size.x, size.y]
	var path := output.path_join(leaf)
	var pixels := viewport.get_texture().get_image()
	if frames.size() >= 28 or pixels == null or pixels.get_size() != size or pixels.save_png(path) != OK:
		_fail("Bounded native image capture failed: " + leaf)
		return false
	var saved := FileAccess.open(path, FileAccess.READ)
	if saved == null:
		_fail("Cannot verify saved native image size")
		return false
	capture_bytes += saved.get_length()
	saved.close()
	if capture_bytes > 39 * 1024 * 1024:
		_fail("Evidence exceeded the bounded 39MiB image budget")
		return false
	frames.append({"file": leaf, "sha256": FileAccess.get_sha256(path), "width": size.x, "height": size.y,
		"kind": kind, "details": details})
	return true

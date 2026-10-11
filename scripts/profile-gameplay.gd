extends SceneTree
## Native diagnostic, not a release acceptance test or GPU/presentation timer.
## Example (launch Godot with APPDATA redirected to a fresh diagnostic folder):
## godot --path . --script res://scripts/profile-gameplay.gd -- --no-lan-discovery
##   --profile-user-data=<exact isolated OS.get_user_data_dir()>
##   --profile-output=<fresh absolute report.json> --profile-seconds=10
## Optional: --profile-soak-seconds=120 --profile-screenshots
##   --profile-profiles=low,standard --profile-cases=hearth_idle,garden_middle
##   --profile-width=1280 --profile-height=720 --profile-frame-limit=60
##   --profile-light-observer (interval control without detailed stage/memory sampling)
## Cold means uncached by this process, not a flushed operating-system disk cache.

const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Quality = preload("res://src/presentation/render_quality.gd")
const DEFAULT_CASES := ["hearth_idle", "garden_entry", "garden_middle", "paid_fire_bolt", "paid_all_six_mantle", "movement_boundary", "range_paid_fire"]
const CASES := ["hearth_idle", "garden_entry", "garden_middle", "paid_fire_bolt", "paid_all_six_mantle", "movement_boundary", "range_paid_fire", "paid_fire_bolt_close"]
const READY_TIMEOUT := 60.0

class TimedCourt extends HexCourtPresenter:
	var recording := false
	var samples: Array[float] = []
	var geometry_us := 0
	var bundle_us := 0
	var surface_us := 0
	var region_detail := false
	var prepare_region_us := 0
	var prepare_region_calls := 0
	var accepted_regions := 0
	var max_prepared_regions_per_draw := 0
	var prepared_regions_by_material := {}
	var mirror_product_us := 0
	var mirror_product_calls := 0
	var fire_mark_us := 0
	var fire_mark_calls := 0
	var _regions_this_draw := 0
	var region_draw_samples: Array[Dictionary] = []
	var _materials_this_draw: Dictionary = {}
	var _phases_this_draw: Dictionary = {}
	func draw_ground(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool = true) -> bool:
		if not recording: return super.draw_ground(canvas, court, tick, reduced, draw_district_base)
		var started := Time.get_ticks_usec()
		_regions_this_draw = 0
		if region_detail:
			_materials_this_draw.clear()
			_phases_this_draw.clear()
		var result := super.draw_ground(canvas, court, tick, reduced, draw_district_base)
		max_prepared_regions_per_draw = maxi(max_prepared_regions_per_draw, _regions_this_draw)
		if recording: samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		if recording and region_detail:
			region_draw_samples.append({"sample_index": samples.size() - 1, "render_tick": tick, "process_frame": Engine.get_process_frames(), "regions": _regions_this_draw, "materials": _materials_this_draw.duplicate(), "phases": _phases_this_draw.duplicate()})
		return result
	func _prepare_region(value: Variant, material: String, expected_polygon: PackedVector2Array = PackedVector2Array()) -> Dictionary:
		if not recording or not region_detail: return super._prepare_region(value, material, expected_polygon)
		var started := Time.get_ticks_usec()
		var result := super._prepare_region(value, material, expected_polygon)
		prepare_region_us += Time.get_ticks_usec() - started
		prepare_region_calls += 1
		if not result.is_empty():
			accepted_regions += 1
			_regions_this_draw += 1
			prepared_regions_by_material[material] = int(prepared_regions_by_material.get(material, 0)) + 1
			_materials_this_draw[material] = int(_materials_this_draw.get(material, 0)) + 1
			var phase_key := material + "/" + String(result.get("phase", ""))
			_phases_this_draw[phase_key] = int(_phases_this_draw.get(phase_key, 0)) + 1
		return result
	func _draw_mirror_product(canvas: CanvasItem, regions_by_cell: Dictionary, material: String, tick: float, reduced: bool) -> void:
		if not recording or not region_detail:
			super._draw_mirror_product(canvas, regions_by_cell, material, tick, reduced)
			return
		var started := Time.get_ticks_usec()
		super._draw_mirror_product(canvas, regions_by_cell, material, tick, reduced)
		mirror_product_us += Time.get_ticks_usec() - started
		mirror_product_calls += 1
	func _draw_fire_region_mark(canvas: CanvasItem, polygon: PackedVector2Array, phase: String, dark: Color, base: Color, bright: Color, danger: Color, tick: float, seed: int, reduced: bool) -> void:
		if not recording or not region_detail:
			super._draw_fire_region_mark(canvas, polygon, phase, dark, base, bright, danger, tick, seed, reduced)
			return
		var started := Time.get_ticks_usec()
		super._draw_fire_region_mark(canvas, polygon, phase, dark, base, bright, danger, tick, seed, reduced)
		fire_mark_us += Time.get_ticks_usec() - started
		fire_mark_calls += 1
	func _prepare_court(court: RefCounted, include_empty: bool = true) -> bool:
		if not recording: return super._prepare_court(court, include_empty)
		var started := Time.get_ticks_usec()
		var result := super._prepare_court(court, include_empty)
		if recording: geometry_us += Time.get_ticks_usec() - started
		return result
	func _prepare_frame_bundle(court: RefCounted, tick: float) -> Dictionary:
		if not recording: return super._prepare_frame_bundle(court, tick)
		var started := Time.get_ticks_usec()
		var result := super._prepare_frame_bundle(court, tick)
		if recording: bundle_us += Time.get_ticks_usec() - started
		return result
	func _draw_material_surface(canvas: CanvasItem, material: String, region: Dictionary, style: Dictionary, tick: float, reduced: bool) -> bool:
		if not recording: return super._draw_material_surface(canvas, material, region, style, tick, reduced)
		var started := Time.get_ticks_usec()
		var result := super._draw_material_surface(canvas, material, region, style, tick, reduced)
		if recording: surface_us += Time.get_ticks_usec() - started
		return result

class TimedCampus extends SanctumCampusRenderer:
	var delegate: SanctumCampusRenderer
	var recording := false
	var samples: Array[float] = []
	func draw(canvas: CanvasItem, layout: SanctumCampusLayout, presentation_tick: int, focus_world_position: Vector2 = Vector2(-1000000, -1000000), reduced_effects: bool = false, station_titles: bool = true, visible_world_rect: Rect2 = Rect2(), practice_details: bool = true, court_context: String = "") -> void:
		if not recording:
			delegate.draw(canvas, layout, presentation_tick, focus_world_position, reduced_effects, station_titles, visible_world_rect, practice_details, court_context)
			return
		var started := Time.get_ticks_usec()
		delegate.draw(canvas, layout, presentation_tick, focus_world_position, reduced_effects, station_titles, visible_world_rect, practice_details, court_context)
		if recording: samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	func prepare_terrain_view(visible: Rect2, upload_budget: int = 2) -> bool:
		return delegate.prepare_terrain_view(visible, upload_budget)
	func terrain_ready_for(visible: Rect2) -> bool:
		return delegate.terrain_ready_for(visible)
	func terrain_status() -> Dictionary:
		return delegate.terrain_status()
	func suspend_terrain() -> bool:
		return delegate.suspend_terrain()
	func finish_terrain_shutdown() -> void:
		delegate.finish_terrain_shutdown()
	func prepare_overview() -> bool:
		return delegate.prepare_overview()

class TimedGarden extends "res://src/presentation/element_garden_presenter.gd":
	var recording := false
	var samples: Array[float] = []
	var stages: Array[Dictionary] = []
	func draw_ground(canvas: CanvasItem, entries: Array[Dictionary], reduced: bool) -> void:
		if not recording:
			profile_enabled = false
			super.draw_ground(canvas, entries, reduced)
			return
		var started := Time.get_ticks_usec()
		profile_enabled = recording
		super.draw_ground(canvas, entries, reduced)
		if recording:
			samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
			stages.append(profile_stages_us.duplicate())

class TimedGame extends "res://src/app/bootstrap.gd":
	var recording := false
	var light_observer := false
	var frame_ms: Array[float] = []
	var frame_start_us: Array[int] = []
	var process_ms: Array[float] = []
	var observer_overhead_ms: Array[float] = []
	var draw_ms: Array[float] = []
	var garden_step_ms: Array[float] = []
	var pov_ms: Array[float] = []
	var render_setup_ms: Array[float] = []
	var previous_us := 0
	var casting := false
	var close_fire := false
	var cast_attempt_ticks: Array[int] = []
	var max_cast_records := 0
	var max_ground_parts := 0
	var max_products := 0
	var moving := false
	var next_cast_tick := 0
	var motion_start_tick := 0
	var route: Array[Vector2] = []
	var route_index := 1
	var attempts := 0
	var max_projectiles := 0
	var max_paid_cells := 0
	var max_resident_plots := 0
	var unfocused_frames := 0
	var loading_frames := 0
	var distance_pixels := 0.0
	var tile_crossings := 0
	var last_position := Vector2.ZERO
	var last_tile := Vector2i.ZERO
	var max_static_memory := 0
	var max_texture_memory := 0
	var max_video_memory := 0
	var world_stage_samples: Array[Dictionary] = []
	var draw_stage_samples: Array[Dictionary] = []
	var draw_stage_contexts: Array[Dictionary] = []
	var draw_serial := 0
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		if recording:
			frame_start_us.append(started)
			if previous_us > 0: frame_ms.append(float(started - previous_us) / 1000.0)
			previous_us = started
		# Synthetic paid commands remain repeatable when diagnostic focus changes.
		# Actual window focus is still recorded for every measured frame.
		application_input_active = true
		var tick_before := -1 if world == null else world.tick
		var game_started := Time.get_ticks_usec()
		super._process(delta)
		var game_elapsed := Time.get_ticks_usec() - game_started
		if not recording: return
		process_ms.append(float(game_elapsed) / 1000.0)
		if not get_window().has_focus(): unfocused_frames += 1
		if terrain_loading: loading_frames += 1
		if world != null:
			if not light_observer and world.tick > tick_before:
				world_stage_samples.append({"completed_tick": world.tick - 1, "steps_this_frame": world.tick - tick_before, "last_step_stages_us": world.profile_stages_us.duplicate()})
			max_projectiles = maxi(max_projectiles, world.projectiles.size())
			if not light_observer: max_paid_cells = maxi(max_paid_cells, world.hex_court.occupied_cells().size())
			max_resident_plots = maxi(max_resident_plots, element_garden._resident.size())
			if close_fire and not light_observer:
				max_cast_records = maxi(max_cast_records, world.hex_court.casts.size())
				max_products = maxi(max_products, world.hex_court.products.size())
				var ground_parts := 0
				for record: Dictionary in world.hex_court.casts.values():
					ground_parts += (record.get("ground_parts", {}) as Dictionary).size()
				max_ground_parts = maxi(max_ground_parts, ground_parts)
			var point := _player_position()
			distance_pixels += point.distance_to(last_position)
			last_position = point
			var tile := Vector2i((point / 512.0).floor())
			if tile != last_tile: tile_crossings += 1
			last_tile = tile
		if not light_observer:
			max_static_memory = maxi(max_static_memory, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
			max_texture_memory = maxi(max_texture_memory, int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
			max_video_memory = maxi(max_video_memory, int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
		observer_overhead_ms.append(float(Time.get_ticks_usec() - started - game_elapsed) / 1000.0)
	func _draw() -> void:
		var started := Time.get_ticks_usec()
		draw_serial += 1
		diagnostic_render_profile = recording and not light_observer
		# Bootstrap clears stages only after its no-world/loading early returns.
		# Own the sampling boundary here so an early draw cannot replay the last
		# gameplay frame's timings. Empty stages belong to this actual callback.
		if diagnostic_render_profile: diagnostic_draw_stages_us.clear()
		var draw_phase := "no_world" if world == null else "loading" if terrain_loading else "gameplay"
		super._draw()
		if recording:
			draw_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
			if not light_observer:
				draw_stage_samples.append(diagnostic_draw_stages_us.duplicate())
				draw_stage_contexts.append({"draw_serial": draw_serial, "process_frame": Engine.get_process_frames(), "phase": draw_phase})
	func _update_element_garden() -> void:
		if not recording or light_observer:
			super._update_element_garden()
			return
		var started := Time.get_ticks_usec()
		super._update_element_garden()
		if recording: garden_step_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
	func _draw_pov_mask(origin: Vector2, aim: Vector2, camera_origin: Vector2) -> void:
		if not recording or light_observer:
			super._draw_pov_mask(origin, aim, camera_origin)
			return
		var started := Time.get_ticks_usec()
		super._draw_pov_mask(origin, aim, camera_origin)
		if recording: pov_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
	func _sample_gameplay_command(tick: int, _position: Vector2, _pointer: Vector2, _blocking: bool) -> SimCommand:
		var pressed := 0
		var held := 0
		var direction := Vector2.ZERO
		# Match Bootstrap's finite portable sequence predicate, then submit the
		# ordinary command. No cooldown, recovery, payment or resource is edited.
		var sequence_ready := false
		if casting and close_fire and attempts < 12:
			var actor: PlayerState = _local_player_state()
			sequence_ready = actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(actor.spell_wire_id(1)) == 0
		if casting and ((close_fire and sequence_ready) or (not close_fire and tick >= next_cast_tick)):
			pressed |= SimCommand.SPELL_PRESSED_BITS[0]
			next_cast_tick = tick + 120
			attempts += 1
			if close_fire: cast_attempt_ticks.append(tick)
		if moving and route.size() == 2:
			var point := _player_position()
			if point.distance_to(route[route_index]) < 40.0: route_index = 1 - route_index
			direction = (route[route_index] - point).normalized()
			held |= SimCommand.HELD_SPRINT
			var phase := posmod(tick - motion_start_tick, 180)
			if phase in [12, 30]: pressed |= SimCommand.PRESSED_JUMP
			if phase < 42: held |= SimCommand.HELD_JUMP
			if phase == 100: pressed |= SimCommand.PRESSED_SLIDE
			if phase >= 100 and phase < 126: held |= SimCommand.HELD_SLIDE
			if phase == 145: pressed |= SimCommand.PRESSED_EVADE
		return SimCommand.new(tick, input_router.entity_id, roundi(direction.x * 1000), roundi(direction.y * 1000), held, pressed, 1000, 0, 1736000 if close_fire else -1, 880000 if close_fire else -1)
	func reset_samples() -> void:
		frame_ms.clear()
		frame_start_us.clear()
		process_ms.clear()
		observer_overhead_ms.clear()
		draw_ms.clear()
		garden_step_ms.clear()
		pov_ms.clear()
		render_setup_ms.clear()
		previous_us = 0
		attempts = 0
		cast_attempt_ticks.clear()
		max_cast_records = 0
		max_ground_parts = 0
		max_products = 0
		max_projectiles = 0
		max_paid_cells = 0
		max_resident_plots = 0
		unfocused_frames = 0
		loading_frames = 0
		distance_pixels = 0.0
		tile_crossings = 0
		last_position = _player_position()
		last_tile = Vector2i((last_position / 512.0).floor())
		max_static_memory = 0
		max_texture_memory = 0
		max_video_memory = 0
		world_stage_samples.clear()
		draw_stage_samples.clear()
		draw_stage_contexts.clear()

var game: TimedGame
var garden: TimedGarden
var court: TimedCourt
var campus: TimedCampus
var output_path := ""
var seconds_per_case := 10.0
var soak_seconds := 0.0
var screenshots := false
var light_observer := false
var profiles := PackedStringArray(["standard", "low"])
var selected_cases := PackedStringArray(DEFAULT_CASES)
var frame_limit := 60
var results: Array[Dictionary] = []
var report: Dictionary = {}
var capture: Dictionary = {}
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _option(name: String, fallback: String = "") -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(name + "="): return argument.substr(name.length() + 1)
	return fallback

func _run() -> void:
	output_path = _option("--profile-output")
	var expected_data := _option("--profile-user-data").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual_data := OS.get_user_data_dir().replace("\\", "/").simplify_path().trim_suffix("/")
	if DisplayServer.get_name() == "headless": _fail("A native window is required; headless timing does not qualify gameplay."); return
	if expected_data.is_empty() or expected_data.to_lower() != actual_data.to_lower(): _fail("Pass --profile-user-data matching the fresh isolated engine data directory. Current engine directory: " + actual_data); return
	if output_path.is_empty() or not output_path.is_absolute_path() or FileAccess.file_exists(output_path): _fail("--profile-output must name a fresh absolute JSON path."); return
	if not OS.get_cmdline_user_args().has("--no-lan-discovery"): _fail("Pass --no-lan-discovery to isolate the local benchmark."); return
	seconds_per_case = float(_option("--profile-seconds", "10"))
	soak_seconds = float(_option("--profile-soak-seconds", "0"))
	if not is_finite(seconds_per_case) or seconds_per_case < 1 or seconds_per_case > 600 or not is_finite(soak_seconds) or soak_seconds < 0 or soak_seconds > 3600: _fail("Use 1..600 seconds per diagnostic case and 0..3600 seconds per optional soak."); return
	profiles = _option("--profile-profiles", "standard,low").split(",", false)
	selected_cases = _option("--profile-cases", ",".join(DEFAULT_CASES)).split(",", false)
	for profile: String in profiles:
		if profile not in ["standard", "low"]: _fail("Unknown quality profile: " + profile); return
	for label: String in selected_cases:
		if label not in CASES: _fail("Unknown benchmark case: " + label); return
	if profiles.is_empty() or selected_cases.is_empty(): _fail("Select at least one quality profile and case."); return
	frame_limit = int(_option("--profile-frame-limit", "60"))
	if frame_limit not in [0, 60, 120]: _fail("--profile-frame-limit accepts 0,60,120."); return
	screenshots = OS.get_cmdline_user_args().has("--profile-screenshots")
	light_observer = OS.get_cmdline_user_args().has("--profile-light-observer")
	if DirAccess.make_dir_recursive_absolute(output_path.get_base_dir()) != OK: _fail("Could not create report directory."); return
	root.size = Vector2i(clampi(int(_option("--profile-width", "1280")), 960, 2560), clampi(int(_option("--profile-height", "720")), 540, 1440))
	root.unresizable = true
	root.title = "H.E.X. performance check"
	root.mode = Window.MODE_WINDOWED
	root.visible = true
	# Independent disk provenance is collected outside every game timer. The
	# packaging identity can legitimately lag an in-progress source benchmark.
	var observed_source := _source_snapshot()
	var startup := Time.get_ticks_usec()
	var instance: Node = load("res://scenes/bootstrap/bootstrap.tscn").instantiate()
	instance.set_script(TimedGame)
	game = instance
	game.light_observer = light_observer
	garden = TimedGarden.new()
	game.element_garden_presenter = garden
	court = TimedCourt.new()
	game.hex_court_presenter = court
	root.add_child(game)
	if game.world == null or game.session_transport.mode != SessionTransport.Mode.OFFLINE: _fail("Benchmark startup did not produce an offline world."); return
	game.preference_overrides_are_transient = true
	game.world.profile_enabled = not light_observer
	# Delegate only the main campus call. The existing POV viewport keeps its
	# original renderer/reference and its capture is not mislabelled main draw.
	campus = TimedCampus.new()
	campus.delegate = game.campus_renderer
	campus.illustrated_kit = campus.delegate.illustrated_kit
	campus.natural_kit = campus.delegate.natural_kit
	campus.language = campus.delegate.language
	game.campus_renderer = campus
	RenderingServer.frame_post_draw.connect(_record_render_setup)
	game.player_preferences.reduced_motion = false
	game.player_preferences.frame_limit = frame_limit
	game.player_preferences.render_quality = profiles[0]
	game._apply_performance_preferences()
	root.grab_focus()
	report = {"schema": "hex-gameplay-profile-v1", "started_utc": Time.get_datetime_string_from_system(true),
		"scope": "Instrumented native source runtime. Main-thread elapsed timers can include scheduling/driver waits. Frame-start intervals are not GPU time, physical presentation or input-to-photon latency. Nested timers are not additive. No 60FPS acceptance is inferred.",
		"fixtures": "Fresh120Hz world per independent case, ordinary paid SimCommand casts, no measured-period refill. Direct placement/equip happens before warm measurement. Cold travel uses actual authored menu travel. Focus loss is observed, while deterministic commands continue.",
		"statistics": "Nearest-rank quantiles of raw process-start intervals; short samples do not establish stable tails. Sequential profile order is recorded; repeat in reverse order for comparisons.",
		"observer_mode": "light" if light_observer else "full",
		"observer_policy": "Light mode retains frame/process/draw intervals, tick/endpoints and inexpensive counters; disables per-frame occupied-membership queries, memory monitors, stage dictionaries and nested component timers. Unavailable metrics are null, never inferred maxima. Both modes remain instrumented, not physical-presentation measurements.",
		"process_timer_scope": "Elapsed Bootstrap._process call only; excludes benchmark head/tail observation. Earlier receipts included head bookkeeping. Embedded simulation and nested component timer overhead remains inside this value in full mode.",
		"observer_overhead_scope": "Benchmark _process head and tail, excluding elapsed Bootstrap._process: interval recording, synthetic focus bookkeeping, focus/counters, final-step copies, paid-cell membership and memory monitors when enabled. Excludes draw/render-setup observation and the overhead of timers embedded inside Bootstrap/SimWorld. Includes scheduling waits, not pure CPU cost.",
		"draw_stage_scope": "Full mode clears stage storage immediately before each actual Bootstrap._draw call. main_draw_stages_us and main_draw_contexts align by index with draw_submission_elapsed_ms. Each context records a monotonic callback serial, process frame and entry phase. Loading/no-world callbacks have current empty stages, counted as zero for any stage observed elsewhere in that case; full draw elapsed time remains measured. No categories are invented if the entire case has no gameplay stages. Earlier receipts could repeat stale gameplay stage dictionaries during loading; their cold stage statistics are not valid.",
		"engine": Engine.get_version_info(), "debug_build": OS.is_debug_build(), "executable": OS.get_executable_path(),
		"renderer": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"screen_id": DisplayServer.window_get_current_screen(root.get_window_id()),
		"window_vsync_mode": DisplayServer.window_get_vsync_mode(root.get_window_id()),
		"screen_size": _v(DisplayServer.screen_get_size(DisplayServer.window_get_current_screen(root.get_window_id()))), "screen_refresh_hz": DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen(root.get_window_id())), "window_size": _v(root.size),
		"user_data": actual_data, "profile_script_sha256": FileAccess.get_sha256(get_script().resource_path),
		"manifest": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)), "manifest_note": "Generated runtime identity is recorded here; exact source-to-manifest binding is checked by the separate packaging gate.",
		"observed_source_before": observed_source,
		"observed_source_scope": "Independent raw-byte filesystem hashes of project.godot, this benchmark, src/*.gd, scenes/*.tscn and *.tres, content/*.json except the generated identity, and assets/shaders/*.gdshader (recursive). Sorted path<TAB>SHA256<LF> records are SHA256 hashed. Start/end snapshots detect source drift; they do not hash imported textures, certify a pack, or prove code was not edited and restored between snapshots. Source reading occurs outside measured intervals and may warm OS file cache.",
		"protocol": SimConfig.PROTOCOL_VERSION, "tick_rate": game.tick_rate, "frame_limit": frame_limit, "profiles": profiles, "case_seconds": seconds_per_case, "soak_seconds": soak_seconds,
		"startup_synchronous_ms": float(Time.get_ticks_usec() - startup) / 1000.0, "complete": false, "results": results}
	_begin("startup_arrival", profiles[0], "cold_process_cache")
	var ready := await _wait_ready()
	if not _end(ready, {"initial_startup": true}): return
	if not ready: _fail("Startup terrain did not become ready."); return
	for profile: String in profiles:
		game.player_preferences.render_quality = profile
		game._apply_performance_preferences()
		for label: String in selected_cases:
			if not await _run_case(label, profile, seconds_per_case): return
		if soak_seconds > 0:
			if not await _run_case("garden_middle", profile, soak_seconds, "garden_soak"): return
	game.casting = false
	game.moving = false
	report.observed_source_after = _source_snapshot()
	report.observed_source_unchanged = bool(observed_source.ok) and bool(report.observed_source_after.ok) and String(observed_source.sha256) == String(report.observed_source_after.sha256)
	report.complete = true
	if not _write_report(output_path): return
	print("HEX_GAMEPLAY_PROFILE_COMPLETE ", output_path)
	game.queue_free()
	await process_frame
	quit(0)

func _run_case(label: String, profile: String, duration: float, result_label: String = "") -> bool:
	game.casting = false
	game.close_fire = false
	game.moving = false
	var original_pointer := game.capture_pointer_world
	game.element_garden.clear()
	if not game._start_match_world(120): _fail("Fresh world failed before " + label); return false
	game.world.profile_enabled = not light_observer
	game.player_camera.clear()
	var fixture := {"source_case": label, "fresh_world": true, "fixture_prepare_ms": 0.0}
	var started := Time.get_ticks_usec()
	if label == "paid_fire_bolt_close":
		if not _place(Vector2(1536, 880)): _fail("Close Fire Hearth placement refused."); return false
		game.capture_pointer_world = Vector2i(1736, 880)
	if label == "range_paid_fire":
		if not game.element_expansion.activate("expansion-range"): _fail("Ordinary Range entry failed."); return false
		game.element_expansion.panel.close()
	elif label in ["garden_entry", "garden_middle"]:
		# Include admission/preparation in a separate transition record, never hide
		# it in a warm gameplay claim. Later visits may reuse retained terrain.
		_begin(label + "_arrival", profile, "travel_process_cache_state_recorded")
		if not game.local_navigation.travel("element-garden"): _fail("Authored Element Garden fast travel refused."); return false
		if label == "garden_middle":
			var plots: Array[Dictionary] = game.element_garden.plots()
			var bounds := Rect2(plots[0].center, Vector2.ZERO)
			for plot: Dictionary in plots: bounds = bounds.expand(plot.center)
			var nearest: Vector2 = plots[0].center
			for plot: Dictionary in plots:
				if Vector2(plot.center).distance_squared_to(bounds.get_center()) < nearest.distance_squared_to(bounds.get_center()): nearest = plot.center
			if not _place(nearest): _fail("Validated Garden midpoint placement refused."); return false
		var ready := await _wait_ready()
		if not _end(ready, {"authored_travel": "element-garden", "additional_midpoint_placement": label == "garden_middle"}): return false
		if not ready: _fail("Garden arrival did not become ready."); return false
	elif label == "movement_boundary":
		game.route = _movement_route()
		if game.route.size() != 2 or not _place(game.route[0]): _fail("No clear cross-tile movement route found."); return false
		fixture["route"] = [_v(game.route[0]), _v(game.route[1])]
		game.route_index = 1
	if label in ["paid_fire_bolt", "paid_all_six_mantle", "range_paid_fire", "paid_fire_bolt_close"]:
		var wire := Mixtures.wire_for(63 if label == "paid_all_six_mantle" else 2, "mantle" if label == "paid_all_six_mantle" else "bolt")
		if not game._local_player_state().place_proven_spell(0, wire): _fail("Ordinary runtime slot equip failed."); return false
		fixture["spell_wire"] = wire
		if label == "paid_fire_bolt_close":
			fixture["cast_policy"] = "Twelve finite slot-1 attempts at the first tick with no pending cast, no cast recovery and zero spell-owned cooldown; ordinary paid admission, no refill. Same readiness predicate and 200px cursor as the portable capture sequence. Warm source instrumentation, not identical cold-start sampling."
			fixture["finite_attempt_limit"] = 12
			fixture["target_world_px"] = [1736, 880]
			fixture["target_distance_px"] = 200
			fixture["actor_world_px"] = [1536, 880]
			fixture["resource_refill"] = false
			fixture["region_observation_scope"] = "Full observer only: inclusive region/mirror/fire-mark timings and counts; nested timers are not additive (mirror includes fire marks). Extra timers/counters have overhead. Cache counters are unmeasured endpoints. Counts are prepared visible region records, not unique occupied cells."
		else:
			fixture["cast_interval_ticks"] = 120
	fixture.fixture_prepare_ms = float(Time.get_ticks_usec() - started) / 1000.0
	game.world.profile_enabled = not light_observer
	if not await _wait_ready(): _fail("Warm case readiness timed out: " + label); return false
	await _wait_seconds(1.0)
	game.next_cast_tick = game.world.tick + 1
	game.motion_start_tick = game.world.tick
	game.casting = label in ["paid_fire_bolt", "paid_all_six_mantle", "range_paid_fire", "paid_fire_bolt_close"]
	game.close_fire = label == "paid_fire_bolt_close"
	game.moving = label == "movement_boundary"
	_begin(label if result_label.is_empty() else result_label, profile, "warm")
	await _wait_seconds(duration)
	await RenderingServer.frame_post_draw
	if not _end(true, fixture): return false
	game.casting = false
	game.moving = false
	if screenshots:
		var shot_path := output_path.get_basename() + "-" + profile + "-" + (label if result_label.is_empty() else result_label) + ".png"
		var screenshot_error := root.get_texture().get_image().save_png(shot_path)
		results[-1]["screenshot"] = shot_path if screenshot_error == OK else "capture_failed_%d" % screenshot_error
		if not _write_report(output_path + ".partial.json"): return false
	game.capture_pointer_world = original_pointer
	game.close_fire = false
	return true

func _place(point: Vector2) -> bool:
	var actor: PlayerState = game._local_player_state()
	var fixed := Vector2i((point * 1000.0).round())
	if not game.world.collision.can_occupy(fixed, actor.radius): return false
	actor.position_x = fixed.x
	actor.position_y = fixed.y
	actor.velocity_x = 0
	actor.velocity_y = 0
	game.current_position = point
	game.previous_position = point
	game.accumulator_seconds = 0.0
	game._reset_motion_history()
	game.player_camera.clear()
	return true

func _movement_route() -> Array[Vector2]:
	var actor: PlayerState = game._local_player_state()
	var candidates: Array[Vector2] = [game._player_position()]
	for row: Dictionary in game.campus_layout.travel_destinations(): candidates.append(Vector2(float(row.position[0]), float(row.position[1])))
	for center: Vector2 in candidates:
		for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
			var first := center - direction * 300.0
			var second := center + direction * 300.0
			var start := Vector2i(first * 1000.0)
			var finish := Vector2i(second * 1000.0)
			if game.world.collision.can_occupy(start, actor.radius) and game.world.collision.can_occupy(finish, actor.radius) and ContinuousContact.wall_contact(start, finish, actor.radius, game.world.collision).is_empty():
				var route: Array[Vector2] = [first, second]
				return route
	return []

func _wait_ready() -> bool:
	var start := Time.get_ticks_usec()
	var stable := 0
	while float(Time.get_ticks_usec() - start) / 1000000.0 < READY_TIMEOUT:
		await process_frame
		var origin: Vector2 = game._camera_origin(game._camera_focus_position(game.current_position))
		# canvas_items stretching can make the native window larger than the
		# gameplay viewport (notably in tiling compositors). Match the renderer's
		# world view instead of waiting for terrain it never requested.
		var visible := Rect2(origin, game.get_viewport_rect().size / game._camera_zoom_scale())
		var terrain_ready: bool = game._is_hex_practice() or game.campus_renderer.terrain_ready_for(SanctumCampusRenderer.terrain_preparation_rect(visible))
		var backdrop_ready: bool = game._is_hex_practice() or game.pov_terrain_backdrop.ready_for(visible)
		if not game.terrain_loading and terrain_ready and backdrop_ready and game._character_pages_ready:
			stable += 1
			if stable >= 3: return true
		else: stable = 0
		if not game.terrain_loading_error.is_empty(): return false
	return false

func _wait_seconds(duration: float) -> void:
	var started := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started) / 1000000.0 < duration: await process_frame

func _begin(label: String, profile: String, temperature: String) -> void:
	game.reset_samples()
	garden.samples.clear()
	garden.stages.clear()
	court.samples.clear()
	court.geometry_us = 0
	court.bundle_us = 0
	court.surface_us = 0
	court.region_detail = label == "paid_fire_bolt_close"
	court.prepare_region_us = 0
	court.prepare_region_calls = 0
	court.accepted_regions = 0
	court.max_prepared_regions_per_draw = 0
	court.prepared_regions_by_material.clear()
	court.region_draw_samples.clear()
	court.mirror_product_us = 0
	court.mirror_product_calls = 0
	court.fire_mark_us = 0
	court.fire_mark_calls = 0
	campus.samples.clear()
	var memory_before := _memory_endpoint()
	var paid_cells_before: int = game.world.hex_court.occupied_cells().size()
	capture = {"label": label, "quality": profile, "temperature": temperature, "start_us": Time.get_ticks_usec(), "tick_before": game.world.tick,
		"paid_before": int(game.world.hex_court.metrics.matter_paid), "admitted_before": int(game.world.hex_court.metrics.admitted), "refused_before": int(game.world.hex_court.metrics.refused), "dropped_before": game.dropped_time_seconds, "clamped_before": game.clamped_frame_time_seconds,
		"court_cache_before": {"geometry": court.geometry_cache_stats(), "outline": court.outline_cache_stats(), "surface": court.material_surface.stats()},
		"terrain_before": game.campus_renderer.terrain_status(), "position_before": _v(game._player_position()), "flux_before": game._local_player_state().flux,
		"memory_before": memory_before, "paid_cells_before": paid_cells_before}
	game.recording = true
	garden.recording = not light_observer
	court.recording = not light_observer
	campus.recording = not light_observer

func _end(ready: bool, fixture: Dictionary) -> bool:
	game.recording = false
	garden.recording = false
	court.recording = false
	campus.recording = false
	var elapsed := float(Time.get_ticks_usec() - int(capture.start_us)) / 1000000.0
	var row := {"label": capture.label, "quality": capture.quality, "temperature": capture.temperature, "ready": ready, "wall_seconds": elapsed,
		"observer_mode": "light" if light_observer else "full",
		"frame_interval_ms": _stats(game.frame_ms), "process_elapsed_ms": _stats(game.process_ms), "draw_submission_elapsed_ms": _stats(game.draw_ms),
		"observer_overhead_elapsed_ms": _stats(game.observer_overhead_ms),
		"garden_draw_elapsed_ms": _stats(garden.samples), "garden_step_elapsed_ms": _stats(game.garden_step_ms), "pov_elapsed_ms": _stats(game.pov_ms),
		"main_court_draw_elapsed_ms": _stats(court.samples), "main_campus_draw_elapsed_ms": _stats(campus.samples),
		"engine_render_setup_cpu_ms": _stats(game.render_setup_ms),
		"main_court_components_total_us": {"geometry": court.geometry_us, "bundle": court.bundle_us, "surface": court.surface_us, "draw_count": court.samples.size()},
		"world_stage_sample_scope": "One final completed fixed step per rendered process frame; not every step or a sum across catch-up steps. Includes the stage timing overhead and may undersample rare earlier steps.",
		"last_fixed_step_stage_stats_ms": _world_stage_stats(game.world_stage_samples),
		"main_draw_stage_stats_ms": _stage_stats(game.draw_stage_samples), "garden_stage_stats_ms": _stage_stats(garden.stages),
		"raw": {"frame_start_us": game.frame_start_us.duplicate(), "frame_interval_ms": game.frame_ms.duplicate(), "process_elapsed_ms": game.process_ms.duplicate(), "draw_submission_elapsed_ms": game.draw_ms.duplicate(), "garden_draw_elapsed_ms": garden.samples.duplicate(), "garden_step_elapsed_ms": game.garden_step_ms.duplicate(), "pov_elapsed_ms": game.pov_ms.duplicate()},
		"ticks_advanced": game.world.tick - int(capture.tick_before), "ticks_per_wall_second": float(game.world.tick - int(capture.tick_before)) / maxf(elapsed, 0.000001),
		"dropped_accumulator_seconds": game.dropped_time_seconds - float(capture.dropped_before), "clamped_delta_seconds": game.clamped_frame_time_seconds - float(capture.clamped_before),
		"cast_attempts": game.attempts, "matter_paid_delta": int(game.world.hex_court.metrics.matter_paid) - int(capture.paid_before),
		"max_projectiles": game.max_projectiles, "max_paid_cells": game.max_paid_cells, "max_resident_plots": game.max_resident_plots,
		"paid_cells_endpoints": {"before": capture.paid_cells_before, "after": game.world.hex_court.occupied_cells().size()},
		"flux_before": capture.flux_before, "flux_after": game._local_player_state().flux, "champion_wire": game._local_player_state().champion_wire_id,
		"position_before": capture.position_before, "position_after": _v(game._player_position()), "distance_pixels": game.distance_pixels, "terrain_tile_crossings": game.tile_crossings,
		"terrain_before": capture.terrain_before, "terrain_after": game.campus_renderer.terrain_status(), "terrain_loading_frames": game.loading_frames,
		"window_focus_end": root.has_focus(), "unfocused_frames": game.unfocused_frames, "window_size": _v(root.size), "world_map": game.world.map_id,
		"memory_max_bytes": {"static": game.max_static_memory, "textures": game.max_texture_memory, "video": game.max_video_memory},
		"memory_endpoint_bytes": {"before": capture.memory_before, "after": _memory_endpoint()},
		"render_last": {"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)},
		"fixture": fixture}
	row.raw["main_court_draw_elapsed_ms"] = court.samples.duplicate()
	row.raw["observer_overhead_elapsed_ms"] = game.observer_overhead_ms.duplicate()
	row.raw["main_campus_draw_elapsed_ms"] = campus.samples.duplicate()
	row.raw["last_fixed_step_stages"] = game.world_stage_samples.duplicate(true)
	row.raw["engine_render_setup_cpu_ms"] = game.render_setup_ms.duplicate()
	row.raw["main_draw_stages_us"] = game.draw_stage_samples.duplicate(true)
	row.raw["main_draw_contexts"] = game.draw_stage_contexts.duplicate(true)
	row.raw["garden_stages_us"] = garden.stages.duplicate(true)
	if capture.label == "paid_fire_bolt_close":
		row["cast_attempt_ticks"] = game.cast_attempt_ticks.duplicate()
		row["admitted_casts_delta"] = int(game.world.hex_court.metrics.admitted) - int(capture.admitted_before)
		row["refused_casts_delta"] = int(game.world.hex_court.metrics.refused) - int(capture.refused_before)
		row["close_fire_observation"] = null if light_observer else {"max_cast_records": game.max_cast_records, "max_ground_parts": game.max_ground_parts, "max_products": game.max_products, "prepare_region_inclusive_us": court.prepare_region_us, "prepare_region_calls": court.prepare_region_calls, "accepted_prepared_regions": court.accepted_regions, "max_prepared_regions_per_draw": court.max_prepared_regions_per_draw, "prepared_regions_by_material": court.prepared_regions_by_material.duplicate(), "per_draw_regions": court.region_draw_samples.duplicate(true), "mirror_product_inclusive_us": court.mirror_product_us, "mirror_product_calls": court.mirror_product_calls, "fire_mark_inclusive_us": court.fire_mark_us, "fire_mark_calls": court.fire_mark_calls, "cache_before": capture.court_cache_before, "cache_after": {"geometry": court.geometry_cache_stats(), "outline": court.outline_cache_stats(), "surface": court.material_surface.stats()}}
	row["unavailable_metrics"] = []
	if light_observer:
		for metric: String in ["max_paid_cells", "memory_max_bytes", "garden_draw_elapsed_ms", "garden_step_elapsed_ms", "pov_elapsed_ms", "main_court_draw_elapsed_ms", "main_campus_draw_elapsed_ms", "main_court_components_total_us", "last_fixed_step_stage_stats_ms", "main_draw_stage_stats_ms", "garden_stage_stats_ms", "engine_render_setup_cpu_ms"]:
			row[metric] = null
			row.unavailable_metrics.append(metric)
		for metric: String in ["garden_draw_elapsed_ms", "garden_step_elapsed_ms", "pov_elapsed_ms", "main_court_draw_elapsed_ms", "main_campus_draw_elapsed_ms", "last_fixed_step_stages", "main_draw_stages_us", "main_draw_contexts", "garden_stages_us", "engine_render_setup_cpu_ms"]:
			row.raw[metric] = null
	results.append(row)
	if not _write_report(output_path + ".partial.json"): return false
	var summary := row.duplicate()
	summary.erase("raw")
	print("HEX_GAMEPLAY_PROFILE_CASE ", JSON.stringify(summary))
	return true

static func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	var counts := {"over_20ms": 0, "over_33_3ms": 0, "over_50ms": 0, "over_100ms": 0}
	for value: float in values:
		total += value
		if value > 20.0: counts.over_20ms += 1
		if value > 33.3: counts.over_33_3ms += 1
		if value > 50.0: counts.over_50ms += 1
		if value > 100.0: counts.over_100ms += 1
	return {"count": values.size(), "mean": total / values.size(), "p50": sorted[maxi(0, ceili(sorted.size() * 0.50) - 1)], "p95": sorted[maxi(0, ceili(sorted.size() * 0.95) - 1)], "p99": sorted[maxi(0, ceili(sorted.size() * 0.99) - 1)], "max": sorted[-1], "threshold_counts": counts}

static func _v(value: Variant) -> Array:
	return [value.x, value.y]

static func _memory_endpoint() -> Dictionary:
	return {"static": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"textures": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"video": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))}

func _record_render_setup() -> void:
	# Godot's CPU render-setup monitor, sampled after frame submission. This is
	# separate from our draw callbacks and does not report GPU execution time.
	if game != null and game.recording and not light_observer: game.render_setup_ms.append(RenderingServer.get_frame_setup_time_cpu())

static func _world_stage_stats(rows: Array[Dictionary]) -> Dictionary:
	var stages: Array[Dictionary] = []
	for row: Dictionary in rows: stages.append(row.last_step_stages_us)
	return _stage_stats(stages)

static func _stage_stats(rows: Array[Dictionary]) -> Dictionary:
	var values := {}
	for row: Dictionary in rows:
		for label: String in row:
			if not values.has(label):
				var samples: Array[float] = []
				values[label] = samples
	# Optional stages that did no work count as zero in the full-frame mean.
	# Otherwise a rare warning cue's mean would describe only its active draws.
	for row: Dictionary in rows:
		for label: String in values: values[label].append(float(row.get(label, 0)) / 1000.0)
	var result := {}
	for label: String in values: result[label] = _stats(values[label])
	return result

static func _source_snapshot() -> Dictionary:
	var paths: Array[String] = ["res://project.godot", "res://scripts/profile-gameplay.gd"]
	var errors: Array[String] = []
	_collect_source_paths("res://src", ["gd"], paths, errors)
	_collect_source_paths("res://scenes", ["tscn", "tres"], paths, errors)
	_collect_source_paths("res://content", ["json"], paths, errors)
	_collect_source_paths("res://assets/shaders", ["gdshader"], paths, errors)
	paths.sort()
	var records: Array[Dictionary] = []
	var canonical := ""
	for path: String in paths:
		if path == RuntimeBuildIdentity.MANIFEST_PATH: continue
		var digest := FileAccess.get_sha256(path)
		if digest.length() != 64: errors.append(path)
		records.append({"path": path, "sha256": digest})
		canonical += path + "\t" + digest + "\n"
	return {"ok": errors.is_empty(), "sha256": canonical.sha256_text() if errors.is_empty() else "",
		"count": records.size(), "files": records, "unreadable_paths": errors,
		"observed_utc": Time.get_datetime_string_from_system(true)}

static func _collect_source_paths(directory: String, extensions: Array[String], paths: Array[String], errors: Array[String]) -> void:
	var access := DirAccess.open(directory)
	if access == null:
		errors.append(directory)
		return
	for file_name: String in access.get_files():
		if file_name.get_extension() in extensions: paths.append(directory.path_join(file_name))
	for child: String in access.get_directories():
		if not child.begins_with("."): _collect_source_paths(directory.path_join(child), extensions, paths, errors)

func _write_report(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return _report_io_failure("Could not open benchmark receipt: " + path)
	var serialized := JSON.stringify(report, "\t")
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return _report_io_failure("Could not flush benchmark receipt: " + path)
	# Outside captured intervals. A success marker requires the complete text to
	# be readable, not merely that opening its destination succeeded.
	if FileAccess.get_file_as_string(path) != serialized:
		return _report_io_failure("Benchmark receipt read-back differed: " + path)
	return true

func _report_io_failure(message: String) -> bool:
	failed = true
	if not report.is_empty():
		report.complete = false
		report["error"] = message
	push_error(message)
	# Do not recursively try to report a failure through the same failed output.
	quit(1)
	return false

func _fail(message: String) -> void:
	failed = true
	push_error(message)
	if not report.is_empty():
		report["error"] = message
		report.complete = false
		_write_report(output_path + ".partial.json")
	quit(1)

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
##   --profile-viewport-render-timing (opt-in last-engine CPU/GPU readings; full only)
##   --profile-all-fixed-steps (opt-in completed-stage totals across catch-up; full only)
##   --profile-wait-for-foreground (bounded manual arm before game instantiation)
## Cold means uncached by this process, not a flushed operating-system disk cache.

const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Quality = preload("res://src/presentation/render_quality.gd")
const DEFAULT_CASES := ["hearth_idle", "garden_entry", "garden_middle", "paid_fire_bolt", "paid_all_six_mantle", "movement_boundary", "range_paid_fire"]
const CASES := ["hearth_idle", "garden_entry", "garden_middle", "paid_fire_bolt", "paid_all_six_mantle", "movement_boundary", "range_paid_fire", "paid_fire_bolt_close", "paid_fire_bolt_sustained", "paid_all_six_mantle_sustained"]
const READY_TIMEOUT := 60.0

class ObservationBudget extends RefCounted:
	# A record group is one callback and its aligned scalar/stage/context arrays.
	# Both observer modes fail closed on overflow; there is no silent decimation.
	const CASE_STREAM_LIMIT := 12000
	const RUN_GROUP_LIMIT := 120000
	const STREAMS := [&"process", &"draw", &"court", &"campus", &"garden", &"garden_step", &"terrain", &"pov", &"render_setup", &"cast_attempt"]
	var case_counts: Dictionary = {}
	var run_counts: Dictionary = {}
	var run_groups := 0
	var overflow := false
	var overflow_stream := ""
	func begin_case() -> void:
		case_counts.clear()
	func admit(stream: StringName) -> bool:
		if overflow: return false
		if stream not in STREAMS or int(case_counts.get(stream, 0)) >= CASE_STREAM_LIMIT or run_groups >= RUN_GROUP_LIMIT:
			overflow = true
			overflow_stream = String(stream)
			return false
		case_counts[stream] = int(case_counts.get(stream, 0)) + 1
		run_counts[stream] = int(run_counts.get(stream, 0)) + 1
		run_groups += 1
		return true
	func snapshot() -> Dictionary:
		return {"case_stream_limit": CASE_STREAM_LIMIT, "run_group_limit": RUN_GROUP_LIMIT, "case_counts": case_counts.duplicate(), "run_counts": run_counts.duplicate(), "run_groups": run_groups, "overflow": overflow, "overflow_stream": overflow_stream}

class TimedCourt extends HexCourtPresenter:
	var recording := false
	var observation_budget: ObservationBudget
	var samples: Array[float] = []
	var preparation_samples: Array[Dictionary] = []
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
		if not recording or not observation_budget.admit(&"court"): return super.draw_ground(canvas, court, tick, reduced, draw_district_base)
		var started := Time.get_ticks_usec()
		var geometry_before := geometry_us
		var bundle_before := bundle_us
		_regions_this_draw = 0
		if region_detail:
			_materials_this_draw.clear()
			_phases_this_draw.clear()
		var result := super.draw_ground(canvas, court, tick, reduced, draw_district_base)
		max_prepared_regions_per_draw = maxi(max_prepared_regions_per_draw, _regions_this_draw)
		var elapsed := Time.get_ticks_usec() - started
		if recording:
			samples.append(float(elapsed) / 1000.0)
			preparation_samples.append({"geometry": geometry_us - geometry_before, "bundle": bundle_us - bundle_before, "drawing_and_other": maxi(0, elapsed - (geometry_us - geometry_before) - (bundle_us - bundle_before))})
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
	var observation_budget: ObservationBudget
	var samples: Array[float] = []
	func retained_source() -> SanctumCampusRenderer:
		return delegate
	func begin_terrain_profile(enabled: bool) -> void:
		if delegate.illustrated_kit == null or delegate.illustrated_kit.terrain_stream == null: return
		delegate.illustrated_kit.terrain_stream.profile_enabled = enabled
		delegate.illustrated_kit.terrain_stream.reset_profile()
	func end_terrain_profile() -> void:
		if delegate.illustrated_kit != null and delegate.illustrated_kit.terrain_stream != null:
			delegate.illustrated_kit.terrain_stream.profile_enabled = false
	func draw(canvas: CanvasItem, layout: SanctumCampusLayout, presentation_tick: int, focus_world_position: Vector2 = Vector2(-1000000, -1000000), reduced_effects: bool = false, station_titles: bool = true, visible_world_rect: Rect2 = Rect2(), practice_details: bool = true, court_context: String = "") -> void:
		if not recording or not observation_budget.admit(&"campus"):
			delegate.draw(canvas, layout, presentation_tick, focus_world_position, reduced_effects, station_titles, visible_world_rect, practice_details, court_context)
			return
		var started := Time.get_ticks_usec()
		delegate.draw(canvas, layout, presentation_tick, focus_world_position, reduced_effects, station_titles, visible_world_rect, practice_details, court_context)
		if recording: samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	func prepare_terrain_view(visible: Rect2, upload_budget: int = 2) -> bool:
		return delegate.prepare_terrain_view(visible, upload_budget)
	func terrain_ready_for(visible: Rect2) -> bool:
		return delegate.terrain_ready_for(visible)
	func prefetch_terrain_view(visible: Rect2) -> void:
		delegate.prefetch_terrain_view(visible)
	func clear_terrain_prefetch() -> void:
		delegate.clear_terrain_prefetch()
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
	var observation_budget: ObservationBudget
	var samples: Array[float] = []
	var stages: Array[Dictionary] = []
	func draw_ground(canvas: CanvasItem, entries: Array[Dictionary], reduced: bool) -> void:
		if not recording or not observation_budget.admit(&"garden"):
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
	var observation_budget: ObservationBudget
	var light_observer := false
	var frame_ms: Array[float] = []
	var frame_start_us: Array[int] = []
	var frame_activity: Array[String] = []
	var previous_activity := "idle"
	var process_ms: Array[float] = []
	var observer_overhead_ms: Array[float] = []
	var draw_ms: Array[float] = []
	var garden_step_ms: Array[float] = []
	var pov_ms: Array[float] = []
	var render_setup_ms: Array[float] = []
	var terrain_prepare_ms: Array[float] = []
	var retained_prepare_us := 0
	var retained_prepare_calls := 0
	var previous_us := 0
	var casting := false
	var close_fire := false
	var sustained := false
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
	var area_loading_frames := 0
	var garden_arrival_loading_frames := 0
	var expected_window_size := Vector2i.ZERO
	var viewport_mismatch_frames := 0
	var distance_pixels := 0.0
	var tile_crossings := 0
	var last_position := Vector2.ZERO
	var last_tile := Vector2i.ZERO
	var max_static_memory := 0
	var max_texture_memory := 0
	var max_video_memory := 0
	var world_stage_samples: Array[Dictionary] = []
	var all_fixed_steps := false
	var all_fixed_step_samples: Array[Dictionary] = []
	var draw_stage_samples: Array[Dictionary] = []
	var draw_stage_contexts: Array[Dictionary] = []
	var draw_serial := 0
	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		var observe_frame := recording and observation_budget.admit(&"process")
		# Retained layers prepare in _process and draw separately from Bootstrap.
		# Set this frame's observer policy before that preparation, not one draw late.
		diagnostic_render_profile = observe_frame and not light_observer
		if observe_frame:
			frame_start_us.append(started)
			if previous_us > 0:
				frame_ms.append(float(started - previous_us) / 1000.0)
				frame_activity.append(previous_activity)
			previous_us = started
		# Synthetic paid commands remain repeatable when diagnostic focus changes.
		# Actual window focus is still recorded for every measured frame.
		application_input_active = true
		var tick_before := -1 if world == null else world.tick
		var completed_before: Dictionary = {}
		if observe_frame and all_fixed_steps and not light_observer and world != null:
			completed_before = world.profile_cumulative_snapshot()
		var game_started := Time.get_ticks_usec()
		super._process(delta)
		var game_elapsed := Time.get_ticks_usec() - game_started
		if not observe_frame: return
		process_ms.append(float(game_elapsed) / 1000.0)
		if all_fixed_steps and not light_observer:
			var completed_after: Dictionary = {} if world == null else world.profile_cumulative_snapshot()
			all_fixed_step_samples.append({"process_index": process_ms.size() - 1,
				"process_frame": Engine.get_process_frames(), "process_started_us": game_started,
				"process_elapsed_us": game_elapsed, "before": completed_before, "after": completed_after,
				"delta": completed_stage_delta(completed_before, completed_after, game_elapsed)})
		if not get_window().has_focus(): unfocused_frames += 1
		if terrain_loading: loading_frames += 1
		if _area_loading(): area_loading_frames += 1
		if element_garden_arrival_pending: garden_arrival_loading_frames += 1
		if get_window().size != expected_window_size: viewport_mismatch_frames += 1
		previous_activity = "loading" if _area_loading() else "post_effect_idle" if attempts > 0 else "idle"
		if world != null:
			if not light_observer and world.tick > tick_before:
				world_stage_samples.append({"completed_tick": world.tick - 1, "steps_this_frame": world.tick - tick_before, "last_step_stages_us": world.profile_stages_us.duplicate()})
			max_projectiles = maxi(max_projectiles, world.projectiles.size())
			if not light_observer:
				var paid_cells: int = world.hex_court.occupied_cells().size()
				max_paid_cells = maxi(max_paid_cells, paid_cells)
				if not _area_loading() and paid_cells > 0: previous_activity = "paid_ground"
			if not _area_loading() and (not world.projectiles.is_empty() or _local_player_state().pending_cast_wire_id != 0): previous_activity = "cast_or_projectile"
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
		var observe_draw := recording and observation_budget.admit(&"draw")
		diagnostic_render_profile = observe_draw and not light_observer
		# Bootstrap clears stages only after its no-world/loading early returns.
		# Own the sampling boundary here so an early draw cannot replay the last
		# gameplay frame's timings. Empty stages belong to this actual callback.
		if diagnostic_render_profile: diagnostic_draw_stages_us.clear()
		var draw_phase := "no_world" if world == null else "loading" if _area_loading() else "gameplay"
		super._draw()
		if observe_draw:
			draw_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
			if not light_observer:
				draw_stage_samples.append(diagnostic_draw_stages_us.duplicate())
				draw_stage_contexts.append({"draw_serial": draw_serial, "process_frame": Engine.get_process_frames(), "phase": draw_phase})
	func _update_element_garden() -> void:
		if not recording or light_observer or not observation_budget.admit(&"garden_step"):
			super._update_element_garden()
			return
		var started := Time.get_ticks_usec()
		super._update_element_garden()
		if recording: garden_step_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
	func _prepare_terrain_frame() -> void:
		if not recording or light_observer or not observation_budget.admit(&"terrain"):
			super._prepare_terrain_frame()
			return
		var started := Time.get_ticks_usec()
		super._prepare_terrain_frame()
		terrain_prepare_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
	func _prepare_retained_campus() -> void:
		if not recording or light_observer:
			super._prepare_retained_campus()
			return
		var started := Time.get_ticks_usec()
		super._prepare_retained_campus()
		retained_prepare_us += Time.get_ticks_usec() - started
		retained_prepare_calls += 1
	func set_retained_observer(enabled: bool) -> void:
		# Endpoint changes also cover a queued child draw at a capture boundary.
		# These six fixed counters never append per-frame observations.
		retained_campus.profile_enabled = enabled
		for layer in retained_campus.layers: layer.profile_enabled = enabled
	func _draw_pov_mask(origin: Vector2, aim: Vector2, camera_origin: Vector2) -> void:
		if not recording or light_observer or not observation_budget.admit(&"pov"):
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
		if casting and close_fire and (attempts < 12 or sustained):
			var actor: PlayerState = _local_player_state()
			sequence_ready = actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(actor.spell_wire_id(1)) == 0
		if casting and ((close_fire and sequence_ready and (not sustained or tick >= next_cast_tick)) or (not close_fire and tick >= next_cast_tick)):
			pressed |= SimCommand.SPELL_PRESSED_BITS[0]
			next_cast_tick = tick + 120
			attempts += 1
			if close_fire and recording and observation_budget.admit(&"cast_attempt"): cast_attempt_ticks.append(tick)
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
		frame_activity.clear()
		previous_activity = "idle"
		process_ms.clear()
		observer_overhead_ms.clear()
		draw_ms.clear()
		garden_step_ms.clear()
		pov_ms.clear()
		render_setup_ms.clear()
		terrain_prepare_ms.clear()
		retained_prepare_us = 0
		retained_prepare_calls = 0
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
		area_loading_frames = 0
		garden_arrival_loading_frames = 0
		viewport_mismatch_frames = 0
		distance_pixels = 0.0
		tile_crossings = 0
		last_position = _player_position()
		last_tile = Vector2i((last_position / 512.0).floor())
		max_static_memory = 0
		max_texture_memory = 0
		max_video_memory = 0
		world_stage_samples.clear()
		all_fixed_step_samples.clear()
		draw_stage_samples.clear()
		draw_stage_contexts.clear()

	func begin_completed_stage_case() -> bool:
		if not all_fixed_steps: return true
		if light_observer or world == null or not world.profile_enabled: return false
		return world.profile_cumulative_begin()

	func end_completed_stage_case() -> void:
		if all_fixed_steps and not light_observer and world != null:
			world.profile_cumulative_end()

	static func completed_stage_delta(before: Dictionary, after: Dictionary, process_elapsed_us: int) -> Dictionary:
		var result := {"valid": false, "error": "Invalid completed-stage boundary.", "completed_steps": 0, "elapsed_us": {}, "executions": {}}
		if process_elapsed_us < 0 or process_elapsed_us > 9007199254740991: return result
		for snapshot: Dictionary in [before, after]:
			if typeof(snapshot.get("enabled")) != TYPE_BOOL or typeof(snapshot.get("profile_enabled")) != TYPE_BOOL: return result
			if snapshot.get("schema") != "hex.sim.completed-stages.v1" or snapshot.get("enabled") != true or snapshot.get("profile_enabled") != true:
				return result
			if typeof(snapshot.get("hex_mode")) != TYPE_BOOL: return result
			if typeof(snapshot.get("world_id")) != TYPE_STRING: return result
			var world_identity: String = snapshot.world_id
			var digits: String = world_identity.substr(1) if world_identity.begins_with("-") else world_identity
			if digits.is_empty() or digits.length() > 20 or digits.begins_with("0"): return result
			for digit_index: int in digits.length():
				if digits.unicode_at(digit_index) < 48 or digits.unicode_at(digit_index) > 57: return result
			for key: String in ["epoch", "tick", "attempted_steps", "completed_steps", "failed_steps"]:
				if typeof(snapshot.get(key)) != TYPE_INT or int(snapshot[key]) < 0 or int(snapshot[key]) > 9007199254740991: return result
			if int(snapshot.epoch) <= 0 or int(snapshot.failed_steps) != 0 \
				or int(snapshot.attempted_steps) != int(snapshot.completed_steps) + int(snapshot.failed_steps): return result
			for lane: String in ["elapsed_us", "executions"]:
				if not snapshot.get(lane) is Dictionary or snapshot[lane].size() != SimWorld.PROFILE_CUMULATIVE_STAGES.size(): return result
				for stage: String in SimWorld.PROFILE_CUMULATIVE_STAGES:
					if typeof(snapshot[lane].get(stage)) != TYPE_INT or int(snapshot[lane][stage]) < 0 or int(snapshot[lane][stage]) > 9007199254740991: return result
			for stage: String in SimWorld.PROFILE_CUMULATIVE_STAGES:
				var count := int(snapshot.executions[stage])
				var wanted := 0 if stage == "actor_product_effects" and not bool(snapshot.hex_mode) else int(snapshot.completed_steps)
				if count != wanted: return result
				if count == 0 and int(snapshot.elapsed_us[stage]) != 0: return result
		if before.world_id != after.world_id or before.epoch != after.epoch or before.hex_mode != after.hex_mode:
			result.error = "World identity or profiling epoch changed within a process."
			return result
		var steps := int(after.completed_steps) - int(before.completed_steps)
		if steps < 0 or int(after.tick) - int(before.tick) != steps:
			result.error = "Completed steps and authoritative tick delta disagree."
			return result
		var elapsed_sum := 0
		for stage: String in SimWorld.PROFILE_CUMULATIVE_STAGES:
			var elapsed := int(after.elapsed_us[stage]) - int(before.elapsed_us[stage])
			var count := int(after.executions[stage]) - int(before.executions[stage])
			if elapsed < 0 or count < 0 or count > steps or (stage != "actor_product_effects" and count != steps) or (count == 0 and elapsed != 0): return result
			if stage == "actor_product_effects" and count != (steps if bool(before.hex_mode) else 0): return result
			result.elapsed_us[stage] = elapsed
			result.executions[stage] = count
			elapsed_sum += elapsed
		if elapsed_sum > process_elapsed_us:
			result.error = "Completed-stage elapsed total exceeds its containing process interval."
			return result
		result.valid = true
		result.error = ""
		result.completed_steps = steps
		return result

var game: TimedGame
var garden: TimedGarden
var court: TimedCourt
var campus: TimedCampus
var output_path := ""
var seconds_per_case := 10.0
var soak_seconds := 0.0
var screenshots := false
var light_observer := false
var viewport_render_timing := false
var all_fixed_steps := false
const VIEWPORT_TIMING_ROLES := ["root", "pov_main", "pov_spare"]
var viewport_timing_owned: Dictionary = {}
var viewport_timing_pending: Array[Dictionary] = []
var viewport_timing_samples: Array[Dictionary] = []
var viewport_timing_serial := 0
var viewport_timing_pre_frame := -1
var viewport_timing_pre_us := 0
var viewport_timing_post_us := 0
var viewport_timing_enabled_count := 0
var viewport_timing_disabled_count := 0
var viewport_timing_freed_count := 0
var profiles := PackedStringArray(["standard", "low"])
var selected_cases := PackedStringArray(DEFAULT_CASES)
var frame_limit := 60
var requested_window_size := Vector2i.ZERO
var results: Array[Dictionary] = []
var report: Dictionary = {}
var capture: Dictionary = {}
var failed := false
var observation_budget := ObservationBudget.new()
var run_id := ""
var foreground_arming: Dictionary = {"schema": "hex-foreground-arming-v1", "requested": false, "armed": false, "armed_utc_msec": null}

func _initialize() -> void:
	_run.call_deferred()

func _finalize() -> void:
	if all_fixed_steps and not light_observer and is_instance_valid(game): game.end_completed_stage_case()
	_disable_viewport_timing()

func _option(name: String, fallback: String = "") -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(name + "="): return argument.substr(name.length() + 1)
	return fallback

func _run() -> void:
	output_path = _option("--profile-output")
	run_id = _option("--profile-run-id")
	if run_id.is_empty(): _fail("Pass --profile-run-id to bind every case to the wrapper invocation."); return
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
	viewport_render_timing = OS.get_cmdline_user_args().has("--profile-viewport-render-timing")
	if viewport_render_timing and light_observer: _fail("Viewport render timing requires the full observer; omit --profile-light-observer."); return
	all_fixed_steps = OS.get_cmdline_user_args().has("--profile-all-fixed-steps")
	if all_fixed_steps and light_observer: _fail("All fixed-step attribution requires the full observer; omit --profile-light-observer."); return
	if DirAccess.make_dir_recursive_absolute(output_path.get_base_dir()) != OK: _fail("Could not create report directory."); return
	foreground_arming.requested = OS.get_cmdline_user_args().has("--profile-wait-for-foreground")
	# Early failures retain setup evidence even though no game has been created.
	report = {"schema": "hex-gameplay-profile-v1", "run_id": run_id, "complete": false, "foreground_arming": foreground_arming, "results": results}
	requested_window_size = Vector2i(clampi(int(_option("--profile-width", "1280")), 960, 2560), clampi(int(_option("--profile-height", "720")), 540, 1440))
	root.title = "H.E.X. performance check"
	root.mode = Window.MODE_WINDOWED
	root.visible = true
	root.unresizable = true
	# Native decoration/style changes can defer a client-area resize on Windows.
	# Let them settle before applying the requested client size and measuring.
	await process_frame
	await process_frame
	root.size = requested_window_size
	await process_frame
	await process_frame
	if root.size != requested_window_size: _fail("Native viewport refused requested bounds: " + str(root.size)); return
	# One explicit foreground request for this owned diagnostic window. The OS
	# may refuse it; sampled focus still gates the receipt, with no retry loop.
	if not foreground_arming.requested and not OS.get_cmdline_user_args().has("--profile-external-foreground-request"):
		DisplayServer.window_move_to_foreground(root.get_window_id())
	if foreground_arming.requested and not await _wait_for_foreground(): return
	# Independent disk provenance is collected outside every game timer. The
	# packaging identity can legitimately lag an in-progress source benchmark.
	var observed_source := _source_snapshot()
	var startup := Time.get_ticks_usec()
	if foreground_arming.requested:
		foreground_arming.game_instantiation_started_monotonic_usec = startup
		foreground_arming.game_instantiation_started_utc_msec = _utc_msec()
	var instance: Node = load("res://scenes/bootstrap/bootstrap.tscn").instantiate()
	instance.set_script(TimedGame)
	game = instance
	game.observation_budget = observation_budget
	game.light_observer = light_observer
	game.all_fixed_steps = all_fixed_steps
	game.expected_window_size = requested_window_size
	garden = TimedGarden.new()
	garden.observation_budget = observation_budget
	game.element_garden_presenter = garden
	court = TimedCourt.new()
	court.observation_budget = observation_budget
	game.hex_court_presenter = court
	root.add_child(game)
	if game.world == null or game.session_transport.mode != SessionTransport.Mode.OFFLINE: _fail("Benchmark startup did not produce an offline world."); return
	game.preference_overrides_are_transient = true
	game.world.profile_enabled = not light_observer
	# Delegate only the main campus call. The existing POV viewport keeps its
	# original renderer/reference and its capture is not mislabelled main draw.
	campus = TimedCampus.new()
	campus.observation_budget = observation_budget
	campus.delegate = game.campus_renderer
	campus.illustrated_kit = campus.delegate.illustrated_kit
	campus.natural_kit = campus.delegate.natural_kit
	campus.language = campus.delegate.language
	game.campus_renderer = campus
	RenderingServer.frame_post_draw.connect(_record_render_setup)
	if viewport_render_timing: RenderingServer.frame_pre_draw.connect(_prepare_viewport_timing)
	game.player_preferences.reduced_motion = false
	game.player_preferences.frame_limit = frame_limit
	game.player_preferences.render_quality = profiles[0]
	game._apply_performance_preferences()
	report = {"schema": "hex-gameplay-profile-v1", "run_id": run_id, "started_utc": Time.get_datetime_string_from_system(true),
		"foreground_arming": foreground_arming,
		"observation_limits": observation_budget.snapshot(),
		"observation_storage_scope": "At most12000 aligned callback record groups per stream per case and120000 groups across this run, in either observer mode. Each group has a fixed set of scalar/context fields or bounded runtime stage/material keys. Overflow stops collection, retains the partial case and fails the run; it never silently samples or admits truncated quantiles. Split long/high-frame-rate matrices into fresh runs. Raw result copies/JSON add transient memory beyond these record counts.",
		"focus_scope": "Engine focus is sampled once per recorded process callback and at case endpoints; wrapper separately validates exact owned HWND/client dimensions and sampled foreground. Synthetic commands continue through lost focus so failed evidence remains inspectable. Neither sampling path proves continuous focus or physical presentation.",
		"scope": "Instrumented native source runtime. Main-thread elapsed timers can include scheduling/driver waits. Frame-start intervals are not GPU time, physical presentation or input-to-photon latency. Nested timers are not additive. No 60FPS acceptance is inferred. Optional manual foreground setup occurs before game instantiation; source loading, empty-window setup, waiting and provenance hashing are excluded from game startup/case timers. Cold rows mean this game's process cache, not full process launch latency or a flushed OS cache.",
		"fixtures": "Fresh120Hz world per independent case, ordinary paid SimCommand casts, no measured-period refill. Direct placement/equip happens before warm measurement. Cold travel uses actual authored menu travel. Focus loss is observed, while deterministic commands continue.",
		"statistics": "Nearest-rank quantiles of raw process-start intervals; short samples do not establish stable tails. Sequential profile order is recorded; repeat in reverse order for comparisons.",
		"observer_mode": "light" if light_observer else "full",
		"all_fixed_steps": {"schema": "hex-completed-stage-observer-v1", "requested": all_fixed_steps, "stages": SimWorld.PROFILE_CUMULATIVE_STAGES},
		"all_fixed_steps_scope": "Explicit full-observer option only. Exactly one bounded before/after completed-stage group per admitted process, including zero-step frames; no per-tick history. Fixed nine cumulative elapsed/count lanes commit only successful steps. Failed steps, world/epoch changes, missing groups or inconsistent clocks invalidate attribution. Totals include every catch-up step and preserve the older final-step fields separately. Stage intervals are nested in Bootstrap process time and include observer overhead; residual work remains unassigned, not rendering or GPU time. Default and light perform no cumulative snapshots or accumulation. Snapshot copying is outside the process timer; enabled counter updates are inside it.",
		"viewport_render_timing": {"schema": "hex-viewport-render-timing-v1", "requested": viewport_render_timing, "viewport_limit": 3,
			"reading_scope": "last_engine_reading_source_frame_unknown", "update_mode_scope": "rendering_server_pre_draw", "cleanup": null},
		"viewport_render_timing_scope": "Optional, full observer only. At most root and two existing POV viewports; one fixed three-row group per admitted render_setup callback. Pre-draw effective RenderingServer policy is expected update eligibility, not proof of rendering (especially WHEN_VISIBLE); the requested node policy is recorded separately because it retains consumed ONCE requests. Effective-policy getters may synchronize the render thread, adding observer cost. CPU/GPU values are Godot's last stored engine readings, not necessarily the observation frame: the API exposes no source-frame ID. First eligible reading per case, after target replacement or any inactive gap is flagged warmup_or_resumed; inactive/absent targets are not queried and remain null. Numeric zero is retained without claiming true zero work or supported GPU timestamps. Per-role summaries separate continuous and warmup readings, never sum viewports or CPU/GPU. Timing instrumentation and callback bookkeeping add uncalibrated cost; callback totals exclude engine timestamp overhead. No player VSync/frame-cap change or physical-present inference.",
		"campus_mode": "retained" if game.retained_campus_enabled else "immediate_reference",
		"retained_campus_scope": "Six fixed child CanvasItems. Endpoint counter deltas include layer redraw requests, actual draw callbacks and inclusive draw-command generation time in full mode. Child draws run outside Bootstrap._draw; main draw elapsed alone cannot measure the change. Preparation elapsed is nested inside Bootstrap._process. These values are not GPU/present time or a total frame-cost sum. Light mode retains counts but disables all child timing; immediate reference keeps its main-campus timer.",
		"observer_policy": "Light mode retains frame/process/draw intervals, tick/endpoints and inexpensive counters; disables per-frame occupied-membership queries, memory monitors, stage dictionaries and nested component timers. Unavailable metrics are null, never inferred maxima. Both modes remain instrumented, not physical-presentation measurements.",
		"process_timer_scope": "Elapsed Bootstrap._process call only; excludes benchmark head/tail observation. Earlier receipts included head bookkeeping. Embedded simulation and nested component timer overhead remains inside this value in full mode.",
		"observer_overhead_scope": "Benchmark _process head and tail, excluding elapsed Bootstrap._process: interval recording, synthetic focus bookkeeping, focus/counters, final-step copies, paid-cell membership and memory monitors when enabled. Excludes draw/render-setup observation and the overhead of timers embedded inside Bootstrap/SimWorld. Includes scheduling waits, not pure CPU cost.",
		"draw_stage_scope": "Full mode clears stage storage immediately before each actual Bootstrap._draw call. main_draw_stages_us and main_draw_contexts align by index with draw_submission_elapsed_ms. Each context records a monotonic callback serial, process frame and entry phase. Loading/no-world callbacks have current empty stages, counted as zero for any stage observed elsewhere in that case; full draw elapsed time remains measured. No categories are invented if the entire case has no gameplay stages. Earlier receipts could repeat stale gameplay stage dictionaries during loading; their cold stage statistics are not valid.",
		"activity_scope": "Process intervals are partitioned by the preceding frame's post-process world state: loading, cast_or_projectile, paid_ground, post_effect_idle, idle. Full mode only; paid_ground means world presence, not visibility. Region samples separately identify visible paid ground and preserve process-frame IDs. Categories do not claim physical presentation timing.",
		"court_preparation_scope": "Full mode per-draw geometry and bundle timers plus elapsed drawing_and_other remainder. The remainder includes command submission and observer overhead, not GPU execution; nested surface and region timers are not additive.",
		"engine": Engine.get_version_info(), "debug_build": OS.is_debug_build(), "executable": OS.get_executable_path(),
		"renderer": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"screen_id": DisplayServer.window_get_current_screen(root.get_window_id()),
		"window_vsync_mode": DisplayServer.window_get_vsync_mode(root.get_window_id()),
		"screen_size": _v(DisplayServer.screen_get_size(DisplayServer.window_get_current_screen(root.get_window_id()))), "screen_refresh_hz": DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen(root.get_window_id())), "window_size": _v(root.size), "requested_window_size": _v(requested_window_size),
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
	_disable_viewport_timing()
	report.observed_source_after = _source_snapshot()
	report.observation_limits = observation_budget.snapshot()
	report["window_size_end"] = _v(root.size)
	if root.size != requested_window_size: _fail("Native viewport changed before report completion."); return
	report.observed_source_unchanged = bool(observed_source.ok) and bool(report.observed_source_after.ok) and String(observed_source.sha256) == String(report.observed_source_after.sha256)
	if foreground_arming.requested: _sample_post_arm_focus()
	report.complete = true
	if not _write_report(output_path): return
	print("HEX_GAMEPLAY_PROFILE_COMPLETE ", output_path)
	game.queue_free()
	await process_frame
	quit(0)

static func _utc_msec() -> int:
	return int(floor(Time.get_unix_time_from_system() * 1000.0))

func _wait_for_foreground() -> bool:
	var started := Time.get_ticks_usec()
	foreground_arming.merge({"setup_started_monotonic_usec": started, "setup_started_utc_msec": _utc_msec(),
		"deadline_ms": 300000, "stable_focus_required_ms": 1000, "maximum_poll_gap_ms": 250,
		"armed_monotonic_usec": null, "wait_elapsed_ms": 0, "stable_focus_elapsed_ms": 0, "stable_focus_samples": 0,
		"game_instantiation_started_monotonic_usec": null, "game_instantiation_started_utc_msec": null,
		"manual_confirmation_received": false, "manual_confirmation_phase": "setup", "manual_confirmation_kind": "start_button_pressed",
		"manual_confirmation_monotonic_usec": null, "manual_confirmation_utc_msec": null,
		"setup_focus_observations": [], "setup_focus_polls": 0, "setup_unfocused_polls": 0,
		"post_arm_focus": {"samples": 0, "unfocused_samples": 0, "focus_exit_events": 0},
		"scope": "SETUP: native Start button before source snapshot and TimedGame instantiation. An actual button pressed event must precede1000ms of sampled focus with no poll gap above250ms. Focus polled each process callback; at most3001 records at least100ms apart during the five-minute setup window. No input synthesis is performed. Godot focus alone is not OS foreground proof; independent Windows admission remains mandatory. All post-arm process callbacks and focus-exit events are counted, including preparation/warmups. Raw Windows rows retain their UTC setup/measurement boundary."}, true)
	root.title = "H.E.X. — click Start to begin performance test"
	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var prompt := Label.new()
	prompt.text = "Click Start when this window is in front.\nKeep H.E.X. in front until the test finishes."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(prompt)
	var start_button := Button.new()
	start_button.text = "Start performance test"
	start_button.custom_minimum_size = Vector2(320, 56)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(start_button)
	start_button.pressed.connect(_confirm_foreground_start.bind(start_button, prompt))
	start_button.grab_focus()
	var previous := started
	var stable_started := -1
	var stable_samples := 0
	var next_record := started
	while true:
		var now := Time.get_ticks_usec()
		var elapsed_ms := int((now - started) / 1000.0)
		foreground_arming.wait_elapsed_ms = elapsed_ms
		if now - started > 300000000:
			panel.free()
			_fail("Foreground setup did not arm within five minutes. Setup observations and the unqualified partial report are retained.")
			return false
		var focused := root.has_focus()
		var eligible := bool(foreground_arming.manual_confirmation_received) and focused and root.visible and root.mode != Window.MODE_MINIMIZED and root.size == requested_window_size
		foreground_arming.setup_focus_polls += 1
		if not focused: foreground_arming.setup_unfocused_polls += 1
		if not eligible or now - previous > 250000:
			stable_started = -1
			stable_samples = 0
		if eligible:
			if stable_started < 0: stable_started = now
			stable_samples += 1
		var record_due := now >= next_record
		if record_due:
			foreground_arming.setup_focus_observations.append({"phase": "setup", "elapsed_ms": elapsed_ms, "focused": focused, "eligible": eligible})
			next_record = now + 100000
		if record_due and eligible and stable_samples >= 3 and now - stable_started >= 1000000:
			foreground_arming.armed = true
			foreground_arming.armed_monotonic_usec = now
			foreground_arming.armed_utc_msec = _utc_msec()
			foreground_arming.stable_focus_elapsed_ms = int((now - stable_started) / 1000.0)
			foreground_arming.stable_focus_samples = stable_samples
			panel.free()
			root.title = "H.E.X. performance check — keep this window in front"
			process_frame.connect(_sample_post_arm_focus)
			root.focus_exited.connect(_record_post_arm_focus_exit)
			_sample_post_arm_focus()
			print("HEX_GAMEPLAY_PROFILE_ARMED ", run_id, " ", foreground_arming.armed_utc_msec)
			return true
		previous = now
		await process_frame
	return false

func _confirm_foreground_start(button: Button, prompt: Label) -> void:
	if foreground_arming.manual_confirmation_received: return
	foreground_arming.manual_confirmation_monotonic_usec = Time.get_ticks_usec()
	foreground_arming.manual_confirmation_utc_msec = _utc_msec()
	foreground_arming.manual_confirmation_received = true
	button.disabled = true
	prompt.text = "Start confirmed. Keep this window in front.\nThe performance test will begin after the focus check."

func _sample_post_arm_focus() -> void:
	foreground_arming.post_arm_focus.samples += 1
	if not root.has_focus(): foreground_arming.post_arm_focus.unfocused_samples += 1

func _record_post_arm_focus_exit() -> void:
	foreground_arming.post_arm_focus.focus_exit_events += 1

func _run_case(label: String, profile: String, duration: float, result_label: String = "") -> bool:
	game.casting = false
	game.close_fire = false
	game.sustained = label.ends_with("_sustained")
	game.moving = false
	var original_pointer := game.capture_pointer_world
	game.element_garden.clear()
	if not game._start_match_world(120): _fail("Fresh world failed before " + label); return false
	game.world.profile_enabled = not light_observer
	game.player_camera.clear()
	var fixture := {"source_case": label, "fresh_world": true, "fixture_prepare_ms": 0.0}
	var started := Time.get_ticks_usec()
	if label in ["paid_fire_bolt_close", "paid_fire_bolt_sustained"]:
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
	if label in ["paid_fire_bolt", "paid_all_six_mantle", "range_paid_fire", "paid_fire_bolt_close", "paid_fire_bolt_sustained", "paid_all_six_mantle_sustained"]:
		var mantle := label in ["paid_all_six_mantle", "paid_all_six_mantle_sustained"]
		var wire := Mixtures.wire_for(63 if mantle else 2, "mantle" if mantle else "bolt")
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
		if game.sustained:
			fixture["cast_policy"] = "Ordinary paid attempts no faster than once per120 simulation ticks throughout the measured duration; natural recovery/recharge only. Insufficient resource refusals are reported, never refilled."
			fixture["resource_refill"] = false
	fixture.fixture_prepare_ms = float(Time.get_ticks_usec() - started) / 1000.0
	game.world.profile_enabled = not light_observer
	if not await _wait_ready(): _fail("Warm case readiness timed out: " + label); return false
	await _wait_seconds(1.0)
	game.next_cast_tick = game.world.tick + 1
	game.motion_start_tick = game.world.tick
	game.casting = label in ["paid_fire_bolt", "paid_all_six_mantle", "range_paid_fire", "paid_fire_bolt_close", "paid_fire_bolt_sustained", "paid_all_six_mantle_sustained"]
	game.close_fire = label in ["paid_fire_bolt_close", "paid_fire_bolt_sustained"]
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
		if observation_budget.overflow: return false
		if not game.element_garden_arrival_error.is_empty(): return false
		var origin: Vector2 = game._camera_origin(game._camera_focus_position(game.current_position))
		# canvas_items stretching can make the native window larger than the
		# gameplay viewport (notably in tiling compositors). Match the renderer's
		# world view instead of waiting for terrain it never requested.
		var visible := Rect2(origin, game.get_viewport_rect().size / game._camera_zoom_scale())
		var terrain_ready: bool = game._is_hex_practice() or game.campus_renderer.terrain_ready_for(SanctumCampusRenderer.terrain_preparation_rect(visible))
		var backdrop_ready: bool = game._is_hex_practice() or game.pov_terrain_backdrop.ready_for(visible)
		if not game._area_loading() and terrain_ready and backdrop_ready and game._character_pages_ready:
			stable += 1
			if stable >= 3: return true
		else: stable = 0
		if not game.terrain_loading_error.is_empty(): return false
	return false

func _wait_seconds(duration: float) -> void:
	var started := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started) / 1000000.0 < duration and not observation_budget.overflow: await process_frame

func _begin(label: String, profile: String, temperature: String) -> void:
	observation_budget.begin_case()
	viewport_timing_samples.clear()
	viewport_timing_pending.clear()
	viewport_timing_serial = 0
	viewport_timing_pre_frame = -1
	viewport_timing_pre_us = 0
	viewport_timing_post_us = 0
	for owned: Dictionary in viewport_timing_owned.values(): owned["was_expected"] = false
	campus.begin_terrain_profile(not light_observer)
	game.reset_samples()
	if all_fixed_steps and not game.begin_completed_stage_case():
		_fail("Completed-stage observer could not begin on the current profiled world.")
		return
	garden.samples.clear()
	garden.stages.clear()
	court.samples.clear()
	court.preparation_samples.clear()
	court.geometry_us = 0
	court.bundle_us = 0
	court.surface_us = 0
	court.region_detail = label.begins_with("paid_") or label == "range_paid_fire"
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
		"started_utc_msec": _utc_msec(),
		"window_size_before": _v(root.size), "window_focus_before": root.has_focus(),
		"paid_before": int(game.world.hex_court.metrics.matter_paid), "admitted_before": int(game.world.hex_court.metrics.admitted), "refused_before": int(game.world.hex_court.metrics.refused), "dropped_before": game.dropped_time_seconds, "clamped_before": game.clamped_frame_time_seconds,
		"court_cache_before": {"geometry": court.geometry_cache_stats(), "outline": court.outline_cache_stats(), "surface": court.material_surface.stats()},
		"hud_preparation_before": game.compact_hud.preparation_stats(),
		"retained_campus_before": game.retained_campus.stats(),
		"terrain_before": game.campus_renderer.terrain_status(), "position_before": _v(game._player_position()), "flux_before": game._local_player_state().flux,
		"memory_before": memory_before, "paid_cells_before": paid_cells_before}
	game.recording = true
	game.set_retained_observer(not light_observer)
	garden.recording = not light_observer
	court.recording = not light_observer
	campus.recording = not light_observer

func _end(ready: bool, fixture: Dictionary) -> bool:
	game.recording = false
	var completed_summary: Variant = _completed_stage_summary() if all_fixed_steps else null
	if all_fixed_steps: game.end_completed_stage_case()
	game.set_retained_observer(false)
	garden.recording = false
	court.recording = false
	campus.recording = false
	var elapsed := float(Time.get_ticks_usec() - int(capture.start_us)) / 1000000.0
	var arrival_error: String = game.element_garden_arrival_error
	var row := {"label": capture.label, "quality": capture.quality, "temperature": capture.temperature, "ready": ready and arrival_error.is_empty(), "garden_arrival_error": arrival_error, "wall_seconds": elapsed,
		"started_utc_msec": capture.started_utc_msec, "started_monotonic_usec": capture.start_us,
		"run_id": run_id, "case_index": results.size(), "observation_limits": observation_budget.snapshot(),
		"workload": {"map_id": game.world.map_id, "champion_wire": game._local_player_state().champion_wire_id, "tick_begin": capture.tick_before, "tick_end": game.world.tick, "phase": capture.temperature, "synthetic_commands": true, "resource_refill": false},
		"observer_mode": "light" if light_observer else "full",
		"campus_mode": "retained" if game.retained_campus_enabled else "immediate_reference",
		"frame_interval_ms": _stats(game.frame_ms), "process_elapsed_ms": _stats(game.process_ms), "draw_submission_elapsed_ms": _stats(game.draw_ms),
		"observer_overhead_elapsed_ms": _stats(game.observer_overhead_ms),
		"garden_draw_elapsed_ms": _stats(garden.samples), "garden_step_elapsed_ms": _stats(game.garden_step_ms), "pov_elapsed_ms": _stats(game.pov_ms),
		"main_court_draw_elapsed_ms": _stats(court.samples), "main_campus_draw_elapsed_ms": _stats(campus.samples),
		"engine_render_setup_cpu_ms": _stats(game.render_setup_ms),
		"terrain_preparation_elapsed_ms": _stats(game.terrain_prepare_ms),
		"frame_interval_by_activity_ms": _partition_stats(game.frame_ms, game.frame_activity),
		"main_court_preparation_stats_ms": _stage_stats(court.preparation_samples),
		"main_court_by_visible_ground_ms": _court_activity_stats(),
		"hud_preparation_endpoints": {"before": capture.hud_preparation_before, "after": game.compact_hud.preparation_stats()},
		"retained_campus_endpoints": {"before": capture.retained_campus_before, "after": game.retained_campus.stats()},
		"retained_campus_prepare": null if light_observer else {"calls": game.retained_prepare_calls, "elapsed_us": game.retained_prepare_us},
		"main_court_components_total_us": {"geometry": court.geometry_us, "bundle": court.bundle_us, "surface": court.surface_us, "draw_count": court.samples.size()},
		"world_stage_sample_scope": "One final completed fixed step per rendered process frame; not every step or a sum across catch-up steps. Includes the stage timing overhead and may undersample rare earlier steps.",
		"last_fixed_step_stage_stats_ms": _world_stage_stats(game.world_stage_samples),
		"main_draw_stage_stats_ms": _stage_stats(game.draw_stage_samples), "garden_stage_stats_ms": _stage_stats(garden.stages),
		"raw": {"frame_start_us": game.frame_start_us.duplicate(), "frame_interval_ms": game.frame_ms.duplicate(), "process_elapsed_ms": game.process_ms.duplicate(), "draw_submission_elapsed_ms": game.draw_ms.duplicate(), "garden_draw_elapsed_ms": garden.samples.duplicate(), "garden_step_elapsed_ms": game.garden_step_ms.duplicate(), "pov_elapsed_ms": game.pov_ms.duplicate()},
		"ticks_advanced": game.world.tick - int(capture.tick_before), "ticks_per_wall_second": float(game.world.tick - int(capture.tick_before)) / maxf(elapsed, 0.000001),
		"dropped_accumulator_seconds": game.dropped_time_seconds - float(capture.dropped_before), "clamped_delta_seconds": game.clamped_frame_time_seconds - float(capture.clamped_before),
		"cast_attempts": game.attempts, "matter_paid_delta": int(game.world.hex_court.metrics.matter_paid) - int(capture.paid_before),
		"admitted_casts_delta": int(game.world.hex_court.metrics.admitted) - int(capture.admitted_before),
		"refused_casts_delta": int(game.world.hex_court.metrics.refused) - int(capture.refused_before),
		"max_projectiles": game.max_projectiles, "max_paid_cells": game.max_paid_cells, "max_resident_plots": game.max_resident_plots,
		"paid_cells_endpoints": {"before": capture.paid_cells_before, "after": game.world.hex_court.occupied_cells().size()},
		"flux_before": capture.flux_before, "flux_after": game._local_player_state().flux, "champion_wire": game._local_player_state().champion_wire_id,
		"position_before": capture.position_before, "position_after": _v(game._player_position()), "distance_pixels": game.distance_pixels, "terrain_tile_crossings": game.tile_crossings,
		"terrain_before": capture.terrain_before, "terrain_after": game.campus_renderer.terrain_status(), "terrain_loading_frames": game.loading_frames,
		"area_loading_frames": game.area_loading_frames, "garden_arrival_loading_frames": game.garden_arrival_loading_frames,
		"loading_counter_scope": "Post-process observations. Terrain retains its original meaning; area is terrain or explicit Garden arrival. Garden and terrain counts can overlap and must not be added. A final preparation frame that becomes ready within its process is not counted as still loading.",
		"window_focus_before": capture.window_focus_before, "window_focus_end": root.has_focus(), "focus_sample_count": game.process_ms.size(), "unfocused_frames": game.unfocused_frames, "window_size": _v(root.size), "window_size_before": capture.window_size_before, "viewport_mismatch_frames": game.viewport_mismatch_frames, "world_map": game.world.map_id,
		"memory_max_bytes": {"static": game.max_static_memory, "textures": game.max_texture_memory, "video": game.max_video_memory},
		"memory_endpoint_bytes": {"before": capture.memory_before, "after": _memory_endpoint()},
		"render_last": {"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)},
		"fixture": fixture}
	row.raw["main_court_draw_elapsed_ms"] = court.samples.duplicate()
	row.raw["main_court_preparation_us"] = court.preparation_samples.duplicate(true)
	row.raw["visible_paid_regions"] = court.region_draw_samples.duplicate(true)
	row.raw["frame_activity"] = game.frame_activity.duplicate()
	row.raw["terrain_preparation_elapsed_ms"] = game.terrain_prepare_ms.duplicate()
	row.raw["observer_overhead_elapsed_ms"] = game.observer_overhead_ms.duplicate()
	row.raw["main_campus_draw_elapsed_ms"] = campus.samples.duplicate()
	row.raw["last_fixed_step_stages"] = game.world_stage_samples.duplicate(true)
	row["all_fixed_step_totals"] = completed_summary
	row.raw["all_fixed_steps"] = game.all_fixed_step_samples.duplicate(true) if all_fixed_steps else null
	row.raw["engine_render_setup_cpu_ms"] = game.render_setup_ms.duplicate()
	row.raw["main_draw_stages_us"] = game.draw_stage_samples.duplicate(true)
	row.raw["main_draw_contexts"] = game.draw_stage_contexts.duplicate(true)
	row.raw["garden_stages_us"] = garden.stages.duplicate(true)
	row["viewport_render_timing"] = _viewport_timing_summary() if viewport_render_timing else null
	row.raw["viewport_render_timing"] = viewport_timing_samples.duplicate(true) if viewport_render_timing else null
	if capture.label == "paid_fire_bolt_close":
		row["cast_attempt_ticks"] = game.cast_attempt_ticks.duplicate()
		row["admitted_casts_delta"] = int(game.world.hex_court.metrics.admitted) - int(capture.admitted_before)
		row["refused_casts_delta"] = int(game.world.hex_court.metrics.refused) - int(capture.refused_before)
		row["close_fire_observation"] = null if light_observer else {"max_cast_records": game.max_cast_records, "max_ground_parts": game.max_ground_parts, "max_products": game.max_products, "prepare_region_inclusive_us": court.prepare_region_us, "prepare_region_calls": court.prepare_region_calls, "accepted_prepared_regions": court.accepted_regions, "max_prepared_regions_per_draw": court.max_prepared_regions_per_draw, "prepared_regions_by_material": court.prepared_regions_by_material.duplicate(), "per_draw_regions": court.region_draw_samples.duplicate(true), "mirror_product_inclusive_us": court.mirror_product_us, "mirror_product_calls": court.mirror_product_calls, "fire_mark_inclusive_us": court.fire_mark_us, "fire_mark_calls": court.fire_mark_calls, "cache_before": capture.court_cache_before, "cache_after": {"geometry": court.geometry_cache_stats(), "outline": court.outline_cache_stats(), "surface": court.material_surface.stats()}}
	row["unavailable_metrics"] = []
	if light_observer:
		for metric: String in ["max_paid_cells", "memory_max_bytes", "garden_draw_elapsed_ms", "garden_step_elapsed_ms", "pov_elapsed_ms", "main_court_draw_elapsed_ms", "main_campus_draw_elapsed_ms", "main_court_components_total_us", "last_fixed_step_stage_stats_ms", "main_draw_stage_stats_ms", "garden_stage_stats_ms", "engine_render_setup_cpu_ms", "terrain_preparation_elapsed_ms", "frame_interval_by_activity_ms", "main_court_preparation_stats_ms", "main_court_by_visible_ground_ms"]:
			row[metric] = null
			row.unavailable_metrics.append(metric)
		for metric: String in ["garden_draw_elapsed_ms", "garden_step_elapsed_ms", "pov_elapsed_ms", "main_court_draw_elapsed_ms", "main_campus_draw_elapsed_ms", "last_fixed_step_stages", "main_draw_stages_us", "main_draw_contexts", "garden_stages_us", "engine_render_setup_cpu_ms", "terrain_preparation_elapsed_ms", "frame_activity", "main_court_preparation_us", "visible_paid_regions"]:
			row.raw[metric] = null
	results.append(row)
	campus.end_terrain_profile()
	report.observation_limits = observation_budget.snapshot()
	if not _write_report(output_path + ".partial.json"): return false
	if not arrival_error.is_empty():
		_fail("Garden arrival preparation failed: " + arrival_error + "; partial evidence retained.")
		return false
	if all_fixed_steps and not bool(completed_summary.valid):
		_fail("Completed-stage attribution failed: " + String(completed_summary.error) + "; partial evidence retained.")
		return false
	if observation_budget.overflow:
		_fail("Observation budget exhausted in stream " + observation_budget.overflow_stream + "; partial evidence retained, shorten or split this diagnostic.")
		return false
	if capture.window_size_before != _v(requested_window_size) or root.size != requested_window_size or game.viewport_mismatch_frames > 0:
		_fail("Viewport changed during case: " + String(capture.label))
		return false
	var summary := row.duplicate()
	summary.erase("raw")
	print("HEX_GAMEPLAY_PROFILE_CASE ", JSON.stringify(summary))
	return true

func _court_activity_stats() -> Dictionary:
	var labels: Array[String] = []
	for sample: Dictionary in court.region_draw_samples:
		labels.append("visible_paid_ground" if int(sample.regions) > 0 else "no_visible_paid_ground")
	return _partition_stats(court.samples, labels)


static func _partition_stats(values: Array[float], labels: Array[String]) -> Dictionary:
	if values.size() != labels.size(): return {}
	var groups: Dictionary = {}
	for index: int in values.size():
		if not groups.has(labels[index]):
			var samples: Array[float] = []
			groups[labels[index]] = samples
		groups[labels[index]].append(values[index])
	var result: Dictionary = {}
	for label: String in groups: result[label] = _stats(groups[label])
	return result

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
	if game != null and game.recording and not light_observer and observation_budget.admit(&"render_setup"):
		game.render_setup_ms.append(RenderingServer.get_frame_setup_time_cpu())
		if viewport_render_timing: _record_viewport_timing()

func _prepare_viewport_timing() -> void:
	if game == null or not game.recording or observation_budget.overflow: return
	var started := Time.get_ticks_usec()
	viewport_timing_serial += 1
	viewport_timing_pre_frame = Engine.get_process_frames()
	viewport_timing_pending.clear()
	var main: SubViewport = game.pov_terrain_backdrop
	var spare: SubViewport = main.get("_spare_view") if is_instance_valid(main) else null
	var targets: Array = [root, main, spare]
	for index: int in range(VIEWPORT_TIMING_ROLES.size()):
		var role: String = VIEWPORT_TIMING_ROLES[index]
		var target: Viewport = targets[index]
		var row := {"role": role, "instance_id": null, "update_mode_before": null, "requested_node_update_mode": null, "expected_update": false,
			"status": "absent", "source_frame": null, "cpu_last_engine_reading_ms": null, "gpu_last_engine_reading_ms": null}
		if not is_instance_valid(target):
			_release_viewport_timing_role(role)
			viewport_timing_pending.append(row)
			continue
		var owned: Dictionary = viewport_timing_owned.get(role, {})
		if owned.is_empty() or owned.instance_id != target.get_instance_id():
			_release_viewport_timing_role(role)
			RenderingServer.viewport_set_measure_render_time(target.get_viewport_rid(), true)
			owned = {"reference": weakref(target), "instance_id": target.get_instance_id(), "was_expected": false}
			viewport_timing_owned[role] = owned
			viewport_timing_enabled_count += 1
		var expected: bool
		if target is Window:
			row.update_mode_before = "visible_window"
			expected = root.visible and root.mode != Window.MODE_MINIMIZED
		else:
			var sub: SubViewport = target as SubViewport
			# The node retains its requested ONCE mode after the server consumes it.
			# Read effective server policy only in this opt-in observer; the getter
			# can synchronize the render thread and its cost is included above.
			row.requested_node_update_mode = int(sub.render_target_update_mode)
			row.update_mode_before = int(RenderingServer.viewport_get_update_mode(sub.get_viewport_rid()))
			expected = int(row.update_mode_before) != SubViewport.UPDATE_DISABLED
		row.instance_id = target.get_instance_id()
		row.expected_update = expected
		row.status = ("last_engine_reading" if bool(owned.was_expected) else "warmup_or_resumed") if expected else "inactive"
		owned.was_expected = expected
		viewport_timing_pending.append(row)
	viewport_timing_pre_us += Time.get_ticks_usec() - started

func _record_viewport_timing() -> void:
	var started := Time.get_ticks_usec()
	# frame_pre_draw captures UPDATE_ONCE before rendering resets it to DISABLED.
	# The getter still exposes only its last engine reading, with no source-frame
	# identity; even a continuously eligible viewport can have delayed timestamps.
	var rows: Array[Dictionary] = viewport_timing_pending.duplicate(true)
	for row: Dictionary in rows:
		if not bool(row.expected_update): continue
		var owned: Dictionary = viewport_timing_owned.get(row.role, {})
		var target: Viewport = owned.reference.get_ref() if not owned.is_empty() else null
		if not is_instance_valid(target) or target.get_instance_id() != row.instance_id:
			row.status = "unavailable_after_pre_draw"
			continue
		var rid: RID = target.get_viewport_rid()
		row.cpu_last_engine_reading_ms = RenderingServer.viewport_get_measured_render_time_cpu(rid)
		row.gpu_last_engine_reading_ms = RenderingServer.viewport_get_measured_render_time_gpu(rid)
	viewport_timing_samples.append({"observation_serial": viewport_timing_serial,
		"pre_draw_process_frame": viewport_timing_pre_frame, "observation_process_frame": Engine.get_process_frames(), "source_frame_unknown": true, "viewports": rows})
	viewport_timing_pending.clear()
	viewport_timing_post_us += Time.get_ticks_usec() - started

func _viewport_timing_summary() -> Dictionary:
	var roles := {}
	for role: String in VIEWPORT_TIMING_ROLES:
		var counts := {"absent": 0, "inactive": 0, "warmup_or_resumed": 0, "last_engine_reading": 0, "unavailable_after_pre_draw": 0}
		var continuous_cpu: Array[float] = []
		var continuous_gpu: Array[float] = []
		var warmup_cpu: Array[float] = []
		var warmup_gpu: Array[float] = []
		for group: Dictionary in viewport_timing_samples:
			for row: Dictionary in group.viewports:
				if row.role != role: continue
				counts[row.status] += 1
				if row.status == "last_engine_reading":
					continuous_cpu.append(row.cpu_last_engine_reading_ms)
					continuous_gpu.append(row.gpu_last_engine_reading_ms)
				elif row.status == "warmup_or_resumed":
					warmup_cpu.append(row.cpu_last_engine_reading_ms)
					warmup_gpu.append(row.gpu_last_engine_reading_ms)
		roles[role] = {"status_counts": counts,
			"continuous_cpu_last_engine_reading_ms": _stats(continuous_cpu), "continuous_gpu_last_engine_reading_ms": _stats(continuous_gpu),
			"warmup_cpu_last_engine_reading_ms": _stats(warmup_cpu), "warmup_gpu_last_engine_reading_ms": _stats(warmup_gpu)}
	return {"group_count": viewport_timing_samples.size(), "viewport_limit": 3,
		"observer_pre_elapsed_us": viewport_timing_pre_us, "observer_post_elapsed_us": viewport_timing_post_us, "roles": roles}

func _release_viewport_timing_role(role: String) -> void:
	if not viewport_timing_owned.has(role): return
	var owned: Dictionary = viewport_timing_owned[role]
	var target: Viewport = owned.reference.get_ref()
	if is_instance_valid(target):
		RenderingServer.viewport_set_measure_render_time(target.get_viewport_rid(), false)
		viewport_timing_disabled_count += 1
	else:
		viewport_timing_freed_count += 1
	viewport_timing_owned.erase(role)

func _disable_viewport_timing() -> void:
	if not viewport_render_timing: return
	if RenderingServer.frame_pre_draw.is_connected(_prepare_viewport_timing): RenderingServer.frame_pre_draw.disconnect(_prepare_viewport_timing)
	for role: String in VIEWPORT_TIMING_ROLES: _release_viewport_timing_role(role)
	viewport_timing_pending.clear()
	if report.has("viewport_render_timing"):
		report.viewport_render_timing.cleanup = {"enabled_count": viewport_timing_enabled_count, "disabled_count": viewport_timing_disabled_count,
			"freed_before_cleanup_count": viewport_timing_freed_count, "live_owned_count": viewport_timing_owned.size(), "pre_draw_callback_connected": RenderingServer.frame_pre_draw.is_connected(_prepare_viewport_timing)}

func _completed_stage_summary() -> Dictionary:
	var summary := {"valid": false, "error": "Incomplete process coverage.", "process_frames": game.all_fixed_step_samples.size(), "completed_steps": 0, "elapsed_us": {}, "executions": {}}
	for stage: String in SimWorld.PROFILE_CUMULATIVE_STAGES:
		summary.elapsed_us[stage] = 0
		summary.executions[stage] = 0
	if game.all_fixed_step_samples.is_empty() or game.all_fixed_step_samples.size() != game.process_ms.size(): return summary
	var previous: Dictionary = {}
	var last_process_frame := -1
	var last_end_us := -1
	for index: int in game.all_fixed_step_samples.size():
		var row: Dictionary = game.all_fixed_step_samples[index]
		var current: Dictionary = row.delta
		if not bool(current.valid):
			summary.error = current.error
			return summary
		if int(row.process_index) != index or int(row.process_frame) <= last_process_frame or int(row.process_started_us) < last_end_us: return summary
		if not previous.is_empty() and previous != row.before: return summary
		if index == 0 and int(row.before.tick) != int(capture.tick_before): return summary
		previous = row.after
		last_process_frame = int(row.process_frame)
		last_end_us = int(row.process_started_us) + int(row.process_elapsed_us)
		summary.completed_steps += int(current.completed_steps)
		for stage: String in SimWorld.PROFILE_CUMULATIVE_STAGES:
			summary.elapsed_us[stage] += int(current.elapsed_us[stage])
			summary.executions[stage] += int(current.executions[stage])
	if game.world == null or previous.world_id != str(game.world.get_instance_id()) or int(previous.tick) != game.world.tick \
		or int(summary.completed_steps) != game.world.tick - int(capture.tick_before): return summary
	summary.valid = true
	summary.error = ""
	return summary


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
	if all_fixed_steps and not light_observer and is_instance_valid(game): game.end_completed_stage_case()
	_disable_viewport_timing()
	if not report.is_empty():
		report.complete = false
		report["error"] = message
	push_error(message)
	# Do not recursively try to report a failure through the same failed output.
	quit(1)
	return false

func _fail(message: String) -> void:
	failed = true
	if all_fixed_steps and not light_observer and is_instance_valid(game): game.end_completed_stage_case()
	_disable_viewport_timing()
	push_error(message)
	if not report.is_empty():
		report["error"] = message
		report.complete = false
		_write_report(output_path + ".partial.json")
	quit(1)
